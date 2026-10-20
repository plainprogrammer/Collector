# Implementation Plan: Add Cards from a Set by Collector Number

**Spec:** docs/specs/026-typed-entry/spec.md (1.2.0, approved 2026-10-15)
**Decisions:** none new; builds on ADRs 0017 (tenancy), 0018 (catalog core), 0019 (lots), 0020 (export format). No ADR 0022 is needed: the list follows the scanner sitting's pattern (spec 009) and nothing here is a new architectural choice.
**Created:** 2026-10-15
**Status:** Approved by the maintainer (2026-10-15)

## Global Constraints

- Core code only: nothing under `app/` that this plan adds names a collectible type, its source, its finishes or its conditions (`mtg`, `scryfall`, `magic`, `foil`, `nonfoil`, `etched`); labels come from `Catalog.title_for` and the type's vocabulary (`Catalog.collecting_for(type)`: `finish_order`, `finish_label`, `special_finishes`, `finishes_for`). Phase 8 checks it.
- Every query of lots and lines goes through `Current.account`; another account's line answers 404.
- Adds go through `Lot.add!`; condition and price paid stay unspecified.
- The list's tables are "Left out" of the export; the format, schema, examples and version don't change.
- No JavaScript is needed for any step; one small Stimulus controller enhances focus and Enter on the finish select.
- Copy: sentence case, "you", no "we", no exclamation marks; quantities as `×4`, set and number as `MH3 · 47`, languages as their codes in capitals.
- The add's status message, "Added N × <name> (<SET · number>, <finish>) to your collection.", isn't in the spec's copy; it is there for parity with the scanner's add message (spec 009 AC-1.3), and the spec's ACs don't forbid it.
- Exact copy (from the spec): "Add by number"; "No set matches “<text>”. Type a set code or choose a set from the list."; "No card numbered <number> in <set name> (<LANGUAGE>)."; "must be a whole number from 1 to 9,999"; "isn't available for this printing"; "One lot can hold at most 9,999 copies."; "This list: N lines, M cards"; "Show all N"; "Changed in your collection"; "Undid N × <name>."; "Those copies have changed in your collection, so they can't be undone here."; "That line is no longer in your list."; the empty collection's "No cards in your collection yet. Search for a card or add cards by number to start adding."
- Small commits: one Conventional Commit per step that changes files. Stage with `git add <paths>` in its own command, then commit (pre-commit hook reads the command text).
- After `bin/rails db:migrate`, restore the cable, cache and queue schema files if the migration rewrote them (`git checkout -- db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb`), keeping only `db/schema.rb`'s change.

---

## Goal

A signed-in collector opens "Add by number", chooses a set and a language, and adds copies by typing number, quantity and finish line after line; each add merges into their lots, joins a per-account list with Undo, and Done clears the list.

---

## Phase 1: The list and its lines

**Implements:** FR-3 (recording, idempotency), FR-4 (Undo, Done at the model), FR-5 | **Satisfies:** AC-2.11, AC-2.12, AC-3.2, AC-3.3, AC-3.4, AC-3.5, AC-3.9, AC-4.4 (model level)
**Files:** `db/migrate/20261015100001_create_number_entries.rb`, `db/migrate/20261015100002_create_number_entry_lines.rb`, `db/schema.rb`, `app/models/number_entry.rb`, `app/models/number_entry/line.rb`, `app/models/account.rb`, `docs/export-format/README.md`, `spec/export_format_document_spec.rb`, `spec/models/number_entry_spec.rb`, `spec/models/number_entry/line_spec.rb`
**Interfaces:** Consumes: `Lot.add!(account:, entry:, quantity:, finish:)`. Produces: `NumberEntry` (table `number_entries`; `NumberEntry::KEY_FORMAT`, `NumberEntry::SHOWN = 10`, `NumberEntry.new_line_key`, `NumberEntry.add!(account:, entry:, quantity:, finish:, line_key:) → NumberEntry::Added(line:, replayed:)`, `#kept_lines`), `NumberEntry::Line` (table `number_entry_lines`; `#undoable?`, `#undo! → removed lot?`, `NumberEntry::Line::NotUndoable`, scopes `kept`, `newest_first`), `Account#number_entry`.

The data a list needs, modelled on the scanner's sitting (spec 009): one list per account, one line per add with its lot (nulled when the lot goes), quantity, finish and line key, and `undone_at`, so a replayed key never adds again after an Undo.

- [ ] Write the failing model specs.

  `spec/models/number_entry_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe NumberEntry do
    let(:account) { create(:user).account }
    let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }
    let(:key) { "a" * 32 }

    def add(line_key: key, quantity: 1, finish: "nonfoil", to: entry)
      described_class.add!(account:, entry: to, quantity:, finish:, line_key:)
    end

    describe ".add!" do
      it "opens the account's list, adds the copies to a lot and records the line (FR-3)", :aggregate_failures do
        added = add(quantity: 4, finish: "foil")
        expect(added.replayed).to be(false)
        expect(account.lots.sole).to have_attributes(entry:, quantity: 4, finish: "foil", condition: nil, price_paid_cents: nil)
        expect(account.number_entry.lines.sole).to have_attributes(entry:, lot: account.lots.sole, quantity: 4, finish: "foil", line_key: key)
      end

      it "adds nothing for a line key already in the list, and returns that line (AC-2.11)", :aggregate_failures do
        first = add(quantity: 2)
        again = add(quantity: 2)
        expect(again).to have_attributes(line: first.line, replayed: true)
        expect(account.lots.sole.quantity).to eq(2)
        expect(NumberEntry::Line.count).to eq(1)
      end

      it "adds the same number twice under two keys (AC-2.12)", :aggregate_failures do
        add
        add(line_key: "b" * 32)
        expect(account.lots.sole.quantity).to eq(2)
        expect(account.number_entry.lines.count).to eq(2)
      end

      it "records nothing when the lot would pass 9,999 copies (AC-4.4)", :aggregate_failures do
        create(:lot, account:, entry:, finish: "nonfoil", quantity: 9_998)
        expect { add(quantity: 2) }.to raise_error(ActiveRecord::RecordInvalid)
        expect(account.lots.sole.quantity).to eq(9_998)
        expect(NumberEntry::Line.count).to eq(0)
      end

      it "refuses a malformed line key" do
        expect { add(line_key: "x") }.to raise_error(ArgumentError)
      end
    end

    describe "#kept_lines" do
      it "lists lines not undone, newest first", :aggregate_failures do
        older = add.line
        newer = add(line_key: "b" * 32).line
        undone = add(line_key: "c" * 32).line
        undone.undo!
        expect(account.number_entry.kept_lines).to eq([ newer, older ])
      end
    end

    it "goes with its account, lines and all (AC-3.9)", :aggregate_failures do
      add
      account.user.destroy!
      expect(described_class.count).to eq(0)
      expect(NumberEntry::Line.count).to eq(0)
    end

    it "goes with Done, leaving the copies (AC-3.7)", :aggregate_failures do
      add(quantity: 3)
      account.number_entry.destroy!
      expect(NumberEntry::Line.count).to eq(0)
      expect(account.lots.sole.quantity).to eq(3)
    end
  end
  ```

  `spec/models/number_entry/line_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe NumberEntry::Line do
    let(:account) { create(:user).account }
    let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }
    let(:line) { NumberEntry.add!(account:, entry:, quantity: 4, finish: "nonfoil", line_key: "a" * 32).line }
    let(:lot) { line.lot }

    describe "#undo!" do
      it "takes the line's copies out of a lot that holds more (AC-3.2)", :aggregate_failures do
        lot.update!(quantity: 6)
        expect(line.undo!).to be(false)
        expect(lot.reload.quantity).to eq(2)
        expect(line.reload.undone_at).to be_present
      end

      it "removes a lot that holds exactly the line's copies (AC-3.3)", :aggregate_failures do
        expect(line.undo!).to be(true)
        expect(Lot.exists?(lot.id)).to be(false)
      end

      it "undoes from a lot whose condition was edited since (AC-3.5)", :aggregate_failures do
        lot.revise!(condition: "near_mint")
        expect(line.undo!).to be(true)
        expect(account.lots).to be_empty
      end

      it "refuses when the lot now holds fewer copies than the line added (AC-3.4)", :aggregate_failures do
        lot.update!(quantity: 3)
        expect(line).not_to be_undoable
        expect { line.undo! }.to raise_error(NumberEntry::Line::NotUndoable)
        expect(lot.reload.quantity).to eq(3)
      end

      it "refuses when the lot was removed (AC-3.4)", :aggregate_failures do
        lot.destroy!
        expect(line.reload.lot_id).to be_nil
        expect(line).not_to be_undoable
        expect { line.undo! }.to raise_error(NumberEntry::Line::NotUndoable)
      end

      it "refuses when the lot was merged away (AC-3.4)", :aggregate_failures do
        other = create(:lot, account:, entry:, finish: "foil", quantity: 1)
        lot.revise!(finish: "foil")
        expect(Lot.exists?(lot.id)).to be(false)
        expect(other.reload.quantity).to eq(5)
        expect(line.reload).not_to be_undoable
      end

      it "refuses a second undo", :aggregate_failures do
        lot.update!(quantity: 8)
        line.undo!
        expect { line.undo! }.to raise_error(NumberEntry::Line::NotUndoable)
        expect(lot.reload.quantity).to eq(4)
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/number_entry_spec.rb spec/models/number_entry/line_spec.rb` — expect: FAIL (`uninitialized constant NumberEntry`).
- [ ] Write the migrations.

  `db/migrate/20261015100001_create_number_entries.rb`:
  ```ruby
  # The account's list of number entry adds (spec 026 decision 6): at most one per account.
  class CreateNumberEntries < ActiveRecord::Migration[8.1]
    def change
      create_table :number_entries do |t|
        t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
        t.timestamps
      end
    end
  end
  ```

  `db/migrate/20261015100002_create_number_entry_lines.rb`:
  ```ruby
  # One added line of number entry (spec 026 FR-3): the entry, the quantity and finish, the lot the copies went into
  # (cleared when that lot is removed or merged away, decision 5) and the form's line key (one line per key, decision 10).
  class CreateNumberEntryLines < ActiveRecord::Migration[8.1]
    def change
      create_table :number_entry_lines do |t|
        t.references :number_entry, null: false, foreign_key: { on_delete: :cascade }, index: false
        t.references :account, null: false, foreign_key: { on_delete: :cascade }
        t.references :catalog_entry, null: false, foreign_key: true
        t.references :lot, foreign_key: { on_delete: :nullify }
        t.integer :quantity, null: false
        t.string :finish
        t.string :line_key, null: false
        t.datetime :undone_at
        t.timestamps
        t.index %i[number_entry_id line_key], unique: true
        t.check_constraint "quantity BETWEEN 1 AND 9999", name: "number_entry_lines_quantity_range"
      end
    end
  end
  ```
- [ ] Run: `bin/rails db:migrate && bin/rails db:rollback STEP=2 && bin/rails db:migrate` (reversible), then restore the non-primary schema files as Global Constraints say. Expect `db/schema.rb` to gain both tables.
- [ ] Write the models.

  `app/models/number_entry.rb`:
  ```ruby
  # The account's list of number entry adds, open until Done (spec 026 decisions 4–6). An account has at most one: the
  # first add opens it, and Done deletes it with its lines, which are working state rather than collection data (left out
  # of the export). SQLite's IMMEDIATE transactions serialise writers, so two adds can't both open a list or reuse a key.
  class NumberEntry < ApplicationRecord
    KEY_FORMAT = /\A[0-9a-f]{32}\z/
    SHOWN = 10

    # One add's outcome: its line, and whether an earlier request with the same line key made it (decision 10).
    Added = Data.define(:line, :replayed)

    belongs_to :account
    has_many :lines, class_name: "NumberEntry::Line", foreign_key: :number_entry_id, inverse_of: :list, dependent: :delete_all

    def self.new_line_key = SecureRandom.hex(16)

    # Adds quantity copies of entry, at most once per line key in the account's list (FR-3, AC-2.11). The copies merge
    # into their lot through Lot.add!, which raises RecordInvalid at the 9,999 cap (AC-4.4); nothing is recorded then.
    def self.add!(account:, entry:, quantity:, finish:, line_key:)
      raise ArgumentError, "malformed line key" unless KEY_FORMAT.match?(line_key.to_s)

      transaction do
        list = find_or_create_by!(account:)
        existing = list.lines.find_by(line_key:)
        next Added.new(line: existing, replayed: true) if existing

        lot = Lot.add!(account:, entry:, quantity:, finish:)
        Added.new(line: list.lines.create!(account:, entry:, lot:, quantity:, finish:, line_key:), replayed: false)
      end
    end

    # Lines not undone, newest first, with what the page shows of each (AC-3.1).
    def kept_lines = lines.kept.newest_first.includes(:lot, entry: :set)
  end
  ```

  `app/models/number_entry/line.rb`:
  ```ruby
  # One added line of number entry (spec 026 FR-3): the entry, the quantity and finish, the lot the copies went into and
  # the form's line key. The lot reference clears itself (on delete set null) when that lot is removed or merged away.
  class NumberEntry::Line < ApplicationRecord
    NotUndoable = Class.new(StandardError)

    belongs_to :list, class_name: "NumberEntry", foreign_key: :number_entry_id, inverse_of: :lines
    belongs_to :account
    belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id
    belongs_to :lot, optional: true

    scope :kept, -> { where(undone_at: nil) }
    scope :newest_first, -> { order(created_at: :desc, id: :desc) }

    # Its copies can come back out while it isn't undone and its lot exists, is the account's, and holds at least as
    # many (decision 5, AC-3.4). A lot edited without a merge still counts: the copies come out of it as it now is
    # (AC-3.5). The list preloads the lots, so showing it asks this per line without a query.
    def undoable? = undone_at.nil? && lot.present? && lot.account_id == account_id && lot.quantity >= quantity

    # Takes the line's copies out of its lot, removing the lot when none are left (AC-3.2, AC-3.3), and returns whether
    # the lot went. Raises NotUndoable when it was undone already or its copies changed (AC-3.4).
    def undo!
      transaction do
        reload
        raise NotUndoable unless undoable?

        lot = account.lots.find(lot_id) # the write goes through the account (multi-tenancy rule)
        removed = lot.quantity == quantity
        removed ? lot.destroy! : lot.update!(quantity: lot.quantity - quantity)
        update!(undone_at: Time.current)
        removed
      end
    end

  end
  ```

  `app/models/account.rb` gains, after `has_one :scanner_sitting …`:
  ```ruby
  has_one :number_entry, dependent: :destroy
  ```
- [ ] Run: `bin/rspec spec/models/number_entry_spec.rb spec/models/number_entry/line_spec.rb` — expect: PASS.
- [ ] Run: `bin/rspec spec/export_format_document_spec.rb` — expect: FAIL (the Coverage tables don't list `number_entries` and `number_entry_lines`).
- [ ] In `spec/export_format_document_spec.rb`, "marks each table as the spec rules (AC-3.5)", add the two tables to the "Left out" list:
  ```ruby
        .to match_array(%w[bulk_removals bulk_selection_marks bulk_selections number_entries number_entry_lines scanner_sitting_entries scanner_sittings sessions])
  ```
- [ ] In `docs/export-format/README.md`'s Coverage table, after the `bulk_selections` row, add:
  ```markdown
  | `number_entries` | Left out | Working state of one run of adding cards by number. What it adds is already in the lots. |
  | `number_entry_lines` | Left out | Working state of one run of adding cards by number. What it adds is already in the lots. |
  ```
- [ ] Run: `bin/rspec spec/export_format_document_spec.rb spec/export_format_examples_spec.rb` — expect: PASS.
- [ ] Commit: `feat(number-entry): add the per-account list and its lines` (migrations, schema, models, account, Coverage rows, the document spec's list, specs).

---

## Phase 2: Choosing the set and the language

**Implements:** FR-1 (offered sets), decision 2, decision 9 | **Satisfies:** AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-1.7, AC-1.11 (model level)
**Files:** `app/models/number_entry/set_choice.rb`, `spec/models/number_entry/set_choice_spec.rb`
**Interfaces:** Consumes: `Catalog::Set.newest_first`, `Catalog::Entry.active`. Produces: `NumberEntry::SetChoice.new(text:, type: nil, language: nil)` with `#sets` (Array of `Catalog::Set`), `#text`, `#set`, `#language`, `#languages` (Hash code → count), `#asked?`, `#chosen?`, `#canonical?(params)`, `#to_params` (`{ type:, set:, language: }`), `#label(set)` ("Name (CODE)"), `#unmatched_message`; `NumberEntry::SetChoice.offered`.

- [ ] Write the failing spec `spec/models/number_entry/set_choice_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe NumberEntry::SetChoice do
    let(:mh3) { create(:catalog_set, code: "mh3", name: "Modern Horizons 3", released_on: Date.new(2024, 6, 14)) }

    def entry(set:, language: "en", **attributes) = create(:catalog_entry, set:, language:, **attributes)

    describe ".offered" do
      it "offers sets with an active entry of any kind, newest first, undated last (AC-1.3)", :aggregate_failures do
        tokens = create(:catalog_set, code: "tmh3", name: "Modern Horizons 3 Tokens", released_on: Date.new(2023, 1, 1))
        retired = create(:catalog_set, code: "old", released_on: Date.new(2025, 1, 1))
        undated = create(:catalog_set, code: "nod", released_on: nil)
        entry(set: mh3)
        entry(set: tokens, kind: "token")
        entry(set: retired, retired_at: 1.day.ago)
        entry(set: undated)
        expect(described_class.offered.to_a).to eq([ mh3, tokens, undated ])
      end
    end

    describe "resolving the typed set (AC-1.4)" do
      before { entry(set: mh3) }

      it "takes the code in any case, the name in any case, or the offered label", :aggregate_failures do
        [ "MH3", "mh3", " mh3 ", "modern horizons 3", "Modern Horizons 3", "Modern Horizons 3 (MH3)" ].each do |text|
          expect(described_class.new(text:).set).to eq(mh3), text
        end
      end

      it "finds nothing for text that names no offered set", :aggregate_failures do
        choice = described_class.new(text: "zzz")
        expect(choice).to have_attributes(set: nil, asked?: true, chosen?: false)
        expect(choice.unmatched_message).to eq("No set matches “zzz”. Type a set code or choose a set from the list.")
      end

      it "asks nothing for empty text" do
        expect(described_class.new(text: "")).to have_attributes(set: nil, asked?: false, chosen?: false)
      end

      it "ignores a type or text that isn't a string (a forged parameter)" do
        expect(described_class.new(text: "mh3", type: { "a" => "b" }).set).to eq(mh3)
      end

      it "narrows to the type when one is given" do
        expect(described_class.new(text: "mh3", type: "other").set).to be_nil
      end
    end

    describe "the language" do
      it "defaults to EN when the set has English entries (AC-1.5)", :aggregate_failures do
        entry(set: mh3)
        entry(set: mh3, language: "ja")
        choice = described_class.new(text: "mh3")
        expect(choice.languages.keys).to contain_exactly("en", "ja")
        expect(choice.language).to eq("en")
        expect(choice.to_params).to eq(type: "mtg", set: "mh3", language: "en")
      end

      it "defaults to the most common language without English, ties to the first code (AC-1.6)", :aggregate_failures do
        3.times { entry(set: mh3, language: "ja") }
        entry(set: mh3, language: "de")
        expect(described_class.new(text: "mh3").language).to eq("ja")
        entry(set: mh3, language: "de")
        entry(set: mh3, language: "de")
        expect(described_class.new(text: "mh3").language).to eq("de")
      end

      it "keeps a language the set has, and chooses nothing for one it lacks (AC-1.11)", :aggregate_failures do
        entry(set: mh3)
        entry(set: mh3, language: "ja")
        expect(described_class.new(text: "mh3", language: "ja")).to have_attributes(language: "ja", chosen?: true)
        lacking = described_class.new(text: "mh3", language: "fr")
        expect(lacking).to have_attributes(chosen?: false, asked?: true)
        expect(lacking.unmatched_message).to eq("No set matches “mh3”. Type a set code or choose a set from the list.")
      end
    end

    describe "#canonical?" do
      before { entry(set: mh3) }

      it "holds only for the type, the code and the language as the page links them", :aggregate_failures do
        choice = described_class.new(text: "mh3", type: "mtg", language: "en")
        expect(choice.canonical?(ActionController::Parameters.new(type: "mtg", set: "mh3", language: "en"))).to be(true)
        expect(choice.canonical?(ActionController::Parameters.new(set: "MH3"))).to be(false)
      end
    end

    it "labels a set as its name and code" do
      expect(described_class.new(text: "").label(mh3)).to eq("Modern Horizons 3 (MH3)")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/number_entry/set_choice_spec.rb` — expect: FAIL (`uninitialized constant NumberEntry::SetChoice`).
- [ ] Add to the spec, in `describe "resolving the typed set (AC-1.4)"`:
  ```ruby
      it "finds the page's own link without loading the offered sets", :aggregate_failures do
        choice = described_class.new(text: "mh3", type: "mtg", language: "en")
        expect(choice.set).to eq(mh3)
        expect(choice.instance_variable_get(:@sets)).to be_nil
      end

      it "leaves a linked set whose entries are all retired unchosen" do
        retired = create(:catalog_set, code: "old")
        entry(set: retired, retired_at: 1.day.ago)
        expect(described_class.new(text: "old", type: "mtg")).to have_attributes(chosen?: false)
      end
  ```
- [ ] Implement `app/models/number_entry/set_choice.rb`:
  ```ruby
  # The set and language number entry adds from (spec 026 decision 2): the sets on offer, the typed text resolved to one
  # of them, and the languages of its active entries. The offered sets are loaded once and matched in Ruby, so a code or
  # name in any case matches the way the page's suggestions show it.
  class NumberEntry::SetChoice
    ENGLISH = "en"
    LABELLED = /\A(?<name>.+) \((?<code>[^()\s]+)\)\z/

    attr_reader :sets, :text, :set, :language

    # Every set with an active entry of any kind (decision 9), newest first, undated last.
    def self.offered = Catalog::Set.where(id: Catalog::Entry.active.select(:catalog_set_id)).newest_first

    def initialize(text:, type: nil, language: nil)
      @text = text.to_s.strip
      @set = find_set(type.to_s.presence)
      @language = pick_language(language.to_s) if @set
    end

    # Loaded only when asked for (the set form, or resolving typed text), so a line's add never loads them all.
    def sets = @sets ||= self.class.offered.to_a

    def asked? = text.present?
    def chosen? = set.present? && language.present?

    # The set's active entries per language code (AC-1.5).
    def languages
      @languages ||= set ? Catalog::Entry.active.where(catalog_set_id: set.id).group(:language).count : {}
    end

    def to_params = { type: set.collectible_type, set: set.code, language: }

    # True when the request already names the set and language as the page links them, so it needn't redirect.
    def canonical?(params) = to_params.all? { |name, value| params[name] == value }

    def label(set) = "#{set.name} (#{set.code.upcase})"

    def unmatched_message = "No set matches “#{text}”. Type a set code or choose a set from the list."

    private
      # The page's own link names the type and the exact code: one lookup, and #languages is empty for a set with no
      # active entry, which leaves it unchosen. Typed text is matched against the offered sets.
      def find_set(type)
        return if text.empty?

        linked = Catalog::Set.find_by(collectible_type: type, code: text) if type
        return linked if linked

        candidates = type ? sets.select { it.collectible_type == type } : sets
        labelled = LABELLED.match(text)
        (labelled && candidates.find { it.code.casecmp?(labelled[:code]) && it.name.casecmp?(labelled[:name]) }) ||
          candidates.find { it.code.casecmp?(text) } || candidates.find { it.name.casecmp?(text) }
      end

      # The requested language when the set has it; none when the request names one it lacks (AC-1.11); otherwise EN
      # when the set has it, else the language most of its entries have, ties to the first code (AC-1.5, AC-1.6).
      def pick_language(requested)
        return languages.key?(requested) ? requested : nil if requested.present?
        return ENGLISH if languages.key?(ENGLISH)

        languages.min_by { |code, count| [ -count, code ] }&.first
      end
  end
  ```
- [ ] Run: `bin/rspec spec/models/number_entry/set_choice_spec.rb` — expect: PASS.
- [ ] Commit: `feat(number-entry): choose the set and the language`.

---

## Phase 3: Matching and checking a line

**Implements:** FR-2, FR-3 (finish rule), decisions 3, 8, 10 | **Satisfies:** AC-2.6, AC-2.7, AC-2.8, AC-2.9, AC-2.10, AC-2.15, AC-4.1, AC-4.2, AC-4.3, AC-4.5 (model level)
**Files:** `app/models/number_entry/line_form.rb`, `spec/models/number_entry/line_form_spec.rb`
**Interfaces:** Consumes: `Catalog::Entry.active`, the type's vocabulary, `NumberEntry::KEY_FORMAT`. Produces: `NumberEntry::LineForm.new(set:, language:, number:, quantity:, finish:, line_key:, pick:)` with `#matches`, `#entry`, `#choice?`, `#blank_number?`, `#finish` (defaults to the type's first finish), `#finishes`, `#vocabulary`, `#add_attributes` (`{ entry:, quantity:, finish:, line_key: }`), validations putting errors on `:number`, `:quantity`, `:finish`, `:base`; `NumberEntry::LineForm.normalize(number)`.

- [ ] Write the failing spec `spec/models/number_entry/line_form_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe NumberEntry::LineForm do
    let(:mh3) { create(:catalog_set, code: "mh3", name: "Modern Horizons 3") }
    let(:key) { "a" * 32 }

    def printing(number, language: "en", finishes: %w[nonfoil foil], **attributes)
      entry = create(:catalog_entry, set: mh3, number:, language:, **attributes)
      create(:mtg_printing, entry:, finishes:) if finishes
      entry
    end

    def line(number, quantity: "1", finish: nil, pick: nil, language: "en")
      described_class.new(set: mh3, language:, number:, quantity:, finish:, line_key: key, pick:)
    end

    describe ".normalize" do
      it "trims, ignores case and leading zeros, keeping one character", :aggregate_failures do
        expect([ " 007 ", "117A", "0", "00", "0a" ].map { described_class.normalize(it) }).to eq(%w[7 117a 0 0 a])
      end
    end

    describe "#matches (decision 8)" do
      it "finds an active entry ignoring spaces, case and leading zeros (AC-2.6)", :aggregate_failures do
        seven = printing("7")
        letter = printing("117a")
        expect(line("007").entry).to eq(seven)
        expect(line(" 7 ").entry).to eq(seven)
        expect(line("117A").entry).to eq(letter)
      end

      it "keeps to the chosen language (AC-2.7)" do
        english = printing("47")
        printing("47", language: "ja")
        expect(line("47").entry).to eq(english)
      end

      it "prefers an exact match over one that differs only in case (AC-2.8)", :aggregate_failures do
        lower = printing("12a")
        printing("12A")
        expect(line("12a")).to have_attributes(entry: lower, choice?: false)
      end

      it "asks for a choice when two entries match only ignoring zeros (AC-2.9)", :aggregate_failures do
        printing("049")
        printing("49")
        form = line("0049")
        expect(form.choice?).to be(true)
        expect(form.matches.map(&:number)).to eq(%w[049 49])
        expect(form.entry).to be_nil
      end

      it "takes a picked match, and refuses a pick that isn't one (AC-2.9, AC-2.10)", :aggregate_failures do
        picked = printing("049")
        printing("49")
        elsewhere = create(:catalog_entry, number: "49")
        expect(line("0049", pick: picked.external_key)).to be_valid
        expect(line("0049", pick: picked.external_key).entry).to eq(picked)
        expect(line("0049", pick: elsewhere.external_key)).not_to be_valid
        expect(line("0049", pick: printing("50").external_key)).not_to be_valid
      end

      it "never matches a retired entry", :aggregate_failures do
        printing("48", retired_at: 1.day.ago)
        form = line("48")
        expect(form).not_to be_valid
        expect(form.errors[:number]).to eq([ "No card numbered 48 in Modern Horizons 3 (EN)." ])
      end
    end

    describe "validation" do
      before { printing("47") }

      it "says when no entry has the number (AC-4.1)" do
        form = line("999")
        form.validate
        expect(form.errors[:number]).to eq([ "No card numbered 999 in Modern Horizons 3 (EN)." ])
      end

      it "takes a whole quantity from 1 to 9,999 (AC-4.2)", :aggregate_failures do
        %w[0 -1 2.5 x 10000].each do |quantity|
          form = line("47", quantity:)
          expect(form).not_to be_valid
          expect(form.errors[:quantity]).to eq([ "must be a whole number from 1 to 9,999" ]), quantity
        end
        expect(line("47", quantity: " 4 ")).to be_valid
      end

      it "refuses a finish the entry doesn't offer (AC-4.3)", :aggregate_failures do
        printing("50", finishes: %w[nonfoil])
        form = line("50", finish: "foil")
        expect(form).not_to be_valid
        expect(form.errors[:finish]).to eq([ "isn't available for this printing" ])
      end

      it "refuses a malformed line key" do
        form = described_class.new(set: mh3, language: "en", number: "47", line_key: "x")
        expect(form).not_to be_valid
      end

      it "treats an empty number as blank, not as an error (AC-4.5)", :aggregate_failures do
        expect(line("  ").blank_number?).to be(true)
        expect(line("47").blank_number?).to be(false)
      end
    end

    describe "#finish (decision 3)" do
      it "defaults to the type's first finish and keeps a chosen one", :aggregate_failures do
        expect(line("47").finish).to eq(Catalog.collecting_for("mtg").finish_order.first)
        expect(line("47", finish: "foil").finish).to eq("foil")
      end
    end

    describe "#add_attributes" do
      it "gives the entry, the quantity, the finish and the key", :aggregate_failures do
        entry = printing("47")
        expect(line("47", quantity: "4", finish: "foil").add_attributes).to eq(entry:, quantity: 4, finish: "foil", line_key: key)
      end

      it "gives no finish for an entry that lists none (AC-2.15)", :aggregate_failures do
        printing("60", finishes: nil)
        form = line("60")
        expect(form).to be_valid
        expect(form.add_attributes[:finish]).to be_nil
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/number_entry/line_form_spec.rb` — expect: FAIL (`uninitialized constant NumberEntry::LineForm`).
- [ ] Implement `app/models/number_entry/line_form.rb`:
  ```ruby
  # One line of number entry (spec 026 decisions 3, 8 and 10): the number, quantity and finish as typed, the line key,
  # and the entry they match among the active entries of the chosen set and language. Errors sit on their own field.
  class NumberEntry::LineForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :number, :string
    attribute :quantity, :string, default: "1"
    attribute :finish, :string
    attribute :line_key, :string
    attribute :pick, :string
    attr_accessor :set, :language

    validate :line_key_well_formed, :quantity_in_range, :single_entry, :finish_offered

    # A number as decision 8's second step compares it: trimmed, lower case, without leading zeros, at least one character.
    def self.normalize(number) = number.to_s.strip.downcase.sub(/\A0+(?=.)/, "")

    def vocabulary = Catalog.collecting_for(set.collectible_type)
    def finishes = vocabulary.finish_order

    # The chosen finish, or the type's first one (decision 3).
    def finish = super.presence || finishes.first

    def blank_number? = number.to_s.strip.empty? && pick.blank?

    # More than one entry matches and the collector hasn't picked one (AC-2.9).
    def choice? = !blank_number? && pick.blank? && matches.size > 1

    # The active entries of the set and language this number matches: those equal to the trimmed text, or only if there
    # are none, those equal to it ignoring case and leading zeros (decision 8).
    def matches = @matches ||= find_matches

    # The one entry the line adds: the only match, or the picked one among the matches (AC-2.10).
    def entry
      return matches.find { it.external_key == pick } if pick.present?

      matches.first if matches.one?
    end

    def add_attributes = { entry:, quantity: parsed_quantity, finish: (finish if entry_finishes.any?), line_key: }

    private
      def find_matches
        candidates = Catalog::Entry.active.where(catalog_set_id: set.id, language:)
        typed = number.to_s.strip
        exact = candidates.where(number: typed).includes(:set).to_a
        return exact if exact.any?

        wanted = self.class.normalize(typed)
        ids = candidates.pluck(:id, :number).filter_map { |id, printed| id if self.class.normalize(printed) == wanted }
        ids.empty? ? [] : candidates.where(id: ids).includes(:set).order(:number).to_a
      end

      def parsed_quantity = Integer(quantity.to_s.strip, 10, exception: false)

      def entry_finishes = @entry_finishes ||= vocabulary.finishes_for(entry)

      def line_key_well_formed
        errors.add(:base, "That line couldn't be added. Try again.") unless NumberEntry::KEY_FORMAT.match?(line_key.to_s)
      end

      def quantity_in_range
        errors.add(:quantity, "must be a whole number from 1 to 9,999") unless parsed_quantity&.between?(1, Lot::MAX_QUANTITY)
      end

      def single_entry
        return if entry || choice?

        errors.add(:number, "No card numbered #{number.to_s.strip} in #{set.name} (#{language.upcase}).")
      end

      # An entry that lists finishes takes one of them; one that lists none takes none, whatever the field says.
      def finish_offered
        return unless entry && entry_finishes.any? && entry_finishes.exclude?(finish)

        errors.add(:finish, "isn't available for this printing")
      end
  end
  ```
- [ ] Run: `bin/rspec spec/models/number_entry/line_form_spec.rb` — expect: PASS.
- [ ] Commit: `feat(number-entry): match a line's number and check it`.

---

## Phase 4: The page, choosing a set, and the ways in

**Implements:** FR-1 | **Satisfies:** AC-1.1 (request), AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.7, AC-1.8, AC-1.9, AC-1.10, AC-1.11
**Files:** `config/routes.rb`, `app/views/layouts/application.html.erb`, `app/controllers/concerns/number_entry_page.rb`, `app/controllers/collections/number_entries_controller.rb`, `app/helpers/number_entries_helper.rb`, `app/views/collections/number_entries/show.html.erb`, `app/views/collections/number_entries/_set_form.html.erb`, `app/views/collections/number_entries/_chosen_set.html.erb`, `app/views/collections/number_entries/_line_form.html.erb`, `app/views/collections/number_entries/_choice.html.erb`, `app/views/collections/number_entries/_list.html.erb`, `app/views/collections/number_entries/_line.html.erb`, `app/views/collections/show.html.erb`, `app/views/mores/show.html.erb`, `spec/requests/number_entries_spec.rb`, `spec/requests/collections_spec.rb`
**Interfaces:** Consumes: `NumberEntry::SetChoice`, `NumberEntry::LineForm`, `NumberEntry#kept_lines`, `NumberEntry::SHOWN`, `NumberEntry.new_line_key`. Produces: routes `collection_number_entry_path` (GET), `collection_number_entry_lines_path` (POST), `collection_number_entry_line_undo_path(line)` (POST), `collection_number_entry_ending_path` (POST); concern `NumberEntryPage` (`set_choice`, `render_page(status:)`, `page_path(finish:)`); helpers `number_entry_copy(line)`, `number_entry_finish(line)`; every partial of the page (Phases 5–6 add the controllers that post to it).

Every partial is written here, so later phases only add controllers and tests. The page renders without scripting.

The layout turns morph refreshes on for every page (`turbo_refreshes_with method: :morph`). An add redirects back to the URL the page is on, and a rejected line answers 422 on it, so Turbo treats both as page refreshes and morphs them; the morphing renderer never autofocuses, and a morphed input never reconnects its Stimulus target. Number entry's whole keyboard flow rests on the focus moving after each answer, so this page asks for `replace` refreshes, which render with Turbo's page renderer and honour `autofocus`. The layout keeps morph as every other page's method.

- [ ] Write the failing request spec `spec/requests/number_entries_spec.rb` (Phases 5 and 6 add to it):
  ```ruby
  require "rails_helper"

  RSpec.describe "Number entry", type: :request do
    let(:user) { create(:user) }
    let(:mh3) { create(:catalog_set, code: "mh3", name: "Modern Horizons 3", released_on: Date.new(2024, 6, 14)) }
    let(:page_params) { { type: "mtg", set: "mh3", language: "en" } }

    def printing(number, name = "Card #{number}", set: mh3, language: "en", finishes: %w[nonfoil foil], **attributes)
      entry = create(:catalog_entry, set:, number:, language:, identity: create(:catalog_identity, name:), name:, **attributes)
      create(:mtg_printing, entry:, finishes:) if finishes
      entry
    end

    def add(number, quantity: "1", finish: nil, line_key: SecureRandom.hex(16), pick: nil, **context)
      post collection_number_entry_lines_path,
        params: { **page_params, **context, line: { number:, quantity:, finish:, line_key:, pick: }.compact }
    end

    context "when signed in" do
      before { sign_in_as(user) }

      describe "the ways in" do
        it "links Add by number from the collection's header and its empty message, and from More (AC-1.1, AC-1.2)", :aggregate_failures do
          get collection_path
          expect(response.body).to include(%(<a class="c-btn c-btn--secondary" href="#{collection_number_entry_path}">Add by number</a>))
          expect(response.body).to include(%(No cards in your collection yet. Search for a card or <a href="#{collection_number_entry_path}">add cards by number</a> to start adding.))
          get more_path
          expect(Nokogiri::HTML5(response.body).at_css(".c-more li:nth-child(3) a")&.text).to eq("Add by number")
          expect(response.body).to include(%(<a href="#{collection_number_entry_path}">Add by number</a>))
        end
      end

      describe "choosing a set" do
        it "starts with the set field, focused, offering sets newest first (AC-1.1, AC-1.3)", :aggregate_failures do
          printing("1")
          older = create(:catalog_set, code: "tmh3", name: "Modern Horizons 3 Tokens", released_on: Date.new(2023, 1, 1))
          printing("1", set: older, kind: "token")
          get collection_number_entry_path
          expect(response.body).to include("<h1 class=\"c-pagehead__title\">Add by number</h1>")
          expect(response.body).to match(/<input[^>]*id="number_entry_set"[^>]*autofocus/)
          expect(response.body.index("Modern Horizons 3 (MH3)")).to be < response.body.index("Modern Horizons 3 Tokens (TMH3)")
          expect(response.body).not_to include('id="line_number"')
        end

        it "takes a code, a name or a label, and links the set as type, code and language (AC-1.4, AC-1.5)", :aggregate_failures do
          printing("1")
          [ "MH3", "mh3", "modern horizons 3", "Modern Horizons 3 (MH3)" ].each do |text|
            get collection_number_entry_path(set: text)
            expect(response).to redirect_to(collection_number_entry_path(**page_params)), text
          end
          follow_redirect!
          expect(response.body).to include("Modern Horizons 3", "MH3", "Change set")
          expect(response.body).to match(/<input[^>]*id="line_number"[^>]*autofocus/)
        end

        it "offers the set's languages, EN chosen (AC-1.5)", :aggregate_failures do
          printing("1")
          printing("1", language: "ja")
          get collection_number_entry_path(**page_params)
          expect(response.body).to include('<option selected="selected" value="en">EN</option>', '<option value="ja">JA</option>')
        end

        it "states a set's one language with no field (AC-1.7)", :aggregate_failures do
          printing("1")
          get collection_number_entry_path(**page_params)
          expect(response.body).to include("Language: EN")
          expect(response.body).not_to include('id="number_entry_language"')
        end

        it "says when no set matches, keeping the text (AC-1.8)", :aggregate_failures do
          printing("1")
          get collection_number_entry_path(set: "zzz")
          expect(response.body).to include("No set matches “zzz”. Type a set code or choose a set from the list.", 'value="zzz"')
          expect(response.body).not_to include('id="line_number"')
        end

        it "answers a forged type parameter without an error" do
          printing("1")
          get collection_number_entry_path(set: "mh3", type: { a: "b" })
          expect(response).to redirect_to(collection_number_entry_path(**page_params))
        end

        it "says so for a language the set lacks (AC-1.11)" do
          printing("1")
          get collection_number_entry_path(**page_params, language: "fr")
          expect(response.body).to include("No set matches “mh3”. Type a set code or choose a set from the list.")
        end

        it "shows the list under the set field after Change set (AC-1.9)", :aggregate_failures do
          NumberEntry.add!(account: user.account, entry: printing("1", "Flare"), quantity: 1, finish: "nonfoil", line_key: "a" * 32)
          get collection_number_entry_path
          expect(response.body).to include('id="number_entry_set"', "This list: 1 line, 1 card", "Flare")
        end

        it "replaces the page on a refresh, where other pages morph", :aggregate_failures do
          printing("1")
          get collection_number_entry_path(**page_params)
          expect(response.body).to include('<meta name="turbo-refresh-method" content="replace">')
          get collection_path
          expect(response.body).to include('<meta name="turbo-refresh-method" content="morph">')
        end

        it "says when the catalog has no sets, showing no form", :aggregate_failures do
          get collection_number_entry_path
          expect(response.body).to include("The card catalog hasn't been loaded yet.")
          expect(response.body).not_to include('id="number_entry_set"')
        end
      end
    end

    context "when signed out" do
      it "sends a visitor to sign in (AC-1.10)" do
        get collection_number_entry_path
        expect(response).to redirect_to(new_session_path)
      end

      it "sends a visitor to sign in when the catalog is open (AC-1.10)", :public_catalog do
        get collection_number_entry_path(**page_params)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
  ```
  In `spec/requests/collections_spec.rb`, the empty-state example's expectation becomes:
  ```ruby
  expect(response.body).to include("My collection", "No cards in your collection yet. Search for a card or")
  ```
- [ ] Run: `bin/rspec spec/requests/number_entries_spec.rb spec/requests/collections_spec.rb` — expect: FAIL (`undefined local variable or method 'collection_number_entry_path'`).
- [ ] Let a page choose its refresh method. In `app/views/layouts/application.html.erb`, the refresh line becomes:
  ```erb
      <%# A page may ask for another refresh method (number entry asks for replace, so autofocus works; spec 026). %>
      <%= turbo_refreshes_with method: content_for(:turbo_refresh_method).presence&.to_sym || :morph, scroll: :preserve %>
  ```
- [ ] Add the routes. In `config/routes.rb`, inside `resource :collection … scope module: :collections do`, after `resources :bulk_removals …`:
  ```ruby
      # Number entry (spec 026): add cards from a set by collector number.
      resource :number_entry, only: :show do
        scope module: :number_entries do
          resources :lines, only: :create do
            resource :undo, only: :create, module: :lines
          end
          resource :ending, only: :create
        end
      end
  ```
- [ ] Write the concern `app/controllers/concerns/number_entry_page.rb`:
  ```ruby
  # Number entry's page as each of its actions shows it (spec 026): the chosen set and language, the line form with a
  # fresh line key, and the account's list, newest first.
  module NumberEntryPage
    extend ActiveSupport::Concern

    private
      def set_choice
        @choice ||= NumberEntry::SetChoice.new(text: params[:set], type: params[:type], language: params[:language])
      end

      def render_page(status: :ok)
        set_choice
        @line ||= NumberEntry::LineForm.new(set: @choice.set, language: @choice.language, finish: params[:finish]) if @choice.chosen?
        @line_key = NumberEntry.new_line_key
        list = Current.account.number_entry
        @lines = list ? list.kept_lines.to_a : []
        @unloaded_catalogs = Catalog.unloaded_titles
        @catalogs_named = Catalog.sources.many?
        render "collections/number_entries/show", status:
      end

      # The page for the chosen set and language, keeping the finish; the bare page when none is chosen.
      def page_path(finish: params[:finish])
        set_choice
        collection_number_entry_path(**(@choice.chosen? ? @choice.to_params : {}), finish: finish.presence)
      end
  end
  ```
- [ ] Write `app/controllers/collections/number_entries_controller.rb`:
  ```ruby
  # Number entry (spec 026): choose a set and a language, then add cards by collector number, line after line. A typed
  # set redirects to the page's own link for it (type, code and language), so a reload or Back keeps the choice.
  class Collections::NumberEntriesController < ApplicationController
    include NumberEntryPage

    def show
      set_choice
      return redirect_to(page_path) if @choice.chosen? && !@choice.canonical?(params)

      render_page
    end
  end
  ```
- [ ] Write `app/helpers/number_entries_helper.rb`:
  ```ruby
  module NumberEntriesHelper
    # "Psychic Frog (MH3 · 47, <finish label>)": a line's card, set and number, and finish (spec 026).
    def number_entry_copy(line)
      "#{line.entry.name} (#{[ set_number(line.entry), number_entry_finish_label(line) ].compact.join(", ")})"
    end

    # A line's finish as the copies table shows one (spec 004 AC-8.5): a special finish as the one badge, any other as
    # muted text, "—" when it has none.
    def number_entry_finish(line)
      label = number_entry_finish_label(line)
      return "—" unless label

      special = Catalog.collecting_for(line.entry.collectible_type).special_finishes.include?(line.finish)
      special ? render("catalog/entries/finish_badge", label:) : tag.span(label, class: "is-muted")
    end

    def number_entry_finish_label(line) = line.finish && Catalog.collecting_for(line.entry.collectible_type).finish_label(line.finish)
  end
  ```
- [ ] Write the views.

  `app/views/collections/number_entries/show.html.erb`:
  ```erb
  <% content_for :title, "Add by number · Collector" %>
  <%# Back refetches the page, so it never restores a typed number or a stale list. %>
  <% content_for :head, tag.meta(name: "turbo-cache-control", content: "no-cache") %>
  <%# Each answer comes back to this URL; replace (not morph) lets the focus move to the field that needs it. %>
  <% content_for :turbo_refresh_method, "replace" %>
  <%= render "layouts/appbar", section: :collection, detail: true, back_path: collection_path %>
  <main class="c-main c-page">
    <div class="c-pagehead"><div><h1 class="c-pagehead__title">Add by number</h1></div></div>
    <%= render "catalog/not_loaded", titles: @unloaded_catalogs, named: @catalogs_named %>
    <div class="c-numentry">
      <% if @choice.chosen? %>
        <%= render "collections/number_entries/chosen_set", choice: @choice, finish: @line.finish %>
        <%= render "collections/number_entries/choice", choice: @choice, line: @line, line_key: @line_key if @line.choice? %>
        <%= render "collections/number_entries/line_form", choice: @choice, line: @line, line_key: @line_key %>
      <% elsif @choice.sets.any? %>
        <%= render "collections/number_entries/set_form", choice: @choice, named: @catalogs_named %>
      <% end %>
      <%= render "collections/number_entries/list", lines: @lines,
            page_params: @choice.chosen? ? { **@choice.to_params, finish: @line.finish } : {} %>
    </div>
  </main>
  <%= render "layouts/tabbar", section: :collection %>
  ```

  `app/views/collections/number_entries/_set_form.html.erb`:
  ```erb
  <%# locals: (choice:, named:) %>
  <%# Spec 026 decision 2: one text field with the offered sets as native suggestions, so typing filters them without
      scripting; the server resolves a code, a name or the "Name (CODE)" label. %>
  <% unmatched = choice.asked? && !choice.chosen? %>
  <%= form_with url: collection_number_entry_path, method: :get, class: "c-form" do %>
    <div class="c-field<%= " c-field--invalid" if unmatched %>">
      <label class="c-field__label" for="number_entry_set">Set</label>
      <label class="c-input"><%= text_field_tag :set, choice.text, id: "number_entry_set", list: "number_entry_sets",
            required: true, autofocus: true, "aria-describedby": (unmatched ? "number_entry_set_error" : "number_entry_set_hint") %></label>
      <% if unmatched %>
        <p class="c-field__error" id="number_entry_set_error"><%= choice.unmatched_message %></p>
      <% else %>
        <p class="c-field__hint" id="number_entry_set_hint">Type a set code or name.</p>
      <% end %>
      <datalist id="number_entry_sets">
        <% choice.sets.each do |set| %><%= tag.option(value: choice.label(set), label: (Catalog.title_for(set.collectible_type) if named)) %><% end %>
      </datalist>
    </div>
    <div class="c-form__actions"><%= submit_tag "Choose set", name: nil, class: "c-btn c-btn--primary" %></div>
  <% end %>
  ```

  `app/views/collections/number_entries/_chosen_set.html.erb`:
  ```erb
  <%# locals: (choice:, finish:) %>
  <%# The chosen set and language (spec 026 decision 2): the language is a field only when the set has more than one. %>
  <div class="c-numentry__set">
    <p class="c-numentry__setname"><strong><%= choice.set.name %></strong> <span class="c-numentry__data"><%= choice.set.code.upcase %></span></p>
    <% if choice.languages.size > 1 %>
      <%= form_with url: collection_number_entry_path, method: :get, class: "c-numentry__language" do %>
        <%= hidden_field_tag :type, choice.set.collectible_type, id: nil %>
        <%= hidden_field_tag :set, choice.set.code, id: nil %>
        <%= hidden_field_tag :finish, finish, id: nil %>
        <label class="c-select"><span class="c-field__label">Language</span><%= select_tag :language,
              options_for_select(choice.languages.keys.sort.map { [ it.upcase, it ] }, choice.language), id: "number_entry_language" %></label>
        <%= submit_tag "Change language", name: nil, class: "c-btn c-btn--secondary c-btn--sm" %>
      <% end %>
    <% else %>
      <p class="c-numentry__data">Language: <%= choice.language.upcase %></p>
    <% end %>
    <%= link_to "Change set", collection_number_entry_path, class: "c-btn c-btn--ghost c-btn--sm" %>
  </div>
  ```

  `app/views/collections/number_entries/_line_form.html.erb`:
  ```erb
  <%# locals: (choice:, line:, line_key:) %>
  <%# One line (spec 026 decision 3): number, quantity and finish, in tab order; Enter adds it. The first field with an
      error takes the focus, the number otherwise, unless a choice between matches is showing (it takes the focus). %>
  <% focus = (%i[number quantity finish] & line.errors.attribute_names).first || :number %>
  <%# novalidate: the server's messages (AC-4.2) show, not the browser's own bubbles. %>
  <%= form_with url: collection_number_entry_lines_path, class: "c-numentry__line", html: { novalidate: true }, data: { controller: "number-entry" } do %>
    <% choice.to_params.each do |name, value| %><%= hidden_field_tag name, value, id: nil %><% end %>
    <%= hidden_field_tag "line[line_key]", line_key, id: nil %>
    <% line.errors[:base].each do |message| %><p class="c-field__error"><%= message %></p><% end %>
    <div class="c-field<%= " c-field--invalid" if line.errors[:number].any? %>">
      <label class="c-field__label" for="line_number">Number</label>
      <label class="c-input"><%= text_field_tag "line[number]", line.number, id: "line_number", class: "c-numentry__data-input", autocomplete: "off", spellcheck: false,
            autofocus: (focus == :number && !line.choice?), "aria-describedby": ("line_number_error" if line.errors[:number].any?),
            data: { number_entry_target: "number", select: line.errors[:number].any? } %></label>
      <% line.errors[:number].each do |message| %><p class="c-field__error" id="line_number_error"><%= message %></p><% end %>
    </div>
    <div class="c-field<%= " c-field--invalid" if line.errors[:quantity].any? %>">
      <label class="c-field__label" for="line_quantity">Quantity</label>
      <label class="c-input"><%= number_field_tag "line[quantity]", line.quantity, id: "line_quantity", class: "c-numentry__data-input", min: 1, max: Lot::MAX_QUANTITY, step: 1,
            inputmode: "numeric", required: true, autofocus: focus == :quantity,
            "aria-describedby": ("line_quantity_error" if line.errors[:quantity].any?) %></label>
      <% lot_error_messages(line, :quantity).each do |message| %><p class="c-field__error" id="line_quantity_error"><%= message %></p><% end %>
    </div>
    <% if line.finishes.any? %>
      <div class="c-field<%= " c-field--invalid" if line.errors[:finish].any? %>">
        <label class="c-field__label" for="line_finish">Finish</label>
        <%= select_tag "line[finish]", options_for_select(line.finishes.map { [ line.vocabulary.finish_label(it), it ] }, line.finish),
              id: "line_finish", autofocus: focus == :finish, "aria-describedby": ("line_finish_error" if line.errors[:finish].any?),
              data: { action: "keydown.enter->number-entry#submit" } %>
        <% lot_error_messages(line, :finish).each do |message| %><p class="c-field__error" id="line_finish_error"><%= message %></p><% end %>
      </div>
    <% end %>
    <div class="c-numentry__add"><%= submit_tag "Add", name: nil, class: "c-btn c-btn--primary" %></div>
  <% end %>
  ```

  `app/views/collections/number_entries/_choice.html.erb`:
  ```erb
  <%# locals: (choice:, line:, line_key:) %>
  <%# Two or more entries match the number (spec 026 AC-2.9): each is a button that adds the line as typed, naming the
      entry by its external key, which the server checks against the set, language and number (AC-2.10). %>
  <section class="c-numentry__choice" aria-labelledby="number-entry-choice-heading">
    <p class="c-numentry__prompt" id="number-entry-choice-heading">More than one card matches <%= line.number.to_s.strip %>. Choose one.</p>
    <ul class="c-list">
      <% line.matches.each_with_index do |entry, index| %>
        <li><%= button_to "#{entry.name} (#{set_number(entry)})", collection_number_entry_lines_path, class: "c-btn c-btn--secondary",
              autofocus: index.zero?, params: { **choice.to_params,
                line: { number: line.number, quantity: line.quantity, finish: line.finish, line_key:, pick: entry.external_key } } %></li>
      <% end %>
    </ul>
  </section>
  ```

  `app/views/collections/number_entries/_list.html.erb`:
  ```erb
  <%# locals: (lines:, page_params:) %>
  <%# The account's list (spec 026 Story 3): the 10 newest lines, the rest behind "Show all", and Done. %>
  <% if lines.any? %>
    <section id="number_entry_list" class="c-numentry__list" aria-labelledby="number-entry-list-heading">
      <div class="c-section__head">
        <h2 class="c-section__title" id="number-entry-list-heading">This list: <%= pluralize(lines.size, "line") %>, <%= pluralize(lines.sum(&:quantity), "card") %></h2>
        <span class="c-section__actions"><%= button_to "Done", collection_number_entry_ending_path, class: "c-btn c-btn--secondary c-btn--sm" %></span>
      </div>
      <ul class="c-list"><%= render partial: "collections/number_entries/line", collection: lines.first(NumberEntry::SHOWN), as: :line, locals: { page_params: } %></ul>
      <% if lines.size > NumberEntry::SHOWN %>
        <details class="c-numentry__more">
          <summary class="c-btn c-btn--ghost c-btn--sm">Show all <%= lines.size %></summary>
          <ul class="c-list"><%= render partial: "collections/number_entries/line", collection: lines.drop(NumberEntry::SHOWN), as: :line, locals: { page_params: } %></ul>
        </details>
      <% end %>
    </section>
  <% end %>
  ```

  `app/views/collections/number_entries/_line.html.erb`:
  ```erb
  <%# locals: (line:, page_params:) %>
  <li>
    <span><%= line.entry.name %></span>
    <span class="c-list__meta"><span class="c-numentry__data"><%= set_number(line.entry) %> · ×<%= line.quantity %></span> · <%= number_entry_finish(line) %></span>
    <span class="c-list__end">
      <% if line.undoable? %>
        <%= button_to "Undo", collection_number_entry_line_undo_path(line), params: page_params, class: "c-btn c-btn--secondary c-btn--sm",
              "aria-label": "Undo #{line.quantity} × #{number_entry_copy(line)}" %>
      <% else %>
        <span class="c-tag">Changed in your collection</span>
      <% end %>
    </span>
  </li>
  ```

  `app/views/collections/show.html.erb`: the page head's actions become
  ```erb
    <div class="c-pagehead__actions"><%= link_to "Add by number", collection_number_entry_path, class: "c-btn c-btn--secondary" %><%= link_to scanner_path, class: "c-btn c-btn--secondary", data: { turbo_prefetch: false } do %><%= render "icons/scan" %>Scan cards<% end %><%= link_to catalog_entries_path, class: "c-btn c-btn--primary" do %><%= render "icons/plus" %>Add items<% end %></div>
  ```
  and the empty state becomes
  ```erb
    <p class="c-empty">No cards in your collection yet. Search for a card or <%= link_to "add cards by number", collection_number_entry_path %> to start adding. <%= link_to "Search cards", catalog_entries_path %></p>
  ```

  `app/views/mores/show.html.erb`: right after the "Export collection" item (ruling, 2026-10-15), add
  ```erb
    <li><%= link_to "Add by number", collection_number_entry_path %></li>
  ```
- [ ] Run: `bin/rspec spec/requests/number_entries_spec.rb spec/requests/collections_spec.rb` — expect: PASS.
- [ ] Run: `bin/rspec spec/requests spec/system/page_head_spec.rb spec/system/collection_spec.rb` — expect: PASS (no other page's expectations broke on the new button or message; fix any that pin the old empty-state sentence).
- [ ] Commit: `feat(number-entry): the page, choosing a set, and links from the collection and More`.

---

## Phase 5: Adding lines

**Implements:** FR-2, FR-3 | **Satisfies:** AC-2.1, AC-2.3, AC-2.4 (request), AC-2.5, AC-2.6, AC-2.7, AC-2.9, AC-2.10, AC-2.11, AC-2.12, AC-2.14, AC-2.15, AC-4.1, AC-4.2, AC-4.3, AC-4.4, AC-4.5
**Files:** `app/controllers/collections/number_entries/lines_controller.rb`, `spec/requests/number_entries_spec.rb`
**Interfaces:** Consumes: `NumberEntryPage`, `NumberEntry::LineForm`, `NumberEntry.add!`, `number_entry_copy`. Produces: `Collections::NumberEntries::LinesController#create`.

- [ ] Add the failing examples to `spec/requests/number_entries_spec.rb`, inside `context "when signed in"`:
  ```ruby
      describe "adding a line" do
        it "adds a copy with the type's first finish and lists it, keeping the set (AC-2.1, AC-2.2)", :aggregate_failures do
          entry = printing("47", "Psychic Frog")
          add("47")
          expect(response).to redirect_to(collection_number_entry_path(**page_params, finish: "nonfoil"))
          expect(user.account.lots.sole).to have_attributes(entry:, quantity: 1, finish: "nonfoil", condition: nil, price_paid_cents: nil)
          follow_redirect!
          expect(response.body).to include("Added 1 × Psychic Frog (MH3 · 47, Nonfoil) to your collection.", "This list: 1 line, 1 card", "MH3 · 47 · ×1")
          expect(response.body).to match(/<input[^>]*id="line_number"[^>]*value=""|<input(?![^>]*value=)[^>]*id="line_number"/)
        end

        it "adds the quantity typed (AC-2.3)" do
          printing("47")
          add("47", quantity: "4")
          expect(user.account.lots.sole.quantity).to eq(4)
        end

        it "adds a chosen finish and keeps it for the next line (AC-2.4)", :aggregate_failures do
          printing("47")
          add("47", finish: "foil")
          expect(user.account.lots.sole.finish).to eq("foil")
          follow_redirect!
          expect(response.body).to include('<option selected="selected" value="foil">Foil</option>')
        end

        it "merges into the lot of the same identity (AC-2.5)", :aggregate_failures do
          entry = printing("47")
          create(:lot, account: user.account, entry:, finish: "nonfoil", quantity: 2)
          add("47", quantity: "3", finish: "nonfoil")
          expect(user.account.lots.sole.quantity).to eq(5)
        end

        it "matches ignoring spaces, case and leading zeros, in the chosen language (AC-2.6, AC-2.7)", :aggregate_failures do
          seven = printing("7")
          letter = printing("117a")
          printing("7", language: "ja")
          [ "007", " 7 ", "117A" ].each { add(it) }
          expect(user.account.lots.to_h { [ it.entry, it.quantity ] }).to eq(seven => 2, letter => 1)
        end

        it "asks which of two matches, adding nothing, and adds the one picked (AC-2.9)", :aggregate_failures do
          one = printing("049", "Frog A")
          printing("49", "Frog B")
          add("0049", quantity: "2")
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("More than one card matches 0049. Choose one.", "Frog A (MH3 · 049)", "Frog B (MH3 · 49)")
          expect(user.account.lots).to be_empty
          add("0049", quantity: "2", pick: one.external_key)
          expect(user.account.lots.sole).to have_attributes(entry: one, quantity: 2)
        end

        it "adds nothing for a pick that isn't one of the matches (AC-2.10)", :aggregate_failures do
          printing("049")
          printing("49")
          elsewhere = create(:catalog_entry, number: "49")
          add("0049", pick: elsewhere.external_key)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("No card numbered 0049 in Modern Horizons 3 (EN).")
          expect(user.account.lots).to be_empty
        end

        it "adds a line once for one line key, and twice for two (AC-2.11, AC-2.12)", :aggregate_failures do
          printing("47")
          add("47", line_key: "a" * 32)
          add("47", line_key: "a" * 32)
          expect(user.account.lots.sole.quantity).to eq(1)
          add("47", line_key: "b" * 32)
          expect(user.account.lots.sole.quantity).to eq(2)
          expect(user.account.number_entry.lines.count).to eq(2)
        end

        it "adds a token from a token set (AC-2.14)" do
          tokens = create(:catalog_set, code: "tmh3", name: "Modern Horizons 3 Tokens")
          token = printing("5", set: tokens, kind: "token", finishes: %w[nonfoil])
          add("5", set: "tmh3")
          expect(user.account.lots.sole.entry).to eq(token)
        end

        it "adds no finish for an entry that lists none (AC-2.15)" do
          printing("60", finishes: nil)
          add("60")
          expect(user.account.lots.sole.finish).to be_nil
        end
      end

      describe "a rejected line" do
        it "keeps the line when no entry has the number (AC-4.1)", :aggregate_failures do
          printing("47")
          add("999", quantity: "3", finish: "foil")
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("No card numbered 999 in Modern Horizons 3 (EN).", 'value="999"', 'value="3"',
            '<option selected="selected" value="foil">Foil</option>')
          expect(response.body).to match(/<input[^>]*id="line_number"[^>]*autofocus/)
          expect(response.body).to include('data-select="true"')
          expect(user.account.lots).to be_empty
        end

        it "says what's wrong with the quantity, focusing it (AC-4.2)", :aggregate_failures do
          printing("47")
          %w[0 -1 2.5 x 10000].each do |quantity|
            add("47", quantity:)
            expect(response.body).to include("Quantity must be a whole number from 1 to 9,999"), quantity
            expect(response.body).to match(/<input[^>]*id="line_quantity"[^>]*autofocus/)
          end
          expect(user.account.lots).to be_empty
        end

        it "refuses a finish the entry doesn't offer (AC-4.3)", :aggregate_failures do
          printing("50", finishes: %w[nonfoil])
          add("50", finish: "foil")
          expect(response.body).to include("Finish isn&#39;t available for this printing")
          expect(user.account.lots).to be_empty
        end

        it "refuses at the lot cap (AC-4.4)", :aggregate_failures do
          entry = printing("47")
          create(:lot, account: user.account, entry:, finish: "nonfoil", quantity: 9_998)
          add("47", quantity: "2")
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("One lot can hold at most 9,999 copies.")
          expect(user.account.lots.sole.quantity).to eq(9_998)
          expect(NumberEntry::Line.count).to eq(0)
        end

        it "adds nothing for an empty number, with no message (AC-4.5)", :aggregate_failures do
          printing("47")
          add("  ")
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).not_to include("c-field__error")
          expect(response.body).to match(/<input[^>]*id="line_number"[^>]*autofocus/)
          expect(user.account.lots).to be_empty
        end
      end
  ```
- [ ] Run: `bin/rspec spec/requests/number_entries_spec.rb` — expect: FAIL (`uninitialized constant Collections::NumberEntries::LinesController`).
- [ ] Implement `app/controllers/collections/number_entries/lines_controller.rb`:
  ```ruby
  # Adds one line of number entry: its copies merge into the collector's lots and the line joins the list (spec 026
  # Story 2). A rejected line, or one that needs a choice between matches, comes back as typed and nothing changes (Story 4).
  class Collections::NumberEntries::LinesController < ApplicationController
    include NumberEntryPage

    def create
      set_choice
      return redirect_to(page_path, status: :see_other) unless @choice.chosen?

      @line = NumberEntry::LineForm.new(**line_params, set: @choice.set, language: @choice.language)
      return render_page(status: :unprocessable_content) if @line.blank_number? || @line.choice? || @line.invalid?

      added = NumberEntry.add!(account: Current.account, **@line.add_attributes)
      redirect_to page_path(finish: @line.finish), status: :see_other,
        notice: "Added #{added.line.quantity} × #{helpers.number_entry_copy(added.line)} to your collection."
    rescue ActiveRecord::RecordInvalid
      flash.now[:alert] = Lot::FULL_MESSAGE
      render_page(status: :unprocessable_content)
    end

    private
      def line_params = params.expect(line: %i[number quantity finish line_key pick]).to_h.symbolize_keys
  end
  ```
- [ ] Run: `bin/rspec spec/requests/number_entries_spec.rb` — expect: PASS.
- [ ] Commit: `feat(number-entry): add a line by number, quantity and finish`.

---

## Phase 6: Undo, Done, and working without scripting

**Implements:** FR-4 | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.6, AC-3.7, AC-3.8, AC-5.1, NFR Performance (query count)
**Files:** `app/controllers/collections/number_entries/lines/undos_controller.rb`, `app/controllers/collections/number_entries/endings_controller.rb`, `spec/requests/number_entries_spec.rb`
**Interfaces:** Consumes: `NumberEntryPage`, `NumberEntry::Line#undo!`, `NumberEntry::Line::NotUndoable`, `BulkRemoval.supersede!(session)`. Produces: `Collections::NumberEntries::Lines::UndosController#create`, `Collections::NumberEntries::EndingsController#create`.

- [ ] Add the failing examples, inside `context "when signed in"`:
  ```ruby
      describe "the list" do
        def list_line(entry, quantity: 1, key: SecureRandom.hex(16))
          NumberEntry.add!(account: user.account, entry:, quantity:, finish: "nonfoil", line_key: key).line
        end

        it "counts lines and cards, shows the 10 newest first and the rest behind Show all (AC-3.1)", :aggregate_failures do
          entries = Array.new(25) { printing((it + 1).to_s, "Card #{it + 1}") }
          entries.each_with_index { |entry, index| travel_to(index.minutes.from_now) { list_line(entry, quantity: index < 6 ? 2 : 1) } }
          get collection_number_entry_path(**page_params)
          expect(response.body).to include("This list: 25 lines, 31 cards", "Show all 25")
          shown = response.body[/<ul class="c-list">.*?<\/ul>/m]
          expect(shown.scan(/<li>/).size).to eq(10)
          expect(shown.index("Card 25")).to be < shown.index("Card 16")
        end

        it "undoes a line, leaving the rest of the lot (AC-3.2)", :aggregate_failures do
          line = list_line(printing("47", "Psychic Frog"), quantity: 4)
          line.lot.update!(quantity: 6)
          post collection_number_entry_line_undo_path(line), params: page_params
          expect(response).to redirect_to(collection_number_entry_path(**page_params))
          expect(line.lot.reload.quantity).to eq(2)
          follow_redirect!
          expect(response.body).to include("Undid 4 × Psychic Frog.")
          expect(response.body).not_to include("This list:")
        end

        it "removes the lot when the line held all its copies (AC-3.3)" do
          line = list_line(printing("47"), quantity: 4)
          post collection_number_entry_line_undo_path(line), params: page_params
          expect(user.account.lots).to be_empty
        end

        it "marks a changed line and refuses its undo (AC-3.4)", :aggregate_failures do
          line = list_line(printing("47"), quantity: 4)
          line.lot.update!(quantity: 3)
          get collection_number_entry_path(**page_params)
          expect(response.body).to include("Changed in your collection")
          expect(response.body).not_to include("Undo 4 ×")
          post collection_number_entry_line_undo_path(line), params: page_params
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Those copies have changed in your collection, so they can&#39;t be undone here.")
          expect(line.lot.reload.quantity).to eq(3)
        end

        it "keeps the list across visits (AC-3.6)" do
          list_line(printing("47", "Psychic Frog"))
          get collection_path
          get collection_number_entry_path(**page_params)
          expect(response.body).to include("This list: 1 line, 1 card", "Psychic Frog")
        end

        it "clears the list with Done, keeping the copies (AC-3.7)", :aggregate_failures do
          list_line(printing("47"), quantity: 3)
          post collection_number_entry_ending_path
          expect(response).to redirect_to(collection_path)
          expect(user.account.reload.number_entry).to be_nil
          expect(user.account.lots.sole.quantity).to eq(3)
        end

        it "answers 404 for a cleared line, an undone one or another account's (AC-3.8)", :aggregate_failures do
          list_line(printing("46"))
          theirs = NumberEntry.add!(account: create(:user).account, entry: printing("47"), quantity: 1, finish: "nonfoil", line_key: "a" * 32).line
          post collection_number_entry_line_undo_path(theirs), params: page_params
          expect(response).to have_http_status(:not_found)
          expect(response.body).to include("That line is no longer in your list.")
          expect(theirs.lot.reload.quantity).to eq(1)
          undone = list_line(printing("45"))
          undone.undo!
          post collection_number_entry_line_undo_path(undone), params: page_params
          expect(response).to have_http_status(:not_found)
          mine = list_line(printing("48"))
          post collection_number_entry_ending_path
          post collection_number_entry_line_undo_path(mine), params: page_params
          expect(response).to have_http_status(:not_found)
        end
      end

      it "works through full page loads with no scripting (AC-5.1)", :aggregate_failures do
        printing("47", "Psychic Frog")
        printing("12", "Flare")
        get collection_number_entry_path(set: "MH3")
        follow_redirect!
        add("47", finish: "foil")
        follow_redirect!
        expect(response.body).to include('<option selected="selected" value="foil">Foil</option>')
        expect(response.body).to match(/<input[^>]*id="line_number"[^>]*autofocus/)
        add("12", finish: "foil")
        follow_redirect!
        line = user.account.number_entry.lines.find_by!(entry: Catalog::Entry.find_by!(number: "12"))
        post collection_number_entry_line_undo_path(line), params: { **page_params, finish: "foil" }
        follow_redirect!
        expect(response.body).to include("This list: 1 line, 1 card", '<option selected="selected" value="foil">Foil</option>')
        post collection_number_entry_ending_path
        follow_redirect!
        expect(response.body).to include("My collection")
        expect(user.account.lots.sole).to have_attributes(quantity: 1, finish: "foil")
      end

      it "adds with the same number of queries in a small set and a large one (NFR Performance)" do
        printing("1")
        add("1") # opens the list and the lot, so both measured adds merge
        small = count_queries { add("1") }
        40.times { printing((it + 2).to_s) }
        large = count_queries { add("1") }
        expect(large).to eq(small)
      end
  ```
- [ ] Run: `bin/rspec spec/requests/number_entries_spec.rb` — expect: FAIL (the undo and ending controllers don't exist).
- [ ] Implement `app/controllers/collections/number_entries/lines/undos_controller.rb`:
  ```ruby
  # Undoes one line of number entry: its copies leave the lot they went into (spec 026 decision 5, Story 3). An undone
  # line has left the list; it, another account's line, or one of a list that Done cleared, is not found (AC-3.8).
  class Collections::NumberEntries::Lines::UndosController < ApplicationController
    include NumberEntryPage

    GONE = "That line is no longer in your list.".freeze
    CHANGED = "Those copies have changed in your collection, so they can't be undone here.".freeze

    def create
      line = Current.account.number_entry&.lines&.kept&.includes(:entry)&.find_by(id: params[:line_id])
      return refuse(GONE, status: :not_found) unless line

      # A removed lot can't come back through a bulk removal's Undo any more, as with the scanner's Undo (spec 009).
      BulkRemoval.supersede!(Current.session) if line.undo!
      redirect_to page_path, status: :see_other, notice: "Undid #{line.quantity} × #{line.entry.name}."
    rescue NumberEntry::Line::NotUndoable
      refuse(CHANGED, status: :unprocessable_content)
    end

    private
      def refuse(message, status:)
        flash.now[:alert] = message
        render_page(status:)
      end
  end
  ```
  `app/controllers/collections/number_entries/endings_controller.rb`:
  ```ruby
  # Done (spec 026 decision 5): the list and its lines go, the copies stay, and the collector is back on their collection.
  class Collections::NumberEntries::EndingsController < ApplicationController
    def create
      Current.account.number_entry&.destroy!
      redirect_to collection_path, status: :see_other
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/number_entries_spec.rb` — expect: PASS.
- [ ] Commit: `feat(number-entry): undo a line and end the list with Done`.

---

## Phase 7: Keyboard, look and phone width

**Implements:** FR-1 (design system), decision 3 (Enter on the finish) | **Satisfies:** AC-1.1, AC-1.2 (phone), AC-1.4, AC-2.2, AC-2.4, AC-2.13, AC-4.1 (selection), NFR Accessibility (360px)
**Files:** `app/javascript/controllers/number_entry_controller.js`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/NumberEntry.md`, `docs/design-system/components/EmptyState.md`, `docs/design-system/components/MorePage.md`, `docs/design-system/README.md`, `spec/system/number_entry_spec.rb`
**Interfaces:** Consumes: the page's markup (`data-controller="number-entry"`, `data-number-entry-target="number"`, `data-select`, `keydown.enter->number-entry#submit`; classes `c-numentry`, `c-numentry__set`, `c-numentry__setname`, `c-numentry__data`, `c-numentry__language`, `c-numentry__line`, `c-numentry__add`, `c-numentry__choice`, `c-numentry__prompt`, `c-numentry__list`, `c-numentry__more`). Produces: the Stimulus controller `number-entry` and the `NumberEntry` design-system pattern.

- [ ] Write the failing system spec `spec/system/number_entry_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Number entry", type: :system do
    let(:user) { create(:user) }
    let(:mh3) { create(:catalog_set, code: "mh3", name: "Modern Horizons 3", released_on: Date.new(2024, 6, 14)) }

    def printing(number, name)
      create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, set: mh3, number:, name:, identity: create(:catalog_identity, name:))).entry
    end

    before do
      printing("12", "Flare of Duplication")
      printing("47", "Psychic Frog")
      printing("103", "Ocelot Pride")
      system_sign_in_as(user)
    end

    it "opens from the collection with the set field focused (AC-1.1)" do
      visit collection_path
      click_on "Add by number"
      expect(page).to have_css("h1", text: "Add by number")
      expect(page).to have_css("#number_entry_set:focus")
    end

    it "adds three lines from the keyboard alone, the number focused after each (AC-1.4, AC-2.2, AC-2.4, AC-2.13)", :aggregate_failures do
      visit collection_number_entry_path
      fill_in "Set", with: "MH3"
      find_field("Set").send_keys(:escape, :enter) # close the suggestions first
      expect(page).to have_css(".c-numentry__setname", text: "Modern Horizons 3")
      expect(page).to have_css("#line_number:focus")
      find_field("Number").send_keys("12", :enter)
      expect(page).to have_css("#number_entry_list", text: "This list: 1 line, 1 card")
      expect(page).to have_css("#line_number:focus")
      find_field("Number").send_keys("47", :tab, :backspace, "4", :enter)
      expect(page).to have_css("#number_entry_list", text: "This list: 2 lines, 5 cards")
      expect(page).to have_css("#line_number:focus")
      find_field("Number").send_keys("103", :tab, :tab, "f", :enter)
      expect(page).to have_css("#number_entry_list", text: "This list: 3 lines, 6 cards")
      expect(page).to have_css("#line_number:focus")
      expect(page).to have_select("Finish", selected: "Foil")
      expect(user.account.lots.map { [ it.entry.number, it.quantity, it.finish ] })
        .to contain_exactly([ "12", 1, "nonfoil" ], [ "47", 4, "nonfoil" ], [ "103", 1, "foil" ])
    end

    it "selects a rejected number so typing replaces it (AC-4.1)", :aggregate_failures do
      visit collection_number_entry_path(type: "mtg", set: "mh3", language: "en")
      find_field("Number").send_keys("999", :enter)
      expect(page).to have_css(".c-field__error", text: "No card numbered 999 in Modern Horizons 3 (EN).")
      expect(page).to have_css("#line_number:focus")
      expect(page.evaluate_script("[document.activeElement.selectionStart, document.activeElement.selectionEnd]")).to eq([ 0, 3 ])
      find_field("Number").send_keys("47", :enter)
      expect(page).to have_css("#number_entry_list", text: "Psychic Frog")
    end

    it "is reached from More and fits a 360px screen with a list (AC-1.2, NFR Accessibility)", :aggregate_failures do
      12.times { |index| NumberEntry.add!(account: user.account, entry: Catalog::Entry.find_by!(number: "47"), quantity: 1, finish: "foil", line_key: format("%032x", index)) }
      visit collection_path
      open_in_narrow_frame(more_path, width: 360, ready: ".c-more")
      within_narrow_frame do
        click_on "Add by number"
        expect(page).to have_css("h1", text: "Add by number")
      end
      expect(open_in_narrow_frame(collection_number_entry_path(type: "mtg", set: "mh3", language: "en"), width: 360, ready: "#line_number")).to eq([ 360, true ])
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system/number_entry_spec.rb` — expect: FAIL (Enter on the finish select doesn't add the third line; the rejected number isn't selected).
- [ ] Implement `app/javascript/controllers/number_entry_controller.js`:
  ```js
  import { Controller } from "@hotwired/stimulus"

  // Number entry's line form (spec 026): a rejected number is focused and selected, so typing replaces it (AC-4.1), and
  // Enter on the finish select adds the line, as it does in the text fields (AC-2.4).
  export default class extends Controller {
    static targets = ["number"]

    numberTargetConnected(input) {
      if (input.dataset.select !== "true") return
      input.focus()
      input.select()
    }

    submit(event) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }
  ```
- [ ] Add the styles to the end of `app/assets/stylesheets/collector/additions.css`:
  ```css

  /* ---------- Number entry (spec 026): the chosen set, one line's fields in a row, a choice between matches, the list ---------- */
  .c-numentry { display:flex; flex-direction:column; gap:var(--space-6); margin-top:var(--space-6); }
  .c-numentry__set { display:flex; flex-wrap:wrap; align-items:center; gap:var(--space-2) var(--space-4); }
  .c-numentry__setname, .c-numentry__set > p { margin:0; }
  .c-numentry__data { font-family:var(--font-mono); }
  .c-numentry__language { display:flex; flex-wrap:wrap; align-items:center; gap:var(--space-2); }
  .c-numentry__line { display:grid; grid-template-columns:minmax(0, 10rem) minmax(0, 7rem) minmax(0, 12rem) auto; align-items:start; gap:var(--space-3); }
  .c-numentry__line > .c-field__error { grid-column:1 / -1; margin:0; }
  .c-numentry__data-input { font-family:var(--font-mono); }
  .c-numentry__add { padding-top:var(--space-6); }
  .c-numentry__prompt { margin:0 0 var(--space-2); }
  .c-numentry__choice .c-list li { border:0; padding:var(--space-1) 0; }
  .c-numentry__choice .c-btn { white-space:normal; height:auto; min-height:44px; text-align:left; }
  .c-numentry__list .c-list li { flex-wrap:wrap; }
  .c-numentry__list .c-btn { min-height:44px; min-width:44px; }
  @container page (max-width: 639px) {
    .c-numentry__line { grid-template-columns:minmax(0, 1fr) minmax(0, 1fr); }
    .c-numentry__add { grid-column:1 / -1; padding-top:0; }
    .c-numentry__add .c-btn { width:100%; }
  }
  ```
  (Check `.c-numentry__add`'s top padding against the label height in the browser; the button lines up with the inputs, not the labels. Adjust only with spacing tokens.)
- [ ] Write `docs/design-system/components/NumberEntry.md`:
  ```markdown
  # NumberEntry

  Adding cards from one set by collector number (spec 026): the chosen set and language, one line's fields in a row, a choice when a number matches more than one printing, and the list of what was added, with Undo and Done.

  **Markup** — inside `.c-main.c-page`, after the page head:

  ```html
  <div class="c-numentry">
    <div class="c-numentry__set">
      <p class="c-numentry__setname"><strong>Modern Horizons 3</strong> <span class="c-numentry__data">MH3</span></p>
      <form class="c-numentry__language" method="get">…<select id="number_entry_language">…</select><input type="submit" class="c-btn c-btn--secondary c-btn--sm" value="Change language"></form>
      <a class="c-btn c-btn--ghost c-btn--sm" href="…">Change set</a>
    </div>
    <form class="c-numentry__line" method="post" data-controller="number-entry">
      <div class="c-field"><label class="c-field__label" for="line_number">Number</label><label class="c-input"><input id="line_number" name="line[number]" autofocus></label></div>
      <div class="c-field"><label class="c-field__label" for="line_quantity">Quantity</label><label class="c-input"><input type="number" id="line_quantity" name="line[quantity]" value="1"></label></div>
      <div class="c-field"><label class="c-field__label" for="line_finish">Finish</label><select id="line_finish" name="line[finish]">…</select></div>
      <div class="c-numentry__add"><input type="submit" class="c-btn c-btn--primary" value="Add"></div>
    </form>
    <section id="number_entry_list" class="c-numentry__list">
      <div class="c-section__head"><h2 class="c-section__title">This list: 3 lines, 6 cards</h2><span class="c-section__actions"><button class="c-btn c-btn--secondary c-btn--sm">Done</button></span></div>
      <ul class="c-list"><li><span>Psychic Frog</span><span class="c-list__meta"><span class="c-numentry__data">MH3 · 47 · ×4</span> · <span class="is-muted">Nonfoil</span></span><span class="c-list__end"><button class="c-btn c-btn--secondary c-btn--sm">Undo</button></span></li></ul>
    </section>
  </div>
  ```

  - The line's fields sit in one row on wide screens (number, quantity, finish, Add) and two columns below 640px of the page, with Add full width. Tab order is number, quantity, finish, Add; Enter in any field adds the line.
  - Set codes, numbers and quantities use the `data` face (`c-numentry__data`, Plex Mono).
  - A special finish shows as the `FinishBadge`; any other as muted text, as in the copies table.
  - When a number matches more than one printing, `c-numentry__choice` lists one secondary button per match above the line form, the first focused.
  - A line whose copies changed in the collection shows a `c-tag` ("Changed in your collection") in place of Undo.
  - The list shows the 10 newest lines; the rest are behind "Show all N" in a `<details>` (`c-numentry__more`).
  - The page uses `.c-main.c-page`, the detail-page container (`c-page`, from `ItemPage`), so its parts respond to the page's width below 640px.
  - The number and quantity inputs take the `data` face through `c-numentry__data-input`.
  - Everything works without scripting. The `number-entry` Stimulus controller selects a rejected number and lets Enter on the finish select add the line.
  ```
- [ ] In `docs/design-system/components/MorePage.md`, add the row to the markup after "Export collection" (`<li><a href="/collection/number_entry">Add by number</a></li>`), and change the first rule to: "It holds what the header's account menu holds on wide screens, so phones reach everything from the tab bar, plus "Add by number", which wide screens reach from the collection page's head (spec 026)."
- [ ] In `docs/design-system/components/EmptyState.md`, update the quoted empty-collection sentence to the new one ("No cards in your collection yet. Search for a card or add cards by number to start adding.").
- [ ] In `docs/design-system/README.md`, after the spec 023 app-additions paragraph, add:
  ```markdown
  App additions (spec 026, in `collector/additions.css`): `NumberEntry`. Upstream it into the published design system before the next export replaces this folder.
  ```
- [ ] Run: `bin/rspec spec/system/number_entry_spec.rb spec/design_system_files_spec.rb` — expect: PASS.
- [ ] Render the page at 1280px and 390px in light and dark (`bin/dev`, the `run` skill or the PR screenshots workflow), with a list, a rejected line and a choice; check focus rings and contrast against the design system. Save the screenshots under `docs/specs/026-typed-entry/screenshots/`.
- [ ] Commit: `feat(number-entry): keyboard focus, styles and the design-system pattern`.

---

## Phase 8: The core boundary, documents and verification

**Implements:** FR-1 (must not name a type), Documents that change | **Satisfies:** Goals (collectible-agnostic), all ACs through the full suite
**Files:** `spec/number_entry_core_spec.rb`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/026-typed-entry/verification.md`
**Interfaces:** Consumes: every file the earlier phases added. Produces: nothing new for code.

- [ ] Write `spec/number_entry_core_spec.rb`:
  ```ruby
  require "rails_helper"

  # Spec 026: number entry is core code. Its models, controllers, helper, views and script never name a collectible
  # type, a source, or a finish; finishes and their labels come from the type's vocabulary.
  RSpec.describe "Number entry's code" do
    let(:files) do
      Rails.root.glob("{app/models/number_entry{,/*}.rb,app/controllers/collections/number_entries{_controller.rb,/**/*.rb}," \
        "app/controllers/concerns/number_entry_page.rb,app/helpers/number_entries_helper.rb,app/views/collections/number_entries/*.erb," \
        "app/javascript/controllers/number_entry_controller.js}")
    end

    it "covers every file of the feature" do
      expect(files.size).to eq(18)
    end

    it "never names a collectible type, a source or a finish" do
      offenders = files.select { |file| file.read.match?(/\b(mtg|scryfall|magic|foil|nonfoil|etched)\b/i) }
      expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
    end
  end
  ```
  (18 files: 4 models, 4 controllers, the concern, the helper, 7 views — `show`, `_set_form`, `_chosen_set`, `_line_form`, `_choice`, `_list`, `_line` — and the Stimulus controller.)
- [ ] Run: `bin/rspec spec/number_entry_core_spec.rb` — expect: PASS (an offender is a real leak to remove).
- [ ] `CLAUDE.md`, Project Status: after the sentence on the export, add "A collector adds cards from a set by collector number at `/collection/number_entry` ("Add by number", spec 026): one line per number, quantity and finish, each added at once to a per-account list with Undo (`NumberEntry`, `NumberEntry::Line`), which Done clears; the list is working state, left out of the export." Add a Non-obvious Facts bullet: "**Number entry (spec 026):** core code (`spec/number_entry_core_spec.rb`): the finish defaults to the type's first in `finish_order` so typed and scanned copies share lots; a number matches exactly first, then ignoring case and leading zeros; a tie asks the collector (`pick`, the entry's external key, checked on the server); one line per line key (`NumberEntry::KEY_FORMAT`)."
- [ ] `docs/roadmap.md`, item 8: append "**Done 2026-10-15:** [spec 026](specs/026-typed-entry/spec.md), [PR #N](…)." (N filled when the PR exists; edit only this line.)
- [ ] Run: `bin/ci` — expect: green (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec).
- [ ] Measure an add against the full English catalog in development, rolled back, and record the time in `verification.md`:
  ```sh
  bin/rails runner 'ActiveRecord::Base.transaction do
    account = Account.create!
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    choice = NumberEntry::SetChoice.new(text: "mh3", type: "mtg", language: "en")
    form = NumberEntry::LineForm.new(set: choice.set, language: choice.language, number: "47", quantity: "1", line_key: NumberEntry.new_line_key)
    form.valid? && NumberEntry.add!(account:, **form.add_attributes)
    puts (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(4)
    raise ActiveRecord::Rollback
  end'
  ```
  (This times what an add's request does with the database: the set lookup, the match, the add. If the development catalog isn't loaded, say so in `verification.md` and record the query-count spec's result instead.)
- [ ] Write `docs/specs/026-typed-entry/verification.md`: note that decision 2's catalog-title label on the suggestions has no test while only one type is registered; then each AC with the spec example or screenshot that proves it (AC-2.13's focus ring by the Phase 7 screenshots of each focused field), the `bin/ci` result, the measurement, and the hosted-door check (rule 2: no admin page shows lines; rule 3: no instance setting added; rule 4: one ~100-byte row per added line until Done, no background work).
- [ ] Commit: `docs(number-entry): verification, CLAUDE.md and the core boundary spec`, then push and open the PR (draft), closing #43; fill the roadmap line's PR number in a following commit.

---

## Quickstart Validation

1. `bin/dev`, sign in, open My collection, choose "Add by number".
2. Type `mh3`, Enter. The set and EN show; the cursor is in Number.
3. Type `47`, Enter: "Added 1 × … (MH3 · 47, Nonfoil) to your collection." and the list shows one line; the cursor is back in Number.
4. Type `47`, Tab, `4`, Tab, `f`, Enter: four foil copies; the finish stays Foil.
5. Type `9999`, Enter: "No card numbered 9999 in Modern Horizons 3 (EN).", the number selected.
6. Undo the four foils; the list drops the line. Done: back on My collection, the first copy kept.
7. At 390px, More → "Add by number" opens the page; the line fields sit in two columns.
