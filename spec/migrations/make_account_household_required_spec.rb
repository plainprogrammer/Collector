require "rails_helper"
require Rails.root.join("db/migrate/20261113120003_make_account_household_required")

# Spec 090 decision 5 (c), AC-3.4 to AC-3.7: the copy of accounts must lose no row of the thirteen tables that reference it, keep their
# keys, keep the id sequence, give a straggler a household, and change nothing when it fails. It commits its rows and runs through the
# Migrator OUTSIDE any example transaction (inside one, enforcement stays on and the cascades would fire).
RSpec.describe MakeAccountHouseholdRequired, :backup, :committed, type: :model do
  include ReferencingTableHelpers

  let(:connection) { ActiveRecord::Base.connection }
  let(:tables) { %w[bulk_removals bulk_selection_marks bulk_selections deck_proxies decks import_uploads locations lots number_entries number_entry_lines scanner_sitting_entries scanner_sittings users] }

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down = context.run(:down, 2026_11_13_120003)

  def up = context.run(:up, 2026_11_13_120003)

  def nullable? = connection.columns(:accounts).find { it.name == "household_id" }.null

  def count(table) = connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  def counts = (tables + %w[accounts households memberships sessions]).to_h { [ it, count(it) ] }

  def sequence = connection.select_value("SELECT seq FROM main.sqlite_sequence WHERE name = 'accounts'")

  def shapes = (%w[accounts] + tables).to_h { [ it, shape(it) ] }

  def shape(table)
    [ connection.columns(table).map { [ it.name, it.sql_type, it.null, it.default ] },
      connection.foreign_keys(table).map { [ it.to_table, it.column, it.on_delete ] }.sort_by(&:to_s),
      connection.indexes(table).map { [ it.name, it.columns, it.unique, it.where ] }.sort_by(&:to_s),
      connection.check_constraints(table).map { [ it.name, it.expression ] }.sort_by(&:to_s) ]
  end

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up if nullable?
    Account.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  it "turns the migration's transaction off, so the copy runs with foreign keys off, and opens its own" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "makes the column NOT NULL and keeps every row of the thirteen tables, going down and up (AC-3.6)", :aggregate_failures do
    fill_every_referencing_table(create(:user))
    before = counts
    expect(before.values_at(*tables)).to all(be >= 1)

    down
    expect(nullable?).to be(true)
    expect(counts).to eq(before)
    up

    expect(nullable?).to be(false)
    expect(counts).to eq(before)
    expect(connection.select_rows("PRAGMA foreign_key_check")).to be_empty
    expect(connection.select_values("PRAGMA integrity_check")).to eq([ "ok" ])
  end

  it "keeps the foreign keys, checks and indexes of accounts and the thirteen tables, going down and up (AC-3.6)" do
    before = shapes
    down
    up
    expect(shapes).to eq(before)
  end

  it "keeps the id sequence of accounts, so a deleted account's id is not issued again (AC-3.6)", :aggregate_failures do
    create(:user)
    gone = create(:user)
    connection.execute("DELETE FROM memberships WHERE user_id = #{gone.id}")
    gone_account = gone.account_id
    connection.execute("DELETE FROM users WHERE id = #{gone.id}")
    connection.execute("DELETE FROM accounts WHERE id = #{gone_account}")
    seq = sequence
    expect(seq).to be >= gone_account

    down
    expect(sequence).to eq(seq)
    up
    expect(sequence).to eq(seq)
    expect(connection.insert("INSERT INTO accounts (created_at, updated_at, household_id) VALUES (datetime('now'), datetime('now'), #{create(:household).id})")).to be > seq
  end

  it "gives a user made between (b) and (c) a household, removes an emptied household, and succeeds (AC-3.7)", :aggregate_failures do
    straggler = create(:user, name: "Late")
    down
    connection.execute("DELETE FROM memberships WHERE user_id = #{straggler.id}")
    connection.execute("UPDATE accounts SET household_id = NULL WHERE id = #{straggler.account_id}")
    emptied = connection.insert("INSERT INTO households (name, created_at, updated_at) VALUES ('Left behind', datetime('now'), datetime('now'))")

    up

    expect(connection.select_value("SELECT households.name FROM users JOIN memberships ON memberships.user_id = users.id JOIN households ON households.id = memberships.household_id WHERE users.id = #{straggler.id}")).to eq("Late's household")
    expect(connection.select_value("SELECT COUNT(*) FROM households WHERE id = #{emptied}")).to eq(0)

    settled = counts.merge("sequence" => sequence)
    described_class.new.migrate(:up) # the Migrator skips a recorded version, so the migration itself is run again
    expect(counts.merge("sequence" => sequence)).to eq(settled)
  end

  it "stops and rolls back when a count of accounts or of any of the thirteen referencing tables differs after the copy (AC-3.6)", :aggregate_failures do
    create(:user)
    migration = described_class.new
    before = migration.send(:state) # the check's own example: each table's count, changed in turn, is a loss it must name
    ([ "accounts" ] + described_class::REFERENCING).each do |table|
      lost = before.merge(rows: before[:rows].merge(table => before[:rows][table] + 1))
      expect { migration.send(:require_nothing_lost, lost) }.to raise_error(ActiveRecord::MigrationError, /#{table}/), "a changed count of #{table} was not caught"
    end
    expect { migration.send(:require_nothing_lost, before) }.not_to raise_error
  end

  it "refuses to run when foreign keys are enforced, and changes nothing (AC-3.6)", :aggregate_failures do
    create(:user)
    down
    before = counts

    connection.transaction { expect { described_class.new.migrate(:up) }.to raise_error(ActiveRecord::MigrationError, /enforced/) }

    expect([ nullable?, counts ]).to eq([ true, before ])
  end

  it "is not stopped by a dangling row the database already held, and keeps it (AC-3.6)", :aggregate_failures do
    create(:user)
    down
    connection.disable_referential_integrity do # as an operator's sqlite3 session does
      connection.execute("INSERT INTO locations (account_id, name, name_key, created_at, updated_at) VALUES (999999, 'Dangling', 'dangling', datetime('now'), datetime('now'))")
    end

    expect { up }.not_to raise_error
    expect(connection.select_value("SELECT COUNT(*) FROM locations WHERE account_id = 999999")).to eq(1)
  end

  it "undoes a failure of the copy itself, after the old table was dropped: nothing is lost (AC-3.6)", :aggregate_failures do
    create(:user)
    down
    orphan = connection.insert("INSERT INTO accounts (created_at, updated_at) VALUES (datetime('now'), datetime('now'))")
    before = counts.merge("sequence" => sequence)
    # Fault injection: the refusal that would stop the run before any DDL is switched off, so the copy-back's NOT NULL fails.
    migration = Class.new(described_class) { private def refuse_accounts_nobody_can_house = nil }.new

    expect { migration.migrate(:up) }.to raise_error(ActiveRecord::StatementInvalid, /NOT NULL/)

    expect([ nullable?, connection.select_value("PRAGMA foreign_keys") ]).to eq([ true, 1 ])
    expect(counts.merge("sequence" => sequence)).to eq(before)
    expect(connection.select_value("SELECT COUNT(*) FROM accounts WHERE id = #{orphan}")).to eq(1)
    connection.execute("DELETE FROM accounts WHERE id = #{orphan}")
    expect { up }.not_to raise_error
  end

  it "changes nothing when it refuses, and succeeds on the next run (AC-3.6, the Error Scenarios row)", :aggregate_failures do
    create(:user)
    straggler = create(:user, name: "Late")
    down
    connection.execute("DELETE FROM memberships WHERE user_id = #{straggler.id}")
    connection.execute("UPDATE accounts SET household_id = NULL WHERE id = #{straggler.account_id}")
    orphan = connection.insert("INSERT INTO accounts (created_at, updated_at) VALUES (datetime('now'), datetime('now'))") # no user: no step can house it
    before = counts.merge("sequence" => sequence)

    expect { up }.to raise_error(StandardError, /accounts? .*#{orphan}.* no user/m)

    expect(nullable?).to be(true)
    expect(connection.select_value("PRAGMA foreign_keys")).to eq(1)
    expect(counts.merge("sequence" => sequence)).to eq(before)
    expect(connection.select_value("SELECT COUNT(*) FROM memberships WHERE user_id = #{straggler.id}")).to eq(0) # the stragglers step was rolled back
    connection.execute("DELETE FROM accounts WHERE id = #{orphan}")
    expect { up }.not_to raise_error
    expect(nullable?).to be(false)
  end
end
