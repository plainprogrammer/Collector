# Implementation Plan: Export Format

**Spec:** docs/specs/017-export-format/spec.md (v1.1.2, Approved; reviewed once: Fable Mode A, NEEDS REVISION, all findings applied)
**Decisions:** ADR 0020, "The export format is one versioned JSON document keyed by source ids". It is a deliverable of this plan (spec FR-10) and its full text is in Phase 3.
**Issue:** [#37](https://github.com/plainprogrammer/Collector/issues/37)
**Created:** 2026-10-11
**Status:** Draft, awaiting the maintainer's approval.
**Revised:** 2026-10-11, after a read-only plan review (Fable, READY TO EXECUTE). The reviewer extracted every block, matched all 32 checksums, reproduced each red and green count, found every edit anchor exactly once, and probed the rules with its own inputs: none raised. Applied:
- a file of a higher version fails version 1's schema but isn't called malformed: its own example, and a sentence in the document
- `generator` is any string, so it can never be a reason to refuse a file (FR-2)
- additions 5 and 6 below, which the first draft made without listing
- ADR 0020's status names decision 20; the profile's name and dates wording; a comment on `same_collection?`

## Global Constraints

- The format is one JSON document, UTF-8, for one account's collection. No internal primary key appears in a file (FR-1).
- `format_version` is a whole number, 1 in this feature. Once merged, the meaning of version 1 never changes (FR-8).
- Finish, condition and price paid are always present and `null` when not recorded; never an empty string (FR-5).
- Price paid is the price of one copy, as a string matching `^(0|[1-9][0-9]*)\.[0-9]{2}$` (FR-5).
- Every time is `YYYY-MM-DDTHH:MM:SSZ` (FR-2).
- The core of the format document and the schema name no collectible. Everything about Magic sits under "Collectible types" (FR-6).
- Nothing a collector or operator can reach is added, and no dependency that the running application loads (FR-10). `json_schemer` goes in the `:test` group with `require: false`.
- Field names are the ones in "Plan decisions" below, exactly. Export (#38) and import (#39, #40) are built against them.
- Specs: `type:` tags aren't needed (no request or system spec); multi-expectation examples carry `:aggregate_failures`; RuboCop clean under the project config.
- Only spec 017 and ADR 0020 belong to this branch. Specs 018 and 019 are sibling worktrees; don't touch their directories. Any other ADR takes 0021 or later.

## Context

**Facts established during planning (2026-10-11):**

- **The plan's code was run before it was written down.** Every file below was drafted in the session scratchpad, and the code blocks in this plan were rendered from those files by a script, not retyped. The two spec files ran from the worktree with `bin/rspec` (the real `rails_helper`, test database and RuboCop config) against scratch copies of the planned files, with `Rails.root` pointed at the copy. `json_schemer` was locked and installed in a scratch copy of the `Gemfile` (`BUNDLE_GEMFILE=<scratch>/Gemfile`), so the worktree stayed untouched.
  - All files in place: **27 examples, 0 failures** (16 in the examples spec, 11 in the document spec).
  - Phase 1's red state: the examples spec with no rules module gives **16 examples, 16 failures**, each a `NameError: uninitialized constant ExportFormatRules`.
  - Phase 1's green state needs no format document: the examples spec alone gives 16 examples, 0 failures.
  - Phase 2's red state: the document spec (its first nine examples) with no document gives **9 failures**, each an `Errno::ENOENT`.
  - Phase 3's red state: the two new examples fail against today's `README.md` and `docs/adr/README.md`.
  - RuboCop reports one offense per spec file, `RSpec/DescribeClass`, which Phase 1's exclusion removes. The rules module and the generator have none.
- **The guards fail when the document drifts.** With the `sessions` row and the `users.admin` row deleted from a scratch copy of the document, four coverage examples failed and RSpec named `["sessions"]` and `["users.admin"]` as the missing elements. With a sixth condition added to the Magic table, the conditions example failed.
- **`bundle lock` with `json_schemer`** adds `json_schemer (2.5.0)`, `hana (1.3.7)` and `simpleidn (0.3.0)`, with checksums, and changes nothing else. `bigdecimal` and `regexp_parser`, its other dependencies, are already locked. `bundler-audit` on that lockfile: no vulnerabilities.
- **The image installs the `:test` group already.** The `Dockerfile` sets `BUNDLE_WITHOUT="development"`, so Capybara and WebMock are in the published image today and `json_schemer` will be too. Nothing loads it there: production requires only the default and production groups, and the gem is `require: false`.
- **`json_schemer` 2.5.0 behaviour that the rules module depends on:**
  - An error's `"type"` is the failing keyword (`pattern`, `const`, `minimum`, `maximum`, `required`), except for a type mismatch: `"type"` when the schema allows several types, and the type's own name (`"integer"`, `"string"`) when it allows one. The module reports all of those as `type`.
  - A `required` error sits at the parent's pointer with `details.missing_keys`. The module reports one problem per missing key, at the key's own pointer.
  - With the default Ruby regexp resolver, `^…$` matches per line, so `"12.50\n"` would pass the price pattern. The module uses `regexp_resolver: "ecma"`, under which it fails. The spec has that case.
- **JSON parsing (json 3.0.2 in the bundle, 2.19.9 as Ruby's default gem):** `JSON.parse(text, allow_duplicate_key: false)` raises `JSON::ParserError` on a repeated key. A byte order mark and `NaN` raise it too.
- **`Date.valid_date?(2026, 2, 30)` is false**, while `Time.utc(2026, 2, 30)` rolls over to March without raising. The module checks a time's parts itself.
- **The example generator gives the same bytes under both json versions.** Its output was compared file by file, and the checksums in Phase 1 are of that output.
- **Tables that belong to an account or a user** (test database, `account_id` or `user_id` column): `bulk_removals`, `bulk_selection_marks`, `bulk_selections`, `lots`, `scanner_sitting_entries`, `scanner_sittings`, `sessions`, `users`. No Solid Queue table has either column, although those tables are loaded into the test database.
- **For Magic, `catalog_entries.external_key` is the Scryfall card id** (`app/models/mtg/scryfall/mapper.rb:21`), the set code is Scryfall's (`:23`) and the language is Scryfall's `lang` (`:26`).
- **The app has no version constant.** Release tags exist (`v0.2.1` is the newest). What export writes into `generator` is #38's decision; the field is optional.
- **Not run during planning:**
  - The full suite and `bin/ci` with the new files in place. They run in Phase 4.
  - `bin/rubocop` over the whole repository after the `.rubocop.yml` edit.

**Plan decisions (not spelled out in the spec):**

- **Field names.** The spec left them to the plan.

  | Where | Field | Holds |
  |---|---|---|
  | file | `format` | `"collector-export"` |
  | file | `format_version` | `1` |
  | file | `exported_at` | the export time |
  | file | `generator` | optional; the program and version that wrote the file |
  | file | `profile` | object |
  | profile | `name`, `email_address`, `collection_view` | as stored on the user |
  | file | `currency` | ISO 4217 code |
  | file | `lots` | list |
  | lot | `entry` | object |
  | lot | `quantity`, `finish`, `condition`, `price_paid` | as the spec's FR-5 |
  | lot | `added_at`, `changed_at` | the lot's created and updated times |
  | entry | `collectible_type`, `source_id` | the entry identity |
  | entry | `name`, `set_code`, `collector_number`, `language` | the descriptive fields |

  `source_id` is the one identifier field (AC-1.4). It isn't called `id` or `external_key` so that nobody takes it for a key of this instance.
- **Where the files live:** `docs/export-format/README.md` is the format document, `docs/export-format/v1.schema.json` the schema, and `docs/export-format/examples/` the examples. A folder's `README.md` renders when the folder is opened on GitHub. The schema's name carries the version, so that version 2 can add `v2.schema.json` beside it.
- **The schema is JSON Schema, draft 2020-12**, and states no collectible: `finish`, `condition` and `collectible_type` are any non-blank string.
- **The schema accepts only `format_version` 1.** A file of another version fails it at `/format_version`; a reader then looks at the number to tell "newer than I can read" from "not a version".
- **What a schema can't state** is checked by `ExportFormatRules.problems`: UTF-8, JSON with no repeated key, real moments, `changed_at` not before `added_at`, no duplicate lot identity. Each has a rule name that the document lists.
- **Invalid examples name their reason in `examples/problems.json`**: for each file, `why` in words, the `rule` that fails and `at`, a JSON Pointer. The suite expects each invalid file to fail for exactly that one problem. Variants of one rule (the six malformed prices, for example) are table rows in the spec, not more files.
- **The rules live in `spec/support/export_format_rules.rb`**, as test support. The app has no export or import to own them yet, and `lib/` or `app/` would make `json_schemer` a runtime dependency. #39 decides where a reader inside the app keeps its copy.
- **Two spec files at the top of `spec/`**, beside `readme_spec.rb` and `admin_catalog_core_spec.rb`, which check repository files the same way: `spec/export_format_examples_spec.rb` (schema, rules and examples) and `spec/export_format_document_spec.rb` (document against schema, examples and application).
- **The document is parsed by its Markdown tables.** `ExportFormatRules.table(text, heading)` reads the table whose first column has that heading. No cell may contain a `|`; the price pattern is in a code block for that reason.
- **Example data is illustrative.** The source ids are invented (`00000000-0000-4000-8000-00000000000N`), and the document says so.
- **Example files are written by a generator, run once.** There are 32 files, about 1,100 lines, and most differ from another by one value. The generator is 110 lines, is not committed, and its output is checked against the checksums in Phase 1.
- **`4.0` counts as a whole number.** JSON Schema's `integer` accepts it, and the plan leaves that as the schema has it.
- **No `data-model.md` or `contracts/` beside this plan.** The format document is the contract, and nothing is stored.

**Additions to the spec that need the maintainer's ruling.** The plan carries these; Phase 0 writes them into the spec as version 1.2.0. If the maintainer strikes one, the matching lines come out of Phase 0 and of the files named.

1. **A repeated key makes a file not well-formed** (rule `not_json`). `{"finish": "foil", "finish": null}` has no single finish, so lot identity can't be decided. The spec's Error Scenarios don't list it. Files: the document's "The file" and "Well-formed and resolvable", `examples/invalid/repeated-key.json`.
2. **A time must be a real moment** (rule `not_a_time`). `2026-02-30T18:02:11Z` has FR-2's form and names no moment. The spec says only "isn't in FR-2's form". Files: the document's "Times", `examples/invalid/time-not-a-moment.json`.
3. **`accounts` is in the coverage table**, marked "Nothing to export" with its three columns left out. The spec's FR-9 says only that the document mentions it. Listing its columns means that a column added to `accounts` fails the guard, which is exactly what #64 (currency per account) will do.
4. **`generator` names any program**, not only Collector's version (FR-2 says "the Collector version that wrote the file"). A file written by another tool can then say so.
5. **No byte order mark.** A file that starts with one isn't JSON to a strict parser (rule `not_json`). The spec's FR-1 says only "encoded as UTF-8".
6. **`collection_view` is required and not blank**, like the name and the email address. FR-3 says the file carries it; the Error Scenarios list only the other two as required.

One clarification needs no ruling: the document says a `null` finish or condition is always resolvable. The spec's glossary doesn't say so, and the app already treats it that way (`Lot#finish_offered` skips a blank finish).

**Changes outside the spec's list of deliverables:** a decision-log row (32) and a note on item 10 in `docs/roadmap.md`, and an automated check of FR-6 (the core names no collectible), which no acceptance criterion asks for.

### Pre-implementation gates

- **Simplicity:** one test-support module, two spec files, one test-only gem. No application code, migration, route or setting. Nothing beyond the spec except the six additions above.
- **Anti-abstraction:** `json_schemer` is called directly. The module exists because the suite needs the rules a schema can't state and FR-7's comparison in one place.
- **Integration-first:** each phase starts with its failing spec. The schema and examples (the contract) come before the prose that describes them.

---

## Goal

A documented, versioned export format (document, schema, examples and ADR 0020) that the suite checks against itself and against the application, ready for export and import to be built on.

---

## Phase 0: Record the plan's additions in the spec

**Implements:** FR-1, FR-2, FR-9 (wording) | **Satisfies:** AC-3.5 (wording)
**Files:** `docs/specs/017-export-format/spec.md`
**Interfaces:** Consumes: nothing. Produces: spec 1.2.0, which the later phases' rule names and coverage rows match.

The maintainer approved the six additions with this plan. The spec is the source of truth, so it says them before any file does.

- [ ] In `spec.md`, set `**Version:** 1.2.0` and add this changelog row after the 1.1.2 row:

```markdown
| 1.2.0 | 2026-10-11 | Plan additions, approved by the maintainer with the plan (decision 20). **A repeated key** in one object makes a file not well-formed (FR-1, Error Scenarios). **A time must be a real moment** (FR-2, Error Scenarios). **Accounts** join the coverage table as nothing to export, with each column left out, so a column added later fails the guard (FR-9, AC-3.5). **The writer's name:** the optional header field names any program and its version (FR-2). **No byte order mark** (FR-1). **The collection view** is required and not blank (Error Scenarios). The field names are fixed by the plan and the format document |
```

- [ ] In FR-1's **Must** list, replace "Be a single JSON document, encoded as UTF-8." with:

```markdown
- Be a single JSON document, encoded as UTF-8 with no byte order mark.
- Hold no key twice in one object.
```

- [ ] In FR-2, replace the line "Allow, but not require, the Collector version that wrote the file. It is information only." with:

```markdown
- Allow, but not require, the name and version of the program that wrote the file. It is information only.
```

  and in the same list, after the sentence "A writer drops the fraction; it doesn't round.", add a new bullet:

```markdown
- Require every time to be a real moment: 30 February isn't one.
```

- [ ] In FR-9, replace "The accounts table has no data of its own beyond its id and dates; the document says so." with:

```markdown
**Must** mark as nothing to export:
- **Accounts.** The table has no data of its own beyond its id and dates. Each of its columns is listed as left out, so a column added later fails the guard.
```

- [ ] In AC-3.5, replace "lots and users are marked exported, with the left-out columns of FR-9," with "lots and users are marked exported, with the left-out columns of FR-9, accounts is marked nothing to export with every column left out,".

- [ ] In Error Scenarios, replace the row "The profile's name or email address is missing, or empty after trimming" with:

```markdown
| The profile's name, email address or collection view is missing, or empty after trimming | Not well-formed |
```

- [ ] In Error Scenarios, replace the row "The file isn't JSON, or isn't UTF-8" with:

```markdown
| The file isn't JSON, isn't UTF-8, or starts with a byte order mark | Not well-formed |
```

  and add after it:

```markdown
| An object in the file holds the same key twice | Not well-formed |
```

  and after the row "A time isn't in FR-2's form (an offset, a fraction of a second, a date alone)":

```markdown
| A time has FR-2's form but is no real moment (30 February, hour 24) | Not well-formed |
```

- [ ] In Decisions, change the lead sentence's "and 15 to 19 with its approval." to "15 to 19 with its approval, and 20 with the plan's." and add this row after row 19:

```markdown
| 20 | Does the plan's reading of the format stand? | Yes: the field names in the format document; a repeated key and a time that is no real moment are not well-formed; accounts are in the coverage table; the writer's name may be any program's; no byte order mark; the collection view is required. |
```

- [ ] Commit: `docs(017): record the plan's additions in the spec`

---

## Phase 1: Schema, rules and examples

**Implements:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7 | **Satisfies:** AC-1.3, AC-1.4, AC-2.1, AC-2.2, AC-2.3, AC-2.5
**Files:** `Gemfile`, `Gemfile.lock`, `.rubocop.yml`, `spec/export_format_examples_spec.rb`, `spec/support/export_format_rules.rb`, `docs/export-format/v1.schema.json`, `docs/export-format/examples/` (32 files)
**Interfaces:** Consumes: nothing. Produces, all on `ExportFormatRules` (loaded by `rails_helper`'s `spec/support` glob):
- `Problem = Data.define(:rule, :at)`; `RULES` (the five rule names a schema can't state)
- `.directory` → `Pathname` of `docs/export-format`; `.document` → the format document's text; `.version` → the integer the document states
- `.schema_file` → `Pathname` of the newest `v<N>.schema.json`; `.schema` → it, parsed
- `.examples(kind)` → `{ "kind/file.json" => bytes }` for `"valid"`, `"invalid"` or `"comparison"`
- `.problems(bytes)` → `Array<Problem>`, empty when the file is well-formed
- `.identity(lot)` → the five identity values; `.same_collection?(one, other)` → FR-7 on two parsed files
- `.field_names(data)` → every key at any depth; `.section(title)` → a `## ` section's text; `.table(text, heading)` → rows as hashes

The contract first: the schema, the rules a schema can't state, FR-7's comparison, and the example files they are checked against. The format document isn't needed yet.

- [ ] Add the gem. In `Gemfile`, change the `:test` group to:

```ruby
group :test do
  # Checks the export format's examples against its JSON Schema (spec 017); never loaded by the running app.
  gem "json_schemer", "~> 2.4", require: false
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
  gem "vcr"
end
```

- [ ] Run: `bundle install` — expect `Gemfile.lock` to gain exactly `json_schemer (2.5.0)` (depending on `bigdecimal`, `hana (~> 1.3)`, `regexp_parser (~> 2.0)`, `simpleidn (~> 0.2)`), `hana (1.3.7)`, `simpleidn (0.3.0)`, the `json_schemer (~> 2.4)` dependency line and three checksum lines. Check with `git diff --stat Gemfile.lock` (10 insertions, 0 deletions). If a newer 2.x resolves, keep it and note the version in the commit body.
- [ ] Run: `bin/bundler-audit` — expect: `No vulnerabilities found`
- [ ] Commit: `chore(deps): add json_schemer to the test group`

- [ ] In `.rubocop.yml`, extend the comment above `RSpec/DescribeClass` and its list. Replace:

```yaml
# script, and the collector rake spec a rake task, not a class. The image
# publishing spec checks the publishing files, and the admin catalog core spec
# the files of a page.
RSpec/DescribeClass:
  Exclude:
    - "spec/admin_catalog_core_spec.rb"
    - "spec/design_system_files_spec.rb"
```

  with:

```yaml
# script, and the collector rake spec a rake task, not a class. The image
# publishing spec checks the publishing files, and the admin catalog core spec
# the files of a page. The export format specs check the format's document,
# schema and example files.
RSpec/DescribeClass:
  Exclude:
    - "spec/admin_catalog_core_spec.rb"
    - "spec/design_system_files_spec.rb"
    - "spec/export_format_document_spec.rb"
    - "spec/export_format_examples_spec.rb"
```

- [ ] Write the failing spec, `spec/export_format_examples_spec.rb`:

```ruby
require "rails_helper"

# Spec 017: the export format's example files, checked against its schema and the rules a schema can't state
# (docs/export-format/README.md). The rules themselves are in spec/support/export_format_rules.rb.
RSpec.describe "The export format's examples" do
  def parsed(examples) = examples.transform_values { |bytes| JSON.parse(bytes) }

  def problems_of(bytes) = ExportFormatRules.problems(bytes).map { |problem| problem.to_h.stringify_keys }

  # What examples/problems.json says is wrong with each invalid example.
  def named = JSON.parse(ExportFormatRules.directory.join("examples/problems.json").read)

  def base = comparison.fetch("comparison/base.json")

  def lots = parsed(valid).values.flat_map { |file| file["lots"] }

  # Spec 017's Error Scenarios list several ways to break one rule. Each pair here is one of them: where the base
  # file is changed and to what, then the rule that must fail and where.
  def malformed_variants
    {
      [ %w[exported_at], :absent ] => %w[required /exported_at],
      [ %w[profile], :absent ] => %w[required /profile],
      [ %w[currency], :absent ] => %w[required /currency],
      [ %w[format_version], 0 ] => %w[const /format_version],
      [ %w[profile email_address], :absent ] => %w[required /profile/email_address],
      [ %w[profile email_address], "" ] => %w[pattern /profile/email_address],
      [ %w[currency], "US" ] => %w[pattern /currency],
      [ %w[currency], "USDX" ] => %w[pattern /currency],
      [ [ "lots", 0, "entry", "collectible_type" ], :absent ] => %w[required /lots/0/entry/collectible_type],
      [ [ "lots", 0, "entry", "language" ], "" ] => %w[pattern /lots/0/entry/language],
      [ [ "lots", 0, "quantity" ], -1 ] => %w[minimum /lots/0/quantity],
      [ [ "lots", 0, "quantity" ], 10_000 ] => %w[maximum /lots/0/quantity],
      [ [ "lots", 0, "quantity" ], 2.5 ] => %w[type /lots/0/quantity],
      [ [ "lots", 0, "quantity" ], "4" ] => %w[type /lots/0/quantity],
      [ [ "lots", 0, "finish" ], " " ] => %w[pattern /lots/0/finish],
      [ [ "lots", 0, "condition" ], :absent ] => %w[required /lots/0/condition],
      [ [ "lots", 0, "price_paid" ], :absent ] => %w[required /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], 12.5 ] => %w[type /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "012.50" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "-1.00" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "$3.00" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "1,200.00" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "12.50\n" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "added_at" ], :absent ] => %w[required /lots/0/added_at],
      [ [ "lots", 0, "added_at" ], "2026-09-30T18:02:11.250Z" ] => %w[pattern /lots/0/added_at],
      [ [ "lots", 0, "added_at" ], "2026-09-30" ] => %w[pattern /lots/0/added_at],
      [ [ "lots", 0, "added_at" ], "2026-09-30T24:00:00Z" ] => %w[not_a_time /lots/0/added_at],
      [ %w[exported_at], "2026-13-01T00:00:00Z" ] => %w[not_a_time /exported_at]
    }
  end

  # The base file with one value replaced, or removed when the value is :absent, as bytes.
  def changed(path, value)
    data = JSON.parse(base)
    *parents, last = path
    target = parents.empty? ? data : data.dig(*parents)
    value == :absent ? target.delete(last) : target[last] = value
    JSON.generate(data)
  end

  let(:valid) { ExportFormatRules.examples("valid") }
  let(:invalid) { ExportFormatRules.examples("invalid") }
  let(:comparison) { ExportFormatRules.examples("comparison") }

  it "is defined by a schema that is itself valid" do
    expect(JSONSchemer.valid_schema?(ExportFormatRules.schema)).to be(true)
  end

  it "has valid, invalid and comparison examples", :aggregate_failures do
    expect(valid.keys).to eq(%w[valid/collection.json valid/empty.json])
    expect(invalid.size).to eq(21)
    expect(comparison.size).to eq(8)
  end

  it "finds nothing wrong with any valid or comparison example (AC-2.1)" do
    found = valid.merge(comparison).transform_values { |bytes| problems_of(bytes) }

    expect(found.reject { |_name, problems| problems.empty? }).to be_empty
  end

  it "finds each invalid example wrong for the one reason it names (AC-2.2)" do
    found = invalid.transform_values { |bytes| problems_of(bytes) }

    expect(found).to eq(named.transform_values { |entry| [ entry.slice("rule", "at") ] })
  end

  it "says in words why each invalid example is wrong (AC-2.2)" do
    expect(named.values.map { |entry| entry["why"].to_s.strip }).to all(match(/\A[A-Z].+\.\z/))
  end

  it "has an invalid example for every rule a schema can't state (AC-2.2)" do
    expect(named.values.map { |entry| entry["rule"] }).to include(*ExportFormatRules::RULES)
  end

  it "finds every listed variant of a malformed value (AC-2.2)", :aggregate_failures do
    malformed_variants.each do |(path, value), (rule, at)|
      expect(problems_of(changed(path, value))).to eq([ { "rule" => rule, "at" => at } ]), "#{path.join('/')} = #{value.inspect}"
    end
  end

  it "fails version 1's schema for a file of another version, which a reader refuses before it checks (FR-8)" do
    expect(problems_of(changed(%w[format_version], 2))).to eq([ { "rule" => "const", "at" => "/format_version" } ])
  end

  it "accepts the values at the edges of each rule", :aggregate_failures do
    {
      %w[generator] => :absent, %w[profile collection_view] => "gallery", [ "lots", 0, "price_paid" ] => nil, %w[currency] => "XTS",
      [ "lots", 0, "quantity" ] => 9_999, [ "lots", 0, "price_paid" ] => "0.00", [ "lots", 0, "finish" ] => "glossy",
      [ "lots", 0, "changed_at" ] => "2026-09-30T18:02:11Z", [ "lots", 0, "entry", "collectible_type" ] => "comics",
      %w[lots] => []
    }.each do |path, value|
      expect(problems_of(changed(path, value))).to be_empty, "#{path.join('/')} = #{value.inspect}"
    end
  end

  it "covers every shape a lot can take between the valid examples (AC-2.3)", :aggregate_failures do
    identities = lots.map { |lot| ExportFormatRules.identity(lot) }
    differing = identities.combination(2).map { |one, other| one.each_index.reject { |index| one[index] == other[index] } }

    expect(lots).to include(a_hash_including("finish" => String, "condition" => String, "price_paid" => String))
    expect(lots).to include(a_hash_including("finish" => nil, "condition" => nil, "price_paid" => nil))
    expect(lots.map { |lot| lot["price_paid"] }).to include("0.00")
    expect(lots.map { |lot| lot["quantity"] }).to include(1, 9_999)
    expect(differing).to include([ 2 ], [ 3 ], [ 4 ])
    expect(parsed(valid).values.map { |file| file["lots"].size }).to include(0)
  end

  it "describes every lot's entry for a reader with no catalog (AC-1.3)" do
    described = lots.map { |lot| lot["entry"].values_at("collectible_type", "source_id", "name", "set_code", "collector_number", "language") }

    expect(described.flatten).to all(match(/\S/))
  end

  it "carries no credential, role or internal id (AC-1.4)", :aggregate_failures do
    names = parsed(valid).values.flat_map { |file| ExportFormatRules.field_names(file) }.uniq

    expect(names).not_to include("admin", "password", "session")
    expect(names.grep(/_digest\z/)).to be_empty
    expect(names.grep(/(\A|_)(id|key)\z/)).to eq(%w[source_id])
  end

  describe "the same collection (FR-7)" do
    def different = parsed(comparison).select { |name, _file| name.start_with?("comparison/different-") }

    let(:original) { JSON.parse(base) }
    let(:same) { JSON.parse(comparison.fetch("comparison/same.json")) }

    it "holds for a file that differs only in what the rule ignores (AC-2.5)" do
      expect(ExportFormatRules.same_collection?(original, same)).to be(true)
    end

    it "is tested by a pair that differs in everything the rule ignores (AC-2.5)", :aggregate_failures do
      expect(same["lots"].map { |lot| ExportFormatRules.identity(lot) }).to eq(original["lots"].map { |lot| ExportFormatRules.identity(lot) }.reverse)
      expect(same.values_at("exported_at", "generator")).not_to include(*original.values_at("exported_at", "generator"))
      expect(same["lots"].last["entry"].values_at("name", "set_code")).not_to include(*original["lots"].first["entry"].values_at("name", "set_code"))
      expect(ExportFormatRules.field_names(same) - ExportFormatRules.field_names(original)).to match_array(%w[note shelf])
    end

    it "fails for each file that differs in one thing the rule compares (AC-2.5)", :aggregate_failures do
      expect(different.keys.map { |name| name[/different-(.+)\.json/, 1] })
        .to eq(%w[changed-at currency email-address finish missing-lot quantity])
      different.each { |name, file| expect(ExportFormatRules.same_collection?(original, file)).to be(false), name }
    end

    it "is only defined for files of one version" do
      expect { ExportFormatRules.same_collection?(original, original.merge("format_version" => 2)) }.to raise_error(ArgumentError)
    end
  end
end
```

- [ ] Run: `bin/rspec spec/export_format_examples_spec.rb` — expect: FAIL, `16 examples, 16 failures`, each `NameError: uninitialized constant ExportFormatRules`

- [ ] Write the rules, `spec/support/export_format_rules.rb`:

```ruby
require "json_schemer"

# The export format's rules as the suite applies them (spec 017, docs/export-format/README.md): what makes a file
# well-formed, what identifies a lot, and when two files hold the same collection. Test support only: the app has
# no export or import yet, and json_schemer is never loaded outside the suite.
module ExportFormatRules
  Problem = Data.define(:rule, :at)

  # The rules a schema can't state, and the two that apply before a schema can.
  RULES = %w[not_utf8 not_json not_a_time changed_before_added duplicate_lot].freeze
  TIME = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\z/
  JSON_TYPES = %w[array boolean integer null number object string].freeze

  def self.directory = Rails.root.join("docs/export-format")

  def self.document = directory.join("README.md").read

  # The version the document says it defines.
  def self.version = document[/^\*\*Format version:\*\* (\d+)$/, 1].to_i

  # The schema of the newest version: v<N>.schema.json.
  def self.schema_file = directory.glob("v*.schema.json").max_by { |file| file.basename.to_s[/\d+/].to_i }

  def self.schema = JSON.parse(schema_file.read)

  # The examples of one kind ("valid", "invalid", "comparison"), as bytes keyed by their path under examples/.
  def self.examples(kind)
    directory.glob("examples/#{kind}/*.json").sort.to_h { |file| [ "#{kind}/#{file.basename}", file.binread ] }
  end

  # Why a file isn't well-formed: an empty list when it is. Schema problems carry the schema keyword that failed.
  def self.problems(bytes)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    return [ Problem.new("not_utf8", "") ] unless text.valid_encoding?

    data = JSON.parse(text, allow_duplicate_key: false)
    found = schema_problems(data)
    found.empty? ? rule_problems(data) : found
  rescue JSON::ParserError
    [ Problem.new("not_json", "") ]
  end

  # What identifies a lot (ADR 0019): its entry's type and source id, finish, condition and price paid.
  def self.identity(lot)
    lot.fetch("entry").values_at("collectible_type", "source_id") + lot.values_at("finish", "condition", "price_paid")
  end

  # Whether two well-formed files of one version hold the same collection (spec 017 FR-7). Callers check
  # .problems first: a file that isn't well-formed may raise here.
  def self.same_collection?(one, other)
    raise ArgumentError, "the files have different format versions" unless one["format_version"] == other["format_version"]

    compared(one) == compared(other)
  end

  # Every field name in a parsed file, at any depth.
  def self.field_names(data)
    case data
    when Hash then data.keys | data.values.flat_map { |value| field_names(value) }
    when Array then data.flat_map { |value| field_names(value) }.uniq
    else []
    end
  end

  # A "## " section of the format document, without its heading.
  def self.section(title)
    document[/^## #{Regexp.escape(title)}\n(.*?)(?=^## |\z)/m, 1] or raise KeyError, "no section #{title}"
  end

  # The rows of the table in +text+ whose first column is headed +heading+, as hashes keyed by column heading.
  # Backticks are dropped from the cells.
  def self.table(text, heading)
    lines = text.lines.map(&:strip)
    start = lines.index { |line| line.start_with?("| #{heading} |") } or raise KeyError, "no table headed #{heading}"
    header = cells(lines[start])
    lines.drop(start + 2).take_while { |line| line.start_with?("|") }.map { |line| header.zip(cells(line)).to_h }
  end

  def self.cells(line) = line.delete_prefix("|").delete_suffix("|").split("|", -1).map { |cell| cell.strip.delete("`") }

  def self.schema_problems(data)
    JSONSchemer.schema(schema, regexp_resolver: "ecma").validate(data).flat_map do |error|
      missing = error.dig("details", "missing_keys")
      next missing.map { |key| Problem.new("required", "#{error["data_pointer"]}/#{key}") } if missing

      [ Problem.new(JSON_TYPES.include?(error["type"]) ? "type" : error["type"], error["data_pointer"]) ]
    end
  end

  def self.rule_problems(data)
    lots = data["lots"].each_with_index.to_a
    times = [ [ "/exported_at", data["exported_at"] ] ] +
      lots.flat_map { |lot, index| %w[added_at changed_at].map { |name| [ "/lots/#{index}/#{name}", lot[name] ] } }
    not_times = times.reject { |_at, value| moment?(value) }.map { |at, _value| Problem.new("not_a_time", at) }
    backwards = lots.select { |lot, _index| lot["changed_at"] < lot["added_at"] }
      .map { |_lot, index| Problem.new("changed_before_added", "/lots/#{index}/changed_at") }
    repeats = lots.group_by { |lot, _index| identity(lot) }.values
      .flat_map { |group| group.drop(1).map { |_lot, index| Problem.new("duplicate_lot", "/lots/#{index}") } }
    not_times + backwards + repeats
  end

  def self.moment?(value)
    year, month, day, hour, minute, second = value.match(TIME).captures.map(&:to_i)
    Date.valid_date?(year, month, day) && hour < 24 && minute < 60 && second < 60
  end

  def self.compared(file)
    [ file.fetch("profile").slice("name", "email_address", "collection_view"), file["currency"],
      file.fetch("lots").to_h { |lot| [ identity(lot), lot.values_at("quantity", "added_at", "changed_at") ] } ]
  end

  private_class_method :schema_problems, :rule_problems, :moment?, :compared, :cells
end
```

- [ ] Write the schema, `docs/export-format/v1.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:collector:export-format:v1",
  "title": "Collector export, format version 1",
  "description": "The part of a well-formed Collector export that a schema can state. README.md beside this file defines the format and lists the rules a schema can't state: the file is UTF-8 JSON with no repeated key, every time is a real moment, no lot was changed before it was added, and no two lots have the same identity.",
  "type": "object",
  "required": ["format", "format_version", "exported_at", "profile", "currency", "lots"],
  "properties": {
    "format": { "const": "collector-export" },
    "format_version": { "const": 1 },
    "exported_at": { "$ref": "#/$defs/time" },
    "generator": { "type": "string" },
    "profile": {
      "type": "object",
      "required": ["name", "email_address", "collection_view"],
      "properties": {
        "name": { "$ref": "#/$defs/text" },
        "email_address": { "$ref": "#/$defs/text" },
        "collection_view": { "$ref": "#/$defs/text" }
      }
    },
    "currency": { "type": "string", "pattern": "^[A-Z]{3}$" },
    "lots": { "type": "array", "items": { "$ref": "#/$defs/lot" } }
  },
  "$defs": {
    "text": {
      "description": "A string that isn't empty or only whitespace.",
      "type": "string",
      "pattern": "\\S"
    },
    "recorded_text": {
      "description": "A string that isn't empty or only whitespace, or null when not recorded.",
      "type": ["string", "null"],
      "pattern": "\\S"
    },
    "time": {
      "description": "RFC 3339 in UTC with a Z and no fraction of a second.",
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
    },
    "lot": {
      "type": "object",
      "required": ["entry", "quantity", "finish", "condition", "price_paid", "added_at", "changed_at"],
      "properties": {
        "entry": { "$ref": "#/$defs/entry" },
        "quantity": { "type": "integer", "minimum": 1, "maximum": 9999 },
        "finish": { "$ref": "#/$defs/recorded_text" },
        "condition": { "$ref": "#/$defs/recorded_text" },
        "price_paid": {
          "description": "The price of one copy with exactly two decimal places, or null when not recorded.",
          "type": ["string", "null"],
          "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{2}$"
        },
        "added_at": { "$ref": "#/$defs/time" },
        "changed_at": { "$ref": "#/$defs/time" }
      }
    },
    "entry": {
      "type": "object",
      "required": ["collectible_type", "source_id", "name", "set_code", "collector_number", "language"],
      "properties": {
        "collectible_type": { "$ref": "#/$defs/text" },
        "source_id": { "$ref": "#/$defs/text" },
        "name": { "$ref": "#/$defs/text" },
        "set_code": { "$ref": "#/$defs/text" },
        "collector_number": { "$ref": "#/$defs/text" },
        "language": { "$ref": "#/$defs/text" }
      }
    }
  }
}
```

- [ ] Write the example generator to **your scratchpad directory, not the repository**, as `examples.rb`. It is run once and isn't committed:

```ruby
# Writes the export format's example files (spec 017). Run once from the repository root, then check the result
# against the plan's checksums: ruby examples.rb .
require "json"
require "fileutils"

ROOT = File.join(ARGV.fetch(0), "docs/export-format/examples")
%w[valid invalid comparison].each { |kind| FileUtils.mkdir_p(File.join(ROOT, kind)) }

def write(path, data) = File.write(File.join(ROOT, path), JSON.pretty_generate(data) + "\n")
def deep(data) = JSON.parse(JSON.generate(data))

def entry(n, name, set, number, language = "en")
  { "collectible_type" => "mtg", "source_id" => format("00000000-0000-4000-8000-%012d", n), "name" => name,
    "set_code" => set, "collector_number" => number, "language" => language }
end
def lot(entry, quantity, finish, condition, price, added, changed = added)
  { "entry" => entry, "quantity" => quantity, "finish" => finish, "condition" => condition, "price_paid" => price,
    "added_at" => added, "changed_at" => changed }
end
def file(lots, generator: "Collector 0.2.1", exported_at: "2026-10-11T12:34:56Z")
  { "format" => "collector-export", "format_version" => 1, "exported_at" => exported_at, "generator" => generator,
    "profile" => { "name" => "Ada Example", "email_address" => "ada@example.test", "collection_view" => "table" },
    "currency" => "USD", "lots" => lots }.compact
end

angel = entry(1, "Serra Angel", "dmr", "27")
bolt = entry(2, "Lightning Bolt", "2xm", "117")
forest = entry(3, "Forest", "blb", "280")
elves = entry(4, "Llanowar Elves", "fdn", "227")
spell = entry(5, "Counterspell", "sta", "78", "ja")

# valid
write "valid/collection.json", file([
  lot(angel, 4, "foil", "near_mint", "12.50", "2026-09-30T18:02:11Z", "2026-10-02T09:15:00Z"),
  lot(angel, 1, "nonfoil", "near_mint", "12.50", "2026-09-30T18:03:40Z"),
  lot(angel, 2, "foil", "lightly_played", "12.50", "2026-10-01T07:45:09Z"),
  lot(angel, 1, "foil", "near_mint", "10.00", "2026-10-01T07:46:30Z"),
  lot(bolt, 1, nil, nil, nil, "2026-10-03T20:11:02Z"),
  lot(forest, 9999, "nonfoil", nil, nil, "2026-10-04T10:00:00Z", "2026-10-09T16:20:45Z"),
  lot(elves, 3, nil, "near_mint", "0.00", "2026-10-05T12:00:00Z"),
  lot(spell, 1, "etched", "near_mint", "1200.00", "2026-10-06T08:30:00Z")
])
write "valid/empty.json", file([], generator: nil).merge("profile" => { "name" => "Grace Example", "email_address" => "grace@example.test", "collection_view" => "grid" }, "currency" => "EUR")

# comparison
base = file([
  lot(angel, 4, "foil", "near_mint", "12.50", "2026-09-30T18:02:11Z", "2026-10-02T09:15:00Z"),
  lot(bolt, 1, nil, nil, nil, "2026-10-03T20:11:02Z")
])
write "comparison/base.json", base
same = deep(base)
same["exported_at"] = "2026-10-12T08:00:00Z"
same["generator"] = "Another tool 3.1"
same["note"] = "A field the format doesn't define."
same["lots"].reverse!
same["lots"][1]["entry"].merge!("name" => "Serra Angel (retro frame)", "set_code" => "DMR")
same["lots"][0]["shelf"] = "A field the format doesn't define."
write "comparison/same.json", same
different = lambda do |name, &change|
  data = deep(base)
  change.call(data)
  write "comparison/different-#{name}.json", data
end
different.call("quantity") { |d| d["lots"][0]["quantity"] = 3 }
different.call("changed-at") { |d| d["lots"][0]["changed_at"] = "2026-10-02T09:15:01Z" }
different.call("finish") { |d| d["lots"][0]["finish"] = "nonfoil" }
different.call("currency") { |d| d["currency"] = "EUR" }
different.call("email-address") { |d| d["profile"]["email_address"] = "ada@example.org" }
different.call("missing-lot") { |d| d["lots"].pop }

# invalid: each is this file with one thing wrong
small = file([ lot(angel, 4, "foil", "near_mint", "12.50", "2026-09-30T18:02:11Z", "2026-10-02T09:15:00Z") ])
problems = {}
invalid = lambda do |name, rule, at, why, &change|
  data = deep(small)
  change.call(data)
  write "invalid/#{name}.json", data
  problems["invalid/#{name}.json"] = { "why" => why, "rule" => rule, "at" => at }
end
raw = lambda do |name, rule, why, bytes|
  File.binwrite(File.join(ROOT, "invalid/#{name}.json"), bytes)
  problems["invalid/#{name}.json"] = { "why" => why, "rule" => rule, "at" => "" }
end
raw.call("not-json", "not_json", "The file isn't JSON: the last brace is missing.", JSON.pretty_generate(small).delete_suffix("}"))
raw.call("not-utf8", "not_utf8", "The file isn't UTF-8: the name holds a Latin-1 byte.",
  JSON.pretty_generate(small).sub("Ada Example", "Ad\xE9 Example".b).b + "\n")
raw.call("repeated-key", "not_json", "An object holds the same key twice, so its finish can't be told.",
  JSON.pretty_generate(small).sub(%("finish": "foil",), %("finish": "foil",\n      "finish": null,)) + "\n")
invalid.call("format-missing", "required", "/format", "The format name is missing.") { |d| d.delete("format") }
invalid.call("format-other", "const", "/format", "The format name is another name.") { |d| d["format"] = "some-other-export" }
invalid.call("format-version-missing", "required", "/format_version", "The format version is missing.") { |d| d.delete("format_version") }
invalid.call("format-version-not-a-number", "const", "/format_version", "The format version is a string, not a whole number.") { |d| d["format_version"] = "1" }
invalid.call("lots-missing", "required", "/lots", "The list of lots is missing.") { |d| d.delete("lots") }
invalid.call("profile-name-blank", "pattern", "/profile/name", "The profile's name is empty after trimming.") { |d| d["profile"]["name"] = "   " }
invalid.call("currency-lower-case", "pattern", "/currency", "The currency isn't three upper-case letters.") { |d| d["currency"] = "usd" }
invalid.call("entry-missing", "required", "/lots/0/entry", "A lot has no entry.") { |d| d["lots"][0].delete("entry") }
invalid.call("entry-source-id-missing", "required", "/lots/0/entry/source_id", "A lot's entry has no source id.") { |d| d["lots"][0]["entry"].delete("source_id") }
invalid.call("entry-name-missing", "required", "/lots/0/entry/name", "A lot's entry lacks a descriptive field.") { |d| d["lots"][0]["entry"].delete("name") }
invalid.call("quantity-zero", "minimum", "/lots/0/quantity", "A lot's quantity is 0.") { |d| d["lots"][0]["quantity"] = 0 }
invalid.call("finish-left-out", "required", "/lots/0/finish", "A lot's finish is left out; not recorded is written as null.") { |d| d["lots"][0].delete("finish") }
invalid.call("condition-empty", "pattern", "/lots/0/condition", "A lot's condition is an empty string; not recorded is written as null.") { |d| d["lots"][0]["condition"] = "" }
invalid.call("price-one-place", "pattern", "/lots/0/price_paid", "A lot's price paid has one decimal place.") { |d| d["lots"][0]["price_paid"] = "12.5" }
invalid.call("time-with-offset", "pattern", "/lots/0/added_at", "A time is written with an offset, not with Z.") { |d| d["lots"][0]["added_at"] = "2026-09-30T20:02:11+02:00" }
invalid.call("time-not-a-moment", "not_a_time", "/lots/0/added_at", "A time has the right form but is no real moment: 30 February.") { |d| d["lots"][0].merge!("added_at" => "2026-02-30T18:02:11Z") }
invalid.call("changed-before-added", "changed_before_added", "/lots/0/changed_at", "A lot was last changed before it was added.") { |d| d["lots"][0]["changed_at"] = "2026-09-30T18:02:10Z" }
invalid.call("duplicate-lot", "duplicate_lot", "/lots/1", "Two lots have the same lot identity; only their quantities differ.") { |d| d["lots"] << d["lots"][0].merge("quantity" => 2) }
write "problems.json", problems
```

- [ ] Run, from the repository root: `ruby <scratchpad>/examples.rb .` — expect: no output, and `find docs/export-format/examples -type f | wc -l` prints `32`
- [ ] Verify the files are the ones this plan was tested with. Save the list below as `<scratchpad>/examples.sha256` and run `(cd docs/export-format/examples && sha256sum -c --quiet <scratchpad>/examples.sha256)` — expect: no output, exit 0:

```
4be9f9e52588c0aa3b38f96fb7043e1cb2e48fe8c791eb096b9d1b453b88d43d  valid/collection.json
4d1e88561429bc232c9c8da3bb8f72ec1e36f6fb78a22958fd41ee300b78ed69  valid/empty.json
ddf3a6cf7727776203e34bece59ce058a2b25726800e8e1b126e47a5740fe7e8  invalid/changed-before-added.json
8802231e7207b439827717dc3885c5eb0558b5e378f0e97c0632a9b022a6321f  invalid/condition-empty.json
421e732f5e2f57060ae54f130816ede607a3d7e8b74470f34c20e74dfe3bd52e  invalid/currency-lower-case.json
e512831c55b3d5bf67cebfb6e53cda72d808bac2a2f76f6607341eeca716afee  invalid/duplicate-lot.json
b8efd8d5582c4a7708cfb468ba7f7cc9cf52daf0b3f2321d611f4c127feb75ac  invalid/entry-missing.json
8170f102d57fa002c76d493f0e215984b5acdab14b9f10dff7c03ef0bcfd5711  invalid/entry-name-missing.json
eb4544ea38bb4ca800e2d2c0f200862296a22fbfa5c4fff972419985a42f9ae8  invalid/entry-source-id-missing.json
9d9af8d3e997ed749a2eb5888005eedbcafa20e2b8d48b98e101800996865fb9  invalid/finish-left-out.json
f4d1b2606541356400f0c123c4e88b3bf678a46d4649c55dec7a710db2606890  invalid/format-missing.json
fe006b22c4d90a3cacfb9409131aefd75059eee1f245ff367fec38cf2006a3b1  invalid/format-other.json
7f8c0af618bb4edcac6539a2d8c414302575d0e8573ad7a3df07f9c74b64e016  invalid/format-version-missing.json
5ff0220fbbdeb3dae835d4997db9acc6117f01d3a4e05f22c53dffd77b6e2a6e  invalid/format-version-not-a-number.json
0ac21f7d0e6c784421f96d79d6ffd459b2c7afe1bd9eafc8505b53b62230738e  invalid/lots-missing.json
da4bb42521c3350f570344d05a63a6a764cb3500b80e0ea26886c0f3f9ca7c46  invalid/not-json.json
5a7dbd5bfc8f3b674652d035b5f0b12df7ab9c2e33d0150dad144158b4723414  invalid/not-utf8.json
a7606cf4b44c0219a1d19a2fa9e2734f0c79cf4faae5551a8b92a9974a02aae4  invalid/price-one-place.json
11d27e80a5e78bb4a763261894d02b3e67c08ca5585275e92657bc2edec9bad2  invalid/profile-name-blank.json
662619963ebdab90a70cb395767c17a4b47900fc3bed32274e0fdb5fc198f248  invalid/quantity-zero.json
f6d5f1bcc765c81775e04f074ba558b0cf89f6620fe9ff354ff2437d5c1cf828  invalid/repeated-key.json
085d8646e08d390f77820d23a80dab213ddc5a1885b0f2b0efc3fc320ff75d47  invalid/time-not-a-moment.json
20fffffd010f75ca612c5bc2ee6315037c6c051e724154bdd8c59b55a5f63262  invalid/time-with-offset.json
6c049c87ba756951437dd5a46bce541af3eb4b439ebadb48c86f0aad79ab7681  comparison/base.json
0e99c114a8d8f4785e266b1c8fc75e1a421f665e7666af25376e3d1145f70efd  comparison/different-changed-at.json
859110999440176a31e7213b24d887c708c511c1170508d00484ce3f66e00f38  comparison/different-currency.json
7766f393433fec4199748a97bd6f360b70f2e3737c940b290cad46e183d60efc  comparison/different-email-address.json
d42487608540e7f36c604dd72991558f91732eeb1ca3a2d702b15766981868d9  comparison/different-finish.json
c0de1bb564534531f1ba44817e90f5634a56aad6edf0e878ec451fea90c4a4d1  comparison/different-missing-lot.json
a656bd154dc00bfd81427edcc32cb1bc5794ee05feb7fc9ecfd880e5f4a1f506  comparison/different-quantity.json
58dc298b35fc24bfef22ae55d8275cf9149d76393a4a77efd9fa795868f3aa01  comparison/same.json
09cf646f6a3e2141ed1b0a5af80375463c1d61dfbcbd66a08c33b9257a370b70  problems.json
```

  `invalid/not-utf8.json` holds one Latin-1 byte on purpose and `invalid/not-json.json` and `invalid/repeated-key.json` aren't valid JSON on purpose; don't let an editor "fix" them.

  For reference, the generator writes `valid/collection.json` as:

```json
{
  "format": "collector-export",
  "format_version": 1,
  "exported_at": "2026-10-11T12:34:56Z",
  "generator": "Collector 0.2.1",
  "profile": {
    "name": "Ada Example",
    "email_address": "ada@example.test",
    "collection_view": "table"
  },
  "currency": "USD",
  "lots": [
    {
      "entry": {
        "collectible_type": "mtg",
        "source_id": "00000000-0000-4000-8000-000000000001",
        "name": "Serra Angel",
        "set_code": "dmr",
        "collector_number": "27",
        "language": "en"
      },
      "quantity": 4,
      "finish": "foil",
      "condition": "near_mint",
      "price_paid": "12.50",
      "added_at": "2026-09-30T18:02:11Z",
      "changed_at": "2026-10-02T09:15:00Z"
    },
    {
      "entry": {
        "collectible_type": "mtg",
        "source_id": "00000000-0000-4000-8000-000000000001",
        "name": "Serra Angel",
        "set_code": "dmr",
        "collector_number": "27",
        "language": "en"
      },
      "quantity": 1,
      "finish": "nonfoil",
      "condition": "near_mint",
      "price_paid": "12.50",
      "added_at": "2026-09-30T18:03:40Z",
      "changed_at": "2026-09-30T18:03:40Z"
    },
    {
      "entry": {
        "collectible_type": "mtg",
        "source_id": "00000000-0000-4000-8000-000000000001",
        "name": "Serra Angel",
        "set_code": "dmr",
        "collector_number": "27",
        "language": "en"
      },
      "quantity": 2,
      "finish": "foil",
      "condition": "lightly_played",
      "price_paid": "12.50",
      "added_at": "2026-10-01T07:45:09Z",
      "changed_at": "2026-10-01T07:45:09Z"
    },
    {
      "entry": {
        "collectible_type": "mtg",
        "source_id": "00000000-0000-4000-8000-000000000001",
        "name": "Serra Angel",
        "set_code": "dmr",
        "collector_number": "27",
        "language": "en"
      },
      "quantity": 1,
      "finish": "foil",
      "condition": "near_mint",
      "price_paid": "10.00",
      "added_at": "2026-10-01T07:46:30Z",
      "changed_at": "2026-10-01T07:46:30Z"
    },
    {
      "entry": {
        "collectible_type": "mtg",
        "source_id": "00000000-0000-4000-8000-000000000002",
        "name": "Lightning Bolt",
        "set_code": "2xm",
        "collector_number": "117",
        "language": "en"
      },
      "quantity": 1,
      "finish": null,
      "condition": null,
      "price_paid": null,
      "added_at": "2026-10-03T20:11:02Z",
      "changed_at": "2026-10-03T20:11:02Z"
    },
    {
      "entry": {
        "collectible_type": "mtg",
        "source_id": "00000000-0000-4000-8000-000000000003",
        "name": "Forest",
        "set_code": "blb",
        "collector_number": "280",
        "language": "en"
      },
      "quantity": 9999,
      "finish": "nonfoil",
      "condition": null,
      "price_paid": null,
      "added_at": "2026-10-04T10:00:00Z",
      "changed_at": "2026-10-09T16:20:45Z"
    },
    {
      "entry": {
        "collectible_type": "mtg",
        "source_id": "00000000-0000-4000-8000-000000000004",
        "name": "Llanowar Elves",
        "set_code": "fdn",
        "collector_number": "227",
        "language": "en"
      },
      "quantity": 3,
      "finish": null,
      "condition": "near_mint",
      "price_paid": "0.00",
      "added_at": "2026-10-05T12:00:00Z",
      "changed_at": "2026-10-05T12:00:00Z"
    },
    {
      "entry": {
        "collectible_type": "mtg",
        "source_id": "00000000-0000-4000-8000-000000000005",
        "name": "Counterspell",
        "set_code": "sta",
        "collector_number": "78",
        "language": "ja"
      },
      "quantity": 1,
      "finish": "etched",
      "condition": "near_mint",
      "price_paid": "1200.00",
      "added_at": "2026-10-06T08:30:00Z",
      "changed_at": "2026-10-06T08:30:00Z"
    }
  ]
}
```

  and `examples/problems.json` as:

```json
{
  "invalid/not-json.json": {
    "why": "The file isn't JSON: the last brace is missing.",
    "rule": "not_json",
    "at": ""
  },
  "invalid/not-utf8.json": {
    "why": "The file isn't UTF-8: the name holds a Latin-1 byte.",
    "rule": "not_utf8",
    "at": ""
  },
  "invalid/repeated-key.json": {
    "why": "An object holds the same key twice, so its finish can't be told.",
    "rule": "not_json",
    "at": ""
  },
  "invalid/format-missing.json": {
    "why": "The format name is missing.",
    "rule": "required",
    "at": "/format"
  },
  "invalid/format-other.json": {
    "why": "The format name is another name.",
    "rule": "const",
    "at": "/format"
  },
  "invalid/format-version-missing.json": {
    "why": "The format version is missing.",
    "rule": "required",
    "at": "/format_version"
  },
  "invalid/format-version-not-a-number.json": {
    "why": "The format version is a string, not a whole number.",
    "rule": "const",
    "at": "/format_version"
  },
  "invalid/lots-missing.json": {
    "why": "The list of lots is missing.",
    "rule": "required",
    "at": "/lots"
  },
  "invalid/profile-name-blank.json": {
    "why": "The profile's name is empty after trimming.",
    "rule": "pattern",
    "at": "/profile/name"
  },
  "invalid/currency-lower-case.json": {
    "why": "The currency isn't three upper-case letters.",
    "rule": "pattern",
    "at": "/currency"
  },
  "invalid/entry-missing.json": {
    "why": "A lot has no entry.",
    "rule": "required",
    "at": "/lots/0/entry"
  },
  "invalid/entry-source-id-missing.json": {
    "why": "A lot's entry has no source id.",
    "rule": "required",
    "at": "/lots/0/entry/source_id"
  },
  "invalid/entry-name-missing.json": {
    "why": "A lot's entry lacks a descriptive field.",
    "rule": "required",
    "at": "/lots/0/entry/name"
  },
  "invalid/quantity-zero.json": {
    "why": "A lot's quantity is 0.",
    "rule": "minimum",
    "at": "/lots/0/quantity"
  },
  "invalid/finish-left-out.json": {
    "why": "A lot's finish is left out; not recorded is written as null.",
    "rule": "required",
    "at": "/lots/0/finish"
  },
  "invalid/condition-empty.json": {
    "why": "A lot's condition is an empty string; not recorded is written as null.",
    "rule": "pattern",
    "at": "/lots/0/condition"
  },
  "invalid/price-one-place.json": {
    "why": "A lot's price paid has one decimal place.",
    "rule": "pattern",
    "at": "/lots/0/price_paid"
  },
  "invalid/time-with-offset.json": {
    "why": "A time is written with an offset, not with Z.",
    "rule": "pattern",
    "at": "/lots/0/added_at"
  },
  "invalid/time-not-a-moment.json": {
    "why": "A time has the right form but is no real moment: 30 February.",
    "rule": "not_a_time",
    "at": "/lots/0/added_at"
  },
  "invalid/changed-before-added.json": {
    "why": "A lot was last changed before it was added.",
    "rule": "changed_before_added",
    "at": "/lots/0/changed_at"
  },
  "invalid/duplicate-lot.json": {
    "why": "Two lots have the same lot identity; only their quantities differ.",
    "rule": "duplicate_lot",
    "at": "/lots/1"
  }
}
```

- [ ] Run: `bin/rspec spec/export_format_examples_spec.rb` — expect: PASS, `16 examples, 0 failures`
- [ ] Run: `bin/rubocop spec/export_format_examples_spec.rb spec/support/export_format_rules.rb` — expect: `no offenses detected`
- [ ] Commit: `docs(export-format): define version 1 in a schema with checked examples`

---

## Phase 2: The format document

**Implements:** FR-1 to FR-9 | **Satisfies:** AC-1.1, AC-3.4, AC-3.5, AC-4.1, AC-4.2, AC-4.3; by reading: AC-1.2, AC-1.5, AC-2.4, AC-2.6, AC-3.1, AC-3.2, AC-3.3
**Files:** `spec/export_format_document_spec.rb`, `docs/export-format/README.md`
**Interfaces:** Consumes: `ExportFormatRules.document`, `.version`, `.schema_file`, `.schema`, `.examples("valid")`, `.field_names(data)`, `.section(title)`, `.table(text, heading)` from Phase 1; `Catalog.collecting` and `Catalog.collecting_for(type).conditions` (the application's registered conditions); `Collector::Currency::SYMBOLS`. Produces: `docs/export-format/README.md`, with a `**Format version:** N` line, `## ` sections titled "Currency", "Versions", "Collectible types" and "Coverage", a `### … (`type`)` heading per collectible type with a table headed "Condition", and coverage tables headed "Table" and "Column".

The prose, checked against the schema, the examples and the application. The seven criteria marked (review) in the spec are met by the sections named in Phase 4's table.

- [ ] Write the failing spec, `spec/export_format_document_spec.rb`:

```ruby
require "rails_helper"

# Spec 017: the export format's document (docs/export-format/README.md), checked against its schema, its examples
# and the application, so that a change to one that isn't made to the others fails here.
RSpec.describe "The export format's document" do
  def tables_owned_by_a_collector
    connection = ActiveRecord::Base.connection
    [ "accounts" ] + connection.tables.select { |table| connection.columns(table).map(&:name).intersect?(%w[account_id user_id]) }
  end

  def columns_of(tables)
    tables.flat_map { |table| ActiveRecord::Base.connection.columns(table).map { |column| "#{table}.#{column.name}" } }
  end

  let(:document) { ExportFormatRules.document }
  let(:fields) do
    ExportFormatRules.examples("valid").values.flat_map { |bytes| ExportFormatRules.field_names(JSON.parse(bytes)) }.uniq
  end
  let(:coverage) { ExportFormatRules.section("Coverage") }
  let(:covered_tables) { ExportFormatRules.table(coverage, "Table") }
  let(:covered_columns) { ExportFormatRules.table(coverage, "Column") }

  it "names every field that appears in the valid examples (AC-1.1)" do
    expect(fields.reject { |field| document.include?("`#{field}`") }).to be_empty
  end

  it "states the version that the schema and the valid examples carry (AC-4.1)", :aggregate_failures do
    version = ExportFormatRules.version

    expect(version).to be >= 1
    expect(ExportFormatRules.schema_file.basename.to_s).to eq("v#{version}.schema.json")
    expect(ExportFormatRules.schema.dig("properties", "format_version", "const")).to eq(version)
    expect(ExportFormatRules.examples("valid").values.map { |bytes| JSON.parse(bytes)["format_version"] }).to all(eq(version))
    expect(ExportFormatRules.table(ExportFormatRules.section("Versions"), "Version").last["Version"]).to eq(version.to_s)
  end

  it "lists each collectible type's conditions as the application registers them (AC-4.2)", :aggregate_failures do
    types = ExportFormatRules.section("Collectible types")

    expect(Catalog.collecting.keys).not_to be_empty
    Catalog.collecting.each_key do |type|
      section = types[/^### [^\n]*\(`#{Regexp.escape(type)}`\)\n(.*?)(?=^### |\z)/m, 1].to_s
      listed = ExportFormatRules.table(section, "Condition").map { |row| row["Condition"] }
      expect(listed).to eq(Catalog.collecting_for(type).conditions.keys), type
    end
  end

  it "lists the currencies the application supports (AC-4.3)" do
    expect(ExportFormatRules.section("Currency").scan(/`([A-Z]{3})`/).flatten).to eq(Collector::Currency::SYMBOLS.keys)
  end

  it "names no collectible outside its section for collectible types (FR-6)", :aggregate_failures do
    core = document.sub(/^## Collectible types\n.*?(?=^## )/m, "")
    names = /\b(mtg|magic|scryfall)\b/i

    expect(core).not_to eq(document)
    expect(core).not_to match(names)
    expect(ExportFormatRules.schema_file.read).not_to match(names)
  end

  describe "coverage" do
    it "accounts for every table that belongs to an account or a user (AC-3.4)" do
      expect(covered_tables.map { |row| row["Table"] }).to match_array(tables_owned_by_a_collector)
    end

    it "accounts for every column of a table that isn't left out whole (AC-3.4)" do
      kept = covered_tables.reject { |row| row["In the export"] == "Left out" }.map { |row| row["Table"] }

      expect(covered_columns.map { |row| row["Column"] }).to match_array(columns_of(kept))
    end

    it "marks each table as the spec rules (AC-3.5)", :aggregate_failures do
      status = covered_tables.to_h { |row| [ row["Table"], row["In the export"] ] }

      expect(status).to include("lots" => "Exported", "users" => "Exported", "accounts" => "Nothing to export")
      expect(status.select { |_table, mark| mark == "Left out" }.keys)
        .to match_array(%w[bulk_removals bulk_selection_marks bulk_selections scanner_sitting_entries scanner_sittings sessions])
      expect(covered_tables.map { |row| row["Why"] }).to all(match(/\S/))
    end

    it "maps each column to a field of the format or says why it is left out (AC-3.5)", :aggregate_failures do
      left_out, mapped = covered_columns.partition { |row| row["In the file"] == "Left out" }

      expect(left_out.map { |row| row["Why left out"] }).to all(match(/\S/))
      expect(mapped.map { |row| row["In the file"] } - fields).to be_empty
      expect(left_out.map { |row| row["Column"] }).to match_array(%w[
        accounts.id accounts.created_at accounts.updated_at lots.id lots.account_id lots.lot_key
        users.id users.account_id users.password_digest users.admin users.created_at users.updated_at
      ])
    end
  end
end
```

- [ ] Run: `bin/rspec spec/export_format_document_spec.rb` — expect: FAIL, `9 examples, 9 failures`, each `Errno::ENOENT` for `docs/export-format/README.md`

- [ ] Write the format document, `docs/export-format/README.md`. The tables' first-column headings, the `**Format version:**` line and the section titles are read by the spec; keep them as written:

`````markdown
# Collector export format

**Format name:** `collector-export`
**Format version:** 1

An export is one file that holds one collector's data: their profile, the currency their prices are in, and every lot in their collection.

- **It is personal.** The file contains your name and your email address. It never contains your password.
- **It is complete.** The file contains everything needed to rebuild your collection on another Collector instance.
- **It is yours.** It is plain JSON, and it names every item so that a person can read it without Collector.

This document defines the format. Export and import are built against it, and so is the check that a restored collection matches the one exported. The decision and the alternatives it rejected are in [ADR 0020](../adr/0020-export-format.md). [`v1.schema.json`](v1.schema.json) states the same rules for a program, and [`examples/`](examples/) holds files that the test suite checks against both.

Two words are used throughout. A **writer** is any program that produces a file, and a **reader** is any program that consumes one.

## The file

A file is a single JSON document ([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)): one object, encoded as UTF-8 with no byte order mark. No object in it holds the same key twice.

A file describes exactly one account's collection at one moment. It needs no other file to be read, and nothing in it is an internal id of the instance that wrote it.

| Field | Value | Meaning |
|---|---|---|
| `format` | The string `collector-export` | Says that the file is a Collector export. A reader refuses a file with any other value. |
| `format_version` | A whole number | The version of this format that the file follows. This document defines version 1. See [Versions](#versions). |
| `exported_at` | A [time](#times) | When the file was written. Information only. |
| `generator` | A string; may be left out | The program that wrote the file, and its version (`Collector 0.2.1`). Information only. |
| `profile` | An object | The collector. See [Profile](#profile). |
| `currency` | A string | The currency of every price in the file. See [Currency](#currency). |
| `lots` | A list | The collection. See [Lots](#lots). It may be empty, and its order has no meaning. |

A reader never behaves differently because of `exported_at` or `generator`.

A whole number may be written with a zero fraction: `1.0` is the same number as `1`.

A collection with nothing in it is a complete file:

```json
{
  "format": "collector-export",
  "format_version": 1,
  "exported_at": "2026-10-11T12:34:56Z",
  "profile": {
    "name": "Grace Example",
    "email_address": "grace@example.test",
    "collection_view": "grid"
  },
  "currency": "EUR",
  "lots": []
}
```

### Times

Every time in a file has one form: [RFC 3339](https://www.rfc-editor.org/rfc/rfc3339) in UTC, with a `Z` and no fraction of a second.

```
2026-10-11T12:34:56Z
```

An offset (`+02:00`), a fraction of a second or a date alone is not well-formed. The time must also be a real moment: 30 February isn't one. A writer that holds a finer time drops the fraction; it doesn't round.

### Not recorded

A collector may leave a lot's finish, condition or price blank. The file writes each of those as `null`. The three fields are always present, and an empty string never stands for "not recorded".

## Profile

| Field | Value | Meaning |
|---|---|---|
| `name` | A string that isn't blank | The collector's name, without spaces around it. |
| `email_address` | A string that isn't blank | The collector's email address. Collector writes it in lower case. |
| `collection_view` | A string that isn't blank | How the collector likes to see their collection: `grid` or `table` today. |

`collection_view` is a preference. A reader that doesn't know its value uses its own default, and that isn't an error.

The format says what these fields mean. It doesn't say what a reader does with them: whether an import changes a name or an email address is the import's decision.

A file never carries a password in any form, a role on the instance, sign-in sessions, or the dates an account or its user were created.

## Currency

`currency` is one [ISO 4217](https://www.iso.org/iso-4217-currency-codes.html) code of three upper-case letters. Every `price_paid` in the file is in that currency; there is no currency per lot.

A file is well-formed with any three upper-case letters. A file written by Collector carries one of these:

`USD`, `CAD`, `AUD`, `NZD`, `EUR`, `GBP`, `CHF`, `SEK`, `NOK`, `DKK`, `PLN`, `CZK`, `JPY`, `CNY`, `KRW`, `SGD`, `HKD`, `BRL`, `MXN`, `ZAR`

The code is the currency in force for the collector when the file is written. Today that is the instance's setting. When it becomes each collector's own choice, the field keeps its meaning.

## Lots

A collector owns lots, not single copies ([ADR 0019](../adr/0019-lot-as-the-unit-of-ownership.md)). A lot is a number of copies of one catalog entry that share a finish, a condition and a price paid.

| Field | Value | Meaning |
|---|---|---|
| `entry` | An object | The catalog entry the copies are of. See [Entry](#entry). |
| `quantity` | A whole number from 1 to 9999 | How many copies. |
| `finish` | A string that isn't blank, or `null` | The finish of the copies, as the collectible type names it. |
| `condition` | A string that isn't blank, or `null` | The condition of the copies, as the collectible type names it. |
| `price_paid` | A string in the form below, or `null` | What the collector paid for **one copy**, in the file's currency. |
| `added_at` | A [time](#times) | When the lot was added to the collection. |
| `changed_at` | A [time](#times) | When the lot was last changed. Never earlier than `added_at`. |

All seven fields are always present. The format gives `finish` and `condition` no meaning of its own; the collectible type does ([Collectible types](#collectible-types)). A file says nothing about a single copy within a lot.

### Price paid

`price_paid` is a string of digits, a point, and exactly two more digits. The digits before the point have no leading zero, except a lone `0`.

```
^(0|[1-9][0-9]*)\.[0-9]{2}$
```

`"12.50"`, `"0.00"` and `"1200.00"` are prices. `12.5`, `"12.5"`, `"012.50"`, `"-1.00"`, `"$3.00"` and `"1,200.00"` are not well-formed.

Two places apply to every currency, including those that are usually written without any, because that is how Collector stores and shows a price.

`null` and `"0.00"` are different. `null` is a price that wasn't recorded. `"0.00"` is a copy that was free.

### Entry

| Field | Value | Meaning |
|---|---|---|
| `collectible_type` | A string that isn't blank | The key of the collectible type. |
| `source_id` | A string that isn't blank | The catalog source's own id for the entry, written as the source gives it. |
| `name` | A string that isn't blank | The catalog's name for the entry. It isn't a localized printed name. |
| `set_code` | A string that isn't blank | The code of the set the entry belongs to. |
| `collector_number` | A string that isn't blank | The entry's number within its set. |
| `language` | A string that isn't blank | The language of the entry. |

`collectible_type` and `source_id` together are the **entry identity**. They are the only thing a reader matches an entry on.

The other four are **descriptive fields**. They are information only, so that a person can read the file without a catalog and can repair a lot whose id a source has retired. A reader never matches on them. When they disagree with what the reader's catalog holds for that id, the id wins and the file is still well-formed.

A file carries no other catalog data: no images, rules text or market prices.

## Lot identity

A lot is identified by five values:

1. its entry's `collectible_type`
2. its entry's `source_id`
3. its `finish`
4. its `condition`
5. its `price_paid`

Each is compared character for character. `null` is a value of its own: it matches only `null`.

The descriptive fields, the quantity and the two times are never part of a lot's identity.

A file never holds two lots with the same identity. Copies that share all five values are one lot with a larger quantity.

## Well-formed and resolvable

A file can be wrong in two different ways, and the format keeps them apart.

**Well-formed** is a property of the file alone. It never depends on a catalog or on an instance. A file is well-formed when it passes [`v1.schema.json`](v1.schema.json) and the rules that a schema can't state:

- it is UTF-8 JSON, and no object holds the same key twice
- every time is a real moment
- no lot's `changed_at` is earlier than its `added_at`
- no two lots have the same [identity](#lot-identity)

The schema and these rules are version 1's. A reader looks at `format_version` first: a file whose version is higher than it knows is refused as newer than it can read, not as malformed.

A field that this document doesn't define doesn't make a file malformed. A reader ignores it.

**Resolvable** is a property of a file against one instance's catalog. A well-formed file is resolvable there when, for every lot:

- its entry is in that catalog, retired or not
- its `finish` is `null` or one that the catalog lists for that entry
- its `condition` is `null` or in the collectible type's conditions on that instance

| A well-formed file where | Is |
|---|---|
| a lot's collectible type isn't one the instance has | not resolvable there |
| a lot's entry isn't in the instance's catalog | not resolvable there |
| a lot's entry is in the catalog and retired | resolvable; a lot of a retired entry is still part of a collection |
| a lot's finish isn't one the catalog lists for that entry | not resolvable there |
| a lot's condition isn't one of the type's conditions | not resolvable there |
| a descriptive field disagrees with the catalog | resolvable; the id wins |

The same file may be resolvable on one instance and not on another. What a reader does with a file that isn't well-formed or isn't resolvable is the reader's decision. A reader never guesses at a lot it can't resolve, and never drops it without saying so.

## The same collection

Two well-formed files of the same version hold the same collection when all of these are true:

- Their profiles are equal: `name`, `email_address` and `collection_view`.
- Their currencies are equal.
- Their lots are equal as sets. Each lot in one file has exactly one lot in the other with the same [identity](#lot-identity), and those two have the same `quantity`, `added_at` and `changed_at`.

Every comparison is exact, character for character. A writer writes each value as the instance stores it: the email address in lower case, the name and the email address without spaces around them, the currency in upper case.

These never count: `exported_at`, `generator`, the order of the lots, the descriptive fields, fields this document doesn't define, and how the JSON is laid out.

This is what "matched" means when an export is restored into another instance and exported again. It follows that a reader which restores a collection keeps each lot's `added_at` and `changed_at` as the file gives them.

## Versions

`format_version` is a whole number. It goes up by one when a reader of the earlier version would misread a file or lose a collector's data from it:

- a change to lot identity or entry identity
- a field removed or renamed
- a field given a new meaning or a new form
- a change in which fields are required
- a new field that holds data the collector owns

It doesn't go up for:

- a new optional field that is information only
- a new collectible type
- a new condition for a collectible type, or a finish that a source newly lists
- a new value of `collection_view`
- a new currency

A reader:

- refuses a file whose `format` isn't `collector-export`, or that has no `format_version`
- refuses a file whose `format_version` is higher than any it knows, and says that the file is newer than it can read
- ignores fields it doesn't know. Because a new field of the collector's data raises the version, a field that a reader doesn't know at a version it does know is always information only

The meaning of a version never changes once it has been released.

| Version | Date | Change |
|---|---|---|
| 1 | 2026-10-11 | The first version: profile, currency and lots. |

Two changes are already expected. Locations will add where each lot is kept, which is the collector's data, so they will raise the version to 2. Collections shared by a household will change who owns a lot and will raise it again ([ADR 0017](../adr/0017-row-level-tenancy-one-user-per-account.md)).

## Extending the format

A feature that adds data a collector owns extends the format in the same pull request. It:

1. describes the new data in this document
2. adds it to the schema and to the examples, valid and invalid
3. adds its tables and columns to [Coverage](#coverage)
4. applies the rule in [Versions](#versions) and, if the version goes up, adds a schema for the new version and a line to the version history

The test suite fails until the third step is done: it compares the coverage tables with the application's database.

## Collectible types

Everything in the format that depends on one kind of collectible is in this section. Version 1 has one type.

### Magic: The Gathering (`mtg`)

| Field | For this type |
|---|---|
| `collectible_type` | `mtg` |
| `source_id` | The [Scryfall](https://scryfall.com) card id: one printing of a card in one language. |
| `name` | The card's name as Scryfall gives it. It is the English name whatever the printing's language. |
| `set_code` | Scryfall's set code, in lower case. |
| `collector_number` | The collector number printed on the card, as Scryfall gives it. |
| `language` | Scryfall's language code (`en`, `ja`). |

`condition` is `null` or one of these:

| Condition | Meaning |
|---|---|
| `near_mint` | Near mint |
| `lightly_played` | Lightly played |
| `moderately_played` | Moderately played |
| `heavily_played` | Heavily played |
| `damaged` | Damaged |

`finish` is `null` or one of the finishes that Scryfall lists for that printing. It is an open set: `nonfoil`, `foil` and `etched` are the usual values, and Scryfall may list others. Whether a finish is allowed is a question about one printing in one catalog, so it is part of resolvable and never of well-formed.

A lot of four foil copies, bought for 12.50 each:

```json
{
  "entry": {
    "collectible_type": "mtg",
    "source_id": "00000000-0000-4000-8000-000000000001",
    "name": "Serra Angel",
    "set_code": "dmr",
    "collector_number": "27",
    "language": "en"
  },
  "quantity": 4,
  "finish": "foil",
  "condition": "near_mint",
  "price_paid": "12.50",
  "added_at": "2026-09-30T18:02:11Z",
  "changed_at": "2026-10-02T09:15:00Z"
}
```

The ids in the examples are invented, and the cards are illustrations.

## Coverage

Every table in Collector's database that belongs to an account or to a user is listed here, with what the format does about it. The test suite compares these two tables with the database, so a table or a column that is added without a line here fails the build.

| Table | In the export | Why |
|---|---|---|
| `accounts` | Nothing to export | It holds only its id and its dates; see the columns below. |
| `lots` | Exported | The collection. |
| `users` | Exported | The collector's profile. |
| `bulk_removals` | Left out | A short-lived way to undo a bulk removal. The lots it would restore aren't in the collection. |
| `bulk_selection_marks` | Left out | Working state that lasts for one bulk edit. |
| `bulk_selections` | Left out | Working state that lasts for one bulk edit. |
| `scanner_sitting_entries` | Left out | Working state of one sitting at the scanner. What a sitting adds is already in the lots. |
| `scanner_sittings` | Left out | Working state of one sitting at the scanner. |
| `sessions` | Left out | Sign-in state on one instance. |

| Column | In the file | Why left out |
|---|---|---|
| `accounts.id` | Left out | An internal id. |
| `accounts.created_at` | Left out | A fact about the instance, not about the collection. |
| `accounts.updated_at` | Left out | A fact about the instance, not about the collection. |
| `lots.id` | Left out | An internal id. |
| `lots.account_id` | Left out | An internal id. A file is one account's collection. |
| `lots.catalog_entry_id` | `entry` | |
| `lots.quantity` | `quantity` | |
| `lots.finish` | `finish` | |
| `lots.condition` | `condition` | |
| `lots.price_paid_cents` | `price_paid` | |
| `lots.lot_key` | Left out | Derived from the finish, the condition and the price paid. |
| `lots.created_at` | `added_at` | |
| `lots.updated_at` | `changed_at` | |
| `users.id` | Left out | An internal id. |
| `users.account_id` | Left out | An internal id. |
| `users.name` | `name` | |
| `users.email_address` | `email_address` | |
| `users.password_digest` | Left out | A credential. |
| `users.admin` | Left out | A role on one instance, not the collector's data. |
| `users.collection_view` | `collection_view` | |
| `users.created_at` | Left out | A fact about the instance, not about the collection. |
| `users.updated_at` | Left out | A fact about the instance, not about the collection. |

`lots.catalog_entry_id` is an internal id too. The file writes the entry it points at by its type and source id.

`currency` comes from no table yet. It is the instance's setting.

## Examples

| Folder | Holds |
|---|---|
| [`examples/valid/`](examples/valid/) | Well-formed files: a collection that shows every shape a lot can take, and an empty one. |
| [`examples/invalid/`](examples/invalid/) | Files that aren't well-formed, each with one thing wrong. |
| [`examples/comparison/`](examples/comparison/) | A base file, a file that holds the same collection, and files that each differ from the base in one thing that counts. |

[`examples/problems.json`](examples/problems.json) names, for each invalid file, why it isn't well-formed (`why`), the rule it breaks (`rule`) and where (`at`, a [JSON Pointer](https://www.rfc-editor.org/rfc/rfc6901) into the file, empty for the whole file).

A `rule` is the schema keyword that fails (`required`, `const`, `pattern`, `minimum`, `maximum`, `type`), or one of these:

| Rule | Meaning |
|---|---|
| `not_utf8` | The file isn't UTF-8. |
| `not_json` | The file isn't JSON, or an object holds the same key twice. |
| `not_a_time` | A time has the right form but isn't a real moment. |
| `changed_before_added` | A lot's `changed_at` is earlier than its `added_at`. |
| `duplicate_lot` | A lot has the same identity as an earlier lot in the file. |
`````

- [ ] Run: `bin/rspec spec/export_format_document_spec.rb spec/export_format_examples_spec.rb` — expect: PASS, `25 examples, 0 failures`
- [ ] Run: `bin/rubocop spec/export_format_document_spec.rb` — expect: `no offenses detected`
- [ ] Commit: `docs(export-format): add the format document`

---

## Phase 3: ADR 0020 and the pointers to the format

**Implements:** FR-10 | **Satisfies:** AC-4.4
**Files:** `spec/export_format_document_spec.rb`, `docs/adr/0020-export-format.md`, `docs/adr/README.md`, `README.md`, `docs/roadmap.md`, `CLAUDE.md`
**Interfaces:** Consumes: the spec file from Phase 2. Produces: nothing later phases call.

The decision record, and the places a reader starts from: the README, the ADR index, the roadmap and CLAUDE.md.

- [ ] Check the ADR number is still free: `git fetch origin && git ls-tree --name-only origin/main docs/adr/ | sort | tail -3` — expect no `0020-…` from another branch. 0020 is reserved for this spec; if `origin/main` has taken it all the same, stop and ask the maintainer.

- [ ] Add the failing examples. In `spec/export_format_document_spec.rb`, insert this block before the file's last `end`, after the `describe "coverage"` block and a blank line:

```ruby
  describe "the repository around it (AC-4.4)" do
    it "is linked from the README" do
      expect(Rails.root.join("README.md").read).to include("(docs/export-format/README.md)")
    end

    it "has its decision in the ADR index, no longer among the expected ones", :aggregate_failures do
      adr_index = Rails.root.join("docs/adr/README.md").read

      expect(adr_index).to include("[0020](0020-export-format.md)")
      expect(adr_index[/^### Expected\n.*\z/m]).not_to include("export format")
      expect(Rails.root.join("docs/adr/0020-export-format.md")).to exist
    end
  end
```

- [ ] Run: `bin/rspec spec/export_format_document_spec.rb` — expect: FAIL, `11 examples, 2 failures` (the README link and the ADR index)

- [ ] Write `docs/adr/0020-export-format.md`:

```markdown
# 0020: The export format is one versioned JSON document keyed by source ids

## Status

Accepted (2026-10-11; the maintainer ruled on each point in spec 017: decisions 1 to 19 with the spec and 20 with the plan).

**Date:** 2026-10-11
**Feature:** 017-export-format

## Context

Foundation principle 2 says collectors own their data in open, documented formats. Export, import preview and import apply (roadmap items 3 to 5) each need one agreed format before any of them is built, and the 1.0 test's second check, "an export of that instance has been restored into a fresh instance and matched", needs a definition of "matched". [Spec 017](../specs/017-export-format/spec.md) defines the format; this ADR records the decision and what was rejected.

What the format has to describe is small today:

- A collector owns lots ([ADR 0019](0019-lot-as-the-unit-of-ownership.md)): a quantity of one catalog entry with the same finish, condition and price paid. A lot points at its entry by an internal id, and the catalog keys each entry by the source's own id (for Magic, the Scryfall card id).
- An account has one user ([ADR 0017](0017-row-level-tenancy-one-user-per-account.md)), with a name, an email address and a choice of collection view.
- Price paid is stored in hundredths for every currency, and the currency is one instance setting.

Two changes are known to be coming: locations (roadmap theme C), and collections shared by a household after 1.0, for which ADR 0017 already accepts a format bump.

## Options considered

### The shape of the file

- **One JSON document (chosen).** A header, the profile, the currency and a list of lots. Nested data has somewhere to go when locations and shared collections arrive, and the header carries the version.
- **CSV, one row per lot.** It opens in a spreadsheet, but it has no natural place for the version, the currency or the profile, and a lot divided among places doesn't fit a row.
- **JSON with a CSV view beside it.** Two representations to specify and keep in step, for a convenience that a later feature can add without changing this format.

### How a lot points at its entry

- **The source's id, with descriptive fields beside it (chosen).** The collectible type and the source id identify the entry. The name, set code, collector number and language are information only.
- **The source's id alone.** The smallest file, but a person can't read it without a catalog, and a lot whose id a source later retires leaves no clue to what it was.
- **Descriptive fields as a fallback match.** More forgiving, but it makes the set code, number and language part of identity, so two readers with different catalogs could resolve one file to different entries.

### How price paid is written

- **A decimal string with two places (chosen).** `"12.50"` is what the collector typed and what the app shows.
- **A whole number of minor units.** Exact as well, but Collector stores hundredths for every currency, including those with no minor unit. `1250` in a file whose currency is `JPY` would read as 1,250 yen to anyone who knows ISO 4217 and mean 12.50.

### What raises the version

- **A change that makes an older reader misread a file or lose the collector's data from it (chosen).** That includes a new field that holds data the collector owns.
- **Only a change that makes an older reader misread a file.** New optional fields would be free. A version-1 reader ignores fields it doesn't know, so it would drop a later release's locations without a word and report the same collection.

## Decision

The format is a single JSON document, encoded as UTF-8, that describes one account's collection at one moment. It is defined in [`docs/export-format/README.md`](../export-format/README.md), with a JSON Schema (draft 2020-12) and example files beside it.

- **Header:** the format name `collector-export`, `format_version` (a whole number, 1 today), the time of export and, optionally, the program that wrote it.
- **Contents:** the collector's profile (name, email address, collection view), one ISO 4217 currency for the file, and the lots.
- **A lot:** its entry, quantity, finish, condition, price paid per copy, and when it was added and last changed. Finish, condition and price paid are always present, and `null` when not recorded.
- **An entry:** identified by collectible type and source id, with four descriptive fields that a reader never matches on.
- **No internal primary key appears anywhere.** Lot identity in a file is the entry identity, finish, condition and price paid, as ADR 0019 defines it, and a file never holds two lots with the same identity.
- **Times** are RFC 3339 in UTC to the second.
- **Well-formed and resolvable are kept apart.** Whether a file is well-formed never depends on a catalog. Whether its entries, finishes and conditions exist is a question about one instance.
- **The same collection** is defined by the profile, the currency and the lots as sets. That definition is what "matched" means in the 1.0 test.
- **The version** rises by the rule chosen above. A reader refuses a version higher than it knows and ignores fields it doesn't know.

The document, the schema and the examples are checked against each other and against the application by the test suite. That includes a coverage table of every table that belongs to an account or to a user, which fails the build when a table or column is added without a line in the format document.

## Consequences

- Export and import are built against one definition, and a round trip can be tested by comparing two files.
- The file carries a name and an email address, so export has to treat it as personal data.
- The descriptive fields make the file larger than it needs to be for Collector alone. That is the price of a file a person can read and repair.
- The spec that puts a lot in a location raises the format to version 2, whichever way its own ADR decides ADR 0019's open question.
- A file can only be written by a program that knows the descriptive fields. A tool that knows only source ids can't write a well-formed file. Importing files from other tools is parked until after 1.0.
- Times lose their fraction of a second. A restored lot's times equal the file's, not the original instance's to the microsecond.
- The format, the schema and the examples live under `docs/`, which the published image leaves out. The suite checks the schema with `json_schemer`, a test-only gem. An import that validates files inside the running app has to decide where its copy of the rules lives.
- The coverage check compares names, not meaning. It catches a table or column that nobody accounted for; it can't tell whether the account given is right.
- A source that retires or replaces an id still leaves a lot that doesn't resolve. The descriptive fields let a person repair it; nothing does so automatically.
```

- [ ] In `docs/adr/README.md`, replace:

```markdown
### Expected

Named by the [roadmap](../roadmap.md) and written with their specs: the export format (item 2), the backup mechanism (item 6), lots in locations (item 10).
```

  with:

```markdown
### Data safety

- [0020](0020-export-format.md): The export format is one versioned JSON document keyed by source ids

### Expected

Named by the [roadmap](../roadmap.md) and written with their specs: the backup mechanism (item 6), lots in locations (item 10).
```

- [ ] In `README.md`, insert this section before `## License`. The link must stay on one line; the spec looks for `(docs/export-format/README.md)`:

```markdown
## Your data

A collector's data has a documented, versioned format: one JSON file that holds their profile,
the currency of their prices and every lot in their collection, keyed by the catalog source's
own ids and never by this instance's. It is defined in
[docs/export-format/README.md](docs/export-format/README.md), with a JSON Schema and example
files beside it. Exporting and importing a collection are built against that format; neither is
in the app yet.

```

- [ ] Run: `bin/rspec spec/export_format_document_spec.rb spec/readme_spec.rb` — expect: PASS, 0 failures (11 examples in the first file)
- [ ] Commit: `docs(adr): record the export format as ADR 0020`

- [ ] In `docs/roadmap.md`, three edits. `<today>` is the date this phase runs, from `date +%F`.
  - Replace item 2's ending "(enabling slice). **Expected ADR:** the export format." with:

```markdown
(enabling slice). **Done <today>:** [the format](export-format/README.md), [ADR 0020](adr/0020-export-format.md) and [spec 017](specs/017-export-format/spec.md), ruled on in decision log 32.
```

  - At the end of item 10's line, after "([ADR 0019](adr/0019-lot-as-the-unit-of-ownership.md) names the question).", add:

```markdown
 It raises the export format to version 2 ([ADR 0020](adr/0020-export-format.md)).
```

  - At the end of the file, after the last row of the decision log (31), add. If a sibling branch has merged a row 32 first, take the next free number and change "decision log 32" in item 2 to match:

```markdown

### 2026-10-11: export format (spec 017)

| # | Question | Ruling |
|---|---|---|
| 32 | What is the export format? | One JSON document per account, keyed by the catalog source's ids, holding the profile, one currency and the lots. Its version is a whole number that rises when an older reader would misread a file or lose the collector's data from it, so locations will make version 2. The rulings are decisions 1 to 20 of [spec 017](specs/017-export-format/spec.md), recorded in [ADR 0020](adr/0020-export-format.md). |
```

- [ ] In `CLAUDE.md`, two edits.
  - In "Project Status", replace "and see, retry and discard background jobs at `/admin/jobs` (spec 015). License: AGPL-3.0." with:

```markdown
and see, retry and discard background jobs at `/admin/jobs` (spec 015). The export format for a collector's data is defined in `docs/export-format/` (spec 017, ADR 0020); export and import aren't built yet. License: AGPL-3.0.
```

  - In "Non-obvious Facts", add this bullet before the "**Off-limits for reads**" bullet:

```markdown
- **Export format (spec 017, ADR 0020):** `docs/export-format/README.md` defines it, with `v1.schema.json` and `examples/` beside it. Nothing in the app reads or writes it yet. `spec/export_format_examples_spec.rb` and `spec/export_format_document_spec.rb` check the document, the schema, the examples and the application against each other, using `spec/support/export_format_rules.rb` (`json_schemer`, test group, `require: false`). A new table with `account_id` or `user_id`, or a new column on `accounts`, `lots` or `users`, fails the suite until the document's Coverage tables list it. A new field that holds collector-owned data raises `format_version` and needs a new `v<N>.schema.json`; the meaning of a released version never changes.
```

- [ ] Commit: `docs(planning): mark the export format defined`

---

## Phase 4: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run: `bin/rubocop` — expect: `no offenses detected`
- [ ] Run: `bin/rspec` — expect: 0 failures, with 27 examples more than `main` has
- [ ] Run: `bin/ci` — expect: every step green
- [ ] Run: `git status --short` — expect: clean. In particular, the generator isn't in the repository.
- [ ] Read the format document against the seven criteria the spec marks (review), and write `docs/specs/017-export-format/verification.md`. Fill the "Found" column with what the document says, quoted; a row that can't be filled is a defect to fix before the commit:

```markdown
# Verification: Export Format

**Spec:** [spec.md](spec.md) | **Plan:** [plan.md](plan.md)

## Automated

| Check | Command | Result |
|---|---|---|
| The format's examples and rules (AC-1.3, AC-1.4, AC-2.1, AC-2.2, AC-2.3, AC-2.5) | `bin/rspec spec/export_format_examples_spec.rb` | |
| The document against the schema, examples and application (AC-1.1, AC-3.4, AC-3.5, AC-4.1 to AC-4.4) | `bin/rspec spec/export_format_document_spec.rb` | |
| The whole suite | `bin/rspec` | |
| Local CI | `bin/ci` | |

## By reading

| Criterion | Where in `docs/export-format/README.md` | Found |
|---|---|---|
| AC-1.2: each field's meaning, whether it may be `null`, its values; price paid is per copy | The field tables under "The file", "Profile", "Lots" and "Entry"; "Not recorded"; "Price paid" | |
| AC-1.5: the opening says the file holds the name and email address, and everything needed to rebuild the collection | The opening list ("It is personal", "It is complete") | |
| AC-2.4: lot identity; `null` is a value of its own; descriptive fields never part of it | "Lot identity" | |
| AC-2.6: the same collection, well-formed and resolvable; well-formed never depends on a catalog | "The same collection"; "Well-formed and resolvable" | |
| AC-3.1: what raises the version, what doesn't, what a reader does with an unknown version and an unknown field | "Versions" | |
| AC-3.2: the steps a spec takes to extend the format | "Extending the format" | |
| AC-3.3: version 1 with its date; locations and shared collections expected | "Versions": the history table and the paragraph after it | |

## Not checked here

- Whether export writes this format and import reads it: #38, #39 and #40.
- The guard compares names. It can't tell whether a column's mapping is right.
```

- [ ] Commit: `docs(017): record the verification`

After this phase: `sdd-superpowers:sdd-review` (Mode B, read-only Fable) checks the implementation against the spec, including the seven (review) criteria, and then `sdd-superpowers:session-wrap` and the draft PR follow, as this project does for every spec. The PR closes #37.

---

## Quickstart Validation

```sh
bin/rspec spec/export_format_examples_spec.rb spec/export_format_document_spec.rb   # 27 examples, 0 failures
bin/rubocop                                                                          # no offenses detected
ls docs/export-format                                                                # README.md  examples  v1.schema.json
find docs/export-format/examples -type f | wc -l                                     # 32
grep -n "Format version" docs/export-format/README.md                                # **Format version:** 1
grep -n "0020" docs/adr/README.md                                                    # the index line
```

To see a guard fail: delete the `` | `sessions` | `` row from the document's Coverage table and run the document spec. Four examples fail, and RSpec names `["sessions"]` as the missing element. Restore the row with `git checkout docs/export-format/README.md`.
