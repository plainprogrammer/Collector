# The time a session was last used, recorded at most once a day (spec 049 decision 2). Nullable here: SQLite can't add a
# NOT NULL column with no default, and the backfill that follows sets every existing row; the third migration makes it NOT NULL.
# Without a transaction: removing a column copies the table, and with foreign keys enforced the copy's DROP TABLE would run
# the ON DELETE CASCADE of bulk_selections and bulk_removals (see AddCurrencyToAccounts, AddLocationToLots).
class AddLastUsedAtToSessions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :sessions, :last_used_at, :datetime unless column_exists?(:sessions, :last_used_at)
  end

  def down
    remove_column :sessions, :last_used_at if column_exists?(:sessions, :last_used_at)
  end
end
