# A household and its members, and the two columns that put an account in one (spec 090 decisions 1 and 5 (a), ADR 0030).
# Without a transaction, as AddDecks explains: dropping the two columns on the way down copies accounts, and with foreign keys
# enforced inside a transaction the copy's DROP TABLE would run the delete rules of the thirteen tables that reference it. Every
# step is guarded, so a run that stopped part way is finished by the next boot. Going down refuses while a household has two
# members or a shared account exists (an older release can't hold either), keeps accounts' id sequence across each copy, and
# stops and rolls back, as the third migration does, when enforcement is on or a copy changed a row count.
class CreateHouseholdsAndMemberships < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    create_table :households, if_not_exists: true do |t|
      t.string :name, null: false
      t.timestamps
      t.check_constraint "length(name) BETWEEN 1 AND 100", name: "households_name_length"
    end
    create_table :memberships, if_not_exists: true do |t|
      t.references :household, null: false, foreign_key: true
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :role, null: false
      t.timestamps
      t.check_constraint "role IN ('manager', 'member')", name: "memberships_role_known"
    end
    # ADD COLUMN copies no table: REFERENCES is accepted because the default is NULL, and a named CHECK on the column is
    # tested against every row and kept by the schema dump (the precedent is AddDecks).
    unless column_exists?(:accounts, :household_id)
      connection.execute "ALTER TABLE accounts ADD COLUMN household_id integer REFERENCES households (id)"
    end
    add_index :accounts, :household_id unless index_exists?(:accounts, :household_id)
    unless column_exists?(:accounts, :kind)
      connection.execute "ALTER TABLE accounts ADD COLUMN kind varchar NOT NULL DEFAULT 'personal' " \
              "CONSTRAINT accounts_kind_known CHECK (kind IN ('personal', 'shared'))"
    end
  end

  def down
    refuse_what_the_older_release_cannot_hold
    connection.disable_referential_integrity do
      connection.transaction do
        require_enforcement_off
        before = state
        keeping_sequence do
          remove_check_constraint :accounts, name: "accounts_kind_known" if check_constraint_exists?(:accounts, name: "accounts_kind_known")
          remove_column :accounts, :kind if column_exists?(:accounts, :kind)
        end
        keeping_sequence do
          remove_index :accounts, :household_id if index_exists?(:accounts, :household_id)
          remove_column :accounts, :household_id if column_exists?(:accounts, :household_id)
        end
        require_nothing_lost(before)
      end
    end
    drop_table :memberships, if_exists: true
    drop_table :households, if_exists: true
  end

  private
    # The same two guards as MakeAccountHouseholdRequired (migrations don't share code: a released one is never edited). Its
    # comments say why: the copy of accounts cascades silently when foreign keys are enforced, and Rails runs no check after it.
    def require_enforcement_off
      return if connection.select_value("PRAGMA foreign_keys").to_i.zero?

      raise ActiveRecord::MigrationError, "foreign keys are enforced inside the table copy, which would delete the collections that reference accounts; nothing was changed"
    end

    # Safe: literal table names. The thirteen tables that reference accounts; accounts itself is counted with them.
    REFERENCING = %w[bulk_removals bulk_selection_marks bulk_selections deck_proxies decks import_uploads locations lots number_entries number_entry_lines scanner_sitting_entries scanner_sittings users].freeze

    def state
      rows = ([ "accounts" ] + REFERENCING).to_h { [ it, connection.select_value("SELECT COUNT(*) FROM #{it}").to_i ] }
      broken = connection.select_rows("PRAGMA foreign_key_check").select { |_table, _row, parent, *| parent == "accounts" }
      { rows:, broken: }
    end

    def require_nothing_lost(before)
      after = state
      lost = after[:rows].reject { |table, count| count == before[:rows][table] }
      new_broken = after[:broken] - before[:broken]
      return if lost.empty? && new_broken.empty?

      raise ActiveRecord::MigrationError, "the table copy changed row counts #{lost.inspect} or broke keys #{new_broken.first(3).inspect}; nothing was changed"
    end

    def refuse_what_the_older_release_cannot_hold
      shared_households = table_exists?(:memberships) ? connection.select_value("SELECT COUNT(*) FROM (SELECT 1 FROM memberships GROUP BY household_id HAVING COUNT(*) > 1)").to_i : 0
      shared_accounts = column_exists?(:accounts, :kind) ? connection.select_value("SELECT COUNT(*) FROM accounts WHERE kind = 'shared'").to_i : 0
      return if shared_households.zero? && shared_accounts.zero?

      raise ActiveRecord::IrreversibleMigration,
        "#{shared_households} #{"household".pluralize(shared_households)} with more than one member and " \
        "#{shared_accounts} shared #{"account".pluralize(shared_accounts)} exist; remove them before rolling back"
    end

    # A table copy drops and recreates accounts, which resets its row of sqlite_sequence to the highest id present, so the id of a
    # deleted account could be issued again. The sequence is read before and restored after, never lowered, and the row is made
    # when the copy left none (an empty table has none). The table is always `main.sqlite_sequence`: the copy builds a TEMP table
    # with AUTOINCREMENT, which gives the connection a `temp.sqlite_sequence` that a bare name then resolves to.
    def keeping_sequence
      seq = connection.select_value("SELECT seq FROM main.sqlite_sequence WHERE name = 'accounts'")
      yield
      return unless seq

      connection.execute "UPDATE main.sqlite_sequence SET seq = #{seq.to_i} WHERE name = 'accounts' AND seq < #{seq.to_i}"
      connection.execute "INSERT INTO main.sqlite_sequence (name, seq) SELECT 'accounts', #{seq.to_i} WHERE NOT EXISTS (SELECT 1 FROM main.sqlite_sequence WHERE name = 'accounts')"
    end
end
