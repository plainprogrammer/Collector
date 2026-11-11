# Changes a deck's format (spec 064): the deck's zones become the new format's, the lots in a zone the new format lacks move
# into the deck's Considering zone, and the `decks` row takes the new collectible type and format, in one transaction, or
# nothing is written. The form's value is `<type>/<format key>`, the pair `Catalog::Formats` registers.
#
# The zones follow from the deck's own rows, not from its old format (decision 2): a row whose key the new format has is
# kept (same id, lots stay), one it lacks is dropped after its lots have moved (the lots' foreign key refuses to remove a zone
# that still holds one), and a zone the deck has no row for is added. Every kept zone takes its name from the registration, as
# an import's zone repair does (spec 062 AC-8.2a), so a release that renamed a zone can't make a new zone's name meet an old one
# in the unique index on (deck, name key). The order of the writes is what keeps that index safe: lots, then the dropped zones,
# then the renames, then the added zones. One case is not repaired: a deck with no Considering row that also holds a zone of
# another key named like it (no path of the app makes one); its insert is refused by the index, and the change rolls back with
# that error.
#
# Needs no `Current.account`: the deck carries it. The deck and its zones are read again inside the write transaction, so the
# "same format" check and the cap are judged on what holds when the write runs.
# @see file:collection-and-lots.md
class Deck::FormatChange
  include ActiveModel::Model

  # RecordInvalid looks its message up under the model's i18n scope, and ActiveModel's scope has no such entry.
  def self.i18n_scope = :activerecord

  attr_accessor :deck, :format
  # The copies {#save} moved into Considering.
  # @return [Integer]
  attr_reader :moved
  # The Considering zone's name as its row has it, for the notice; set when copies moved.
  # @return [String, nil]
  attr_reader :considering_name

  # Whether {#save} changed the deck.
  #
  # Meaningful after a {#save} that returned true (false when the deck already had the format, so nothing was written) and
  # after one that wrote nothing; a refused or failed change leaves it false, as it leaves the deck.
  #
  # @return [Boolean]
  def changed? = @changed

  # Makes the change.
  #
  # @return [Boolean] false, with "Choose a format." on `errors[:format]`, when the value isn't a registered pair; nothing is
  #   written then
  # @raise [Lot::CapExceeded] when a merge into Considering would hold more than 9,999 copies in one lot; nothing is written
  #   and the deck is read again
  def save
    errors.clear
    @moved = 0
    @changed = false
    option = Catalog::Formats.find_pair(format)
    unless option
      errors.add(:format, Deck::Creation::CHOOSE_A_FORMAT)
      return false
    end

    Deck.transaction { apply(option) }
    true
  rescue Lot::CapExceeded
    @changed = false # the transaction rolled back: the deck is as it was
    @moved = 0
    deck.reload
    raise
  end

  # (see #save)
  # @raise [ActiveRecord::RecordInvalid] when {#save} is false
  def save! = save || raise(ActiveRecord::RecordInvalid, self)

  private
    def apply(option)
      deck.reload
      return if deck.collectible_type == option.type && deck.format == option.format.key

      @changed = true
      location = deck.location
      wanted = option.format.zones
      zones = location.zones.order(:id).to_a
      dropped, kept = zones.partition { |zone| wanted.none? { it.key == zone.zone } }
      deck.update!(collectible_type: option.type, format: option.format.key)
      considering = kept.find { it.zone == Catalog::Formats::CONSIDERING } || add_considering!(location, wanted, kept)
      move_lots!(dropped, considering)
      remove_zones!(location, dropped)
      rewrite_names!(location, kept, wanted)
      add_zones!(location, kept, wanted)
      @considering_name = location.zones.find_by!(zone: Catalog::Formats::CONSIDERING).name if @moved.positive? # after the renames: the registered name
    end

    # A deck that has no Considering row (none made by the app lacks one; a repair is spec 062 AC-8.2a's) gets it before the
    # lots move, because they move into it.
    def add_considering!(location, wanted, kept)
      zone = wanted.find { it.key == Catalog::Formats::CONSIDERING }
      Location.insert_all!(Deck::Creation.zone_rows(location, [ zone ]))
      location.zones.find_by!(zone: zone.key).tap { kept << it }
    end

    # The lots of the dropped zones go into Considering through the bulk move: one lot of an identity per place, the cap checked
    # for every merge before anything is written (all or nothing), every key rebuilt with the place (`Lot.key_for`, so no sixth
    # builder). The bulk move raises for an empty selection, which is the ordinary case of an empty dropped zone, so it is
    # skipped then. The default order of the collection table names the first lot over the cap.
    def move_lots!(dropped, considering)
      lots = deck.account.lots.where(location_id: dropped.map(&:id))
      return unless lots.exists?

      sort = CollectionTable::Sort.parse(nil, nil)
      @moved = Lot::BulkMove.new(account: deck.account, lots:, to: considering, sort:).apply!.moved
    end

    # The dropped zones are empty here (their lots moved), and the lots' foreign key is RESTRICT, so a lot that slipped in fails
    # the whole change instead of being lost.
    def remove_zones!(location, dropped)
      return if dropped.empty?

      location.zones.where(id: dropped.map(&:id)).delete_all # Safe: scoped through the deck's location, bound ids; the foreign key refuses a zone that holds a lot
    end

    # Gives every kept zone the name and comparison key its key has in the registration, in two passes: first each zone to
    # rewrite is parked on a key no name can have (U+0001 and its id), then it takes its registered one, so two zones that
    # exchange names can't meet in the unique index in the middle of a statement.
    def rewrite_names!(location, kept, wanted)
      now = Time.current
      stale = kept.filter_map do |zone|
        name = Location::Name.normalise(wanted.find { it.key == zone.zone }.name)
        key = Location::Name.key(name)
        [ zone.id, name, key ] if zone.name != name || zone.name_key != key
      end
      return if stale.empty?

      location.zones.where(id: stale.map(&:first)).update_all("name_key = char(1) || id") # Safe: scoped through the deck's location, bound ids, no input in the SQL
      stale.each { |id, name, key| location.zones.where(id:).update_all(name:, name_key: key, updated_at: now) } # Safe: scoped, bound values
    end

    def add_zones!(location, kept, wanted)
      have = kept.map(&:zone)
      rows = Deck::Creation.zone_rows(location, wanted.reject { have.include?(it.key) })
      Location.insert_all!(rows) if rows.any? # skips the model's validations on purpose, as Deck::Creation does
    end
end
