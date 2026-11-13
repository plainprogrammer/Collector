# Implementation Plan: Deck Checks (spec 079, issue #258)

**Spec:** `docs/specs/079-deck-checks/spec.md` (Approved v0.2.1) · **Issue:** #258 · **Branch:** `079-deck-checks` · **Created:** 2026-11-12
**Approved 2026-11-12** (the maintainer); plan review by Opus (read-only) 2026-11-12: APPROVE WITH CHANGES, applied. Retired by `distill-feature` after the merge (spec 027).

## Context

A collector can't tell whether a deck meets its format's rules. Spec 079 adds a **Check deck** link to the deck page; following it shows, on that page, the deck's size and copy-limit results and every card that has owned copies and proxies in one zone. The result is computed on request (a GET), never stored, and never blocks an edit. A game's rules live behind the collecting vocabulary (a third optional seam answer, `deck_rules`), so the core names no collectible, format or zone key (`spec/deck_core_spec.rb`). Owned-plus-proxy is a core check and runs for every deck.

## Global Constraints

- **Repo rules:** `CLAUDE.md`, `.claude/rules/*.md`. Specs tag their type (`type: :model|:request|:system`); `RSpec/ExampleLength` max 15 lines; `RSpec/MultipleMemoizedHelpers` max 5 (use `def`, not `let`); multi-expectation examples use `:aggregate_failures`; a multi-case AC is one example per case in an `:aggregate_failures` group (spec 079, Interactions).
- **Core files name nothing.** `spec/deck_core_spec.rb` reads whole files, comments included, with `/mtg|scryfall|magic/i` anywhere and `/(?<![a-z])(casual|standard|pioneer|modern|legacy|vintage|pauper|commander|sideboard)(?![a-z])/i`. In `app/models/catalog/deck_checks.rb`, `decks/checks_controller.rb` and the views, never write those words, **not even as the English word "standard" or "modern"** (say "ordinary", "usual"). Review `main` by eye.
- **One commit per task, test first** (red, implement, green, RuboCop). Conventional Commits with `(#258)`; the trailer is the attribution reminder in force at commit time. One git operation per shell call; `git add` and `git commit` in separate calls (the pre-commit hook reads the command text). Every `git grep` ends with `':!.kamal/secrets'`. Never read `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`.
- **The guard stays green at every commit.** The hand-counted total in `spec/deck_core_spec.rb:39` (today `20 + 6 + 1 + 1 + 4 + 1 + 15 + 2 + 6 + 5 + 1 + 3` = 65) rises **in the commit that adds a covered file**: `app/models/catalog/deck_checks.rb` (a new pattern, +1, T1.1), `app/controllers/decks/checks_controller.rb` and `app/views/decks/_check.html.erb` (both covered by globs, +2, T3.1). Append a clause to the trailing comment each time.
- **Comments:** every public class, module and method gets a summary (comment ratchet in `bin/ci checks`) with `@param`/`@return`; no `{…}` outside YARD links; `@see file:collection-and-lots.md`; private helpers are `@api private` + `private_class_method`. `Catalog::DeckChecks`' comment is the one place the extension contract is written.
- **Zero extra statements.** The check reads only what `Deck::Page#zones` loaded (entries with `extension`, `catalog_identity_id`, `name`, `collectible_type`). Nothing queries per row.
- **No migration, no export/import/backup change, export format stays 4.** No gem, no JS toolchain. `spec/support/runtime_log.txt` is not refreshed (new spec files take the average).
- **UI:** use the `collector-design-system` skill and read `docs/design-system/README.md` before touching a view or CSS; tokens and `c-*` only; a new pattern goes in `collector/additions.css` with a component doc; `DeckPage.md` is updated.
- **Existing examples this feature changes (grep):** `spec/system/deck_page_spec.rb:259` (`"buttons" => [ true, true ]` becomes three; `:249` and `:258` need no edit) and `:264-273` (heights ≥ 36 now also cover the new link). `spec/requests/deck_pages_spec.rb:64-74` is scoped to the Edit link and stays.
- **Fixtures that can fail:** each counting AC has a fixture whose wrong answer differs from the right one. The statement-count example and each narrow-width assertion are broken once on purpose (mutation proofs, recorded in `verification.md`).

## Goal

Press **Check deck** on any deck page and see, between the head and the zones, a "Deck check" section: a summary ("3 findings", "1 finding", "No findings") and, in order, one result per size rule, the copy check and owned-plus-proxy. A deck whose format has no rules gets the no-rules line, then owned-plus-proxy.

## Pre-implementation gates

- **Simplicity (≤3 components): pass.** (1) `Catalog::DeckChecks` (core seam, counting, words), (2) `MTG::DeckRules` + `MTG::Collecting.deck_rules` (Magic's table and limits), (3) `Decks::ChecksController` + `decks/_check` + one CSS block. No gem, model or table.
- **Anti-abstraction: pass.** The `Data.define` types are the contract itself, not wrappers; the controller renders the existing `decks/show` with one more ivar. The three lines that build `Deck::Page` and the shape answer are repeated in the controller, not extracted (two callers).
- **Integration-first: pass.** The seam's types and contract comment, with their specs, are Phase 1, before Magic, the controller or the view.
- **Complexity note (T4.1):** a new design-system pattern (`DeckCheck`) is needed. No class gives a wrapping status-word + sentence row: `c-badge` is nowrap and limited to two words ("Over the limit" and "Owned and proxy" are three), `c-list li` doesn't wrap, and the deck page has no block between head and `c-deck`. Documented as an addition per `CLAUDE.md`.

## Files

| File | Change | Responsibility |
|---|---|---|
| `app/models/catalog/deck_checks.rb` | create | core seam: types, `report`, the three checks, words, the contract comment |
| `app/models/mtg/deck_rules.rb` | create | Magic's rules table and each printing's limit |
| `app/models/mtg/collecting.rb` | edit | `deck_rules(format_key)` delegating to `MTG::DeckRules` |
| `config/routes.rb` | edit | `resource :check, only: :show, module: :decks` |
| `app/controllers/decks/checks_controller.rb` | create | GET: build page, shape and report; render `decks/show` |
| `app/views/decks/show.html.erb`, `_check.html.erb` | edit, create | the link, the no-cache tag, the results section |
| `app/assets/stylesheets/collector/additions.css` | edit | the `c-check` block |
| `docs/design-system/components/DeckCheck.md`, `DeckPage.md`, `docs/design-system/README.md` | create, edit | the pattern's document; the page's head link and section; the additions line |
| `spec/deck_core_spec.rb`, `spec/system/deck_page_spec.rb` | edit | guard list and count; the head's three buttons |
| `spec/models/catalog/deck_checks_spec.rb`, `spec/models/mtg/deck_rules_spec.rb`, `spec/models/mtg/deck_checks_for_magic_spec.rb`, `spec/requests/deck_checks_spec.rb`, `spec/system/deck_checks_spec.rb` | create | the proofs |
| `docs/architecture/collection-and-lots.md`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md`, `docs/specs/079-deck-checks/verification.md` | edit, create | Story 7 |

## Phase 0: Preflight (no code)

**Implements:** execution preamble · **Satisfies:** supports AC-3.4, 3.5, 3.12, 3.13

- [ ] **T0.1** `git switch -c 079-deck-checks` from `main` (uncommitted spec, plan and index row travel with it), then one commit: `docs(decks): spec and plan for deck checks (#258)`.
- [ ] **T0.2 Confirm the unverified Scryfall facts**, once, with `curl` (`User-Agent: Collector-dev` and `Accept: application/json` as `.claude/rules/external-data-and-portability.md` asks, 100 ms between calls, no private data): `https://api.scryfall.com/cards/named?exact=Relentless+Rats`, `…exact=Seven+Dwarves`, `…exact=Nazg%C3%BBl` and `https://api.scryfall.com/cards/search?q=%21%22Lightning+Bolt%22+lang%3Aja&unique=prints`. Check the `oracle_text` wording ("A deck can have any number of cards named …", "… up to seven cards named …", "… up to nine …") and that `name` is English while `printed_name` is Japanese. Quote the lines in `verification.md` ("Scryfall facts"). **If a wording differs, update `MTG::DeckRules::ANY_NUMBER` / `STATED_NUMBER` and the T2.1 fixtures before T2.1; if `name` isn't English for a non-English printing, stop and raise it (spec decision 6).**

## Phase 1: The core seam (contracts first)

**Implements:** FR-1, FR-2; decisions 1, 2, 4, 5, 6, 10 · **Satisfies:** AC-1.7, 2.1–2.6, 2.9–2.13 (words and counts), 3.1–3.3, 3.5, 3.6, 3.8–3.11, 3.13, 3.15 (core), 4.1–4.10, 5.4, 5.5
**Files:** `app/models/catalog/deck_checks.rb`, `spec/models/catalog/deck_checks_spec.rb`, `spec/deck_core_spec.rb`
**Interfaces:** Produces `Catalog::DeckChecks.report(deck_type, format_key, zones) → Report`; `SizeRule(zone_keys, min, max)`, `Limit(count, reason)`, `CopyRule(zone_keys, limit_for)`, `Rules(sizes, copies)`, `Line(status, sentence, fault)`, `Report(lines)` with `#faults` and `#summary`. Consumes `Deck::Page::Zone/Group/Row/Line`, `Catalog::Formats.name_for/zones_for`, `Catalog.collecting`.

A fake vocabulary stands in for the game, so these examples prove the core with no Magic in them. Top of `spec/models/catalog/deck_checks_spec.rb` (shared helpers, defined once and used by every task below):

```ruby
require "rails_helper"

RSpec.describe Catalog::DeckChecks, type: :model do
  def zone(key, name, *rows)
    location = Struct.new(:zone, :name).new(key, name)
    Deck::Page::Zone.new(location:, groups: rows.empty? ? [] : [ Deck::Page::Group.new(name: nil, rows:) ])
  end

  def card(name, id, type: "game")
    build_stubbed(:catalog_entry, identity: build_stubbed(:catalog_identity, id:, name:), name:, collectible_type: type)
  end

  def row(entry, owned: 0, proxy: 0)
    lines = proxy.zero? ? [] : [ Deck::Page::Line.new(id: 1, finish: "nonfoil", quantity: proxy) ]
    Deck::Page::Row.new(entry:, owned:, lines:, answer: Catalog::DeckCards::NONE)
  end

  def size(keys, min: nil, max: nil) = Catalog::DeckChecks::SizeRule.new(zone_keys: keys, min:, max:)
  def limit(count, reason = nil) = ->(_entry) { Catalog::DeckChecks::Limit.new(count:, reason:) }
  def copies(keys, limit_for) = Catalog::DeckChecks::CopyRule.new(zone_keys: keys, limit_for:)

  def register(sizes: [], copies: nil)
    rules = Catalog::DeckChecks::Rules.new(sizes:, copies:)
    stub_const("GameVocabulary", Module.new { define_singleton_method(:deck_rules) { |_key| rules } })
    Catalog.collecting["game"] = "GameVocabulary"
  end

  def report(*zones) = described_class.report("game", "tight", zones)
  def lines(report) = report.lines.map { [ it.status, it.sentence ] }

  after { Catalog.collecting.delete("game") }

  # … the describe blocks of T1.1, T1.2 and T1.3 go here …
end
```

### T1.1 Types, contract, the no-rules path and owned plus proxy

- [ ] **Test (red).** Inside the `RSpec.describe`:

```ruby
  describe ".report with no rules" do
    it "says the format has no rules and still runs owned-plus-proxy", :aggregate_failures do
      result = described_class.report("game", "tight", [ zone("main", "Main", row(card("Bolt", 1), owned: 2, proxy: 1)) ])
      expect(lines(result)).to eq([ [ nil, "tight has no rules to check." ], [ "Owned and proxy", "Bolt in Main: 2 owned, 1 proxy." ] ])
      expect([ result.lines.first.fault, result.summary ]).to eq([ false, "1 finding" ])
    end

    it "treats a missing method, a nil answer and an unregistered type alike (AC-5.5)", :aggregate_failures do
      stub_const("SilentVocabulary", Module.new)
      stub_const("NilVocabulary", Module.new { def self.deck_rules(_key) = nil })
      expected = [ [ nil, "tight has no rules to check." ], [ "Pass", "No card has both owned copies and proxies in one zone." ] ]
      %w[SilentVocabulary NilVocabulary].each do |vocabulary|
        Catalog.collecting["game"] = vocabulary
        expect(lines(described_class.report("game", "tight", []))).to eq(expected)
      end
      expect(described_class.report("gone", "tight", []).summary).to eq("No findings")
    end
  end

  describe "owned-plus-proxy results" do
    let(:bolt) { card("Lightning Bolt", 1) }

    it "flags a zone that holds both, across printings, naming the split", :aggregate_failures do
      result = report(zone("main", "Main", row(bolt, owned: 2), row(card("Lightning Bolt", 1), proxy: 1)))
      expect(lines(result)).to include([ "Owned and proxy", "Lightning Bolt in Main: 2 owned, 1 proxy." ])
      expect(result.faults).to eq(1)
    end

    it "judges each zone alone, includes zones no rule names, and skips Considering's lone proxy", :aggregate_failures do
      zones = [ zone("main", "Main", row(bolt, owned: 1), row(bolt, proxy: 1)), zone("stash", "Stash", row(bolt, owned: 2, proxy: 3)),
                zone("considering", "Considering", row(bolt, proxy: 1)) ]
      sentences = lines(report(*zones)).map(&:last)
      expect(sentences).to include("Lightning Bolt in Main: 1 owned, 1 proxy.", "Lightning Bolt in Stash: 2 owned, 3 proxy.")
      expect(sentences).not_to include(a_string_matching(/Considering/))
    end

    it "does not flag owned only, proxy only, owned in one zone with a proxy in another, or another collectible", :aggregate_failures do
      stray = card("Other", 9, type: "stranger")
      zones = [ zone("main", "Main", row(bolt, owned: 2)), zone("considering", "Considering", row(bolt, proxy: 1), row(stray, owned: 1, proxy: 1)) ]
      expect(lines(report(*zones)).last).to eq([ "Pass", "No card has both owned copies and proxies in one zone." ])
    end

    it "delimits the split's numbers as the deck page's heads do", :aggregate_failures do
      result = report(zone("main", "Main", row(bolt, owned: 1_234, proxy: 5_678)))
      expect(lines(result)).to include([ "Owned and proxy", "Lightning Bolt in Main: 1,234 owned, 5,678 proxy." ])
    end

    it "orders findings by zone, then name, then identity", :aggregate_failures do
      zones = [ zone("a", "Alpha", row(card("Zed", 1), owned: 1, proxy: 1), row(card("Abe", 2), owned: 1, proxy: 1)), zone("b", "Beta", row(card("Abe", 2), owned: 1, proxy: 1)) ]
      expect(lines(report(*zones)).map(&:last)).to eq([ "Abe in Alpha: 1 owned, 1 proxy.", "Zed in Alpha: 1 owned, 1 proxy.", "Abe in Beta: 1 owned, 1 proxy." ])
    end
  end
```

  Run `bin/rspec spec/models/catalog/deck_checks_spec.rb` → **FAIL** (`uninitialized constant Catalog::DeckChecks`).

- [ ] **Implement** `app/models/catalog/deck_checks.rb`. The header comment is the extension contract and names no format, zone key or game:

```ruby
# What a deck page's Check deck answers (spec 079): the deck's size and copy limits judged by the collectible's own rules, and
# every card with owned copies and proxies in one zone, which needs no rule and runs for every deck. Like
# `Catalog::DeckShape`, an optional answer on the collecting vocabulary (`Catalog.collecting_for`), so the core counts and
# words the results and never names a collectible, a format or a zone key but `Catalog::Formats::CONSIDERING`.
#
# An extension contract: a vocabulary that has rules for a format provides
# * `deck_rules(format_key)` returning {Rules}, or nil for a format it has no rules for (the deck's stored key, registered or not).
# * `Rules#sizes`: {SizeRule}s in the order they are shown. A rule holds the `zone_keys` it counts (the extension names them;
#   the core matches each to a zone row's key) and one of three shapes: `min` only, `max` only, or `min == max` (an exact
#   size); a range with two different bounds is not offered. The extension supplies no words.
# * `Rules#copies`: a {CopyRule} or nil. Its `zone_keys` are counted together; `limit_for` is called with one counted printing
#   (a `Catalog::Entry` whose `extension` may be nil) and returns a {Limit} (`count`, and a `reason` sentence part such as
#   "restricted to 1", or nil) or nil for a card that is never limited. For a printing with no extension record it returns
#   the format's ordinary limit. It reads loaded records only, never a query.
# The core counts copies by catalog identity over every counted printing and holds a card to the lowest number its printings
# answer; nil is above every number, so a card is unlimited only when every counted printing answers nil, and the reason is
# the one given with the lowest number (the first printing in page order on a tie). A card of another collectible than the
# deck's is left out of every check. Considering and any zone no rule names are counted by no size or copy rule.
# A vocabulary without `deck_rules`, a nil answer, a type no longer registered and a deck whose format is no longer registered
# have no size or copy rules.
# @see file:collection-and-lots.md
module Catalog::DeckChecks
  # One size rule: the zone keys it counts together and a minimum, a maximum, or both equal (an exact size).
  SizeRule = Data.define(:zone_keys, :min, :max)
  # A card's limit: the most copies a deck may hold, and an optional sentence part that says why ("restricted to 1").
  Limit = Data.define(:count, :reason)
  # The copy rule: the zone keys counted together and a callable from a loaded printing to a {Limit} or nil.
  CopyRule = Data.define(:zone_keys, :limit_for)
  # What a vocabulary answers for a format: its size rules and its copy rule (nil for none).
  Rules = Data.define(:sizes, :copies)
  # One line of a report: a status word (nil for a line that is no check), its sentence, and whether it is a finding.
  Line = Data.define(:status, :sentence, :fault)
  # The results of one check request, in the order they are shown.
  Report = Data.define(:lines) do
    # The number of findings.
    def faults = lines.count(&:fault)

    # The summary line: "3 findings", "1 finding" or "No findings".
    def summary = faults.zero? ? "No findings" : "#{faults} #{faults == 1 ? 'finding' : 'findings'}"
  end
  # A row of the deck's collectible with its zone and the zone's position in page order.
  # @api private
  Counted = Data.define(:zone, :position, :row)

  # The report for a deck.
  #
  # @param deck_type [String] the deck's collectible type
  # @param format_key [String] the deck's stored format key, registered or not
  # @param zones [Array<Deck::Page::Zone>] `Deck::Page#zones`; read from memory, no statement runs
  # @return [Report] never nil, and never raises for an unregistered type or format
  def self.report(deck_type, format_key, zones)
    counted = counted_rows(deck_type, zones)
    rules = rules_for(deck_type, format_key)
    lines = rules ? rule_lines(rules, deck_type, format_key, zones, counted) : [ no_rules_line(deck_type, format_key) ]
    Report.new(lines: lines + split_lines(counted))
  end

  # @api private
  def self.rules_for(deck_type, format_key)
    return unless Catalog.collecting.key?(deck_type)

    vocabulary = Catalog.collecting_for(deck_type)
    vocabulary.deck_rules(format_key) if vocabulary.respond_to?(:deck_rules)
  end
  private_class_method :rules_for

  # Every row of the deck's collectible with its zone's position; another collectible's rows are left out (decision 4).
  # @api private
  def self.counted_rows(deck_type, zones)
    zones.each_with_index.flat_map do |zone, position|
      zone.groups.flat_map(&:rows).select { it.entry.collectible_type == deck_type }.map { Counted.new(zone:, position:, row: it) }
    end
  end
  private_class_method :counted_rows

  # @api private
  def self.rule_lines(_rules, _deck_type, _format_key, _zones, _counted) = []
  private_class_method :rule_lines

  # @api private
  def self.no_rules_line(deck_type, format_key)
    Line.new(status: nil, sentence: "#{Catalog::Formats.name_for(deck_type, format_key)} has no rules to check.", fault: false)
  end
  private_class_method :no_rules_line

  # A count with delimiters ("1,234"), as the deck page's heads and spec 069's panel write one.
  # @api private
  def self.delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)
  private_class_method :delimited

  # The owned-plus-proxy check (decision 5): each zone alone, any printing of the card; findings ordered by the zone's
  # position, then the card's name, then its identity; or one pass line.
  # @api private
  def self.split_lines(counted)
    findings = counted.group_by { [ it.position, it.row.entry.catalog_identity_id ] }.filter_map do |(position, identity_id), cards|
      owned = cards.sum { it.row.owned }
      proxy = cards.sum { it.row.proxy }
      next unless owned.positive? && proxy.positive?

      [ position, cards.first.row.entry.name, identity_id, cards.first.zone.name, owned, proxy ]
    end
    return [ Line.new(status: "Pass", sentence: "No card has both owned copies and proxies in one zone.", fault: false) ] if findings.empty?

    findings.sort_by { it.first(3) }.map do |_position, name, _identity_id, zone_name, owned, proxy|
      Line.new(status: "Owned and proxy", sentence: "#{name} in #{zone_name}: #{delimited(owned)} owned, #{delimited(proxy)} proxy.", fault: true)
    end
  end
  private_class_method :split_lines
end
```

- [ ] **Guard.** In `spec/deck_core_spec.rb` add `app/models/catalog/deck_checks.rb` to the `patterns` list beside the other `catalog/*.rb` files and append `+ 1` to the total, with the comment clause `spec 079 adds the seam app/models/catalog/deck_checks.rb (a new pattern)`.
- [ ] Run `bin/rspec spec/models/catalog/deck_checks_spec.rb spec/deck_core_spec.rb` → PASS. `bin/rubocop -a` on both; `bin/yard doc --no-cache` has no warning. Commit `feat(decks): add Catalog::DeckChecks and its owned-plus-proxy check (#258)`.

### T1.2 Size results

- [ ] **Test (red).** Add inside the `RSpec.describe`:

```ruby
  describe "size results" do
    it "judges a minimum with the true count in every sentence", :aggregate_failures do
      register(sizes: [ size(%w[main], min: 60) ])
      bolt = card("Bolt", 1)
      expect(lines(report(zone("main", "Main", row(bolt, owned: 58))))).to include([ "Short", "Main: 58 cards; tight needs at least 60." ])
      expect(lines(report(zone("main", "Main", row(bolt, owned: 59, proxy: 1))))).to include([ "Pass", "Main: 60 cards; tight needs at least 60." ])
      expect(lines(report(zone("main", "Main", row(bolt, owned: 61))))).to include([ "Pass", "Main: 61 cards; tight needs at least 60." ])
    end

    it "names a rule's zones in its key order and a zone the deck lacks by its key", :aggregate_failures do
      register(sizes: [ size(%w[bench], max: 15), size(%w[lead main], min: 100, max: 100) ])
      zones = [ zone("main", "Main", row(card("A", 1), owned: 98)), zone("lead", "Lead", row(card("B", 2), owned: 1)) ]
      expect(lines(report(*zones))).to start_with([ "Pass", "bench: 0 cards; tight allows at most 15." ], [ "Short", "Lead + Main: 99 cards; tight needs exactly 100." ])
    end

    it "says Over past a maximum and past an exact size, and the singular for one card", :aggregate_failures do
      register(sizes: [ size(%w[bench], max: 15), size(%w[main], min: 1, max: 1) ])
      zones = [ zone("bench", "Bench", row(card("A", 1), owned: 16)), zone("main", "Main", row(card("B", 2), owned: 2)) ]
      expect(lines(report(*zones))).to start_with([ "Over", "Bench: 16 cards; tight allows at most 15." ], [ "Over", "Main: 2 cards; tight needs exactly 1." ])
      expect(lines(report(zone("main", "Main", row(card("B", 2), owned: 1))))).to include([ "Pass", "Main: 1 card; tight needs exactly 1." ])
    end

    it "counts nothing in Considering or an unnamed zone, and passes at exactly the exact size", :aggregate_failures do
      register(sizes: [ size(%w[main], min: 100, max: 100) ])
      zones = [ zone("main", "Main", row(card("A", 1), owned: 100)), zone("considering", "Considering", row(card("B", 2), owned: 30)) ]
      expect(lines(report(*zones)).first).to eq([ "Pass", "Main: 100 cards; tight needs exactly 100." ])
    end

    it "separates thousands in a count" do
      register(sizes: [ size(%w[main], min: 60) ])
      expect(lines(report(zone("main", "Main", row(card("A", 1), owned: 1_234)))).first.last).to eq("Main: 1,234 cards; tight needs at least 60.")
    end

    it "leaves out another collectible's cards and zones no rule names", :aggregate_failures do
      register(sizes: [ size(%w[main], min: 1) ])
      zones = [ zone("main", "Main", row(card("Other", 9, type: "stranger"), owned: 5)), zone("stash", "Stash", row(card("A", 1), owned: 7)) ]
      expect(lines(report(*zones)).first).to eq([ "Short", "Main: 0 cards; tight needs at least 1." ])
    end
  end
```

  Run → **FAIL** (the rule lines are empty).

- [ ] **Implement.** Replace the `rule_lines` stub and add the size helpers:

```ruby
  # @api private
  def self.rule_lines(rules, deck_type, format_key, zones, counted)
    rules.sizes.map { size_line(it, deck_type, format_key, zones, counted) }
  end
  private_class_method :rule_lines

  # One size result (decision 6). Zones are named in the rule's key order: by the zone row's shown name, else by the format's
  # registration, else by the key.
  # @api private
  def self.size_line(rule, deck_type, format_key, zones, counted)
    total = counted.select { rule.zone_keys.include?(it.zone.location.zone) }.sum { it.row.total }
    subject = rule.zone_keys.map { zone_name(it, deck_type, format_key, zones) }.join(" + ")
    status = if rule.min && total < rule.min then "Short" elsif rule.max && total > rule.max then "Over" else "Pass" end
    format_name = Catalog::Formats.name_for(deck_type, format_key)
    Line.new(status:, sentence: "#{subject}: #{counted_words(total, 'card')}; #{format_name} #{size_need(rule)}.", fault: status != "Pass")
  end
  private_class_method :size_line

  # The rule's requirement in words: "needs at least 60", "allows at most 15" or "needs exactly 100".
  # @api private
  def self.size_need(rule)
    return "needs exactly #{delimited(rule.min)}" if rule.min && rule.min == rule.max
    return "needs at least #{delimited(rule.min)}" if rule.min

    "allows at most #{delimited(rule.max)}"
  end
  private_class_method :size_need

  # @api private
  def self.zone_name(key, deck_type, format_key, zones)
    zones.find { it.location.zone == key }&.name || Catalog::Formats.zones_for(deck_type, format_key)&.find { it.key == key }&.name || key
  end
  private_class_method :zone_name

  # "1 card", "5 copies": the count with delimiters and the singular for one.
  # @api private
  def self.counted_words(number, word) = "#{delimited(number)} #{word.pluralize(number)}"
  private_class_method :counted_words
```

- [ ] Run → PASS; rubocop; commit `feat(decks): size results for the deck checks (#258)`.

### T1.3 Copy limits

- [ ] **Test (red).** Add inside the `RSpec.describe`:

```ruby
  describe "copy results" do
    let(:bolt) { card("Lightning Bolt", 1) }

    it "names a card over its limit across zones, printings and owned plus proxy", :aggregate_failures do
      register(copies: copies(%w[main bench], limit(4)))
      zones = [ zone("main", "Main", row(bolt, owned: 3), row(card("Lightning Bolt", 1), proxy: 1)), zone("bench", "Bench", row(bolt, owned: 1)) ]
      expect(lines(report(*zones))).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
    end

    it "passes at the limit and counts no copy in an unnamed zone", :aggregate_failures do
      register(copies: copies(%w[main], limit(4)))
      zones = [ zone("main", "Main", row(bolt, owned: 4)), zone("considering", "Considering", row(bolt, owned: 9)) ]
      expect(lines(report(*zones))).to include([ "Pass", "No card is over its limit." ])
    end

    it "passes at the limit across two named zones (4 of 3 + 1)" do
      register(copies: copies(%w[main bench], limit(4)))
      zones = [ zone("main", "Main", row(bolt, owned: 3)), zone("bench", "Bench", row(bolt, owned: 1)) ]
      expect(lines(report(*zones))).to include([ "Pass", "No card is over its limit." ])
    end

    it "breaks a tie on the lowest limit by the first printing in page order", :aggregate_failures do
      first = card("Black Lotus", 2)
      second = card("Black Lotus", 2)
      answer = ->(entry) { Catalog::DeckChecks::Limit.new(count: 1, reason: entry.equal?(first) ? "restricted to 1" : "banned past 1") }
      register(copies: copies(%w[main], answer))
      expect(lines(report(zone("main", "Main", row(second, owned: 1), row(first, owned: 1))))).to include([ "Over the limit", "Black Lotus: 2 copies; banned past 1." ])
    end

    it "orders two findings of one zone by name, then by identity when the names match", :aggregate_failures do
      register(copies: copies(%w[main], limit(0)))
      zones = [ zone("main", "Main", row(card("Zed", 1), owned: 1), row(card("Abe", 5), owned: 2), row(card("Abe", 2), owned: 1)) ]
      expect(lines(report(*zones)).first(3).map(&:last)).to eq([ "Abe: 1 copy; the limit is 0.", "Abe: 2 copies; the limit is 0.", "Zed: 1 copy; the limit is 0." ])
    end

    it "holds a card to the lowest limit its printings answer, with that reason", :aggregate_failures do
      one = card("Black Lotus", 2)
      two = card("Black Lotus", 2)
      answer = ->(entry) { entry.equal?(one) ? Catalog::DeckChecks::Limit.new(count: 4, reason: nil) : Catalog::DeckChecks::Limit.new(count: 1, reason: "restricted to 1") }
      register(copies: copies(%w[main], answer))
      expect(lines(report(zone("main", "Main", row(one, owned: 1), row(two, owned: 1))))).to include([ "Over the limit", "Black Lotus: 2 copies; restricted to 1." ])
    end

    it "treats nil as above every number: unlimited only when every printing says nil", :aggregate_failures do
      free = card("Plains", 3)
      mixed = card("Plains", 3)
      register(copies: copies(%w[main], ->(entry) { Catalog::DeckChecks::Limit.new(count: 4, reason: nil) unless entry.equal?(free) }))
      expect(lines(report(zone("main", "Main", row(free, owned: 20))))).to include([ "Pass", "No card is over its limit." ])
      expect(lines(report(zone("main", "Main", row(free, owned: 3), row(mixed, owned: 2))))).to include([ "Over the limit", "Plains: 5 copies; the limit is 4." ])
    end

    it "orders findings by first zone, then name, then identity; leaves out another collectible", :aggregate_failures do
      register(copies: copies(%w[main bench], limit(1)))
      zones = [ zone("main", "Main", row(card("Zed", 1), owned: 2)), zone("bench", "Bench", row(card("Abe", 2), owned: 2), row(card("Other", 3, type: "stranger"), owned: 9)) ]
      expect(lines(report(*zones)).map(&:last)).to start_with("Zed: 2 copies; the limit is 1.", "Abe: 2 copies; the limit is 1.")
      expect(lines(report(*zones)).map(&:last)).not_to include(a_string_matching(/Other/))
    end

    it "says the singular for one copy" do
      register(copies: copies(%w[main], limit(0)))
      expect(lines(report(zone("main", "Main", row(bolt, owned: 1))))).to include([ "Over the limit", "Lightning Bolt: 1 copy; the limit is 0." ])
    end
  end
```

  Run → **FAIL**.

- [ ] **Implement.** Make `rule_lines` return the sizes plus the copy lines, and add `copy_lines`:

```ruby
  # @api private
  def self.rule_lines(rules, deck_type, format_key, zones, counted)
    sizes = rules.sizes.map { size_line(it, deck_type, format_key, zones, counted) }
    sizes + (rules.copies ? copy_lines(rules.copies, counted) : [])
  end
  private_class_method :rule_lines

  # The copy check (decisions 1, 3, 4): copies by catalog identity over the rule's zones, owned plus proxy; one finding per
  # card over its limit, ordered by the first zone that holds it, then its name, then its identity; or one pass line. A card
  # is held to the lowest number its printings answer; `min_by` keeps the first printing in page order on a tie.
  # @api private
  def self.copy_lines(rule, counted)
    in_rule = counted.select { rule.zone_keys.include?(it.zone.location.zone) }
    findings = in_rule.group_by { it.row.entry.catalog_identity_id }.filter_map do |identity_id, cards|
      copies = cards.sum { it.row.total }
      limit = cards.map { it.row.entry }.uniq.filter_map { rule.limit_for.call(it) }.min_by(&:count)
      next if limit.nil? || copies <= limit.count

      [ cards.map(&:position).min, cards.first.row.entry.name, identity_id, copies, limit ]
    end
    return [ Line.new(status: "Pass", sentence: "No card is over its limit.", fault: false) ] if findings.empty?

    findings.sort_by { it.first(3) }.map do |_position, name, _identity_id, copies, limit|
      Line.new(status: "Over the limit", sentence: "#{name}: #{counted_words(copies, 'copy')}; #{limit.reason || "the limit is #{limit.count}"}.", fault: true)
    end
  end
  private_class_method :copy_lines
```

- [ ] Run the whole file and `spec/deck_core_spec.rb` → PASS; rubocop; `bin/yard doc --no-cache`; commit `feat(decks): copy-limit results for the deck checks (#258)`.

## Phase 2: Magic's rules

**Implements:** decisions 1 and 3 (Magic side), FR-2 · **Satisfies:** AC-2.1–2.4, 2.7, 2.8, 3.1–3.7, 3.12, 3.14, 3.16, 4.5
**Files:** `app/models/mtg/deck_rules.rb`, `app/models/mtg/collecting.rb`, `spec/models/mtg/deck_rules_spec.rb`, `spec/models/mtg/deck_checks_for_magic_spec.rb`
**Interfaces:** Produces `MTG::DeckRules.for(format_key) → Rules | nil`, `MTG::DeckRules.limit_for(entry, format_key, ordinary)`, `MTG::Collecting.deck_rules(format_key)`. Consumes the Phase 1 types and the loaded `MTG::Printing` (`faces[].type_line`, `faces[].oracle_text`, `legalities`).

### T2.1 `MTG::DeckRules` and the vocabulary answer

- [ ] **Test (red)** `spec/models/mtg/deck_rules_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::DeckRules, type: :model do
  def entry(name = "Card", type_line: "Instant", text: nil, legalities: {}, record: true)
    entry = create(:catalog_entry, name:)
    create(:mtg_printing, entry:, legalities:, faces: [ { "name" => name, "type_line" => type_line, "oracle_text" => text, "image_uris" => {} } ]) if record
    Catalog::Entry.preload_extensions([ entry ]).first
  end

  def limit(format, entry) = described_class.for(format).copies.limit_for.call(entry)&.then { [ it.count, it.reason ] }
  def shape(rule) = [ rule.zone_keys, rule.min, rule.max ]

  describe ".for" do
    it "has size and copy rules for each constructed format", :aggregate_failures do
      %w[standard pioneer modern legacy vintage pauper].each do |key|
        rules = described_class.for(key)
        expect(rules.sizes.map { shape(it) }).to eq([ [ %w[main], 60, nil ], [ %w[sideboard], nil, 15 ] ])
        expect(rules.copies.zone_keys).to eq(%w[main sideboard])
      end
    end

    it "has Commander's exact size, a singleton copy rule, and none for casual or an unknown key", :aggregate_failures do
      commander = described_class.for("commander")
      expect(commander.sizes.map { shape(it) }).to eq([ [ %w[commander main], 100, 100 ] ])
      expect(commander.copies.zone_keys).to eq(%w[commander main])
      expect([ described_class.for("casual"), described_class.for("retired"), MTG::Collecting.deck_rules("casual") ]).to all(be_nil)
    end
  end

  describe "a card's limit" do
    it "is 4 in constructed formats and 1 in Commander", :aggregate_failures do
      bolt = entry("Lightning Bolt")
      expect([ limit("standard", bolt), limit("pauper", bolt), limit("vintage", bolt), limit("commander", bolt) ]).to eq([ [ 4, nil ], [ 4, nil ], [ 4, nil ], [ 1, nil ] ])
    end

    it "is none for a basic land, Snow-Covered ones included", :aggregate_failures do
      plains = entry("Plains", type_line: "Basic Land — Plains")
      snow = entry("Snow-Covered Island", type_line: "Basic Snow Land — Island")
      expect([ limit("standard", plains), limit("commander", snow) ]).to all(be_nil)
    end

    it "is none for any-number text, in every format", :aggregate_failures do
      rats = entry("Relentless Rats", type_line: "Creature — Rat", text: "Relentless Rats gets +1/+1 for each other creature you control named Relentless Rats.\nA deck can have any number of cards named Relentless Rats.")
      expect([ limit("modern", rats), limit("commander", rats) ]).to all(be_nil)
    end

    it "is the stated number for up-to text, in every format", :aggregate_failures do
      dwarves = entry("Seven Dwarves", type_line: "Creature — Dwarf", text: "Seven Dwarves gets +1/+1 for each other creature named Seven Dwarves you control.\nA deck can have up to seven cards named Seven Dwarves.")
      expect([ limit("standard", dwarves), limit("commander", dwarves) ]).to eq([ [ 7, nil ], [ 7, nil ] ])
    end

    it "is 1, restricted, in Vintage only", :aggregate_failures do
      lotus = entry("Black Lotus", type_line: "Artifact", legalities: { "vintage" => "restricted", "legacy" => "banned" })
      expect([ limit("vintage", lotus), limit("legacy", lotus) ]).to eq([ [ 1, "restricted to 1" ], [ 4, nil ] ])
    end

    it "is the ordinary limit for a printing with no card data, a basic land included", :aggregate_failures do
      bare = entry("Plains", record: false)
      expect([ limit("standard", bare), limit("commander", bare) ]).to eq([ [ 4, nil ], [ 1, nil ] ])
    end
  end
end
```

  Run `bin/rspec spec/models/mtg/deck_rules_spec.rb` → **FAIL** (`uninitialized constant MTG::DeckRules`).

- [ ] **Implement** `app/models/mtg/deck_rules.rb` (Magic's side may name formats and zones; it is not a core file):

```ruby
# Magic's deck rules for the deck checks (spec 079 decision 3, the extension side of `Catalog::DeckChecks`): size and copy
# limits per format, and each printing's limit read from its first face's type line, its rules text and its legalities.
# Reads the loaded printing record only, so no query runs per card.
class MTG::DeckRules
  # The formats that share one rule set: the main zone's minimum, the sideboard's maximum and a limit of four.
  CONSTRUCTED = %w[standard pioneer modern legacy vintage pauper].freeze
  # A constructed deck holds at least this many cards in its main zone (spec 079 decision 3).
  MAIN_MINIMUM = 60
  # A constructed deck's sideboard holds at most this many cards.
  SIDEBOARD_MAXIMUM = 15
  # The copies of one card a constructed deck may hold (a basic land and the cards that say otherwise excepted).
  CONSTRUCTED_COPIES = 4
  # The copies of one card a Commander deck may hold: the singleton rule.
  COMMANDER_COPIES = 1
  # A Commander deck's commander and main zones hold exactly this many cards together.
  COMMANDER_SIZE = 100
  # Rules text of a card a deck may hold any number of: Scryfall's own words (confirmed in verification.md, T0.2).
  ANY_NUMBER = /a deck can have any number of cards named/i
  # Rules text of a card a deck may hold up to a stated number of; the number is the word after "up to".
  STATED_NUMBER = /a deck can have up to (\w+) cards named/i
  # The number words the stated limits use (Seven Dwarves: seven; Nazgûl: nine).
  NUMBER_WORDS = %w[two three four five six seven eight nine ten].each_with_index.to_h { |word, index| [ word, index + 2 ] }.freeze

  # The rules of one format.
  #
  # @param format_key [String] the deck's stored format key
  # @return [Catalog::DeckChecks::Rules, nil] nil for casual and for a key the collectible has no rules for
  def self.for(format_key)
    return commander if format_key == "commander"

    constructed(format_key) if CONSTRUCTED.include?(format_key)
  end

  # A printing's limit in a format. Order matters: a basic land and any-number text are exempt first, then a stated number,
  # then Vintage's restriction, then the ordinary limit. A printing with no card data is never exempt and never restricted.
  #
  # @param entry [Catalog::Entry] a printing, its `extension` loaded or nil
  # @param format_key [String]
  # @param ordinary [Integer] the format's ordinary limit
  # @return [Catalog::DeckChecks::Limit, nil] nil for a card that is never limited
  def self.limit_for(entry, format_key, ordinary)
    printing = entry.extension
    return Catalog::DeckChecks::Limit.new(count: ordinary, reason: nil) if printing.nil?

    faces = Array(printing.faces)
    return if basic_land?(faces.first)

    text = faces.filter_map { it["oracle_text"] }.join("\n")
    return if text.match?(ANY_NUMBER)

    stated = NUMBER_WORDS[text[STATED_NUMBER, 1].to_s.downcase]
    return Catalog::DeckChecks::Limit.new(count: stated, reason: nil) if stated
    return Catalog::DeckChecks::Limit.new(count: 1, reason: "restricted to 1") if format_key == "vintage" && printing.legalities.to_h["vintage"] == "restricted"

    Catalog::DeckChecks::Limit.new(count: ordinary, reason: nil)
  end

  # @api private
  def self.basic_land?(face) = face&.dig("type_line").to_s.split("—").first.to_s.split.include?("Basic")
  private_class_method :basic_land?

  # @api private
  def self.constructed(format_key)
    Catalog::DeckChecks::Rules.new(
      sizes: [ Catalog::DeckChecks::SizeRule.new(zone_keys: %w[main], min: MAIN_MINIMUM, max: nil),
               Catalog::DeckChecks::SizeRule.new(zone_keys: %w[sideboard], min: nil, max: SIDEBOARD_MAXIMUM) ],
      copies: Catalog::DeckChecks::CopyRule.new(zone_keys: %w[main sideboard], limit_for: ->(entry) { limit_for(entry, format_key, CONSTRUCTED_COPIES) })
    )
  end
  private_class_method :constructed

  # @api private
  def self.commander
    Catalog::DeckChecks::Rules.new(
      sizes: [ Catalog::DeckChecks::SizeRule.new(zone_keys: %w[commander main], min: COMMANDER_SIZE, max: COMMANDER_SIZE) ],
      copies: Catalog::DeckChecks::CopyRule.new(zone_keys: %w[commander main], limit_for: ->(entry) { limit_for(entry, "commander", COMMANDER_COPIES) })
    )
  end
  private_class_method :commander
end
```

  In `app/models/mtg/collecting.rb`, after `deck_shape`:

```ruby
  # The deck checks' rules for one format (spec 079, the extension side of `Catalog::DeckChecks`): size and copy limits.
  # See `MTG::DeckRules`.
  #
  # @param format_key [String] the deck's stored format key
  # @return [Catalog::DeckChecks::Rules, nil] nil for casual and for a key with no rules
  def self.deck_rules(format_key) = MTG::DeckRules.for(format_key.to_s)
```

- [ ] Run → PASS; `bin/rubocop -a`; `bin/yard doc --no-cache`; commit `feat(decks): Magic's deck rules for the deck checks (#258)`.

### T2.2 Magic decks end to end through the seam

- [ ] **Test** `spec/models/mtg/deck_checks_for_magic_spec.rb` (real decks, real `Deck::Page`; AC-2.1–2.4, 2.7, 2.8, 3.1–3.7, 3.12, 3.14, 3.16, 4.5):

```ruby
require "rails_helper"

RSpec.describe "Catalog::DeckChecks for a Magic deck", type: :model do
  let(:account) { create(:user).account }

  def deck_of(format) = create(:deck, account:, format:, name: "Deck #{format}")

  def card(name, type_line: "Instant", text: nil, legalities: {}, identity: create(:catalog_identity, name:), **attributes)
    entry = create(:catalog_entry, identity:, name:, **attributes)
    create(:mtg_printing, entry:, legalities:, faces: [ { "name" => name, "type_line" => type_line, "oracle_text" => text, "image_uris" => {} } ])
    entry
  end

  def land(name = "Plains") = card(name, type_line: "Basic Land — #{name}")
  def own(deck, zone, entry, quantity) = create_lot_in_zone(deck, zone, entry:, quantity:)
  def proxy(deck, zone, entry) = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, finish: "nonfoil", quantity: 1)

  def lines(deck)
    page = Deck::Page.new(Deck.includes(:location).find_by!(location_id: deck.location_id))
    Catalog::DeckChecks.report("mtg", deck.format, page.zones).lines.map { [ it.status, it.sentence ] }
  end

  it "judges Main and Sideboard in each constructed format's own name", :aggregate_failures do
    %w[standard pioneer modern legacy vintage pauper].each do |key|
      deck = deck_of(key)
      own(deck, "main", land, 58)
      own(deck, "sideboard", land("Island"), 16)
      expect(lines(deck)).to include([ "Short", "Main: 58 cards; #{key.titleize} needs at least 60." ], [ "Over", "Sideboard: 16 cards; #{key.titleize} allows at most 15." ])
    end
  end

  it "counts a proxy toward Main and passes at 60 and at 15", :aggregate_failures do
    deck = deck_of("standard")
    own(deck, "main", land, 59)
    proxy(deck, "main", land("Island"))
    own(deck, "sideboard", land("Swamp"), 15)
    expect(lines(deck)).to include([ "Pass", "Main: 60 cards; Standard needs at least 60." ], [ "Pass", "Sideboard: 15 cards; Standard allows at most 15." ])
  end

  it "judges Commander's two zones together", :aggregate_failures do
    deck = deck_of("commander")
    own(deck, "commander", card("Krenko"), 1)
    own(deck, "main", land, 98)
    expect(lines(deck)).to include([ "Short", "Commander + Main: 99 cards; Commander needs exactly 100." ])
    own(deck, "main", land("Island"), 2)
    expect(lines(deck)).to include([ "Over", "Commander + Main: 101 cards; Commander needs exactly 100." ])
  end

  it "says Casual and an unregistered format have no rules but still flag a forgotten proxy", :aggregate_failures do
    deck = deck_of("casual")
    bolt = card("Lightning Bolt")
    own(deck, "main", bolt, 2)
    proxy(deck, "main", bolt)
    expect(lines(deck)).to eq([ [ nil, "Casual has no rules to check." ], [ "Owned and proxy", "Lightning Bolt in Main: 2 owned, 1 proxy." ] ])
    deck.update!(format: "retired")
    expect(lines(deck).first).to eq([ nil, "retired has no rules to check." ])
  end

  it "adds a card's copies across printings, zones, owned and proxy", :aggregate_failures do
    deck = deck_of("standard")
    bolt = create(:catalog_identity, name: "Lightning Bolt")
    one = card("Lightning Bolt", identity: bolt)
    two = card("Lightning Bolt", identity: bolt, set: create(:catalog_set))
    own(deck, "main", one, 3)
    own(deck, "sideboard", two, 1)
    proxy(deck, "main", two)
    expect(lines(deck)).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
  end

  it "names a card by its English name when its first row in page order is a Japanese printing", :aggregate_failures do
    deck = deck_of("standard") # Main is read before Sideboard, and the Japanese printing is the only row of Main
    bolt = create(:catalog_identity, name: "Lightning Bolt")
    own(deck, "main", card("Lightning Bolt", identity: bolt, language: "ja", localized_name: "稲妻"), 3)
    own(deck, "sideboard", card("Lightning Bolt", identity: bolt, set: create(:catalog_set)), 2)
    expect(lines(deck)).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
    expect(lines(deck).map(&:last)).not_to include(a_string_matching(/稲妻/))
  end

  it "names a Sideboard the deck has no zone row for from the registration (AC-2.12)" do
    deck = deck_of("standard")
    deck.zone("sideboard").destroy!
    expect(lines(deck)).to include([ "Pass", "Sideboard: 0 cards; Standard allows at most 15." ])
  end

  it "passes Commander at exactly 100 while cards in Considering count nowhere (AC-2.4, 2.5)" do
    commander = deck_of("commander")
    own(commander, "commander", card("Krenko"), 1)
    own(commander, "main", land, 99)
    own(commander, "considering", land("Island"), 30)
    expect(lines(commander)).to include([ "Pass", "Commander + Main: 100 cards; Commander needs exactly 100." ])
  end

  it "exempts basic lands and any-number cards, and holds Commander to one of the rest", :aggregate_failures do
    standard = deck_of("standard")
    own(standard, "main", land, 20)
    rats = card("Relentless Rats", type_line: "Creature — Rat", text: "A deck can have any number of cards named Relentless Rats.")
    own(standard, "main", rats, 9)
    expect(lines(standard)).to include([ "Pass", "No card is over its limit." ])
    commander = deck_of("commander")
    krenko = create(:catalog_identity, name: "Krenko")
    own(commander, "commander", card("Krenko", identity: krenko), 1)
    own(commander, "main", card("Krenko", identity: krenko, set: create(:catalog_set)), 1)
    own(commander, "main", card("Snow-Covered Island", type_line: "Basic Snow Land — Island"), 2)
    expect(lines(commander)).to include([ "Over the limit", "Krenko: 2 copies; the limit is 1." ])
    expect(lines(commander).map(&:last)).not_to include(a_string_matching(/Snow-Covered/))
  end

  it "holds a numbered card to its number in every format, and passes at that number", :aggregate_failures do
    text = "A deck can have up to seven cards named Seven Dwarves."
    %w[standard commander].each do |key|
      over = deck_of(key)
      own(over, "main", card("Seven Dwarves", type_line: "Creature — Dwarf", text:), 8)
      expect(lines(over)).to include([ "Over the limit", "Seven Dwarves: 8 copies; the limit is 7." ])
      exact = create(:deck, account:, format: key, name: "Exact #{key}")
      own(exact, "main", card("Seven Dwarves", type_line: "Creature — Dwarf", text:), 7)
      expect(lines(exact)).to include([ "Pass", "No card is over its limit." ])
    end
  end

  it "restricts a card to one in Vintage only", :aggregate_failures do
    legalities = { "vintage" => "restricted" }
    vintage = deck_of("vintage")
    own(vintage, "main", card("Black Lotus", type_line: "Artifact", legalities:), 2)
    expect(lines(vintage)).to include([ "Over the limit", "Black Lotus: 2 copies; restricted to 1." ])
    legacy = deck_of("legacy")
    own(legacy, "main", card("Black Lotus", type_line: "Artifact", legalities:), 2)
    expect(lines(legacy)).to include([ "Pass", "No card is over its limit." ])
  end

  it "counts a basic land's two printings, one with no card data, at the ordinary limit (AC-3.14, 3.16)", :aggregate_failures do
    deck = deck_of("standard")
    identity = create(:catalog_identity, name: "Plains")
    own(deck, "main", card("Plains", type_line: "Basic Land — Plains", identity:), 1)
    own(deck, "main", create(:catalog_entry, identity:, name: "Plains", set: create(:catalog_set)), 4)
    expect(lines(deck)).to include([ "Over the limit", "Plains: 5 copies; the limit is 4." ])
  end

  it "leaves out another collectible's cards", :aggregate_failures do
    deck = deck_of("standard")
    own(deck, "main", create(:catalog_entry, collectible_type: "stranger", name: "Odd"), 70)
    expect(lines(deck)).to include([ "Short", "Main: 0 cards; Standard needs at least 60." ], [ "Pass", "No card is over its limit." ])
  end
end
```

- [ ] Run → these should pass on first run, since T2.1 is in; this task is the end-to-end proof, not new behaviour. **Mutation proof:** set `MAIN_MINIMUM` to 61 once, see the Standard examples fail, restore. Record it in `verification.md`. Commit `test(decks): Magic deck checks end to end through the seam (#258)`.

## Phase 3: The request and the page

**Implements:** FR-3; decisions 7, 8, 9 · **Satisfies:** AC-1.1–1.9, 5.1, 5.2, 5.3
**Files:** `config/routes.rb`, `app/controllers/decks/checks_controller.rb`, `app/views/decks/show.html.erb`, `app/views/decks/_check.html.erb`, `spec/requests/deck_checks_spec.rb`, `spec/deck_core_spec.rb`, `spec/system/deck_page_spec.rb`
**Interfaces:** Produces `GET /decks/:deck_id/check` (`deck_check_path(deck)`, `Decks::ChecksController#show`) and `@check` (a `Catalog::DeckChecks::Report`) in `decks/show`. Consumes Phases 1 and 2, `FindsDeck#set_deck`, `Deck::Page`, `Catalog::DeckShape.answer`.

### T3.1 Route, controller, link, results section (plain markup)

- [ ] **Test (red)** `spec/requests/deck_checks_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Deck checks", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo", format: "standard") }

  def html = Nokogiri::HTML5(response.body)

  def printing(name: "Lightning Bolt", type_line: "Instant")
    entry = create(:catalog_entry, identity: create(:catalog_identity, name:), name:)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => "{R}", "image_uris" => {} } ])
    entry
  end

  def plains = printing(name: "Plains", type_line: "Basic Land — Plains")
  def own(zone, entry, quantity: 1) = create_lot_in_zone(deck, zone, entry:, quantity:)
  def proxy_in(zone, entry) = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, finish: "nonfoil", quantity: 1)
  def rows = html.css(".c-check__row").map { it.text.squish }

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the button and no results on the plain deck page (AC-1.1, 1.9)", :aggregate_failures do
      get deck_path(deck)
      expect(html.at_css(".c-item__actions > a.c-btn--secondary[href='#{deck_check_path(deck)}']").text).to eq("Check deck")
      expect(html.at_css("#deck-check-title")).to be_nil
      expect(html.at_css("main form")).to be_nil
      expect(response.body).not_to include('name="turbo-cache-control"')
    end

    it "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)", :aggregate_failures do
      own("main", plains, quantity: 58)
      get deck_check_path(deck)
      expect(response).to have_http_status(:ok)
      expect([ html.at_css("#deck-check-title").text, html.at_css(".c-check__summary").text ]).to eq([ "Deck check", "1 finding" ])
      expect(rows).to eq([ "Short Main: 58 cards; Standard needs at least 60.", "Pass Sideboard: 0 cards; Standard allows at most 15.",
                           "Pass No card is over its limit.", "Pass No card has both owned copies and proxies in one zone." ])
      expect(html.css("main > *").first(3).map { it["class"].to_s.split.first }).to eq(%w[c-item__head c-check c-deck])
      expect(response.body).to include('<meta name="turbo-cache-control" content="no-cache">')
      expect(html.at_css("main form")).to be_nil
    end

    it "shows the same results again and every link of the plain page (AC-1.4, 1.5)", :aggregate_failures do
      own("main", plains, quantity: 58)
      get deck_path(deck)
      plain = html.css("main a[href]").map { it["href"] }
      get deck_check_path(deck)
      first = rows
      get deck_check_path(deck)
      expect(rows).to eq(first)
      expect(html.css("main a[href]").map { it["href"] }).to include(*plain)
      expect(html.css("main a, main button").map { it["disabled"] || it["aria-disabled"] }.compact).to be_empty
      get edit_deck_path(deck) # following one of them works as from the plain page
      expect(response).to have_http_status(:ok)
    end

    it "changes nothing: no write reaches lots, proxies or locations (AC-4.8)", :aggregate_failures do
      entry = printing
      own("main", entry)
      proxy_in("main", entry)
      before = [ Lot.sum(:quantity), Deck::Proxy.sum(:quantity), Location.count ]
      writes = [ Lot, Deck::Proxy, Location ].flat_map { |model| write_statements_to(model.table_name) { get deck_check_path(deck) } }
      expect(writes).to be_empty
      expect([ Lot.sum(:quantity), Deck::Proxy.sum(:quantity), Location.count ]).to eq(before)
    end

    it "shows no results on the next deck page request after the deck changes (AC-1.3)", :aggregate_failures do
      entry = printing
      own("main", entry)
      proxy = proxy_in("main", entry)
      get deck_check_path(deck)
      expect(rows).to include("Owned and proxy Lightning Bolt in Main: 1 owned, 1 proxy.")
      delete deck_proxy_path(deck, proxy)
      follow_redirect!
      expect(html.at_css("#deck-check-title")).to be_nil
      expect(html.at_css("a[href='#{deck_check_path(deck)}']")).to be_present
      get deck_check_path(deck) # pressing the button again judges the changed deck
      expect(rows).not_to include(a_string_matching(/Owned and proxy/))
    end

    it "words no findings, one finding and several (AC-1.7)", :aggregate_failures do
      own("main", plains, quantity: 60)
      get deck_check_path(deck)
      expect(html.at_css(".c-check__summary").text).to eq("No findings")
      own("sideboard", plains, quantity: 16)
      get deck_check_path(deck)
      expect(html.at_css(".c-check__summary").text).to eq("1 finding")
      own("main", printing(name: "Shock"), quantity: 5)
      get deck_check_path(deck)
      expect(html.at_css(".c-check__summary").text).to eq("2 findings")
    end

    it "gives a deck with no rules the no-rules line and the owned-plus-proxy result (AC-2.7)" do
      get deck_check_path(create(:deck, account:, name: "Pile", format: "casual"))
      expect(rows).to eq([ "Casual has no rules to check.", "Pass No card has both owned copies and proxies in one zone." ])
    end

    it "is a 404 for another account's deck, a zone and a bad id (AC-1.6)", :aggregate_failures do
      theirs = "Rival #{SecureRandom.hex(4)}" # built at run time: the test 404 page prints the spec's own source lines (docs/lessons 2026-11-11)
      other = create(:deck, account: create(:user).account, name: theirs)
      [ other.to_param, deck.zone("main").id, 0, "abc" ].each do |id|
        get deck_check_path(id)
        expect(response).to have_http_status(:not_found), "#{id.inspect} was not a 404"
        expect(response.body).not_to include(theirs)
      end
    end
  end

  it "redirects a visitor who is not signed in (AC-5.2)" do
    get deck_check_path(deck)
    expect(response).to redirect_to(new_session_path)
  end
end
```

  Run `bin/rspec spec/requests/deck_checks_spec.rb` → **FAIL** (`undefined local variable deck_check_path`).

- [ ] **Implement.**
  - `config/routes.rb`, after `resource :selection, only: :create, module: :decks` (line 51): `resource :check, only: :show, module: :decks # spec 079: Check deck, the deck page with its checks`.
  - `app/controllers/decks/checks_controller.rb`:

```ruby
# Check deck (spec 079): the deck page with its checks' results. A read-only request, so the link to it needs no form and the
# result is never stored: any later request of the deck page has none (decision 7). The deck comes from the signed-in
# account's decks, so another account's is a 404 (`FindsDeck`). It builds the page and the shape panel as
# `DecksController#show` does and adds one report; the report reads the loaded rows and runs no statement of its own (AC-5.1).
class Decks::ChecksController < ApplicationController
  include FindsDeck

  before_action :set_deck

  # Renders the deck page with `@check` set.
  def show
    @page = Deck::Page.new(@deck)
    @shape = Catalog::DeckShape.answer(@deck.collectible_type, @page.zones)
    @check = Catalog::DeckChecks.report(@deck.collectible_type, @deck.format, @page.zones)
    render "decks/show"
  end
end
```

  - `app/views/decks/show.html.erb`: after line 1 add `<%# The results page isn't kept for Back: Back asks for the check again, so it never shows results from before an edit (spec 079 decision 7). %>` and `<% content_for :head, tag.meta(name: "turbo-cache-control", content: "no-cache") if @check %>`; after the Edit deck link add `<%= link_to "Check deck", deck_check_path(@deck), class: "c-btn c-btn--secondary", data: { turbo_prefetch: false } %>` (a hover prefetch would compute a check nobody asked for); between the head's closing `</div>` and `<div class="c-deck">` add `<%= render "decks/check", check: @check if @check %>`.
  - `app/views/decks/_check.html.erb`:

```erb
<section class="c-check" aria-labelledby="deck-check-title">
  <h2 class="c-section__title c-check__title" id="deck-check-title" tabindex="-1" autofocus>Deck check</h2>
  <p class="c-check__summary"><%= check.summary %></p>
  <ul class="c-check__list">
    <% check.lines.each do |line| %>
      <li class="c-check__row<%= line.status ? (line.fault ? " c-check__row--fault" : " c-check__row--pass") : " c-check__row--plain" %>">
        <% if line.status %>
          <span class="c-check__status"><%= render(line.fault ? "icons/alert" : "icons/check") %><%= line.status %></span>
        <% end %>
        <span class="c-check__text"><%= line.sentence %></span>
      </li>
    <% end %>
  </ul>
</section>
```

  - `spec/deck_core_spec.rb`: raise the total by `+ 2` with the clause `spec 079 adds the check's controller and the results partial (the globs already cover them)`.
  - `spec/system/deck_page_spec.rb:259`: the head now has three `.c-btn` (Edit deck, Check deck, More): change `[ true, true ]` to `[ true, true, true ]`; read `:264-273` (the link is a `c-btn--secondary`, so heights ≥ 36 hold).
- [ ] Run `bin/rspec spec/requests/deck_checks_spec.rb spec/requests/deck_pages_spec.rb spec/deck_core_spec.rb spec/system/deck_page_spec.rb` → PASS (the last is the file this task edits). Rubocop; commit `feat(decks): Check deck on the deck page (#258)`.

### T3.2 The statement count

- [ ] **Test** append to `spec/requests/deck_checks_spec.rb` (AC-5.1; the form of `spec/requests/query_counts_spec.rb:227-253`, the bulk fixtures of `spec/requests/collection_import_proxy_timing_spec.rb:43-60`):

```ruby
  describe "statements" do
    before { sign_in_as(user) }

    # `count_queries` is `spec/support/query_counting.rb`'s (cached, SCHEMA and TRANSACTION statements are not counted).
    def queries_for(path)
      count = count_queries { get path }
      expect(response).to have_http_status(:ok)
      count
    end

    # +rows+ printings of one identity, bulk-inserted and owned in the deck's Main zone, ten of them also as proxies.
    def fill(deck, rows, label)
      set = create(:catalog_set, code: label)
      identity = create(:catalog_identity, name: "Bulk #{label}")
      now = Time.current
      Catalog::Entry.insert_all(Array.new(rows) { |i| { collectible_type: "mtg", external_key: "#{label}-#{i}", catalog_set_id: set.id, catalog_identity_id: identity.id, number: i.to_s, language: "en", name: "Card #{i}", kind: "card", content_digest: "d", created_at: now, updated_at: now } })
      ids = Catalog::Entry.where(catalog_set_id: set.id).pluck(:id)
      MTG::Printing.insert_all(ids.map { |id| { catalog_entry_id: id, rarity: "common", finishes: %w[nonfoil], layout: "normal", scryfall_uri: "https://example.test/#{id}", faces: [], created_at: now, updated_at: now } })
      location = deck.zone("main")
      Lot.insert_all(ids.map { |id| { account_id: account.id, catalog_entry_id: id, quantity: 2, finish: "nonfoil", price_paid_cents: nil, location_id: location.id, lot_key: Lot.key_for("nonfoil", nil, nil, location.id), created_at: now, updated_at: now } })
      ids.first(10).each { |id| create(:deck_proxy, zone: location, account:, entry: Catalog::Entry.find(id), finish: "nonfoil", quantity: 1) }
    end

    it "runs the plain deck page's statements however many rows the deck has", :aggregate_failures do
      small = create(:deck, account:, name: "Small", format: "standard")
      big = create(:deck, account:, name: "Big", format: "standard")
      fill(small, 5, "small")
      fill(big, 500, "big")
      [ small, big ].each { |deck| get deck_path(deck) } # warm the page once
      expect(queries_for(deck_check_path(small))).to eq(queries_for(deck_path(small)))
      expect(queries_for(deck_check_path(big))).to eq(queries_for(deck_path(big)))
      expect(queries_for(deck_check_path(big))).to eq(queries_for(deck_check_path(small)))
    end
  end
```

  (The bulk printings list `nonfoil`, so each proxy uses `finish: "nonfoil"`. A 500-row page renders every row; record the example's runtime in `verification.md`.)
- [ ] Run → PASS (the check adds no statement), and run `bin/rspec spec/models/deck/page_spec.rb`: its examples at `:173-200` pin `Deck::Page#zones` at 3 and 6 statements, which is AC-5.1's "`Deck::Page#zones` is as before". **Mutation proof:** temporarily make `split_lines` call `Catalog::Entry.find(it.row.entry.id)` per card, see the example FAIL, revert. Record it in `verification.md`. Commit `test(decks): the check runs no statement of its own (#258)`.

## Phase 4: Design system and browser proof

**Implements:** NFR Accessibility and design; decisions 6–8 · **Satisfies:** AC-1.8 (browser), 6.1–6.4, 7.4
**Files:** `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/DeckCheck.md`, `DeckPage.md`, `docs/design-system/README.md`, `spec/system/deck_checks_spec.rb`
**Interfaces:** Consumes the `decks/_check` markup: `c-check`, `c-check__title|summary|list|row|status|text`, `--pass|--fault|--plain`.

### T4.1 The `DeckCheck` pattern

- [ ] **Test first (red).** Write T4.2's file (below) and run `bin/rspec spec/system/deck_checks_spec.rb` before any CSS exists: the phone example must **FAIL** (the 60-character text and zone name are unwrapped and clipped with no `c-check` rule). That failure is the red step for this task's CSS.
- [ ] Invoke the `collector-design-system` skill; read `docs/design-system/README.md`, `DeckPage.md`, `Badge.md`, `StageList.md`. Reuse first: `c-section__title` for the heading; `icons/check` and `icons/alert` at the 12 px badge-icon size. The gap is the Complexity note above.
- [ ] Add to `additions.css` after the `c-deck` block (tokens only; text sizes are the type scale's: body 15/22, data 13/18; the 12 px icon takes the 2.5 stroke the README gives an icon no component sizes, as `.c-badge svg` does at `additions.css:634`):

```css
/* DeckCheck (spec 079): the Check deck results, a full-width section between the deck page's head and its zones. A row is a
   status word with its icon and a sentence; the word and the icon say pass or fault, so colour is never the only signal. */
.c-check { margin-top:var(--space-6); display:flex; flex-direction:column; gap:var(--space-3); min-width:0; }
.c-check__title:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); }
.c-check__summary { margin:0; font:400 13px/18px var(--font-mono); color:var(--ink-muted); }
.c-check__list { list-style:none; margin:0; padding:0; background:var(--surface-raised); border:1px solid var(--line); border-radius:var(--radius-md); }
.c-check__row { display:grid; grid-template-columns:minmax(0, 1fr); gap:var(--space-1); padding:var(--space-3) var(--space-4); border-top:1px solid var(--line); overflow-wrap:anywhere; }
.c-check__row:first-child { border-top:0; }
.c-check__status { display:inline-flex; align-items:center; gap:var(--space-2); font:600 13px/18px var(--font-sans); color:var(--ink); }
.c-check__status svg { width:12px; height:12px; flex:none; stroke-width:2.5; }
.c-check__row--pass .c-check__status svg { color:var(--success); }
.c-check__row--fault .c-check__status svg { color:var(--warning); }
.c-check__text { font:400 15px/22px var(--font-sans); color:var(--ink); }
@container page (min-width: 640px) {
  .c-check__row { grid-template-columns:11rem minmax(0, 1fr); align-items:baseline; gap:var(--space-4); }
  .c-check__row--plain .c-check__text { grid-column:1 / -1; }
}
```

  Adjust a value only to match an existing token (confirm `--radius-sm` exists in `tokens.css`); re-run T4.2 after any change.
- [ ] Write `docs/design-system/components/DeckCheck.md` (shape of `DeckShape.md`: what it is, a markup sample, the classes, the pass/fault/plain states, colour never alone, focus on the heading, phone behaviour, the 12 px icon at stroke 2.5). Edit `DeckPage.md` (the "As built" paragraph gets the head's Check deck link and the results section between head and `c-deck`; keep "no `form`") and `README.md` (an App additions line, and `DeckCheck`'s 12 px icon added to the Iconography list beside the badge and legality icons). Commit `feat(design): the DeckCheck pattern for the check results (#258)`.

### T4.2 Browser proof

- [ ] **Test** `spec/system/deck_checks_spec.rb` (type :system; helpers `system_sign_in_as`, `wait_for_turbo_idle`, `open_in_viewport_frame`, `within_narrow_frame`, `page_fits_sideways?`, `tab_to_text`; `set_theme` defined locally as in `spec/system/deck_page_spec.rb:32`):

```ruby
require "rails_helper"

RSpec.describe "Deck checks", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:deck) { create(:deck, account: user.account, name: "Izzet Tempo", format: "standard") }

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")

  def printing(name, type_line: "Basic Land — Plains")
    entry = create(:catalog_entry, identity: create(:catalog_identity, name:), name:)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "image_uris" => {} } ])
    entry
  end

  def clipped(selector) = page.evaluate_script("[...document.querySelectorAll(#{selector.to_json})].filter(el => el.scrollWidth > el.clientWidth + 1).length")

  it "moves keyboard focus to the results heading (AC-6.3)", :aggregate_failures do
    visit deck_path(deck)
    expect(tab_to_text("Check deck")).to be(true) # the link is reachable by Tab, and Enter is pressed on it
    page.send_keys(:enter)
    expect(page).to have_css("#deck-check-title:focus", text: "Deck check")
    expect(page.evaluate_script("document.getElementById('deck-check-title').tabIndex")).to eq(-1)
  end

  it "asks for the check again on Back instead of restoring a Turbo snapshot (AC-1.8)", :aggregate_failures do
    visit deck_path(deck)
    click_link "Check deck"
    expect(page).to have_text("Main: 0 cards; Standard needs at least 60.")
    page.execute_script("window.__sameDocument = true") # Turbo visits keep the document; a full page load would drop this
    create_lot_in_zone(deck, "main", entry: printing("Plains"), quantity: 60)
    click_link "Edit deck"
    wait_for_turbo_idle
    page.go_back
    expect(page).to have_text("Main: 60 cards; Standard needs at least 60.")
    expect(page.evaluate_script("window.__sameDocument")).to be(true) # still the same document, so Turbo did the Back
  end

  it "puts the results before the zones in reading order (AC-6.3)" do
    visit deck_check_path(deck)
    follows = "document.getElementById('deck-check-title').compareDocumentPosition(document.querySelector('.c-zone')) & Node.DOCUMENT_POSITION_FOLLOWING"
    expect(page.evaluate_script("!!(#{follows})")).to be(true)
  end

  it "fits a phone, in both themes, with long names (AC-6.1, 6.4)", :aggregate_failures do
    long = "N" * 60
    create_lot_in_zone(deck, "main", entry: printing(long, type_line: "Instant"), quantity: 5)
    deck.zone("main").update_columns(name: "Z" * 60) # a zone's shown name is a copy, so a long one is a fixture, not a rename flow
    visit deck_path(deck)
    expect(open_in_viewport_frame(deck_check_path(deck), viewport: 360, ready: "#deck-check-title")).to eq(360)
    within_narrow_frame do
      %w[light dark].each do |theme|
        set_theme(theme)
        expect([ page_fits_sideways?, clipped(".c-check__text, .c-check__status, .c-item__actions .c-btn") ]).to eq([ true, 0 ])
      end
    end
  end

  it "says pass or fault in words with an icon on every row, never by colour alone (AC-6.2)", :aggregate_failures do
    create_lot_in_zone(deck, "main", entry: printing("Plains"), quantity: 58)
    visit deck_check_path(deck)
    rows = all(".c-check__row--fault .c-check__status")
    expect(rows.map(&:text)).to all(be_in([ "Short", "Over", "Over the limit", "Owned and proxy" ]))
    expect(page).to have_css(".c-check__status svg", count: page.all(".c-check__status").size)
  end
end
```

  (The narrow-frame example's card uses an Instant type line so the copy limit applies and the finding "NNN…: 5 copies; the limit is 4." is the long text under test; the other examples use basic lands so a count finding is the only finding. The Back example follows the repo's own pattern, `spec/system/collection_spec.rb:22-33` and `back_navigation_spec.rb`: Turbo navigations, then Back, with a marker on `window` showing the document is the same one, so the Back was Turbo's and the snapshot cache was in play.)
- [ ] **Mutation proofs (record each in `verification.md`):** (a) remove `overflow-wrap:anywhere` from `.c-check__row`, confirm the phone example fails, restore (memory `headless-firefox-narrow-frame.md`); (b) remove the `turbo-cache-control` line from `decks/show.html.erb`, confirm the Back example fails (Turbo restores the 0-card snapshot), restore; (c) remove `autofocus` from the heading, confirm the focus example fails, restore. Run `bin/rspec spec/system/deck_checks_spec.rb spec/system/deck_page_spec.rb` → PASS. Commit `test(decks): the check's focus, Back and phone width in the browser (#258)`.

### T4.3 Visual evidence

- [ ] Per memories `pr-screenshots-workflow.md` and `pr-visual-evidence-required.md` (headless Firefox, magick/ffmpeg; set `data-theme` for light shots; pause 0.6 s after a theme switch): seed a Standard deck with findings (a short Main, a 5-of, a split), a Vintage deck with a restricted card, and a Casual deck. Capture the results at desktop and 360 px in light and dark, the plain page's head with the new link at 360 px, and a GIF of deck page → Check deck → results → remove a proxy → plain page. Save under `docs/specs/079-deck-checks/screenshots/`, embedded in the PR by SHA-pinned link.

## Phase 5: Documents, verification and review

**Implements:** Story 7 · **Satisfies:** AC-5.3, 5.4, 7.1–7.6
**Files:** `docs/architecture/collection-and-lots.md`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md`, `docs/specs/079-deck-checks/verification.md`

- [ ] **T5.1** `collection-and-lots.md`: the deck checks' rules (decisions 1–10) with the spec as source and a pointer to `Catalog::DeckChecks`' comment (not a copy of the contract); spec 069's non-goal done in part; the new files in the area's list. `CLAUDE.md` Project Status gets one clause ("A collector checks a deck on demand from its page: deck size, copy limits and owned plus proxy of one card (`Catalog::DeckChecks`, `MTG::Collecting.deck_rules`, spec 079)"). `docs/roadmap.md` theme C lists #258 as shipped. Verified by reading, not RSpec (`.claude/rules/testing.md`).
- [ ] **T5.2** `verification.md` in the shape of spec 069's: an AC → proving-example table per story; Story 7 "verified by reading"; the supersession grep (`git grep -n -i "deck rules\|copy limit\|deck size" -- spec docs app ':!.kamal/secrets'`); the Scryfall facts (T0.2); the mutation proofs (T2.2's `MAIN_MINIMUM`, T3.2's per-row statement, T4.2's CSS, cache tag and `autofocus`); the screenshots; findings; deviations.
- [ ] **T5.3** `bin/ci` (RuboCop, YARD, comment ratchet, Brakeman, bundler-audit, importmap audit, the whole suite). A CI failure is reproduced with its seed first (memory `reproduce-ci-with-seed.md`). Cite the pushed SHA. AC-5.3's evidence is the unchanged schema, export spec (`FORMAT_VERSION == 4`) and backup guard.
- [ ] **T5.4** `sdd-review` Mode B on **Opus**, recorded under `## Implementation review` in `verification.md` with the verdict first; then `distill-feature` before the PR is marked ready; open the PR with the maintainer assigned and `gh pr view N --web` once CI is green (memory `open-green-prs-for-review.md`); merge only on their approval.

## Spec coverage

| AC | Task | AC | Task |
|---|---|---|---|
| 1.1, 1.9 | T3.1 | 4.1–4.4, 4.6, 4.7, 4.9, 4.10 | T1.1 |
| 4.8 | T3.1 (no write reaches lots, proxies or locations) |
| 1.2, 1.3, 1.4, 1.5, 1.6, 1.7 | T3.1 | 4.5 | T2.2, T3.1 |
| 1.8 | T3.1 (the tag), T4.2 (Back) | 5.1 | T3.2 |
| 2.1–2.6, 2.8, 2.9 | T1.2, T2.2 | 5.2 | T3.1 |
| 2.7 | T1.1, T2.2, T3.1 | 5.3 | T5.3 |
| 2.10–2.13 | T1.2, T2.2 | 5.4 | T1.1, T3.1 |
| 3.1–3.3, 3.5, 3.6, 3.8–3.11, 3.13, 3.15 | T1.3, T2.2 | 5.5 | T1.1 |
| 3.4, 3.7, 3.12, 3.14, 3.16 | T2.1, T2.2 | 6.1–6.4 | T4.2 |
| | | 7.1, 7.3–7.6 | T4.1, T5.1, T5.3 |
| | | 7.2 | T0.1 (the index row, committed with the spec) |

FR-1 → T1.1, T2.1; FR-2 → T1.1–T1.3, T2.1; FR-3 → T3.1. NFRs: performance T3.2; security T3.1; reliability T1.1, T2.1; accessibility T4.1–T4.2.

## Verification (end to end)

1. `bin/rspec spec/models/catalog/deck_checks_spec.rb spec/models/mtg spec/requests/deck_checks_spec.rb spec/system/deck_checks_spec.rb spec/deck_core_spec.rb` green; then `bin/ci` green.
2. `bin/dev`, sign in, open a Standard deck, press **Check deck**: results appear between head and zones, focus is on "Deck check", the summary reads as expected; remove a proxy: the plain page returns with no results; press Back: a fresh check. Repeat at phone width in both themes.
3. Casual deck: "Casual has no rules to check." then the owned-plus-proxy result. Another account's deck URL: 404.

## Risks and notes

- **Unverified facts (T0.2):** Scryfall's rules-text wording and that `name` is English for a non-English printing. A wording difference changes two regexes and the fixtures, nothing else.
- **Autofocus on a heading:** Turbo honours `autofocus` on a link visit (an `advance` visit uses `PageRenderer`; morph renders don't focus, and this isn't one) and the browser does on a full load; the repo has no heading precedent, so T4.2's first example is the proof. If it fails, fall back to the repo's own pattern (`sitting_focus_controller.js`: `tabindex="-1"` and a one-shot Stimulus controller).
- **Three head buttons at 360 px:** Edit deck, Check deck and More share `c-item__actions`; T4.2 and the screenshots are the proof. If they overflow, wrap rather than shrink.
- **A numbered card with an unknown number word** ("up to twelve") falls through to the ordinary limit. Only two real cards have the text and both are in the map.
- **Left out on purpose:** boot-time verification of `deck_rules` (zone keys against the format's zones). It isn't in the spec; a wrong key counts as no cards and is named from the registration, which T1.2 tests. Offered as a follow-up.
