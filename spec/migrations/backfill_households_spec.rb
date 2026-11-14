require "rails_helper"
require Rails.root.join("db/migrate/20261113120002_backfill_households")

# Spec 090 decision 5 (b), AC-3.1 to AC-3.3, AC-3.8, AC-1.5: a household of one for every user that has none, in batches, idempotent,
# touching accounts' household_id only. The users are made with the models and their household rows then removed by SQL, which is the
# state a database from the previous release is in once (a) has run.
RSpec.describe BackfillHouseholds, :backup, :committed, type: :model do
  let(:connection) { ActiveRecord::Base.connection }

  # Migration (c), which makes accounts.household_id NOT NULL, comes after this one: the examples that put a household-less account
  # in the database take (c) down first (forget_households) and the around puts it back.
  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    context.run(:up, 2026_11_13_120003) if household_nullable?
    Account.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def context = ActiveRecord::Base.connection_pool.migration_context

  def household_nullable? = connection.columns(:accounts).find { it.name == "household_id" }.null

  def run_up = described_class.new.migrate(:up)

  # An account in a household of its own, by SQL, as the NOT NULL column needs; answers the account's id.
  def insert_account(now = "2026-11-13 12:00:00")
    household = connection.insert("INSERT INTO households (name, created_at, updated_at) VALUES ('h', '#{now}', '#{now}')")
    connection.insert("INSERT INTO accounts (created_at, updated_at, household_id) VALUES ('#{now}', '#{now}', #{household})")
  end

  def count(table) = connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  # Takes every household away, as the previous release leaves users and accounts: (c) goes down first, because it forbids an account
  # with no household.
  def forget_households
    context.run(:down, 2026_11_13_120003) unless household_nullable?
    connection.execute("DELETE FROM memberships")
    connection.execute("UPDATE accounts SET household_id = NULL")
    connection.execute("DELETE FROM households")
  end

  def pairs = connection.select_rows("SELECT users.id, households.name, memberships.role, accounts.kind FROM users JOIN memberships ON memberships.user_id = users.id JOIN households ON households.id = memberships.household_id JOIN accounts ON accounts.id = users.account_id AND accounts.household_id = households.id ORDER BY users.id")

  it "turns the migration's transaction off, so each batch is its own short write" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "gives every user a household named for them, a manager membership and an account in it, and changes no other column (AC-3.1)", :aggregate_failures do
    users = Array.new(3) { |i| create(:user, name: "Collector #{i}") }
    lot = create(:lot, account: users.first.account)
    accounts = connection.select_rows("SELECT id, created_at, updated_at, currency, kind FROM accounts ORDER BY id")
    forget_households

    run_up

    expect(pairs).to eq(users.map { [ it.id, "#{it.name}'s household", "manager", "personal" ] })
    expect(connection.select_rows("SELECT id, created_at, updated_at, currency, kind FROM accounts ORDER BY id")).to eq(accounts)
    expect(count("lots")).to eq(1)
    expect(Lot.find(lot.id).account_id).to eq(users.first.account_id)
  end

  it "builds the name the model builds, for 100 characters, an apostrophe and multi-byte characters (AC-1.5)", :aggregate_failures do
    names = [ "n" * 100, "O'Neil", "é" * 100, "A" ]
    users = names.each_with_index.map { |name, i| create(:user, name:, email_address: "u#{i}@example.test") }
    forget_households

    run_up

    expect(connection.select_values("SELECT households.name FROM users JOIN memberships ON memberships.user_id = users.id JOIN households ON households.id = memberships.household_id ORDER BY users.id"))
      .to eq(users.map { Household.name_for(it.name) })
  end

  it "adds nothing the second time and makes only the rest after a stop (AC-3.2)", :aggregate_failures do
    first, second = Array.new(2) { create(:user) }
    forget_households
    # the state of a run that stopped after its first batch: the first user's household exists
    household = connection.insert("INSERT INTO households (name, created_at, updated_at) VALUES ('kept', datetime('now'), datetime('now'))")
    connection.execute("INSERT INTO memberships (household_id, user_id, role, created_at, updated_at) VALUES (#{household}, #{first.id}, 'manager', datetime('now'), datetime('now'))")
    connection.execute("UPDATE accounts SET household_id = #{household} WHERE id = #{first.account_id}")

    run_up
    after = [ count("households"), count("memberships"), pairs ]
    run_up

    expect([ count("households"), count("memberships"), pairs ]).to eq(after)
    expect(connection.select_value("SELECT name FROM households WHERE id = #{household}")).to eq("kept")
    expect(connection.select_value("SELECT COUNT(*) FROM memberships WHERE user_id = #{second.id}")).to eq(1)
  end

  it "works in batches of at most 500, each its own transaction (AC-3.3)", :aggregate_failures do
    expect(described_class::BATCH).to eq(500)
    now = "2026-11-13 12:00:00"
    stub_const("BackfillHouseholds::BATCH", 2) # 5 users make 3 batches
    5.times { |i| connection.execute("INSERT INTO users (account_id, name, email_address, password_digest, created_at, updated_at) VALUES (#{insert_account(now)}, 'U#{i}', 'u#{i}@example.test', 'x', '#{now}', '#{now}')") }
    forget_households
    begins = 0
    counter = ->(*, payload) { begins += 1 if payload[:sql].match?(/\ABEGIN/i) }

    # The class by its name, not described_class: the Migrator reloads a migration's file (`load`), which makes a new class under the same name once any
    # example has taken (c) down, and the constant stubbed above belongs to the new one.
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.name.constantize.new.migrate(:up) }

    expect(count("households")).to eq(5)
    expect(begins).to eq(3) # one transaction for each of the three batches; the empty read that ends the loop opens none
  end

  it "makes 10,000 households in 20 batches, and says how long it took (the NFR)", :timing do
    context.run(:down, 2026_11_13_120003) # (c) forbids the household-less accounts of the previous release's database
    connection.execute("WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 10000) INSERT INTO accounts (created_at, updated_at) SELECT datetime('now'), datetime('now') FROM n")
    connection.execute("INSERT INTO users (account_id, name, email_address, password_digest, created_at, updated_at) SELECT id, 'U' || id, 'u' || id || '@example.test', 'x', datetime('now'), datetime('now') FROM accounts")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    run_up
    seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    RSpec.configuration.reporter.message "backfill of 10,000 users: #{seconds.round(2)} s"
    expect(count("households")).to eq(10_000)
  end

  it "succeeds on a database with no user (AC-3.4)" do
    expect { run_up }.not_to raise_error
  end

  it "leaves every session row as it was (AC-3.8)", :aggregate_failures do
    user = create(:user)
    session = user.sessions.create!
    forget_households
    rows = connection.select_rows("SELECT * FROM sessions ORDER BY id")

    run_up

    expect(connection.select_rows("SELECT * FROM sessions ORDER BY id")).to eq(rows)
    expect(session.reload).to be_present
  end
end
