# Plan: Feature 064, Change a Deck's Format

**Spec:** [spec.md](spec.md) v0.2.1 (Approved at Gate A) · **Issue:** [#251](https://github.com/plainprogrammer/Collector/issues/251) · **Branch:** `064-change-deck-format`
**Version:** 0.1.0

## Global Constraints

- Test first: every task writes the failing example, runs it red, then the code, then green. One Conventional Commit per task (`docs/git-convention.md`), each ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; one git operation per shell call, `git add` in a call of its own.
- Deck files name no collectible, no format key and no zone key but `considering` (`spec/deck_core_spec.rb`, matched in comments too: no "Sideboard", "Commander", "Modern", "MTG"). Core words only: "format", "zone", "Considering" as the zone's own registered name (read from the row), never typed.
- New or changed public code carries a YARD comment with a summary (`.claude/rules/code-documentation.md`, `script/yard/comment_ratchet.rb`); no `{…}` in comments outside YARD links; `@see file:collection-and-lots.md` for the area doc.
- `Lot::BulkMove`'s behaviour for places stays exactly as it is (coordinator's note: #252 changes the pickers). Only its comment changes, in the same commit as the first caller.
- Every lookup through `Current.account` and the deck's location id. No `permit!`; `params.expect`.
- Design system: only `c-*` classes and tokens from `app/assets/stylesheets/collector/`; the one new rule goes in `collector/additions.css`.
- Targeted `bin/rspec <file>` runs need no CI slot. Never run two test runs at once in this worktree. A full `bin/ci` or a push needs a slot from the coordinator.

## Goal

A collector changes a deck's format from the Decks page. One transaction makes the deck's zones the new format's, moves the lots of dropped zones into Considering through `Lot::BulkMove`'s merge and cap rules, and the page says how many cards moved.

## Pre-implementation gates

- **Simplicity:** three components: `Deck::FormatChange` (model), `Decks::FormatsController` with its route and view, the row button. No new table, column, seam or dependency. Passed.
- **Anti-abstraction:** `Lot::BulkMove` is reused, not wrapped, so no sixth lot-key builder (spec FR-1). One small extraction: `Deck::Creation.zone_rows` becomes a class method so creation and the change write a zone row's shape in one place. Passed.
- **Integration-first:** the contract is `Deck::FormatChange#save` (below) and the route; model examples come before the controller. Passed.

### Contract

```ruby
change = Deck::FormatChange.new(deck: deck, format: "mtg/commander")  # format: the New deck form's "<type>/<key>"
change.save      # => true | false (false: errors[:format] == "Choose a format.", nothing written)
                 # raises Lot::CapExceeded (with #lot) when a merge would pass 9,999; nothing written; deck reloaded
change.changed?  # => false when the deck already had the format (nothing written)
change.moved     # => Integer, copies moved into Considering
change.considering_name # => the Considering zone's name (read from its row), for the notice
```

Routes: `GET /decks/:deck_id/format/edit` (`edit_deck_format_path`), `PATCH /decks/:deck_id/format` (`deck_format_path`), both `Decks::FormatsController`; `:deck_id` is the deck's location id.

## Phase 1: The change (model)

**Implements:** FR-1, decisions 2–6 | **Satisfies:** AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-1.7, AC-2.1, AC-2.1a, AC-2.2, AC-2.3, AC-2.4, AC-2.5, AC-2.6, AC-2.7, AC-2.8, AC-2.9, AC-2.10, AC-3.1 (the model's half)
**Files:** create `app/models/deck/format_change.rb`, `spec/models/deck/format_change_spec.rb`; modify `app/models/deck/creation.rb`, `app/models/lot/bulk_move.rb` (comment only), `spec/models/deck/creation_spec.rb` (one example)
**Interfaces:** the contract above; `Deck::Creation.zone_rows(location, zones)` (class method, `@api private`).

### Task 1.1: `Deck::Creation.zone_rows` as a class method

- [ ] Add to `spec/models/deck/creation_spec.rb`, inside `RSpec.describe Deck::Creation`, a new `describe ".zone_rows"`:

```ruby
  describe ".zone_rows" do
    it "builds one row per zone, with the normalised name and its comparison key, for one INSERT" do
      deck = create(:deck, account:)
      zones = [ Catalog::Formats::Zone.new(key: "extra", name: "  Extra   Zone ") ]

      rows = described_class.zone_rows(deck.location, zones)

      expect(rows).to match([ a_hash_including(account_id: account.id, parent_id: deck.location_id, kind: "deck_zone", zone: "extra",
        name: "Extra Zone", name_key: "extra zone") ])
    end
  end
```

- [ ] Run `bin/rspec spec/models/deck/creation_spec.rb -e ".zone_rows"`; expect `NoMethodError: undefined method 'zone_rows'` (red).
- [ ] In `app/models/deck/creation.rb` replace the private `zone_rows(location, format)` and its call:

```ruby
      Location.insert_all!(self.class.zone_rows(location, option.format.zones))
```

and add, above `private`:

```ruby
  # The rows of a deck's zones, ready for one `Location.insert_all!` (which skips validations on purpose: the keys and names
  # come from a registration `Catalog::Formats.verify!` checked at boot, and the unique index on (deck, name key) backs
  # them). The one place a zone row's shape is written: creating a deck and changing its format both use it.
  #
  # @api private
  # @param location [Location] the deck's location
  # @param zones [Array<Catalog::Formats::Zone>] the zones to write, in order
  # @return [Array<Hash>]
  def self.zone_rows(location, zones)
    now = Time.current
    zones.map do |zone|
      normal = Location::Name.normalise(zone.name)
      { account_id: location.account_id, parent_id: location.id, kind: "deck_zone", zone: zone.key, name: normal,
        name_key: Location::Name.key(normal), created_at: now, updated_at: now }
    end
  end
```

  and delete the old private `zone_rows`.
- [ ] Run `bin/rspec spec/models/deck/creation_spec.rb`; expect all green.
- [ ] `git add app/models/deck/creation.rb spec/models/deck/creation_spec.rb`, then commit `refactor(decks): write a zone row's shape in one place (#251)`.

### Task 1.2: `Deck::FormatChange`, the zones and the same-format no-op

- [ ] Create `spec/models/deck/format_change_spec.rb`:

```ruby
require "rails_helper"

# Spec 064 Stories 1 and 2: changing a deck's format makes its zones the new format's and moves the lots of dropped zones
# into Considering, all or nothing.
RSpec.describe Deck::FormatChange, type: :model do
  let(:account) { create(:user).account }

  def change(deck, to) = described_class.new(deck:, format: "mtg/#{to}")
  def zone_keys(deck) = deck.zones.pluck(:zone)
  def written = [ Location.count, Deck.count, Lot.count ]

  describe "#save" do
    it "changes the type and format and nothing else when the formats share their zones (AC-1.3, AC-1.4)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")
      lot = create_lot_in_zone(deck, "main", quantity: 3)
      zone_ids = deck.zones.pluck(:id)
      form = change(deck, "pauper")

      expect(form.save).to be(true)

      expect(deck.reload).to have_attributes(collectible_type: "mtg", format: "pauper")
      expect(deck.location_id).to eq(deck.location.id)
      expect(deck.zones.pluck(:id)).to eq(zone_ids)
      expect(lot.reload).to have_attributes(quantity: 3, location_id: deck.zone("main").id)
      expect([ form.changed?, form.moved ]).to eq([ true, 0 ])
    end

    it "drops and adds zones from the deck's rows: Commander to Modern keeps Main and Considering and adds Sideboard (AC-1.5)", :aggregate_failures do
      deck = create(:deck, account:, format: "commander")
      kept = deck.zones.where(zone: %w[main considering]).pluck(:zone, :id).to_h

      expect(change(deck, "modern").save).to be(true)

      expect(zone_keys(deck)).to contain_exactly("main", "considering", "sideboard")
      expect(deck.zones.where(zone: %w[main considering]).pluck(:zone, :id).to_h).to eq(kept)
      expect(deck.zone("sideboard")).to have_attributes(name: "Sideboard", kind: "deck_zone", parent_id: deck.location_id, account_id: account.id)
    end

    it "goes back the other way: Modern to Commander drops Sideboard and adds Commander (AC-1.5)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")

      expect(change(deck, "commander").save).to be(true)

      expect(zone_keys(deck)).to contain_exactly("main", "considering", "commander")
      expect(deck.zone("commander")).to have_attributes(name: "Commander")
    end

    it "rewrites a kept zone's name from the registration, so no unique-index error can happen (AC-1.5)", :aggregate_failures do
      deck = create(:deck, account:, format: "commander")
      deck.zone("main").update_columns(name: "Sideboard", name_key: "sideboard") # a stale name another zone is about to take

      expect(change(deck, "modern").save).to be(true)

      expect(deck.zone("main")).to have_attributes(name: "Main", name_key: "main")
      expect(deck.zone("sideboard")).to have_attributes(name: "Sideboard", name_key: "sideboard")
    end

    it "does nothing for the format the deck already has, writing no row and moving no timestamp (AC-1.6)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")
      create_lot_in_zone(deck, "sideboard", quantity: 2)
      stamps = [ Deck.pluck(:updated_at), Location.pluck(:updated_at), Lot.pluck(:updated_at) ]
      form = change(deck, "modern")

      expect(form.save).to be(true)

      expect([ form.changed?, form.moved ]).to eq([ false, 0 ])
      expect([ Deck.pluck(:updated_at), Location.pluck(:updated_at), Lot.pluck(:updated_at) ]).to eq(stamps)
    end

    it "reads the format under the write lock: a stale deck object that already has the chosen format changes nothing (AC-1.6)" do
      deck = create(:deck, account:, format: "modern")
      stale = Deck.find(deck.id)
      change(deck, "pauper").save!

      form = change(stale, "pauper")

      expect { form.save }.not_to change { [ Location.count, Lot.count ] }
      expect(form.changed?).to be(false)
    end

    it "changes a deck whose format the instance no longer registers, judging by its zone rows (AC-1.7)", :aggregate_failures do
      deck = create(:deck, account:, format: "commander")
      create_lot_in_zone(deck, "commander", quantity: 2)
      deck.update!(format: "retired")

      form = change(deck, "modern")

      expect(form.save).to be(true)
      expect(form.moved).to eq(2)
      expect(deck.reload.format).to eq("modern")
    end

    it "refuses a blank, unregistered or foreign-key format with 'Choose a format.' and writes nothing (AC-3.1)", :aggregate_failures do
      deck = create(:deck, account:, format: "modern")

      [ "", "modern", "nope/modern", "mtg/nope" ].each do |value|
        form = described_class.new(deck:, format: value)
        expect { expect(form.save).to be(false) }.not_to change { [ written, deck.reload.format ] }
        expect(form.errors[:format]).to eq([ "Choose a format." ])
      end
    end
  end
end
```

- [ ] Run `bin/rspec spec/models/deck/format_change_spec.rb`; expect `NameError: uninitialized constant Deck::FormatChange` (red).
- [ ] Create `app/models/deck/format_change.rb` with the zones part (`move_lots!` is an empty method that Task 1.3 fills; the examples that move lots are Task 1.3's):

```ruby
# Changes a deck's format (spec 064): the deck's zones become the new format's, the lots in a zone the new format lacks move
# into the deck's Considering zone, and the `decks` row takes the new collectible type and format, in one transaction, or
# nothing is written. The form's value is `<type>/<format key>`, the pair `Catalog::Formats` registers.
#
# The zones follow from the deck's own rows, not from its old format (decision 2): a row whose key the new format has is
# kept (same id, lots stay), one it lacks is dropped after its lots have moved (the lots' foreign key refuses to remove a zone
# that still holds one), and a zone the deck has no row for is added. Every kept zone takes its name from the registration, as
# an import's zone repair does (spec 062 AC-8.2a), so a release that renamed a zone can't make a new zone's name meet an old one
# in the unique index on (deck, name key). The order of the writes is what keeps that index safe: lots, then the dropped zones,
# then the renames, then the added zones.
#
# Needs no `Current.account`: the deck carries it. The deck and its zones are read again inside the write transaction, so the
# "same format" check and the cap are judged on what holds when the write runs.
# @see file:collection-and-lots.md
class Deck::FormatChange
  include ActiveModel::Model

  # RecordInvalid looks its message up under the model's i18n scope, and ActiveModel's scope has no such entry.
  def self.i18n_scope = :activerecord

  attr_accessor :deck, :format
  # @return [Integer] the copies moved into Considering by a successful {#save}
  attr_reader :moved
  # @return [String, nil] the Considering zone's name as its row has it, set when copies moved
  attr_reader :considering_name

  # @return [Boolean] whether {#save} changed the deck: false when it already had the format
  def changed? = @changed

  # Makes the change.
  #
  # @return [Boolean] false, with "Choose a format." on `errors[:format]`, when the value isn't a registered pair; nothing is
  #   written then
  # @raise [Lot::CapExceeded] when a merge into Considering would hold more than 9,999 copies in one lot; nothing is written
  #   and the deck is read again
  def save
    errors.clear
    @moved = 0
    @changed = false
    option = Catalog::Formats.find_pair(format)
    unless option
      errors.add(:format, Deck::Creation::CHOOSE_A_FORMAT)
      return false
    end

    Deck.transaction { apply(option) }
    true
  rescue Lot::CapExceeded
    deck.reload
    raise
  end

  private
    def apply(option)
      deck.reload
      return if deck.collectible_type == option.type && deck.format == option.format.key

      @changed = true
      location = deck.location
      wanted = option.format.zones
      zones = location.zones.order(:id).to_a
      dropped, kept = zones.partition { |zone| wanted.none? { it.key == zone.zone } }
      deck.update!(collectible_type: option.type, format: option.format.key)
      considering = kept.find { it.zone == Catalog::Formats::CONSIDERING } || add_considering!(location, wanted, kept)
      move_lots!(dropped, considering)
      remove_zones!(location, dropped)
      rewrite_names!(location, kept, wanted)
      add_zones!(location, kept, wanted)
      @considering_name = location.zones.find_by!(zone: Catalog::Formats::CONSIDERING).name if @moved.positive? # after the renames: the registered name
    end

    # A deck that has no Considering row (none made by the app lacks one; a repair is spec 062 AC-8.2a's) gets it before the
    # lots move, because they move into it.
    def add_considering!(location, wanted, kept)
      zone = wanted.find { it.key == Catalog::Formats::CONSIDERING }
      Location.insert_all!(Deck::Creation.zone_rows(location, [ zone ]))
      location.zones.find_by!(zone: zone.key).tap { kept << it }
    end

    def move_lots!(dropped, considering)
    end

    # The dropped zones are empty here (their lots moved), and the lots' foreign key is RESTRICT, so a lot that slipped in fails
    # the whole change instead of being lost.
    def remove_zones!(location, dropped)
      return if dropped.empty?

      location.zones.where(id: dropped.map(&:id)).delete_all # Safe: scoped through the deck's location, bound ids; the foreign key refuses a zone that holds a lot
    end

    # Gives every kept zone the name and comparison key its key has in the registration, in two passes: first each zone to
    # rewrite is parked on a key no name can have (U+0001 and its id), then it takes its registered one, so two zones that
    # exchange names can't meet in the unique index in the middle of a statement.
    def rewrite_names!(location, kept, wanted)
      now = Time.current
      stale = kept.filter_map do |zone|
        name = Location::Name.normalise(wanted.find { it.key == zone.zone }.name)
        key = Location::Name.key(name)
        [ zone.id, name, key ] if zone.name != name || zone.name_key != key
      end
      return if stale.empty?

      location.zones.where(id: stale.map(&:first)).update_all("name_key = char(1) || id") # Safe: scoped through the deck's location, bound ids, no input in the SQL
      stale.each { |id, name, key| location.zones.where(id:).update_all(name:, name_key: key, updated_at: now) } # Safe: scoped, bound values
    end

    def add_zones!(location, kept, wanted)
      have = kept.map(&:zone)
      rows = Deck::Creation.zone_rows(location, wanted.reject { have.include?(it.key) })
      Location.insert_all!(rows) if rows.any? # skips the model's validations on purpose, as Deck::Creation does
    end
end
```

- [ ] Run `bin/rspec spec/models/deck/format_change_spec.rb`. Expected: the examples above pass except "changes a deck whose format the instance no longer registers" (its lots wait for Task 1.3; it expects `moved == 2`), which stays red.
- [ ] `bin/rubocop -a app/models/deck spec/models/deck`, then `bin/rspec spec/deck_core_spec.rb`. Expected: the core guard's file count is now 18 and fails: in `spec/deck_core_spec.rb` change `eq(17)` to `eq(18)` (the new file falls under `app/models/deck/*.rb`; Phase 2 adds two more). Run again; green.
- [ ] `git add app/models/deck/format_change.rb spec/models/deck/format_change_spec.rb spec/deck_core_spec.rb`, then commit `feat(decks): change a deck's zones to its new format's (#251)`.

### Task 1.3: Move the lots of dropped zones into Considering

- [ ] Append to `spec/models/deck/format_change_spec.rb`, inside `describe "#save"`, before the closing `end`s (add the helper `fake_vocabulary` right under `written`):

```ruby
  # A vocabulary registered as the type "fake" with two formats: "f" has the zones a, b and considering, "g" only considering,
  # so one change drops two zones (no shipped format does).
  def fake_vocabulary
    zone = ->(key, name) { Catalog::Formats::Zone.new(key:, name:) }
    formats = [ Catalog::Formats::Format.new(key: "f", name: "F", default: true, zones: [ zone.("a", "A"), zone.("b", "B"), zone.("considering", "Considering") ]),
                Catalog::Formats::Format.new(key: "g", name: "G", default: false, zones: [ zone.("considering", "Considering") ]) ]
    stub_const("FakeDeckVocabulary", Module.new { define_singleton_method(:formats) { formats } })
    Catalog.collecting["fake"] = "FakeDeckVocabulary"
  end

  after { Catalog.collecting.delete("fake") }
```

and these examples inside `describe "#save"`:

```ruby
    context "when zones are dropped" do
      let(:deck) { create(:deck, account:, format: "commander") }
      let(:considering) { deck.zone("considering") }

      it "moves every lot of a dropped zone into Considering, leaves the others where they are and says how many copies (AC-2.1)", :aggregate_failures do
        first = create_lot_in_zone(deck, "commander", quantity: 2)
        second = create_lot_in_zone(deck, "commander", quantity: 1)
        main = create_lot_in_zone(deck, "main", quantity: 4)
        there = create_lot_in_zone(deck, "considering", quantity: 5)
        form = change(deck, "modern")

        expect(form.save).to be(true)

        expect([ first.reload.location_id, second.reload.location_id ]).to eq([ considering.id, considering.id ])
        expect(main.reload.location_id).to eq(deck.zone("main").id)
        expect(there.reload).to have_attributes(location_id: considering.id, quantity: 5)
        expect(zone_keys(deck)).not_to include("commander")
        expect([ form.moved, form.considering_name ]).to eq([ 3, "Considering" ])
      end

      it "removes an empty dropped zone and moves nothing (AC-2.1a)", :aggregate_failures do
        lot = create_lot_in_zone(deck, "main", quantity: 2)
        form = change(deck, "modern")

        expect { form.save }.not_to change { Lot.pluck(:id, :quantity, :location_id, :lot_key) }
        expect(zone_keys(deck)).not_to include("commander")
        expect([ form.moved, lot.reload.quantity ]).to eq([ 0, 2 ])
      end

      it "merges a moved lot into the lot of its identity already in Considering, which survives; a lot alone keeps its id (AC-2.2)", :aggregate_failures do
        entry = create(:mtg_printing).entry
        there = create_lot_in_zone(deck, "considering", entry:, quantity: 3)
        merging = create_lot_in_zone(deck, "commander", entry:, quantity: 2)
        alone = create_lot_in_zone(deck, "commander", quantity: 1)

        change(deck, "modern").save!

        expect(there.reload).to have_attributes(quantity: 5, location_id: considering.id)
        expect(Lot.exists?(merging.id)).to be(false)
        expect(alone.reload.location_id).to eq(considering.id)
      end

      it "counts the copies that moved, merged ones included, and not those already in Considering (AC-2.5)" do
        entry = create(:mtg_printing).entry
        create_lot_in_zone(deck, "considering", entry:, quantity: 3)
        create_lot_in_zone(deck, "commander", entry:, quantity: 2)

        form = change(deck, "modern")
        form.save!

        expect(form.moved).to eq(2)
      end

      it "keys a moved lot by the Considering zone's id, as Lot.key_for builds it, and exports it there (AC-2.4)", :aggregate_failures do
        lot = create_lot_in_zone(deck, "commander", finish: "foil", condition: "near_mint", price_paid_cents: 250, quantity: 1)

        change(deck, "modern").save!

        expect(lot.reload.lot_key).to eq(Lot.key_for("foil", "near_mint", 250, considering.id))
        exported = CollectionExport.new(account:, at: Time.utc(2026, 11, 10)).to_json
        expect(JSON.parse(exported)["lots"].map { it["location"] }).to eq([ { "deck" => "Izzet Tempo", "zone" => "considering" } ])
      end

      it "holds as many copies after as before and touches no other lot (AC-2.7)", :aggregate_failures do
        create_lot_in_zone(deck, "commander", quantity: 2)
        create_lot_in_zone(deck, "main", quantity: 3)
        other = create(:deck, account:, name: "Other", format: "commander")
        elsewhere = create_lot_in_zone(other, "commander", quantity: 7)
        unplaced = Lot.add!(account:, entry: create(:mtg_printing).entry, quantity: 1)
        stamps = [ elsewhere.reload.updated_at, unplaced.reload.updated_at ]

        expect { change(deck, "modern").save! }.not_to change { deck.holdings.copies }
        expect([ elsewhere.reload.updated_at, unplaced.reload.updated_at ]).to eq(stamps)
        expect(elsewhere.location_id).to eq(other.zone("commander").id)
      end

      it "refuses, changing nothing, when a merge would pass 9,999 copies (AC-2.6)", :aggregate_failures do
        entry = create(:mtg_printing).entry
        create_lot_in_zone(deck, "considering", entry:, quantity: 9_999)
        create_lot_in_zone(deck, "commander", entry:, quantity: 1)
        before = [ Lot.order(:id).pluck(:id, :quantity, :location_id, :lot_key), deck.zones.order(:id).pluck(:id, :zone, :name) ]

        expect { change(deck, "modern").save }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot.entry).to eq(entry) }

        expect(deck.reload.format).to eq("commander")
        expect([ Lot.order(:id).pluck(:id, :quantity, :location_id, :lot_key), deck.zones.order(:id).pluck(:id, :zone, :name) ]).to eq(before)
      end

      it "leaves everything as it was when a write fails part way, and does not call it a refusal (AC-2.8)", :aggregate_failures do
        lot = create_lot_in_zone(deck, "commander", quantity: 2)
        allow(Location).to receive(:insert_all!).and_raise(ActiveRecord::StatementInvalid, "disk full")

        expect { change(deck, "modern").save }.to raise_error(ActiveRecord::StatementInvalid)

        expect(deck.reload.format).to eq("commander")
        expect(lot.reload.location_id).to eq(deck.zone("commander").id)
        expect(zone_keys(deck)).to include("commander")
      end

      it "gives a deck with no Considering row one, from the registration, before the lots move into it (AC-2.10)", :aggregate_failures do
        lot = create_lot_in_zone(deck, "commander", quantity: 2)
        deck.zone("considering").delete

        change(deck, "modern").save!

        expect(lot.reload.location_id).to eq(deck.zone("considering").id)
      end

      it "keeps Considering the same row and keeps the lots in it (AC-2.10)" do
        there = create_lot_in_zone(deck, "considering", quantity: 5)

        expect { change(deck, "modern").save! }.not_to change { deck.zone("considering").id }
        expect(there.reload.location_id).to eq(deck.zone("considering").id)
      end
    end

    it "makes one lot of two dropped zones' lots of one identity (AC-2.3)", :aggregate_failures do
      fake_vocabulary
      deck = create(:deck, account:, pair: "fake/f")
      entry = create(:mtg_printing).entry
      create_lot_in_zone(deck, "a", entry:, quantity: 2)
      create_lot_in_zone(deck, "b", entry:, quantity: 3)

      form = described_class.new(deck:, format: "fake/g")
      form.save!

      lots = deck.zone("considering").lots
      expect(lots.map { [ it.catalog_entry_id, it.quantity ] }).to eq([ [ entry.id, 5 ] ])
      expect([ form.moved, zone_keys(deck) ]).to eq([ 5, [ "considering" ] ])
    end

    it "brings an undo of an earlier bulk removal back without a location once its zone is gone (AC-2.9)", :aggregate_failures do
      deck = create(:deck, account:, format: "commander")
      lot = create_lot_in_zone(deck, "commander", quantity: 2)
      session = create(:session, user: account.users.first)
      selection = BulkSelection.for(session)
      selection.record!(shown_ids: [ lot.id ], ticked_ids: [ lot.id ], header_rendered: false, header_ticked: false)
      removal = BulkRemoval.remove!(selection)

      change(deck, "modern").save!
      undone = removal.undo!(sort: CollectionTable::Sort.parse(nil, nil))

      expect(undone.unplaced).to eq(1)
      expect(account.lots.sole).to have_attributes(location_id: nil, quantity: 2)
    end
```

(If `create(:session, …)`, `BulkSelection.for` or `record!` differ from `spec/migrations/add_location_to_lots_spec.rb`'s `pick`/`fill` helpers, mirror those helpers exactly: that spec removes lots through the same three calls.)

- [ ] Run `bin/rspec spec/models/deck/format_change_spec.rb`; expect the new examples red (the lots don't move: `move_lots!` is empty).
- [ ] Fill in `move_lots!` in `app/models/deck/format_change.rb` and the notice's name:

```ruby
    # The lots of the dropped zones go into Considering through the bulk move: one lot of an identity per place, the cap checked
    # for every merge before anything is written (all or nothing), every key rebuilt with the place (`Lot.key_for`, so no sixth
    # builder). The bulk move raises for an empty selection, which is the ordinary case of an empty dropped zone, so it is
    # skipped then. The default order of the collection table names the first lot over the cap.
    def move_lots!(dropped, considering)
      lots = deck.account.lots.where(location_id: dropped.map(&:id))
      return unless lots.exists?

      sort = CollectionTable::Sort.parse(nil, nil)
      @moved = Lot::BulkMove.new(account: deck.account, lots:, to: considering, sort:).apply!.moved
    end
```
- [ ] In `app/models/lot/bulk_move.rb` change the comment on `initialize`: "+to+ is a place of +account+, or nil for none (never a deck or a zone, …" to say: "+to+ is a place of +account+, a zone of one of its decks, or nil for none, never a deck's own row: the writes below skip validations, so the caller's lookup is what keeps a lot out of a deck. The collection's Move to… passes a place or none (`Collections::MovesController`); a deck's change of format passes its Considering zone (`Deck::FormatChange`, spec 064)." and the class comment's first paragraph gains "or a deck's Considering zone". No code changes.
- [ ] Run `bin/rspec spec/models/deck/format_change_spec.rb spec/models/lot/bulk_move_spec.rb`; expect all green. If the AC-2.9 example's setup raises, align it with `spec/migrations/add_location_to_lots_spec.rb` as noted, then rerun.
- [ ] `bin/rubocop -a app/models spec/models/deck`, then `git add app/models/deck/format_change.rb app/models/lot/bulk_move.rb spec/models/deck/format_change_spec.rb`, then commit `feat(decks): move a dropped zone's lots into Considering (#251)`.

## Phase 2: The page (controller, route, view, row button)

**Implements:** FR-2, decisions 1, 4–6 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.6, AC-1.7, AC-1.8, AC-2.1, AC-2.6, AC-3.1 to AC-3.6
**Files:** create `app/controllers/decks/formats_controller.rb`, `app/views/decks/formats/edit.html.erb`, `spec/requests/deck_formats_spec.rb`; modify `config/routes.rb`, `app/helpers/decks_helper.rb`, `app/views/decks/index.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/deck_core_spec.rb`
**Interfaces:** routes and contract above; `DecksHelper#format_changed_message(deck, change)`, `#deck_format_selection(deck)`.

### Task 2.1: Request specs, route and controller

- [ ] Create `spec/requests/deck_formats_spec.rb`:

```ruby
require "rails_helper"

# Spec 064 Stories 1 to 3: the Change format page and the change, with the refusals and tenant isolation.
RSpec.describe "Deck formats", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:deck) { create(:deck, account:, name: "Izzet Tempo", format: "modern") }

  def html = Nokogiri::HTML5(response.body)
  def patch_format(value, target: deck) = patch(deck_format_path(target), params: { deck: { format: value } })

  context "when signed in" do
    before { sign_in_as(user) }

    describe "GET /decks/:id/format/edit (AC-1.2)" do
      it "shows the head, the deck's name and format, the select with the current format, the hint and Save and Cancel", :aggregate_failures do
        get edit_deck_format_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Change format of Izzet Tempo · Collector")
        expect(html.at_css("h1").text).to eq("Change format")
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Izzet Tempo · Modern")
        expect(html.css("select[name='deck[format]'] option").map(&:text)).to include("Casual", "Commander", "Modern")
        expect(html.at_css("select[name='deck[format]'] option[selected]")["value"]).to eq("mtg/modern")
        expect(html.at_css(".c-field__hint").text).to eq("Cards in zones the new format doesn't have move to Considering.")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Save")
        expect(html.at_css("a.c-btn--secondary[href='#{decks_path}']").text).to eq("Cancel")
        expect(html.at_css(".c-appbar--detail")).to be_present
      end

      it "opens for a deck whose format is no longer registered, shows its stored key and starts the select on the default (AC-1.7)", :aggregate_failures do
        deck.update!(format: "retired")

        get edit_deck_format_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Izzet Tempo · retired")
        expect(html.at_css("select[name='deck[format]'] option[selected]")["value"]).to eq("mtg/casual")
      end
    end

    describe "PATCH /decks/:id/format" do
      it "changes the format, answers 303 to the Decks page with the notice and shows the new format (AC-1.3, AC-1.4)", :aggregate_failures do
        patch_format("mtg/pauper")

        expect(response).to redirect_to(decks_path)
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("Changed “Izzet Tempo” to Pauper.")
        follow_redirect!
        expect(html.css(".c-decks tbody td.is-opt").first.text).to eq("Pauper")
      end

      it "says how many cards moved into Considering (AC-2.1)", :aggregate_failures do
        commander = create(:deck, account:, name: "Krenko", format: "commander")
        create_lot_in_zone(commander, "commander", quantity: 2)
        create_lot_in_zone(commander, "commander", quantity: 1)

        patch_format("mtg/modern", target: commander)

        expect(flash[:notice]).to eq("Changed “Krenko” to Modern. 3 cards moved to Considering.")
        expect(commander.reload.holdings.copies).to eq(3)
      end

      it "says '1 card' for one" do
        commander = create(:deck, account:, name: "Krenko", format: "commander")
        create_lot_in_zone(commander, "commander", quantity: 1)

        patch_format("mtg/modern", target: commander)

        expect(flash[:notice]).to eq("Changed “Krenko” to Modern. 1 card moved to Considering.")
      end

      it "says the deck already has the format and writes nothing (AC-1.6)", :aggregate_failures do
        expect { patch_format("mtg/modern") }.not_to change { [ Deck.pluck(:updated_at), Location.pluck(:updated_at) ] }

        expect(response).to redirect_to(decks_path)
        expect(flash[:notice]).to eq("“Izzet Tempo” is already Modern.")
      end

      it "answers 422 on the page with the alert and the chosen format kept when a merge passes the cap, changing nothing (AC-2.6)", :aggregate_failures do
        commander = create(:deck, account:, name: "Krenko", format: "commander")
        entry = create(:mtg_printing).entry
        create_lot_in_zone(commander, "considering", entry:, quantity: 9_999)
        create_lot_in_zone(commander, "commander", entry:, quantity: 1)

        patch_format("mtg/modern", target: commander)

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css(".c-alert, [role=alert]").text).to include("Nothing changed. #{entry.name}", "would have more than 9,999 copies in one lot.")
        expect(html.at_css("select option[selected]")["value"]).to eq("mtg/modern")
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Krenko · Commander")
        expect(commander.reload.format).to eq("commander")
      end

      it "answers 422 with 'Choose a format.' on the Format field for a value that is not a registered pair, writing nothing (AC-3.1)", :aggregate_failures do
        [ "", "modern", "nope/modern" ].each do |value|
          patch_format(value)

          expect(response).to have_http_status(:unprocessable_content)
          expect(html.at_css("#deck_format-error, .c-field__error").text).to include("Choose a format.")
        end
        expect(deck.reload.format).to eq("modern")
      end

      it "answers 400 without the deck parameter (AC-3.1)" do
        patch deck_format_path(deck), params: { other: "x" }

        expect(response).to have_http_status(:bad_request)
      end

      it "ignores an account, a kind, a parent, a zone, a collectible type, a name and a location id (AC-3.2)", :aggregate_failures do
        other = create(:user).account

        patch deck_format_path(deck), params: { deck: { format: "mtg/pauper", account_id: other.id, kind: "place", parent_id: 1, zone: "x",
                                                        collectible_type: "other", name: "Hacked", location_id: 1 } }

        expect(deck.reload).to have_attributes(collectible_type: "mtg", format: "pauper", account_id: account.id)
        expect(deck.name).to eq("Izzet Tempo")
      end
    end

    describe "tenant isolation and bad ids (AC-3.3, AC-3.4)" do
      let(:foreign) { create(:deck, account: create(:user).account, name: "Theirs", format: "modern") }
      let(:place) { create(:location, account:) }

      it "answers 404 for another account's deck, a place and a zone, and changes nothing", :aggregate_failures do
        zone = deck.zone("main")
        [ foreign.location_id, place.id, zone.id, deck.id + 10_000 ].each do |id|
          get "/decks/#{id}/format/edit"
          expect(response).to have_http_status(:not_found)
          patch "/decks/#{id}/format", params: { deck: { format: "mtg/pauper" } }
          expect(response).to have_http_status(:not_found)
        end
        expect([ foreign.reload.format, deck.reload.format ]).to eq(%w[modern modern])
      end

      it "answers 404 for a deck removed in another tab" do
        removed = create(:deck, account:, name: "Gone")
        removed.remove!

        patch_format("mtg/pauper", target: removed.location_id)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "when signed out (AC-3.5)" do
    it "sends the visitor to sign in", :aggregate_failures do
      get edit_deck_format_path(deck)
      expect(response).to redirect_to(new_session_path)
      patch_format("mtg/pauper")
      expect(response).to redirect_to(new_session_path)
      expect(deck.reload.format).to eq("modern")
    end
  end
end
```

(Match `create(:location, account:)` and the sign-in redirect target to the helpers `spec/requests/decks_spec.rb` already uses; copy its sign-in-needed example for the redirect.)

- [ ] Run `bin/rspec spec/requests/deck_formats_spec.rb`; expect `NameError`/routing errors (red).
- [ ] In `config/routes.rb`, inside the `resources :decks` block, add `resource :format, only: %i[edit update], module: :decks # spec 064: change a deck's format`.
- [ ] Create `app/controllers/decks/formats_controller.rb`:

```ruby
# Spec 064: the Change format page and the change. The lookup is by the deck's location id through the account, so another
# account's deck, a place and a zone are all 404 (AC-3.3, AC-3.4); the one permitted parameter is the format pair (AC-3.2).
# @see file:collection-and-lots.md
class Decks::FormatsController < ApplicationController
  before_action :set_deck

  def edit
    @change = Deck::FormatChange.new(deck: @deck, format: helpers.deck_format_selection(@deck))
  end

  # A format the deck has is no change (AC-1.6); a merge past the cap re-renders the page with the alert and writes nothing
  # (AC-2.6); an unregistered pair re-renders it with "Choose a format." on the field (AC-3.1).
  def update
    @change = Deck::FormatChange.new(deck: @deck, format: params.expect(deck: [ :format ])[:format])
    if @change.save
      redirect_to decks_path, notice: helpers.format_changed_message(@deck, @change), status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  rescue Lot::CapExceeded => error
    flash.now[:alert] = helpers.over_cap_message("Nothing changed.", error.lot)
    render :edit, status: :unprocessable_content
  end

  private
    def set_deck = @deck = Current.account.decks.includes(:location).find_by!(location_id: params[:deck_id])
end
```

- [ ] Add to `app/helpers/decks_helper.rb`:

```ruby
  # The value the Change format select starts on: the deck's own pair when the instance registers it, else the default format
  # (a deck whose registration was lost; the page head still shows its stored key, spec 064 AC-1.7).
  #
  # @param deck [Deck]
  # @return [String, nil] `<type>/<key>`
  def deck_format_selection(deck)
    Catalog::Formats.find(deck.collectible_type, deck.format) ? "#{deck.collectible_type}/#{deck.format}" : Catalog::Formats.default_option&.value
  end

  # The notice after a change of format: "Changed “Izzet Tempo” to Commander. 12 cards moved to Considering." (the second
  # sentence only when copies moved, naming the zone as its row does), or that the deck already has the format (AC-1.3, AC-1.6).
  #
  # @param deck [Deck] after the change
  # @param change [Deck::FormatChange] after {Deck::FormatChange#save}
  # @return [String]
  def format_changed_message(deck, change)
    return "“#{deck.name}” is already #{deck.format_name}." unless change.changed?

    base = "Changed “#{deck.name}” to #{deck.format_name}."
    change.moved.positive? ? "#{base} #{pluralize(number_with_delimiter(change.moved), "card")} moved to #{change.considering_name}." : base
  end
```

- [ ] Create `app/views/decks/formats/edit.html.erb` (the Rename page's markup with the New deck page's Format field and the alert, which the layout shows from `flash`; confirm that the layout renders `flash.now[:alert]` by checking `app/views/collections/moves/new.html.erb` and mirror what it does for the alert if the layout doesn't):

```erb
<% content_for :title, "Change format of #{@deck.name} · Collector" %>
<%= render "layouts/appbar", section: :decks, detail: true, back_path: decks_path %>
<main class="c-main c-page c-decks">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Change format</h1>
      <p class="c-pagehead__stats"><%= @deck.name %> · <%= @deck.format_name %></p>
    </div>
  </div>
  <% messages = @change.errors.messages_for(:format) %>
  <%= form_with model: @change, scope: :deck, url: deck_format_path(@deck), method: :patch, class: "c-form" do |form| %>
    <div class="c-field<%= " c-field--invalid" if messages.any? %>">
      <%= form.label :format, "Format", class: "c-field__label" %>
      <%= form.select :format, deck_format_options(@change.format), {}, "aria-describedby": field_error_describedby("deck_format-error", messages) %>
      <%= render "shared/field_errors", messages:, id: "deck_format-error" %>
      <p class="c-field__hint">Cards in zones the new format doesn't have move to Considering.</p>
    </div>
    <div class="c-form__actions">
      <%= form.submit "Save", class: "c-btn c-btn--primary" %>
      <%= link_to "Cancel", decks_path, class: "c-btn c-btn--secondary" %>
    </div>
  <% end %>
</main>
<%= render "layouts/tabbar", section: :decks %>
```

  The word "Considering" in the hint is fixed copy of the Decks section (the issue design's word); it is not a zone key, so the guard allows it.
- [ ] In `spec/deck_core_spec.rb` change `eq(18)` to `eq(20)` (the controller and the view).
- [ ] Run `bin/rspec spec/requests/deck_formats_spec.rb spec/deck_core_spec.rb`; fix the two mirrored details above until green.
- [ ] `bin/rubocop -a`, then `git add` the controller, view, helper, routes and specs, then commit `feat(decks): the Change format page (#251)`.

### Task 2.2: The row button

- [ ] Add to `spec/requests/deck_formats_spec.rb`, inside `context "when signed in"`:

```ruby
    describe "the Decks page's row button (AC-1.1)" do
      it "links each deck to its Change format page and names the deck for a screen reader" do
        get decks_path

        link = html.at_css(".c-decks__actions a[href='#{edit_deck_format_path(deck)}']")
        expect(link.text.squish).to eq("Change format Izzet Tempo")
        expect(link["class"]).to include("c-btn--ghost", "c-btn--sm")
        expect(html.css(".c-decks__actions a").map { it.text.squish.split.first(2).join(" ") }).to eq([ "Rename Izzet", "Change format", "Remove Izzet" ])
      end
    end
```

- [ ] Run it (red). In `app/views/decks/index.html.erb` insert between Rename and Remove:

```erb
                  <%= link_to edit_deck_format_path(deck), class: "c-btn c-btn--ghost c-btn--sm" do %>Change format<span class="c-sr"> <%= deck.name %></span><% end %>
```

- [ ] In `app/assets/stylesheets/collector/additions.css` change the rule and its comment:

```css
/* ---------- Decks page row actions (spec 062, 064): Rename, Change format and Remove beside each deck ---------- */
/* The Locations list's ghost buttons in a table cell. The cell is as narrow as its buttons (`td.c-table__actions`), the three sit
   on one line with the list's gap where they fit and wrap onto lines of their own where they don't (a phone), so they never
   widen the page; they meet the 44px touch floor like the rest of the deck pages, and the deck page's own links (#253) may take
   them over. */
.c-decks__actions { display:flex; flex-wrap:wrap; justify-content:flex-end; gap:var(--space-2); font-family:var(--font-sans); }
```

- [ ] Run `bin/rspec spec/requests/deck_formats_spec.rb spec/requests/decks_spec.rb`; expect green (the existing Decks examples that count links or read the actions row may need the third button: update only expectations that list the actions).
- [ ] `git add` the view, css, spec; commit `feat(decks): a Change format button on each Decks row (#251)`.

## Phase 3: System specs, timing, guards, round trip

**Implements:** FR-2, NFR Performance | **Satisfies:** AC-1.1 (360px), AC-1.8, NFR (timing, queries)
**Files:** modify `spec/system/decks_spec.rb`, `spec/requests/deck_formats_spec.rb`; create `spec/requests/deck_format_change_timing_spec.rb`, `spec/models/deck/format_change_round_trip_spec.rb`

### Task 3.1: The flow and the phone widths

- [ ] Append to `spec/system/decks_spec.rb`:

```ruby
  describe "changing a deck's format (spec 064)" do
    it "changes the format from the row through the Change format page, which needs no script (AC-1.1, AC-1.3)", :aggregate_failures do
      deck = create(:deck, account:, name: "Krenko", format: "commander")
      create_lot_in_zone(deck, "commander", quantity: 2)

      visit decks_path
      click_link "Change format Krenko"
      expect(page).to have_css("h1", text: "Change format")
      select "Modern", from: "Format"
      click_button "Save"

      expect(page).to have_css(".c-notice, [role=status]", text: "Changed “Krenko” to Modern. 2 cards moved to Considering.")
      expect(page).to have_css(".c-decks tbody", text: "Modern")
    end

    it "keeps the Decks row and the Change format page inside a 360px frame (AC-1.1)", :aggregate_failures do
      create(:deck, account:, name: "W" * 60, format: "casual")

      open_in_narrow_frame(decks_path, width: 360, ready: ".c-decks table")
      within_narrow_frame { expect(fits?).to be(true) }

      open_in_narrow_frame(edit_deck_format_path(account.decks.first), width: 360, ready: ".c-decks form")
      within_narrow_frame { expect(fits?).to be(true) }
    end
  end
```

(The notice selector must match what the app's notices render; copy it from the existing "creates a deck from the form" example in the same file.)

- [ ] Run `bin/rspec spec/system/decks_spec.rb`. If the 360px example fails because the three buttons overflow, fix the CSS in `additions.css` (not the spec) until green; this is the "wraps onto lines of their own" criterion.
- [ ] Commit `test(decks): the Change format flow and its phone fit (#251)`.

### Task 3.2: The round trip, the statement count and the timing example

- [ ] Create `spec/models/deck/format_change_round_trip_spec.rb`:

```ruby
require "rails_helper"

# Spec 064 AC-1.8: a deck whose format was changed exports with the new format and its lots' new zones, and applying that
# file on the same instance has nothing to change.
RSpec.describe Deck::FormatChange, "export round trip", type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }

  it "exports the new format and zones, and the file has nothing to change", :aggregate_failures do
    deck = create(:deck, account:, name: "Krenko", format: "commander")
    create_lot_in_zone(deck, "commander", quantity: 2)
    create_lot_in_zone(deck, "main", quantity: 1)
    described_class.new(deck:, format: "mtg/modern").save!

    data = JSON.parse(CollectionExport.new(account: account.reload, at: Time.utc(2026, 11, 10)).to_json)

    expect(data["decks"]).to eq([ { "name" => "Krenko", "collectible_type" => "mtg", "format" => "modern" } ])
    expect(data["lots"].map { it["location"] }).to contain_exactly({ "deck" => "Krenko", "zone" => "considering" }, { "deck" => "Krenko", "zone" => "main" })
    expect(CollectionImport.new(account:, file: StringIO.new(JSON.generate(data))).plan.nothing_to_change?).to be(true)
  end
end
```

- [ ] Run it; expect green (it proves AC-1.8 against the existing export and import).
- [ ] Add to `spec/models/deck/format_change_spec.rb` an example bounding the statements for a change that moves many lots, using the helper the creation spec uses for "costs at most ten statements" (`grep -n "statements" spec/models/deck/creation_spec.rb` for the counter) so that the count is the same for 3 lots and 30 lots in the dropped zone plus the merges it makes (one statement per merged lot is the documented cost: create the 30 lots of distinct identities so none merges). Assert the two counts are equal.
- [ ] Create `spec/requests/deck_format_change_timing_spec.rb` modelled on `spec/requests/bulk_move_timing_spec.rb` (same `:timing` tag, same seed helper style: `Lot.insert_all` in slices of 1,000): a Commander deck with 5,000 lots in its Commander zone over 1,000 printings and 400 lots already in Considering that 400 of the moved lots merge into; call `Deck::FormatChange.new(deck:, format: "mtg/modern").save!` inside `Benchmark.realtime`; assert `< 2` seconds; puts the time (run with `SCANNER_TIMING=1`, never gating).
- [ ] Run `SCANNER_TIMING=1 bin/rspec spec/requests/deck_format_change_timing_spec.rb`, note the time for `verification.md`.
- [ ] Commit `test(decks): the export round trip, the statement count and the timing of a change (#251)`.

## Phase 4: Documents and the visual evidence

**Implements:** FR-2, the spec's Updates | **Satisfies:** the area-doc, design-system and tenancy updates; the screenshots
**Files:** modify `docs/architecture/collection-and-lots.md`, `docs/architecture/tenancy-and-accounts.md`, `docs/architecture/data-portability.md`, `docs/design-system/components/DecksIndex.md`; create `docs/specs/064-change-deck-format/verification.md` and `screenshots/`

### Task 4.1: The area docs and the design system's page

- [ ] `docs/architecture/collection-and-lots.md`: (a) Scope's Decks bullet gains `Deck::FormatChange`, `Decks::FormatsController` and `spec 064`; (b) in "A deck", after the Remove row add the Change format row: "any | Change format (`/decks/:id/format/edit`, `PATCH /decks/:id/format`) | One transaction: the zones become the new format's (kept by key, same rows and lots; dropped ones removed after their lots move; added ones created; kept zones named from the registration), every lot of a dropped zone moves into Considering through `Lot::BulkMove` (merging by identity, the Considering lot surviving, all or nothing at 9,999) and the `decks` row takes the type and format. 303 to `/decks` with "Changed “<name>” to <Format>. 12 cards moved to Considering." (second sentence only when copies moved); the same format is "“<name>” is already <Format>." and writes nothing; a cap refusal is 422 on the page, "Nothing changed. <name> (<SET> · <number>) would have more than 9,999 copies in one lot."; "Choose a format." for a bad pair (spec 064 AC-1.3–AC-1.7, AC-2.1–AC-2.10, AC-3.1)"; (c) the invariant "A deck and its zones are written, renamed and removed as one thing" gains "changed"; (d) a bullet under the deck table: Considering is in every format and is in the deck, so copies in it are not free to use (#50) and the shape panel leaves it out (#256), with the issue design's decision 3 as source; (e) the line about `Deck#zones` order (line ~268) says a format change adds to the cases that list a later-added zone last; (f) Sources gains spec 064 and #251; the "In the app a deck keeps its format" statement, if present, is removed.
- [ ] `docs/architecture/tenancy-and-accounts.md`: the deck routes' 404 rule lists `/decks/:id/format/edit` and `PATCH /decks/:id/format`.
- [ ] `docs/architecture/data-portability.md`: the statement that the move into Considering is #251's now points at spec 064 (an import still moves none).
- [ ] `docs/design-system/components/DecksIndex.md`: the Decks markup gains the "Change format" button between Rename and Remove; a new "Markup, the Change format page" section (the Rename page's shape with the Format field, hint, and the alert on a cap refusal); the row-actions CSS note says the buttons wrap on a phone.
- [ ] Commit `docs(decks): record the format change in the area docs and the design system (#251)`.

### Task 4.2: Screenshots and verification

- [ ] Follow `.claude/memory/pr-screenshots-workflow.md` ("Screenshots from a throwaway system spec"): an uncommitted `spec/system/zz_064_screenshots_spec.rb` with factory data: Decks page with and without the Change format button (the "before" shot deletes `a[href$="/format/edit"]` from the DOM before shooting), the Change format page, a 422 cap refusal and the notice after a change that moves cards, at 1280px and in a 360px frame (use 390 per the workflow), light and dark; set `data-theme` and pause 0.6s. Save to `docs/specs/064-change-deck-format/screenshots/` as JPEGs (`magick ... -quality 82`), look at every shot, delete the spec.
- [ ] Write `verification.md` (criterion by criterion with the example that proves it, as spec 062's does, and the timing result), leaving `## Implementation review` for the review step.
- [ ] Commit `docs(specs): verification and screenshots for spec 064 (#251)`.

## After the last batch (supervisor)

Per the run's brief: check each implementer batch's diff; `bin/rubocop`; `bin/rspec spec/models/deck spec/requests spec/system/decks_spec.rb spec/deck_core_spec.rb`; `bin/yard doc` warnings; ask the coordinator for a CI slot before the full `bin/ci`; Opus implementation review (`sdd-review` Mode B) into `verification.md`; session-wrap and `distill-feature`; push; draft PR with the screenshots; wait for green CI.

## Self-review

- **Spec coverage:** AC-1.1 (2.2, 3.1), AC-1.2 (2.1), AC-1.3, 1.4 (1.2, 2.1), AC-1.5 (1.2), AC-1.6 (1.2, 2.1), AC-1.7 (1.2, 2.1), AC-1.8 (3.2), AC-2.1 to AC-2.10 (1.3, 2.1), AC-3.1 to AC-3.5 (1.2, 2.1), AC-3.6 and AC-3.7 (two accounts: Task 2.1's isolation example covers rows unchanged; the operator pages show no deck and don't read decks, unchanged code: stated in `verification.md` by reading). FR-1 (1.2, 1.3), FR-2 (2.x, 4.1), NFR performance (3.2).
- **No placeholders:** the two spots that say "mirror the existing helper" (the notice selector, the session/selection setup in AC-2.9, the statement counter) name the existing file to copy from.
- **Types:** `Deck::FormatChange#save/#changed?/#moved/#considering_name`, `Deck::Creation.zone_rows(location, zones)`, `DecksHelper#format_changed_message(deck, change)` and `#deck_format_selection(deck)` agree across tasks.
