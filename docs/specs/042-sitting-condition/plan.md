# Implementation Plan: Set a Condition for a Scanner Sitting

**Spec:** docs/specs/042-sitting-condition/spec.md (v0.3.1, approved under the maintainer's delegation on 2026-11-06 after three independent reviews)
**Status:** Draft, for the maintainer's approval
**Decisions:** none new. No ADR: the condition on the sitting follows spec 040's decision 2 (the place on the sitting) and its migration pattern. The scanner's vocabulary is the one `MTG::Reading::COLLECTIBLE_TYPE` already names in the scanner's controllers (spec decision 5).
**Created:** 2026-11-06 (on `origin/main` after spec 040, #172)
**Model for this plan:** spec 040's retired plan (`git show a5c97027375d8309dd2c14acb64840e7779345b5^:docs/specs/040-sitting-into-location/plan.md`) and its merged code.

## Global Constraints

Copied from the spec; each applies to every task.

- One pull request, one outcome: a sitting's condition. No language (#58), price or quantity; no JavaScript change; no export change (Non-Goals, decision 6).
- **The condition lives on `scanner_sittings.condition`** (a nullable string holding a vocabulary key, decision 4), read on the server inside each add's transaction (FR-2). An add's request carries nothing new.
- **Not specified stays real:** a sitting with no condition adds exactly as today (AC-1.5).
- **Names:** `Scanner::Sitting`, `Scanner::SittingEntry`, the partials `_sitting`, `_sitting_entry`, `_picker`, `_summary` and `ScannersHelper` never name a collectible type (FR-3, `spec/scanner_sitting_core_spec.rb`, Task 4). The scale comes from **`Catalog.collecting_for(MTG::Reading::COLLECTIBLE_TYPE).conditions`**, written once, in the `ScannerSitting` concern's private `scanner_conditions` (decision 5); the controllers that include the concern (`Scanner::SittingsController`, `ScannersController`, `Scanner::Sittings::EntriesController`, the undo and measurement controllers) may name the type, the model and the views receive the Hash (`{ "near_mint" => [ "Near mint", "NM" ], … }`) as the strict local `conditions`. At an add the model reads the printing's own vocabulary (`Catalog.collecting_for(printing.collectible_type)`), as `Scanner::Sitting.finish_offered?` does.
- A submitted `condition` is checked against `scanner_conditions.key?`; `location_id` is resolved through `Current.account.locations`. Both are checked before anything is written. `params.expect` only, no sitting id, no account id, no `permit!` (FR-1, NFR Security, `.claude/rules/security.md`).
- The migration copies no table and loses no entry: `disable_ddl_transaction!`, guarded steps (NFR Migration, AC-6.1, AC-6.2). No released migration is edited (`ruby script/upgrade/guard.rb`).
- UI uses only design-system tokens and `c-*` classes, no new rule unless Task 9 proves one is needed. Read `docs/design-system/README.md`, `components/Form.md`, `components/ChoicePage.md` and `components/Scanner.md` (the `collector-design-system` skill) before Task 6.
- Pages work at 390px and at desktop width with the keyboard alone; no script is added (AC-7.1).
- **Running specs.** The implementer runs only the spec files each task names, one `bin/rspec` call at a time. **Never `bin/ci`, never a bare `bin/rspec`, never the whole suite** (the test database is shared; the full suite runs only in a CI slot the supervisor obtains, Task 13). `bin/rubocop` on the touched files and `bin/brakeman` are fine.
- **After `bin/rails db:migrate`** (Task 1): `git status`; only `db/schema.rb` may change. Restore the rest: `git checkout -- db/cache_schema.rb db/queue_schema.rb db/cable_schema.rb`. `Gemfile.lock` stays uncommitted and unstaged throughout (it is already modified in the worktree).
- TDD is the hard gate: a failing spec precedes every implementation step. Prose documents are verified by reading and recorded in `verification.md`, never by RSpec (`.claude/rules/testing.md`).
- Small commits: one Conventional Commit per task (the tasks say which), staged by file name, each ending with the attribution trailer of the session. No commit message or command contains the word "push" after "git".

## Goal

A collector sets a condition for the scanner's sitting in the one control that already holds the place, changes it mid-sitting, and every card added in it goes into the lot of that printing, finish, condition and place.

## Scope Check and Gates

- **Simplicity (at most 3 components):** (1) *the condition on the sitting*: the column, `Scanner::Sitting.choose!` and the add; (2) *the control*: `Scanner::SittingsController#update`, `_picker`, the panel copy; (3) *the condition named*: the add notice and the entry line.
- **Anti-abstraction:** no new service or model. `Sitting.choose!` replaces spec 040's `Sitting.place!` as the one class method that opens, changes, clears or deletes a sitting by its choices; `Sitting.add!` stays the one for adds. The picker stays one partial, used by the panel, the no-sitting state and the summary. One helper lists the sitting's choices as words (`sitting_choices`), so no view holds logic.
- **Integration-first:** the migration spec (Task 1) precedes the model; model specs precede the controller; request specs precede each view and controller change; the system spec (Task 9) proves the flow in a browser.

## Areas and Supersessions

- **Area docs to change** (`.claude/rules/documentation.md`, Task 12): `collection-and-lots.md` (the scope line, "Only some ways of adding choose a place", Sources), `data-portability.md` (the working-state invariant, Sources). Source inline for each statement. The distillation log is the `distill-feature` step's, not this plan's.
- **Design system:** `docs/design-system/components/Scanner.md` (Task 11).
- **Supersessions** are already written in the spec's Supersedes section and in `docs/specs/README.md` (rows 009, 040 and 042 name each other); Task 12 only checks them by reading. Neither old spec is edited.
- **Existing expectations this change makes false** are listed in the task that changes them (Tasks 6, 7, 8, 9, 10); an example is changed in the task that breaks it, never left red.

## Open Items

| # | Item | Ruling in this plan | Source |
|---|---|---|---|
| P1 | Whether the control's fieldset needs CSS | `fieldset.c-choices` (spec 006's flex column, no border, legend spacing) holds the legend and the two `c-field`s, stacked, so no new rule. Task 9 checks it at 390px and desktop; only if a control overflows does a rule go in: `.c-scanner__place .c-choices { min-width: 0; }` in `additions.css`, documented in `Scanner.md` | AC-7.1, Design system NFR |
| P2 | `choose!`'s keyword shape | `choose!(account:, condition: <key or nil>, location: <Location or nil>)`: a key left out is kept, a key given as `nil` clears. One call writes both, after the controller checked both | decisions 4, 8 |
| P3 | Where the status line learns whether the account has locations | The concern memoises `account_locations` (the list `sitting_locals` already loads once per request), so the status message adds no query | decision 3 |
| P4 | An add that opens a sitting and is then refused for its condition | Cannot happen through the page (a sitting's condition is set first); in the model, `Refused` is raised inside the transaction, so a sitting that this add just opened is rolled back with it. Nothing is recorded (AC-4.5) | decision 5 |

## Task 1: The column (AC-6.1, AC-6.2, NFR Migration)

**Commit:** `feat(scanner): add a condition to the sitting`
**Files:** `db/migrate/20261106200001_add_condition_to_scanner_sittings.rb`, `spec/migrations/add_condition_to_scanner_sittings_spec.rb`, `db/schema.rb`.
**Covers:** AC-6.1, AC-6.2, NFR Migration.

1. **Red.** `spec/migrations/add_condition_to_scanner_sittings_spec.rb`, on the model of `spec/migrations/add_location_to_scanner_sittings_spec.rb`:

```ruby
require "rails_helper"
require Rails.root.join("db/migrate/20261106200001_add_condition_to_scanner_sittings")

# Spec 042 AC-6.1, AC-6.2: the migration changes no sitting and loses no entry, going up and down, whatever the sitting
# holds. It runs outside a transaction (disable_ddl_transaction!), so the examples commit their rows (:committed empties the
# database around them). Down and up go through the Migrator (MigrationContext#run), which wraps a migration in a
# transaction unless it turns that off, exactly as db:rollback does (spec/migrations/add_location_to_scanner_sittings_spec.rb).
RSpec.describe AddConditionToScannerSittings, :backup, :committed, type: :model do
  let(:account) { create(:user).account }

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up unless Scanner::Sitting.connection.column_exists?(:scanner_sittings, :condition)
    Scanner::Sitting.reset_column_information
    Lot.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def migration = described_class.new

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down = context.run(:down, 2026_11_06_200001)

  def up = context.run(:up, 2026_11_06_200001)

  def connection = Scanner::Sitting.connection

  def sitting_rows = connection.select_rows("SELECT id, account_id, location_id, created_at, updated_at FROM scanner_sittings ORDER BY id")

  def entry_rows = connection.select_rows("SELECT id, scanner_sitting_id, account_id, catalog_entry_id, lot_id, finish, reading_key, undone_at FROM scanner_sitting_entries ORDER BY id")

  # The table copy of a rollback must keep the foreign keys (accounts cascade, locations nullify) and the unique account index.
  def expect_table_intact
    keys = connection.foreign_keys(:scanner_sittings)
    expect(keys.find { |key| key.to_table == "locations" }).to have_attributes(on_delete: :nullify)
    expect(keys.find { |key| key.to_table == "accounts" }).to have_attributes(on_delete: :cascade)
    expect(connection.index_exists?(:scanner_sittings, :account_id, unique: true)).to be(true)
    expect(connection.index_exists?(:scanner_sittings, :location_id)).to be(true)
  end

  def fill
    lot = owned_printing("Opt", account:, quantity: 2, finish: "foil")
    Scanner::Sitting.add!(account:, printing: lot.entry, finish: "foil", reading_key: SecureRandom.hex(16))
    Scanner::Sitting.add!(account:, printing: lot.entry, finish: "foil", reading_key: SecureRandom.hex(16)).entry.undo!
    connection.execute("UPDATE scanner_sittings SET location_id = #{create(:location, account:).id}") # Safe: an integer id
  end

  it "turns the migration's transaction off, so a rollback rebuilds the sittings with foreign keys off" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "keeps every sitting, its place and every entry going down and up, and leaves no sitting a condition (AC-6.1)", :aggregate_failures do
    fill
    before = [ sitting_rows, entry_rows ]
    expect(entry_rows.map { |row| row[4] }.compact).not_to be_empty
    expect(before.first.map { |row| row[2] }).to all(be_present)

    down
    expect(connection.column_exists?(:scanner_sittings, :condition)).to be(false)
    expect([ sitting_rows, entry_rows ]).to eq(before)
    expect_table_intact

    up
    expect(connection.column_exists?(:scanner_sittings, :condition)).to be(true)
    expect([ sitting_rows, entry_rows ]).to eq(before)
    expect_table_intact
    expect(connection.select_values("SELECT condition FROM scanner_sittings")).to all(be_nil)
  end

  it "goes down while a sitting holds a condition, keeping the sitting, its place and its entries (AC-6.2)", :aggregate_failures do
    fill
    connection.execute("UPDATE scanner_sittings SET condition = 'near_mint'")
    before = [ sitting_rows, entry_rows ]

    down
    expect(connection.column_exists?(:scanner_sittings, :condition)).to be(false)
    expect([ sitting_rows, entry_rows ]).to eq(before)
    expect_table_intact
  end

  it "runs twice without harm, the guard skipping a column that is already there" do
    expect { migration.migrate(:up) }.not_to raise_error
    expect(connection.columns(:scanner_sittings).count { |column| column.name == "condition" }).to eq(1)
  end
end
```

   `owned_printing` is the helper spec 040's migration spec calls (a support helper; check `git grep -n "def owned_printing" spec/support` and use the same one). Run `bin/rspec spec/migrations/add_condition_to_scanner_sittings_spec.rb`: it fails (no migration file to require).

2. **Green.** The migration:

```ruby
# Lets a scanner sitting hold a condition for its adds (spec 042 decision 4). The sitting is working state, so every existing
# sitting has none.
class AddConditionToScannerSittings < ActiveRecord::Migration[8.1]
  # SQLite copies a table to remove a column from it, and with foreign keys enforced the copy's DROP TABLE would cascade-delete
  # the sitting's entries. Rails turns enforcement off for the copy only outside a transaction, so this migration runs without
  # one, and each step is guarded so a run that stopped between steps is finished by the next
  # (db/migrate/20261105100001_add_location_to_scanner_sittings.rb).
  disable_ddl_transaction!

  def up
    add_column :scanner_sittings, :condition, :string unless column_exists?(:scanner_sittings, :condition) # a nullable ADD COLUMN copies no table
  end

  # The condition is working state, so a rollback drops it whatever it holds.
  def down
    remove_column :scanner_sittings, :condition if column_exists?(:scanner_sittings, :condition)
  end
end
```

3. `bin/rails db:migrate`. Then `git status` and `git diff db/schema.rb`: the diff is the `version:` line and `t.string "condition"` in `scanner_sittings` (after `location_id`) and nothing else; restore the other three schema files with `git checkout -- db/cache_schema.rb db/queue_schema.rb db/cable_schema.rb`. Run `ruby script/upgrade/guard.rb` (no released migration touched).
4. `bin/rspec spec/migrations/add_condition_to_scanner_sittings_spec.rb spec/migrations/add_location_to_scanner_sittings_spec.rb` (the older migration's spec runs its own `down` with the new column present; it must stay green). `bin/rubocop db/migrate/20261106200001_add_condition_to_scanner_sittings.rb spec/migrations/add_condition_to_scanner_sittings_spec.rb`.
5. Commit: the migration, its spec, `db/schema.rb`.

## Task 2: The sitting's choices, written together (AC-1.2, AC-1.8, AC-2.4, AC-3.3, FR-1)

**Commit:** `feat(scanner): a sitting holds its choices, set together`
**Files:** `app/models/scanner/sitting.rb`, `app/controllers/scanner/sittings_controller.rb` (the one call), `spec/models/scanner/sitting_spec.rb`, `spec/requests/scanner/sitting_entries_spec.rb`, `spec/requests/scanner/sittings_spec.rb`, `spec/system/scanner_sitting_spec.rb` (the `place!` callers only).
**Covers:** AC-1.2, AC-1.8, AC-2.4, AC-3.3, FR-1 (the model's half).

1. **Red.** In `spec/models/scanner/sitting_spec.rb` replace the `describe ".place!"` block with `.choose!`, and change the `place` helpers elsewhere in the file (`open_in` at the `.add! into the sitting's place` block, lines 191, 221 and 224) to `described_class.choose!(account:, location: …)`:

```ruby
describe ".choose!" do
  let(:blue) { create(:location, account:, name: "Blue binder") }
  let(:long_box) { create(:location, account:, name: "Long box") }

  def choose(**choices) = described_class.choose!(account:, **choices)

  it "opens a sitting holding the condition, or the place, when none is open (AC-1.2)", :aggregate_failures do
    expect(choose(condition: "near_mint")).to have_attributes(account:, condition: "near_mint", location: nil, persisted?: true)
    expect(described_class.count).to eq(1)
    described_class.destroy_all
    expect(choose(location: blue)).to have_attributes(condition: nil, location: blue, persisted?: true)
  end

  it "keeps the choice it isn't given: a condition alone keeps the place, a place alone keeps the condition (AC-2.4)", :aggregate_failures do
    choose(condition: "near_mint", location: blue)
    expect(choose(condition: "lightly_played")).to have_attributes(condition: "lightly_played", location: blue)
    expect(choose(location: long_box)).to have_attributes(condition: "lightly_played", location: long_box)
    expect(described_class.where(account:).count).to eq(1)
  end

  it "clears a choice given as nil and keeps a sitting that holds a card (AC-1.8)", :aggregate_failures do
    choose(condition: "near_mint", location: blue)
    add
    expect(choose(condition: nil, location: nil)).to have_attributes(condition: nil, location: nil, persisted?: true)
    expect(described_class.find_by!(account:).entries.count).to eq(1)
  end

  it "keeps a sitting with no card while it still holds one choice (AC-1.8)", :aggregate_failures do
    choose(condition: "near_mint", location: blue)
    expect(choose(location: nil)).to have_attributes(condition: "near_mint", location: nil, persisted?: true)
    expect(choose(location: blue, condition: nil)).to have_attributes(condition: nil, location: blue, persisted?: true)
  end

  it "deletes a sitting with no kept card, no condition and no place, whether none was added or all were undone (AC-1.8)", :aggregate_failures do
    choose(condition: "near_mint")
    expect(choose(condition: nil)).to be_destroyed
    expect(described_class.count).to eq(0)

    choose(condition: "near_mint", location: blue)
    add.entry.undo!
    choose(condition: nil, location: nil)
    expect([ described_class.count, Scanner::SittingEntry.count ]).to eq([ 0, 0 ])
  end

  it "does nothing when clearing with no sitting open, and opens none" do
    expect(choose(condition: nil, location: nil)).to be_nil
    expect(described_class.count).to eq(0)
  end

  it "needs at least one of the two choices and no other key", :aggregate_failures do
    expect { described_class.choose!(account:) }.to raise_error(ArgumentError)
    expect { described_class.choose!(account:, language: "en") }.to raise_error(ArgumentError)
  end

  it "changes only the given account's sitting" do
    other = create(:user).account
    described_class.choose!(account: other, condition: "damaged")
    choose(condition: "near_mint")
    expect(described_class.where(account: other).sole.condition).to eq("damaged")
  end
end
```

   Change `describe "#pointless? (spec 040 plan P1)"` and `"#drop_if_pointless! …"` examples to add the condition rule:

```ruby
describe "#pointless? (spec 040 plan P1, spec 042 AC-3.3)" do
  it "is true only for a sitting with no entries at all, no place and no condition", :aggregate_failures do
    sitting = described_class.create!(account:)
    expect(sitting).to be_pointless
    sitting.update!(location: create(:location, account:))
    expect(sitting).not_to be_pointless
    sitting.update!(location: nil, condition: "near_mint")
    expect(sitting).not_to be_pointless
    sitting.update!(condition: nil)
    add.entry.undo!
    expect(sitting.reload).not_to be_pointless
  end
end
```

   Replace the `place!` calls in `spec/requests/scanner/sitting_entries_spec.rb:83` (`def place(location) = Scanner::Sitting.choose!(account: user.account, location:)`), `spec/requests/scanner/sittings_spec.rb:269` (`Scanner::Sitting.choose!(account: other, location: create(:location, account: other))`) and `spec/system/scanner_sitting_spec.rb:85,111` (`Scanner::Sitting.choose!(account: user.account, location: …)`). Run `bin/rspec spec/models/scanner/sitting_spec.rb`: the `.choose!` and `#pointless?` examples fail.

2. **Green.** `app/models/scanner/sitting.rb`: replace `place!` and `pointless?`:

```ruby
CHOICES = %i[condition location].freeze

# Sets, changes or clears the account's sitting choices (spec 042 decisions 4, 8; spec 040 decision 2): a condition (a
# vocabulary key the caller has checked) and a place. A choice left out is kept; one given as nil is cleared. Choosing opens
# a sitting as an add does; a sitting left with no kept card, no condition and no place is deleted, so the page is as before
# any sitting (AC-1.8), the check and the delete in one write transaction. Returns the sitting (destroyed when it was
# deleted), or nil when there was none to clear.
def self.choose!(account:, **choices)
  raise ArgumentError, "give :condition, :location or both" if choices.empty? || (choices.keys - CHOICES).any?

  transaction do
    sitting = find_by(account:)
    next if sitting.nil? && choices.values.none? # clearing with none open opens none

    sitting ||= create!(account:)
    sitting.update!(choices)
    sitting.destroy! if sitting.condition.nil? && sitting.location_id.nil? && !sitting.entries.kept.exists?
    sitting
  end
end

# A sitting with no entries at all, no place and no condition says nothing, so the scanner drops it before it renders (spec 040
# AC-3.2, spec 042 AC-3.3): what a removed location leaves of a sitting that was only opened by choosing that place.
def pointless? = location_id.nil? && condition.nil? && !entries.exists?
```

   `app/controllers/scanner/sittings_controller.rb` still calls `place!`: change that one call to `Scanner::Sitting.choose!(account: Current.account, location:)` so the controller keeps working until Task 7. Update the class comment's first lines of `Scanner::Sitting` only if they mention places only.

3. `bin/rspec spec/models/scanner/sitting_spec.rb spec/requests/scanner/sittings_spec.rb spec/requests/scanner/sitting_entries_spec.rb spec/system/scanner_sitting_spec.rb`; `bin/rubocop` on the touched files. All green (the request specs still exercise the place, which `choose!` keeps).
4. Commit.

## Task 3: Adding with the sitting's condition (AC-1.3 to AC-1.6, AC-4.4, AC-4.5, FR-2)

**Commit:** `feat(scanner): a sitting adds with its condition`
**Files:** `app/models/scanner/sitting.rb`, `spec/models/scanner/sitting_spec.rb`, new `spec/support/other_collecting.rb`.
**Covers:** AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-4.4, AC-4.5 (model), FR-2.

1. **Red.** New `spec/support/other_collecting.rb` (a second vocabulary, in the manner of `:other_catalog`, `spec/support/fake_catalog_source.rb`):

```ruby
# A second collecting vocabulary, registered for one example with :other_collecting as the type "other" (spec 042 AC-4.5). Its
# scale has one condition, "mint", which the scanner's own vocabulary doesn't know.
module OtherCollecting
  CONDITIONS = { "mint" => [ "Mint", "M" ] }.freeze

  def self.conditions = CONDITIONS
  def self.special_finishes = []
  def self.finishes_for(_entry) = []
  def self.finish_label(finish) = finish.to_s.humanize
end

RSpec.configure do |config|
  config.around(:each, :other_collecting) do |example|
    Catalog.collecting["other"] = "OtherCollecting"
    example.run
  ensure
    Catalog.collecting.delete("other")
  end
end
```

   In `spec/models/scanner/sitting_spec.rb` add, after the `.add! into the sitting's place` block:

```ruby
describe ".add! with the sitting's condition (spec 042)" do
  let(:blue) { create(:location, account:, name: "Blue binder") }

  def choose(**choices) = described_class.choose!(account:, **choices)

  it "adds into the lot of that printing, finish and condition, leaving the others alone (AC-1.3)", :aggregate_failures do
    unspecified = create(:lot, account:, entry: printing, finish: "foil", quantity: 2)
    lightly = create(:lot, account:, entry: printing, finish: "foil", condition: "lightly_played", quantity: 4)
    choose(condition: "near_mint")
    added = add
    expect(added.entry.lot).to have_attributes(condition: "near_mint", location: nil, quantity: 1, finish: "foil", price_paid_cents: nil)
    expect([ unspecified.reload.quantity, lightly.reload.quantity ]).to eq([ 2, 4 ])
  end

  it "merges into a lot already of that condition (AC-1.3)", :aggregate_failures do
    there = create(:lot, account:, entry: printing, finish: "foil", condition: "near_mint", quantity: 3)
    choose(condition: "near_mint")
    add
    expect(there.reload.quantity).to eq(4)
    expect(account.lots.count).to eq(1)
  end

  it "adds with the condition and the place together (AC-1.4)" do
    choose(condition: "near_mint", location: blue)
    expect(add.entry.lot).to have_attributes(condition: "near_mint", location: blue, finish: "foil")
  end

  it "joins the lot with no condition when the sitting has none (AC-1.5)", :aggregate_failures do
    choose(location: blue)
    expect(add.entry.lot.condition).to be_nil
    choose(condition: "near_mint")
    choose(condition: nil)
    expect(add(key: "b" * 32).entry.lot).to have_attributes(condition: nil, quantity: 2)
  end

  it "refuses at the cap of the lot of that condition, while Not specified takes the card (AC-1.6)", :aggregate_failures do
    create(:lot, account:, entry: printing, finish: "foil", condition: "near_mint", quantity: Lot::MAX_QUANTITY)
    choose(condition: "near_mint")
    expect { add }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Scanner::SittingEntry.count).to eq(0)
    choose(condition: nil)
    expect(add.entry.lot.condition).to be_nil
  end

  it "answers a replayed key with its entry, whatever the condition is now (AC-4.4)", :aggregate_failures do
    choose(condition: "near_mint")
    first = add
    choose(condition: "lightly_played")
    again = add
    expect(again).to have_attributes(replayed: true, entry: first.entry)
    expect(again.entry.lot.condition).to eq("near_mint")
    expect(account.lots.sum(:quantity)).to eq(1)
  end

  it "refuses a condition the printing's vocabulary doesn't know as :condition, never as the cap, recording nothing (AC-4.5)", :other_collecting, :aggregate_failures do
    other = create(:catalog_entry, collectible_type: "other")
    choose(condition: "near_mint")
    expect(refusal { add(finish: nil, to: other) }).to eq(:condition)
    expect([ account.lots.count, Scanner::SittingEntry.count ]).to eq([ 0, 0 ])
    expect(described_class.find_by!(account:).condition).to eq("near_mint")
  end

  it "answers a replay before it checks the condition (decision 5)", :other_collecting, :aggregate_failures do
    choose(condition: "near_mint")
    first = add
    again = add(finish: nil, to: create(:catalog_entry, collectible_type: "other"))
    expect(again).to have_attributes(replayed: true, entry: first.entry)
  end
end
```

   Run `bin/rspec spec/models/scanner/sitting_spec.rb`: the new examples fail (the add ignores the condition).

2. **Green.** In `Scanner::Sitting`: add `:condition` to the `Refused` comment ("`:key`, `:unavailable`, `:finish` or `:condition`"), change `add!`'s transaction, and add `condition_known?`, a class method defined at class level after `add!`'s closing `end`, never inside `add!`:

```ruby
transaction do
  sitting = find_or_create_by!(account:)
  existing = sitting.entries.find_by(reading_key:)
  next Added.new(entry: existing, replayed: true) if existing
  # A condition the printing's vocabulary doesn't know is refused here, after the replay check (a replayed key answers as AC-1.5
  # says whatever the sitting holds) and before Lot.add!, whose RecordInvalid the entries controller reports as the 9,999 cap
  # (spec 042 decision 5, AC-4.5). Raising rolls back a sitting this add just opened.
  raise Refused, :condition unless condition_known?(printing, sitting.condition)

  # The place and the condition are read in the transaction (spec 040 FR-2, spec 042 FR-2).
  lot = Lot.add!(account:, entry: printing, finish:, condition: sitting.condition, location: sitting.location)
  Added.new(entry: sitting.entries.create!(account:, printing:, lot:, finish:, reading_key:), replayed: false)
end

# No condition is always known; one is known when the printing's vocabulary lists it (decision 5).
def self.condition_known?(printing, condition)
  condition.nil? || Catalog.collecting_for(printing.collectible_type).conditions.key?(condition)
end
```

   Update the comment above `add!` to say it adds "into the sitting's condition and place".
3. `bin/rspec spec/models/scanner/sitting_spec.rb spec/requests/scanner/sitting_entries_spec.rb`; `bin/rubocop` on touched files.
4. Commit.

## Task 4: The core guard (FR-3)

**Commit:** `test(scanner): guard the sitting's core files against naming a collectible`
**Files:** new `spec/scanner_sitting_core_spec.rb`.
**Covers:** FR-3 (the guard).

1. The guard passes today (no file names a type), so prove it can fail: write the spec below, run it green, then add the word `MTG` in a comment of `app/helpers/scanners_helper.rb`, run it red, and remove the comment. The same check runs on every later task's files.

```ruby
require "rails_helper"

# Spec 042 FR-3: the scanner sitting is core code. Its models, partials and helper never name a collectible type or a source;
# the scale comes to them from the scanner's controllers (the ScannerSitting concern) or from the printing's own vocabulary.
# The pattern is spec 026's (spec/number_entry_core_spec.rb) without its finish words, because the helper's comments quote
# copy such as "Foil".
RSpec.describe "The scanner sitting's code" do
  let(:files) do
    Rails.root.glob("{app/models/scanner/sitting{,_entry}.rb,app/views/scanners/_{sitting,sitting_entry,picker,summary}.html.erb," \
      "app/helpers/scanners_helper.rb}")
  end

  it "covers every file of the feature" do
    expect(files.size).to eq(7)
  end

  it "never names a collectible type or a source" do
    offenders = files.select { |file| file.read.match?(/\b(mtg|scryfall|magic)\b/i) }
    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
```

2. `bin/rspec spec/scanner_sitting_core_spec.rb`; `bin/rubocop spec/scanner_sitting_core_spec.rb`. Commit.

## Task 5: The scale reaches the views; the copy helpers (decision 3, 5)

**Commit:** `feat(scanner): hand the sitting views the scanner's scale`
**Files:** `app/controllers/concerns/scanner_sitting.rb`, `app/helpers/scanners_helper.rb`, `app/views/scanners/_scanner.html.erb`, `_sitting.html.erb`, `_summary.html.erb` (signatures and calls only), `spec/helpers/scanners_helper_spec.rb`.
**Covers:** decision 5 (where the vocabulary comes from), decision 3's labels, NFR cost (no query per entry).

1. **Red.** In `spec/helpers/scanners_helper_spec.rb`:

```ruby
describe "the condition in the sitting's copy (spec 042 decision 3)" do
  let(:printing) { create(:mtg_printing, entry: create(:catalog_entry, name: "Psychic Frog", set: create(:catalog_set, code: "mh3"), number: "47")).entry }
  let(:conditions) { Catalog.collecting_for("mtg").conditions }

  it "gives a condition's short label from the printing's vocabulary, and nil for none or an unknown key", :aggregate_failures do
    expect(helper.scanner_condition(printing, "near_mint")).to eq("NM")
    expect(helper.scanner_condition(printing, nil)).to be_nil
    expect(helper.scanner_condition(printing, "mint")).to be_nil
  end

  it "puts the condition after the finish inside the copy's parentheses, and leaves each out when unspecified", :aggregate_failures do
    expect(helper.scanner_copy(printing, "foil", "near_mint")).to eq("Psychic Frog (MH3 · 47, Foil, NM)")
    expect(helper.scanner_copy(printing, nil, "near_mint")).to eq("Psychic Frog (MH3 · 47, NM)")
    expect(helper.scanner_copy(printing, "foil")).to eq("Psychic Frog (MH3 · 47, Foil)")
  end

  it "lists the sitting's choices as words, only those that are set", :aggregate_failures do
    place = build_stubbed(:location, name: "Blue binder")
    expect(helper.sitting_choices(Scanner::Sitting.new(condition: "near_mint", location: place), conditions)).to eq([ "Near mint", "in Blue binder" ])
    expect(helper.sitting_choices(Scanner::Sitting.new(condition: "near_mint"), conditions)).to eq([ "Near mint" ])
    expect(helper.sitting_choices(Scanner::Sitting.new(location: place), conditions)).to eq([ "in Blue binder" ])
    expect(helper.sitting_choices(Scanner::Sitting.new, conditions)).to eq([])
  end
end
```

   Run `bin/rspec spec/helpers/scanners_helper_spec.rb`: red (no such helpers).

2. **Green.** `app/helpers/scanners_helper.rb`:

```ruby
# "NM": a lot's or a sitting's condition as its short label, from the vocabulary of the printing's own collectible (spec 042
# decision 3); nil when none is set or the vocabulary doesn't list it. No query: the vocabulary is a constant.
def scanner_condition(printing, condition) = condition && Catalog.collecting_for(printing.collectible_type).conditions[condition]&.last

# "Tome Shredder (STX · 117, Foil, NM)": a scanner add's card, printing, finish and, when given, condition (spec 009 AC-1.3,
# spec 042 decision 3). The Undo announcement and the accessible names call it without a condition (spec 042 decision 3).
def scanner_copy(printing, finish, condition = nil)
  "#{printing.name} (#{[ set_number(printing), scanner_finish(printing, finish), scanner_condition(printing, condition) ].compact.join(", ")})"
end

# The sitting's choices as words, only those that are set: "Near mint", "in Blue binder" (spec 042 decision 3). The scale is
# the Hash the caller gives (condition key => [ long label, short label ]).
def sitting_choices(sitting, conditions)
  [ sitting.condition && conditions.dig(sitting.condition, 0), ("in #{sitting.location.name}" if sitting.location) ].compact
end
```

   (Replace the existing one-line `scanner_copy` and its comment.) `app/controllers/concerns/scanner_sitting.rb`: add the scale and the memoised locations, and hand the scale to the views:

```ruby
def sitting_locals(sitting = Current.account.scanner_sitting)
  { sitting:, entries: sitting ? sitting.kept_entries.to_a : [], conditions: scanner_conditions, locations: account_locations,
    added_any: sitting.present? && sitting.entries.exists? }
end

# The scale of the collectible the scanner reads (spec 042 decision 5): condition key => [ long label, short label ]. The one
# place the scanner's controllers name that type for the sitting's choices; the model and the views are handed what they need.
def scanner_conditions = Catalog.collecting_for(MTG::Reading::COLLECTIBLE_TYPE).conditions

# The account's locations in the order of the locations page, loaded once per request.
def account_locations = @account_locations ||= Current.account.locations.ordered.to_a
```

   Add `conditions:` to the strict locals: `_scanner.html.erb` `<%# locals: (sitting:, entries:, conditions:, locations:, added_any:, summary: nil) %>` and its two renders (`"scanners/summary", count: summary, conditions:, locations:` and `"scanners/sitting", sitting:, entries:, conditions:, locations:, added_any:`); `_sitting.html.erb` `<%# locals: (sitting:, entries:, conditions:, locations:, added_any:) %>`; `_summary.html.erb` `<%# locals: (count:, conditions:, locations:) %>` (both unused for now; Task 6 uses them). The pickers' calls change in Task 6. `show.html.erb` and the measurement page pass `**@sitting`, which now carries `conditions`.
3. `bin/rspec spec/helpers/scanners_helper_spec.rb spec/scanner_sitting_core_spec.rb spec/requests/scanners_spec.rb spec/requests/scanner/sittings_spec.rb spec/requests/scanner/sitting_entries_spec.rb spec/requests/scanner/measurements_spec.rb`; `bin/rubocop` on touched Ruby files. Green (no visible change yet).
4. Commit.

## Task 6: The panel: one control for every collector (AC-1.1, AC-1.2 (panel), AC-1.7, AC-2.3, AC-3.1 to AC-3.3, AC-5.2, AC-7.1, decision 3)

**Commit:** `feat(scanner): the sitting's control and its condition on the panel`
**Files:** `app/views/scanners/_picker.html.erb`, `_sitting.html.erb`, `_sitting_entry.html.erb`, `_summary.html.erb`, `spec/system/scanner_sitting_spec.rb` (relabel and the `set_sitting` helper), `spec/requests/scanner/sittings_spec.rb`, `spec/requests/scanner/sitting_entries_spec.rb`, `spec/requests/scanner/measurements_spec.rb`.
**Covers:** AC-1.1, AC-1.2 (the panel's copy), AC-1.7, AC-2.3, AC-3.1, AC-3.2 (header), AC-3.3, AC-5.2, AC-7.1 (markup), NFR cost.

1. **Existing expectations this task changes** (change them first, so they fail for the right reason, then green them with the views):

| Spec, example | Was | Becomes |
|---|---|---|
| `sittings_spec` "shows no list or Done without a sitting (AC-3.7)" | `#scanner_sitting` has `hidden` | `hidden` is nil, the control is there, still no `h2` and no Done link |
| `sittings_spec` "keeps each account's sitting to itself (AC-3.8)" | `#scanner_sitting` hidden | no `#scanner_sitting h2` |
| `sittings_spec` "choosing a place" `shows the control alone … (AC-1.1)` | label `Put this sitting in` | label `Location` (`label[for=sitting_location_id]`), and the Condition select exists |
| same describe, `shows nothing of a sitting for an account with no locations (AC-3.1)` | hidden, no label | replaced by the new AC-3.1 example below |
| `says where cards go in a placed sitting with no entries …` | `Cards you scan now go into Blue binder.` | `Cards you scan now: in Blue binder.` |
| `drops a sitting left with no entries and no place when its location is removed` | `#scanner_sitting` hidden | no `h2`, no Done, not hidden |
| `keeps a sitting with entries, all undone, when its last location goes, with Done and no control` | `not_to include("Put this sitting in")` | no `select#sitting_location_id`; `select#sitting_condition` present |
| `shows no control with the summary for an account with no locations (AC-5.2)` | no `Put this sitting in` | the summary shows `select#sitting_condition` and no `select#sitting_location_id` |
| `sitting_entries_spec` "adds unplaced and names no place once the place's location was removed" | `not_to include("Put this sitting in")` | `html.at_css("select#sitting_location_id")` is nil |
| `measurements_spec` "drops a sitting … as the scanner does" | `#scanner_sitting` hidden | the sitting is gone and `#scanner_sitting` holds `select#sitting_condition` |
| `sittings_spec` "choosing a place" `shows the control alone … (AC-1.1)` (line 152), its option list | `picker.css("option")` (would now also collect "Not specified" and the five conditions) | `picker.css("select#sitting_location_id option")`, expecting the same `[ "No location", "Blue binder", "Long box" ]` list; `chosen` there already reads `select#sitting_location_id option[selected]` |
| each "Put this sitting in" in the `choosing a place` describe | label | `Location` |

   **System spec edits that belong here** (`spec/system/scanner_sitting_spec.rb`, the examples this task's label change breaks): define the helper at the top level of the file, inside the outer `RSpec.describe` and before the `describe "a sitting's place (spec 040)"` block, so both that block and Task 9's sibling describe reach it:

```ruby
def set_sitting(condition: nil, location: nil)
  select condition, from: "Condition" if condition
  select location, from: "Location" if location
  click_on "Set"
end
```

   Remove the block-local `place_in` and have the 040 block's examples call `set_sitting(location: name)`; rename every `"Put this sitting in"` to `"Location"` (lines 48, 61, 88, 93, 101; the `ready: "#sitting_location_id"` selector at 114 is unchanged). The status string at line 66 changes in Task 7.

2. **Red.** Add to `spec/requests/scanner/sittings_spec.rb`, a describe after "choosing a place (spec 040)":

```ruby
describe "the control and the panel (spec 042)" do
  let(:scale) do
    [ [ "Near mint (NM)", "near_mint" ], [ "Lightly played (LP)", "lightly_played" ], [ "Moderately played (MP)", "moderately_played" ],
      [ "Heavily played (HP)", "heavily_played" ], [ "Damaged (DMG)", "damaged" ] ]
  end

  def picker = html.at_css("#scanner_sitting form[action='#{scanner_sitting_path}']")
  def chosen(field) = picker.at_css("select#sitting_#{field} option[selected]").text
  def choose(**choices) = Scanner::Sitting.choose!(account:, **choices)
  def metas = html.css("#scanner_sitting > ul > li .c-list__meta").map { it.text.squish }

  it "shows the control alone before the first add: legend, Condition with Not specified first, Set, nothing of a sitting (AC-1.1, AC-3.1)", :aggregate_failures do
    get scanner_path
    expect(html.at_css("#scanner_sitting")["hidden"]).to be_nil
    expect(picker.at_css("fieldset legend").text).to eq("This sitting's cards")
    expect(picker.at_css("label[for=sitting_condition]").text).to eq("Condition")
    expect(picker.css("select#sitting_condition option").map { [ it.text, it["value"] ] }).to eq([ [ "Not specified", "" ], *scale ])
    expect(chosen(:condition)).to eq("Not specified")
    expect(picker.at_css("input[type=submit]")["value"]).to eq("Set")
    expect(picker.at_css("select#sitting_location_id")).to be_nil # no locations, so no Location select and no hint to /locations
    expect(html.at_css("#scanner_sitting a")).to be_nil
    expect(html.at_css("#scanner_sitting h2")).to be_nil
    expect(response.body).not_to include(new_scanner_sitting_ending_path)
  end

  it "puts the Location select after Condition while the account has locations (AC-1.1)", :aggregate_failures do
    create(:location, account:, name: "Blue binder")
    get scanner_path
    expect(picker.css("select").map { it["id"] }).to eq(%w[sitting_condition sitting_location_id])
    expect(picker.at_css("label[for=sitting_location_id]").text).to eq("Location")
  end

  it "names the sitting's choices in the heading, in the order condition then place (decision 3, AC-3.2)", :aggregate_failures do
    blue = create(:location, account:, name: "Blue binder")
    choose(condition: "near_mint", location: blue)
    3.times { add(format("%x", it)) }
    get scanner_path
    expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards, Near mint, in Blue binder")
    expect([ chosen(:condition), chosen(:location_id) ]).to eq([ "Near mint (NM)", "Blue binder" ])
    choose(location: nil)
    get scanner_path
    expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards, Near mint")
    choose(condition: nil, location: blue)
    get scanner_path
    expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards, in Blue binder")
  end

  it "says what cards go into in a sitting with no entries, naming only what is set (decision 3, AC-1.2)", :aggregate_failures do
    blue = create(:location, account:, name: "Blue binder")
    choose(condition: "near_mint", location: blue)
    get scanner_path
    expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now: Near mint, in Blue binder.")
    choose(location: nil)
    get scanner_path
    expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now: Near mint.")
    expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards, Near mint")
    choose(condition: nil, location: blue)
    get scanner_path
    expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now: in Blue binder.")
  end

  it "drops a sitting with no entries and neither choice when the scanner renders, and says the undone copy once every add was undone (AC-3.3, decision 3)", :aggregate_failures do
    Scanner::Sitting.create!(account:) # what a redraw with neither choice leaves ("Nothing added yet.") until the next render
    get scanner_path
    expect(Scanner::Sitting.count).to eq(0)
    expect(html.at_css("#scanner_sitting h2")).to be_nil
    expect(picker.at_css("select#sitting_condition")).not_to be_nil
    choose(condition: "near_mint")
    add("a").undo!
    get scanner_path
    expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Everything added in this sitting was undone.")
  end

  it "keeps a sitting that holds a condition and no entries (AC-3.3)", :aggregate_failures do
    choose(condition: "near_mint")
    get scanner_path
    expect(Scanner::Sitting.count).to eq(1)
    expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards, Near mint")
  end

  it "keeps the condition on a reload (AC-1.7)" do
    choose(condition: "lightly_played")
    get scanner_path
    expect(chosen(:condition)).to eq("Lightly played (LP)")
  end

  it "shows the short label after the finish, from the entry's lot as it is now (decision 3, AC-2.3)", :aggregate_failures do
    blue = create(:location, account:, name: "Blue binder")
    plain = create(:mtg_printing, finishes: [], entry: create(:catalog_entry, name: "Opt", set: mom, number: "7")).entry
    choose(condition: "near_mint")
    edited = add("a")
    unspecified = add("b", finish: "", card: plain)
    choose(condition: "near_mint", location: blue)
    gone = add("c", card: create(:mtg_printing, entry: create(:catalog_entry, name: "Shock", set: mom, number: "9")).entry)
    edited.lot.update!(condition: "lightly_played")
    gone.lot.destroy!
    get scanner_path
    expect(metas).to match([ /\AMOM · 9 · Foil · Added .+ ago\z/, /\AMOM · 7 · — · NM · Added .+ ago\z/, /\AMOM · 123 · Foil · LP · Added .+ ago\z/ ])
    expect(unspecified.lot.condition).to eq("near_mint")
    expect(html.css("#scanner_sitting > ul > li").first.text).to include("Changed in your collection")
  end

  # Passes before the change (an entry with no condition reads as today): kept as a regression guard.
  it "shows the entry with no condition when the sitting had none (AC-1.5)" do
    add("a")
    get scanner_path
    expect(metas).to match([ /\AMOM · 123 · Foil · Added .+ ago\z/ ])
  end

  it "shows the control on the summary after Done, on Not specified, for every account (AC-5.2)", :aggregate_failures do
    choose(condition: "near_mint")
    add("a")
    post scanner_sitting_ending_path
    follow_redirect!
    expect(html.at_css("#scanner_sitting").text.squish).to include("Added 1 card in this sitting")
    expect(chosen(:condition)).to eq("Not specified")
    expect(Scanner::Sitting.count).to eq(0)
  end

  # Passes before the change too (the entry line reads the vocabulary, not a query): kept as a regression guard for NFR cost.
  it "adds no query per entry to the page (NFR cost)", :aggregate_failures do
    choose(condition: "near_mint")
    2.times { add(format("%x", it), card: create(:mtg_printing, entry: create(:catalog_entry, set: mom)).entry) }
    get scanner_path # warm the caches that the first render fills
    few = count_queries { get scanner_path }
    6.times { add(format("%x", it + 2), card: create(:mtg_printing, entry: create(:catalog_entry, set: mom)).entry) }
    expect(count_queries { get scanner_path }).to eq(few)
  end
end
```

   Add to `spec/requests/scanner/sitting_entries_spec.rb` nothing yet (Task 8). Run `bin/rspec spec/requests/scanner/sittings_spec.rb spec/requests/scanner/measurements_spec.rb`: the new and changed examples fail.

3. **Green.** `_picker.html.erb`:

```erb
<%# locals: (condition:, location_id:, conditions:, locations:) %>
<%# The sitting's one control (spec 042 decision 2, spec 040 decision 3): native selects and "Set" in one form, grouped under a
    legend, answered by a Turbo Stream that redraws the panel, so it works by keyboard and needs no script (AC-7.1). The
    fieldset is the choice page's c-choices (a flex column, no border): the two fields stack, as spec 040's did. %>
<%= form_with url: scanner_sitting_path, method: :patch, scope: :sitting, class: "c-form c-scanner__place" do |form| %>
  <fieldset class="c-choices">
    <legend class="c-field__label">This sitting's cards</legend>
    <div class="c-field">
      <%= form.label :condition, "Condition", class: "c-field__label" %>
      <%= form.select :condition, options_for_select([ [ "Not specified", "" ], *conditions.map { |key, (label, short)| [ "#{label} (#{short})", key ] } ], condition.to_s) %>
    </div>
    <% if locations.any? %>
      <div class="c-field">
        <%= form.label :location_id, "Location", class: "c-field__label" %>
        <%= form.select :location_id, options_for_select([ [ "No location", "" ], *locations.map { |location| [ location.name, location.id ] } ], location_id.to_s) %>
      </div>
    <% end %>
  </fieldset>
  <div class="c-form__actions"><%= form.submit "Set", class: "c-btn c-btn--secondary c-btn--sm" %></div>
<% end %>
```

   `_sitting.html.erb` (the comment at its top says "hidden while there's no sitting": rewrite it to "always holds the control, for every collector, with no sitting too (spec 042 decision 2)"):

```erb
<% if sitting %>
  <% choices = sitting_choices(sitting, conditions) %>
  <section id="scanner_sitting" class="c-scanner__sitting" aria-labelledby="scanner-sitting-heading">
    <div class="c-section__head">
      <h2 class="c-section__title" id="scanner-sitting-heading">This sitting: <%= pluralize(entries.size, "card") %><%= ", #{choices.join(", ")}" if choices.any? %></h2>
      <span class="c-section__actions"><%= link_to "Done", new_scanner_sitting_ending_path, class: "c-btn c-btn--secondary c-btn--sm" %></span>
    </div>
    <%= render "scanners/picker", condition: sitting.condition, location_id: sitting.location_id, conditions:, locations: %>
    <% if entries.empty? %>
      <%# Four states (spec 042 decision 3): entries all undone keep spec 009's copy; a sitting with none says what cards get,
          naming only what is set; with neither (a redraw the next render drops) it says nothing was added. %>
      <% if added_any %>
        <p class="c-empty">Everything added in this sitting was undone.</p>
      <% elsif choices.any? %>
        <p class="c-empty">Cards you scan now: <%= choices.join(", ") %>.</p>
      <% else %>
        <p class="c-empty">Nothing added yet.</p>
      <% end %>
    <% else %>
      (the list and "Show all" as today)
    <% end %>
  </section>
<% else %>
  <section id="scanner_sitting" class="c-scanner__sitting">
    <%= render "scanners/picker", condition: nil, location_id: nil, conditions:, locations: %>
  </section>
<% end %>
```

   Remove the `elsif locations.any?` and `else … hidden` branches. `_summary.html.erb`: `<%= render "scanners/picker", condition: nil, location_id: nil, conditions:, locations: %>` with no `if locations.any?` guard (the picker holds the Location select's own guard); update its comment ("…the control under it, on Not specified and No location, for every collector"). `_sitting_entry.html.erb`: insert the condition between the finish and the place:

```erb
<span class="c-list__meta"><%= set_number(entry.printing) %> · <%= scanner_finish(entry.printing, entry.finish) || "—" %> ·<% if (condition = scanner_condition(entry.printing, entry.lot&.condition)) %> <%= condition %> ·<% end %><% if (place = entry.lot&.location) %> in <%= place.name %> ·<% end %> Added <%= time_tag entry.created_at, "#{time_ago_in_words(entry.created_at)} ago" %></span>
```

   `copy = scanner_copy(entry.printing, entry.finish)` and the `aria-label`s stay as they are (decision 3: no condition in accessible names).
4. `bin/rspec spec/requests/scanner/sittings_spec.rb spec/requests/scanner/sitting_entries_spec.rb spec/requests/scanner/measurements_spec.rb spec/requests/scanners_spec.rb spec/scanner_sitting_core_spec.rb`; `bin/rubocop` on the touched Ruby spec files. Also `bin/rspec spec/system/scanner_sitting_spec.rb` (the 040 examples, relabelled). **Between Tasks 6 and 7 the control is half wired:** for an account with locations "Set" posts both fields and the old `update` reads `location_id` (the place examples pass); for an account with no locations "Set" posts only `sitting[condition]` and the old `params.expect(sitting: :location_id)` answers 400. Nothing in Tasks 6's specs presses "Set" for such an account, so Task 6 is green, but do not stop between the two commits: land Task 7 next.
5. Commit.

## Task 7: Setting the choices (AC-1.2, AC-1.8, AC-2.1, AC-2.4, AC-3.2, AC-4.1 to AC-4.3, AC-5.1, AC-5.2, decisions 3, 8, 9, FR-1)

**Commit:** `feat(scanner): set a sitting's condition and place together`
**Files:** `app/controllers/scanner/sittings_controller.rb`, `spec/requests/scanner/sittings_spec.rb`, `spec/system/scanner_sitting_spec.rb` (the status string only).
**Covers:** AC-1.2, AC-1.8, AC-2.1, AC-2.2, AC-2.4, AC-3.2, AC-4.1, AC-4.2, AC-4.3, AC-5.1, AC-5.2, FR-1, NFR Security.

1. **Existing expectations this task changes** (the status line, decision 3): `"This sitting's cards now go into Blue binder."` becomes `"Cards you scan now: condition not specified, in Blue binder."` (the `opens a sitting in the place` example); `"This sitting's cards now go in no location."` becomes `"Cards you scan now: condition not specified, no location."` and `not_to include("This sitting:", "now go")` becomes `not_to include("This sitting:", "Cards you scan now")` (`clears the place of a sitting with a card, and deletes one with none`); `answers 400 to a request with no place` keeps `sitting: { other: "1" }` and `params: {}` but its body is the same; `sitting_location_id`-only requests (`place(value)`) stay valid because a key left out is kept. In `spec/system/scanner_sitting_spec.rb` the status string at line 66 changes here too: `"This sitting's cards now go into Blue binder."` becomes `"Cards you scan now: condition not specified, in Blue binder."`; run `bin/rspec spec/system/scanner_sitting_spec.rb` in this task's step 4.
2. **Red.** Add to the `the control and the panel (spec 042)` describe, or a sibling `describe "setting the choices (spec 042)"`:

```ruby
describe "setting the choices (spec 042)" do
  def blue = @blue ||= create(:location, account:, name: "Blue binder")
  def set(**fields) = patch(scanner_sitting_path, params: { sitting: fields }, headers: stream)
  def chosen(field) = html.at_css("select#sitting_#{field} option[selected]").text
  # The status line in the stream's update of "status" (`#status` itself is in the layout, not in a stream body).
  def status_line = html.at_css("turbo-stream[target=status] .c-status__message").text.squish
  def status_cleared? = response.body.match?(%r{<turbo-stream action="update" target="status"><template>\s*</template></turbo-stream>})

  it "opens a sitting holding the condition, redrawing the panel, for an account with no locations (AC-1.2, AC-3.1)", :aggregate_failures do
    set(condition: "near_mint")
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('<turbo-stream action="replace" target="scanner_sitting">')
    expect(response.body).not_to include('target="scanner_result"')
    expect(account.scanner_sitting).to have_attributes(condition: "near_mint", location: nil)
    expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 0 cards, Near mint")
    expect(html.at_css("#scanner_sitting .c-empty").text).to eq("Cards you scan now: Near mint.")
    expect(status_line).to eq("Cards you scan now: Near mint.")
    expect(chosen(:condition)).to eq("Near mint (NM)")
  end

  it "says both choices in the status line for an account with locations, in every variant (decision 3)", :aggregate_failures do
    blue
    {
      { condition: "near_mint", location_id: blue.id } => "Cards you scan now: Near mint, in Blue binder.",
      { condition: "near_mint", location_id: "" } => "Cards you scan now: Near mint, no location.",
      { condition: "", location_id: blue.id } => "Cards you scan now: condition not specified, in Blue binder."
    }.each do |fields, line|
      set(**fields)
      expect(status_line).to eq(line), fields.inspect
    end
    add("a")
    set(condition: "", location_id: "")
    expect(status_line).to eq("Cards you scan now: condition not specified, no location.")
    expect(account.scanner_sitting.entries.count).to eq(1)
  end

  it "says only the condition for an account with no locations, also when it is cleared with a card kept (decision 3)", :aggregate_failures do
    add("a")
    set(condition: "near_mint")
    set(condition: "")
    expect(status_line).to eq("Cards you scan now: condition not specified.")
  end

  it "changes the condition of an open sitting, keeping its count, entries and place, and the cards already added stay put (AC-2.1, AC-2.4)", :aggregate_failures do
    set(condition: "near_mint", location_id: blue.id)
    entries = %w[a b c].map { add(it) }
    set(condition: "lightly_played")
    expect(account.scanner_sitting.reload).to have_attributes(condition: "lightly_played", location: blue, entries:)
    expect(entries.map { it.lot.reload.condition }.uniq).to eq([ "near_mint" ])
    expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards, Lightly played, in Blue binder")
    set(location_id: create(:location, account:, name: "Long box").id)
    expect(account.scanner_sitting.reload).to have_attributes(condition: "lightly_played", location: Location.find_by!(name: "Long box"))
  end

  it "clears the condition of a sitting with a card and keeps it; deletes a sitting with no card, condition or place, and clears the status (AC-1.8)", :aggregate_failures do
    set(condition: "near_mint")
    add("a")
    set(condition: "")
    expect(account.scanner_sitting.reload.condition).to be_nil
    expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 1 card")

    account.scanner_sitting.entries.sole.undo!
    set(condition: "near_mint")
    set(condition: "")
    expect(Scanner::Sitting.count).to eq(0)
    expect(response).to have_http_status(:ok)
    expect(chosen(:condition)).to eq("Not specified")
    expect(html.at_css("#scanner_sitting h2")).to be_nil
    expect(status_cleared?).to be(true)
  end

  # Passes before the change (the old controller or model already behaves so): regression guard.
  it "clears the status line when both choices are cleared with no sitting open (decision 3)", :aggregate_failures do
    blue
    set(condition: "", location_id: "")
    expect(Scanner::Sitting.count).to eq(0)
    expect(status_cleared?).to be(true)
  end

  # Passes before the change (the old controller or model already behaves so): regression guard.
  it "takes a sitting that holds a place and no condition to Not specified, deleting it while empty (AC-1.8)" do
    set(location_id: blue.id)
    set(location_id: "")
    expect(Scanner::Sitting.count).to eq(0)
  end

  it "answers 400 to a request with neither key, changing nothing, and keeps the other choice when only one is sent (AC-4.2)", :aggregate_failures do
    set(condition: "near_mint", location_id: blue.id)
    patch scanner_sitting_path, params: { sitting: { other: "1" } }, headers: stream
    expect(response).to have_http_status(:bad_request)
    patch scanner_sitting_path, params: {}, headers: stream
    expect(response).to have_http_status(:bad_request)
    expect(account.scanner_sitting.reload).to have_attributes(condition: "near_mint", location: blue)
    set(condition: "damaged")
    expect(account.scanner_sitting.reload).to have_attributes(condition: "damaged", location: blue)
  end

  it "refuses a condition that is not a key of the scanner's vocabulary, changing nothing, not even a place sent with it (AC-4.1)", :aggregate_failures do
    set(condition: "near_mint", location_id: blue.id)
    long_box = create(:location, account:, name: "Long box")
    [ "Near mint", "Near mint (NM)", "NEAR_MINT", "near_mint ", "mint", "<b>x</b>" ].each do |value|
      set(condition: value, location_id: long_box.id)
      expect(response).to have_http_status(:unprocessable_content), value.inspect
      expect(CGI.unescapeHTML(response.body)).to include("That isn't a known condition. Choose again.")
      expect([ chosen(:condition), chosen(:location_id) ]).to eq([ "Near mint (NM)", "Blue binder" ])
    end
    expect(account.scanner_sitting.reload).to have_attributes(condition: "near_mint", location: blue)
  end

  it "refuses a bad condition with no sitting open, opening none (AC-4.1)", :aggregate_failures do
    set(condition: "mint")
    expect(response).to have_http_status(:unprocessable_content)
    expect(Scanner::Sitting.count).to eq(0)
  end

  it "shows the condition's message when both values are refused, changing nothing (decision 9)", :aggregate_failures do
    set(condition: "near_mint")
    set(condition: "mint", location_id: create(:location).id)
    expect(response).to have_http_status(:unprocessable_content)
    body = CGI.unescapeHTML(response.body)
    expect(body).to include("That isn't a known condition. Choose again.")
    expect(body).not_to include("That location isn't one of yours any more.")
    expect(account.scanner_sitting.reload.condition).to eq("near_mint")
  end

  it "keeps spec 040's message for a refused location, and changes nothing when the condition was good (decision 9)", :aggregate_failures do
    set(condition: "near_mint")
    set(condition: "damaged", location_id: create(:location).id)
    expect(response).to have_http_status(:unprocessable_content)
    expect(CGI.unescapeHTML(response.body)).to include("That location isn't one of yours any more. Choose again.")
    expect(account.scanner_sitting.reload.condition).to eq("near_mint")
  end

  it "ignores a sitting id, an account id and another account's id (AC-4.3)", :aggregate_failures do
    other = create(:user).account
    theirs = Scanner::Sitting.choose!(account: other, condition: "damaged")
    set(condition: "near_mint", sitting_id: theirs.id, account_id: other.id, id: theirs.id)
    expect(theirs.reload.condition).to eq("damaged")
    expect(account.scanner_sitting.reload.condition).to eq("near_mint")
  end

  it "ignores a sitting id and an account id at the top level of the request too (AC-4.3)", :aggregate_failures do
    other = create(:user).account
    theirs = Scanner::Sitting.choose!(account: other, condition: "damaged")
    patch scanner_sitting_path, params: { sitting: { condition: "near_mint" }, sitting_id: theirs.id, account_id: other.id }, headers: stream
    expect(theirs.reload.condition).to eq("damaged")
    expect(account.scanner_sitting.reload.condition).to eq("near_mint")
  end

  it "ends the sitting with its condition, and the next one starts on Not specified (AC-5.1, AC-5.2)", :aggregate_failures do
    set(condition: "near_mint")
    add("a")
    post scanner_sitting_ending_path
    follow_redirect!
    expect(chosen(:condition)).to eq("Not specified")
    expect([ Scanner::Sitting.count, account.lots.sole.condition ]).to eq([ 0, "near_mint" ])
    set(condition: "damaged")
    expect(response.body).not_to include("in this sitting.")
    expect(Scanner::Sitting.sole.condition).to eq("damaged")
  end

  it "takes Undo of an entry added under another condition from the lot it went into (AC-2.2)", :aggregate_failures do
    set(condition: "near_mint")
    first = add("a")
    set(condition: "lightly_played")
    add("b")
    undo(first)
    expect(account.lots.map { [ it.condition, it.quantity ] }).to eq([ [ "lightly_played", 1 ] ])
    expect(chosen(:condition)).to eq("Lightly played (LP)")
  end

  # Passes before the change (the old controller or model already behaves so): regression guard.
  it "sends a signed-out visitor to sign in" do
    delete session_path
    set(condition: "near_mint")
    expect(response).to redirect_to(new_session_path)
  end

  # Passes before the change (the old controller or model already behaves so): regression guard.
  it "never touches another account's sitting (tenant isolation)" do
    other = create(:user).account
    theirs = Scanner::Sitting.choose!(account: other, condition: "damaged", location: create(:location, account: other))
    set(condition: "")
    expect(theirs.reload).to have_attributes(condition: "damaged")
    expect(account.scanner_sitting).to be_nil
  end
end
```

   Run `bin/rspec spec/requests/scanner/sittings_spec.rb`: the new examples and the status-line changes fail.

3. **Green.** `app/controllers/scanner/sittings_controller.rb` (the whole file):

```ruby
# Sets what the scanner sitting's adds get (spec 042 decisions 2, 8, 9; spec 040 Stories 1–4): a condition from the scanner's
# vocabulary, a place among the account's locations, or both, each or none cleared. The answer is a Turbo Stream that redraws
# the panel, so the camera and the reading on screen stay. Both values are checked before anything is written; a value that
# fails changes nothing, and the condition's message wins when both fail.
class Scanner::SittingsController < ApplicationController
  include ScannerSitting

  GONE = "That location isn't one of yours any more. Choose again.".freeze
  UNKNOWN_CONDITION = "That isn't a known condition. Choose again.".freeze

  def update
    attributes = params.expect(sitting: %i[condition location_id]) # a request with neither key (or no sitting) raises ParameterMissing: a 400

    choices = {}
    if attributes.key?(:condition)
      value = attributes[:condition].to_s
      return refuse(UNKNOWN_CONDITION) unless value.empty? || scanner_conditions.key?(value)

      choices[:condition] = value.presence
    end
    if attributes.key?(:location_id)
      value = attributes[:location_id].to_s
      location = Current.account.locations.find_by(id: value) if value.match?(/\A\d+\z/) # "12abc" is refused, not read as 12
      return refuse(GONE) if value.present? && location.nil?

      choices[:location] = location
    end

    render turbo_stream: sitting_stream(chosen_message(Scanner::Sitting.choose!(account: Current.account, **choices)))
  end

  private
    def refuse(message) = render(turbo_stream: sitting_stream(message, alert: true), status: :unprocessable_content)

    # Says what later adds get (decision 3): both choices for an account with locations, the condition alone otherwise; nil,
    # which clears the status line, when "Set" deleted the sitting or cleared both with none open.
    def chosen_message(sitting)
      return unless sitting&.persisted? # a destroyed sitting still holds what it had in memory

      parts = [ (sitting.condition && scanner_conditions.dig(sitting.condition, 0)) || "condition not specified" ]
      parts << (sitting.location ? "in #{sitting.location.name}" : "no location") if account_locations.any?
      "Cards you scan now: #{parts.join(", ")}."
    end
end
```

   `params.expect(sitting: %i[condition location_id])` permits first and then requires, so a missing `sitting`, an empty one or one holding neither permitted key raises `ParameterMissing` (a 400); the AC-4.2 example confirms it. The `Current.account.scanner_sitting` reader is not loaded before `choose!`, so the redraw reads the stored state (the pattern spec 040 relied on).
4. `bin/rspec spec/requests/scanner/sittings_spec.rb spec/requests/scanner/sitting_entries_spec.rb spec/models/scanner/sitting_spec.rb spec/scanner_sitting_core_spec.rb spec/system/scanner_sitting_spec.rb`; `bin/rubocop app/controllers/scanner/sittings_controller.rb spec/requests/scanner/sittings_spec.rb`; `bin/brakeman -q` (no new warning: `params.expect`, no mass assignment of an id).
5. Commit.

## Task 8: The add's notice names the condition (AC-1.3 to AC-1.6, AC-4.4, AC-4.5, FR-2)

**Commit:** `feat(scanner): name the condition in the add's notice`
**Files:** `app/controllers/scanner/sittings/entries_controller.rb`, `spec/requests/scanner/sitting_entries_spec.rb`.
**Covers:** AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-4.4, AC-4.5 (request), decision 3 (notice).

1. **Red.** Add a describe to `spec/requests/scanner/sitting_entries_spec.rb`:

```ruby
describe "with the sitting's condition (spec 042)" do
  def blue = @blue ||= create(:location, account: user.account, name: "Blue binder")
  def choose(**choices) = Scanner::Sitting.choose!(account: user.account, **choices)
  def html = Nokogiri::HTML5(response.body)

  it "adds into the lot of that condition and names it by its short label after the finish (AC-1.3)", :aggregate_failures do
    choose(condition: "near_mint")
    add
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, Foil, NM) to your collection.")
    expect(user.account.lots.sole).to have_attributes(condition: "near_mint", finish: "foil", location: nil, price_paid_cents: nil)
    expect(html.at_css("select#sitting_condition option[selected]").text).to eq("Near mint (NM)")
    expect(html.at_css("#scanner_sitting li .c-list__meta").text.squish).to match(/\AMOM · 123 · Foil · NM · Added/)
  end

  it "names the condition and the place together (AC-1.4)", :aggregate_failures do
    choose(condition: "near_mint", location: blue)
    add
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, Foil, NM) in Blue binder to your collection.")
    expect(user.account.lots.sole).to have_attributes(condition: "near_mint", location: blue)
  end

  it "leaves the finish out and keeps the condition for a printing with no finish listed (decision 3)" do
    MTG::Printing.find_by!(catalog_entry_id: printing.id).update!(finishes: [])
    choose(condition: "near_mint")
    add(finish: "")
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, NM) to your collection.")
  end

  # Passes before the change: regression guard.
  it "names no condition when the sitting has none (AC-1.5)", :aggregate_failures do
    choose(location: blue)
    add
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, Foil) in Blue binder to your collection.")
    expect(user.account.lots.sole.condition).to be_nil
  end

  # Passes before the change: regression guard.
  it "keeps the Undo announcement and the accessible names free of the condition (decision 3)", :aggregate_failures do
    choose(condition: "near_mint")
    add
    expect(html.at_css("#scanner_sitting form.c-scanner__undo input[type=submit], #scanner_sitting form.c-scanner__undo button")["aria-label"]).to eq("Undo Lightning Bolt (MOM · 123, Foil)")
    expect(html.at_css("#scanner_sitting a[data-scanner-event=details]")["aria-label"]).to eq("Details of Lightning Bolt (MOM · 123, Foil)")
    post scanner_sitting_entry_undo_path(Scanner::SittingEntry.sole), headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    expect(response.body).to include("Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.")
  end

  # Passes before the change: regression guard.
  it "refuses at the cap of the lot of that condition with the existing message, while Not specified takes the card (AC-1.6)", :aggregate_failures do
    create(:lot, account: user.account, entry: printing, finish: "foil", condition: "near_mint", quantity: Lot::MAX_QUANTITY)
    choose(condition: "near_mint")
    add
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("You already have the most copies one lot can hold (9,999).")
    expect(Scanner::SittingEntry.count).to eq(0)
    choose(condition: nil)
    add
    expect(response).to have_http_status(:ok)
  end

  it "names the entry's lot's condition and place on a replay, never the sitting's now (AC-4.4)", :aggregate_failures do
    choose(condition: "near_mint", location: blue)
    add
    choose(condition: "damaged", location: create(:location, account: user.account, name: "Long box"))
    add
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, Foil, NM) in Blue binder to your collection.")
    expect(user.account.lots.sum(:quantity)).to eq(1)
  end

  it "names the condition the entry's lot has been edited to (decision 3)" do
    choose(condition: "near_mint")
    add
    user.account.lots.sole.update!(condition: "lightly_played")
    add
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, Foil, LP) to your collection.")
  end

  # Passes before the change: regression guard.
  it "refuses a condition the printing's vocabulary doesn't know with the not-added message, not the cap, recording nothing (AC-4.5)", :other_collecting, :aggregate_failures do
    other = create(:catalog_entry, collectible_type: "other")
    choose(condition: "near_mint")
    add(finish: "", to: other.external_key)
    expect(response).to have_http_status(:unprocessable_content)
    body = CGI.unescapeHTML(response.body)
    expect(body).to include("That card couldn't be added. Scan it again.")
    expect(body).not_to include("9,999")
    expect([ user.account.lots.count, Scanner::SittingEntry.count ]).to eq([ 0, 0 ])
  end
end
```

   Run `bin/rspec spec/requests/scanner/sitting_entries_spec.rb`: the notice examples fail.

2. **Green.** `Scanner::Sittings::EntriesController#message_for`:

```ruby
def message_for(entry)
  return REPLAYED.fetch(entry.state) unless entry.state == :added

  # The condition and the place are the entry's lot's as it is now, so a replay names where its copy went (spec 040 decision 4,
  # spec 042 decision 3, AC-4.4).
  lot = entry.lot
  place = lot&.location
  "Added 1 × #{helpers.scanner_copy(entry.printing, entry.finish, lot&.condition)}#{" in #{place.name}" if place} to your collection."
end
```

   The refusal path needs no code: `Refused` already answers `NOT_ADDED`, and the condition check runs before `Lot.add!`, so `RecordInvalid` (the cap) is never raised for it.
3. `bin/rspec spec/requests/scanner/sitting_entries_spec.rb spec/requests/scanner/sittings_spec.rb`; `bin/rubocop app/controllers/scanner/sittings/entries_controller.rb spec/requests/scanner/sitting_entries_spec.rb`. In the Undo accessible-name example, if the `button_to` renders a `<button>` or an `<input>`, keep the selector that matches (it lists both); adjust only the selector, never the expectation.
4. Commit.

## Task 9: The flow in a browser, and the layout (AC-1.2, AC-1.7, AC-2.1, AC-5.2, AC-7.1)

**Commit:** `test(scanner): a sitting scanned with a condition`
**Files:** `spec/system/scanner_sitting_spec.rb`; `app/assets/stylesheets/collector/additions.css` only if a control overflows (Open item P1).
**Covers:** AC-1.2 (camera and reading untouched), AC-1.7, AC-2.1, AC-5.2, AC-7.1.

1. The relabelling, the status string and the top-level `set_sitting` helper were made in Tasks 6 and 7, so no existing example is red here. The new examples below use `set_sitting`, which is defined at the file's top level.
2. **Acceptance examples** (headless Firefox, no `sleep`, Capybara waits; every one passes on arrival, since Tasks 6 and 7 built the behaviour: they prove it in a browser rather than drive it). Add:

```ruby
describe "a sitting's condition (spec 042)" do
  def entry_metas = all("#scanner_sitting li .c-list__meta").map { it.text.squish }

  it "opens a sitting with the condition, keeping the page and its camera (AC-1.2)", :aggregate_failures do
    visit scanner_path
    expect(page).to have_select("Condition", selected: "Not specified")
    expect(page).to have_no_select("Location")
    page.execute_script("window.__marker = 'still here'")
    set_sitting(condition: "Near mint (NM)")
    expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, Near mint")
    expect(page).to have_css("#status", text: "Cards you scan now: Near mint.")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(page).to have_css(".c-scanner__stage video", visible: :all)
  end

  it "scans into the condition, and into another once it changes mid-sitting (AC-1.3, AC-2.1)", :aggregate_failures do
    visit scanner_path
    set_sitting(condition: "Near mint (NM)")
    add_by_scanning
    expect(page).to have_css("#status", text: "Added 1 × Lightning Bolt (MOM · 123, Foil, NM) to your collection.")
    set_sitting(condition: "Lightly played (LP)")
    expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 1 card, Lightly played")
    add_by_scanning
    expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 2 cards, Lightly played")
    expect(entry_metas).to match([ /Foil · LP ·/, /Foil · NM ·/ ])
    expect(user.account.lots.map { [ it.condition, it.quantity ] }.sort).to eq([ [ "lightly_played", 1 ], [ "near_mint", 1 ] ])
  end

  it "keeps the condition on a reload, clears it with cards kept, and ends with the control on Not specified (AC-1.7, AC-1.8, AC-5.2)", :aggregate_failures do
    Scanner::Sitting.choose!(account: user.account, condition: "near_mint")
    Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
    visit scanner_path
    expect(page).to have_select("Condition", selected: "Near mint (NM)")
    set_sitting(condition: "Not specified")
    expect(page).to have_css("#scanner_sitting h2", exact_text: "This sitting: 1 card")
    click_on "Done"
    click_on "End sitting"
    expect(page).to have_select("Condition", selected: "Not specified")
    set_sitting(condition: "Damaged (DMG)")
    expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, Damaged")
    expect(page).to have_no_text("Added 1 card in this sitting")
  end

  it "reaches Condition, Location and Set with the keyboard alone (AC-7.1)", :aggregate_failures do
    create(:location, account: user.account, name: "Long box")
    visit scanner_path
    field = find_field("Condition")
    field.select("Near mint (NM)")
    field.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.id")).to eq("sitting_location_id")
    page.driver.browser.switch_to.active_element.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.value")).to eq("Set")
    page.driver.browser.switch_to.active_element.send_keys(:enter)
    expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, Near mint")
  end

  it "fits 390px and a desktop width with both selects and a long location name, never scrolling sideways (AC-7.1)", :aggregate_failures do
    long = create(:location, account: user.account, name: "The second long box under the desk, left of the shelf")
    Scanner::Sitting.choose!(account: user.account, condition: "moderately_played", location: long)
    Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
    visit collection_path
    expect(open_in_narrow_frame(scanner_path, width: 390, ready: "#sitting_condition")).to eq([ 390, true ])
    within_narrow_frame do
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
      expect(page.evaluate_script(%(Array.from(document.querySelectorAll("#scanner_sitting select, #scanner_sitting input[type=submit]")).every(el => el.getBoundingClientRect().right <= document.getElementById("scanner_sitting").getBoundingClientRect().right + 1)))).to be(true)
    end
    page.current_window.resize_to(1280, 900)
    visit scanner_path
    expect(page).to have_css("#scanner_sitting select#sitting_condition")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
  end
end
```

   The existing 360px example (long location name) keeps `ready: "#sitting_location_id"`. Run `bin/rspec spec/system/scanner_sitting_spec.rb`. If the fit example fails on a control, add the smallest rule that fixes it to `additions.css` (tokens only, a comment naming spec 042 AC-7.1) and document it in Task 11's `Scanner.md` text; otherwise add none (P1).
3. `bin/rspec spec/system/scanner_sitting_spec.rb spec/system/scanner_adding_spec.rb spec/system/scanner_measurement_spec.rb spec/system/scanner_spec.rb`; `bin/rubocop spec/system/scanner_sitting_spec.rb`. Commit.

## Task 10: An import apply ends the sitting with its condition (AC-5.3)

**Commit:** `test(import): an apply destroys a sitting holding a condition`
**Files:** `spec/models/collection_import/apply_spec.rb`.
**Covers:** AC-5.3.

1. In the `working state (decision 7, AC-1.8)` example (line 148), change the line that places the sitting to `Scanner::Sitting.sole.update!(location: create(:location, account:), condition: "near_mint") # a sitting with its choices goes too (spec 040 AC-5.3, spec 042 AC-5.3)`. The existing expectation (`Scanner::Sitting.count` is 0 after the apply) is the assertion. It passes at once, since the apply deletes the sitting wholesale (`CollectionImport::WorkingState`): the example proves that no change to the apply is owed. Confirm that by running it before and after the edit.
2. `bin/rspec spec/models/collection_import/apply_spec.rb`. Commit.

## Task 11: The design-system doc

**Commit:** `docs(design): the scanner sitting's control`
**Files:** `docs/design-system/components/Scanner.md`.
**Covers:** the "Documents that change" row for `Scanner.md`; AC-7.1 (documentation of any rule).
**Verified by reading** (`.claude/rules/testing.md`), recorded in `verification.md` (Task 13).

Edit the three paragraphs of `Scanner.md` that describe the panel (the lines beginning "The open sitting", "While the account has locations" and "A sitting with no entries says"), and the "Done" paragraph's last sentence:

- **The open sitting:** the heading reads "This sitting: N cards" followed by the choices that are set, ", Near mint" and ", in Blue binder"; the entry line gains the short condition label after the finish ("MH3 · 47 · Foil · NM · in Blue binder · Added …"), read from the entry's lot as it is now; an entry whose lot went names none.
- **The control** replaces "While the account has locations …": the sitting's one control (`form.c-form.c-scanner__place`, spec 042 decision 2) shows for every signed-in collector, before the first add too. A `fieldset.c-choices` with the legend "This sitting's cards" holds, stacked, a `c-field` "Condition" (a native select, "Not specified" first, then the scale as "Near mint (NM)" … "Damaged (DMG)") and, while the account has locations, a `c-field` "Location" ("No location" first, then the locations in the order of the locations page), and a `c-btn--secondary c-btn--sm` "Set" in `c-form__actions`. It needs no script. "Set" redraws the panel with a Turbo Stream and `#status` says "Cards you scan now: Near mint, in Blue binder." (both choices for an account with locations; "condition not specified" and "no location" for what is unset; the condition alone for an account with none), and is cleared when "Set" deletes an empty sitting, or clears both choices with no sitting open (spec 042 decision 3). With no sitting open the panel holds the control alone (no heading, no "Done"). If Task 9 added a rule to `additions.css`, say so here with its selector and reason; otherwise say the control uses only existing classes (`c-choices` is the choice page's fieldset).
- **The empty list:** "Cards you scan now: Near mint, in Blue binder." naming only the parts that are set; "Nothing added yet." with neither (a redraw the next render drops); "Everything added in this sitting was undone." once every add was.
- **After an add:** `#status` announces "Added 1 × Lightning Bolt (MOM · 123, Foil, NM) in Blue binder to your collection." (the short label after the finish, "(MOM · 123, NM)" for a printing with no finish); Undo's announcement and the accessible names ("Undo …", "Details of …") do not name the condition.
- **Done:** the summary now carries the control on Not specified (and No location) for every account.

Commit with only that file.

## Task 12: The area docs, the roadmap and the index (the spec's "Documents that change")

**Commit:** `docs(architecture): the scanner adds with the sitting's condition` (area docs and roadmap, one commit)
**Files:** `docs/architecture/collection-and-lots.md`, `docs/architecture/data-portability.md`, `docs/roadmap.md`; `docs/specs/README.md` is checked, not edited.
**Verified by reading**, recorded in `verification.md`. No spec is edited (`.claude/rules/documentation.md`). The distillation log, the spec index's status cells and the plan's retirement are the `distill-feature` step's, after the merge.

1. `collection-and-lots.md`:
   - Line 23 (scope): "The scanner's sitting adds copies through `Lot.add!` with the sitting's condition and into the sitting's place, unspecified and unplaced while it has none, and has its own Undo (spec 009; spec 040 decisions 2, 4; spec 042 decisions 2, 4): **scanner** (no area doc yet)."
   - Line 56 ("Only some ways of adding choose a place"): the scanner clause becomes "the scanner adds with the condition and into the place chosen once for its sitting, both read on the server inside each add, or unspecified and unplaced while the sitting has none (spec 040 decisions 2, 4, AC-1.3, AC-1.5; spec 042 decisions 2, 4, AC-1.3 to AC-1.5; spec 042 supersedes spec 040 decision 4's "condition (none)")"; the sentence on quick add and the bulk actions stays.
   - Line 53 ("Every way of adding … merges into the identity"): no text change needed beyond keeping "the scanner" in its list; add "an add whose sitting condition the printing's vocabulary doesn't know is refused before anything is written (spec 042 decision 5, AC-4.5)".
   - Sources: a bullet "[Spec 042](../specs/042-sitting-condition/spec.md): decisions 2, 4 and 5 as they touch lots (the scanner adds with the sitting's condition and place; the unknown-condition refusal); the sitting itself is the scanner's." Add the issue [#57](https://github.com/plainprogrammer/Collector/issues/57) to the Issues bullet.
2. `data-portability.md`: line 57 ("Working state is left out of the export …"): "the scanner sitting (with the place and the condition chosen for it, which add no coverage entry or format version)" and add "spec 042 decision 6" to its citations; line 209 mentions the sitting as working state: add "(its condition too, spec 042 decision 6)". Sources: a bullet "[Spec 042](../specs/042-sitting-condition/spec.md): decision 6 and AC-5.3 (the sitting's condition is working state, left out, destroyed by an apply that writes a lot)."
3. `docs/roadmap.md`: item 21a's sentence "21b and 21c keep the order." becomes "only 21c keeps the order (spec 042 amends this: 21b ran first as well)."; item 21b becomes "[#57](…) Set a condition for a sitting. **Built 2026-11-06, done when its pull request merges:** [spec 042](specs/042-sitting-condition/spec.md). It ran before the spikes (17–20) by the maintainer's ruling of 2026-11-06 (spec 042 decision 1), for spec 040's reason: the control and the add path are server-rendered and independent of capture." Keep the other rows.
4. `docs/specs/README.md`: read rows 009, 040 and 042; confirm each names the others' supersessions (already written by the spec's commits); change nothing, and record in `verification.md` that it was checked.
5. Check by reading that no document restates an area's rules in `CLAUDE.md` (do not edit it); CLAUDE.md's scanner paragraph names no condition rule, so no change is owed.

## Task 13: Verification, and what only a run can confirm

**Commit:** `docs(specs): verification for spec 042`
**Files:** new `docs/specs/042-sitting-condition/verification.md`, and `screenshots/` beside it if taken.

1. Run the targeted set, one call at a time, and record the counts:
   - `bin/rspec spec/migrations/add_condition_to_scanner_sittings_spec.rb spec/migrations/add_location_to_scanner_sittings_spec.rb`
   - `bin/rspec spec/models/scanner spec/helpers/scanners_helper_spec.rb spec/scanner_sitting_core_spec.rb spec/number_entry_core_spec.rb`
   - `bin/rspec spec/requests/scanner spec/requests/scanners_spec.rb spec/requests/locations_spec.rb`
   - `bin/rspec spec/models/collection_import/apply_spec.rb spec/export_format_document_spec.rb spec/models/account_spec.rb spec/backup_guards_spec.rb`
   - `bin/rspec spec/system/scanner_sitting_spec.rb spec/system/scanner_adding_spec.rb spec/system/scanner_measurement_spec.rb spec/system/scanner_spec.rb`
   - `bin/rspec spec/system/scanner_art_spec.rb spec/system/scanner_detection_spec.rb spec/system/scanner_timing_spec.rb` (they render the page, which now always holds the control; `scanner_spec.rb` holds the 360px fit and the shutter position)
   - `bin/rubocop`, `bin/brakeman -q`, `bin/bundler-audit`, `ruby script/upgrade/guard.rb`.
2. **The implementer must not run `bin/ci`, a bare `bin/rspec`, or the whole suite.** The whole suite and `bin/ci` run only in a CI slot the supervisor obtains; the implementer reports the targeted results and asks for that slot. `spec/support/runtime_log.txt` is not refreshed (`script/ci/record_runtime_log` runs the suite).
3. Check by `git` that the export is untouched: `git diff origin/main --stat -- docs/export-format app/models/export_format app/models/collection_export.rb` is empty (decision 6, FR-3), and that `db/schema.rb`'s diff is the version line and the one column.
4. `git grep -n -i -E "\b(mtg|scryfall|magic)\b" -- app/models/scanner/sitting.rb app/models/scanner/sitting_entry.rb app/views/scanners/_sitting.html.erb app/views/scanners/_sitting_entry.html.erb app/views/scanners/_picker.html.erb app/views/scanners/_summary.html.erb app/helpers/scanners_helper.rb ':!.kamal/secrets'` is empty (the guard's check, by hand).
5. `verification.md`: each AC, FR and NFR with its evidence (the spec names in the coverage table), document criteria checked by reading, a phone-width screenshot of the control and the panel in both themes (`?theme=dark` or the OS setting; see spec 040's `verification.md` for the form), and the upgrade proof (the migration spec; CI's `bin/upgrade-smoke` runs in the image job). The `## Implementation review` heading is added later by the review step.

## Coverage

| Requirement | Task | Spec example (file: example, abbreviated) |
|---|---|---|
| AC-1.1 | 6 | `sittings_spec`: "shows the control alone before the first add…", "puts the Location select after Condition…" |
| AC-1.2 | 2, 6, 7, 9 | `sitting_spec` ".choose! opens a sitting…"; `sittings_spec` "says what cards go into…", "opens a sitting holding the condition…"; system "opens a sitting with the condition, keeping the page and its camera" |
| AC-1.3 | 3, 8, 9 | `sitting_spec` "adds into the lot of that printing, finish and condition…"; `sitting_entries_spec` "adds into the lot of that condition…"; system "scans into the condition…" |
| AC-1.4 | 3, 8 | `sitting_spec` "adds with the condition and the place together"; `sitting_entries_spec` "names the condition and the place together" |
| AC-1.5 | 3, 6, 8 | `sitting_spec` "joins the lot with no condition…"; `sittings_spec` "shows the entry with no condition…"; `sitting_entries_spec` "names no condition when the sitting has none" |
| AC-1.6 | 3, 8 | `sitting_spec` "refuses at the cap of the lot of that condition…"; `sitting_entries_spec` same name |
| AC-1.7 | 6, 9 | `sittings_spec` "keeps the condition on a reload"; system "keeps the condition on a reload, clears it…" |
| AC-1.8 | 2, 7, 9 | `sitting_spec` ".choose! clears…/deletes…/keeps…"; `sittings_spec` "clears the condition of a sitting with a card…", "takes a sitting that holds a place…" |
| AC-2.1 | 7, 9 | `sittings_spec` "changes the condition of an open sitting…"; system "scans into the condition, and into another…" |
| AC-2.2 | 7 | `sittings_spec` "takes Undo of an entry added under another condition…" |
| AC-2.3 | 6 | `sittings_spec` "shows the short label after the finish, from the entry's lot as it is now" |
| AC-2.4 | 2, 7 | `sitting_spec` ".choose! keeps the choice it isn't given…"; `sittings_spec` "changes the condition of an open sitting…" |
| AC-3.1 | 6, 7 | `sittings_spec` "shows the control alone before the first add…" (no locations); "opens a sitting holding the condition…" |
| AC-3.2 | 6, 7 | `sittings_spec` "names the sitting's choices in the heading…" |
| AC-3.3 | 2, 6 | `sitting_spec` "#pointless?"; `sittings_spec` "keeps a sitting with a condition and no entries…", "drops a sitting with no entries and neither choice…" |
| AC-4.1 | 7 | `sittings_spec` "refuses a condition that is not a key…", "refuses a bad condition with no sitting open…" |
| AC-4.2 | 7 | `sittings_spec` "answers 400 to a request with neither key…" |
| AC-4.3 | 7 | `sittings_spec` "ignores a sitting id, an account id…", "never touches another account's sitting" |
| AC-4.4 | 3, 8 | `sitting_spec` "answers a replayed key with its entry, whatever the condition is now"; `sitting_entries_spec` "names the entry's lot's condition and place on a replay…" |
| AC-4.5 | 3, 8 | `sitting_spec` "refuses a condition the printing's vocabulary doesn't know…" (`:other_collecting`); `sitting_entries_spec` same name |
| AC-5.1 | 7 | `sittings_spec` "ends the sitting with its condition…" |
| AC-5.2 | 6, 7, 9 | `sittings_spec` "shows the control on the summary after Done…"; system "…ends with the control on Not specified" |
| AC-5.3 | 10 | `apply_spec` "clears the lists that point at lots when the apply writes" (sitting with a condition) |
| AC-6.1 | 1 | `add_condition_to_scanner_sittings_spec` "keeps every sitting, its place and every entry going down and up…" |
| AC-6.2 | 1 | same file, "goes down while a sitting holds a condition…" |
| AC-7.1 | 6, 9, 11 | `sittings_spec` markup examples (fieldset, labels); system keyboard example and the 390px and desktop example; `Scanner.md` by reading |
| FR-1 | 2, 5, 6, 7 | `.choose!` examples; request examples for the redraw after an add, Undo and "Set" (`sitting_entries_spec`, `sittings_spec` "takes Undo…") |
| FR-2 | 3, 8 | `.add! with the sitting's condition` examples; `sitting_entries_spec` condition describe |
| FR-3 | 4, 12 | `spec/scanner_sitting_core_spec.rb`; export untouched by the Task 13 `git diff`, no Coverage-table change (`spec/export_format_document_spec.rb` stays green) |
| NFR cost per account | 1, 5, 6 | the migration (one nullable column); `sittings_spec` "adds no query per entry to the page" |
| NFR collector choices | none to build | no environment variable added (read in Task 13) |
| NFR Security | 7 | refusal, 400, tenant and signed-out examples; `bin/brakeman` |
| NFR Migration | 1 | `add_condition_to_scanner_sittings_spec` (all four examples); `ruby script/upgrade/guard.rb`; CI's upgrade check |
| NFR Design system | 6, 9, 11 | markup examples; the fit example; `Scanner.md` read |
| Documents that change | 11, 12 | by reading, in `verification.md` |

## Risks and What Only a Run Can Confirm

- **`params.expect(sitting: %i[condition location_id])` for a `sitting` with neither key, or an empty one,** is meant to raise `ParameterMissing` (a 400) in every shape, with no explicit raise. The AC-4.2 example confirms the 400.
- **`fieldset.c-choices` as a flex column inside a `c-form`** is the choice page's pattern, used here with `c-field` children and a select in each. Legend rendering in flex containers differs between engines; only the headless Firefox fit example (390px and desktop) and a look at the screenshot in both themes confirm P1. If the fit example fails, the one-line fix is named in advance: `.c-scanner__place .c-choices { min-width: 0; }` in `collector/additions.css` (a fieldset's default `min-inline-size` is `min-content`), with a comment naming spec 042 AC-7.1, documented in `Scanner.md` (Task 11).
- **The migration's `down`** copies `scanner_sittings` (with its foreign keys to accounts and locations) with enforcement off; only the migration spec run proves that entries survive, as spec 040's did. If the spec shows entries lost, fix the migration (never weaken the spec).
- **The 040 migration spec's `down`** now runs with a column after `location_id`; Task 1 step 4 runs both specs together to prove the older one stays green.
- **Strict locals:** `conditions:` joins `_scanner`, `_sitting` and `_summary`; the measurement page renders `_scanner` through `**@sitting`. A missed render site raises `ActionView::Template::Error` at render time; Task 6's measurement and request specs cover both pages.
- **The query-count example** compares a page with 2 entries and with 8, after a warm-up; if a cache makes the first count unstable, compare two renders of equal data to find the unstable query before loosening it.
- **`owned_printing`** (used in the migration spec) is spec 040's helper; confirm its name in `spec/support` before copying.
- **System specs** need headless Firefox and the OCR engine under `vendor/ocr/v7.0.0/` (`bin/fetch-ocr-engine`); only a run on a prepared machine confirms Task 9.
- **Shared test database:** the implementer runs one `bin/rspec` call at a time, and `maintain_test_schema!` reloads the test schema after Task 1's migration, so do not overlap a run with another worktree's use of the same database file (each worktree has its own, so this only matters inside this worktree).
- **The full suite and `bin/ci`** are the supervisor's to schedule (Task 13 step 2); no claim of completion is made on targeted runs alone.

## Not in this plan

Language for a sitting (#58, its own spec), focus and announcement after the redraw (#182), changing the condition of cards already added, a remembered or default condition, any export change, any capture, detection, art or JavaScript change.
