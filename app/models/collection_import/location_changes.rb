# Writes what an apply decided about the collector's places (spec 029 decision 11), inside the apply's one write transaction,
# in two halves that `CollectionImport::DeckChanges` runs in order around its own: `remove!` deletes the removed ones, then
# `add!` upserts the added ones and respells the renamed ones, whose ids stay, on [account_id, name_key]. The halves are
# apart because a place and a deck share one name space (spec 062 AC-8.3): every removal of either kind must precede every
# addition of either, or an added key could meet a removed one still in the unique index. Each half is one statement per
# BATCH_SIZE rows, whatever their number. An unchanged place isn't written, not even its updated_at. The names were
# validated by the reader, so the bulk statements skip Location's validations on purpose, as the lots' do (spec 028 FR-3); a
# spec checks the rows against Location. Collectible-agnostic.
module CollectionImport::LocationChanges
  # Deletes the places the file lacks. Their lots are already deleted (a lot's foreign key is RESTRICT), and a scanner
  # sitting that points at one is cleared by its own foreign key.
  #
  # @param account [Account]
  # @param locations [CollectionImport::Locations] what the plan does with the places; nothing is written when there is nothing to change
  # @return [void]
  def self.remove!(account, locations)
    locations.removed.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| account.locations.where(id: ids).delete_all }
  end

  # Inserts the places the file adds and respells the ones it renames (see {.upsert_top_level!}).
  #
  # @param account [Account]
  # @param locations [CollectionImport::Locations]
  # @return [void]
  def self.add!(account, locations)
    upsert_top_level!(account, locations.added + locations.renamed.map(&:name), "place")
  end

  # Inserts a top-level location of +kind+ for each name, or respells the one that has the name's comparison key: one
  # statement per BATCH_SIZE. The conflict target is the name index of top-level locations, which is partial, so the
  # statement must carry the index's condition, `WHERE parent_id IS NULL`; Rails emits it when the index is named (a spec
  # reads the SQL). The reader guarantees that a key held by another kind has been removed already (a file's places and decks
  # never share a key), so the update only ever meets a row of its own kind.
  #
  # @param account [Account]
  # @param names [Array<String>] names as stored (`Location::Name.normalise`)
  # @param kind [String] "place" or "deck"
  # @return [void]
  def self.upsert_top_level!(account, names, kind)
    now = Time.current
    rows = names.map { |name| { account_id: account.id, kind:, name:, name_key: Location::Name.key(name), created_at: now, updated_at: now } }
    rows.each_slice(CollectionImport::BATCH_SIZE) do |slice|
      Location.upsert_all(slice, unique_by: :index_locations_on_account_id_and_name_key_top_level, update_only: %i[name updated_at],
        record_timestamps: false, returning: false)
    end
  end
end
