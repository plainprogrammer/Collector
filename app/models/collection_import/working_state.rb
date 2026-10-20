# Ends the per-account lists that point at lots, which a replaced collection makes wrong (spec 028 decision 7): bulk
# removals can no longer be undone, bulk selections go, and the number-entry list and scanner sitting are done.
module CollectionImport::WorkingState
  def self.clear!(account)
    account.number_entry&.destroy!
    account.scanner_sitting&.destroy!
    account.bulk_selections.destroy_all
    account.bulk_removals.undoable.find_each { |removal| removal.update!(lots_data: nil) }
  end
end
