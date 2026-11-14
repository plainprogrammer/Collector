# Plan 090: Every User Has a Household

**Spec:** [spec.md](spec.md) v0.3.2 (Approved by the coordinator under the maintainer's delegation, 2026-11-13; the maintainer ruled step (c) the same day: take the copy). **ADR:** [0030](../../adr/0030-a-household-is-a-group-of-accounts.md). **Issue:** #380. **Branch:** `090-every-user-has-a-household`.
**Gate B:** approved by the coordinator under the maintainer's delegation (2026-11-13) for phases 1 to 5 and 7. **Condition on phase 6:** its batch does not start until a second read-only Fable review of phase 6 as it now stands (with `require_enforcement_off`, `require_no_broken_keys`, the fault-after-DROP spec and the corrected `down`) and of the changed `User` validation (it can never leave a user without a household and never reads one on an ordinary request) has been sent to the coordinator with its verdict.
**Written by:** the main session (Opus 5.5 from this step; the spec and ADR were written on Sonnet 5.5). Implementers: Sonnet 5.5 (`model: "sonnet"`), 2 to 4 consecutive tasks each, test first, one commit per task, reading this file by line range; the main session checks each batch's diff.

## Global Constraints

- **No agent runs the `sqlite3` command**, `bin/rails console`, `db:rollback`, `db:migrate:down`, `db:seed`, anything with `RAILS_ENV=production`, `bundle update`, or anything else that prompts. Migrations go down and up **inside specs, through the Migrator** (`MigrationContext#run`), as `spec/migrations/add_decks_spec.rb` does. `bin/rails db:migrate` (development) writes `db/schema.rb`; `bin/rails db:test:prepare` then loads it into the test database.
- Targeted `bin/rspec <file>` runs need no slot. Never two test runs at once (one shared test database). No full `bin/ci` and no push without a slot from the coordinator.
- Released migrations are never edited. The three new files are `20261113120001_create_households_and_memberships.rb`, `20261113120002_backfill_households.rb`, `20261113120003_make_account_household_required.rb` (phase 6; ruled by the maintainer, 2026-11-13, and the last of the migrations). None references an application model; all use `disable_ddl_transaction!` and guard each step.
- Every public method added in `app/models/`, `lib/`, `script/upgrade/` or `spec/support/` has a YARD summary (the comment ratchet); no `{…}` in comments; no collectible named in a core file's comments.
- `household_id`, `role` and `kind` are never permitted from parameters (no controller changes at all: Story 4).
- Commits: Conventional Commits, one per task, stage and commit in separate shell calls, ending with the trailer the session reminder gives.
- `bin/rubocop -a` runs on each Ruby file after an edit (hook); remaining offenses are fixed before the commit.

## Goal

Every user has one household and one manager membership, made with the user; an account has a household and a kind; an upgraded instance backfills them unattended; nothing visible changes; the upgrade proof checks it. (a) and (b) are complete and green without (c); (c) is phase 6 and removable.

## Gates

- **Simplicity:** three new models' worth of code (`Household`, `Membership`, `Account` and `User` edits), three migrations, one harness module. No gem, no controller, no view, no route.
- **Anti-abstraction:** Active Record directly; migrations in plain SQL; the name's rule has one Ruby home (`Household.name_for`) and one SQL home (the backfill), held equal by a spec.
- **Integration-first:** the migration specs (phase 1, 3, 6) and the harness fixture spec (phase 5) are written before the code they test. Complexity Tracking: phase 6 exists only for the held ruling (see its note).

## Files

| File | Responsibility | Phase |
|---|---|---|
| `db/migrate/20261113120001_create_households_and_memberships.rb` | (a) tables, columns, keys, checks | 1 |
| `db/schema.rb` | dumped by `db:migrate` | 1, 6 |
| `app/models/household.rb`, `app/models/membership.rb` | the new models | 2 |
| `app/models/account.rb`, `app/models/user.rb` | `belongs_to :household`, `kind`; creation and deletion | 2 |
| `spec/factories/accounts.rb` | `:household`, `:account` gets one | 2 |
| `spec/support/household_invariants.rb` | the helper of AC-2.8 | 2 |
| `db/migrate/20261113120002_backfill_households.rb` | (b) backfill | 3 |
| `spec/requests/households_*_spec.rb`, `spec/models/household_spec.rb`, `membership_spec.rb`, `collection_import/household_untouched_spec.rb` | the specs of Stories 1, 2, 4, 5 | 2, 4 |
| `docs/export-format/README.md`, `spec/export_format_document_spec.rb` | coverage | 4 |
| `script/upgrade/households.rb`, `script/upgrade/harness.rb` | the two-tier check | 5 |
| `db/migrate/20261113120003_make_account_household_required.rb` | (c) | 6 |
| area docs, rules, `docs/releasing.md`, `CLAUDE.md`, indexes, `verification.md` | documentation | 7 |

---

## Phase 0: Baseline

**Implements:** none | **Satisfies:** none | **Interfaces:** none

- [ ] **0.1** `bin/rails db:prepare` then `bin/rspec spec/models/account_spec.rb spec/models/user_spec.rb spec/script/upgrade spec/export_format_document_spec.rb`. Expected: all pass (record the count in `verification.md` later).

---

## Phase 1: Migration (a), the schema

**Implements:** FR-1, FR-3, decision 1, decision 5 (a) | **Satisfies:** AC-2.1 (database half), AC-2.2 (database half), AC-2.5 (database half), AC-2.7 (database half), AC-2.9 (database half), AC-3.5 (the (a) half), AC-3.4 (shape) | **Interfaces:** tables `households` (`id`, `name` NOT NULL with check `households_name_length`, timestamps) and `memberships` (`id`, `household_id` NOT NULL no-action FK indexed, `user_id` NOT NULL cascade FK unique-indexed, `role` NOT NULL with check `memberships_role_known`, timestamps); columns `accounts.household_id` (integer, nullable, `REFERENCES households (id)`, indexed) and `accounts.kind` (`NOT NULL DEFAULT 'personal'`, check `accounts_kind_known`).

- [ ] **1.1 Write the failing spec** `spec/migrations/create_households_and_memberships_spec.rb`:

```ruby
require "rails_helper"
require Rails.root.join("db/migrate/20261113120001_create_households_and_memberships")

# Spec 090 decision 1, decision 5 (a): the tables, the two columns of accounts, their keys and checks. The migration runs outside a
# transaction (disable_ddl_transaction!), so the examples commit their rows (:committed empties the database around them) and go
# down and up through the Migrator, as db:rollback does (the precedent is spec/migrations/add_decks_spec.rb). Rows are made with
# SQL, so the examples don't depend on the models.
RSpec.describe CreateHouseholdsAndMemberships, :backup, :committed, type: :model do
  let(:connection) { ActiveRecord::Base.connection }
  let(:stamp) { "2026-11-13 12:00:00" }

  # Every version of the households migrations that exists, in order. Phase 6 adds the third.
  def versions = [ 2026_11_13_120001 ]

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down_all = versions.reverse_each { |version| context.run(:down, version) }

  def up_all = versions.each { |version| context.run(:up, version) }

  def count(table) = connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  def sequence = connection.select_value("SELECT seq FROM sqlite_sequence WHERE name = 'accounts'")

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
```

- [ ] **1.2 Run it to see it fail:** `bin/rspec spec/migrations/create_households_and_memberships_spec.rb`. Expected: a `LoadError` (the migration file does not exist), 0 examples run.
- [ ] **1.3 Write the migration** `db/migrate/20261113120001_create_households_and_memberships.rb`:

```ruby
# A household and its members, and the two columns that put an account in one (spec 090 decisions 1 and 5 (a), ADR 0030).
# Without a transaction, as AddDecks explains: dropping the two columns on the way down copies accounts, and with foreign keys
# enforced inside a transaction the copy's DROP TABLE would run the delete rules of the thirteen tables that reference it. Every
# step is guarded, so a run that stopped part way is finished by the next boot. Going down refuses while a household has two
# members or a shared account exists (an older release can't hold either), and keeps accounts' id sequence across each copy.
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
        keeping_sequence do
          remove_check_constraint :accounts, name: "accounts_kind_known" if check_constraint_exists?(:accounts, name: "accounts_kind_known")
          remove_column :accounts, :kind if column_exists?(:accounts, :kind)
        end
        keeping_sequence do
          remove_index :accounts, :household_id if index_exists?(:accounts, :household_id)
          remove_column :accounts, :household_id if column_exists?(:accounts, :household_id)
        end
      end
    end
    drop_table :memberships, if_exists: true
    drop_table :households, if_exists: true
  end

  private
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
    # when the copy left none (an empty table has none).
    def keeping_sequence
      seq = connection.select_value("SELECT seq FROM sqlite_sequence WHERE name = 'accounts'")
      yield
      return unless seq

      connection.execute "UPDATE sqlite_sequence SET seq = #{seq.to_i} WHERE name = 'accounts' AND seq < #{seq.to_i}"
      connection.execute "INSERT INTO sqlite_sequence (name, seq) SELECT 'accounts', #{seq.to_i} WHERE NOT EXISTS (SELECT 1 FROM sqlite_sequence WHERE name = 'accounts')"
    end
end
```

- [ ] **1.4 Dump the schema and prepare the test database:** `bin/rails db:migrate` then `bin/rails db:test:prepare`. Also do steps 4.3 and 4.4 now, before the commit (they are phase 1's: without them `spec/export_format_document_spec.rb` fails). `spec/script/upgrade/seeds_spec.rb`'s example "fills every table db/schema.rb creates" stays red until step 2.5 (the seed makes users through the old model, which makes no household): phases 1 and 2 are one implementer's batch and the suite is green again at 2.6. Check `git diff db/schema.rb`: the two tables, `accounts.household_id` and `accounts.kind` with their key, index and check, `add_foreign_key "accounts", "households"`, `add_foreign_key "memberships", "households"`, `add_foreign_key "memberships", "users", on_delete: :cascade`, and the version `2026_11_13_120001`. The prices structure file is untouched.
- [ ] **1.5 Run the spec to see it pass:** `bin/rspec spec/migrations/create_households_and_memberships_spec.rb`. Expected: 11 examples, 0 failures. If the shape example fails on a check's expression text, print both shapes in the failure and report it: do not weaken the example.
- [ ] **1.6 Commit:** `feat(db): households, memberships and the account's household and kind (spec 090 phase 1)`.

---

## Phase 2: The models, and a household with every user

**Implements:** FR-1, FR-2, decisions 3, 6, 7, 8 | **Satisfies:** AC-1.1 to AC-1.7, AC-2.1 to AC-2.9, AC-4.4 | **Interfaces:** `Household` (`name_for(user_name)`, `memberships`, `accounts`, `users`; refuses destroy while held); `Membership` (`role` enum `manager`/`member`, `last_manager?`; refuses a direct destroy and a demotion of the last manager); `Account#household`, `Account#kind` (enum `personal`/`shared`); `User#membership`; a user is made with an account in a new household and a manager membership; a user's delete removes the membership, the account, and the household when empty.

- [ ] **2.1 Factories and the invariants helper.** In `spec/factories/accounts.rb` replace `factory :account` by:

```ruby
  factory :household do
    sequence(:name) { |n| "Household #{n}" }
  end

  factory :account do
    household
  end
```
Create `spec/support/household_invariants.rb`:

```ruby
# The invariants of a household, checked on the test database (spec 090 AC-2.8): the same four the upgrade proof's tier 1 checks.
module HouseholdInvariants
  # Fails the example, naming the broken rule, unless every user has exactly one membership, every household has a
  # manager, every account has a household and a personal account's household is its user's.
  def expect_household_invariants!
    connection = ActiveRecord::Base.connection
    expect(connection.select_values("SELECT users.id FROM users LEFT JOIN memberships ON memberships.user_id = users.id GROUP BY users.id HAVING COUNT(memberships.id) <> 1")).to be_empty, "a user without exactly one membership"
    expect(connection.select_values("SELECT households.id FROM households WHERE NOT EXISTS (SELECT 1 FROM memberships m WHERE m.household_id = households.id AND m.role = 'manager')")).to be_empty, "a household without a manager"
    expect(connection.select_values("SELECT id FROM accounts WHERE household_id IS NULL")).to be_empty, "an account without a household"
    expect(connection.select_values("SELECT accounts.id FROM accounts JOIN users ON users.account_id = accounts.id JOIN memberships ON memberships.user_id = users.id WHERE accounts.kind = 'personal' AND accounts.household_id <> memberships.household_id")).to be_empty, "a personal account outside its user's household"
  end
end

RSpec.configure { |config| config.include HouseholdInvariants }
```
- [ ] **2.2 Write the failing model specs.** `spec/models/household_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Household, type: :model do
  describe ".name_for" do
    it "is the user's name and \"'s household\", the name cut to its first 88 characters (spec 090 decision 2, AC-1.5)", :aggregate_failures do
      expect(described_class.name_for("Ada")).to eq("Ada's household")
      expect(described_class.name_for("A")).to eq("A's household")
      long = described_class.name_for("é" * 100)
      expect([ long.length, long ]).to eq([ 100, "#{"é" * 88}'s household" ])
      expect(described_class.name_for("O'Neil")).to eq("O'Neil's household")
    end
  end

  it "needs a name of 1 to 100 characters (AC-2.7)", :aggregate_failures do
    expect(build(:household, name: "").tap(&:validate).errors[:name]).to be_present
    expect(build(:household, name: "a" * 101).tap(&:validate).errors[:name]).to be_present
    expect(build(:household, name: "a" * 100)).to be_valid
  end

  it "can't be destroyed while it holds an account or a member, by the model or by the database (AC-2.9)", :aggregate_failures do
    user = create(:user)
    household = user.membership.household

    expect(household.destroy).to be(false)
    expect(described_class.exists?(household.id)).to be(true)
    expect { described_class.connection.execute("DELETE FROM households WHERE id = #{household.id}") }.to raise_error(ActiveRecord::InvalidForeignKey)
    expect(create(:household).destroy).to be_truthy
  end
end
```
`spec/models/membership_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Membership, type: :model do
  # Puts +member+ into +manager+'s household as a plain member, the way a later issue's join will, by SQL (spec only).
  def join(member, manager)
    described_class.where(user_id: member.id).update_all(household_id: manager.membership.household_id, role: "member")
    Account.where(id: member.account_id).update_all(household_id: manager.membership.household_id)
    member.reload
  end

  let(:manager) { create(:user) }
  let(:member) { join(create(:user), manager) }

  it "has a role of manager or member only (AC-2.1)", :aggregate_failures do
    expect(described_class.new(role: "boss").tap(&:validate).errors[:role]).to be_present
    bare = create(:user)
    described_class.where(user_id: bare.id).delete_all # a user with no membership, by SQL
    expect { described_class.insert!({ household_id: manager.membership.household_id, user_id: bare.id, role: "boss" }) }.to raise_error(ActiveRecord::StatementInvalid, /memberships_role_known/)
  end

  it "is one per user (AC-2.2)", :aggregate_failures do
    second = described_class.new(household: create(:household), user: manager, role: "member")
    expect(second).not_to be_valid
    expect { described_class.insert!({ household_id: create(:household).id, user_id: manager.id, role: "member" }) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "can't be removed on its own, a household of one's included (AC-2.4)", :aggregate_failures do
    expect(manager.membership.destroy).to be(false)
    expect(member.membership.destroy).to be(false)
    expect(described_class.count).to eq(2)
  end

  it "keeps a manager: the last one can't be demoted, one of two can (AC-2.3)", :aggregate_failures do
    member # joins manager's household
    expect(manager.membership.update(role: "member")).to be(false)
    expect(manager.membership.errors[:role]).to be_present
    member.membership.update!(role: "manager")
    expect(manager.membership.reload.update(role: "member")).to be(true)
  end

  it "keeps a user from being deleted when they are the last manager of a household with others (AC-2.3, decision 7)", :aggregate_failures do
    member
    expect { manager.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    expect([ User.exists?(manager.id), described_class.exists?(user_id: manager.id) ]).to eq([ true, true ])
  end

  it "lets a plain member's user be deleted, leaving the household and its manager (decision 7)", :aggregate_failures do
    household = member.membership.household
    member.destroy!
    expect([ Household.exists?(household.id), described_class.where(household_id: household.id).pluck(:user_id) ]).to eq([ true, [ manager.id ] ])
  end
end
```
`spec/models/account_spec.rb`: append inside the top `RSpec.describe` before its last `end`:

```ruby
  describe "household and kind (spec 090)" do
    it "needs a household (decision 8)" do
      expect(described_class.new.tap(&:validate).errors[:household]).to be_present
    end

    it "is personal by default and shared or personal only (AC-2.5)", :aggregate_failures do
      expect(create(:account).kind).to eq("personal")
      expect(build(:account, kind: "other")).not_to be_valid
      expect { described_class.connection.execute("UPDATE accounts SET kind = 'other' WHERE id = #{create(:account).id}") }.to raise_error(ActiveRecord::StatementInvalid, /accounts_kind_known/)
    end
  end
```
Append to `spec/models/user_spec.rb` (inside the describe):

```ruby
  describe "household (spec 090)" do
    it "is made with a household named for it, an account in it and a manager membership (AC-1.1)", :aggregate_failures do
      user = create(:user, name: "Ada")

      expect(user.membership).to have_attributes(role: "manager", household: have_attributes(name: "Ada's household"))
      expect(user.account).to have_attributes(kind: "personal", household: user.membership.household)
      expect(Household.count).to eq(1)
    end

    it "gives a user with 100 characters a name of exactly 100 (AC-1.5)" do
      expect(create(:user, name: "n" * 100).membership.household.name).to eq("#{"n" * 88}'s household")
    end

    it "makes nothing for a user that is invalid (AC-1.6)", :aggregate_failures do
      expect { build(:user, name: "").save }.not_to change { [ Household.count, Membership.count, Account.count ] }
    end

    it "is refused when its membership is in another household than its account's (AC-2.6)", :aggregate_failures do
      user = create(:user)
      user.account.household = create(:household)

      expect(user).not_to be_valid
      expect(user.errors[:membership]).to be_present
      expect(create(:user)).to be_valid
    end

    it "removes its membership, its account and its household when it is deleted (AC-4.4)", :aggregate_failures do
      user = create(:user)
      household = user.membership.household

      user.destroy!

      expect([ Household.exists?(household.id), Membership.exists?(user_id: user.id), Account.exists?(user.account_id) ]).to eq([ false, false, false ])
    end

    it "keeps the invariants however it is made and deleted (AC-2.8)" do
      create(:user)
      create(:admin).destroy!
      expect_household_invariants!
    end
  end
```
- [ ] **2.3 Write the failing request spec** `spec/requests/households_creation_spec.rb` (Story 1's four paths; AC-1.1 to AC-1.4, AC-1.6, AC-1.7, AC-4.4):

```ruby
require "rails_helper"

RSpec.describe "A household with every user (spec 090 Story 1)", type: :request do
  let(:password) { "correct horse battery" }

  def sign_up(**extra) = post(registration_path, params: { user: { name: "Ann", email_address: "ann@example.test", password:, password_confirmation: password, **extra } })

  def expect_a_household_of_one(user, named: "#{user.name}'s household")
    expect(user.membership).to have_attributes(role: "manager", household: have_attributes(name: named))
    expect(user.account).to have_attributes(kind: "personal", household: user.membership.household)
    expect(user.membership.household.memberships.count).to eq(1)
    expect_household_invariants!
  end

  it "gives the first visitor a household of one and lands them in the collection (AC-1.1)", :aggregate_failures do
    sign_up
    expect(response).to redirect_to(collection_path)
    expect_a_household_of_one(User.sole)
    expect_household_invariants!
  end

  it "gives a person who signs up while sign-up is open their own household (AC-1.2)", :aggregate_failures do
    first = create(:admin)
    InstanceSetting.current.update!(sign_up_open: true)
    sign_up
    expect_a_household_of_one(User.find_by!(email_address: "ann@example.test"))
    expect(first.membership.household.memberships.count).to eq(1)
  end

  it "gives a user an admin adds a household of one and leaves the admin's own alone (AC-1.3)", :aggregate_failures do
    admin = sign_in_as(create(:admin))
    household = admin.membership.household
    post admin_users_path, params: { user: { name: "Bo", email_address: "bo@example.test", password: } }
    expect(response).to redirect_to(admin_users_path)
    expect_a_household_of_one(User.find_by!(email_address: "bo@example.test"))
    expect(admin.reload.membership.household).to eq(household)
  end

  it "gives the operator command's admin a household of one (AC-1.4)", :aggregate_failures do
    user, = User::Command.call(email: "ops@example.test", password:)
    expect_a_household_of_one(user, named: "ops's household")
  end

  it "makes nothing for a sign-up that is invalid: a blank name on an empty instance, a used email while sign-up is open (AC-1.6)", :aggregate_failures do
    expect { sign_up(name: "") }.not_to change { [ Household.count, Membership.count, Account.count ] }
    expect(response).to have_http_status(:unprocessable_content)
    create(:admin, email_address: "ann@example.test")
    InstanceSetting.current.update!(sign_up_open: true)
    expect { sign_up }.not_to change { [ Household.count, Membership.count, Account.count ] }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "makes nothing for a sign-up that finds a user already there, as when it loses the first-user race (AC-1.6)", :aggregate_failures do
    get new_registration_path
    create(:admin)
    expect { sign_up }.not_to change { [ Household.count, Membership.count, Account.count ] }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "ignores a household, role or kind in the parameters of a sign-up and of an admin's form (AC-1.7)", :aggregate_failures do
    other = create(:user).membership.household # a household with a manager, so the invariants helper holds
    sign_up(household_id: other.id, role: "member", kind: "shared")
    ann = User.find_by!(email_address: "ann@example.test")
    expect_a_household_of_one(ann)
    expect(ann.membership.household).not_to eq(other)

    sign_in_as(create(:admin))
    post admin_users_path, params: { user: { name: "Bo", email_address: "bo@example.test", password:, household_id: other.id, role: "member", kind: "shared" } }
    expect_a_household_of_one(User.find_by!(email_address: "bo@example.test"))
  end

  it "removes a deleted user's household, membership and account, and no other (AC-4.4)", :aggregate_failures do
    admin = sign_in_as(create(:admin))
    bo = create(:user, name: "Bo")
    delete admin_user_path(bo)
    expect(response).to redirect_to(admin_users_path)
    expect([ Household.where(name: "Bo's household").count, Membership.where(user_id: bo.id).count, Account.where(id: bo.account_id).count ]).to eq([ 0, 0, 0 ])
    expect(admin.reload.membership).to be_present
    expect_household_invariants!
  end
end
```
- [ ] **2.4 Run the new specs to see them fail:** `bin/rspec spec/models/household_spec.rb spec/models/membership_spec.rb spec/models/account_spec.rb spec/models/user_spec.rb spec/requests/households_creation_spec.rb`. Expected: failures (`uninitialized constant Household`, undefined methods).
- [ ] **2.5 Write the models.** `app/models/household.rb`:

```ruby
# A named group of accounts: today always one user's, from a later issue also a family's (spec 090, ADR 0030). It is the
# household's, not the collector's, so it is never scoped through `Current.account` and no request names one.
class Household < ApplicationRecord
  NAME_LIMIT = 100
  # The name of a household of one is the user's name followed by this: 12 characters, so the user's name is cut to 88.
  SUFFIX = "'s household".freeze

  has_many :memberships, dependent: nil # the foreign key has no action: a household that holds a member can't be deleted
  has_many :users, through: :memberships
  has_many :accounts, dependent: nil # likewise, so a delete can never reach an account and, through its cascades, a collection

  validates :name, presence: true, length: { maximum: NAME_LIMIT }

  before_destroy :refuse_while_held, prepend: true

  # The name a household of one gets (spec 090 decision 2): the user's first 88 characters and "'s household", at most 100.
  # `script/upgrade/households.rb` and the backfill migration build the same name in SQL with `substr`; a spec holds the three equal.
  #
  # @param user_name [String] the user's name
  # @return [String]
  def self.name_for(user_name) = "#{user_name.to_s.slice(0, NAME_LIMIT - SUFFIX.length)}#{SUFFIX}"

  private
    def refuse_while_held
      throw :abort if memberships.exists? || accounts.exists?
    end
end
```
`app/models/membership.rb`:

```ruby
# One user in one household, as a manager or a member (spec 090, ADR 0030). A household always has a manager: the model
# refuses to demote the last one and to remove a membership on its own; a membership goes with its user (`User` deletes it
# without these callbacks, and the database cascades). The role check and the unique user are the database's too.
class Membership < ApplicationRecord
  belongs_to :household
  belongs_to :user

  enum :role, { manager: "manager", member: "member" }, validate: true

  validates :user_id, uniqueness: true, allow_nil: true
  validate :keeps_a_manager, on: :update, if: -> { role_changed?(from: "manager") }

  before_destroy { throw :abort }

  # Whether this is its household's only manager.
  #
  # @return [Boolean]
  def last_manager? = manager? && !household.memberships.manager.where.not(id:).exists?

  private
    def keeps_a_manager
      errors.add(:role, "can't change: a household needs a manager.") unless household.memberships.manager.where.not(id:).exists?
    end
end
```
Edit `app/models/account.rb`: after `has_one :user, dependent: nil` add `belongs_to :household` with a comment, and after `validates :currency …` add the kind:

```ruby
  # The household this account is in: a user's own account (personal) is in that user's household, and a shared account (none
  # exists yet, #384) is the household's. Required, and `NOT NULL` once spec 090's third migration has run.
  belongs_to :household
  enum :kind, { personal: "personal", shared: "shared" }, default: :personal, validate: true
```
Edit `app/models/user.rb`: replace `belongs_to :account, dependent: :destroy` through the callbacks as follows (keep everything else):

```ruby
  has_secure_password
  # Deleted without callbacks (Membership refuses a direct destroy; the database would cascade it anyway), before the user's row.
  has_one :membership, dependent: :delete, inverse_of: :user, autosave: true
  belongs_to :account, dependent: :destroy
  has_many :sessions, dependent: :delete_all
  ...
  validates :membership, presence: true, on: :create
  # Only when both are loaded (a new user, or a user a caller loaded both for): an update of a signed-in user, whose account the
  # session loads, must not read a household (spec 090 Story 4, AC-4.5).
  validate :membership_is_in_the_accounts_household, if: -> { association(:membership).loaded? && association(:account).loaded? }

  before_validation :build_account_and_household, on: :create, unless: :account
  before_destroy :keep_a_manager_for_the_others, prepend: true
  after_destroy :remove_an_empty_household # after the account's, which `belongs_to … dependent: :destroy` registers above
```
and in `private`:

```ruby
    # A user is made with its account and its household of one, as the manager (spec 090 decision 8): one write, so a failed
    # save leaves none of the three.
    def build_account_and_household
      household = Household.new(name: Household.name_for(name))
      build_account(household:)
      build_membership(household:, role: :manager)
    end

    def membership_is_in_the_accounts_household
      return unless membership && account

      errors.add(:membership, "must be in the household of the account") unless membership.household == account.household
    end

    # A household can't lose its last manager by deleting the user while others are in it (spec 090 decision 7); a page that
    # makes such a household (#382, #383) gives it a message. Remembers the household for the delete's last step.
    def keep_a_manager_for_the_others
      @leaving_household = membership&.household
      return unless membership&.last_manager? && membership.household.memberships.where.not(id: membership.id).exists?

      errors.add(:base, "is the last manager of a household that has other members.")
      throw :abort
    end

    # The household of a user whose delete left no member and no account goes with them; `Household` refuses while it holds either.
    def remove_an_empty_household = @leaving_household&.destroy
```
- [ ] **2.6 Run the specs to see them pass:** same command as 2.4. Expected: 0 failures. Then `bin/rspec spec/requests spec/models` (no slot needed) to see nothing else broke; edit `spec/models/account_spec.rb` line 42 (`expect(described_class.new(currency: "SEK")).to be_valid` becomes `expect(build(:account, currency: "SEK")).to be_valid`: an account needs its household now; change nothing in the model to keep the old line passing); fix a factory-made account in any other spec that needs the household (only the three named in the spec's decision 9 (ii) use `create(:account)`, now with a household).
- [ ] **2.7 Commit** in two commits: `feat(models): household and membership, an account's household and kind (spec 090 phase 2)` (models, factories, helper, model specs) and `feat(auth): every way of making a user makes a household of one (spec 090 phase 2)` if the request spec was written after; otherwise one.

---

## Phase 3: Migration (b), the backfill

**Implements:** FR-3, decision 5 (b) | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.8, AC-1.5 (the SQL half) | **Interfaces:** an idempotent data migration; batches of 500 users; each batch one transaction; sets `accounts.household_id` only.

- [ ] **3.1 Write the failing spec** `spec/migrations/backfill_households_spec.rb`:

```ruby
require "rails_helper"
require Rails.root.join("db/migrate/20261113120002_backfill_households")

# Spec 090 decision 5 (b), AC-3.1 to AC-3.3, AC-3.8, AC-1.5: a household of one for every user that has none, in batches, idempotent,
# touching accounts' household_id only. The users are made with the models and their household rows then removed by SQL, which is the
# state a database from the previous release is in once (a) has run.
RSpec.describe BackfillHouseholds, :backup, :committed, type: :model do
  let(:connection) { ActiveRecord::Base.connection }

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = true
  end

  def run_up = described_class.new.migrate(:up)

  def count(table) = connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  # Takes every household away, as the previous release leaves users and accounts.
  def forget_households
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
    5.times { |i| connection.execute("INSERT INTO accounts (created_at, updated_at) VALUES ('#{now}', '#{now}')") ; connection.execute("INSERT INTO users (account_id, name, email_address, password_digest, created_at, updated_at) VALUES (#{connection.select_value("SELECT MAX(id) FROM accounts")}, 'U#{i}', 'u#{i}@example.test', 'x', '#{now}', '#{now}')") }
    forget_households
    begins = 0
    counter = ->(*, payload) { begins += 1 if payload[:sql].match?(/\ABEGIN/i) }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { run_up }

    expect(count("households")).to eq(5)
    expect(begins).to eq(3) # one transaction for each of the three batches; the empty read that ends the loop opens none
  end

  it "makes 10,000 households in 20 batches, and says how long it took (the NFR)", timing: true do
    connection.execute("WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 10000) INSERT INTO accounts (created_at, updated_at) SELECT datetime('now'), datetime('now') FROM n")
    connection.execute("INSERT INTO users (account_id, name, email_address, password_digest, created_at, updated_at) SELECT id, 'U' || id, 'u' || id || '@example.test', 'x', datetime('now'), datetime('now') FROM accounts")
    seconds = Benchmark.realtime { run_up }
    expect(count("households")).to eq(10_000)
    puts "backfill of 10,000 users: #{seconds.round(2)} s"
  end

  it "succeeds on a database with no user (AC-3.4)" do
    expect { run_up }.not_to raise_error
  end

  it "leaves every session row as it was (AC-3.8)" do
    user = create(:user)
    session = user.sessions.create!
    forget_households
    rows = connection.select_rows("SELECT * FROM sessions ORDER BY id")

    run_up

    expect(connection.select_rows("SELECT * FROM sessions ORDER BY id")).to eq(rows)
    expect(session.reload).to be_present
  end
end
```
Note for the implementer: the batch example counts the `BEGIN` statements of the run (one for each batch); `run_up` below is wrapped in the `around` that sets `ActiveRecord::Migration.verbose = false` and restores it. The example's `accounts` inserts rely on `household_id` being nullable and `kind` defaulted: in phase 6 (c) makes `household_id` NOT NULL, and phase 6 edits this one example (step 6.6).
- [ ] **3.2 Run it to see it fail** (`LoadError`), then **3.3 write the migration** `db/migrate/20261113120002_backfill_households.rb`:

```ruby
# Gives every user that has no household one of their own, as its manager (spec 090 decision 5 (b), decision 2). Plain SQL and no
# application model (.claude/rules/sqlite-and-migrations.md). Without a transaction, so each batch of users is its own short write
# transaction: a large instance never holds the write lock for more than one batch, and a run that stopped is finished by the next
# boot. Idempotent: it reads only users with no membership. It sets accounts.household_id and nothing else, updated_at included, so
# the upgrade proof's comparison of accounts needs no expected change. The name is the user's first 88 characters and "'s household"
# (`Household.name_for`; a spec holds the two equal). Nothing to undo going down: the tables go with the first migration.
class BackfillHouseholds < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH = 500

  def up
    now = connection.quote(Time.current.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))
    loop do
      users = connection.select_rows("SELECT id, account_id FROM users WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.user_id = users.id) ORDER BY id LIMIT #{BATCH.to_i}")
      break if users.empty?

      connection.transaction do
        users.each do |user_id, account_id|
          household = connection.insert("INSERT INTO households (name, created_at, updated_at) SELECT substr(name, 1, 88) || '''s household', #{now}, #{now} FROM users WHERE id = #{user_id.to_i}")
          raise ActiveRecord::MigrationError, "no household was made for user #{user_id}" unless household
          connection.execute "INSERT INTO memberships (household_id, user_id, role, created_at, updated_at) VALUES (#{household.to_i}, #{user_id.to_i}, 'manager', #{now}, #{now})"
          connection.execute "UPDATE accounts SET household_id = #{household.to_i} WHERE id = #{account_id.to_i}"
        end
      end
    end
  end

  def down; end
end
```
(`BATCH.to_i`, `user_id.to_i` are integers from the database or a constant: the interpolations are safe and say so in a trailing comment as `BackfillSessionsLastUsedAt` does.)
- [ ] **3.4 Run the spec:** `bin/rspec spec/migrations/backfill_households_spec.rb`. Expected: 7 examples, 0 failures. Then `bin/rails db:migrate` (the development database holds users: check `bin/rails runner 'puts [User.count, Household.count].inspect'` prints equal counts) and `git diff db/schema.rb` (only the version line changes).
- [ ] **3.5 Commit:** `feat(db): backfill a household of one for every existing user (spec 090 phase 3)`.

---

## Phase 4: Nothing looks different, the export and the round trip

**Implements:** FR-5 (format document), decision 4, decision 9 | **Satisfies:** AC-4.1, AC-4.3, AC-4.5, AC-5.1, AC-5.2, AC-5.3, AC-5.4 | **Interfaces:** the Coverage tables list `memberships` (table, "Left out"), `accounts.household_id` and `accounts.kind` (columns, "Left out"); the format stays version 4.

- [ ] **4.1 Failing spec for the invisible change.** Create `spec/requests/households_invisible_spec.rb`:

```ruby
require "rails_helper"

# Spec 090 Story 4, decision 9 (i): no page says "household", and no request of these pages reads a household or a membership.
RSpec.describe "A household is invisible (spec 090 Story 4)", type: :request do
  let!(:admin) { create(:admin, name: "Ann") }
  let(:paths) { [ collection_path, collection_path(view: "table"), admin_users_path, more_path, catalog_entries_path ] }

  def statements_naming(pattern, &)
    seen = []
    ActiveSupport::Notifications.subscribed(->(*, payload) { seen << payload[:sql] if payload[:sql].match?(pattern) }, "sql.active_record", &)
    seen
  end

  it "shows no page of a collector or an admin the word, and runs no query naming the new tables (AC-4.1, AC-4.5)", :aggregate_failures do
    sign_in_as(admin)
    seen = statements_naming(/\b(households|memberships)\b/i) do
      paths.each do |path|
        get path
        expect(response).to have_http_status(:ok), "#{path} answered #{response.status}"
        expect(response.body.downcase).not_to include("household"), "#{path} says household"
      end
    end
    expect(seen).to be_empty
  end

  it "shows a collector who is not an admin no page with the word (AC-4.1)", :aggregate_failures do
    sign_in_as(create(:user))
    [ collection_path, collection_path(view: "table"), more_path, catalog_entries_path ].each do |path|
      get path
      expect(response.body.downcase).not_to include("household"), "#{path} says household"
    end
  end

  it "shows no signed-out page the word (AC-4.1)", :aggregate_failures do
    [ new_session_path, new_registration_path ].each do |path|
      get path
      expect(response.body.downcase).not_to include("household"), "#{path} says household"
    end
  end

  it "lists users as before: a row, its copies and the same buttons (AC-4.5)", :aggregate_failures do
    sign_in_as(admin)
    bo = create(:user, name: "Bo")
    create(:lot, account: bo.account, quantity: 3)
    get admin_users_path
    expect(response.body).to include("Bo", '<td class="is-num">3</td>')
    expect(response.body.downcase).not_to include("household")
  end
end
```
Run it: it should pass at once (nothing visible was added); that is the point of this check. Record in `verification.md` that it passed on the first run. Then **4.2 the one-off checks** (recorded in `verification.md`, no commit): `git grep -n -i 'household\|membership' -- app/views app/helpers app/controllers app/javascript config/locales ':!.kamal/secrets'` prints nothing; `bin/rails routes > "$TMPDIR/routes_branch.txt"`, then the same on `main` in the main checkout is not allowed (read-only worktree rule): compare with `git show main:config/routes.rb` against `config/routes.rb` (`git diff main -- config/routes.rb` is empty) and `bin/rails routes | wc -l` equal to the line count recorded from the first `bin/rails routes` run in phase 0 (add that run to step 0.1's record).
- [ ] **4.3 (done in step 1.4) Failing spec edits for the coverage guard** (`spec/export_format_document_spec.rb`): in the `"marks each table as the spec rules"` example add `memberships` to the `%w[...]` list of "Left out" tables (alphabetical: `… import_uploads memberships number_entries …`); in the columns example add `accounts.household_id accounts.kind` after `accounts.updated_at` in the left-out list. Run `bin/rspec spec/export_format_document_spec.rb`: the coverage examples fail (the document lacks the rows).
- [ ] **4.4 (done in step 1.4) Edit `docs/export-format/README.md`.** In the Coverage tables: add the row `| \`memberships\` | Left out | A household's membership of a user: a fact about a group, not about the collection. A household of one is made with every user, so a person who imports their file is given one by the same rule (spec 090 decision 4). |` between `import_uploads` and `number_entries` (the table is alphabetical after `accounts`, `lots`, ... as the file lists; keep its order of "Exported" rows first, then "Left out" alphabetically); in the Column table add after `accounts.updated_at`: `| \`accounts.household_id\` | Left out | An internal id of a group. A file is one account's collection, and the household is not in it. |` and `| \`accounts.kind\` | Left out | Whether the account is a member's own or the household's. A file is one account's collection, and every account that has a file is personal until the shared collection (#384) decides its own file. |`. After the Coverage tables add the sentence: "`households` has neither `account_id` nor `user_id`, so the guard above does not ask for it; it is not in the file either, and the question of what the shared collection's file carries about its household is decided with the shared collection (issue #384, the design's open question 4)." Replace the sentence at the Versions history (line 336 area) "One change is already expected: collections shared by a household will change who owns a lot and will raise the version ([ADR 0017](../adr/0017-row-level-tenancy-one-user-per-account.md))." by "One change is already expected: the household's shared collection has its own file and will raise the version ([ADR 0030](../adr/0030-a-household-is-a-group-of-accounts.md), issue #384). A household itself, one per user from spec 090, is not in the file and raised no version." Edit `docs/architecture/data-portability.md` line 47's sentence to add: "`memberships` and `accounts.household_id` and `.kind` were listed as left out with spec 090; `households` has neither key and is outside the guard." Run `bin/rspec spec/export_format_document_spec.rb` (expected green) and `bin/rspec spec/models/export_format spec/models/collection_export_spec.rb` (green).
- [ ] **4.5 Failing spec for the round trip and the backup.** Create `spec/models/collection_import/household_untouched_spec.rb`:

```ruby
require "rails_helper"

# Spec 090 AC-5.2: an apply writes the collection and the currency and never the account's household, kind or membership.
RSpec.describe "Applying an export and the household (spec 090 AC-5.2)", type: :model do
  let(:source) { create(:user, name: "Source", email_address: "source@example.test") }
  let(:target) { create(:user, name: "Target", email_address: "target@example.test") }

  def export(user) = JSON.parse(CollectionExport.new(account: user.account, at: Time.utc(2026, 11, 13, 12)).to_json)

  def apply!(user, data)
    upload = store_import!(account: user.account, data:)
    CollectionImport::Apply.new(account: user.account.reload, fingerprint: upload&.fingerprint, confirmed: true).call
  end

  def household_facts(user)
    user.reload
    [ user.membership.household_id, user.membership.role, user.account.household_id, user.account.kind, Household.pluck(:id, :name).sort ]
  end

  before { held_lot(source.account, import_printing, quantity: 3, finish: "foil") }

  it "changes no household, role or kind, whether the file restores a collection or replaces one (AC-5.2)", :aggregate_failures do
    document = export(source)
    expect(document.keys).not_to include("household", "households", "memberships")
    before = [ household_facts(source), household_facts(target) ]

    apply!(target, document)
    apply!(source, document.merge("lots" => []))

    expect([ household_facts(source), household_facts(target) ]).to eq(before)
    expect(target.account.lots.sum(:quantity)).to eq(3)
  end
end
```
It passes as soon as written (the apply never wrote them); record that in `verification.md` (a guard, not a fix). **Backup (AC-5.3):** `bin/rspec spec/backup_guards_spec.rb spec/backup_upgrade_spec.rb spec/lib/collector/backup` expected green and unedited (the primary database is held whole; the households are in it). If an example inserts accounts by SQL and fails on the model's new rules, note it for phase 6 (the SQL inserts at `spec/support/backup_helpers.rb:40` and `spec/lib/collector/backup/snapshot_spec.rb:12` need no change while `household_id` is nullable).
- [ ] **4.6 Run the tenancy guard:** `bin/rspec spec/requests` (no edits to any existing request spec; expected: 0 failures), then `bin/rspec spec/system -e "sign" --dry-run` is not needed: system specs run in the one CI run. Commit: `test(households): nothing looks different, the format's coverage and the round trip (spec 090 phase 4)` and, separately, `docs(export-format): list the household's tables as left out (spec 090 phase 4)`.

---

## Phase 5: The upgrade proof checks the households

**Implements:** FR-4, decision 10 | **Satisfies:** AC-6.1 to AC-6.5, AC-3.8 (the proof's behaviour leg) | **Interfaces:** `Upgrade::Households.problems(db, backfill: false)` answers a list of strings, empty when the snapshot holds the invariants; the harness raises `Failure` with `AC-6.1` on problems in `compare` (upgraded and restored snapshots) and in `next_release`.

- [ ] **5.1 Failing spec** `spec/script/upgrade/households_spec.rb`:

```ruby
require "rails_helper"
require Rails.root.join("script/upgrade/households").to_s

# Spec 090 decision 10 and AC-6.5: the two tiers of the check on fixture snapshots, never on the application.
RSpec.describe Upgrade::Households, :upgrade do
  # The three names of AC-1.5, so this check, the model and the backfill agree on the same cases.
  let(:names) { [ "n" * 100, "O'Neil", "é" * 100 ] }

  def snapshot(users:, memberships: nil, households: nil, accounts: nil)
    path = File.join(upgrade_dir, "snap#{SecureRandom.hex(3)}.sqlite3")
    build_database(path) do |db|
      db.execute_batch(<<~SQL)
        CREATE TABLE households (id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE memberships (id INTEGER PRIMARY KEY, household_id INTEGER, user_id INTEGER, role TEXT);
        CREATE TABLE accounts (id INTEGER PRIMARY KEY, household_id INTEGER, kind TEXT);
        CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, account_id INTEGER);
      SQL
      users.each_with_index do |name, i|
        id = i + 1
        db.execute("INSERT INTO households VALUES (?, ?)", [ id, "#{name[0, 88]}'s household" ]) unless households == :none
        db.execute("INSERT INTO accounts VALUES (?, ?, 'personal')", [ id, id ])
        db.execute("INSERT INTO users VALUES (?, ?, ?)", [ id, name, id ])
        db.execute("INSERT INTO memberships VALUES (?, ?, ?, 'manager')", [ id, id, id ]) unless memberships == :none
      end
      yield db if block_given?
    end
    open_database(path)
  end

  it "passes a clean snapshot in both tiers (AC-6.1)" do
    expect(described_class.problems(snapshot(users: names), backfill: true)).to be_empty
  end

  it "names a user with no membership (AC-6.5)" do
    expect(described_class.problems(snapshot(users: names, memberships: :none))).to include(a_string_matching(/user .* membership/))
  end

  it "names a household with no manager (AC-6.5)" do
    db = snapshot(users: names) { it.execute("UPDATE memberships SET role = 'member' WHERE id = 1") }
    expect(described_class.problems(db)).to include(a_string_matching(/household 1 .*manager/))
  end

  it "names an account in another user's household (AC-6.5)" do
    db = snapshot(users: names) { it.execute("UPDATE accounts SET household_id = 2 WHERE id = 1") }
    expect(described_class.problems(db)).to include(a_string_matching(/account 1 .*household/))
  end

  it "names an account with no household (AC-6.5)" do
    db = snapshot(users: names) { it.execute("UPDATE accounts SET household_id = NULL WHERE id = 3") }
    expect(described_class.problems(db)).to include(a_string_matching(/account 3 .*no household/))
  end

  it "checks the backfill's facts only when asked: a name that differs, a count that differs, a role or a kind that differs (AC-6.5)", :aggregate_failures do
    renamed = snapshot(users: names) { it.execute("UPDATE households SET name = 'Someone else' WHERE id = 2") }
    expect(described_class.problems(renamed)).to be_empty
    expect(described_class.problems(renamed, backfill: true)).to include(a_string_matching(/name/))
    extra = snapshot(users: names) { it.execute("INSERT INTO households VALUES (9, 'x'); INSERT INTO memberships VALUES (9, 9, 99, 'manager')") }
    expect(described_class.problems(extra, backfill: true)).to include(a_string_matching(/count/))
    member = snapshot(users: names) { it.execute("INSERT INTO memberships VALUES (10, 1, 98, 'member')") }
    expect(described_class.problems(member, backfill: true)).to include(a_string_matching(/role/))
    shared = snapshot(users: names) { it.execute("UPDATE accounts SET kind = 'shared' WHERE id = 1") }
    expect(described_class.problems(shared, backfill: true)).to include(a_string_matching(/kind/))
  end

  it "lets a joined household and a shared account pass tier 1 (it must outlive #381 and #384)" do
    db = snapshot(users: names) do
      it.execute("UPDATE memberships SET household_id = 1, role = 'member' WHERE user_id = 2")
      it.execute("UPDATE accounts SET household_id = 1 WHERE id = 2")
      it.execute("INSERT INTO accounts VALUES (10, 1, 'shared')")
    end
    expect(described_class.problems(db)).to be_empty
  end

  it "fails a snapshot with no households table (AC-6.1)" do
    path = File.join(upgrade_dir, "old.sqlite3")
    build_database(path) { it.execute_batch("CREATE TABLE users (id INTEGER PRIMARY KEY)") }
    expect(described_class.problems(open_database(path))).to eq([ "the snapshot has no households or memberships table" ])
  end
end
```
(The block form of `snapshot` runs inside `build_database`'s open connection so the examples can adjust rows; `it` in a block is Ruby 3.4's implicit parameter, the repository's Ruby 4.0.7 accepts it.)
- [ ] **5.2 Run it to see it fail** (`LoadError`), then **5.3 write** `script/upgrade/households.rb`:

```ruby
# The household facts of a snapshot of the primary database (spec 090 decision 10, ADR 0030). Tier 1 is the invariants of a
# household, true on every snapshot of every release from this one on, so it names no count: it must stay true when joined households
# and shared accounts exist (#381, #384). Tier 2 is the backfill's own facts, checked only when the old snapshot had no households.
# It reads the snapshot with SQLite directly, never through the application, as `compare.rb` does.
require_relative "compare"

module Upgrade
  module Households
    SUFFIX = "'s household".freeze

    # What is wrong with the households of +db+, as sentences naming the rule and the first row.
    #
    # @param db [SQLite3::Database] a snapshot, opened read-only
    # @param backfill [Boolean] also check the facts a backfill of a database with no households leaves (decision 10, tier 2)
    # @return [Array<String>] empty when the snapshot holds every rule checked
    def self.problems(db, backfill: false)
      tables = Compare.tables(db)
      return [ "the snapshot has no households or memberships table" ] unless (%w[households memberships] - tables).empty?

      found = invariants(db)
      found += backfilled(db) if backfill
      found
    end

    def self.invariants(db)
      found = []
      db.execute("SELECT users.id, COUNT(memberships.id) FROM users LEFT JOIN memberships ON memberships.user_id = users.id GROUP BY users.id HAVING COUNT(memberships.id) <> 1 LIMIT 3").each do |id, count|
        found << "user #{id} has #{count} memberships, not exactly one"
      end
      db.execute("SELECT id FROM households WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE household_id = households.id AND role = 'manager') LIMIT 3").flatten.each do |id|
        found << "household #{id} has no manager"
      end
      db.execute("SELECT id FROM accounts WHERE household_id IS NULL OR household_id NOT IN (SELECT id FROM households) LIMIT 3").flatten.each do |id|
        found << "account #{id} has no household"
      end
      db.execute("SELECT accounts.id FROM accounts JOIN users ON users.account_id = accounts.id JOIN memberships ON memberships.user_id = users.id WHERE accounts.kind = 'personal' AND accounts.household_id <> memberships.household_id LIMIT 3").flatten.each do |id|
        found << "account #{id} is in a household other than its user's"
      end
      found
    end
    private_class_method :invariants

    def self.backfilled(db)
      found = []
      users = db.get_first_value("SELECT COUNT(*) FROM users")
      households = db.get_first_value("SELECT COUNT(*) FROM households")
      found << "the households' count #{households} is not the users' #{users}" unless users == households
      found << "a membership's role is not manager" if db.get_first_value("SELECT COUNT(*) FROM memberships WHERE role <> 'manager'").positive?
      found << "an account's kind is not personal" if db.get_first_value("SELECT COUNT(*) FROM accounts WHERE kind <> 'personal'").positive?
      db.execute("SELECT users.id FROM users JOIN memberships ON memberships.user_id = users.id JOIN households ON households.id = memberships.household_id WHERE households.name <> substr(users.name, 1, 88) || '#{SUFFIX.gsub("'", "''")}' LIMIT 3").flatten.each do |id|
        found << "the name of user #{id}'s household is not the form of spec 090 decision 2"
      end
      found
    end
    private_class_method :backfilled
  end
end
```
- [ ] **5.4 Run the spec** (`bin/rspec spec/script/upgrade/households_spec.rb`, 8 examples, 0 failures), then **5.5 failing harness examples** in `spec/script/upgrade/harness_spec.rb`: (1) change `seeded` (line 62 area) to take `households: true` and build the household tables and the extra columns:

```ruby
  def seeded(name, versions, lots: 2000, extra: "", households: true)
    accounts = households ? "id INTEGER PRIMARY KEY, household_id INTEGER, kind TEXT DEFAULT 'personal'" : "id INTEGER PRIMARY KEY"
    users = households ? "id INTEGER PRIMARY KEY, password_digest TEXT, name TEXT, account_id INTEGER" : "id INTEGER PRIMARY KEY, password_digest TEXT"
    build_database(File.join(dir, "#{name}.sqlite3")) do |db|
      db.execute_batch(<<~SQL)
        CREATE TABLE accounts (#{accounts}); CREATE TABLE users (#{users});
        CREATE TABLE lots (id INTEGER PRIMARY KEY, account_id INTEGER); CREATE TABLE instance_settings (id INTEGER PRIMARY KEY, sign_up_open BOOLEAN);
        CREATE TABLE schema_migrations (version TEXT PRIMARY KEY);
        #{households ? "INSERT INTO accounts VALUES (1, 1, 'personal'), (2, 2, 'personal'); INSERT INTO users VALUES (1, 'x', 'Ada', 1), (2, 'y', 'Grace', 2);" : "INSERT INTO accounts VALUES (1), (2); INSERT INTO users VALUES (1, 'x'), (2, 'y');"}
        INSERT INTO instance_settings VALUES (1, 1);
        #{households ? "CREATE TABLE households (id INTEGER PRIMARY KEY, name TEXT); CREATE TABLE memberships (id INTEGER PRIMARY KEY, household_id INTEGER, user_id INTEGER, role TEXT); INSERT INTO households VALUES (1, 'Ada''s household'), (2, 'Grace''s household'); INSERT INTO memberships VALUES (1, 1, 1, 'manager'), (2, 2, 2, 'manager');" : ""}
        WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < #{lots}) INSERT INTO lots SELECT i, 1 FROM n;
        #{versions.map { "INSERT INTO schema_migrations VALUES ('#{it}');" }.join}
        #{extra}
      SQL
    end
  end
```
(2) add three examples next to "proves a clean upgrade": one where the old is `seeded(..., households: false)` and the upgraded `seeded(...)` (a backfill: expect OK and the line `households: ok`), one where the upgraded's membership is deleted by `extra: "DELETE FROM memberships WHERE id = 2;"` (expect exit 1 and output matching `AC-6.1`), one where only the `next` snapshot breaks the rule (expect `AC-6.1`). Copy the structure of the nearest existing example that makes the upgraded database differ (find it with `grep -n "differs" spec/script/upgrade/harness_spec.rb`), including how it passes `databases:` to `FakeEngine`; use `pair(...)` for the prices files as the others do. Run: they fail (the harness does not check).
- [ ] **5.6 Wire the harness.** In `script/upgrade/harness.rb` add `require_relative "households"` next to the other requires; in `compare` after the `Compare.integrity` lines:

```ruby
        problems = Households.problems(upgraded, backfill: !Compare.tables(old).include?("households"))
        raise Failure, "AC-6.1: #{problems.first(3).join("; ")}" if problems.any?
        @out.puts "households: ok#{" (backfilled)" unless Compare.tables(old).include?("households")}"
```
and in `next_release` after `Compare.seed_problems(database)`:

```ruby
        households = Households.problems(database)
        raise Failure, "AC-6.1: the next snapshot: #{households.first(3).join("; ")}" if households.any?
```
Run `bin/rspec spec/script/upgrade` (expected: all green, the three new examples included). Then in `spec/script/upgrade/seeds_spec.rb` add to the `next.rb` describe:

```ruby
    it "gives every seeded user a household of one, so households and memberships hold rows (spec 090 AC-6.4)", :aggregate_failures do
      run_seed("next.rb")
      expect([ Household.count, Membership.count ]).to eq([ User.count, User.count ])
      expect(Upgrade::SeedExceptions.load(seeds.join("../seed_exceptions.yml"), "next").entries).to be_empty
    end
```
Run `bin/rspec spec/script/upgrade/seeds_spec.rb`. `script/upgrade/expected_changes.yml` stays `changes: []` (AC-6.3: confirm with `git diff --stat -- script/upgrade/expected_changes.yml` empty).
- [ ] **5.7 Commit:** `test(upgrade): the proof checks every user's household on the upgraded, restored and next snapshots (spec 090 phase 5)`; docs of the harness in the commit body. Stop here for the phases that exist whatever the maintainer rules: **(a), (b), the models, the proof and their specs are complete and green without (c).**

---

## Phase 6: Migration (c), `accounts.household_id` NOT NULL (ruled: take it)

**Implements:** decision 5 (c) | **Satisfies:** AC-3.4, AC-3.5, AC-3.6, AC-3.7 | **Interfaces:** `accounts.household_id` is `NOT NULL`; a stragglers step, the copy and the sequence's restore are one transaction opened with enforcement already off.

**Complexity Tracking:** the maintainer ruled (c) on 2026-11-13 on two conditions: the plan review's trace below, and `bin/upgrade-smoke` from the previous release built from its tag before the push (step 7.3). The phase stays the last of the migrations and nothing in phases 1 to 5 depends on it; if the trace finds the copy unsafe, stop and ask the coordinator before the nullable fallback is taken. **Trace to do in the plan review and again before step 6.3:** read `activerecord-8.1.4.1/lib/active_record/connection_adapters/sqlite3_adapter.rb` (`alter_table`, `copy_table`, `change_column_null`, `disable_referential_integrity`) and `.../sqlite3/database_statements.rb` (transaction mode), and confirm, line by line against the code below: (1) `connection.disable_referential_integrity { connection.transaction { … } }` sets `PRAGMA foreign_keys = OFF` before the transaction opens (it is a no-op after); (2) `alter_table`'s own `disable_referential_integrity` and `transaction` nest inside ours without re-enabling enforcement or committing early; (3) the copy preserves the named checks, the foreign key to `households`, the index and the unique and partial indexes of `accounts`; (4) the children's own keys are untouched (no table rename of a child); (5) `lots → accounts` and `users → accounts` are `NO ACTION` and the eleven others `CASCADE` (`db/schema.rb`); (6) what `PRAGMA foreign_key_check` Rails runs after the copy, if any, and that it passes with the stragglers step done.

- [ ] **6.1 Failing spec** `spec/migrations/make_account_household_required_spec.rb`. Copy the model calls of `script/upgrade/seeds/next.rb` lines 33 to 60 (scanner sitting, bulk selection and marks, bulk removal, locations, deck, lot in a zone, proxy, number entry, import upload) into a `fill_every_referencing_table(user)` helper that makes a row in each of the thirteen tables:

```ruby
require "rails_helper"
require Rails.root.join("db/migrate/20261113120003_make_account_household_required")

# Spec 090 decision 5 (c), AC-3.4 to AC-3.7: the copy of accounts must lose no row of the thirteen tables that reference it, keep their
# keys, keep the id sequence, give a straggler a household, and change nothing when it fails. It commits its rows and runs through the
# Migrator OUTSIDE any example transaction (inside one, enforcement stays on and the cascades would fire).
RSpec.describe MakeAccountHouseholdRequired, :backup, :committed, type: :model do
  let(:connection) { ActiveRecord::Base.connection }
  let(:tables) { %w[bulk_removals bulk_selection_marks bulk_selections deck_proxies decks import_uploads locations lots number_entries number_entry_lines scanner_sitting_entries scanner_sittings users] }

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down = context.run(:down, 2026_11_13_120003)

  def up = context.run(:up, 2026_11_13_120003)

  def nullable? = connection.columns(:accounts).find { it.name == "household_id" }.null

  def count(table) = connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  def counts = (tables + %w[accounts households memberships sessions]).to_h { [ it, count(it) ] }

  def sequence = connection.select_value("SELECT seq FROM sqlite_sequence WHERE name = 'accounts'")

  def shapes = (%w[accounts] + tables).to_h { [ it, shape(it) ] }

  def shape(table)
    [ connection.columns(table).map { [ it.name, it.sql_type, it.null, it.default ] },
      connection.foreign_keys(table).map { [ it.to_table, it.column, it.on_delete ] }.sort_by(&:to_s),
      connection.indexes(table).map { [ it.name, it.columns, it.unique, it.where ] }.sort_by(&:to_s),
      connection.check_constraints(table).map { [ it.name, it.expression ] }.sort_by(&:to_s) ]
  end

  # One row in each of the thirteen tables, as the upgrade seed makes them (script/upgrade/seeds/next.rb).
  def fill_every_referencing_table(user)
    # the plan's implementer copies the model calls of next.rb lines 33 to 60 here, with `ada.account` as `user.account`
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
    expect { up }.not_to raise_error # a second run changes nothing
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
```
- [ ] **6.2 Run it to see it fail** (`LoadError`). **6.3 Re-trace the Rails code** as the Complexity Tracking note says, and record the six findings in the commit body. **6.4 Write the migration** `db/migrate/20261113120003_make_account_household_required.rb`:

```ruby
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
        keeping_sequence { change_column_null :accounts, :household_id, false }
        require_no_broken_keys
      end
    end
  end

  def down
    return if household_nullable?

    connection.disable_referential_integrity do
      connection.transaction do
        require_enforcement_off
        keeping_sequence { change_column_null :accounts, :household_id, true }
        require_no_broken_keys
      end
    end
  end

  private
    def household_nullable? = columns(:accounts).find { it.name == "household_id" }.null

    # The same SQL as BackfillHouseholds (migrations don't share code: a released one is never edited).
    def house_stragglers
      now = connection.quote(Time.current.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))
      loop do
        users = connection.select_rows("SELECT id, account_id FROM users WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.user_id = users.id) ORDER BY id LIMIT #{BATCH.to_i}")
        break if users.empty?

        users.each do |user_id, account_id|
          household = connection.insert("INSERT INTO households (name, created_at, updated_at) SELECT substr(name, 1, 88) || '''s household', #{now}, #{now} FROM users WHERE id = #{user_id.to_i}")
          raise ActiveRecord::MigrationError, "no household was made for user #{user_id}" unless household
          connection.execute "INSERT INTO memberships (household_id, user_id, role, created_at, updated_at) VALUES (#{household.to_i}, #{user_id.to_i}, 'manager', #{now}, #{now})"
          connection.execute "UPDATE accounts SET household_id = #{household.to_i} WHERE id = #{account_id.to_i}"
        end
      end
    end

    # Rails runs no check after a copy and, inside a transaction, enforcement can't be switched off: if either went wrong the copy would
    # have cascaded silently, so a run that finds enforcement on, or rows left pointing at accounts or households, stops and rolls back.
    def require_enforcement_off
      return if connection.select_value("PRAGMA foreign_keys").to_i.zero?

      raise ActiveRecord::MigrationError, "foreign keys are enforced inside the table copy, which would delete the collections that reference accounts; nothing was changed"
    end

    def require_no_broken_keys
      broken = connection.select_rows("PRAGMA foreign_key_check").select { |_table, _row, parent, *| %w[accounts households].include?(parent) }
      raise ActiveRecord::MigrationError, "the copy left rows pointing at accounts or households (#{broken.first(3).inspect}); nothing was changed" if broken.any?
    end

    def remove_empty_households
      connection.execute "DELETE FROM households WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.household_id = households.id) AND NOT EXISTS (SELECT 1 FROM accounts WHERE accounts.household_id = households.id)"
    end

    def refuse_accounts_nobody_can_house
      orphans = connection.select_values("SELECT id FROM accounts WHERE household_id IS NULL")
      return if orphans.empty?

      raise ActiveRecord::MigrationError, "accounts #{orphans.first(5).join(", ")} have no household and no user, so no household can be made for them; " \
        "remove them (an account is made with its user and is deleted with it) and start again; nothing was changed"
    end

    # As CreateHouseholdsAndMemberships: the copy resets accounts' row of sqlite_sequence, which the proof can't see (compare.rb skips sqlite_ tables).
    def keeping_sequence
      seq = connection.select_value("SELECT seq FROM sqlite_sequence WHERE name = 'accounts'")
      yield
      return unless seq

      connection.execute "UPDATE sqlite_sequence SET seq = #{seq.to_i} WHERE name = 'accounts' AND seq < #{seq.to_i}"
      connection.execute "INSERT INTO sqlite_sequence (name, seq) SELECT 'accounts', #{seq.to_i} WHERE NOT EXISTS (SELECT 1 FROM sqlite_sequence WHERE name = 'accounts')"
    end
end
```
- [ ] **6.5 Dump and prepare:** `bin/rails db:migrate` and `bin/rails db:test:prepare`; `git diff db/schema.rb` shows `t.integer "household_id", null: false` and the new version `2026_11_13_120003`, and no other change to `accounts`, its foreign keys or the thirteen tables (any other line is a failure of the copy: stop and report). Run `bin/rspec spec/migrations/make_account_household_required_spec.rb` (6 examples, 0 failures).
- [ ] **6.6 Make the earlier specs follow the final shape.** In `spec/migrations/create_households_and_memberships_spec.rb` and `spec/migrations/backfill_households_spec.rb`, extend the versions so a spec's down and up cover (c): in the first, `def versions = [ 2026_11_13_120001, 2026_11_13_120002, 2026_11_13_120003 ]` and add `require` lines for the other two migrations; in the second, add to the `around` an `ensure` that reruns `context.run(:up, 2026_11_13_120003)` when `accounts.household_id` is nullable after an example that goes down. In `backfill_households_spec.rb`'s batch example and its 10,000-user timing example (both insert accounts by SQL), the raw `INSERT INTO accounts` rows get a household (the timing example inserts one household first and gives every account that id, or runs with (c) down as `forget_households` does): insert a household first and pass `household_id` (the column is NOT NULL now); `forget_households` sets `household_id = NULL`, which the copy refuses: have it first `down` (c) when the column is NOT NULL (`context.run(:down, 2026_11_13_120003)`) and `up` it in `ensure`. In `spec/support/backup_helpers.rb:40` and `spec/lib/collector/backup/snapshot_spec.rb:12` insert a household and give the account its id (`INSERT INTO households (name, created_at, updated_at) VALUES ('h', ?, ?)`, then `accounts (created_at, updated_at, household_id)`). Run `bin/rspec spec/migrations spec/lib/collector/backup spec/backup_guards_spec.rb spec/backup_upgrade_spec.rb` (green).
- [ ] **6.7 Commit:** `feat(db): accounts.household_id is NOT NULL, by a copy that loses no row (spec 090 phase 6)` and `test(db): the earlier households specs follow the final shape (spec 090 phase 6)`.

---

## Phase 7: Documentation, evidence and the finish

**Implements:** FR-5, decision 11, Story 6's evidence | **Satisfies:** AC-4.2, AC-6.6, the documentation criteria (verified by reading, `verification.md`) | **Interfaces:** none.

- [ ] **7.1 `docs/architecture/tenancy-and-accounts.md`** (the source of each statement inline): in the Scope bullet "The tenant and its holder" add `Household`, `Membership` (spec 090; ADR 0030); Glossary: replace the Account entry's "created with its user and deleted with it" tail with "created with its user and deleted with it, and in a household (`accounts.household_id`) as a personal account (`accounts.kind`)", add **Household**, **Membership (manager, member)**, **Personal and shared account** entries and the note that "member" also means an admin page's non-admin (spec 090 Terms); the Tenant-owned list gains `memberships` (user-owned, instance-level) and says `households` and `memberships` carry no `account_id`, are never scoped through `Current.account` and no request names one; Invariants: change "One user per account" to the new rule ("`users.account_id` stays unique; a household is a group of accounts; a household always has a manager; a personal account is in its user's household; a household is made with its user by `User#build_account_and_household`" with `spec 090`, ADR 0030), add the cross-account reads sentence (the household tables are read by the model and the proof only); the "Deleting a user" paragraph gains the order (membership, user, account, household when empty) and the last-manager refusal; "Accepted limits" replaces "An account has exactly one user. Personal and household collections side by side will supersede that half of ADR 0017" with what exists now (a household of one for every user; the rest is #381 to #389); Sources gains spec 090, ADR 0030 and #380; Distillation log gains a row once the PR number exists (the distill-feature step writes it).
- [ ] **7.2** `.claude/rules/multi-tenancy.md`: add one line under the ✓ list: "✓ `households` and `memberships` are instance-level, not tenant-owned: read them through the user or the account, never through `Current.account`'s collections, and name none in a request." `docs/architecture/release-and-deploy.md`: in the upgrade proof's paragraph add the two-tier households check (decision 10; `Upgrade::Households`; spec 090 AC-6.1 to AC-6.5) and that `expected_changes.yml` stays empty because `compare.rb` reads only the old database's columns. `docs/releasing.md`'s Upgrade notes: the entry for this migration with its warning (an older image can't create a user after it; going back is a restore of the backup taken before; a failed third migration stops the boot and changes nothing; Kamal's old container fails sign-up for seconds). `CLAUDE.md`: in the Project Status accounts sentence add "every user belongs to a household (spec 090, ADR 0030): a household of one is made with the user and an existing instance gains one on upgrade, nothing visible yet; the shared collection and joining are the households lane (#381 to #389)". `docs/adr/0030`: Status becomes Accepted (ADR 0017's "superseded in part by 0030" status line and both ADR index rows were written with the ADR: verify them). `docs/specs/README.md`: spec 004's row gains "Superseded by 090 in part (FR-3's one user per account)" and 090's row Status "Approved".
- [ ] **7.3 Evidence for `verification.md`** (create it with the headings the other specs use; write each result as it is produced): the phase 0 and each phase's spec runs with counts; the grep and the routes diff of step 4.2; **`bin/upgrade-smoke`**: build the previous release from its tag as `.claude/memory/container-engine-colima-macos.md` says (`git archive` of `v0.3.0` into its own directory, three `--build-arg` flags for the image: `README.md`, Building from source), build the code under test the same way, then `bin/upgrade-smoke <previous-image> <current-image>` with `TMPDIR` under the worktree and `/opt/homebrew/bin` appended to `PATH`; expected: the run ends `OK: v0.3.0` and prints `households: ok (backfilled)` for the upgraded and the restored snapshot and `households: ok` for the next one. **Run it on the final commit that will be pushed: after 7.4 and after the implementation review's fixes of 7.5; if code changes after a run, run it again, and record the SHA it ran on in `verification.md`.** **Ask the coordinator for the container engine and a slot before this step.** A failure is read, not re-run blindly (`.claude/memory/reproduce-ci-with-seed.md` for CI).
- [ ] **7.4 `bin/ci checks`** (a documentation-and-code branch: it runs RuboCop, YARD, the comment ratchet, Brakeman, bundler-audit, importmap audit and the migration guard): expected green; the comment ratchet needs a summary on each new public method (the models and `Upgrade::Households` have them). Fix and re-run.
- [ ] **7.5 The implementation review** (`sdd-review` Mode B, read-only, Opus 5.5) recorded in `verification.md` under `## Implementation review` with the verdict first; then `sdd-superpowers:session-wrap` and `distill-feature` (digest to the coordinator before commit); then one slot for the one full `bin/ci`; push; draft PR closing #380; CI green; `gh pr ready`; `gh pr edit --add-assignee @me`; `worker_done`.

## Self-review

- **FR coverage:** FR-1 (phases 1, 2), FR-2 (phase 2), FR-3 (phases 1, 3, 6), FR-4 (phase 5), FR-5 (phases 4, 7).
- **AC coverage:** AC-1.1 to 1.7 (2.2, 2.3, 3.1); AC-2.1 to 2.9 (1.1, 2.2); AC-3.1 to 3.3, 3.8 (3.1); AC-3.4 to 3.7 (1.1, 6.1); AC-4.1, 4.3, 4.5 (4.1, 4.6); AC-4.2 (4.2); AC-4.4 (2.2, 2.3); AC-5.1 to 5.4 (4.3 to 4.5); AC-6.1 to 6.5 (5.1 to 5.6); AC-6.6 (7.3). AC-3.4's "empty database" half is 3.1's last example.
- **Names:** `Household.name_for`, `Membership#last_manager?`, `Upgrade::Households.problems(db, backfill:)`, `expect_household_invariants!`, `BackfillHouseholds::BATCH` are used with the same signatures wherever they appear.
