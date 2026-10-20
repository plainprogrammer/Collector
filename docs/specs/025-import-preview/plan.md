# Plan 025: Preview an Import

**Spec:** [spec.md](spec.md) (1.5.0, approved 2026-10-15) · **Decisions:** [ADR 0021](../../adr/0021-export-format-rules-in-the-app.md) · **Issue:** [#39](https://github.com/plainprogrammer/Collector/issues/39) · **Branch:** `025-import-preview`
**Status:** Approved by the maintainer (2026-10-15) with two changes, both applied: the memory bar is 500 MB (spec decision 13), and spec 022 isn't edited (spec decision 14). A read-only Opus plan review's findings are applied.
**Created:** 2026-10-15

## Global Constraints

- Format version 1, `docs/export-format/` (document, schema, examples, Coverage tables) is not edited.
- Nothing is written by a preview: no row, file, cache entry or job (FR-6). The file is read in the request and kept nowhere.
- Tenant data is reached only through `Current.account` and its associations (FR-5).
- The reader's and pages' code never names a collectible type or source (FR-9): no `MTG`, no `Scryfall`.
- Sizes: a file over `CollectionImport::MAX_BYTES` (32,000,000 bytes) is refused before parsing; every server layer refuses a body over 40,000,000 bytes.
- Lists show at most `CollectionImport::LIST_LIMIT` (100) entries, then "and N more" (decision 11).
- AC-1.10's bar: a 50,000-row file previews in under 30 seconds with under 500 MB RSS growth (decisions 12 and 13).
- TDD: each phase writes its failing examples first, runs them red, then the code, then green. One Conventional Commit per step; `git add` and `git commit` as separate commands; every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, exactly that name.
- UI follows `collector-design-system`: existing `c-*` classes, plus one new pattern (`ImportPreview`) in `collector/additions.css` with its doc.
- No code in this plan was run before the review (maintainer's rule of 2026-10-15). Execution verifies it, red then green; a block that needs a fix is fixed in execution and the fix is recorded in the commit body and `verification.md`.

## Goal

A signed-in collector opens "Import collection", uploads an export file, and sees what applying it would do to their collection (added, changed, unchanged, held, removed), every row that can't be applied with its reasons, or why the whole file is refused, with nothing written.

## Pre-implementation gates

- **Simplicity:** three units: `ExportFormat::Rules` (well-formedness, moved from the suite), `CollectionImport` (the reader), and the pages (`Collections::ImportPreviewsController`, two views, a helper). The request-body limits are configuration.
- **Anti-abstraction:** the reader is one plain model with value objects (`Data.define`) for its results; no service layer, no form object.
- **Integration-first:** the reader's interface (below) is fixed in Phase 2's spec before the pages use it.

## Phase 0: Branch state

Branch `025-import-preview` on `origin/main` 6b422d1; `bin/setup --skip-server` has run in the worktree. Spec commit `181a700`. This plan and ADR 0021 are committed together after approval: `docs(025): plan and ADR 0021, approved`.

---

## Phase 1: The format's rules in the app

**Implements:** FR-2, decision 5 (ADR 0021) | **Satisfies:** AC-2.7
**Files:** `Gemfile`, `app/models/export_format/v1.schema.json` (new, a copy), `spec/models/export_format/rules_spec.rb` (new), `app/models/export_format/rules.rb` (new), `spec/support/export_format_rules.rb`
**Interfaces:** Consumes nothing. Produces `ExportFormat::Rules` with `Problem` (`Data.define(:rule, :at)`), `FORMAT`, `VERSION`, `RULES`, `SCHEMA_FILE`, `.schema`, `.parse(bytes)` → `[data, nil]` or `[nil, Problem]`, `.problems(bytes)` → `[Problem]`, `.problems_in(data)` → `[Problem]`, `.identity(lot)` → Array, `.identity_readable?(lot, at, failed)` → Boolean (`failed` a Set of pointers).

The rules move from the suite into the app. Two things change in how they apply (spec FR-2): the time rules and `duplicate_lot` now run beside the schema's problems rather than only when the schema passes, each limited to the values the schema accepted. Every example and variant the suite already checks keeps its single expected problem.

### Step 1.1: Gemfile and the schema copy

In `Gemfile`, remove these two lines from `group :test`:

```ruby
  # Checks the export format's examples against its JSON Schema (spec 017); never loaded by the running app.
  gem "json_schemer", "~> 2.4", require: false
```

and add after `gem "ruby-vips", "~> 2.3", require: false` (with a blank line before):

```ruby

# Checks export files against the format's JSON Schema, in the app (spec 025, ADR 0021) and in the suite (spec 017).
gem "json_schemer", "~> 2.4", require: false
```

Then copy the schema:

```sh
cp docs/export-format/v1.schema.json app/models/export_format/v1.schema.json
bundle install
```

`Gemfile.lock` doesn't record groups, so it is unchanged (`git diff --stat Gemfile.lock` prints nothing).

### Step 1.2: Failing examples

`spec/models/export_format/rules_spec.rb`:

```ruby
require "rails_helper"

# Spec 025 decision 5 (ADR 0021): the export format's well-formedness rules as the app applies them.
RSpec.describe ExportFormat::Rules, type: :model do
  def examples(kind)
    Rails.root.glob("docs/export-format/examples/#{kind}/*.json").sort.to_h { |file| [ "#{kind}/#{file.basename}", file.binread ] }
  end

  def base = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/base.json").read)

  def problems_of(data) = described_class.problems(JSON.generate(data)).map { |problem| [ problem.rule, problem.at ] }

  it "keeps a byte-identical copy of every documented schema (ADR 0021)", :aggregate_failures do
    documented = Rails.root.glob("docs/export-format/v*.schema.json")
    copies = documented.map { |file| described_class::SCHEMA_FILE.dirname.join(file.basename) }

    expect(documented.map(&:basename).map(&:to_s)).to include("v1.schema.json")
    expect(copies.map { |copy| copy.exist? && copy.binread }).to eq(documented.map(&:binread))
  end

  it "reports exactly what examples/problems.json names for each invalid example (AC-2.7)" do
    named = JSON.parse(Rails.root.join("docs/export-format/examples/problems.json").read)
    found = examples("invalid").transform_values { |bytes| described_class.problems(bytes).map { |problem| problem.to_h.stringify_keys } }

    expect(found).to eq(named.transform_values { |entry| [ entry.slice("rule", "at") ] })
  end

  it "finds nothing wrong with the valid and comparison examples (AC-2.7)" do
    found = examples("valid").merge(examples("comparison")).transform_values { |bytes| described_class.problems(bytes) }

    expect(found.reject { |_name, problems| problems.empty? }).to be_empty
  end

  it "reads a whole number written with a zero fraction" do
    data = base
    data["format_version"] = 1.0
    data["lots"][0]["quantity"] = 4.0

    expect(problems_of(data)).to eq([])
  end

  it "checks the times of a lot whose other fields fail the schema" do
    data = base
    data["lots"][0]["quantity"] = 0
    data["lots"][0]["added_at"] = "2026-02-30T00:00:00Z"

    expect(problems_of(data)).to eq([ %w[minimum /lots/0/quantity], %w[not_a_time /lots/0/added_at] ])
  end

  it "leaves a time that fails the schema to the schema" do
    data = base
    data["lots"][0]["added_at"] = "2026-02-30"

    expect(problems_of(data)).to eq([ %w[pattern /lots/0/added_at] ])
  end

  it "compares only real moments when it looks for a lot changed before it was added" do
    data = base
    data["lots"][0]["added_at"] = "2026-02-30T00:00:00Z"
    data["lots"][0]["changed_at"] = "2026-01-01T00:00:00Z"

    expect(problems_of(data)).to eq([ %w[not_a_time /lots/0/added_at] ])
  end

  it "finds the duplicate of a lot whose quantity fails the schema" do
    data = base
    data["lots"] << data["lots"][0].merge("quantity" => 0)

    expect(problems_of(data)).to eq([ %w[minimum /lots/2/quantity], %w[duplicate_lot /lots/2] ])
  end

  it "compares no lot whose identity can't be read" do
    data = base
    data["lots"][0]["price_paid"] = "12.5"
    data["lots"] << data["lots"][0].dup

    expect(problems_of(data)).to eq([ %w[pattern /lots/0/price_paid], %w[pattern /lots/2/price_paid] ])
  end

  it "reports a lot that isn't an object and checks the others" do
    data = base
    data["lots"].unshift(5)
    data["lots"][1]["added_at"] = "2026-02-30T00:00:00Z"

    expect(problems_of(data)).to eq([ %w[type /lots/0], %w[not_a_time /lots/1/added_at] ])
  end

  describe ".identity_readable?" do
    let(:lot) { base["lots"][0] }

    it "is true when no identity field fails the schema" do
      expect(described_class.identity_readable?(lot, "/lots/0", Set["/lots/0/quantity", "/lots/0/added_at"])).to be(true)
    end

    it "is false when an identity field fails, or the entry, or the lot isn't an object", :aggregate_failures do
      %w[entry entry/collectible_type entry/source_id finish condition price_paid].each do |field|
        expect(described_class.identity_readable?(lot, "/lots/0", Set["/lots/0/#{field}"])).to be(false), field
      end
      expect(described_class.identity_readable?(5, "/lots/0", Set["/lots/0"])).to be(false)
    end
  end

  describe ".parse" do
    it "reads UTF-8 JSON and refuses anything else", :aggregate_failures do
      expect(described_class.parse('{"a":1}')).to eq([ { "a" => 1 }, nil ])
      expect(described_class.parse("{\"a\":\"\xE9\"}".b)).to eq([ nil, described_class::Problem.new("not_utf8", "") ])
      expect(described_class.parse('{"a":1,"a":2}')).to eq([ nil, described_class::Problem.new("not_json", "") ])
      expect(described_class.parse("\xEF\xBB\xBF{}".b)).to eq([ nil, described_class::Problem.new("not_json", "") ])
    end

    it "refuses a number too large to read, which JSON reads as infinite" do
      expect(described_class.parse('{"lots":[{"quantity":1e400}]}')).to eq([ nil, described_class::Problem.new("not_json", "") ])
    end
  end
end
```

### Step 1.3: Run it red

`bin/rspec spec/models/export_format/rules_spec.rb` — expect: "An error occurred while loading ./spec/models/export_format/rules_spec.rb", `NameError: uninitialized constant ExportFormat`, and "0 examples, 0 failures, 1 error occurred outside of examples".

### Step 1.4: Commit the failing examples

```sh
git add Gemfile app/models/export_format/v1.schema.json spec/models/export_format/rules_spec.rb
git commit -m "test(025): the export format's rules as the app applies them" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Step 1.5: The rules

`app/models/export_format/rules.rb`:

```ruby
require "json_schemer"

# The export format's rules for a well-formed file, version 1 (docs/export-format/README.md, spec 017), as the app
# applies them when it reads a file (spec 025, ADR 0021). v1.schema.json beside this file is a byte-identical copy of
# docs/export-format/v1.schema.json, which the published image leaves out; spec/models/export_format/rules_spec.rb
# keeps the two equal.
module ExportFormat
  module Rules
    Problem = Data.define(:rule, :at)

    FORMAT = "collector-export".freeze
    VERSION = 1
    # The rules a schema can't state, and the two that apply before a schema can.
    RULES = %w[not_utf8 not_json not_a_time changed_before_added duplicate_lot].freeze
    SCHEMA_FILE = Pathname(__dir__).join("v1.schema.json")
    TIME = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\z/
    JSON_TYPES = %w[array boolean integer null number object string].freeze
    # The fields under a lot that make its identity (ADR 0019).
    IDENTITY_FIELDS = %w[entry entry/collectible_type entry/source_id finish condition price_paid].freeze

    def self.schema = @schema ||= JSON.parse(SCHEMA_FILE.read)

    def self.schemer = @schemer ||= JSONSchemer.schema(schema, regexp_resolver: "ecma")

    # The file as data, or the problem that stops it being read: [data, nil] or [nil, problem]. JSON's error message
    # quotes the file, so it is dropped (spec 025 FR-6). A number too large for a float reads as Infinity, which no
    # JSON text can mean and json_schemer's integer check can't take (FloatDomainError), so it isn't readable JSON.
    def self.parse(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      return [ nil, Problem.new("not_utf8", "") ] unless text.valid_encoding?

      data = JSON.parse(text, allow_duplicate_key: false)
      non_finite?(data) ? [ nil, Problem.new("not_json", "") ] : [ data, nil ]
    rescue JSON::ParserError
      [ nil, Problem.new("not_json", "") ]
    end

    # Why a file isn't well-formed: an empty list when it is.
    def self.problems(bytes)
      data, problem = parse(bytes)
      problem ? [ problem ] : problems_in(data)
    end

    # Why parsed data isn't well-formed. Schema problems carry the keyword that failed. The time rules then apply to
    # each time the schema accepted, and duplicate_lot to the lots whose identity can be read (spec 025 FR-2).
    def self.problems_in(data)
      found = schema_problems(data)
      found + rule_problems(data, found.to_set(&:at))
    end

    # What identifies a lot (ADR 0019): its entry's type and source id, finish, condition and price paid.
    def self.identity(lot)
      lot.fetch("entry").values_at("collectible_type", "source_id") + lot.values_at("finish", "condition", "price_paid")
    end

    # Whether the lot at +at+ has an identity to compare: it is an object, and none of its identity fields is among
    # the +failed+ pointers (spec 025 decision 1).
    def self.identity_readable?(lot, at, failed)
      lot.is_a?(Hash) && !failed.include?(at) && IDENTITY_FIELDS.none? { |field| failed.include?("#{at}/#{field}") }
    end

    def self.schema_problems(data)
      schemer.validate(data).flat_map do |error|
        missing = error.dig("details", "missing_keys")
        next missing.map { |key| Problem.new("required", "#{error["data_pointer"]}/#{key}") } if missing

        [ Problem.new(JSON_TYPES.include?(error["type"]) ? "type" : error["type"], error["data_pointer"]) ]
      end
    end

    def self.rule_problems(data, failed)
      return [] unless data.is_a?(Hash)

      lots = data["lots"].is_a?(Array) ? data["lots"].each_with_index.select { |lot, _index| lot.is_a?(Hash) } : []
      times = [ [ "/exported_at", data["exported_at"] ] ] +
        lots.flat_map { |lot, index| %w[added_at changed_at].map { |name| [ "/lots/#{index}/#{name}", lot[name] ] } }
      checked = times.reject { |at, _value| failed.include?(at) }
      real = checked.select { |_at, value| moment?(value) }.to_set { |at, _value| at }
      not_times = checked.reject { |at, _value| real.include?(at) }.map { |at, _value| Problem.new("not_a_time", at) }
      backwards = lots.select { |lot, index| changed_before_added?(lot, "/lots/#{index}", real) }
        .map { |_lot, index| Problem.new("changed_before_added", "/lots/#{index}/changed_at") }
      repeats = lots.select { |lot, index| identity_readable?(lot, "/lots/#{index}", failed) }.group_by { |lot, _index| identity(lot) }.values
        .flat_map { |group| group.drop(1).map { |_lot, index| Problem.new("duplicate_lot", "/lots/#{index}") } }
      not_times + backwards + repeats
    end

    def self.non_finite?(value)
      case value
      when Float then !value.finite?
      when Hash then value.each_value.any? { |item| non_finite?(item) }
      when Array then value.any? { |item| non_finite?(item) }
      else false
      end
    end

    def self.changed_before_added?(lot, at, real)
      real.include?("#{at}/added_at") && real.include?("#{at}/changed_at") && lot["changed_at"] < lot["added_at"]
    end

    def self.moment?(value)
      year, month, day, hour, minute, second = value.match(TIME).captures.map(&:to_i)
      Date.valid_date?(year, month, day) && hour < 24 && minute < 60 && second < 60
    end

    private_class_method :non_finite?, :schema_problems, :rule_problems, :changed_before_added?, :moment?
  end
end
```

A time in `checked` passed the schema, so it is a string matching `TIME` and `moment?` can read it.

### Step 1.6: The suite's rules pass the app's through

`spec/support/export_format_rules.rb`: replace the header comment and the constants above `def self.directory`:

```ruby
require "json_schemer"

# The export format's rules as the suite applies them (spec 017, docs/export-format/README.md): what makes a file
# well-formed, what identifies a lot, and when two files hold the same collection. Well-formedness and lot identity
# are the app's (ExportFormat::Rules, spec 025, ADR 0021); this module passes them through and adds what only the
# suite needs: the document, its examples and the comparison of two files.
module ExportFormatRules
  Problem = ExportFormat::Rules::Problem
  RULES = ExportFormat::Rules::RULES
```

(removing `Problem = Data.define(:rule, :at)`, the old `RULES`, `TIME` and `JSON_TYPES`). Replace `def self.problems(bytes) … end` and `def self.identity(lot) … end` with:

```ruby
  # Why a file isn't well-formed: an empty list when it is (ExportFormat::Rules).
  def self.problems(bytes) = ExportFormat::Rules.problems(bytes)

  # What identifies a lot (ADR 0019).
  def self.identity(lot) = ExportFormat::Rules.identity(lot)
```

Delete `def self.schema_problems`, `def self.rule_problems` and `def self.moment?`, and change the last line to:

```ruby
  private_class_method :compared, :cells
```

`directory`, `document`, `version`, `schema_file`, `schema`, `examples`, `same_collection?`, `field_names`, `section`, `table`, `cells` and `compared` stay as they are; `schema` still reads the newest schema in `docs/`, which the document spec checks.

### Step 1.7: Run it green

`bin/rspec spec/models/export_format/rules_spec.rb spec/export_format_examples_spec.rb spec/export_format_document_spec.rb spec/models/collection_export_spec.rb spec/requests/collection_exports_spec.rb` — expect: all pass.

### Step 1.8: Commit

```sh
git add app/models/export_format/rules.rb spec/support/export_format_rules.rb
git commit -m "feat(025): the export format's rules in the app" -m "ExportFormat::Rules applies v1's schema, through an in-app copy kept byte-identical to docs/, and the five further rules; the suite's ExportFormatRules passes well-formedness and lot identity through to it (ADR 0021)." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Phase 2: The reader

**Implements:** FR-1, FR-3, FR-4 (reader half), FR-5, FR-6 (reader half), FR-7 (32 MB), decisions 1–4, 9–11 | **Satisfies:** AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-1.7, AC-1.11, AC-2.1, AC-2.2, AC-2.3, AC-2.4, AC-2.5, AC-2.8 (model half), AC-3.2, AC-3.3
**Files:** `spec/models/catalog_spec.rb`, `spec/models/collection_import_spec.rb` (new), `app/models/catalog.rb`, `app/models/collection_import.rb` (new)
**Interfaces:** Consumes `ExportFormat::Rules` (Phase 1). Produces `Catalog.unloaded_titles(among = sources.keys)` and `CollectionImport.new(account:, file:)` with `MAX_BYTES`, `LIST_LIMIT`, `#refusal` (`Refusal` = `Data.define(:rule, :at, :reason)`, or nil), `#refused?`, `#applicable?`, `#rows` (`[Row]`), `#problem_rows`, `#listed_problem_rows`, `#more_problem_rows`, `#problem_counts` (`{summary => count}`), `#added`, `#changed`, `#unchanged`, `#held`, `#removed` (each a `Tally` = `Data.define(:lots, :copies, :copies_after)`), `#removed_lots`, `#more_removed_lots`, `#exported_at`, `#currency`, `#view_change`, `#other_name`, `#other_email_address`, `#unloaded_catalog_titles`. `Row` has `#number`, `#lot`, `#identity`, `#problems` (`[Problem]` = `Data.define(:rule, :at, :reason, :summary)`), `#problem?`, `#name`, `#described`; `HeldLot` has `#name`, `#quantity`, `#identity`, `#described`. `#described` returns the keywords of `ImportPreviewsHelper#import_lot_line` (Phase 3).

### Step 2.1: Failing examples for the registry's notice

In `spec/models/catalog_spec.rb`, inside `describe ".title_for and .unloaded_titles (spec 015 glossary)"`, after the last example, add:

```ruby
    it "lists only the unloaded types it is asked about, ignoring types it doesn't know (spec 025 AC-2.6)", :aggregate_failures, :other_catalog do
      expect(described_class.unloaded_titles(%w[other comics])).to eq([ "Pocket Monsters" ])
      expect(described_class.unloaded_titles([])).to eq([])
    end
```

### Step 2.2: Failing examples for the reader

`spec/models/collection_import_spec.rb`:

```ruby
require "rails_helper"

# Spec 025: an export file read against one account's collection and this instance's catalog. Nothing is written.
RSpec.describe CollectionImport, type: :model do
  let(:user) { create(:user, name: "Grace Example", email_address: "grace@example.test") }
  let(:account) { user.account }

  def printing(**entry) = create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, **entry)).entry

  def row(entry, quantity: 1, finish: nil, condition: nil, price_paid: nil, added_at: "2026-10-01T10:00:00Z", changed_at: added_at)
    { "entry" => { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name,
                   "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language },
      "quantity" => quantity, "finish" => finish, "condition" => condition, "price_paid" => price_paid,
      "added_at" => added_at, "changed_at" => changed_at }
  end

  # A row naming an entry no catalog has.
  def stranger(source_id = "not-#{SecureRandom.hex(4)}", type: "mtg", **options)
    row(build(:catalog_entry, collectible_type: type, external_key: source_id), **options)
  end

  def file(lots, **fields)
    { "format" => "collector-export", "format_version" => 1, "exported_at" => "2026-10-15T09:00:00Z",
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => user.collection_view },
      "currency" => "USD", "lots" => lots }.merge(fields.stringify_keys)
  end

  def import(data) = described_class.new(account:, file: StringIO.new(data.is_a?(String) ? data : JSON.generate(data)))

  def held(entry, quantity:, added_at: "2026-10-01T10:00:00Z", changed_at: added_at, **attributes)
    create(:lot, account:, entry:, quantity:, created_at: Time.iso8601(added_at), updated_at: Time.iso8601(changed_at), **attributes)
  end

  def refusal_of(data) = import(data).refusal.then { |refusal| [ refusal.rule, refusal.at, refusal.reason ] }

  def reasons(preview) = preview.problem_rows.to_h { |row| [ row.number, row.problems.map(&:reason) ] }

  describe "a file refused as a whole (decision 10)" do
    it "asks for a file when there is none, it is empty, or the field isn't an upload", :aggregate_failures do
      reason = "Choose an export file to preview."
      expect(described_class.new(account:, file: nil).refusal).to eq(described_class::Refusal.new("no_file", "", reason))
      expect(described_class.new(account:, file: StringIO.new("")).refusal.rule).to eq("no_file")
      expect(described_class.new(account:, file: "export.json").refusal.rule).to eq("no_file")
    end

    it "refuses a file over 32 MB without reading it (AC-3.3)", :aggregate_failures do
      big = StringIO.new("{}")
      allow(big).to receive(:size).and_return(described_class::MAX_BYTES + 1)
      allow(big).to receive(:read).and_call_original

      expect(described_class.new(account:, file: big).refusal)
        .to eq(described_class::Refusal.new("too_large", "", "This file is larger than 32 MB, so it can't be an export Collector reads."))
      expect(big).not_to have_received(:read)
    end

    it "refuses a file it can't read as JSON", :aggregate_failures do
      reason = "This file isn't a Collector export: it isn't readable JSON."
      expect(refusal_of("{\"a\":\"\xE9\"}".b)).to eq([ "not_utf8", "", reason ])
      expect(refusal_of("{")).to eq([ "not_json", "", reason ])
      expect(refusal_of('{"a":1,"a":2}')).to eq([ "not_json", "", reason ])
      expect(refusal_of("\xEF\xBB\xBF{}".b)).to eq([ "not_json", "", reason ])
    end

    it "refuses JSON that isn't an export", :aggregate_failures do
      reason = "This file isn't a Collector export."
      expect(refusal_of([])).to eq([ "type", "", reason ])
      expect(refusal_of(file([]).except("format"))).to eq([ "required", "/format", reason ])
      expect(refusal_of(file([], format: "other-export"))).to eq([ "const", "/format", reason ])
    end

    it "refuses a file that doesn't say its version", :aggregate_failures do
      reason = "This file doesn't say which version of the export format it follows."
      expect(refusal_of(file([]).except("format_version"))).to eq([ "required", "/format_version", reason ])
      [ "1", 0, -1, 1.5, nil ].each do |version|
        expect(refusal_of(file([], format_version: version))).to eq([ "const", "/format_version", reason ]), version.inspect
      end
    end

    it "refuses a newer version as newer, before the schema (AC-3.2)", :aggregate_failures do
      expect(refusal_of(file([], format_version: 2).except("lots", "profile"))).to eq(
        [ "newer_version", "/format_version", "This file was written by a newer version of Collector (format version 2). This instance reads version 1." ])
      expect(refusal_of(file([], format_version: 2.0)).first).to eq("newer_version")
      expect(import(file([], format_version: 1.0))).not_to be_refused
    end

    it "names the first field outside the lots that isn't well-formed, in the file's order", :aggregate_failures do
      expect(refusal_of(file([], profile: { "name" => " ", "email_address" => "a@b.test", "collection_view" => "grid" }, currency: "usd")))
        .to eq([ "pattern", "/profile/name", "This file isn't a well-formed export: profile.name isn't valid." ])
      expect(refusal_of(file([], exported_at: "2026-02-30T00:00:00Z")))
        .to eq([ "not_a_time", "/exported_at", "This file isn't a well-formed export: exported_at isn't a real moment." ])
      expect(refusal_of(file([]).except("lots"))).to eq([ "required", "/lots", "This file isn't a well-formed export: lots is missing." ])
      expect(refusal_of(file({}))).to eq([ "type", "/lots", "This file isn't a well-formed export: lots isn't valid." ])
    end

    it "refuses a file in another currency, even with no lots (decision 3)" do
      expect(refusal_of(file([], currency: "EUR"))).to eq([ "other_currency", "/currency", "This file's prices are in EUR. This instance uses USD." ])
    end

    it "reports the rule and place problems.json names for each example refused as a whole (AC-2.7)" do
      named = JSON.parse(Rails.root.join("docs/export-format/examples/problems.json").read).reject { |_name, entry| entry["at"].start_with?("/lots/") }
      found = named.to_h do |name, _entry|
        refusal = import(Rails.root.join("docs/export-format/examples", name).binread).refusal
        [ name, refusal && { "rule" => refusal.rule, "at" => refusal.at } ]
      end

      expect(found).to eq(named.transform_values { |entry| entry.slice("rule", "at") })
    end
  end

  describe "what applying would do (decision 1)" do
    it "counts lots added, changed, unchanged and removed, with their copies (AC-1.2)", :aggregate_failures do
      a, b, c, d, e = Array.new(5) { printing }
      held(a, quantity: 3)
      held(b, quantity: 2)
      held(c, quantity: 4)
      held(d, quantity: 7)
      preview = import(file([ row(a, quantity: 3), row(b, quantity: 5), row(c, quantity: 4, changed_at: "2026-10-02T10:00:00Z"), row(e, quantity: 6) ]))

      expect(preview).to be_applicable
      expect(preview.added).to eq(described_class::Tally.new(lots: 1, copies: 6))
      expect(preview.changed).to eq(described_class::Tally.new(lots: 2, copies: 6, copies_after: 9))
      expect(preview.unchanged).to eq(described_class::Tally.new(lots: 1, copies: 3))
      expect(preview.removed).to eq(described_class::Tally.new(lots: 1, copies: 7))
      expect(preview.held).to eq(described_class::Tally.new(lots: 0, copies: 0))
      expect(preview.removed_lots.map(&:name)).to eq([ d.name ])
    end

    it "says what applying would do with each row and which lot it matches (FR-1)", :aggregate_failures do
      a, b, e = Array.new(3) { printing }
      lot_a = held(a, quantity: 3)
      lot_b = held(b, quantity: 2)
      preview = import(file([ row(a, quantity: 3), row(b, quantity: 5), row(e, quantity: 6), stranger ]))

      expect(preview.rows.map { |each_row| preview.row_outcome(each_row) }).to eq([ :unchanged, :changed, :added, nil ])
      expect(preview.rows.first(3).map { |each_row| preview.held_lot_for(each_row)&.id }).to eq([ lot_a.id, lot_b.id, nil ])
      expect([ preview.all_removed_lots, preview.lots_held_by_problem_rows ]).to eq([ [], [] ])
    end

    it "previews a collection's own export as unchanged (AC-1.3)", :aggregate_failures do
      held(printing, quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 1250)
      held(printing, quantity: 1)
      preview = import(CollectionExport.new(account:, at: Time.current).to_json)

      expect(preview).to be_applicable
      expect([ preview.added.lots, preview.changed.lots, preview.unchanged.lots, preview.removed.lots ]).to eq([ 0, 0, 2, 0 ])
    end

    it "adds every row to an empty collection (AC-1.4)" do
      expect(import(file(Array.new(3) { row(printing) })).added).to eq(described_class::Tally.new(lots: 3, copies: 3))
    end

    it "removes every lot for a file with none (AC-1.5)", :aggregate_failures do
      held(printing(name: "Opt"), quantity: 1)
      held(printing(name: "Brainstorm"), quantity: 2)
      preview = import(file([]))

      expect(preview.removed).to eq(described_class::Tally.new(lots: 2, copies: 3))
      expect(preview.removed_lots.map(&:name)).to eq(%w[Brainstorm Opt])
    end

    it "compares times to the second and whole numbers by value (AC-1.6)", :aggregate_failures do
      entry = printing
      create(:lot, account:, entry:, quantity: 4, created_at: Time.utc(2026, 10, 1, 10, 0, 0.75r), updated_at: Time.utc(2026, 10, 2, 11, 0, 0.5r))
      preview = import(file([ row(entry, quantity: 4.0, added_at: "2026-10-01T10:00:00Z", changed_at: "2026-10-02T11:00:00Z") ]))

      expect(preview.unchanged.lots).to eq(1)
      expect(preview.changed.lots).to eq(0)
    end

    it "matches a lot by its finish, condition and price paid as well as its entry" do
      entry = printing
      held(entry, quantity: 1, finish: "foil", price_paid_cents: 1250)
      preview = import(file([ row(entry, finish: "foil", price_paid: "12.50"), row(entry, finish: "nonfoil", price_paid: "12.50") ]))

      expect([ preview.unchanged.lots, preview.added.lots, preview.removed.lots ]).to eq([ 1, 1, 0 ])
    end

    it "holds a lot that a problem row names, rather than removing it (AC-1.11)", :aggregate_failures do
      entry = printing
      held(entry, quantity: 2)
      held(printing, quantity: 5)
      preview = import(file([ row(entry, quantity: 2, added_at: "2026-02-30T00:00:00Z", changed_at: "2026-10-01T10:00:00Z"),
        row(printing).except("entry") ]))

      expect(preview.held).to eq(described_class::Tally.new(lots: 1, copies: 2))
      expect(preview.removed).to eq(described_class::Tally.new(lots: 1, copies: 5))
    end

    it "counts a held lot once when a duplicate row names it too" do
      entry = printing
      held(entry, quantity: 1)
      preview = import(file([ row(entry), row(entry, quantity: 2) ]))

      expect([ preview.unchanged.lots, preview.held.lots, preview.removed.lots ]).to eq([ 1, 0, 0 ])
    end

    it "compares the file with this account's lots only (AC-4.1)", :aggregate_failures do
      entry = printing
      create(:lot, account: create(:user).account, entry:, quantity: 8_888)
      preview = import(file([ row(entry) ]))

      expect(preview.added.lots).to eq(1)
      expect(preview.removed.lots).to eq(0)
    end

    it "lists the first 100 removed lots by name and counts them all (AC-2.8)", :aggregate_failures do
      entry = printing(name: "Opt")
      150.times { |index| create(:lot, account:, entry:, price_paid_cents: index) }
      preview = import(file([]))

      expect(preview.removed.lots).to eq(150)
      expect(preview.removed_lots.size).to eq(100)
      expect(preview.more_removed_lots).to eq(50)
    end
  end

  describe "rows that can't be applied (decision 9)" do
    it "says why a well-formed row doesn't resolve (AC-2.1)", :aggregate_failures do
      known = printing
      preview = import(file([ stranger, stranger(type: "comics"), row(known, finish: "etched"), row(known, condition: "mint"), row(printing) ]))

      expect(preview).not_to be_applicable
      expect(reasons(preview)).to eq(
        1 => [ "Not in this instance's catalog" ], 2 => [ "This instance doesn't collect comics" ],
        3 => [ "This printing doesn't come in etched" ], 4 => [ "mint isn't a condition this instance knows" ])
      expect(preview.problem_rows.flat_map { |row| row.problems.map { |problem| [ problem.rule, problem.at ] } }).to eq([
        %w[not_in_catalog /lots/0/entry/source_id], %w[unknown_type /lots/1/entry/collectible_type],
        %w[finish_not_listed /lots/2/finish], %w[condition_unknown /lots/3/condition] ])
      expect(preview.problem_counts.values).to eq([ 1, 1, 1, 1 ])
      expect(preview.added.lots).to eq(1)
    end

    it "checks the catalog in order: the type, then the entry, then finish and condition", :aggregate_failures do
      known = printing
      preview = import(file([ stranger(type: "comics", condition: "mint"), stranger(finish: "etched", condition: "mint"),
        row(known, finish: "etched", condition: "mint") ]))

      expect(reasons(preview)).to eq(
        1 => [ "This instance doesn't collect comics" ],
        2 => [ "Not in this instance's catalog", "mint isn't a condition this instance knows" ],
        3 => [ "This printing doesn't come in etched", "mint isn't a condition this instance knows" ])
    end

    it "treats a registered type without a collecting vocabulary as one it doesn't collect", :other_catalog do
      expect(reasons(import(file([ stranger(type: "other") ])))).to eq(1 => [ "This instance doesn't collect other" ])
    end

    it "resolves a retired entry and ignores descriptive fields that disagree (AC-2.2, AC-2.3)" do
      retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
      renamed = row(printing).deep_merge("entry" => { "name" => "Something Else", "set_code" => "zzz", "language" => "ja" })

      expect(import(file([ row(retired), renamed ]))).to be_applicable
    end

    it "says why a row isn't well-formed, and doesn't check it against the catalog (AC-2.4)", :aggregate_failures do
      entry = printing
      preview = import(file([
        row(entry).except("quantity"), row(printing, quantity: 0), row(printing, price_paid: "12.5"),
        row(printing, added_at: "2026-02-30T00:00:00Z", changed_at: "2026-10-01T10:00:00Z"), row(printing, added_at: "2026-10-02T00:00:00Z", changed_at: "2026-10-01T00:00:00Z"),
        row(entry, quantity: 2), 7, stranger(quantity: 0), row(printing)
      ]))

      expect(reasons(preview)).to eq(
        1 => [ "quantity is missing" ], 2 => [ "quantity isn't valid" ], 3 => [ "price_paid isn't valid" ],
        4 => [ "added_at isn't a real moment" ], 5 => [ "changed_at is earlier than added_at" ],
        6 => [ "Same card, finish, condition and price as row 1" ], 7 => [ "This row isn't a lot" ], 8 => [ "quantity isn't valid" ])
      expect(preview.added.lots).to eq(1)
    end

    it "names nested fields with a point" do
      expect(reasons(import(file([ row(printing).tap { |lot| lot["entry"].delete("source_id") } ])))).to eq(1 => [ "entry.source_id is missing" ])
    end

    it "shows every reason a row has (AC-2.5)" do
      expect(reasons(import(file([ row(printing, quantity: 0, price_paid: "1") ])))).to eq(1 => [ "quantity isn't valid", "price_paid isn't valid" ])
    end

    it "lists the first 100 problem rows and counts them all, by reason (AC-2.8)", :aggregate_failures do
      preview = import(file(Array.new(150) { stranger }))

      expect(preview.listed_problem_rows.map(&:number)).to eq((1..100).to_a)
      expect(preview.more_problem_rows).to eq(50)
      expect(preview.problem_counts).to eq("Not in this instance's catalog" => 150)
    end

    it "counts duplicates under one reason" do
      entry = printing
      preview = import(file([ row(entry), row(entry, quantity: 2), row(entry, quantity: 3) ]))

      expect(preview.problem_counts).to eq("Same card, finish, condition and price as an earlier row" => 2)
    end

    it "describes a row by the strings the file gives", :aggregate_failures do
      described = import(file([ stranger("x", finish: "foil", price_paid: 3) ])).problem_rows.first

      expect(described.name).to be_a(String)
      expect(described.described.values_at(:finish, :price_paid)).to eq([ "foil", nil ])
    end
  end

  describe "the profile (decision 4, AC-1.7)" do
    it "says nothing when the file's profile agrees", :aggregate_failures do
      preview = import(file([]))

      expect([ preview.view_change, preview.other_name, preview.other_email_address ]).to eq([ nil, nil, nil ])
    end

    it "gives the view a file would change to, and the file's own name and email address when they differ", :aggregate_failures do
      preview = import(file([], profile: { "name" => "Ada Example", "email_address" => "ada@example.test", "collection_view" => "table" }))

      expect([ preview.view_change, preview.other_name, preview.other_email_address ]).to eq([ "table", "Ada Example", "ada@example.test" ])
    end

    it "ignores a view the instance doesn't know" do
      expect(import(file([], profile: { "name" => user.name, "email_address" => user.email_address, "collection_view" => "gallery" })).view_change).to be_nil
    end
  end

  describe "#unloaded_catalog_titles (AC-2.6)" do
    it "names the unloaded catalogs of the types the file names", :aggregate_failures do
      preview = import(file([ row(printing), stranger(type: "comics") ]))
      expect(preview.unloaded_catalog_titles).to eq([ Catalog.title_for("mtg") ])

      create(:catalog_refresh_run, collectible_type: "mtg", status: "applied")
      expect(preview.unloaded_catalog_titles).to eq([])
    end
  end

  it "writes nothing (FR-6)" do
    entry = printing
    held(entry, quantity: 1)
    data = file([ row(entry, quantity: 3), stranger ])

    expect { import(data).then { |preview| [ preview.added, preview.removed_lots, preview.problem_counts ] } }
      .not_to(change { [ Lot.count, Lot.maximum(:updated_at), Catalog::Entry.count, User.maximum(:updated_at) ] })
  end
end
```

### Step 2.3: Run them red

`bin/rspec spec/models/catalog_spec.rb` — expect: the new example fails with `ArgumentError: wrong number of arguments (given 1, expected 0)`, the others pass. Then `bin/rspec spec/models/collection_import_spec.rb` — expect: "An error occurred while loading ./spec/models/collection_import_spec.rb", `NameError: uninitialized constant CollectionImport`, "0 examples, 0 failures, 1 error occurred outside of examples".

### Step 2.4: Commit the failing examples

```sh
git add spec/models/collection_import_spec.rb spec/models/catalog_spec.rb
git commit -m "test(025): the import reader's refusals, outcomes and row problems" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Step 2.5: The registry's notice for some types

In `app/models/catalog.rb`, replace `unloaded_titles`:

```ruby
  # The titles of the catalog types with no applied refresh yet (spec 015 glossary, "Loaded"), in one query; only
  # those +among+ the given types when asked (spec 025: the types an import file names).
  def self.unloaded_titles(among = sources.keys)
    types = sources.keys & among
    loaded = Catalog::RefreshRun.applied.where(collectible_type: types).distinct.pluck(:collectible_type)
    (types - loaded).sort.map { |collectible_type| title_for(collectible_type) }
  end
```

### Step 2.6: The reader

`app/models/collection_import.rb`:

```ruby
# An export file read against one account's collection and this instance's catalog (spec 025): either a refusal of
# the whole file (decision 10), or each row's problems and what applying the file would do (decisions 1, 2, 4, 9, 11).
# It writes nothing. Collectible-agnostic: a type's entries and vocabulary are reached through the catalog registry.
class CollectionImport
  MAX_BYTES = 32_000_000
  LIST_LIMIT = 100
  BATCH_SIZE = 1_000
  ROW = %r{\A/lots/(\d+)(?:/(.+))?\z}
  LOT_COLUMNS = [ "lots.id", "catalog_entries.collectible_type", "catalog_entries.external_key", "lots.finish", "lots.condition",
    "lots.price_paid_cents", "lots.quantity", "lots.created_at", "lots.updated_at", "catalog_entries.name",
    "catalog_sets.code", "catalog_entries.number", "catalog_entries.language" ].freeze

  NO_FILE = "Choose an export file to preview.".freeze
  TOO_LARGE = "This file is larger than 32 MB, so it can't be an export Collector reads.".freeze
  NOT_JSON = "This file isn't a Collector export: it isn't readable JSON.".freeze
  NOT_AN_EXPORT = "This file isn't a Collector export.".freeze
  NO_VERSION = "This file doesn't say which version of the export format it follows.".freeze
  DUPLICATE_OF = "Same card, finish, condition and price as row %d".freeze
  DUPLICATE = "Same card, finish, condition and price as an earlier row".freeze

  Refusal = Data.define(:rule, :at, :reason)
  # One reason a row can't be applied; +summary+ is the reason without what belongs to that row alone.
  Problem = Data.define(:rule, :at, :reason, :summary)
  Tally = Data.define(:lots, :copies, :copies_after) do
    def initialize(lots:, copies:, copies_after: nil) = super
  end

  # A lot of the collection, as the file would write it, with its id for applying (#40).
  HeldLot = Data.define(:id, :identity, :quantity, :added_at, :changed_at, :name, :set_code, :collector_number, :language) do
    def described
      { set_code:, collector_number:, language:, finish: identity[2], condition: identity[3], price_paid: identity[4] }
    end
  end

  # One element of the file's lots, numbered from 1. +identity+ is nil when it can't be read (decision 1).
  Row = Data.define(:number, :lot, :identity, :problems) do
    def problem? = problems.any?

    def quantity = lot["quantity"]

    def same_as?(held) = quantity == held.quantity && lot["added_at"] == held.added_at && lot["changed_at"] == held.changed_at

    def name = text(entry["name"])

    # What the file says the row is, using only the values it gives as strings (decision 9).
    def described
      { set_code: text(entry["set_code"]), collector_number: text(entry["collector_number"]), language: text(entry["language"]),
        finish: field("finish"), condition: field("condition"), price_paid: field("price_paid") }
    end

    def entry = lot.is_a?(Hash) && lot["entry"].is_a?(Hash) ? lot["entry"] : {}

    private
      def field(name) = lot.is_a?(Hash) ? text(lot[name]) : nil

      def text(value) = value if value.is_a?(String)
  end

  attr_reader :refusal, :rows

  # +file+ is the upload: anything that answers #read and #size. Anything else is no file.
  def initialize(account:, file:)
    @account = account
    @refusal = read(file)
    @rows = refused? ? [] : read_rows
  end

  def refused? = !refusal.nil?

  def applicable? = !refused? && problem_rows.empty?

  def exported_at = Time.iso8601(@data["exported_at"])

  def currency = @data["currency"]

  def problem_rows = @problem_rows ||= rows.select(&:problem?)

  def listed_problem_rows = problem_rows.first(LIST_LIMIT)

  def more_problem_rows = problem_rows.size - listed_problem_rows.size

  # How many problem rows have each kind of problem, in the order the kinds first appear.
  def problem_counts = problem_rows.flat_map { |row| row.problems.map(&:summary).uniq }.tally

  def added = outcomes.fetch(:added)
  def changed = outcomes.fetch(:changed)
  def unchanged = outcomes.fetch(:unchanged)
  def held = outcomes.fetch(:held)
  def removed = outcomes.fetch(:removed)

  # The first removed lots, by name, then set code, collector number, language and identity (decision 11).
  def removed_lots
    @removed_lots ||= outcomes.fetch(:removed_lots)
      .sort_by { |lot| [ lot.name, lot.set_code, lot.collector_number, lot.language, lot.identity.map(&:to_s) ] }.first(LIST_LIMIT)
  end

  def more_removed_lots = removed.lots - removed_lots.size

  # What applying would do with a row: :added, :changed or :unchanged, or nil for a problem row (FR-1; for #40).
  def row_outcome(row) = outcomes.fetch(:row_outcomes)[row.number]

  # The held lot a row that isn't a problem row matches, or nil (for #40).
  def held_lot_for(row) = outcomes.fetch(:matched_lots)[row.identity]

  # Every lot applying would remove, and every lot a problem row holds back, in no order (for #40).
  def all_removed_lots = outcomes.fetch(:removed_lots)
  def lots_held_by_problem_rows = outcomes.fetch(:held_by_problem_rows)

  # The view applying would choose, when it is one the instance knows and isn't the collector's (decision 4).
  def view_change
    view = @data.dig("profile", "collection_view")
    view if User::COLLECTION_VIEWS.include?(view) && view != user.collection_view
  end

  def other_name = differing("name")

  def other_email_address = differing("email_address")

  def unloaded_catalog_titles
    Catalog.unloaded_titles(rows.filter_map { |row| row.entry["collectible_type"] }.grep(String).uniq)
  end

  private
    def user = @account.user

    def differing(field)
      value = @data.dig("profile", field)
      value unless value == user.public_send(field)
    end

    def refuse(rule, at, reason) = Refusal.new(rule:, at:, reason:)

    def read(file)
      return refuse("no_file", "", NO_FILE) unless file.respond_to?(:read) && file.respond_to?(:size) && file.size.positive?
      return refuse("too_large", "", TOO_LARGE) if file.size > MAX_BYTES

      @data, problem = ExportFormat::Rules.parse(file.read)
      return refuse(problem.rule, "", NOT_JSON) if problem

      header_refusal || currency_refusal
    end

    # Decision 10's checks in order: an export, its version (read before the schema), then the schema and the time
    # rule outside the rows.
    def header_refusal
      return refuse("type", "", NOT_AN_EXPORT) unless @data.is_a?(Hash)
      return refuse("required", "/format", NOT_AN_EXPORT) unless @data.key?("format")
      return refuse("const", "/format", NOT_AN_EXPORT) unless @data["format"] == ExportFormat::Rules::FORMAT
      return refuse("required", "/format_version", NO_VERSION) unless @data.key?("format_version")

      version = whole_number(@data["format_version"])
      return refuse("const", "/format_version", NO_VERSION) unless version&.positive?
      return refuse("newer_version", "/format_version", newer(version)) if version > ExportFormat::Rules::VERSION

      @problems = ExportFormat::Rules.problems_in(@data)
      outside = @problems.reject { |problem| ROW.match?(problem.at) }
      first = outside.min_by { |problem| [ position(problem.at), outside.index(problem) ] }
      first && refuse(first.rule, first.at, "This file isn't a well-formed export: #{field_reason(first.rule, field_name(first.at))}.")
    end

    def currency_refusal
      code = Rails.configuration.x.currency.code
      return if @data["currency"] == code

      refuse("other_currency", "/currency", "This file's prices are in #{@data["currency"]}. This instance uses #{code}.")
    end

    def whole_number(value)
      case value
      when Integer then value
      when Float then value.to_i if value.finite? && value == value.floor
      end
    end

    def newer(version)
      "This file was written by a newer version of Collector (format version #{version}). " \
        "This instance reads version #{ExportFormat::Rules::VERSION}."
    end

    # Where a header pointer's field sits in the file; a missing field after all those present.
    def position(at) = @data.keys.index(at.split("/")[1]) || @data.size

    def field_name(pointer) = pointer.delete_prefix("/").tr("/", ".")

    def field_reason(rule, field)
      case rule
      when "required" then "#{field} is missing"
      when "not_a_time" then "#{field} isn't a real moment"
      else "#{field} isn't valid"
      end
    end

    def read_rows
      lots = @data["lots"]
      failed = @problems.to_set(&:at)
      found = Hash.new { |hash, index| hash[index] = [] }
      @problems.each { |problem| (match = ROW.match(problem.at)) && found[match[1].to_i] << problem }
      identities = lots.each_with_index.map do |lot, index|
        ExportFormat::Rules.identity(lot) if ExportFormat::Rules.identity_readable?(lot, "/lots/#{index}", failed)
      end
      first_row = {}
      identities.each_with_index { |identity, index| first_row[identity] ||= index + 1 if identity }
      resolved = resolution_problems(lots.each_with_index.reject { |_lot, index| found.key?(index) })
      lots.each_with_index.map do |lot, index|
        problems = found.fetch(index, []).map { |problem| describe(problem, first_row[identities[index]]) } + resolved.fetch(index, [])
        Row.new(number: index + 1, lot:, identity: identities[index], problems:)
      end
    end

    def describe(problem, earlier)
      return Problem.new(rule: problem.rule, at: problem.at, reason: format(DUPLICATE_OF, earlier), summary: DUPLICATE) if problem.rule == "duplicate_lot"

      field = ROW.match(problem.at)[2]&.tr("/", ".")
      reason = case problem.rule
      when "changed_before_added" then "changed_at is earlier than added_at"
      else field ? field_reason(problem.rule, field) : "This row isn't a lot"
      end
      Problem.new(rule: problem.rule, at: problem.at, reason:, summary: reason)
    end

    # Decision 9's catalog checks for well-formed rows: the type, then the entry, then its finish and the condition.
    def resolution_problems(candidates)
      candidates.group_by { |lot, _index| lot["entry"]["collectible_type"] }.each_with_object({}) do |(type, group), found|
        unless registered?(type)
          group.each { |_lot, index| found[index] = [ problem("unknown_type", "/lots/#{index}/entry/collectible_type", "This instance doesn't collect #{type}") ] }
          next
        end

        vocabulary = Catalog.collecting_for(type)
        entries = entries_for(type, group.map { |lot, _index| lot["entry"]["source_id"] })
        group.each do |lot, index|
          list = entry_problems(lot, index, entries[lot["entry"]["source_id"]], vocabulary)
          found[index] = list if list.any?
        end
      end
    end

    def entry_problems(lot, index, entry, vocabulary)
      list = []
      list << problem("not_in_catalog", "/lots/#{index}/entry/source_id", "Not in this instance's catalog") unless entry
      if entry && lot["finish"] && vocabulary.finishes_for(entry).exclude?(lot["finish"])
        list << problem("finish_not_listed", "/lots/#{index}/finish", "This printing doesn't come in #{lot["finish"]}")
      end
      if lot["condition"] && vocabulary.conditions.exclude?(lot["condition"])
        list << problem("condition_unknown", "/lots/#{index}/condition", "#{lot["condition"]} isn't a condition this instance knows")
      end
      list
    end

    def problem(rule, at, reason) = Problem.new(rule:, at:, reason:, summary: reason)

    def registered?(type) = Catalog.collecting.key?(type) && Catalog.sources.key?(type)

    # The type's entries with these source ids, retired or not, with what their finishes need loaded (FR-4).
    def entries_for(type, source_ids)
      source_ids.uniq.each_slice(BATCH_SIZE).flat_map do |slice|
        Catalog::Entry.preload_extensions(Catalog::Entry.where(collectible_type: type, external_key: slice).to_a)
      end.index_by(&:external_key)
    end

    # The collection's lots, as the file would write them, read in one statement.
    def held_lots
      @account.lots.joins(entry: :set).pluck(*LOT_COLUMNS).map do |id, type, source_id, finish, condition, cents, quantity, added, changed, name, set_code, number, language|
        HeldLot.new(id:, identity: [ type, source_id, finish, condition, cents && format("%.2f", cents / 100r) ], quantity:,
          added_at: added.getutc.iso8601, changed_at: changed.getutc.iso8601, name:, set_code:, collector_number: number, language:)
      end
    end

    # Decision 1: each row that isn't a problem row is added, changed or unchanged; each held lot is matched by such a
    # row, else held by a problem row that names it, else removed.
    def outcomes
      @outcomes ||= begin
        held = held_lots.index_by(&:identity)
        good = rows.reject(&:problem?)
        matched = good.select { |row| held.key?(row.identity) }.index_by(&:identity)
        changed, unchanged = matched.values.partition { |row| !row.same_as?(held[row.identity]) }
        named = problem_rows.filter_map(&:identity).to_set
        kept, removed = held.values.reject { |lot| matched.key?(lot.identity) }.partition { |lot| named.include?(lot.identity) }
        added = good.reject { |row| held.key?(row.identity) }
        row_outcomes = [ [ added, :added ], [ changed, :changed ], [ unchanged, :unchanged ] ]
          .flat_map { |list, outcome| list.map { |row| [ row.number, outcome ] } }.to_h
        { added: tally(added), unchanged: tally(unchanged),
          changed: Tally.new(lots: changed.size, copies: changed.sum { |row| held[row.identity].quantity },
                             copies_after: changed.sum { |row| row.quantity.to_i }),
          held: tally(kept), removed: tally(removed), row_outcomes:, held_by_problem_rows: kept, removed_lots: removed,
          matched_lots: matched.transform_values { |row| held[row.identity] } }
      end
    end

    def tally(items) = Tally.new(lots: items.size, copies: items.sum { |item| item.quantity.to_i })
end
```

Notes for the implementer:
- Reasons are plain text. The spec writes field names in backticks as Markdown; the page shows them as plain words ("quantity isn't valid").
- A well-formed row's `entry`, `collectible_type`, `source_id`, `finish` and `condition` have the schema's types, so `resolution_problems` reads them without guards.
- `quantity == held.quantity` compares `4.0` with `4` as equal (Ruby's numeric `==`), as decision 1 says.
- `Lot#vocabulary` and the reader both use `Catalog.collecting_for(type)`, so finishes and conditions are judged as `Lot` validates them.

### Step 2.7: Run them green

`bin/rspec spec/models/collection_import_spec.rb spec/models/catalog_spec.rb` — expect: all pass.

### Step 2.8: Commit

```sh
git add app/models/catalog.rb app/models/collection_import.rb
git commit -m "feat(025): read an export file against the collection and the catalog" -m "CollectionImport refuses a file as a whole (decision 10) or gives each row's problems (decision 9) and what applying would do: added, changed, unchanged, held by a problem row, removed (decision 1). Nothing is written." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Phase 3: The pages and the links

**Implements:** FR-4 (request), FR-5, FR-6 (request), FR-8, FR-9, decisions 7, 8, 9, 11 | **Satisfies:** AC-1.1, AC-1.2 (page), AC-1.8, AC-1.9, AC-2.1 (page), AC-2.6, AC-2.8 (page), AC-3.1, AC-3.5, AC-4.1, AC-4.2, AC-5.1, AC-5.2, AC-5.3, AC-5.4 (narrow check), AC-5.5
**Files:** `.rubocop.yml`, `spec/requests/collection_import_previews_spec.rb` (new), `spec/collection_import_core_spec.rb` (new), `spec/system/collection_import_preview_spec.rb` (new), `spec/system/narrow_pages_spec.rb`, `spec/requests/admin/navigation_spec.rb`, `spec/requests/shell_spec.rb`, `config/routes.rb`, `config/initializers/filter_parameter_logging.rb`, `app/controllers/collections/import_previews_controller.rb` (new), `app/helpers/import_previews_helper.rb` (new), `app/views/collections/import_previews/new.html.erb` (new), `app/views/collections/import_previews/show.html.erb` (new), `app/views/layouts/_appbar.html.erb`, `app/views/mores/show.html.erb`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/ImportPreview.md` (new), `docs/design-system/components/MorePage.md`, `docs/design-system/README.md`
**Interfaces:** Consumes `CollectionImport` (Phase 2). Produces the routes `new_collection_import_preview_path` (`GET /collection/import_preview/new`) and `collection_import_preview_path` (`POST /collection/import_preview`), the file field `export_file`, and `ImportPreviewsHelper#import_lot_line(set_code:, collector_number:, language:, finish:, condition:, price_paid:)`, `#import_copies(count)`, `#import_change(tally)`.

### Step 3.1: Failing request examples

`spec/requests/collection_import_previews_spec.rb`:

```ruby
require "rails_helper"

# Spec 025: the import preview's pages. A collector uploads an export file and sees what applying it would do.
RSpec.describe "Import preview", type: :request do
  let(:user) { create(:user, name: "Grace Example", email_address: "grace@example.test") }

  def printing(**entry) = create(:mtg_printing, entry: create(:catalog_entry, **entry)).entry

  def row(entry, quantity: 1, **fields)
    { "entry" => { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name,
                   "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language },
      "quantity" => quantity, "finish" => nil, "condition" => nil, "price_paid" => nil,
      "added_at" => "2026-10-01T10:00:00Z", "changed_at" => "2026-10-01T10:00:00Z" }.merge(fields.stringify_keys)
  end

  def stranger = row(build(:catalog_entry, external_key: "not-#{SecureRandom.hex(4)}"))

  def file(lots, **fields)
    { "format" => "collector-export", "format_version" => 1, "exported_at" => "2026-10-15T09:00:00Z",
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => "grid" },
      "currency" => "USD", "lots" => lots }.merge(fields.stringify_keys)
  end

  def upload(data, type: "application/json", name: "export.json")
    Rack::Test::UploadedFile.new(StringIO.new(data.is_a?(String) ? data : JSON.generate(data)), type, original_filename: name)
  end

  def preview(data, **options) = post(collection_import_preview_path, params: { export_file: upload(data, **options) })

  def html = Nokogiri::HTML5(response.body)

  def stat(label) = html.css(".c-stat").find { |stat| stat.at_css("dt").text == label }.then { |stat| [ stat.at_css("dd").text, stat.at_css("small").text ] }

  # Every table's row count, and its newest updated_at where it has one (AC-1.8).
  def snapshot
    connection = ActiveRecord::Base.connection
    (connection.tables - %w[schema_migrations ar_internal_metadata]).sort.to_h do |table|
      quoted = connection.quote_table_name(table)
      newest = connection.column_exists?(table, :updated_at) ? connection.select_value("SELECT MAX(updated_at) FROM #{quoted}") : nil
      [ table, [ connection.select_value("SELECT COUNT(*) FROM #{quoted}"), newest ] ]
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "offers the upload form, outside Turbo (AC-1.1)", :aggregate_failures do
      get new_collection_import_preview_path
      form = html.at_css("form.c-form")

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect([ form["action"], form["method"], form["enctype"], form["data-turbo"] ]).to eq([ collection_import_preview_path, "post", "multipart/form-data", "false" ])
      expect(form.at_css("input[type=file][name=export_file]")["accept"]).to eq(".json,application/json")
      expect(form.at_css("input[type=submit]")["value"]).to eq("Preview import")
      expect(form.at_css("label[for=export_file]").text).to eq("Export file")
    end

    it "puts the CSRF token in the upload form (AC-1.1)" do
      ActionController::Base.allow_forgery_protection = true
      get new_collection_import_preview_path

      expect(html.at_css("form.c-form input[name=authenticity_token]")).to be_present
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "shows what applying the file would do (AC-1.2)", :aggregate_failures do
      a, b, c, d, e = Array.new(5) { printing }
      create(:lot, account: user.account, entry: a, quantity: 3, created_at: Time.utc(2026, 10, 1, 10), updated_at: Time.utc(2026, 10, 1, 10))
      create(:lot, account: user.account, entry: b, quantity: 2, created_at: Time.utc(2026, 10, 1, 10), updated_at: Time.utc(2026, 10, 1, 10))
      create(:lot, account: user.account, entry: c, quantity: 4, created_at: Time.utc(2026, 10, 1, 10), updated_at: Time.utc(2026, 10, 1, 10))
      create(:lot, account: user.account, entry: d, quantity: 7)
      preview(file([ row(a, quantity: 3), row(b, quantity: 5), row(c, quantity: 4, changed_at: "2026-10-02T10:00:00Z"), row(e, quantity: 6) ]))

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(html.at_css("h1").text).to eq("Import preview")
      expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Exported 2026-10-15 09:00 UTC · 4 rows · USD")
      expect(html.at_css(".c-import .c-status__message").text.squish).to eq("This file can be applied. Previewing changed nothing.")
      expect([ stat("Lots added"), stat("Lots changed"), stat("Lots unchanged"), stat("Lots removed") ])
        .to eq([ [ "1", "6 copies" ], [ "2", "6 copies become 9" ], [ "1", "3 copies" ], [ "1", "7 copies" ] ])
      expect(html.css("#removed_lots li").map { |item| item.text.squish }).to eq([ "#{d.name} #{d.set.code.upcase} · #{d.number} · EN ×7" ])
      expect(html.at_css("#held_lots").text).to eq("Held by rows with problems: 0 lots, 0 copies.")
      expect(html.at_css("#problem_rows")).to be_nil
    end

    it "lists each row that can't be applied, with its reasons and counts (AC-2.1)", :aggregate_failures do
      known = printing(name: "Serra Angel", number: "27", set: create(:catalog_set, code: "dmr"))
      preview(file([ row(known, finish: "etched", condition: "mint", price_paid: "12.50"), stranger ]))

      expect(html.at_css(".c-import .c-status__message--alert").text.squish)
        .to eq("This file can't be applied: 2 rows have problems. Previewing changed nothing.")
      expect(html.css("#problem_rows > li").first.text.squish)
        .to eq("Row 1 Serra Angel DMR · 27 · EN · Etched · Mint · $12.50 This printing doesn't come in etched mint isn't a condition this instance knows")
      expect(html.css("#problem_counts li").map { |item| item.text.squish })
        .to eq([ "This printing doesn't come in etched 1 row", "mint isn't a condition this instance knows 1 row", "Not in this instance's catalog 1 row" ])
    end

    it "lists the first 100 rows with problems, then says how many more (AC-2.8)", :aggregate_failures do
      preview(file(Array.new(150) { stranger }))

      expect(html.css("#problem_rows > li").size).to eq(100)
      expect(html.at_css("#problem_rows + .c-import__more").text).to eq("and 50 more")
    end

    it "lists the first 100 removed lots, then says how many more (AC-2.8)", :aggregate_failures do
      entry = printing
      150.times { |index| create(:lot, account: user.account, entry:, price_paid_cents: index) }
      preview(file([]))

      expect(html.css("#removed_lots > li").size).to eq(100)
      expect(html.at_css("#removed_lots + .c-import__more").text).to eq("and 50 more")
    end

    it "shows the catalog notice for an unloaded type the file names (AC-2.6)", :aggregate_failures do
      preview(file([ stranger ]))
      expect(html.at_css("#catalog_not_loaded")).to be_present

      create(:catalog_refresh_run, collectible_type: "mtg", status: "applied")
      preview(file([ stranger ]))
      expect(html.at_css("#catalog_not_loaded")).to be_nil
    end

    it "shows what the profile would change, and only then (AC-1.7)", :aggregate_failures do
      preview(file([], profile: { "name" => "Ada Example", "email_address" => "ada@example.test", "collection_view" => "table" }))
      expect(html.css("#profile_notes li").map { |item| item.text.squish }).to eq([
        "Your collection view would change to table.", "The file's name is Ada Example. Importing won't change yours.",
        "The file's email address is ada@example.test. Importing won't change yours." ])

      preview(file([]))
      expect(html.at_css("#profile_notes")).to be_nil
    end

    it "refuses a file it can't read, showing the upload form again with the reason (AC-3.1)", :aggregate_failures do
      {
        nil => "Choose an export file to preview.",
        "{" => "This file isn't a Collector export: it isn't readable JSON.",
        file([], format_version: 2) => "This file was written by a newer version of Collector (format version 2). This instance reads version 1.",
        file([], currency: "EUR") => "This file's prices are in EUR. This instance uses USD."
      }.each do |data, reason|
        data.nil? ? post(collection_import_preview_path, params: { export_file: "a pasted file" }) : preview(data)
        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css(".c-field--invalid .c-field__error")&.text).to eq(reason)
        expect(html.at_css("input[type=file]")["aria-describedby"]).to eq("export_file_error")
        expect(html.at_css(".c-stats, #problem_rows")).to be_nil
      end
      post collection_import_preview_path
      expect(html.at_css(".c-field__error")&.text).to eq("Choose an export file to preview.")
    end

    it "judges a file by its content, not its declared type or name (AC-3.5)", :aggregate_failures do
      preview(file([]), type: "image/png", name: "cards.txt")
      expect(response).to have_http_status(:ok)

      preview("not json at all", type: "application/json")
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "writes nothing and queues nothing (AC-1.8)", :aggregate_failures do
      entry = printing
      create(:lot, account: user.account, entry:, quantity: 2)
      before = snapshot

      expect { preview(file([ row(entry, quantity: 5), row(printing), stranger ])) }.not_to have_enqueued_job
      expect(snapshot).to eq(before)
    end

    it "runs as many queries for 30 rows as for 2 (AC-1.9)" do
      few = Array.new(2) { row(printing) }
      many = Array.new(30) { row(printing) }

      expect(count_queries { preview(file(many)) }).to eq(count_queries { preview(file(few)) })
    end

    it "compares the file with this collector's lots only (AC-4.1)", :aggregate_failures do
      shared = printing
      other = create(:user, name: "Zebulon Otherperson", email_address: "zebulon.otherperson@example.test")
      create(:lot, account: other.account, entry: shared, quantity: 7_919, price_paid_cents: 7_919)
      create(:lot, account: other.account, entry: printing)
      preview(file([ row(shared) ]))

      expect([ stat("Lots added").first, stat("Lots removed").first ]).to eq(%w[1 0])
      expect(response.body).not_to include("7,919", "79.19", "Zebulon Otherperson", "zebulon.otherperson@example.test")
    end
  end

  context "when signed out" do
    it "sends a visitor to sign in from either page, reading no file (AC-4.2)", :aggregate_failures do
      user
      allow(CollectionImport).to receive(:new).and_call_original

      get new_collection_import_preview_path
      expect(response).to redirect_to(new_session_path)

      sign_in_as(user)
      user.sessions.destroy_all
      preview(file([]))
      expect(response).to redirect_to(new_session_path)
      expect(CollectionImport).not_to have_received(:new)
    end
  end

  it "keeps the uploaded field out of the logs (FR-6)" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("export_file" => "a pasted file")).to eq("export_file" => "[FILTERED]")
  end
end
```

`spec/collection_import_core_spec.rb`:

```ruby
require "rails_helper"

# Spec 025 FR-9: the import preview's reader, controller, views and helper name no collectible type or source.
RSpec.describe "The import preview's code" do
  let(:files) do
    %w[app/models/collection_import.rb app/models/export_format/rules.rb app/controllers/collections/import_previews_controller.rb
       app/views/collections/import_previews/new.html.erb app/views/collections/import_previews/show.html.erb
       app/helpers/import_previews_helper.rb].map { |path| Rails.root.join(path) }
  end

  it "exists, every file of it" do
    expect(files.reject(&:exist?)).to be_empty
  end

  it "never names a collectible type or a source" do
    offenders = files.select { |file| file.exist? && file.read.match?(/\b(mtg|scryfall)\b/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
```

`spec/system/collection_import_preview_spec.rb`:

```ruby
require "rails_helper"

# Spec 025 AC-5.3: "Import collection" in the account menu leads to the upload page, and an export file previews.
RSpec.describe "Import preview", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:path) { Rails.root.join("tmp/import-preview-#{SecureRandom.hex(4)}.json") }

  after { FileUtils.rm_f(path) }

  it "previews an export file chosen from the account menu", :aggregate_failures do
    create(:lot, account: user.account, entry: create(:mtg_printing).entry, quantity: 2)
    path.write(CollectionExport.new(account: user.account, at: Time.current).to_json)
    visit collection_path
    find(".c-avatar").click
    click_on "Import collection"
    attach_file "Export file", path.to_s
    click_on "Preview import"

    expect(page).to have_css("h1", text: "Import preview")
    expect(page).to have_text("This file can be applied.")
    within(find(".c-stat", text: "Lots unchanged")) { expect(page).to have_css("dd", text: "1") }
  end
end
```

In `.rubocop.yml`, `RSpec/DescribeClass`'s comment gains "and the import preview's core spec" after "the admin catalog core and footer core specs", and its `Exclude` list gains, in order after `spec/collection_export_core_spec.rb`:

```yaml
    - "spec/collection_import_core_spec.rb"
```

In `spec/system/narrow_pages_spec.rb`, add `new_collection_import_preview_path` after `more_path` in the signed-in list:

```ruby
      new_catalog_entry_lot_path(lot.entry), edit_lot_path(lot), new_lot_removal_path(lot), more_path, new_collection_import_preview_path, admin_users_path,
```

In `spec/requests/admin/navigation_spec.rb`, the two lists gain the import link after the export:

```ruby
    expected = [ [ "Export collection", collection_export_path ], [ "Import collection", new_collection_import_preview_path ],
      [ "Users and sign-up", admin_users_path ], [ "Catalog", admin_catalog_path ], [ "Jobs", admin_jobs_path ] ]
```

```ruby
  it "shows a member only the export and the import, neither admin link", :aggregate_failures do
    sign_in_as(create(:user))

    get more_path

    expected = [ [ "Export collection", collection_export_path ], [ "Import collection", new_collection_import_preview_path ] ]
    expect(links(".c-more")).to eq(expected)
    expect(links(".c-appbar .c-menu__list")).to eq(expected)
  end
```

In `spec/requests/shell_spec.rb`, after the example "puts the export in the account menu for a collector who isn't an admin", add:

```ruby
  it "puts the import right after the export, in the account menu and on More (spec 025 AC-5.1, AC-5.2)", :aggregate_failures do
    get more_path
    page = Nokogiri::HTML5(response.body)

    expect(page.css(".c-appbar .c-menu__list a.c-menu__item").map(&:text).first(2)).to eq([ "Export collection", "Import collection" ])
    expect(page.at_css(".c-more li:nth-child(3) a")&.then { |link| [ link.text, link["href"] ] })
      .to eq([ "Import collection", new_collection_import_preview_path ])
  end
```

### Step 3.2: Run them red

`bin/rspec spec/requests/collection_import_previews_spec.rb spec/collection_import_core_spec.rb spec/system/collection_import_preview_spec.rb spec/system/narrow_pages_spec.rb spec/requests/admin/navigation_spec.rb spec/requests/shell_spec.rb` — expect: failures with `NameError: undefined local variable or method 'new_collection_import_preview_path'` (request, navigation, shell, narrow and system specs) and the core spec's "exists" example listing the four missing files.

### Step 3.3: Commit the failing examples

```sh
git add .rubocop.yml spec/requests/collection_import_previews_spec.rb spec/collection_import_core_spec.rb spec/system/collection_import_preview_spec.rb spec/system/narrow_pages_spec.rb spec/requests/admin/navigation_spec.rb spec/requests/shell_spec.rb
git commit -m "test(025): the import preview's pages and links" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Step 3.4: Route, parameter filter, controller and helper

`config/routes.rb`, inside `scope module: :collections do`, after `resource :export, only: :show, format: false`:

```ruby
      resource :import_preview, only: %i[new create]
```

`config/initializers/filter_parameter_logging.rb`, the list gains `:export_file`:

```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc, :export_file
]
```

`app/controllers/collections/import_previews_controller.rb`:

```ruby
# Spec 025: a collector uploads an export file and sees what applying it would do. The file is read in the request
# and kept nowhere; nothing is written (decision 6).
class Collections::ImportPreviewsController < ApplicationController
  def new
    no_store
  end

  def create
    no_store
    @import = CollectionImport.new(account: Current.account, file: params[:export_file])
    return render(:new, status: :unprocessable_content) if @import.refused?

    @unloaded_catalogs = @import.unloaded_catalog_titles
    @catalogs_named = Catalog.sources.many?
    render :show
  end
end
```

`app/helpers/import_previews_helper.rb`:

```ruby
# Spec 025: how the import preview writes a lot or a row, and its copy counts.
module ImportPreviewsHelper
  PRICE = /\A(0|[1-9][0-9]*)\.[0-9]{2}\z/

  # Set code and number, language, then whatever finish, condition and price it has: "DMR · 27 · EN · Foil · $12.50".
  # A price the file doesn't write in the format's form is shown as the file gives it.
  def import_lot_line(set_code:, collector_number:, language:, finish:, condition:, price_paid:)
    price = price_paid&.match?(PRICE) ? number_to_currency(price_paid, unit: Rails.configuration.x.currency.symbol) : price_paid
    [ [ set_code&.upcase, collector_number ].compact.join(" · ").presence, language&.upcase, finish&.humanize, condition&.humanize, price ]
      .compact.join(" · ")
  end

  def import_copies(count) = pluralize(number_with_delimiter(count), "copy")

  # "6 copies become 9", "1 copy becomes 2".
  def import_change(tally) = "#{import_copies(tally.copies)} #{tally.copies == 1 ? "becomes" : "become"} #{number_with_delimiter(tally.copies_after)}"
end
```

### Step 3.5: The views

`app/views/collections/import_previews/new.html.erb`:

```erb
<% content_for :title, "Import collection · Collector" %>
<%= render "layouts/appbar", section: nil %>
<main class="c-main c-page">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Import collection</h1>
    </div>
  </div>
  <%= form_with url: collection_import_preview_path, multipart: true, class: "c-form", data: { turbo: false } do |form| %>
    <% refusal = @import&.refusal %>
    <div class="c-field<%= " c-field--invalid" if refusal %>">
      <%= form.label :export_file, "Export file", class: "c-field__label" %>
      <%= form.file_field :export_file, accept: ".json,application/json", required: true, class: "c-file",
            "aria-describedby": refusal ? "export_file_error" : "export_file_hint" %>
      <p class="c-field__hint" id="export_file_hint">A .json file from Export collection, at most 32 MB. Previewing shows what importing it would do and changes nothing.</p>
      <% if refusal %><p class="c-field__error" id="export_file_error"><%= refusal.reason %></p><% end %>
    </div>
    <div class="c-form__actions">
      <%= form.submit "Preview import", class: "c-btn c-btn--primary" %>
      <%= link_to "Cancel", collection_path, class: "c-btn c-btn--secondary" %>
    </div>
  <% end %>
</main>
<%= render "layouts/tabbar", section: nil %>
```

`app/views/collections/import_previews/show.html.erb`:

```erb
<% content_for :title, "Import preview · Collector" %>
<%= render "layouts/appbar", section: nil %>
<main class="c-main c-page">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Import preview</h1>
      <p class="c-pagehead__stats">Exported <%= @import.exported_at.strftime("%Y-%m-%d %H:%M UTC") %> · <%= pluralize(number_with_delimiter(@import.rows.size), "row") %> · <%= @import.currency %></p>
    </div>
  </div>
  <div class="c-import">
    <% if @import.applicable? %>
      <p class="c-status__message">This file can be applied. Previewing changed nothing.</p>
    <% else %>
      <p class="c-status__message c-status__message--alert">This file can't be applied: <%= pluralize(number_with_delimiter(@import.problem_rows.size), "row") %> <%= @import.problem_rows.one? ? "has" : "have" %> problems. Previewing changed nothing.</p>
    <% end %>
    <%= render "catalog/not_loaded", titles: @unloaded_catalogs, named: @catalogs_named %>
    <dl class="c-stats">
      <div class="c-stat"><dt>Lots added</dt><dd><%= number_with_delimiter(@import.added.lots) %></dd><small><%= import_copies(@import.added.copies) %></small></div>
      <div class="c-stat"><dt>Lots changed</dt><dd><%= number_with_delimiter(@import.changed.lots) %></dd><small><%= import_change(@import.changed) %></small></div>
      <div class="c-stat"><dt>Lots unchanged</dt><dd><%= number_with_delimiter(@import.unchanged.lots) %></dd><small><%= import_copies(@import.unchanged.copies) %></small></div>
      <div class="c-stat"><dt>Lots removed</dt><dd><%= number_with_delimiter(@import.removed.lots) %></dd><small><%= import_copies(@import.removed.copies) %></small></div>
    </dl>
    <p class="c-import__note" id="held_lots">Held by rows with problems: <%= pluralize(number_with_delimiter(@import.held.lots), "lot") %>, <%= import_copies(@import.held.copies) %>.</p>
    <% if @import.view_change || @import.other_name || @import.other_email_address %>
      <section>
        <div class="c-section__head"><h2 class="c-section__title">Profile</h2></div>
        <ul class="c-list c-import__list" id="profile_notes">
          <% if @import.view_change %><li>Your collection view would change to <%= @import.view_change %>.</li><% end %>
          <% if @import.other_name %><li>The file's name is <%= @import.other_name %>. Importing won't change yours.</li><% end %>
          <% if @import.other_email_address %><li>The file's email address is <%= @import.other_email_address %>. Importing won't change yours.</li><% end %>
        </ul>
      </section>
    <% end %>
    <% if @import.removed.lots.positive? %>
      <section>
        <div class="c-section__head"><h2 class="c-section__title">Lots removed</h2><span class="c-section__count"><%= pluralize(number_with_delimiter(@import.removed.lots), "lot") %> · <%= import_copies(@import.removed.copies) %></span></div>
        <ul class="c-list c-import__list" id="removed_lots">
          <% @import.removed_lots.each do |lot| %>
            <li>
              <span><%= lot.name %> <span class="c-list__meta"><%= import_lot_line(**lot.described) %></span></span>
              <span class="c-list__end">×<%= number_with_delimiter(lot.quantity) %></span>
            </li>
          <% end %>
        </ul>
        <% if @import.more_removed_lots.positive? %><p class="c-import__more">and <%= number_with_delimiter(@import.more_removed_lots) %> more</p><% end %>
      </section>
    <% end %>
    <% if @import.problem_rows.any? %>
      <section>
        <div class="c-section__head"><h2 class="c-section__title">Rows with problems</h2><span class="c-section__count"><%= pluralize(number_with_delimiter(@import.problem_rows.size), "row") %></span></div>
        <ul class="c-list c-import__list" id="problem_counts">
          <% @import.problem_counts.each do |summary, count| %>
            <li>
              <span><%= summary %></span>
              <span class="c-list__end"><%= pluralize(number_with_delimiter(count), "row") %></span>
            </li>
          <% end %>
        </ul>
        <ol class="c-list c-import__list c-import__rows" id="problem_rows">
          <% @import.listed_problem_rows.each do |row| %>
            <li>
              <span class="c-import__number">Row <%= number_with_delimiter(row.number) %></span>
              <span><%= row.name %> <span class="c-list__meta"><%= import_lot_line(**row.described) %></span></span>
              <div class="c-import__reasons">
                <% row.problems.each do |problem| %>
                  <p><%= problem.reason %></p>
                <% end %>
              </div>
            </li>
          <% end %>
        </ol>
        <% if @import.more_problem_rows.positive? %><p class="c-import__more">and <%= number_with_delimiter(@import.more_problem_rows) %> more</p><% end %>
      </section>
    <% end %>
    <div class="c-form__actions">
      <%= link_to "Choose another file", new_collection_import_preview_path, class: "c-btn c-btn--secondary" %>
      <%= link_to "Back to your collection", collection_path, class: "c-btn c-btn--secondary" %>
    </div>
  </div>
</main>
<%= render "layouts/tabbar", section: nil %>
```

`app/views/layouts/_appbar.html.erb`, after the export's `link_to` line:

```erb
            <%= link_to "Import collection", new_collection_import_preview_path, class: "c-menu__item" %>
```

`app/views/mores/show.html.erb`, after the export's row:

```erb
    <li><%= link_to "Import collection", new_collection_import_preview_path %></li>
```

### Step 3.6: The pattern's styles and docs

Append to `app/assets/stylesheets/collector/additions.css`:

```css

/* ---------- Import preview (spec 025): the upload's file field, and the preview's sections and lists ---------- */
.c-file { max-width:100%; font:400 14px/20px var(--font-sans); color:var(--ink); }
.c-file:focus-visible { outline:2px solid var(--focus); outline-offset:2px; }
.c-import { display:flex; flex-direction:column; gap:var(--space-6); margin-top:var(--space-6); }
.c-import__list li { flex-wrap:wrap; overflow-wrap:anywhere; }
.c-import__number { font:400 13px/18px var(--font-mono); color:var(--ink-muted); }
.c-import__reasons { flex-basis:100%; display:flex; flex-direction:column; gap:var(--space-1); }
.c-import__reasons p { margin:0; font:600 13px/18px var(--font-sans); color:var(--danger); }
.c-import__note, .c-import__more { margin:0; font:400 14px/20px var(--font-sans); color:var(--ink-muted); }
```

`docs/design-system/components/ImportPreview.md`:

````markdown
# ImportPreview

The upload page for an export file and the preview of what importing it would do (spec 025). Previewing changes nothing.

**Markup**: the upload page is a `Form` whose field holds a plain file input with `c-file`. The preview page wraps its sections in `c-import`: a status notice, the `c-stats` of outcomes, then sections, each opened by a `c-section__head`, whose lists are `c-list c-import__list`.

```html
<form class="c-form" action="/collection/import_preview" method="post" enctype="multipart/form-data" data-turbo="false">
  <div class="c-field">
    <label class="c-field__label" for="export_file">Export file</label>
    <input class="c-file" type="file" id="export_file" name="export_file" accept=".json,application/json" required aria-describedby="export_file_hint">
    <p class="c-field__hint" id="export_file_hint">A .json file from Export collection, at most 32 MB. Previewing shows what importing it would do and changes nothing.</p>
  </div>
  <div class="c-form__actions"><input type="submit" class="c-btn c-btn--primary" value="Preview import"><a class="c-btn c-btn--secondary" href="/collection">Cancel</a></div>
</form>

<div class="c-import">
  <p class="c-status__message c-status__message--alert">This file can't be applied: 2 rows have problems. Previewing changed nothing.</p>
  <dl class="c-stats">
    <div class="c-stat"><dt>Lots added</dt><dd>1</dd><small>6 copies</small></div>
    <div class="c-stat"><dt>Lots changed</dt><dd>2</dd><small>6 copies become 9</small></div>
    <div class="c-stat"><dt>Lots unchanged</dt><dd>1</dd><small>3 copies</small></div>
    <div class="c-stat"><dt>Lots removed</dt><dd>1</dd><small>7 copies</small></div>
  </dl>
  <section>
    <div class="c-section__head"><h2 class="c-section__title">Rows with problems</h2><span class="c-section__count">2 rows</span></div>
    <ol class="c-list c-import__list c-import__rows">
      <li>
        <span class="c-import__number">Row 1</span>
        <span>Serra Angel <span class="c-list__meta">DMR · 27 · EN · Etched</span></span>
        <div class="c-import__reasons"><p>This printing doesn't come in etched</p></div>
      </li>
    </ol>
    <p class="c-import__more">and 1 more</p>
  </section>
</div>
```

- The form is submitted without Turbo Drive, so the preview is an ordinary page. A refused file shows the form again (422) with the reason as the field's `c-field__error`.
- The file input is the browser's own control, in the page's text style with the `focus` ring. It accepts `.json` as a convenience; the server judges the file by its content.
- The notice says whether the file can be applied, in words. The alert form (`c-status__message--alert`) is used when it can't.
- Outcomes are counts of lots, with copies on the small line; the lots held by rows with problems are counted on the line under them (`c-import__note`), always shown. Only removed lots are listed, because removing is the one destructive outcome.
- A row with problems shows its number (mono), what the file says it is, and each reason on its own line in `danger` with the words carrying the meaning.
- Each list shows its first 100 entries and then "and N more" (`c-import__more`); the counts above it cover them all.
- Rows wrap (`flex-wrap`, `overflow-wrap:anywhere`), so a long name or email address never scrolls the page sideways at 360px.
````

`docs/design-system/components/MorePage.md`: in the markup, after the export row, add

```html
    <li><a href="/collection/import_preview/new">Import collection</a></li>
```

and after the bullet "Export collection is a plain download link, …" add the bullet:

```markdown
- Import collection follows it and opens the import preview's upload page (spec 025).
```

`docs/design-system/README.md`, after the spec 023 additions paragraph:

```markdown
App additions (spec 025, in `collector/additions.css`): `ImportPreview`. Upstream it into the published design system before the next export replaces this folder.
```

### Step 3.7: Run them green

`bin/rspec spec/requests/collection_import_previews_spec.rb spec/collection_import_core_spec.rb spec/system/collection_import_preview_spec.rb spec/system/narrow_pages_spec.rb spec/requests/admin/navigation_spec.rb spec/requests/shell_spec.rb spec/requests/design_system_spec.rb spec/design_system_files_spec.rb` — expect: all pass.

### Step 3.8: Commit

```sh
git add config/routes.rb config/initializers/filter_parameter_logging.rb app/controllers/collections/import_previews_controller.rb app/helpers/import_previews_helper.rb app/views/collections/import_previews app/views/layouts/_appbar.html.erb app/views/mores/show.html.erb app/assets/stylesheets/collector/additions.css docs/design-system/components/ImportPreview.md docs/design-system/components/MorePage.md docs/design-system/README.md
git commit -m "feat(025): preview an import from the account menu and More" -m "GET /collection/import_preview/new uploads an export file; POST /collection/import_preview shows what applying it would do, or why it is refused (422). Import collection follows Export collection in the account menu and on More (decision 7)." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Phase 4: The request body limit at every layer

**Implements:** FR-7 (40 MB), decision 6 (hard cap) | **Satisfies:** AC-3.4 (configuration half)
**Files:** `.rubocop.yml`, `spec/config/request_body_limit_spec.rb` (new), `config/puma.rb`, `Dockerfile`, `config/deploy.yml`, `README.md`
**Interfaces:** Consumes nothing. Produces the 40,000,000-byte limit in Puma, Thruster and kamal-proxy.

### Step 4.1: Failing examples

`spec/config/request_body_limit_spec.rb`:

```ruby
require "rails_helper"
require "puma"
require "puma/configuration"
require "yaml"

# Spec 025 decision 6: every layer that receives a request body refuses one over 40 MB before keeping it, so an
# upload never fills the disk. An export file is at most 32 MB (CollectionImport::MAX_BYTES).
RSpec.describe "The request body limit" do
  let(:limit) { 40_000_000 }

  it "is above the largest file the import preview reads" do
    expect(limit).to be > CollectionImport::MAX_BYTES
  end

  it "is set in Puma, which every environment runs" do
    options = Puma::Configuration.new(config_files: [ Rails.root.join("config/puma.rb").to_s ]).load

    expect(options[:http_content_length_limit]).to eq(limit)
  end

  it "is set for Thruster in the published image" do
    expect(Rails.root.join("Dockerfile").readlines(chomp: true).map(&:strip)).to include(%(ENV MAX_REQUEST_BODY="#{limit}"))
  end

  it "is set for kamal-proxy, which otherwise buffers up to 1 GB to disk" do
    expect(YAML.load_file(Rails.root.join("config/deploy.yml")).dig("proxy", "buffering", "max_request_body")).to eq(limit)
  end
end
```

In `.rubocop.yml`, `RSpec/DescribeClass`'s comment gains "The request body limit spec checks server configuration files." and its `Exclude` list gains, after `spec/collection_import_core_spec.rb`:

```yaml
    - "spec/config/request_body_limit_spec.rb"
```

### Step 4.2: Run them red

`bin/rspec spec/config/request_body_limit_spec.rb` — expect: the first example passes; the other three fail (`expected: 40000000 got: nil`, and the Dockerfile line missing).

### Step 4.3: Commit the failing examples

```sh
git add .rubocop.yml spec/config/request_body_limit_spec.rb
git commit -m "test(025): a request body limit of 40 MB at every layer" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Step 4.4: The limits

`config/puma.rb`, after the `port` line:

```ruby

# Refuse a request body over 40 MB (413) before reading it, so an upload never fills the disk: an export file is at
# most 32 MB (spec 025 decision 6). Thruster (Dockerfile) and kamal-proxy (config/deploy.yml) set the same limit.
http_content_length_limit 40_000_000
```

`Dockerfile`, before `# Entrypoint prepares the database.` in the final stage:

```dockerfile
# Thruster refuses request bodies over 40 MB, as Puma does (spec 025 decision 6).
ENV MAX_REQUEST_BODY="40000000"

```

`config/deploy.yml`: replace the commented block

```yaml
# proxy:
#   ssl: true
#   host: app.example.com
```

with

```yaml
proxy:
  # To enable SSL, uncomment these two lines (see the comments above about SSL).
  # ssl: true
  # host: app.example.com
  # Refuse request bodies over 40 MB instead of buffering up to 1 GB to disk (spec 025 decision 6). Keep this
  # whatever the SSL setting.
  buffering:
    max_request_body: 40_000_000
```

and in the comment above it, "Enable SSL auto certification via Let's Encrypt …" through "Don't use this when deploying to multiple web servers …" now opens with "SSL (the `ssl:` and `host:` lines under `proxy:`):" so the warning about multiple web servers reads as covering SSL only.

`README.md`, in the Docker Compose section's bullet list, after the **HTTPS** bullet:

```markdown
- **Upload limit:** the app refuses a request body over 40 MB (Puma and Thruster), which is more than the largest export file it imports (32 MB). A reverse proxy in front may set a lower limit of its own; keep it at 40 MB or more.
```

and in the Card scanner section, the Kamal bullet's "uncomment `proxy:` with `ssl: true`" becomes "uncomment `ssl: true` under `proxy:`", and at the end of the Kamal section's numbered steps add a paragraph:

```markdown
`config/deploy.yml`'s `proxy:` sets `buffering: max_request_body: 40_000_000`, so kamal-proxy refuses request bodies over 40 MB, as the app does, instead of buffering up to 1 GB to disk.
```

### Step 4.5: Run them green

`bin/rspec spec/config/request_body_limit_spec.rb spec/image_publishing_spec.rb spec/project_config_spec.rb` — expect: all pass.

### Step 4.6: Commit

```sh
git add config/puma.rb Dockerfile config/deploy.yml README.md
git commit -m "feat(025): refuse request bodies over 40 MB at every layer" -m "Puma's http_content_length_limit, Thruster's MAX_REQUEST_BODY and kamal-proxy's buffering.max_request_body (decision 6; the maintainer approved the Thruster and kamal-proxy settings on 2026-10-15, spec 1.4.0)." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Phase 5: Documents

**Implements:** Documents that change | **Satisfies:** AC-5.5 (documents), spec's Documents that change
**Files:** `CLAUDE.md`, `README.md`, `docs/roadmap.md`, `docs/adr/README.md`, `docs/adr/0020-export-format.md`

Each is verified by reading (no RSpec, per `.claude/rules/testing.md`).

### Step 5.1: Edits

`CLAUDE.md`:
- Project Status: "a collector downloads their collection as an export file from the account menu or More (`CollectionExport`, `/collection/export`, spec 022); import isn't built yet." becomes "a collector downloads their collection as an export file from the account menu or More (`CollectionExport`, `/collection/export`, spec 022) and previews importing one (`CollectionImport`, `/collection/import_preview/new`, spec 025); applying an import isn't built yet."
- Active Storage fact: "No upload feature exists yet." becomes "No Active Storage upload exists yet: the import preview's upload (spec 025) is read in the request and never stored, so ADR 0013's owed validation (content type, size, pixel limits) stays with the first Active Storage upload."
- Export format fact: "`CollectionExport` writes it (spec 022); nothing reads it yet." becomes "`CollectionExport` writes it (spec 022) and `CollectionImport` reads it (spec 025), through `ExportFormat::Rules` and its copy of the schema, `app/models/export_format/v1.schema.json`, kept byte-identical to the one in `docs/` (ADR 0021)."; "using `spec/support/export_format_rules.rb` (`json_schemer`, test group, `require: false`)" becomes "using `spec/support/export_format_rules.rb`, which passes well-formedness to `ExportFormat::Rules` (`json_schemer`, in the app's bundle, `require: false`)".
- A new Non-obvious fact after the export format's: "**Import preview (spec 025, ADR 0021):** `/collection/import_preview/new` uploads an export file and `POST /collection/import_preview` renders what applying it would do (`CollectionImport`: replace semantics, added/changed/unchanged/held/removed) or refuses it (422). Nothing is written. Files over 32 MB are refused before parsing (`CollectionImport::MAX_BYTES`); Puma, Thruster (`MAX_REQUEST_BODY` in the `Dockerfile`) and kamal-proxy (`config/deploy.yml`) refuse request bodies over 40 MB."

`README.md`, "Your data": "Import isn't in the app yet." becomes "A collector can preview importing a file from the account menu or More: the app says what applying it would do and which rows it can't apply, and changes nothing. Applying an import isn't in the app yet."

`docs/roadmap.md`, theme A item 4: "[#39](…) Preview an import: per-row errors, nothing written." gains " **Done 2026-10-15:** [spec 025](specs/025-import-preview/spec.md), [ADR 0021](adr/0021-export-format-rules-in-the-app.md)." (the PR link is added in Phase 6 once the PR exists).

`docs/adr/README.md`, under "### Data safety", after the 0020 line:

```markdown
- [0021](0021-export-format-rules-in-the-app.md): The app checks export files with `json_schemer` and its own copy of the schema
```

`docs/adr/0020-export-format.md`, the consequence "An import that validates files inside the running app has to decide where its copy of the rules lives." gains: " [ADR 0021](0021-export-format-rules-in-the-app.md) decides it: `json_schemer` in the app and a byte-identical copy of the schema."

Then grep for statements this change makes stale: `git grep -n -i "nothing reads\|import isn't\|no upload feature" -- . ':!.kamal/secrets' ':!docs/specs/0*'`; expect no hits outside the lines above.

Spec 022 isn't edited (decision 14): spec 025 records that Import collection supersedes its decision 6's menu order. Shipped specs that mention import as future work (specs 017 and 022) stay as they are.

### Step 5.2: Commit

```sh
git add CLAUDE.md README.md docs/roadmap.md docs/adr/README.md docs/adr/0020-export-format.md
git commit -m "docs(025): say that importing a file can be previewed" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Phase 6: Integration verification

**Implements:** All FRs | **Satisfies:** AC-1.10, AC-3.4 (by hand), AC-5.4, all ACs

- [ ] **AC-1.10, measured against a running server.** In the development database, a throwaway script (`bin/rails runner`, kept in the session scratchpad, never committed) inserts 50,000 printings' catalog rows with `insert_all` (one set, identities, entries, `mtg_printings`) and writes three files of 50,000 rows to the scratchpad: all resolvable, all with unknown source ids, all with `"price_paid": "1"`. With `bin/dev` running (background task), sign in with curl (`-c`/`-b` cookie jar, the session form's token), then for each file: read Puma's `VmRSS` from `/proc/<pid>/status`, `curl -s -o /dev/null -w "%{http_code} %{time_total}\n" -F export_file=@<file> …/collection/import_preview` with the CSRF token, read `VmRSS` again. Record the three times, the three RSS deltas and the method in `verification.md`; each must be under 30 s and 500 MB. Delete the inserted rows afterwards. **If the 500 MB memory bar is missed** (json_schemer's classic output keeps a Result tree per lot), the named fallback inside decision 5 is to keep `json_schemer` but validate the header with `lots` replaced by `[]` and each lot with `schemer.ref("#/$defs/lot")`, prefixing each pointer with `/lots/<i>`; it is still the schema checked by `json_schemer`, so ADR 0021 holds. Ask the maintainer before applying it.
- [ ] **AC-3.4 by hand.** Start the server (`bin/dev`, in the background), sign in from a browser to get a session cookie, or simply post without one: `head -c 41000000 /dev/zero > tmp/big.bin && curl -s -o /dev/null -w "%{http_code}\n" -X POST -H "Content-Type: application/octet-stream" --data-binary @tmp/big.bin http://127.0.0.1:<port>/collection/import_preview` — expect `413`. Record the output; remove `tmp/big.bin`.
- [ ] **AC-5.4 screenshots.** With the server running, take the upload page, a refused file, and a preview with removed lots and problem rows, at 1280px and 390px (a 390px frame, per `.claude/memory/headless-firefox-narrow-frame.md`), light and dark: twelve PNGs in `docs/specs/025-import-preview/screenshots/`. Check that nothing scrolls sideways.
- [ ] **Full suite and CI:** `bin/ci` — expect: all steps pass. Record the seed and the SHA it ran at.
- [ ] **`verification.md`:** each AC with its evidence (spec file and example, or reading), the measurements, the screenshots, the bin/ci run, and any deviation from this plan's code with its reason. Commit: `docs(025): record verification`.
- [ ] **Implementation review:** `sdd-superpowers:sdd-review` Mode B, read-only on Opus; apply findings through `receiving-code-review`.
- [ ] **Push and PR:** `git push -u origin 025-import-preview`; `gh pr create --draft` with a body that closes #39, ending with the attribution line. Then add the PR link to the roadmap's item 4 in a `docs(025)` commit and push.

## Quickstart Validation

1. `bin/dev` and sign in.
2. Account menu → Export collection: a file downloads.
3. Account menu → Import collection → choose that file → Preview import: "This file can be applied.", every lot unchanged.
4. Edit the file: change one lot's quantity, delete another, add a row with `"source_id": "nope"`. Preview again: 1 changed, 1 removed (listed), and row N "Not in this instance's catalog", with "This file can't be applied: 1 row has problems."
5. Preview a file with `"currency": "EUR"`: the form again with "This file's prices are in EUR. This instance uses USD."
6. Check nothing changed: the collection page shows the same lots.

## Spec coverage

| Requirement | Phase |
|---|---|
| FR-1 | 2 |
| FR-2 | 1 |
| FR-3 | 2 |
| FR-4 | 2 (reader), 3 (AC-1.9) |
| FR-5 | 2, 3 (AC-4.1) |
| FR-6 | 1 (parse message dropped), 2, 3 (AC-1.8, filter) |
| FR-7 | 2 (32 MB), 4 (40 MB) |
| FR-8 | 3 |
| FR-9 | 3 (core spec) |
| AC-1.1–1.9, 1.11 | 2, 3 |
| AC-1.10 | 6 |
| AC-2.1–2.8 | 1 (2.7), 2, 3 |
| AC-3.1–3.5 | 2, 3, 4, 6 (3.4 by hand) |
| AC-4.1, 4.2 | 2, 3 |
| AC-5.1–5.3, 5.5 | 3, 5 |
| AC-5.4 | 3 (360px check), 6 (screenshots) |
