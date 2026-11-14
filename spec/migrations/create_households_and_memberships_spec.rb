require "rails_helper"
require Rails.root.join("db/migrate/20261113120001_create_households_and_memberships")
require Rails.root.join("db/migrate/20261113120002_backfill_households")
require Rails.root.join("db/migrate/20261113120003_make_account_household_required")

# Spec 090 decision 1, decision 5 (a): the tables, the two columns of accounts, their keys and checks. The migration runs outside a
# transaction (disable_ddl_transaction!), so the examples commit their rows (:committed empties the database around them) and go
# down and up through the Migrator, as db:rollback does (the precedent is spec/migrations/add_decks_spec.rb). Rows are made with
# SQL, so the examples don't depend on the models.
RSpec.describe CreateHouseholdsAndMemberships, :backup, :committed, type: :model do
  let(:connection) { ActiveRecord::Base.connection }
  let(:stamp) { "2026-11-13 12:00:00" }

  # Every version of the households migrations that exists, in order.
  def versions = [ 2026_11_13_120001, 2026_11_13_120002, 2026_11_13_120003 ]

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down_all = versions.reverse_each { |version| context.run(:down, version) }

  def up_all = versions.each { |version| context.run(:up, version) }

  def count(table) = connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  def sequence = connection.select_value("SELECT seq FROM main.sqlite_sequence WHERE name = 'accounts'")

  # What PRAGMA says about a table: columns, foreign keys, indexes, checks (not the table's SQL text).
  def shape(table)
    [ connection.columns(table).map { [ it.name, it.sql_type, it.null, it.default ] }.sort_by(&:first), # by name: a copy moves a column
      connection.foreign_keys(table).map { [ it.to_table, it.column, it.on_delete ] }.sort_by(&:to_s),
      connection.indexes(table).map { [ it.name, it.columns, it.unique, it.where ] }.sort_by(&:to_s),
      connection.check_constraints(table).map { [ it.name, it.expression ] }.sort_by(&:to_s) ]
  end

  def insert(sql, *binds) = connection.insert(ActiveRecord::Base.sanitize_sql_array([ sql, *binds ]))

  def insert_household(name = "Ann's household") = insert("INSERT INTO households (name, created_at, updated_at) VALUES (?, ?, ?)", name, stamp, stamp)

  def insert_membership(household, user, role) = insert("INSERT INTO memberships (household_id, user_id, role, created_at, updated_at) VALUES (?, ?, ?, ?, ?)", household, user, role, stamp, stamp)

  # A user with an account in a household of its own; answers [user id, account id, household id].
  def insert_user(number = 1)
    household = insert_household("User #{number}'s household")
    account = insert("INSERT INTO accounts (created_at, updated_at, household_id) VALUES (?, ?, ?)", stamp, stamp, household)
    user = insert("INSERT INTO users (account_id, name, email_address, password_digest, created_at, updated_at) VALUES (?, ?, ?, 'x', ?, ?)", account, "User #{number}", "u#{number}@example.test", stamp, stamp)
    [ user, account, household ]
  end

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up_all # the Migrator skips a version that is recorded
    Account.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  it "turns the migration's transaction off, so its table copy runs with foreign keys off" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "creates the two tables with their keys, indexes and checks", :aggregate_failures do
    expect(connection.columns(:households).map(&:name)).to eq(%w[id name created_at updated_at])
    expect(connection.columns(:memberships).map(&:name)).to eq(%w[id household_id user_id role created_at updated_at])
    expect(connection.check_constraints(:households).map(&:name)).to eq([ "households_name_length" ])
    expect(connection.check_constraints(:memberships).map(&:name)).to eq([ "memberships_role_known" ])
    expect(connection.foreign_keys(:memberships).to_h { [ it.to_table, it.on_delete ] }).to eq("households" => nil, "users" => :cascade)
    expect(connection.indexes(:memberships).map { [ it.columns, it.unique ] }).to contain_exactly([ %w[household_id], false ], [ %w[user_id], true ])
  end

  it "adds household_id and kind to accounts, with a no-action key, an index and a named check", :aggregate_failures do
    expect(connection.foreign_keys(:accounts).map { [ it.to_table, it.column, it.on_delete ] }).to include([ "households", "household_id", nil ])
    expect(connection.index_exists?(:accounts, :household_id)).to be(true)
    kind = connection.columns(:accounts).find { it.name == "kind" }
    expect([ kind.null, kind.default ]).to eq([ false, "personal" ])
    expect(connection.check_constraints(:accounts).map(&:name)).to include("accounts_kind_known")
  end

  it "refuses a role that is neither manager nor member, and a second membership for a user (AC-2.1, AC-2.2)", :aggregate_failures do
    user, _account, household = insert_user
    expect { insert_membership(household, user, "boss") }.to raise_error(ActiveRecord::StatementInvalid, /memberships_role_known/)
    insert_membership(household, user, "manager")
    expect { insert_membership(insert_household("Other"), user, "member") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "refuses an account kind that is neither personal nor shared (AC-2.5)" do
    _user, account, = insert_user
    expect { connection.execute("UPDATE accounts SET kind = 'other' WHERE id = #{account}") }.to raise_error(ActiveRecord::StatementInvalid, /accounts_kind_known/)
  end

  it "refuses a household name that is blank or over 100 characters, and keeps one of exactly 100 (AC-2.7)", :aggregate_failures do
    expect { insert_household("") }.to raise_error(ActiveRecord::StatementInvalid, /households_name_length/)
    expect { insert_household("a" * 101) }.to raise_error(ActiveRecord::StatementInvalid, /households_name_length/)
    expect { insert_household("a" * 100) }.not_to raise_error
  end

  it "refuses to delete a household that holds an account or a member, and deletes a membership with its user (AC-2.9)", :aggregate_failures do
    user, _account, household = insert_user
    insert_membership(household, user, "manager")
    expect { connection.execute("DELETE FROM households WHERE id = #{household}") }.to raise_error(ActiveRecord::InvalidForeignKey)
    connection.execute("DELETE FROM users WHERE id = #{user}")
    expect([ count("memberships"), count("households") ]).to eq([ 0, 1 ])
  end

  it "runs again with nothing left to do", :aggregate_failures do
    insert_user
    before = [ count("households"), count("accounts") ]
    expect { described_class.new.migrate(:up) }.not_to raise_error
    expect([ count("households"), count("accounts") ]).to eq(before)
  end

  it "returns to the schema before it going down, and keeps every account row and its id sequence going down and up (AC-3.5)", :aggregate_failures do
    insert_user(1)
    insert_user(2)
    _user, last_account, = insert_user(3)
    connection.execute("DELETE FROM users WHERE account_id = #{last_account}")
    connection.execute("DELETE FROM accounts WHERE id = #{last_account}")
    rows = connection.select_rows("SELECT id, created_at, updated_at, currency FROM accounts ORDER BY id")
    seq = sequence
    expect(seq).to be > rows.last.first # a copy without a restore would lower it

    down_all
    expect(connection.columns(:accounts).map(&:name)).to eq(%w[id created_at updated_at currency])
    expect([ connection.table_exists?(:households), connection.table_exists?(:memberships) ]).to eq([ false, false ])
    expect(sequence).to eq(seq)
    up_all

    expect(connection.select_rows("SELECT id, created_at, updated_at, currency FROM accounts ORDER BY id")).to eq(rows)
    expect(sequence).to eq(seq)
  end

  it "leaves accounts, households and memberships, after down and up, as the schema states them (AC-3.4)", :aggregate_failures do
    down_all
    up_all

    # The literals are what db/schema.rb dumps for the migration; if a check's expression text differs, correct the literal to the
    # dumped text and say so, don't loosen the example.
    expect(shape(:accounts)[1..]).to eq([ [ [ "households", "household_id", nil ] ],
      [ [ "index_accounts_on_household_id", %w[household_id], false, nil ] ], [ [ "accounts_kind_known", "kind IN ('personal', 'shared')" ] ] ])
    expect(connection.columns(:accounts).map(&:name).sort).to eq(%w[created_at currency household_id id kind updated_at])
    expect(shape(:households)[1..]).to eq([ [], [], [ [ "households_name_length", "length(name) BETWEEN 1 AND 100" ] ] ])
    expect(shape(:memberships)[1..]).to eq([ [ [ "households", "household_id", nil ], [ "users", "user_id", :cascade ] ],
      [ [ "index_memberships_on_household_id", %w[household_id], false, nil ], [ "index_memberships_on_user_id", %w[user_id], true, nil ] ],
      [ [ "memberships_role_known", "role IN ('manager', 'member')" ] ] ])
  end

  it "refuses to go down while a household has two members or a shared account exists, and changes nothing (AC-3.5)", :aggregate_failures do
    one, _a, first = insert_user(1)
    two, second_account, second = insert_user(2)
    insert_membership(first, one, "manager")
    insert_membership(second, two, "manager")
    connection.execute("UPDATE memberships SET household_id = #{first} WHERE user_id = #{two}")

    expect { context.run(:down, 2026_11_13_120001) }.to raise_error(StandardError, /1 household with more than one member/)
    expect(connection.table_exists?(:households)).to be(true)

    connection.execute("UPDATE memberships SET household_id = #{second} WHERE user_id = #{two}")
    connection.execute("UPDATE accounts SET kind = 'shared' WHERE id = #{second_account}")
    expect { context.run(:down, 2026_11_13_120001) }.to raise_error(StandardError, /1 shared account/)
    expect(connection.column_exists?(:accounts, :kind)).to be(true)
  end
end
