# Makes accounts.household_id NOT NULL, so "every account has a household" is a fact of the database (spec 090 decision 5 (c)).
# SQLite can't add NOT NULL in place; Rails copies accounts (create the new table, copy the rows, drop the old, rename). accounts is
# referenced by thirteen tables, eleven of them ON DELETE CASCADE (lots and users are NO ACTION), so a copy run with foreign keys
# enforced deletes every collector's decks, places, proxies and working state, silently. Rails turns enforcement off for a copy only
# outside a transaction, so the migration runs without Rails' own (`disable_ddl_transaction!`) and opens one itself with enforcement
# already off: the stragglers step, the copy and the sequence's restore commit together or not at all, so a failed run changes nothing
# and the next boot runs it whole. The stragglers step is spec 049's safety-net UPDATE: BackfillHouseholds is recorded once it has
# run, but a user can be made after it (an older container serving during a deploy), and without this the NOT NULL would fail on
# every boot after. It also removes a household an older container's delete of a user left with no member and no account. An
# account with no user and no household can't be housed by any step: the migration says so and changes nothing.
# @see file:tenancy-and-accounts.md
class MakeAccountHouseholdRequired < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH = 500

  def up
    return unless household_nullable?

    connection.disable_referential_integrity do
      connection.transaction do
        require_enforcement_off
        house_stragglers
        remove_empty_households
        refuse_accounts_nobody_can_house
        before = state
        keeping_sequence { change_column_null :accounts, :household_id, false }
        require_nothing_lost(before)
      end
    end
  end

  def down
    return if household_nullable?

    connection.disable_referential_integrity do
      connection.transaction do
        require_enforcement_off
        before = state
        keeping_sequence { change_column_null :accounts, :household_id, true }
        require_nothing_lost(before)
      end
    end
  end

  private
    def household_nullable? = connection.columns(:accounts).find { it.name == "household_id" }&.null

    # The same SQL as BackfillHouseholds (migrations don't share code: a released one is never edited).
    def house_stragglers
      now = connection.quote(Time.current.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))
      loop do
        users = connection.select_rows("SELECT id, account_id FROM users WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.user_id = users.id) ORDER BY id LIMIT #{BATCH.to_i}")
        break if users.empty?

        users.each do |user_id, account_id|
          household = connection.insert("INSERT INTO households (name, created_at, updated_at) SELECT substr(name, 1, 88) || '''s household', #{now}, #{now} FROM users WHERE id = #{user_id.to_i}")
          raise ActiveRecord::MigrationError, "no household was made for user #{user_id}" unless connection.select_value("SELECT changes()").to_i == 1
          connection.execute "INSERT INTO memberships (household_id, user_id, role, created_at, updated_at) VALUES (#{household.to_i}, #{user_id.to_i}, 'manager', #{now}, #{now})"
          connection.execute "UPDATE accounts SET household_id = #{household.to_i} WHERE id = #{account_id.to_i}"
        end
      end
    end

    # Rails runs no check after a copy and, inside a transaction, enforcement can't be switched off: if either went wrong the copy would
    # have cascaded silently, so a run that finds enforcement on stops and rolls back, and so does one after which a table that
    # references accounts holds fewer rows, or a key points at a missing account or household that did not before (a database an
    # operator edited with enforcement off may hold dangling rows already; they are not this run's).
    def require_enforcement_off
      return if connection.select_value("PRAGMA foreign_keys").to_i.zero?

      raise ActiveRecord::MigrationError, "foreign keys are enforced inside the table copy, which would delete the collections that reference accounts; nothing was changed"
    end

    # Safe: literal table names. The thirteen tables that reference accounts; accounts itself is counted with them.
    REFERENCING = %w[bulk_removals bulk_selection_marks bulk_selections deck_proxies decks import_uploads locations lots number_entries number_entry_lines scanner_sitting_entries scanner_sittings users].freeze

    def state
      rows = ([ "accounts" ] + REFERENCING).to_h { [ it, connection.select_value("SELECT COUNT(*) FROM #{it}").to_i ] }
      broken = connection.select_rows("PRAGMA foreign_key_check").select { |_table, _row, parent, *| %w[accounts households].include?(parent) }
      { rows:, broken: }
    end

    def require_nothing_lost(before)
      after = state
      lost = after[:rows].reject { |table, count| count == before[:rows][table] }
      new_broken = after[:broken] - before[:broken]
      return if lost.empty? && new_broken.empty?

      raise ActiveRecord::MigrationError, "the table copy changed row counts #{lost.inspect} or broke keys #{new_broken.first(3).inspect}; nothing was changed"
    end

    def remove_empty_households
      connection.execute "DELETE FROM households WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.household_id = households.id) AND NOT EXISTS (SELECT 1 FROM accounts WHERE accounts.household_id = households.id)"
    end

    def refuse_accounts_nobody_can_house
      # an account whose user has a membership but which was left with no household (a database edited by hand) is put in it
      connection.execute "UPDATE accounts SET household_id = (SELECT memberships.household_id FROM users JOIN memberships ON memberships.user_id = users.id WHERE users.account_id = accounts.id) WHERE household_id IS NULL"
      orphans = connection.select_values("SELECT id FROM accounts WHERE household_id IS NULL AND NOT EXISTS (SELECT 1 FROM users WHERE users.account_id = accounts.id)")
      return if orphans.empty?

      raise ActiveRecord::MigrationError, "accounts #{orphans.first(5).join(", ")} have no household and no user, so no household can be made for them; " \
        "remove them with `bin/rails runner 'Account.find(ID).destroy'` (which deletes what they own; a bare DELETE with the sqlite3 command leaves rows behind, because it does not enforce keys) and start again; nothing was changed"
    end

    # As CreateHouseholdsAndMemberships: the copy resets accounts' row of sqlite_sequence, which the proof can't see (compare.rb skips sqlite_ tables).
    # Always `main.sqlite_sequence`: the copy builds a TEMP table with AUTOINCREMENT, so a bare name resolves to `temp.sqlite_sequence`.
    def keeping_sequence
      seq = connection.select_value("SELECT seq FROM main.sqlite_sequence WHERE name = 'accounts'")
      yield
      return unless seq

      connection.execute "UPDATE main.sqlite_sequence SET seq = #{seq.to_i} WHERE name = 'accounts' AND seq < #{seq.to_i}"
      connection.execute "INSERT INTO main.sqlite_sequence (name, seq) SELECT 'accounts', #{seq.to_i} WHERE NOT EXISTS (SELECT 1 FROM main.sqlite_sequence WHERE name = 'accounts')"
    end
end
