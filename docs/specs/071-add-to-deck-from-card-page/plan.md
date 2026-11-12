# Implementation Plan: Add to a Deck from the Card Page

**Spec:** [spec.md](spec.md) (v0.4.0, Approved at Gate A, 2026-11-11)
**Decisions:** none new; ADR 0028's deck model and spec 068's proxies are used as they are
**Created:** 2026-11-11

## Global Constraints

- **Shared pieces come from spec 070, cherry-picked, never edited here** (the coordinator's ruling, spec decision 6): `Lot.free` (`app/models/lot.rb`, `spec/models/lot/free_spec.rb`) and `Lot::MoveIntoZone` (`app/models/lot/move_into_zone.rb` and its spec). Their contract as built: `Lot::MoveIntoZone.new(account:, zone:, picks: [[lot, count], …]).call!` returns the copies moved; it joins an outer transaction (no savepoint), judges every pick under the write lock before the first write, and raises `Lot::MoveIntoZone::Refused` whose `#reasons` is `{ lot_id => :not_free | :count | :not_saveable | :cap }` (the cap is told apart from a lot that fails its own validation); `ArgumentError` for a zone not of the account or a lot named twice. A caller must not rescue `Refused` inside its own transaction.
- **Free means `Lot.free`** (no location or a place; a lot in any deck zone, Considering included, is not free). The take order of spec decision 5 is this spec's, in `Lot::FreeCopies`, in Ruby over `account.lots.free`, so it never depends on the SQL of `Lot.free`.
- Every read and write goes through the signed-in account: the lots through `Current.account.lots`, the zone through `account.locations.find_placeable!` and the offered zones of `Location::Choices`; another account's, a place's, a deck's own row, a zone of another type's deck and a removed zone are 404 (decision 11, AC-5.2). No parameter names an account, a user, a kind or a lot (AC-5.3).
- A take is **one** write transaction that reads the free lots, chooses the picks and calls `Lot::MoveIntoZone` inside it, and lets `Refused` leave the block before mapping it to a sentence (spec FR-3; `Lot::Move` joins the outer transaction, so a rescue inside it would commit the earlier moves).
- A proxy is added through `Deck::Proxy.add!` and nothing else; a proxy never counts as owned or free and no take changes one (decision 4, AC-3.10).
- Core deck files name no collectible, source, format or zone key but `considering`, comments included; the words `mtg`, `scryfall` and `magic` are banned anywhere in them, and format words (`standard`, `modern`, `legacy`, `casual`, `pioneer`, `vintage`, `pauper`, `commander`, `sideboard`) as whole words too. So no comment in the new files says "standard order" or "modern". `app/views/catalog/entries/show.html.erb` names Scryfall and must not join the guard's list (`spec/deck_core_spec.rb`).
- Design system: tokens and `c-*` classes only; new CSS goes at the end of `app/assets/stylesheets/collector/additions.css` under its own heading (a heading inside the pick block would change `spec/system/design_system_deck_components_spec.rb`'s rule counts). The page's `main` carries `c-decks`.
- No migration, no schema change, no export change, no ADR (decision 13). `docs/export-format/` is untouched.
- Tests: tag spec types explicitly; `:aggregate_failures` on multi-expectation examples; no prose documents checked from RSpec. An "absent" assertion has a positive control; a name asserted absent from a body is built at run time (spec 066's lesson: the test 404 page prints the spec's source). A no-script system example declares `driven_by :rack_test` before the `let!` that signs in and asserts the driver (spec 067's lesson).
- Code documentation (`.claude/rules/code-documentation.md`): every public class, module and method added or changed gets a summary comment (the `bin/ci checks` ratchet); the why, not the what.
- One shared test database: never run two spec runs at once. Targeted `bin/rspec <file>` runs need no CI slot; a full `bin/ci`, or a push whose hook runs it, asks the coordinator for a slot first.
- Commits: Conventional, one per task, each ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; `git add` and `git commit` in separate calls; one git operation per call.

## Goal

A signed-in collector on a card page presses "Add to deck", chooses a zone of one of their decks of that card's type, a count and either "My copies" (free copies of the card, from any printing, moved into the zone in a stated order, all or nothing) or a proxy of the shown printing in one of its finishes, and is back on the card page with a notice; a visitor sees none of it.

## Pre-implementation gates

- **Simplicity (≤3 components).** Three: the free-copies reading (`Lot::FreeCopies` and its sentence helper), the form object (`Deck::Addition`, with `Location::Choices#decks_of` and `Catalog::Entry#deck_addable?`), and the page (controller, route, view, the card page's link, one CSS rule). No gem, JavaScript, job or table.
- **Anti-abstraction.** `Deck::Addition` is the one representation of the page's three fields; it calls `Deck::Proxy.add!` and `Lot::MoveIntoZone` directly. The view reads prepared values (`uses`, `chosen`, `groups`), no queries in it.
- **Integration-first.** The shared contract (T0) is read before any code; model specs come before the request specs and the views; every task starts with its failing spec.
- **Statement bound fixed here (AC-2.9).** The page's statement count is equal for one lot and forty, one deck and ten (the example compares the two counts); `Lot::FreeCopies` reads in 2 statements (the lots with their entries, sets and places preloaded, and the printings' order) however many lots there are.

## File map

| File | Change | Responsibility |
|------|--------|----------------|
| `app/models/lot.rb`, `spec/models/lot/free_spec.rb`, `app/models/lot/move_into_zone.rb`, `spec/models/lot/move_into_zone_spec.rb` | cherry-picked (spec 070) | `Lot.free`, `Lot::MoveIntoZone` |
| `app/models/lot/free_copies.rb` | new | A card's free lots in take order, the total, the places, `take(count)` |
| `app/helpers/deck_additions_helper.rb` | new | The "N free: …" sentence, the radios' labels, the zone select's options |
| `app/models/location/choices.rb` | edit | `decks_of(collectible_type)` |
| `app/models/catalog/entry.rb` | edit | `deck_addable?` |
| `app/models/deck/addition.rb` | new | The form: fields, `uses`, the take, the proxy, the refusals |
| `config/routes.rb` | edit | `resources :deck_additions, only: %i[new create]` under the entry scope |
| `app/controllers/deck_additions_controller.rb` | new | `new`, `create`, the notice |
| `app/views/deck_additions/new.html.erb` | new | The page |
| `app/views/catalog/entries/show.html.erb` | edit | The head's "Add to deck" link |
| `app/assets/stylesheets/collector/additions.css` | edit | The radio rows' coarse floor |
| `docs/design-system/components/AddToDeck.md`, `ItemPage.md`, `ItemPagePhone.md`, `VisitorHeader.md`, `docs/design-system/previews/AddToDeck.html`, `AddToDeckPhone.html` | edit | The per-finish radios, the head action, the floor |
| `spec/models/lot/free_copies_spec.rb`, `spec/helpers/deck_additions_helper_spec.rb`, `spec/models/location/choices_spec.rb`, `spec/models/catalog/entry_spec.rb`, `spec/models/deck/addition_spec.rb` | new, edit | Model and helper specs |
| `spec/requests/deck_additions_spec.rb`, `spec/requests/catalog/entries_show_spec.rb`, `spec/requests/catalog/visitors_spec.rb` | new, edit | The page, the writes, tenancy, counts, the link, the visitor |
| `spec/system/deck_additions_spec.rb`, `spec/system/card_page_spec.rb`, `spec/system/visitor_catalog_spec.rb`, `spec/system/design_system_deck_components_spec.rb` | new, edit | Fit, focus, the floor, no-script paths, the head row |
| `spec/deck_core_spec.rb` | edit | The new files join the guard (+5) |
| `docs/architecture/collection-and-lots.md`, `tenancy-and-accounts.md`, `CLAUDE.md`, `docs/specs/README.md`, `docs/specs/071-…/verification.md`, `…/screenshots/` | edit, new | Area docs, index, evidence |

## Existing examples that change (from a grep of `spec/`, `docs/`, `app/`)

Run once at the start of execution and kept in `verification.md`: `git grep -n 'Add a copy\|c-item__actions\|AddToDeck\|A proxy of\|My copies\|up to two options\|#255\|deck_additions' -- spec docs app CLAUDE.md ':!.kamal/secrets'`. The hits this plan changes:

| Where | Change | Task |
|-------|--------|------|
| `spec/system/card_page_spec.rb:20-25` | The phone example's `widths[2] > widths[0] / 2` and `> 200` assume one primary button and the menu; replaced by the measurable checks of AC-1.5 | T9 |
| `spec/requests/catalog/visitors_spec.rb:196` (absent selectors) and `:202` (absent strings) | Gain `a[href*='/deck_additions/new']` and "Add to deck" | T8 |
| `spec/system/visitor_catalog_spec.rb:52` | Gains `have_no_text("Add to deck")` | T8 |
| `docs/design-system/components/VisitorHeader.md:42` | "no 'Add a copy' button" gains "Add to deck" | T10 |
| `docs/design-system/components/AddToDeck.md` (bullets "What to use has up to two options", "What #255 decides", the lower-case "foil") and both previews | Per-finish radios, the refusals drawn, the label's case | T10 |
| `spec/system/design_system_deck_components_spec.rb` `use_choices` | A second proxy radio and one example | T10 |
| `docs/design-system/components/ItemPage.md`, `ItemPagePhone.md` | The head action's place and the row's fit | T10 |
| `docs/architecture/collection-and-lots.md` open-issues line (#255, #254 "are not") and card-page section | The action, the page, the stale clause | T11 |
| `docs/specs/README.md` rows 060 and 071 | Both directions (done at Gate A) | T11 checks |
| `docs/roadmap.md` item 14j | Marked by the distillation step at merge, not here | session end |

---

## Phase 0: The shared pieces

### T0: Cherry-pick spec 070's commits

**Implements:** spec decision 6 | **Satisfies:** (nothing alone; AC-2.6, AC-3.x build on it) | **Files:** `app/models/lot.rb`, `app/models/lot/move_into_zone.rb` and their specs (cherry-picked, not edited) | **Interfaces:** `Lot.free`, `Lot::MoveIntoZone.new(account:, zone:, picks:).call!`, `Lot::MoveIntoZone::Refused#reasons`

- [ ] **Step 1:** `git cherry-pick 6fc4b8c98e8b67af2d6535e348508254b07d302b`, then in its own call `git cherry-pick 22ed55b31626d23005722eee6104d6b658e30fec`. If a commit has gone away (the 070 branch was rebased), ask the coordinator for the new SHAs; never rewrite these files.
- [ ] **Step 2:** `bin/rspec spec/models/lot/free_spec.rb spec/models/lot/move_into_zone_spec.rb`. Expected: all pass, 0 failures.
- [ ] **Step 3:** Read `app/models/lot/move_into_zone.rb` once; the code below is written to its contract. No commit of our own (the cherry-picks are the commits).

---

## Phase 1: A card's free copies

### T1: `Lot::FreeCopies`

**Implements:** FR-2, decisions 4, 5 | **Satisfies:** AC-2.5 (the data), AC-2.6, AC-2.8, AC-3.7 | **Files:** `app/models/lot/free_copies.rb`, `spec/models/lot/free_copies_spec.rb` | **Interfaces:** `Lot::FreeCopies.new(account:, entry:)` → `#lots`, `#total`, `#places`, `#take(count)`; `Lot::FreeCopies::PLACES_SHOWN`, `Lot::FreeCopies::Place`

- [ ] **Step 1: the failing spec.** Create `spec/models/lot/free_copies_spec.rb`:

```ruby
require "rails_helper"

# Spec 071 decisions 4, 5 and 7 (AC-2.6, AC-2.8, AC-3.7): the free copies of a card and the order a count takes them in.
RSpec.describe Lot::FreeCopies, type: :model do
  let(:account) { create(:user).account }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:shown) { printing("2X2", Date.new(2022, 7, 8)) }

  def printing(code, released_on, identity: self.identity)
    entry = create(:catalog_entry, name: "Lightning Bolt", identity:, released_on:, set: create(:catalog_set, code:))
    create(:mtg_printing, entry:, finishes: %w[nonfoil foil]).entry
  end

  def free(entry = shown) = described_class.new(account:, entry:)

  it "puts the shown printing's lots first, then the other printings newest first (AC-3.7)" do
    oldest = printing("LEA", Date.new(1993, 8, 5))
    newer = printing("MH2", Date.new(2021, 6, 18))
    [ oldest, shown, newer ].each { |entry| create(:lot, account:, entry:) }

    expect(free.lots.map(&:entry)).to eq([ shown, newer, oldest ])
  end

  it "orders a printing's lots as Your copies does: finish, then unplaced before places by name (AC-3.7)" do
    blue = create(:location, account:, name: "Blue binder")
    red = create(:location, account:, name: "Red box")
    foil_unplaced = create(:lot, account:, entry: shown, finish: "foil")
    in_red = create(:lot, account:, entry: shown, location: red)
    in_blue = create(:lot, account:, entry: shown, location: blue)
    unplaced = create(:lot, account:, entry: shown)

    expect(free.lots).to eq([ unplaced, in_blue, in_red, foil_unplaced ])
  end

  it "leaves out a lot in any deck zone, Considering too, another account's lots and another card's (AC-2.6, AC-2.8)", :aggregate_failures do
    deck = create(:deck, account:)
    create_lot_in_zone(deck, "main", entry: shown)
    create_lot_in_zone(deck, "considering", entry: shown)
    create(:lot, entry: shown)
    create(:lot, account:, entry: create(:mtg_printing).entry)
    mine = create(:lot, account:, entry: shown, quantity: 2)

    expect(free.lots).to eq([ mine ])
    expect(free.total).to eq(2)
  end

  it "counts a card's every printing, and no proxy" do
    other = printing("MH2", Date.new(2021, 6, 18))
    create(:lot, account:, entry: shown, quantity: 2)
    create(:lot, account:, entry: other, quantity: 3)
    create(:deck_proxy, zone: create(:deck, account:).zone("main"), account:, entry: shown, quantity: 5)

    expect(free.total).to eq(5)
  end

  it "names each place once with its copies summed, in take order, and no location as nil (decision 7)" do
    blue = create(:location, account:, name: "Blue binder")
    red = create(:location, account:, name: "Red box")
    create(:lot, account:, entry: shown, quantity: 1)
    create(:lot, account:, entry: shown, quantity: 2, location: blue)
    create(:lot, account:, entry: shown, quantity: 1, location: red)
    create(:lot, account:, entry: shown, quantity: 3, location: blue, finish: "foil")

    expect(free.places).to eq([ described_class::Place.new(name: nil, count: 1), described_class::Place.new(name: "Blue binder", count: 5),
                                described_class::Place.new(name: "Red box", count: 1) ])
  end

  describe "#take" do
    let(:blue) { create(:location, account:, name: "Blue binder") }
    let!(:first) { create(:lot, account:, entry: shown, quantity: 1) }
    let!(:second) { create(:lot, account:, entry: shown, quantity: 2, location: blue) }

    it "takes whole lots from the front, then part of the next" do
      expect(free.take(2)).to eq([ [ first, 1 ], [ second, 1 ] ])
    end

    it "takes every lot whole for the full total" do
      expect(free.take(3)).to eq([ [ first, 1 ], [ second, 2 ] ])
    end

    it "takes part of the first lot when the count is smaller than it" do
      first.update!(quantity: 4)
      expect(free.take(3)).to eq([ [ first, 3 ] ])
    end
  end

  it "reads in a number of statements that does not grow with the lots (AC-2.9)" do
    count = ->(reader) { count_queries { reader.lots } }
    create(:lot, account:, entry: shown)
    small = count.call(free)
    12.times { |n| create(:lot, account:, entry: shown, finish: n.even? ? "foil" : nil, location: create(:location, account:)) }

    expect(count.call(free)).to eq(small)
  end
end
```

- [ ] **Step 2:** `bin/rspec spec/models/lot/free_copies_spec.rb`. Expected: FAIL, `uninitialized constant Lot::FreeCopies`.
- [ ] **Step 3: implement.** Create `app/models/lot/free_copies.rb`:

```ruby
# The copies of one card an account can put in a deck: its lots, of every printing of the card, that are in no deck zone
# (`Lot.free`: spec 057's "Free to use", spec 071 decision 4), in the order a count takes them (decision 5) and the places they
# are in, for the "My copies" sentence (decision 7). Free is judged on the card, not the shown printing: a deck uses a card.
#
# Reads the account's lots when first asked (two statements however many lots there are) and keeps them, so build a new one
# inside the transaction that writes. The order is made in Ruby from preloaded rows, so it doesn't depend on the SQL of
# `Lot.free`. Takes the account explicitly; never reads `Current.account`. Collectible-agnostic.
# @see file:collection-and-lots.md
class Lot::FreeCopies
  # Places named in the "My copies" sentence before "and N more places": a line or two on a phone, and an account with hundreds
  # of places can't make a page of it (spec 071 decision 7).
  PLACES_SHOWN = 5

  # A place the free copies are in and how many, `name` nil for copies with no location.
  Place = Data.define(:name, :count)

  # @param account [Account] whose lots are read
  # @param entry [Catalog::Entry] the shown printing; its card (identity) decides which lots count
  def initialize(account:, entry:)
    @account, @entry = account, entry
  end

  # The free lots in take order: the shown printing's first, then the other printings newest first, and within a printing as
  # "Your copies" lists them (finish, condition, price paid, with unspecified first, then a lot with no location before places
  # by name; spec 032 AC-4.1).
  #
  # @return [Array<Lot>] with `entry` (and its set) and `location` loaded
  def lots
    @lots ||= begin
      found = @account.lots.free.joins(:entry).where(catalog_entries: { catalog_identity_id: @entry.catalog_identity_id })
        .includes(entry: :set).preload(:location).to_a
      rank = Catalog::Entry.where(id: found.map(&:catalog_entry_id).uniq).newest_first.pluck(:id).each_with_index.to_h
      found.sort_by { |lot| order_key(lot, rank) }
    end
  end

  # @return [Integer] the copies that are free
  def total = lots.sum(&:quantity)

  # @return [Array<Place>] each place once with its copies summed, in the order the copies would be taken
  def places
    lots.group_by(&:location_id).map { |_, group| Place.new(name: group.first.location&.name, count: group.sum(&:quantity)) }
  end

  # The lots and counts a request for +count+ copies takes: whole lots from the front while a whole lot fits, then the rest
  # from the next lot, which splits.
  #
  # @param count [Integer] from 1 to {#total}
  # @return [Array<Array(Lot, Integer)>] the pairs `Lot::MoveIntoZone` takes
  def take(count)
    left = count
    lots.each_with_object([]) do |lot, picks|
      break picks if left.zero?

      taken = [ lot.quantity, left ].min
      picks << [ lot, taken ]
      left -= taken
    end
  end

  private
    def order_key(lot, rank)
      place = lot.location
      [ lot.catalog_entry_id == @entry.id ? 0 : 1, rank.fetch(lot.catalog_entry_id), lot.finish.to_s, lot.condition.to_s,
        lot.price_paid_cents || -1, place ? 1 : 0, place&.name_key.to_s, place&.name.to_s, lot.id ]
    end
end
```

- [ ] **Step 4:** `bin/rspec spec/models/lot/free_copies_spec.rb`. Expected: 8 examples, 0 failures. If `released_on:` on the entry fails to rank (the factory sets it from the set), the helper passes it explicitly, as written.
- [ ] **Step 5: commit** (`git add app/models/lot/free_copies.rb spec/models/lot/free_copies_spec.rb`, then `git commit -m "feat(lots): Lot::FreeCopies, a card's free lots in take order (spec 071, #255)"` with the trailer).

### T2: The sentence of "My copies"

**Implements:** decision 7 | **Satisfies:** AC-2.5 | **Files:** `app/helpers/deck_additions_helper.rb`, `spec/helpers/deck_additions_helper_spec.rb` | **Interfaces:** `free_copies_sentence(free)`

- [ ] **Step 1: failing spec.** Create `spec/helpers/deck_additions_helper_spec.rb`:

```ruby
require "rails_helper"

# Spec 071 decision 7: the "N free: …" sentence of the My copies option.
RSpec.describe DeckAdditionsHelper, type: :helper do
  def free(*places) = instance_double(Lot::FreeCopies, total: places.sum(&:count), places:)
  def place(name, count) = Lot::FreeCopies::Place.new(name:, count:)

  it "names each place with its copies" do
    expect(helper.free_copies_sentence(free(place("Blue binder", 2), place("Red box", 1)))).to eq("3 free: 2 in Blue binder, 1 in Red box")
  end

  it "says copies with no location in words" do
    expect(helper.free_copies_sentence(free(place(nil, 1)))).to eq("1 free: 1 with no location")
  end

  it "names five places and counts the rest, in the singular for one" do
    seven = (1..7).map { |n| place("P#{n}", 1) }
    expect(helper.free_copies_sentence(free(*seven))).to eq("7 free: 1 in P1, 1 in P2, 1 in P3, 1 in P4, 1 in P5, and 2 more places")
    six = (1..6).map { |n| place("P#{n}", 1) }
    expect(helper.free_copies_sentence(free(*six))).to end_with(", and 1 more place")
  end

  it "writes thousands with a delimiter" do
    expect(helper.free_copies_sentence(free(place("Bulk", 1_234)))).to eq("1,234 free: 1,234 in Bulk")
  end
end
```

- [ ] **Step 2:** `bin/rspec spec/helpers/deck_additions_helper_spec.rb`. Expected: FAIL, `uninitialized constant DeckAdditionsHelper`.
- [ ] **Step 3: implement.** Create `app/helpers/deck_additions_helper.rb` (T6 adds two more methods to it):

```ruby
# Words and options of the Add to deck page (spec 071).
module DeckAdditionsHelper
  # The sentence inside "My copies (…)": the free total and where the copies are, "3 free: 2 in Blue binder, 1 in Red box",
  # at most `Lot::FreeCopies::PLACES_SHOWN` places and then "and 2 more places" (decision 7).
  #
  # @param free [Lot::FreeCopies]
  # @return [String]
  def free_copies_sentence(free)
    shown = free.places.first(Lot::FreeCopies::PLACES_SHOWN)
    parts = shown.map do |place|
      count = number_with_delimiter(place.count)
      place.name ? "#{count} in #{place.name}" : "#{count} with no location"
    end
    hidden = free.places.size - shown.size
    parts << "and #{hidden} more #{"place".pluralize(hidden)}" if hidden.positive?
    "#{number_with_delimiter(free.total)} free: #{parts.join(", ")}"
  end
end
```

- [ ] **Step 4:** run the spec again. Expected: 4 examples, 0 failures.
- [ ] **Step 5: commit** `feat(decks): the My copies sentence (spec 071, #255)`.

### T3: Decks of one collectible type, and the card's "can add" test

**Implements:** decisions 2, 3 | **Satisfies:** AC-1.3, AC-2.2, AC-2.3 | **Files:** `app/models/location/choices.rb`, `spec/models/location/choices_spec.rb`, `app/models/catalog/entry.rb`, `spec/models/catalog/entry_spec.rb` | **Interfaces:** `Location::Choices#decks_of(collectible_type)`, `Catalog::Entry#deck_addable?`

- [ ] **Step 1: failing specs.** Append to `spec/models/location/choices_spec.rb` (inside the existing describe):

```ruby
  describe "#decks_of" do
    it "offers only the decks of the collectible type, with their zones", :aggregate_failures, :other_collecting do
      mine = create(:deck, account:, name: "Izzet Tempo")
      create(:deck, account:, name: "Elsewhere", pair: "other/standard")
      create(:deck, name: "Theirs") # another account's

      groups = described_class.new(account).decks_of("mtg")

      expect(groups.map { it.location.name }).to eq([ "Izzet Tempo" ])
      expect(groups.first.zones.map(&:id)).to eq(mine.zones.map(&:id))
      expect(described_class.new(account).decks_of("other").map { it.location.name }).to eq([ "Elsewhere" ])
    end

    it "is empty for an account with no deck of the type, one more statement than the choices' own" do
      choices = described_class.new(account)
      choices.decks

      expect(count_queries { choices.decks_of("mtg") }).to eq(1)
      expect(choices.decks_of("mtg")).to be_empty
    end
  end
```

Append to `spec/models/catalog/entry_spec.rb`:

```ruby
  describe "#deck_addable? (spec 071 decision 2)" do
    it "is true for a live card of a type with a vocabulary and a source" do
      expect(create(:catalog_entry)).to be_deck_addable
    end

    it "is false for a retired printing, a token and a type with no vocabulary or no source", :aggregate_failures do
      expect(create(:catalog_entry, :retired)).not_to be_deck_addable
      expect(create(:catalog_entry, kind: "token")).not_to be_deck_addable
      expect(create(:catalog_entry, collectible_type: "unregistered")).not_to be_deck_addable
    end
  end
```

- [ ] **Step 2:** `bin/rspec spec/models/location/choices_spec.rb spec/models/catalog/entry_spec.rb`. Expected: FAIL, `undefined method 'decks_of'` / `'deck_addable?'`. (If `kind: "token"` is not a valid kind value, read `Catalog::Entry::PRIMARY_KIND` and the factory's kinds and use another non-primary kind; the check is `kind == PRIMARY_KIND`.)
- [ ] **Step 3: implement.** In `app/models/location/choices.rb`, after `deck(id)`:

```ruby
  # The decks of one collectible type, with their zones: what a card of that type can be added to (spec 071 decision 3). One
  # more statement than {#decks}, which already holds the rows; no deck of another type is ever offered.
  #
  # @param collectible_type [String] the printing's type
  # @return [Array<Group>] the groups of {#decks} whose deck has that type
  def decks_of(collectible_type)
    ids = Deck.where(account_id: @account.id, collectible_type:).pluck(:location_id).to_set
    decks.select { |group| ids.include?(group.location.id) }
  end
```

In `app/models/catalog/entry.rb`, after `retired?`:

```ruby
  # Whether a collector can add this printing to a deck from its page (spec 071 decision 2): a live card of the primary kind
  # (what the search lists, and what a proxy can be made of: spec 068) whose collectible type has both a vocabulary, for its
  # finishes, and a source. The page and the card page's link both ask, so they can't disagree.
  #
  # @return [Boolean]
  def deck_addable? = !retired? && kind == PRIMARY_KIND && Catalog.collecting.key?(collectible_type) && Catalog.sources.key?(collectible_type)
```

- [ ] **Step 4:** run both specs. Expected: 0 failures (the `unregistered` type is neither in `Catalog.collecting` nor `Catalog.sources`).
- [ ] **Step 5: commit** `feat(decks): decks of a collectible type and a printing's deck_addable? (spec 071, #255)`.

---

## Phase 2: The form object

### T4: `Deck::Addition`

**Implements:** FR-1, FR-3, decisions 3, 5, 8, 9, 11 | **Satisfies:** AC-2.5 to AC-2.7, AC-3.1 to AC-3.5, AC-3.8 to AC-3.12, AC-4.1 to AC-4.4, AC-4.6, AC-5.1, AC-5.2 (the lookup) | **Files:** `app/models/deck/addition.rb`, `spec/models/deck/addition_spec.rb` | **Interfaces:** `Deck::Addition.new(account:, entry:, zone_id:, quantity:, use:)` → `#uses`, `#chosen`, `#groups`, `#decks?`, `#free`, `#finish_label(use)`, `#save`, `#errors`, `#zone`, `#count`, `#proxy`, `#moved?`

- [ ] **Step 1: failing spec.** Create `spec/models/deck/addition_spec.rb`:

```ruby
require "rails_helper"

# Spec 071 Stories 2 to 5: what the Add to deck form shows and does, on the real database.
RSpec.describe Deck::Addition, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:zone) { deck.zone("main") }
  let(:shown) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt"), finishes: %w[nonfoil foil]).entry }

  def addition(use: nil, quantity: "1", zone_id: zone.id.to_s, entry: shown) = described_class.new(account:, entry:, zone_id:, quantity:, use:)
  def lot_in(place, quantity:, **attrs) = create(:lot, account:, entry: shown, quantity:, location: place, **attrs)

  describe "#uses" do
    it "offers My copies first when copies are free, then one proxy per finish in the vocabulary's order (decision 9)", :aggregate_failures do
      lot_in(nil, quantity: 1)
      expect(addition.uses.map(&:value)).to eq(%w[copies proxy:nonfoil proxy:foil])
      expect(addition.chosen).to be_nil
    end

    it "offers no My copies when nothing is free, and chooses the only option (spec 060 decision 14)", :aggregate_failures do
      one_finish = create(:mtg_printing, entry: create(:catalog_entry), finishes: %w[nonfoil]).entry
      subject = addition(entry: one_finish)
      expect(subject.uses.map(&:value)).to eq(%w[proxy:nonfoil])
      expect(subject.chosen).to eq("proxy:nonfoil")
    end

    it "offers one proxy with no finish for a printing that lists none, already chosen", :aggregate_failures do
      none = create(:mtg_printing, entry: create(:catalog_entry), finishes: []).entry
      expect(addition(entry: none).uses.map(&:value)).to eq(%w[proxy])
      expect(addition(entry: none).chosen).to eq("proxy")
    end

    it "keeps what was submitted as the chosen option" do
      expect(addition(use: "proxy:foil").chosen).to eq("proxy:foil")
    end
  end

  describe "#save with My copies" do
    let(:blue) { create(:location, account:, name: "Blue binder") }

    it "moves part of the first lot and leaves the rest where it was (AC-3.1)", :aggregate_failures do
      stay = lot_in(blue, quantity: 3)
      subject = addition(use: "copies", quantity: "1")

      expect(subject.save).to be(true)
      expect(stay.reload.quantity).to eq(2)
      expect(stay.location).to eq(blue)
      expect(account.lots.find_by(location: zone).quantity).to eq(1)
      expect(subject.count).to eq(1)
      expect(subject.zone).to eq(zone)
    end

    it "takes the shown printing's lots before another printing's, whole lots first (AC-3.2, AC-3.7)", :aggregate_failures do
      other = create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", identity: shown.identity, released_on: Date.new(1999, 1, 1)), finishes: %w[nonfoil]).entry
      mine = lot_in(blue, quantity: 1)
      theirs = create(:lot, account:, entry: other, quantity: 2)

      expect(addition(use: "copies", quantity: "2").save).to be(true)
      expect(mine.reload.location).to eq(zone)
      expect(theirs.reload.quantity).to eq(1)
      expect(account.lots.where(location: zone).sum(:quantity)).to eq(2)
    end

    it "refuses a count over the free copies with the free total, changing nothing (AC-3.3)", :aggregate_failures do
      lot_in(blue, quantity: 3)
      subject = addition(use: "copies", quantity: "4")

      expect(subject.save).to be(false)
      expect(subject.errors[:quantity]).to eq([ "Enter a number from 1 to 3." ])
      expect(account.lots.where(location: zone)).to be_empty
    end

    it "judges the count at the write, on what is free then (AC-3.8)", :aggregate_failures do
      a = lot_in(blue, quantity: 1)
      lot_in(nil, quantity: 1)
      subject = addition(use: "copies", quantity: "2")
      subject.free # the page was drawn with two free
      Lot::MoveIntoZone.new(account:, zone:, picks: [ [ a, 1 ] ]).call! # another tab took one

      expect(subject.save).to be(false)
      expect(subject.errors[:quantity]).to eq([ "Enter a number from 1 to 1." ])
    end

    it "says so when nothing is free any more, on the choice (AC-3.8)" do
      subject = addition(use: "copies", quantity: "1")

      expect(subject.save).to be(false)
      expect(subject.errors[:use]).to eq([ "You have no free copy of Lightning Bolt to use." ])
    end

    it "merges into the zone's lot of the same identity (AC-3.4)", :aggregate_failures do
      create(:lot, account:, entry: shown, quantity: 2, location: zone)
      lot_in(blue, quantity: 1)
      lot_in(nil, quantity: 1)

      expect(addition(use: "copies", quantity: "2").save).to be(true)
      expect(account.lots.where(location: zone).pluck(:quantity)).to eq([ 4 ])
    end

    it "refuses past 9,999 in one lot of the zone, naming the lot and rolling the first move back (AC-3.5)", :aggregate_failures do
      create(:lot, account:, entry: shown, quantity: 9_995, finish: "foil", location: zone)
      first = lot_in(nil, quantity: 1)
      lot_in(nil, quantity: 10, finish: "foil")
      subject = addition(use: "copies", quantity: "11")

      expect(subject.save).to be(false)
      expect(subject.errors[:base]).to eq([ "Nothing changed. Lightning Bolt (#{ApplicationController.helpers.set_number(shown)}) would have more than 9,999 copies in one lot." ])
      expect(first.reload.location).to be_nil
    end

    it "names a lot the vocabulary no longer accepts, rolling the first move back (AC-3.11)", :aggregate_failures do
      first = lot_in(nil, quantity: 1)
      broken = build(:lot, account:, entry: shown, quantity: 1, finish: "etched").tap { it.save!(validate: false) }
      subject = addition(use: "copies", quantity: "2")

      expect(subject.save).to be(false)
      expect(subject.errors[:base]).to eq([ "Nothing changed. Lightning Bolt (#{ApplicationController.helpers.set_number(shown)}) can't be moved until it is edited." ])
      expect(first.reload.location).to be_nil
      expect(broken.reload.location).to be_nil
    end

    it "raises RecordNotFound when the zone was removed after the page opened (AC-3.12)" do
      lot_in(blue, quantity: 1)
      subject = addition(use: "copies")
      subject.groups # the page's read
      account.locations.where(id: zone.id).delete_all # removed in another tab (its lots, none here, would refuse this)

      expect { subject.save }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "changes no proxy, deck or other account's rows (AC-3.10)", :aggregate_failures do
      proxy = create(:deck_proxy, zone:, account:, entry: shown, quantity: 4)
      lot_in(blue, quantity: 1)
      theirs = create(:lot, entry: shown)

      addition(use: "copies").save

      expect(proxy.reload.quantity).to eq(4)
      expect(theirs.reload.location).to be_nil
    end
  end

  describe "#save with a proxy" do
    it "adds a proxy of the shown printing and finish, merging into the zone's own (AC-4.1)", :aggregate_failures do
      first = addition(use: "proxy:foil", quantity: "2")
      expect(first.save).to be(true)
      expect(first.proxy).to have_attributes(quantity: 2, finish: "foil", entry: shown, zone: zone)

      again = addition(use: "proxy:foil", quantity: "3")
      expect(again.save).to be(true)
      expect(again.proxy.id).to eq(first.proxy.id)
      expect(again.proxy.quantity).to eq(5)
      expect(account.lots.count).to eq(0)
    end

    it "refuses a finish the printing doesn't list and a missing one, on the choice (AC-4.3)", :aggregate_failures do
      unlisted = addition(use: "proxy:etched")
      expect(unlisted.save).to be(false)
      expect(unlisted.errors[:use]).to eq([ "That finish isn't available for this printing." ])

      bare = addition(use: "proxy")
      expect(bare.save).to be(false)
      expect(bare.errors[:use]).to eq([ "Choose a finish." ])
      expect(account.deck_proxies.count).to eq(0)
    end

    it "refuses a quantity that isn't a whole number from 1 to 9,999, on How many (AC-4.4)", :aggregate_failures do
      %w[0 abc 1.5 10000 -1].each do |typed|
        subject = addition(use: "proxy:foil", quantity: typed)
        expect(subject.save).to be(false), typed
        expect(subject.errors[:quantity]).to eq([ "Enter a number from 1 to 9,999." ]), typed
      end
    end

    it "refuses past 9,999 proxies, with spec 068's sentence on How many (AC-4.2)", :aggregate_failures do
      create(:deck_proxy, zone:, account:, entry: shown, finish: "foil", quantity: 9_990)
      subject = addition(use: "proxy:foil", quantity: "10")

      expect(subject.save).to be(false)
      expect(subject.errors[:quantity]).to eq([ Deck::Proxy::FULL_MESSAGE ])
      expect(account.deck_proxies.sole.quantity).to eq(9_990)
    end
  end

  describe "#save's other refusals" do
    it "asks for a zone and a choice on their own fields (AC-5.1)", :aggregate_failures do
      subject = addition(zone_id: "", use: nil)

      expect(subject.save).to be(false)
      expect(subject.errors[:zone_id]).to eq([ "Choose a deck and zone." ])
      expect(subject.errors[:use]).to eq([ "Choose what to use." ])
      expect(addition(use: "banana").tap(&:save).errors[:use]).to eq([ "Choose what to use." ])
    end

    it "raises RecordNotFound for a zone that isn't one of the account's offered zones (AC-5.2)", :aggregate_failures, :other_collecting do
      place = create(:location, account:)
      theirs = create(:deck).zone("main")
      elsewhere = create(:deck, account:, pair: "other/standard").zones.first
      [ place.id, deck.id, theirs.id, elsewhere.id, "12x" ].each do |bad|
        expect { addition(zone_id: bad.to_s, use: "proxy:foil").save }.to raise_error(ActiveRecord::RecordNotFound), bad.to_s
      end
      expect(account.deck_proxies.count).to eq(0)
    end
  end
end
```

Fixes expected on first run: `account.deck_proxies` exists (spec 068's `Account#deck_proxies`); `deck.zone("main")`, `deck.zones` exist (spec 062). The `deck` `let` must be created before `zone_id` is read (it is: `zone` references it).

- [ ] **Step 2:** `bin/rspec spec/models/deck/addition_spec.rb`. Expected: FAIL, `uninitialized constant Deck::Addition`.
- [ ] **Step 3: implement.** Create `app/models/deck/addition.rb`:

```ruby
# The Add to deck page's form (spec 071): a zone, a count and a choice of what to use, checked and written in one call. "My
# copies" moves the card's free copies into the zone in the order `Lot::FreeCopies` gives; a proxy is recorded through
# `Deck::Proxy.add!`. A sentence lands on the field it belongs to; what was typed stays for the page to show again.
#
# The zone must be one of the account's zones of a deck of the printing's collectible type (`Location::Choices#decks_of`): any
# other value is `ActiveRecord::RecordNotFound` (a 404), never an error on the form, so no sentence tells another account's
# zone from a missing one. Collectible-agnostic: finishes and category words come from the printing's vocabulary.
# @see file:collection-and-lots.md
class Deck::Addition
  include ActiveModel::Model
  include ActiveModel::Attributes

  CHOOSE_ZONE = "Choose a deck and zone.".freeze
  CHOOSE_USE = "Choose what to use.".freeze
  USE_SHAPE = /\A(copies|proxy|proxy:.+)\z/

  # One radio of "What to use": its value (`copies`, `proxy:<finish key>` or `proxy`), its kind and the finish key for a proxy.
  Use = Data.define(:value, :kind, :finish)

  attribute :zone_id, :string
  attribute :quantity, :string, default: "1"
  attribute :use, :string

  attr_reader :account, :entry, :zone, :count, :proxy

  # @param account [Account] the signed-in account
  # @param entry [Catalog::Entry] the shown printing, `deck_addable?`
  def initialize(account:, entry:, **fields)
    super(**fields)
    @account, @entry = account, entry
  end

  # @return [Array<Location::Choices::Group>] the account's decks of the printing's type with their zones
  def groups = @groups ||= Location::Choices.new(account).decks_of(entry.collectible_type)

  # @return [Boolean] whether there is a deck to add to
  def decks? = groups.any?

  # @return [Lot::FreeCopies] the card's free copies as of the first call; {#save} reads them again under the lock
  def free = @free ||= Lot::FreeCopies.new(account:, entry:)

  # The radios of "What to use" in page order: My copies when copies are free, then one proxy per finish the printing lists, or
  # one with no finish for a printing that lists none (decision 9).
  #
  # @return [Array<Use>]
  def uses
    @uses ||= begin
      copies = free.total.positive? ? [ Use.new("copies", :copies, nil) ] : []
      finishes = vocabulary.finishes_for(entry)
      proxies = finishes.empty? ? [ Use.new("proxy", :proxy, nil) ] : finishes.map { |finish| Use.new("proxy:#{finish}", :proxy, finish) }
      copies + proxies
    end
  end

  # @return [String, nil] the value to check at first: what was submitted, else the only option
  def chosen = use.presence || (uses.first.value if uses.one?)

  # @param use [Use]
  # @return [String, nil] the finish as the vocabulary labels it, nil for a proxy with none
  def finish_label(use) = use.finish && vocabulary.finish_label(use.finish)

  # Checks and writes.
  #
  # @return [Boolean] false, with sentences on `errors`, when nothing was written
  # @raise [ActiveRecord::RecordNotFound] for a zone that is not one of the offered zones, or removed while the request ran
  def save
    errors.clear
    offered = zone_id.blank? ? nil : offered_zone!
    errors.add(:zone_id, CHOOSE_ZONE) if offered.nil?
    errors.add(:use, CHOOSE_USE) unless USE_SHAPE.match?(use.to_s)
    return false if errors.any?

    use == "copies" ? take(offered) : add_proxy(offered)
  end

  private
    def vocabulary = Catalog.collecting_for(entry.collectible_type)

    def offered_zone!
      groups.flat_map(&:zones).find { |candidate| candidate.id.to_s == zone_id.to_s } || raise(ActiveRecord::RecordNotFound, "no such zone")
    end

    # One write transaction that finds the zone, reads the free copies, chooses the picks and moves them, so the count is judged
    # on what is free at the write (AC-3.8). `Refused` leaves the block before it is mapped to a sentence: `Lot::Move` joins this
    # transaction, so a rescue inside it would commit the earlier moves.
    def take(offered)
      fresh = nil
      Lot.transaction do
        @zone = account.locations.find_placeable!(offered.id)
        fresh = Lot::FreeCopies.new(account:, entry:)
        total = fresh.total
        wanted = Integer(quantity.to_s.strip, 10, exception: false)
        if total.zero?
          errors.add(:use, "You have no free copy of #{entry.name} to use.")
        elsif wanted.nil? || !wanted.between?(1, total)
          errors.add(:quantity, "Enter a number from 1 to #{ActiveSupport::NumberHelper.number_to_delimited(total)}.")
        else
          @count = Lot::MoveIntoZone.new(account:, zone: @zone, picks: fresh.take(wanted)).call!
        end
      end
      errors.empty?
    rescue Lot::MoveIntoZone::Refused => error
      refuse(error, fresh)
    end

    # A refusal of the move as a sentence naming the first lot: the cap, or a lot that fails its own validation. The other
    # reasons (`:not_free`, `:count`) can't happen here, the picks having been chosen under the same lock, and read as the
    # second.
    def refuse(error, fresh)
      id, reason = error.reasons.first
      lot = fresh.lots.find { |candidate| candidate.id == id }
      what = reason == :cap ? "would have more than #{ActiveSupport::NumberHelper.number_to_delimited(Lot::MAX_QUANTITY)} copies in one lot." : "can't be moved until it is edited."
      errors.add(:base, "Nothing changed. #{lot.entry.name} (#{ApplicationController.helpers.set_number(lot.entry)}) #{what}")
      false
    end

    def add_proxy(offered)
      @count = Deck::Proxy.parse_quantity(quantity)
      return refuse_text(:quantity, Deck::Proxy::Addition::QUANTITY_SENTENCE) unless @count

      @zone = offered
      finish = use.delete_prefix("proxy").delete_prefix(":").presence
      @proxy = Deck::Proxy.add!(account:, zone: @zone, entry:, finish:, quantity: @count)
      true
    rescue ActiveRecord::RecordInvalid => error
      error.record.errors.each do |message|
        attribute = { quantity: :quantity, finish: :use }.fetch(message.attribute, :base)
        errors.add(attribute, message.message)
      end
      false
    end

    def refuse_text(attribute, sentence)
      errors.add(attribute, sentence)
      false
    end
end
```

- [ ] **Step 4:** `bin/rspec spec/models/deck/addition_spec.rb`. Expected: all pass. Debug notes: (a) the zone's `label` needs `parent` loaded: `Location::Choices` sets it, and `find_placeable!` includes it (read `Location.find_placeable!` if the notice spec in T5 fails); (b) the "removed zone" example deletes the zone row directly, so `find_placeable!` inside the write raises `RecordNotFound`; (c) if `Lot::MoveIntoZone` refuses with `:not_saveable` for the "etched" lot before the first move, the first lot is untouched, which the example also asserts.
- [ ] **Step 5: commit** `feat(decks): Deck::Addition, the Add to deck form (spec 071, #255)`.

---

## Phase 3: The page

### T5: Route, controller, view and options

**Implements:** FR-1, decisions 2, 3, 10, 12 | **Satisfies:** AC-2.1 to AC-2.8, AC-5.4 | **Files:** `config/routes.rb`, `app/controllers/deck_additions_controller.rb`, `app/views/deck_additions/new.html.erb`, `app/helpers/deck_additions_helper.rb`, `spec/requests/deck_additions_spec.rb` | **Interfaces:** `new_catalog_entry_deck_addition_path(entry)`, `catalog_entry_deck_additions_path(entry)`

- [ ] **Step 1: failing spec** (page only; writes are T6). Create `spec/requests/deck_additions_spec.rb`:

```ruby
require "rails_helper"

# Spec 071 Stories 2 to 5: the Add to deck page and what it writes.
RSpec.describe "Add to deck", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt"), finishes: %w[nonfoil foil]).entry }

  def html = Nokogiri::HTML5(response.body)
  def zone_path_options = html.css("select#deck_zone optgroup option")
  def radios = html.css("fieldset.c-pick input[type=radio]")

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the page (AC-2.1 to AC-2.4)" do
      before { deck }

      it "is a detail page for the card with the select, the count and the choice", :aggregate_failures do
        get new_catalog_entry_deck_addition_path(entry)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Add Lightning Bolt to a deck · Collector")
        expect(html.at_css("h1").text).to eq("Add Lightning Bolt to a deck")
        expect(html.at_css("header.c-appbar--detail")).to be_present
        expect(html.at_css("main.c-decks")).to be_present
        expect(html.at_css("form.c-form")["action"]).to eq(catalog_entry_deck_additions_path(entry))
        expect(html.at_css("a.c-btn--secondary", text: "Cancel")["href"]).to eq(catalog_entry_path(entry))
        expect(html.at_css("input[type=submit]")["value"]).to eq("Add to deck")
      end

      it "carries the collection mark on the form, Cancel and the back link" do
        get new_catalog_entry_deck_addition_path(entry, from: "collection")

        expect(html.at_css("form.c-form")["action"]).to eq(catalog_entry_deck_additions_path(entry, from: "collection"))
        expect(html.at_css("a.c-btn--secondary", text: "Cancel")["href"]).to eq(catalog_entry_path(entry, from: "collection"))
      end

      it "lists every zone of the account's decks under one Decks group, no Places and no No location (AC-2.2)", :aggregate_failures do
        create(:location, account:, name: "Blue binder")
        get new_catalog_entry_deck_addition_path(entry)

        select = html.at_css("select#deck_zone")
        expect(select["required"]).to be_present
        expect(select.css("option").first.text).to eq("Choose a deck and zone…")
        expect(select.css("option").first["value"]).to eq("")
        expect(select.css("optgroup").map { it["label"] }).to eq([ "Decks" ])
        expect(zone_path_options.map(&:text)).to eq(deck.zones.map { "Izzet Tempo › #{it.name}" })
        expect(zone_path_options.map { it["value"] }).to eq(deck.zones.map { it.id.to_s })
        expect(select.text).not_to include("Blue binder")
      end

      it "has a labelled How many field with 1 in it, a minimum of 1 and no maximum (AC-2.4)", :aggregate_failures do
        get new_catalog_entry_deck_addition_path(entry)

        field = html.at_css("input#how_many")
        expect(html.at_css("label[for=how_many]").text).to eq("How many")
        expect(field.attributes.slice("type", "name", "min", "step", "value", "required").transform_values(&:value))
          .to include("type" => "number", "name" => "quantity", "min" => "1", "step" => "1", "value" => "1")
        expect(field["max"]).to be_nil
      end
    end

    describe "What to use (AC-2.5 to AC-2.8)" do
      before { deck }

      it "offers My copies with the free sentence first, then a proxy per finish, nothing chosen, all required", :aggregate_failures do
        blue = create(:location, account:, name: "Blue binder")
        create(:lot, account:, entry:, quantity: 2, location: blue)
        create(:lot, account:, entry:, quantity: 1)
        get new_catalog_entry_deck_addition_path(entry)

        labels = html.css("fieldset.c-pick label.c-check").map { it.text.squish }
        expect(html.at_css("fieldset.c-pick legend").text).to eq("What to use")
        expect(labels).to eq([ "My copies (3 free: 1 with no location, 2 in Blue binder)", "A proxy of #{ApplicationController.helpers.set_number(entry)} Nonfoil",
                               "A proxy of #{ApplicationController.helpers.set_number(entry)} Foil" ])
        expect(radios.map { it["value"] }).to eq(%w[copies proxy:nonfoil proxy:foil])
        expect(radios.map { it["checked"] }).to all(be_nil)
        expect(radios.map { it["required"] }).to all(be_present)
        expect(html.css("fieldset.c-pick .is-data").map(&:text)).to eq([ ApplicationController.helpers.set_number(entry) ] * 2)
      end

      it "doesn't count or name copies in a deck zone, a proxy, another account's copies or another card's (AC-2.6, AC-2.8)", :aggregate_failures do
        create_lot_in_zone(deck, "main", entry:, quantity: 3)
        create(:deck_proxy, zone: deck.zone("main"), account:, entry:, quantity: 2)
        create(:lot, entry:, quantity: 7) # another account's
        create(:lot, account:, entry: create(:mtg_printing).entry, quantity: 5)
        get new_catalog_entry_deck_addition_path(entry)

        expect(radios.map { it["value"] }).to eq(%w[proxy:nonfoil proxy:foil])
        expect(html.text).not_to include("free:")
      end

      it "shows the owner's own copies, as the positive control of the example above (AC-2.8)" do
        create(:lot, account:, entry:, quantity: 3)
        get new_catalog_entry_deck_addition_path(entry)

        expect(radios.first["value"]).to eq("copies")
        expect(html.text).to include("3 free: 3 with no location")
      end

      it "chooses the only option when one is left (spec 060 decision 14)", :aggregate_failures do
        one = create(:mtg_printing, entry: create(:catalog_entry), finishes: %w[foil]).entry
        get new_catalog_entry_deck_addition_path(one)
        expect(radios.map { it["value"] }).to eq(%w[proxy:foil])
        expect(radios.first["checked"]).to be_present

        none = create(:mtg_printing, entry: create(:catalog_entry), finishes: []).entry
        get new_catalog_entry_deck_addition_path(none)
        expect(radios.map { it["value"] }).to eq(%w[proxy])
        expect(html.at_css("fieldset.c-pick label.c-check").text.squish).to eq("A proxy of #{ApplicationController.helpers.set_number(none)}")
      end
    end

    it "says there are no decks and links New deck, with no form (AC-2.3)", :aggregate_failures, :other_collecting do
      create(:deck, account:, pair: "other/standard")
      get new_catalog_entry_deck_addition_path(entry)

      expect(response).to have_http_status(:ok)
      expect(html.at_css("h1").text).to eq("Add Lightning Bolt to a deck")
      expect(html.at_css("p.c-empty").text.squish).to eq("You have no decks yet. Add a deck first. New deck")
      expect(html.at_css("p.c-empty a")["href"]).to eq(new_deck_path)
      expect(html.at_css("form.c-form")).to be_nil
    end

    it "offers no zone of a deck of another collectible type (AC-2.3)", :aggregate_failures, :other_collecting do
      deck
      create(:deck, account:, name: "Elsewhere", pair: "other/standard")
      get new_catalog_entry_deck_addition_path(entry)

      expect(zone_path_options.map(&:text).join).not_to include("Elsewhere")
      expect(zone_path_options.map(&:text).join).to include("Izzet Tempo")
    end

    it "is 404 for a retired printing, a token and an unknown key (AC-1.3)", :aggregate_failures do
      retired = create(:catalog_entry, :retired)
      token = create(:catalog_entry, kind: "token")

      [ retired, token ].each do |bad|
        get new_catalog_entry_deck_addition_path(bad)
        expect(response).to have_http_status(:not_found)
      end
      get new_catalog_entry_deck_addition_path("no-such-key")
      expect(response).to have_http_status(:not_found)
    end

    it "runs the same number of statements for one lot and deck as for forty lots and ten decks (AC-2.9)" do
      deck
      create(:lot, account:, entry:)
      get new_catalog_entry_deck_addition_path(entry) # warm-up
      small = count_queries { get new_catalog_entry_deck_addition_path(entry) }
      9.times { |n| create(:deck, account:, name: "Deck #{n}") }
      40.times { |n| create(:lot, account:, entry:, finish: n.even? ? "foil" : nil, price_paid_cents: n, location: create(:location, account:)) }

      expect(count_queries { get new_catalog_entry_deck_addition_path(entry) }).to eq(small)
    end
  end

  context "when signed out (AC-1.2, AC-5.4)" do
    it "sends the page and the create to sign in, writing nothing", :aggregate_failures do
      get new_catalog_entry_deck_addition_path(entry)
      expect(response).to redirect_to(new_session_path)

      post catalog_entry_deck_additions_path(entry), params: { zone_id: deck.zone("main").id, use: "proxy:foil", quantity: "1" }
      expect(response).to redirect_to(new_session_path)
      expect(Deck::Proxy.count).to eq(0)
    end
  end
end
```

- [ ] **Step 2:** `bin/rspec spec/requests/deck_additions_spec.rb`. Expected: FAIL, `undefined method 'new_catalog_entry_deck_addition_path'`.
- [ ] **Step 3: route.** In `config/routes.rb`, replace the block

```ruby
  scope "catalog/entries/:entry_external_key", as: :catalog_entry do
    resources :lots, only: %i[new create]
  end
```
with
```ruby
  scope "catalog/entries/:entry_external_key", as: :catalog_entry do
    resources :lots, only: %i[new create]
    resources :deck_additions, only: %i[new create] # "Add to deck" (spec 071)
  end
```
- [ ] **Step 4: controller.** Create `app/controllers/deck_additions_controller.rb`:

```ruby
# Spec 071: "Add to deck" from the card page. The printing is found by its key and must be one a collector can add to a deck
# (`Catalog::Entry#deck_addable?`: live, a card, its type registered), else 404; the zone and the lots go through
# `Current.account` (`Deck::Addition`). Signed-out visitors are sent to sign in by the application controller: this page is not
# part of the open catalog.
# @see file:collection-and-lots.md
class DeckAdditionsController < ApplicationController
  before_action :set_entry

  # A zone removed while the form was open: the foreign key (the proxy path) or the lookup (the take) refused it.
  rescue_from(ActiveRecord::InvalidForeignKey) { raise ActiveRecord::RecordNotFound }

  def new
    @addition = build
  end

  def create
    @addition = build(addition_params)
    return render(:new, status: :unprocessable_content) unless @addition.save

    redirect_to catalog_entry_path(@entry, **card_params), status: :see_other, notice: notice(@addition)
  end

  private
    def set_entry
      @entry = Catalog::Entry.includes(:set, :identity).find_by!(external_key: params[:entry_external_key])
      raise ActiveRecord::RecordNotFound, "not a printing to add to a deck" unless @entry.deck_addable?

      Catalog::Entry.preload_extensions([ @entry ])
    end

    def build(fields = {}) = Deck::Addition.new(account: Current.account, entry: @entry, **fields)

    # Flat fields, permitted by name: `params.expect` would answer 400 for the radio a browser doesn't send when none is chosen,
    # and that case is a 422 with a sentence (AC-5.1). Nothing else is read (AC-5.3).
    def addition_params = params.permit(:zone_id, :quantity, :use).to_h.symbolize_keys

    def notice(addition)
      if addition.proxy
        added = helpers.pluralize(helpers.number_with_delimiter(addition.count), "proxy", "proxies")
        "Added #{added} of #{helpers.proxy_name(addition.proxy)} to #{addition.zone.label}."
      else
        "Moved #{helpers.pluralize(helpers.number_with_delimiter(addition.count), "copy", "copies")} of #{@entry.name} to #{addition.zone.label}."
      end
    end
end
```

`proxy_name(proxy)` needs the proxy's entry and set loaded: `Deck::Proxy.add!` returns a proxy with `entry` set to our `@entry` (set included). If `set_number` fails on set not loaded, `@entry` has `:set` included. Good.

- [ ] **Step 5: helper additions.** Append to `app/helpers/deck_additions_helper.rb`:

```ruby
  # The Deck and zone select's options: one `optgroup` "Decks" holding "Deck › Zone" for every zone, valued with the zone's
  # id; the placeholder is the select's `include_blank` (spec 071 decision 3; no Places group, only a zone can be chosen).
  #
  # @param groups [Array<Location::Choices::Group>] from `Deck::Addition#groups`
  # @param selected [String, nil] the zone id to mark
  # @return [ActiveSupport::SafeBuffer]
  def deck_zone_options(groups, selected: nil)
    zones = groups.flat_map { |group| group.zones.map { |zone| [ zone.label, zone.id.to_s ] } }
    grouped_options_for_select([ [ "Decks", zones ] ], selected)
  end

  # A radio's words: "My copies (3 free: …)" or "A proxy of SET · number Foil", `SET · number` in `is-data` (decision 9).
  #
  # @param addition [Deck::Addition]
  # @param use [Deck::Addition::Use]
  # @return [ActiveSupport::SafeBuffer, String]
  def use_label(addition, use)
    return "My copies (#{free_copies_sentence(addition.free)})" if use.kind == :copies

    finish = addition.finish_label(use)
    safe_join([ "A proxy of ", tag.span(set_number(addition.entry), class: "is-data"), (" #{finish}" if finish) ])
  end
```

- [ ] **Step 6: the view.** Create `app/views/deck_additions/new.html.erb`:

```erb
<% content_for :title, "Add #{@entry.name} to a deck · Collector" %>
<%= render "layouts/appbar", section: card_context, detail: true, back_path: catalog_entry_path(@entry, **card_params) %>
<main class="c-main c-page c-decks">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Add <%= @entry.name %> to a deck</h1>
    </div>
  </div>
  <% if !@addition.decks? %>
    <p class="c-empty">You have no decks yet. Add a deck first. <%= link_to "New deck", new_deck_path %></p>
  <% else %>
    <% zone_errors = @addition.errors[:zone_id] %>
    <% quantity_errors = @addition.errors[:quantity] %>
    <% use_errors = @addition.errors[:use] %>
    <%= form_with url: catalog_entry_deck_additions_path(@entry, **card_params), method: :post, class: "c-form" do %>
      <div class="c-field<%= " c-field--invalid" if zone_errors.any? %>">
        <%= label_tag :deck_zone, "Deck and zone", class: "c-field__label" %>
        <%= select_tag :zone_id, deck_zone_options(@addition.groups, selected: @addition.zone_id), include_blank: "Choose a deck and zone…", required: true,
              id: "deck_zone", "aria-describedby": field_error_describedby("deck_addition_zone-error", zone_errors) %>
        <%= render "shared/field_errors", messages: zone_errors, id: "deck_addition_zone-error" %>
      </div>
      <div class="c-field<%= " c-field--invalid" if quantity_errors.any? %>">
        <%= label_tag :how_many, "How many", class: "c-field__label" %>
        <label class="c-input"><%= number_field_tag :quantity, @addition.quantity, id: "how_many", min: 1, step: 1, inputmode: "numeric", required: true,
              "aria-describedby": field_error_describedby("deck_addition_quantity-error", quantity_errors) %></label>
        <%= render "shared/field_errors", messages: quantity_errors, id: "deck_addition_quantity-error" %>
      </div>
      <fieldset class="c-choices c-pick<%= " c-field--invalid" if use_errors.any? %>" aria-describedby="<%= field_error_describedby("deck_addition_use-error", use_errors) %>">
        <legend class="c-field__label">What to use</legend>
        <% @addition.uses.each do |use| %>
          <label class="c-check"><%= radio_button_tag :use, use.value, @addition.chosen == use.value, required: true %><%= use_label(@addition, use) %></label>
        <% end %>
        <%= render "shared/field_errors", messages: use_errors, id: "deck_addition_use-error" %>
      </fieldset>
      <%= render "shared/field_errors", messages: @addition.errors[:base], id: "deck_addition_base-error" %>
      <div class="c-form__actions">
        <%= submit_tag "Add to deck", class: "c-btn c-btn--primary", name: nil %>
        <%= link_to "Cancel", catalog_entry_path(@entry, **card_params), class: "c-btn c-btn--secondary" %>
      </div>
    <% end %>
  <% end %>
</main>
<%= render "layouts/tabbar", section: card_context %>
```

Notes for the implementer: `field_error_describedby` returns nil for no errors, so `aria-describedby=""` would render empty on the fieldset: use `<%= tag.fieldset ... %>` or the conditional attribute pattern the other views use if the empty attribute fails a spec; `form_with url:` with no model emits `name="zone_id"`, `name="quantity"`, `name="use"` flat as the spec says; `select_tag`'s `include_blank` text and `required` are honoured. If `form_with` adds `data-turbo` or an authenticity field, that is normal.

- [ ] **Step 7:** `bin/rspec spec/requests/deck_additions_spec.rb`. Expected: all pass. The fixes the first run is likely to need: the entry's "kind" values for the token example, `aria-describedby` on the fieldset (omit it when empty), the free sentence's order of places ("1 with no location, 2 in Blue binder": the unplaced lot sorts before places), and `new_session_path` for the sign-in redirect (read an existing request spec's signed-out example for the path helper).
- [ ] **Step 8: commit** `feat(decks): the Add to deck page (spec 071, #255)`.

### T6: The writes, refusals and tenancy through the request

**Implements:** FR-1, decisions 10, 11 | **Satisfies:** AC-3.1 to AC-3.3, AC-3.6, AC-4.1, AC-4.5, AC-5.1 to AC-5.3 | **Files:** `spec/requests/deck_additions_spec.rb` | **Interfaces:** (none new)

- [ ] **Step 1: failing examples.** Append to the same file, inside `context "when signed in"`:

```ruby
    describe "My copies (AC-3.1 to AC-3.3, AC-3.6)" do
      let(:blue) { create(:location, account:, name: "Blue binder") }
      let(:zone) { deck.zone("main") }

      def add(use:, quantity: "1", zone_id: zone.id, **extra) = post(catalog_entry_deck_additions_path(entry, **extra), params: { zone_id:, use:, quantity: })

      it "moves the copies, 303s to the card page and says so (AC-3.1)", :aggregate_failures do
        stay = create(:lot, account:, entry:, quantity: 2, location: blue)
        add(use: "copies", quantity: "1")

        expect(response).to redirect_to(catalog_entry_path(entry))
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("Moved 1 copy of Lightning Bolt to Izzet Tempo › Main.")
        expect(stay.reload.quantity).to eq(1)
        expect(account.lots.find_by(location: zone).quantity).to eq(1)
      end

      it "keeps the collection mark on the redirect" do
        create(:lot, account:, entry:)
        add(use: "copies", from: "collection")

        expect(response).to redirect_to(catalog_entry_path(entry, from: "collection"))
      end

      it "says copies for more than one, and shows them as Deck › Zone in Your copies (AC-3.2, AC-3.6)", :aggregate_failures do
        create(:lot, account:, entry:, quantity: 2, location: blue)
        create(:lot, account:, entry:, quantity: 1, finish: "foil")
        add(use: "copies", quantity: "3", zone_id: deck.zone("considering").id)
        expect(flash[:notice]).to eq("Moved 3 copies of Lightning Bolt to Izzet Tempo › Considering.")

        get catalog_entry_path(entry)
        expect(html.at_css("#copies").text).to include("Izzet Tempo › Considering")
        expect(html.at_css(".c-stat dd").text).to eq("3") # Owned is unchanged
      end

      it "refuses a count over the free copies with 422, the typed values kept and nothing moved (AC-3.3)", :aggregate_failures do
        lot = create(:lot, account:, entry:, quantity: 3, location: blue)
        add(use: "copies", quantity: "4")

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#deck_addition_quantity-error").text).to eq("Enter a number from 1 to 3.")
        expect(html.at_css("input#how_many")["value"]).to eq("4")
        expect(html.at_css("select#deck_zone option[selected]")["value"]).to eq(zone.id.to_s)
        expect(html.at_css("input[value=copies]")["checked"]).to be_present
        expect(lot.reload.location).to eq(blue)
      end

      it "refuses the cap with the lot named above the actions (AC-3.5)", :aggregate_failures do
        create(:lot, account:, entry:, quantity: 9_995, finish: "foil", location: zone)
        create(:lot, account:, entry:, quantity: 10, finish: "foil", location: blue)
        add(use: "copies", quantity: "10")

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#deck_addition_base-error").text).to eq("Nothing changed. Lightning Bolt (#{ApplicationController.helpers.set_number(entry)}) would have more than 9,999 copies in one lot.")
        expect(account.lots.find_by(location: blue).quantity).to eq(10)
      end

      it "doesn't make the double submit lose or create copies (AC-3.9)", :aggregate_failures do
        create(:lot, account:, entry:, quantity: 2, location: blue)
        2.times { add(use: "copies", quantity: "2") }

        expect(response).to have_http_status(:unprocessable_content) # the second finds nothing free
        expect(account.lots.sum(:quantity)).to eq(2)
        expect(account.lots.where(location: zone).sum(:quantity)).to eq(2)
      end
    end

    describe "a proxy (AC-4.1, AC-4.5)" do
      it "adds the proxy, says so and shows it on the deck page, owned copies unchanged", :aggregate_failures do
        zone = deck.zone("main")
        post catalog_entry_deck_additions_path(entry), params: { zone_id: zone.id, use: "proxy:foil", quantity: "2" }

        expect(response).to redirect_to(catalog_entry_path(entry))
        expect(flash[:notice]).to eq("Added 2 proxies of Lightning Bolt (#{ApplicationController.helpers.set_number(entry)}, Foil) to Izzet Tempo › Main.")
        expect(account.lots.count).to eq(0)

        get deck_path(deck)
        expect(html.css("section.c-zone").first.text).to include("Lightning Bolt")
        expect(html.css(".c-proxy").first.text.squish).to eq("Proxy 2")
      end

      it "says 1 proxy in the singular, and the finish only when there is one", :aggregate_failures do
        none = create(:mtg_printing, entry: create(:catalog_entry, name: "Island"), finishes: []).entry
        post catalog_entry_deck_additions_path(none), params: { zone_id: deck.zone("main").id, use: "proxy", quantity: "1" }

        expect(flash[:notice]).to eq("Added 1 proxy of Island (#{ApplicationController.helpers.set_number(none)}) to Izzet Tempo › Main.")
      end
    end

    describe "refusals and tenancy (AC-5.1 to AC-5.3)" do
      it "answers 422 with a sentence on the field for no zone, no choice or no recognised choice", :aggregate_failures do
        post catalog_entry_deck_additions_path(entry), params: { zone_id: "", quantity: "1" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#deck_addition_zone-error").text).to eq("Choose a deck and zone.")
        expect(html.at_css("#deck_addition_use-error").text).to eq("Choose what to use.")
        expect(Deck::Proxy.count).to eq(0)
      end

      it "answers 404 for another account's zone, a place, a deck's own row, a missing zone and a bad id, writing nothing and leaking nothing", :aggregate_failures do
        rival = "Rival #{SecureRandom.hex(4)}" # built at run time: the test 404 page prints the spec's source
        theirs = create(:deck, name: rival)
        place = create(:location, account:)
        own = create(:deck, account:, name: "Own #{SecureRandom.hex(4)}")
        [ theirs.zone("main").id, place.id, own.id, 0, "abc" ].each do |bad|
          post catalog_entry_deck_additions_path(entry), params: { zone_id: bad, use: "proxy:foil", quantity: "1" }
          expect(response).to have_http_status(:not_found), bad.to_s
          expect(response.body).not_to include(rival)
        end
        expect(Deck::Proxy.count).to eq(0)

        get new_catalog_entry_deck_addition_path(entry) # the owner's own request shows the owner's deck (positive control)
        expect(html.at_css("select#deck_zone").text).to include(own.name)
      end

      it "ignores an account, user, location, kind or lot in the request (AC-5.3)", :aggregate_failures do
        other = create(:user).account
        lot = create(:lot, account:, entry:, quantity: 1)
        post catalog_entry_deck_additions_path(entry), params: { zone_id: deck.zone("main").id, use: "proxy:foil", quantity: "1",
                                                                  account_id: other.id, user_id: other.id, location_id: 0, kind: "place", lot_id: lot.id }

        expect(Deck::Proxy.sole.account_id).to eq(account.id)
        expect(lot.reload.location_id).to be_nil
      end
    end
```

(`before { deck }` is not set in this group: examples that need the deck reference `deck`/`zone`, which creates it; the proxy examples call `deck.zone` for the same reason. The "double submit" example posts twice sequentially; the genuinely concurrent case is covered by `Lot::MoveIntoZone`'s own lock and `Deck::Proxy.add!`'s retry, which spec 070 and spec 068 prove.)

- [ ] **Step 2:** `bin/rspec spec/requests/deck_additions_spec.rb`. Expected: these examples run against the finished page from T5; any that fail show a real gap (the notice's `set_number`, the `Moved 1 copy` pluralization, `flash` access in request specs: use `follow_redirect!` and read the notice from the page if `flash` isn't available in this project's request specs; `grep -rn 'flash\[:notice\]' spec/requests | head -3` shows the local idiom).
- [ ] **Step 3:** fix what failed in the code, never in the expectation's meaning; re-run until 0 failures.
- [ ] **Step 4: commit** `test(decks): the Add to deck writes, refusals and tenancy (spec 071, #255)`.

---

## Phase 4: The entry point

### T7: The card page's link and the visitor guards

**Implements:** decision 1 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4 | **Files:** `app/views/catalog/entries/show.html.erb`, `spec/requests/catalog/entries_show_spec.rb`, `spec/requests/catalog/visitors_spec.rb`, `spec/system/visitor_catalog_spec.rb` | **Interfaces:** (none)

- [ ] **Step 1: failing examples.** Append to `spec/requests/catalog/entries_show_spec.rb` (inside its signed-in context; read the file's helpers for `sign_in_as` and `entry`):

```ruby
  describe "the Add to deck action (spec 071 AC-1.1, AC-1.3, AC-1.4)" do
    let(:user) { create(:user) }
    let(:printing) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt")).entry }

    before { sign_in_as(user) }

    it "is a secondary link before Add a copy, to the page, keeping the collection mark", :aggregate_failures do
      get catalog_entry_path(printing, from: "collection")

      actions = Nokogiri::HTML5(response.body).at_css(".c-item__actions")
      links = actions.css("a.c-btn").map { [ it.text.squish, it["href"], it["class"] ] }
      expect(links.map(&:first)).to eq([ "Add to deck", "Add a copy" ])
      expect(links.first[1]).to eq(new_catalog_entry_deck_addition_path(printing, from: "collection"))
      expect(links.first[2]).to include("c-btn--secondary")
      expect(links.last[2]).to include("c-btn--primary")
      expect(actions.at_css("a.c-btn--secondary svg")).to be_present
    end

    it "is absent for a retired printing and a token (AC-1.3)", :aggregate_failures do
      [ create(:catalog_entry, :retired), create(:catalog_entry, kind: "token") ].each do |bad|
        get catalog_entry_path(bad)
        expect(response.body).not_to include("Add to deck"), bad.kind
      end
      get catalog_entry_path(printing) # the control: the same page for a live card has it
      expect(response.body).to include("Add to deck")
    end

    it "leaves the stats strip and the sections as they are, so #50's places are free (AC-1.4)", :aggregate_failures do
      get catalog_entry_path(printing)

      html = Nokogiri::HTML5(response.body)
      expect(html.css("dl.c-stats").size).to eq(1)
      expect(html.at_css("dl.c-stats")["class"]).to include("c-stats--single")
      expect(html.css("dl.c-stats .c-stat dt").map(&:text)).to eq([ "Owned" ])
      expect(response.body).not_to include("Free to use")
      expect(response.body).not_to include("In decks")
    end
  end
```

In `spec/requests/catalog/visitors_spec.rb`, add `"a[href*='/deck_additions/new']"` to the absent-selectors list (line ~196, beside `a[href*='/lots/new']`) and `"Add to deck"` to the absent-strings list (line ~202, beside "Add a copy"). In `spec/system/visitor_catalog_spec.rb` line ~52 add `expect(page).to have_no_text("Add to deck")` under `have_no_text("Add a copy")`. Add to the request file a positive-control-free example for the routes:

```ruby
  it "sends a visitor's request for the Add to deck page to sign in (spec 071 AC-1.2)", :public_catalog, :aggregate_failures do
    printing = create(:mtg_printing).entry
    get new_catalog_entry_deck_addition_path(printing)
    expect(response).to redirect_to(new_session_path)
  end
```
(read the file's existing visitor examples for the tag and the path helper they use for sign-in, and copy them.)

- [ ] **Step 2:** `bin/rspec spec/requests/catalog/entries_show_spec.rb spec/requests/catalog/visitors_spec.rb`. Expected: FAIL (no link yet; the visitor lists pass trivially until the link exists, so the first example is the red one).
- [ ] **Step 3: implement.** In `app/views/catalog/entries/show.html.erb`, inside the `c-item__actions` div, before the "Add a copy" link:

```erb
          <% if collector? && @entry.deck_addable? %>
            <%= link_to new_catalog_entry_deck_addition_path(@entry, **card_params), class: "c-btn c-btn--secondary" do %><%= render "icons/decks" %>Add to deck<% end %>
          <% end %>
```
- [ ] **Step 4:** run the specs. Expected: 0 failures.
- [ ] **Step 5: commit** `feat(catalog): an Add to deck action in the card page's head (spec 071, #255)`.

---

## Phase 5: Design system and the browser

### T8: The radio rows' coarse floor, and the browser examples

**Implements:** decision 17 | **Satisfies:** AC-1.5, AC-5.5, AC-6.1 to AC-6.5 | **Files:** `app/assets/stylesheets/collector/additions.css`, `spec/system/deck_additions_spec.rb`, `spec/system/card_page_spec.rb` | **Interfaces:** (none)

- [ ] **Step 1: failing examples.** Create `spec/system/deck_additions_spec.rb`:

```ruby
require "rails_helper"

# Spec 071 Story 5 (AC-5.5) and Story 6 (AC-6.1 to AC-6.5): the Add to deck page in a browser, with and without scripting.
RSpec.describe "Add to deck", type: :system do
  let(:long_card) { "W" * 60 }
  let(:entry) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt"), finishes: %w[nonfoil foil]).entry }

  def set_theme(name)
    page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
    sleep 0.6 # the buttons transition their background over 0.12s; a shot or a colour read right after a switch is mid-fade
  end

  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  context "with scripting" do
    let!(:user) { system_sign_in_as(create(:user)) }
    let(:account) { user.account }
    let(:deck) { create(:deck, account:, name: "D" * 60) }
    let(:wide_entry) { create(:mtg_printing, entry: create(:catalog_entry, name: long_card), finishes: %w[nonfoil foil]).entry }

    before do
      create(:lot, account:, entry: wide_entry, quantity: 2, location: create(:location, account:, name: "P" * 60))
      create(:lot, account:, entry: wide_entry, quantity: 1)
      deck
    end

    %w[light dark].each do |theme|
      [ 360, 640, 1280 ].each do |width|
        it "fits at #{width}px in the #{theme} theme with 60-character deck, place and card names (AC-6.1)", :aggregate_failures do
          visit catalog_entry_path(wide_entry) # the outer page hosts the frame
          open_in_narrow_frame(new_catalog_entry_deck_addition_path(wide_entry), width:, ready: "main")
          within_narrow_frame do
            set_theme(theme)
            expect(fits?).to be(true)
            overflow = page.evaluate_script(<<~JS)
              (() => { const form = document.querySelector(".c-form").getBoundingClientRect()
                const select = document.querySelector("#deck_zone").getBoundingClientRect()
                const text = document.createRange(); text.selectNodeContents(document.querySelector(".c-pick .c-check"))
                return { select: select.width <= form.width, text: text.getBoundingClientRect().right <= document.querySelector(".c-pick").getBoundingClientRect().right + 0.5,
                         title: document.querySelector(".c-pagehead__title").getBoundingClientRect().right <= window.innerWidth } })()
            JS
            expect(overflow).to eq("select" => true, "text" => true, "title" => true)
          end
        end
      end
    end

    it "shows the 2px focus ring on the radio row that has keyboard focus (AC-6.2)", :aggregate_failures do
      visit new_catalog_entry_deck_addition_path(wide_entry)
      find("#deck_zone").send_keys(:tab, :tab)
      expect(page.evaluate_script("document.activeElement.value")).to eq("copies")
      ring = page.evaluate_script("(() => { const s = getComputedStyle(document.activeElement.closest('label')); return [ s.outlineStyle, s.outlineWidth ] })()")
      expect(ring).to eq([ "solid", "2px" ])
    end

    # Headless Firefox has a fine pointer, so the coarse-pointer sizes are read from the stylesheet (spec 068's lesson). The rule
    # of each control type, in order: buttons (`.c-decks .c-btn`, every pointer), the select (`.c-decks .c-field select`, coarse),
    # the number field (components.css' `.c-input`, coarse), the radio rows (this spec's one rule, coarse).
    it "gives every control of the page the 44px floor by a rule it reads (AC-6.3, AC-6.4)", :aggregate_failures do
      visit new_catalog_entry_deck_addition_path(wide_entry)
      rules = page.evaluate_script(<<~JS)
        (() => { const found = {}
          for (const sheet of document.styleSheets) for (const media of sheet.cssRules) {
            if (!(media instanceof CSSMediaRule) || !media.conditionText.includes("pointer: coarse")) continue
            for (const rule of media.cssRules) {
              const sel = rule.selectorText || ""
              if (sel === ".c-decks .c-pick .c-check") found.check = rule.style.minHeight
              if (sel.includes(".c-decks .c-field select")) found.select = rule.style.minHeight
              if (sel.split(",").map((part) => part.trim()).includes(".c-input")) found.input = rule.style.minHeight
            } }
          found.floor = parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--touch-floor")) || 0
          found.buttons = [...document.querySelectorAll("main .c-btn")].map((el) => el.getBoundingClientRect().height)
          return found })()
      JS
      expect(rules.slice("check", "select")).to eq("check" => "var(--touch-floor)", "select" => "var(--touch-floor)")
      expect(rules["input"]).to eq("44px")
      expect(rules["floor"]).to be >= 44
      expect(rules["buttons"].size).to be >= 2 # Add to deck and Cancel
      expect(rules["buttons"]).to all(be >= 44)
    end

    it "keeps the new rule under its own heading, scoped to the pick list, with no colour or font literal (AC-6.4)", :aggregate_failures do
      css = Rails.root.join("app/assets/stylesheets/collector/additions.css").read
      block = css[/\/\* -+ Add to deck's radio rows \(spec 071\).*?(?=\n\/\* -{5,}|\z)/m]
      expect(block).to be_present
      expect(block).to include("@media (pointer: coarse) { .c-decks .c-pick .c-check { min-height:var(--touch-floor); } }")
      expect(block).not_to match(/#[0-9a-fA-F]{3,6}\b|font-family|rgb\(/)
    end
  end

  # AC-5.5: the whole path in a browser that runs no script, a system example per use. `driven_by :rack_test` comes before the
  # `let!` that signs in, or the sign-in would go through Firefox; the sign-in is a plain form.
  context "without scripting" do
    before { driven_by :rack_test }

    let!(:user) { system_sign_in_as(create(:user)) }
    let(:account) { user.account }
    let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }

    it "moves free copies from the card page to the deck page (AC-5.5)", :aggregate_failures do
      expect(page.driver).to be_a(Capybara::RackTest::Driver)
      create(:lot, account:, entry:, quantity: 2, location: create(:location, account:, name: "Blue binder"))
      visit catalog_entry_path(entry)
      click_link "Add to deck"
      select "Izzet Tempo › Main", from: "Deck and zone"
      fill_in "How many", with: "2"
      choose "My copies (2 free: 2 in Blue binder)"
      click_button "Add to deck"

      expect(page).to have_current_path(catalog_entry_path(entry))
      expect(page).to have_content("Moved 2 copies of Lightning Bolt to Izzet Tempo › Main.")
      expect(page).to have_css("#copies", text: "Izzet Tempo › Main")
      visit deck_path(deck)
      expect(page).to have_css("section.c-zone", text: "Lightning Bolt")
    end

    it "records a proxy from the card page and shows it on the deck page (AC-5.5)", :aggregate_failures do
      expect(page.driver).to be_a(Capybara::RackTest::Driver)
      visit catalog_entry_path(entry)
      click_link "Add to deck"
      select "Izzet Tempo › Sideboard", from: "Deck and zone"
      fill_in "How many", with: "3"
      choose "A proxy of #{ApplicationController.helpers.set_number(entry)} Foil"
      click_button "Add to deck"

      expect(page).to have_content("Added 3 proxies of Lightning Bolt (#{ApplicationController.helpers.set_number(entry)}, Foil) to Izzet Tempo › Sideboard.")
      visit deck_path(deck)
      expect(page).to have_css(".c-proxy", text: /Proxy\s+3/)
    end
  end
end
```

Replace the phone example in `spec/system/card_page_spec.rb` (lines ~19-26, the two width assertions) with the measurable checks of AC-1.5, and add the 360px and coarse cases:

```ruby
      widths = page.evaluate_script(<<~JS)
        [ ".c-item__actions", ".c-item__body" ].map((selector) => document.querySelector(selector).getBoundingClientRect().width)
      JS
      expect(widths[0]).to eq(widths[1])
      expect(head_row_fits).to eq("oneLine" => true, "inside" => true, "unclipped" => true, "overflow" => false)
```
and a helper plus examples (inside the same describe):

```ruby
  # The head's actions at the frame's width: on one line, every control inside the row, the primary not clipped, no overflow.
  def head_row_fits
    page.evaluate_script(<<~JS)
      (() => { const row = document.querySelector(".c-item__actions"), box = row.getBoundingClientRect()
        const controls = [...row.querySelectorAll(".c-btn")].map((el) => el.getBoundingClientRect())
        const primary = row.querySelector(".c-btn--primary")
        return { oneLine: Math.max(...controls.map((c) => c.height)) >= box.height - 1,
                 inside: controls.every((c) => c.left >= box.left - 0.5 && c.right <= box.right + 0.5),
                 unclipped: primary.scrollWidth <= primary.clientWidth + 1,
                 overflow: document.documentElement.scrollWidth > window.innerWidth } })()
    JS
  end

  it "keeps the head's three controls on one line at 360px, also with the coarse pointer's sizes (AC-1.5)", :aggregate_failures do
    system_sign_in_as(create(:user))
    visit catalog_entry_path(entry)
    open_in_narrow_frame(catalog_entry_path(entry), width: 360, height: 800, ready: ".c-item__title")
    within_narrow_frame do
      expect(page).to have_link("Add to deck")
      expect(head_row_fits).to eq("oneLine" => true, "inside" => true, "unclipped" => true, "overflow" => false)
      # A fine pointer doesn't apply components.css' coarse sizes (the menu is 8px wider); inject them, as the example's lesson asks.
      page.execute_script("const s = document.createElement('style'); s.textContent = '.c-btn { min-height:44px } .c-btn--icon { min-width:44px }'; document.head.append(s)")
      expect(head_row_fits).to eq("oneLine" => true, "inside" => true, "unclipped" => true, "overflow" => false)
    end
  end
```

(A card with no Scryfall link has no "…" menu: the entry's extension decides it, so the "menu absent" case is one more example that visits a card whose `MTG::Printing` has `scryfall_uri: nil`; add it with `create(:mtg_printing, entry:, scryfall_uri: nil)` if the factory allows `nil`, else skip the absent case and note it in `verification.md`.)

- [ ] **Step 2:** `bin/rspec spec/system/deck_additions_spec.rb spec/system/card_page_spec.rb`. Expected: FAIL on the floor examples (no rule yet) and, if the row doesn't fit, on `head_row_fits`.
- [ ] **Step 3: implement the CSS.** Append at the end of `app/assets/stylesheets/collector/additions.css`:

```css

/* ---------- Add to deck's radio rows (spec 071): a coarse pointer's 44px tap target ---------- */
/* A `.c-check` row is 20px high and its radio 16px wide, and the label is the whole tap target. The How many field and the
   buttons already reach 44px (components.css' coarse `.c-input`, `.c-decks .c-btn`) and the select has its own rule above, so the
   rows are the one control of the page left under the floor. Scoped to the Decks pages' pick list: no other page changes. */
@media (pointer: coarse) { .c-decks .c-pick .c-check { min-height:var(--touch-floor); } }
```

- [ ] **Step 4:** run both system files. Expected: 0 failures. If `head_row_fits` fails at 360px (the three controls don't fit), apply the spec's fallback: let the row wrap (`.c-item__actions { flex-wrap:wrap }` in the narrow `@container` block of `components.css`... but that file is the export: add the rule in `additions.css` under a heading of its own, scoped to `.c-item .c-item__actions`), re-run the deck page's examples (`bin/rspec spec/system/deck_page_spec.rb`, which read the same class) and record the change in `verification.md`. Do not loosen the AC.
- [ ] **Step 5: commit** `feat(design): the radio rows' coarse floor, and the Add to deck browser examples (spec 071, #255)`.

### T9: The design documents and previews

**Implements:** decision 9, 17; spec "Supersedes and updates" | **Satisfies:** AC-6.5 (documents), the supersession of spec 060 decision 14 | **Files:** `docs/design-system/components/AddToDeck.md`, `ItemPage.md`, `ItemPagePhone.md`, `VisitorHeader.md`, `docs/design-system/previews/AddToDeck.html`, `AddToDeckPhone.html`, `spec/system/design_system_deck_components_spec.rb` | **Interfaces:** (none)

- [ ] **Step 1: failing example.** In `spec/system/design_system_deck_components_spec.rb`, inside `describe "AddToDeck"`, with the helper unchanged:

```ruby
    it "fits a 360px frame with a proxy radio per finish, the rows wrapping (spec 071 decision 9)", :aggregate_failures do
      in_phone_frame(add_to_deck_html(long: true)) do
        expect_add_fit(add_fit)
        expect(evaluate("return document.querySelectorAll('#probe .c-choices input[type=radio]').length")).to eq(3)
      end
    end
```

- [ ] **Step 2:** `bin/rspec spec/system/design_system_deck_components_spec.rb -e "AddToDeck"`. Expected: the new example FAILs (the helper draws two radios, not three).
- [ ] **Step 3: implement.** Change `use_choices` to draw one proxy radio per finish (the markup the document will show):

```ruby
  def use_choices(place, finishes: %w[Nonfoil Foil])
    copies = %(<label class="c-check"><input type="radio" name="use" value="copies" required>My copies (3 free: 2 in #{place}, 1 in Red box)</label>)
    proxies = finishes.map { |finish| %(<label class="c-check"><input type="radio" name="use" value="proxy:#{finish.downcase}" required>A proxy of <span class="is-data">2X2 · 117</span> #{finish}</label>) }.join
    %(<fieldset class="c-choices c-pick"><legend class="c-field__label">What to use</legend>#{copies}#{proxies}</fieldset>)
  end
```
(the change is the proxy radios only; the existing examples read the first radio and the fieldset, and the call `use_choices(place)` in `add_to_deck_html` is unchanged)

Re-run: 0 failures, the existing focus example still lands on `copies` after two tabs.
- [ ] **Step 4: the documents.** (a) `AddToDeck.md`: in the markup, replace the one `proxy` radio by two (`value="proxy:nonfoil"` "A proxy of `2X2 · 117` Nonfoil" and `value="proxy:foil"` "… Foil"), and replace the two bullets "What to use has up to two options…" and "With two options nothing is chosen…" and "What #255 decides…" by:

```markdown
- **What to use** has "My copies" when copies are free, then one proxy option per finish the printing lists (spec 071 decision 9; spec 060 decision 14 drew a single proxy option for a printing with one finish), in the vocabulary's order. The option's words are the printing and the finish's label: "A proxy of `2X2 · 117` Foil", `SET · number` in mono (`is-data`), the finish in the vocabulary's case, nothing after the number for a printing that lists no finish. Radio values are `copies`, `proxy:<finish key>` and `proxy` (no finish). "My copies" gives the free count and where the copies are, "3 free: 2 in Blue binder, 1 in Red box", in the order a count takes them, copies with no location as "1 with no location", at most five places and then "and 2 more places".
- **With one option nothing else is needed and it is chosen** (`checked`: a printing with one finish or none, and no free copy); with two or more nothing is chosen and every radio is `required`, as `ChoicePage` does (spec 060 decision 14).
- **Which lots a count takes** is the server's (spec 071 decision 5): the shown printing's free lots first, then the card's other printings newest first, within a printing in the card page's "Your copies" order; whole lots, then the rest from the next lot. **The server's refusals** (spec 071 decision 11) are one sentence each under the field they belong to, as `Form` documents: "Choose a deck and zone." under the select, "Enter a number from 1 to N." under How many (N the free copies for My copies, 9,999 for a proxy), "Choose what to use." and "You have no free copy of Lightning Bolt to use." under the options, and above the actions "Nothing changed. Lightning Bolt (MH2 · 138) would have more than 9,999 copies in one lot." or "… can't be moved until it is edited."
- **The page's `main` carries `c-decks`** (the Decks pages' 44px floor for buttons and the select on a coarse pointer, and their long-name wrap); the radio rows take `min-height:var(--touch-floor)` on a coarse pointer under `.c-decks .c-pick`, and the number field has the app-wide `.c-input` coarse floor (spec 071 AC-6.3).
```
and change the Cancel bullet to say the back link and Cancel return to the card page, keeping its collection mark. (b) `AddToDeckPhone.html` and `AddToDeck.html`: replace the single proxy radio by the two radios above. (c) `ItemPage.md`: in the markup comment after `c-item__actions` write "Add to deck (secondary, the decks icon), Add a copy (primary), the … menu" and add a bullet "**Head actions.** For a signed-in collector: `Add to deck` (a secondary link to `AddToDeck`, shown when the printing can be added to a deck), `Add a copy` (primary) and, with a Scryfall link, the `…` menu. A visitor sees none of the first two. The stats strip, Your copies and In decks are the page's body and the actions take no room from them (spec 071 decision 1)." (d) `ItemPagePhone.md`: add under the actions bullet that the three controls stay on one line at 360px, `Add a copy` the flexible one. (e) `VisitorHeader.md` line 42: "The card page has no 'Owned' stat, no 'Your copies' section and no 'Add a copy' or 'Add to deck' button."
- [ ] **Step 5:** `bin/rspec spec/system/design_system_deck_components_spec.rb spec/design_system_files_spec.rb`. Expected: 0 failures. The documents are verified by reading, not by RSpec (`.claude/rules/testing.md`).
- [ ] **Step 6: commit** `docs(design-system): AddToDeck's per-finish proxy options, the head action and the radio floor (spec 071, #255)`.

---

## Phase 6: Guards and documents

### T10: The deck-code guard, the area docs, CLAUDE.md

**Implements:** decision 14, the documentation NFR | **Satisfies:** AC-6.5 (guard), the documentation duties | **Files:** `spec/deck_core_spec.rb`, `docs/architecture/collection-and-lots.md`, `docs/architecture/tenancy-and-accounts.md`, `CLAUDE.md`, `docs/specs/README.md` | **Interfaces:** (none)

- [ ] **Step 1: failing guard.** In `spec/deck_core_spec.rb`, add to the `patterns` list `app/controllers/deck_additions_controller.rb app/views/deck_additions/*.erb app/models/lot/free_copies.rb app/helpers/deck_additions_helper.rb` and extend the count: `…+ 15 + 5` with the comment `; spec 071 adds 5: the controller, its view, Lot::FreeCopies and the helper (new patterns) and deck/addition.rb (the glob already covers it)`. (If spec 070 has landed first, sum the counts when merging: keep both.)
- [ ] **Step 2:** `bin/rspec spec/deck_core_spec.rb`. Expected: PASS only if no new file names a collectible, format or zone key; a failure names the file, and the fix is to reword the comment or code (the likely hit is a comment with "standard" or "modern").
- [ ] **Step 3: area docs.** `collection-and-lots.md`: (a) Scope bullets: add "Adding a card to a deck from its card page: `DeckAdditionsController`, `Deck::Addition`, `Lot::FreeCopies`, the free-copies rule and the take (spec 071)". (b) Glossary: a **Free copy** entry: "a copy of a card, of any printing, in no deck zone (unplaced or in a place); Considering counts as a deck zone; proxies never count (spec 071 decision 4; spec 057 FR-3; `Lot.free`, spec 070)". (c) "The card page and search": add the head action and the page, in one paragraph: the link's place and conditions (decision 1, 2), the select (decision 3), the free definition and the take order (decisions 4, 5), the sentence (decision 7), the count's limits (decision 8), a proxy per finish (decision 9), the result and notice (decision 10: card page; ruled by the maintainer, option A), the refusals (decision 11), the empty state (decision 12). (d) "Named constants": `Lot::FreeCopies::PLACES_SHOWN` = 5, "Places named in the My copies sentence", spec 071 decision 7; `Deck::Addition::CHOOSE_ZONE`, `CHOOSE_USE`. (e) "Decisions not in an ADR": "**A count takes free lots in a stated order** (shown printing first, then newer printings, then the card page's order); the alternatives, the lowest condition first and the collector's own pick, were not chosen (spec 071 decision 5)" and "**A proxy of a printing with several finishes is one option per finish** (spec 071 decision 9; supersedes spec 060 decision 14's single option for such printings)". (f) Open issues: replace the #50 line's "The deck page is built (#253, spec 066); the shape panel (#256) and proxies (#254) are not;" by "The deck page, proxies and Add to deck are built (#253, #254, #255); the shape panel (#256) is not;" and add: "The card page's `Add to deck` is hidden for a retired printing or a token, even for My copies (spec 071 decision 2)". (g) Sources: add Spec 071 with its decisions and ACs. (h) Distillation log: left to `distill-feature`.
  `tenancy-and-accounts.md`: in the route/404 table add the row for `GET/POST /catalog/entries/:key/deck_additions`: another account's zone, a place's id, a deck's own row, a zone of another type's deck, a removed zone and a non-searchable printing are 404; signed out is sent to sign in; free lots are the account's own (spec 071 AC-1.2, AC-1.3, AC-5.2 to AC-5.4).
  `CLAUDE.md`: in the deck sentence add "a collector adds a card to a deck from its card page, free copies or a proxy (`Deck::Addition`, `Lot::FreeCopies`, spec 071)"; add `spec/deck_core_spec.rb`'s new names are not needed there.
  `docs/specs/README.md`: row 071 is already there ("Approved"); set its Areas column to "[Collection and lots](../architecture/collection-and-lots.md), [tenancy and accounts](../architecture/tenancy-and-accounts.md), [design system](../design-system/README.md) (`AddToDeck`)" and its Plan column to "in progress" (the distillation step changes both to frozen and retired).
- [ ] **Step 4:** `bin/yard doc` (a `{…}` or an unknown tag in the new comments fails it) and `bin/rubocop -a` on the changed Ruby files; fix findings. Expected: 0 warnings, 0 offenses.
- [ ] **Step 5: commit** `docs(architecture): add to a deck from the card page (spec 071, #255)`.

---

## Phase 7: Evidence and review

### T11: Screenshots and GIFs (the maintainer's run-wide requirement)

**Implements:** the PR's visual evidence | **Satisfies:** (evidence for AC-1.1, AC-2.x, AC-3.x, AC-4.x, AC-6.1) | **Files:** `docs/specs/071-add-to-deck-from-card-page/screenshots/*` (committed), a throwaway `spec/system/zz_071_screenshots_spec.rb` (deleted before the commit) | **Interfaces:** (none)

- [ ] **Step 1:** read `.claude/memory/pr-screenshots-workflow.md` (the throwaway-spec, theme, narrow-frame and `ffmpeg` recipes). Create the uncommitted `spec/system/zz_071_screenshots_spec.rb` building factory data (a signed-in user; "Izzet Tempo" deck; a Modern-legal Lightning Bolt with two printings and finishes nonfoil/foil; free copies in "Blue binder" and "Red box" and one with no location; a card with no free copy; an account with no deck for the empty state; a 60-character deck, place and card name) and saving into `ENV.fetch("SHOTS_DIR")`. Shots, each at 1280 and as a 390 `open_in_narrow_frame`, light and dark, with `data-theme` set explicitly for both (pause 0.6s after each switch):
  1. the card page head with Add to deck, Add a copy and the menu (desktop, phone);
  2. the page with free copies (My copies and two proxy radios, nothing chosen), with no free copy and one finish (the proxy chosen), and the empty state;
  3. refused states by the real form with `form.noValidate = true` then `requestSubmit()`: no zone and no choice, a count over the free copies, the cap, a lot that can't be moved;
  4. the long-name worst case at 360 (the select cut, the sentence wrapping);
  5. the card page after a move (notice, "Your copies" naming Deck › Zone) and the deck page showing the card.
- [ ] **Step 2: GIFs.** Frames step by step, repeating a frame to hold it, then `ffmpeg -framerate 4 -pattern_type glob -i 'f-*.png' -vf "scale=960:-1,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse" -loop 0 <name>.gif`, under about 1 MB each: (a) card page → Add to deck → My copies → card page notice → deck page (desktop); (b) the same with a proxy (desktop); (c) the My copies flow on a phone frame. Compress shots with `magick in.png -resize 1000x -quality 70 out.jpg`.
- [ ] **Step 3: look at every shot and frame** (Read each image). Fix anything wrong test-first (a new failing example in the matching spec, then the fix) and re-shoot the affected ones; record each finding and fix in `verification.md`.
- [ ] **Step 4:** delete `spec/system/zz_071_screenshots_spec.rb`; `git status` shows only the screenshots. Commit them in one commit `docs(specs): screenshots and walkthroughs of spec 071 (#255)`.

### T12: `verification.md`, the full gate and the implementation review

**Implements:** the hard gates | **Satisfies:** every AC (the table), NFR | **Files:** `docs/specs/071-add-to-deck-from-card-page/verification.md` | **Interfaces:** (none)

- [ ] **Step 1:** write `verification.md`: a table of every AC with the example that proves it (file and example name), the grep of the supersession list with each hit's disposition, the deviations (flat `params.permit` instead of `params.expect`, the reason being the no-choice 422; any head-row CSS change T8 needed), the open items, the shots and GIFs listed with what each shows ("factory data, placeholder card images").
- [ ] **Step 2:** `bin/rspec spec/models/lot spec/models/deck spec/models/location spec/models/catalog spec/helpers spec/requests/deck_additions_spec.rb spec/requests/catalog spec/system/deck_additions_spec.rb spec/system/card_page_spec.rb spec/system/design_system_deck_components_spec.rb spec/deck_core_spec.rb`. Expected: 0 failures.
- [ ] **Step 3:** ask the coordinator for a CI slot, then `bin/ci`; expected: every step green; release the slot with the SHA and the result. A failing shard is reproduced with its seed (`bin/ci rspec N/M`), never assumed a flake.
- [ ] **Step 4: implementation review** (`sdd-superpowers:sdd-review`, Mode B): a read-only Opus subagent given the diff, the spec and `verification.md`, reading the shots too; record it in `verification.md` under `## Implementation review` with the verdict on its first line; at most two rounds; blocking or major findings left after round two go to the coordinator with options and a recommendation.
- [ ] **Step 5:** `sdd-superpowers:session-wrap`, the `distill-feature` skill (area docs before the PR is ready), commit, and the push with a slot; the first push opens a **draft** PR that says `Closes #255`.

## Integration verification

Signed in as a collector with a deck, a card they own two free copies of (one in a binder, one unplaced) and the card's other printing: open the card page, "Add to deck", choose "Izzet Tempo › Main", 3, "My copies", submit: the card page's notice names the move, "Your copies" lists the lots as "Izzet Tempo › Main" and Owned is unchanged; the deck page shows the card with Owned 3. Then add a proxy of foil to Sideboard: the deck page shows the dashed tag. Signed out: the card page has no Add to deck and the routes sign in. At 360px in both themes nothing overflows.

## Quickstart validation

`bin/rspec spec/requests/deck_additions_spec.rb spec/models/deck/addition_spec.rb spec/models/lot/free_copies_spec.rb`, then open `/catalog/entries/<key>` in `bin/dev` as a signed-in user with a deck and press "Add to deck".

## Spec coverage (self-review)

| FR / Story | Task |
|------------|------|
| FR-1 (the action and the page) | T5, T6, T7 |
| FR-2 (free copies) | T0 (`Lot.free`), T1 |
| FR-3 (the take) | T0 (`MoveIntoZone`), T4 |
| Story 1 (AC-1.1 to 1.5) | T7 (1.1 to 1.4), T8 (1.5) |
| Story 2 (AC-2.1 to 2.9) | T3, T4, T5 |
| Story 3 (AC-3.1 to 3.12) | T4 (model), T6 (request) |
| Story 4 (AC-4.1 to 4.6) | T4, T6 (4.6: `Deck::Proxy.add!`'s retry, spec 068 AC-1.9, whose example is cited in `verification.md`) |
| Story 5 (AC-5.1 to 5.5) | T4, T6, T8 |
| Story 6 (AC-6.1 to 6.5) | T8, T9 |
| NFR performance (AC-2.9) | T1, T5 |
| NFR documentation | T9, T10 |
| Evidence (maintainer) | T11 |
