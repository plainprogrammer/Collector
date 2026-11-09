# A session no longer keeps the client's address and user agent, which nothing read (spec 049 decision 5; #218 2), and its
# stamp becomes NOT NULL. Without a transaction, as AddLastUsedAtToSessions explains. The UPDATE first is a safety net, not
# the backfill (that is the migration before this): it stamps a row a database that skipped the backfill still holds, so the
# NOT NULL can't fail. Going down puts the two columns back empty (the values are not kept) and lets the stamp be NULL again.
class DropSessionClientColumns < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute "UPDATE sessions SET last_used_at = #{connection.quote(Time.current.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))} WHERE last_used_at IS NULL"
    remove_columns :sessions, *%i[ip_address user_agent].select { column_exists?(:sessions, it) } # one table copy for both
    change_column_null :sessions, :last_used_at, false if columns(:sessions).find { it.name == "last_used_at" }&.null
  end

  def down
    add_column :sessions, :ip_address, :string unless column_exists?(:sessions, :ip_address)
    add_column :sessions, :user_agent, :string unless column_exists?(:sessions, :user_agent)
    change_column_null :sessions, :last_used_at, true unless columns(:sessions).find { it.name == "last_used_at" }&.null
  end
end
