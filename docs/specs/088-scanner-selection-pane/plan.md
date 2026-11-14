# Implementation Plan: Scanner: the Selection Pane

**Spec:** docs/specs/088-scanner-selection-pane/spec.md (1.0.1; 1.0.0 approved at Gate A on 2026-11-13)
**Decisions:** none (no ADR, decision 17)
**Created:** 2026-11-13
**Status:** Approved at Gate B on 2026-11-13 by the coordinator under the maintainer's delegation (plan at `a6bb3fe1`, spec 1.0.1; the coordinator read the round-2 fixes itself). Two execution notes from that read: the first implementer who touches the not-sure examples asserts in the request spec that "Lightning" is not a strong name against the test catalog (Task 3's example), and changes the drawn name if a fixture makes it strong, never the threshold; the red window from Task 5 to Task 8 is named in each commit message and no full `bin/ci` runs inside it.

## Global Constraints

- Hotwire first: native scroll snap, one server-rendered Turbo Frame (`scanner_selection`), one small Stimulus controller (`selection`) that notes the centred card; no client-side state store, no HTML built from strings in script (spec decisions 5, 6).
- The band is one element (`p#scanner_band.c-band`, `role="status"`) whose form class, icon and sentence are replaced in place from the centred panel's `<template>`; never a second band revealed with `hidden`. The row's centred item carries `aria-current="true"`; every `c-scanpane__card` but its own carries `hidden`.
- Every string a Turbo Stream writes is escaped (`ERB::Util.html_escape`) or comes from a partial; the page writes the reader's text with `textContent` (`.claude/memory/turbo-stream-string-is-html-safe.md`).
- Rank nothing, read nothing differently: only the predicate `Candidate#card_sure?` is new in `MTG::Reading`.
- Band wordings (exact): "Matched by its collector line"; "Matched by its collector line, one digit corrected"; "Matched by its artwork"; "Printing not confirmed. Swipe to check."; "Not sure of this card. Check it against your capture."; "Not the printing that was read". Position "1 of 14 printings" / "1 of 3 possible cards". Buttons "Previous printing", "Next printing", "Previous card", "Next card", "All printings", "Show 20 more". Add buttons "Add nonfoil", "Add foil", "Add etched", "Add", "Add foil · read from the card"; accessible name stays "Add Lightning Bolt MOM · 123 Foil".
- Regions (spec 082 decision 10, spec 088 decisions 1, 8): the pane's `#status` and the band stay rendered while empty and take no space; "Done. ‹band sentence and tail›" is a visually hidden (`c-sr`) paragraph written once the pane shows and only when the band holds text; refusals in the pane (catalog not ready, too long, no key) are visible alerts in `#status` with `#scanner_result` empty; the no-edge sentence is a second visible paragraph appended after "Done."; `#status` has no padding, margin or gap of its own (spacing is on the `.c-status__message` inside it).
- The layout numbers (decision 13) live in one place: `--scan-image-min: 96px` on `.c-scanpane` and the `@container scan (max-height: 599px)` block (strip 64px, picture 52px), both in the `(spec 088 …)` block of `additions.css`. Task 9 owns them and their specs, so a different ruling is a small change.
- Measurement mode's run-sheet row logic (#419) is not touched.
- Touch targets are 44px at every pointer (spec 075); both themes; nothing scrolls sideways at 360px.
- Tests: tag spec types explicitly; `:aggregate_failures` for multi-expectation examples; no `sleep`; no `any_instance_of`; run `bin/rails db:prepare` after any merge of `main` before a spec run; targeted `bin/rspec <file>` needs no CI slot; never two test runs at once; never run `bin/jobs`, `sqlite3`, or anything on the permission-ask list.
- Commits: Conventional Commits, one per task step that says Commit, ending with the model's `Co-Authored-By` trailer; stage and commit in separate calls.

---

## Goal

After a capture the collector sees their capture beside the match under a status band, adds a confident match with one tap on a finish, swipes (or steps) to another printing, and can tell at a glance when the scanner is less sure; the interim result body, "What the scanner read", the candidates grid and the Other printings frame are gone.

---

## Phase 0: Contracts and tests first

**Implements:** FR-1, FR-2 | **Satisfies:** AC-2.1 to AC-2.6, AC-3.1, AC-3.8 to AC-3.11, AC-6.1 to AC-6.3, AC-8.1
**Files:** `spec/models/mtg/reading/candidate_spec.rb`, `spec/models/scanner/selection_spec.rb`, `spec/requests/scanner/readings_spec.rb`, `spec/requests/scanner/printings_spec.rb`
**Interfaces:** Consumes: nothing. Produces: the failing specs that Phases 1 and 2 turn green; `MTG::Reading::Candidate#card_sure?`, `Scanner::Selection` (see Phase 1), the answers of `POST /scanner/readings` and `GET /scanner/printings` as the request specs state them.

The units and the two requests are specified before any of them exists. The system specs of Phase 4 onward are written in their own phases, test first, because they need the pane.

### Task 1: `Candidate#card_sure?` (failing spec, then code)

- [ ] Write `spec/models/mtg/reading/candidate_spec.rb` (the path RSpec/SpecFilePathFormat wants for `MTG::Reading::Candidate`; no method string in the describe):

```ruby
require "rails_helper"

# Spec 088 decision 2: the one new reading of the evidence, "sure of the card". It changes nothing the ranking does.
RSpec.describe MTG::Reading::Candidate, type: :model do
  def candidate(evidence, strong_name: false)
    described_class.new(entry: nil, evidence:, name_rank: 0, strong_name:)
  end

  describe "#card_sure?" do
  it "trusts the card on collector-line evidence, plain or corrected", :aggregate_failures do
    expect(candidate(%i[collector_line])).to be_card_sure
    expect(candidate(%i[name collector_line_corrected])).to be_card_sure
  end

  it "trusts the card on confident art or a strong name match", :aggregate_failures do
    expect(candidate(%i[art])).to be_card_sure
    expect(candidate(%i[name], strong_name: true)).to be_card_sure
  end

  it "does not trust a name-only or weak-art candidate", :aggregate_failures do
    expect(candidate(%i[name])).not_to be_card_sure
    expect(candidate(%i[name art_weak])).not_to be_card_sure
  end
  end
end
```

- [ ] Run `bin/rspec spec/models/mtg/reading/candidate_spec.rb` — expect FAIL (`undefined method card_sure?`).
- [ ] In `app/models/mtg/reading.rb`, inside `Candidate`, after `def printing_confirmed? = …` add:

```ruby
    # Whether the scanner trusts the card itself (spec 088 decision 2): collector-line evidence (plain or corrected), confident
    # art, or a strong name match. A candidate that is not sure, and whose printing is not confirmed, is "not sure of this card"
    # on the pane's band. Reads the evidence only; the ranking is `rank_key`, unchanged.
    def card_sure? = collector_line? || art? || strong_name
```

- [ ] Run the spec — expect PASS. Commit: `feat(scanner): name the evidence that makes the scanner sure of a card (spec 088)`.

### Task 2: `Scanner::Selection` (failing spec, then code)

- [ ] Write `spec/models/scanner/selection_spec.rb`:

```ruby
require "rails_helper"

# Spec 088 decisions 2 to 4, 15: what the pane's row holds, in which band state, and how many printings load at once.
RSpec.describe Scanner::Selection, type: :model do
  let(:key) { "f" * 32 }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  def printing(code, number, identity: self.identity)
    set = Catalog::Set.find_by(code:) || create(:catalog_set, code:, name: code.upcase)
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: identity.name, set:, number:)).entry
  end

  def candidate(entry, evidence, strong_name: false, name_rank: 0, **rest)
    MTG::Reading::Candidate.new(entry:, evidence:, name_rank:, strong_name:, **rest)
  end

  def reading(*candidates, finish_hint: nil)
    instance_double(MTG::Reading, candidates:, finish_hint:, collector_line: Struct.new(:set_code, :number).new("mom", "123"))
  end

  describe ".state_of" do
    let(:entry) { printing("mom", "123") }

    it "names the band state of a candidate", :aggregate_failures do
      expect(described_class.state_of(candidate(entry, %i[collector_line]))).to eq(:collector_line)
      expect(described_class.state_of(candidate(entry, %i[name collector_line_corrected]))).to eq(:collector_line_corrected)
      expect(described_class.state_of(candidate(entry, %i[art], artwork_id: "a", art_unique: true))).to eq(:art)
      expect(described_class.state_of(candidate(entry, %i[art], artwork_id: "a", art_unique: false))).to eq(:guess)
      expect(described_class.state_of(candidate(entry, %i[name], strong_name: true))).to eq(:guess)
      expect(described_class.state_of(candidate(entry, %i[name]))).to eq(:unsure)
    end
  end

  describe ".for_reading when sure of the card" do
    let!(:matched) { printing("mom", "123") }
    let!(:others) { [ printing("m10", "146"), printing("2x2", "117") ] }
    subject(:selection) { described_class.for_reading(reading(candidate(matched, %i[collector_line])), key:) }

    it "holds the matched printing first, then the card's other printings, and counts them all", :aggregate_failures do
      expect(selection.kind).to eq(:printings)
      expect(selection.items.map(&:entry).first).to eq(matched)
      expect(selection.items.map(&:entry)).to match_array([ matched, *others ])
      expect(selection.total).to eq(3)
      expect(selection.current).to eq(0)
      expect(selection.more).to eq(0)
    end

    it "gives the first item the evidence's band and rank 1, the others 'Not the printing that was read'", :aggregate_failures do
      expect(selection.items.first.band).to have_attributes(form: :success, icon: :check, sentence: "Matched by its collector line")
      expect(selection.items.first.rank).to eq(1)
      expect(selection.items.drop(1).map { it.band.sentence }.uniq).to eq([ "Not the printing that was read" ])
      expect(selection.items.drop(1).map(&:rank)).to all(be_nil)
    end

    it "does not hold the other candidate cards", :aggregate_failures do
      other_card = printing("m21", "1", identity: create(:catalog_identity, name: "Lightning Blast"))
      selection = described_class.for_reading(reading(candidate(matched, %i[name], strong_name: true), candidate(other_card, %i[name], name_rank: 1)), key:)
      expect(selection.items.map(&:entry)).not_to include(other_card)
      expect(selection.items.first.band.sentence).to eq("Printing not confirmed. Swipe to check.")
    end

    it "puts the read set first among the others (the Other printings order)" do
      selection = described_class.for_card(identity:, match: matched, state: "guess", key:, set: "2x2")
      expect(selection.items.map { it.entry.set.code }.first(2)).to eq(%w[mom 2x2])
    end
  end

  describe ".for_reading when not sure of the card" do
    it "holds the candidate cards, ranked, each with its own printing's state for 'All printings'", :aggregate_failures do
      first = printing("mom", "123")
      second = printing("m21", "1", identity: create(:catalog_identity, name: "Lightning Blast"))
      selection = described_class.for_reading(reading(candidate(first, %i[name]), candidate(second, %i[name], name_rank: 1)), key:)
      expect(selection.kind).to eq(:cards)
      expect(selection.items.map(&:entry)).to eq([ first, second ])
      expect(selection.items.map(&:rank)).to eq([ 1, 2 ])
      expect(selection.items.map { it.band.sentence }.uniq).to eq([ "Not sure of this card. Check it against your capture." ])
      expect(selection.items.map { it.band.icon }.uniq).to eq([ :question ])
      expect(selection.items.map(&:state)).to eq(%i[guess guess])
      expect(selection.total).to eq(2)
    end
  end

  describe ".for_card" do
    let!(:matched) { printing("mom", "123") }

    before { 24.times { |i| printing("s#{i}", i.to_s) } }

    it "shows 20 printings and a count of the rest, keeping the position's total", :aggregate_failures do
      selection = described_class.for_card(identity:, match: matched, state: "collector_line", key:)
      expect(selection.items.size).to eq(20)
      expect(selection.total).to eq(25)
      expect(selection.more).to eq(5)
      expect(selection.limit).to eq(20)
    end

    it "shows more at a raised limit, centred on the named printing, clamped to 20..200", :aggregate_failures do
      named = described_class.for_card(identity:, match: matched, state: "guess", key:).items.last.entry
      selection = described_class.for_card(identity:, match: matched, state: "guess", key:, limit: 40, current: named.external_key)
      expect(selection.items.size).to eq(25)
      expect(selection.more).to eq(0)
      expect(selection.current).to eq(19)
      expect(described_class.for_card(identity:, match: matched, state: "guess", key:, limit: 5).limit).to eq(20)
      expect(described_class.for_card(identity:, match: matched, state: "guess", key:, limit: 21).limit).to eq(40)
      expect(described_class.for_card(identity:, match: matched, state: "guess", key:, limit: [ "x" ]).limit).to eq(20)
      expect(described_class.for_card(identity:, match: matched, state: "guess", key:, limit: 9_999).limit).to eq(200)
    end

    it "treats a band state outside the closed list as a guess" do
      selection = described_class.for_card(identity:, match: matched, state: "<script>", key:)
      expect(selection.items.first.band.sentence).to eq("Printing not confirmed. Swipe to check.")
    end
  end
end
```

- [ ] Run `bin/rspec spec/models/scanner/selection_spec.rb` — expect FAIL (uninitialized constant `Scanner::Selection`).
- [ ] Create `app/models/scanner/selection.rb`:

```ruby
# What the scanner's selection pane shows for one reading (spec 088 decisions 2 to 4, 15): the items of the swipe row, each
# with the status band it reads, as the server renders them. Two kinds. When the scanner is sure of the card the row is its
# printings, the matched one first and then the others in `Scanner::OtherPrintings` order, the first `STEP` of them; when it
# is not sure it is the candidate cards, one printing each, and a card's own printings are one tap away (`for_card`). It ranks
# nothing and reads nothing: it takes a reading's candidates as ranked (their evidence predicates: `collector_line?`,
# `corrected?`, `art?`, `art_unique`, `card_sure?`) and the printings as `OtherPrintings` orders them, and it names no
# collectible (`spec/scanner_sitting_core_spec.rb`).
#
# @example the answer to a reading
#   selection = Scanner::Selection.for_reading(reading, key: key)
#   selection.items.first.band.sentence # => "Matched by its collector line"
class Scanner::Selection
  # A status band's content: form (:success or :warning), the icon partial's name and the sentence.
  Band = Data.define(:form, :icon, :sentence)
  # One card of the row: its printing, the rank the add event records (nil for "other"), its band and the band state its
  # printing would have if the collector chose its card ("All printings").
  Item = Data.define(:entry, :rank, :band, :state)

  BANDS = {
    collector_line: Band.new(:success, :check, "Matched by its collector line"),
    collector_line_corrected: Band.new(:success, :check, "Matched by its collector line, one digit corrected"),
    art: Band.new(:success, :check, "Matched by its artwork"),
    guess: Band.new(:warning, :alert, "Printing not confirmed. Swipe to check."),
    unsure: Band.new(:warning, :question, "Not sure of this card. Check it against your capture."),
    other: Band.new(:warning, :alert, "Not the printing that was read")
  }.freeze
  # The states a printings row's first item may have, a closed list: a request's `band` outside it is a guess.
  PRINTING_STATES = %i[collector_line collector_line_corrected art guess].freeze
  # Printings loaded at once, and per "Show 20 more" (spec 088 decision 4; the existing Other printings constant).
  STEP = Scanner::OtherPrintings::SHOWN
  # The most printings a row ever holds (a basic land has more English printings than that).
  MAX = 200

  attr_reader :kind, :items, :total, :current, :limit, :key, :finish_hint, :set, :number, :artwork, :identity, :match, :state

  # The band state of a reading's first candidate: the evidence when its printing is confirmed, a guess when the card is
  # sure and the printing is not, else :unsure.
  #
  # @param candidate [#collector_line?, #corrected?, #art?, #art_unique, #card_sure?] a ranked candidate
  # @return [Symbol] one of :collector_line, :collector_line_corrected, :art, :guess, :unsure
  def self.state_of(candidate)
    printing_state_of(candidate, sure: candidate.card_sure?) || :unsure
  end

  # The band state of a printing whose card the collector has chosen ("All printings"): the evidence when its printing is
  # confirmed, else a guess, never :unsure.
  #
  # @param candidate [#collector_line?, #corrected?, #art?, #art_unique] a ranked candidate
  # @param sure [Boolean] whether the card is trusted; false returns nil for a printing that is not confirmed
  # @return [Symbol, nil]
  def self.printing_state_of(candidate, sure: true)
    if candidate.collector_line? then candidate.corrected? ? :collector_line_corrected : :collector_line
    elsif candidate.art? && candidate.art_unique then :art
    elsif sure then :guess
    end
  end

  # The selection a reading's answer renders.
  #
  # @param reading [#candidates, #finish_hint, #collector_line] a resolved reading with at least one candidate
  # @param key [String] the reading's key
  # @return [Scanner::Selection]
  def self.for_reading(reading, key:)
    first = reading.candidates.first
    context = { key:, finish_hint: reading.finish_hint, set: reading.collector_line.set_code, number: reading.collector_line.number }
    state = state_of(first)
    if state == :unsure
      items = reading.candidates.each_with_index.map do |candidate, index|
        Item.new(entry: candidate.entry, rank: index + 1, band: BANDS.fetch(:unsure), state: printing_state_of(candidate) || :guess)
      end
      new(kind: :cards, items:, total: items.size, current: 0, limit: STEP, **context)
    else
      for_card(identity: first.entry.identity, match: first.entry, state:, artwork: first.artwork_id, first_rank: 1, **context)
    end
  end

  # One card's printings, `match` first: the answer to the reading, to "All printings" and to "Show 20 more".
  #
  # @param identity [Catalog::Identity] the card
  # @param match [Catalog::Entry] the printing that goes first, one of the card's
  # @param state [String, Symbol] the band state of that printing; outside `PRINTING_STATES` it is :guess
  # @param limit [Integer, String] how many printings to render, clamped to `STEP`..`MAX`
  # @param current [String, nil] the external key of the printing to centre
  # @param first_rank [Integer, nil] the rank the first item's add event records
  # @return [Scanner::Selection]
  def self.for_card(identity:, match:, state:, key:, set: nil, number: nil, finish_hint: nil, artwork: nil, limit: STEP, current: nil, first_rank: nil)
    state = PRINTING_STATES.find { it.to_s == state.to_s } || :guess
    limit = (limit.to_s.to_i + STEP - 1).then { it / STEP * STEP }.clamp(STEP, MAX) # a multiple of STEP; arrays and junk read as 0
    others = Scanner::OtherPrintings.new(identity:, set_code: set, number:, artwork:).entries.reject { it.id == match.id }
    ordered = [ match, *others ]
    items = ordered.first(limit).each_with_index.map do |entry, index|
      index.zero? ? Item.new(entry:, rank: first_rank, band: BANDS.fetch(state), state:) : Item.new(entry:, rank: nil, band: BANDS.fetch(:other), state: :guess)
    end
    new(kind: :printings, items:, total: ordered.size, current: (items.index { it.entry.external_key == current } if current) || 0, limit:,
      key:, finish_hint:, set:, number:, artwork:, identity:, match:, state:)
  end

  def initialize(kind:, items:, total:, current:, limit:, key:, finish_hint: nil, set: nil, number: nil, artwork: nil, identity: nil, match: nil, state: nil)
    @kind, @items, @total, @current, @limit = kind, items, total, current, limit
    @key, @finish_hint, @set, @number, @artwork = key, finish_hint, set, number, artwork
    @identity, @match, @state = identity, match, state
  end

  # Printings not rendered yet (the row's "more" item); always 0 for a cards row.
  #
  # @return [Integer]
  def more = kind == :printings ? total - items.size : 0

  # Whether the row ends with a "more printings" item.
  #
  # @return [Boolean]
  def more? = more.positive?

  # The row's items, with the more item when there is one: Previous and Next step through this many.
  #
  # @return [Integer]
  def count = items.size + (more? ? 1 : 0)

  # The query of the selection frame's request for this card (`GET /scanner/printings`), with the given params merged in.
  #
  # @param extra [Hash] params that replace or add to the card's
  # @return [Hash{Symbol => String, Integer}] only the params that have a value
  def link_params(**extra)
    { card: identity.external_key, key:, set:, number:, finish_hint:, artwork:, match: match.external_key, band: state, limit: }.compact.merge(extra)
  end

  # The query that opens a possible card's own printings ("All printings"): that printing first, its band by its own evidence.
  #
  # @param item [Item] a possible card's item
  # @return [Hash{Symbol => String, Integer}]
  def printings_params(item)
    { card: item.entry.identity.external_key, key:, set:, number:, finish_hint:, match: item.entry.external_key, band: item.state, limit: STEP }.compact
  end
end
```

- [ ] Run `bin/rspec spec/models/scanner/selection_spec.rb` — expect PASS. Commit: `feat(scanner): the selection a reading's answer is built from (spec 088)`.

### Task 3: request specs for the answers (failing)

- [ ] Replace `spec/requests/scanner/readings_spec.rb`'s examples that expect the old result (the three above at the top, and every one that mentions "What the scanner read", "Candidates", "Matched one printing", `.c-scanner__candidate`, "Other printings", "Matched by its name", "Artwork looks similar" or the overrule sentence) with the examples below; keep the examples about the key, length, tenancy/sign-in, measurement recording and artwork parsing, changing only the expectations that named the old markup. The new examples (inside the existing `context "when the name index is built"`, which builds the index):

```ruby
    def pane = Nokogiri::HTML5(response.body)

    it "answers a collector-line match with a selection frame of its printings, the match first, success band in the first panel (AC-2.1, AC-3.1)", :aggregate_failures do
      read("Lightnlng Bo1t", "R 0123\nMOM • EN")
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="update" target="scanner_result">')
      expect(pane.css("turbo-frame#scanner_selection.c-scanpane__body").size).to eq(1)
      items = pane.css(".c-scanpane__item")
      expect(items.first["aria-current"]).to eq("true")
      expect(items.drop(1).map { it["aria-current"] }.uniq).to eq([ nil ])
      panels = pane.css(".c-scanpane__card")
      expect(panels.map { it["hidden"] }).to eq([ nil, *Array.new(panels.size - 1, "hidden") ])
      template = panels.first.at_css("template[data-band]")
      expect(template["data-band"]).to eq("c-band--success")
      expect(template.inner_html).to include("Matched by its collector line", "Printing 1 of 1: Lightning Bolt, March of the Machine, MOM · 123.")
      expect(panels.first.at_css(".c-scanpane__position").text).to eq("1 of 1 printing")
      expect(response.body).not_to include("What the scanner read", "c-scanner__candidate", "scanner_printings")
    end

    it "marks a name-only match of the right card as a printing guess (AC-2.2)", :aggregate_failures do
      read("Lightning Bolt", "")
      template = pane.at_css(".c-scanpane__card template[data-band]")
      expect(template["data-band"]).to eq("c-band--warning")
      expect(template.inner_html).to include("Printing not confirmed. Swipe to check.")
      expect(response.body).not_to include("Matched by its name")
    end

    it "reads 'Lightning' as a name-only, not strong match, so the system examples that draw it get the possible-cards row (execution note)", :aggregate_failures do
      read("Lightning", "")
      template = pane.at_css(".c-scanpane__card template[data-band]")
      expect(template.inner_html).to include("Not sure of this card. Check it against your capture.")
      expect(pane.css(".c-scanpane__row").first.ancestors(".c-scanpane__rowwrap").first["aria-label"]).to eq("Possible cards")
    end

    it "gives every panel one add button per finish, named for the printing, with the star on a special finish (AC-4.2)", :aggregate_failures do
      MTG::Printing.find_by!(catalog_entry_id: bolt.id).update!(finishes: %w[nonfoil foil])
      read("Lightning Bolt", "R 0123\nMOM • EN")
      forms = pane.css(".c-scanpane__card:not([hidden]) .c-scanpane__add")
      expect(forms.map { it.at_css("button").text.strip }).to eq([ "Add nonfoil", "Add foil" ])
      expect(forms.map { it.at_css("button")["aria-label"] }).to eq([ "Add Lightning Bolt MOM · 123 Nonfoil", "Add Lightning Bolt MOM · 123 Foil" ])
      expect(forms.map { it["data-turbo-frame"] }.uniq).to eq([ "_top" ])
      expect(forms.map { it.css("svg").size }).to eq([ 0, 1 ])
    end

    it "relabels the foil button when the foil marker was read, and adds nothing more (AC-4.3)" do
      MTG::Printing.find_by!(catalog_entry_id: bolt.id).update!(finishes: %w[nonfoil foil])
      read("Lightning Bolt", "R 0123\nMOM ★ EN")
      forms = pane.css(".c-scanpane__card:not([hidden]) .c-scanpane__add")
      expect(forms.map { it.at_css("button").text.strip }).to eq([ "Add nonfoil", "Add foil · read from the card" ])
    end

    it "writes a card named with markup as text everywhere the answer says it (AC-6.3)", :aggregate_failures do
      bolt.update!(name: "Bolt <script>alert(1)</script>")
      read("Lightning Bolt", "R 0123\nMOM • EN")
      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
    end

    it "says 'Nothing could be read' on the status line and opens no pane (AC-6.1)", :aggregate_failures do
      read("", "")
      expect(response.body).to include('<turbo-stream action="update" target="scanner_status_text">', "Nothing could be read. Line the card up with the guide and capture it again.")
      expect(response.body).not_to include('target="scanner_result"', 'target="status"')
    end

    it "says 'No card matches' on the status line when text was read and nothing matches (AC-6.1)", :aggregate_failures do
      read("Zzzzzzzz Qqqqqq", "")
      expect(response.body).to include('target="scanner_status_text"', "No card matches what was read. Line the card up with the guide and capture it again.")
    end
```
  and, in the `context` where the name index is empty (the existing "catalog isn't ready" example) expect: `include('target="status"', "c-status__message--alert")` and `CGI.unescapeHTML(response.body)` to `include("The card catalog isn't ready yet")` (the status partial escapes the apostrophe, as `sitting_entries_spec.rb:97` reads it) and `not_to include('target="scanner_result"')`; in the examples for a too-long text and a malformed key expect the 422 body to include `target="status"` and the sentence in the alert style, and `not_to include('target="scanner_result"')`.

- [ ] In the same file add an example for a sure-of-the-card reading with an unrelated second candidate, expecting the second card not in `.c-scanpane__item` names, and one for a not-sure reading (a name that is not strong with no collector line: `read("Lightnlng Bo1t", "")` scores about 0.94, under the 0.96 threshold) expecting `.c-scanpane__position` text "1 of 1 possible card" or "1 of 2 possible cards" per the data, the question-mark band (`template.inner_html` includes "Not sure of this card. Check it against your capture."), the row group named "Possible cards" and an "All printings" link per panel whose `href` carries `match=` and `band=guess`.
- [ ] Rewrite `spec/requests/scanner/printings_spec.rb` for the selection frame request. Keep, adapted to the new markup (items and panels instead of list rows), the file's examples about the order by read set and number, the artwork's printings first, `finish_hint` and an invalid artwork id being ignored (decision 15 keeps them "as today"), and add these (setup: one card with 25 printings as in the Selection spec; sign in as a user):

```ruby
require "rails_helper"

RSpec.describe "The scanner's selection frame", type: :request do
  let(:key) { "f" * 32 }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let!(:matched) { create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom", name: "March of the Machine"), number: "123")).entry }

  before do
    24.times { |i| create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "s#{i}", name: "Set #{i}"), number: i.to_s)) }
    sign_in_as(create(:user))
  end

  def frame(**params)
    get scanner_printings_path(card: identity.external_key, key:, match: matched.external_key, band: "guess", **params), headers: { "Turbo-Frame" => "scanner_selection" }
    Nokogiri::HTML5(response.body)
  end

  it "answers the card's printings in the selection frame, the named one first, 20 at a time with a more item (AC-3.1, AC-3.10)", :aggregate_failures do
    page = frame
    expect(response).to have_http_status(:ok)
    expect(page.css("turbo-frame#scanner_selection .c-scanpane__item").size).to eq(21) # 20 and the more item
    expect(page.at_css(".c-scanpane__item--more").text).to include("5 more printings")
    expect(page.at_css(".c-scanpane__card:not([hidden]) .c-scanpane__position").text).to eq("1 of 25 printings")
    expect(page.at_css(".c-scanpane__row")["data-selection-focus"]).to eq("true")
    more = page.css(".c-scanpane__card").last.at_css("a.c-btn")
    expect(more.text).to eq("Show 20 more")
    expect(more["href"]).to include("limit=40", "current=")
  end

  it "answers every printing at a raised limit, centred on the current one (AC-3.10)", :aggregate_failures do
    current = Catalog::Entry.where(catalog_identity_id: identity.id).order(:id).last.external_key
    page = frame(limit: 40, current:)
    expect(page.css(".c-scanpane__item--more")).to be_empty
    expect(page.css(".c-scanpane__item").size).to eq(25)
    expect(page.css(".c-scanpane__item").map { it["aria-current"] }.compact.size).to eq(1)
  end

  it "reads a band outside the closed list as a guess (decision 15)" do
    frame(band: "<b>x</b>")
    expect(response.body).to include("Printing not confirmed. Swipe to check.")
    expect(response.body).not_to include("<b>x</b>")
  end

  it "answers 404 for a malformed key or an unknown card, as before", :aggregate_failures do
    get scanner_printings_path(card: identity.external_key, key: "nope"), headers: { "Turbo-Frame" => "scanner_selection" }
    expect(response).to have_http_status(:not_found)
    get scanner_printings_path(card: "missing", key:), headers: { "Turbo-Frame" => "scanner_selection" }
    expect(response).to have_http_status(:not_found)
  end

  it "needs a sign-in" do
    delete session_path
    get scanner_printings_path(card: identity.external_key, key:)
    expect(response).to redirect_to(new_session_path)
  end
end
```

- [ ] Run `bin/rspec spec/requests/scanner/readings_spec.rb spec/requests/scanner/printings_spec.rb` — expect FAIL (the old views answer).
- [ ] Commit: `test(scanner): specify the selection pane's answers (spec 088)`.

---

## Phase 1: The server renders the selection

**Implements:** FR-1 | **Satisfies:** AC-2.1 to AC-2.6, AC-3.1, AC-3.8, AC-3.9, AC-3.10, AC-4.1 to AC-4.3, AC-6.1 to AC-6.3, AC-8.1 (markup)
**Files:** `app/views/scanners/_selection.html.erb`, `_item.html.erb`, `_more_item.html.erb`, `_panel.html.erb`, `_more_panel.html.erb`, `_band_content.html.erb`, `_add_buttons.html.erb`, `app/views/scanner/printings/index.html.erb`, `app/views/icons/_question.html.erb`, `_chevron_right.html.erb`, `app/helpers/scanners_helper.rb`, `app/controllers/scanner/readings_controller.rb`, `printings_controller.rb`, `spec/helpers/scanners_helper_spec.rb`
**Interfaces:** Consumes: `Scanner::Selection` (Task 2): `kind`, `items` (`Item#entry/rank/band/state`), `total`, `current`, `limit`, `more`, `more?`, `count`, `key`, `finish_hint`, `link_params(**extra)`, `printings_params(item)`. Produces: the frame markup the `selection` controller reads: `turbo-frame#scanner_selection.c-scanpane__body` holding `.c-scanpane__rowwrap[role=group]` > `ul.c-scanpane__row[data-selection-target=row]` of `li.c-scanpane__item[data-selection-target=item]`, `button[data-selection-target=prev|next]`, then one `.c-scanpane__card[data-selection-target=panel]` per item (each holding `template[data-band]`); helpers `selection_tail(selection, index)`, `selection_position(selection, index)`.

The row and its panels are one frame the server renders whole (decision 4); the readings answer and the frame request render the same partial.

### Task 4: partials, helpers and icons

- [ ] Add the icons. `app/views/icons/_question.html.erb`:

```erb
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3M12 17h.01"/></svg>
```

`app/views/icons/_chevron_right.html.erb`:

```erb
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m9 18 6-6-6-6"/></svg>
```

- [ ] In `app/helpers/scanners_helper.rb` remove `COLLECTOR_OUTCOMES`, `collector_outcome`, `ART_OUTCOMES`, `scanner_art_outcome` and `scanner_overrule_note`, delete their three examples in `spec/helpers/scanners_helper_spec.rb`, and add (with its example in that spec, test first: `helper.selection_tail(selection, 1)` against a `Scanner::Selection` built as in Task 2's spec):

```ruby
  # The visually hidden tail of a band sentence, naming the centred card so the band's text changes with every swipe and is
  # announced each time (spec 088 decision 8): "Printing 2 of 14: Lightning Bolt, Double Masters 2022, 2X2 · 117." The more item
  # (index past the items) says what it offers instead.
  #
  # @param selection [Scanner::Selection]
  # @param index [Integer] the item's place in the row
  # @return [String]
  def selection_tail(selection, index)
    return "#{pluralize(selection.more, "more printing")}. Show 20 more." if index >= selection.items.size

    entry = selection.items[index].entry
    noun = selection.kind == :cards ? "Card" : "Printing"
    "#{noun} #{index + 1} of #{selection.total}: #{entry.display_name}, #{entry.set.name}, #{set_number(entry)}."
  end

  # "2 of 14 printings", "1 of 3 possible cards": the details block's position (design decision 15).
  #
  # @param selection [Scanner::Selection]
  # @param index [Integer] the item's place in the row
  # @return [String]
  def selection_position(selection, index)
    noun = selection.kind == :cards ? "possible card" : "printing"
    "#{index + 1} of #{pluralize(selection.total, noun)}"
  end
```

- [ ] Write the partials. `app/views/scanners/_band_content.html.erb` (what the band holds; the `template` and the controller's copy use it):

```erb
<%# locals: (band:, tail:) %>
<%# The band's icon and sentence, then the visually hidden tail naming the centred card (spec 088 decision 8). %>
<%= render "icons/#{band.icon}" %><span><%= band.sentence %><span class="c-sr"><%= band.sentence.end_with?(".") ? " " : ". " %><%= tail %></span></span>
```

`app/views/scanners/_selection.html.erb`:

```erb
<%# locals: (selection:, focus: false) %>
<%# The selection (spec 088 decisions 3, 4, 15): the swipe row of card images and one panel per image, as one Turbo Frame the server
    renders whole; the `selection` controller notes which is centred. `focus` (a frame request) asks it to put focus on Next. %>
<%= turbo_frame_tag "scanner_selection", class: "c-scanpane__body" do %>
  <% cards = selection.kind == :cards %>
  <div class="c-scanpane__rowwrap" role="group" aria-label="<%= cards ? "Possible cards" : "Printings" %>">
    <%= tag.ul class: "c-scanpane__row", tabindex: 0,
          data: { selection_target: "row", selection_focus: (focus || nil), action: "scroll->selection#scrolled keydown->selection#key click->selection#tap" } do %>
      <% selection.items.each_with_index do |item, index| %>
        <%= render "scanners/item", item:, current: index == selection.current %>
      <% end %>
      <%= render("scanners/more_item", selection:) if selection.more? %>
    <% end %>
    <%= tag.button type: "button", class: "c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--prev", "aria-label": (cards ? "Previous card" : "Previous printing"),
          disabled: selection.current.zero?, data: { selection_target: "prev", action: "selection#previous" } do %><%= render "icons/back" %><% end %>
    <%= tag.button type: "button", class: "c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--next", "aria-label": (cards ? "Next card" : "Next printing"),
          disabled: selection.current == selection.count - 1, data: { selection_target: "next", action: "selection#next" } do %><%= render "icons/chevron_right" %><% end %>
  </div>
  <% selection.items.each_with_index do |item, index| %>
    <%= render "scanners/panel", selection:, item:, index: %>
  <% end %>
  <%= render("scanners/more_panel", selection:) if selection.more? %>
<% end %>
```

`app/views/scanners/_item.html.erb`:

```erb
<%# locals: (item:, current:) %>
<% entry = item.entry %>
<%= tag.li class: "c-scanpane__item", aria: { current: ("true" if current) }, data: { selection_target: "item" } do %>
  <% if (image = catalog_url(entry.image_url)) %>
    <%= image_tag image, alt: "#{entry.display_name}, #{entry.set.name}, #{set_number(entry)}", loading: "lazy", width: 206, height: 288 %>
  <% else %>
    <div class="c-scanpane__missing"><strong><%= entry.display_name %></strong><span><%= set_number(entry) %></span></div>
  <% end %>
<% end %>
```

`app/views/scanners/_more_item.html.erb`:

```erb
<%# locals: (selection:) %>
<li class="c-scanpane__item c-scanpane__item--more" data-selection-target="item"><div class="c-scanpane__missing"><strong><%= pluralize(selection.more, "more printing") %></strong></div></li>
```

`app/views/scanners/_panel.html.erb`:

```erb
<%# locals: (selection:, item:, index:) %>
<%# One card's panel (spec 088 decisions 3, 5, 10): the band it makes the pane show, the details block and one add per finish. Hidden
    unless it is the centred card's. In a possible-cards row it also offers "All printings", which navigates the frame. %>
<% entry = item.entry %>
<%= tag.div class: "c-scanpane__card", hidden: index != selection.current, data: { selection_target: "panel" } do %>
  <template data-band="c-band--<%= item.band.form %>"><%= render "scanners/band_content", band: item.band, tail: selection_tail(selection, index) %></template>
  <div class="c-scanpane__details">
    <h2 class="c-scanpane__name"><%= entry.display_name %></h2>
    <p class="c-scanpane__set"><%= entry.set.name %></p>
    <p class="c-scanpane__meta<%= " c-scanpane__meta--cards" if selection.kind == :cards %>">
      <span class="c-tag"><%= set_number(entry) %></span>
      <% if entry.released_on && selection.kind == :printings %><span><%= entry.released_on.year %></span><% end %>
      <span class="c-scanpane__position"><%= selection_position(selection, index) %></span>
      <% if selection.kind == :cards %>
        <%= link_to "All printings", scanner_printings_path(selection.printings_params(item)), class: "c-btn c-btn--ghost c-btn--sm",
              data: { turbo_frame: "scanner_selection", failure_message: "The card's printings couldn't be loaded. Tap “All printings” again.", action: "scanner-reading#remember" } %>
      <% end %>
    </p>
  </div>
  <div class="c-scanpane__adds"><%= render "scanners/add_buttons", printing: entry, key: selection.key, finish_hint: selection.finish_hint, rank: item.rank || "other" %></div>
<% end %>
```

`app/views/scanners/_more_panel.html.erb`:

```erb
<%# locals: (selection:) %>
<%# The "more printings" item's panel (spec 088 decision 4): it keeps the last item's band and offers the rest. `current` names the printing
    before it, so the frame renders again with that card centred. %>
<% last = selection.items.last %>
<% index = selection.items.size %>
<%= tag.div class: "c-scanpane__card", hidden: true, data: { selection_target: "panel" } do %>
  <template data-band="c-band--<%= last.band.form %>"><%= render "scanners/band_content", band: last.band, tail: selection_tail(selection, index) %></template>
  <div class="c-scanpane__details">
    <h2 class="c-scanpane__name"><%= selection.identity.name %></h2>
    <p class="c-scanpane__set"><%= pluralize(selection.more, "more printing") %></p>
    <p class="c-scanpane__meta"></p>
  </div>
  <div class="c-scanpane__adds">
    <div class="c-scanpane__add">
      <%= link_to "Show 20 more",
            scanner_printings_path(selection.link_params(limit: selection.limit + Scanner::Selection::STEP, current: last.entry.external_key)),
            class: "c-btn c-btn--secondary", data: { turbo_frame: "scanner_selection", failure_message: "More printings couldn't be loaded. Tap “Show 20 more” again.", action: "scanner-reading#remember" } %>
    </div>
  </div>
<% end %>
```

`app/views/scanners/_add_buttons.html.erb` (replace):

```erb
<%# locals: (printing:, key:, finish_hint:, rank:) %>
<%# One add button per finish the printing comes in; "Add" alone for one finish or none listed (spec 088 decision 10, spec 080 decision 11).
    A special finish carries the star; the foil marker read off the card relabels its button and nothing more (spec 009 AC-6.5); the
    accessible name stays "Add ‹card› ‹SET · number› ‹finish›", so it never depends on how the separator was read. The forms sit in the
    selection frame and answer as a page (`_top`): an ended session's redirect is a visit, an add's answer is a Turbo Stream. %>
<% vocabulary = Catalog.collecting_for(printing.collectible_type) %>
<% finishes = vocabulary.finishes_for(printing).presence || [ nil ] %>
<% finishes.each do |finish| %>
  <% name = finish && vocabulary.finish_label(finish) %>
  <% hinted = finish.present? && finish == finish_hint %>
  <% label = if hinted then "Add #{name.downcase} · read from the card" elsif finishes.one? then "Add" else "Add #{name.downcase}" end %>
  <%= button_to scanner_sitting_entries_path, params: { entry: { printing: printing.external_key, finish: finish.to_s, reading_key: key } },
        class: "c-btn c-btn--secondary", form: { class: "c-scanpane__add", data: { turbo_frame: "_top", scanner_event: "add", rank: } },
        "aria-label": [ "Add", printing.name, set_number(printing), name ].compact.join(" ") do %>
    <%= render "icons/star" if finish && vocabulary.special_finishes.include?(finish) %><%= label %>
  <% end %>
<% end %>
```

- [ ] Run `bin/rspec spec/helpers/scanners_helper_spec.rb` — PASS. Commit: `feat(scanner): the selection's partials, helpers and icons (spec 088)`.

### Task 5: the controllers answer with the selection

- [ ] Rewrite `app/controllers/scanner/readings_controller.rb`:

```ruby
# Turns what was read off a card into what the page shows (spec 007 Story 3, spec 088 decisions 2 to 4, 11): a selection of the
# card's printings or of the candidate cards, or a sentence on the status line when nothing could be read or no card matches.
# Only the text, the page's reading key and a live capture's nearest artworks (ids and distances, spec 011 FR-5) arrive here; the
# photo and its fingerprint never leave the device.
class Scanner::ReadingsController < ApplicationController
  TOO_LONG = "That reading was too long to use. Line the card up with the guide and capture it again.".freeze
  NO_KEY = "That reading couldn't be used. Capture the card again.".freeze
  NOTHING_READ = "Nothing could be read. Line the card up with the guide and capture it again.".freeze
  NO_MATCH = "No card matches what was read. Line the card up with the guide and capture it again.".freeze
  CATALOG_NOT_READY = "The card catalog isn't ready yet. Once it has loaded, scan the card again.".freeze

  def create
    attributes = params.expect(reading: %i[name_text collector_text key])
    reading = MTG::Reading.new(attributes.slice(:name_text, :collector_text))
    reading.artworks = MTG::Art::Sent.from_params(params) # read leniently: never fails the request (spec 011 AC-6.1)
    key = attributes[:key].to_s
    if !Scanner::Sitting::KEY_FORMAT.match?(key) then refuse(NO_KEY)
    elsif reading.valid?
      render turbo_stream: answer(reading.resolve, key)
      record_measurement(key, reading)
    else refuse(TOO_LONG)
    end
  end

  private
    # The streams that answer a resolved reading. A refusal that opens the pane is a visible alert in its region and leaves
    # `#scanner_result` empty; nothing read or no match is the status line's sentence and opens no pane (spec 088 decision 11).
    def answer(reading, key)
      if !reading.catalog_ready? then [ alert_in_pane(CATALOG_NOT_READY) ]
      elsif reading.candidates.empty?
        [ turbo_stream.update("scanner_status_text", ERB::Util.html_escape(reading.nothing_read? ? NOTHING_READ : NO_MATCH)) ]
      else
        [ turbo_stream.update("scanner_result", partial: "scanners/selection", locals: { selection: Scanner::Selection.for_reading(reading, key:) }) ]
      end
    end

    # Development measurement mode only (spec 011 AC-9.3): never fails or changes the answer.
    def record_measurement(key, reading)
      Scanner::MeasurementRun.current(framing: Scanner::MeasurementRun.framing_in(session))&.record_reading!(key, reading)
    rescue StandardError => error
      Rails.logger.warn("scanner.measurement reading not recorded: #{error.class}: #{error.message}")
    end

    def alert_in_pane(message)
      turbo_stream.update("status", partial: "shared/status_message", locals: { message:, alert: true })
    end

    def refuse(message)
      render turbo_stream: alert_in_pane(message), status: :unprocessable_content
    end
end
```

- [ ] Rewrite `app/controllers/scanner/printings_controller.rb`:

```ruby
# The selection frame for one card (spec 088 decisions 3, 4, 15; reworks spec 009 Story 2's Other printings): its printings with
# one first, 20 at a time, for "All printings" from a possible-cards row and "Show 20 more". The same partial the reading's answer
# renders, so the camera and the scanner stay on the page. Params: card (the identity's external key), key (the reading key),
# set, number, finish_hint, artwork (as the reading's candidates carry them), match (the printing that goes first), band (its
# band state, a closed list), limit and current (the printing to centre).
class Scanner::PrintingsController < ApplicationController
  def index
    key = params.expect(:key)
    return head(:not_found) unless Scanner::Sitting::KEY_FORMAT.match?(key)

    identity = Catalog::Identity.where(collectible_type: MTG::Reading::COLLECTIBLE_TYPE).find_by!(external_key: params.expect(:card))
    artwork = params[:artwork].to_s[MTG::Art::Sent::ID] # an invalid or unknown id is ignored (spec 011 AC-7.5)
    match = identity.entries.includes(:set).find_by(external_key: params[:match].to_s) ||
      Scanner::OtherPrintings.new(identity:, set_code: params[:set], number: params[:number], artwork:).entries.first
    return head(:not_found) unless match

    Catalog::Entry.preload_extensions([ match ])
    @selection = Scanner::Selection.for_card(identity:, match:, state: params[:band], key:, set: params[:set].to_s.presence, number: params[:number].to_s.presence,
      finish_hint: params[:finish_hint].to_s.presence, artwork:, limit: params[:limit], current: params[:current].to_s.presence)
  end
end
```

- [ ] Replace `app/views/scanner/printings/index.html.erb` with `<%= render "scanners/selection", selection: @selection, focus: true %>`; delete `app/views/scanner/printings/_printing.html.erb`, `app/views/scanners/_result.html.erb`, `app/views/scanners/_candidate.html.erb`.
- [ ] Run `bin/rspec spec/requests/scanner spec/helpers spec/models/scanner spec/models/mtg/reading/candidate_spec.rb` — expect PASS (fix any request example that still names the old markup, per Task 3's rule). Run `bin/rubocop -a app spec` and `bin/rails zeitwerk:check`.
- [ ] Commit: `feat(scanner): answer a reading with the selection frame (spec 088)`.

---

## Phase 2: The pane on the page

**Implements:** FR-2, FR-3 | **Satisfies:** AC-1.1 to AC-1.4, AC-2.4, AC-2.5, AC-3.2 to AC-3.7, AC-3.11, AC-4.4 to AC-4.6, AC-6.1, AC-6.2, AC-7.1 to AC-7.5, AC-8.1, AC-8.2
**Files:** `app/views/scanners/_scanner.html.erb`, `app/javascript/controllers/selection_controller.js`, `card_reader_controller.js`, `scanner_reading_controller.js`, `app/javascript/controllers/index.js` (only if controllers are registered by name), `app/assets/stylesheets/collector/additions.css`, `spec/system/scanner_selection_spec.rb`, `spec/system/scanner_result_spec.rb`, the other `spec/system/scanner_*_spec.rb`
**Interfaces:** Consumes: the frame markup of Phase 1 (`data-selection-target` = `row|item|panel|prev|next`, `data-selection-focus`, `template[data-band]` per panel, `data-action="scanner-reading#remember"` links with `data-failure-message`). Produces: `selection` Stimulus controller on `.c-scanpane` (targets `band`, `row`, `item`, `panel`, `prev`, `next`; actions `scrolled`, `key`, `tap`, `previous`, `next`); on `c-scan`: `card-reader` targets `strip`, `capture`, `readName`, `readLine`, `band`; `scanner-reading#remember`.

### Task 6: the pane's skeleton and the CSS (failing system spec first)

Before this task and Task 9, invoke the `collector-design-system` skill and read `docs/design-system/README.md` (CLAUDE.md requires it before any view, partial or stylesheet change).

- [ ] Write `spec/system/scanner_selection_spec.rb` (the shared setup and the first examples; later tasks add to it). Data: Lightning Bolt in three sets, a collector-line capture of the first:

```ruby
require "rails_helper"

# Spec 088: a capture's result as the selection pane: the strip, the band, the swipe row, the details block and one add per finish.
RSpec.describe "The selection pane", type: :system do
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  before do
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "m10", name: "Magic 2010"), number: "146"))
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "2x2", name: "Double Masters 2022"), number: "117"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
  end

  # The pane at rest: the answer is in and neither the rise nor the shrink is running. Task 8 adds the wait for the pane's hidden
  # "Done." sentence, which needs the reader's change.
  def wait_for_pane
    expect(page).to have_css(".c-scan--result .c-scanpane__item[aria-current='true']", wait: 30)
    eventually("document.getAnimations().every((animation) => animation.playState !== 'running')")
  end

  def capture_synthetic(frame: false)
    show_synthetic_card
    click_on "Capture"
    wait_for_pane
  end

  def band = find("#scanner_band")

  it "shows the capture beside what was read, the band, the row and the first panel (AC-1.1, AC-2.1, AC-3.1)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    expect(page).to have_css(".c-scan.c-scan--result .c-scan__strip .c-scan__read-name", text: "Lightning Bolt")
    expect(page).to have_css(".c-scan__read-line", text: /MOM/)
    expect(page.evaluate_script("[document.querySelector('.c-scan__capture').width, document.querySelector('.c-scan__capture').height]")).to eq([ 178, 248 ])
    expect(band).to have_css("svg").and have_text("Matched by its collector line")
    expect(band[:class]).to include("c-band--success")
    expect(page).to have_css(".c-scanpane__item", count: 3)
    expect(page).to have_css(".c-scanpane__item[aria-current='true']", count: 1)
    expect(page).to have_css(".c-scanpane__card:not([hidden])", count: 1)
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "1 of 3 printings")
    expect(page).to have_no_css(".c-scanpane__results, .c-scanner__candidate, #scanner_printings", visible: :all)
  end

  it "writes the reading's text as text (AC-1.2)" do
    visit scanner_path
    show_synthetic_card(name: "<b>Bolt</b>")
    click_on "Capture"
    wait_for_pane
    expect(page).to have_no_css(".c-scan__read-name b")
  end
end
```

- [ ] Run `bin/rspec spec/system/scanner_selection_spec.rb` — expect FAIL (no strip or band in the page).
- [ ] In `app/views/scanners/_scanner.html.erb`: (1) insert the strip before the pane, in the stage; (2) replace the pane block (`<div class="c-scanpane">…`) with the new pane. The strip:

```erb
    <div class="c-scan__strip" data-card-reader-target="strip">
      <canvas class="c-scan__capture" data-card-reader-target="capture" aria-hidden="true"></canvas>
      <div class="c-scan__read">
        <p class="c-scan__read-label">Read from the card</p>
        <p class="c-scan__read-name" data-card-reader-target="readName"></p>
        <p class="c-scan__read-line" data-card-reader-target="readLine"></p>
      </div>
    </div>
```

The pane (replacing the old one, `c-scanpane__results` and the failure block's name and collector rows go):

```erb
    <div class="c-scanpane" data-controller="selection">
      <p id="scanner_band" class="c-band" role="status" aria-live="polite" data-selection-target="band" data-card-reader-target="band"></p>
      <div id="status" class="c-scan__pane-status" role="status" aria-live="polite" data-card-reader-target="paneStatus" data-scan-shell-target="paneStatus"></div>
      <div class="c-scanner__failure" data-card-reader-target="failure" data-scan-shell-target="failure" hidden>
        <button type="button" class="c-btn c-btn--secondary" data-card-reader-target="resend" data-action="card-reader#resend">Send again</button>
        <%= link_to "Sign in", new_session_path, class: "c-btn c-btn--primary", data: { card_reader_target: "signIn", turbo: false }, hidden: true %>
      </div>
      <div id="scanner_result" class="c-scanpane__result" data-card-reader-target="result" data-scan-shell-target="result" data-controller="scanner-reading"
           data-action="turbo:submit-start->scanner-reading#lock turbo:submit-end->scanner-reading#unlock turbo:before-fetch-response->scanner-reading#inspect turbo:frame-missing->scanner-reading#printingsMissing turbo:fetch-request-error->scanner-reading#printingsErrored"></div>
    </div>
```

  and delete the `failureName` and `failureCollector` targets from `card_reader_controller.js`'s `static targets` and from `failed()` (Task 8 edits that file; remove the two lines now so the page does not break: `this.failureNameTarget.textContent = …` and `this.failureCollectorTarget.textContent = …`).
- [ ] Edit `app/assets/stylesheets/collector/additions.css`: (a) (the images' floor and the strip's compact height are Task 9's, so the layout numbers have one home and their specs; not here) (b) delete the `.c-scanpane__results { … }` rule and `.c-scan__pane-status:empty { … }` and fix the block's comment that mentions them; (c) add, above the reduced-motion block, this block (it holds the layout numbers of decision 13, which Task 9 proves):

```css
/* ---------- Scanner selection pane (spec 088): the band's empty state, the selection frame, the layout numbers ---------- */
/* The band and the pane's `#status` stay rendered while empty and take no space, so a sentence written into them is announced
   (spec 080 decision 8); `#status` has no padding, margin or gap of its own, and the spacing is on the message inside it. The result
   container is a flex column that takes the pane's remaining height, so the selection frame (a grid by its class) sizes as spec 080's
   body did. The layout numbers of decision 13 are not here: they are Task 9's, in one place. */
.c-band:empty { min-height:0; padding:0; }
.c-scanpane__result { flex:1 1 auto; min-height:0; display:flex; flex-direction:column; }
.c-scanpane__result > .c-scanpane__body { flex:1 1 auto; }
.c-scanpane__result > .c-status__message { margin:var(--space-3) var(--space-4); }
.c-scan__pane-status .c-status__message { margin:var(--space-3) var(--space-4); }
.c-scanpane > .c-scanner__failure { padding:0 var(--space-4) var(--space-3); }
.c-scanpane__missing { box-sizing:border-box; width:100%; height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:var(--space-1);
  padding:var(--space-2); text-align:center; font:600 13px/18px var(--font-sans); color:var(--ink-muted); overflow-wrap:anywhere; }
.c-scanpane__missing span { font:400 13px/18px var(--font-mono); }
.c-scanpane__meta .c-btn { box-sizing:border-box; flex:none; min-height:44px; min-width:44px; }
/* A possible-cards row (spec 088 decision 3): the line holds the tag, the position and the 44px "All printings", which do not fit
   on one line at 360px with the year, so the year is left out and the position wraps to two lines, right-aligned, inside the 44px. */
.c-scanpane__meta--cards .c-scanpane__position { min-width:0; white-space:normal; text-align:right; }
```

- [ ] Run `bin/rspec spec/system/scanner_selection_spec.rb:` (the first example needs Task 7's controller and Task 8's reader changes for the strip, the band and "Done."; it stays red here by design). Run `bin/rspec spec/system/design_system_scanner_components_spec.rb` to see which of spec 080's examples the floor changes (Task 9 updates them). Commit: `feat(scanner): the pane's skeleton, strip and empty-band styles (spec 088)`.

### Task 7: the `selection` controller

- [ ] Extend `spec/system/scanner_selection_spec.rb` (inside the describe) with the stepping examples, failing first:

```ruby
  it "steps to the next printing with Next: the same band element, replaced in place (AC-2.4, AC-3.2, AC-7.2)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    node = page.evaluate_script("window.__band = document.getElementById('scanner_band'); true")
    expect(page).to have_button("Previous printing", disabled: true)
    click_on "Next printing"
    expect(page).to have_css(".c-scanpane__item:nth-child(2)[aria-current='true']")
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "2 of 3 printings")
    expect(band).to have_text("Not the printing that was read")
    expect(band[:class]).to include("c-band--warning")
    expect(band.text(:all)).to include("Printing 2 of 3:")
    expect(page.evaluate_script("window.__band === document.getElementById('scanner_band') && document.querySelectorAll('.c-band').length === 1")).to be(true)
    expect(page).to have_button("Previous printing", disabled: false)
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
    click_on "Previous printing"
    expect(band).to have_text("Matched by its collector line")
  end

  it "disables Next at the last item and moves focus to Previous (AC-3.3)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    click_on "Next printing"
    expect(page).to have_css(".c-scanpane__item:nth-child(2)[aria-current='true']")
    find_button("Next printing").send_keys(:enter) # Firefox on a Mac does not focus a clicked button (scanner_page_spec.rb:57)
    expect(page).to have_button("Next printing", disabled: true)
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq("Previous printing")
  end

  it "steps with the arrow keys on the focused row (AC-3.4)" do
    visit scanner_path
    capture_synthetic
    find(".c-scanpane__row").send_keys(:arrow_right)
    expect(page).to have_css(".c-scanpane__item:nth-child(2)[aria-current='true']")
    find(".c-scanpane__row").send_keys(:arrow_left)
    expect(page).to have_css(".c-scanpane__item:nth-child(1)[aria-current='true']")
  end

  it "notes the nearest item when the row is scrolled by script, and when a neighbour is tapped (AC-3.5, AC-3.6)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    page.execute_script("const row = document.querySelector('.c-scanpane__row'); row.style.scrollBehavior = 'auto'; row.scrollLeft = row.scrollWidth")
    expect(page).to have_css(".c-scanpane__item:nth-child(3)[aria-current='true']", wait: 5)
    page.execute_script("document.querySelectorAll('.c-scanpane__item')[1].click()") # Next covers the neighbour's visible part, so a driver click is intercepted
    expect(page).to have_css(".c-scanpane__item:nth-child(2)[aria-current='true']")
  end
```

- [ ] Run them — expect FAIL (no controller).
- [ ] Create `app/javascript/controllers/selection_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// The selection pane's one small controller (spec 088 decision 6): it notes which card of the swipe row is centred and shows what
// that means. The server rendered everything else: every item, a panel for each (hidden unless centred) and, inside each panel, a
// <template> holding the band's icon and sentence. When the row's scrolling stops (about SETTLE ms after the last scroll event, so a
// fling is noted once) it takes the item nearest the row's centre, sets aria-current on it alone, shows its panel, copies the band
// in place (the one element's form class and children, so a live region announces the change: spec 080 decision 8), and disables
// Previous and Next at the ends, moving focus off a button that has just become disabled (spec 047). Previous, Next, the arrow
// keys and a tap on a neighbour do what a swipe does. When the frame renders again ("Show 20 more", "All printings") it restores
// the item the server marked, scrolling there at once. It holds no other state and sends nothing.
const SETTLE = 100

export default class extends Controller {
  static targets = [ "band", "row", "item", "panel", "prev", "next" ]

  disconnect() {
    clearTimeout(this.timer)
  }

  rowTargetConnected(row) {
    this.index = Math.max(0, this.itemTargets.findIndex((item) => item.getAttribute("aria-current") === "true"))
    this.apply(this.index)
    if (this.index > 0) this.scrollTo(this.index, "instant")
    if (row.dataset.selectionFocus) { // a frame request asked for focus on Next (the row when Next is disabled)
      delete row.dataset.selectionFocus
      this.focusOr(this.nextTarget, row)
    }
  }

  // The row went away (an add, "Scan again"): the band empties, unless the frame is only rendering again in the same batch.
  rowTargetDisconnected() {
    queueMicrotask(() => {
      if (this.hasRowTarget) return
      this.bandTarget.className = "c-band"
      this.bandTarget.replaceChildren()
    })
  }

  scrolled() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.settle(), SETTLE)
  }

  previous() { this.go(this.index - 1) }

  next() { this.go(this.index + 1) }

  key(event) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
    event.preventDefault()
    this.go(this.index + (event.key === "ArrowRight" ? 1 : -1))
  }

  tap(event) {
    const index = this.itemTargets.indexOf(event.target.closest(".c-scanpane__item"))
    if (index >= 0 && index !== this.index) this.go(index)
  }

  go(index) {
    if (index < 0 || index >= this.itemTargets.length) return
    this.apply(index)
    this.scrollTo(index)
  }

  settle() {
    if (!this.hasRowTarget) return // the row went away while the timer ran
    const row = this.rowTarget.getBoundingClientRect(), middle = row.left + row.width / 2
    let nearest = this.index, distance = Infinity
    this.itemTargets.forEach((item, index) => {
      const box = item.getBoundingClientRect(), apart = Math.abs(box.left + box.width / 2 - middle)
      if (apart < distance) { distance = apart; nearest = index }
    })
    if (nearest !== this.index) this.apply(nearest)
  }

  // Scrolls the item to the row's centre; without a behavior the row's own scroll-behavior decides (smooth, or at once under
  // prefers-reduced-motion).
  scrollTo(index, behavior) {
    const row = this.rowTarget, box = row.getBoundingClientRect(), item = this.itemTargets[index].getBoundingClientRect()
    row.scrollTo({ left: row.scrollLeft + (item.left + item.width / 2) - (box.left + box.width / 2), behavior })
  }

  apply(index) {
    const focused = document.activeElement
    this.index = index
    this.itemTargets.forEach((item, at) => (at === index ? item.setAttribute("aria-current", "true") : item.removeAttribute("aria-current")))
    this.panelTargets.forEach((panel, at) => { panel.hidden = at !== index })
    this.copyBand(this.panelTargets[index])
    this.prevTarget.disabled = index === 0
    this.nextTarget.disabled = index === this.itemTargets.length - 1
    if (focused === this.prevTarget && this.prevTarget.disabled) this.focusOr(this.nextTarget, this.rowTarget)
    if (focused === this.nextTarget && this.nextTarget.disabled) this.focusOr(this.prevTarget, this.rowTarget)
  }

  copyBand(panel) {
    const source = panel.querySelector("template[data-band]")
    this.bandTarget.className = `c-band ${source.dataset.band}`
    this.bandTarget.replaceChildren(source.content.cloneNode(true))
  }

  focusOr(button, fallback) {
    (button.disabled ? fallback : button).focus()
  }
}
```

  Confirm controllers are auto-registered (`app/javascript/controllers/index.js` uses `eagerLoadControllersFrom`); if names are listed by hand, add `selection`.
- [ ] Run the stepping examples — expect PASS (they need only this controller and the pane; `wait_for_pane` waits for the items and for the animations). The first example of Task 6 (strip texts) still needs Task 8. Commit: `feat(scanner): the selection controller notes the centred card (spec 088)`.

### Task 8: the reader writes the strip and the opening sentence; the add lock follows the new markup

- [ ] Extend `spec/system/scanner_selection_spec.rb` with (failing first):

```ruby
  it "says 'Done.' and the band's sentence once, as hidden text in the pane's region, and no 'What the scanner read' (AC-7.1)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    paragraph = find("#status .c-sr", visible: :all)
    expect(paragraph.text(:all)).to start_with("Done. Matched by its collector line")
    expect(paragraph.text(:all)).to include("Printing 1 of 3:")
    expect(page).to have_no_css("#status .c-status__message")
    expect(page).to have_no_text("What the scanner read")
  end

  it "adds the centred printing in the tapped finish, and the pane closes with the camera live (AC-4.4, AC-4.5, AC-7.4)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    click_on "Add foil"
    expect(page).to have_css("#scanner_added_text", text: "Added Lightning Bolt MOM · 123, foil", wait: 10)
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("#scanner_band:empty")
    eventually("document.activeElement.classList.contains('c-scan__main')")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(Lot.where(finish: "foil").count).to eq(1)
  end

  it "adds the swiped-to printing, not the matched one (AC-4.5)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    click_on "Next printing"
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "2 of 3 printings")
    within(".c-scanpane__card:not([hidden])") { first(".c-scanpane__add button").click }
    expect(page).to have_css("#scanner_added_text", text: /\AAdded Lightning Bolt (M10|2X2) · /, wait: 10)
  end

  it "says nothing read on the status line, with no pane, and the camera live (AC-6.1)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card(name: "", lines: [])
    click_on "Capture"
    expect(page).to have_css("#scanner_status_text", text: /Nothing could be read|No card matches/, wait: 30)
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(page).to have_no_css("#status .c-sr, #status .c-status__message")
    expect(page).to have_button("Capture", disabled: false)
  end

  it "returns to the camera on Scan again, emptying the band, the strip's texts and the region (AC-7.5)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    sent = scanner_sent.size
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("#scanner_band:empty")
    expect(page.evaluate_script("[document.querySelector('.c-scan__read-name').textContent, document.getElementById('status').textContent]")).to eq([ "", "" ])
    expect(page).to have_css("#scanner_status_text", text: "Ready. Line the card up with the guide, then capture.")
    expect(scanner_sent.size).to eq(sent)
  end

  it "shows the strip and the failure, no band, after a send failure (AC-1.4)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.driver.browser.manage.delete_cookie("session_id")
    click_on "Capture"
    expect(page).to have_css(".c-scan--result .c-scan__read-name", text: "Lightning Bolt", wait: 30)
    expect(page).to have_link("Sign in")
    expect(page).to have_css("#scanner_band:empty")
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
  end
```

- [ ] First give the helper a flat photo (edit `spec/support/scanner_helpers.rb`): in `CARD_JS` make `window.__syntheticCard = async (name, lines, live = false, flat = false)` fill the background `flat ? "white" : "gray"`, and let `pick_synthetic_photo(name: ..., lines: ..., input: PICKER, flat: false)` pass `flat` as a fourth script argument and on to `window.__syntheticCard(name, lines, false, flat)`. A flat photo has no edge for the detector, so the reading is the guide placement's and the result is a selection with the no-edge sentence. Rewrite `spec/system/scanner_detection_spec.rb`'s no-edge example (its `pick_photo(card: nil)` photo has no text, which now reads as nothing and shows no pane) the same way, with `flat: true`.
- [ ] Add these examples too, failing first (AC-1.3, 2.6, 3.9, 3.10, 3.11, 6.3, 7.3, 8.2):

```ruby
  it "shows a picked photo's card on the strip, and a no-edge sentence after 'Done.' (AC-1.3)", :aggregate_failures do
    visit scanner_path
    wait_for_scanner
    pick_synthetic_photo(flat: true, input: "#scanner_destination_sheet input[type=file]") # readable text, no card edge: guide placement
    wait_for_pane
    expect(page).to have_css(".c-scan__read-name", text: "Lightning Bolt")
    expect(page.evaluate_script("[document.querySelector('.c-scan__capture').width, document.querySelector('.c-scan__capture').height]")).to eq([ 178, 248 ])
    expect(page).to have_css("#status .c-sr", text: /\ADone\. /, visible: :all)
    expect(page).to have_css("#status .c-status__message:not(.c-status__message--alert)", text: /No card edge was found/)
  end

  it "says nothing about art in the pane with art matching off (AC-2.6)" do
    visit scanner_path
    capture_synthetic
    expect(page).to have_no_text(/artwork/i, wait: 0)
    expect(page).to have_no_css("#scanner_art_status, [data-card-reader-target=artStatus]", visible: :all) # it is in the destination sheet only with art on
  end

  it "opens a possible card's printings from All printings, in the frame, with focus on Next (AC-3.9)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card(name: "Lightning", lines: [])
    click_on "Capture"
    wait_for_pane
    expect(band).to have_text("Not sure of this card. Check it against your capture.")
    expect(find(".c-scanpane__row")["aria-label"] || find(".c-scanpane__rowwrap")["aria-label"]).to eq("Possible cards")
    page.execute_script("window.__marker = true")
    find_link("All printings").send_keys(:enter)
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "1 of 3 printings")
    expect(band).to have_text("Printing not confirmed. Swipe to check.")
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq("Next printing")
    expect(page.evaluate_script("window.__marker")).to be(true)
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
  end

  it "keeps the centred printing centred and focus on Next when Show 20 more renders the frame again (AC-3.10)", :aggregate_failures do
    24.times { |i| create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "t#{i}", name: "Set #{i}"), number: i.to_s)) }
    visit scanner_path
    capture_synthetic
    expect(page).to have_css(".c-scanpane__item--more")
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "1 of 27 printings")
    page.execute_script("const row = document.querySelector('.c-scanpane__row'); row.style.scrollBehavior = 'auto'; row.scrollLeft = row.scrollWidth")
    expect(page).to have_css(".c-scanpane__card:not([hidden]) a.c-btn", text: "Show 20 more", wait: 5)
    find_link("Show 20 more").send_keys(:enter)
    expect(page).to have_css(".c-scanpane__item", count: 27)
    expect(page).to have_no_css(".c-scanpane__item--more")
    expect(page).to have_css(".c-scanpane__item[aria-current='true']", count: 1)
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "20 of 27 printings")
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq("Next printing")
  end

  it "says so in the pane's region and leaves the row as it was when the selection request fails (AC-3.11)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card(name: "Lightning", lines: [])
    click_on "Capture"
    wait_for_pane
    page.execute_script("const send = window.fetch; window.fetch = (url, options) => String(url).includes('/scanner/printings') ? Promise.reject(new TypeError('offline')) : send(url, options)")
    find_link("All printings").send_keys(:enter)
    expect(page).to have_css("#status .c-status__message--alert", text: "The card's printings couldn't be loaded. Tap “All printings” again.")
    expect(page).to have_css(".c-scanpane__item", count: 1)
  end

  it "shows a card named with markup as text on every pane surface (AC-6.3)", :aggregate_failures do
    Catalog::Entry.find_by!(number: "123").update!(name: "Bolt <i>x</i>")
    visit scanner_path
    capture_synthetic
    expect(page).to have_no_css(".c-scanpane__name i, .c-scanpane__item img[alt*='<i>'] ~ i, #scanner_band i", visible: :all)
    expect(find(".c-scanpane__card:not([hidden]) .c-scanpane__name").text).to eq("Bolt <i>x</i>")
  end

  it "keeps the destination sheet's own region working while a result shows (AC-7.3)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    open_destination
    within("#scanner_destination_sheet") { click_on "Set" }
    expect(page).to have_css("#scanner_destination_status", text: /Cards you scan now/)
    expect(page).to have_no_css("#status .c-status__message", text: /Cards you scan now/)
  end

  it "records the add's rank: 1 on the matched printing, 'other' on a swiped-to one (AC-8.2)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    expect(page).to have_css(".c-scanpane__card:not([hidden]) form.c-scanpane__add[data-rank='1']", minimum: 1)
    click_on "Next printing"
    expect(page).to have_css(".c-scanpane__card:not([hidden]) form.c-scanpane__add[data-rank='other']", minimum: 1)
  end
```

- [ ] Run — expect FAIL. Then edit `app/javascript/controllers/card_reader_controller.js`:
  - add targets `"strip", "capture", "readName", "readLine", "band"` (and remove `failureName`, `failureCollector` if Task 6 has not);
  - replace the constants `SHOWING` with `const READING = "Reading the card…"` and keep `COULD_NOT_READ`, `NO_EDGE`; update the header comment's last sentence to describe the strip and the opening sentence (spec 088 decisions 8, 9, 11);
  - in `read()`, after `strips` and the reading are computed and before `this.dispatch("read", …)`, add:

```javascript
      this.drawCapture(image, card, source.outline)
      this.writeRead(reading.nameText, reading.collectorText)
```

  - replace the end of `read()`'s try block (`if (await this.send(reading) && reading.outline === "not_found") this.paneSay(NO_EDGE)`) with `if (await this.send(reading) && reading.outline === "not_found") this.paneSay(NO_EDGE, { append: true })`, and `say("Reading the card…")` with `this.say(READING)`;
  - in `resend()` clear the old failure alert before sending again, so a nothing-read or no-match answer does not leave it in the region: `this.paneStatusTarget.replaceChildren(...[ ...this.paneStatusTarget.children ].filter((child) => child.hasAttribute("data-pane-keep")))`;
  - replace in `send()`:

```javascript
    Turbo.renderStreamMessage(await response.text())
    this.paneSay(SHOWING)
    return true
```

    with

```javascript
    Turbo.renderStreamMessage(await response.text())
    return this.opened()
```

  - add these methods and update `paneSay`, `shellChanged`, `failed`:

```javascript
  // Waits for the answer to land and says what it did (spec 088 decision 11): a selection opens the pane (the band holds its
  // sentence) and says "Done." once, as hidden text; a refusal in the pane is its own alert; "nothing read" or "no match" is the
  // status line's sentence, so the frozen frame goes and no pane opens. Turbo applies a stream after a repaint, so wait for the
  // pane or for the status line to change, at most about a second.
  async opened() {
    for (let frame = 0; frame < 60 && !this.resultShowing && this.statusTarget.textContent === READING; frame++) await nextFrame()
    await nextFrame()
    if (!this.resultShowing) {
      this.frozenTarget.hidden = true
      return false
    }
    const sentence = this.bandTarget.textContent.replace(/\s+/g, " ").trim()
    if (!sentence) return false
    this.paneSay(`Done. ${sentence}`, { hidden: true })
    return true
  }

  // The card's box drawn on the strip's canvas at twice its size, so the strip shows the card and not the whole frame (spec 088
  // decision 9); a live capture's shrink starts from the guide's height over the picture's (spec 080's `--from`).
  drawCapture(image, card, outline) {
    const canvas = this.captureTarget
    canvas.height = 248
    canvas.width = Math.round(248 * 63 / 88)
    canvas.getContext("2d").drawImage(image, card.x, card.y, card.width, card.height, 0, 0, canvas.width, canvas.height)
    const guide = outline === "live" && this.element.querySelector(".c-scan__guide")?.getBoundingClientRect().height
    if (guide) canvas.style.setProperty("--from", (guide / parseFloat(getComputedStyle(canvas).height || 124)).toFixed(2))
    else canvas.style.removeProperty("--from") // a photo has no guide on the stage: spec 080's default
  }

  // What the reader read, on one line each (escaped by textContent; "nothing read" for a blank).
  writeRead(nameText, collectorText) {
    const line = (text) => text.replace(/\s+/g, " ").trim() || "nothing read"
    this.readNameTarget.textContent = line(nameText)
    this.readLineTarget.textContent = line(collectorText)
  }
```

  `paneSay` becomes:

```javascript
  async paneSay(message, { alert = false, hidden = false, append = false } = {}) {
    const said = this.paneSaid
    for (let frame = 0; frame < 120 && !this.resultShowing; frame++) await nextFrame()
    await nextFrame()
    if (said !== this.paneSaid || !this.resultShowing) return // a sentence for a pane that never opened is dropped (spec 088 decision 11)
    const className = hidden ? "c-sr" : `c-status__message${alert ? " c-status__message--alert" : ""}`
    const paragraph = Object.assign(document.createElement("p"), { className, textContent: message })
    const kept = [ ...this.paneStatusTarget.children ].filter((child) => append || child.hasAttribute("data-pane-keep"))
    this.paneStatusTarget.replaceChildren(...kept, paragraph)
  }
```

  `shellChanged` gains, in the `!result` case: `this.readNameTarget.textContent = ""; this.readLineTarget.textContent = ""`. `failed()` keeps its tail (resend/signIn/failure visible, `paneSay(message, { alert: true })`), without the two removed target lines. Update the file's header comment where it says "a sentence about a result is written to the pane's region".
- [ ] Rewrite `app/javascript/controllers/scanner_reading_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Holds a reading's add buttons while one of its adds is in flight, so one reading adds one copy (spec 009 AC-1.4). The answer
// clears the reading when the add goes through; a refusal hands the buttons back. An add that fails on the network or the server
// keeps the reading and says so, and its button is the retry: the same reading key makes a retry safe (AC-1.5, Error Scenarios).
// The selection frame's links ("All printings", "Show 20 more") that fail say so in the pane's region and leave the row as it was
// (spec 088 AC-3.11); `remember` notes which link was used, since a failed frame request does not say.
const ADD_FAILED = "That card wasn't added. Check your connection, then tap its add button again."
const PRINTINGS_FAILED = "The card's printings couldn't be loaded. Tap “All printings” again."
const SIGN_IN_PATH = "/session/new"
const ADD = ".c-scanpane__add"

export default class extends Controller {
  lock({ target }) {
    if (target.matches(ADD)) this.buttons.forEach((button) => { button.disabled = true })
  }

  // success is undefined when Turbo cancelled this submission for a newer one, which is still in flight: keep the lock.
  unlock({ target, detail: { success, error } }) {
    if (!target.matches(ADD)) return
    if (error) this.announce(ADD_FAILED, { alert: true })
    if (success === false) this.buttons.forEach((button) => { button.disabled = false })
  }

  // The link the collector used, so a failure can name its button.
  remember({ currentTarget }) {
    this.failureMessage = currentTarget.dataset.failureMessage
  }

  // A server error's HTML page would otherwise replace the scanner, camera and all; for the selection frame, one whose body isn't
  // HTML would leave the frame silently unchanged.
  inspect(event) {
    if (!event.detail.fetchResponse.serverError) return
    if (event.target.matches?.(ADD)) {
      event.preventDefault()
      this.announce(ADD_FAILED, { alert: true })
    } else if (event.target.id === "scanner_selection") {
      event.preventDefault()
      this.printingsFailed()
    }
  }

  // An ended session answers the selection frame with the sign-in page, which has no frame: show it, as an add would.
  printingsMissing(event) {
    if (event.target.id !== "scanner_selection") return
    const { response, visit } = event.detail
    event.preventDefault()
    if (response.redirected && new URL(response.url).pathname === SIGN_IN_PATH) visit(response)
    else this.printingsFailed()
  }

  printingsErrored({ target }) {
    if (target.id === "scanner_selection") this.printingsFailed()
  }

  printingsFailed() {
    this.announce(this.failureMessage || PRINTINGS_FAILED, { alert: true })
  }

  announce(text, { alert = false } = {}) {
    document.getElementById("status")?.replaceChildren(this.message(text, { alert }))
  }

  message(text, { alert }) {
    return Object.assign(document.createElement("p"), { className: `c-status__message${alert ? " c-status__message--alert" : ""}`, textContent: text })
  }

  get buttons() {
    return this.element.querySelectorAll(`${ADD} button`)
  }
}
```

- [ ] Extend `wait_for_pane` in the spec with the line `expect(page).to have_css("#status .c-sr", text: /\ADone\. /, visible: :all, wait: 30)` before the animations wait. Run `bin/rspec spec/system/scanner_selection_spec.rb` — expect PASS. Then update the rest of the scanner's system specs for the new markup, each example failing first against the new page and then fixed: the mapping is `.c-scanner__candidate` → `.c-scanpane__card:not([hidden])`; "Foil"/"Nonfoil" button names → "Add foil"/"Add nonfoil" (accessible names unchanged); "What the scanner read", "Candidates", "Other printings" examples are replaced by the selection's (delete the ones whose behaviour is gone: the grid, the overrule sentence, the evidence lines, the Artwork row; keep the art examples' assertions about what the art decided by reading the band's sentence and the first item); `"Done. What the scanner read and its candidates are showing."` → the hidden "Done. ‹band›" paragraph; `scanner_printings` → `scanner_selection`; the 360 × 640 / 360 × 560 "scrolls a long result inside the pane" examples in `scanner_result_spec.rb` are deleted (Task 9's pane-fit examples replace them). Files: `scanner_result_spec.rb`, `scanner_adding_spec.rb`, `scanner_art_spec.rb`, `scanner_detection_spec.rb`, `scanner_sitting_spec.rb`, `scanner_spec.rb`, `scanner_timing_spec.rb`, `scanner_measurement_spec.rb`. Run each file with `bin/rspec <file>`, one at a time.
- [ ] Run `bin/rubocop -a` and `bin/rspec spec/requests/footer_spec.rb spec/scanner_sitting_core_spec.rb`. Commit (one commit per file group is fine): `feat(scanner): the reader writes the strip and the opening sentence (spec 088)` and `test(scanner): the system specs follow the selection pane (spec 088)`.

---

## Phase 3: The layout at three sizes, the guards and the documents

**Implements:** FR-3 | **Satisfies:** AC-5.1 to AC-5.6, AC-8.3, AC-8.4
**Files:** `spec/system/scanner_selection_spec.rb`, `spec/system/design_system_scanner_components_spec.rb`, `spec/system/small_controls_touch_floor_spec.rb`, `spec/scanner_sitting_core_spec.rb`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/**`, `docs/architecture/scanner.md`, `CLAUDE.md`, `docs/specs/**`
**Interfaces:** Consumes: Phase 2's pane and the layout numbers in `additions.css` (`--scan-image-min`, the 599px container block). Produces: the proofs of decision 13 and the documents that state the numbers.

### Task 9: the layout numbers and their specs (one task, so a different ruling is a small change)

- [ ] Add to `spec/system/scanner_selection_spec.rb` (failing first if the CSS is wrong) the pane-fit examples at the three sizes, measuring at rest in the narrow frame:

```ruby
  # The boxes of the pane's parts in the page the driver is in, and whether the pane's body scrolls.
  def pane_boxes
    page.evaluate_script(<<~JS)
      (() => {
        const box = (selector) => { const el = document.querySelector(selector); if (!el) return null; const b = el.getBoundingClientRect(); return { top: b.top, bottom: b.bottom, left: b.left, right: b.right, width: b.width, height: b.height } }
        const body = document.querySelector(".c-scanpane__body")
        return { strip: box(".c-scan__strip"), band: box("#scanner_band"), row: box(".c-scanpane__rowwrap"), image: box(".c-scanpane__item[aria-current='true']"),
                 prev: box(".c-scanpane__nav--prev"), next: box(".c-scanpane__nav--next"), details: box(".c-scanpane__card:not([hidden]) .c-scanpane__details"),
                 adds: box(".c-scanpane__card:not([hidden]) .c-scanpane__adds"), pane: box(".c-scanpane"), bottom: box(".c-scan__bottom"),
                 scrolls: body.scrollHeight > body.clientHeight + 1, viewport: window.innerHeight }
      })()
    JS
  end

  [ [ 390, 844, 144, 288 ], [ 360, 640, 96, 160 ], [ 360, 560, 64, 112 ] ].each do |width, height, strip, image|
    it "fits the band, Previous and Next, the details and the add buttons at #{width} × #{height} for a confident match (AC-5.1, AC-5.3)", :aggregate_failures do
      open_scanner_frame(width:, height:)
      within_narrow_frame do
        capture_synthetic
        boxes = pane_boxes
        expect(boxes["strip"]["height"]).to eq(strip)
        expect(boxes["image"]["height"]).to be_within(1).of(image)
        expect(boxes["scrolls"]).to be(false)
        expect(boxes["adds"]["bottom"]).to be <= boxes["bottom"]["top"]
        parts = %w[strip band row details adds].map { boxes[it] }
        parts.each_cons(2) { |above, below| expect(above["bottom"]).to be <= below["top"] + 0.5 }
        expect(boxes["prev"]["top"]).to be >= boxes["row"]["top"]
        expect(boxes["next"]["bottom"]).to be <= boxes["row"]["bottom"] + 0.5
        expect_one_screen(height)
      end
    end
  end

  # The not-sure state: a two-line band at 360px and the 44px "All printings" line (a fixed part of 270px; 254px with a one-line band
  # at 390px). Images: 390 × 844 278px or 288px, 360 × 640 122px (within 2px), 360 × 560 the 96px floor with the body scrolling.
  [ [ 390, 844, [ 278, 288 ], false ], [ 360, 640, [ 120, 124 ], false ], [ 360, 560, [ 96 ], true ] ].each do |width, height, images, scrolls|
    it "fits the not-sure pane at #{width} × #{height} (AC-5.2, AC-5.4)", :aggregate_failures do
      open_scanner_frame(width:, height:)
      within_narrow_frame do
        show_synthetic_card(name: "Lightning", lines: [])
        click_on "Capture"
        wait_for_pane
        expect(band).to have_text("Not sure of this card")
        before = pane_boxes
        expect(images.any? { |h| (before["image"]["height"] - h).abs <= 2 }).to be(true), "images #{before["image"]["height"]}px, expected one of #{images}"
        expect(before["scrolls"]).to be(scrolls)
        expect(page.evaluate_script("(() => { const b = document.querySelector('.c-scanpane__body'); return b.scrollWidth <= b.clientWidth })()")).to be(true)
        page.execute_script("const b = document.querySelector('.c-scanpane__body'); b.scrollTop = b.scrollHeight")
        after = pane_boxes
        expect(after["adds"]["bottom"]).to be <= after["bottom"]["top"] + 0.5 # reachable: in view once the body is scrolled to its end, at every size
        expect([ after["strip"]["top"], after["band"]["top"] ]).to eq([ before["strip"]["top"], before["band"]["top"] ])
        expect_one_screen(height)
      end
    end
  end

  it "wraps a long set and card name inside the details at 360px and never scrolls sideways (AC-5.4)", :aggregate_failures do
    Catalog::Set.find_by(code: "mom").update!(name: "A set name of sixty characters long enough to wrap two lines")
    open_scanner_frame(width: 360, height: 640)
    within_narrow_frame do
      capture_synthetic
      expect(page.evaluate_script("(() => { const b = document.querySelector('.c-scanpane__body'); return b.scrollWidth <= b.clientWidth && document.documentElement.scrollWidth <= document.documentElement.clientWidth })()")).to be(true)
    end
  end
```

  (The system examples draw the name "Lightning" and the OCR reads it, so the score is about 0.93 against "lightning bolt" however well it is read, under the 0.96 threshold; the request spec's "Lightnlng Bo1t" is sent verbatim and needs no OCR. If an example reads as a strong name anyway, shorten the drawn name, never the threshold.)
- [ ] Run them — expect FAIL (spec 080's 160px floor and 96px strip are still in force: 360 × 560 shows a strip of 96px and images under 112px or a scrolling body).
- [ ] Write the layout numbers, here and nowhere else. In spec 080's pane block of `additions.css` change the body's rows to read the floor from a variable, `grid-template-rows:minmax(calc(var(--scan-image-min, 160px) + var(--space-4) + var(--space-3)), calc(288px + var(--space-4) + var(--space-3))) 1fr;`, update that block's comment (it says 160px, and "96px with a 76px one under 720px" only), and add to the `(spec 088 …)` block, after spec 080's 719px step:

```css
.c-scanpane { --scan-image-min:96px; }
@container scan (max-height: 599px) {
  .c-scan__strip { box-sizing:border-box; height:64px; }
  .c-scan__capture { box-sizing:border-box; height:52px; }
}
```

  Run them again — expect PASS; adjust only these two values until it does, then record the measured boxes in `verification.md`. Decision 14 asks for reduced motion where a box is read; the examples wait for `document.getAnimations()` to be idle instead, which measures the same rest state.
- [ ] Update `spec/system/design_system_scanner_components_spec.rb` (spec 080's examples, which draw the pane from markup the spec builds): the example "holds the images at 160px at 360 × 640 with a one-line band" stays; "scrolls the pane's content at 360 × 640 with a two-line band" becomes `expect(pane_layout.values_at("band", "image", "scrolls")).to eq([ 56, 144, false ])` (title: "gives way to 144px images with nothing scrolling at 360 × 640 with a two-line band (spec 088 decision 13)"); "scrolls the pane's content at 360 × 560 …" is replaced by an example that, at 360 × 560 with the one-line band, expects `[ 40, 112, false ]` and `strip` 64, and keeps the check that the bars, strip and band stay in place when the body is scrolled at 360 × 560 with a *wrapped set name and a two-line band* (the accepted limit; it scrolls by only a few pixels, so the example scrolls to the end and expects `scrollTop` above 0); the 390 × 664 example's `strip` expectation stays 96. Run `bin/rspec spec/system/design_system_scanner_components_spec.rb`.
- [ ] Update every document that states the old numbers (grep `160px`, `96px with a 76px`, `76px`, `at least 160px` in `docs/design-system/` and the previews `ScannerFlow.html`, `ScannerConfidence.html`, `StatusBand.html`, `Sheet.html`): `Scanner.md`'s "capture strip" and "pane" bullets (strip 144px with a 124px picture, 96px with a 76px one under 720px, 64px with a 52px one under 600px; the images 288px at most and 96px at least) and the sums in spec 088's note; the previews need no change unless a frame is shorter than 600px (check their frames; if one is, redraw its numbers). Mark spec 080's decision 7 and AC-4.7 as superseded for the two numbers in `docs/specs/README.md` (already recorded) and in `Scanner.md`'s sources.
- [ ] Run `bin/rspec spec/system/design_system_scanner_components_spec.rb spec/system/scanner_selection_spec.rb`. Commit: `feat(scanner): fit the pane to the three phone sizes (spec 088 decision 13)` and `docs(design-system): the pane's new floors (spec 088 decision 13)`.

### Task 10: guards, the touch floor and the documents

- [ ] In `spec/system/small_controls_touch_floor_spec.rb`: add `.c-scanpane__meta` and `.c-scanpane__add` to `page_rule_scopes` (replacing `.c-scanner__add`, now unused) and add the scanner's pane controls ("All printings", "Show 20 more", Previous, Next, the add buttons) to the scanner pages' control list with the result showing, following that file's existing pattern for the scanner (spec 082 AC-1.9); run the file.
- [ ] In `spec/scanner_sitting_core_spec.rb` add the selection's files to the glob (`app/models/scanner/selection.rb` and `app/views/scanners/_{selection,item,more_item,panel,more_panel,band_content,add_buttons}.html.erb`), so FR-1's "names no collectible" is guarded, and raise the file's `files.size` expectation (12) by the number of files added; fix any file it flags (comments included); run the file. Run `bin/rspec spec/requests/footer_spec.rb` (the policy's pin).
- [ ] Remove `Scanner::OtherPrintings#shown` and `#rest` (the frame replaced them; `SHOWN` stays, as `Scanner::Selection::STEP`) and their examples in `spec/models/scanner/other_printings_spec.rb`; in `lib/collector/scanner_findings/sitting_report.rb` check how the rank "other" is labelled ("Other printings") and keep the report's output stable (rank "other" is still recorded); in `spec/requests/footer_spec.rb` around line 83 change any `Turbo-Frame: scanner_printings` header to `scanner_selection`.
- [ ] Remove the `c-scanner__*` CSS rules no view uses any more: for each selector of `.c-scanner__candidate`, `.c-scanner__adds`, `.c-scanner__add`, `.c-scanner__evidence`, `.c-scanner__printings`, `.c-scanner__result`, `.c-scanner__read`, `.c-scanner__mono`, run `git grep -n '<selector without the dot>' -- app ':!.kamal/secrets'`; delete a rule only when nothing else uses it (the sitting's `c-scanner__more`, `c-scanner__undo` and `c-scanner__sitting` stay); add the name of each removed rule to the commit body; run `spec/design_system_files_spec.rb`.
- [ ] Write the documents: `docs/architecture/scanner.md` (the pane, the band and its three states and wordings, the row's contents, the selection frame's request and its params, the strip, the outcomes' places, decision 13's numbers in Named constants, the accepted limits: a card with more than 200 English printings, a confidently wrong card is a "Scan again", a failed read shows no capture; the regions table gains the new rows; the supersessions in Sources and its distillation log is `distill-feature`'s); `docs/design-system/README.md` (the Mobile and Hotwire and Motion rules mention "built by #345" where they do; the band's first use; AC-8.4), `docs/design-system/components/Scanner.md` (replace "What #345 builds in the pane" and "The result partial, until #345" with the pane as built, its markup from `scanners/_selection`, `_panel`, `_item`; keep one sentence on measurement mode's record); `StatusBand.md` (first use is built; "Not the printing that was read" is on every printing other than the matched one); `CLAUDE.md`'s scanner paragraph gains one sentence (the pane, spec 088). Documents are verified by reading, recorded in `verification.md`, never by RSpec.
- [ ] Commit: `docs(scanner): the selection pane in the area doc and the design system (spec 088)`.

---

## Phase 4: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run `bin/ci checks`, then (with the coordinator's slot) the full `bin/ci` once, after the implementation review and the wrap.
- [ ] Targeted runs before that, one file at a time: `bin/rspec spec/models spec/requests/scanner spec/helpers spec/system/scanner_selection_spec.rb spec/system/scanner_result_spec.rb spec/system/scanner_adding_spec.rb spec/system/scanner_page_spec.rb spec/system/scanner_spec.rb spec/system/scanner_art_spec.rb spec/system/scanner_detection_spec.rb spec/system/scanner_sitting_spec.rb spec/system/scanner_measurement_spec.rb spec/system/scanner_timing_spec.rb spec/system/design_system_scanner_components_spec.rb spec/system/small_controls_touch_floor_spec.rb spec/scanner_sitting_core_spec.rb spec/requests/footer_spec.rb` (the suite is red from Task 5 until Task 8 has brought the system specs along; that is expected and the commits say so).
- [ ] Screenshots and GIFs, looked at before the specs are trusted (`.claude/memory/pr-screenshots-workflow.md`): a confident match, a swipe with the band replaced, the three bands, a short phone (360 × 560), the failure and the nothing-read line, light and dark, desktop and phone; the GIF of capture, swipe, add foil; embedded by SHA-pinned links in the PR; saved in `docs/specs/088-scanner-selection-pane/screenshots/`.
- [ ] Write `verification.md` (criterion by criterion, documents read, the measured boxes) and the implementation review (`## Implementation review`, verdict first line, Opus 5.5).

---

## Quickstart Validation

1. `bin/rails db:prepare && bin/dev`; sign in; open `/scanner` on a phone over HTTPS (`bin/dev-certificate`), or use the specs' substituted camera.
2. Capture a card whose collector line reads: the strip shows the capture beside the name and line read, the band is green with a check and "Matched by its collector line", the add buttons are in view; tap "Add foil": the pane drops, the camera is live, the after-add line says "Added …, foil" with Undo.
3. Capture a card by its name alone: the band is amber, "Printing not confirmed. Swipe to check."; swipe or tap Next: the same band reads "Not the printing that was read" and Previous enables.
4. Capture a card the scanner cannot be sure of: the question-mark band, "1 of 3 possible cards", "All printings" opens that card's printings.
5. Capture nothing: the status line says "Nothing could be read…" and the camera stays live.
