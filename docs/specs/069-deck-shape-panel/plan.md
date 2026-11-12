# Plan: 069 The Deck Shape Panel

**Spec:** [spec.md](spec.md) v0.2.1 (Approved at Gate A) · **Issue:** [#256](https://github.com/plainprogrammer/Collector/issues/256) · **Branch:** `069-deck-shape-panel`
**Status:** Draft v1.1 (plan review round 1 applied; Gate B pending)

## Goal

The deck page of a Magic deck shows the shape panel (spec 060's `DeckShape`, already drawn in `additions.css`): a closed `details` fold below 640px of the page container and an `aside` from 640px, built from the Commander and Main zones' rows, with the figures the spec's decisions fix. The panel is a second optional answer of the collecting vocabulary (`Catalog::DeckShape`, the core seam; `MTG::Collecting.deck_shape`, the answer; `MTG::DeckShape`, the figures). Core files name no collectible. Nothing is stored. No CSS, token, migration, export or import change.

## What exists (read before editing)

- `Deck::Page#zones` (memoised, one build per request): `Deck::Page::Zone` (`location`, whose `zone` is the key, `name`, `groups`), `Group#rows`, `Row` (`entry` with `extension` (an `MTG::Printing`) preloaded, `owned`, `proxy`, `total`, `answer`). `Row#answer` is `Catalog::DeckCards::Answer`; its `position` is nil for a card of another collectible (`NONE`) and an index of `MTG::DeckGroups::NAMES` for a Magic card (Other when there is no data).
- `MTG::DeckGroups` (`NAMES`, `TYPES`, `position`, `group_name`); `MTG::Collecting.deck_card` is the model for the new answer.
- `DecksController#show` sets `@page = Deck::Page.new(@deck)`; `decks/show.html.erb` has `div.c-deck > div.c-deck__zones`.
- CSS for every class the panel uses is in `additions.css` ("DeckShape panel and curve", "card types", "mana bar", "DeckPage" blocks) and proved by `spec/system/design_system_deck_components_spec.rb`. **No CSS is written in this plan.**
- Spec helpers: `create_lot_in_zone(deck, zone_key, entry:, quantity:)` (`spec/support/deck_helpers.rb`); `create(:deck, account:, format: "commander")` (default format `modern`; its zones are Main, Sideboard, Considering); `create(:deck_proxy, zone: deck.zone("main"), account:, entry:, quantity:)`; `create(:mtg_card, identity: entry.identity, mana_value: 1.0)`; `:other_collecting` registers type `other` (no `deck_shape`) and `create(:deck, pair: "other/standard")` makes its deck.

## Files

| File | Change |
|---|---|
| `app/models/catalog/deck_shape.rb` | New: the core seam (`Answer`, `.answer`) |
| `app/models/mtg/deck_groups.rb` | Add `land?(position)` |
| `app/models/mtg/deck_shape.rb` | New: the figures (curve, average, types, symbols, scope, labels) |
| `app/models/mtg/collecting.rb` | Add `deck_shape(zones)` |
| `app/views/mtg/deck_shapes/_parts.html.erb` | New: the three parts |
| `app/views/decks/_shape.html.erb` | New: core frame of one copy (`aside` or `details`) |
| `app/views/decks/show.html.erb` | Two `render` lines inside `c-deck`, before the zones (the aside partial is the only other edit) |
| `app/controllers/decks_controller.rb` | One line in `show`: `@shape = Catalog::DeckShape.answer(...)` (the only controller edit) |
| `spec/deck_core_spec.rb` | Add `app/models/catalog/deck_shape.rb` to the patterns and 2 to the count (48 → 50; sum with the other branches at merge) |
| specs | `spec/models/catalog/deck_shape_spec.rb`, `spec/models/mtg/deck_groups_spec.rb` (extend or create), `spec/models/mtg/deck_shape_spec.rb`, `spec/models/mtg/collecting_deck_shape_spec.rb`, `spec/requests/deck_shape_panel_spec.rb`, `spec/system/deck_shape_panel_spec.rb`; changed: `spec/requests/deck_pages_spec.rb`, `spec/system/deck_page_spec.rb`, `spec/requests/query_counts_spec.rb` |
| docs | `docs/architecture/collection-and-lots.md`, `docs/architecture/catalog-core.md`, `docs/design-system/components/DeckShape.md`, `DeckPage.md`, `CLAUDE.md` decks sentence, `docs/specs/README.md`, `verification.md`, `screenshots/` |

## Existing examples that change (from a grep; re-run it in T7 and T9)

`git grep -n -i "shape\|c-deck\|c-shapefold\|aside\|second column\|children.length" -- spec ':!.kamal/secrets'` found exactly: `spec/requests/deck_pages_spec.rb:76-83` ("has no shape panel…", the `be_nil` line) and `spec/system/deck_page_spec.rb:202-214` ("leaves the second column empty from 992px…", `children` is 1). Every other deck-page selector is scoped to `section.c-zone`, `.c-zone` or `tbody` (checked: `zone_section`, `section.c-zone h2`, `.c-zone thead th`), so the panel's `h2`, `h3` and `details` break none. `spec/design_system_deck_components_spec.rb` builds its own markup and is unchanged. Spec 066 AC-1.6 and AC-5.1 are superseded in the spec (`Interactions and Supersession`) and `docs/specs/README.md` (done at spec time).

## Phases and tasks

One commit per task, Conventional Commits, trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Test first in every task: write the examples, run them, see them fail for the right reason, then write the code. Every public method of `app/models` carries a YARD summary (the ratchet, `.claude/rules/code-documentation.md`); core files and their comments never name a game, format or zone but Considering (`spec/deck_core_spec.rb` reads comments).

### Phase 1: Contracts (the seam and the group rule)

#### T1: `Catalog::DeckShape`, the core seam

**Implements** FR-1, decision 1. **Satisfies** AC-1.4 (the nil answers), AC-1.7.
**Files:** create `app/models/catalog/deck_shape.rb`, `spec/models/catalog/deck_shape_spec.rb`; edit `spec/deck_core_spec.rb`.

Test (mirrors `spec/models/catalog/deck_cards_spec.rb`):

```ruby
require "rails_helper"

# Spec 069 decision 1: the deck page's optional panel of a collectible's vocabulary, and the core's nil default.
RSpec.describe Catalog::DeckShape, type: :model do
  let(:zones) { [] }

  def register(type, vocabulary)
    stub_const("ShapeVocabulary#{type.capitalize}", vocabulary)
    Catalog.collecting[type] = "ShapeVocabulary#{type.capitalize}"
  end

  after { %w[answering silent].each { Catalog.collecting.delete(it) } }

  describe ".answer" do
    it "gives the vocabulary's answer, handing it the deck's zones untouched", :aggregate_failures do
      given = nil
      answer = described_class::Answer.new(partial: "p", figures: :f, scope: "s", facts: "t")
      register("answering", Module.new { define_singleton_method(:deck_shape) { |zones| given = zones; answer } })

      expect(described_class.answer("answering", zones)).to eq(answer)
      expect(given).to equal(zones)
    end

    it "gives nil for a type no longer registered" do
      expect(described_class.answer("gone", zones)).to be_nil
    end

    it "gives nil when the vocabulary has no deck_shape" do
      register("silent", Module.new)

      expect(described_class.answer("silent", zones)).to be_nil
    end

    it "gives nil when the vocabulary answers nil" do
      register("answering", Module.new { def self.deck_shape(_zones) = nil })

      expect(described_class.answer("answering", zones)).to be_nil
    end
  end
end
```

Code:

```ruby
# What the deck page asks a collectible's vocabulary for beside its zone tables: the shape panel (spec 069, #256), a second
# optional answer of the collecting vocabulary like `Catalog::DeckCards`. The core draws the page and each copy's frame and
# never names a collectible, a format or a zone; the vocabulary decides which zones count and what the parts say.
#
# An extension contract: a vocabulary that wants a panel provides `deck_shape(zones)` returning an {Answer} or nil.
# * `zones` is `Deck::Page#zones` as the page built it: every zone of the deck (Considering included), each a
#   `Deck::Page::Zone` whose `location.zone` is the zone's key, with its `name` and `groups` of rows. The vocabulary chooses the zones
#   that count and reads only what the rows already hold (the printings' loaded extension records); it runs a fixed number of
#   statements however many rows there are, and none when no card counts.
# * `partial` is the view that draws the panel's parts, rendered with a local `figures`; `figures` is what it draws;
#   `scope` is the scope line (the counted zones' names and their card count) and `facts` the fold's facts line.
# A vocabulary without `deck_shape`, a type no longer registered and a nil answer give the page no panel.
# @see file:collection-and-lots.md
module Catalog::DeckShape
  # What the page shows: see the module's contract for each member.
  Answer = Data.define(:partial, :figures, :scope, :facts)

  # The panel of one deck.
  #
  # @param deck_type [String] the deck's collectible type
  # @param zones [Array<Deck::Page::Zone>] `Deck::Page#zones`
  # @return [Answer, nil] nil when the type, its vocabulary or the answer is missing; never raises for an unregistered type
  def self.answer(deck_type, zones)
    return unless Catalog.collecting.key?(deck_type)

    vocabulary = Catalog.collecting_for(deck_type)
    vocabulary.deck_shape(zones) if vocabulary.respond_to?(:deck_shape)
  end
end
```

`spec/deck_core_spec.rb`: add `app/models/catalog/deck_shape.rb` to `patterns` next to `deck_cards.rb`; the count example becomes `20 + 6 + 1 + 1 + 4 + 1 + 15 + 2` with the comment "spec 069 adds 2: the seam `app/models/catalog/deck_shape.rb` and the page's frame `app/views/decks/_shape.html.erb` (the views glob already covers it)". The guard totals 48 today. T1 adds the pattern, so its count is `+ 1` (49 files); T7 creates `_shape.html.erb` and raises it to `+ 2` (50), so every commit's suite is green.

Run: `bin/rspec spec/models/catalog/deck_shape_spec.rb spec/deck_core_spec.rb`. Commit `feat(decks): add Catalog::DeckShape, the panel's seam (#256)`.

#### T2: `MTG::DeckGroups.land?`

**Implements** decision 3/4 (what a Land is). **Satisfies** AC-2.6, AC-3.3 (the rule the figures use).
**Files:** edit `app/models/mtg/deck_groups.rb`; extend or create `spec/models/mtg/deck_groups_spec.rb` (look for it first: `ls spec/models/mtg/deck_groups_spec.rb`).

Test:

```ruby
describe ".land?" do
  it "is true only for the Lands group's position", :aggregate_failures do
    positions = ->(type_line) { described_class.position(type_line) }

    expect(described_class.land?(positions.("Basic Land — Forest"))).to be(true)
    expect(described_class.land?(positions.("Artifact Land"))).to be(true)
    expect(described_class.land?(positions.("Land Creature — Forest Dryad"))).to be(false) # Dryad Arbor is a Creature
    expect(described_class.land?(positions.("Instant"))).to be(false)
    expect(described_class.land?(positions.(nil))).to be(false) # Other
    expect(described_class.land?(nil)).to be(false)
  end
end
```

Code (a comment on why: one place knows which index is Land):

```ruby
  # Whether a position is the Lands group's, so a caller can leave lands out without naming an index (spec 069: the curve).
  #
  # @param position [Integer, nil] from {position}
  # @return [Boolean] false for nil
  def self.land?(position) = !position.nil? && position == TYPES.index("Land")
```

Run the file. Commit `feat(decks): add MTG::DeckGroups.land? (#256)`.

### Phase 2: The figures (`MTG::DeckShape`, pure of the view)

All Phase 2 examples go in `spec/models/mtg/deck_shape_spec.rb` with these helpers (written in T3, reused):

```ruby
require "rails_helper"

# Spec 069: the figures of the deck shape panel, from a deck page's zones.
RSpec.describe MTG::DeckShape, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  # A printing with a face, and its card's mana value (pass `mana_value: nil` for a card with none yet).
  def card(name: "Card #{SecureRandom.hex(3)}", type_line: "Instant", cost: "{R}", mana_value: 1.0, faces: nil)
    entry = create(:catalog_entry, name:)
    faces ||= [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ]
    create(:mtg_printing, entry:, faces:)
    create(:mtg_card, identity: entry.identity, mana_value:)
    entry
  end

  def own(entry, quantity = 1, zone: "main", in_deck: deck) = create_lot_in_zone(in_deck, zone, entry:, quantity:)
  def proxy(entry, quantity = 1, zone: "main", in_deck: deck) = create(:deck_proxy, zone: in_deck.zone(zone), account:, entry:, quantity:)
  def zones_of(in_deck = deck) = Deck::Page.new(Deck.includes(:location).find_by!(location_id: in_deck.location_id)).zones
  def shape(in_deck = deck) = described_class.build(zones_of(in_deck))
end
```

#### T3: Types, scope and counted zones

**Implements** decisions 2, 3, 10, 14 (types, scope), FR-2. **Satisfies** AC-2.8 (zones), AC-3.1 to AC-3.5, scope parts of AC-1.5.
**Files:** create `app/models/mtg/deck_shape.rb`, start `spec/models/mtg/deck_shape_spec.rb`.

Examples to write first:

```ruby
describe ".build" do
  it "is nil for a deck with neither a main nor a commander zone" do
    deck.zone("main").destroy!   # no lot or proxy in it, so the foreign keys allow it

    expect(shape).to be_nil
  end

  it "counts Main only for a constructed deck, by quantity, and says so in the scope line", :aggregate_failures do
    own(card(mana_value: 1.0), 3)
    proxy(card, 1)
    own(card(mana_value: 7.0, type_line: "Sorcery", cost: "{G}"), 5, zone: "sideboard") # a value, a type and a colour Main lacks
    own(card(mana_value: 7.0, type_line: "Sorcery", cost: "{G}"), 2, zone: "considering")

    figures = shape

    expect(figures.cards).to eq(4)
    expect(figures.scope).to eq("Main · 4 cards")
    expect(figures.types.map(&:name)).to eq([ "Instants" ])
  end

  it "counts Commander and Main together, in the deck's zone order, and not Considering", :aggregate_failures do
    krenko = create(:deck, account:, name: "Krenko", format: "commander")
    own(card, 1, zone: "commander", in_deck: krenko)
    own(card, 99, zone: "main", in_deck: krenko)
    own(card(type_line: "Sorcery", cost: "{G}", mana_value: 7.0), 3, zone: "considering", in_deck: krenko) # a type, a colour and a value the counted zones lack

    figures = shape(krenko)

    expect(figures.scope).to eq("Commander + Main · 100 cards")
    expect(figures.types.map(&:name)).to eq([ "Instants" ])
  end

  it "says '1 card' and '0 cards' and delimits thousands", :aggregate_failures do
    expect(shape.scope).to eq("Main · 0 cards")
    own(card)
    expect(shape.scope).to eq("Main · 1 card")
    own(card, 1_233)
    expect(shape.scope).to eq("Main · 1,234 cards")
  end
end

describe "#types" do
  it "lists the groups present in the zone tables' order with the owned plus proxy count and the proxy count (AC-3.1)", :aggregate_failures do
    8.times { |n| n < 2 ? proxy(card(type_line: "Creature — Elf", mana_value: 2.0)) : own(card(type_line: "Creature — Elf", mana_value: 2.0)) }
    own(card(type_line: "Artifact Creature — Golem", mana_value: 3.0))
    own(card(type_line: "Sorcery", mana_value: 3.0))
    own(card(type_line: "Basic Land — Island", cost: "", mana_value: 0.0), 3)
    own(card(faces: [], mana_value: nil))

    types = shape.types

    expect(types.map { [ it.name, it.count, it.proxy ] }).to eq([ [ "Creatures", 9, 2 ], [ "Sorceries", 1, 0 ], [ "Lands", 3, 0 ], [ "Other", 1, 0 ] ])
    expect(types.sum(&:count)).to eq(shape.cards)
  end

  it "groups as the zone tables do: Dryad Arbor, an Artifact Land, a Kindred Instant, a Planeswalker (AC-3.3)" do
    { "Land Creature — Forest Dryad" => "Creatures", "Artifact Land" => "Lands", "Kindred Instant — Elf" => "Instants",
      "Legendary Planeswalker — Jace" => "Planeswalkers" }.each_key { own(card(type_line: it)) }

    expect(shape.types.map(&:name)).to eq(%w[Creatures Planeswalkers Instants Lands])
  end

  it "counts a proxy of a land under Lands (AC-3.4)" do
    proxy(card(type_line: "Basic Land — Forest", cost: "", mana_value: 0.0))

    expect(shape.types.map { [ it.name, it.count, it.proxy ] }).to eq([ [ "Lands", 1, 1 ] ])
  end

  it "agrees with the zone table's group counts for a Main-only deck (AC-3.2)" do
    own(card(type_line: "Creature — Elf"), 2)
    own(card(type_line: "Land"), 3)
    proxy(card(type_line: "Creature — Elf"), 1)

    page_groups = zones_of.find { it.name == "Main" }.groups.to_h { [ it.name, it.total ] }

    expect(shape.types.to_h { [ it.name, it.count ] }).to eq(page_groups)
  end

  it "skips a row of another collectible, in every part and in the scope (AC-3.5)", :aggregate_failures do
    own(card(type_line: "Creature — Elf"), 2)
    stranger = create(:catalog_entry, collectible_type: "stranger") # the page's answer for it is NONE: no position
    create_lot_in_zone(deck, "main", entry: stranger, quantity: 4)

    expect(shape.cards).to eq(2)
    expect(shape.types.sum(&:count)).to eq(2)
  end
end
```

(If `create(:catalog_entry, collectible_type: "stranger")` fails because `Deck::Page#entries_for` needs a registered source, build the row's `answer` through `Catalog::DeckCards::NONE` in a `Deck::Page::Row` by hand and call `described_class.new([zone])`: see T3's note below.)

Note for the implementer: a lot of an unregistered collectible type may not be creatable by factory; if so, test AC-3.5 with hand-built `Deck::Page::Zone`/`Group`/`Row` data objects (they are `Data`, constructible: `Deck::Page::Row.new(entry:, owned: 4, lines: [], answer: Catalog::DeckCards::NONE)`), and say so in `verification.md`. The request example (T7) proves the page-level case if a lot can be placed.

**Class layout (one `private`, written once here).** The class is laid out as: constants (`COUNTED_ZONES`, `Type` now; `TOP_COLUMN`, `Column` in T4; `COLOURS`, `Segment` in T5), `attr_reader`, `self.build`, `initialize`, every public method, then a single `private` holding the helpers (`counted`, built on `delimited`, both defined once; `nonland`, `valued`, `mana_values` from T4; `symbol_counts` from T5). T4 and T5 insert their public methods and constants **above** that `private` and their helpers below it; appending a public method after it makes it private and its callers raise `NoMethodError`.

Code (this task writes the class's frame, the rows, types and scope; the curve and symbols arrive in T4 and T5):

```ruby
# The figures of the deck shape panel for Magic (spec 069, #256): what a deck's Commander and Main zones hold, counted by
# type, by mana value and by coloured mana symbol, owned copies and proxies together and the curve and types keeping them
# apart. A plain object built once per request from `Deck::Page#zones`; it reads the rows' loaded printings and runs one
# statement of its own (the cards' mana values, none when no card counts). It is the code of the spec's
# decisions 2 to 10 (the rules themselves are in the area doc).
#
# Known limit (spec 069 Non-Goals, decision 7): a card is read through its first face, as the zone tables read it, so the second half of a
# split card adds no symbol to the bar, though its mana value (Scryfall's, both halves added) is in the curve. That is deliberate.
# @see file:collection-and-lots.md
class MTG::DeckShape
  # The zone keys that count (decision 2); the order shown is the deck's zone order.
  COUNTED_ZONES = %w[commander main].freeze
  # One kind of card: its group's name, how many cards (owned plus proxy) and how many of them are proxies.
  Type = Data.define(:name, :count, :proxy)

  attr_reader :rows

  # The figures of a deck page's counted zones (decision 2), or nil when the deck has neither a Commander nor a Main zone.
  #
  # @param zones [Array<Deck::Page::Zone>] `Deck::Page#zones`
  # @return [MTG::DeckShape, nil] nil when the deck has no counted zone
  def self.build(zones)
    counted = zones.select { COUNTED_ZONES.include?(it.location.zone) }
    new(counted) if counted.any?
  end

  # @param zones [Array<Deck::Page::Zone>] only the counted zones
  def initialize(zones)
    @names = zones.map(&:name)
    # A row with no position is another collectible's card: the page shows it flat and the panel skips it (decision 3).
    @rows = zones.flat_map { |zone| zone.groups.flat_map(&:rows) }.reject { it.answer.position.nil? }
  end

  # The cards in the counted zones, owned plus proxy.
  # @return [Integer]
  def cards = @cards ||= rows.sum(&:total)

  # The zones' names, "Main" or "Commander + Main".
  # @return [String]
  def scope_names = @names.join(" + ")

  # "Main · 60 cards".
  # @return [String]
  def scope = "#{scope_names} · #{counted(cards, 'card')}"

  # The kinds of card present, in the order of `MTG::DeckGroups::NAMES`; the counts add up to {#cards}.
  # @return [Array<Type>]
  def types
    @types ||= rows.group_by { it.answer.position }.sort.map do |position, in_group|
      Type.new(name: MTG::DeckGroups.group_name(position), count: in_group.sum(&:total), proxy: in_group.sum(&:proxy))
    end
  end

  private
    def delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)

    def counted(number, word) = "#{delimited(number)} #{number == 1 ? word : word.pluralize}"
end
```

Run `bin/rspec spec/models/mtg/deck_shape_spec.rb`. Commit `feat(decks): add the shape panel's types and scope (#256)`.

#### T4: The curve, the average and the cards with no mana value

**Implements** decisions 4, 5, 6, 7 (mana value), 11 (one statement). **Satisfies** AC-2.1 to AC-2.7, AC-1.5 (curve parts), AC-6.1/AC-6.3 (statement).
**Files:** `app/models/mtg/deck_shape.rb`, `spec/models/mtg/deck_shape_spec.rb`.

**Edit T3's two zone examples first**: add `expect(figures.curve.last.total).to eq(0)` to each (the 7s in Sideboard and Considering are outside the counted zones; the curve's 6+ column would hold them if they were counted).

Examples first:

```ruby
describe "#curve" do
  it "buckets Bolt, Elves, Counterspell and a Forest as AC-2.1 says", :aggregate_failures do
    bolt = card(name: "Lightning Bolt", mana_value: 1.0)
    own(bolt, 3)
    proxy(bolt, 1)
    own(card(name: "Llanowar Elves", type_line: "Creature — Elf", mana_value: 1.0), 2)
    proxy(card(name: "Counterspell", mana_value: 2.0), 2)
    own(card(name: "Forest", type_line: "Basic Land — Forest", cost: "", mana_value: 0.0), 4)

    figures = shape

    expect(figures.curve.map { [ it.owned, it.proxy ] }).to eq([ [ 0, 0 ], [ 5, 1 ], [ 0, 2 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ] ])
    expect([ figures.curve_owned, figures.curve_proxy, figures.curve_max ]).to eq([ 5, 3, 6 ])
    expect(figures.average_text).to eq("1.3") # (6 × 1 + 2 × 2) ÷ 8 = 1.25, half up
  end

  it "puts 0, 5, 6, 7, 9 and 1,000,000 in columns 0, 5, 6+, 6+, 6+, 6+ (AC-2.2)" do
    [ 0.0, 5.0, 6.0, 7.0, 9.0, 1_000_000.0 ].each { own(card(mana_value: it)) }

    expect(shape.curve.map(&:total)).to eq([ 1, 0, 0, 0, 0, 1, 4 ])
  end

  it "floors a half value into the whole number below it: 0.5, 2.5, 6.5 (AC-2.3)" do
    [ 0.5, 2.5, 6.5 ].each { own(card(mana_value: it)) }

    expect(shape.curve.map(&:total)).to eq([ 1, 0, 1, 0, 0, 0, 1 ])
  end

  it "leaves lands out and keeps Dryad Arbor in column 0 (AC-2.6)", :aggregate_failures do
    own(card(type_line: "Land Creature — Forest Dryad", cost: "", mana_value: 0.0)) # Dryad Arbor: a Creature, mana value 0
    own(card(type_line: "Artifact Land", cost: "", mana_value: 0.0))
    own(card(type_line: "Basic Land — Island", cost: "", mana_value: 0.0))

    expect(shape.curve.map(&:total)).to eq([ 1, 0, 0, 0, 0, 0, 0 ])
    expect(shape.curve_owned).to eq(1)
  end

  it "uses the card's stored value for a double-faced and a reversible card, and keeps a Sorcery // Land in the curve (AC-2.7)", :aggregate_failures do
    own(card(mana_value: 2.0, faces: [ { "name" => "A", "type_line" => "Creature — Human", "mana_cost" => "{1}{U}" },
                                       { "name" => "B", "type_line" => "Land", "mana_cost" => "" } ])) # transform: front Creature, back Land
    own(card(mana_value: 4.0, faces: [ { "name" => "Ajani", "type_line" => "Legendary Planeswalker — Ajani", "mana_cost" => "{2}{W}{W}" },
                                       { "name" => "Ajani", "type_line" => "Legendary Planeswalker — Ajani", "mana_cost" => "{2}{W}{W}" } ])) # reversible: stored value 4
    own(card(mana_value: 3.0, faces: [ { "name" => "C", "type_line" => "Sorcery", "mana_cost" => "{2}{B}" }, { "name" => "D", "type_line" => "Land", "mana_cost" => "" } ]))

    expect(shape.curve.map(&:total)).to eq([ 0, 0, 1, 1, 1, 0, 0 ])
    expect(shape.types.map { [ it.name, it.count ] }).to eq([ [ "Creatures", 1 ], [ "Planeswalkers", 1 ], [ "Sorceries", 1 ] ]) # by the front face's type
  end

  it "leaves a nonland card with no mana value out and counts it for the note (AC-2.5)", :aggregate_failures do
    own(card(mana_value: 3.0))
    own(card(mana_value: nil))

    expect(shape.curve.map(&:total)).to eq([ 0, 0, 0, 1, 0, 0, 0 ])
    expect(shape.unvalued).to eq(1)
    expect(shape.types.sum(&:count)).to eq(2)
    expect(shape.unvalued_note).to eq("1 nonland card has no mana value yet.")
  end

  it "words the note for several cards, and has none for a mana value of 0.0 (AC-2.5)", :aggregate_failures do
    3.times { own(card(mana_value: nil)) }
    expect(shape.unvalued_note).to eq("3 nonland cards have no mana value yet.")

    other = create(:deck, account:, name: "Zero")
    own(card(type_line: "Artifact", cost: "{0}", mana_value: 0.0), 1, in_deck: other)
    expect(shape(other).unvalued_note).to be_nil
    expect(shape(other).curve.first.total).to eq(1)
  end

  it "counts an entry with no MTG::Card row as having no mana value" do
    entry = create(:catalog_entry)
    create(:mtg_printing, entry:)
    own(entry)

    expect(shape.unvalued).to eq(1)
  end
end

describe "#average_text" do
  it "is the exact mean, 2.625 shown 2.6 (AC-2.4)" do
    [ 0.5, 2.5, 6.5, 1.0 ].each { own(card(mana_value: it)) }

    expect(shape.average_text).to eq("2.6")
  end

  it "keeps a trailing zero: a mean of 3 is 3.0 (AC-2.4)" do
    own(card(mana_value: 3.0), 4)

    expect(shape.average_text).to eq("3.0")
  end

  it "rounds 0.15 up with exact arithmetic, not down as a float would (AC-2.4)" do
    own(card(mana_value: 0.5), 3)
    own(card(mana_value: 0.0), 7)

    expect(shape.average_text).to eq("0.2")
  end

  it "is nil with no card in the curve, and delimits a long number (AC-1.5)", :aggregate_failures do
    expect(shape.average_text).to be_nil
    own(card(mana_value: 1_000_000.0))
    expect(shape.average_text).to eq("1,000,000.0")
  end
end

describe "statements" do
  it "runs one statement for the mana values however many cards, and none for an empty deck (AC-6.1)", :aggregate_failures do
    page_zones = zones_of
    expect(count_queries { described_class.build(page_zones).curve }).to eq(0)

    10.times { own(card) }
    page_zones = zones_of
    expect(count_queries { described_class.build(page_zones).curve }).to eq(1)

    30.times { own(card) }
    page_zones = zones_of
    expect(count_queries { described_class.build(page_zones).curve }).to eq(1)
  end

  it "reads the mana values once for the curve, the average and the note (AC-6.3)" do
    own(card)
    figures = described_class.build(zones_of)

    expect(count_queries { figures.curve; figures.average_text; figures.unvalued; figures.curve_max }).to eq(1)
  end
end
```

Code to add to `MTG::DeckShape` (comments for each public method; the first-use read of the mana values is memoised):

```ruby
  # One column of the curve: nonland cards of one mana value bucket, owned and proxy apart.
  Column = Data.define(:owned, :proxy) do
    # Owned plus proxy: the count above the column.
    def total = owned + proxy
  end
  # The curve's last column holds this mana value and above (decision 4).
  TOP_COLUMN = 6

  # The seven columns, mana value 0 to 6+, counting nonland cards with a mana value (decision 4): column n holds values from n
  # up to but not including n + 1, and the last holds every value from 6.
  # @return [Array<Column>]
  def curve
    @curve ||= begin
      owned = Array.new(TOP_COLUMN + 1, 0)
      proxy = Array.new(TOP_COLUMN + 1, 0)
      valued.each do |row, value|
        column = [ value.floor, TOP_COLUMN ].min
        owned[column] += row.owned
        proxy[column] += row.proxy
      end
      owned.zip(proxy).map { |o, p| Column.new(owned: o, proxy: p) }
    end
  end

  # The owned cards in the curve (the legend's "Owned N").
  # @return [Integer]
  def curve_owned = curve.sum(&:owned)

  # The proxy cards in the curve (the legend's "Proxy N").
  # @return [Integer]
  def curve_proxy = curve.sum(&:proxy)

  # The tallest column's owned plus proxy, the custom property `--max` of every bar; 0 when the curve is empty.
  # @return [Integer]
  def curve_max = curve.map(&:total).max

  # The cards in the curve.
  # @return [Integer]
  def curve_cards = curve_owned + curve_proxy

  # The exact mean mana value of the cards in the curve, shown to one decimal, rounded half up (decision 5). The arithmetic is
  # exact (Rational), so 0.15 shows 0.2 where a float would give 0.1.
  # @return [String, nil] nil when no card is in the curve
  def average_text
    return if curve_cards.zero?

    mean = valued.sum { |row, value| value.to_r * row.total } / curve_cards
    delimited(format("%.1f", mean.round(1).to_f))
  end

  # The nonland cards with no mana value (decision 6): a catalog not refreshed since spec 058, or a card Scryfall gave none.
  # @return [Integer]
  def unvalued = @unvalued ||= nonland.sum { |row| mana_values[row.entry.catalog_identity_id] ? 0 : row.total }

  # The sentence under the curve, or nil when every nonland card has a mana value.
  # @return [String, nil]
  def unvalued_note
    return if unvalued.zero?

    "#{counted(unvalued, 'nonland card')} #{unvalued == 1 ? 'has' : 'have'} no mana value yet."
  end

  # Helpers go below the class's single `private` (T3), not under a second one.
    def nonland = @nonland ||= rows.reject { MTG::DeckGroups.land?(it.answer.position) }

    # [[row, mana value]] for the nonland rows whose card has one.
    def valued = @valued ||= nonland.filter_map { |row| (value = mana_values[row.entry.catalog_identity_id]) && [ row, value ] }

    # One statement, none when no card counts: `{ identity id => mana value }` (spec 058's column, global catalog data).
    def mana_values
      @mana_values ||= begin
        ids = rows.map { it.entry.catalog_identity_id }.uniq
        ids.empty? ? {} : MTG::Card.where(catalog_identity_id: ids).where.not(mana_value: nil).pluck(:catalog_identity_id, :mana_value).to_h
      end
    end
```

(`counted` and `delimited` are T3's private helpers, not redefined. `format("%.1f", Rational#round(1).to_f)`: `Rational(1,5).to_f` is 0.2 so "0.2"; `Rational(13,10)` → "1.3".) Note `unvalued` and `valued` use the same `mana_values` memo, so the statement count is 1. Run, commit `feat(decks): add the shape panel's curve and average (#256)`.

#### T5: Coloured symbols, percentages and the texts

**Implements** decisions 7 (first face's cost), 8, 9, 10, 14. **Satisfies** AC-4.1 to AC-4.8, AC-4.10, AC-2.9 (label text), AC-4.9 (label text), AC-1.5, scope facts.
**Files:** `app/models/mtg/deck_shape.rb`, `spec/models/mtg/deck_shape_spec.rb`.

**Edit T3's two zone examples first** ("counts Main only…" and "counts Commander and Main together…"): add `expect(figures.symbols.map(&:colour)).to eq([ "R" ])` to each. The Sideboard and Considering cards hold a colour (G), a type (Sorcery) and a mana value (7) that the counted zones lack, so counting them would change the figure; that is what makes AC-2.8 and AC-4.10 able to fail.

Examples first (symbols):

```ruby
describe "#symbols" do
  def counts(figures = shape) = figures.symbols.to_h { [ it.colour, it.count ] }

  it "counts by colour, times the card's count, W U B R G order (AC-4.1)", :aggregate_failures do
    own(card(cost: "{U}{U}"), 2)
    own(card(cost: "{R}"), 1)
    proxy(card(cost: "{R}"), 1)
    proxy(card(cost: "{2}{W}{W}", type_line: "Sorcery"), 1)

    figures = shape

    expect(figures.symbols.map { [ it.colour, it.count, it.percent ] }).to eq([ [ "W", 2, 25 ], [ "U", 4, 50 ], [ "R", 2, 25 ] ])
    expect(figures.caption).to eq("White 2 · 25% · Blue 4 · 50% · Red 2 · 25%")
    expect(figures.symbols_label).to eq("Coloured mana symbols in Main: white 2, blue 4, red 2")
  end

  it "counts a hybrid symbol toward each colour (AC-4.2)" do
    own(card(cost: "{W/U}{W/U}"), 2)
    own(card(cost: "{R/G}"))

    expect(counts).to eq("W" => 4, "U" => 4, "R" => 1, "G" => 1)
  end

  it "counts a Phyrexian symbol toward its colour, a Phyrexian hybrid toward both, and {2/W} and {C/W} toward W only (AC-4.3)" do
    own(card(cost: "{2}{G/P}"))
    own(card(cost: "{G/W/P}"))
    own(card(cost: "{2/W}"))
    own(card(cost: "{C/W}"))

    expect(counts).to eq("W" => 3, "G" => 2)
  end

  it "never counts generic, X, colourless, snow or half symbols (AC-4.4)", :aggregate_failures do
    own(card(cost: "{3}{X}{C}{S}{G}"))
    own(card(name: "Little Girl", cost: "{HW}", mana_value: 0.5))

    expect(counts).to eq("G" => 1)
    expect(shape.symbols.sum(&:count)).to eq(1)
    expect(shape.curve.first.total).to eq(1) # the {HW} card is still in the curve, at its mana value
  end

  it "reads only the first face of a double-faced and a split card (AC-4.5)" do
    own(card(faces: [ { "name" => "A", "type_line" => "Creature", "mana_cost" => "{1}{U}" }, { "name" => "B", "type_line" => "Land", "mana_cost" => "{3}{R}" } ]))
    own(card(faces: [ { "name" => "Fire", "type_line" => "Instant", "mana_cost" => "{1}{R}" }, { "name" => "Ice", "type_line" => "Instant", "mana_cost" => "{1}{U}" } ]))

    expect(counts).to eq("U" => 1, "R" => 1)
  end

  it "marks a segment under 10% narrow and not one of exactly 10% (AC-4.6)", :aggregate_failures do
    own(card(cost: "{W}"), 5)
    own(card(cost: "{U}"), 95)
    expect(shape.symbols.map { [ it.colour, it.narrow ] }).to eq([ [ "W", true ], [ "U", false ] ])
    expect(shape.caption).to eq("White 5 · 5% · Blue 95 · 95%")

    other = create(:deck, account:, name: "Ten")
    own(card(cost: "{W}"), 10, in_deck: other)
    own(card(cost: "{U}"), 90, in_deck: other)
    expect(shape(other).symbols.first.narrow).to be(false)
  end

  it "rounds each percentage on its own, half up and exactly (AC-4.7)", :aggregate_failures do
    own(card(cost: "{W}{U}{B}"))
    expect(shape.symbols.map(&:percent)).to eq([ 33, 33, 33 ])

    other = create(:deck, account:, name: "Eighths")
    own(card(cost: "{W}"), 1, in_deck: other)
    own(card(cost: "{U}"), 7, in_deck: other)
    expect(shape(other).symbols.map(&:percent)).to eq([ 13, 88 ]) # 12.5 and 87.5, each half up
  end

  it "has no segment and no caption for a deck of generic costs (AC-4.8)", :aggregate_failures do
    own(card(type_line: "Artifact", cost: "{3}", mana_value: 3.0), 4)

    expect(shape.symbols).to eq([])
    expect(shape.caption).to be_nil
  end

  it "does not count Sideboard or Considering symbols (AC-4.10)" do
    own(card(cost: "{U}"))
    own(card(cost: "{G}{G}"), 3, zone: "sideboard")
    own(card(cost: "{G}"), 3, zone: "considering")

    expect(counts).to eq("U" => 1)
  end

  it "reads a nil, blank or malformed cost as nothing and raises nothing" do
    own(card(cost: nil))
    own(card(cost: ""))
    own(card(cost: "{W"))
    own(card(faces: [ { "name" => "Bare" } ]))

    expect(shape.symbols).to eq([])
  end
end
```

Examples first (texts):

```ruby
describe "texts" do
  it "reads the curve for a screen reader: each column with cards, the owned and proxy split, then the average (AC-2.9)" do
    own(card(mana_value: 1.0), 11)
    proxy(card(mana_value: 1.0), 1)
    own(card(mana_value: 6.0), 2)

    expect(shape.curve_label).to eq("Mana curve of the 14 nonland cards in Main: mana value 1, 12 cards (11 owned, 1 proxy); 6+, 2 cards (2 owned). Average mana value 1.7.")
    # (12 × 1 + 2 × 6) ÷ 14 = 1.714…
  end

  it "says '1 nonland card' and, for none, 'no cards' (AC-1.5)", :aggregate_failures do
    expect(shape.curve_label).to eq("Mana curve of the 0 nonland cards in Main: no cards.")
    own(card(mana_value: 2.0))
    expect(shape.curve_label).to eq("Mana curve of the 1 nonland card in Main: mana value 2, 1 card (1 owned). Average mana value 2.0.")
  end

  it "builds the fold's facts: the scope, then the average when there is one", :aggregate_failures do
    expect(shape.facts).to eq("Main · 0 cards")
    own(card(mana_value: 3.0), 2)
    expect(shape.facts).to eq("Main · 2 cards · average mana value 3.0")
  end

  it "reads the symbols label for the scope (AC-4.9)" do
    krenko = create(:deck, account:, name: "Krenko", format: "commander")
    own(card(cost: "{R}"), 1, zone: "commander", in_deck: krenko)

    expect(shape(krenko).symbols_label).to eq("Coloured mana symbols in Commander + Main: red 1")
  end
end
```

Code:

```ruby
  # One coloured segment of the mana bar: the colour's letter, its symbol count, its share rounded half up to a percent and whether the
  # segment is too narrow for its label (under 10% of the symbols, decision 9).
  Segment = Data.define(:colour, :count, :percent, :narrow)
  # The five colours in the order the bar draws them, with the words the caption and label use.
  COLOURS = { "W" => "white", "U" => "blue", "B" => "black", "R" => "red", "G" => "green" }.freeze

  # The segments of the mana bar for the colours that have a symbol (decision 8), in W, U, B, R, G order.
  # @return [Array<Segment>]
  def symbols
    @symbols ||= begin
      total = symbol_counts.values.sum
      COLOURS.keys.filter_map do |colour|
        count = symbol_counts[colour]
        next unless count.positive?

        Segment.new(colour:, count:, percent: Rational(count * 100, total).round, narrow: count * 100 < total * 10)
      end
    end
  end

  # "White 2 · 25% · Blue 4 · 50%": every colour present with its count and percentage.
  # @return [String, nil] nil when there is no coloured symbol
  def caption
    symbols.map { |s| "#{COLOURS[s.colour].capitalize} #{delimited(s.count)} · #{s.percent}%" }.join(" · ").presence
  end

  # "Coloured mana symbols in Main: white 2, blue 4" for the bar's `aria-label`.
  # @return [String]
  def symbols_label = "Coloured mana symbols in #{scope_names}: #{symbols.map { |s| "#{COLOURS[s.colour]} #{delimited(s.count)}" }.join(', ')}"

  # The curve's `aria-label` (spec 060 AC-2.2): the scope, the cards in the curve, each column that has cards with its split, then the average.
  # @return [String]
  def curve_label
    head = "Mana curve of the #{counted(curve_cards, 'nonland card')} in #{scope_names}: "
    return "#{head}no cards." if curve_cards.zero?

    columns = curve.each_with_index.reject { |column, _| column.total.zero? }.map.with_index do |(column, index), position|
      split = [ ("#{delimited(column.owned)} owned" if column.owned.positive?), ("#{delimited(column.proxy)} proxy" if column.proxy.positive?) ].compact.join(", ")
      "#{'mana value ' if position.zero?}#{index == TOP_COLUMN ? '6+' : index}, #{counted(column.total, 'card')} (#{split})"
    end
    "#{head}#{columns.join('; ')}. Average mana value #{average_text}."
  end

  # The fold's facts line: the scope, and the average when the curve has cards.
  # @return [String]
  def facts = [ scope, ("average mana value #{average_text}" if average_text) ].compact.join(" · ")

  # Below the single `private` too:
    # `{ "W" => 3, … }` for every colour: each symbol of every row's first face's cost, times the row's cards.
    def symbol_counts
      @symbol_counts ||= rows.each_with_object(COLOURS.keys.index_with { 0 }) do |row, counts|
        cost = row.entry.extension&.faces&.first&.dig("mana_cost")
        cost.to_s.scan(/\{([^{}]+)\}/).flatten.each { |symbol| (symbol.split("/") & COLOURS.keys).each { counts[it] += row.total } }
      end
    end
```

Check the AC-2.9 expected string in the example: 14 cards in the curve = 11+1+2; column 1 = 12; column 6+ = 2; average (12×1 + 2×6)/14 = 24/14 = 1.714 → "1.7". Run, commit `feat(decks): add the shape panel's coloured symbols and texts (#256)`.

### Phase 3: The vocabulary's answer and the page

#### T6: `MTG::Collecting.deck_shape`

**Implements** decision 1 (the extension side), FR-2. **Satisfies** AC-1.4 (Magic answers nil without a counted zone).
**Files:** `app/models/mtg/collecting.rb`; create `spec/models/mtg/collecting_deck_shape_spec.rb`.

Test:

```ruby
require "rails_helper"

# Spec 069 decision 1: Magic's answer to the deck page's panel seam.
RSpec.describe MTG::Collecting, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def zones_of(in_deck) = Deck::Page.new(Deck.includes(:location).find_by!(location_id: in_deck.location_id)).zones

  describe ".deck_shape" do
    it "answers the parts' partial with the figures, the scope line and the fold's facts", :aggregate_failures do
      entry = create(:catalog_entry)
      create(:mtg_printing, entry:)
      create(:mtg_card, identity: entry.identity, mana_value: 1.0)
      create_lot_in_zone(deck, "main", entry:, quantity: 2)

      answer = described_class.deck_shape(zones_of(deck))

      expect(answer.partial).to eq("mtg/deck_shapes/parts")
      expect(answer.figures).to be_a(MTG::DeckShape)
      expect([ answer.scope, answer.facts ]).to eq([ "Main · 2 cards", "Main · 2 cards · average mana value 1.0" ])
    end

    it "answers nil when no zone is Commander or Main" do
      deck.zone("main").destroy!

      expect(described_class.deck_shape(zones_of(deck))).to be_nil
    end

    it "is what the core seam returns for a Magic deck" do
      expect(Catalog::DeckShape.answer("mtg", zones_of(deck))).to be_a(Catalog::DeckShape::Answer)
    end
  end
end
```

Code (after `deck_card`):

```ruby
  # The deck page's shape panel for Magic (spec 069, the extension side of `Catalog::DeckShape`): the figures of the Commander
  # and Main zones and the partial that draws them. See {MTG::DeckShape} for the rules and the one statement it runs.
  #
  # @param zones [Array<Deck::Page::Zone>] `Deck::Page#zones`
  # @return [Catalog::DeckShape::Answer, nil] nil when the deck has no Commander or Main zone
  def self.deck_shape(zones)
    figures = MTG::DeckShape.build(zones) or return

    Catalog::DeckShape::Answer.new(partial: "mtg/deck_shapes/parts", figures:, scope: figures.scope, facts: figures.facts)
  end
```

Run both new files. Commit `feat(decks): answer the deck page's shape panel for Magic (#256)`.

#### T7: The views, the controller line and the request examples

**Implements** FR-3, decision 12. **Satisfies** AC-1.1 to AC-1.8, AC-2.9, AC-2.10 (markup), AC-4.9 (markup), AC-6.1 (request level), AC-1.7.
**Files:** create `app/views/mtg/deck_shapes/_parts.html.erb`, `app/views/decks/_shape.html.erb`, `spec/requests/deck_shape_panel_spec.rb`; edit `app/controllers/decks_controller.rb`, `app/views/decks/show.html.erb`, `spec/requests/deck_pages_spec.rb`, `spec/system/deck_page_spec.rb`, `spec/deck_core_spec.rb`.

Examples first, `spec/requests/deck_shape_panel_spec.rb`:

```ruby
require "rails_helper"

# Spec 069 Stories 1 to 4: the shape panel on the deck page, GET /decks/:id.
RSpec.describe "Deck shape panel", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def html = Nokogiri::HTML5(response.body)
  def card(name: "Card #{SecureRandom.hex(3)}", type_line: "Instant", cost: "{R}", mana_value: 1.0)
    entry = create(:catalog_entry, name:)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    create(:mtg_card, identity: entry.identity, mana_value:)
    entry
  end
  def own(entry, quantity = 1, zone: "main") = create_lot_in_zone(deck, zone, entry:, quantity:)
  def proxy(entry, quantity = 1, zone: "main") = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, quantity:)

  before { sign_in_as(user) }

  describe "the two copies (Story 1)" do
    # Bolt (owned 3), Counterspell (owned 1, proxy 2: one column holding both) and two Forests: 8 cards, 6 in the curve.
    before do
      own(card(name: "Lightning Bolt"), 3)
      counterspell = card(name: "Counterspell", cost: "{U}{U}", mana_value: 2.0)
      own(counterspell, 1)
      proxy(counterspell, 2)
      own(card(name: "Forest", type_line: "Basic Land — Forest", cost: "", mana_value: 0.0), 2)
      get deck_path(deck)
    end

    it "puts the details copy, the aside copy and the zones inside c-deck, in that order (AC-1.1)", :aggregate_failures do
      expect(html.css(".c-deck > *").map { it["class"] }).to eq([ "c-shapefold", "c-deck__shape", "c-deck__zones" ])
      aside = html.at_css("aside.c-deck__shape")
      expect(aside.at_css("section.c-shape h2.c-shape__title").text).to eq("Deck shape")
      expect(aside.at_css(".c-shape__scope").text).to eq("Main · 8 cards")
      summary = html.at_css("details.c-shapefold summary")
      expect(summary.at_css(".c-shapefold__title").text).to eq("Deck shape")
      expect(summary.at_css(".c-shapefold__facts").text).to eq("Main · 8 cards · average mana value 1.5")
      expect(html.at_css("details.c-shapefold")["open"]).to be_nil
    end

    it "has the three parts in order in each copy (AC-1.1)" do
      %w[aside.c-deck__shape details.c-shapefold].each do |copy|
        expect(html.css("#{copy} h3.c-shape__heading").map(&:text)).to eq([ "Mana curve", "Card types", "Mana symbols" ])
      end
    end

    it "gives no id twice, no root id, and labels the aside by its own title (AC-1.2)", :aggregate_failures do
      ids = html.css("[id]").map { it["id"] }
      expect(ids.tally.select { |_id, n| n > 1 }).to eq({})
      expect(html.at_css("section.c-shape")["id"]).to be_nil
      expect(html.at_css("section.c-shape")["aria-labelledby"]).to eq(html.at_css("h2.c-shape__title")["id"])
    end

    it "reads each chart for a screen reader once per copy and hides the columns (AC-2.9, AC-4.9)", :aggregate_failures do
      aside = html.at_css("aside.c-deck__shape")
      expect(aside.at_css(".c-curve [role=img]")["aria-label"]).to eq(
        "Mana curve of the 6 nonland cards in Main: mana value 1, 3 cards (3 owned); 2, 3 cards (1 owned, 2 proxy). Average mana value 1.5."
      )
      expect(aside.at_css(".c-curve__cols")["aria-hidden"]).to eq("true")
      expect(aside.at_css(".c-manabar")["aria-label"]).to eq("Coloured mana symbols in Main: blue 6, red 3")
    end

    it "draws a column with the proxy part above the owned part, numbers only in style, a part of zero having no element (AC-2.9, AC-2.10)", :aggregate_failures do
      cols = html.css("aside .c-curve__col")
      expect(cols.size).to eq(7)
      expect(cols[1].css(".c-curve__bar > *").map { [ it["class"], it["style"] ] }).to eq([ [ "c-curve__owned", "--owned:3;--max:3" ] ])
      expect(cols[2].css(".c-curve__bar > *").map { [ it["class"], it["style"] ] }).to eq(
        [ [ "c-curve__proxy", "--proxy:2;--max:3" ], [ "c-curve__owned", "--owned:1;--max:3" ] ] # the proxy part first: it sits on top
      )
      expect(html.css("aside [style]").map { it["style"] }).to all(match(/\A(--\w+:\d+;?)+\z/)) # no colour in a style attribute
      expect(html.css("aside .c-curve__legend li").map(&:text)).to eq([ "Owned 4", "Proxy 2" ])
      expect(html.at_css("aside .c-curve__avg").text.strip).to eq("Average mana value 1.5")
    end

    it "lists the types with the proxy suffix, empty where a row has none, and the symbol segments with their letters (AC-3.1, AC-4.1)", :aggregate_failures do
      expect(html.css("aside .c-types li").map { |li| li.css("span").map(&:text) }).to eq([ [ "Instants", "6", "2 proxy" ], [ "Lands", "2", "" ] ])
      expect(html.css("aside .c-manabar__seg").map { [ it["class"], it["style"], it.text ] }).to eq(
        [ [ "c-manabar__seg c-manabar__seg--u", "--n:6", "U 6" ], [ "c-manabar__seg c-manabar__seg--r", "--n:3", "R 3" ] ]
      )
      expect(html.at_css("aside .c-manacap").text).to eq("Blue 6 · 67% · Red 3 · 33%")
    end
  end

  it "marks a segment under 10% of the symbols narrow in the page (AC-4.6)", :aggregate_failures do
    own(card(cost: "{W}"), 1)
    own(card(cost: "{U}"), 19)
    get deck_path(deck)

    segments = html.css("aside .c-manabar__seg").to_h { [ it["class"][/seg--(\w+)/, 1], it["class"].include?("c-manabar__seg--narrow") ] }
    expect(segments).to eq({ "w" => true, "u" => false })
    expect(html.at_css("aside .c-manacap").text).to eq("White 1 · 5% · Blue 19 · 95%")
  end

  it "skips a card of another collectible in the panel and shows its row flat in the zone table (AC-3.5)", :other_collecting, :aggregate_failures do
    own(card, 2)
    stranger = create(:catalog_entry, collectible_type: "other", name: "Foreign card")
    create_lot_in_zone(deck, "main", entry: stranger, quantity: 4)
    get deck_path(deck)

    expect(html.at_css("aside .c-shape__scope").text).to eq("Main · 2 cards")
    expect(html.css("aside .c-types li").map { |li| li.css("span").first.text }).to eq([ "Instants" ])
    expect(html.css("section.c-zone").find { it.at_css("h2").text == "Main" }.text).to include("Foreign card")
  end

  it "shows the empty states of a Casual deck with no card (AC-1.5)", :aggregate_failures do
    get deck_path(create(:deck, account:, name: "Empty casual", format: "casual"))

    aside = html.at_css("aside.c-deck__shape")
    expect(aside.at_css(".c-shape__scope").text).to eq("Main · 0 cards")
    expect(aside.css(".c-curve__count").map(&:text)).to eq(%w[0] * 7)
    expect(aside.css(".c-curve__owned, .c-curve__proxy")).to be_empty
    expect(aside.css(".c-curve__legend li").map(&:text)).to eq([ "Owned 0", "Proxy 0" ])
    expect(aside.css(".c-curve__avg")).to be_empty
    expect(aside.at_css(".c-types, .c-types li")).to be_nil
    expect(aside.text).to include("No cards yet.", "No coloured mana symbols.")
    expect(aside.at_css(".c-manabar")).to be_nil
  end

  it "notes the nonland cards with no mana value after the average line (AC-2.5)", :aggregate_failures do
    own(card(mana_value: 2.0))
    own(card(mana_value: nil), 2)
    get deck_path(deck)

    notes = html.css("aside .c-curve__avg").map { it.text.squish }
    expect(notes).to eq([ "Average mana value 2.0", "2 nonland cards have no mana value yet." ])
  end

  it "keeps the panel for a format the instance no longer registers (AC-1.8)", :aggregate_failures do
    own(card, 2)
    deck.update!(format: "retired") # a stored key the registry lacks, as deck_pages_spec.rb does
    get deck_path(deck)

    expect(html.at_css("aside .c-shape__scope").text).to eq("Main · 2 cards")
  end

  it "draws no panel for a deck with neither a main nor a commander zone row (AC-1.4)", :aggregate_failures do
    deck.zone("main").destroy!
    get deck_path(deck)

    expect(response).to have_http_status(:ok)
    expect(html.css("aside.c-deck__shape, details.c-shapefold")).to be_empty
    expect(html.css(".c-deck > *").map { it["class"] }).to eq([ "c-deck__zones" ])
  end

  it "draws no panel for a collectible whose vocabulary answers none (AC-1.4)", :other_collecting, :aggregate_failures do
    other = create(:deck, account:, name: "Other deck", pair: "other/standard")
    get deck_path(other)

    expect(response).to have_http_status(:ok)
    expect(html.css("aside.c-deck__shape, details.c-shapefold")).to be_empty
  end

  it "draws no panel for a deck of a type no longer registered, and still answers 200 (AC-1.4)", :aggregate_failures do
    own(card)
    deck.update!(collectible_type: "gone") # the fixture deck_pages_spec.rb uses for a type the instance no longer has
    get deck_path(deck)

    expect(response).to have_http_status(:ok)
    expect(html.css("aside.c-deck__shape, details.c-shapefold")).to be_empty
  end

  it "is a 404 for another account's deck and shows none of its figures (AC-1.6)" do
    rival = create(:deck, account: create(:user).account, name: "Rival #{SecureRandom.hex(4)}")
    create_lot_in_zone(rival, "main", entry: card, quantity: 3)

    get deck_path(rival)

    expect(response).to have_http_status(:not_found)
  end
end
```

Two existing examples go red the moment the panel renders, so both are rewritten **in this commit**: (1) delete the `be_nil` line and rewrite the example in `spec/requests/deck_pages_spec.rb:76-83`: title becomes "has a dash in the Proxy cell of a row with no proxy (AC-1.6; spec 068 supersedes spec 066 AC-1.6's no proxy control, and spec 069 its no shape panel)" and drops the `aside.c-deck__shape, details.c-shapefold` `be_nil` expectation (the panel is now proved in the new file). (2) Rewrite `spec/system/deck_page_spec.rb:202-214` ("leaves the second column empty from 992px…", which asserts `.c-deck` has one child and goes red now that a Magic deck has three): the example uses a deck of another collectible, `let(:other_deck) { create(:deck, account:, name: "Other deck", pair: "other/standard") }` with the `:other_collecting` tag, visits `deck_path(other_deck)` and keeps every assertion (`children` 1, `columns` 2, the zones narrower than the grid); retitle it "leaves the second column empty from 992px for a deck whose collectible draws no panel (AC-5.1; spec 069 supersedes it for a Magic deck, spec 060 AC-3.12)".

Code. `app/controllers/decks_controller.rb`, in `show` (one line, the only controller edit):

```ruby
  def show
    @page = Deck::Page.new(@deck)
    @shape = Catalog::DeckShape.answer(@deck.collectible_type, @page.zones) # spec 069: the panel, nil when the collectible draws none
  end
```

`app/views/decks/show.html.erb` (the two lines inside `c-deck`, before the zones: DOM order is the details copy, the aside copy, the zones, as `DeckPage.md` says):

```erb
  <div class="c-deck">
    <% if @shape %>
      <%= render "decks/shape", answer: @shape, copy: :fold %>
      <%= render "decks/shape", answer: @shape, copy: :aside %>
    <% end %>
    <div class="c-deck__zones">
```

`app/views/decks/_shape.html.erb` (the core frame; the extension's partial draws the parts; no collectible named):

```erb
<%# One copy of the shape panel (spec 069, DeckShape.md "The two copies"): the extension's partial draws the parts, this frame is the page's. %>
<% parts = render(partial: answer.partial, locals: { figures: answer.figures }) %>
<% if copy == :aside %>
  <aside class="c-deck__shape">
    <section class="c-shape" aria-labelledby="shape-title-aside">
      <div><h2 class="c-shape__title" id="shape-title-aside">Deck shape</h2><p class="c-shape__scope"><%= answer.scope %></p></div>
      <%= parts %>
    </section>
  </aside>
<% else %>
  <details class="c-shapefold">
    <summary><span class="c-shapefold__title">Deck shape</span><span class="c-shapefold__facts"><%= answer.facts %></span></summary>
    <div class="c-shape c-shape--bare"><%= parts %></div>
  </details>
<% end %>
```

`app/views/mtg/deck_shapes/_parts.html.erb` (markup as `DeckShape.md`'s; every number is an integer or an escaped string from the figures):

```erb
<%# The three parts of the deck shape panel for Magic (spec 069, DeckShape.md): a part of zero has no element. %>
<div class="c-shape__part"><h3 class="c-shape__heading">Mana curve</h3>
  <div class="c-curve">
    <div role="img" aria-label="<%= figures.curve_label %>">
      <div class="c-curve__cols" aria-hidden="true">
        <% figures.curve.each do |column| %>
          <div class="c-curve__col"><span class="c-curve__count"><%= number_with_delimiter(column.total) %></span>
            <div class="c-curve__bar">
              <% if column.proxy.positive? %><div class="c-curve__proxy" style="--proxy:<%= column.proxy %>;--max:<%= figures.curve_max %>"></div><% end %>
              <% if column.owned.positive? %><div class="c-curve__owned" style="--owned:<%= column.owned %>;--max:<%= figures.curve_max %>"></div><% end %>
            </div></div>
        <% end %>
      </div>
      <div class="c-curve__labels" aria-hidden="true"><% %w[0 1 2 3 4 5 6+].each do |label| %><span><%= label %></span><% end %></div>
    </div>
    <ul class="c-curve__legend">
      <li><span class="c-curve__swatch c-curve__swatch--owned"></span>Owned <%= number_with_delimiter(figures.curve_owned) %></li>
      <li><span class="c-curve__swatch c-curve__swatch--proxy"></span>Proxy <%= number_with_delimiter(figures.curve_proxy) %></li>
    </ul>
    <% if figures.average_text %><p class="c-curve__avg">Average mana value <b><%= figures.average_text %></b></p><% end %>
    <% if figures.unvalued_note %><p class="c-curve__avg"><%= figures.unvalued_note %></p><% end %>
  </div>
</div>
<div class="c-shape__part"><h3 class="c-shape__heading">Card types</h3>
  <% if figures.types.any? %>
    <ul class="c-types">
      <% figures.types.each do |type| %>
        <li><span><%= type.name %></span><span class="c-types__n"><%= number_with_delimiter(type.count) %></span><span class="c-types__proxy"><%= "#{number_with_delimiter(type.proxy)} proxy" if type.proxy.positive? %></span></li>
      <% end %>
    </ul>
  <% else %>
    <p class="c-manacap">No cards yet.</p>
  <% end %>
</div>
<div class="c-shape__part"><h3 class="c-shape__heading">Mana symbols</h3>
  <% if figures.symbols.any? %>
    <ul class="c-manabar" role="img" aria-label="<%= figures.symbols_label %>">
      <% figures.symbols.each do |segment| %>
        <li class="<%= class_names("c-manabar__seg", "c-manabar__seg--#{segment.colour.downcase}", "c-manabar__seg--narrow": segment.narrow) %>" style="--n:<%= segment.count %>"><span><%= segment.colour %> <%= number_with_delimiter(segment.count) %></span></li>
      <% end %>
    </ul>
    <p class="c-manacap"><%= figures.caption %></p>
  <% else %>
    <p class="c-manacap">No coloured mana symbols.</p>
  <% end %>
</div>
```

(The test above asserts the markup's exact shapes: each `.c-types li` holds three spans, name, count and the proxy suffix, the last empty for a row with none; the class attribute order `c-manabar__seg c-manabar__seg--u` comes from `class_names`.)

`spec/deck_core_spec.rb`: the count example's comment and sum go to `+ 2` (the seam and `app/views/decks/_shape.html.erb`).

Run: `bin/rspec spec/requests/deck_shape_panel_spec.rb spec/requests/deck_pages_spec.rb spec/system/deck_page_spec.rb spec/deck_core_spec.rb spec/models/mtg spec/models/catalog/deck_shape_spec.rb` (one run at a time: the system file shares the database). Also run `bin/rails zeitwerk:check`. Re-run the supersession grep above and record the result. Commit `feat(decks): show the shape panel on the deck page (#256)`.

#### T8: The page's statements stay bounded; `Deck::Page` is untouched

**Satisfies** AC-6.1, AC-6.2, AC-6.3.
**Files:** `spec/requests/query_counts_spec.rb`.

Test (next to the existing deck example, "keeps the deck page's and the Decks page's queries the same with six proxies as with one"; copy its fixture helpers for decks and printings):

```ruby
it "keeps the deck page's queries the same with 60 cards of 40 printings as with one, panel included (spec 069 AC-6.1)", :aggregate_failures do
  deck = create(:deck, account: user.account, name: "Izzet Tempo")
  card = lambda do
    entry = printing
    create(:mtg_card, identity: entry.identity, mana_value: 2.0)
    entry
  end
  create_lot_in_zone(deck, "main", entry: card.call, quantity: 1)
  few = queries_for(deck_path(deck))

  entries = Array.new(39) { card.call }
  entries.each { |entry| create_lot_in_zone(deck, "main", entry:, quantity: 1) }
  entries.first(20).each { |entry| create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry:, quantity: 2) } # 40 printings, lots and proxies

  expect(queries_for(deck_path(deck))).to eq(few)
end
```

Add the example that pins the panel's one statement (AC-6.1, AC-6.3), where the only change is which zone holds the card:

```ruby
it "adds one statement for the panel, and none when Commander and Main hold no card (spec 069 AC-6.1, AC-6.3)" do
  entry = printing
  create(:mtg_card, identity: entry.identity, mana_value: 2.0)
  outside = create(:deck, account: user.account, name: "Sideboard only")
  inside = create(:deck, account: user.account, name: "In Main")
  create_lot_in_zone(outside, "sideboard", entry:)
  create_lot_in_zone(inside, "main", entry:)

  expect(queries_for(deck_path(inside))).to eq(queries_for(deck_path(outside)) + 1) # the mana values, read once for the curve, average and note
end
```

`Deck::Page` reads the same for both decks (one lot, one entry), so the one statement is the panel's. (`deck_path(outside)`'s panel is empty of cards in its counted zones, so it reads no mana value; the order of the two `queries_for` calls doesn't matter.) Also assert `Deck::Page`'s own counts did not move: run `bin/rspec spec/models/deck/page_spec.rb` unchanged (it asserts the 3 and 6; no edit). The model-level proof of "one statement, none for an empty deck, built once" is T4's "statements" examples. Run `bin/rspec spec/requests/query_counts_spec.rb spec/models/deck/page_spec.rb`. Commit `test(decks): the deck page's queries stay bounded with the panel (#256)`.

### Phase 4: Browser proof

#### T9: The panel on the real page at every width and in both themes

**Satisfies** AC-1.3, AC-2.10, AC-4.9 (colours), AC-5.1 to AC-5.4.
**Files:** create `spec/system/deck_shape_panel_spec.rb`.

The CSS is proved by `design_system_deck_components_spec.rb`; this proves the real page puts the right markup where that CSS works. Test:

```ruby
require "rails_helper"

# Spec 069 Stories 1 and 5: the shape panel on the deck page at 360, 640, 768 and 1280px in both themes, in headless Firefox.
# Phone widths use the narrow frame; headless Firefox has a fine pointer, so the 44px floor is read from the summary's box.
RSpec.describe "Deck shape panel", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "W" * 60) }

  def card(name:, type_line: "Creature — Elf", cost: "{2}{W}{U}{B}{R}{G}", mana_value: 7.0)
    entry = create(:catalog_entry, name:)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    create(:mtg_card, identity: entry.identity, mana_value:)
    entry
  end

  # Every type (Creatures to Other), a five-colour hybrid-heavy cost, proxies, and a mana value of 1,000,000 (the average line's worst case).
  before do
    create_lot_in_zone(deck, "main", entry: card(name: "Worst"), quantity: 123)
    create(:deck_proxy, zone: deck.zone("main"), account:, entry: card(name: "Gleemax", cost: "{W/U}{U/B}{B/R}{R/G}{G/W}", mana_value: 1_000_000.0), quantity: 1234)
    create_lot_in_zone(deck, "main", entry: card(name: "Bolt", type_line: "Instant", cost: "{R}", mana_value: 1.0), quantity: 4)
    create_lot_in_zone(deck, "main", entry: card(name: "Island", type_line: "Basic Land — Island", cost: "", mana_value: 0.0), quantity: 20)
    { "Jace" => "Legendary Planeswalker — Jace", "Invasion of Zendikar" => "Battle — Siege", "Rite" => "Sorcery", "Sol Ring" => "Artifact",
      "Pacifism" => "Enchantment — Aura" }.each { |name, type_line| create_lot_in_zone(deck, "main", entry: card(name:, type_line:, cost: "{1}", mana_value: 1.0), quantity: 1) }
    create_lot_in_zone(deck, "main", entry: create(:mtg_printing, faces: []).entry, quantity: 1) # a printing with no face data: Other
  end

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  def shown?(selector) = page.evaluate_script("(() => { const el = document.querySelector(#{selector.to_json}); return !!el && el.getClientRects().length > 0 })()")

  describe "the page container's widths (AC-1.3)" do
    [ 360, 640 ].each do |width|
      it "shows the details copy, closed, in a #{width}px frame (a container under 640px), and not the aside", :aggregate_failures do
        open_in_narrow_frame(deck_path(deck), width:, ready: "details.c-shapefold")
        within_narrow_frame do
          expect(shown?("details.c-shapefold")).to be(true)
          expect(shown?("aside.c-deck__shape")).to be(false)
          expect(page.evaluate_script('document.querySelector("details.c-shapefold").open')).to be(false)
          expect(page.evaluate_script('document.querySelector("details.c-shapefold summary").getBoundingClientRect().height')).to be >= 44
        end
    end
    end

    # The page container is the frame minus the page's 32px side padding from 640px and a 15px classic scrollbar, so 640px of
    # container needs a frame of at least 640 + 64 + 15 = 719px, and a 640px frame (container 561px) still shows the fold.
    [ 768, 1000 ].each do |width|
      it "shows the aside, open and not sticky, above the zones in a #{width}px frame (a container of 640px to 991px), and not the details copy", :aggregate_failures do
        open_in_narrow_frame(deck_path(deck), width:, ready: "aside.c-deck__shape")
        within_narrow_frame do
          expect(shown?("aside.c-deck__shape")).to be(true)
          expect(shown?("details.c-shapefold")).to be(false)
          expect(page.evaluate_script('getComputedStyle(document.querySelector("aside.c-deck__shape")).position')).not_to eq("sticky")
          above = page.evaluate_script('document.querySelector("aside.c-deck__shape").getBoundingClientRect().bottom <= document.querySelector(".c-deck__zones").getBoundingClientRect().top')
          expect(above).to be(true)
        end
      end
    end

    it "puts the 320px aside beside the zones, sticky, from 1280px", :aggregate_failures do
      visit deck_path(deck)
      page.driver.browser.manage.window.resize_to(1280, 900)
      expect(page).to have_css("aside.c-deck__shape")

      boxes = page.evaluate_script('(() => { const a = document.querySelector("aside.c-deck__shape"), z = document.querySelector(".c-deck__zones"); return { aside: a.getBoundingClientRect().width, left: a.getBoundingClientRect().left > z.getBoundingClientRect().left, sticky: getComputedStyle(a).position } })()')
      expect(boxes).to eq({ "aside" => 320, "left" => true, "sticky" => "sticky" })
      expect(shown?("details.c-shapefold")).to be(false)
    end
  end

  it "opens and closes the fold from the keyboard with no script, its summary ending in Show (AC-5.2)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 360, ready: "details.c-shapefold")
    within_narrow_frame do
      summary = find("details.c-shapefold summary")
      expect(page.evaluate_script('getComputedStyle(document.querySelector("details.c-shapefold summary"), "::after").content')).to include("Show")
      summary.send_keys(:enter)
      expect(page).to have_css("details.c-shapefold[open]")
      summary.send_keys(:space)
      expect(page).to have_no_css("details.c-shapefold[open]")
    end
  end

  [ 360, 640, 768, 1280 ].product(%w[light dark]).each do |width, theme|
    it "has no horizontal overflow at #{width}px in the #{theme} theme with every panel part full (AC-5.1)" do
      open_in_narrow_frame(deck_path(deck), width:, ready: ".c-deck__zones")
      within_narrow_frame do
        page.execute_script("document.documentElement.dataset.theme = #{theme.to_json}")
        page.execute_script('document.querySelector("details.c-shapefold").open = true')
        expect(fits?).to be(true)
      end
    end
  end

  # The 360px frame's container is 313px (360 - 15 for the classic scrollbar - 32 of page padding), the details' border takes 2 and the
  # panel's padding 32: 279px inside. Each check can fail: the panel scrolling sideways, an element drawn past the padding box's
  # right edge, and a text element cut off at its own box.
  it "fits the open fold's parts in the 279px inside it at 360px, with nothing cut off (AC-5.3)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 360, ready: "details.c-shapefold")
    within_narrow_frame do
      page.execute_script('document.querySelector("details.c-shapefold").open = true')
      fit = page.evaluate_script(<<~JS)
        (() => { const panel = document.querySelector("details.c-shapefold .c-shape"), box = panel.getBoundingClientRect()
          const right = box.right - parseFloat(getComputedStyle(panel).paddingRight)
          return { inside: Math.round(panel.clientWidth - 32), scrolls: panel.scrollWidth > panel.clientWidth,
            beyond: [...panel.querySelectorAll("*")].filter((el) => el.getClientRects().length && el.getBoundingClientRect().right > right + 0.5).length,
            clipped: [...panel.querySelectorAll(".c-curve__count, .c-types li > *, .c-curve__legend li, .c-curve__avg, .c-manacap")].filter((el) => el.scrollWidth > el.clientWidth + 1).length,
            cols: panel.querySelectorAll(".c-curve__col").length } })()
      JS
      expect(fit).to eq({ "inside" => 279, "scrolls" => false, "beyond" => 0, "clipped" => 0, "cols" => 7 })
    end
  end

  %w[light dark].each do |theme|
    it "draws owned solid ink-muted, proxy hatched, and the mana segments in their own tokens in the #{theme} theme (AC-2.10, AC-4.9)", :aggregate_failures do
      visit deck_path(deck)
      page.driver.browser.manage.window.resize_to(1280, 900)
      set_theme(theme)
      expect(page).to have_css("aside .c-curve__owned")

      paint = page.evaluate_script(<<~JS)
        (() => { const token = (name) => { const p = document.createElement("span"); p.style.color = `var(${name})`; document.body.append(p); const c = getComputedStyle(p).color; p.remove(); return c }
          const owned = getComputedStyle(document.querySelector("aside .c-curve__owned")), proxy = getComputedStyle(document.querySelector("aside .c-curve__proxy"))
          const segments = [...document.querySelectorAll("aside .c-manabar__seg")].map((seg) => { const colour = seg.className.match(/seg--([wubrg])\b/)[1], style = getComputedStyle(seg)
            return style.backgroundColor === token(`--mana-${colour}`) && style.color === token(`--on-mana-${colour}`) })
          return { owned: owned.backgroundColor === token("--ink-muted"), proxyHatch: proxy.backgroundImage.includes("repeating-linear-gradient"),
                   noBrand: [owned, proxy].every((s) => s.backgroundColor !== token("--brand") && s.borderTopColor !== token("--brand")),
                   segments: segments.length, segmentsRight: segments.every(Boolean) } })()
      JS
      expect(paint).to eq({ "owned" => true, "proxyHatch" => true, "noBrand" => true, "segments" => 5, "segmentsRight" => true })
    end
  end
end
```

Run the new system file and `deck_page_spec` one at a time (shared test database). Prove each narrow assertion once by breaking the CSS or markup (the lesson of `headless-firefox-narrow-frame`): e.g. temporarily rename `c-shapefold` in `_shape.html.erb`, see the 360px example fail, restore. Commit `test(decks): the shape panel at every width and in both themes (#256)`.

### Phase 5: Documents and evidence

#### T10: Area docs, design-system docs, CLAUDE.md, comments

**Satisfies** AC-7.1 to AC-7.4. Documents are verified by reading, never by RSpec (`.claude/rules/testing.md`).
**Files and statements to change** (each with spec 069 and #256 as the source, inline):

- `docs/architecture/collection-and-lots.md`: (1) the deck-page paragraph's last sentence "The right column stays empty for the shape panel (#256)." becomes the panel's rules: the seam (a second optional answer after `deck_card`, `deck_shape(zones)`, asked once by `DecksController#show`), the counted zones (Commander and Main, chosen by the extension), one type per card by the zone tables' group in their order, the curve (nonland cards with a mana value, floor bucketing, 6+ from 6, owned and proxy apart), the exact one-decimal average, the cards with no mana value left out and noted, the first face's cost and Scryfall's mana value, the symbol rules (hybrid and Phyrexian count toward each colour, half symbols and generic never), the percentages and the narrow rule, one added statement and none for an empty deck; (2) **the split-card limit named as deliberate** ("a split card's second half adds no symbol; its mana value is Scryfall's, both halves added"), as the coordinator asked; (3) the second paragraph's list of answers ("The page's collectible part is a second optional answer…") gains the third; (4) line ~152's "(both not built …)" and line ~291's "the shape panel (#256) and proxies (#254) are not" statements brought up to date (grep first: `git grep -n "shape panel\|#256\|not built" -- docs/architecture ':!.kamal/secrets'`); (5) Sources gain spec 069 and #256; (6) the Named constants table gains `MTG::DeckShape::COUNTED_ZONES`, `TOP_COLUMN` and the narrow threshold (10%).
- `docs/architecture/catalog-core.md:180`: "Nothing reads the column yet; the deck shape panel … is its first reader" becomes "The deck shape panel's curve and average read it (spec 069, `MTG::DeckShape`); a card with no value is left out of the curve and noted".
- `docs/design-system/components/DeckShape.md`: replace "Spec 060 builds nothing that reads it … are #256's" with what #256 settled: the bucketing, the average's rounding and exactness, the type order (the zone tables'), which cost counts (first face), the symbol rules, the note under the curve (a second `c-curve__avg` paragraph, after the average) and the empty Card types and Mana symbols sentences (`c-manacap`), the aria-label wording with 0 and 1 cards. `DeckPage.md`: the "As built" paragraph no longer says neither copy is rendered and the second column stays empty; the "**No shape panel** (a deck page before the panel exists)" bullet reads "a deck whose collectible draws no panel"; spec 069 is named in the paragraph's source line.
- `CLAUDE.md`: the decks sentence gains "and shows the deck's shape, its mana curve, card types and coloured mana symbols, in a panel beside the zones (`Catalog::DeckShape`, `MTG::DeckShape`, spec 069)", and the guard sentence "(the deck page's `Catalog::DeckCards` seam among them)" names `Catalog::DeckShape` too. Keep the edit to those two phrases (shared file).
- `docs/specs/README.md`: change the 069 row's Status as the distillation step directs (after the merge); nothing to do at implementation time except keep the row.
- Comments: `bin/yard doc` must build without warnings and `bin/ci checks`' ratchet needs a summary on every new public method (the snippets above carry them); no collectible is named in `Catalog::DeckShape`'s, `decks/_shape.html.erb`'s or `decks/show.html.erb`'s comments.

Run: `bin/yard doc` (no warnings), `bin/rubocop` on the changed files, `bin/rspec spec/deck_core_spec.rb`. Commit `docs(decks): document the shape panel (#256)`.

#### T11: Screenshots and GIFs (the maintainer's added requirement)

**Files:** an uncommitted throwaway `spec/system/zz_069_screenshots_spec.rb` (deleted before the commit), `docs/specs/069-deck-shape-panel/screenshots/*.jpg` and `*.gif` (one commit).

Follow `.claude/memory/pr-screenshots-workflow.md`: factory data (the card pictures are placeholders), `SHOTS_DIR=<scratchpad> bin/rspec spec/system/zz_069_screenshots_spec.rb` (no CI slot; no other test run at the same time), `data-theme` set explicitly for both themes with a 0.6 s pause after each switch, phone shots from `open_in_narrow_frame` at 360 and 390 with the window taller than the frame, `magick in.png -resize 1000x -quality 70 out.jpg`. Shots, each in light and dark, at 1280 and in a 360/390 frame:

1. A full 60-card Main (every type, five colours, owned and proxy mixed): the panel beside the zones; the phone fold closed, and open.
2. A Commander deck (scope "Commander + Main · 100 cards").
3. The edge states of the spec: an empty deck (empty curve, "No cards yet.", "No coloured mana symbols."), a deck whose catalog has no mana values (the note), a deck of proxies only (hatched columns only), a five-colour deck with a narrow white segment (the caption carries it), the long deck name and a mana value of 1,000,000 at 360px.
4. GIF (a deck filling and its panel updating): desktop viewport frames of the deck page after each of: an empty deck; 20 Lands; 24 spells owned; 8 proxies added; the panel redrawn each time (visit the page after creating the data between frames, repeating a frame to hold it); build with `ffmpeg -framerate 4 -pattern_type glob -i 'f-*.png' -vf "scale=960:-1,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse" -loop 0 deck-fills.gif`, under about 1 MB. A phone GIF of the fold opening, if it fits under the size.

Look at every shot and frame yourself before committing; fix anything found test-first (a bug found here becomes a failing example in T7 or T9 first). List them in `verification.md`. Delete the throwaway spec. Commit `docs(specs): screenshots and GIFs of the shape panel (#256)`.

#### T12: `verification.md` and the implementation review

Write `docs/specs/069-deck-shape-panel/verification.md` (AC → the example or the document that proves it, the supersession grep and its result, deviations, and the screenshots list), then run the implementation review (`sdd-review` Mode B, a read-only Opus subagent given the code and the spec, not this plan's conclusions) and record it under `## Implementation review` with the verdict on its first line; at most two rounds. A full `bin/ci` needs a slot from the coordinator (asked for before the push). Not a code task: commit `docs(specs): verification and implementation review of spec 069 (#256)`.

## Spec coverage

| Spec | Task |
|---|---|
| FR-1 (seam), AC-1.4 nil answers, AC-1.7 | T1, T6, T7 |
| FR-2 (figures): decisions 2 to 11, 14 | T2 to T5 |
| FR-3 (view), AC-1.1 to AC-1.3, AC-1.5, AC-1.6, AC-1.8, AC-2.9, AC-2.10, AC-4.9 | T7, T9 |
| Story 2 (AC-2.1 to AC-2.8) | T4 (figures), T7 (page) |
| Story 3 (AC-3.1 to AC-3.5) | T3 |
| Story 4 (AC-4.1 to AC-4.10) | T5, T7 |
| Story 5 (AC-5.1 to AC-5.4) | T9 |
| Story 6 (AC-6.1 to AC-6.3) | T4, T7, T8 |
| Story 7 (AC-7.1 to AC-7.4) | T10 |
| The maintainer's screenshots requirement | T11 |

## Pre-implementation gates

- **Simplicity:** three new units (seam, figures, two partials), no new abstraction beyond the seam the existing pattern prescribes.
- **Anti-abstraction:** the figures object holds the rules because three outputs (curve, types, symbols) share the rows and one statement; there is no wrapper around `MTG::DeckGroups`, only `land?`.
- **Integration-first:** the seam's contract and the figures' interface (T1, T3) come before the view.

## Risks and notes

- `Deck::Page` is not edited; if the page spec's statement counts (3 and 6) change, a mistake was made.
- The rounding rule needs `Rational`: Ruby's `Float#round(1)` happens to give 0.2 for 0.15, so the 0.15 example guards against `format("%.1f", float)` (which rounds the binary value) rather than against `round` itself.
- The system fixture's 6+ column count is "1,357" (123 owned + 1,234 proxy) in a column about 36px wide at 360px. If AC-5.3's `clipped` check fails on `.c-curve__count`, that is a real finding to take back to spec 060's CSS (a scope question for the coordinator), not something to hide by shrinking the fixture. The margin is thin (the count is about 36.0px wide in a column of about 36.4px, in IBM Plex Mono at 12px): T9 also measures the count's width against its column and records the margin in `verification.md`; if the check fails, ask the coordinator before touching the CSS (spec 060 owns it).
- `row.answer.position` is the page's own group, so the panel can't disagree with the zone tables about a card's type.
- #257 (spec 070) may edit `decks/show.html.erb` and `DecksController`: the edits here are one block inside `c-deck` and one line in `show`; on a merge conflict keep both.
