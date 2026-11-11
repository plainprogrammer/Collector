# Writes what an apply decided about the collector's decks and zones, with its places, inside the apply's one write
# transaction (spec 062 Story 8). One entry point, because the order is the rule: every removal, of a place or a deck, before
# any addition, of a place or a deck, since both share one name space and its unique index (AC-8.3); and a zone is written
# only after its deck. Every step is a bulk statement, a number of statements that depends on the registered formats and
# on BATCH_SIZE, never on the number of decks (AC-8.9). The reader judged every row, so the statements skip the models'
# validations on purpose, and a spec checks each written row against `Location` and `Deck`.
#
# Collectible-agnostic: a deck's collectible type and format are text, and its zones are what `Catalog::Formats` registers.
# @see file:data-portability.md
module CollectionImport::DeckChanges
  # Writes the places and, for a file that counts decks (version 4), the decks, their locations and their zones. The caller has
  # deleted the removed lots already, the lots of a removed deck's zones and of a zone a deck loses among them, so no lot's
  # foreign key fires. Writing the same plan twice is safe: the second time finds every row in place and writes only what a
  # repair still needs.
  #
  # The order: the removed places; the removed decks (their zones and `decks` rows go with them, by the foreign keys) and the
  # zones format-changed decks lose; then the added and renamed places; the added and renamed decks' locations; the `decks`
  # rows of added and format-changed decks; and last the repair of the zones of every deck the file lists (AC-8.2a).
  #
  # @param account [Account]
  # @param locations [CollectionImport::Locations]
  # @param decks [CollectionImport::Decks] uncounted for a version 1 to 3 file, which leaves the collector's decks alone
  # @return [void]
  def self.write!(account, locations, decks)
    CollectionImport::LocationChanges.remove!(account, locations)
    remove!(account, decks)
    CollectionImport::LocationChanges.add!(account, locations)
    return unless decks.counted?

    CollectionImport::LocationChanges.upsert_top_level!(account, decks.added.map(&:name) + decks.renamed.map(&:name), "deck")
    write_deck_rows!(account, decks)
    repair_zones!(account)
  end

  # Deletes the removed decks' locations (the foreign keys cascade to their zones and `decks` rows) and, for each deck whose
  # format changes, the zones the new format lacks: one statement per BATCH_SIZE decks and per new format.
  #
  # @api private
  def self.remove!(account, decks)
    decks.removed.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| account.locations.where(id: ids).delete_all }
    decks.format_changed.group_by { |change| [ change.collectible_type, change.format ] }.each do |(type, format), changes|
      keys = Catalog::Formats.zones_for(type, format).map(&:key)
      changes.map { |change| change.held.id }.each_slice(CollectionImport::BATCH_SIZE) do |ids|
        account.locations.zones_of_decks.where(parent_id: ids).where.not(zone: keys).delete_all
      end
    end
  end
  private_class_method :remove!

  # The `decks` rows of the added decks (their locations are written) and the new type and format of the format-changed ones:
  # one upsert per BATCH_SIZE on the unique `location_id`.
  def self.write_deck_rows!(account, decks)
    ids = account.locations.decks.pluck(:name_key, :id).to_h
    now = Time.current
    rows = decks.added.map { |deck| [ Location::Name.key(deck.name), deck.collectible_type, deck.format ] } +
      decks.format_changed.map { |change| [ change.held.key, change.collectible_type, change.format ] }
    rows.map { |key, type, format| { account_id: account.id, location_id: ids.fetch(key), collectible_type: type, format:, created_at: now, updated_at: now } }
      .each_slice(CollectionImport::BATCH_SIZE) do |slice|
        Deck.upsert_all(slice, unique_by: :location_id, update_only: %i[collectible_type format updated_at], record_timestamps: false, returning: false)
      end
  end
  private_class_method :write_deck_rows!

  # Makes every deck of the account (after the removals, those the file lists) hold exactly one zone row for each zone of its
  # format, with the registration's key and name (spec 062 AC-8.2a): the zones a release added are inserted, and the names of
  # the zones a deck has are rewritten from the registration first, so a zone's old name never meets another's new name in
  # the zone name index. It reads the decks and their zones once and writes only where something differs, so an apply that
  # needs no repair writes nothing here, and the number of statements follows the registered formats, not the decks. A zone
  # whose key the format lacks is left alone (it holds no lot: the file can't name it).
  def self.repair_zones!(account)
    decks = account.decks.order(:location_id).pluck(:location_id, :collectible_type, :format)
    return if decks.empty?

    held = account.locations.zones_of_decks.order(:id).pluck(:parent_id, :zone, :id, :name, :name_key).group_by(&:first)
    now = Time.current
    stale = []
    missing = []
    decks.each do |deck_id, type, format|
      have = held.fetch(deck_id, []).index_by { |_parent, zone| zone }
      Array(Catalog::Formats.zones_for(type, format)).each do |zone|
        name = Location::Name.normalise(zone.name)
        key = Location::Name.key(name)
        existing = have[zone.key]
        if existing.nil?
          missing << { account_id: account.id, parent_id: deck_id, kind: "deck_zone", zone: zone.key, name:, name_key: key, created_at: now, updated_at: now }
        elsif existing[3] != name || existing[4] != key
          stale << [ existing[2], name, key ]
        end
      end
    end
    rename_zones!(account, stale, now)
    missing.each_slice(CollectionImport::BATCH_SIZE) do |slice|
      Location.insert_all(slice, unique_by: :index_locations_on_parent_id_and_name_key, returning: false)
    end
  end
  private_class_method :repair_zones!

  # Rewrites zone names in two passes: first every zone to rewrite is given a name key no name can have (a name holds no
  # control character, so U+0001 and its id are free), then each gets its registered name and key. Two zones that exchange
  # names, or a zone that takes another's old one, would otherwise meet in the unique index in the middle of one statement.
  # Statements: one per BATCH_SIZE zones for the first pass, one per distinct registered name for the second.
  def self.rename_zones!(account, stale, now)
    stale.map(&:first).each_slice(CollectionImport::BATCH_SIZE) { |ids| account.locations.where(id: ids).update_all("name_key = char(1) || id") }
    stale.group_by { |_id, name, key| [ name, key ] }.each do |(name, key), group|
      group.map(&:first).each_slice(CollectionImport::BATCH_SIZE) { |ids| account.locations.where(id: ids).update_all(name:, name_key: key, updated_at: now) }
    end
  end
  private_class_method :rename_zones!
end
