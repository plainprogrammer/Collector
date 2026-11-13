# Implementation Plan: A Price Source Contract, and Scryfall's Prices Through It (spec 085, issue #364)

**Spec:** `docs/specs/085-price-source-contract/spec.md` (Approved 1.0.4) · **ADR:** none (Gate A: the contract's comment and `prices.md` carry the rules) · **Issue:** #364 · **Branch:** `085-price-source-contract` · **Created:** 2026-11-13
Plan review: Fable 5.2, read-only. Round 1 (2026-11-13): APPROVE WITH CHANGES, 1 blocking, 3 major, 14 minor. Round 2: APPROVE WITH CHANGES, 1 major (a stale sentence), 4 minor, 5 nits. All applied in this revision.

## Global Constraints

- **Repo rules:** `CLAUDE.md`, `.claude/rules/*.md`. Spec types are tagged (`type: :model`). `RSpec/ExampleLength` max 15 lines; multi-expectation examples use `:aggregate_failures`; `RSpec/MultipleMemoizedHelpers` max 5. Arrays are written `[ a, b ]` (omakase).
- **One commit per task, test first:** red, implement, green, RuboCop (the edit hook runs it; run `bin/rubocop <files>` once more before committing). Conventional Commits ending `(#364)` with the trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for an implementer. One git operation per shell call; `git add` and `git commit` in separate calls. Every `git grep` ends with `':!.kamal/secrets'`.
- **Off limits:** never read `.kamal/secrets`, `config/master.key`, `.env*`, `storage/` or any `*.sqlite3`. Never run the `sqlite3` command, `bin/rails console`/`dbconsole`, `db:rollback`, `db:migrate:down`, `db:seed`, anything with `RAILS_ENV=production`, `bundle add`/`update`, or `bin/jobs`.
- **One test run at a time** in this worktree (one shared `storage/test*.sqlite3`). Targeted `bin/rspec <file>` only; no full `bin/ci` without a slot from the coordinator.
- **No migration, no schema change.** The five tables exist (spec 081); this feature adds no column, no table and no row by migration (spec decision 7). `db/prices_structure.sql` must not change; if it does after a command, stop and report.
- **Comments** (`.claude/rules/code-documentation.md`): every public class, module and method added or changed gets a summary, plus `@param`/`@return`/`@raise` where it is reusable. No `{…}` outside YARD links. Point at the area doc with `@see file:prices.md`. A comment is Markdown. **Core files** (`app/models/prices.rb`, `app/models/prices/**`, `app/models/price_source.rb`, `app/models/price_series.rb`) never contain `mtg`, `magic`, `scryfall`, `tcgplayer` or `cardmarket` (matched as substrings, case-insensitive, so `scryfall_id` and `MTGPrinting` are caught too: issue #209), comments included; their examples use a neutral fake collectible ("widgets"). The guard of T1.1 reads them.
- **Prices are global:** no `account_id`, no `Current.account`, nothing in an export. `each_quote` makes no network call and writes nothing; `sync!` and `ensure!` write to the prices database only.
- **The hosted flag lives in one place** (`MTG::Scryfall::PriceQuotes.hosted_paid_allowed?`) with its spec in a task of its own (T2.4), so a ruling of `false` after #362's answer changes that one line, its example, and the sentence in `prices.md` that states the value (T4.1). The maintainer ruled `true` on 2026-11-13; #362 is open and may change it.
- **Existing files this feature changes:** `app/models/prices_record.rb` (its comment, T3.1), `config/initializers/` (new `prices.rb`, T2.4), `CLAUDE.md`, `docs/architecture/prices.md`, `docs/roadmap.md`, `docs/specs/README.md` (T4.1, T4.2). No existing example changes.

## Goal

After this branch: a collectible extension supplies prices through the documented `Prices::Sources` contract and a registry; `MTG::Scryfall::PriceQuotes` yields a quote for every price in the bulk file the catalog reads; `PriceSource.sync!` and `PriceSeries.ensure!` write the source and series rows from a source's declaration; and a guard keeps the core files free of any collectible.

## Pre-implementation gates

- **Simplicity (≤3 components): pass.** (1) The contract and registry (`Prices`, `Prices::Sources`). (2) The Scryfall source (`MTG::Scryfall::PriceQuotes`). (3) Two models (`PriceSource`, `PriceSeries`). No gem, no migration, no job, no page.
- **Anti-abstraction: pass.** `Series`, `Quote` and `Malformed` are `Data` values, as the catalog contract's records are; the models are plain Active Record on the existing `PricesRecord`.
- **Integration-first: pass.** Phase 1 fixes the contract (values, `verify!`, registry) with a fake source before the Scryfall source exists; Phase 2 meets it; Phase 3 stores what it declares.

## Files

| File | Responsibility |
|---|---|
| `app/models/prices.rb` (new) | The registry: `Prices.sources`, `.source_class`, `.sources_for` |
| `app/models/prices/sources.rb` (new) | The contract's comment, `Series`, `Quote`, `Malformed`, errors, `verify!` |
| `app/models/mtg/scryfall/price_quotes.rb` (new) | The Scryfall source |
| `app/models/price_series.rb`, `app/models/price_source.rb` (new) | Rows from declarations: `PriceSeries.ensure!`, `PriceSource.sync!` |
| `config/initializers/prices.rb` (new) | Registers `scryfall` |
| `app/models/prices_record.rb` | Comment only |
| `spec/support/fake_price_source.rb` (new) | `FakePriceSource`, `OtherFakePriceSource` for the contract's specs |
| `spec/price_source_core_spec.rb` (new) | The core guard |
| `spec/models/prices_spec.rb`, `spec/models/prices/sources_spec.rb`, `spec/models/mtg/scryfall/price_quotes_spec.rb`, `spec/models/price_series_spec.rb`, `spec/models/price_source_spec.rb` (new) | The criteria |
| `CLAUDE.md`, `docs/architecture/prices.md`, `docs/roadmap.md`, `docs/specs/README.md` | Documents (T4.1, T4.2) |

Batches for implementers (2–4 consecutive tasks each, one commit per task): **A** = T1.1–T1.3; **B** = T2.1–T2.3; **C** = T2.4, T3.1, T3.2; **D** = T4.1, T4.2.

---

## Phase 1: The contract, its registry and the guard

**Implements:** FR-1 | **Satisfies:** AC-1.1 (the part a test can check), AC-1.2 to AC-1.5, AC-4.1
**Files:** `spec/price_source_core_spec.rb`, `spec/support/fake_price_source.rb`, `spec/models/prices_spec.rb`, `spec/models/prices/sources_spec.rb`, `app/models/prices.rb`, `app/models/prices/sources.rb`
**Interfaces:** Consumes: nothing. Produces: `Prices.sources` (Hash key => class name), `Prices.source_class(key)`, `Prices.sources_for(collectible_type)`; `Prices::Sources::Series.new(finish:, currency:, kind:)`, `Prices::Sources::Quote.new(external_key:, finish:, currency:, kind:, cents:, reported_on:)` with `#series`, `Prices::Sources::Malformed.new(external_key:, error:, series: nil)`, `Prices::Sources::Error`, `::IntegrityError`, `::ConfigurationError`, `Prices::Sources.verify!(source_class)`; the spec helper classes `FakePriceSource` (key `fake_source`, collectible type `widgets`) and `OtherFakePriceSource` (key `aaa_other`).

### T1.1: The guard, the fake source and the registry

- [ ] Write the guard `spec/price_source_core_spec.rb`:

```ruby
require "rails_helper"

# Spec 085 decision 12, AC-4.1: the core of prices names no collectible, source or marketplace, comments included.
# Substring matching, not a word, so scryfall_id and MTGPrinting are caught too (issue #209).
RSpec.describe "the price source contract is core", type: :model do
  let(:matcher) { /mtg|magic|scryfall|tcgplayer|cardmarket/i }
  let(:core_files) do
    %w[app/models/prices.rb app/models/prices/**/*.rb app/models/price_source.rb app/models/price_series.rb]
      .flat_map { |pattern| Rails.root.glob(pattern) }
  end

  it "names no collectible, source or marketplace in the files it adds", :aggregate_failures do
    expect(core_files).not_to be_empty
    expect(core_files.select { |file| file.read.match?(matcher) }.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end

  it "has a matcher that flags a name, so the guard can fail" do
    samples = [ "a Scryfall file", "Magic cards", "an MTG type", "TCGplayer", "Cardmarket", "scryfall_id", "MTGPrinting" ]

    expect(samples.reject { |text| text.match?(matcher) }).to be_empty
  end
end
```

- [ ] Write the fake sources `spec/support/fake_price_source.rb` (it is loaded by `rails_helper` with the other support files):

```ruby
# A price source for the contract's own specs (spec 085): it knows no real collectible and yields the records it is given.
#
# @api private
class FakePriceSource
  def self.key = "fake_source"
  def self.collectible_type = "widgets"
  def self.title = "Fake Source"
  def self.attribution = "Prices as reported by the fake source."
  def self.attribution_url = "https://prices.example.test"
  def self.hosted_paid_allowed? = false
  def self.series = [ Prices::Sources::Series.new(finish: "plain", currency: "USD", kind: "market") ]

  # A subclass whose class members answer what is given, for a source that has one member wrong or different.
  #
  # @param members [Hash] class member name => the value it answers
  # @return [Class]
  def self.with(**members)
    Class.new(self) { members.each { |name, value| define_singleton_method(name) { value } } }
  end

  # @param records [Array] the Quote and Malformed values each_quote yields
  # @param reported_on [Date, Exception] what reported_on answers, or the error it raises
  def initialize(records: [], reported_on: Date.new(2026, 11, 13))
    @records = records
    @reported_on = reported_on
  end

  def reported_on(_path) = @reported_on.is_a?(Exception) ? raise(@reported_on) : @reported_on

  def each_quote(path, languages:, &block)
    return enum_for(:each_quote, path, languages:) unless block

    @records.each(&block)
  end
end

# A second fake of the same collectible, to show the registry's key order.
#
# @api private
class OtherFakePriceSource < FakePriceSource
  def self.key = "aaa_other"
end
```

- [ ] Write the registry spec `spec/models/prices_spec.rb` (AC-1.3; AC-1.6 is added in T2.4):

```ruby
require "rails_helper"

RSpec.describe Prices, type: :model do
  describe "the registry (spec 085 decision 11, AC-1.3)" do
    around do |example|
      original = described_class.sources.dup
      described_class.sources["fake_source"] = "FakePriceSource"
      described_class.sources["aaa_other"] = "OtherFakePriceSource"
      example.run
    ensure
      described_class.sources.replace(original)
    end

    it "finds a source class by its key", :aggregate_failures do
      expect(described_class.source_class("fake_source")).to eq(FakePriceSource)
      expect { described_class.source_class("nope") }.to raise_error(ArgumentError, /unknown price source: nope/)
    end

    it "lists the sources of a collectible type in key order, and none for a type without one", :aggregate_failures do
      expect(described_class.sources_for("widgets")).to eq([ OtherFakePriceSource, FakePriceSource ])
      expect(described_class.sources_for("gadgets")).to eq([])
    end
  end
end
```

- [ ] Run: `bin/rspec spec/price_source_core_spec.rb spec/models/prices_spec.rb` — expect: FAIL. `prices_spec.rb` fails at load (`uninitialized constant Prices`), so RSpec reports an error outside examples; run the guard alone first, `bin/rspec spec/price_source_core_spec.rb`, and expect its first example to FAIL (the core file list is empty).
- [ ] Implement `app/models/prices.rb`:

```ruby
# Market prices as the core knows them: which price sources exist and which collectible each one is for. A source
# implements the contract in `Prices::Sources`, which is the one place the contract is written down; this module only
# finds sources, as `Catalog.sources` finds a collectible's catalog source (spec 085 decision 11).
#
# @see file:prices.md
module Prices
  # Registered price sources, by key => class name, set in `config/initializers/prices.rb`.
  mattr_accessor :sources, default: {}

  # The class of a registered price source.
  #
  # @param key [String] the source's key, as registered
  # @return [Class] a class that implements `Prices::Sources`
  # @raise [ArgumentError] when no source is registered under the key
  def self.source_class(key)
    sources.fetch(key) { raise ArgumentError, "unknown price source: #{key}" }.constantize
  end

  # The price sources of one collectible type, in key order.
  #
  # @param collectible_type [String] a key of `Catalog.sources`
  # @return [Array<Class>] empty when the type has no price source
  def self.sources_for(collectible_type)
    sources.keys.sort.map { |key| source_class(key) }.select { |source| source.collectible_type == collectible_type }
  end
end
```

- [ ] Run: `bin/rspec spec/price_source_core_spec.rb spec/models/prices_spec.rb` — expect: `4 examples, 0 failures` (the guard now finds `app/models/prices.rb`; the fake's `series` method refers to `Prices::Sources::Series` only when it is called, which these examples do not).
- [ ] Run: `bin/rails zeitwerk:check` — expect: `All is good!`.
- [ ] Commit: `feat(prices): the price source registry and the core guard (#364)`

### T1.2: `Series`, `Quote`, `Malformed` and the errors

- [ ] Write `spec/models/prices/sources_spec.rb` (AC-1.2 second clause, AC-1.4, AC-1.5; `.verify!` is added in T1.3):

```ruby
require "rails_helper"

RSpec.describe Prices::Sources, type: :model do
  let(:series) { described_class::Series.new(finish: "plain", currency: "USD", kind: "market") }
  let(:reported_on) { Date.new(2026, 11, 13) }

  describe "::Series (spec 085 decisions 1 and 2)" do
    it "refuses a blank finish or kind and a currency that is not three upper-case letters (AC-1.2)", :aggregate_failures do
      expect { described_class::Series.new(finish: " ", currency: "USD", kind: "market") }.to raise_error(ArgumentError, /finish/)
      expect { described_class::Series.new(finish: "plain", currency: "USD", kind: "") }.to raise_error(ArgumentError, /kind/)
      expect { described_class::Series.new(finish: "plain", currency: "usd", kind: "market") }.to raise_error(ArgumentError, /currency/)
      expect { described_class::Series.new(finish: "plain", currency: "USDX", kind: "market") }.to raise_error(ArgumentError, /currency/)
    end

    it "is equal to another with the same parts, so it can key a hash" do
      expect({ series => :row }[described_class::Series.new(finish: "plain", currency: "USD", kind: "market")]).to eq(:row)
    end
  end

  describe "::Quote (spec 085 decision 2, AC-1.5)" do
    let(:arguments) { { external_key: "abc-1", finish: "plain", currency: "USD", kind: "market", cents: 142, reported_on: } }

    it "offers its series" do
      expect(described_class::Quote.new(**arguments).series).to eq(series)
    end

    it "refuses each invalid argument", :aggregate_failures do
      [ { external_key: "" }, { external_key: nil }, { finish: " " }, { kind: "" }, { currency: "usd" }, { cents: -1 },
        { cents: 1.5 }, { cents: "142" }, { reported_on: "2026-11-13" }, { reported_on: nil } ].each do |invalid|
        expect { described_class::Quote.new(**arguments, **invalid) }.to raise_error(ArgumentError), "expected #{invalid} to be refused"
      end
    end

    it "accepts a price of zero cents" do
      expect(described_class::Quote.new(**arguments, cents: 0).cents).to eq(0)
    end
  end

  describe "::Malformed" do
    it "carries the series of a price the source could not read, and none for a line it could not read", :aggregate_failures do
      expect(described_class::Malformed.new(external_key: "abc-1", error: "unreadable", series:).series).to eq(series)
      expect(described_class::Malformed.new(external_key: nil, error: "not JSON").series).to be_nil
    end
  end

  describe "the contract shown by a fake source (AC-1.4)" do
    let(:quote) { described_class::Quote.new(external_key: "abc-1", finish: "plain", currency: "USD", kind: "market", cents: 142, reported_on:) }
    let(:records) { [ quote, described_class::Malformed.new(external_key: "abc-2", error: "unreadable", series:), described_class::Malformed.new(external_key: nil, error: "not JSON") ] }

    it "yields its records to a block, and as an enumerator without one", :aggregate_failures do
      source = FakePriceSource.new(records:)
      yielded = []
      source.each_quote("any.file", languages: [ "en" ]) { |record| yielded << record }

      expect(yielded).to eq(records)
      expect(source.each_quote("any.file", languages: [ "en" ])).to be_an(Enumerator)
      expect(source.each_quote("any.file", languages: [ "en" ]).to_a).to eq(records)
    end

    it "answers the day its data is from, or raises IntegrityError", :aggregate_failures do
      expect(FakePriceSource.new.reported_on("any.file")).to eq(reported_on)
      expect { FakePriceSource.new(reported_on: described_class::IntegrityError.new("no date")).reported_on("any.file") }
        .to raise_error(described_class::IntegrityError, "no date")
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/prices/sources_spec.rb` — expect: FAIL (`uninitialized constant Prices::Sources`).
- [ ] Implement `app/models/prices/sources.rb` (the first half; T1.3 adds `verify!` below the errors). Replace the comment's example names only with neutral ones, as written:

```ruby
# The contract between the core and a price source: how a collectible's extension supplies prices (spec 085). This
# comment is the one place the contract is written down; a source for a new collectible is added by reading it. It
# mirrors `Catalog::Sources`, the contract for the catalog. A source is a class, registered in `Prices.sources` under
# its key (config/initializers/prices.rb), built with `.new` and no arguments, that provides:
#
#   .key                      the source's stable key: lower case letters, digits and underscores, such as "widget_prices";
#                             stored as price_sources.key, and never changed once released
#   .collectible_type         the key of the `Catalog.sources` entry whose printings this source's external ids name
#   .title                    the source's name, stored as price_sources.name (not `.name`, which every class answers)
#   .attribution              the text a page shows beside this source's prices
#   .attribution_url          an https address, or nil
#   .hosted_paid_allowed?     true or false: whether a hosted instance with paid plans may show this source's prices. Stated
#                             and stored; nothing refuses a source by it yet
#   .series                   the `Series` this source quotes: an Array, not empty, with no two equal
#   #reported_on(path)        the Date the data in the file at path is from. Raises IntegrityError when the file doesn't say
#   #each_quote(path, languages:) { |Quote or Malformed| }
#                             streamed, for the file at path, each Quote carrying #reported_on's date; without a block it
#                             returns an Enumerator. `languages:` is what the collectible's catalog source returns from
#                             `#languages`, so quotes are yielded for the printings the catalog holds; a source for a
#                             collectible without languages ignores it
#
# What `#each_quote` must and must not do:
#
# - It reads a local copy of the source's data and nothing else: no network call, no write, no read of the database. The
#   file is the caller's to fetch. The contract has no members that fetch it.
# - It holds one record at a time: memory doesn't grow with the file.
# - It yields only the prices the file carries. A price the file leaves empty has no quote; whether that means a price is
#   gone is the caller's to decide from the absence.
# - It yields a `Malformed` for what it could not read, and goes on. What a `Malformed` means for absence:
#   - one with a `series` is a price the file carries and the source could not read: **not an absence**, and the caller
#     must leave that printing's price in that series alone;
#   - one with an `external_key` and no `series` is a printing whose prices could not be read at all: no series of that
#     printing may be read as absent;
#   - one with no `external_key` names no printing, so the run's absences can't be trusted.
# - It raises `IntegrityError` (before yielding anything) for a file whose day it can't tell, and lets the reader's own
#   error (a corrupt file) surface to the caller.
#
# A `Quote` is one price of one printing: the source's id for the printing (the catalog entry's `external_key`), its
# series (finish, currency, kind), whole `cents` and the day it was reported. Values validate when built, so a source
# can't yield what the prices database would refuse.
#
# @see file:prices.md
module Prices::Sources
  # A source's failure that isn't a bad line: the base of the errors below.
  class Error < StandardError; end

  # The file can't be trusted: its day can't be told, so no quote may be given a date.
  class IntegrityError < Error; end

  # A source class that doesn't meet the contract (see `verify!`).
  class ConfigurationError < Error; end

  # An ISO 4217 code is three upper-case letters; the same rule as the price_series table's check constraint (spec 081).
  CURRENCY = /\A[A-Z]{3}\z/

  # @api private
  # @raise [ArgumentError] unless the value is a String with something in it
  def self.text!(name, value)
    raise ArgumentError, "#{name} must be a non-blank String, got #{value.inspect}" unless value.is_a?(String) && !value.strip.empty?
  end

  # @api private
  # @raise [ArgumentError] unless the value is three upper-case letters
  def self.currency!(value)
    raise ArgumentError, "currency must be three upper-case letters, got #{value.inspect}" unless value.is_a?(String) && value.match?(CURRENCY)
  end

  # What a price means: a finish, an ISO 4217 currency and a kind (spec 081 glossary). Series are global: two sources
  # that quote the same finish, currency and kind share one row (`PriceSeries`).
  Series = Data.define(:finish, :currency, :kind) do
    def initialize(finish:, currency:, kind:)
      Prices::Sources.text!(:finish, finish)
      Prices::Sources.currency!(currency)
      Prices::Sources.text!(:kind, kind)
      super
    end
  end

  # One price of one printing, as a source reported it.
  #
  # `external_key` is the source's id for the printing; `cents` is a whole number of cents, 0 or more; `reported_on` is
  # a Date, the day the source's data is from.
  #
  # @raise [ArgumentError] when built with a blank key, finish or kind, a currency that isn't three upper-case
  #   letters, a `cents` that isn't a non-negative Integer, or a `reported_on` that isn't a Date
  Quote = Data.define(:external_key, :finish, :currency, :kind, :cents, :reported_on) do
    def initialize(external_key:, finish:, currency:, kind:, cents:, reported_on:)
      Prices::Sources.text!(:external_key, external_key)
      Prices::Sources.text!(:finish, finish)
      Prices::Sources.currency!(currency)
      Prices::Sources.text!(:kind, kind)
      raise ArgumentError, "cents must be an Integer of 0 or more, got #{cents.inspect}" unless cents.is_a?(Integer) && cents >= 0
      raise ArgumentError, "reported_on must be a Date, got #{reported_on.inspect}" unless reported_on.is_a?(Date)

      super
    end

    # The series this quote is a price in.
    #
    # @return [Series]
    def series = Series.new(finish:, currency:, kind:)
  end

  # A line, or a price on a line, that the source could not read. `series` is the `Series` of an unreadable price, or
  # nil when the line is unreadable as a whole. See the comment of this module for what each kind means for absence.
  Malformed = Data.define(:external_key, :error, :series) do
    def initialize(external_key:, error:, series: nil) = super
  end
end
```

- [ ] Run: `bin/rspec spec/models/prices/sources_spec.rb spec/price_source_core_spec.rb` — expect: PASS (`10 examples, 0 failures`; the guard reads the new file: its comment names no real collectible).
- [ ] Commit: `feat(prices): the contract's values, errors and comment (#364)`

### T1.3: `verify!`

- [ ] Add to `spec/models/prices/sources_spec.rb`, inside the top-level describe (AC-1.2 first clause):

```ruby
  describe ".verify! (spec 085 decision 1, AC-1.1, AC-1.2)" do
    it "returns a class that provides every member" do
      expect(described_class.verify!(FakePriceSource)).to eq(FakePriceSource)
    end

    it "refuses a member that is wrong and names it", :aggregate_failures do
      {
        key: "Bad Key", collectible_type: " ", title: "", attribution: nil, attribution_url: "http://prices.example.test",
        hosted_paid_allowed?: nil, series: []
      }.each do |member, value|
        expect { described_class.verify!(FakePriceSource.with(member => value)) }
          .to raise_error(described_class::ConfigurationError, /#{Regexp.escape(member.to_s)}/), "expected #{member}: #{value.inspect} to be refused"
      end
    end

    it "refuses a key that is blank, upper case or has a character outside a-z, 0-9 and underscore", :aggregate_failures do
      [ "", "UPPER", "with-dash", "with space" ].each do |key|
        expect { described_class.verify!(FakePriceSource.with(key:)) }.to raise_error(described_class::ConfigurationError, /key/), "expected #{key.inspect} to be refused"
      end
    end

    it "refuses an address that is not an https URL, a series list with a repeat, and a series that is not a Series", :aggregate_failures do
      expect { described_class.verify!(FakePriceSource.with(attribution_url: "not a url")) }.to raise_error(described_class::ConfigurationError, /attribution_url/)
      expect { described_class.verify!(FakePriceSource.with(series: [ series, series ])) }.to raise_error(described_class::ConfigurationError, /series/)
      expect { described_class.verify!(FakePriceSource.with(series: [ "plain" ])) }.to raise_error(described_class::ConfigurationError, /series/)
    end

    it "accepts no address" do
      expect(described_class.verify!(FakePriceSource.with(attribution_url: nil))).to be_a(Class)
    end

    it "refuses a class that lacks a class member or an instance method", :aggregate_failures do
      expect { described_class.verify!(Class.new { def self.key = "x" }) }.to raise_error(described_class::ConfigurationError, /collectible_type/)
      expect { described_class.verify!(Class.new(FakePriceSource) { undef_method :each_quote }) }.to raise_error(described_class::ConfigurationError, /each_quote/)
      expect { described_class.verify!(Class.new(FakePriceSource) { undef_method :reported_on }) }.to raise_error(described_class::ConfigurationError, /reported_on/)
    end
  end
```

- [ ] Run: `bin/rspec spec/models/prices/sources_spec.rb -e "verify!"` — expect: FAIL (`undefined method 'verify!'`).
- [ ] Implement: add to `app/models/prices/sources.rb`, after `Malformed` and before the closing `end` of the module:

```ruby
  # The members a source class answers and the instance methods it defines: the table in this module's comment.
  CLASS_MEMBERS = %i[key collectible_type title attribution attribution_url hosted_paid_allowed? series].freeze
  INSTANCE_MEMBERS = %i[reported_on each_quote].freeze
  # A source key is stored and compared, so it is lower case letters, digits and underscores only.
  KEY = /\A[a-z0-9_]+\z/

  # Checks a class against the contract (see the comment of this module). A class and its members are all it sees, so
  # whether `.key` is the key the class is registered under, and whether `.collectible_type` is a key of
  # `Catalog.sources`, are the suite's to check for the registered sources.
  #
  # @param source_class [Class]
  # @return [Class] the same class, when it meets the contract
  # @raise [ConfigurationError] naming the first member that is missing or wrong
  def self.verify!(source_class)
    CLASS_MEMBERS.each { |member| refuse!(source_class, member, "is missing") unless source_class.respond_to?(member) }
    INSTANCE_MEMBERS.each { |member| refuse!(source_class, member, "is missing") unless source_class.method_defined?(member) }
    refuse!(source_class, :key, "must match #{KEY.inspect}") unless source_class.key.is_a?(String) && source_class.key.match?(KEY)
    %i[collectible_type title attribution].each do |member|
      value = source_class.public_send(member)
      refuse!(source_class, member, "must be a non-blank String, got #{value.inspect}") unless value.is_a?(String) && !value.strip.empty?
    end
    refuse!(source_class, :attribution_url, "must be nil or an https URL") unless https_or_nil?(source_class.attribution_url)
    unless [ true, false ].include?(source_class.hosted_paid_allowed?)
      refuse!(source_class, :hosted_paid_allowed?, "must be true or false, got #{source_class.hosted_paid_allowed?.inspect}")
    end
    verify_series!(source_class)
    source_class
  end

  # @api private
  def self.verify_series!(source_class)
    series = source_class.series
    unless series.is_a?(Array) && series.any? && series.all?(Series)
      refuse!(source_class, :series, "must be a non-empty Array of Prices::Sources::Series")
    end
    refuse!(source_class, :series, "has two equal entries") unless series.uniq.size == series.size
  end

  # @api private
  def self.https_or_nil?(url)
    return true if url.nil?
    return false unless url.is_a?(String)

    uri = URI.parse(url)
    uri.is_a?(URI::HTTPS) && !uri.host.to_s.empty?
  rescue URI::InvalidURIError
    false
  end

  # @api private
  def self.refuse!(source_class, member, problem)
    raise ConfigurationError, "#{source_class} #{member} #{problem}"
  end
```

  Note: `refuse!` and `verify_series!` and `https_or_nil?` are `@api private`, public methods of the module (a module's `private_class_method` would also do; keep them public with `@api private`, as the comment ratchet requires a summary on public methods and accepts `@api private`).

- [ ] Run: `bin/rspec spec/models/prices/sources_spec.rb spec/models/prices_spec.rb spec/price_source_core_spec.rb` — expect: PASS (about 18 examples, 0 failures).
- [ ] Run: `bin/rubocop app/models/prices.rb app/models/prices spec/support/fake_price_source.rb spec/models/prices_spec.rb spec/models/prices spec/price_source_core_spec.rb` — expect: no offenses.
- [ ] Commit: `feat(prices): verify a price source against the contract (#364)`

---

## Phase 2: The Scryfall source

**Implements:** FR-2 | **Satisfies:** AC-1.6, AC-2.1 to AC-2.11
**Files:** `app/models/mtg/scryfall/price_quotes.rb`, `config/initializers/prices.rb`, `spec/models/mtg/scryfall/price_quotes_spec.rb`, `spec/models/prices_spec.rb`
**Interfaces:** Consumes: Phase 1's `Prices::Sources::{Series, Quote, Malformed, IntegrityError}`, `Prices::Sources.verify!`, `Prices.sources`; the spec helpers `scryfall_card`, `gzip_jsonl` (`spec/support/scryfall_helpers.rb`); `MTG::Scryfall::Mapper.paper?`; `MTG::Scryfall::Source#each_entry`. Produces: `MTG::Scryfall::PriceQuotes` (`.key` "scryfall", `.collectible_type` "mtg", `.title`, `.attribution`, `.attribution_url`, `.hosted_paid_allowed?`, `.series`, `#reported_on(path)`, `#each_quote(path, languages:)`); the registration `Prices.sources["scryfall"]`.

### T2.1: The declaration and the day

The declaration here has no `hosted_paid_allowed?`: T2.4 adds it, with its spec, as a task of its own.

- [ ] Write `spec/models/mtg/scryfall/price_quotes_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Scryfall::PriceQuotes, type: :model do
  subject(:source) { described_class.new }

  let(:dir) { Pathname(Dir.mktmpdir) }

  after { FileUtils.rm_rf(dir) }

  def write_file(cards, name: "default-cards-20261113100623.jsonl.gz")
    dir.join(name).tap { |path| path.binwrite(gzip_jsonl(cards)) }
  end

  def read(cards, languages: [ "en" ], name: "default-cards-20261113100623.jsonl.gz")
    source.each_quote(write_file(cards, name:), languages:).to_a
  end

  def series(finish, currency) = Prices::Sources::Series.new(finish:, currency:, kind: "market")

  describe "its declaration (spec 085 decisions 5 and 10, AC-2.11)" do
    it "names Scryfall, with an attribution that says where each price comes from", :aggregate_failures do
      expect(described_class.key).to eq("scryfall")
      expect(described_class.collectible_type).to eq("mtg")
      expect(described_class.title).to eq("Scryfall")
      expect(described_class.attribution_url).to eq("https://scryfall.com")
      expect(described_class.attribution).to include("Scryfall", "TCGplayer's market price", "Cardmarket", "once a day")
    end

    it "quotes six series of kind market, with the finish names the collectible's vocabulary uses", :aggregate_failures do
      expect(described_class.series).to eq([ series("nonfoil", "USD"), series("foil", "USD"), series("etched", "USD"),
                                             series("nonfoil", "EUR"), series("foil", "EUR"), series("etched", "EUR") ])
      expect(MTG::Collecting.finish_order).to include(*described_class.series.map(&:finish))
    end
  end

  describe "#reported_on (spec 085 decision 4, AC-2.4)" do
    it "takes the day from the timestamp in the file's name, for a file with no cards too", :aggregate_failures do
      {
        "default-cards-20261113100623.jsonl.gz" => Date.new(2026, 11, 13),
        "all-cards-20261112235959.jsonl.gz" => Date.new(2026, 11, 12)
      }.each do |name, date|
        expect(source.reported_on(write_file([], name:))).to eq(date)
      end
    end

    it "refuses a name with no timestamp, or whose digits are not a date", :aggregate_failures do
      %w[cards.jsonl.gz default-cards-20261113.jsonl.gz default-cards-20261340100623.jsonl.gz].each do |name|
        expect { source.reported_on(dir.join(name)) }.to raise_error(Prices::Sources::IntegrityError, /#{Regexp.escape(name)}/)
      end
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb` — expect: FAIL (`uninitialized constant MTG::Scryfall::PriceQuotes`).
- [ ] Implement `app/models/mtg/scryfall/price_quotes.rb` (the declaration and `reported_on`; `each_quote` follows in T2.2):

```ruby
# The price source for Magic: The Gathering, backed by the `prices` object of Scryfall's bulk data file, the same file
# the catalog refresh reads (implements the contract in app/models/prices/sources.rb; spec 085). It stores what the file
# carries per printing, including the EUR a non-English printing copies from its English twin (research 083, ruling 41);
# which price a page shows for such a printing is a display rule, not a quote.
class MTG::Scryfall::PriceQuotes
  # The key in a card's `prices` object, in the order quotes are yielded, and the series it quotes. The 2026-11-13 file
  # has no etched EUR key in any object (research 083); it is read anyway, so one that appears is a quote. `tix`, the
  # MTGO price, and any other key are left out on purpose (spec 085 decision 5).
  SERIES_BY_KEY = {
    "usd" => Prices::Sources::Series.new(finish: "nonfoil", currency: "USD", kind: "market"),
    "usd_foil" => Prices::Sources::Series.new(finish: "foil", currency: "USD", kind: "market"),
    "usd_etched" => Prices::Sources::Series.new(finish: "etched", currency: "USD", kind: "market"),
    "eur" => Prices::Sources::Series.new(finish: "nonfoil", currency: "EUR", kind: "market"),
    "eur_foil" => Prices::Sources::Series.new(finish: "foil", currency: "EUR", kind: "market"),
    "eur_etched" => Prices::Sources::Series.new(finish: "etched", currency: "EUR", kind: "market")
  }.freeze

  # The UTC timestamp Scryfall puts at the end of a bulk file's name, the string the catalog keeps as the version.
  FILE_STAMP = /-(\d{4})(\d{2})(\d{2})\d{6}\.jsonl(?:\.gz)?\z/

  # The key this source is registered and stored under (price_sources.key); never changed once released.
  def self.key = "scryfall"

  # The catalog type whose printings these prices are for (a key of `Catalog.sources`).
  def self.collectible_type = "mtg"

  # The source's name, stored as price_sources.name.
  def self.title = "Scryfall"

  # Where a page links the attribution to.
  def self.attribution_url = "https://scryfall.com"

  # Spec 085 decision 10: what a page may say beside these prices.
  def self.attribution
    "Prices are provided by Scryfall. USD prices are TCGplayer's market price and EUR prices are Cardmarket's, " \
      "as Scryfall reports them. Scryfall updates them once a day."
  end

  # The series this source quotes: the six of SERIES_BY_KEY, in its order.
  #
  # @return [Array<Prices::Sources::Series>]
  def self.series = SERIES_BY_KEY.values

  # The day the file's data is from: the date in the UTC timestamp of its name (spec 085 decision 4).
  #
  # @param path [Pathname, String] a bulk file, such as `default-cards-20261113100623.jsonl.gz`; only its name is read
  # @return [Date]
  # @raise [Prices::Sources::IntegrityError] when the name has no timestamp, or its digits are not a date
  def reported_on(path)
    name = File.basename(path.to_s)
    year, month, day = FILE_STAMP.match(name)&.captures&.map(&:to_i)
    raise Prices::Sources::IntegrityError, "#{name}: the file's name carries no date, so no price can be given one" unless year && Date.valid_date?(year, month, day)

    Date.new(year, month, day)
  end
end
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb` — expect: PASS (`4 examples, 0 failures`).
- [ ] Commit: `feat(prices): the Scryfall price source's declaration and the day of its file (#364)`

### T2.2: Reading prices as quotes

- [ ] Add to `spec/models/mtg/scryfall/price_quotes_spec.rb`, inside the describe, after `#reported_on`:

```ruby
  describe "#each_quote (spec 085 decisions 5 and 6)" do
    let(:all_prices) do
      { "usd" => "1.42", "usd_foil" => "3.10", "usd_etched" => "5.00", "eur" => "1.20", "eur_foil" => "2.55", "eur_etched" => "4.10" }
    end

    it "yields a quote for each of the six prices, dated by the file (AC-2.1, AC-2.4)", :aggregate_failures do
      quotes = read([ scryfall_card("id" => "card-1", "prices" => all_prices) ])

      expect(quotes).to all(be_a(Prices::Sources::Quote))
      expect(quotes.map { |quote| [ quote.finish, quote.currency, quote.cents ] }).to eq(
        [ [ "nonfoil", "USD", 142 ], [ "foil", "USD", 310 ], [ "etched", "USD", 500 ], [ "nonfoil", "EUR", 120 ], [ "foil", "EUR", 255 ], [ "etched", "EUR", 410 ] ]
      )
      expect(quotes.map(&:external_key).uniq).to eq([ "card-1" ])
      expect(quotes.map(&:kind).uniq).to eq([ "market" ])
      expect(quotes.map(&:reported_on).uniq).to eq([ Date.new(2026, 11, 13) ])
    end

    it "takes each quote's day from the file's name (AC-2.4)" do
      quotes = read([ scryfall_card("prices" => { "usd" => "1.00" }) ], name: "all-cards-20261112235959.jsonl.gz")

      expect(quotes.map(&:reported_on)).to eq([ Date.new(2026, 11, 12) ])
    end

    it "yields a quote only for a price that is there, and no Malformed for one that isn't (AC-2.2)", :aggregate_failures do
      cards = [ scryfall_card("id" => "a", "prices" => { "usd" => nil, "usd_foil" => "2.00" }), scryfall_card("id" => "b", "prices" => {}),
                scryfall_card("id" => "c").except("prices"), scryfall_card("id" => "d", "prices" => nil) ]
      records = read(cards)

      expect(records.map { |record| [ record.class, record.external_key, record.finish ] }).to eq([ [ Prices::Sources::Quote, "a", "foil" ] ])
    end

    it "leaves out tix and a key it doesn't know (AC-2.3)" do
      expect(read([ scryfall_card("prices" => { "tix" => "0.03", "usd_gold" => "9.00" }) ])).to eq([])
    end

    it "leaves out a card that is not a paper printing or not in a requested language (AC-2.5)", :aggregate_failures do
      cards = [ scryfall_card("id" => "digital", "digital" => true), scryfall_card("id" => "no-paper", "games" => [ "mtgo" ]),
                scryfall_card("id" => "ja", "lang" => "ja"), scryfall_card("id" => "en") ]

      expect(read(cards).map(&:external_key)).to eq([ "en" ])
      expect(read(cards, languages: [ "en", "ja" ]).map(&:external_key)).to eq([ "ja", "en" ])
    end

    it "turns a price into cents from its digits, never through a float (AC-2.6)" do
      prices = { "0.05" => 5, "10" => 1000, "1234.5" => 123_450, "0.00" => 0, "0.29" => 29, "999999999.99" => 99_999_999_999 }
      cards = prices.keys.each_with_index.map { |value, index| scryfall_card("id" => "c#{index}", "prices" => { "usd" => value }) }

      expect(read(cards).map(&:cents)).to eq(prices.values)
    end

    it "yields a Malformed that names the series for a price it can't read, and goes on with the card's others (AC-2.6)", :aggregate_failures do
      bad = [ "1.234", "-1", "+1", "abc", "", "1,42", ".5", "1.", " 1.42", "1e2", "1234567890.00", 1.42 ]
      cards = bad.each_with_index.map { |value, index| scryfall_card("id" => "c#{index}", "prices" => { "usd" => value, "usd_foil" => "2.00" }) }
      records = read(cards)

      malformed = records.grep(Prices::Sources::Malformed)
      expect(malformed.map(&:external_key)).to eq(bad.each_index.map { |index| "c#{index}" })
      expect(malformed.map(&:series).uniq).to eq([ series("nonfoil", "USD") ])
      expect(malformed.map(&:error)).to all(include("prices.usd"))
      expect(records.grep(Prices::Sources::Quote).map(&:cents)).to all(eq(200))
      expect(records.grep(Prices::Sources::Quote).size).to eq(bad.size)
    end

    it "yields a Malformed for a line it can't read as a card, and goes on (AC-2.7)", :aggregate_failures do
      lines = [ "not json", scryfall_card("id" => "x").except("id"), scryfall_card("id" => "c3", "prices" => "oops"), "",
                scryfall_card("digital" => true, "games" => [ "mtgo" ]).except("id"), scryfall_card("id" => "good", "prices" => { "usd" => "1.00" }) ]
      records = read(lines)

      expect(records.map(&:class)).to eq([ Prices::Sources::Malformed ] * 3 + [ Prices::Sources::Quote ])
      expect(records.first(3).map { |record| [ record.external_key, record.series ] }).to eq([ [ nil, nil ], [ nil, nil ], [ "c3", nil ] ])
      expect(records.last.external_key).to eq("good")
    end
  end
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb` — expect: FAIL (`undefined method 'each_quote'`).
- [ ] Implement: add to `app/models/mtg/scryfall/price_quotes.rb`, after `reported_on` (a `PRICE` constant goes with the other constants, after `FILE_STAMP`):

```ruby
  # A price as Scryfall writes it: whole dollars or euros with at most two decimals. Nine integer digits (below a
  # billion) keep a garbled value from becoming a price (spec 085 decision 6).
  PRICE = /\A\d{1,9}(\.\d{1,2})?\z/
```

```ruby
  # Yields a quote for every price the bulk file carries, for the paper printings in the given languages, one card at a
  # time (spec 085 decisions 3, 5 and 6). It makes no network call, writes nothing and applies no twin rule. A price
  # that is null or missing has no quote; one that can't be read is a `Malformed` that names its series (so it isn't
  # taken for an absence), and a card that can't be read at all is a `Malformed` too. Blank lines are skipped.
  #
  # @param path [Pathname, String] the gzip'd JSON Lines file the catalog refresh downloaded
  # @param languages [Array<String>] the languages the catalog holds (`MTG::Scryfall::Source#languages`)
  # @yieldparam record [Prices::Sources::Quote, Prices::Sources::Malformed]
  # @return [Enumerator, nil] an Enumerator when no block is given
  # @raise [Prices::Sources::IntegrityError] before yielding anything, when the file's name carries no date
  # @raise [Zlib::Error] from the reader, when the file is corrupt or cut short; quotes already yielded stay yielded
  def each_quote(path, languages:, &block)
    return enum_for(:each_quote, path, languages:) unless block

    date = reported_on(path)
    allowed = languages.to_set
    File.open(path, "rb") do |file|
      Zlib::GzipReader.wrap(file) do |gzip|
        gzip.each_line { |line| each_card_record(line, allowed, date, &block) }
      end
    end
    nil
  end

  private
    def each_card_record(line, allowed, date)
      return if line.strip.empty?

      card = parse(line)
      return yield(card) if card.is_a?(Prices::Sources::Malformed)
      return yield(malformed(nil, "the line is not a JSON object")) unless card.is_a?(Hash)
      return unless allowed.include?(card["lang"]) && MTG::Scryfall::Mapper.paper?(card)

      id = card["id"]
      return yield(malformed(nil, "the card has no id")) unless id.is_a?(String) && !id.strip.empty?

      prices = card["prices"]
      return if prices.nil?
      return yield(malformed(id, "prices is not an object")) unless prices.is_a?(Hash)

      each_price_record(id, prices, date) { |record| yield record }
    end

    def each_price_record(id, prices, date)
      SERIES_BY_KEY.each do |key, series|
        value = prices[key]
        next if value.nil?

        cents = cents_from(value)
        if cents
          yield Prices::Sources::Quote.new(external_key: id, finish: series.finish, currency: series.currency, kind: series.kind, cents:, reported_on: date)
        else
          yield malformed(id, "prices.#{key} #{value.inspect} is not a price of whole cents", series)
        end
      end
    end

    def parse(line)
      JSON.parse(line)
    rescue JSON::ParserError => error
      malformed(nil, "#{error.class}: #{error.message}")
    end

    def malformed(external_key, error, series = nil) = Prices::Sources::Malformed.new(external_key:, error:, series:)

    # Whole cents from the digits of a price string; nil for anything else. No Float: 0.29 * 100 is 28.999…
    def cents_from(value)
      return unless value.is_a?(String) && value.match?(PRICE)

      whole, fraction = value.split(".")
      (whole.to_i * 100) + fraction.to_s.ljust(2, "0").to_i
    end
```

  Note: `private` with indented methods follows the repo style (`MTG::Scryfall::Source`). The class has no `initialize`, so `.new` takes no arguments.

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb` — expect: PASS (12 examples, 0 failures).
- [ ] Commit: `feat(prices): the Scryfall price source reads quotes from the bulk file (#364)`

### T2.3: The catalog's file, the twin, streaming and a timing

- [ ] Add to `spec/models/mtg/scryfall/price_quotes_spec.rb`, inside the `#each_quote` describe, before its closing `end`:

```ruby
    it "yields a non-English printing's copied EUR as that printing's own quote, with no USD and no twin lookup (AC-2.8, ruling 41)", :aggregate_failures do
      cards = [ scryfall_card("id" => "en-1", "cardmarket_id" => 7, "prices" => { "usd" => "1.00", "eur" => "0.50" }),
                scryfall_card("id" => "ja-1", "lang" => "ja", "cardmarket_id" => 7, "prices" => { "usd" => nil, "eur" => "0.50" }) ]
      records = read(cards, languages: [ "en", "ja" ])

      expect(records.select { |record| record.external_key == "ja-1" }.map { |record| [ record.finish, record.currency, record.cents ] }).to eq([ [ "nonfoil", "EUR", 50 ] ])
      expect(records.size).to eq(3)
    end

    it "reads the file the catalog reads, and calls no one (AC-2.9)", :aggregate_failures do
      path = write_file([ scryfall_card("id" => "card-1", "prices" => { "usd" => "1.00" }), scryfall_card("id" => "card-2", "prices" => { "eur" => "2.00" }) ])
      entries = []
      MTG::Scryfall::Source.new.each_entry(path, languages: [ "en" ]) { |record| entries << record }

      expect(entries.map(&:external_key)).to eq([ "card-1", "card-2" ])
      expect(source.each_quote(path, languages: [ "en" ]).map(&:external_key)).to eq(entries.map(&:external_key))
      expect(a_request(:any, /.*/)).not_to have_been_made
    end

    it "reads the file as a stream: the first card's quotes arrive before a cut-short file's error (AC-2.10)", :aggregate_failures do
      io = StringIO.new
      gzip = Zlib::GzipWriter.new(io)
      gzip.puts(JSON.generate(scryfall_card("id" => "first", "prices" => { "usd" => "1.00" })))
      gzip.flush # the first line is readable; the stream's end is never written
      bytes = io.string.dup
      gzip.close # closed after the copy, so it doesn't warn at garbage collection
      path = dir.join("default-cards-20261113100623.jsonl.gz")
      path.binwrite(bytes)
      yielded = []

      expect { source.each_quote(path, languages: [ "en" ]) { |record| yielded << record } }.to raise_error(Zlib::GzipFile::Error)
      expect(yielded.map(&:external_key)).to eq([ "first" ])
    end

    it "refuses a file with no date before it yields anything (AC-2.4)", :aggregate_failures do
      path = dir.join("cards.jsonl.gz")
      path.binwrite(gzip_jsonl([ scryfall_card ]))
      yielded = []

      expect { source.each_quote(path, languages: [ "en" ]) { |record| yielded << record } }.to raise_error(Prices::Sources::IntegrityError)
      expect { source.each_quote(path, languages: [ "en" ]).to_a }.to raise_error(Prices::Sources::IntegrityError)
      expect(yielded).to be_empty
    end

    # Measured, never gating (spec 085 NFR): the time to read a file of 50,000 cards, for #365 and #366 to plan from.
    it "reads 50,000 cards", :timing do
      cards = Array.new(50_000) { |index| scryfall_card("id" => "c#{index}", "prices" => all_prices) }
      path = write_file(cards)
      count = 0
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      source.each_quote(path, languages: [ "en" ]) { count += 1 }
      seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      RSpec.configuration.reporter.message "price quotes: #{count} quotes from 50,000 cards in #{seconds.round(2)} s"
      expect(count).to eq(300_000)
    end
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb` — expect: PASS for the new examples (the timing one is excluded by default), because T2.2's code already has the behaviour they check. Show each can fail, then restore the code, recording the four results in the commit body. Run each break with only its named example (`-e` and part of its description), since a break can fail other examples too: (1) in `each_quote` replace `date = reported_on(path)` with `date = Date.new(2026, 11, 13)` → the no-date example and T2.2's all-cards date example fail; (2) replace `gzip.each_line` with `gzip.read.each_line` → the stream example fails (`yielded` stays empty); (3) change the quote's `external_key: id` to `external_key: id.upcase` in `each_price_record` → the catalog-file example fails; (4) add `return unless card["lang"] == "en"` after the `card.is_a?(Hash)` guard in `each_card_record` → the Japanese-twin example fails. Restore all four before the commit.
- [ ] Run once with the timing example: `SCANNER_TIMING=1 bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb -e "reads 50,000 cards"` — expect: PASS and a line `price quotes: 300000 quotes from 50,000 cards in N s`; record N in the commit body (Phase 5 copies it into `verification.md`).
- [ ] Commit: `test(prices): the Scryfall source reads the catalog's file as a stream (#364)`

### T2.4: The hosted flag, and the registration

The maintainer ruled the value `true` on 2026-11-13 (rulings 27, 37, 38); issue #362 is open and may change it. It is written in one place, with its example in this task alone.

- [ ] Add to `spec/models/mtg/scryfall/price_quotes_spec.rb`, as its own describe after `#reported_on` and before `#each_quote`:

```ruby
  # Spec 085 decision 9: ruled true by the maintainer on 2026-11-13; issue #362 may change it. A ruling of false changes this
  # example, the one line `hosted_paid_allowed?` in the class and the sentence in prices.md that states it, and nothing else.
  describe ".hosted_paid_allowed? (decision 9, AC-2.11)" do
    it "says a hosted instance with paid plans may show Scryfall's prices, and so meets the contract", :aggregate_failures do
      expect(described_class.hosted_paid_allowed?).to be(true)
      expect(Prices::Sources.verify!(described_class)).to eq(described_class)
    end
  end
```

- [ ] Add to `spec/models/prices_spec.rb`, a second top-level describe inside `RSpec.describe Prices` (outside the registry's `around`; AC-1.6):

```ruby
  describe "the registered sources (spec 085, AC-1.6)" do
    it "each meet the contract, under their own key, for a collectible the catalog has", :aggregate_failures do
      expect(described_class.sources.keys).to include("scryfall")
      described_class.sources.each do |key, class_name|
        source_class = class_name.constantize

        expect(Prices::Sources.verify!(source_class)).to eq(source_class)
        expect(source_class.key).to eq(key)
        expect(Catalog.sources).to have_key(source_class.collectible_type)
      end
      expect(described_class.source_class("scryfall")).to eq(MTG::Scryfall::PriceQuotes)
      expect(described_class.sources_for("mtg")).to eq([ MTG::Scryfall::PriceQuotes ])
    end
  end
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb spec/models/prices_spec.rb` — expect: FAIL (`undefined method 'hosted_paid_allowed?'`; `"scryfall"` not registered).
- [ ] Implement: add to `app/models/mtg/scryfall/price_quotes.rb` after `self.attribution_url`:

```ruby
  # Spec 085 decision 9, ruled true by the maintainer on 2026-11-13: ruling 27 allows this source's data on a hosted instance
  # with paid plans while it stays publicly accessible, and rulings 37 and 38 show prices to everyone who can see the
  # card. The one place the value is written; issue #362 (Scryfall's written answer) is open and may change it.
  def self.hosted_paid_allowed? = true
```

  and create `config/initializers/prices.rb`:

```ruby
# Price sources, one per source key (see app/models/prices/sources.rb); each names the collectible type its prices are for.
Rails.application.config.to_prepare do
  Prices.sources["scryfall"] = "MTG::Scryfall::PriceQuotes"
end
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb spec/models/prices_spec.rb spec/price_source_core_spec.rb` — expect: PASS (about 22 examples, 0 failures).
- [ ] Run: `bin/rubocop app/models/mtg/scryfall/price_quotes.rb config/initializers/prices.rb spec/models/mtg/scryfall/price_quotes_spec.rb spec/models/prices_spec.rb` — expect: no offenses.
- [ ] Commit: `feat(prices): Scryfall's hosted flag and the source's registration (#364)`

---

## Phase 3: The rows for sources and series

**Implements:** FR-3 | **Satisfies:** AC-3.1 to AC-3.7
**Files:** `app/models/price_series.rb`, `app/models/price_source.rb`, `app/models/prices_record.rb`, `spec/models/price_series_spec.rb`, `spec/models/price_source_spec.rb`
**Interfaces:** Consumes: `PricesRecord`; `Prices::Sources::Series`, `Prices::Sources.verify!`, `Prices::Sources::ConfigurationError`; `FakePriceSource`; `MTG::Scryfall::PriceQuotes`. Produces: `PriceSeries.ensure!(series)` → Hash `{ Prices::Sources::Series => PriceSeries }`; `PriceSource.sync!(source_class)` → the `PriceSource` row.

### T3.1: `PriceSeries`

- [ ] Write `spec/models/price_series_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe PriceSeries, type: :model do
  let(:plain) { Prices::Sources::Series.new(finish: "plain", currency: "USD", kind: "market") }
  let(:shiny) { Prices::Sources::Series.new(finish: "shiny", currency: "USD", kind: "market") }

  describe ".ensure! (spec 085 decision 7, AC-3.5)" do
    it "returns the row of each declared series, keyed by the series, creating the ones that are missing", :aggregate_failures do
      existing = described_class.create!(finish: "plain", currency: "USD", kind: "market")
      rows = described_class.ensure!([ plain, shiny ])

      expect(rows.keys).to eq([ plain, shiny ])
      expect(rows[plain]).to eq(existing)
      expect(rows[shiny]).to have_attributes(finish: "shiny", currency: "USD", kind: "market", persisted?: true)
      expect(described_class.count).to eq(2)
    end

    it "finds a quote's row by the quote's series" do
      quote = Prices::Sources::Quote.new(external_key: "abc-1", finish: "shiny", currency: "USD", kind: "market", cents: 5, reported_on: Date.new(2026, 11, 13))

      expect(described_class.ensure!([ plain, shiny ])[quote.series].finish).to eq("shiny")
    end

    it "is idempotent: a second call adds no row and changes no id", :aggregate_failures do
      first = described_class.ensure!([ plain, shiny ]).values.map(&:id)

      expect(described_class.ensure!([ plain, shiny ]).values.map(&:id)).to eq(first)
      expect(described_class.count).to eq(2)
    end
  end

  describe "the table (spec 085 decision 7, AC-3.7)" do
    it "is in the prices database, global, and a table the primary database lacks", :aggregate_failures do
      expect(described_class.connection_db_config.name).to eq("prices")
      expect(described_class.table_name).to eq("price_series")
      expect(described_class.column_names).not_to include("account_id", "user_id")
      expect(ActiveRecord::Base.lease_connection.table_exists?("price_series")).to be(false)
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/price_series_spec.rb` — expect: FAIL (`uninitialized constant PriceSeries`).
- [ ] Implement `app/models/price_series.rb`:

```ruby
# What a price means: a finish, an ISO 4217 currency and a kind, in the prices database (spec 081 decision 2). Series are
# global, not per source, so two sources that quote the same finish, currency and kind share one row. A row is written
# from a source's declaration (its `.series`), never by a migration (spec 085 decision 7).
#
# There is no uniqueness validation: the unique index on finish, currency and kind is the guard, and `ensure!` creates
# through it, so a caller that loses a race reads the winner's row instead of failing a validation.
#
# @see file:prices.md
class PriceSeries < PricesRecord
  validates :finish, :kind, presence: true
  validates :currency, format: { with: Prices::Sources::CURRENCY }

  # The rows of the given series, each created if it doesn't exist. Idempotent and safe from two processes at once; never
  # deletes a row. Writes to the prices database only.
  #
  # @param series [Array<Prices::Sources::Series>] declared series
  # @return [Hash{Prices::Sources::Series => PriceSeries}] a row for each series, so `ensure!(series)[quote.series]` is a
  #   quote's row
  def self.ensure!(series)
    series.to_h do |declared|
      attributes = declared.to_h
      [ declared, find_by(attributes) || create_or_find_by!(attributes) ]
    end
  end
end
```

  Note: `Hash{…}` in a YARD `@return` is YARD type syntax, not a brace link; it builds without warning. If `bin/yard doc` warns on it, write `Hash` and describe the keys in words.

- [ ] Run: `bin/rspec spec/models/price_series_spec.rb spec/price_source_core_spec.rb` — expect: PASS (`6 examples, 0 failures`; the guard now also reads `price_series.rb`).
- [ ] Commit: `feat(prices): PriceSeries rows from a source's declaration (#364)`

### T3.2: `PriceSource`, and `PricesRecord`'s comment

- [ ] Write `spec/models/price_source_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe PriceSource, type: :model do
  describe ".sync! (spec 085 decision 7)" do
    it "writes the source and its six series from the Scryfall declaration (AC-3.1)", :aggregate_failures do
      source = described_class.sync!(MTG::Scryfall::PriceQuotes)

      expect(source).to have_attributes(key: "scryfall", name: "Scryfall", attribution_url: "https://scryfall.com", hosted_paid_allowed: MTG::Scryfall::PriceQuotes.hosted_paid_allowed?,
                                        attribution: MTG::Scryfall::PriceQuotes.attribution, persisted?: true)
      expect(described_class.count).to eq(1)
      expect(PriceSeries.pluck(:finish, :currency, :kind)).to match_array(MTG::Scryfall::PriceQuotes.series.map { |series| series.to_h.values })
    end

    it "is idempotent: a second call adds no row, changes no id and leaves the row untouched (AC-3.2)", :aggregate_failures do
      first = described_class.sync!(FakePriceSource)
      updated_at = first.reload.updated_at
      second = described_class.sync!(FakePriceSource)

      expect(second.id).to eq(first.id)
      expect(second.reload.updated_at).to eq(updated_at)
      expect([ described_class.count, PriceSeries.count ]).to eq([ 1, 1 ])
    end

    it "updates a source row whose declaration changed, keeping its id, and never deletes a series (AC-3.3)", :aggregate_failures do
      two = [ Prices::Sources::Series.new(finish: "plain", currency: "USD", kind: "market"), Prices::Sources::Series.new(finish: "shiny", currency: "USD", kind: "market") ]
      first = described_class.sync!(FakePriceSource.with(series: two))
      corrected = described_class.sync!(FakePriceSource.with(attribution: "Corrected text.", series: [ two.first ]))

      expect(corrected.id).to eq(first.id)
      expect(corrected.reload.attribution).to eq("Corrected text.")
      expect(PriceSeries.count).to eq(2)
    end

    it "gives two sources that quote the same series one series row (AC-3.4)", :aggregate_failures do
      described_class.sync!(FakePriceSource)
      described_class.sync!(FakePriceSource.with(key: "other_fake"))

      expect(described_class.count).to eq(2)
      expect(PriceSeries.count).to eq(1)
    end

    it "writes nothing for a source that fails the contract (AC-3.6)", :aggregate_failures do
      expect { described_class.sync!(FakePriceSource.with(title: "")) }.to raise_error(Prices::Sources::ConfigurationError, /title/)
      expect([ described_class.count, PriceSeries.count ]).to eq([ 0, 0 ])
    end
  end

  describe "the table (AC-3.7)" do
    it "is in the prices database, global, and a table the primary database lacks", :aggregate_failures do
      expect(described_class.connection_db_config.name).to eq("prices")
      expect(described_class.column_names).not_to include("account_id", "user_id")
      expect(ActiveRecord::Base.lease_connection.table_exists?("price_sources")).to be(false)
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/price_source_spec.rb` — expect: FAIL (`uninitialized constant PriceSource`).
- [ ] Implement `app/models/price_source.rb`:

```ruby
# Where prices come from, in the prices database (spec 081 decision 2): a key, a name, the attribution a page shows and
# whether a hosted instance with paid plans may show the source. A row is written from the source class's own
# declaration (`Prices::Sources`), so the text ships with the build and takes effect at the next sync, and no migration
# seeds it (spec 085 decision 7).
#
# @see file:prices.md
class PriceSource < PricesRecord
  validates :key, :name, :attribution, presence: true
  validates :hosted_paid_allowed, inclusion: { in: [ true, false ] }

  # The row of a price source, created or brought up to date from its declaration, and the rows of the series it
  # declares (`PriceSeries.ensure!`). Idempotent, safe to call at the start of every run and from two processes at once
  # (a lost race on the unique key is retried once), and a call that changes nothing writes nothing. Never deletes a
  # source or a series. Writes to the prices database only.
  #
  # @param source_class [Class] a class that implements `Prices::Sources`
  # @return [PriceSource] the row
  # @raise [Prices::Sources::ConfigurationError] when the class doesn't meet the contract; nothing is written
  def self.sync!(source_class)
    Prices::Sources.verify!(source_class)
    PriceSeries.ensure!(source_class.series)
    attempts = 0
    begin
      find_or_initialize_by(key: source_class.key).tap do |source|
        source.assign_attributes(name: source_class.title, attribution: source_class.attribution, attribution_url: source_class.attribution_url,
                                 hosted_paid_allowed: source_class.hosted_paid_allowed?)
        source.save!
      end
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      retry if attempts < 2
      raise
    end
  end
end
```

  and replace in `app/models/prices_record.rb` the sentence `This class has no models yet: #364 to #366 add them.` with `Its models so far are PriceSource and PriceSeries (spec 085); #365 and #366 add the rest.`

- [ ] Run: `bin/rspec spec/models/price_source_spec.rb spec/models/price_series_spec.rb spec/models/prices_record_spec.rb spec/price_source_core_spec.rb spec/prices_core_spec.rb spec/prices_schema_spec.rb` — expect: PASS (0 failures). If `prices_record_spec.rb` asserts the comment's old words or "no models", report it; do not weaken it.
- [ ] Run: `bin/rubocop app/models spec/models/price_source_spec.rb spec/models/price_series_spec.rb` — expect: no offenses.
- [ ] Run: `git status --short db/` — expect: no change to `db/prices_structure.sql` or any schema file.
- [ ] Commit: `feat(prices): PriceSource rows from a source's declaration (#364)`

---

## Phase 4: The documents

**Implements:** Story 4 | **Satisfies:** AC-4.2 (comments, YARD, lint), AC-4.3
**Files:** `docs/architecture/prices.md`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md`, `docs/specs/085-price-source-contract/verification.md`
**Interfaces:** Consumes: the code of Phases 1–3. Produces: documents that say what the code does, each statement with its source.

### T4.1: The area doc

- [ ] Edit `docs/architecture/prices.md` (reading its current text first; keep its shape):
  - **Scope:** replace "The price source contract (#364), the daily refresh (#365), …" so the contract is no longer to come: it covers "the prices database …, and the price source contract with Scryfall's source and the rows of sources and series (spec 085)"; the refresh (#365), run record (#366), admin log (#367), history levels (#368), display (#369) and cost documentation (#370) still extend it.
  - **Glossary:** add *Quote* (one price of one printing in one series from one source on one reported day; `Prices::Sources::Quote`), *Reported on* (the day a source's data is from, from the file's name for Scryfall), and one line that says `PriceSource` (the model, a row), `Prices::Sources` (the contract) and `Prices.sources` (the registry) are three things (spec 085 decisions 1, 7 and 11).
  - **Invariants:** add (each with its source in parentheses), including: the date reported is the UTC date in the file's name, and a name with no date, or digits that are not one, is refused before any quote is yielded, because a guessed date would put a wrong day into history that can't be fetched again (decision 4); a price becomes cents from its digits, never through a float, and anything that isn't one to nine digits with at most two decimals is a `Malformed` that names its series (decision 6); the contract's comment in `app/models/prices/sources.rb` is the one place it is written, and core files name no collectible (`spec/price_source_core_spec.rb`; decisions 1 and 12, AC-4.1); a source yields only the prices its file carries, a price the file leaves empty has no quote, and a `Malformed` with a series, or with a key and no series, is not an absence while one with no key makes the run's absences untrustworthy (decision 2); `each_quote` makes no network call, writes nothing and reads no database, and the contract has no members that fetch the file, which is #365's (decision 3); the quotes store what the file carries, including the EUR a non-English printing copies from its English twin, and the choice of the twin is a display rule that #369 owns (ruling 41, research 083; decision 5); source and series rows are written by `PriceSource.sync!` and `PriceSeries.ensure!` from the declaration, never seeded by a migration, never deleted (decision 7); the models built are `PriceSource` and `PriceSeries`, and `CurrentPrice`, `PriceChange` and `PriceRefreshRun` are #365's and #366's (decision 8); `hosted_paid_allowed?` is stated and stored and nothing refuses a source by it yet, because no setting for the kind of instance exists (hosted mode, #392, adds one), and Scryfall's is `true`, ruled by the maintainer on 2026-11-13 (rulings 27, 37 and 38), with #362 open and its answer able to change the value (decision 9).
  - **Named constants:** add `MTG::Scryfall::PriceQuotes::SERIES_BY_KEY` (six series; the 2026-11-13 file has no etched EUR key, read anyway; research 083, decision 5), `PRICE` (`\A\d{1,9}(\.\d{1,2})?\z`, decision 6) and `FILE_STAMP` (decision 4), each as a row of the table's five columns (Name, Value, Where, Why, Source); add `Prices::Sources::CURRENCY` and `KEY` too.
  - **Decisions not in an ADR:** rewrite the bullet "No model per table yet": two models exist now (`PriceSource`, `PriceSeries`) and three are left to #365 and #366 (decision 8). Then add "the attribution wording and the hosted flag are the source's declaration" and "no ADR: the contract's comment is the contract" with the source (Gate A, 2026-11-13).
  - **Sources:** add spec 085 (decisions 1 to 12), research 083 and ruling 41, roadmap rulings 27, 37 and 38 (the hosted flag), issues #364 and #362.
  - **Distillation log:** leave for `distill-feature`, which also adds spec 085 to the Prices row of `docs/architecture/README.md` (the area map).
- [ ] Run: `bin/yard doc` — expect: builds with no warnings.
- [ ] Commit: `docs(architecture): the price source contract in the prices area doc (#364)`

### T4.2: CLAUDE.md, the roadmap and the specs index

- [ ] Edit `CLAUDE.md`: in the Project Status paragraph, replace "whose five tables exist with no reader or writer yet" with "whose five tables exist, with a price source contract and Scryfall's prices through it (`Prices::Sources`, `MTG::Scryfall::PriceQuotes`, `PriceSource.sync!`; spec 085, #364) and no refresh or reader yet". Do not restate the area doc's rules.
- [ ] Edit `docs/roadmap.md`, the prices lane: the #364 line gains "Done: [spec 085](specs/085-price-source-contract/spec.md)." in the form the #361 line uses.
- [ ] Edit `docs/specs/README.md`: the 085 row already exists (added with the plan, when the spec was written: `.claude/rules/documentation.md`); leave it as it is, and in the 083 row (read it first; keep its links) replace its Status clause "nothing distilled yet: the prices area doc takes ruling 41 when [#364](…) is specified" with "ruling 41 is distilled into [prices](../architecture/prices.md) with spec 085", and the start of its Areas cell "None yet: the prices lane" with "[Prices](../architecture/prices.md); the prices lane".
- [ ] Run: `bin/yard doc` — expect: no warnings. (`bin/ci checks` needs a slot and runs in Phase 5.)
- [ ] Commit: `docs: spec 085 in CLAUDE.md, the roadmap and the specs index (#364)`

---

## Phase 5: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run the spec's files together: `bin/rspec spec/models/prices_spec.rb spec/models/prices spec/models/mtg/scryfall/price_quotes_spec.rb spec/models/price_series_spec.rb spec/models/price_source_spec.rb spec/price_source_core_spec.rb spec/prices_core_spec.rb spec/prices_schema_spec.rb spec/models/prices_record_spec.rb` — expect: 0 failures; record the count.
- [ ] Run `bin/rails zeitwerk:check` — expect: `All is good!`.
- [ ] Record in `verification.md` that the guard matches substrings, stricter than AC-4.1's "as a word", and why (issue #209).
- [ ] Verify AC-1.1's comment, AC-4.2 and AC-4.3 by reading, and record each in `docs/specs/085-price-source-contract/verification.md` with the evidence (commands and output).
- [ ] After a slot is granted: `bin/ci` — expect: all steps pass (the comment ratchet included).
- [ ] The implementation review (`sdd-review` Mode B, Opus 5.5, read-only) is recorded in `verification.md` under `## Implementation review`, verdict first.

## Quickstart Validation

Not a UI feature. After `bin/rails db:prepare`, in the suite:

```
bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb spec/models/price_source_spec.rb
SCANNER_TIMING=1 bin/rspec spec/models/mtg/scryfall/price_quotes_spec.rb -e "reads 50,000 cards"
```

expect: 0 failures, and the timing line. The Scryfall source's real file is exercised by #365.
