# Every session that exists now has been used as of this upgrade, so none expires at once (spec 049 decision 11): the only
# older record is the creation time, which says nothing about use. Idempotent (a row already stamped is left), in batches of
# 1,000, and plain SQL (no application model, .claude/rules/sqlite-and-migrations.md). Nothing to undo going down.
class BackfillSessionsLastUsedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  BATCH = 1_000

  def up
    now = connection.quote(Time.current.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))
    loop do
      ids = select_values("SELECT id FROM sessions WHERE last_used_at IS NULL ORDER BY id LIMIT #{BATCH}") # Safe: a constant
      break if ids.empty?

      execute "UPDATE sessions SET last_used_at = #{now} WHERE id IN (#{ids.join(", ")})" # Safe: integer ids from the query above
    end
  end

  def down; end
end
