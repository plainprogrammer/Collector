# Writes what an apply decided about the collector's locations (spec 029 decision 11), inside the apply's one write
# transaction and in at most two statements whatever their number: the removed ones are deleted first, so that an added
# key never meets a removed one, then one upsert on [account_id, name_key] inserts the added ones and respells the renamed
# ones, whose ids stay. An unchanged location isn't written, not even its updated_at. The names were validated by the
# reader, so the bulk statements skip Location's validations on purpose, as the lots' do (spec 028 FR-3); a spec checks the
# rows against Location. Collectible-agnostic.
module CollectionImport::LocationChanges
  def self.write!(account, locations)
    return if locations.nothing_to_change?

    locations.removed.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| account.locations.where(id: ids).delete_all }
    now = Time.current
    rows = (locations.added + locations.renamed.map(&:name)).map do |name|
      { account_id: account.id, name:, name_key: Location::Name.key(name), created_at: now, updated_at: now }
    end
    rows.each_slice(CollectionImport::BATCH_SIZE) do |slice|
      Location.upsert_all(slice, unique_by: %i[account_id name_key], update_only: %i[name updated_at], record_timestamps: false, returning: false)
    end
  end
end
