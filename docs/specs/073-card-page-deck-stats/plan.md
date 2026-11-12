# Implementation Plan: "Free to use" and "In decks" on the Card Page

**Spec:** docs/specs/073-card-page-deck-stats/spec.md (v0.2.3, Approved)
**Decisions:** none (no ADR; spec decisions 1 to 10)
**Created:** 2026-11-11

## Global Constraints

Binding on every task (from the spec, verbatim or as short as exactness allows):

- Scope is the card, every printing (retired included), for the signed-in account; a visitor reads nothing (decision 1).
- "Free" is `Lot.free` read through `Lot::FreeCopies`; "in decks" is the card's lots not among `Lot::FreeCopies#lots`; nothing on the page tests a location's kind to decide "in a deck" (decision 2). A proxy never changes Owned, In decks or Free to use.
- The strip: `c-stats c-stats--three`, Owned ("N printings"), In decks ("in N decks", N = decks holding at least one owned copy), Free to use ("not in a deck"), `number_with_delimiter` (decision 3).
- The section: `#in-decks`, after "Printings", before "Format legality"; columns Deck (link to `/decks/:id`, format muted beside), Zone, Owned, Proxy; one row per zone holding an owned copy or a proxy of the card; sums across printings, finishes and conditions; decks by comparison key then name, a deck's zones by id; Proxy 0 is a muted dash; no proxy tag; Zone and the format fold into `c-table__sub` ("Modern · Main") when the section is narrower than 640px (decision 4).
- Head count: "4 copies in 2 decks", then " · 2 proxy" (no plural); proxies only "2 proxy"; neither: none. Empty: "This card isn't in any of your decks." and, when `Catalog::Entry#deck_addable?`, an "Add to deck" link carrying `card_params` (decision 5).
- The Proxy column counts proxies of the card in any printing (decision 6).
- The reads hang off `Catalog::CardOverview`, which both `Catalog::EntriesController#show` and `Catalog::QuickAddsController`'s no-script 422 build (decision 7).
- No schema, no migration, no export change, no ADR (decision 8).
- Collectible-agnostic: new deck files and the card page's new parts name no collectible, format or zone key but `considering` (`spec/deck_core_spec.rb`); the head-count helper goes in `decks_helper.rb` (decision 9).
- One new CSS rule: `#in-decks td:first-child { white-space:normal; overflow-wrap:anywhere; }` under a `(spec 073)` heading in `additions.css`, and the existing `c-table__place` class on "Your copies"' Location cell if its zone label overflows (decision 10).
- Rubocop limits that `-a` cannot fix: `RSpec/ExampleLength` is 15 lines and `RSpec/MultipleMemoizedHelpers` is 5 `let`s per group: split an example or use a helper method, not a longer example.
- Commit order keeps every guard green: a task that makes an existing example fail edits that example in its own commit (Tasks 3.2, 4.3 name them).
- The page runs a constant number of statements whatever the lots, decks, zones or proxies (NFR; AC-3.3).
- Repo rules: tag spec types explicitly (`type: :request`, `type: :system`), `:aggregate_failures` on multi-expectation examples, no `any_instance_of`, no `sleep`; another account's record is built from `other = create(:user).account` with every record given `account: other` (lesson 2026-11-11); a new public class or method needs a YARD summary (`.claude/rules/code-documentation.md`; `bin/ci checks` fails without); keep `{…}` out of comments; `bin/rubocop -a` on each Ruby file; commits are small Conventional Commits ending `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`, one git operation per shell call; targeted `bin/rspec <file>` needs no CI slot, a full `bin/ci` does (ask the coordinator).
- Never read `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`, `*.sqlite3`; every `git grep` ends with `':!.kamal/secrets'`.

---

## Goal

A signed-in collector's card page shows Owned, In decks and Free to use for the card, and an "In decks" table of the zones that hold a copy or a proxy of it, read from one bounded set of statements and from the one existing definition of "free".

---

## Pre-implementation gates

- **Simplicity:** two components (`Deck::CardUses`, the reads on `Catalog::CardOverview`) and two partials; no dependency.
- **Anti-abstraction:** `Lot::FreeCopies`, `Lot.free`, `Deck#format_name`, `Deck.listing_order`'s terms and the existing table classes are used as they are; one value object (`Deck::CardUses::Row`).
- **Integration-first:** the contract between the pieces is `Deck::CardUses.new(account:, entry:, lots:)` and the four `Catalog::CardOverview` readers; Phase 1 and 2 write their tests before the views exist.

---

## Phase 1: Where a card is used (`Deck::CardUses`)

**Implements:** FR-1 (rows), decisions 4 and 6 | **Satisfies:** AC-2.2, AC-2.3 (sums), AC-2.4 (proxy-only row), AC-2.8, AC-2.9 and AC-1.6 (model level), decision 4's order
**Files:** `app/models/deck/card_uses.rb`, `spec/models/deck/card_uses_spec.rb`
**Interfaces:** Consumes: `Lot` rows (the card's lots in deck zones, passed in), `Deck::Proxy`, `Location` (`zones_of_decks`, `parent`), `Deck` (`name`, `format_name`, `to_param`). Produces: `Deck::CardUses.new(account:, entry:, lots:)` with `#rows` (`Array<Deck::CardUses::Row>`; `Row = Data.define(:deck, :zone, :owned, :proxy)`, `deck` a `Deck`, `zone` a `Location`), `#owned` (Integer), `#proxy` (Integer), `#deck_count` (Integer: decks with a row whose `owned` is positive). A nil account has no rows and runs no statement.

The one place that knows how a card's copies and proxies fall into deck zones. The caller hands it the card's lots that are in zones (so "in a deck" is decided once, by `Lot.free`'s complement); it reads the card's proxies and the zones' decks in a constant number of statements.

### Task 1.1: The model spec (write it, watch it fail)

- [ ] Create `spec/models/deck/card_uses_spec.rb`:

```ruby
require "rails_helper"

# Spec 073 decisions 4 and 6: the zones that hold a copy or a proxy of one card, summed across its printings.
RSpec.describe Deck::CardUses, type: :model do
  let(:account) { create(:user).account }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:entry) { printing }

  def printing(**attributes) = create(:mtg_printing, entry: create(:catalog_entry, identity:, **attributes)).entry

  # The lots the caller passes are the card's lots in deck zones; here every lot the account has is one.
  def uses(for_entry: entry) = described_class.new(account:, entry: for_entry, lots: account.lots.to_a)

  def shown(rows) = rows.map { [ it.deck.name, it.zone.name, it.owned, it.proxy ] }

  it "makes one row per zone, summing copies across printings, finishes and conditions and proxies across printings", :aggregate_failures do
    deck = create(:deck, account:, name: "Izzet Tempo")
    other = printing
    create_lot_in_zone(deck, "main", entry:, quantity: 2, finish: "foil")
    create_lot_in_zone(deck, "main", entry: other, quantity: 3, condition: "near_mint")
    create(:deck_proxy, zone: deck.zone("main"), entry:, finish: "nonfoil", quantity: 1)
    create(:deck_proxy, zone: deck.zone("main"), entry: other, finish: "foil", quantity: 2)

    expect(shown(uses.rows)).to eq([ [ "Izzet Tempo", "Main", 5, 3 ] ])
    expect(uses).to have_attributes(owned: 5, proxy: 3, deck_count: 1)
  end

  it "orders decks by comparison key then name and a deck's zones by id", :aggregate_failures do
    banana = create(:deck, account:, name: "Banana")
    apple = create(:deck, account:, name: "apple")
    create_lot_in_zone(banana, "main", entry:)
    create_lot_in_zone(apple, "sideboard", entry:)
    create_lot_in_zone(apple, "main", entry:)

    expect(shown(uses.rows).map { it.first(2) }).to eq([ %w[apple Main], %w[apple Sideboard], %w[Banana Main] ]) # "apple" sorts before "Banana" by key
  end

  it "makes a row for a zone that has only a proxy, with 0 owned, and leaves it out of the deck count", :aggregate_failures do
    deck = create(:deck, account:, name: "Proxy only")
    create(:deck_proxy, zone: deck.zone("considering"), entry:, finish: "nonfoil", quantity: 2)

    expect(shown(uses.rows)).to eq([ [ "Proxy only", "Considering", 0, 2 ] ])
    expect(uses).to have_attributes(owned: 0, proxy: 2, deck_count: 0)
  end

  it "counts a deck once however many of its zones hold copies" do
    deck = create(:deck, account:)
    create_lot_in_zone(deck, "main", entry:)
    create_lot_in_zone(deck, "considering", entry:)

    expect(uses.deck_count).to eq(1)
  end

  it "reads only this account's proxies, and only of this card's printings", :aggregate_failures do
    deck = create(:deck, account:, name: "Mine")
    create(:deck_proxy, zone: deck.zone("main"), entry:, quantity: 1)
    create(:deck_proxy, zone: deck.zone("main"), entry: create(:mtg_printing).entry, quantity: 4) # another card
    other = create(:user).account # another account: every record is its own
    theirs = create(:deck, account: other, name: "Theirs")
    create(:deck_proxy, zone: theirs.zone("main"), entry:, account: other, quantity: 8)
    create_lot_in_zone(theirs, "main", entry:, quantity: 6)

    expect(shown(uses.rows)).to eq([ [ "Mine", "Main", 0, 1 ] ]) # the control: the owner's own proxy is there
    expect(described_class.new(account: other, entry:, lots: other.lots.to_a).rows.map { it.deck.name }).to eq([ "Theirs" ])
  end

  it "has no rows and runs no statement for a visitor (no account)", :aggregate_failures do
    entry.identity # loaded beforehand: only the object's own reads are counted
    visitor = described_class.new(account: nil, entry:, lots: [])
    statements = count_queries { visitor.rows }

    expect(statements).to eq(0)
    expect([ visitor.rows, visitor.owned, visitor.proxy, visitor.deck_count ]).to eq([ [], 0, 0, 0 ])
  end
end
```

- [ ] Run `bin/rspec spec/models/deck/card_uses_spec.rb` — expect: FAIL (`uninitialized constant Deck::CardUses`).
- [ ] Commit (stage, then commit, separate calls): `test: add Deck::CardUses examples (spec 073)`.

### Task 1.2: The model

- [ ] Create `app/models/deck/card_uses.rb`:

```ruby
# Where an account uses one card in its decks: a row per deck zone that holds a copy or a proxy of the card, summed across the
# card's printings (spec 073 decisions 4 and 6). Behind the card page's "In decks" section and the "in N decks" line of its
# stats.
#
# "In a deck" is not decided here: the caller passes the card's lots that are in deck zones (`Catalog::CardOverview#deck_lots`,
# the complement of `Lot::FreeCopies`), so `Lot.free` stays the one definition. Proxies are read here, by the card's identity,
# because they are never lots. Two statements for the proxies and the zones' decks plus one preload each for a zone's deck
# and the deck's own row, however many zones there are; none for a nil account or for a card in no deck.
#
# Takes the account explicitly and never reads `Current.account`. Collectible-agnostic.
# @see file:collection-and-lots.md
class Deck::CardUses
  # The zones' parent, the deck's location, for the order of the rows; a deck's zones have one.
  PARENT_JOIN = "INNER JOIN locations parents ON parents.id = locations.parent_id".freeze

  # One zone that holds a copy or a proxy of the card: its `deck` (a `Deck`), the `zone` (a `Location`), the copies of the card
  # in it (`owned`) and the proxies of the card in it (`proxy`), each summed across printings.
  Row = Data.define(:deck, :zone, :owned, :proxy)

  # @param account [Account, nil] whose decks are read; nil (a visitor) reads nothing
  # @param entry [Catalog::Entry] the shown printing; its identity is the card
  # @param lots [Array<Lot>] the card's lots that are in deck zones (all of them are counted in `owned`)
  def initialize(account:, entry:, lots:)
    @account, @entry, @lots = account, entry, lots
  end

  # The zones with a copy or a proxy of the card, decks by comparison key then name (the order `Deck.listing_order` uses) and a
  # deck's zones by id (the deck's own order).
  #
  # @return [Array<Row>]
  def rows = @rows ||= build_rows

  # The copies of the card in deck zones.
  #
  # @return [Integer]
  def owned = rows.sum(&:owned)

  # The proxies of the card, in every zone.
  #
  # @return [Integer]
  def proxy = rows.sum(&:proxy)

  # The decks that hold at least one owned copy of the card; a deck with only a proxy of it is not counted (a proxy is never
  # owned).
  #
  # @return [Integer]
  def deck_count = rows.select { it.owned.positive? }.map { it.deck.id }.uniq.size

  private
    def build_rows
      return [] unless @account

      owned = @lots.group_by(&:location_id).transform_values { |group| group.sum(&:quantity) }
      proxies = proxies_by_zone
      ids = owned.keys | proxies.keys
      return [] if ids.empty?

      zones = @account.locations.zones_of_decks.where(id: ids).joins(PARENT_JOIN)
        .order("parents.name_key", "parents.name", "locations.id").preload(parent: :deck)
      zones.map { |zone| Row.new(deck: zone.parent.deck, zone:, owned: owned.fetch(zone.id, 0), proxy: proxies.fetch(zone.id, 0)) }
    end

    # One statement: the account's proxies of any printing of the card, summed by zone.
    def proxies_by_zone
      Deck::Proxy.where(account_id: @account.id).joins(:entry)
        .where(catalog_entries: { catalog_identity_id: @entry.catalog_identity_id }).group(:location_id).sum(:quantity)
    end
end
```

- [ ] Run `bin/rspec spec/models/deck/card_uses_spec.rb` — expect: PASS (6 examples). If the ordering example fails, `parents.name_key` is the comparison key column of the deck's location (`Location#name_key`); confirm with `git grep -n name_key -- app/models/location.rb ':!.kamal/secrets'`.
- [ ] Run `bin/rubocop -a app/models/deck/card_uses.rb spec/models/deck/card_uses_spec.rb` — expect: no offenses.
- [ ] Commit: `feat: add Deck::CardUses, the zones a card is used in (spec 073)`.

---

## Phase 2: The card page's reads (`Catalog::CardOverview`)

**Implements:** FR-1, decisions 2, 3 and 7 | **Satisfies:** AC-1.5 (definition agrees), AC-1.6 (model level), AC-3.1 (nothing read for a visitor, model level)
**Files:** `app/models/catalog/card_overview.rb`, `spec/models/catalog/card_overview_spec.rb`
**Interfaces:** Consumes: `Lot::FreeCopies.new(account:, entry:)` (`#lots`, `#total`), `Deck::CardUses.new(account:, entry:, lots:)`. Produces on `Catalog::CardOverview`: `#free_count` (Integer: `Lot::FreeCopies#total`; 0 for a visitor), `#deck_lots` (Array<Lot>: the card's lots not among the free ones; [] for a visitor), `#in_decks_count` (Integer: their quantities), `#uses` (a `Deck::CardUses`).

### Task 2.1: Failing examples

- [ ] Append to `spec/models/catalog/card_overview_spec.rb`, before the final `end`:

```ruby
  describe "the card's decks (spec 073)" do
    let(:deck_a) { create(:deck, account:, name: "Alpha") }
    let(:deck_b) { create(:deck, account:, name: "Beta") }

    def overview(entry) = described_class.new(account:, entry:)

    it "splits what is owned into in-decks and free, Considering counted as in a deck", :aggregate_failures do
      a, b = printing(Date.new(2020, 1, 1)), printing(Date.new(2021, 1, 1))
      create_lot_in_zone(deck_a, "main", entry: a, quantity: 2)
      create_lot_in_zone(deck_b, "considering", entry: b, quantity: 1)
      create(:lot, account:, entry: a, quantity: 3, location: create(:location, account:)) # in a place: free
      create(:lot, account:, entry: b, quantity: 1) # no location: free
      create(:lot, account:, entry: create(:mtg_printing).entry, quantity: 5, location: deck_a.zone("main")) # another card: not counted

      overview = overview(a)
      expect([ overview.owned_count, overview.in_decks_count, overview.free_count ]).to eq([ 7, 3, 4 ])
      expect(overview.free_count).to eq(Lot::FreeCopies.new(account:, entry: a).total) # the definition, not a copy of it
      expect(overview.deck_lots.map(&:quantity)).to contain_exactly(2, 1)
      expect(overview.uses.deck_count).to eq(2)
    end

    it "never counts a proxy as owned, in a deck or free", :aggregate_failures do
      entry = printing(Date.new(2020, 1, 1))
      create(:lot, account:, entry:, quantity: 2)
      before = overview(entry).then { [ it.owned_count, it.in_decks_count, it.free_count, it.uses.deck_count ] }
      create(:deck_proxy, zone: deck_a.zone("main"), entry:, quantity: 4)

      after = overview(entry)
      expect([ after.owned_count, after.in_decks_count, after.free_count, after.uses.deck_count ]).to eq(before)
      expect(after.uses.proxy).to eq(4)
    end

    it "reads nothing for a visitor", :aggregate_failures do
      entry = printing(Date.new(2020, 1, 1))
      visitor = described_class.new(account: nil, entry:)
      entry.identity # the identity is the page's own read, loaded beforehand

      statements = count_queries { [ visitor.free_count, visitor.in_decks_count, visitor.deck_lots, visitor.uses.rows ] }
      expect(statements).to eq(0)
      expect([ visitor.free_count, visitor.in_decks_count, visitor.deck_lots, visitor.uses.rows ]).to eq([ 0, 0, [], [] ])
    end
  end
```

- [ ] Run `bin/rspec spec/models/catalog/card_overview_spec.rb` — expect: the 3 new examples FAIL (`undefined method 'in_decks_count'`).
- [ ] Commit: `test: add CardOverview deck and free examples (spec 073)`.

### Task 2.2: The readers

- [ ] In `app/models/catalog/card_overview.rb`, after `def total_printings …`, add:

```ruby
  # The copies of the card the account can put in a deck: `Lot.free` read through `Lot::FreeCopies`, the one definition of
  # "free" (specs 070, 071 and 073). Built on first use; a visitor never builds it.
  #
  # @return [Lot::FreeCopies]
  def free_copies = @free_copies ||= Lot::FreeCopies.new(account: @account, entry:)

  # The copies of the card that are free to use (spec 073 decision 2): in no deck zone, Considering counted as in a deck.
  #
  # @return [Integer] 0 for a visitor
  def free_count = @account ? free_copies.total : 0

  # The card's lots that are in a deck zone: the card's lots that are not among the free ones, so "in a deck" is the
  # complement of `Lot.free` and is never tested on a location's kind here. A proxy is not a lot and is not among them.
  #
  # @return [Array<Lot>] empty for a visitor
  def deck_lots
    @deck_lots ||= begin
      free = @account ? free_copies.lots.to_set(&:id) : Set.new
      lots.reject { free.include?(it.id) }
    end
  end

  # The copies of the card in deck zones, so that Owned is this plus {#free_count}.
  #
  # @return [Integer]
  def in_decks_count = deck_lots.sum(&:quantity)

  # The zones of the account's decks that hold a copy or a proxy of the card, for the "In decks" section and the stats' deck
  # count.
  #
  # @return [Deck::CardUses]
  def uses = @uses ||= Deck::CardUses.new(account: @account, entry:, lots: deck_lots)
```

- [ ] Run `bin/rspec spec/models/catalog/card_overview_spec.rb spec/models/deck/card_uses_spec.rb` — expect: PASS.
- [ ] Run `bin/rubocop -a app/models/catalog/card_overview.rb spec/models/catalog/card_overview_spec.rb` — expect: no offenses.
- [ ] Commit: `feat: CardOverview reads free copies and the card's deck lots (spec 073)`.

---

## Phase 3: The stats strip

**Implements:** FR-2, decision 3 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-3.2 (strip part)
**Files:** `app/views/catalog/entries/_stats.html.erb`, `app/views/catalog/entries/show.html.erb`, `spec/requests/catalog/card_page_decks_spec.rb`, `spec/requests/catalog/entries_show_spec.rb`, `spec/requests/catalog/quick_adds_spec.rb`
**Interfaces:** Consumes: `Catalog::CardOverview#owned_count`, `#printings_owned`, `#in_decks_count`, `#free_count`, `#uses` (`#deck_count`). Produces: partial `catalog/entries/_stats` (local `overview`), the request spec file Phase 4 extends (helpers `html`, `strip`, `table_rows`).

### Task 3.1: Failing request examples for the strip

- [ ] Create `spec/requests/catalog/card_page_decks_spec.rb`:

```ruby
require "rails_helper"

# Spec 073: the card page's stats strip (Story 1) and "In decks" section (Story 2) for a signed-in collector.
RSpec.describe "Card page: Free to use and In decks", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:card) { create(:mtg_printing, entry: create(:catalog_entry, identity:, released_on: Date.new(2022, 1, 1))).entry }
  let(:older) { create(:mtg_printing, entry: create(:catalog_entry, identity:, released_on: Date.new(2020, 1, 1))).entry }

  before { sign_in_as(user) }

  def html = Nokogiri::HTML5(response.body)

  # The strip as { "Owned" => [ "7", "3 printings" ], … }.
  def strip = html.css("dl.c-stats .c-stat").to_h { [ it.at_css("dt").text, [ it.at_css("dd").text, it.at_css("small").text ] ] }

  def place = create(:location, account:)

  # Another account whose deck holds the card: 5 copies in its Sideboard and 2 proxies in its Main. Every record is its own
  # account's (lesson 2026-11-11: another account's lot and zone are built from one account). Returns the other user.
  def other_account_deck(name)
    other_user = create(:user)
    deck = create(:deck, account: other_user.account, name:)
    create_lot_in_zone(deck, "sideboard", entry: card, quantity: 5)
    create(:deck_proxy, zone: deck.zone("main"), entry: card, account: other_user.account, quantity: 2)
    other_user
  end

  def switch_to(other_user)
    delete session_path
    sign_in_as(other_user)
  end

  describe "the stats strip" do
    it "shows Owned, In decks and Free to use as three stats for a card in no deck (AC-1.1)", :aggregate_failures do
      create(:lot, account:, entry: card, quantity: 3)
      get catalog_entry_path(card)

      expect(html.css("dl.c-stats").size).to eq(1)
      expect(html.at_css("dl.c-stats")["class"].split).to include("c-stats--three")
      expect(html.at_css("dl.c-stats")["class"]).not_to include("c-stats--single")
      expect(strip).to eq("Owned" => [ "3", "1 printing" ], "In decks" => [ "0", "in 0 decks" ], "Free to use" => [ "3", "not in a deck" ])
    end

    it "counts copies in zones, Considering included, as in decks and the rest as free (AC-1.2)", :aggregate_failures do
      alpha, beta = create(:deck, account:, name: "Alpha"), create(:deck, account:, name: "Beta")
      create_lot_in_zone(alpha, "main", entry: card, quantity: 2)
      create_lot_in_zone(beta, "considering", entry: older, quantity: 1)
      create(:lot, account:, entry: card, quantity: 3, location: place)
      create(:lot, account:, entry: older, quantity: 1)
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "7", "2 printings" ], "In decks" => [ "3", "in 2 decks" ], "Free to use" => [ "4", "not in a deck" ])
    end

    it "writes each number with its delimiter (AC-1.2)" do
      deck = create(:deck, account:)
      create_lot_in_zone(deck, "main", entry: card, quantity: 9_999)
      create_lot_in_zone(deck, "sideboard", entry: older, quantity: 2_346)
      create(:lot, account:, entry: card, quantity: 9_999)
      create(:lot, account:, entry: older, quantity: 2_346)
      get catalog_entry_path(card)

      expect(strip.transform_values(&:first)).to eq("Owned" => "24,690", "In decks" => "12,345", "Free to use" => "12,345")
    end

    it "has Free to use 0 and In decks equal to Owned when every copy is in a deck (AC-1.3)" do
      deck = create(:deck, account:)
      create_lot_in_zone(deck, "main", entry: card, quantity: 2)
      create_lot_in_zone(deck, "sideboard", entry: card, quantity: 1)
      get catalog_entry_path(card)

      expect(strip.transform_values(&:first)).to eq("Owned" => "3", "In decks" => "3", "Free to use" => "0")
    end

    it "changes none of the three numbers when a proxy is added to a zone of the same deck or of another deck (AC-1.4)", :aggregate_failures do
      first, second = create(:deck, account:, name: "First"), create(:deck, account:, name: "Second")
      create_lot_in_zone(first, "main", entry: card, quantity: 1)
      create(:lot, account:, entry: card, quantity: 1)
      get catalog_entry_path(card)
      before = strip
      expect(before).to eq("Owned" => [ "2", "1 printing" ], "In decks" => [ "1", "in 1 deck" ], "Free to use" => [ "1", "not in a deck" ])

      [ first.zone("sideboard"), second.zone("main") ].each { create(:deck_proxy, zone: it, entry: card, quantity: 2) }
      get catalog_entry_path(card)
      expect(strip).to eq(before)
    end

    it "reads 0, 0 printings and in 0 decks for a card with only a proxy (AC-1.4)" do
      create(:deck_proxy, zone: create(:deck, account:).zone("main"), entry: card, quantity: 1)
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "0", "0 printings" ], "In decks" => [ "0", "in 0 decks" ], "Free to use" => [ "0", "not in a deck" ])
    end

    it "gives the card's own numbers and agrees with Lot::FreeCopies (AC-1.5)", :aggregate_failures do
      deck = create(:deck, account:)
      other_card = create(:mtg_printing).entry
      create_lot_in_zone(deck, "main", entry: card, quantity: 4)
      create(:lot, account:, entry: card, quantity: 2, location: place)
      create(:lot, account:, entry: card, quantity: 1, finish: "foil")
      create_lot_in_zone(deck, "main", entry: other_card, quantity: 9) # another card in a zone
      create(:lot, account:, entry: other_card, quantity: 8) # another card, free
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "7", "1 printing" ], "In decks" => [ "4", "in 1 deck" ], "Free to use" => [ "3", "not in a deck" ])
      expect(Lot::FreeCopies.new(account:, entry: card).total).to eq(3)
    end

    it "counts nothing of another account's lots and proxies, and shows them on that account's own page (AC-1.6)", :aggregate_failures do
      create(:lot, account:, entry: card, quantity: 1)
      other_user = other_account_deck("Their Deck Name")
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "1", "1 printing" ], "In decks" => [ "0", "in 0 decks" ], "Free to use" => [ "1", "not in a deck" ])
      expect(response.body).not_to include("Their Deck Name")

      switch_to(other_user) # the control: the same page for the other account shows their numbers and their deck
      get catalog_entry_path(card)
      expect(strip).to eq("Owned" => [ "5", "1 printing" ], "In decks" => [ "5", "in 1 deck" ], "Free to use" => [ "0", "not in a deck" ])
      expect(response.body).to include("Their Deck Name")
    end
  end
end
```

(The "Their Deck Name" assertion on the owner's page is the same absence Phase 4 checks for the table; here it also guards the strip.)

- [ ] Run `bin/rspec spec/requests/catalog/card_page_decks_spec.rb` — expect: FAIL (the strip is still the single stat).
- [ ] Commit: `test: add card page stats strip examples (spec 073)`.

### Task 3.2: The partial and the page

- [ ] Create `app/views/catalog/entries/_stats.html.erb`:

```erb
<%# The card page's stats for a collector (spec 073 decision 3): Owned, In decks and Free to use, for the card as a whole. A proxy is in none of them. %>
<dl class="c-stats c-stats--three">
  <div class="c-stat"><dt>Owned</dt><dd><%= number_with_delimiter(overview.owned_count) %></dd><small><%= pluralize(overview.printings_owned, "printing") %></small></div>
  <div class="c-stat"><dt>In decks</dt><dd><%= number_with_delimiter(overview.in_decks_count) %></dd><small>in <%= pluralize(overview.uses.deck_count, "deck") %></small></div>
  <div class="c-stat"><dt>Free to use</dt><dd><%= number_with_delimiter(overview.free_count) %></dd><small>not in a deck</small></div>
</dl>
```

- [ ] In `app/views/catalog/entries/show.html.erb` replace

```erb
        <dl class="c-stats c-stats--single">
          <div class="c-stat"><dt>Owned</dt><dd><%= number_with_delimiter(@overview.owned_count) %></dd><small><%= pluralize(@overview.printings_owned, "printing") %></small></div>
        </dl>
```

with

```erb
        <%= render "catalog/entries/stats", overview: @overview %>
```

- [ ] The card page now reads proxies, zones and decks, so the card path's "zone minus place" difference in `spec/requests/query_counts_spec.rb` (the example at line 110, "keeps the grid's, the table's, the bulk table's and the card page's queries to a place's plus one for lots in zones") rises above 1 and the example goes red. Change it in this same commit: rename it "keeps the grid's, the table's and the bulk table's queries to a place's plus one for lots in zones", delete `card: catalog_entry_path(entry)` from its `paths` hash, and add above it the comment line `# The card page reads the card's decks too (spec 073) and is judged by its own example below.` (Task 5.2 adds that example.)
- [ ] Run `bin/rspec spec/requests/catalog/card_page_decks_spec.rb spec/requests/query_counts_spec.rb` — expect: PASS (the strip examples; the examples at `query_counts_spec.rb` lines 58 and 97 stay green: their shapes have no zone lots and no proxies, so both runs gain the same statements, which `verification.md` records).

### Task 3.3: The existing examples this changes

- [ ] In `spec/requests/catalog/entries_show_spec.rb`, replace the example "leaves the stats strip and the sections as they are, so #50's places are free (AC-1.4)" (lines 278 to 287; it is in the spec 071 describe) with:

```ruby
    it "has the three-stat strip, which spec 073 puts where spec 071 left room for it (supersedes spec 071 AC-1.4)", :aggregate_failures do
      get catalog_entry_path(card)

      html = Nokogiri::HTML5(response.body)
      expect(html.css("dl.c-stats").size).to eq(1)
      expect(html.at_css("dl.c-stats")["class"].split).to include("c-stats--three")
      expect(html.css("dl.c-stats .c-stat dt").map(&:text)).to eq([ "Owned", "In decks", "Free to use" ])
    end
```

- [ ] In `spec/requests/catalog/quick_adds_spec.rb` line 55, replace

```ruby
    expect(html.css(".c-stat dt").map(&:text)).to eq([ "Owned" ]) # spec 023 AC-6.2: the collection parts stay
```

with

```ruby
    expect(html.css(".c-stat dt").map(&:text)).to eq([ "Owned", "In decks", "Free to use" ]) # spec 023 AC-6.2: the collection parts stay (spec 073 adds two stats and the section)
```

- [ ] Run `bin/rspec spec/requests/catalog/card_page_decks_spec.rb spec/requests/catalog/quick_adds_spec.rb spec/requests/catalog/entries_show_spec.rb` — expect: PASS. Run `bin/rubocop -a` on the changed spec files — expect: no offenses (examples within 15 lines).
- [ ] Commit once, with the view, the partial and the examples they turn red: `feat: card page stats show In decks and Free to use (spec 073)`.

---

## Phase 4: The "In decks" section

**Implements:** FR-3, decisions 4, 5, 6, 10 | **Satisfies:** AC-2.1 to AC-2.10, AC-3.2, AC-5.3 (markup)
**Files:** `app/views/catalog/entries/_decks.html.erb`, `app/views/catalog/entries/show.html.erb`, `app/helpers/decks_helper.rb`, `spec/helpers/decks_helper_spec.rb`, `app/assets/stylesheets/collector/additions.css`, `spec/requests/catalog/card_page_decks_spec.rb`
**Interfaces:** Consumes: `Catalog::CardOverview#uses` (`#rows`, `#owned`, `#proxy`, `#deck_count`), `Catalog::Entry#deck_addable?`, `card_params`, `new_catalog_entry_deck_addition_path`, `deck_path`, `Deck#format_name`. Produces: partial `catalog/entries/_decks` (local `overview`), `DecksHelper#card_decks_count_line(uses)` (String), the CSS rule.

### Task 4.1: The head count (helper), test first

- [ ] Create `spec/helpers/decks_helper_spec.rb`:

```ruby
require "rails_helper"

# Spec 073 decision 5 and AC-2.6: the count beside the card page's "In decks".
RSpec.describe DecksHelper, type: :helper do
  describe "#card_decks_count_line" do
    def line(owned:, decks:, proxy:) = helper.card_decks_count_line(instance_double(Deck::CardUses, owned:, deck_count: decks, proxy:))

    it "reads the copies, the decks and the proxies", :aggregate_failures do
      expect(line(owned: 4, decks: 2, proxy: 2)).to eq("4 copies in 2 decks · 2 proxy")
      expect(line(owned: 1, decks: 1, proxy: 0)).to eq("1 copy in 1 deck")
      expect(line(owned: 0, decks: 0, proxy: 2)).to eq("2 proxy")
      expect(line(owned: 1, decks: 1, proxy: 1)).to eq("1 copy in 1 deck · 1 proxy")
      expect(line(owned: 0, decks: 0, proxy: 0)).to eq("")
    end

    it "delimits thousands" do
      expect(line(owned: 12_345, decks: 1_000, proxy: 1_234)).to eq("12,345 copies in 1,000 decks · 1,234 proxy")
    end
  end
end
```

- [ ] Run `bin/rspec spec/helpers/decks_helper_spec.rb` — expect: FAIL (`undefined method 'card_decks_count_line'`).
- [ ] In `app/helpers/decks_helper.rb`, after `deck_page_line`, add:

```ruby
  # "4 copies in 2 decks · 2 proxy": the count beside the card page's "In decks" (spec 073 decision 5). The copies and the decks
  # come first, only when copies are in decks; the proxies follow, as the deck pages count them ("proxy" has no plural).
  #
  # @param uses [Deck::CardUses]
  # @return [String] empty when the card is in no deck zone and has no proxy
  def card_decks_count_line(uses)
    parts = []
    parts << "#{pluralize(number_with_delimiter(uses.owned), "copy")} in #{pluralize(number_with_delimiter(uses.deck_count), "deck")}" if uses.owned.positive?
    parts << "#{number_with_delimiter(uses.proxy)} proxy" if uses.proxy.positive?
    parts.join(" · ")
  end
```

- [ ] Run `bin/rspec spec/helpers/decks_helper_spec.rb` — expect: PASS. Run `bin/rubocop -a app/helpers/decks_helper.rb spec/helpers/decks_helper_spec.rb`.
- [ ] Commit: `feat: add the In decks count line helper (spec 073)`.

### Task 4.2: Failing request examples for the section

- [ ] In `spec/requests/catalog/card_page_decks_spec.rb`, add before the final `end`:

```ruby
  # Each row as [ deck name, deck href, zone, owned, proxy ].
  def table_rows
    html.css("#in-decks tbody tr").map do |tr|
      cells = tr.css("td")
      [ tr.at_css("a").text, tr.at_css("a")["href"], cells[1].text.strip, cells[2].text.strip, cells[3].text.strip ]
    end
  end

  describe "the In decks section" do
    it "follows Printings and precedes Format legality, with the four headers (AC-2.1)", :aggregate_failures do
      create_lot_in_zone(create(:deck, account:, name: "Alpha"), "main", entry: card)
      get catalog_entry_path(card)

      body = response.body
      expect([ body.index(%(id="printings")), body.index(%(id="in-decks")), body.index("Format legality") ]).to eq(
        [ body.index(%(id="printings")), body.index(%(id="in-decks")), body.index("Format legality") ].sort)
      expect(html.css("#in-decks .c-collection table.c-table thead th").map { it.text.squish }).to eq([ "Deck", "Zone", "Owned", "Proxy" ])
      expect(html.at_css("#in-decks h2.c-section__title").text).to eq("In decks")
      expect(html.at_css("#in-decks table")["aria-labelledby"]).to eq(html.at_css("#in-decks h2")["id"])
    end

    it "makes a row per zone with a link to the deck, the format beside the name and the zone's own name (AC-2.1)", :aggregate_failures do
      beta = create(:deck, account:, name: "Beta", format: "commander")
      apple = create(:deck, account:, name: "apple")
      create_lot_in_zone(beta, "main", entry: card, quantity: 1)
      create_lot_in_zone(apple, "sideboard", entry: card, quantity: 2)
      create_lot_in_zone(apple, "main", entry: card, quantity: 3)
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ "apple", deck_path(apple), "Main", "3", "—" ], [ "apple", deck_path(apple), "Sideboard", "2", "—" ],
                                 [ "Beta", deck_path(beta), "Main", "1", "—" ] ])
      first = html.at_css("#in-decks tbody tr")
      expect(first.at_css("span.is-opt.is-muted").text.squish).to eq("· Modern")
      expect(first.at_css(".c-table__sub").text.squish).to eq("Modern · Main")
      expect(html.at_css("#in-decks tbody tr:nth-child(3) span.is-opt.is-muted").text.squish).to eq("· Commander")
    end

    it "sums across printings, finishes and conditions, and proxies across printings (AC-2.2)", :aggregate_failures do
      deck = create(:deck, account:, name: "Alpha")
      create_lot_in_zone(deck, "main", entry: card, quantity: 2, finish: "foil")
      create_lot_in_zone(deck, "main", entry: older, quantity: 3, condition: "near_mint")
      create(:deck_proxy, zone: deck.zone("main"), entry: card, finish: "nonfoil", quantity: 1)
      create(:deck_proxy, zone: deck.zone("main"), entry: older, finish: "foil", quantity: 2)
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ "Alpha", deck_path(deck), "Main", "5", "3" ] ])
    end

    it "has a Considering row, and the table's Owned sums to the strip's In decks, with delimiters (AC-2.3)", :aggregate_failures do
      alpha, beta = create(:deck, account:, name: "Alpha"), create(:deck, account:, name: "Beta")
      create_lot_in_zone(alpha, "considering", entry: card, quantity: 1)
      create_lot_in_zone(alpha, "main", entry: card, quantity: 9_999)
      create_lot_in_zone(alpha, "main", entry: older, quantity: 9_999)
      create_lot_in_zone(beta, "sideboard", entry: card, quantity: 2)
      get catalog_entry_path(card)

      expect(table_rows.map { it[2..3] }).to eq([ [ "Main", "19,998" ], [ "Considering", "1" ], [ "Sideboard", "2" ] ])
      expect(table_rows.sum { it[3].delete(",").to_i }).to eq(strip.fetch("In decks").first.delete(",").to_i)
    end

    it "has a row with Owned 0 and the proxy count, as plain text, for a zone with only a proxy (AC-2.4)", :aggregate_failures do
      deck = create(:deck, account:, name: "Proxies")
      create(:deck_proxy, zone: deck.zone("main"), entry: card, quantity: 2)
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ "Proxies", deck_path(deck), "Main", "0", "2" ] ])
      expect(html.css("#in-decks .c-proxy")).to be_empty
      expect(html.css("#in-decks td.is-muted")).to be_empty # the control for the dash below: a proxy cell with a count is not muted
    end

    it "shows a muted dash in the Proxy cell for a zone with no proxy (AC-2.4)" do
      create_lot_in_zone(create(:deck, account:), "main", entry: card)
      get catalog_entry_path(card)

      expect(html.css("#in-decks tbody td")[3].then { [ it.text.strip, it["class"].split ] }).to eq([ "—", %w[is-num is-muted] ])
    end

    it "shows the format's key when the extension no longer registers it, and answers 200 (AC-2.5)", :aggregate_failures do
      deck = create(:deck, account:, name: "Old")
      create_lot_in_zone(deck, "main", entry: card)
      deck.update!(format: "gone")
      get catalog_entry_path(card)

      expect(response).to have_http_status(:ok)
      expect(html.at_css("#in-decks span.is-opt.is-muted").text.squish).to eq("· gone")
    end

    def count_line = html.at_css("#in-decks .c-section__count")&.text

    it "words the head count for copies in decks and proxies (AC-2.6)", :aggregate_failures do
      alpha, beta = create(:deck, account:, name: "Alpha"), create(:deck, account:, name: "Beta")
      create_lot_in_zone(alpha, "main", entry: card, quantity: 3)
      create_lot_in_zone(beta, "main", entry: card, quantity: 1)
      get catalog_entry_path(card)
      expect(count_line).to eq("4 copies in 2 decks")

      create(:deck_proxy, zone: alpha.zone("sideboard"), entry: card, quantity: 2)
      get catalog_entry_path(card)
      expect(count_line).to eq("4 copies in 2 decks · 2 proxy")
    end

    it "words the head count for one copy, for proxies only and for neither (AC-2.6)", :aggregate_failures do
      deck = create(:deck, account:, name: "Alpha")
      create_lot_in_zone(deck, "main", entry: card, quantity: 1)
      get catalog_entry_path(card)
      expect(count_line).to eq("1 copy in 1 deck")

      lone = create(:mtg_printing).entry
      create(:deck_proxy, zone: deck.zone("main"), entry: lone, quantity: 2)
      get catalog_entry_path(lone)
      expect(count_line).to eq("2 proxy")

      get catalog_entry_path(create(:mtg_printing).entry)
      expect(count_line).to be_nil
    end

    it "does not count a deck that holds only a proxy as a deck in the head count (AC-2.6)" do
      copies, proxies = create(:deck, account:, name: "Copies"), create(:deck, account:, name: "Proxies")
      create_lot_in_zone(copies, "main", entry: card, quantity: 1)
      create(:deck_proxy, zone: proxies.zone("main"), entry: card, quantity: 1)
      get catalog_entry_path(card)

      expect(count_line).to eq("1 copy in 1 deck · 1 proxy")
    end

    it "says the card is in no deck, with an Add to deck link that keeps the collection mark (AC-2.7)", :aggregate_failures do
      get catalog_entry_path(card, from: "collection")

      expect(html.css("#in-decks table")).to be_empty
      expect(html.at_css("#in-decks p.c-empty").text.squish).to eq("This card isn't in any of your decks. Add to deck")
      expect(html.at_css("#in-decks p.c-empty a")["href"]).to eq(new_catalog_entry_deck_addition_path(card, from: "collection"))
    end

    it "has no link in the empty state for a retired printing, and is drawn for an account with no decks (AC-2.7)", :aggregate_failures do
      retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
      get catalog_entry_path(retired)

      expect(response).to have_http_status(:ok)
      expect(html.at_css("#in-decks p.c-empty").text.squish).to eq("This card isn't in any of your decks.")
      expect(html.css("#in-decks a")).to be_empty
      expect(account.decks).to be_empty # the account has no deck at all, and the section is still drawn
    end

    it "counts a lot of a retired printing as it counts the others (AC-2.8)", :aggregate_failures do
      retired = create(:mtg_printing, entry: create(:catalog_entry, :retired, identity:)).entry
      deck = create(:deck, account:, name: "Alpha")
      create_lot_in_zone(deck, "main", entry: retired, quantity: 2)
      create(:deck_proxy, zone: deck.zone("main"), entry: retired, quantity: 1)
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ "Alpha", deck_path(deck), "Main", "2", "1" ] ])
      expect(strip.fetch("In decks")).to eq([ "2", "in 1 deck" ])
    end

    it "shows nothing of another account's deck, zone, lot or proxy (AC-2.9)", :aggregate_failures do
      mine = "Owner Deck #{SecureRandom.hex(4)}" # built at run time, so a literal in the page can't be a coincidence
      deck = create(:deck, account:, name: mine)
      create_lot_in_zone(deck, "main", entry: card, quantity: 1)
      other_user = other_account_deck("Their Deck Name")
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ mine, deck_path(deck), "Main", "1", "—" ] ]) # the control: the owner's own row is there
      expect(response.body).not_to include("Their Deck Name")

      switch_to(other_user)
      get catalog_entry_path(card)
      expect(response.body).to include("Their Deck Name")
      expect(response.body).not_to include(mine)
    end

    it "shows a renamed deck's new name (AC-2.10)", :aggregate_failures do
      deck = create(:deck, account:, name: "Before")
      create_lot_in_zone(deck, "main", entry: card)
      get catalog_entry_path(card)
      expect(table_rows.first.first).to eq("Before")

      deck.rename("After")
      get catalog_entry_path(card)
      expect(table_rows.first.first).to eq("After")
    end

    it "does not write to lots, locations, decks or deck proxies (AC-3.4)", :aggregate_failures do
      deck = create(:deck, account:)
      create_lot_in_zone(deck, "main", entry: card)
      create(:deck_proxy, zone: deck.zone("main"), entry: card)

      writes = %w[lots locations decks deck_proxies].flat_map { |table| write_statements_to(table) { get catalog_entry_path(card) } }
      expect(writes).to be_empty
      expect(write_statements_to("lots") { create(:lot, account:, entry: card) }).not_to be_empty # the control: the spy sees a write
    end

    it "uses only c- and is- classes and no inline style, and marks the Owned cell numeric (AC-5.3)", :aggregate_failures do
      create_lot_in_zone(create(:deck, account:), "main", entry: card)
      get catalog_entry_path(card)

      expect(html.css("#in-decks [class], dl.c-stats [class]").flat_map { it["class"].split }.uniq).to all(match(/\A(c|is)-/))
      expect(html.css("#in-decks [style], dl.c-stats [style]")).to be_empty
      expect(html.css("#in-decks tbody td")[2]["class"].split).to include("is-num")
    end
  end
end
```

- [ ] Run `bin/rspec spec/requests/catalog/card_page_decks_spec.rb` — expect: the new section examples FAIL (`#in-decks` absent).
- [ ] Run `bin/rubocop -a spec/requests/catalog/card_page_decks_spec.rb` — expect: no offenses (every example is within 15 lines; the file has 5 `let`s).
- [ ] Commit: `test: add card page In decks section examples (spec 073)`.

### Task 4.3: The section, the page and the CSS

- [ ] Create `app/views/catalog/entries/_decks.html.erb`:

```erb
<%# "In decks" (spec 073 decisions 4 and 5): a row per deck zone that holds a copy or a proxy of the card, for a collector. Owned counts copies, Proxy counts proxies, each across the card's printings. A proxy never counts as owned. %>
<% uses = overview.uses %>
<section id="in-decks">
  <div class="c-section__head">
    <h2 class="c-section__title" id="in-decks-title">In decks</h2>
    <% if (line = card_decks_count_line(uses)).present? %><span class="c-section__count"><%= line %></span><% end %>
  </div>
  <% if uses.rows.empty? %>
    <p class="c-empty">This card isn't in any of your decks.<% if overview.entry.deck_addable? %> <%= link_to "Add to deck", new_catalog_entry_deck_addition_path(overview.entry, **card_params) %><% end %></p>
  <% else %>
    <div class="c-collection">
      <table class="c-table" aria-labelledby="in-decks-title">
        <thead><tr><th>Deck</th><th class="is-opt">Zone</th><th class="is-num">Owned</th><th class="is-num">Proxy</th></tr></thead>
        <tbody>
          <% uses.rows.each do |row| %>
            <tr>
              <td><div class="c-table__item"><div><%= link_to row.deck.name, deck_path(row.deck) %><span class="is-opt is-muted"> · <%= row.deck.format_name %></span><span class="c-table__sub"><%= row.deck.format_name %> · <%= row.zone.name %></span></div></div></td>
              <td class="is-opt"><%= row.zone.name %></td>
              <td class="is-num"><%= number_with_delimiter(row.owned) %></td>
              <% if row.proxy.zero? %><td class="is-num is-muted">—</td><% else %><td class="is-num"><%= number_with_delimiter(row.proxy) %></td><% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% end %>
</section>
```

- [ ] In `app/views/catalog/entries/show.html.erb`, between the printings and legality lines:

```erb
      <%= render "catalog/entries/printings", overview: @overview %>
      <%= render "catalog/entries/decks", overview: @overview if collector? %>
      <%= render_catalog_extension @entry, :legality %>
```

- [ ] In `app/assets/stylesheets/collector/additions.css`, after the `.c-stats--three` block (the `@container page (max-width: 639px) { … }` that ends with `.c-stats.c-stats--three .c-stat + .c-stat { … }` and its closing brace), add:

```css

/* ---------- Card page "In decks" (spec 073): a deck's name wraps ---------- */
/* The export's `.c-table td` is nowrap, and the only rule that lets a deck's name wrap is the Decks pages' (`.c-decks td:first-child`),
   so a deck named with 60 characters and no space scrolled the card page sideways at 360px. Scoped by the section's id, so
   "Your copies" and "Printings" keep their cells. */
#in-decks td:first-child { white-space:normal; overflow-wrap:anywhere; }
```

- [ ] In the same file change the heading comment `/* ---------- Card page: details list, single stat, faces ---------- */` to `/* ---------- Card page: details list, single stat (SingleStat; the card page itself uses c-stats--three since spec 073), faces ---------- */`. Nothing else in the file is reordered or reformatted.
- [ ] A card in no deck now has two links named "Add to deck" (the head's and the empty state's), so two existing no-script examples that click the bare name are ambiguous: in `spec/system/deck_additions_spec.rb` lines 152 and 168 replace `click_link "Add to deck"` with `within(".c-item__actions") { click_link "Add to deck" }` (the head's link is the one these examples are about). Do it in this same commit.
- [ ] The section names the zone in its own Zone column ("Main") on the deck's row, next to the deck's link, so the "zone's name alone" check of `spec/requests/zone_place_label_spec.rb` line 27 would now find "Main" on the card page. In that example replace `expect(without_label).not_to include("Main")` with

```ruby
    # "In decks" names the zone in its own Zone column on the deck's row, next to the deck's link (spec 073 decision 4), so it is
    # never the zone's name alone (spec 062 decision 6); the check is on the rest of the page.
    expect(without_label.sub(%r{<section id="in-decks">.*?</section>}m, "")).not_to include("Main")
```

  and do it in this same commit.
- [ ] Run `bin/rspec spec/requests/catalog/card_page_decks_spec.rb spec/requests/catalog/entries_show_spec.rb spec/requests/catalog/quick_adds_spec.rb spec/requests/zone_place_label_spec.rb spec/helpers/decks_helper_spec.rb spec/system/deck_additions_spec.rb` — expect: PASS. (If `card_decks_count_line` is not found in the view, check `git grep -n include_all_helpers -- config app ':!.kamal/secrets'`; none was found at planning time, so all helpers load.)
- [ ] Run `bin/rubocop -a` on the changed Ruby files; run `bin/rspec spec/requests/catalog spec/requests/deck_additions_spec.rb` — expect: PASS (the other card page examples are unchanged).
- [ ] Commit (view, CSS rule and the three existing-example edits): `feat: card page In decks section (spec 073)`.

### Task 4.4: The existing examples that read the section

- [ ] In `spec/requests/catalog/entries_show_spec.rb`, in the example rewritten in Task 3.3, add after the strip assertion `expect(html.at_css("#in-decks h2").text).to eq("In decks")`; and in the order example ("shows the sections in order and only the listed paper formats", line 147) replace the marker list with:

```ruby
    order = [ "c-item__image", "c-item__title", "c-chip--cards", "c-rules", "c-details", "<dt>Owned</dt>", "Your copies",
      %(<h2 class="c-section__title">Printings</h2>), "In decks</h2>", "Format legality" ]
```

- [ ] In `spec/requests/catalog/quick_adds_spec.rb`, add after the "answers an over-cap add without scripting with the card page at 422" example (AC-3.2: the refused page has the same numbers as a plain visit, for data that has a deck):

```ruby
  it "shows the same stats and In decks table as a plain visit when the no-script add is refused (spec 073 AC-3.2)", :aggregate_failures do
    create(:lot, account: user.account, entry:, quantity: 9_999)
    create_lot_in_zone(create(:deck, account: user.account, name: "Izzet Tempo"), "main", entry:, quantity: 2)
    post catalog_entry_quick_add_path(entry)
    refused = Nokogiri::HTML5(response.body)
    get catalog_entry_path(entry)
    plain = Nokogiri::HTML5(response.body)

    [ ".c-stat dd", "#in-decks tbody td" ].each do |selector|
      expect(refused.css(selector)).not_to be_empty # the control: the refused page has the parts
      expect(refused.css(selector).map { it.text.squish }).to eq(plain.css(selector).map { it.text.squish })
    end
    expect(refused.css(".c-stat dd").map(&:text)).to eq(%w[10,001 2 9,999])
  end
```

- [ ] Run `bin/rspec spec/requests/catalog/entries_show_spec.rb spec/requests/catalog/quick_adds_spec.rb` — expect: PASS. Run `bin/rubocop -a` on both files.
- [ ] Commit: `test: existing card page examples read the In decks section (spec 073)`.

---

## Phase 5: The guards (core names, statement counts, visitor)

**Implements:** FR-1 "Must not", NFR Performance, Security | **Satisfies:** AC-3.1, AC-3.3
**Files:** `spec/deck_core_spec.rb`, `spec/requests/query_counts_spec.rb`, `spec/requests/catalog/visitors_spec.rb`
**Interfaces:** Consumes: everything above. Produces: nothing.

### Task 5.1: The collectible-agnostic guard

- [ ] In `spec/deck_core_spec.rb`, add to `patterns` a new line after the last pattern line (`app/controllers/deck_additions_controller.rb … deck_additions_helper.rb`):

```
    app/models/catalog/card_overview.rb app/views/catalog/entries/_stats.html.erb app/views/catalog/entries/_decks.html.erb
```

  and change the count arithmetic `20 + 6 + 1 + 1 + 4 + 1 + 15 + 2 + 6 + 5` to `20 + 6 + 1 + 1 + 4 + 1 + 15 + 2 + 6 + 5 + 4` (61 + 4 = 65), appending to that line's trailing comment: `; spec 073 adds 4: `deck/card_uses.rb` (the `app/models/deck/*.rb` glob already covers it), `catalog/card_overview.rb` and the card page's `_stats` and `_decks` partials (new patterns; the page's `show.html.erb` is not listed, because its `scryfall` link variable names a source)`.
- [ ] Run `bin/rspec spec/deck_core_spec.rb` — expect: PASS. If "never names a game…" fails on a new file (a comment naming a format key or a game), reword that comment: the guard reads comments too.
- [ ] Commit: `test: cover the card page's deck files with the core-names guard (spec 073)`.

### Task 5.2: Statement counts

- [ ] In `spec/requests/query_counts_spec.rb`, add after the example at line 110 (which Task 3.2 narrowed to the grid, the table and the bulk table):

```ruby
  # Decks of the account with a lot and a proxy of the card in each of the zones, and free lots in places, every one on a printing of
  # the card other than the shown one (spec 073 AC-3.3).
  def stock_card_decks(identity, decks:, zones:, free_lots:)
    decks.times do
      deck = create(:deck, account: user.account, name: "Deck #{Deck.count}")
      zones.each do |zone|
        create_lot_in_zone(deck, zone, entry: printing(identity:), quantity: 2)
        create(:deck_proxy, zone: deck.zone(zone), entry: printing(identity:), quantity: 1)
      end
    end
    free_lots.times { own(printing(identity:), location: create(:location, account: user.account)) }
  end

  # Spec 073 AC-3.3: the card page's reads don't grow with the account's lots, places, decks, zones or proxies. Both runs have the
  # same shape (a free lot, a lot in a zone and a proxy, on printings other than the shown one) so every preload has rows to load
  # and the request's query cache hides none (spec 070's lesson); the page is warmed once before each count.
  it "keeps the card page's queries independent of the number of lots, decks, zones and proxies (spec 073 AC-3.3)" do
    entry = printing(identity:)
    stock_card_decks(identity, decks: 1, zones: %w[main], free_lots: 1)
    queries_for(catalog_entry_path(entry)) # warm
    few = queries_for(catalog_entry_path(entry))
    stock_card_decks(identity, decks: 10, zones: %w[main sideboard considering], free_lots: 20)
    queries_for(catalog_entry_path(entry)) # warm

    expect(queries_for(catalog_entry_path(entry))).to eq(few)
  end
```

  (`create_lot_in_zone` is available to request specs: `spec/support/deck_helpers.rb`.)
- [ ] Run `bin/rspec spec/requests/query_counts_spec.rb` — expect: PASS.
- [ ] Prove the example can fail (lesson 2026-11-11): temporarily change `.preload(parent: :deck)` in `app/models/deck/card_uses.rb` to `.preload(:parent)` and make `Row.new(deck: …)` read `Deck.find_by(location_id: zone.parent_id)`; run the example — expect: FAIL (the counts differ); restore with `git checkout app/models/deck/card_uses.rb`. Record the result for `verification.md` (do not commit the mutation).
- [ ] Run `bin/rubocop -a spec/requests/query_counts_spec.rb`; commit: `test: bound the card page's statement count with decks and proxies (spec 073)`.

### Task 5.3: The visitor

- [ ] In `spec/requests/catalog/visitors_spec.rb`:
  - in the absent-selector list of "shows a visitor no collection part and no tenant data (AC-4.1)" add `"#in-decks"` after `"#copies"`, and extend its text list to `[ "Not owned", "Your copies", "Add a copy", "Add to deck", " owned", "In decks", "Free to use" ]`;
  - replace the example "runs no query against lots for a visitor (AC-4.2)" with:

```ruby
    it "runs no query against lots, locations, decks or deck proxies for a visitor (AC-4.2; spec 073 AC-3.1)", :aggregate_failures do
      pages.each do |path|
        statements = statements_during { get path }
        expect(response).to have_http_status(:ok), path
        expect(statements.grep(/"(lots|locations|decks|deck_proxies)"/)).to be_empty, path
      end
    end

    it "reads those tables for a signed-in collector's card page, so the visitor example's grep can fail (control of spec 073 AC-3.1)", :aggregate_failures do
      deck = create(:deck, account: collector.account)
      create_lot_in_zone(deck, "main", entry: printing)
      create(:deck_proxy, zone: deck.zone("main"), entry: printing)
      sign_in_as(collector)
      statements = statements_during { get catalog_entry_path(printing) }

      %w[lots locations decks deck_proxies].each { |table| expect(statements.grep(/"#{table}"/)).not_to be_empty, table }
    end
```

- [ ] Run `bin/rspec spec/requests/catalog/visitors_spec.rb` — expect: PASS. If the visitor grep finds `"locations"` or `"decks"` from a part of the page that is not a collection part (the header, say), name the statement in the failure and narrow the grep to the table names that statement does not read; do not hide a real read.
- [ ] Commit: `test: a visitor's card page reads no deck tables (spec 073)`.

---

## Phase 6: Layout, themes and the no-script path (system specs)

**Implements:** Story 4, Story 5 | **Satisfies:** AC-4.1, AC-5.1, AC-5.2, AC-5.3, AC-5.4
**Files:** `spec/system/card_page_decks_spec.rb`, `spec/system/card_page_decks_no_script_spec.rb`, `app/views/catalog/entries/_copies.html.erb`
**Interfaces:** Consumes: `open_in_narrow_frame`, `within_narrow_frame` (`spec/support/narrow_frame.rb`), `system_sign_in_as`, `create_lot_in_zone`.

### Task 6.1: The system examples

- [ ] Create `spec/system/card_page_decks_spec.rb`:

```ruby
require "rails_helper"

# Spec 073 Stories 4 and 5: the stats strip and the In decks table at phone and laptop widths, in both themes. Headless Firefox has a
# fine pointer, so no coarse rule is measured: AC-5.4 lists the controls and the rules that cover them.
RSpec.describe "Card page: Free to use and In decks", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:card) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", released_on: Date.new(2022, 1, 1))).entry }

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")

  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  describe "the stats strip (AC-5.1)" do
    before do
      older = create(:mtg_printing, entry: create(:catalog_entry, identity: card.identity, released_on: Date.new(2020, 1, 1))).entry
      deck = create(:deck, account:, name: "Alpha")
      create_lot_in_zone(deck, "main", entry: card, quantity: 9_999)
      create_lot_in_zone(deck, "sideboard", entry: older, quantity: 2_346)
      create(:lot, account:, entry: card, quantity: 9_999)
      create(:lot, account:, entry: older, quantity: 2_346)
    end

    %w[light dark].each do |theme|
      [ 360, 390 ].each do |width|
        it "is three across with nothing clipped at #{width}px in the #{theme} theme", :aggregate_failures do
          visit catalog_entry_path(card) # the outer page hosts the frame
          open_in_narrow_frame(catalog_entry_path(card), width:, ready: ".c-stats--three")
          within_narrow_frame do
            set_theme(theme)
            shown = page.evaluate_script(<<~JS)
              (() => { const stats = [ ...document.querySelectorAll(".c-stats--three .c-stat") ]
                const parts = [ ...document.querySelectorAll(".c-stats--three dt, .c-stats--three dd, .c-stats--three small") ]
                return { texts: stats.map((s) => s.querySelector("dd").textContent),
                         oneRow: new Set(stats.map((s) => Math.round(s.getBoundingClientRect().top))).size === 1,
                         clipped: parts.some((el) => el.scrollWidth > el.clientWidth + 1) } })()
            JS
            expect(shown).to eq("texts" => %w[24,690 12,345 12,345], "oneRow" => true, "clipped" => false)
            expect(fits?).to be(true)
          end
        end
      end
    end
  end

  describe "the table (AC-5.2)" do
    let(:deck) { create(:deck, account:, name: "D" * 60) }

    before do
      create_lot_in_zone(deck, "main", entry: card, quantity: 2)
      create(:deck_proxy, zone: deck.zone("considering"), entry: card, quantity: 1)
    end

    # The headers a reader sees, then the section's own width.
    def shown_headers = page.evaluate_script('[ ...document.querySelectorAll("#in-decks thead th") ].filter((th) => th.getClientRects().length > 0).map((th) => th.textContent.trim())')

    def section_width = page.evaluate_script('document.querySelector("#in-decks .c-collection").getBoundingClientRect().width')

    %w[light dark].each do |theme|
      [ 360, 390, 640, 1024 ].each do |width|
        it "folds Zone and the format under the name, keeps Owned and Proxy and does not scroll sideways at #{width}px in the #{theme} theme", :aggregate_failures do
          visit catalog_entry_path(card)
          open_in_narrow_frame(catalog_entry_path(card), width:, ready: "#in-decks table")
          within_narrow_frame do
            set_theme(theme)
            expect(section_width).to be < 640
            expect(shown_headers).to eq([ "Deck", "Owned", "Proxy" ])
            expect(page).to have_css("#in-decks tbody tr:first-child .c-table__sub", text: "Modern · Main", visible: :visible)
            expect(find("#in-decks td:first-child a", match: :first).native.rect.height).to be > 20 # the 60-character name wraps
            expect(fits?).to be(true)
          end
        end
      end

      it "shows all four columns, the format beside the name and no overflow at 1280px in the #{theme} theme", :aggregate_failures do
        visit catalog_entry_path(card)
        open_in_narrow_frame(catalog_entry_path(card), width: 1280, ready: "#in-decks table")
        within_narrow_frame do
          set_theme(theme)
          expect(section_width).to be >= 640
          expect(shown_headers).to eq([ "Deck", "Zone", "Owned", "Proxy" ])
          expect(page).to have_css("#in-decks tbody tr:first-child span.is-muted", text: "· Modern", visible: :visible)
          expect(page).to have_no_css("#in-decks .c-table__sub", visible: :visible)
          expect(fits?).to be(true)
        end
      end
    end

    it "carries the wrap rule, scoped to the section and written with no token (AC-5.3)" do
      visit catalog_entry_path(card)
      rule = page.evaluate_script(<<~JS)
        (() => { const rules = [ ...document.styleSheets ].flatMap((sheet) => [ ...sheet.cssRules ])
          const found = rules.find((r) => r.selectorText === "#in-decks td:first-child")
          return found && { white: found.style.whiteSpace, wrap: found.style.overflowWrap } })()
      JS
      expect(rule).to eq("white" => "normal", "wrap" => "anywhere")
    end
  end
end
```

  The no-script path is its own file because `driven_by :rack_test` is an instance method that must run in a `before` placed above the `let!` that signs in (spec 067's lesson; the pattern of `spec/system/deck_additions_spec.rb:141`), and the file above signs in for every group.

- [ ] Create `spec/system/card_page_decks_no_script_spec.rb`:

```ruby
require "rails_helper"

# Spec 073 AC-4.1: card page, then the deck's name in "In decks", then the deck page, with no scripting.
RSpec.describe "Card page to deck page without scripting", type: :system do
  before { driven_by :rack_test } # an instance method: before the `let!` that signs in, or the sign-in goes through Firefox

  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:card) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt")).entry }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  it "follows the deck's name from the card page to that deck's page, which lists the card", :aggregate_failures do
    expect(page.driver).to be_a(Capybara::RackTest::Driver)
    create_lot_in_zone(deck, "main", entry: card, quantity: 2)
    visit catalog_entry_path(card)
    within("#in-decks") { click_link "Izzet Tempo" }

    expect(page).to have_current_path(deck_path(deck))
    expect(page).to have_css("h1", text: "Izzet Tempo")
    expect(page).to have_css(".c-zone table", text: "Lightning Bolt")
    expect(page).to have_no_css("#in-decks") # the section is the card page's, not the deck page's
    expect(page).to have_no_text("In decks")
  end
end
```

- [ ] Run `bin/rspec spec/system/card_page_decks_spec.rb spec/system/card_page_decks_no_script_spec.rb` — expect: the 1280px examples FAIL (see Task 6.2), the rest PASS. Rules for any other failure: a 360px overflow means the wrap rule needs a hook (the name's `.c-table__item > div` flex item: the Decks page's equivalent needed only a rule like Task 4.3's, so first confirm `#in-decks` is on the `section`); a frame width whose section reads 640 or more where the example expects less means the page column is wider than estimated: measure it, change the example's list of folded widths to the measured ones and record the numbers in `verification.md` (the criterion is "narrower than 640px", not a list of device widths).
- [ ] Run `bin/rubocop -a spec/system/card_page_decks_spec.rb spec/system/card_page_decks_no_script_spec.rb` — expect: no offenses (`RSpec/MultipleMemoizedHelpers` max 5: the file's lets are `user`, `account`, `card` and, in one group, `deck`).
- [ ] Commit: `test: card page layout, themes and the no-script path to the deck (spec 073)`.

### Task 6.2: "Your copies" wraps a long zone label

At 1280px the page is wider than the section only because of "Your copies": its Location cell (`td.is-data.is-opt`) is `white-space:nowrap` (`components.css:110`) and holds the lot's label "DDD…D › Main", about 550px in mono. The existing rule of spec 048 (`.c-table td.c-table__place:not(.is-muted)`, `.c-table__place-name`, `additions.css` near line 97) is the collection table's answer to the same problem; the card page takes it, so this is a class, not a new rule (decision 10).

- [ ] Confirm the failure is "Your copies": run the 1280px example and read which cell is widest, or evaluate `[...document.querySelectorAll("td")].find((td) => td.getBoundingClientRect().right > window.innerWidth)` in a throwaway statement of the example; expect the Location cell of `#copies`.
- [ ] In `app/views/catalog/entries/_copies.html.erb` replace

```erb
              <td class="is-data is-opt"><%= lot_place(lot) %></td>
```

with

```erb
              <td class="is-data is-opt<%= " c-table__place" if lot.location_id %>"><span class="c-table__place-name"><%= lot_place(lot) %></span></td>
```

  (the class only for a placed lot: `.c-table td.c-table__place:not(.is-muted)` lets the cell wrap, and "No location" should stay on one line, as the collection keeps it by marking the unplaced cell muted)

- [ ] Run `bin/rspec spec/system/card_page_decks_spec.rb spec/system/card_page_spec.rb spec/requests/catalog` — expect: PASS (the 1280px examples now pass; "Your copies" text is unchanged, so the request examples that read it still pass).
- [ ] Commit: `fix: the card page's Your copies wraps a long zone label (spec 073)`.

---

## Phase 7: Documents

**Implements:** Story 6 | **Satisfies:** AC-6.1, AC-6.2, AC-6.3
**Files:** `docs/design-system/components/ItemPage.md`, `ItemPagePhone.md`, `SingleStat.md`, `docs/design-system/previews/ItemPage.html`, `ItemPagePhone.html`, `docs/design-system/README.md`, `docs/architecture/collection-and-lots.md`, `docs/architecture/catalog-core.md`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md`
**Interfaces:** none (prose). Documents are verified by reading, not by RSpec (`.claude/rules/testing.md`).

Edit with minimal, local changes (other branches edit `collection-and-lots.md`, `catalog-core.md`, `CLAUDE.md`, `docs/specs/README.md` and the design-system docs too: change only the lines named, never reflow). Each new statement ends with its source inline (spec 073 decision or AC).

### Task 7.1: Design system

- [ ] `ItemPage.md`: in the **Stats** bullet append "The three numbers are always shown, 0 included; In decks counts the decks that hold at least one owned copy, so a deck with only a proxy is not counted (spec 073 decision 3)." In the **In decks** bullet replace the sentence "Owned counts the copies in that zone and Proxy the proxies in it; the Proxy column is always shown, with a muted dash for none." and the sentence "On a phone Zone folds under the deck name with the format (`c-table__sub`), as in the other tables." with "Owned counts the copies of the card in that zone and Proxy the proxies of the card in it, each across every printing, finish and condition; the Proxy column is always shown, with a muted dash for none; a zone with only a proxy has Owned 0 (spec 073 decisions 4 and 6). The count beside the heading reads \"4 copies in 2 decks · 2 proxy\" (\"proxy\" has no plural, as the deck pages say it; proxies only \"2 proxy\"; none, no count), and a card in no deck shows \"This card isn't in any of your decks.\" with an \"Add to deck\" link when the printing can be added (spec 073 decision 5). When the section is narrower than 640px (a phone, or a laptop window with a narrow page column: the table's own container query) Zone folds under the deck name with the format (`c-table__sub`, \"Modern · Main\"), as in the other tables. A deck's name wraps at every width, by one rule in `additions.css` scoped to `#in-decks` (spec 073 decision 10)." and change "No new CSS (spec 057 decision 8)." to "That one rule is the only CSS the section adds; \"Your copies\" takes the existing `c-table__place` class on its Location cell so a long zone label wraps there too (spec 073 decision 10)."
- [ ] `ItemPagePhone.md`: after the line about In decks add "The section folds whenever it is narrower than 640px: the cell reads the deck's name, then the format and the zone (\"Modern · Main\"), Owned and Proxy stay, and the name wraps inside its cell (spec 073 AC-5.2)."
- [ ] `previews/ItemPage.html` and `ItemPagePhone.html`: change `<span class="c-section__count">4 copies in 2 decks</span>` to `<span class="c-section__count">4 copies in 2 decks · 1 proxy</span>` (the rows hold 3+1 copies and 1 proxy).
- [ ] `SingleStat.md` line 3 and line 15: say "the card page used it while it had one stat; since spec 073 it uses `c-stats--three`; keep the pattern for a page with one stat".
- [ ] `docs/design-system/README.md` line 99 ("What is live"): add that the card page's stats and "In decks" section are live (spec 073).
- [ ] Verify by reading both previews still open (`python3 -m http.server` is not needed: only the count text changed).
- [ ] Commit: `docs(design-system): the card page's In decks section and its head count (spec 073)`.

### Task 7.2: Area docs, CLAUDE.md, roadmap, index

- [ ] `docs/architecture/collection-and-lots.md`: (a) the card-page section (the paragraph starting "The card page shows \"Owned <copies>\"") gains a paragraph: the strip is Owned / In decks / Free to use for the card as a whole; Free to use is `Lot::FreeCopies#total` (`Lot.free`), In decks is the card's other lots (`Catalog::CardOverview#deck_lots`) so the two sum to Owned and no page code tests a location's kind; a proxy is in none of them; "in N decks" counts decks holding an owned copy; the "In decks" section's rows, columns, order, sums, head count, empty state and fold; the reads are `Deck::CardUses` plus `CardOverview`, a constant number of statements; a visitor reads none (spec 073 decisions 1 to 7, AC-3.3). (b) line 19's `Lot::FreeCopies` scope bullet: add "and the card page's Free to use and In decks (spec 073)". (c) line 163: replace "and the card page's \"Free to use\" of [#50](https://github.com/plainprogrammer/Collector/issues/50) must count them as in the deck (it has `Lot.free` to reuse)" … "(the card page's \"Free to use\" is not built; the panel is, spec 069 decision 2; …)" with the built statement: "the card page's Free to use counts them as in the deck (spec 073: it reads `Lot.free` through `Lot::FreeCopies`)", keeping the shape panel sentence and its source. (d) line 312's #50 clause: replace "no \"Free to use\" or \"In decks\" on the card page." by "#50 built the card page's Free to use and In decks (spec 073)." (keeping the link already on the line) and keep the rest of the line. (e) the Sources section: add the entry "[Spec 073](../specs/073-card-page-deck-stats/spec.md) (issue [#50](https://github.com/plainprogrammer/Collector/issues/50)): decisions 1 to 10, Stories 1 to 6 and FR-1 to FR-3 (the card page's stats and In decks section, the card as the scope, the reads, `Lot.free` as the one definition of free)." and, in the issues line (353), add "(spec 073: built)" after its #50 entry (AC-6.2 names that line); the Distillation log is the distillation step's. (f) the card-page paragraph also says "Your copies"' Location cell wraps a long zone label with the `c-table__place` class (spec 073 decision 10).
- [ ] `docs/architecture/catalog-core.md`: line 88's order sentence: "for a collector the \"Owned\" stat and \"Your copies\"" → "for a collector the stats (Owned, In decks, Free to use) and \"Your copies\"", and "\"Printings\" before the legality section" → "\"Printings\", \"In decks\" (a collection part, [collection and lots](collection-and-lots.md)) before the legality section"; line 202: replace the whole bullet with "The card page leaves out an estimated value and wishlist actions until those features exist; the collector's \"Free to use\", \"In decks\" and their section are built (spec 073, #50) and are [collection and lots](collection-and-lots.md)'s."; line 21 and 45 and 59: "the \"Owned\" stat" → "the stats" where they list collection parts a visitor never sees. Line 221 (Issues): delete `[#50](https://github.com/plainprogrammer/Collector/issues/50), ` from its "open:" list (spec 073 built it). Line 59 ("No collection part reaches a visitor"): after "and issue no query against `lots`" add "`locations`, `decks` or `deck_proxies`" so it reads "no query against `lots`, `locations`, `decks` or `deck_proxies`" (spec 073 AC-3.1).
- [ ] `CLAUDE.md`: in the long deck sentence of Project Status, after "A collector adds a card to a deck from its card page, their free copies or a proxy (`Deck::Addition`, `Lot::FreeCopies`, spec 071)." add "The card page shows how many copies are free to use and which decks hold the rest, in its stats and an \"In decks\" table (`Catalog::CardOverview`, `Deck::CardUses`, spec 073)."
- [ ] `docs/roadmap.md`: mark item 15 (#50) the way item 14l is marked: append "**Built 2026-11-11, done when its pull request merges:** [spec 073](specs/073-card-page-deck-stats/spec.md): the card page's stats (Owned, In decks, Free to use) and an \"In decks\" table (the pull request is recorded here when it merges)."
- [ ] `docs/specs/README.md`: the 073 row's Status and Areas stay "Approved" until the PR merges; add pointers "073 (AC-1.4 and the Non-Goal/Out of Scope entries: fulfilled)" to the Superseded-by cell of the 071 row and "073 (FR-9's single stat, its Non-Goal and Out of Scope entries, AC-8.1's order in part)" to the 004 row.
- [ ] Verify by reading each edited paragraph against the spec; check no line outside those named changed (`git diff --stat`).
- [ ] Commit: `docs: area docs, CLAUDE.md, roadmap and index for the card page's decks (spec 073)`.

---

## Phase 8: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run `bin/rspec spec/models/deck spec/models/catalog spec/helpers spec/requests/catalog spec/requests/query_counts_spec.rb spec/requests/deck_additions_spec.rb spec/requests/deck_pages_spec.rb spec/deck_core_spec.rb spec/design_system_files_spec.rb spec/system/card_page_spec.rb spec/system/card_page_decks_spec.rb spec/system/card_page_decks_no_script_spec.rb spec/system/deck_additions_spec.rb spec/system/narrow_pages_spec.rb` — expect: PASS. Record the counts.
- [ ] Ask the coordinator for the CI slot, then run `bin/ci` once (full) — expect: green; send "slot released" with the SHA and the result.
- [ ] Write `docs/specs/073-card-page-deck-stats/verification.md`: each AC with the example that proves it (the table the other specs' files use); the grep that built the supersession list (`git grep -n -E "Free to use|In decks|c-stats--single|\.c-stat\b|<dt>Owned|#50|Owned stat|one stat" -- spec docs app ':!.kamal/secrets'`); the Task 5.2 mutation result; that `query_counts_spec.rb` lines 58 and 97 stayed green with the same shape in both runs; the measured section widths of Task 6.1; the AC-5.4 control list; the screenshots.
- [ ] Screenshots and GIF (maintainer's evidence rules; `.claude/memory/pr-screenshots-workflow.md`): an uncommitted `spec/system/zz_073_screenshots_spec.rb` with factory data, `SHOTS_DIR=<scratchpad> bin/rspec <file>`, four states (no decks, some in decks, all in decks, proxies only), desktop (1280) and phone (390 through `open_in_narrow_frame`), light and dark, `data-theme` set for both with a 0.6s pause, a "before" of the wrap rule (the rule removed by injecting a `<style>` that resets `#in-decks td:first-child`) for a 60-character deck name, and a GIF from the card page to the deck page (frames `f-*.png`, `ffmpeg -framerate 4 -pattern_type glob -i 'f-*.png' -vf "scale=960:-1,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse" -loop 0 card-to-deck.gif`, under 1 MB). Look at every shot; fix a defect test-first. Compress with `magick in.png -resize 1000x -quality 70 out.jpg`, store under `docs/specs/073-card-page-deck-stats/screenshots/`, list in `verification.md`, delete the throwaway spec before committing, commit the shots alone.
- [ ] Implementation review (`sdd-review` Mode B, read-only Opus subagent) recorded in `verification.md` under `## Implementation review`, verdict on its first line.
- [ ] Commit: `docs(spec): verification and screenshots for spec 073`.

---

## Quickstart Validation

1. `bin/setup --skip-server`, then `bin/dev`; sign in as a collector with a few lots.
2. Create a deck at `/decks/new` (Modern), then on a card's page choose Add to deck, "My copies", Main, 2.
3. Reload the card page: the strip reads Owned N, In decks 2, Free to use N − 2 ("in 1 deck"); "In decks" lists the deck, Main, 2, a dash; click the deck's name and see the card in Main.
4. Add a proxy of the card to the deck's Sideboard from the deck page: the card page's table gains Sideboard with Owned 0 and Proxy 1, and the three numbers don't change.
5. Narrow the window below about 1036px: Zone folds under the deck name beside the format.
