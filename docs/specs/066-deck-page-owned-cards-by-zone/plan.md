# Implementation Plan: The Deck Page, Owned Cards by Zone

**Spec:** [spec.md](spec.md) (v0.3.0, Approved at Gate A, 2026-11-11)
**Decisions:** none new; ADR 0028's seam gets one more optional answer (spec decision 12)
**Created:** 2026-11-11

## Global Constraints

- Read-only page: no write, no table, no export, import or backup change (FR-1, Non-Goals).
- Every read is through the signed-in account; another account's deck, a place's id, a zone's id or an unknown id is a 404 (AC-1.2).
- Core deck files never name a game, a source, a format or a zone but `considering`, comments included; the words `mtg`, `scryfall` and `magic` are banned anywhere in them, and `casual standard pioneer modern legacy vintage pauper commander sideboard` as whole words (`spec/deck_core_spec.rb`). Write comments in the core files without those words.
- One row per printing per zone; Owned is the sum of that printing's lots in the zone whatever the finish, condition or price (decision 2).
- Columns are Card, Cost, Owned, Proxy, Total, in that order, with no menu column; every Proxy cell is a muted dash and Total equals Owned (decision 7). Below 640px of the table's container Owned and Proxy are hidden (spec 060 decision 9, unchanged).
- Zones are in the format's registered order, the rest by id; groups in the extension's order; rows by shown name, set code, collector number as a person reads it, number text, language (decision 3).
- Counts are copies: "Modern · 58 cards · 58 owned" in the head, "12 cards · 12 owned" in a zone head, no "proxy" counts (decision 4).
- No row menu and no form, no "add" link, no drag target on the page; the card name links to `/catalog/entries/:key?from=collection#copies` (decisions 9, 10, AC-4.2).
- Legality: read from the stored data, no request; Casual (no rules) shows no marker; a missing entry for a format with rules reads "Not legal"; an unregistered format shows no marker but keeps groups and costs; the marker is `c-legal c-legal--no` with a cross and its word, written twice (decision 8).
- Group by first face's type line: Creature wins, then Land, then the first match in the order Creatures, Planeswalkers, Battles, Instants, Sorceries, Artifacts, Enchantments, Lands, then Other (decision 6). Cost is the first face's cost (decision 11).
- Design system: tokens and `c-*` classes only; the existing zone CSS (`additions.css`, spec 060) already covers every width, so this plan adds no CSS unless a system example fails (Phase 5 says what to do then).
- Tests: tag spec types explicitly; `:aggregate_failures` on multi-expectation examples; no prose documents checked from RSpec.
- Code documentation (`.claude/rules/code-documentation.md`): every public class, module and method added gets a summary comment; the seam's contract lives in `Catalog::DeckCards`' comment and the area doc points to it.
- One shared test database: never run two spec runs at once. Targeted `bin/rspec <file>` runs need no CI slot; a full `bin/ci` or a push whose hook runs it asks the coordinator for a slot first.
- Commits: Conventional, one per task, each ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; `git add` and `git commit` in separate calls.

---

## Goal

A signed-in collector opens `GET /decks/:id` from the Decks page and reads their deck zone by zone: a table per zone of the printings they own in it, grouped by type, with cost, owned count and a legality marker, the right column left empty for the shape panel.

---

## Pre-implementation gates

- **Simplicity (≤3 components).** Three: `Deck::Page` (reads and shapes the zones), `Catalog::DeckCards` (the seam, with Magic's answer behind it in `MTG::Collecting`, `MTG::DeckGroups` and one partial) and the views with their helper. No new table, gem, controller, JavaScript or CSS.
- **Anti-abstraction.** `Deck::Page` returns three small `Data` shapes (`Row`, `Group`, `Zone`) that the views read directly; there is no parallel view-model layer. The seam is one module, one `Data` answer and one optional vocabulary method, the same shape as `Catalog::Formats`.
- **Integration-first.** The seam's contract test (Phase 0) is written before Magic's answer and before the page; each later phase starts with its failing spec.
- **Statement count (AC-2.10), fixed here:** `Deck::Page#zones` runs exactly **5** statements (the zones, the grouped lot sums, the entries, their sets, one extension read per collectible type; 4 for a deck with no lots, 2 for no zones with lots), given a deck whose location is loaded, whatever the number of zones, rows, lots and printings. The request adds the controller's 2 (the deck and its location). Phase 1 pins the 5; Phase 2 compares a small and a large deck's whole request.

## File map

| File | Change | Responsibility |
|------|--------|----------------|
| `app/models/catalog/deck_cards.rb` | new | The seam: `Answer`, `NONE`, `answer`; the contract comment |
| `app/models/mtg/deck_groups.rb` | new | Magic's type line to group position and name |
| `app/models/mtg/collecting.rb` | edit | `deck_card`, `LEGALITY_FORMATS` |
| `app/views/mtg/printings/_deck_cost.html.erb` | new | The cost cell: pips or a muted dash |
| `app/models/catalog/entry.rb` | edit | `DISPLAY_NAME_SQL` beside `#display_name` |
| `app/models/deck/page.rb` | new | One deck's zones, groups, rows and counts |
| `config/routes.rb` | edit | `show` on `decks` |
| `app/controllers/decks_controller.rb` | edit | `show`, the id guard in `set_deck` |
| `app/views/decks/show.html.erb`, `_zone.html.erb`, `_card_row.html.erb`, `_legality_marker.html.erb` | new | The page |
| `app/helpers/decks_helper.rb` | edit | `deck_counts_line`, `deck_page_line`, `deck_set_line` |
| `app/views/decks/index.html.erb` | edit | The name is a link |
| `spec/deck_core_spec.rb` | edit | Pattern for `deck_cards.rb`, count 26 to 32 |
| `spec/models/catalog/deck_cards_spec.rb`, `spec/models/mtg/deck_groups_spec.rb`, `spec/models/mtg/collecting_deck_card_spec.rb`, `spec/models/catalog/entry_display_name_sql_spec.rb`, `spec/models/deck/page_spec.rb`, `spec/requests/deck_pages_spec.rb`, `spec/system/deck_page_spec.rb` | new | The proofs |
| `spec/requests/decks_spec.rb`, `spec/requests/query_counts_spec.rb` | edit | The link; the page's bounded queries |
| `docs/design-system/components/DeckPage.md`, `DecksIndex.md`, `docs/architecture/collection-and-lots.md`, `docs/architecture/tenancy-and-accounts.md`, `CLAUDE.md`, `docs/specs/README.md`, `verification.md` | edit/new | Documentation (Phase 6) |

Batches for the implementer subagents (2–4 consecutive tasks, one commit per task, test first): **Batch A** = T1–T4, **Batch B** = T5–T7, **Batch C** = T8. The supervisor checks each batch's diff; the documentation (T9) is written by the supervisor.

---

## Phase 0: The seam and Magic's answer

**Implements:** FR-3, Story 6 | **Satisfies:** AC-6.1 (data side), AC-6.3, AC-6.4 (cost data), AC-6.5, AC-6.6, AC-3.1, AC-3.2, AC-3.3, AC-3.4 (data side), AC-3.7
**Files:** `app/models/catalog/deck_cards.rb`, `app/models/mtg/deck_groups.rb`, `app/models/mtg/collecting.rb`, `app/views/mtg/printings/_deck_cost.html.erb`, `spec/models/catalog/deck_cards_spec.rb`, `spec/models/mtg/deck_groups_spec.rb`, `spec/models/mtg/collecting_deck_card_spec.rb`
**Interfaces:** Consumes: `Catalog.collecting_for`, `MTG::Legality.word`, `MTGHelper#mana_cost_tag`, `Catalog::Entry#extension`. Produces: `Catalog::DeckCards::Answer = Data.define(:group, :position, :legality, :costed)`, `Catalog::DeckCards::NONE`, `Catalog::DeckCards.answer(deck_type, entry, format_key) -> Answer`; the optional vocabulary method `deck_card(entry, format_key) -> Answer, nil`; `MTG::DeckGroups.position(type_line) -> Integer`, `MTG::DeckGroups.group_name(position) -> String`; `MTG::Collecting.deck_card`; the partial `mtg/printings/_deck_cost` rendered by `render_catalog_extension(entry, :deck_cost)`.

The contract first: what a vocabulary may answer for a card of a deck, and the core's behavior for every vocabulary that answers nothing, then Magic's mapping.

### T1: the seam `Catalog::DeckCards`

- [ ] Write `spec/models/catalog/deck_cards_spec.rb`:

```ruby
require "rails_helper"

# Spec 066 decision 5, AC-6.1: the deck page's optional answer of a collectible's vocabulary, and the core's flat default.
RSpec.describe Catalog::DeckCards, type: :model do
  let(:entry) { build_stubbed(:catalog_entry) }

  describe ".answer" do
    it "gives the vocabulary's answer for an entry of the deck's own type", :aggregate_failures do
      stub_const("AnsweringCollecting", Module.new do
        def self.deck_card(entry, format_key) = Catalog::DeckCards::Answer.new(group: "Group", position: 3, legality: "Banned: #{format_key}", costed: true)
      end)
      Catalog.collecting["answering"] = "AnsweringCollecting"
      answering = build_stubbed(:catalog_entry, collectible_type: "answering")

      expect(described_class.answer("answering", answering, "k")).to eq(described_class::Answer.new(group: "Group", position: 3, legality: "Banned: k", costed: true))
    ensure
      Catalog.collecting.delete("answering")
    end

    it "gives NONE for an entry of another type than the deck's" do
      expect(described_class.answer("other", entry, "k")).to eq(described_class::NONE) # the entry is of the "mtg" type
    end

    it "gives NONE for a type no longer registered" do
      stranger = build_stubbed(:catalog_entry, collectible_type: "gone")

      expect(described_class.answer("gone", stranger, "x")).to eq(described_class::NONE)
    end

    it "gives NONE when the vocabulary does not answer", :other_collecting do
      other = build_stubbed(:catalog_entry, collectible_type: "other")

      expect(described_class.answer("other", other, "standard")).to eq(described_class::NONE)
    end

    it "gives NONE when the vocabulary answers nil" do
      stub_const("NilCollecting", Module.new { def self.deck_card(*) = nil })
      Catalog.collecting["nilish"] = "NilCollecting"
      nilish = build_stubbed(:catalog_entry, collectible_type: "nilish")

      expect(described_class.answer("nilish", nilish, "k")).to eq(described_class::NONE)
    ensure
      Catalog.collecting.delete("nilish")
    end

    it "has no group, position or legality in NONE and no cost display", :aggregate_failures do
      none = described_class::NONE

      expect([ none.group, none.position, none.legality, none.costed ]).to eq([ nil, nil, nil, false ])
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/catalog/deck_cards_spec.rb` — expect FAIL (`uninitialized constant Catalog::DeckCards`).
- [ ] Implement `app/models/catalog/deck_cards.rb`:

```ruby
# What a deck page asks a collectible's vocabulary about one card of a deck (spec 066 decision 5): the group the card's
# row sits under, whether the extension draws its cost, and the legality marker's word in the deck's format. Like
# `Catalog::Formats`, an optional answer on the collecting vocabulary (`Catalog.collecting_for`), so the core renders the
# page and never names a collectible.
#
# An extension contract: a vocabulary that wants its cards grouped, costed and marked may provide
# * `deck_card(entry, format_key)` returning an {Answer} (or nil for none). `entry` is a `Catalog::Entry` of the vocabulary's
#   own type with its `extension` already loaded (`Catalog::Entry.preload_extensions` ran once per type), so the method
#   reads memory and runs no query. `format_key` is the deck's stored format key, registered or not: answer no legality for
#   a key the collectible has no rules for.
# * `group` is the group's shown name and `position` its place among the groups (lower first); both are nil for a flat row.
# * `legality` is nil for a legal card and for a format with no rules, or the word the page shows beside a cross ("Banned").
# * `costed` is true when the extension has a `deck_cost` partial for the entry, drawn with
#   `render_catalog_extension(entry, :deck_cost)`; the partial draws a muted dash itself for a card with no cost.
# A vocabulary without `deck_card`, an entry of another type than the deck's and a type no longer registered get {NONE}:
# one flat table with a muted dash in Cost and no marker.
# @see file:collection-and-lots.md
module Catalog::DeckCards
  # What the deck page shows for one card; see the module's contract for each member.
  Answer = Data.define(:group, :position, :legality, :costed)
  # The answer for a card the vocabulary does not describe: no group, no marker, no cost display.
  NONE = Answer.new(group: nil, position: nil, legality: nil, costed: false)

  # The deck page's answer for one card.
  #
  # @param deck_type [String] the deck's collectible type
  # @param entry [Catalog::Entry] the card, its `extension` loaded
  # @param format_key [String] the deck's stored format key
  # @return [Answer] the vocabulary's, or {NONE}; never nil and never raises for an unregistered type
  def self.answer(deck_type, entry, format_key)
    return NONE unless entry.collectible_type == deck_type && Catalog.collecting.key?(deck_type)

    vocabulary = Catalog.collecting_for(deck_type)
    return NONE unless vocabulary.respond_to?(:deck_card)

    vocabulary.deck_card(entry, format_key) || NONE
  end
end
```

- [ ] Run: `bin/rspec spec/models/catalog/deck_cards_spec.rb` — expect PASS.
- [ ] Commit: `feat(catalog): add the deck page's optional vocabulary answer`

### T2: Magic's answer: groups, cost and legality

- [ ] Write `spec/models/mtg/deck_groups_spec.rb`:

```ruby
require "rails_helper"

# Spec 066 decision 6, AC-6.3: Magic's top-level types of a printing's first face, as the deck page groups rows.
RSpec.describe MTG::DeckGroups, type: :model do
  describe ".position" do
    {
      "Legendary Creature — Elf Druid" => "Creatures",
      "Artifact Creature — Golem" => "Creatures",
      "Basic Land — Forest" => "Lands",
      "Artifact Land" => "Lands",
      "Land Creature — Forest Dryad" => "Creatures",
      "Kindred Instant — Elf" => "Instants",
      "Instant" => "Instants",
      "Sorcery" => "Sorceries",
      "Legendary Planeswalker — Jace" => "Planeswalkers",
      "Battle — Siege" => "Battles",
      "Legendary Artifact — Equipment" => "Artifacts",
      "Enchantment — Aura" => "Enchantments",
      "Conspiracy" => "Other",
      "" => "Other"
    }.each do |type_line, group|
      it "puts #{type_line.inspect} in #{group}" do
        expect(described_class.group_name(described_class.position(type_line))).to eq(group)
      end
    end

    it "puts a card with no type data in Other" do
      expect(described_class.group_name(described_class.position(nil))).to eq("Other")
    end

    it "does not read a type after the dash" do
      expect(described_class.group_name(described_class.position("Creature — Land"))).to eq("Creatures")
      expect(described_class.group_name(described_class.position("Instant — Land"))).to eq("Instants")
    end
  end

  describe "NAMES" do
    it "lists the groups in the order the page shows them (decision 6)" do
      expect(described_class::NAMES).to eq(%w[Creatures Planeswalkers Battles Instants Sorceries Artifacts Enchantments Lands Other])
    end
  end
end
```

- [ ] Write `spec/models/mtg/collecting_deck_card_spec.rb`:

```ruby
require "rails_helper"

# Spec 066 decisions 6, 8 and 11, AC-3.1 to AC-3.4, AC-6.3 to AC-6.6: Magic's answer to the deck page's seam.
RSpec.describe MTG::Collecting, type: :model do
  def entry_with(type_line: "Instant", cost: "{R}", legalities: {}, faces: nil)
    entry = create(:catalog_entry)
    faces ||= [ { "name" => entry.name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ]
    create(:mtg_printing, entry:, legalities:, faces:)
    Catalog::Entry.preload_extensions([ entry ]).first
  end

  describe ".deck_card" do
    it "groups by the first face's type line and says the cost is drawn", :aggregate_failures do
      answer = described_class.deck_card(entry_with(type_line: "Artifact Creature — Golem"), "modern")

      expect(answer.group).to eq("Creatures")
      expect(answer.position).to eq(0)
      expect(answer.costed).to be(true)
    end

    it "places a multi-face card by its first face (a Sorcery // Land is a Sorcery)" do
      faces = [ { "name" => "A", "type_line" => "Sorcery", "mana_cost" => "{1}{U}" }, { "name" => "B", "type_line" => "Land", "mana_cost" => "" } ]

      expect(described_class.deck_card(entry_with(faces:), "modern").group).to eq("Sorceries")
    end

    it "puts a printing with no face data in Other with no marker", :aggregate_failures do
      answer = described_class.deck_card(entry_with(faces: [], legalities: { "modern" => "banned" }), "casual")

      expect([ answer.group, answer.legality ]).to eq([ "Other", nil ])
    end

    it "puts an entry with no extension record in Other, not costed, with no marker", :aggregate_failures do
      bare = create(:catalog_entry)
      Catalog::Entry.preload_extensions([ bare ])

      answer = described_class.deck_card(bare, "modern")

      expect([ answer.group, answer.costed, answer.legality ]).to eq([ "Other", false, nil ])
    end

    {
      "banned" => "Banned", "restricted" => "Restricted", "not_legal" => "Not legal"
    }.each do |status, word|
      it "reads #{status.inspect} in the deck's own format as #{word.inspect}" do
        expect(described_class.deck_card(entry_with(legalities: { "vintage" => status }), "vintage").legality).to eq(word)
      end
    end

    it "shows no marker for a legal card", :aggregate_failures do
      expect(described_class.deck_card(entry_with(legalities: { "modern" => "legal" }), "modern").legality).to be_nil
    end

    it "reads a card with no entry for the format as Not legal (AC-3.2)" do
      expect(described_class.deck_card(entry_with(legalities: {}), "modern").legality).to eq("Not legal")
    end

    it "reads the legality of each format it registers under the format's own key (AC-6.5)", :aggregate_failures do
      legalities = described_class::LEGALITY_FORMATS.index_with { "banned" }
      entry = entry_with(legalities:)

      described_class::LEGALITY_FORMATS.each do |key|
        expect(described_class.deck_card(entry, key).legality).to eq("Banned"), "#{key} read no legality"
      end
      expect(described_class::LEGALITY_FORMATS).to eq(%w[standard pioneer modern legacy vintage pauper commander])
    end

    it "shows no marker in a format with no rules, whatever the card's legalities (AC-3.3)" do
      expect(described_class.deck_card(entry_with(legalities: { "modern" => "banned" }), "casual").legality).to be_nil
    end

    it "shows no marker for a format the instance no longer registers (AC-3.4)" do
      expect(described_class.deck_card(entry_with(legalities: { "modern" => "banned" }), "retired").legality).to be_nil
    end

    it "registers every deck format Casual aside as one with stored legality (AC-6.5)" do
      keys = described_class.formats.map(&:key) - [ "casual" ]

      expect(keys).to match_array(described_class::LEGALITY_FORMATS)
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/mtg/deck_groups_spec.rb spec/models/mtg/collecting_deck_card_spec.rb` — expect FAIL (`uninitialized constant MTG::DeckGroups`, no `deck_card`).
- [ ] Implement `app/models/mtg/deck_groups.rb`:

```ruby
# Magic's groups for a deck page's rows (spec 066 decision 6): the top-level types of a printing's first face. A card is
# placed by the part of its type line before the dash: a Creature is a Creature whatever else it is (an Artifact Creature,
# Dryad Arbor, a Land Creature), then a Land is a Land (an Artifact Land), then the first of the other types in the order of
# {NAMES}. The order of {NAMES} is the order the groups are shown in; a type line with none of them is Other.
module MTG::DeckGroups
  # The groups, in the order the page shows them.
  NAMES = %w[Creatures Planeswalkers Battles Instants Sorceries Artifacts Enchantments Lands Other].freeze
  # The card type each group but Other collects, at the same index as its name.
  TYPES = %w[Creature Planeswalker Battle Instant Sorcery Artifact Enchantment Land].freeze

  # Where a card's type line puts it among {NAMES}.
  #
  # @param type_line [String, nil] a face's type line, "Legendary Creature — Elf Druid"
  # @return [Integer] an index of {NAMES}; Other's for no type data
  def self.position(type_line)
    types = type_line.to_s.split("—").first.to_s.split
    return TYPES.index("Creature") if types.include?("Creature")
    return TYPES.index("Land") if types.include?("Land")

    TYPES.index { types.include?(it) } || NAMES.index("Other")
  end

  # The group's shown name.
  #
  # @param position [Integer] from {position}
  # @return [String]
  def self.group_name(position) = NAMES.fetch(position)
end
```

- [ ] Edit `app/models/mtg/collecting.rb`: after `def self.formats = FORMATS` add:

```ruby

  # The deck formats whose rules the catalog stores a legality for: Scryfall's legality key is the format's own key, so the
  # deck's key reads the printing's `legalities` directly. Casual has no rules, so it has no entry here and no marker.
  LEGALITY_FORMATS = %w[standard pioneer modern legacy vintage pauper commander].freeze

  # The deck page's answer for one card (spec 066, the extension side of `Catalog::DeckCards`): the group of its first face's
  # type line, the marker word for the deck's format and whether the `deck_cost` partial draws its cost. Reads the loaded
  # extension record only, so no query runs per card.
  #
  # @param entry [Catalog::Entry] a printing with `extension` loaded (`Catalog::Entry.preload_extensions`)
  # @param format_key [String] the deck's stored format key
  # @return [Catalog::DeckCards::Answer]
  def self.deck_card(entry, format_key)
    printing = entry.extension
    position = MTG::DeckGroups.position(printing&.faces&.first&.dig("type_line"))
    Catalog::DeckCards::Answer.new(group: MTG::DeckGroups.group_name(position), position:,
      legality: deck_legality(printing, format_key), costed: !printing.nil?)
  end

  # @api private
  def self.deck_legality(printing, format_key)
    return unless printing && LEGALITY_FORMATS.include?(format_key)

    status = printing.legalities.fetch(format_key, "not_legal")
    MTG::Legality.word(status) unless status == "legal"
  end
  private_class_method :deck_legality
```

- [ ] Create `app/views/mtg/printings/_deck_cost.html.erb` (one line, no trailing blank):

```erb
<%= mana_cost_tag(extension.faces.first&.dig("mana_cost")) || tag.span("–", class: "is-muted") %>
```

- [ ] Run: `bin/rspec spec/models/catalog/deck_cards_spec.rb spec/models/mtg/deck_groups_spec.rb spec/models/mtg/collecting_deck_card_spec.rb` — expect PASS.
- [ ] Commit: `feat(mtg): answer a deck page's groups, cost and legality`

---

## Phase 1: `Deck::Page`

**Implements:** FR-2, FR-3 (the core's use of the seam), Performance NFR | **Satisfies:** AC-1.3 (the counts), AC-2.1, AC-2.2, AC-2.4, AC-2.6, AC-2.8, AC-2.9, AC-2.10, AC-6.1 (rows), AC-6.6 (rows), AC-3.5 (data)
**Files:** `app/models/catalog/entry.rb`, `app/models/deck/page.rb`, `spec/models/catalog/entry_display_name_sql_spec.rb`, `spec/models/deck/page_spec.rb`
**Interfaces:** Consumes: `Catalog::DeckCards.answer`, `Catalog::Formats.zones_for`, `Catalog::Entry.preload_extensions`, `Catalog::Entry::NUMBER_HAS_DIGITS_FIRST`/`NUMBER_VALUE`, `Deck#zones`, `Deck#location`, `Deck#account_id`. Produces: `Catalog::Entry::DISPLAY_NAME_SQL`; `Deck::Page.new(deck)` with `#deck`, `#zones -> Array<Deck::Page::Zone>`, `#owned -> Integer`; `Deck::Page::Zone(location, groups)` with `#id #name #owned #empty?`; `Group(name, rows)` with `#owned`; `Row(entry, owned, answer)`.

### T3: the shown name as SQL

The rows' name order is by the name shown (decision 3), which the model computes in Ruby (`#display_name`). The SQL twin sits beside it and a parity spec holds the two together.

- [ ] Write `spec/models/catalog/entry_display_name_sql_spec.rb`:

```ruby
require "rails_helper"

# Spec 066 decision 3: ordering by the name shown needs the same rule in SQL as `Catalog::Entry#display_name` has in Ruby.
RSpec.describe Catalog::Entry, type: :model do
  describe "DISPLAY_NAME_SQL" do
    it "evaluates to #display_name for English, localized and blank-localized printings", :aggregate_failures do
      entries = [
        create(:catalog_entry, name: "Lightning Bolt", language: "en", localized_name: "ignored"),
        create(:catalog_entry, name: "Lightning Bolt", language: "de", localized_name: "Blitzschlag"),
        create(:catalog_entry, name: "Lightning Bolt", language: "ja", localized_name: ""),
        create(:catalog_entry, name: "Lightning Bolt", language: "fr", localized_name: nil)
      ]

      shown = described_class.where(id: entries.map(&:id)).pluck(:id, described_class::DISPLAY_NAME_SQL).to_h

      entries.each { |entry| expect(shown.fetch(entry.id)).to eq(entry.display_name) }
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/catalog/entry_display_name_sql_spec.rb` — expect FAIL (`uninitialized constant Catalog::Entry::DISPLAY_NAME_SQL`).
- [ ] Edit `app/models/catalog/entry.rb`: after the `def display_name` line add:

```ruby

  # `#display_name` as SQL, for an ORDER BY or a pluck (spec 066 decision 3): the localized name of a non-English printing
  # that has one, else the card's name. Fixed text, nothing interpolated; `spec/models/catalog/entry_display_name_sql_spec.rb`
  # holds it equal to the Ruby rule.
  DISPLAY_NAME_SQL = Arel.sql(
    "CASE WHEN catalog_entries.language <> 'en' AND COALESCE(catalog_entries.localized_name, '') <> '' " \
    "THEN catalog_entries.localized_name ELSE catalog_entries.name END"
  )
```

- [ ] Run: `bin/rspec spec/models/catalog/entry_display_name_sql_spec.rb` — expect PASS.
- [ ] Commit: `feat(catalog): add the shown name as SQL for ordering`

### T4: `Deck::Page`

- [ ] Write `spec/models/deck/page_spec.rb`:

```ruby
require "rails_helper"

# Spec 066 FR-2, Story 2: one deck's zones, groups, rows and counts, read in a bounded number of statements.
RSpec.describe Deck::Page, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def printing(name: "Lightning Bolt", type_line: "Instant", cost: "{R}", set: create(:catalog_set), **attrs)
    entry = create(:catalog_entry, name:, set:, **attrs)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    entry
  end

  def page_of(deck) = described_class.new(Deck.includes(:location).find_by!(location_id: deck.location_id))
  def zone_named(page, name) = page.zones.find { it.name == name }
  def names(zone) = zone.groups.flat_map { |group| group.rows.map { it.entry.display_name } }

  describe "#zones" do
    it "lists the zones in the format's order (AC-2.1)" do
      expect(page_of(create(:deck, account:, name: "Krenko", format: "commander")).zones.map(&:name)).to eq(%w[Commander Main Considering])
    end

    it "lists Main, Sideboard, Considering after a change from Commander to Modern added Sideboard last by id (AC-2.2)" do
      commander = create(:deck, account:, name: "Krenko", format: "commander")
      Deck::FormatChange.new(deck: commander, format: "mtg/modern").save!

      expect(page_of(commander).zones.map(&:name)).to eq(%w[Main Sideboard Considering])
    end

    it "puts every zone of an unregistered format in id order (AC-2.1)" do
      deck.update!(format: "retired")

      expect(page_of(deck).zones.map(&:name)).to eq(deck.zones.order(:id).pluck(:name))
    end

    it "has a zone for every zone of the deck, with no rows for an empty one (AC-2.7)", :aggregate_failures do
      zone = zone_named(page_of(deck), "Sideboard")

      expect(zone.empty?).to be(true)
      expect(zone.owned).to eq(0)
    end

    it "sums a printing's lots in the zone whatever the finish, and counts nothing outside it (AC-2.4, AC-2.8)", :aggregate_failures do
      entry = printing
      create_lot_in_zone(deck, "main", entry:, quantity: 2, finish: "foil")
      create_lot_in_zone(deck, "main", entry:, quantity: 1, finish: "nonfoil")
      create_lot_in_zone(deck, "sideboard", entry:, quantity: 5)
      other = create(:deck, account:, name: "Other")
      create_lot_in_zone(other, "main", entry:, quantity: 7)
      create(:lot, account:, entry:, quantity: 9, location: create(:location, account:))
      create(:lot, account:, entry:, quantity: 11)
      create(:lot, entry:, quantity: 13) # another account's lot of the same printing

      page = page_of(deck)

      expect(zone_named(page, "Main").groups.flat_map(&:rows).map(&:owned)).to eq([ 3 ])
      expect(zone_named(page, "Sideboard").owned).to eq(5)
      expect(page.owned).to eq(8)
    end

    it "keeps two printings of one card as two rows (AC-2.4)" do
      create_lot_in_zone(deck, "main", entry: printing(number: "1"), quantity: 2)
      create_lot_in_zone(deck, "main", entry: printing(number: "2"), quantity: 1)

      expect(zone_named(page_of(deck), "Main").groups.flat_map(&:rows).map(&:owned)).to eq([ 2, 1 ])
    end

    it "shows a retired printing like any other (AC-2.9)" do
      create_lot_in_zone(deck, "main", entry: printing(retired_at: 1.day.ago), quantity: 1)

      expect(zone_named(page_of(deck), "Main").owned).to eq(1)
    end
  end

  describe "groups and order (AC-2.6)" do
    it "lists groups in the extension's order, none for a group with no cards, with the copies in each", :aggregate_failures do
      create_lot_in_zone(deck, "main", entry: printing(name: "Island", type_line: "Basic Land — Island"), quantity: 20)
      create_lot_in_zone(deck, "main", entry: printing(name: "Murktide Regent", type_line: "Creature — Dragon"), quantity: 2)
      create_lot_in_zone(deck, "main", entry: printing(name: "Lightning Bolt", type_line: "Instant"), quantity: 4)

      groups = zone_named(page_of(deck), "Main").groups

      expect(groups.map(&:name)).to eq(%w[Creatures Instants Lands])
      expect(groups.map(&:owned)).to eq([ 2, 4, 20 ])
    end

    it "orders rows by shown name, set code, number as a person reads it, number text and language", :aggregate_failures do
      aaa = create(:catalog_set, code: "aaa")
      bbb = create(:catalog_set, code: "bbb")
      [
        [ "Bolt", bbb, "1", "en" ], [ "Bolt", aaa, "10", "en" ], [ "Bolt", aaa, "2", "en" ], [ "Bolt", aaa, "★", "en" ],
        [ "Bolt", aaa, "2", "de" ], [ "Abzan", bbb, "9", "en" ]
      ].each do |name, set, number, language|
        entry = printing(name:, set:, number:, language:, localized_name: (language == "en" ? nil : "Blitz"))
        create_lot_in_zone(deck, "main", entry:, quantity: 1)
      end

      rows = zone_named(page_of(deck), "Main").groups.flat_map(&:rows)

      expect(rows.map { [ it.entry.display_name, it.entry.set.code, it.entry.number, it.entry.language ] }).to eq([
        [ "Abzan", "bbb", "9", "en" ], [ "Blitz", "aaa", "2", "de" ], [ "Bolt", "aaa", "2", "en" ], [ "Bolt", "aaa", "10", "en" ],
        [ "Bolt", "aaa", "★", "en" ], [ "Bolt", "bbb", "1", "en" ]
      ])
    end

    it "gives a flat zone, one group with no name, when the type's vocabulary answers nothing (AC-6.1)", :aggregate_failures, :other_collecting do
      other_deck = create(:deck, account:, name: "Other deck", pair: "other/standard")
      entry = create(:catalog_entry, collectible_type: "other", name: "Thing")
      Lot.add!(account:, entry:, location: other_deck.zone("deck"), quantity: 3)

      zone = zone_named(page_of(other_deck), "Deck")

      expect(zone.groups.map(&:name)).to eq([ nil ])
      expect(zone.groups.first.rows.first.answer).to eq(Catalog::DeckCards::NONE)
    end

    it "puts a printing with no extension record in Other with a not-costed answer (AC-6.6)", :aggregate_failures do
      create_lot_in_zone(deck, "main", entry: create(:catalog_entry, name: "Bare"), quantity: 1)

      row = zone_named(page_of(deck), "Main").groups.first.rows.first

      expect([ row.answer.group, row.answer.costed ]).to eq([ "Other", false ])
    end
  end

  describe "statements (AC-2.10)" do
    def seed(zones:, printings:)
      printings.times do |i|
        entry = printing(name: "Card #{i}", type_line: i.even? ? "Creature" : "Instant", number: i.to_s)
        zones.each { |zone| create_lot_in_zone(deck, zone, entry:, quantity: 1 + i, finish: "nonfoil") }
      end
    end

    it "runs 5 statements for a small deck and for a large one alike", :aggregate_failures do
      seed(zones: %w[main], printings: 1)
      small = page_of(deck).then { |page| count_queries { page.zones } } # the deck and its location are read outside the count
      seed(zones: %w[main sideboard considering], printings: 12)
      large = page_of(deck).then { |page| count_queries { page.zones } }

      expect([ small, large ]).to eq([ 5, 5 ]) # the zones, the copies, the entries, their sets, the one extension read
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/deck/page_spec.rb` — expect FAIL (`uninitialized constant Deck::Page`).
- [ ] Implement `app/models/deck/page.rb`:

```ruby
# One deck's page (spec 066): its zones in the format's order, each with the printings the account owns in it grouped as the
# collectible's vocabulary groups them, and the counts. Reads only; needs the deck, which came from the signed-in account's
# decks, so every read is scoped to it by value and costs no extra statement.
#
# Reads in a bounded number of statements however many zones, rows and lots the deck has: the zones, the lots' copies summed
# per zone and printing, the printings with their sets, and the extension records once per collectible type (5 in all
# when the deck's location is loaded; spec 066 AC-2.10). A row is one printing in one zone: its lots of every finish,
# condition and price are summed (decision 2).
# @see file:collection-and-lots.md
class Deck::Page
  # One printing in one zone: the entry (its set and extension loaded), the copies owned and the vocabulary's answer.
  Row = Data.define(:entry, :owned, :answer)
  # The rows under one group's name; a nil name is the flat group of a collectible that answers nothing.
  Group = Data.define(:name, :rows) do
    # The copies in the group.
    def owned = rows.sum(&:owned)
  end
  # One zone: its location and its groups in the extension's order.
  Zone = Data.define(:location, :groups) do
    # The zone location's id.
    def id = location.id

    # The zone's shown name.
    def name = location.name

    # The copies in the zone.
    def owned = groups.sum(&:owned)

    # Whether the zone holds no lot.
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
  #
  # @return [Integer]
  def owned = zones.sum(&:owned)

  private
    def build_zones
      locations = ordered_locations
      copies = copies_by_zone_and_entry(locations)
      entries = entries_for(copies.keys.map(&:last).uniq)
      locations.map { |location| Zone.new(location:, groups: groups_for(location, entries, copies)) }
    end

    def ordered_locations
      keys = Catalog::Formats.zones_for(deck.collectible_type, deck.format)&.map(&:key) || []
      deck.zones.to_a.sort_by { |zone| [ keys.index(zone.zone) || keys.size, zone.id ] }
    end

    # One grouped statement: { [zone id, entry id] => copies }. The account is the deck's, by value.
    def copies_by_zone_and_entry(locations)
      Lot.where(account_id: deck.account_id, location_id: locations.map(&:id)).group(:location_id, :catalog_entry_id).sum(:quantity)
    end

    # The printings in the order a zone lists them, with sets and extension records: two statements and one per type.
    def entries_for(ids)
      return [] if ids.empty?

      entries = Catalog::Entry.where(id: ids).joins(:set).preload(:set).order(
        Catalog::Entry::DISPLAY_NAME_SQL, Catalog::Set.arel_table[:code].asc,
        Catalog::Entry::NUMBER_HAS_DIGITS_FIRST, Catalog::Entry::NUMBER_VALUE,
        Catalog::Entry.arel_table[:number].asc, Catalog::Entry.arel_table[:language].asc
      ).to_a
      Catalog::Entry.preload_extensions(entries.select { Catalog.sources.key?(it.collectible_type) }) # a type with no source has no extension model to ask
    end

    # The zone's rows in the printings' order, grouped by the vocabulary's position (a row with none last), each group
    # named by its answer.
    def groups_for(location, entries, copies)
      rows = entries.filter_map do |entry|
        owned = copies[[ location.id, entry.id ]] or next
        Row.new(entry:, owned:, answer: Catalog::DeckCards.answer(deck.collectible_type, entry, deck.format))
      end
      rows.group_by { it.answer.position }.sort_by { |position, _| position || Float::INFINITY }
        .map { |_position, in_group| Group.new(name: in_group.first.answer.group, rows: in_group) }
    end
end
```

- [ ] Run: `bin/rspec spec/models/deck/page_spec.rb` — expect PASS. If the statement example reads a number other than 5, report which statement differs (print the SQL with a `sql.active_record` subscriber) instead of changing the 5.
- [ ] Run: `bin/rspec spec/models/deck spec/models/catalog spec/models/mtg spec/deck_core_spec.rb` — expect PASS (`deck_core_spec` still counts 26; the new core file is outside its globs until T7).
- [ ] Commit: `feat(decks): add Deck::Page, a deck's zones, groups and rows`

---

## Phase 2: The route, the controller and the views

**Implements:** FR-1, FR-2, FR-3, Stories 1–4 and 5 (AC-5.3, AC-5.7) | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.6, AC-2.1, AC-2.3, AC-2.4, AC-2.5, AC-2.6, AC-2.7, AC-2.10, AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.5, AC-3.6, AC-4.1, AC-4.2, AC-5.3 (markup), AC-5.7, AC-6.1, AC-6.4, AC-6.6
**Files:** `config/routes.rb`, `app/controllers/decks_controller.rb`, `app/helpers/decks_helper.rb`, `app/views/decks/show.html.erb`, `app/views/decks/_zone.html.erb`, `app/views/decks/_card_row.html.erb`, `app/views/decks/_legality_marker.html.erb`, `spec/requests/deck_pages_spec.rb`, `spec/requests/query_counts_spec.rb`
**Interfaces:** Consumes: `Deck::Page`, `DecksHelper`, `catalog_entry_path`, `set_number`, `render_catalog_extension`, layouts `appbar`/`tabbar`, icons `more` and `cross`. Produces: `GET /decks/:id` (`deck_path(deck)`), `@page`, `deck_counts_line(owned)`, `deck_page_line(page)`, `deck_set_line(entry)`.

### T5: the page

- [ ] Write `spec/requests/deck_pages_spec.rb`:

```ruby
require "rails_helper"

# Spec 066 Stories 1 to 4 and 6: the deck page, GET /decks/:id.
RSpec.describe "Deck page", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def html = Nokogiri::HTML5(response.body)
  def zone_section(name) = html.css("section.c-zone").find { it.at_css("h2").text == name }
  def card_rows(section) = section.css("tbody tr:not(.c-zone__group)")
  def own(zone, entry, quantity: 1, **attrs) = create_lot_in_zone(deck, zone, entry:, quantity:, **attrs)

  def printing(name: "Lightning Bolt", type_line: "Instant", cost: "{R}", legalities: {}, **attrs)
    entry = create(:catalog_entry, name:, **attrs)
    create(:mtg_printing, entry:, legalities:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    entry
  end

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the page and its head (Story 1)" do
      it "answers 200 as a detail page under Decks with the deck's name as the h1 (AC-1.1)", :aggregate_failures do
        get deck_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Izzet Tempo · Collector")
        expect(html.at_css("h1").text).to eq("Izzet Tempo")
        expect(html.at_css("header.c-appbar--detail")).to be_present
        expect(html.at_css("header a[aria-label='Back'][href='#{decks_path}']")).to be_present
        expect(html.at_css("header nav a[aria-current='page']").text).to eq("Decks")
        expect(html.at_css("nav.c-tabbar a[aria-current='page']")&.text.to_s).to include("Decks")
      end

      it "reads the format and the copies of every zone, Considering included (AC-1.3)", :aggregate_failures do
        own("main", printing, quantity: 40)
        own("sideboard", printing(name: "Spell Pierce"), quantity: 15)
        own("considering", printing(name: "Force of Will"), quantity: 3)

        get deck_path(deck)

        expect(html.at_css(".c-item__type").text).to eq("Modern · 58 cards · 58 owned")
      end

      it "reads '1 card · 1 owned' for one copy and '0 cards · 0 owned' for none (AC-1.3)", :aggregate_failures do
        get deck_path(deck)
        expect(html.at_css(".c-item__type").text).to eq("Modern · 0 cards · 0 owned")

        own("main", printing)
        get deck_path(deck)
        expect(html.at_css(".c-item__type").text).to eq("Modern · 1 card · 1 owned")
      end

      it "shows the stored format key for a format the instance no longer registers (AC-1.3)" do
        deck.update!(format: "retired")

        get deck_path(deck)

        expect(html.at_css(".c-item__type").text).to eq("retired · 0 cards · 0 owned")
      end

      it "offers Edit deck, then a menu with Change format and, after a separator, Remove deck (AC-1.4)", :aggregate_failures do
        get deck_path(deck)

        expect(html.at_css(".c-item__actions > a.c-btn--secondary[href='#{edit_deck_path(deck)}']").text).to eq("Edit deck")
        items = html.css(".c-item__actions .c-menu__list > *")
        expect(items.map { [ it["class"], it.text.strip ] }).to eq([
          [ "c-menu__item", "Change format" ], [ "c-menu__sep", "" ], [ "c-menu__item c-menu__item--danger", "Remove deck" ]
        ])
        expect(items.first["href"]).to eq(edit_deck_format_path(deck))
        expect(items.last["href"]).to eq(new_deck_removal_path(deck))
      end

      it "has no proxy control, no proxy count and no shape panel (AC-1.6)", :aggregate_failures do
        own("main", printing)

        get deck_path(deck)

        expect(html.at_css("main").text).not_to match(/proxy/i)
        expect(html.at_css("aside.c-deck__shape, details.c-shapefold")).to be_nil
      end
    end

    describe "tenancy (AC-1.2)" do
      it "answers 404 for another account's deck, a place's id, a zone's id and an id nothing has", :aggregate_failures do
        other = create(:deck, account: create(:user).account, name: "Theirs")
        place = create(:location, account:)

        [ other.to_param, place.id, deck.zone("main").id, 0, "abc", "#{deck.location_id}abc", Location.maximum(:id).to_i + 100 ].each do |id|
          get deck_path(id)
          expect(response).to have_http_status(:not_found), "#{id.inspect} was not a 404"
        end
        expect(response.body).not_to include("Theirs")
      end

      it "sends a visitor who is not signed in to sign in" do
        delete session_path

        get deck_path(deck)

        expect(response).to redirect_to(new_session_path)
      end
    end

    describe "zones (Story 2)" do
      it "stacks a section per zone, h2 and counts, in the format's order, each table named by its heading (AC-2.1, AC-2.3)", :aggregate_failures do
        own("main", printing, quantity: 12)

        get deck_path(deck)

        expect(html.css("section.c-zone h2").map(&:text)).to eq(%w[Main Sideboard Considering])
        expect(zone_section("Main").at_css(".c-section__count").text).to eq("12 cards · 12 owned")
        table = zone_section("Main").at_css("table")
        expect(table["aria-labelledby"]).to eq(zone_section("Main").at_css("h2")["id"])
        expect(table.css("thead th").map { it.text.squish }).to eq([ "Card", "Cost", "Owned", "Proxy", "Total" ])
      end

      it "lists Commander first for a Commander deck (AC-2.1)" do
        krenko = create(:deck, account:, name: "Krenko", format: "commander")

        get deck_path(krenko)

        expect(html.css("section.c-zone h2").map(&:text)).to eq(%w[Commander Main Considering])
      end

      it "lists Main, Sideboard, Considering after a change from Commander to Modern (AC-2.2)" do
        krenko = create(:deck, account:, name: "Krenko", format: "commander")
        Deck::FormatChange.new(deck: krenko, format: "mtg/modern").save!

        get deck_path(krenko)

        expect(html.css("section.c-zone h2").map(&:text)).to eq(%w[Main Sideboard Considering])
      end

      it "adds a printing's lots of every finish into one row, Proxy a dash and Total equal to Owned (AC-2.3, AC-2.4)", :aggregate_failures do
        bolt = printing
        own("main", bolt, quantity: 2, finish: "foil")
        own("main", bolt, quantity: 1, finish: "nonfoil")
        own("main", printing(name: "Lightning Bolt", number: "9"), quantity: 4) # another printing of the card
        own("sideboard", bolt, quantity: 8) # another zone
        create(:lot, account:, entry: bolt, quantity: 6, location: create(:location, account:)) # a place
        create(:lot, entry: bolt, quantity: 5) # another account

        get deck_path(deck)

        cells = card_rows(zone_section("Main")).map { |row| row.css("td").map { it.text.squish } }
        expect(cells.size).to eq(2)
        expect(cells.map { it.values_at(2, 4) }).to contain_exactly([ "3", "3" ], [ "4", "4" ])
        expect(cells.map { it[3] }).to eq([ "–", "–" ])
        expect(card_rows(zone_section("Main")).first.css("td")[3].at_css(".is-muted")).to be_present
      end

      it "shows the name linked to the card's copies in the collection's context, and SET · NUMBER under it (AC-2.5, AC-4.1)", :aggregate_failures do
        entry = printing(name: "Murktide Regent", type_line: "Creature — Dragon", number: "52")
        own("main", entry)

        get deck_path(deck)

        card = card_rows(zone_section("Main")).first.at_css("td")
        link = card.at_css("a")
        expect(link.text).to eq("Murktide Regent")
        expect(link["href"]).to eq(catalog_entry_path(entry, from: "collection", anchor: "copies"))
        expect(card.css(".c-zone__set").map { it.text }).to eq([ "#{entry.set.code.upcase} · 52" ] * 2)
      end

      it "shows a non-English printing under its localized name with its language after the number (AC-2.5)", :aggregate_failures do
        entry = printing(name: "Lightning Bolt", language: "de", localized_name: "Blitzschlag")
        own("main", entry)

        get deck_path(deck)

        card = card_rows(zone_section("Main")).first.at_css("td")
        expect(card.at_css("a").text).to eq("Blitzschlag")
        expect(card.css(".c-zone__set").first.text).to eq("#{entry.set.code.upcase} · #{entry.number} · DE")
      end

      it "puts each group in its own tbody under a rowgroup header with its copies, in the extension's order (AC-2.6, AC-5.7)", :aggregate_failures do
        own("main", printing(name: "Island", type_line: "Basic Land — Island"), quantity: 20)
        own("main", printing(name: "Murktide Regent", type_line: "Creature — Dragon"), quantity: 2)
        own("main", printing(name: "Dryad Arbor", type_line: "Land Creature — Forest Dryad"), quantity: 1)

        get deck_path(deck)

        bodies = zone_section("Main").css("table tbody")
        expect(bodies.map { it.at_css("tr.c-zone__group th[scope='rowgroup']").text }).to eq([ "Creatures3", "Lands20" ])
        expect(bodies.map { it.at_css("th[scope='rowgroup']")["colspan"] }).to eq(%w[5 5])
        expect(bodies.first.css("tr:not(.c-zone__group) td a").map(&:text)).to eq([ "Dryad Arbor", "Murktide Regent" ])
      end

      it "shows the empty sentence in place of a table for an empty zone (AC-2.7)", :aggregate_failures do
        own("main", printing)

        get deck_path(deck)

        sideboard = zone_section("Sideboard")
        expect(sideboard.at_css(".c-section__count").text).to eq("0 cards · 0 owned")
        expect(sideboard.at_css("p.c-zone__empty").text).to eq("No cards in Sideboard yet.")
        expect(sideboard.at_css("table")).to be_nil
      end

      it "does not show or count copies of another deck of the account (AC-2.8)", :aggregate_failures do
        other = create(:deck, account:, name: "Other")
        create_lot_in_zone(other, "main", entry: printing(name: "Elsewhere"), quantity: 9)

        get deck_path(deck)

        expect(response.body).not_to include("Elsewhere")
        expect(html.at_css(".c-item__type").text).to eq("Modern · 0 cards · 0 owned")
      end

      it "shows a retired printing like any other (AC-2.9)" do
        own("main", printing(name: "Old Card", retired_at: 1.day.ago))

        get deck_path(deck)

        expect(card_rows(zone_section("Main")).first.at_css("a").text).to eq("Old Card")
      end

      it "escapes a card name with markup" do
        own("main", printing(name: "<script>alert(1)</script>"))

        get deck_path(deck)

        expect(response.body).not_to include("<script>alert(1)</script>")
      end
    end

    describe "cost (AC-6.4)" do
      it "draws the first face's pips, not the second's, and a muted dash for no cost", :aggregate_failures do
        pips = printing(name: "Tarmogoyf", type_line: "Creature", cost: "{3}{G}{G}")
        double = printing(name: "Delver", cost: "{1}{U}")
        double.extension.update!(faces: [ { "name" => "Delver", "type_line" => "Creature", "mana_cost" => "{1}{U}" },
                                          { "name" => "Insectile", "type_line" => "Creature", "mana_cost" => "{2}{G}" } ])
        land = printing(name: "Island", type_line: "Basic Land — Island", cost: "")
        [ pips, double, land ].each { own("main", it) }

        get deck_path(deck)

        cost = ->(name) { card_rows(zone_section("Main")).find { |row| row.at_css("a").text == name }.css("td")[1] }
        expect(cost.("Tarmogoyf").at_css(".c-cost")["aria-label"]).to eq("Mana cost: 3 generic, 1 green, 1 green")
        expect(cost.("Delver").at_css(".c-cost")["aria-label"]).to eq("Mana cost: 1 generic, 1 blue")
        expect(cost.("Island").at_css(".c-cost")).to be_nil
        expect(cost.("Island").at_css(".is-muted").text).to eq("–")
      end
    end

    describe "the legality marker (Story 3)" do
      def markers(name) = card_rows(zone_section("Main")).find { it.at_css("a").text == name }.css(".c-legal")

      it "marks a banned, a restricted and a not legal card in the deck's format in the muted ink, and not a legal one (AC-3.1)", :aggregate_failures do
        own("main", printing(name: "Ragavan", legalities: { "modern" => "banned" }))
        own("main", printing(name: "Pyroblast", legalities: { "modern" => "not_legal" }))
        own("main", printing(name: "Bolt", legalities: { "modern" => "legal" }))
        vintage = create(:deck, account:, name: "Vintage", format: "vintage")
        create_lot_in_zone(vintage, "main", entry: printing(name: "Black Lotus", legalities: { "vintage" => "restricted" }))

        get deck_path(deck)
        expect(markers("Ragavan").map { it.text.strip }).to eq([ "Banned", "Banned" ])
        expect(markers("Pyroblast").map { it.text.strip }).to eq([ "Not legal", "Not legal" ])
        expect(markers("Bolt")).to be_empty
        expect(markers("Ragavan").first["class"]).to eq("c-legal c-legal--no")
        expect(markers("Ragavan").first.at_css("svg")).to be_present

        get deck_path(vintage)
        expect(html.css(".c-legal").map { it.text.strip }).to eq([ "Restricted", "Restricted" ])
      end

      it "reads a card with no entry for the format as Not legal (AC-3.2)" do
        own("main", printing(name: "Blank", legalities: {}))

        get deck_path(deck)

        expect(markers("Blank").map { it.text.strip }).to eq([ "Not legal", "Not legal" ])
      end

      it "shows no marker in a Casual deck (AC-3.3)" do
        casual = create(:deck, account:, name: "Casual", format: "casual")
        create_lot_in_zone(casual, "main", entry: printing(legalities: { "modern" => "banned" }))

        get deck_path(casual)

        expect(html.css(".c-legal")).to be_empty
      end

      it "shows no marker for an unregistered format and keeps the groups and costs (AC-3.4)", :aggregate_failures do
        deck.update!(format: "retired")
        own("main", printing(name: "Ragavan", type_line: "Creature", legalities: { "modern" => "banned" }))

        get deck_path(deck)

        expect(html.css(".c-legal")).to be_empty
        expect(html.css("tr.c-zone__group th").first.text).to start_with("Creatures")
        expect(html.at_css(".c-cost")).to be_present
      end

      it "drops the marker after the deck's format changes to one the card is legal in (AC-3.5)", :aggregate_failures do
        standard = create(:deck, account:, name: "Std", format: "standard")
        create_lot_in_zone(standard, "main", entry: printing(name: "Mox", legalities: { "standard" => "not_legal", "modern" => "legal" }))
        get deck_path(standard)
        expect(html.css(".c-legal").size).to eq(2)

        Deck::FormatChange.new(deck: standard, format: "mtg/modern").save!
        get deck_path(standard)

        expect(html.css(".c-legal")).to be_empty
      end

      it "writes the marker beside the name inside is-opt and in the line under it (AC-3.6)", :aggregate_failures do
        own("main", printing(name: "Ragavan", legalities: { "modern" => "banned" }))

        get deck_path(deck)

        cell = card_rows(zone_section("Main")).first.at_css("td")
        expect(cell.css(".is-opt .c-legal").size).to eq(1)
        expect(cell.css(".c-table__sub .c-legal").size).to eq(1)
      end

      it "sends no request out of the app to read a legality (AC-3.7)" do
        own("main", printing(legalities: { "modern" => "banned" }))

        get deck_path(deck)

        expect(response).to have_http_status(:ok) # WebMock blocks every real request, so a fetch would have raised
      end
    end

    describe "copies are not added or moved here (Story 4)" do
      it "has no form, no row menu, no link to add, to number entry or to the scanner inside the page, no drag target (AC-4.2)", :aggregate_failures do
        own("main", printing)

        get deck_path(deck)

        main = html.at_css("main")
        expect(main.css("form, .c-table__actions, [draggable]")).to be_empty
        hrefs = main.css("a").map { it["href"] }
        expect(hrefs.grep(%r{/lots/new|number_entry|/scanner})).to be_empty
        expect(main.css("tbody a").map { it["href"] }).to all(include("from=collection#copies"))
      end
    end

    describe "a collectible that answers nothing (AC-6.1, AC-6.6)", :other_collecting do
      it "renders one flat table with a dash in Cost and no marker", :aggregate_failures do
        other = create(:deck, account:, name: "Other deck", pair: "other/standard")
        Lot.add!(account:, entry: create(:catalog_entry, collectible_type: "other", name: "Thing"), location: other.zone("deck"), quantity: 3)

        get deck_path(other)

        expect(response).to have_http_status(:ok)
        expect(html.css("tr.c-zone__group")).to be_empty
        expect(html.css("table tbody").size).to eq(1)
        row = html.at_css("tbody tr")
        expect(row.css("td")[1].at_css(".is-muted").text).to eq("–")
        expect(html.css(".c-legal")).to be_empty
      end
    end

    it "keeps a printing with no extension record in Other with a dash and no marker (AC-6.6)", :aggregate_failures do
      own("main", create(:catalog_entry, name: "Bare"))

      get deck_path(deck)

      expect(zone_section("Main").at_css("tr.c-zone__group th").text).to start_with("Other")
      expect(card_rows(zone_section("Main")).first.css("td")[1].at_css(".is-muted").text).to eq("–")
      expect(html.css(".c-legal")).to be_empty
    end
  end
end
```

- [ ] Add to `spec/requests/query_counts_spec.rb` (before the final `end`, using its `printing`, `own` and `queries_for` helpers; `create_lot_in_zone` comes from `DeckHelpers`):

```ruby
  it "keeps the deck page's queries independent of the zones, printings and lots a deck holds (spec 066 AC-2.10)" do
    deck = create(:deck, account: user.account, name: "Izzet Tempo")
    create_lot_in_zone(deck, "main", entry: printing(identity: create(:catalog_identity, name: "One")))
    few = queries_for(deck_path(deck))
    24.times do |n|
      entry = printing(identity: create(:catalog_identity, name: "Card #{n}"), number: (n + 2).to_s)
      create_lot_in_zone(deck, %w[main sideboard considering][n % 3], entry:, finish: n.even? ? "foil" : "nonfoil")
    end

    expect(queries_for(deck_path(deck))).to eq(few)
  end
```

- [ ] Run: `bin/rspec spec/requests/deck_pages_spec.rb spec/requests/query_counts_spec.rb` — expect FAIL (no route `deck_path`... `undefined method`/routing error).
- [ ] Edit `config/routes.rb` line 48: `resources :decks, only: %i[index show new create edit update destroy] do`.
- [ ] Edit `app/controllers/decks_controller.rb`: replace the file header comment's first sentence and `before_action`, add `show`, guard the id:

```ruby
# Spec 062: the signed-in collector's decks, and spec 066's page of one deck. Every lookup is through Current.account and by the
# deck's location id, so another account's deck, a place or a zone is a 404 (AC-9.7, AC-3.8, spec 066 AC-1.2); nothing in a
# request names an account, a kind or a parent.
# @see file:collection-and-lots.md
class DecksController < ApplicationController
  before_action :set_deck, only: %i[show edit update destroy]

  def index
    @listing = Deck::Listing.new(Current.account)
  end

  # One deck's zones with the cards the account owns in them (spec 066). Reads only.
  def show
    @page = Deck::Page.new(@deck)
  end
```

and replace `set_deck` and its comment with:

```ruby
    # `find_by!` raises RecordNotFound (404) for another account's deck and for a place's or a zone's location id, which no
    # deck row points at. An id is text of digits only: "12abc" would otherwise cast to 12 (`Location::ID_TEXT`, spec 066 AC-1.2).
    def set_deck
      raise ActiveRecord::RecordNotFound, "not a deck id" unless params[:id].to_s.match?(Location::ID_TEXT)

      @deck = Current.account.decks.includes(:location).find_by!(location_id: params[:id])
    end
```

(The id `0` and `"abc"` also fail the text check, so they are 404 before a query.)

- [ ] Edit `app/helpers/decks_helper.rb`: add after `deck_sub_line`:

```ruby

  # "12 cards · 12 owned": a zone's counts and the tail of the page head. Cards and owned are one number until proxies exist
  # (spec 066 decision 4).
  #
  # @param owned [Integer] the copies counted
  # @return [String]
  def deck_counts_line(owned) = "#{pluralize(number_with_delimiter(owned), "card")} · #{number_with_delimiter(owned)} owned"

  # The deck page's muted head line: the format's name (its key when no longer registered), then the counts of every zone.
  #
  # @param page [Deck::Page]
  # @return [String]
  def deck_page_line(page) = "#{page.deck.format_name} · #{deck_counts_line(page.owned)}"

  # "S1 · 52" under a card's name, with " · DE" after the number for a printing whose language is not English (spec 066 AC-2.5).
  #
  # @param entry [Catalog::Entry] with its set loaded
  # @return [String]
  def deck_set_line(entry) = entry.language == "en" ? set_number(entry) : "#{set_number(entry)} · #{entry.language.upcase}"
```

- [ ] Create `app/views/decks/show.html.erb`:

```erb
<% content_for :title, "#{@deck.name} · Collector" %>
<%= render "layouts/appbar", section: :decks, detail: true, back_path: decks_path %>
<main class="c-main c-page">
  <div class="c-item__head">
    <div>
      <h1 class="c-item__title"><%= @deck.name %></h1>
      <p class="c-item__type"><%= deck_page_line(@page) %></p>
    </div>
    <div class="c-item__actions">
      <%= link_to "Edit deck", edit_deck_path(@deck), class: "c-btn c-btn--secondary" %>
      <details class="c-menu" data-controller="menu">
        <summary class="c-btn c-btn--secondary c-btn--icon" aria-label="More actions"><%= render "icons/more" %></summary>
        <div class="c-menu__list">
          <%= link_to "Change format", edit_deck_format_path(@deck), class: "c-menu__item" %>
          <div class="c-menu__sep"></div>
          <%= link_to "Remove deck", new_deck_removal_path(@deck), class: "c-menu__item c-menu__item--danger" %>
        </div>
      </details>
    </div>
  </div>
  <div class="c-deck">
    <div class="c-deck__zones">
      <%= render partial: "decks/zone", collection: @page.zones, as: :zone %>
    </div>
  </div>
</main>
<%= render "layouts/tabbar", section: :decks %>
```

- [ ] Create `app/views/decks/_zone.html.erb`:

```erb
<section class="c-zone">
  <div class="c-section__head">
    <h2 class="c-section__title" id="zone-<%= zone.id %>"><%= zone.name %></h2>
    <span class="c-section__count"><%= deck_counts_line(zone.owned) %></span>
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
          </tr>
        </thead>
        <% zone.groups.each do |group| %>
          <tbody>
            <% if group.name %>
              <tr class="c-zone__group"><th scope="rowgroup" colspan="5"><%= group.name %><span class="c-zone__groupcount"><%= number_with_delimiter(group.owned) %></span></th></tr>
            <% end %>
            <%= render partial: "decks/card_row", collection: group.rows, as: :row %>
          </tbody>
        <% end %>
      </table>
    </div>
  <% end %>
</section>
```

- [ ] Create `app/views/decks/_card_row.html.erb`:

```erb
<% entry = row.entry %>
<% marker = row.answer.legality %>
<tr>
  <td>
    <div class="c-table__item"><div>
      <%= link_to entry.display_name, catalog_entry_path(entry, from: "collection", anchor: "copies") %>
      <% if marker %><span class="is-opt"> <%= render "decks/legality_marker", word: marker %></span><% end %>
      <span class="is-opt"><br><span class="c-zone__set"><%= deck_set_line(entry) %></span></span>
      <span class="c-table__sub"><span class="c-zone__set"><%= deck_set_line(entry) %></span><% if marker %> <%= render "decks/legality_marker", word: marker %><% end %></span>
    </div></div>
  </td>
  <td><%= row.answer.costed ? render_catalog_extension(entry, :deck_cost) : tag.span("–", class: "is-muted") %></td>
  <td class="is-num is-opt"><%= number_with_delimiter(row.owned) %></td>
  <td class="is-num is-opt"><span class="is-muted">–</span></td>
  <td class="is-num"><%= number_with_delimiter(row.owned) %></td>
</tr>
```

- [ ] Create `app/views/decks/_legality_marker.html.erb`:

```erb
<span class="c-legal c-legal--no"><%= render "icons/cross" %><%= word %></span>
```

- [ ] Run: `bin/rspec spec/requests/deck_pages_spec.rb spec/requests/query_counts_spec.rb` — expect PASS. Run `bin/rspec spec/requests/decks_spec.rb spec/requests/deck_formats_spec.rb` — expect PASS (the guard in `set_deck` must not change the existing deck routes' answers).
- [ ] Commit: `feat(decks): add the deck page, owned cards by zone`

---

## Phase 3: The Decks page links to it

**Implements:** FR-4 | **Satisfies:** AC-1.5
**Files:** `app/views/decks/index.html.erb`, `spec/requests/decks_spec.rb`
**Interfaces:** Consumes: `deck_path`. Produces: the name link on each Decks row.

### T6: the name is a link

- [ ] Edit `spec/requests/decks_spec.rb` line 29 (the comment-bearing expectation) from `expect(html.css(".c-decks tbody td:first-child a")).to be_empty # a name is plain text until the deck page (#253)` to:

```ruby
        expect(html.css(".c-decks tbody td:first-child .c-table__item > div > span:first-child a").map { it["href"] }).to eq(
          Deck.listing_order.map { deck_path(it) }
        ) # spec 066 AC-1.5: each name links to its page
```

and add an example after the "gives each row Rename and Remove links" example:

```ruby
      it "links each deck's name to its page and keeps the row's three buttons and narrow line (spec 066 AC-1.5)", :aggregate_failures do
        deck = create(:deck, account:, name: "Izzet Tempo")

        get decks_path

        link = html.at_css(".c-decks tbody td:first-child a")
        expect([ link.text, link["href"] ]).to eq([ "Izzet Tempo", deck_path(deck) ])
        expect(html.css(".c-decks tbody .c-decks__actions a").size).to eq(3)
        expect(html.at_css(".c-decks .c-table__sub").text).to eq("Modern · 0 owned")
      end
```

- [ ] Run: `bin/rspec spec/requests/decks_spec.rb` — expect FAIL on the two examples.
- [ ] Edit `app/views/decks/index.html.erb`: replace `<span><%= deck.name %></span>` with `<span><%= link_to deck.name, deck_path(deck) %></span>`.
- [ ] Run: `bin/rspec spec/requests/decks_spec.rb spec/system/decks_spec.rb` — expect PASS (the system example's `find(".c-decks td:first-child .c-table__item span", text: long_name)` still finds the span).
- [ ] Commit: `feat(decks): link each deck's name on the Decks page to its page`

---

## Phase 4: The core guard

**Implements:** FR-3 (Must not), Story 6 | **Satisfies:** AC-6.2
**Files:** `spec/deck_core_spec.rb`
**Interfaces:** Consumes: the new files. Produces: the guard covering `app/models/catalog/deck_cards.rb` and the count 32.

### T7: list the new core files

`app/models/deck/page.rb`, `app/views/decks/show.html.erb`, `_zone.html.erb`, `_card_row.html.erb` and `_legality_marker.html.erb` match the existing globs; `app/models/catalog/deck_cards.rb` does not. Today's count is 26, so the guard's count is **32** (6 new files). The other worker may add files to the same list: when merging `main`, sum both changes and keep both rows.

- [ ] Edit `spec/deck_core_spec.rb`: change the example to `expect(files.size).to eq(20 + 6 + 6) # spec 066 adds the page model, its seam, the show view and three partials` and add `app/models/catalog/deck_cards.rb` to the first line of `patterns` after `app/models/catalog/formats.rb`:

```ruby
    app/models/deck.rb app/models/deck/*.rb app/models/location/placement.rb app/models/catalog/formats.rb app/models/catalog/deck_cards.rb
```

- [ ] Run: `bin/rspec spec/deck_core_spec.rb` — expect PASS (a count that differs from 32 means a file is missing from a glob or an extra one matched: find which with `git ls-files`, do not just change the number).
- [ ] Run: `bin/rspec spec/deck_core_spec.rb spec/requests/deck_pages_spec.rb` — expect PASS; a failure in the guard's third example names a file with a banned word (a comment's "modern" or "standard"): reword the comment.
- [ ] Commit: `test(decks): cover the deck page's core files in the core guard`

---

## Phase 5: Layout at every width, in both themes

**Implements:** Story 5 | **Satisfies:** AC-5.1, AC-5.2, AC-5.3, AC-5.4, AC-5.5, AC-5.6
**Files:** `spec/system/deck_page_spec.rb`; `app/assets/stylesheets/collector/additions.css` only if an example fails
**Interfaces:** Consumes: `open_in_narrow_frame`, `within_narrow_frame`, `system_sign_in_as`, `create_lot_in_zone`. Produces: the system proof of the layout.

### T8: system examples

The existing zone CSS (spec 060) is written for exactly this table; the plan expects these to pass without a CSS change. If one fails, the fix goes in `additions.css` with the failing measurement in the commit body, and `DeckPage.md` is updated in T9 to match.

- [ ] Write `spec/system/deck_page_spec.rb`:

```ruby
require "rails_helper"

# Spec 066 Story 5: the deck page at 360, 640, 768 and 1280px in both themes, in headless Firefox. Phone widths use the narrow
# frame (a window can't go below 500px), whose page is a same-origin iframe.
RSpec.describe "Deck page", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:long_name) { "W" * 60 }

  def printing(name:, type_line: "Creature", cost: "{2}{W}{U}{B}{R}{G}", legalities: { "modern" => "banned" }, **attrs)
    entry = create(:catalog_entry, name:, **attrs)
    create(:mtg_printing, entry:, legalities:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    entry
  end

  # The worst case (a 60-character name with no space, a six-symbol cost, a marker, a three-digit quantity), a short row, a land,
  # and cards in Sideboard and Considering so three zone tables differ in content.
  before do
    create_lot_in_zone(deck, "main", entry: printing(name: long_name), quantity: 123)
    create_lot_in_zone(deck, "main", entry: printing(name: "Lightning Bolt", type_line: "Instant", cost: "{R}", legalities: { "modern" => "legal" }), quantity: 4)
    create_lot_in_zone(deck, "main", entry: printing(name: "Island", type_line: "Basic Land — Island", cost: "", legalities: { "modern" => "legal" }), quantity: 20)
    create_lot_in_zone(deck, "sideboard", entry: printing(name: "Spell Pierce", type_line: "Instant", cost: "{U}", legalities: { "modern" => "not_legal" }), quantity: 2)
    create_lot_in_zone(deck, "considering", entry: printing(name: "Force of Will", type_line: "Instant", cost: "{3}{U}{U}", legalities: { "modern" => "legal" }), quantity: 1)
  end

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  def shown_headers
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".c-zone thead th")].filter((th) => th.getClientRects().length > 0).slice(0, 5).map((th) => th.textContent.trim())
    JS
  end

  # The left edge and width of each column's header in each zone table.
  def column_boxes
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".c-zone table")].map((table) =>
        [...table.querySelectorAll("thead th")].map((th) => { const box = th.getBoundingClientRect(); return [Math.round(box.left * 10) / 10, Math.round(box.width * 10) / 10] }))
    JS
  end

  [ 360, 640, 768 ].each do |width|
    %w[light dark].each do |theme|
      it "has no horizontal overflow at #{width}px in the #{theme} theme and keeps a six-symbol cost inside its cell (AC-5.4, AC-5.5)", :aggregate_failures do
        open_in_narrow_frame(deck_path(deck), width:, ready: ".c-zone table")
        within_narrow_frame do
          set_theme(theme)
          expect(fits?).to be(true)
          worst = page.evaluate_script(<<~JS)
            (() => { const cost = [...document.querySelectorAll(".c-zone td:nth-child(2)")].find((td) => td.querySelectorAll(".c-mana").length === 6)
              return [cost.scrollWidth, cost.clientWidth] })()
          JS
          expect(worst.first).to be <= worst.last
        end
      end
    end
  end

  it "shows Card, Cost and Total under 640px, with the set and the marker under the name and Owned hidden (AC-5.3)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 360, ready: ".c-zone table")
    within_narrow_frame do
      expect(shown_headers.first(3)).to eq([ "Card", "Cost", "Total" ])
      visible = page.evaluate_script(<<~JS)
        (() => { const row = [...document.querySelectorAll(".c-zone tbody tr")].find((tr) => tr.textContent.includes("W".repeat(60)))
          const shown = (el) => el.getClientRects().length > 0
          return { sub: shown(row.querySelector(".c-table__sub .c-legal")), beside: shown(row.querySelector(".is-opt .c-legal")) } })()
      JS
      expect(visible).to eq({ "sub" => true, "beside" => false })
    end
  end

  it "shows the marker once beside the name from 640px and not under it, and all five columns (AC-3.6, AC-5.2)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 1280, ready: ".c-zone table")
    within_narrow_frame do
      expect(shown_headers).to eq([ "Card", "Cost", "Owned", "Proxy", "Total" ])
      visible = page.evaluate_script(<<~JS)
        (() => { const row = [...document.querySelectorAll(".c-zone tbody tr")].find((tr) => tr.textContent.includes("W".repeat(60)))
          const shown = (el) => el.getClientRects().length > 0
          return { sub: shown(row.querySelector(".c-table__sub .c-legal")), beside: shown(row.querySelector(".is-opt .c-legal")) } })()
      JS
      expect(visible).to eq({ "sub" => false, "beside" => true })
    end
  end

  it "gives Cost, Owned, Proxy and Total one left edge and width in every zone table from 640px (AC-5.2)", :aggregate_failures do
    visit deck_path(deck)
    page.driver.browser.manage.window.resize_to(1280, 900)
    expect(page).to have_css(".c-zone table", count: 3)

    boxes = column_boxes

    (1..4).each { |column| expect(boxes.map { it[column] }.uniq.size).to eq(1), "column #{column} differs between zone tables: #{boxes.map { it[column] }}" }
  end

  it "leaves the second column empty from 992px: the zones keep the first column and nothing sits in the second (AC-5.1)", :aggregate_failures do
    visit deck_path(deck)
    page.driver.browser.manage.window.resize_to(1280, 900)
    expect(page).to have_css(".c-deck__zones")

    layout = page.evaluate_script(<<~JS)
      (() => { const grid = getComputedStyle(document.querySelector(".c-deck")); const zones = document.querySelector(".c-deck__zones").getBoundingClientRect()
        return { columns: grid.gridTemplateColumns.split(" ").length, children: document.querySelector(".c-deck").children.length, zonesWidth: zones.width, gridWidth: document.querySelector(".c-deck").getBoundingClientRect().width } })()
    JS
    expect(layout["children"]).to eq(1)
    expect(layout["columns"]).to eq(2)
    expect(layout["zonesWidth"]).to be < layout["gridWidth"]
  end

  it "keeps the marker in the muted ink in both themes, never red (AC-3.1, AC-5.5)", :aggregate_failures do
    visit deck_path(deck)
    %w[light dark].each do |theme|
      set_theme(theme)
      colours = page.evaluate_script(<<~JS)
        (() => { const probe = document.createElement("span"); probe.style.color = "var(--ink-muted)"; document.body.append(probe)
          const muted = getComputedStyle(probe).color; probe.remove()
          return [getComputedStyle(document.querySelector(".c-legal")).color, muted] })()
      JS
      expect(colours.first).to eq(colours.last), "#{theme}: the marker is #{colours.first}, the muted ink #{colours.last}"
    end
  end

  it "wraps the head's actions below the name at 360px and keeps them 36px high or more (AC-5.6)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 360, ready: ".c-item__head")
    within_narrow_frame do
      boxes = page.evaluate_script(<<~JS)
        (() => { const rect = (el) => el.getBoundingClientRect()
          return { title: rect(document.querySelector(".c-item__title")).bottom, actions: rect(document.querySelector(".c-item__actions")).top,
                   heights: [...document.querySelectorAll(".c-item__actions .c-btn")].map((el) => rect(el).height) } })()
      JS
      expect(boxes["actions"]).to be >= boxes["title"]
      expect(boxes["heights"]).to all(be >= 36) # the 44px floor is the design system's coarse-pointer rule; a fine-pointer run measures 36px
    end
  end
end
```

- [ ] Run: `bin/rspec spec/system/deck_page_spec.rb` — expect PASS for all (the views and CSS exist). If an example fails: read the measurement it prints; make the smallest rule in `additions.css`, using only tokens, commented with the measurement; re-run; mention it in the commit body. A failing AC-5.2 or AC-5.3 means the removal of the menu column changed a width that spec 060's rules assumed: check the `.c-zone__c-menu` rule and the Card column's remaining width (192px at a 640px container).
- [ ] Run: `bin/rspec spec/system/deck_page_spec.rb spec/system/decks_spec.rb spec/system/design_system_deck_components_spec.rb spec/system/design_system_deck_rules_spec.rb` — expect PASS.
- [ ] Commit: `test(decks): measure the deck page at every width in both themes`

> Flag for the reviewers: AC-5.6 says each touch target is at least 44px. The design system gives 44px only to `pointer: coarse` (`components.css`); a fine-pointer Firefox measures the buttons' own height (36px). The system example asserts 36px, as `spec/system/decks_spec.rb` does for New deck, and `verification.md` records that the coarse rule supplies 44px, as for every page. Spec 066's wording is not changed.

---

## Phase 6: Documentation (the supervisor writes it)

**Implements:** the Design system and documentation NFR | **Satisfies:** the document criteria, verified by reading and recorded in `verification.md`
**Files:** `docs/design-system/components/DeckPage.md`, `DecksIndex.md`, `docs/architecture/collection-and-lots.md`, `docs/architecture/tenancy-and-accounts.md`, `CLAUDE.md`, `docs/specs/README.md`, `docs/specs/066-deck-page-owned-cards-by-zone/verification.md`
**Interfaces:** Consumes: the finished code. Produces: the area docs' statements with their sources.

### T9: documents

Each in its own commit; each statement carries its source (spec 066 decision or AC) inline.

- [ ] `DeckPage.md`: after the Markup section's intro add "**As built (spec 066, until #254):** the page head's line is `Format · N cards · N owned`; a zone's head is its name and `N cards · N owned`, with no 'Add a proxy'; the table has Card, Cost, Owned, Proxy and Total and no menu column; every Proxy cell is the muted dash and Total equals Owned; the card name links to the card's copies; neither panel copy is rendered. #254 adds the proxy counts, the Proxy and Total content, 'Add a proxy' and the menu column." Reword the row-menu paragraph's lead to "From #254" and keep its content; leave the sample markup, which is the full page.
- [ ] `DecksIndex.md`: the deck's name is a link to the deck page (spec 066 decision 1, AC-1.5); keep the rest.
- [ ] `collection-and-lots.md`: in the Decks section add the deck page (route, `Deck::Page`, one row per printing, the sum rule, the order, the head and zone counts, the card link, the 5-statement bound) and the seam `Catalog::DeckCards` with a pointer to its comment as the contract (`@see` style: "the contract is in `Catalog::DeckCards`' comment"); MTG's answer (`MTG::DeckGroups`, `MTG::Collecting.deck_card`, the `deck_cost` partial, the Land-unless-Creature rule); replace the open note that `Deck#zones` is ordered by id with "the deck page lists zones in the format's order (spec 066 decision 3); `Deck#zones` stays by id"; replace the statement that the deck's name is plain text until #253; add spec 066 to Sources and the named constants `MTG::DeckGroups::NAMES`, `MTG::Collecting::LEGALITY_FORMATS`.
- [ ] `tenancy-and-accounts.md`: add `GET /decks/:id` to the routes that find a deck by its location id through the account, 404 for another account's deck, a place's id, a zone's id and a malformed id (spec 066 AC-1.2); add spec 066 to its Sources and distillation log lines as the area doc's convention requires.
- [ ] `CLAUDE.md`: in the Collection-and-lots bullet's deck sentence add "a collector opens a deck at `/decks/:id` to read its owned cards by zone (`Deck::Page`, `Catalog::DeckCards`, spec 066)" and in the first paragraph's decks sentence the same; add spec 066 to the bullet's spec list; the deck files' guard sentence mentions `Catalog::DeckCards`.
- [ ] `docs/specs/README.md`: the 066 row's plan cell links `plan.md`; Status stays Approved until implementation review records and the distillation step changes it.
- [ ] `verification.md`: the AC to proof table (below), the system examples' results at 360/640/768/1280px in both themes, the statement count, the screenshots at 360px and 1280px light and dark (headless Firefox per the PR-screenshots note, kept in `screenshots/`), the AC-5.6 note, and the `## Implementation review` heading with the Mode B verdict on its first line.

---

## Phase 7: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run the touched specs together: `bin/rspec spec/models spec/requests/deck_pages_spec.rb spec/requests/decks_spec.rb spec/requests/query_counts_spec.rb spec/deck_core_spec.rb spec/system/deck_page_spec.rb spec/system/decks_spec.rb` — expect PASS.
- [ ] Ask the coordinator for a CI slot, then run `bin/ci` once; expect green (RuboCop, YARD, the comment ratchet, Brakeman, the whole suite). Send "slot released" with the SHA and result.
- [ ] Verify the document criteria by reading; record in `verification.md`.
- [ ] Mode B implementation review (read-only, Opus), recorded under `## Implementation review`.
- [ ] Commit: `docs(specs): record the verification and implementation review of spec 066`

### AC to proof

| AC | Proved by |
|----|-----------|
| 1.1, 1.3, 1.4, 1.6 | `spec/requests/deck_pages_spec.rb` "the page and its head" |
| 1.2 | `deck_pages_spec` "tenancy" (another account, place, zone, 0, letters, an id nothing has, signed out) |
| 1.5 | `spec/requests/decks_spec.rb` (the link examples) |
| 2.1, 2.2, 2.3, 2.5, 2.6, 2.7, 2.8, 2.9 | `deck_pages_spec` "zones" and `spec/models/deck/page_spec.rb` |
| 2.4 | `page_spec` and `deck_pages_spec` (finishes summed, printings split, other zone, place, account) |
| 2.10 | `page_spec` "statements" (5) and `query_counts_spec` (whole request) |
| 3.1 to 3.6 | `deck_pages_spec` "the legality marker", `collecting_deck_card_spec` |
| 3.7 | `deck_pages_spec` (WebMock blocks the network) |
| 4.1, 4.2 | `deck_pages_spec` "copies are not added or moved here" |
| 5.1 to 5.6 | `spec/system/deck_page_spec.rb` (5.6 at 36px fine pointer, see the flag) |
| 5.7 | `deck_pages_spec` "puts each group in its own tbody" |
| 6.1, 6.6 | `deck_cards_spec`, `deck_pages_spec` "a collectible that answers nothing" |
| 6.2 | `spec/deck_core_spec.rb` |
| 6.3 | `deck_groups_spec`, `collecting_deck_card_spec` |
| 6.4 | `deck_pages_spec` "cost" |
| 6.5 | `collecting_deck_card_spec` |

## Quickstart Validation

1. `bin/setup --skip-server`, then `bin/dev`; sign in; open Decks, make "Izzet Tempo" (Modern), add a few cards to Main from a card page's Add a copy (Location: Izzet Tempo › Main), one banned in Modern, one land, one in Sideboard.
2. Open Decks, follow the deck's name: the page shows "Modern · N cards · N owned", Main, Sideboard and Considering sections, groups by type with their counts, a Cost cell of pips or a dash, a Proxy dash and Total equal to Owned, and a marker on the banned card.
3. Follow a card's name: the card page opens at "Your copies" in the collection's context.
4. Narrow the window below 640px (or a phone): Owned and Proxy hide, the set line and the marker move under the name, no sideways scroll; toggle the theme.
5. `GET /decks/<another account's deck id>` answers 404.
