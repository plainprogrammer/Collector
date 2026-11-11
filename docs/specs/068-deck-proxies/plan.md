# Implementation Plan: Proxies in a Deck Zone

**Spec:** [spec.md](spec.md) (v0.4.0, Approved at Gate A, 2026-11-11); plan approved at Gate B (the coordinator, under the maintainer's delegation, 2026-11-11)
**Decisions:** none new; ADR 0028's deck model gets one table (spec decision 12)
**Created:** 2026-11-11

## Global Constraints

- A proxy is a row of `deck_proxies` and never a lot: no query, count, export row, bulk selection, number-entry line, scanner sitting or card page that reads lots may read it, and no write path of a lot may write it (decisions 1, 11; AC-4.1 to AC-4.3).
- Every read and write goes through the signed-in account: the deck by `Current.account.decks.find_by!(location_id:)` with the `Location::ID_TEXT` guard, the zone by its key within the deck, the proxy by its id within the deck's zones. Another account's anything, a place's id, a zone's id, a zone key the deck lacks and another deck's proxy id are 404 (AC-1.7, AC-3.6, AC-8.3). No parameter names an account, a zone id, a kind or a user (AC-1.11).
- The deck page keeps no `form`: "Add a proxy" and the menu items are links (decision 3, AC-1.1, AC-2.7).
- Counts of proxies are **quantities** everywhere but the import, where they are **rows** (spec Terms).
- Creation-time rules (finish listed or required, entry of the deck's collectible type) apply on create and, for the finish, when it is set; a stored proxy is never revalidated against the catalog (decisions 2, 19). The import has no type check and never requires a finish.
- The cap is 9,999 per proxy. An add past it, and a format change that would pass it, write nothing (AC-1.9, AC-6.4).
- Export format version 4 is **unreleased** (`v0.2.1`'s tree has no `v4.schema.json`): `proxies` is a **required** list of version 4, both schema copies, the document, the examples and the Coverage tables change together, and **every existing version 4 example gets `"proxies": []`** (decision 14, AC-7.3).
- Core deck files never name a game, a source, a format or a zone key but `considering`, comments included, and the words `mtg`, `scryfall` and `magic` are banned anywhere in them (`spec/deck_core_spec.rb`, AC-8.7). The chooser reuses `Catalog::Search` and the vocabulary's `finishes_for`; nothing of a game is named in a proxy file.
- Design system: tokens and `c-*` classes only; new CSS goes under its own heading in `app/assets/stylesheets/collector/additions.css`; the existing zone CSS (spec 060) already has the Proxy, Total and menu column widths.
- Migrations: additive, reversible, safe to run unattended (`.claude/rules/sqlite-and-migrations.md`). After `db:migrate`, restore the unrelated schema noise (the cable, cache and queue schema files) with `git checkout` of those files only.
- Tests: tag spec types explicitly; `:aggregate_failures` on multi-expectation examples; no prose documents checked from RSpec (the export format document is the one exception).
- Code documentation (`.claude/rules/code-documentation.md`): every public class, module and method added or changed gets a summary comment; no collectible named in a core file's comments.
- One shared test database: never run two spec runs at once. Targeted `bin/rspec <file>` runs need no CI slot; a full `bin/ci`, or a push whose hook runs it, asks the coordinator for a slot first.
- Commits: Conventional, one per task, each ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; `git add` and `git commit` in separate calls.

---

## Goal

A collector adds a proxy (a printing, a finish and a quantity) to a zone of a deck from the zone's header, changes its quantity or removes it from the row's menu, and sees proxies beside the owned copies on the deck page and on the Decks page; a format change keeps them (into Considering); the export carries them and the import restores them.

---

## Pre-implementation gates

- **Simplicity (≤3 components).** Three: the proxy data (`deck_proxies`, `Deck::Proxy` with its `Addition` form), the deck pages' reads and views, and the export format's reader and writer (`CollectionExport`, `ExportFormat::Rules`, `CollectionImport::Proxies`). No gem, JavaScript or background job.
- **Anti-abstraction.** `Deck::Proxy` is the one representation; `Deck::Page` gains one `Data` (`Line`) and fields on the existing `Row`, `Group` and `Zone`; the import gets one class (`CollectionImport::Proxies`) beside `Locations` and `Decks`, the pattern they set. The views read these directly; no view model layer.
- **Integration-first.** Phase 0's model spec and Phase 5's schema and examples come before the code that uses them; every task starts with its failing spec.
- **Statement counts fixed here.** `Deck::Page#zones` runs **6** statements with lots and proxies (the zones, the lot sums, the proxies, the entries, their sets, one extension read per collectible type) and **3** with none, whatever the number of zones, rows, lots and proxies (AC-2.10: spec 066's 5 and 2, plus one). The Decks page runs one grouped statement more (AC-5.3). The export reads the proxies in **one** statement (AC-7.2).

## File map

| File | Change | Responsibility |
|------|--------|----------------|
| `db/migrate/20261111150001_create_deck_proxies.rb`, `db/schema.rb` | new, edit | The table, its checks and its indexes |
| `app/models/deck/proxy.rb` | new | The proxy: validations, `add!` (merge, cap, race) |
| `app/models/deck/proxy/addition.rb` | new | The add form: parses text, copies errors |
| `app/models/deck.rb`, `app/models/account.rb` | edit | `Deck#proxies`; `Account#deck_proxies` |
| `app/models/deck/page.rb` | edit | Proxies read once; `Line`, `Row#proxy`, `total` |
| `app/models/deck/listing.rb` | edit | Proxies grouped per deck |
| `app/models/deck/format_change.rb` | edit | Proxies move into Considering after the lots |
| `app/models/catalog/search.rb` | edit | `collectible_type:` filter |
| `config/routes.rb` | edit | The proxy routes under `decks` |
| `app/controllers/concerns/finds_deck.rb` | new | `set_deck` for the new controllers |
| `app/controllers/decks/proxies_controller.rb`, `app/controllers/decks/proxies/removals_controller.rb` | new | Chooser, form, create, edit, update, destroy, removal page |
| `app/controllers/decks_controller.rb`, `app/controllers/decks/formats_controller.rb`, `app/controllers/decks/removals_controller.rb` | edit | Notice, cap alert, removal text |
| `app/views/decks/show.html.erb` (unchanged), `_zone.html.erb`, `_card_row.html.erb`, `_proxy_menu.html.erb`, `index.html.erb`, `removals/new.html.erb`, `proxies/{choose,new,edit}.html.erb`, `proxies/_group.html.erb`, `proxies/removals/new.html.erb` | new, edit | The pages |
| `app/helpers/decks_helper.rb` | edit | Counts, tag, menu labels, notices |
| `app/models/export_format/rules.rb`, `v4.schema.json` (app copy), `docs/export-format/**` | edit | `proxies`, `duplicate_proxy`, `unknown_location`; the document, schema, examples, Coverage |
| `spec/support/export_format_rules.rb`, `spec/export_format_*_spec.rb` | edit | The comparison and the lists |
| `app/models/collection_export.rb` | edit | The `proxies` list |
| `app/models/collection_import.rb`, `collection_import/{proxy_rows,proxies,plan,apply}.rb` | new, edit | Read, plan, fingerprint, write |
| `app/controllers/collections/imports_controller.rb`, `app/helpers/import_previews_helper.rb`, `app/views/collections/import_previews/{show,_proxies,_apply}.html.erb` | edit, new | The preview, the confirmation, the notice |
| `script/upgrade/seeds/next.rb`, `spec/deck_core_spec.rb`, `spec/requests/query_counts_spec.rb` | edit | The upgrade seed, the core guard, the counts |
| `docs/design-system/**`, `docs/architecture/**`, `CLAUDE.md`, `docs/specs/README.md`, `docs/releasing.md`, `verification.md` | edit, new | Documentation (Phase 8) |

Batches for the implementer subagents (2–4 consecutive tasks, one commit per task, test first): **A** = T1–T3, **B** = T4–T6, **C** = T7–T9, **D** = T10–T11, **E** = T12–T13, **F** = T14–T16, **G** = T17–T19, **H** = T20–T21. The supervisor checks each batch's diff; the documentation (T22 to T24) is written by the supervisor.

---

## Phase 0: The data

**Implements:** FR-1 (data), Story 8 | **Satisfies:** AC-8.1, AC-8.2, AC-8.4, AC-1.6 (merge), AC-1.9
**Files:** `db/migrate/20261111150001_create_deck_proxies.rb`, `db/schema.rb`, `app/models/deck/proxy.rb`, `app/models/deck/proxy/addition.rb`, `app/models/deck.rb`, `app/models/account.rb`, `spec/factories/decks.rb`, `spec/models/deck/proxy_spec.rb`, `spec/models/deck/proxy/addition_spec.rb`, `spec/models/account_spec.rb`
**Interfaces:** Produces `Deck::Proxy` (`zone`, `entry`, `finish`, `quantity`; `.add!(account:, zone:, entry:, finish:, quantity:)`; `Deck::Proxy::FULL_MESSAGE`), `Deck::Proxy::Addition` (`#save` → true or false; `#proxy` the written proxy), `Deck#proxies`, `Account#deck_proxies`, factory `:deck_proxy`.

### T1: The table and the model

- [ ] **Step 1: The failing spec** `spec/models/deck/proxy_spec.rb`:

```ruby
require "rails_helper"

# Spec 068 decisions 1, 2, 4, 19 and Story 8: the proxy row, its creation-time rules and its merge.
RSpec.describe Deck::Proxy, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }
  let(:zone) { deck.zone("main") }
  let(:entry) { create(:mtg_printing).entry } # the factory's finishes: foil and nonfoil

  def add(quantity: 1, finish: "foil", zone: self.zone, entry: self.entry) = described_class.add!(account:, zone:, entry:, finish:, quantity:)

  it "is saved with a zone of the account, a listed finish and a quantity from 1 to 9,999 (AC-8.2)", :aggregate_failures do
    proxy = add(quantity: 2)

    expect(proxy).to be_persisted
    expect([ proxy.zone, proxy.entry, proxy.finish, proxy.quantity ]).to eq([ zone, entry, "foil", 2 ])
    expect(Lot.count).to eq(0)
  end

  it "refuses what AC-8.2 lists", :aggregate_failures do
    other = create(:user).account
    place = create(:location, account:)
    other_deck_zone = create(:deck, account: other, name: "Theirs").zone("main")
    other_type_entry = create(:catalog_entry, collectible_type: "other")

    expect { add(quantity: 0) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { add(quantity: 10_000) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { add(zone: place) }.to raise_error(ActiveRecord::RecordInvalid)             # a place is no zone
    expect { add(zone: deck.location) }.to raise_error(ActiveRecord::RecordInvalid)     # nor is a deck's own row
    expect { add(zone: other_deck_zone) }.to raise_error(ActiveRecord::RecordInvalid)   # another account's zone
    expect { add(finish: nil) }.to raise_error(ActiveRecord::RecordInvalid, /Choose a finish/)
    expect { add(finish: "etched") }.to raise_error(ActiveRecord::RecordInvalid, /isn't available/)
    expect { add(entry: other_type_entry) }.to raise_error(ActiveRecord::RecordInvalid)  # another collectible than the deck's
    expect(described_class.count).to eq(0)
  end

  it "accepts no finish for a printing that lists none (decision 2)" do
    bare = create(:mtg_printing, finishes: []).entry

    expect(add(entry: bare, finish: nil).finish).to be_nil
  end

  it "merges an add into the proxy of the same zone, printing and finish, keeping its id (AC-1.6)", :aggregate_failures do
    first = add(quantity: 2)
    second = add(quantity: 3)
    other_finish = add(quantity: 1, finish: "nonfoil")

    expect(second.id).to eq(first.id)
    expect(first.reload.quantity).to eq(5)
    expect(other_finish.id).not_to eq(first.id)
    expect(described_class.count).to eq(2)
  end

  it "merges proxies that have no finish too (the unique index holds for a NULL finish)" do
    bare = create(:mtg_printing, finishes: []).entry
    add(entry: bare, finish: nil, quantity: 1)
    add(entry: bare, finish: nil, quantity: 1)

    expect(described_class.where(catalog_entry_id: bare.id).pluck(:quantity)).to eq([ 2 ])
  end

  it "refuses an add past 9,999 and changes nothing (AC-1.9)", :aggregate_failures do
    proxy = add(quantity: 9_990)

    expect { add(quantity: 10) }.to raise_error(ActiveRecord::RecordInvalid, /#{Regexp.escape(described_class::FULL_MESSAGE)}/)
    expect(proxy.reload.quantity).to eq(9_990)
  end

  it "wins a race on the unique index by merging (AC-1.9)" do
    add(quantity: 1)
    calls = 0
    allow(described_class).to receive(:find_by).and_wrap_original do |original, *args, **kwargs|
      calls += 1
      calls == 1 ? nil : original.call(*args, **kwargs) # the first read misses the row another request just wrote
    end

    add(quantity: 2)

    expect(described_class.pluck(:quantity)).to eq([ 3 ])
  end

  it "is removed with its zone and its deck, and deleted with the account (decision 1, AC-8.4)", :aggregate_failures do
    add
    expect { deck.remove! }.to change(described_class, :count).from(1).to(0)

    other_account = create(:user).account
    other = create(:deck, account: other_account, name: "Other")
    described_class.add!(account: other_account, zone: other.zone("main"), entry:, finish: "foil", quantity: 1)
    expect { other_account.user.destroy! }.to change(described_class, :count).from(1).to(0) # the user's account is destroyed with it
  end

  it "doesn't revalidate a stored proxy against the catalog (decision 2)" do
    proxy = add
    entry.extension.update!(finishes: %w[nonfoil]) # a refresh dropped foil

    expect(proxy.reload.update(quantity: 4)).to be(true)
  end
end
```

- [ ] **Step 2: Run it, confirm it fails** (`NameError: uninitialized constant Deck::Proxy`): `bin/rspec spec/models/deck/proxy_spec.rb`.
- [ ] **Step 3: The migration** `db/migrate/20261111150001_create_deck_proxies.rb`:

```ruby
# Proxies (spec 068, #254): cards a deck's zone needs and the collector doesn't own, one row per zone, printing and finish.
# Additive: one new table, nothing else changes. A zone's or a deck's removal removes its proxies through the foreign key on
# the zone's location (the format change moves a dropped zone's proxies out first, in the app), and an account's deletion
# removes them through its own. The unique index uses COALESCE so that a proxy with no finish (a printing that lists none)
# is unique too: SQLite treats two NULLs as different in a plain unique index. Guarded, so a run that stopped part way is
# finished by the next boot.
class CreateDeckProxies < ActiveRecord::Migration[8.1]
  def change
    create_table :deck_proxies, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :location, null: false, foreign_key: { on_delete: :cascade } # the zone
      t.references :catalog_entry, null: false, foreign_key: true
      t.string :finish
      t.integer :quantity, null: false
      t.timestamps
      t.check_constraint "quantity BETWEEN 1 AND 9999", name: "deck_proxies_quantity_range"
    end
    add_index :deck_proxies, "location_id, catalog_entry_id, COALESCE(finish, '')", unique: true,
      name: "index_deck_proxies_on_zone_entry_and_finish", if_not_exists: true
  end
end
```

Run `bin/rails db:migrate` and `RAILS_ENV=test bin/rails db:migrate`; `git diff db/schema.rb` must show only the new table, its three foreign keys and its indexes (restore any other noise with `git checkout db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb`, never the primary `db/schema.rb`). Check the version line of `db/schema.rb` is `20261111150001` or newer.

- [ ] **Step 4: The model** `app/models/deck/proxy.rb`:

```ruby
# A card a deck's zone needs that the collector doesn't own (spec 068): a printing and a finish with a quantity, in one zone.
# It is never a lot: it is in no count of owned copies, and it changes only by hand (the add, change and remove pages, a
# format change, a deck's removal, an import that carries proxies). One row per zone, printing and finish (the unique index,
# which also holds when the finish is NULL).
#
# The finish and entry rules are creation-time rules (decisions 2, 19): a stored proxy is never revalidated against the
# catalog, so a refresh that changes a printing's finishes leaves its proxies editable and exportable.
# @see file:collection-and-lots.md
class Deck::Proxy < ApplicationRecord
  MAX_QUANTITY = Lot::MAX_QUANTITY
  FULL_MESSAGE = "A zone can hold at most 9,999 proxies of one printing and finish.".freeze
  CHOOSE_A_FINISH = "Choose a finish.".freeze
  FINISH_UNAVAILABLE = "That finish isn't available for this printing.".freeze

  self.table_name = "deck_proxies"

  belongs_to :account
  belongs_to :zone, class_name: "Location", foreign_key: :location_id
  belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id

  normalizes :finish, with: ->(value) { value.presence }

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate :quantity_within_cap
  validate :zone_is_a_zone_of_the_account, if: :location_id_changed?
  validate :entry_is_of_the_decks_type, on: :create
  validate :finish_is_offered, if: -> { new_record? || finish_changed? }

  # Adds +quantity+ proxies of +entry+ in +finish+ to +zone+: into the proxy that zone already has of that printing and
  # finish (it survives, with the quantities added) or as a new one. All or nothing at the cap. A request that loses a race on
  # the unique index retries once and merges, as `Lot.add!` does.
  #
  # @param account [Account] the signed-in account; the zone must be one of its zones
  # @param zone [Location] a zone of one of the account's decks
  # @param entry [Catalog::Entry]
  # @param finish [String, nil] one of the printing's finishes; nil only for a printing that lists none
  # @param quantity [Integer]
  # @return [Deck::Proxy] the new or the merged proxy
  # @raise [ActiveRecord::RecordInvalid] on any rule above, with the sentence on the attribute (`quantity` for the cap)
  def self.add!(account:, zone:, entry:, finish:, quantity:)
    tries = 0
    begin
      transaction(requires_new: true) { merge_or_create!(account:, zone:, entry:, finish: finish.presence, quantity:) }
    rescue ActiveRecord::RecordNotUnique
      retry if (tries += 1) < 2
      raise
    end
  end

  # (see .add!)
  # @api private
  def self.merge_or_create!(account:, zone:, entry:, finish:, quantity:)
    existing = find_by(account_id: account.id, location_id: zone.id, catalog_entry_id: entry.id, finish:)
    return create!(account:, zone:, entry:, finish:, quantity:) unless existing

    existing.update!(quantity: existing.quantity + quantity)
    existing
  end
  private_class_method :merge_or_create!

  # A quantity as typed: a whole number from 1 to 9,999, or nil (text, a fraction, 0, a negative number, over the cap).
  #
  # @param text [String, nil]
  # @return [Integer, nil]
  def self.parse_quantity(text) = Integer(text.to_s.strip, 10, exception: false)&.then { it if it.between?(1, MAX_QUANTITY) }

  # The finish as the printing's vocabulary labels it, nil for a proxy with none.
  # @return [String, nil]
  def finish_label
    return unless finish

    Catalog.collecting.key?(entry.collectible_type) ? Catalog.collecting_for(entry.collectible_type).finish_label(finish) : finish.humanize
  end

  private
    def quantity_within_cap
      errors.add(:quantity, FULL_MESSAGE) if quantity.to_i > MAX_QUANTITY
    end

    def zone_is_a_zone_of_the_account
      errors.add(:zone, "must be a zone of the account") unless zone&.zone? && zone.account_id == account_id
    end

    # The zone's deck is the one whose collectible the printing must be of (decision 19). A deck row is read through the zone's
    # parent; a zone without one was refused above.
    def entry_is_of_the_decks_type
      deck = zone&.parent&.deck
      errors.add(:entry, "isn't of the deck's collectible") unless deck && entry && deck.collectible_type == entry.collectible_type
    end

    def finish_is_offered
      return if entry.nil?
      return errors.add(:finish, FINISH_UNAVAILABLE) unless Catalog.collecting.key?(entry.collectible_type)

      offered = Catalog.collecting_for(entry.collectible_type).finishes_for(entry)
      if finish.nil?
        errors.add(:finish, CHOOSE_A_FINISH) if offered.any?
      elsif offered.exclude?(finish)
        errors.add(:finish, FINISH_UNAVAILABLE)
      end
    end
end
```

`finishes_for(entry)` reads `entry.extension`, so a spec's entry needs it loaded: `Catalog::Entry#extension` is lazy (one query) — fine here (a write path). In `add!`'s callers, the controller preloads it (T8).

- [ ] **Step 5: Associations.** In `app/models/deck.rb` add after `holdings`:

```ruby
  # The deck's proxies, in every zone, as one relation read by value (the account and the zones' parent), so a caller adds no
  # query to find them (spec 068).
  #
  # @return [ActiveRecord::Relation<Deck::Proxy>]
  def proxies = Deck::Proxy.where(account_id:, location_id: Location.where(parent_id: location_id, kind: "deck_zone").select(:id))
```

In `app/models/account.rb`, after `has_many :decks, dependent: nil ...` add:

```ruby
  has_many :deck_proxies, class_name: "Deck::Proxy", dependent: nil # declared after `locations` and `decks`; the foreign keys cascade (spec 068 AC-8.4)
```

- [ ] **Step 6: The factory**, appended to `spec/factories/decks.rb` inside `FactoryBot.define`:

```ruby
  # A proxy in the Main zone of a new deck of the account (spec 068); pass `zone:` for another zone.
  factory :deck_proxy, class: "Deck::Proxy" do
    zone { association(:deck).zone("main") }
    account { zone.account }
    entry { association(:mtg_printing).entry }
    finish { "nonfoil" }
    quantity { 1 }
  end
```

- [ ] **Step 7: Run** `bin/rspec spec/models/deck/proxy_spec.rb spec/models/account_spec.rb`: all pass (the race example stubs `find_by` on the class: if the first call returns nil and the create hits the unique index, the retry's `find_by` finds the row and merges). If `account_spec.rb`'s order example is `%i[lots locations decks]`, extend it to `%i[lots locations decks deck_proxies]` in this step (a failing-first edit: change the expected order, see it fail, then the association above satisfies it).
- [ ] **Step 8: Commit** `feat(decks): proxies table and model (spec 068 T1)`.

### T2: The add form

- [ ] **Step 1: The failing spec** `spec/models/deck/proxy/addition_spec.rb`:

```ruby
require "rails_helper"

# Spec 068 AC-1.5, AC-1.8, AC-1.9: the add page's form parses text and puts a sentence on the field it belongs to.
RSpec.describe Deck::Proxy::Addition, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }
  let(:entry) { create(:mtg_printing).entry }

  def addition(**attrs) = described_class.new(account:, zone: deck.zone("main"), entry:, finish: "foil", quantity: "2", **attrs)

  it "saves a valid add and exposes the proxy", :aggregate_failures do
    form = addition

    expect(form.save).to be(true)
    expect(form.proxy.quantity).to eq(2)
  end

  it "reads the quantity as whole text from 1 to 9,999 (AC-1.8)", :aggregate_failures do
    [ "", "0", "-1", "2.5", "abc", "10000", " " ].each do |text|
      form = addition(quantity: text)

      expect(form.save).to be(false), text.inspect
      expect(form.errors[:quantity]).to eq([ "Enter a number from 1 to 9,999." ])
    end
    expect(Deck::Proxy.count).to eq(0)
  end

  it "puts the finish sentences on :finish (AC-1.8)", :aggregate_failures do
    expect(addition(finish: "").tap(&:save).errors[:finish]).to eq([ "Choose a finish." ])
    expect(addition(finish: "etched").tap(&:save).errors[:finish]).to eq([ "That finish isn't available for this printing." ])
  end

  it "puts the cap sentence on :quantity and keeps the proxy as it was (AC-1.9)", :aggregate_failures do
    addition(quantity: "9990").save
    form = addition(quantity: "10")

    expect(form.save).to be(false)
    expect(form.errors[:quantity]).to eq([ Deck::Proxy::FULL_MESSAGE ])
    expect(Deck::Proxy.pick(:quantity)).to eq(9_990)
  end
end
```

- [ ] **Step 2: Run, confirm it fails** (`NameError`).
- [ ] **Step 3: The form** `app/models/deck/proxy/addition.rb`:

```ruby
# The add page's form (spec 068 decision 3): the text of Finish and Quantity as typed, checked, then written through
# `Deck::Proxy.add!`. A sentence lands on the field it belongs to; what was typed stays for the page to show again.
class Deck::Proxy::Addition
  include ActiveModel::Model
  include ActiveModel::Attributes

  QUANTITY_SENTENCE = "Enter a number from 1 to 9,999.".freeze

  attribute :finish, :string
  attribute :quantity, :string, default: "1"
  attr_accessor :account, :zone, :entry

  # @return [Deck::Proxy, nil] the proxy {#save} wrote or merged into
  attr_reader :proxy

  # Checks and writes.
  #
  # @return [Boolean] false, with a sentence on `errors[:quantity]` or `errors[:finish]`, when nothing was written
  def save
    errors.clear
    count = Deck::Proxy.parse_quantity(quantity)
    unless count
      errors.add(:quantity, QUANTITY_SENTENCE)
      return false
    end

    @proxy = Deck::Proxy.add!(account:, zone:, entry:, finish: finish.presence, quantity: count)
    true
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.each { |message| errors.add(message.attribute == :entry || message.attribute == :zone ? :base : message.attribute, message.message) }
    false
  end
end
```

- [ ] **Step 4: Run** `bin/rspec spec/models/deck/proxy/addition_spec.rb`: pass. **Step 5: Commit** `feat(decks): the add proxy form (spec 068 T2)`.

### T3: `Deck::Proxy` change and remove

- [ ] **Step 1: Failing spec**, appended to `spec/models/deck/proxy_spec.rb`:

```ruby
  describe "#change_quantity!" do
    it "sets the quantity, keeping the id, and is a no-op for the same quantity (AC-3.2)", :aggregate_failures do
      proxy = add(quantity: 2)
      stamp = proxy.updated_at

      expect(proxy.change_quantity!(4).reload.quantity).to eq(4)
      travel_to(1.hour.from_now) { expect { proxy.change_quantity!(4) }.not_to(change { proxy.reload.updated_at }) }
      expect(proxy.updated_at).to be >= stamp
    end

    it "refuses 0 and a number over 9,999 (AC-3.3)", :aggregate_failures do
      proxy = add(quantity: 2)

      expect { proxy.change_quantity!(0) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { proxy.change_quantity!(10_000) }.to raise_error(ActiveRecord::RecordInvalid, /#{Regexp.escape(described_class::FULL_MESSAGE)}/)
      expect(proxy.reload.quantity).to eq(2)
    end
  end
```

- [ ] **Step 2: Run, confirm it fails.** **Step 3:** add to `Deck::Proxy` (above `finish_label`):

```ruby
  # Sets the quantity. The same quantity writes nothing (not even `updated_at`).
  #
  # @param count [Integer]
  # @return [Deck::Proxy] self
  # @raise [ActiveRecord::RecordInvalid] when the quantity is outside 1 to 9,999
  def change_quantity!(count)
    self.quantity = count
    save! if changed?
    self
  end
```

- [ ] **Step 4: Run** the file: pass. **Step 5: Commit** `feat(decks): change a proxy's quantity (spec 068 T3)`.

---

## Phase 1: The deck page and the Decks page read proxies

**Implements:** FR-2, Stories 2 and 5 | **Satisfies:** AC-2.1 to AC-2.6, AC-2.8 to AC-2.12, AC-5.1 to AC-5.3, AC-4.1
**Files:** `app/models/deck/page.rb`, `app/models/deck/listing.rb`, `app/helpers/decks_helper.rb`, `app/views/decks/_zone.html.erb`, `_card_row.html.erb`, `_proxy_menu.html.erb`, `index.html.erb`, `spec/models/deck/page_spec.rb`, `spec/models/deck/listing_spec.rb`, `spec/requests/deck_pages_spec.rb`, `spec/requests/decks_spec.rb`, `spec/requests/query_counts_spec.rb`, `spec/system/deck_page_spec.rb`
**Interfaces:** Consumes `Deck#proxies`, `Deck::Proxy`. Produces `Deck::Page::Line = Data.define(:id, :finish, :quantity)`, `Row#proxy`/`#total`/`#lines`, `Group#proxy`/`#total`, `Zone#proxy`/`#total`, `Deck::Page#proxy`/`#total`, `Deck::Listing::Row#owned`/`#proxy`/`#cards`, the helpers `proxy_tag`, `deck_counts_line(owned, proxy)`, `proxy_item_label`, `proxy_zone_label`.

### T4: `Deck::Page` reads the proxies

- [ ] **Step 1: The failing spec**, added to `spec/models/deck/page_spec.rb` (read the file first and follow its `printing` and `page` helpers; the new examples use only `create(:deck_proxy, zone:, entry:, finish:, quantity:)`):

```ruby
  describe "proxies (spec 068)" do
    let(:deck) { create(:deck, account:) }
    let(:bolt) { create(:mtg_printing).entry }

    def proxy(zone, entry, finish: "nonfoil", quantity: 1) = create(:deck_proxy, zone: deck.zone(zone), account: deck.account, entry:, finish:, quantity:)

    it "sums a printing's proxies of every finish into its row and lists each as a line (AC-2.1, AC-2.2)", :aggregate_failures do
      proxy("main", bolt, finish: "foil", quantity: 2)
      proxy("main", bolt, finish: "nonfoil", quantity: 3)
      create_lot_in_zone(deck, "main", entry: bolt, quantity: 4)

      row = described_class.new(deck).zones.first.groups.first.rows.first

      expect([ row.owned, row.proxy, row.total ]).to eq([ 4, 5, 9 ])
      expect(row.lines.map { [ it.finish, it.quantity ] }).to match_array([ [ "foil", 2 ], [ "nonfoil", 3 ] ])
    end

    it "makes a row of a printing that has a proxy and no copy, with Owned 0 (AC-2.2)", :aggregate_failures do
      proxy("sideboard", bolt, quantity: 2)

      zone = described_class.new(deck).zones.find { it.name == "Sideboard" }

      expect(zone.empty?).to be(false)
      expect(zone.groups.flat_map(&:rows).map { [ it.owned, it.proxy, it.total ] }).to eq([ [ 0, 2, 2 ] ])
    end

    it "counts owned, proxy and total in the zone, the group and the page (AC-2.3)", :aggregate_failures do
      create_lot_in_zone(deck, "main", entry: bolt, quantity: 4)
      proxy("main", bolt, quantity: 5)
      proxy("considering", create(:mtg_printing).entry, quantity: 2)
      page = described_class.new(deck)

      expect([ page.owned, page.proxy, page.total ]).to eq([ 4, 7, 11 ])
      main = page.zones.find { it.name == "Main" }
      expect([ main.owned, main.proxy, main.total ]).to eq([ 4, 5, 9 ])
      expect(main.groups.first.total).to eq(9)
    end

    it "counts no proxy of another deck, another account or a place (AC-2.8 by value)", :aggregate_failures do
      other = create(:deck, account: deck.account, name: "Other")
      create(:deck_proxy, zone: other.zone("main"), account: other.account, entry: bolt)
      stranger = create(:deck_proxy, entry: bolt) # another account's deck

      expect(stranger.account).not_to eq(deck.account)
      expect(described_class.new(deck).proxy).to eq(0)
    end

    it "reads the proxies in one statement more than before, however many there are (AC-2.10)", :aggregate_failures do
      none = page_of(deck).then { |page| count_queries { page.zones } } # the deck and its location are read outside the count
      create_lot_in_zone(deck, "main")
      proxy("main", create(:mtg_printing).entry)
      some = page_of(deck).then { |page| count_queries { page.zones } }
      6.times { |n| proxy(%w[main sideboard considering][n % 3], create(:mtg_printing).entry) }
      many = page_of(deck).then { |page| count_queries { page.zones } }

      expect([ none, some, many ]).to eq([ 3, 6, 6 ]) # the zones, the lot sums, the proxies; then the entries, their sets and one extension read
    end
  end
```

The example's numbers are spec 066's (the file's existing example asserts 5 for a deck with lots; a deck with none reads the zones and the lot sums, 2) plus one (AC-2.10); if a run shows another figure, stop and report it: the gate's count and the spec's AC are then wrong, not the example. The file's own `page_of(deck)` helper builds the page the way the controller does.

- [ ] **Step 2: Run, confirm it fails** (`NoMethodError: proxy`).
- [ ] **Step 3: The implementation**, `app/models/deck/page.rb` replaces the top of the class and `build_zones`/`groups_for`:

```ruby
class Deck::Page
  # One proxy of a card row: its id (the menu's links), its finish (nil when the printing lists none) and its quantity.
  Line = Data.define(:id, :finish, :quantity)
  # One printing in one zone: the entry (its set and extension loaded), the copies owned, the zone's proxies of it (one line
  # per finish) and the vocabulary's answer.
  Row = Data.define(:entry, :owned, :lines, :answer) do
    # The proxies of the printing in the zone, every finish added up.
    def proxy = lines.sum(&:quantity)

    # Owned plus proxy: the Total column.
    def total = owned + proxy
  end
  # The rows under one group's name; a nil name is the flat group of a collectible that answers nothing.
  Group = Data.define(:name, :rows) do
    # The copies in the group.
    def owned = rows.sum(&:owned)

    # The proxies in the group.
    def proxy = rows.sum(&:proxy)

    # Owned plus proxy: the group row's count.
    def total = owned + proxy
  end
  # One zone: its location and its groups in the extension's order.
  Zone = Data.define(:location, :groups) do
    # The zone location's id.
    def id = location.id

    # The zone's shown name.
    def name = location.name

    # The copies in the zone.
    def owned = groups.sum(&:owned)
    # The proxies in the zone.
    def proxy = groups.sum(&:proxy)
    # Owned plus proxy.
    def total = owned + proxy
    # Whether the zone holds no lot and no proxy.
    def empty? = groups.empty?
  end

  attr_reader :deck

  # @param deck [Deck] a deck of the signed-in account, its location loaded to keep the read count
  def initialize(deck)
    @deck = deck
  end

  # The zones in the format's order; a zone the format does not list, and every zone of a format the instance no longer
  # registers, follows by id. Read once.
  #
  # @return [Array<Zone>]
  def zones = @zones ||= build_zones

  # The copies in every zone, Considering included.
  # @return [Integer]
  def owned = zones.sum(&:owned)

  # The proxies in every zone, Considering included (quantities).
  # @return [Integer]
  def proxy = zones.sum(&:proxy)

  # The deck's cards: owned copies plus proxies (spec 060 decision 12).
  # @return [Integer]
  def total = owned + proxy

  private
    def build_zones
      locations = ordered_locations
      copies = copies_by_zone_and_entry(locations)
      proxies = proxies_by_zone_and_entry(locations)
      entries = entries_for((copies.keys + proxies.keys).map(&:last).uniq)
      locations.map { |location| Zone.new(location:, groups: groups_for(location, entries, copies, proxies)) }
    end

    # One statement: { [zone id, entry id] => [Line] }, the proxies of the deck's zones by value (the account and the zones'
    # ids), in id order.
    def proxies_by_zone_and_entry(locations)
      Deck::Proxy.where(account_id: deck.account_id, location_id: locations.map(&:id)).order(:id)
        .pluck(:location_id, :catalog_entry_id, :id, :finish, :quantity)
        .group_by { |zone_id, entry_id, *| [ zone_id, entry_id ] }
        .transform_values { |rows| rows.map { |_zone, _entry, id, finish, quantity| Line.new(id:, finish:, quantity:) } }
    end

    def groups_for(location, entries, copies, proxies)
      rows = entries.filter_map do |entry|
        owned = copies[[ location.id, entry.id ]]
        lines = proxies.fetch([ location.id, entry.id ], [])
        next if owned.nil? && lines.empty?

        Row.new(entry:, owned: owned.to_i, lines:, answer: Catalog::DeckCards.answer(deck.collectible_type, entry, deck.format))
      end
      rows.group_by { it.answer.position }.sort_by { |position, _| position || Float::INFINITY }
        .map { |_position, in_group| Group.new(name: in_group.first.answer.group, rows: in_group) }
    end
```

(Keep `ordered_locations`, `copies_by_zone_and_entry` and `entries_for` as they are. Update the class comment: "at most 6 statements with the deck's location loaded, 3 for a deck with no lots and no proxies (spec 068 AC-2.10)".)

- [ ] **Step 4: Run** `bin/rspec spec/models/deck/page_spec.rb`: the new examples pass; the file's existing example "runs 5 statements for a small deck and for a large one alike" now reads 6 (the proxies' statement always runs): change its title and its expected `[ 5, 5 ]` to `[ 6, 6 ]` and its comment to add "the proxies", in the same commit.
- [ ] **Step 5: Commit** `feat(decks): the deck page model reads proxies (spec 068 T4)`.

### T5: The Decks page's listing

- [ ] **Step 1: The failing spec**, `spec/models/deck/listing_spec.rb` (read the existing file; add):

```ruby
  it "adds the proxies of every zone to a deck's cards and lists owned and proxy apart (AC-5.1)", :aggregate_failures do
    deck = create(:deck, account:, name: "Alpha")
    create_lot_in_zone(deck, "main", quantity: 3)
    create(:deck_proxy, zone: deck.zone("sideboard"), account:, quantity: 4)
    create(:deck_proxy, zone: deck.zone("considering"), account:, quantity: 2)
    create(:deck, account:, name: "Beta")

    alpha, beta = described_class.new(account).rows

    expect([ alpha.owned, alpha.proxy, alpha.cards ]).to eq([ 3, 6, 9 ])
    expect([ beta.owned, beta.proxy, beta.cards ]).to eq([ 0, 0, 0 ])
  end

  it "reads the proxies with one grouped statement, however many decks (AC-5.3)" do
    3.times { |n| create(:deck_proxy, zone: create(:deck, account:, name: "D#{n}").zone("main"), account:) }

    expect(count_queries { described_class.new(account).rows }).to eq(4) # the decks, their locations, the copies, the proxies
  end
```

(The old count was 3, the decks, their locations and the copies; the new is 4. The example asserts a figure so a later change is noticed.)

- [ ] **Step 2: Run, confirm it fails.** **Step 3:** in `app/models/deck/listing.rb`:

```ruby
  # One row of the page: the deck (its location loaded), the copies owned in all its zones and the proxies in them,
  # Considering included.
  Row = Data.define(:deck, :owned, :proxy) do
    # The deck's cards: owned plus proxy (spec 060 decision 12).
    def cards = owned + proxy
  end
```

and `rows`:

```ruby
  # The page's rows, read once per listing so the page and its count agree. The copies and the proxies are each summed per deck
  # in one grouped statement and the decks' locations preloaded, so the cost doesn't grow with the number of decks.
  # @return [Array<Row>] the decks by comparison key, then name; a deck with no copies and no proxies has 0 of each
  def rows
    @rows ||= begin
      owned = @account.lots.joins(:location).where(locations: { kind: "deck_zone" }).group("locations.parent_id").sum(:quantity)
      proxies = @account.deck_proxies.joins(:zone).group("locations.parent_id").sum(:quantity)
      @account.decks.listing_order.preload(:location).map do |deck|
        Row.new(deck:, owned: owned.fetch(deck.location_id, 0), proxy: proxies.fetch(deck.location_id, 0))
      end
    end
  end
```

Update the class comment: "one grouped read of the copies and one of the proxies". Fix any other caller of `Row.new(deck:, cards:)` (grep `Listing::Row`) and the helpers' `row.cards` stays valid.

- [ ] **Step 4: Run** the file and `spec/requests/decks_spec.rb` (its "same number of queries with 2 decks as with 10" example compares two counts, so no number moves; the listing's own example in `listing_spec.rb`, if it asserts a figure, goes up by one). **Step 5: Commit** `feat(decks): the Decks listing counts proxies (spec 068 T5)`.

### T6: The pages: heads, cells, tag, menu column and the Decks page's columns

- [ ] **Step 1: The failing request spec**, added to `spec/requests/deck_pages_spec.rb` (use the file's `printing`, `own`, `zone_section`, `card_rows` helpers; add `def proxy_in(zone, entry, quantity: 1, finish: "nonfoil") = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, finish:, quantity:)`):

```ruby
    describe "proxies (spec 068 Story 2)" do
      it "shows the tag, Owned 0 and Total in the row, and the three counts in the heads (AC-2.1, AC-2.3)", :aggregate_failures do
        bolt = printing
        own("main", bolt, quantity: 4)
        proxy_in("main", bolt, quantity: 5)
        proxy_in("sideboard", printing(name: "Spell Pierce"), quantity: 2)

        get deck_path(deck)

        expect(html.at_css(".c-item__type").text).to eq("Modern · 11 cards · 4 owned · 7 proxy")
        main = zone_section("Main")
        expect(main.at_css(".c-section__count").text).to eq("9 cards · 4 owned · 5 proxy")
        row = card_rows(main).first
        expect(row.css("td")[2].text.strip).to eq("4")
        expect(row.css("td")[3].at_css("span.c-proxy").text.squish).to eq("Proxy 5")
        expect(row.css("td")[4].text.strip).to eq("9")
        expect(row.at_css(".c-table__sub .c-proxy").text.squish).to eq("Proxy 5")
        side = card_rows(zone_section("Sideboard")).first
        expect(side.css("td")[2].text.strip).to eq("0")
        expect(main.at_css("tr.c-zone__group .c-zone__groupcount").text).to eq("9")
      end

      it "shows a muted dash and no tag for a row with no proxy, and '0 proxy' in an empty zone's head (AC-2.1, AC-2.3)", :aggregate_failures do
        own("main", printing)

        get deck_path(deck)

        row = card_rows(zone_section("Main")).first
        expect(row.css("td")[3].at_css(".c-proxy")).to be_nil
        expect(row.css("td")[3].at_css(".is-muted").text).to eq("–")
        expect(row.at_css(".c-table__sub .c-proxy")).to be_nil
        expect(zone_section("Sideboard").at_css(".c-section__count").text).to eq("0 cards · 0 owned · 0 proxy")
        expect(zone_section("Sideboard").at_css(".c-zone__empty").text).to eq("No cards in Sideboard yet.")
      end

      it "gives each zone head an Add a proxy link, and the page no form (AC-1.1, AC-2.7)", :aggregate_failures do
        get deck_path(deck)

        main = zone_section("Main")
        link = main.at_css(".c-section__actions a")
        expect(link["href"]).to eq(new_deck_zone_proxy_path(deck, "main"))
        expect(link.text.squish).to eq("Add a proxy to Main")
        expect(zone_section("Sideboard").at_css(".c-section__actions a")).to be_present
        expect(html.at_css("main form")).to be_nil
      end

      it "has a menu cell with the proxy items for a row with a proxy, and none for a row without (AC-2.6, AC-2.7)", :aggregate_failures do
        bolt = printing
        proxy_in("main", bolt)
        own("main", printing(name: "Spell Pierce"))

        get deck_path(deck)

        rows = card_rows(zone_section("Main"))
        with, without = rows.partition { it.at_css("a").text.include?("Lightning") }.map(&:first)
        trigger = with.at_css("td.c-table__actions summary")
        expect(trigger["aria-label"]).to match(/\AActions for Lightning Bolt /)
        items = with.css(".c-menu__item")
        expect(items.map { it.text.strip }).to eq([ "Change proxy count", "Remove proxy" ])
        expect(items.last["class"]).to include("c-menu__item--danger")
        expect(with.css(".c-menu__sep").size).to eq(1)
        expect(without.at_css("td.c-table__actions").children.map(&:text).join.strip).to eq("")
        expect(without.at_css("summary")).to be_nil
        expect(html.css("th").map { it.text.strip }.first(6)).to eq([ "Card", "Cost", "Owned", "Proxy", "Total", "Actions" ])
      end

      it "names the finish in a row with proxies of two finishes (AC-2.6)", :aggregate_failures do
        bolt = printing
        proxy_in("main", bolt, finish: "foil", quantity: 1)
        proxy_in("main", bolt, finish: "nonfoil", quantity: 2)

        get deck_path(deck)

        items = card_rows(zone_section("Main")).first.css(".c-menu__item").map { it.text.strip }
        expect(items).to eq([ "Change Foil proxy count", "Change Nonfoil proxy count", "Remove Foil proxy", "Remove Nonfoil proxy" ])
      end

      it "shows a proxy of a retired printing and a legality marker on a proxy row (AC-2.8, AC-2.9)", :aggregate_failures do
        banned = printing(name: "Black Lotus", legalities: { "modern" => "banned" })
        retired = create(:catalog_entry, :retired, name: "Old Card")
        create(:mtg_printing, entry: retired)
        proxy_in("main", banned)
        proxy_in("main", retired)

        get deck_path(deck)

        rows = card_rows(zone_section("Main"))
        expect(rows.map { it.at_css("a").text }).to include("Black Lotus", "Old Card")
        expect(rows.find { it.at_css("a").text == "Black Lotus" }.at_css(".c-legal").text).to include("Banned")
      end

      it "counts no proxy in the collection, the card page or an export's lots (AC-4.1)", :aggregate_failures do
        bolt = printing
        proxy_in("main", bolt, quantity: 3)

        get collection_path
        expect(response.body).not_to include("Lightning Bolt")
        get catalog_entry_path(bolt)
        expect(html.text).not_to match(/\b3 copies\b/)
        expect(CollectionExport.new(account:, at: Time.current).to_h["lots"]).to eq([])
      end
    end
```

and in `spec/requests/decks_spec.rb` (the Decks page):

```ruby
    it "shows Cards as owned plus proxy, Owned, and the Proxy tag or a dash, and the phone line's tag (AC-5.1, AC-5.2)", :aggregate_failures do
      alpha = create(:deck, account:, name: "Alpha")
      create_lot_in_zone(alpha, "main", quantity: 58)
      create(:deck_proxy, zone: alpha.zone("main"), account:, quantity: 11)
      create(:deck, account:, name: "Beta")

      get decks_path

      a, b = html.css("tbody tr")
      expect(a.css("td")[2].text.strip).to eq("69")
      expect(a.css("td")[3].text.strip).to eq("58")
      expect(a.css("td")[4].at_css(".c-proxy").text.squish).to eq("Proxy 11")
      expect(a.at_css(".c-table__sub").text.squish).to eq("Modern · 58 owned Proxy 11")
      expect(b.css("td")[4].at_css(".is-muted").text).to eq("–")
      expect(html.at_css(".c-pagehead__stats").text).to eq("2 decks · 69 cards")
      expect(html.css("th").map { it.text.strip }).to eq([ "Deck", "Format", "Cards", "Owned", "Proxy", "Actions" ])
    end
```

(`html` and the `own`/`create_lot_in_zone` helpers are as that spec defines them; read it first and use its names.)

- [ ] **Step 2: Run both files, confirm failures** (`NoMethodError`/missing route helper `new_deck_zone_proxy_path` — T8 adds the route; add only the **route lines** for the chooser now (Step 3) so the link helper exists; the controller is T8's).
- [ ] **Step 3: Routes**, in `config/routes.rb` inside `resources :decks ... do` after the `selection` line:

```ruby
    # Spec 068: a proxy is named by its own id under its deck (the deck's location id is :deck_id).
    scope module: :decks do
      resources :proxies, only: %i[edit update destroy] do
        resource :removal, only: :new, module: :proxies
      end
    end
```

and, after the `end` of that `resources :decks` block, two top-level routes (a `get` inside the block would be named `deck_new_zone_proxy`, which no `as:` can change), so a zone is named by its key within the deck:

```ruby
  # Spec 068: add a proxy to a zone, named by its key in the path (:deck_id is the deck's location id, never a zone's).
  get "decks/:deck_id/zones/:zone/proxies/new", to: "decks/proxies#new", as: :new_deck_zone_proxy
  post "decks/:deck_id/zones/:zone/proxies", to: "decks/proxies#create", as: :deck_zone_proxies
```

`bin/rails routes -g proxy` must list `new_deck_zone_proxy`, `deck_zone_proxies`, `edit_deck_proxy`, `deck_proxy` (PATCH, DELETE) and `new_deck_proxy_removal`; these are the names every spec and view of this plan uses.

- [ ] **Step 4: The helpers** in `app/helpers/decks_helper.rb` (replace `deck_sub_line`, `deck_counts_line` and `deck_page_line`; add the rest):

```ruby
  # "Format name · 58 owned": the line a narrow table shows under a deck's name; the proxy tag follows it in the view.
  #
  # @param row [Deck::Listing::Row]
  # @return [String]
  def deck_sub_line(row) = "#{row.deck.format_name} · #{number_with_delimiter(row.owned)} owned"

  # "60 cards · 52 owned · 8 proxy": a zone's counts and the tail of the page head (spec 068 decision 7). Cards are owned plus
  # proxy, and "proxy" has no plural.
  #
  # @param owned [Integer] the copies counted
  # @param proxy [Integer] the proxies counted (quantities)
  # @return [String]
  def deck_counts_line(owned, proxy = 0) = "#{pluralize(number_with_delimiter(owned + proxy), "card")} · #{number_with_delimiter(owned)} owned · #{number_with_delimiter(proxy)} proxy"

  # The deck page's muted head line: the format's name (its key when no longer registered), then the counts of every zone.
  #
  # @param page [Deck::Page]
  # @return [String]
  def deck_page_line(page) = "#{page.deck.format_name} · #{deck_counts_line(page.owned, page.proxy)}"

  # The dashed tag of a proxy count: `<span class="c-proxy">Proxy <b>2</b></span>` (ProxyTag, spec 060 FR-1).
  #
  # @param count [Integer]
  # @return [ActiveSupport::SafeBuffer]
  def proxy_tag(count) = tag.span(class: "c-proxy") { safe_join([ "Proxy ", tag.b(number_with_delimiter(count)) ]) }

  # "Izzet Tempo › Main": a zone as the pages say it, from the deck's name and the zone's own, without loading the parent.
  #
  # @param deck [Deck]
  # @param zone [Location]
  # @return [String]
  def proxy_zone_label(deck, zone) = Location::Placement.label(zone.name, deck.name)

  # "Lightning Bolt (MH2 · 138, Foil)": a proxy as the pages and notices name it, the finish after the number only when it has one.
  #
  # @param proxy [Deck::Proxy] with its entry and set loaded
  # @return [String]
  def proxy_name(proxy)
    detail = [ set_number(proxy.entry), proxy.finish_label ].compact.join(", ")
    "#{proxy.entry.name} (#{detail})"
  end

  # A row menu item's words (spec 068 decision 5): "Change proxy count" / "Remove proxy", with the finish named when the row has
  # proxies of more than one finish: "Change Foil proxy count", "Remove Foil proxy".
  #
  # @param verb [String] "Change" or "Remove"
  # @param line [Deck::Page::Line]
  # @param row [Deck::Page::Row]
  # @return [String]
  def proxy_item_label(verb, line, row)
    finish = line.finish && row.lines.size > 1 ? "#{proxy_finish_label(row.entry, line.finish)} " : ""
    verb == "Change" ? "Change #{finish}proxy count" : "Remove #{finish}proxy"
  end

  # The finish as its collectible's vocabulary labels it; the humanised key for a collectible this instance no longer has.
  #
  # @param entry [Catalog::Entry]
  # @param finish [String]
  # @return [String]
  def proxy_finish_label(entry, finish)
    Catalog.collecting.key?(entry.collectible_type) ? Catalog.collecting_for(entry.collectible_type).finish_label(finish) : finish.humanize
  end
```

- [ ] **Step 5: The views.** `app/views/decks/_zone.html.erb`:

```erb
<section class="c-zone">
  <div class="c-section__head">
    <h2 class="c-section__title" id="zone-<%= zone.id %>"><%= zone.name %></h2>
    <span class="c-section__count"><%= deck_counts_line(zone.owned, zone.proxy) %></span>
    <div class="c-section__actions">
      <%= link_to new_deck_zone_proxy_path(@deck, zone.location.zone), class: "c-btn c-btn--ghost c-btn--sm" do %><%= render "icons/plus" %>Add a proxy<span class="c-sr"> to <%= zone.name %></span><% end %>
    </div>
  </div>
  <% if zone.empty? %>
    <p class="c-zone__empty">No cards in <%= zone.name %> yet.</p>
  <% else %>
    <div class="c-collection">
      <table class="c-table" aria-labelledby="zone-<%= zone.id %>">
        <thead>
          <tr>
            <th>Card</th>
            <th class="c-zone__c-cost">Cost</th>
            <th class="c-zone__c-owned is-num is-opt">Owned</th>
            <th class="c-zone__c-proxy is-num is-opt">Proxy</th>
            <th class="c-zone__c-total is-num">Total</th>
            <th class="c-zone__c-menu"><span class="c-sr">Actions</span></th>
          </tr>
        </thead>
        <% zone.groups.each do |group| %>
          <tbody>
            <% if group.name %>
              <tr class="c-zone__group"><th scope="rowgroup" colspan="6"><%= group.name %><span class="c-zone__groupcount"><%= number_with_delimiter(group.total) %></span></th></tr>
            <% end %>
            <%= render partial: "decks/card_row", collection: group.rows, as: :row %>
          </tbody>
        <% end %>
      </table>
    </div>
  <% end %>
</section>
```

`app/views/decks/_card_row.html.erb`:

```erb
<% entry = row.entry %>
<% marker = row.answer.legality %>
<tr>
  <td>
    <div class="c-table__item"><div>
      <%= link_to entry.display_name, catalog_entry_path(entry, from: "collection", anchor: "copies") %>
      <% if marker %><span class="is-opt"> <%= render "decks/legality_marker", word: marker %></span><% end %>
      <span class="is-opt"><br><span class="c-zone__set"><%= deck_set_line(entry) %></span></span>
      <span class="c-table__sub"><span class="c-zone__set"><%= deck_set_line(entry) %></span><% if row.proxy.positive? %> <%= proxy_tag(row.proxy) %><% end %><% if marker %> <%= render "decks/legality_marker", word: marker %><% end %></span>
    </div></div>
  </td>
  <td><%= row.answer.costed ? render_catalog_extension(entry, :deck_cost) : tag.span("–", class: "is-muted") %></td>
  <td class="is-num is-opt"><%= number_with_delimiter(row.owned) %></td>
  <td class="is-num is-opt"><%= row.proxy.positive? ? proxy_tag(row.proxy) : tag.span("–", class: "is-muted") %></td>
  <td class="is-num"><%= number_with_delimiter(row.total) %></td>
  <td class="c-table__actions"><%= render "decks/proxy_menu", deck: @deck, row: %></td>
</tr>
```

`app/views/decks/_proxy_menu.html.erb`:

```erb
<%# locals: (deck:, row:) %>
<% if row.lines.any? %>
  <details class="c-menu" data-controller="menu">
    <summary class="c-btn c-btn--ghost c-btn--sm c-btn--icon" aria-label="Actions for <%= row.entry.display_name %> <%= deck_set_line(row.entry) %>"><%= render "icons/more" %></summary>
    <div class="c-menu__list">
      <% row.lines.each do |line| %>
        <%= link_to proxy_item_label("Change", line, row), edit_deck_proxy_path(deck, line.id), class: "c-menu__item" %>
      <% end %>
      <div class="c-menu__sep"></div>
      <% row.lines.each do |line| %>
        <%= link_to proxy_item_label("Remove", line, row), new_deck_proxy_removal_path(deck, line.id), class: "c-menu__item c-menu__item--danger" %>
      <% end %>
    </div>
  </details>
<% end %>
```

`app/views/decks/index.html.erb`: add the Proxy header and cell and the phone tag:

```erb
            <th class="is-num is-opt">Owned</th>
            <th class="is-num is-opt">Proxy</th>
```
```erb
              <td><div class="c-table__item"><div><span><%= link_to deck.name, deck_path(deck) %></span><span class="c-table__sub"><%= deck_sub_line(row) %><% if row.proxy.positive? %> <%= proxy_tag(row.proxy) %><% end %></span></div></div></td>
              <td class="is-opt"><%= deck.format_name %></td>
              <td class="is-num"><%= number_with_delimiter(row.cards) %></td>
              <td class="is-num is-opt"><%= number_with_delimiter(row.owned) %></td>
              <td class="is-num is-opt"><%= row.proxy.positive? ? proxy_tag(row.proxy) : tag.span("–", class: "is-muted") %></td>
```

(`deck_count_line` keeps `listing.rows.sum(&:cards)`.)

- [ ] **Step 6: Run** `bin/rspec spec/requests/deck_pages_spec.rb spec/requests/decks_spec.rb spec/helpers`: pass, after updating the two existing examples that assert the spec 066 heads ("58 cards · 58 owned", "12 cards · 12 owned", "0 cards · 0 owned", every Proxy cell a dash, no menu column, five columns) to their spec 068 texts ("… · 0 proxy", six `th`, the last "Actions"); each such edit is one assertion changed to the text AC-2.3 gives. The examples that spec 066 wrote and spec 068 supersedes (its "Supersedes and updates") are, in `spec/requests/deck_pages_spec.rb`: the head texts at lines ~43, 48, 52, 60, 115, 199, 211 and 368 ("58 cards · 58 owned", "12 cards · 12 owned", "0 cards · 0 owned", each gains " · 0 proxy"); the AC-1.6 example at ~75 ("no proxy control, no proxy count and no proxy tag"), which is rewritten whole: it keeps "no shape panel" and a dash in the Proxy cell of a row with no proxy, and drops the rest; the AC-4.2 example at ~337, whose selector `form, .c-table__actions, [draggable]` becomes `form, [draggable]` (every row now has an actions cell; the menu's own checks are AC-2.6's) and which keeps its "no link to a new copy, number entry or the scanner"; the `thead th` list at ~118 (`[ "Card", "Cost", "Owned", "Proxy", "Total" ]` gains `"Actions"`); and in `spec/requests/decks_spec.rb` the column list at ~30 (five headers become six: `Deck Format Cards Owned Proxy Actions`) and the line at ~33 `expect(html.at_css(".c-decks").text).not_to include("Proxy")` (spec 066's "no Proxy column": delete it) and any Cards or Owned cell it asserts (Cards is owned plus proxy). Each change is a supersession the spec names, never a weakened assertion for a behaviour that still holds.
- [ ] **Step 7: The system spec** `spec/system/deck_page_spec.rb`: extend the spec 066 widths example (read it; it measures overflow at 360/640/768/1280px in both themes) so its seeded deck has a proxy row with a four-digit proxy count, the 60-character name, the six-symbol cost and a marker, and asserts: no horizontal overflow, the zone heads' counts uncut, the Cost cell's scroll width ≤ client width (AC-2.11), the Cost, Owned, Proxy, Total and menu columns share a left edge and width across three zone tables at 1280px (AC-2.5), Owned and Proxy hidden below 640px with the tag in the line under the name (AC-2.4), and every menu trigger at least 44px on a coarse pointer (AC-2.11). The existing CSS has the widths (`additions.css:481-487`); if an example fails, fix it with a rule under a new heading comment `(spec 068 deck page with proxies)` in `additions.css`, never a literal colour or size outside the tokens.
- [ ] **Step 7b: The columns the system spec reads.** In `spec/system/deck_page_spec.rb`, the example "shows the marker and the set line beside the name from 768px … and all five columns" (line ~110) expects `shown_headers` to eq `[ "Card", "Cost", "Owned", "Proxy", "Total" ]`: it gains `"Actions"` and "six columns" in its title; run the file and change any other spec 066 expectation that names five columns or no menu to spec 068's (a supersession the spec names).
- [ ] **Step 8: The Decks page at the narrow widths** (AC-5.2, AC-5.2a): extend `spec/system/decks_spec.rb` (read it: it has the Decks page's overflow examples) with a deck that has 58 owned copies, 11 proxies and a 60-character name with no space, and assert at 360px (narrow frame) that Format, Owned and Proxy are hidden, the line under the name reads "Modern · 58 owned" followed by the tag, there is no horizontal overflow, and at 640px, 768px and 1280px in both themes there is no horizontal overflow and the tag and the three action buttons don't overlap (their bounding boxes don't intersect). If the row's actions don't fit at 640px, fix it with a rule under a heading comment `(spec 068 Decks list with proxies)` in `additions.css`.
- [ ] **Step 9: Run** `bin/rspec spec/system/deck_page_spec.rb spec/system/decks_spec.rb`. **Step 10: Commit** `feat(decks): proxies on the deck page and the Decks page (spec 068 T6)`.

---

## Phase 2: Add a proxy

**Implements:** FR-1, Story 1 | **Satisfies:** AC-1.1 to AC-1.11, AC-9.1 (chooser and form)
**Files:** `app/models/catalog/search.rb`, `app/controllers/concerns/finds_deck.rb`, `app/controllers/decks/proxies_controller.rb`, `app/views/decks/proxies/choose.html.erb`, `new.html.erb`, `_group.html.erb`, `spec/models/catalog/search_spec.rb`, `spec/requests/deck_proxies_spec.rb`, `spec/system/deck_proxies_spec.rb`
**Interfaces:** Consumes `Deck::Proxy.add!`, `Deck::Proxy::Addition`, `Catalog::Search`. Produces `Catalog::Search.new(..., collectible_type:)`, `FindsDeck#set_deck`, `FindsDeck#set_proxy`, the routes of T6, `Decks::ProxiesController#new/#create`.

### T7: The search's collectible filter

- [ ] **Step 1: The failing spec**, added to `spec/models/catalog/search_spec.rb` (read it; it has its own entry helpers):

```ruby
  it "lists only the printings of the collectible type it is given (spec 068 AC-1.3)", :aggregate_failures do
    mtg = create(:catalog_entry, name: "Bolt of Mtg")
    other = create(:catalog_entry, name: "Bolt of Other", collectible_type: "other")

    everything = described_class.new(query: "Bolt")
    only_mtg = described_class.new(query: "Bolt", collectible_type: "mtg")

    expect(everything.pagination.total_count).to eq(2) # not `groups`: it preloads each type's extension, and "other" has no source
    expect(only_mtg.groups.flat_map(&:entries)).to contain_exactly(mtg)
    expect(only_mtg.pagination.total_count).to eq(1)
  end
```

- [ ] **Step 2: Run, confirm it fails** (`ArgumentError: unknown keyword: :collectible_type`).
- [ ] **Step 3: The change**, `app/models/catalog/search.rb`: add the keyword and a private scope used by both reads:

```ruby
  attr_reader :query, :set_code

  # @param collectible_type [String, nil] limits the results to one collectible type's printings (the add-a-proxy page lists
  #   only the deck's own; spec 068 decision 3); nil searches every type, as the card search does
  def initialize(query: nil, set_code: nil, page: nil, collectible_type: nil)
    @query = query.to_s.strip.first(MAX_QUERY_LENGTH)
    @set_code = set_code.presence
    @requested_page = page
    @collectible_type = collectible_type.presence
  end
```

In `groups`, replace `Catalog::Entry.searchable.in_set(set_code).where(catalog_identity_id: ...)` with `entries_scope.where(catalog_identity_id: identities.map(&:id))`, and `matching_entries` with:

```ruby
    def entries_scope
      scope = Catalog::Entry.searchable.in_set(set_code)
      @collectible_type ? scope.where(collectible_type: @collectible_type) : scope
    end

    def matching_entries
      query.present? ? entries_scope.named_like(query) : entries_scope
    end
```

- [ ] **Step 4: Run** `bin/rspec spec/models/catalog/search_spec.rb spec/requests/catalog_entries_spec.rb` (every existing example passes: no caller passes the keyword). **Step 5: Commit** `feat(catalog): the card search can be limited to one collectible type (spec 068 T7)`.

### T8: The chooser, the form and the create

- [ ] **Step 1: The failing request spec** `spec/requests/deck_proxies_spec.rb`:

```ruby
require "rails_helper"

# Spec 068 Stories 1 and 3: the add, change and remove pages of a deck zone's proxies.
RSpec.describe "Deck proxies", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def html = Nokogiri::HTML5(response.body)
  # Printings of one card share an identity (the search groups by it); pass `identity: bolt` for several printings of a card.
  def printing(name: "Lightning Bolt", finishes: %w[foil nonfoil], identity: nil, **attrs)
    create(:mtg_printing, entry: create(:catalog_entry, name:, identity: identity || create(:catalog_identity, name:), **attrs), finishes:).entry
  end

  let(:bolt) { create(:catalog_identity, name: "Lightning Bolt") }

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the chooser (AC-1.2, AC-1.3)" do
      it "is a detail page titled for the zone, with the search and no results until a name or a set is given", :aggregate_failures do
        get new_deck_zone_proxy_path(deck, "main")

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Add a proxy to Izzet Tempo › Main · Collector")
        expect(html.at_css("header.c-appbar--detail")).to be_present
        expect(html.at_css("input[name=q]")).to be_present
        expect(html.at_css("select[name=set]")).to be_present
        expect(html.css("a").select { it.text.start_with?("Choose") }).to be_empty
      end

      it "lists a card's printings of the deck's type with a Choose link each, and no retired or other printing", :aggregate_failures do
        first = printing(identity: bolt)
        second = printing(identity: bolt, set: create(:catalog_set, code: "mh2"))
        create(:mtg_printing, entry: create(:catalog_entry, :retired, name: "Lightning Bolt", identity: bolt))
        create(:catalog_entry, name: "Lightning Bolt", collectible_type: "other")

        get new_deck_zone_proxy_path(deck, "main", q: "Lightning")

        links = html.css("a").select { it.text.start_with?("Choose") }
        expect(links.map { it["href"] }).to match_array([ first, second ].map { new_deck_zone_proxy_path(deck, "main", entry: it.external_key) })
        expect(html.text).to include("2 printings")
      end

      it "says how many printings of a card with more than ten it shows (AC-1.3)" do
        12.times { |n| printing(identity: bolt, set: create(:catalog_set, code: "s#{n}")) }

        get new_deck_zone_proxy_path(deck, "main", q: "Lightning")

        expect(html.text).to include("Showing 10 of 12 printings. Choose a set to see the others.")
      end

      it "pages the cards as the card search does (12 a page)", :aggregate_failures do
        13.times { |n| printing(name: "Bolt #{format("%02d", n)}") }

        get new_deck_zone_proxy_path(deck, "main", q: "Bolt")

        expect(html.css("section.c-group").size).to eq(12)
        expect(html.at_css("nav.c-pager a[rel=next]")["href"]).to include("page=2")
      end
    end

    describe "the form (AC-1.4)" do
      it "shows the printing, a Finish select of its finishes (in the vocabulary's order) with nothing chosen, a Quantity of 1, Add proxy and Cancel", :aggregate_failures do
        entry = printing

        get new_deck_zone_proxy_path(deck, "main", entry: entry.external_key)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("Add a proxy to Izzet Tempo › Main")
        expect(html.at_css("select[name='proxy[finish]'] option[selected]")).to be_nil
        expect(html.css("select[name='proxy[finish]'] option").map(&:text)).to eq([ "Choose…", "Nonfoil", "Foil" ]) # the vocabulary's finish order
        expect(html.at_css("input[name='proxy[quantity]']")["value"]).to eq("1")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Add proxy")
        expect(html.css("a").find { it.text.squish == "Cancel" }["href"]).to eq(deck_path(deck))
        expect(html.css("label").map(&:text)).to include("Finish", "Quantity") # each field has its visible label (AC-9.1)
      end

      it "ties a field's error to it with aria-describedby (AC-9.1)", :aggregate_failures do
        post deck_zone_proxies_path(deck, "main"), params: { proxy: { entry: printing.external_key, finish: "foil", quantity: "0" } }

        field = html.at_css("input[name='proxy[quantity]']")
        expect(field["aria-describedby"]).to be_present
        expect(html.at_css("##{field["aria-describedby"]}").text).to eq("Enter a number from 1 to 9,999.")
      end

      it "chooses the only finish, and shows no Finish select for a printing that lists none", :aggregate_failures do
        get new_deck_zone_proxy_path(deck, "main", entry: printing(finishes: %w[nonfoil]).external_key)
        expect(html.at_css("select[name='proxy[finish]'] option[selected]").text).to eq("Nonfoil")

        get new_deck_zone_proxy_path(deck, "main", entry: printing(finishes: []).external_key)
        expect(html.at_css("select[name='proxy[finish]']")).to be_nil
      end
    end

    describe "the create (AC-1.5, AC-1.6, AC-1.8 to AC-1.10)" do
      def add(entry, zone: "main", **proxy) = post(deck_zone_proxies_path(deck, zone), params: { proxy: { entry: entry.external_key, finish: "foil", quantity: "2" }.merge(proxy) })

      it "writes the proxy, redirects to the deck page with the notice, and creates no lot", :aggregate_failures do
        entry = printing

        add(entry)

        expect(response).to redirect_to(deck_path(deck))
        expect(flash[:notice]).to eq("Added 2 proxies of Lightning Bolt (#{entry.set.code.upcase} · #{entry.number}, Foil) to Izzet Tempo › Main.")
        proxy = Deck::Proxy.sole
        expect([ proxy.zone, proxy.entry, proxy.finish, proxy.quantity ]).to eq([ deck.zone("main"), entry, "foil", 2 ])
        expect(Lot.count).to eq(0)
      end

      it "says '1 proxy' for one, and merges into the proxy it already has (same id)", :aggregate_failures do
        entry = printing
        add(entry, quantity: "1")
        expect(flash[:notice]).to start_with("Added 1 proxy of ")
        first = Deck::Proxy.sole

        add(entry, quantity: "3")

        expect(Deck::Proxy.sole.id).to eq(first.id)
        expect(Deck::Proxy.sole.quantity).to eq(4)
      end

      it "answers 422 with the field's sentence and what was typed, and writes nothing", :aggregate_failures do
        entry = printing

        add(entry, quantity: "0")
        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css(".c-field__error").text).to eq("Enter a number from 1 to 9,999.")
        expect(html.at_css("input[name='proxy[quantity]']")["value"]).to eq("0")
        add(entry, finish: "")
        expect(html.at_css(".c-field__error").text).to eq("Choose a finish.")
        add(entry, finish: "etched")
        expect(html.at_css(".c-field__error").text).to eq("That finish isn't available for this printing.")
        expect(Deck::Proxy.count).to eq(0)
      end

      it "refuses an add past 9,999 with the cap sentence and changes nothing", :aggregate_failures do
        entry = printing
        add(entry, quantity: "9990")

        add(entry, quantity: "10")

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css(".c-field__error").text).to eq(Deck::Proxy::FULL_MESSAGE)
        expect(Deck::Proxy.sole.quantity).to eq(9_990)
      end

      it "reads no account, zone id, kind or user from the request (AC-1.11)", :aggregate_failures do
        stranger = create(:user).account
        entry = printing

        post deck_zone_proxies_path(deck, "main"), params: { account_id: stranger.id, location_id: 1, kind: "place", user_id: 1,
                                                              proxy: { entry: entry.external_key, finish: "foil", quantity: "1", account_id: stranger.id, location_id: 1 } }

        expect(Deck::Proxy.sole.account).to eq(account)
        expect(Deck::Proxy.sole.zone).to eq(deck.zone("main"))
      end
    end

    describe "what is 404 (AC-1.7, AC-1.10)" do
      let(:entry) { printing }

      it "answers 404 for another account's deck, a place, a zone, a malformed id, a zone key the deck lacks and an entry it can't use", :aggregate_failures do
        theirs = create(:deck, account: create(:user).account, name: "Theirs")
        place = create(:location, account:)
        retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
        elsewhere = create(:catalog_entry, collectible_type: "other")
        token = create(:catalog_entry, kind: "token")
        bad = [
          new_deck_zone_proxy_path(theirs, "main"), new_deck_zone_proxy_path(place.id, "main"), new_deck_zone_proxy_path(deck.zone("main").id, "main"),
          "/decks/12abc/zones/main/proxies/new", new_deck_zone_proxy_path(deck, "commander"),
          new_deck_zone_proxy_path(deck, "main", entry: "no-such-entry"), new_deck_zone_proxy_path(deck, "main", entry: retired.external_key),
          new_deck_zone_proxy_path(deck, "main", entry: elsewhere.external_key), new_deck_zone_proxy_path(deck, "main", entry: token.external_key)
        ]
        bad.each do |path|
          get path
          expect(response).to have_http_status(:not_found), path
        end
        post deck_zone_proxies_path(theirs, "main"), params: { proxy: { entry: entry.external_key, finish: "foil", quantity: "1" } }
        expect(response).to have_http_status(:not_found)
        post deck_zone_proxies_path(deck, "main"), params: { proxy: { entry: retired.external_key, finish: "foil", quantity: "1" } }
        expect(response).to have_http_status(:not_found)
        expect(Deck::Proxy.count).to eq(0)
      end

      it "answers 404 for a deck whose collectible type the instance no longer registers (decision 19)" do
        deck.update_columns(collectible_type: "gone")

        get new_deck_zone_proxy_path(deck, "main")

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  it "sends a visitor who isn't signed in to sign in (AC-1.7)", :aggregate_failures do
    deck = create(:deck)

    get new_deck_zone_proxy_path(deck, "main")
    expect(response).to redirect_to(new_session_path)
    post deck_zone_proxies_path(deck, "main")
    expect(response).to redirect_to(new_session_path)
  end
end
```

- [ ] **Step 2: Run, confirm it fails** (`uninitialized constant Decks::ProxiesController` or a routing error).
- [ ] **Step 3: The concern** `app/controllers/concerns/finds_deck.rb`:

```ruby
# Finds the deck, and a proxy of it, for the proxy controllers (spec 068): by the deck's location id and the proxy's id through
# the signed-in account, so another account's deck, a place's id, a zone's id, an id that isn't digits only and another deck's
# proxy are all 404 (AC-1.7, AC-3.6). Nothing in a request names an account.
module FindsDeck
  extend ActiveSupport::Concern

  private
    # @param param [Symbol] the path parameter holding the deck's location id
    def set_deck(param = :deck_id)
      raise ActiveRecord::RecordNotFound, "not a deck id" unless params[param].to_s.match?(Location::ID_TEXT)

      @deck = Current.account.decks.includes(:location).find_by!(location_id: params[param])
    end

    # The proxy with the path's id among the deck's own (its zones'), with the entry and set the pages name it by.
    #
    # @param param [Symbol] the path parameter holding the proxy's id (`:id`; the removal page's route calls it `:proxy_id`)
    def set_proxy(param = :id)
      raise ActiveRecord::RecordNotFound, "not a proxy id" unless params[param].to_s.match?(Location::ID_TEXT)

      @proxy = @deck.proxies.includes(:zone, entry: :set).find(params[param])
    end
end
```

- [ ] **Step 4: The controller** `app/controllers/decks/proxies_controller.rb`:

```ruby
# Spec 068 Stories 1 and 3: a deck zone's proxies. The deck is found by its location id through the account and the zone by its
# key within it; a proxy by its id among the deck's. Nothing in a request names an account, a zone id or a kind (AC-1.11).
# @see file:collection-and-lots.md
class Decks::ProxiesController < ApplicationController
  include FindsDeck

  before_action :set_deck
  before_action :set_zone, :require_vocabulary, only: %i[new create]
  before_action :set_proxy, only: %i[edit update destroy]

  # The chooser (a search of the deck's collectible type), or with `entry` the form for that printing.
  def new
    return render_form(Deck::Proxy::Addition.new(account: Current.account, zone: @zone, entry: find_entry(params[:entry]))) if params[:entry].present?

    @search = Catalog::Search.new(query: search_params[:q], set_code: search_params[:set], page: search_params[:page], collectible_type: @deck.collectible_type)
    @groups = @search.groups
    @sets = Catalog::Set.with_searchable_entries.newest_first.to_a
    render :choose
  end

  # Adds the quantity to the zone's proxy of that printing and finish, or makes one (decision 4).
  def create
    entry = find_entry(proxy_params[:entry])
    @addition = Deck::Proxy::Addition.new(account: Current.account, zone: @zone, entry:, finish: proxy_params[:finish], quantity: proxy_params[:quantity])
    if @addition.save
      added = helpers.pluralize(Deck::Proxy.parse_quantity(@addition.quantity), "proxy", "proxies")
      redirect_to deck_path(@deck), status: :see_other,
        notice: "Added #{added} of #{helpers.proxy_name(@addition.proxy)} to #{helpers.proxy_zone_label(@deck, @zone)}."
    else
      render_form(@addition, status: :unprocessable_content)
    end
  end

  # The Change proxy count page (T10).
  def edit
  end

  # Sets the proxy's quantity (T10).
  def update
    count = Deck::Proxy.parse_quantity(proxy_params[:quantity])
    return refuse_quantity(proxy_params[:quantity]) unless count

    @proxy.change_quantity!(count)
    redirect_to deck_path(@deck), status: :see_other,
      notice: "Changed the proxies of #{helpers.proxy_name(@proxy)} in #{helpers.proxy_zone_label(@deck, @proxy.zone)} to #{helpers.number_with_delimiter(count)}."
  end

  # Removes the proxy (T10); the confirmation page is `Decks::Proxies::RemovalsController#new`.
  def destroy
    @proxy.destroy!
    redirect_to deck_path(@deck), status: :see_other,
      notice: "Removed the proxies of #{helpers.proxy_name(@proxy)} from #{helpers.proxy_zone_label(@deck, @proxy.zone)}."
  end

  private
    def set_zone = @zone = @deck.zones.find_by!(zone: params[:zone].to_s)

    # The vocabulary and the source name the finishes and the search; a deck whose collectible the instance lost has neither,
    # so the add pages are 404 for it (decision 19) while its proxies still show and export.
    def require_vocabulary
      type = @deck.collectible_type
      raise ActiveRecord::RecordNotFound, "no vocabulary" unless Catalog.collecting.key?(type) && Catalog.sources.key?(type)
    end

    # A searchable printing of the deck's own collectible type: a retired one, a token and another type's are 404 (AC-1.10).
    def find_entry(key)
      entry = Catalog::Entry.searchable.includes(:set).find_by!(collectible_type: @deck.collectible_type, external_key: key.to_s)
      Catalog::Entry.preload_extensions([ entry ])
      entry
    end

    def render_form(addition, status: :ok)
      @addition = addition
      vocabulary = Catalog.collecting_for(addition.entry.collectible_type)
      @finishes = vocabulary.finishes_for(addition.entry).map { [ vocabulary.finish_label(it), it ] }
      render :new, status:
    end

    def refuse_quantity(typed)
      @typed = typed.to_s
      @quantity_error = @typed.strip == "0" ? "#{Deck::Proxy::Addition::QUANTITY_SENTENCE} To remove it, use Remove proxy." : Deck::Proxy::Addition::QUANTITY_SENTENCE
      render :edit, status: :unprocessable_content
    end

    def search_params = params.permit(:q, :set, :page)

    def proxy_params = params.expect(proxy: %i[entry finish quantity])
end
```

`params.expect(proxy: [...])` is a 400 when `proxy` is missing; the signed-out request spec above posts with no params, but the sign-in redirect happens before. The 404 spec posts with params.

- [ ] **Step 5: The views.** `app/views/decks/proxies/choose.html.erb`:

```erb
<% content_for :title, "Add a proxy to #{proxy_zone_label(@deck, @zone)} · Collector" %>
<%# Back refetches this page instead of restoring a snapshot, so it never shows typed filter values. %>
<% content_for :head, tag.meta(name: "turbo-cache-control", content: "no-cache") %>
<%= render "layouts/appbar", section: :decks, detail: true, back_path: deck_path(@deck) %>
<main class="c-main c-page">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Add a proxy to <%= proxy_zone_label(@deck, @zone) %></h1>
      <p class="c-pagehead__stats">Choose a printing. A proxy is a card the deck needs that you don't own.</p>
    </div>
  </div>
  <div class="c-collection">
    <%= form_with url: new_deck_zone_proxy_path(@deck, @zone.zone), method: :get, class: "c-filterbar", role: "search" do |form| %>
      <label class="c-input"><%= render "icons/search" %><%= form.search_field :q, value: @search.query, placeholder: "Lightning Bolt", "aria-label": "Card name" %></label>
      <div class="c-filterbar__filters">
        <label class="c-select"><span class="c-sr">Set</span><%= form.select :set,
              options_for_select(@sets.map { |set| [ "#{set.name} (#{set.code.upcase})", set.code ] }, @search.set_code), include_blank: "All sets" %></label>
        <%= form.submit "Search", name: nil, class: "c-btn c-btn--secondary c-btn--sm" %>
      </div>
    <% end %>
    <% if !@search.active? %>
      <p class="c-empty">Type part of a card name to search.</p>
    <% elsif @groups.empty? %>
      <p class="c-empty">No cards match. Check the spelling or try part of the name.</p>
    <% else %>
      <div class="c-results__meta"><span class="c-filterbar__count"><%= pluralize(@search.pagination.total_count, "card") %></span></div>
      <% @groups.each do |group| %>
        <%= render "decks/proxies/group", group:, deck: @deck, zone: @zone %>
      <% end %>
      <%= render "catalog/pagination", pagination: @search.pagination, link_params: { q: @search.query.presence, set: @search.set_code } %>
    <% end %>
  </div>
  <div class="c-form__actions"><%= link_to "Cancel", deck_path(@deck), class: "c-btn c-btn--secondary" %></div>
</main>
<%= render "layouts/tabbar", section: :decks %>
```

`app/views/decks/proxies/_group.html.erb`:

```erb
<%# locals: (group:, deck:, zone:) %>
<section class="c-group" aria-labelledby="<%= dom_id(group.identity, :heading) %>">
  <div class="c-section__head">
    <h2 class="c-section__title" id="<%= dom_id(group.identity, :heading) %>"><%= group.identity.name %></h2>
    <% if group.total_entries > group.entries.size %>
      <span class="c-section__count">Showing <%= group.entries.size %> of <%= group.total_entries %> printings. Choose a set to see the others.</span>
    <% else %>
      <span class="c-section__count"><%= pluralize(group.total_entries, "printing") %></span>
    <% end %>
  </div>
  <ul class="c-list">
    <% group.entries.each do |entry| %>
      <li>
        <span class="is-data"><%= deck_set_line(entry) %></span>
        <span class="c-list__end"><%= link_to new_deck_zone_proxy_path(deck, zone.zone, entry: entry.external_key), class: "c-btn c-btn--secondary c-btn--sm" do %>Choose<span class="c-sr"> <%= group.identity.name %> <%= deck_set_line(entry) %></span><% end %></span>
      </li>
    <% end %>
  </ul>
</section>
```

`app/views/decks/proxies/new.html.erb`:

```erb
<% content_for :title, "Add a proxy to #{proxy_zone_label(@deck, @zone)} · Collector" %>
<%= render "layouts/appbar", section: :decks, detail: true, back_path: new_deck_zone_proxy_path(@deck, @zone.zone) %>
<main class="c-main c-page c-decks">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Add a proxy to <%= proxy_zone_label(@deck, @zone) %></h1>
      <p class="c-pagehead__stats"><%= @addition.entry.name %> <span class="is-data"><%= deck_set_line(@addition.entry) %></span></p>
    </div>
  </div>
  <% finish_errors = @addition.errors[:finish] %>
  <% quantity_errors = @addition.errors[:quantity] %>
  <%= form_with model: @addition, scope: :proxy, url: deck_zone_proxies_path(@deck, @zone.zone), method: :post, class: "c-form" do |form| %>
    <%= hidden_field_tag "proxy[entry]", @addition.entry.external_key, id: nil %>
    <% if @finishes.any? %>
      <div class="c-field<%= " c-field--invalid" if finish_errors.any? %>">
        <%= form.label :finish, "Finish", class: "c-field__label" %>
        <%= form.select :finish, options_for_select(@finishes, @addition.finish.presence || (@finishes.first.last if @finishes.one?)),
              (@finishes.one? ? {} : { include_blank: "Choose…" }), { required: true, "aria-describedby": field_error_describedby("proxy_finish-error", finish_errors) } %>
        <%= render "shared/field_errors", messages: finish_errors, id: "proxy_finish-error" %>
      </div>
    <% end %>
    <div class="c-field<%= " c-field--invalid" if quantity_errors.any? %>">
      <%= form.label :quantity, "Quantity", class: "c-field__label" %>
      <label class="c-input"><%= form.number_field :quantity, min: 1, max: Deck::Proxy::MAX_QUANTITY, step: 1, inputmode: "numeric", required: true, "aria-describedby": field_error_describedby("proxy_quantity-error", quantity_errors) %></label>
      <%= render "shared/field_errors", messages: quantity_errors, id: "proxy_quantity-error" %>
    </div>
    <%= render "shared/field_errors", messages: @addition.errors[:base], id: "proxy_base-error" %>
    <div class="c-form__actions">
      <%= form.submit "Add proxy", class: "c-btn c-btn--primary" %>
      <%= link_to "Cancel", deck_path(@deck), class: "c-btn c-btn--secondary" %>
    </div>
  <% end %>
</main>
<%= render "layouts/tabbar", section: :decks %>
```

`Deck::Proxy::Addition` is an `ActiveModel::Model` with `form_with model:`: `model_name` → `Deck::Proxy::Addition`; scope given explicitly. `form.select :finish` needs `@addition.finish` ✓.

- [ ] **Step 6: Run** `bin/rspec spec/requests/deck_proxies_spec.rb spec/requests/deck_pages_spec.rb`: pass (T6's link example now resolves). Fix by reading failures; if `url_for` in the pager loses the path params, pass them explicitly (`link_params: { deck_id: @deck.location_id, zone: @zone.zone, q:, set: }`).
- [ ] **Step 7: Commit** `feat(decks): add a proxy to a zone (spec 068 T8)`.

### T9: The add flow without scripting, at every width

- [ ] **Step 1: The failing system spec** `spec/system/deck_proxies_spec.rb` (read `spec/system/deck_page_spec.rb` for the login and viewport helpers, `spec/support/narrow_frame.rb` for the phone frame, and `spec/support/system.rb`):

```ruby
require "rails_helper"

# Spec 068 Story 1 and Story 9: the add flow from the zone's header to the table, and every proxy page at 360px, 640px and 1280px
# in both themes (AC-9.1). Phone widths use the narrow frame (a window can't go below 500px), as spec 066's system spec does.
RSpec.describe "Adding a proxy", type: :system do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }
  let!(:entry) do
    create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", set: create(:catalog_set, code: "mh2"), number: "138"), finishes: %w[foil nonfoil]).entry
  end
  let!(:long) { create(:mtg_printing, entry: create(:catalog_entry, name: "W" * 60), finishes: %w[foil nonfoil]).entry } # a 60-character name with no space

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  before do
    page.driver.browser.manage.window.resize_to(1280, 900)
    system_sign_in_as(user)
  end

  it "adds a proxy through the chooser and the form and shows it in the zone (AC-1.5)", :aggregate_failures do
    visit deck_path(deck)
    within(first("section.c-zone")) { click_link "Add a proxy to Main" }
    fill_in "Card name", with: "Lightning"
    click_button "Search"
    click_link "Choose Lightning Bolt MH2 · 138"
    select "Foil", from: "Finish"
    fill_in "Quantity", with: "3"
    click_button "Add proxy"

    expect(page).to have_content("Added 3 proxies of Lightning Bolt (MH2 · 138, Foil) to Izzet Tempo › Main.")
    expect(first("section.c-zone")).to have_css(".c-proxy", text: "Proxy 3")
    expect(page).to have_css(".c-item__type", text: "3 cards · 0 owned · 3 proxy")
  end

  %w[light dark].each do |theme|
    [ 360, 640, 1280 ].each do |width|
      it "fits the chooser, the form, the change page and the removal page at #{width}px in the #{theme} theme (AC-9.1)", :aggregate_failures do
        proxy = create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry: long, finish: "foil", quantity: 2)
        paths = [ new_deck_zone_proxy_path(deck, "main", q: "WWWW"), new_deck_zone_proxy_path(deck, "main", entry: long.external_key),
                  edit_deck_proxy_path(deck, proxy), new_deck_proxy_removal_path(deck, proxy) ]

        paths.first(2).each do |path| # T10 changes this to `paths`: the change and removal pages don't exist until then
          visit deck_path(deck) # the outer page hosts the frame
          open_in_narrow_frame(path, width:, ready: "main")
          within_narrow_frame do
            set_theme(theme)
            expect(fits?).to be(true), "#{path} at #{width}px in #{theme}"
          end
        end
      end
    end
  end
end
```

- [ ] **Step 2: Run, confirm it fails or passes honestly** (`bin/rspec spec/system/deck_proxies_spec.rb`): the flow example passes after T8 if the pages are right; a failure is a bug in T8's views, fix it there. If the pager or the select fails, fix the view.
- [ ] **Step 3: Commit** `test(decks): the add-a-proxy flow without scripting, at every width (spec 068 T9)`.

---

## Phase 3: Change and remove a proxy, and removing a deck

**Implements:** FR-1, Stories 3 and 5 | **Satisfies:** AC-3.1 to AC-3.7, AC-5.4, AC-5.5, AC-4.4
**Files:** `app/controllers/decks/proxies_controller.rb` (done in T8), `app/controllers/decks/proxies/removals_controller.rb`, `app/views/decks/proxies/edit.html.erb`, `app/views/decks/proxies/removals/new.html.erb`, `app/views/decks/removals/new.html.erb`, `app/controllers/decks/removals_controller.rb`, `app/helpers/decks_helper.rb`, `spec/requests/deck_proxies_spec.rb`, `spec/requests/decks_spec.rb`
**Interfaces:** Consumes the T8 controller's `edit`, `update` and `destroy`. Produces the two pages and `deck_removal_sentence(proxies)`.

### T10: The change page, the removal page and the removal

- [ ] **Step 1: The failing specs**, appended to `spec/requests/deck_proxies_spec.rb` inside `context "when signed in"`:

```ruby
    describe "changing a proxy (Story 3)" do
      let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry: printing, finish: "foil", quantity: 2) }
      let(:name) { "Lightning Bolt (#{proxy.entry.set.code.upcase} · #{proxy.entry.number}, Foil)" }

      it "shows the proxy named with its deck, zone and finish, the count, Save and Cancel (AC-3.1)", :aggregate_failures do
        get edit_deck_proxy_path(deck, proxy)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("header.c-appbar--detail")).to be_present
        expect(html.at_css("h1").text).to include("Lightning Bolt")
        expect(html.text).to include("Izzet Tempo › Main")
        expect(html.text).to include("Foil")
        expect(html.at_css("input[name='proxy[quantity]']")["value"]).to eq("2")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Save")
        expect(html.css("a").find { it.text.squish == "Cancel" }["href"]).to eq(deck_path(deck))
      end

      it "saves a quantity from 1 to 9,999 keeping the id, and says so (AC-3.2)", :aggregate_failures do
        patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "4" } }

        expect(response).to redirect_to(deck_path(deck))
        expect(flash[:notice]).to eq("Changed the proxies of #{name} in Izzet Tempo › Main to 4.")
        expect(proxy.reload.quantity).to eq(4)
      end

      it "writes nothing for the same quantity (AC-3.2)", :aggregate_failures do
        expect(write_statements_to("deck_proxies") { patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "2" } } }).to be_empty
        expect(response).to redirect_to(deck_path(deck))
      end

      it "refuses 0, a negative number, over 9,999, text and nothing, keeping what was typed (AC-3.3)", :aggregate_failures do
        [ "0", "-1", "10000", "x", "" ].each do |text|
          patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: text } }

          expect(response).to have_http_status(:unprocessable_content), text.inspect
          expect(html.at_css(".c-field__error").text).to start_with("Enter a number from 1 to 9,999.")
          expect(html.at_css("input[name='proxy[quantity]']")["value"]).to eq(text)
        end
        expect(html.at_css(".c-field__error").text).not_to include("Remove proxy")
        patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "0" } }
        expect(html.at_css(".c-field__error").text).to eq("Enter a number from 1 to 9,999. To remove it, use Remove proxy.")
        expect(proxy.reload.quantity).to eq(2)
      end

      it "touches no lot, location, deck or other proxy (AC-3.7)", :aggregate_failures do
        other = create(:deck_proxy, zone: deck.zone("main"), account:, entry: printing(name: "Spell Pierce"))
        lot = create_lot_in_zone(deck, "main")
        before = [ Lot.pluck(:updated_at), Location.pluck(:updated_at), Deck.pluck(:updated_at), other.reload.updated_at ]

        patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "7" } }

        expect([ Lot.pluck(:updated_at), Location.pluck(:updated_at), Deck.pluck(:updated_at), other.reload.updated_at ]).to eq(before)
        expect(lot.reload.quantity).to eq(1)
      end
    end

    describe "removing a proxy (Story 3)" do
      let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry: printing, finish: "foil", quantity: 2) }
      let!(:other_finish) { create(:deck_proxy, zone: deck.zone("main"), account:, entry: proxy.entry, finish: "nonfoil", quantity: 1) }
      let(:name) { "Lightning Bolt (#{proxy.entry.set.code.upcase} · #{proxy.entry.number}, Foil)" }

      it "asks first on a page that removes nothing by itself (AC-3.4)", :aggregate_failures do
        get new_deck_proxy_removal_path(deck, proxy)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("Remove the proxies of #{name} from Izzet Tempo › Main?")
        expect(html.at_css("form[action='#{deck_proxy_path(deck, proxy)}'] input[name=_method][value=delete]")).to be_present
        expect(html.css("a").find { it.text.squish == "Cancel" }["href"]).to eq(deck_path(deck))
        expect(Deck::Proxy.count).to eq(2)
      end

      it "removes that proxy only, and says so (AC-3.4)", :aggregate_failures do
        delete deck_proxy_path(deck, proxy)

        expect(response).to redirect_to(deck_path(deck))
        expect(flash[:notice]).to eq("Removed the proxies of #{name} from Izzet Tempo › Main.")
        expect(Deck::Proxy.pluck(:id)).to eq([ other_finish.id ])
      end

      it "answers 404 for a proxy removed meanwhile and for a second delete (AC-3.5)", :aggregate_failures do
        proxy.destroy!

        get edit_deck_proxy_path(deck, proxy)
        expect(response).to have_http_status(:not_found)
        delete deck_proxy_path(deck, proxy)
        expect(response).to have_http_status(:not_found)
        patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "3" } }
        expect(response).to have_http_status(:not_found)
      end

      it "answers 404 for every proxy page of a deck removed meanwhile (AC-5.5)", :aggregate_failures do
        removed = create(:deck_proxy, zone: deck.zone("sideboard"), account:)
        id = deck.location_id
        deck.remove!

        [ new_deck_zone_proxy_path(id, "main"), edit_deck_proxy_path(id, removed.id), new_deck_proxy_removal_path(id, removed.id) ].each do |path|
          get path
          expect(response).to have_http_status(:not_found), path
        end
        delete deck_proxy_path(id, removed.id)
        expect(response).to have_http_status(:not_found)
      end

      it "answers 404 for another account's proxy, another deck's proxy under this deck, a place's or a zone's id as the deck, and a malformed id (AC-3.6)", :aggregate_failures do
        theirs = create(:deck_proxy)
        elsewhere = create(:deck, account:, name: "Elsewhere")
        elsewhere_proxy = create(:deck_proxy, zone: elsewhere.zone("main"), account:)
        place = create(:location, account:)
        paths = [ [ :get, edit_deck_proxy_path(deck, theirs) ], [ :get, edit_deck_proxy_path(deck, elsewhere_proxy) ],
                  [ :get, new_deck_proxy_removal_path(deck, elsewhere_proxy) ], [ :delete, deck_proxy_path(deck, elsewhere_proxy) ],
                  [ :patch, deck_proxy_path(deck, theirs) ], [ :get, edit_deck_proxy_path(place.id, proxy) ],
                  [ :get, edit_deck_proxy_path(deck.zone("main").id, proxy) ], [ :get, "/decks/#{deck.location_id}/proxies/12abc/edit" ] ]
        paths.each do |verb, path|
          public_send(verb, path)
          expect(response).to have_http_status(:not_found), "#{verb} #{path}"
        end
        expect(Deck::Proxy.count).to eq(4)
      end
    end
```

- [ ] **Step 2: Run, confirm it fails** (the `edit` and removal views are missing; `update` and `destroy` exist from T8).
- [ ] **Step 3: The removal controller** `app/controllers/decks/proxies/removals_controller.rb`:

```ruby
# The no-script confirmation page for removing a proxy (spec 068 decision 6, AC-3.4), the lot's and the deck's removal pages'
# sibling. It removes nothing; `Decks::ProxiesController#destroy` does. The lookup is the proxy controller's (FindsDeck), so
# another account's proxy, another deck's proxy and a place's or a zone's id as the deck are all 404 (AC-3.6).
# @see file:collection-and-lots.md
class Decks::Proxies::RemovalsController < ApplicationController
  include FindsDeck

  before_action :set_deck
  before_action -> { set_proxy(:proxy_id) }, only: :new

  # Renders the question.
  def new
  end
end
```

(The nested `resource :removal` route calls the proxy's id `:proxy_id`, so the callback passes it; the concern's default `:id` serves the proxies controller.)

- [ ] **Step 4: The views.** `app/views/decks/proxies/edit.html.erb`:

```erb
<% content_for :title, "Change proxy count · Collector" %>
<%= render "layouts/appbar", section: :decks, detail: true, back_path: deck_path(@deck) %>
<main class="c-main c-page c-decks">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Change the proxies of <%= proxy_name(@proxy) %></h1>
      <p class="c-pagehead__stats">in <%= proxy_zone_label(@deck, @proxy.zone) %> · <%= number_with_delimiter(@proxy.quantity) %> now</p>
    </div>
  </div>
  <% quantity_errors = @quantity_error ? [ @quantity_error ] : [] %>
  <%= form_with scope: :proxy, url: deck_proxy_path(@deck, @proxy), method: :patch, class: "c-form" do |form| %>
    <div class="c-field<%= " c-field--invalid" if quantity_errors.any? %>">
      <%= form.label :quantity, "Quantity", class: "c-field__label" %>
      <label class="c-input"><%= form.number_field :quantity, value: @typed || @proxy.quantity, min: 1, max: Deck::Proxy::MAX_QUANTITY, step: 1, inputmode: "numeric", required: true, "aria-describedby": field_error_describedby("proxy_quantity-error", quantity_errors) %></label>
      <%= render "shared/field_errors", messages: quantity_errors, id: "proxy_quantity-error" %>
    </div>
    <div class="c-form__actions">
      <%= form.submit "Save", class: "c-btn c-btn--primary" %>
      <%= link_to "Cancel", deck_path(@deck), class: "c-btn c-btn--secondary" %>
    </div>
  <% end %>
</main>
<%= render "layouts/tabbar", section: :decks %>
```

`app/views/decks/proxies/removals/new.html.erb`:

```erb
<% content_for :title, "Remove proxy · Collector" %>
<%= render "layouts/appbar", section: :decks, detail: true, back_path: deck_path(@deck) %>
<main class="c-main c-page c-decks">
  <section class="c-confirm">
    <h1 class="c-pagehead__title">Remove the proxies of <%= proxy_name(@proxy) %> from <%= proxy_zone_label(@deck, @proxy.zone) %>?</h1>
    <p>This removes <%= pluralize(number_with_delimiter(@proxy.quantity), "proxy", "proxies") %> from this zone. No copy in your collection is removed or changed.</p>
    <div class="c-form__actions">
      <%= button_to "Remove", deck_proxy_path(@deck, @proxy), method: :delete, class: "c-btn c-btn--danger" %>
      <%= link_to "Cancel", deck_path(@deck), class: "c-btn c-btn--secondary" %>
    </div>
  </section>
</main>
<%= render "layouts/tabbar", section: :decks %>
```

- [ ] **Step 5: Run** `bin/rspec spec/requests/deck_proxies_spec.rb`: pass. A failing "same quantity writes nothing" example means `change_quantity!`'s `save! if changed?` is not reached: check `quantity = 2` against a stored 2 isn't dirty.
- [ ] **Step 6: The system spec's other two pages**: in `spec/system/deck_proxies_spec.rb` change `paths.first(2)` to `paths` (T9) and run it. **Step 7: Commit** `feat(decks): change and remove a proxy (spec 068 T10)`.

### T11: Removing a deck names its proxies

- [ ] **Step 1: The failing spec**, in `spec/requests/decks_spec.rb`:

```ruby
    describe "removing a deck with proxies (spec 068 Story 5)" do
      let(:deck) { create(:deck, account:, name: "Wishlist") }

      it "asks first and says the proxies go with the deck (AC-5.4)", :aggregate_failures do
        create(:deck_proxy, zone: deck.zone("main"), account:, quantity: 8)
        create(:deck_proxy, zone: deck.zone("sideboard"), account:, quantity: 3)

        get new_deck_removal_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css(".c-confirm p").text).to eq("This removes the deck, and its zones and its 11 proxies are removed with it. No copy in your collection is removed or changed.")
        expect(html.at_css("form[action='#{deck_path(deck)}']")).to be_present
      end

      it "keeps the old sentence for a deck with no proxy" do
        get new_deck_removal_path(deck)

        expect(html.at_css(".c-confirm p").text).to eq("This removes the deck, and its zones are removed with it. No copy in your collection is removed or changed.")
      end

      it "removes a deck that holds only proxies, with its zones and its proxies, and nothing else (AC-5.4, AC-4.4)", :aggregate_failures do
        create(:deck_proxy, zone: deck.zone("main"), account:, quantity: 8)
        other = create(:deck, account:, name: "Other")
        keep = create(:deck_proxy, zone: other.zone("main"), account:)
        lot = create_lot_in_zone(other, "main")

        delete deck_path(deck)

        expect(response).to redirect_to(decks_path)
        expect(Deck::Proxy.pluck(:id)).to eq([ keep.id ])
        expect(Deck.pluck(:location_id)).to eq([ other.location_id ])
        expect(lot.reload.quantity).to eq(1)
      end

      it "is still refused while a zone holds a lot, whatever its proxies (AC-4.4)", :aggregate_failures do
        create(:deck_proxy, zone: deck.zone("main"), account:)
        create_lot_in_zone(deck, "sideboard")

        get new_deck_removal_path(deck)
        expect(html.at_css("h1").text).to include("isn't empty")

        delete deck_path(deck)
        expect(response).to have_http_status(:conflict)
        expect(Deck::Proxy.count).to eq(1)
      end
    end
```

- [ ] **Step 2: Run, confirm the first example fails** (the sentence). **Step 3:** in `app/controllers/decks/removals_controller.rb` `new`: after the refusal check add `@proxies = @deck.proxies.sum(:quantity)`; the controller becomes:

```ruby
  def new
    @deck = Current.account.decks.includes(:location).find_by!(location_id: params[:deck_id])
    @holdings = @deck.holdings
    return render :refused if @holdings.any?

    @proxies = @deck.proxies.sum(:quantity)
  end
```

In `app/helpers/decks_helper.rb` add:

```ruby
  # The confirmation's first sentence (spec 068 AC-5.4): the zones go with the deck, and so do its proxies when it has any.
  #
  # @param proxies [Integer] the quantities of proxies in the deck
  # @return [String]
  def deck_removal_sentence(proxies)
    what = proxies.positive? ? "its zones and its #{pluralize(number_with_delimiter(proxies), "proxy", "proxies")} are" : "its zones are"
    "This removes the deck, and #{what} removed with it. No copy in your collection is removed or changed."
  end
```

and in `app/views/decks/removals/new.html.erb` replace the `<p>` with `<p><%= deck_removal_sentence(@proxies) %></p>`.

`DecksController#destroy` already works for a deck with only proxies (its foreign keys cascade the zones and their proxies): the spec's third example proves it with no code change.

- [ ] **Step 4: Run** `bin/rspec spec/requests/decks_spec.rb`: pass. **Step 5: Commit** `feat(decks): a deck's removal names and removes its proxies (spec 068 T11)`.

---

## Phase 4: A change of format moves proxies into Considering

**Implements:** FR-3, Story 6 | **Satisfies:** AC-6.1 to AC-6.8
**Files:** `app/models/deck/proxy/cap_exceeded.rb`, `app/models/deck/format_change.rb`, `app/controllers/decks/formats_controller.rb`, `app/helpers/decks_helper.rb`, `spec/models/deck/format_change_spec.rb`, `spec/requests/deck_formats_spec.rb`
**Interfaces:** Consumes `Deck::Proxy`. Produces `Deck::Proxy::CapExceeded` (`#proxy`), `Deck::FormatChange#proxies_moved`, `format_changed_message` with the proxy sentence, `over_proxy_cap_message(prefix, proxy)`.

### T12: The move

- [ ] **Step 1: The failing spec**, appended to `spec/models/deck/format_change_spec.rb` (read the file's top for `change_to`, `zone_keys`, `written`; the fake vocabulary helper there drops two zones; the shipped Commander to Modern drops one):

```ruby
  describe "proxies (spec 068 Story 6)" do
    let(:deck) { create(:deck, account:, name: "Elves", format: "commander") }
    let(:entry) { create(:mtg_printing).entry }

    def proxy_in(zone, entry: self.entry, finish: "foil", quantity: 1) = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, finish:, quantity:)

    it "moves the proxies of a dropped zone into Considering and leaves the others where they were (AC-6.1)", :aggregate_failures do
      commander = proxy_in("commander", quantity: 2)
      main = proxy_in("main", entry: create(:mtg_printing).entry)
      kept = proxy_in("considering", entry: create(:mtg_printing).entry)
      change = change_to(deck, "modern")

      change.save!

      considering = deck.reload.zone("considering")
      expect(commander.reload.zone).to eq(considering)
      expect([ main.reload.zone, kept.reload.zone ]).to eq([ deck.zone("main"), considering ])
      expect(deck.zones.pluck(:zone)).not_to include("commander")
      expect(change.proxies_moved).to eq(2)
      expect(Deck::Proxy.count).to eq(3)
    end

    it "merges a moved proxy into the proxy of its printing and finish already in Considering, which survives (AC-6.2)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 2)
      there = proxy_in("considering", quantity: 3)

      change_to(deck, "modern").save!

      expect(Deck::Proxy.pluck(:id, :quantity)).to eq([ [ there.id, 5 ] ])
      expect { moved.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "keeps a moved proxy's own row (same id) when Considering has none of that printing and finish (AC-6.2)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 2)
      proxy_in("considering", finish: "nonfoil", quantity: 3) # another finish of the same printing: not a merge

      change_to(deck, "modern").save!

      expect(moved.reload.zone).to eq(deck.zone("considering"))
      expect(Deck::Proxy.count).to eq(2)
    end

    it "makes one proxy of those of one printing and finish from several dropped zones (AC-6.2)", :aggregate_failures do
      fake_vocabulary # the helper's vocabulary also answers `finishes_for` and `finish_label` (see the edit below)
      other = create(:deck, account:, name: "Fake deck", pair: "fake/f")
      entry = create(:catalog_entry, collectible_type: "fake")
      a = create(:deck_proxy, zone: other.zone("a"), account:, entry:, finish: nil, quantity: 2)
      b = create(:deck_proxy, zone: other.zone("b"), account:, entry:, finish: nil, quantity: 3)

      change = described_class.new(deck: other, format: "fake/g")
      change.save!

      expect(Deck::Proxy.where(location_id: other.zone("considering").id).pluck(:id, :quantity)).to eq([ [ a.id, 5 ] ])
      expect { b.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(change.proxies_moved).to eq(5)
    end

    it "refuses a move past 9,999 naming the proxy, and writes nothing (AC-6.4)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 5_000)
      proxy_in("considering", quantity: 5_000)

      expect { change_to(deck, "modern").save }.to raise_error(Deck::Proxy::CapExceeded) { |error| expect(error.proxy.id).to eq(moved.id) }

      expect(deck.reload.format).to eq("commander")
      expect(moved.reload.zone).to eq(deck.zone("commander"))
      expect(Deck::Proxy.pluck(:quantity).sort).to eq([ 5_000, 5_000 ])
    end

    it "shows the lots' refusal first when both would pass the cap (AC-6.5)" do
      lot_entry = create(:mtg_printing).entry
      Lot.add!(account:, entry: lot_entry, location: deck.zone("commander"), quantity: 9_000, finish: "foil")
      Lot.add!(account:, entry: lot_entry, location: deck.zone("considering"), quantity: 9_000, finish: "foil")
      proxy_in("commander", quantity: 9_000)
      proxy_in("considering", quantity: 9_000)

      expect { change_to(deck, "modern").save }.to raise_error(Lot::CapExceeded)
    end

    it "adds no sentence about proxies when none moved, and counts none for a same-zones change (AC-6.6)", :aggregate_failures do
      proxy_in("main")

      change = change_to(create(:deck, account:, name: "Plain", format: "modern"), "pauper")
      change.save!

      expect(change.proxies_moved).to eq(0)
      expect(Deck::Proxy.count).to eq(1)
    end

    it "rolls the proxies back with the deck when the change fails part way (AC-6.7)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 4)
      allow(Location).to receive(:insert_all!).and_raise(ActiveRecord::StatementInvalid, "disk full") # the step after the move adds Modern's Sideboard, as spec 064 AC-2.8's example fails it

      expect { change_to(deck, "modern").save }.to raise_error(ActiveRecord::StatementInvalid)

      expect(moved.reload.zone).to eq(deck.zone("commander"))
      expect(deck.reload.format).to eq("commander")
    end

    it "moves the proxies into the Considering the change makes for a deck that has none (AC-6.8)", :aggregate_failures do
      moved = proxy_in("commander", quantity: 2)
      deck.zone("considering").delete # a deck with no Considering row (spec 064 AC-2.10's case): no lot is in it

      change_to(deck.reload, "modern").save!

      expect(moved.reload.zone).to eq(deck.zone("considering"))
    end
  end
```

- [ ] **Step 2: The spec's fake vocabulary.** In `fake_vocabulary` (the file's helper, which registers the type "fake"), add `define_singleton_method(:finishes_for) { |_entry| [] }` and `define_singleton_method(:finish_label) { |finish| finish.to_s }` beside its `finish_order` and `conditions`: a proxy's creation reads the vocabulary's finishes, and the example's printing lists none.
- [ ] **Step 2b: Run, confirm it fails** (`uninitialized constant Deck::Proxy::CapExceeded` / no `proxies_moved`).
- [ ] **Step 3: The error** `app/models/deck/proxy/cap_exceeded.rb`:

```ruby
# A move that would put more than 9,999 proxies of one printing and finish in one zone (spec 068 decision 10). It names the
# first such proxy by card name, set code, collector number, language and finish, as the format change's refusal says.
class Deck::Proxy::CapExceeded < StandardError
  attr_reader :proxy

  # @param proxy [Deck::Proxy] the proxy that would overflow, with its entry and set loaded
  def initialize(proxy)
    @proxy = proxy
    super("#{proxy.entry.name} would have more than #{Deck::Proxy::MAX_QUANTITY} proxies in one zone")
  end
end
```

- [ ] **Step 4: The move.** In `app/models/deck/format_change.rb`: add the reader `attr_reader :proxies_moved`, reset it in `save` (`@proxies_moved = 0`, also in the rescue), rescue `Deck::Proxy::CapExceeded` beside `Lot::CapExceeded`, and call the new step after the lots:

```ruby
  # The proxies {#save} moved into Considering, by quantity (spec 068 decision 10).
  # @return [Integer]
  attr_reader :proxies_moved
```

```ruby
  def save
    errors.clear
    @moved = 0
    @proxies_moved = 0
    @changed = false
    option = Catalog::Formats.find_pair(format)
    unless option
      errors.add(:format, Deck::Creation::CHOOSE_A_FORMAT)
      return false
    end

    Deck.transaction { apply(option) }
    true
  rescue Lot::CapExceeded, Deck::Proxy::CapExceeded
    @changed = false # the transaction rolled back: the deck is as it was
    @moved = 0
    @proxies_moved = 0
    deck.reload
    raise
  end
```

(Update the `@raise` doc: "or `Deck::Proxy::CapExceeded` when a merge of proxies would pass 9,999".) In `apply`, after `move_lots!(dropped, considering)` add `move_proxies!(dropped, considering)`, and add:

```ruby
    # The proxies of the dropped zones go into Considering (spec 068 decision 10), after the lots so that the lots' cap refusal
    # is the one shown when both would pass it (AC-6.5). A proxy that meets the printing and finish of one already there joins
    # it (the one there survives); proxies of one printing and finish from several dropped zones become one (the first by id
    # survives); any other keeps its own row. The cap is judged for every merge before anything is written, so a refusal
    # writes nothing, and the transaction rolls back whatever else is. Writes go through the model (`update!`, `destroy!`):
    # a deck has few proxies, and the rows are small.
    def move_proxies!(dropped, considering)
      proxies = deck.account.deck_proxies.where(location_id: dropped.map(&:id)).includes(entry: :set).order(:id).to_a
      return if proxies.empty?

      there = deck.account.deck_proxies.where(location_id: considering.id).index_by { |proxy| [ proxy.catalog_entry_id, proxy.finish ] }
      groups = proxies.group_by { |proxy| [ proxy.catalog_entry_id, proxy.finish ] }
      over = groups.filter_map { |key, group| group.first if group.sum(&:quantity) + (there[key]&.quantity || 0) > Deck::Proxy::MAX_QUANTITY }
      raise Deck::Proxy::CapExceeded, first_by_shown_order(over) if over.any?

      moved = proxies.sum(&:quantity) # before the writes: a keeper's quantity changes in memory when its siblings merge into it
      groups.each do |key, group|
        total = group.sum(&:quantity)
        if there[key]
          there[key].update!(quantity: there[key].quantity + total)
          group.each(&:destroy!)
        else
          keeper, *rest = group
          keeper.update!(zone: considering, quantity: total)
          rest.each(&:destroy!)
        end
      end
      @proxies_moved = moved
    end

    # The proxy that comes first by card name, set code, collector number as a person reads it, language, then finish.
    def first_by_shown_order(proxies)
      proxies.min_by do |proxy|
        entry = proxy.entry
        number = entry.number.to_s
        [ entry.display_name, entry.set.code, number.match?(/\A\d/) ? 0 : 1, number.to_i, number, entry.language, proxy.finish.to_s ]
      end
    end
```

`raise Deck::Proxy::CapExceeded, proxy` passes the proxy as the exception's single `new` argument ✓ (`raise Klass, arg` calls `Klass.new(arg)`... `raise Class, message` calls `exception(message)` → `Class.new(message)` ✓).

Note: `update!(zone: considering)` runs the model's `zone_is_a_zone_of_the_account` (considering belongs to the account ✓) and does not re-run the creation-time rules.

Name-sort caveat: `entry.display_name` is a method (the localized name for a non-English printing); the set is loaded by `includes(entry: :set)`.

- [ ] **Step 5: Run** `bin/rspec spec/models/deck/format_change_spec.rb`: all pass, the spec 064 examples included. **Step 6: Commit** `feat(decks): a format change moves proxies into Considering (spec 068 T12)`.

### T13: The notice and the refusal on the Format page

- [ ] **Step 1: The failing spec**, appended to `spec/requests/deck_formats_spec.rb` (read it: it signs in, makes a Commander deck, and patches `deck_format_path`):

```ruby
    describe "proxies (spec 068 AC-6.3, AC-6.4)" do
      let(:deck) { create(:deck, account:, name: "Elves", format: "commander") }
      let(:entry) { create(:mtg_printing).entry }

      it "says how many proxies moved, after the cards sentence (AC-6.3)", :aggregate_failures do
        Lot.add!(account:, entry: create(:mtg_printing).entry, location: deck.zone("commander"), quantity: 12, finish: "foil")
        create(:deck_proxy, zone: deck.zone("commander"), account:, entry:, quantity: 3)

        patch deck_format_path(deck), params: { deck: { format: "mtg/modern" } }

        expect(response).to redirect_to(decks_path)
        expect(flash[:notice]).to eq("Changed “Elves” to Modern. 12 cards moved to Considering. 3 proxies moved to Considering.")
      end

      it "says '1 proxy', and omits the cards sentence when only proxies moved (AC-6.3)", :aggregate_failures do
        create(:deck_proxy, zone: deck.zone("commander"), account:, entry:, quantity: 1)

        patch deck_format_path(deck), params: { deck: { format: "mtg/modern" } }

        expect(flash[:notice]).to eq("Changed “Elves” to Modern. 1 proxy moved to Considering.")
      end

      it "adds nothing about proxies when none moved (AC-6.6)" do
        patch deck_format_path(deck), params: { deck: { format: "mtg/modern" } }

        expect(flash[:notice]).to eq("Changed “Elves” to Modern.")
      end

      it "refuses a cap breach with the alert naming the proxy, 422, nothing changed (AC-6.4)", :aggregate_failures do
        create(:deck_proxy, zone: deck.zone("commander"), account:, entry:, finish: "foil", quantity: 5_000)
        create(:deck_proxy, zone: deck.zone("considering"), account:, entry:, finish: "foil", quantity: 5_000)

        patch deck_format_path(deck), params: { deck: { format: "mtg/modern" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css(".c-status__message--alert, [role=alert]").text).to include("Nothing changed. #{entry.name} (#{entry.set.code.upcase} · #{entry.number}) would have more than 9,999 proxies in one zone.")
        expect(deck.reload.format).to eq("commander")
      end
    end
```

(Use the file's own `html` helper and the selector its existing cap-refusal example uses for the alert.)

- [ ] **Step 2: Run, confirm it fails.** **Step 3:** in `app/helpers/decks_helper.rb` replace `format_changed_message`'s last line and add the proxy message:

```ruby
  def format_changed_message(deck, change)
    return "“#{deck.name}” is already #{deck.format_name}." unless change.changed?

    parts = [ "Changed “#{deck.name}” to #{deck.format_name}." ]
    parts << "#{pluralize(number_with_delimiter(change.moved), "card")} moved to #{change.considering_name}." if change.moved.positive?
    parts << "#{number_with_delimiter(change.proxies_moved)} #{change.proxies_moved == 1 ? "proxy" : "proxies"} moved to #{change.considering_name}." if change.proxies_moved.positive?
    parts.join(" ")
  end

  # The alert of a format change a proxy merge would break (spec 068 AC-6.4): "Nothing changed. Lightning Bolt (MH2 · 138) would
  # have more than 9,999 proxies in one zone."
  #
  # @param prefix [String]
  # @param proxy [Deck::Proxy] with its entry and set loaded
  # @return [String]
  def over_proxy_cap_message(prefix, proxy)
    "#{prefix} #{proxy.entry.name} (#{set_number(proxy.entry)}) would have more than #{number_with_delimiter(Deck::Proxy::MAX_QUANTITY)} proxies in one zone."
  end
```

`considering_name` is set only `if @moved.positive?` in `FormatChange#apply`: change that line to `if @moved.positive? || @proxies_moved.positive?` so a proxy-only move names the zone (Edit `deck/format_change.rb`: `@considering_name = ... if @moved.positive? || @proxies_moved.positive?`) and update its attr comment ("set when copies or proxies moved").

In `Decks::FormatsController#update` add a second rescue:

```ruby
  rescue Deck::Proxy::CapExceeded => error
    flash.now[:alert] = helpers.over_proxy_cap_message("Nothing changed.", error.proxy)
    render :edit, status: :unprocessable_content
```

- [ ] **Step 4: Run** `bin/rspec spec/requests/deck_formats_spec.rb spec/models/deck/format_change_spec.rb`: pass. **Step 5: Commit** `feat(decks): the format change's notice and refusal cover proxies (spec 068 T13)`.

---

## Phase 5: The format and the export

**Implements:** FR-4 (format and export), Story 7 | **Satisfies:** AC-7.1, AC-7.2, AC-7.3, AC-7.14 (export side)
**Files:** `docs/export-format/README.md`, `docs/export-format/v4.schema.json`, `app/models/export_format/v4.schema.json`, `docs/export-format/examples/**`, `app/models/export_format/rules.rb`, `app/models/collection_export.rb`, `spec/export_format_examples_spec.rb`, `spec/export_format_document_spec.rb`, `spec/support/export_format_rules.rb`, `spec/models/collection_export_spec.rb`, `spec/collection_export_core_spec.rb`
**Interfaces:** Produces the schema's `$defs/proxy`, `ExportFormat::Rules::RULES` with `duplicate_proxy`, `ExportFormat::Rules.proxy_schemer`, `CollectionExport#to_h["proxies"]`.

### T14: The schema, the document and the examples

- [ ] **Step 1: The failing specs.** In `spec/export_format_examples_spec.rb`: change the `valid.keys` list to add `valid/proxies-v4.json`; `invalid.size` from 68 to 79; `comparison.size` from 22 to 23; the v4 different-example names to `%w[deck-format deck-name lot-zone proxy-added]`; and add, inside `describe "version 4 (spec 062)"`, after the `6.13` examples:

```ruby
    describe "proxies (spec 068)" do
      def v4_with(proxies) = JSON.parse(v4base).tap { |data| data["proxies"] = proxies }

      def proxy(**changes)
        base = JSON.parse(v4base)
        { "deck" => base["decks"][0]["name"], "zone" => "main", "entry" => base["lots"][0]["entry"], "finish" => "foil", "quantity" => 2 }.merge(changes.transform_keys(&:to_s))
      end

      it "finds each listed variant of a malformed proxy, one problem each", :aggregate_failures do
        {
          [ proxy.merge("quantity" => 0) ] => %w[minimum /proxies/0/quantity],
          [ proxy.merge("quantity" => 10_000) ] => %w[maximum /proxies/0/quantity],
          [ proxy.merge("quantity" => 2.5) ] => %w[type /proxies/0/quantity],
          [ proxy.merge("quantity" => "2") ] => %w[type /proxies/0/quantity],
          [ proxy.except("quantity") ] => %w[required /proxies/0/quantity],
          [ proxy.except("finish") ] => %w[required /proxies/0/finish],
          [ proxy.merge("finish" => " ") ] => %w[pattern /proxies/0/finish],
          [ proxy.except("deck") ] => %w[required /proxies/0/deck],
          [ proxy.merge("deck" => "Izzet  Tempo") ] => %w[pattern /proxies/0/deck],
          [ proxy.except("zone") ] => %w[required /proxies/0/zone],
          [ proxy.merge("zone" => "") ] => %w[pattern /proxies/0/zone],
          [ proxy.except("entry") ] => %w[required /proxies/0/entry],
          [ proxy.merge("slot" => 1) ] => %w[schema /proxies/0/slot],
          [ 5 ] => %w[type /proxies/0],
          [ proxy.merge("deck" => "Nope") ] => %w[unknown_location /proxies/0/deck],
          [ proxy, proxy ] => %w[duplicate_proxy /proxies/1],
          [ proxy, proxy.merge("deck" => "IZZET TEMPO") ] => %w[duplicate_proxy /proxies/1]
        }.each do |proxies, (rule, at)|
          expect(problems_of(JSON.generate(v4_with(proxies)))).to eq([ { "rule" => rule, "at" => at } ]), proxies.inspect
        end
      end

      it "finds a missing or malformed list at the list" do
        expect(problems_of(JSON.generate(JSON.parse(v4base).tap { it.delete("proxies") }))).to eq([ { "rule" => "required", "at" => "/proxies" } ])
        expect(problems_of(JSON.generate(v4_with({})))).to eq([ { "rule" => "type", "at" => "/proxies" } ])
      end

      it "accepts a proxy with no finish, two finishes of one printing and a deck in another case", :aggregate_failures do
        expect(problems_of(JSON.generate(v4_with([ proxy("finish" => nil) ])))).to be_empty
        expect(problems_of(JSON.generate(v4_with([ proxy("finish" => "foil"), proxy("finish" => "nonfoil") ])))).to be_empty
        expect(problems_of(JSON.generate(v4_with([ proxy("deck" => "IZZET TEMPO") ])))).to be_empty
      end

      it "carries proxies of two finishes, a null finish and two zones in the valid example", :aggregate_failures do
        file = JSON.parse(valid.fetch("valid/proxies-v4.json"))

        expect(file["proxies"].map { it["finish"] }).to include("foil", "nonfoil", nil)
        expect(file["proxies"].map { it["zone"] }.uniq.size).to be >= 2
        expect(problems_of(valid.fetch("valid/proxies-v4.json"))).to be_empty
      end

      it "holds the same collection for the same proxies in another order, and a different one for any change (spec 068 AC-7.3)", :aggregate_failures do
        original = v4_with([ proxy("finish" => "foil"), proxy("finish" => "nonfoil") ])
        reordered = v4_with(original["proxies"].reverse)

        expect(ExportFormatRules.same_collection?(original, reordered)).to be(true)
        [ proxy("finish" => "foil", "quantity" => 3), proxy("finish" => "etched"), proxy("zone" => "sideboard"), proxy("deck" => "izzet tempo") ].each do |changed|
          other = v4_with([ changed, proxy("finish" => "nonfoil") ])
          expect(ExportFormatRules.same_collection?(original, other)).to be(false), changed.inspect
        end
        expect(ExportFormatRules.same_collection?(original, v4_with([ proxy("finish" => "foil") ]))).to be(false)
        expect(ExportFormatRules.same_collection?(JSON.parse(v4base), JSON.parse(comparison.fetch("comparison/v4-different-proxy-added.json")))).to be(false)
      end
    end
```

In `v4changed` (the same describe), the line `data["lots"] = [] if path.first == "decks"` stays (the base's proxies are `[]`). In `spec/export_format_document_spec.rb` change the `Exported` expectation to include `"deck_proxies" => "Exported"` and add to the `left_out` column list `deck_proxies.id deck_proxies.account_id deck_proxies.created_at deck_proxies.updated_at`. In `spec/support/export_format_rules.rb`'s `compared`, add after the decks entry:

```ruby
      file["decks"]&.map { |deck| deck.values_at("name", "collectible_type", "format") }&.to_set,
      file["proxies"]&.map { |proxy| [ proxy["deck"], proxy["zone"], *proxy["entry"].values_at("collectible_type", "source_id"), proxy["finish"], proxy["quantity"] ] }&.to_set ]
```

and extend the comment above `same_collection?`: "from version 4 the proxies are compared as sets of deck name as written, zone key, entry identity, finish and quantity (spec 068)".

- [ ] **Step 2: Run both files, confirm they fail** (the missing example files, then the schema).
- [ ] **Step 3: The schema**, textual edits to `docs/export-format/v4.schema.json` (the file is not re-dumped: its layout is hand-written, and a JSON round trip changes it). With `python3 -I` in the scratchpad (a script, never inside the repo):

```python
import pathlib
p = pathlib.Path("docs/export-format/v4.schema.json")
s = p.read_text()
def once(old, new):
    global s
    assert s.count(old) == 1, old
    s = s.replace(old, new)

once('"locations", "decks", "lots"],', '"locations", "decks", "proxies", "lots"],')
once('    "decks": { "type": "array", "maxItems": 500, "items": { "$ref": "#/$defs/deck" } },\n',
     '    "decks": { "type": "array", "maxItems": 500, "items": { "$ref": "#/$defs/deck" } },\n'
     '    "proxies": { "type": "array", "items": { "$ref": "#/$defs/proxy" } },\n')
once('    "location_name": {',
     '    "proxy": {\n'
     '      "description": "A card a deck\'s zone needs and the collector doesn\'t own: the deck and one of its zones, the entry, a finish (null for a printing that lists none) and a quantity. The object has these fields and no others.",\n'
     '      "type": "object",\n'
     '      "required": ["deck", "zone", "entry", "finish", "quantity"],\n'
     '      "additionalProperties": false,\n'
     '      "properties": {\n'
     '        "deck": { "$ref": "#/$defs/location_name" },\n'
     '        "zone": { "$ref": "#/$defs/text" },\n'
     '        "entry": { "$ref": "#/$defs/entry" },\n'
     '        "finish": { "$ref": "#/$defs/recorded_text" },\n'
     '        "quantity": { "type": "integer", "minimum": 1, "maximum": 9999 }\n'
     '      }\n'
     '    },\n'
     '    "location_name": {')
p.write_text(s)
```

then read the schema's top-level `description` (line 5), which lists the rules a schema can't state, and add `duplicate_proxy` and "every proxy's deck is one of the file's decks" to it in its own style; then `cp docs/export-format/v4.schema.json app/models/export_format/v4.schema.json` (byte-identical; a spec keeps them equal).

- [ ] **Step 4: Add `"proxies": []` to every version 4 example, textually** (same scratchpad script style; the examples include invalid files whose bytes are the point, so no JSON round trip):

```python
import pathlib, re
root = pathlib.Path("docs/export-format/examples")
for path in sorted(root.glob("*/*.json")):
    text = path.read_bytes().decode("utf-8", errors="surrogateescape")
    if not re.search(r'"format_version":\s*4(\.0)?\s*,', text) or re.search(r'^  "proxies"', text, re.M):
        continue
    assert re.search(r'^  "lots"', text, re.M), path   # every version 4 example has its top-level lots key (invalid/lots-missing.json is version 1)
    text = re.sub(r'^(  "lots")', r'  "proxies": [],\n\1', text, count=1, flags=re.M)
    path.write_bytes(text.encode("utf-8", errors="surrogateescape"))
```

Run `git diff --stat docs/export-format/examples | tail -1` (29 files, one line each) and `git diff docs/export-format/examples/invalid/repeated-key.json docs/export-format/examples/invalid/byte-order-mark.json docs/export-format/examples/invalid/not-json.json docs/export-format/examples/invalid/not-utf8.json`: only the one inserted line (or none, for a file that isn't a version 4 file) must show.

- [ ] **Step 5: The new example files** (one scratchpad script, writing pretty files with `json.dumps(indent=2, ensure_ascii=False)`):

```python
import json, pathlib
root = pathlib.Path("docs/export-format/examples")
def load(name): return json.loads((root / name).read_text())
def write(name, data): (root / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")

base = load("comparison/v4-base.json")
deck = base["decks"][0]["name"]
entry = base["lots"][0]["entry"]
proxy = {"deck": deck, "zone": "main", "entry": entry, "finish": "foil", "quantity": 2}

# valid: proxies of two finishes, no finish, two zones
valid = json.loads(json.dumps(base))
valid["proxies"] = [dict(proxy), dict(proxy, finish="nonfoil", quantity=1), dict(proxy, zone="sideboard", finish=None, quantity=3)]
write("valid/proxies-v4.json", valid)

def invalid(name, proxies, why, rule, at):
    data = json.loads(json.dumps(base)); data["proxies"] = proxies; write("invalid/" + name, data)
    problems[("invalid/" + name)] = {"why": why, "rule": rule, "at": at}
def raw(name, mutate, why, rule, at):
    data = json.loads(json.dumps(base)); mutate(data); write("invalid/" + name, data)
    problems[("invalid/" + name)] = {"why": why, "rule": rule, "at": at}

problems = json.loads((root / "problems.json").read_text())
raw("proxies-missing.json", lambda d: d.pop("proxies"), "A version 4 file has no proxies. The list is always present, empty when the collector has none.", "required", "/proxies")
raw("proxies-not-a-list.json", lambda d: d.__setitem__("proxies", {}), "The proxies are one object, not a list.", "type", "/proxies")
invalid("proxy-not-an-object.json", [5], "A proxy is a number, not an object.", "type", "/proxies/0")
invalid("proxy-quantity-zero.json", [dict(proxy, quantity=0)], "A proxy's quantity is 0.", "minimum", "/proxies/0/quantity")
invalid("proxy-quantity-10000.json", [dict(proxy, quantity=10000)], "A proxy's quantity is over 9,999.", "maximum", "/proxies/0/quantity")
invalid("proxy-extra-key.json", [dict(proxy, slot=1)], "A proxy has a key besides deck, zone, entry, finish and quantity.", "schema", "/proxies/0/slot")
invalid("proxy-finish-blank.json", [dict(proxy, finish=" ")], "A proxy's finish is only whitespace; not recorded is written as null.", "pattern", "/proxies/0/finish")
invalid("proxy-entry-missing.json", [{k: v for k, v in proxy.items() if k != "entry"}], "A proxy has no entry.", "required", "/proxies/0/entry")
invalid("proxy-deck-unlisted.json", [dict(proxy, deck="Nope")], "A proxy names a deck that none of the file's decks has.", "unknown_location", "/proxies/0/deck")
invalid("proxy-duplicate.json", [proxy, dict(proxy)], "Two proxies have the same deck, zone, entry and finish.", "duplicate_proxy", "/proxies/1")
invalid("proxy-duplicate-deck-case.json", [proxy, dict(proxy, deck=deck.upper())], "Two proxies have the same zone, entry and finish in decks that differ only in case, so they are one deck and one proxy.", "duplicate_proxy", "/proxies/1")
(root / "problems.json").write_text(json.dumps(problems, indent=2, ensure_ascii=False) + "\n")

added = json.loads(json.dumps(base)); added["proxies"] = [proxy]
write("comparison/v4-different-proxy-added.json", added)
```

(Check `problems.json`'s own layout first: it is two-space `json.dumps`-compatible, as the printed head above shows; if `git diff docs/export-format/examples/problems.json` shows anything but the eleven added entries, restore the file and append the entries by hand.) The deck name in `v4-base.json` must be a name that `.upper()` changes; if it isn't, spell the example's deck by hand.

- [ ] **Step 6: The document** `docs/export-format/README.md`. Make these edits, each its own small change:
  1. "The file" table: a row after `decks`: ``| `proxies` | A list | From version 4: the cards the collector's decks need and they don't own. See [Proxies](#proxies). It may be empty, and its order has no meaning. A file of version 1 to 3 has no `proxies`. |``, and `"proxies": [],` between `"decks": [],` and `"lots": []` in the empty-collection sample.
  2. A new `## Proxies` section between `## Decks` and `## Lot identity`:

```markdown
## Proxies

A **proxy** is a card that a deck's zone needs and that the collector doesn't own. From version 4 a file carries the collector's proxies as the required top-level list `proxies`; a file of version 1 to 3 has none and says nothing about them. A proxy is never a lot: it isn't in `lots`, and no count of copies the collector owns includes it.

| Field | Value | Meaning |
|---|---|---|
| `deck` | A [name](#names) | The name of one of the file's decks, matched by [comparison key](#location-identity). |
| `zone` | A string that isn't blank | The key of one of the zones of that deck's format. A zone key is compared exactly, as written. |
| `entry` | An [entry](#entry) | The printing the proxy is of. Its collectible type and source id identify it. |
| `finish` | A string that isn't blank, or `null` | One of the finishes the catalog lists for that entry; `null` for a printing that lists none. |
| `quantity` | A whole number from 1 to 9,999 | How many proxies of that printing and finish the zone has. |

The object has these fields and no others. A proxy is identified by five values: the deck's comparison key, the zone key, the entry's collectible type and source id, and the finish. A file never holds two proxies of one identity. A proxy carries no time and no price. A zone, a deck and a collectible type are the ones the [Decks](#decks) section describes; a proxy's printing need not be of its deck's collectible type, because a deck whose type changed keeps the proxies it had.
```

  3. "Well-formed" rule list: add `- from version 4, no two proxies have the same [identity](#proxies) (\`duplicate_proxy\`)` and `- from version 4, every proxy's \`deck\` is one of the file's decks, compared by comparison key (\`unknown_location\`)`; the sentence "the rules are the same for all four" gains "and the rules about proxies from version 4". The "Resolvable" list gains: ``- for every proxy: its entry is in that catalog, retired or not; its `finish` is `null` or one that the catalog lists for that entry; and its `zone` is one of the zones of its deck's format on that instance``, and the table gains rows for a proxy's type, entry and finish (not resolvable) and zone (`unknown_zone`).
  4. "The same collection": a bullet `- From version 4, their proxies are equal as sets of deck name (as written), zone key, entry identity, finish and quantity, each compared exactly. The order of the proxies doesn't matter.`
  5. "Versions": history row 4 becomes `| 4 | 2026-11-10 | Decks and proxies: the required top-level lists \`decks\` and \`proxies\`, and a lot's \`location\` may be an object \`{ deck, zone }\`. The rules \`duplicate_location\` and \`unknown_location\` cover decks (and \`unknown_location\` a proxy's deck), \`duplicate_proxy\` covers proxies, and \`too_many_locations\` counts places and decks together. |`; after the table add: "Version 4 gained \`proxies\` before any release wrote a version 4 file, so it is one version (the maintainer's ruling of 2026-11-11); a version 4 file written by a development build before that has no \`proxies\` and isn't a well-formed version 4 file." and in the paragraph on older files: "A reader of version 4 reads a file of version 1 to 3 as … the collector's decks are left in place … and so are their proxies, because such a file can name none."
  6. "Coverage": a table row ``| `deck_proxies` | Exported | The proxies a collector's decks need, as `proxies`. |`` after `decks`, and column rows after the `decks.*` ones:

```markdown
| `deck_proxies.id` | Left out | An internal id. |
| `deck_proxies.account_id` | Left out | An internal id. A file is one account's collection. |
| `deck_proxies.location_id` | `deck` | By the zone's deck's name; the zone is the field `zone`. |
| `deck_proxies.catalog_entry_id` | `entry` | |
| `deck_proxies.finish` | `finish` | |
| `deck_proxies.quantity` | `quantity` | |
| `deck_proxies.created_at` | Left out | A fact about the instance, not about the collection. |
| `deck_proxies.updated_at` | Left out | A fact about the instance, not about the collection. |
```

(The "Left out" rows' second column heading in that table is "Why left out"; copy the neighbouring rows' column layout, and keep the `locations.zone` row's wording in step: its "In the file" is `zone`, which now serves proxies too.) The "Examples" section's list gains `valid/proxies-v4.json`, the eleven `invalid/proxy*` files and `comparison/v4-different-proxy-added.json`.

- [ ] **Step 7: Run** `bin/rspec spec/export_format_examples_spec.rb spec/export_format_document_spec.rb spec/models/export_format`: the example and the document specs still fail only on what T15 and T16 add (the rules: `duplicate_proxy` and the per-row proxy problems need the app's `ExportFormat::Rules`); the document spec's coverage examples fail until the migration's table is listed (done in Step 6) — they must pass now. Commit the schema, the examples and the document together once T15's rules make the examples spec pass (the round-trip example over the valid examples, `spec/models/collection_import/round_trip_spec.rb`, stays red on `valid/proxies-v4.json` until T18: the commit is still made, and the red example is named in its body), as one commit `docs(export): version 4 carries proxies, their schema, document and examples (spec 068 T14)`: if the examples spec still fails after T15, the examples are wrong, not the rules.

### T15: The app's rules for proxies

- [ ] **Step 1: The failing spec**: T14's examples spec is the spec; add to `spec/models/export_format/rules_spec.rb`:

```ruby
  describe "proxies (spec 068 decision 18)" do
    let(:base) { JSON.parse(ExportFormatRules.examples("valid").fetch("valid/proxies-v4.json")) }

    it "reads each proxy against its own schema, so a bad proxy is one row problem under /proxies/N", :aggregate_failures do
      data = base.merge("proxies" => base["proxies"] + [ base["proxies"][0].merge("quantity" => 0, "finish" => "etched") ]) # another finish: not a duplicate

      expect(described_class.problems_in(data).map { [ it.rule, it.at ] }).to eq([ [ "minimum", "/proxies/3/quantity" ] ])
    end

    it "judges duplicates and unlisted decks by identity and comparison key, skipping a proxy whose own fields failed", :aggregate_failures do
      one = base["proxies"][0]
      data = base.merge("proxies" => [ one, one.merge("deck" => one["deck"].upcase), one.merge("deck" => "Nope"), one.merge("finish" => " ", "quantity" => 1) ])

      expect(described_class.problems_in(data).map { [ it.rule, it.at ] }).to eq([ [ "pattern", "/proxies/3/finish" ], [ "duplicate_proxy", "/proxies/1" ], [ "unknown_location", "/proxies/2/deck" ] ])
    end

    it "lists duplicate_proxy among the rules a schema can't state" do
      expect(described_class::RULES).to include("duplicate_proxy")
    end

    it "doesn't read proxies of a file older than version 4 (a version 3 file has none)" do
      v3 = JSON.parse(ExportFormatRules.examples("valid").fetch("valid/collection-v3.json"))

      expect(described_class.problems_in(v3.merge("proxies" => [ 5 ]))).to be_empty
    end
  end
```

- [ ] **Step 2: Run, confirm it fails.** **Step 3: The code**, in `app/models/export_format/rules.rb`. `RULES` gains `duplicate_proxy`; the identity constants:

```ruby
    RULES = %w[not_utf8 not_json not_a_time changed_before_added duplicate_lot duplicate_location duplicate_proxy unknown_location too_many_locations].freeze
    # The fields under a proxy that make its identity (spec 068): the deck, the zone, the entry's type and source id, the finish.
    PROXY_IDENTITY_FIELDS = %w[deck zone entry entry/collectible_type entry/source_id finish].freeze
```

(update the comment above `RULES`: "duplicate_proxy is version 4's second proxy of one identity".) Next to `lot_schemer`:

```ruby
    # The schema of one proxy, $defs/proxy (version 4), checked one at a time like a lot (spec 068 decision 18).
    def self.proxy_schemer(version = VERSION) = (@proxy_schemers ||= {})[version] ||= schemer(version).ref("#/$defs/proxy")
```

`schema_problems` becomes:

```ruby
    def self.schema_problems(data, version)
      return problems_from(schemer(version).validate(data)) unless data.is_a?(Hash) && data["lots"].is_a?(Array)

      over = names_over_limit?(data, version)
      data = cut_names(data) if over
      proxies = data["proxies"] if version >= 4 && data["proxies"].is_a?(Array)
      shell = data.merge("lots" => [])
      shell = shell.merge("proxies" => []) if proxies
      root, header = schemer(version).validate(shell).partition { |error| error["data_pointer"].empty? }
      lots = data["lots"].each_with_index.flat_map { |lot, index| problems_from(lot_schemer(version).validate(lot), "/lots/#{index}") }
      rows = proxies ? proxies.each_with_index.flat_map { |proxy, index| problems_from(proxy_schemer(version).validate(proxy), "/proxies/#{index}") } : []
      problems_from(header) + (over ? [ over_limit_problem(version) ] : []) + lots + rows + problems_from(root)
    end
```

(update its comment: "the lots and, from version 4, the proxies are checked one at a time".) In `rule_problems`, replace the final `long + ...` line's tail:

```ruby
      proxies = version >= 4 && data["proxies"].is_a?(Array) ? data["proxies"].each_with_index.select { |proxy, _index| proxy.is_a?(Hash) } : []
      long + not_times + backwards + repeats + unlisted_places(data, lots, failed, version) + (version >= 2 ? repeated_locations(data, failed, version) : []) +
        repeated_proxies(proxies, failed) + unlisted_proxy_decks(data, proxies, failed)
```

and the new methods (add `:repeated_proxies, :unlisted_proxy_decks` to `private_class_method`):

```ruby
    # The second and later proxies of one identity (spec 068, `duplicate_proxy`): the deck by comparison key, so "Izzet" and
    # "izzet" are one deck. A proxy whose identity fields failed the schema has nothing to compare, as a lot's doesn't.
    def self.repeated_proxies(proxies, failed)
      readable = proxies.select { |proxy, index| proxy_identity_readable?(proxy, "/proxies/#{index}", failed) }
      readable.group_by { |proxy, _index| proxy_identity(proxy) }.values
        .flat_map { |group| group.drop(1).map { |_proxy, index| Problem.new("duplicate_proxy", "/proxies/#{index}") } }
    end

    # The proxies whose deck isn't one of the file's decks, by comparison key (`unknown_location`, at the proxy's `deck`): a
    # proxy whose deck failed the schema has nothing to compare, and none is compared against a list that failed.
    def self.unlisted_proxy_decks(data, proxies, failed)
      keys = listed_keys(data, "decks", failed, 4) or return []

      proxies.filter_map do |proxy, index|
        at = "/proxies/#{index}"
        next if failed.include?(at) || failed.include?("#{at}/deck")

        Problem.new("unknown_location", "#{at}/deck") unless keys.include?(Location::Name.key(Location::Name.normalise(proxy["deck"])))
      end
    end

    # What identifies a proxy (spec 068): the deck's comparison key, the zone key, the entry's type and source id, the finish.
    #
    # @param proxy [Hash] a proxy of the file whose identity fields passed the schema
    # @return [Array] five values
    def self.proxy_identity(proxy)
      [ Location::Name.key(Location::Name.normalise(proxy["deck"])), proxy["zone"], proxy.dig("entry", "collectible_type"), proxy.dig("entry", "source_id"), proxy["finish"] ]
    end

    # Whether the proxy at +at+ has an identity to compare: none of its identity fields is among the +failed+ pointers.
    #
    # @return [Boolean]
    def self.proxy_identity_readable?(proxy, at, failed)
      !failed.include?(at) && PROXY_IDENTITY_FIELDS.none? { |field| failed.include?("#{at}/#{field}") }
    end
```

(`private_class_method` gains `:repeated_proxies, :unlisted_proxy_decks` only: `proxy_identity` and `proxy_identity_readable?` stay public, as `identity` and `identity_readable?` are, because `CollectionImport::ProxyRows` calls them.)

- [ ] **Step 4: Run** `bin/rspec spec/models/export_format spec/export_format_examples_spec.rb spec/export_format_document_spec.rb`: pass, including the 11 new invalid examples each with exactly its problem. A failing "one problem each" example means a rule fires twice (a duplicate also unlisted, a failed field also read): fix the rule's guard, not the example.
- [ ] **Step 5: Commit** T14's and T15's files: first `git add docs/export-format app/models/export_format spec/export_format_examples_spec.rb spec/export_format_document_spec.rb spec/support/export_format_rules.rb spec/models/export_format`, then `git commit -m "feat(export): version 4 carries proxies, the schema, rules, examples and document (spec 068 T14, T15)"`.

### T16: The export

- [ ] **Step 1: The failing spec**, in `spec/models/collection_export_spec.rb` (read its top for how it builds `account` and calls the export; use its helpers):

```ruby
  describe "proxies (spec 068 Story 7)" do
    let(:account) { create(:user).account }
    let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
    let(:entry) { create(:mtg_printing).entry }

    def exported = described_class.new(account:, at: Time.utc(2026, 11, 11, 12)).to_h

    it "writes an empty list for an account with none (AC-7.1)" do
      expect(exported["proxies"]).to eq([])
    end

    it "writes each proxy as deck, zone, entry, finish and quantity, with no id and no time (AC-7.1)", :aggregate_failures do
      create(:deck_proxy, zone: deck.zone("sideboard"), account:, entry:, finish: "foil", quantity: 2)

      proxy = exported["proxies"].sole

      expect(proxy).to eq("deck" => "Izzet Tempo", "zone" => "sideboard",
        "entry" => { "collectible_type" => "mtg", "source_id" => entry.external_key, "name" => entry.name, "set_code" => entry.set.code,
                     "collector_number" => entry.number, "language" => "en" },
        "finish" => "foil", "quantity" => 2)
      expect(ExportFormat::Rules.problems(described_class.new(account:, at: Time.current).to_json)).to be_empty
    end

    it "writes them in the same order for two exports, and not another account's or any lot (AC-7.1)", :aggregate_failures do
      other = create(:deck, account:, name: "Alpha")
      create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "nonfoil")
      create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil")
      create(:deck_proxy, zone: other.zone("considering"), account:)
      create(:deck_proxy)

      first = exported["proxies"]

      expect(first.map { [ it["deck"], it["zone"], it["finish"] ] }).to eq([ [ "Alpha", "considering", "nonfoil" ], [ "Izzet Tempo", "main", "foil" ], [ "Izzet Tempo", "main", "nonfoil" ] ])
      expect(exported["proxies"]).to eq(first)
      expect(exported["lots"]).to eq([])
    end

    it "reads the proxies in one statement, however many (AC-7.2)", :aggregate_failures do
      few = count_queries { exported }
      5.times { |n| create(:deck_proxy, zone: create(:deck, account:, name: "D#{n}").zone("main"), account:) }

      expect(count_queries { exported }).to eq(few) # the proxies' read runs once, with none or with five
    end

    it "still exports a proxy of a collectible type the instance no longer has (AC-7.2)" do
      create(:deck_proxy, zone: deck.zone("main"), account:, entry:)
      allow(Catalog).to receive(:collecting).and_return({})

      expect(exported["proxies"].size).to eq(1)
    end
  end
```

- [ ] **Step 2: Run, confirm it fails** (`expected "proxies"`). **Step 3: The code**, `app/models/collection_export.rb`: update the header comment ("Version 4 adds `decks` …, and `proxies`: …"), add the constant, the call and the helpers:

```ruby
  # What a proxy is written from: its entry and set, its finish and quantity, then its zone's key and its deck's name, type and
  # format as the same statement saw them.
  PROXY_COLUMNS = [ "catalog_entries.collectible_type", "catalog_entries.external_key", "catalog_entries.name", "catalog_sets.code",
    "catalog_entries.number", "catalog_entries.language", "deck_proxies.finish", "deck_proxies.quantity",
    "parents.name", "locations.zone", "decks.collectible_type", "decks.format" ].freeze
```

`to_h` and `places_decks_and_lots`:

```ruby
    locations, decks, proxies, lots = places_decks_and_lots
    { ..., "locations" => locations, "decks" => decks, "proxies" => proxies, "lots" => lots }
```

```ruby
    def places_decks_and_lots
      TRIES.times do
        rows = lot_rows
        proxies = proxy_rows
        names = @account.locations.places.ordered.pluck(:name)
        decks = @account.decks.listing_order.pluck("locations.name", :collectible_type, :format)
        deck_map = decks.to_h { |name, type, format| [ name, [ type, format ] ] }
        next unless settled?(rows, names.to_set, deck_map) && proxies_settled?(proxies, deck_map)

        return [ names.map { |name| { "name" => name } },
                 decks.map { |name, type, format| { "name" => name, "collectible_type" => type, "format" => format } },
                 proxies.map { |row| proxy_hash(row) },
                 rows.map { |row| lot_hash(row) } ]
      end
      raise Unsettled, "the account's locations and decks kept changing while its collection was read"
    end

    # Every proxy's deck is one the list names, with the type and format the proxy's own statement saw.
    def proxies_settled?(rows, decks)
      rows.all? { |row| decks[row[8]] == row.last(2) }
    end

    # The proxies, in one statement with their zone, its deck and the entry's set, in the order two exports of one collection
    # share: the deck's comparison key and name, the zone key, the entry's type and source id, the finish (no finish first).
    # A proxy is never a lot: this reads `deck_proxies` only (spec 068 decision 1).
    def proxy_rows
      @account.deck_proxies.joins(entry: :set)
        .joins("JOIN locations ON locations.id = deck_proxies.location_id " \
               "JOIN locations parents ON parents.id = locations.parent_id " \
               "JOIN decks ON decks.location_id = parents.id")
        .order("parents.name_key", "parents.name", "locations.zone", "catalog_entries.collectible_type", "catalog_entries.external_key", "deck_proxies.finish")
        .pluck(*PROXY_COLUMNS)
    end

    def proxy_hash(row)
      type, source_id, name, set_code, number, language, finish, quantity, deck_name, zone = row.first(10)
      { "deck" => deck_name, "zone" => zone,
        "entry" => { "collectible_type" => type, "source_id" => source_id, "name" => name, "set_code" => set_code,
                     "collector_number" => number, "language" => language },
        "finish" => finish, "quantity" => quantity }
    end
```

(`@account.deck_proxies.joins(entry: :set)`: the `decks` join must not clash with the proxies' own account scope; the statement names every column it reads.)

- [ ] **Step 4: The header example.** In `spec/models/collection_export_spec.rb` the example "writes the header, the profile and the currency" (line ~41) compares `file.except("lots", "locations", "decks")`: add `"proxies"` to the `except`.
- [ ] **Step 4b: Run** `bin/rspec spec/models/collection_export_spec.rb spec/collection_export_core_spec.rb spec/requests/collection_exports_spec.rb`: pass (the export's existing query-count examples compare a few lots with many, so no number moves). **Step 5: Commit** `feat(export): the export carries proxies (spec 068 T16)`.

---

## Phase 6: The import

**Implements:** FR-4 (import), Story 7 | **Satisfies:** AC-7.4 to AC-7.13
**Files:** `app/models/collection_import.rb`, `app/models/collection_import/proxy_rows.rb`, `app/models/collection_import/proxies.rb`, `app/models/collection_import/plan.rb`, `app/models/collection_import/apply.rb`, `app/controllers/collections/imports_controller.rb`, `app/helpers/import_previews_helper.rb`, `app/views/collections/import_previews/show.html.erb`, `_decks.html.erb`, `_proxies.html.erb`, `spec/models/collection_import_proxies_spec.rb`, `spec/requests/collection_import_proxies_spec.rb`, `spec/requests/collection_import_proxy_timing_spec.rb`
**Interfaces:** Consumes `ExportFormat::Rules` (T15), the export (T16), `Deck::Proxy`. Produces `CollectionImport#proxies` (a `CollectionImport::Proxies`), `#proxy_rows`, `#proxy_problem_rows`, `#proxy_entry_id(row)`, `Plan#proxies`, the `Plan.new(outcomes, view_change, locations, decks, proxies, currency_change)` signature.

### T17: The reader and the outcomes

- [ ] **Step 1: The failing spec** `spec/models/collection_import_proxies_spec.rb`:

```ruby
require "rails_helper"

# Spec 068 Story 7: how a file's proxies are read, judged and planned against the collector's own. The file is the account's
# own export, changed, so every deck and lot matches and only the proxies differ.
RSpec.describe CollectionImport, "proxies", type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing).entry }
  let!(:held) { create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2) }

  def file = CollectionExport.new(account:, at: Time.utc(2026, 11, 11)).to_h
  def read(data) = described_class.new(account:, file: StringIO.new(JSON.generate(data)))
  def entry_hash(entry) = { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name, "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language }
  def proxy(**changes) = file["proxies"].first.merge(changes.transform_keys(&:to_s))
  def with(proxies) = file.merge("proxies" => proxies)

  describe "the outcomes (decision 16)" do
    it "reads the account's own export as nothing to change", :aggregate_failures do
      import = read(file)

      expect(import.applicable?).to be(true)
      expect(import.plan.proxies.counted?).to be(true)
      expect(import.plan.proxies.counts).to eq(added: 0, changed: 0, unchanged: 1, removed: 0)
      expect(import.plan.nothing_to_change?).to be(true)
    end

    it "adds a row no held proxy has, changes one with another quantity, keeps an equal one and removes a held one the file lacks", :aggregate_failures do
      other = create(:mtg_printing).entry
      data = with([ proxy("quantity" => 5), proxy("entry" => entry_hash(other), "finish" => "nonfoil", "quantity" => 1) ])

      proxies = read(data).plan.proxies

      expect(proxies.counts).to eq(added: 1, changed: 1, unchanged: 0, removed: 0)
      expect(proxies.added.map(&:number)).to eq([ 2 ])
      expect(proxies.changed.map(&:number)).to eq([ 1 ])
      expect(proxies.held_for(proxies.changed.first).id).to eq(held.id)
      expect(read(with([])).plan.proxies.removed.map(&:id)).to eq([ held.id ])
    end

    it "counts the proxies of a deck or zone the file drops among the removed (decision 16)", :aggregate_failures do
      data = file.merge("decks" => [], "lots" => [], "proxies" => [])

      import = read(data)

      expect(import.plan.proxies.removed.map(&:id)).to eq([ held.id ])
      expect(import.plan.removes?).to be(true)
    end

    it "counts a held proxy that only a problem row names as removed (the preview can't be applied then)", :aggregate_failures do
      data = with([ proxy("quantity" => 0) ])

      import = read(data)

      expect(import.applicable?).to be(false)
      expect(import.plan.proxies.removed.map(&:id)).to eq([ held.id ])
    end

    it "lists the removed proxies by deck, zone, name, set, number, language and finish (decision 16)" do
      second = create(:deck_proxy, zone: deck.zone("considering"), account:, entry: create(:mtg_printing).entry)

      expect(read(with([])).plan.proxies.removed.map(&:id)).to eq([ second.id, held.id ]) # the zone key "considering" sorts before "main"
    end

    it "judges nothing for a file older than version 4, and leaves the proxies (decision 15)", :aggregate_failures do
      v3 = file.except("proxies", "decks").merge("format_version" => 3)
      v3["lots"] = []

      proxies = read(v3).plan.proxies

      expect(proxies.counted?).to be(false)
      expect([ proxies.removes?, proxies.nothing_to_change?, proxies.removed ]).to eq([ false, true, [] ])
    end
  end

  describe "the whole file's refusals (decision 14, AC-7.5)" do
    it "refuses a version 4 file with no proxies list, naming it", :aggregate_failures do
      import = read(file.except("proxies"))

      expect(import.refused?).to be(true)
      expect([ import.refusal.rule, import.refusal.at ]).to eq([ "required", "/proxies" ])
      expect(import.refusal.reason).to include("proxies")
    end

    it "refuses a proxies value that isn't a list", :aggregate_failures do
      import = read(file.merge("proxies" => {}))

      expect([ import.refused?, import.refusal.at ]).to eq([ true, "/proxies" ])
    end
  end

  describe "the problem rows (decision 18, AC-7.6)" do
    def reasons(data) = read(data).proxy_problem_rows.flat_map { |row| row.problems.map { [ row.number, it.rule, it.reason ] } }

    it "is a row problem, not a refusal, for a field that fails the schema", :aggregate_failures do
      import = read(with([ proxy("quantity" => 0) ]))

      expect(import.refused?).to be(false)
      expect(import.proxy_problem_rows.map(&:number)).to eq([ 1 ])
      expect(import.proxy_problem_rows.first.problems.map(&:rule)).to eq([ "minimum" ])
      expect(import.applicable?).to be(false)
    end

    it "names each reader's rule with its reason", :aggregate_failures do
      other = create(:mtg_printing).entry
      expect(reasons(with([ proxy("deck" => "Nope") ]))).to eq([ [ 1, "unknown_location", "Its deck “Nope” isn't one of the file's decks." ] ])
      expect(reasons(with([ proxy("zone" => "no-such-zone") ]))).to eq([ [ 1, "unknown_zone", "The deck “Izzet Tempo” has no zone “no-such-zone” in its format." ] ])
      expect(reasons(with([ proxy("entry" => entry_hash(other).merge("collectible_type" => "gone")) ]))).to eq([ [ 1, "unknown_type", "This instance doesn't collect gone" ] ])
      expect(reasons(with([ proxy("entry" => entry_hash(other).merge("source_id" => "nope")) ]))).to eq([ [ 1, "not_in_catalog", "Not in this instance's catalog" ] ])
      expect(reasons(with([ proxy("finish" => "etched") ]))).to eq([ [ 1, "finish_not_listed", "This printing doesn't come in etched" ] ])
      expect(reasons(with([ proxy, proxy ]))).to eq([ [ 2, "duplicate_proxy", "Same deck, zone, card and finish as proxy 1" ] ])
    end

    it "accepts a proxy with no finish, for a printing that lists finishes too (decision 2)" do
      expect(read(with([ proxy("finish" => nil) ])).proxy_problem_rows).to be_empty
    end

    it "never compares a proxy's collectible type with its deck's (decision 19)" do
      other_type = create(:catalog_entry, collectible_type: "other") # a type the instance has no source for
      problems = read(with([ proxy("entry" => entry_hash(other_type), "finish" => nil) ])).proxy_problem_rows.flat_map { |row| row.problems.map(&:rule) }

      expect(problems).to eq([ "unknown_type" ]) # the type isn't registered here; a registered one is never compared with the deck's
    end

    it "counts the problems of every row by their summary, and lists the first LIST_LIMIT rows" do
      rows = Array.new(3) { proxy("quantity" => 0) }.each_with_index.map { |row, index| row.merge("zone" => "z#{index}") }

      import = read(with(rows))

      expect(import.proxy_problem_counts).to eq("quantity isn't valid" => 3)
      expect(import.listed_proxy_problem_rows.size).to eq(3)
    end
  end
end
```

- [ ] **Step 2: Run, confirm it fails** (`NoMethodError: plans`/`proxies`).
- [ ] **Step 3: The outcomes class** `app/models/collection_import/proxies.rb`:

```ruby
# What applying a file would do with the collector's proxies (spec 068 decision 16): compare by identity, as lots are. A version
# 1 to 3 file says nothing about proxies (+rows+ is nil), so the collector's stay and nothing here counts. A held proxy no good
# row matches is *removed*, a held proxy a problem row only names included (the preview can't be applied then); counts are
# rows, not quantities (spec Terms).
#
# Collectible-agnostic: a proxy is a deck and zone key, an entry's type and source id and a finish.
# @see file:data-portability.md
class CollectionImport::Proxies
  # A proxy of the collection, read as the file would write it: +identity+ is `[deck key, zone key, type, source id, finish]`;
  # +place+ is "Deck › Zone".
  Held = Data.define(:id, :identity, :quantity, :name, :set_code, :collector_number, :language, :finish, :place) do
    # What a list shows of it: `import_proxy_line`'s keywords.
    def described = { set_code:, collector_number:, language:, finish:, place: }
  end

  # @return [Array<CollectionImport::ProxyRows::ProxyRow>] the good rows no held proxy has
  attr_reader :added
  # @return [Array<CollectionImport::ProxyRows::ProxyRow>] the good rows whose held proxy has another quantity
  attr_reader :changed
  # @return [Array<Held>] the held proxies no good row matches
  attr_reader :removed
  # @return [Integer] the good rows equal to a held proxy
  attr_reader :unchanged

  # @param held [Array<Held>] the account's proxies
  # @param rows [Array<CollectionImport::ProxyRows::ProxyRow>, nil] the file's proxy rows, or nil for a version 1 to 3 file
  def initialize(held, rows)
    @counted = !rows.nil?
    @added = []
    @changed = []
    @removed = []
    @unchanged = 0
    @held = held.index_by(&:identity)
    return unless @counted

    good = rows.reject(&:problem?)
    matched, @added = good.partition { |row| @held.key?(row.identity) }
    @changed, same = matched.partition { |row| row.quantity != @held.fetch(row.identity).quantity }
    @unchanged = same.size
    kept = matched.to_set(&:identity)
    @removed = held.reject { |proxy| kept.include?(proxy.identity) }.sort_by { |proxy| order(proxy) }
  end

  # Whether the file says anything about proxies (version 4).
  def counted? = @counted

  # The four counts the preview shows, in rows.
  #
  # @return [Hash{Symbol => Integer}]
  def counts = { added: added.size, changed: changed.size, unchanged:, removed: removed.size }

  # Whether the file changes no proxy.
  def nothing_to_change? = added.empty? && changed.empty? && removed.empty?

  # Whether applying removes a proxy, which needs the collector's confirmation.
  def removes? = removed.any?

  # The held proxy a changed row matches.
  #
  # @param row [CollectionImport::ProxyRows::ProxyRow]
  # @return [Held]
  def held_for(row) = @held.fetch(row.identity)

  # The first `CollectionImport::LIST_LIMIT` removed proxies, for the page.
  def listed_removed = removed.first(CollectionImport::LIST_LIMIT)

  # How many removed proxies the page doesn't list.
  def more_removed = removed.size - listed_removed.size

  # What the plan's fingerprint takes from the proxies: each added row by its identity and quantity, each changed row by its
  # identity and both quantities, each removed proxy by its identity and quantity. No id and no row number, so a proxy
  # deleted and added again with the same identity and quantity changes nothing. Empty for an older file.
  #
  # @return [Array]
  def fingerprint_part
    [ added.map { |row| [ *row.identity, row.quantity ] }.sort_by { |part| part.map(&:to_s) },
      changed.map { |row| [ *row.identity, held_for(row).quantity, row.quantity ] }.sort_by { |part| part.map(&:to_s) },
      removed.map { |proxy| [ *proxy.identity, proxy.quantity ] } ]
  end

  private
    # Deck key, zone key, card name, set code, collector number as a person reads it, language, finish (decision 16).
    def order(proxy)
      number = proxy.collector_number.to_s
      [ proxy.identity[0], proxy.identity[1], proxy.name, proxy.set_code, number.match?(/\A\d/) ? 0 : 1, number.to_i, number, proxy.language, proxy.finish.to_s ]
    end
end
```

- [ ] **Step 4: The row reader** `app/models/collection_import/proxy_rows.rb`:

```ruby
# Reads a version 4 file's proxies, one row at a time, as `CollectionImport` reads its lots (spec 068 decision 18): a problem under
# `/proxies/N` is a problem row of that proxy and never a refusal of the file; a `proxies` that isn't a list is refused with the
# header's problems. Included by `CollectionImport`, whose private helpers it shares (`entries_for`, `registered?`, `problem`,
# `field_reason`, `file_deck_formats`, `zone_name`); its constants are named in full (`CollectionImport::Problem`) because the
# compact module name leaves `CollectionImport` out of the lexical scope.
#
# The rules, each with its home: the schema's keywords, `duplicate_proxy` and `unknown_location` are the format's
# (`ExportFormat::Rules`); `unknown_type`, `not_in_catalog`, `finish_not_listed` and `unknown_zone` are the reader's, judged in
# that order for a row with no problem of the format. A proxy with no finish is never a problem (decision 2), and the reader
# never compares a proxy's collectible type with its deck's (decision 19).
# @see file:data-portability.md
module CollectionImport::ProxyRows
  PROXY_ROW = %r{\A/proxies/(\d+)(?:/(.+))?\z}
  DUPLICATE_PROXY_OF = "Same deck, zone, card and finish as proxy %d".freeze
  DUPLICATE_PROXY = "Same deck, zone, card and finish as an earlier proxy".freeze

  # One element of the file's proxies, numbered from 1. +identity+ is nil when it can't be read; +place+ is "Deck › Zone" as the
  # file spells the deck and the zone's registered name (its key when the format has none), nil when either isn't text.
  ProxyRow = Data.define(:number, :proxy, :identity, :problems, :place) do
    # Whether the row can't be applied.
    def problem? = problems.any?

    # The quantity the file gives.
    def quantity = proxy.is_a?(Hash) ? proxy["quantity"] : nil

    # The finish the file gives, when it is text.
    def finish = (proxy["finish"] if proxy.is_a?(Hash) && proxy["finish"].is_a?(String))

    # The card's name as the file writes it, when it is text.
    def name = text(entry["name"])

    # What the file says the row is, for a list (`import_proxy_line`'s keywords).
    def described = { set_code: text(entry["set_code"]), collector_number: text(entry["collector_number"]), language: text(entry["language"]), finish:, place: }

    # The file's entry object, or an empty one when it isn't.
    def entry = proxy.is_a?(Hash) && proxy["entry"].is_a?(Hash) ? proxy["entry"] : {}

    private
      def text(value) = (value if value.is_a?(String))
  end

  private
    def read_proxy_rows
      proxies = @data["proxies"]
      failed = @problems.reject { |problem| %w[duplicate_proxy unknown_location].include?(problem.rule) }.to_set(&:at)
      found = Hash.new { |hash, index| hash[index] = [] }
      @problems.each { |problem| (match = PROXY_ROW.match(problem.at)) && found[match[1].to_i] << problem }
      identities = proxies.each_with_index.map do |proxy, index|
        ExportFormat::Rules.proxy_identity(proxy) if ExportFormat::Rules.proxy_identity_readable?(proxy, "/proxies/#{index}", failed)
      end
      first = {}
      identities.each_with_index { |identity, index| first[identity] ||= index + 1 if identity }
      resolved = proxy_resolution_problems(proxies.each_with_index.reject { |_proxy, index| found.key?(index) })
      proxies.each_with_index.map do |proxy, index|
        problems = found.fetch(index, []).map { |item| describe_proxy_problem(item, first[identities[index]], proxy) } + resolved.fetch(index, [])
        ProxyRow.new(number: index + 1, proxy:, identity: identities[index], problems:, place: proxy_place_label(proxy))
      end
    end

    def proxy_place_label(proxy)
      return unless proxy.is_a?(Hash) && proxy["deck"].is_a?(String) && proxy["zone"].is_a?(String)

      Location::Placement.label(zone_name({ "deck" => proxy["deck"], "zone" => proxy["zone"] }) || proxy["zone"], proxy["deck"])
    end

    def describe_proxy_problem(item, earlier, proxy)
      case item.rule
      when "duplicate_proxy" then CollectionImport::Problem.new(rule: item.rule, at: item.at, reason: format(DUPLICATE_PROXY_OF, earlier), summary: DUPLICATE_PROXY)
      when "unknown_location"
        CollectionImport::Problem.new(rule: item.rule, at: item.at, reason: "Its deck “#{proxy["deck"]}” isn't one of the file's decks.", summary: "Its deck isn't one of the file's decks.")
      else
        field = PROXY_ROW.match(item.at)[2]&.tr("/", ".")
        reason = field ? field_reason(item.rule, field) : "This row isn't a proxy"
        CollectionImport::Problem.new(rule: item.rule, at: item.at, reason:, summary: reason)
      end
    end

    # The type, then the entry, then the finish (a non-null one the entry doesn't list); then, for a row with none of those, the
    # zone its deck's format lacks. Also remembers the entry each good row resolved to, for applying.
    def proxy_resolution_problems(candidates)
      found = {}
      candidates.group_by { |proxy, _index| proxy["entry"]["collectible_type"] }.each do |type, group|
        unless registered?(type)
          group.each { |_proxy, index| found[index] = [ problem("unknown_type", "/proxies/#{index}/entry/collectible_type", "This instance doesn't collect #{type}") ] }
          next
        end

        vocabulary = Catalog.collecting_for(type)
        entries = entries_for(type, group.map { |proxy, _index| proxy["entry"]["source_id"] })
        group.each do |proxy, index|
          entry = entries[proxy["entry"]["source_id"]]
          @proxy_entry_ids[index + 1] = entry&.id
          list = proxy_entry_problems(proxy, index, entry, vocabulary)
          zone = proxy_zone_problem(proxy, index) if list.empty?
          list << zone if zone
          found[index] = list if list.any?
        end
      end
      found
    end

    def proxy_entry_problems(proxy, index, entry, vocabulary)
      list = []
      list << problem("not_in_catalog", "/proxies/#{index}/entry/source_id", "Not in this instance's catalog") unless entry
      if entry && proxy["finish"] && vocabulary.finishes_for(entry).exclude?(proxy["finish"])
        list << problem("finish_not_listed", "/proxies/#{index}/finish", "This printing doesn't come in #{proxy["finish"]}")
      end
      list
    end

    # A proxy in a zone its deck's format lacks: the deck is listed (else it is `unknown_location`, a rule of the format) and
    # registered (else the file was refused), so only the zone key can be wrong; a resolvable check (spec 062 AC-6.11).
    def proxy_zone_problem(proxy, index)
      pair = file_deck_formats[Location::Name.key(Location::Name.normalise(proxy["deck"]))]
      zones = Catalog::Formats.zones_for(*pair) if pair
      return unless zones && zones.none? { |zone| zone.key == proxy["zone"] }

      CollectionImport::Problem.new(rule: "unknown_zone", at: "/proxies/#{index}/zone", summary: "Its deck has no such zone in its format.",
        reason: "The deck “#{proxy["deck"]}” has no zone “#{proxy["zone"]}” in its format.")
    end
end
```

- [ ] **Step 5: The reader's wiring**, `app/models/collection_import.rb`:
  - `include ProxyRows` right after the class line; in `initialize`: `@proxy_entry_ids = {}` before `@refusal = read(file)`, and after `@rows = ...`: `@proxy_rows = refused? || @version < 4 ? [] : read_proxy_rows`.
  - `header_refusal`: `outside = @problems.reject { |problem| ROW.match?(problem.at) || ProxyRows::PROXY_ROW.match?(problem.at) }`.
  - new public methods:

```ruby
  attr_reader :refusal, :rows, :proxy_rows

  # Whether the file lists proxies (version 4); an older one leaves the collector's alone, and the page says so.
  def proxies_counted? = @version >= 4

  # What applying would do with the collector's proxies: nothing counted for a file older than version 4 (spec 068 decision 15).
  def proxies = @proxies ||= Proxies.new(held_proxies, proxies_counted? ? proxy_rows : nil)

  # The proxy rows that can't be applied, as `problem_rows` are for lots (spec 068 decision 18).
  def proxy_problem_rows = @proxy_problem_rows ||= proxy_rows.select(&:problem?)

  # The first `LIST_LIMIT` proxy rows that can't be applied, for the page.
  def listed_proxy_problem_rows = proxy_problem_rows.first(LIST_LIMIT)

  # How many proxy problem rows the page doesn't list.
  def more_proxy_problem_rows = proxy_problem_rows.size - listed_proxy_problem_rows.size

  # How many proxy rows have each kind of problem, in the order the kinds first appear.
  def proxy_problem_counts = proxy_problem_rows.flat_map { |row| row.problems.map(&:summary).uniq }.tally

  # The catalog entry a proxy row that isn't a problem row resolved to (for applying).
  def proxy_entry_id(row) = @proxy_entry_ids.fetch(row.number)
```
  - `applicable?` → `!refused? && problem_rows.empty? && proxy_problem_rows.empty?`.
  - `plan`: `Plan.new(outcomes, view_change, locations, decks, proxies, currency_change)`; `replan`: reset `@held_proxies = nil; @proxies = nil` and `@plan = Plan.new(@outcomes, view_change, locations, decks, proxies, currency_change)`.
  - `unloaded_catalog_titles`: `Catalog.unloaded_titles((rows.filter_map { it.entry["collectible_type"] } + proxy_rows.filter_map { it.entry["collectible_type"] }).grep(String).uniq)`.
  - private, next to `held_decks`:

```ruby
    # The account's proxies, in one statement, read once until `replan`: each as the file would write it, with its zone's
    # deck's comparison key and the zone's key for the identity.
    def held_proxies
      @held_proxies ||= @account.deck_proxies.joins(entry: :set)
        .joins("JOIN locations ON locations.id = deck_proxies.location_id JOIN locations parents ON parents.id = locations.parent_id")
        .pluck("deck_proxies.id", "catalog_entries.collectible_type", "catalog_entries.external_key", "deck_proxies.finish", "deck_proxies.quantity",
               "catalog_entries.name", "catalog_sets.code", "catalog_entries.number", "catalog_entries.language", "parents.name_key", "parents.name", "locations.zone", "locations.name")
        .map do |id, type, source_id, finish, quantity, name, set_code, number, language, deck_key, deck_name, zone, zone_name|
          Proxies::Held.new(id:, identity: [ deck_key, zone, type, source_id, finish ], quantity:, name:, set_code:, collector_number: number, language:, finish:,
            place: Location::Placement.label(zone_name, deck_name))
        end
    end
```

  Update the class comment: "spec 068 reads version 4's proxies".
- [ ] **Step 6: The plan**, `app/models/collection_import/plan.rb`: `attr_reader ... :proxies`, the constructor `def initialize(outcomes, view_change, locations, decks, proxies, currency_change)` with `@proxies = proxies` (doc: `@param proxies [CollectionImport::Proxies] what applying does with the proxies, uncounted for a version 1 to 3 file`), and:

```ruby
  def nothing_to_change? = !writes_lots? && view_change.nil? && locations.nothing_to_change? && decks.nothing_to_change? && proxies.nothing_to_change? && currency_change.nil?

  def removes? = removed_lots.any? || locations.removes? || decks.removes? || proxies.removes?
```

and in `fingerprint`, after the decks' line: `parts << proxies.fingerprint_part if proxies.counted?` (doc: "the proxies' part for a file that counts them (version 4 only, so a version 1 to 3 plan keeps the fingerprint it had, spec 068 AC-7.8)"); update the comments on `nothing_to_change?` ("no lot, no location, no deck, no proxy, no view change and no currency change"), `removes?` ("a lot, a place, a deck or a proxy") and the class's top comment ("and, for a version 4 file, of the proxies") in the same edit, and `format_changed_message`'s comment in `decks_helper.rb` ("… the proxy sentence follows the cards sentence"). `writes_lots?` is unchanged: a proxy-only apply clears no working state (AC-7.11).
- [ ] **Step 7: Run** `bin/rspec spec/models/collection_import_proxies_spec.rb spec/models/collection_import_spec.rb spec/models/collection_import spec/requests/collection_import_previews_spec.rb spec/requests/collection_imports_spec.rb`: the new file passes and the rest still do, once the version 4 files they build by hand carry `proxies` (a required list now). Four places build them, and each gets the list: `import_file_v4` in `spec/support/import_helpers.rb` gains `proxies: []` as a keyword and passes it on (`def import_file_v4(user, lots, locations: [], decks: [], proxies: [], **fields)`, `import_file(user, lots, format_version: 4, locations: ..., decks:, proxies:, **fields)`; its callers are `apply_spec`, `deck_changes_spec`, `plan_spec` and `collection_imports_spec`); the local `file_v4` helpers of `spec/models/collection_import_spec.rb` (line ~552, 26 uses) and of `spec/requests/collection_import_previews_spec.rb` (line ~180, 12 uses) each add `proxies: []` the same way (`def file_v4(lots, locations: [], decks: [], proxies: [], **fields)` and `proxies:` in the `file(...)` call); `as_current_version` in `spec/models/collection_import/round_trip_spec.rb` (line ~186) adds `"proxies" => data.fetch("proxies", [])` to its last `merge`, so `same_collection?` compares empty sets and not nil; and `spec/requests/collection_import_deck_timing_spec.rb` (line ~72) adds `"proxies" => []` to its file hash. Two examples need a change of their own: `spec/models/collection_import_spec.rb`'s "reports the rule and place problems.json names for each example refused as a whole (AC-2.7)" (line ~113) rejects only the entries whose `at` starts with `/lots/`; the invalid examples under `/proxies/N/` are row problems now, so its `reject` also drops `entry["at"].match?(%r{\A/proxies/\d})` (the two entries at `/proxies` itself are refusals and stay); and `spec/models/collection_import/round_trip_spec.rb`'s loop over every valid example (line ~201) picks up `valid/proxies-v4.json`, which restores only once T18's apply writes proxies: run that round-trip example in T18 Step 7, and until then expect it red (it is the proof of AC-7.4's file side). **Step 8: Commit** `feat(import): read, judge and plan a file's proxies (spec 068 T17)`.

### T18: The apply, the preview and the notice

- [ ] **Step 1: The failing spec** `spec/requests/collection_import_proxies_spec.rb`:

```ruby
require "rails_helper"

# Spec 068 Story 7: previewing and applying a file with proxies, through the pages, the round trip and the stale preview.
RSpec.describe "Importing proxies", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing).entry }

  def html = Nokogiri::HTML5(response.body)
  def export(account: self.account) = CollectionExport.new(account:, at: Time.utc(2026, 11, 11)).to_h
  def preview(data) = post(collection_import_preview_path, params: { export_file: import_upload_file(JSON.generate(data)) })
  def apply(confirm: false) = post(collection_import_path, params: { fingerprint: account.reload.import_upload.fingerprint, confirm_removal: (confirm ? "1" : nil) }.compact)
  def entry_hash(entry) = { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name, "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language }

  before { sign_in_as(user) }

  it "restores a collection's proxies into a fresh account, and the second export is the same collection (AC-7.4)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    create(:deck_proxy, zone: deck.zone("sideboard"), account:, entry:, finish: "nonfoil", quantity: 1)
    create_lot_in_zone(deck, "main", entry:, quantity: 4)
    first = export
    other_user = create(:user)
    delete session_path # sign out, then in as a second collector
    sign_in_as(other_user)

    post collection_import_preview_path, params: { export_file: import_upload_file(JSON.generate(first)) }
    expect(response).to have_http_status(:ok)
    post collection_import_path, params: { fingerprint: other_user.account.reload.import_upload.fingerprint }
    expect(response).to have_http_status(:see_other)

    second = export(account: other_user.account)
    expect(second["proxies"]).to eq(first["proxies"])
    expect(ExportFormatRules.same_collection?(first, second.merge("profile" => first["profile"], "currency" => first["currency"]))).to be(true)
    preview(second)
    expect(response).to have_http_status(:ok)
    expect(html.text).to include("This file has nothing to change")
  end

  it "previews a Proxies section with the four counts and the removed list, and asks for the confirmation naming proxies (AC-7.7, AC-7.9)", :aggregate_failures do
    held = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    gone = create(:deck_proxy, zone: deck.zone("sideboard"), account:, entry: create(:mtg_printing).entry, quantity: 3)
    data = export.merge("proxies" => [ export["proxies"].find { it["zone"] == "main" }.merge("quantity" => 5) ])

    preview(data)

    expect(response).to have_http_status(:ok)
    stats = html.css("#proxies .c-stat").to_h { [ it.at_css("dt").text, it.at_css("dd").text ] }
    expect(stats).to eq("Proxies added" => "0", "Proxies changed" => "1", "Proxies unchanged" => "0", "Proxies removed" => "1")
    expect(html.at_css("#removed_proxies li").text).to include(gone.entry.name, "Izzet Tempo › Sideboard", "×3")
    expect(html.at_css("label.c-check").text).to include("I understand this removes 1 proxy")
    expect(held.reload.quantity).to eq(2) # a preview writes nothing
  end

  it "refuses an apply without the box, and applies with it, writing and removing the proxies (AC-7.9, AC-7.10)", :aggregate_failures do
    kept = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    gone = create(:deck_proxy, zone: deck.zone("sideboard"), account:, entry: create(:mtg_printing).entry, quantity: 3)
    fresh = create(:mtg_printing).entry
    data = export.merge("proxies" => [ export["proxies"].find { it["zone"] == "main" }.merge("quantity" => 5),
                                       { "deck" => "Izzet Tempo", "zone" => "considering", "entry" => entry_hash(fresh), "finish" => nil, "quantity" => 1 } ])
    preview(data)

    apply
    expect(response).to have_http_status(:unprocessable_content)
    expect(Deck::Proxy.count).to eq(2)

    apply(confirm: true)

    expect(response).to redirect_to(collection_path)
    expect(flash[:notice]).to eq("Imported: 0 lots added, 0 changed, 0 removed; 1 proxy added, 1 changed, 1 removed")
    expect(kept.reload.quantity).to eq(5) # the same row: its id survives
    expect { gone.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(Deck::Proxy.where(catalog_entry_id: fresh.id, finish: nil).pick(:quantity, :location_id)).to eq([ 1, deck.zone("considering").id ])
  end

  it "writes a proxy-only change without clearing the working state, and a second apply is nothing to change (AC-7.11)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    data = export.merge("proxies" => [ export["proxies"].first.merge("quantity" => 3) ])
    preview(data)
    expect(CollectionImport::WorkingState).not_to receive(:clear!)

    apply

    expect(Deck::Proxy.sole.quantity).to eq(3)
    preview(data)
    expect(html.text).to include("This file has nothing to change")
  end

  it "makes the preview stale when a proxy changes between the preview and the apply (AC-7.12)", :aggregate_failures do
    proxy = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    preview(export.merge("proxies" => [ export["proxies"].first.merge("quantity" => 3) ]))
    proxy.update!(quantity: 9)

    apply

    expect(response).to have_http_status(:conflict)
    expect(proxy.reload.quantity).to eq(9)
  end

  it "removes the proxies of a deck the file drops, counted among the removed (decision 16)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    data = export.merge("decks" => [], "proxies" => [], "lots" => [])
    preview(data)
    expect(html.at_css("label.c-check").text).to include("1 deck and 1 proxy")

    apply(confirm: true)

    expect([ Deck.count, Deck::Proxy.count ]).to eq([ 0, 0 ])
  end

  it "leaves the proxies of a version 3 file's collector alone and says so (AC-7.8)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    v3 = export.except("proxies", "decks").merge("format_version" => 3, "lots" => [])
    v3["lots"] = []

    preview(v3)

    expect(html.at_css("#decks_stay").text).to include("so your decks would stay")
    expect(html.at_css("#decks_stay").text).to include("This file was written before proxies existed, so your proxies would stay.")
    expect(html.at_css("#proxies")).to be_nil
  end

  it "lists a proxy row with problems as 'Proxy N', says the file can't be applied, and stores nothing (AC-7.6)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)

    preview(export.merge("proxies" => [ export["proxies"].first.merge("quantity" => 0) ]))

    expect(response).to have_http_status(:ok)
    expect(html.text).to include("This file can't be applied")
    expect(html.at_css("#problem_proxies li .c-import__number").text).to eq("Proxy 1")
    expect(html.at_css("#problem_proxies li").text).to include("quantity isn't valid")
    expect(account.reload.import_upload).to be_nil
  end

  it "refuses a version 4 file without proxies as not well-formed (AC-7.5)", :aggregate_failures do
    preview(export.except("proxies"))

    expect(response).to have_http_status(:unprocessable_content)
    expect(html.text).to include("proxies")
  end
end
```

- [ ] **Step 2: Run, confirm it fails** (no Proxies section; apply doesn't write proxies).
- [ ] **Step 3: The apply**, `app/models/collection_import/apply.rb`. In `call`'s `decide(upload, import, rows_to_write(import))` pass the proxy attributes too: `decide(upload, import, rows_to_write(import), proxy_attributes(import))`, and in `decide`'s signature and its `write!(plan, rows, proxies)` call. Add:

```ruby
    # Every proxy row to write, built before the lock: the deck's comparison key and the zone's key (resolved to the zone's id
    # once the decks and zones are written), the entry's id, the finish and the quantity.
    def proxy_attributes(import)
      return [] unless import.proxies_counted?

      import.proxy_rows.reject(&:problem?).to_h do |row|
        deck_key, zone_key, _type, _source_id, finish = row.identity
        [ row.number, { deck_key:, zone_key:, catalog_entry_id: import.proxy_entry_id(row), finish:, quantity: row.quantity } ]
      end
    end
```

`write!(plan, rows, proxies)` becomes:

```ruby
    def write!(plan, rows, proxies)
      @account.update!(currency: plan.currency_change.to) if plan.currency_change
      plan.removed_lots.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.lots.where(id: ids).delete_all }
      plan.proxies.removed.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.deck_proxies.where(id: ids).delete_all } # Safe: scoped to the account, bound ids; before the zones and decks they sit in
      CollectionImport::DeckChanges.write!(@account, plan.locations, plan.decks)
      places, zones = place_ids, zone_ids
      (plan.added_rows + plan.changed_rows).each_slice(CollectionImport::BATCH_SIZE) do |slice|
        upsert_lots!(slice.map { |row| placed(rows.fetch(row.number), places, zones) })
      end
      (plan.proxies.added + plan.proxies.changed).each_slice(CollectionImport::BATCH_SIZE) do |slice|
        upsert_proxies!(slice.map { |row| proxies.fetch(row.number) }, zones)
      end
      CollectionImport::WorkingState.clear!(@account) if plan.writes_lots?
      @account.user.update!(collection_view: plan.view_change) if plan.view_change
    end
```

and, beside `upsert_lots!`:

```ruby
    PROXY_WRITE_COLUMNS = %i[account_id location_id catalog_entry_id finish quantity created_at updated_at].freeze
    PROXY_ROW_MARKS = "(#{Array.new(PROXY_WRITE_COLUMNS.size, "?").join(", ")})".freeze

    # One multi-row INSERT .. ON CONFLICT per batch on the proxy's identity, setting the quantity, so a changed proxy keeps its
    # id and its `created_at`: what `Deck::Proxy.upsert_all` would write, through placeholders like the lots' (the rows were
    # validated by the reader, so the model's validations are skipped on purpose, spec 028 FR-3; a spec checks the written rows
    # against `Deck::Proxy`). The conflict target is the unique index's expression, which also holds for a NULL finish.
    def upsert_proxies!(attributes, zones)
      now = Time.current
      rows = attributes.map do |row|
        [ @account.id, zones.fetch([ row[:deck_key], row[:zone_key] ]), row[:catalog_entry_id], row[:finish], row[:quantity], now, now ]
      end
      sql = "INSERT INTO deck_proxies (#{PROXY_WRITE_COLUMNS.join(", ")}) VALUES #{Array.new(rows.size, PROXY_ROW_MARKS).join(", ")} " \
        "ON CONFLICT (location_id, catalog_entry_id, COALESCE(finish, '')) DO UPDATE SET quantity = excluded.quantity, updated_at = excluded.updated_at"
      Deck::Proxy.connection.execute(Deck::Proxy.sanitize_sql_array([ sql, *rows.flatten ]))
    end
```

(If SQLite rejects the expression conflict target, use `ON CONFLICT DO UPDATE SET …` without a target: it is allowed on the last clause and takes the one unique index as the conflict; the spec in Step 1 proves either works.) Update the class comment ("its lots, locations, decks, proxies, view and currency") and the `write!` comment.
- [ ] **Step 4: The controller's notice**, `app/controllers/collections/imports_controller.rb`: in `notice_for` add `proxy_sentence(plan.proxies)` after `deck_sentence`, and the method:

```ruby
    # "2 proxies added, 1 changed, 1 removed", the same way (rows); nil for a file older than version 4 and when no proxy
    # changes (spec 068 decision 16).
    def proxy_sentence(proxies)
      return unless proxies.counted?

      sentence("proxy", proxies.counts.slice(:added, :changed, :removed))
    end
```

and make `sentence` pluralise "proxy" right: `helpers.pluralize(count, noun)` gives "proxies" ✓ (`pluralize(2, "proxy")`).
- [ ] **Step 5: The helpers**, `app/helpers/import_previews_helper.rb`: add

```ruby
  # Set code and number, language, finish and place of a proxy as the preview writes it: "MH2 · 138 · EN · Foil · in Izzet Tempo › Main".
  def import_proxy_line(set_code:, collector_number:, language:, finish:, place:)
    [ [ set_code&.upcase, collector_number ].compact.join(" · ").presence, language&.upcase, finish&.humanize, ("in #{place}" if place) ].compact.join(" · ")
  end
```

and in the private `import_removed_places_and_decks` add, after the decks part: `parts << pluralize(number_with_delimiter(plan.proxies.removed.size), "proxy") if plan.proxies.removes?`; update the two doc comments ("… 1 deck and 4 proxies").
- [ ] **Step 6: The views.** `app/views/collections/import_previews/_proxies.html.erb`:

```erb
<%# locals: (import:) %>
<% proxies = import.plan.proxies %>
<% if proxies.counted? %>
  <section id="proxies">
    <div class="c-section__head"><h2 class="c-section__title">Proxies</h2></div>
    <dl class="c-stats">
      <div class="c-stat"><dt>Proxies added</dt><dd><%= number_with_delimiter(proxies.added.size) %></dd></div>
      <div class="c-stat"><dt>Proxies changed</dt><dd><%= number_with_delimiter(proxies.changed.size) %></dd></div>
      <div class="c-stat"><dt>Proxies unchanged</dt><dd><%= number_with_delimiter(proxies.unchanged) %></dd></div>
      <div class="c-stat"><dt>Proxies removed</dt><dd><%= number_with_delimiter(proxies.removed.size) %></dd></div>
    </dl>
    <% if proxies.removed.any? %>
      <ul class="c-list c-import__list" id="removed_proxies">
        <% proxies.listed_removed.each do |proxy| %>
          <li>
            <span><%= proxy.name %> <span class="c-list__meta"><%= import_proxy_line(**proxy.described) %></span></span>
            <span class="c-list__end">×<%= number_with_delimiter(proxy.quantity) %></span>
          </li>
        <% end %>
      </ul>
      <% if proxies.more_removed.positive? %><p class="c-import__more">and <%= number_with_delimiter(proxies.more_removed) %> more</p><% end %>
    <% end %>
  </section>
<% end %>
```

In `show.html.erb`: render it after the decks partial: `<%= render "collections/import_previews/proxies", import: @import %>`; add the proxy problem section after the lot problem section:

```erb
    <% if @import.proxy_problem_rows.any? %>
      <section>
        <div class="c-section__head"><h2 class="c-section__title">Proxies with problems</h2><span class="c-section__count"><%= pluralize(number_with_delimiter(@import.proxy_problem_rows.size), "proxy", "proxies") %></span></div>
        <ul class="c-list c-import__list" id="proxy_problem_counts">
          <% @import.proxy_problem_counts.each do |summary, count| %>
            <li><span><%= summary %></span><span class="c-list__end"><%= pluralize(number_with_delimiter(count), "row") %></span></li>
          <% end %>
        </ul>
        <ol class="c-list c-import__list c-import__rows" id="problem_proxies">
          <% @import.listed_proxy_problem_rows.each do |row| %>
            <li>
              <span class="c-import__number">Proxy <%= number_with_delimiter(row.number) %></span>
              <span><%= row.name %> <span class="c-list__meta"><%= import_proxy_line(**row.described) %></span></span>
              <div class="c-import__reasons"><% row.problems.each do |problem| %><p><%= problem.reason %></p><% end %></div>
            </li>
          <% end %>
        </ol>
        <% if @import.more_proxy_problem_rows.positive? %><p class="c-import__more">and <%= number_with_delimiter(@import.more_proxy_problem_rows) %> more</p><% end %>
      </section>
    <% end %>
```

and the "can't be applied" message's row count becomes `@import.problem_rows.size + @import.proxy_problem_rows.size` ("N rows have problems"), its `one? ? "has" : "have"` read from that sum. In `_decks.html.erb`'s `else` branch: `<p class="c-import__note" id="decks_stay"><%= import_decks_stay(import.plan) %> This file was written before proxies existed, so your proxies would stay.</p>`.
- [ ] **Step 7: Run** `bin/rspec spec/requests/collection_import_proxies_spec.rb spec/requests/collection_import_previews_spec.rb spec/requests/collection_imports_spec.rb spec/models/collection_import`: pass. The existing examples that assert the whole notice, the confirmation label or the decks-stay paragraph keep their text for files with no proxy; the decks-stay paragraph gains the proxy sentence, so each existing assertion of it becomes `include(...)`/the new full text: change those assertions in this commit, one assertion each.
- [ ] **Step 8: Commit** `feat(import): preview and apply a file's proxies (spec 068 T18)`.

### T19: The bars, the working state and the written rows

- [ ] **Step 1: The timing spec** `spec/requests/collection_import_proxy_timing_spec.rb`: copy `spec/requests/collection_import_deck_timing_spec.rb` and change: the describe to `"Import and export timing with proxies"`, add `let(:proxies) { 20_000 }`, and in `build_file(quantity:)` add before the final hash:

```ruby
    proxy_rows = (1..proxies).map do |i|
      { "deck" => deck_names[i % decks], "zone" => zone_keys[i % 3], "entry" => { "collectible_type" => "mtg", "source_id" => "bulk-#{i}", "name" => "Card #{i}", "set_code" => "bulk", "collector_number" => i.to_s, "language" => "en" },
        "finish" => "foil", "quantity" => quantity }
    end
```

and `"proxies" => proxy_rows` after `"decks" => …` in the returned hash; the scenario's counts line becomes `expect([ user.account.lots.count, user.account.decks.count, user.account.deck_proxies.count ]).to eq([ lots, decks, proxies ])`, the export's `expect(JSON.parse(response.body).values_at("lots", "proxies").map(&:size)).to eq([ lots, proxies ])`, and the message line names the proxies. The bars and their assertions are unchanged (preview under 30 s and 500 MB; apply under 30 s with the write transaction under 4 s; export under 10 s). Note the entries are the same 50,000 the lots use, so the proxies' `source_id`s resolve; the (deck, zone, entry, finish) identities are unique because `i` is. Run it once with `SCANNER_TIMING=1 bin/rspec spec/requests/collection_import_proxy_timing_spec.rb` and record the numbers in `verification.md` (T24); a missed bar is a finding to report, never a threshold to move.
- [ ] **Step 2: The written rows** — a model spec that proves the bulk statements wrote what the model would accept, in `spec/requests/collection_import_proxies_spec.rb`:

```ruby
  it "writes rows the model accepts, with an account, a zone of a deck, a listed finish and a quantity in range (AC-7.10)", :aggregate_failures do
    deck
    data = export.merge("proxies" => [ { "deck" => "Izzet Tempo", "zone" => "main", "entry" => entry_hash(entry), "finish" => "foil", "quantity" => 7 } ])
    preview(data)

    apply

    proxy = Deck::Proxy.sole
    expect(proxy.valid?).to be(true)
    expect([ proxy.account, proxy.zone, proxy.entry, proxy.finish, proxy.quantity ]).to eq([ account, deck.zone("main"), entry, "foil", 7 ])
    expect(proxy.created_at).to be_within(1.minute).of(Time.current)
  end

  it "clears no working state for a proxy-only change (AC-7.11)", :aggregate_failures do
    deck
    NumberEntry.add!(account:, entry:, quantity: 1, finish: "foil", line_key: SecureRandom.hex(16))
    data = export.merge("decks" => [ { "name" => "Izzet Tempo", "collectible_type" => "mtg", "format" => "modern" } ],
                        "proxies" => [ { "deck" => "Izzet Tempo", "zone" => "main", "entry" => entry_hash(entry), "finish" => "foil", "quantity" => 1 } ])
    preview(data)

    apply

    expect(account.reload.number_entry).to be_present
    expect(Deck::Proxy.count).to eq(1)
  end
```

And the other half, a file that also changes a lot:

```ruby
  it "clears the working state when the same file also changes a lot (spec 028 decision 7)", :aggregate_failures do
    deck
    NumberEntry.add!(account:, entry:, quantity: 1, finish: "foil", line_key: SecureRandom.hex(16))
    data = export.merge("decks" => [ { "name" => "Izzet Tempo", "collectible_type" => "mtg", "format" => "modern" } ],
                        "proxies" => [ { "deck" => "Izzet Tempo", "zone" => "main", "entry" => entry_hash(entry), "finish" => "foil", "quantity" => 1 } ],
                        "lots" => [ { "entry" => entry_hash(entry), "quantity" => 2, "finish" => "foil", "condition" => nil, "price_paid" => nil, "location" => nil,
                                     "added_at" => "2026-11-01T10:00:00Z", "changed_at" => "2026-11-01T10:00:00Z" } ])
    preview(data)

    apply

    expect(account.reload.number_entry).to be_nil
    expect(Deck::Proxy.count).to eq(1)
  end
```

- [ ] **Step 3: Run** both files; fix by reading failures. The written-rows and working-state examples guard behaviour T18 built, so they pass on their first run: run each once with the line it guards broken (the `CollectionImport::WorkingState.clear!` condition made `true`; the `quantity` column dropped from `upsert_proxies!`'s update set) to see it fail, then restore it. **Step 4: Commit** `test(import): the proxy bars, the written rows and the working state (spec 068 T19)`.

---

## Phase 7: The guards

**Implements:** Story 8, FR-1 | **Satisfies:** AC-8.3 to AC-8.7, AC-4.2, AC-4.3, AC-2.10, AC-5.3
**Files:** `spec/deck_core_spec.rb`, `spec/requests/query_counts_spec.rb`, `spec/requests/deck_proxy_tenancy_spec.rb`, `spec/models/lot_proxy_isolation_spec.rb`, `script/upgrade/seeds/next.rb`, `docs/backup-restore.md` (only if it lists tables), `docs/releasing.md`

### T20: Never owned, never changed by a copy; tenancy; the core guard

- [ ] **Step 1: The specs.** `spec/models/lot_proxy_isolation_spec.rb` (AC-4.2, AC-4.3):

```ruby
require "rails_helper"

# Spec 068 decision 11 (closing spec 065 decision 11): no way of adding, moving, editing, bulk-moving, typing, scanning or
# removing a copy changes a proxy, and a catalog refresh doesn't either. The proxy is checked by id, quantity and times.
RSpec.describe "Proxies and the ways copies reach a zone", type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }
  let(:entry) { create(:mtg_printing).entry }
  let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 3) }

  def unchanged? = Deck::Proxy.sole.slice(:id, :quantity, :updated_at) == proxy.slice(:id, :quantity, :updated_at)

  it "leaves the proxy as it is when a copy is added, moved, edited, bulk-moved, typed in, scanned in or removed", :aggregate_failures do
    lot = Lot.add!(account:, entry:, quantity: 2, finish: "foil", location: deck.zone("main"))
    expect(unchanged?).to be(true)
    elsewhere = create(:location, account:)
    Lot::Move.new(lot:, to: elsewhere, copies: "1").call!
    Lot::Move.new(lot: Lot.find_by!(location: elsewhere), to: deck.zone("main"), copies: "1").call!
    expect(unchanged?).to be(true)
    lot.reload.revise!(quantity: 4)
    expect(unchanged?).to be(true)
    Lot::BulkMove.new(account:, lots: account.lots, to: deck.zone("sideboard"), sort: CollectionTable::Sort.parse(nil, nil)).apply!
    expect(unchanged?).to be(true)
    NumberEntry.add!(account:, entry:, quantity: 1, finish: "foil", line_key: SecureRandom.hex(16), location: deck.zone("main"))
    expect(unchanged?).to be(true)
    account.lots.destroy_all
    expect(unchanged?).to be(true)
    expect(Deck::Proxy.count).to eq(1)
  end

  it "survives a catalog refresh that retires the printing (AC-4.3)", :aggregate_failures do
    entry.update!(retired_at: Time.current)

    expect(unchanged?).to be(true)
    expect(proxy.reload.entry).to eq(entry)
  end
end
```

(`NumberEntry.add!` is called with the keywords the upgrade seed uses (`account:, entry:, quantity:, finish:, line_key:`); add `location:` only if its signature takes it (`grep -n "def self.add!" app/models/number_entry.rb`); otherwise drop that argument. `Lot::Move.new(...).call!` is as `Lots::MovesController` uses it. Read each signature before writing the example.)

`spec/requests/deck_proxy_tenancy_spec.rb` (AC-8.3): one example per page and verb proving another account's deck, zone key or proxy answers 404 and writes nothing, as T8's and T10's 404 examples do, but run from the **other** account's session, plus the admin pages:

```ruby
require "rails_helper"

# Spec 068 AC-8.3: another account's deck, zone and proxy are 404 on every proxy page and verb, and no admin page shows one.
RSpec.describe "Proxy pages and tenancy", type: :request do
  let(:owner) { create(:user) }
  let(:deck) { create(:deck, account: owner.account, name: "Izzet Tempo") }
  let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account: owner.account, entry: create(:mtg_printing).entry, finish: "foil", quantity: 2) }
  let(:stranger) { create(:user) }

  before { sign_in_as(stranger) }

  it "is 404 for another account on every page and verb, and writes nothing", :aggregate_failures do
    [ [ :get, new_deck_zone_proxy_path(deck, "main") ], [ :get, new_deck_zone_proxy_path(deck, "main", entry: proxy.entry.external_key) ],
      [ :post, deck_zone_proxies_path(deck, "main") ], [ :get, edit_deck_proxy_path(deck, proxy) ], [ :patch, deck_proxy_path(deck, proxy) ],
      [ :get, new_deck_proxy_removal_path(deck, proxy) ], [ :delete, deck_proxy_path(deck, proxy) ] ].each do |verb, path|
      public_send(verb, path, params: { proxy: { entry: proxy.entry.external_key, finish: "foil", quantity: "5" } })
      expect(response).to have_http_status(:not_found), "#{verb} #{path}"
    end
    expect(proxy.reload.quantity).to eq(2)
    expect(Deck::Proxy.count).to eq(1)
  end

  it "shows no proxy, deck or location on an admin page (hosted-door rule 2)", :aggregate_failures do
    admin = create(:admin)
    sign_in_as(admin)

    get admin_users_path

    expect(response.body).not_to include("Izzet Tempo")
  end
end
```

(If `admin_users_path` or the `admin: true` attribute are named otherwise, use what `spec/requests/admin_users_spec.rb` uses.)

- [ ] **Step 2: `spec/deck_core_spec.rb`:** add to `patterns` (a shared file: keep the edit to these lines, so a second branch merges by summing the count): `app/controllers/decks/proxies/*.rb app/controllers/concerns/finds_deck.rb app/models/deck/proxy/*.rb app/models/collection_import/proxies.rb app/models/collection_import/proxy_rows.rb app/views/collections/import_previews/_proxies.html.erb`; and change the count to `20 + 6 + 1 + 1 + 4 + 1 + 15` with the trailing comment "spec 068 adds 15: `deck/proxy.rb` and the proxies controller (the globs already cover them), the six proxy views under `app/views/decks`, `decks/proxies/removals_controller.rb`, `deck/proxy/addition.rb` and `cap_exceeded.rb`, `finds_deck.rb`, the import's `proxies.rb` and `proxy_rows.rb`, and the preview's `_proxies.html.erb`". Run the spec first: it fails by the real number of files; the arithmetic must equal what `files.size` reports (recount: if it isn't 48, the sum above is wrong, not the glob, and the comment names the files found). `spec/collection_export_core_spec.rb` already lists `collection_export.rb`; `spec/collection_import_core_spec.rb` and `spec/import_apply_core_spec.rb` list their files explicitly, so add to the first's `files` the new `app/models/collection_import/proxies.rb`, `app/models/collection_import/proxy_rows.rb` and `app/views/collections/import_previews/_proxies.html.erb` (AC-7.14), and to the second's `app/models/collection_import/proxies.rb`; each file names no collectible, a source, a format key or a zone key other than `considering`.
- [ ] **Step 3: The query-count spec**, `spec/requests/query_counts_spec.rb`: add an example that the deck page and the Decks page run the same number of statements with 1 and with 6 proxies (AC-2.10, AC-5.3), modelled on the file's neighbouring examples:

```ruby
  it "keeps the deck page's and the Decks page's queries the same with six proxies as with one (spec 068 AC-2.10, AC-5.3)", :aggregate_failures do
    deck = create(:deck, account: user.account, name: "Izzet Tempo")
    create(:deck_proxy, zone: deck.zone("main"), account: user.account)
    paths = [ deck_path(deck), decks_path ]
    with_one = paths.map { |path| queries_for(path) }

    5.times { |n| create(:deck_proxy, zone: deck.zone(%w[main sideboard considering][n % 3]), account: user.account) }

    expect(paths.map { |path| queries_for(path) }).to eq(with_one)
  end
```

(`queries_for` and `user` are the file's own helpers.)
- [ ] **Step 4: Run** the three files and `bin/rspec spec/deck_core_spec.rb spec/models/account_spec.rb spec/backup_guards_spec.rb`. The isolation and tenancy examples guard behaviour built in Phases 0 to 3, so they pass on their first run: run each once with the rule it guards broken (for the isolation example, make `Lot.add!` touch `Deck::Proxy.update_all(updated_at: Time.current)`; for the tenancy one, find the deck without `Current.account`) to see it fail, then restore it. **Step 5: Commit** `test(decks): proxies are never owned, tenant-scoped and core-clean (spec 068 T20)`.

### T21: The upgrade seed, the backup and the release notes

- [ ] **Step 1:** in `script/upgrade/seeds/next.rb`, after the deck's lot line add:

```ruby
# A proxy beside the deck's lot, so the next release's upgrade proof carries `deck_proxies` across (spec 068 AC-8.6, spec 031's coverage rule).
Deck::Proxy.add!(account: ada.account, zone: deck.zone("sideboard"), entry: entries.first, finish: "foil", quantity: 2)
```

- [ ] **Step 2:** run `ruby script/upgrade/guard.rb` (no released migration changed) and read `script/upgrade/rules.rb` and `docs/specs/031-upgrade-from-previous-release/contracts/yaml-files.md` for the coverage rule: if it requires `deck_proxies` to appear in `seed_exceptions.yml` or to be named in the seed's facts, make that edit (a one-line entry, or the proxy count in `facts`) and say which in the commit. The migration needs no `expected_changes.yml` entry (it changes no data a release holds). The upgrade smoke itself needs a container engine and runs in CI (not a `bin/ci` step).
- [ ] **Step 3: The backup.** `spec/backup_guards_spec.rb` needs nothing (no attachment, no fifth database). Run `grep -n "decks\|lots" docs/backup-restore.md README.md | head`: if a document lists the primary database's tables, add `deck_proxies` beside `decks`; if none does, record in `verification.md` that the backup document needed no change (AC-8.5).
- [ ] **Step 4: The upgrade notes**, `docs/releasing.md`, "Upgrade notes" (newest first): add

```markdown
- **Proxies (spec 068).** One migration, `CreateDeckProxies`, runs on boot; it creates the `deck_proxies` table and changes nothing else. A collector records the cards a deck's zone needs and they don't own as proxies; an export now carries them as `proxies` in format version 4, which no release had shipped before, so a version 4 file written by a development build before this change (an `edge` image) has no `proxies` and is refused as not well-formed. Nothing is required of the operator; the backup includes the table with the primary database.
```

- [ ] **Step 5: Run** `bin/rspec spec/backup_guards_spec.rb spec/models/account_spec.rb` and `ruby script/upgrade/guard.rb`. **Step 6: Commit** `chore(upgrade): the next seed carries a proxy, and the upgrade note (spec 068 T21)`.

---

## Phase 8: Documentation and the review's evidence

**Implements:** Story 9 (AC-9.2, AC-9.3), the NFR "Design system and documentation" | **Satisfies:** AC-9.2, AC-9.3, AC-8.5
**Files:** `docs/design-system/components/DeckPage.md`, `DecksIndex.md`, `ProxyTag.md`, `AddProxy.md` (new), `docs/design-system/previews/AddProxy.html`, `AddProxyPhone.html` (new), `docs/design-system/README.md`, `app/assets/stylesheets/collector/additions.css` (comments only, unless a rule was needed), `docs/architecture/collection-and-lots.md`, `data-portability.md`, `tenancy-and-accounts.md`, `CLAUDE.md`, `docs/specs/README.md`, `docs/specs/068-deck-proxies/verification.md`
**Interfaces:** none (documents).

The supervisor writes these (no implementer subagent), each statement with its source (spec criterion, ADR or issue) inline, as `.claude/rules/documentation.md` asks. Prose documents are verified by reading, never by RSpec (the export format document, done in T14, is the one exception).

### T22: The design system

- [ ] **Step 1: `DeckPage.md`.** Replace the "As built (spec 066, #253, until #254)" paragraph with "As built (spec 068, #254): the page head's line reads `Format · N cards · N owned · N proxy`; a zone's head is its name, `N cards · N owned · N proxy` and "Add a proxy" (a link); the table has Card, Cost, Owned, Proxy, Total and the row menu; a row with proxies shows the `ProxyTag` and its menu has "Change proxy count" and "Remove proxy" (the finish named when a row has proxies of two finishes); a row with no proxy has an empty menu cell; Total is owned plus proxy; the card name links to the card page at its copies. "Use my copy" and "Add a new copy" come with #257." Then fix the sentences that still say "not built until #254" (the row menu paragraph: it now lists only the proxy items, and says the order: the changes, a separator, the removals), the zone head paragraph (the counts and "Add a proxy" are live), and the "Do not add a column" rule (it stands). Source: spec 068 decisions 5, 7, 8.
- [ ] **Step 2: `DecksIndex.md`.** Replace the as-built note's "no Proxy column" clause with the Proxy column (the tag or a muted dash); the phone fold reads "Modern · 58 owned" then the tag; "Cards counts every zone, owned plus proxy" (drop "Owned is the same number until proxies exist"). Source: spec 068 decision 7, AC-5.1, AC-5.2.
- [ ] **Step 3: `ProxyTag.md`.** Add the live uses (the zone table's Proxy cell and the phone line, the Decks list's Proxy cell and phone line) and delete "until #254" wording; keep the card page's plain count rule. Source: spec 068 AC-2.1, AC-2.4, AC-5.1.
- [ ] **Step 4: `AddProxy.md` (new)**, in the shape of `AddToDeck.md`: the chooser (a `c-pagehead`, the card search's `c-filterbar`, results as `c-group` sections each a `c-list` of printings with a "Choose" button), the form (Finish select with "Choose…", Quantity number field, "Add proxy", "Cancel"), the change page (the proxy named, a Quantity field, "Save", "Cancel"), the removal page (`c-confirm`, "Remove", "Cancel"); each page's markup copied from `app/views/decks/proxies/**`, the errors (`c-field__error` under the field, the sentences of AC-1.8, AC-1.9, AC-3.3), the empty states ("Type part of a card name to search.", "No cards match…"), the "Showing 10 of 24 printings…" line, and that it adds no CSS class. Source: spec 068 decisions 3, 6, AC-9.2.
- [ ] **Step 5: Previews** `docs/design-system/previews/AddProxy.html` and `AddProxyPhone.html`: copy `AddToDeck.html` and `AddToDeckPhone.html` (they link `preview-fonts.css`, `tokens.css`, `components.css`, `additions.css` in that order), keep the shell and app bar, and replace the `main` with the form page's markup from `AddProxy.md` (wide) and the same in a 390px frame (phone). Open each in the headless Firefox helper of `.claude/skills/collector-design-system` (or the system spec's frame) in both themes and fix any overflow.
- [ ] **Step 6: README.** In "Components" add `AddProxy` to the full screens (`AddToDeck`, `UseMyCopy`, `AddProxy`) and the App additions line: "(spec 060, spec 068: no new class)". In the Decks section, the vocabulary sentence for proxy: "a proxy is recorded in a zone, shown with the dashed tag, counted in a deck's cards and never in Owned".
- [ ] **Step 7: `additions.css` comments.** Update the comment on `.c-zone td:first-child` (line ~492): "the Card column is 128px with the menu column (spec 060, built by spec 068)…" (drop "and 192px on the deck page until #254 adds the menu"). A comment-only change keeps the rule count `spec/design_system_files_spec.rb` reads. Run `bin/rspec spec/design_system_files_spec.rb spec/system/design_system_deck_components_spec.rb`.
- [ ] **Step 8: Commit** `docs(design-system): proxies on the deck page, the Decks page and the add-a-proxy pages (spec 068 T22)`.

### T23: The area docs, `CLAUDE.md` and the index

- [ ] **Step 1: `docs/architecture/collection-and-lots.md`.** Scope: add `Deck::Proxy`, `Deck::Proxy::Addition`, `Decks::ProxiesController`, `Decks::Proxies::RemovalsController` and `FindsDeck` to the decks bullet with "spec 068"; Glossary: **Proxy** ("one row of `deck_proxies`: one zone, one printing, one finish and a quantity of 1 to 9,999; never a lot; spec 068 decision 1") and **Cards** (owned plus proxy, spec 060 decision 12); Invariants: replace "A copy that reaches a zone through a picker never changes a proxy. There are no proxies yet…" with "**A proxy is never owned and changes only by hand**: no way of adding, moving, editing, bulk-moving, typing, scanning or removing a copy, no import of lots and no catalog refresh creates, changes or removes one; the writers are the add, change and remove pages, a format change, a deck's removal and an import that carries proxies (spec 068 decision 11, AC-4.2, AC-4.3; closes spec 065 decision 11)", add proxies to "A deck and its zones are written…" (a format change moves a dropped zone's proxies into Considering in the same transaction), the "core names no collectible" bullet's `spec/deck_core_spec.rb` count (33 to 48, and the new files), and the "Lists cost a bounded number of queries" bullet (the deck page 6 statements, 3 with none; the Decks page one grouped read more); States and transitions: the Decks page's columns (Cards = owned plus proxy, Owned, Proxy), the deck page paragraph (heads, columns, menu, rows of proxy-only printings), the Change format row (the notice's proxy sentence, the proxy cap refusal), the Remove row (the confirmation names the proxies; a deck of only proxies is removable), and a new table "A proxy" with the add, change and remove rows (URLs, sentences, merge, cap) and the chooser's rules (a search of the deck's collectible type, 12 cards a page, 10 printings a card). Sources: spec 068 and #254. Distillation log: a row "2026-11-11 | Spec 068 (proxies: the table, the deck and Decks pages, the add, change and remove pages, the format change, the removal) | spec 068's pull request" (the pull request's number replaces the words after the merge, as spec 066's row did).
- [ ] **Step 2: `docs/architecture/data-portability.md`.** Scope: "Version 4: decks, proxies and a lot in a deck's zone"; Glossary: **Proxy** (a file's proxy `{ deck, zone, entry, finish, quantity }`, its five-value identity), the "same collection" sentence (proxies as sets); Invariants: version 4 "adds `decks`, a lot's zone and `proxies`", "No internal id…" (a proxy is its deck's name and its zone's key), "A new table with `account_id`…" (`deck_proxies` listed with version 4), "A version 1 to 3 file leaves the decks and removes the copies in them" gains "and leaves their proxies, which it can name none of", "Applying is all or nothing… replaces the collection, the locations, the decks and the proxies", the decks'-name-space bullet unchanged; the export section (the `proxies` list, its one statement and its order); Reading a file: the rows (a required `proxies` list: header refusal naming `proxies`; `duplicate_proxy` and `unknown_location` at `/proxies/N` as row problems, `unknown_type`, `not_in_catalog`, `finish_not_listed`, `unknown_zone` the reader's; a null finish never a problem; no type comparison) and a Proxy row problems table; Outcomes: the proxies table (added, changed, unchanged, removed; counts are rows; the held-by-a-problem-row case counts as removed); the preview page (the Proxies section, "Proxies with problems", the decks-stay paragraph's proxy sentence); the apply (the removed proxies are deleted with the removed lots, the upsert on the unique index's expression after the lots, the working state cleared only by a lot, the confirmation text and the notice's proxy part); the fingerprint (the proxies' part, version 4 only); Named constants (none new, say so); Decisions not in an ADR: "Version 4 gained `proxies` before any release wrote it; `proxies` is required; an `edge`-written version 4 file without it is refused (maintainer, 2026-11-11; spec 068 decision 14)" and "An older file leaves proxies alone (spec 068 decision 15)"; delete the accepted limit that no longer holds if any; Sources and Distillation log as above.
- [ ] **Step 3: `docs/architecture/tenancy-and-accounts.md`.** The tenant-owned table list gains `deck_proxies` (spec 068 AC-8.1); the deck-routes bullet gains the proxy routes ("`Decks::ProxiesController` and `Decks::Proxies::RemovalsController` find the deck by its location id through the account (`FindsDeck`), the zone by its key within it and the proxy by its id among the deck's; another account's deck, a place's or a zone's id, an id that isn't digits only, a zone key the deck lacks and another deck's proxy are 404", AC-1.7, AC-3.6, AC-8.3); the account-deletion paragraph gains "`deck_proxies` go through the foreign keys, with `Account` still deleting lots before locations (AC-8.4)"; Sources and log.
- [ ] **Step 4: `CLAUDE.md`.** Project Status: in the decks sentence add "a collector records the cards a deck's zone needs and doesn't own as proxies, shown beside the owned copies and counted in a deck's cards (`Deck::Proxy`, spec 068), moved into Considering by a change of format, carried by the export (format version 4 now has `proxies`)"; the "Collection and lots" non-obvious bullet's spec list gains 068 and its decks clause ends "and the deck files (the deck page's `Catalog::DeckCards` seam among them)… (`spec/deck_core_spec.rb`)" unchanged; the "Export format and import" bullet gains "version 4 carries `proxies` (spec 068)". Keep each edit a clause, not a restated rule (`.claude/rules/documentation.md`).
- [ ] **Step 5: `docs/specs/README.md`.** Spec 068's row stays "Approved" until the distillation step (T24); the supersession cells are already in both directions (recorded at spec time).
- [ ] **Step 6: Commit** `docs(architecture): proxies in the area docs and CLAUDE.md (spec 068 T23)`.

### T24: `verification.md`

- [ ] **Step 1:** write `docs/specs/068-deck-proxies/verification.md` with: a table of every AC and the spec example that proves it (from the coverage table below, with the real file and example name once written), the measured numbers of T19's timing example (seconds, resident growth, peak, write transaction, for the preview, the apply, the second apply and the export) with the harness's note on memory, the statement counts of AC-2.10, AC-5.3 and AC-7.2 as measured, the screenshots listed in Step 2, and a "Documents verified by reading" list (the area docs, the design-system docs, `docs/export-format/README.md`, `docs/releasing.md`'s upgrade note, the backup document check of AC-8.5).
- [ ] **Step 2: Screenshots** (kept in `docs/specs/068-deck-proxies/screenshots/`, per the project's PR-screenshot workflow in memory): the deck page with proxies at 360px and 1280px, light and dark; the chooser, the form, the change page and the removal page at 390px light; the Decks page with proxies at 1280px; the import preview's Proxies section. Seed one deck of Modern with a proxy row (foil and nonfoil of one printing), an owned-and-proxy row and a proxy-only row.
- [ ] **Step 3:** the `## Implementation review` heading (verdict on its first line) is written by the review step after execution (`sdd-review` Mode B); do not write it here.
- [ ] **Step 4: Commit** `docs(specs): verification of spec 068 (T24)`.

---

## Integration Verification

Before the implementation review, in this order (the supervisor, not an implementer):

1. `bin/rspec` for the files this plan names (every `spec/**/*proxy*`, `spec/models/deck`, `spec/requests/deck*`, `spec/requests/collection_import*`, `spec/export_format*`, `spec/models/export_format`, `spec/models/collection_export_spec.rb`, `spec/system/deck*`, `spec/deck_core_spec.rb`, `spec/backup_guards_spec.rb`, `spec/design_system_files_spec.rb`): green.
2. `bin/rubocop` and `bin/brakeman`: clean (a Brakeman warning on the `update_all`/`delete_all` or the raw `INSERT` is answered by the comment the line carries, as the lots' upsert's is).
3. `bin/yard doc` builds with no warning, and the comment ratchet passes (`bin/ci checks`): every public class and method this plan adds has a summary.
4. A full `bin/ci` under a slot from the coordinator (ask before; release after with the SHA and result).
5. The timing example with `SCANNER_TIMING=1` once, numbers into `verification.md`.
6. `ruby script/upgrade/guard.rb`; the upgrade smoke runs in CI.
7. The pre-push hook runs the full `bin/ci`: ask for a slot before the first push.

## Quickstart Validation

With the dev server (`bin/dev`, the worktree's port) and a catalog loaded:

1. Sign in, make a Modern deck, open it. Each zone's head has "Add a proxy"; click it in Main, search "Lightning", choose a printing, pick Foil, quantity 3, add: the deck page reads "3 cards · 0 owned · 3 proxy", Main shows the row with "Proxy 3", Owned 0 and Total 3.
2. Add an owned copy of the same printing to Main through its card page: the row reads Owned 1, Proxy 3, Total 4, and the proxy is unchanged (AC-4.2).
3. Open the row's menu: "Change proxy count" sets 5; "Remove proxy" asks first, then removes; the notices read as AC-3.2 and AC-3.4.
4. Change the deck's format to Commander and back to Modern: the proxy in Sideboard (add one first) moves into Considering with "1 proxy moved to Considering."
5. Download an export: `proxies` lists the deck's proxies; import it into a second account: the proxies are there, and importing it again says "nothing to change".
6. Remove a deck that holds only proxies: the confirmation names them and they go.

## Spec coverage

| Spec item | Task(s) |
|---|---|
| AC-1.1 | T6 (the link), T8 |
| AC-1.2 to AC-1.4, AC-1.7, AC-1.10, AC-1.11 | T7, T8 |
| AC-1.5, AC-1.6, AC-1.8, AC-1.9 | T1, T2, T8 |
| AC-2.1 to AC-2.3, AC-2.8, AC-2.9 | T4, T6 |
| AC-2.4 to AC-2.7, AC-2.11, AC-2.12 | T6 (request and system specs), T22 |
| AC-2.10 | T4, T20 |
| AC-3.1 to AC-3.7 | T3, T10 |
| AC-4.1 | T6 |
| AC-4.2, AC-4.3 | T20 |
| AC-4.4 | T11 |
| AC-5.1, AC-5.2, AC-5.2a | T5, T6 |
| AC-5.3 | T5, T20 |
| AC-5.4, AC-5.5 | T10, T11 |
| AC-6.1 to AC-6.8 | T12, T13 |
| AC-7.1, AC-7.2 | T16 |
| AC-7.3 | T14, T15 |
| AC-7.4 to AC-7.12 | T17, T18 |
| AC-7.13 | T19 |
| AC-7.14 | T16, T17, T20 |
| AC-8.1, AC-8.2, AC-8.4 | T1 |
| AC-8.3, AC-8.7 | T20 |
| AC-8.5, AC-8.6 | T21 |
| AC-9.1 | T9, T10 |
| AC-9.2, AC-9.3 | T22 |
| FR-1 | T1 to T3, T8, T10 |
| FR-2 | T4 to T6 |
| FR-3 | T12, T13 |
| FR-4 | T14 to T19 |
| NFR Performance | T4, T5, T16, T19, T20 |
| NFR Security | T8, T10, T20 |
| NFR Reliability | T1, T21 |
| NFR Accessibility | T6, T9 |
| NFR Design system and documentation | T22, T23 |
