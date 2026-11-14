# Implementation Plan: CI Fails on a Dependency Whose Licence Isn't Allowed (spec 091, issue #402)

**Spec:** `docs/specs/091-licence-check-in-ci/spec.md` (Approved v0.5.0) · **ADR:** [0031](../../adr/0031-a-dependency-licence-is-a-decision.md) (Proposed) · **Issue:** #402 · **Branch:** `091-licence-check-in-ci` · **Created:** 2026-11-13
**Status:** Approved (Gate B, 2026-11-13, the coordinator under the maintainer's delegation, no second plan round). Written by my main session; plan review round 1 (Fable, read-only): APPROVE WITH CHANGES (0 blocking, 3 major, 8 minor), all fixed in this version.

## Context

A `bin/ci checks` step, `bin/rails licences:check`, judges every component of the list spec 087's reader builds (`Collector::ThirdPartyLicences.build`: the gems of the bundle and the manifest's JavaScript, OCR engine, font and icon entries) against `config/licence_policy.yml`, which holds the allowed SPDX ids and the named exceptions (ADR 0031). It also reports spec 087's guard (`Audit`), so a pin with no manifest entry fails the checks job too. Two new classes under `lib/collector/third_party_licences/` (`Policy`, `Check`), one rake task, one policy file, one `config/ci.rb` step. No second reader of the bundle: the one extra input is the lockfile's gem names.

Facts the tasks rely on, read from the files on `main` at `71212946`:

- `ThirdPartyLicences::Component` is `Data.define(:name, :version, :identifiers, :home, :copyright, :texts, :note)`; `Section` is `Data.define(:key, :title, :components)`, with `key` one of `:javascript, :ocr, :fonts, :icons, :gems` (`ThirdPartyLicences::TITLES`, page order). `ThirdPartyLicences.load_manifest(path)` is `YAML.safe_load_file(path) || {}` and is public; `Audit.new` takes nine keyword inputs and `Audit#problems` returns sentences, and returns early with "has no javascript entry" for a pin with no entry, before it reads the served file.
- `config/ci.rb`'s `unless selection.group == :rspec` block ends with `step "Security: Importmap vulnerability audit", "bin/importmap audit"`; `spec/config/ci_definition_spec.rb` already places the YARD and ratchet steps by line index. `.claude/settings.json` allows `bin/ci` and `bin/ci *` but no `bin/rails licences:check`, so a session runs the task only through `bin/ci checks` or in-process in a spec (nothing here edits that file).
- Rake task specs live in `spec/tasks/` with `type: :task` and `Rails.application.load_tasks` (`spec/tasks/catalog_rake_spec.rb`); `start.rake` is the model for `warn` plus `exit 1`.
- Measured before: `bin/ci checks` took **35.5 s** total (`46.48s user 6.65s system`) on the author's machine on 2026-11-13 at `71212946`, run with `time bin/ci checks` (the ratchet step, YARD, RuboCop, Brakeman and both audits included). T2.4 measures the same way after.

## Global Constraints

- **Repo rules:** `CLAUDE.md`, `.claude/rules/*.md`. Spec files under `lib/` are tagged `type: :model`; task specs `type: :task`; `RSpec/ExampleLength` max 15; `RSpec/MultipleMemoizedHelpers` max 5 (use `def`); multi-expectation examples use `:aggregate_failures`. Prose documents are verified by reading and recorded in `verification.md`, never from RSpec (`.claude/rules/testing.md`).
- **Core names no collectible.** `spec/licences_core_spec.rb` (T4.1) reads whole files, comments included, for `/mtg|magic|wizards|scryfall|fan content/i`: none of those words in the new class files, the rake task or the policy file.
- **One commit per task, test first** (red, implement, green, RuboCop), Conventional Commits with `(#402)`. The trailer is the attribution reminder in force at commit time; a Sonnet implementer's commits name Sonnet 5.5. One git operation per shell call; `git add` and `git commit` separate (the pre-commit hook reads the command text). Every `git grep` ends with `':!.kamal/secrets'`. Never read `.kamal/secrets`, `config/master.key`, `.env*`, `storage/` or any `*.sqlite3`.
- **No agent runs the `sqlite3` command, `bin/rails console`, `bundle add`/`update`, `bin/importmap pin`, or anything else on the ask list, and none runs `bin/rails licences:check` as a Bash command** (it isn't allowed in `.claude/settings.json` and would prompt): run the task in-process in its spec, and the real tree through `bin/ci checks`. Never touch `Dockerfile`, `.github/workflows/**`, `config/deploy*.yml` or `.claude/settings.json`. `config/ci.rb` is a plain edit.
- **Comments:** every public class, module and method gets a summary (the comment ratchet in `bin/ci checks`), with `@param`/`@return` on reusable code, and `@see file:catalog-core.md` and `@see file:0031-a-dependency-licence-is-a-decision.md`. No `{…}` outside YARD links (write paths in backticks).
- **No migration, no export, import or backup change** (the export format stays 4); no gem, no JavaScript; `spec/support/runtime_log.txt` is not refreshed; the existing `Audit`'s rules and `spec/third_party_licences_manifest_spec.rb` are not changed.
- **Run `bin/yard doc` only through `bin/ci checks`** (a plain `bin/yard` isn't on the allow list); an implementer who adds a class runs `bin/ci checks` once at the end of its batch, not per task.
- **Shared test database:** one test run at a time in this worktree; a targeted `bin/rspec <file>` needs no CI slot, a full `bin/ci` and a push do (the coordinator's).

## Goal

A pull request that adds a gem, or a pinned JavaScript package, font or icon set, under a licence the maintainer hasn't allowed fails `bin/ci checks`, with a message naming the dependency, its licence and the policy file; the allowed licences and each exception are recorded in the repository.

## Pre-implementation gates

- **Simplicity (≤3 components): pass.** (1) `Policy` (the rules) with `config/licence_policy.yml`; (2) `Check` (the join with spec 087's guard) and the rake task; (3) the `config/ci.rb` step.
- **Anti-abstraction: pass.** `Data` values and `YAML.safe_load_file` through `ThirdPartyLicences.load_manifest`; `Bundler::LockfileParser` called directly; `Check` exists only because the issue's outcome needs the guard and the policy in one step, and it is eight lines.
- **Integration-first: pass.** The rules take injected sections (Phase 1) before the real file (T2.1), the class that joins them (T2.2) and the task (T2.3) before the step (T2.4).

## Files

| File | Change | Responsibility |
|---|---|---|
| `lib/collector/third_party_licences/policy.rb` | create | the rules over injected sections, policy data and lockfile names; `for_repository`, `locked_names` |
| `lib/collector/third_party_licences/check.rb` | create | joins an injected audit's problems and the policy's |
| `lib/tasks/licences.rake` | create | `licences:check[policy]`: prints, exits 1 on a problem |
| `config/licence_policy.yml` | create | the seven allowed ids, the exceptions (T2.1; `vcr` in T3.1) |
| `config/ci.rb` | edit | the step (T2.4) |
| `spec/lib/collector/third_party_licences/policy_spec.rb`, `check_spec.rb` | create | the rules by injection |
| `spec/tasks/licences_rake_spec.rb` | create | the task in-process |
| `spec/config/ci_definition_spec.rb`, `spec/licences_core_spec.rb` | edit | the step's place; the core files |
| `docs/architecture/catalog-core.md`, `release-and-deploy.md`, `CLAUDE.md`, `.claude/rules/testing.md`, `.claude/rules/conventions.md`, `docs/roadmap.md`, `docs/specs/README.md`, `docs/adr/README.md` | edit | Story 5 |
| `docs/specs/091-licence-check-in-ci/verification.md` | create | evidence, timings, the review |

## Phase 1: The rules

**Implements** FR-2 (the class); **satisfies** AC-1.1 to AC-1.6, AC-2.1 to AC-2.3, AC-3.1 to AC-3.3, AC-3.5, AC-3.6. One implementer takes T1.1 to T1.3 (three commits).

### T1.1 Policy: shape and judging (AC-1.1 to AC-1.6, AC-2.1, AC-2.2, AC-3.3 shape)

Test first, `spec/lib/collector/third_party_licences/policy_spec.rb`; it fails with `uninitialized constant ...::Policy`.

```ruby
require "rails_helper"
require "tmpdir"

# Spec 091 decisions 1, 2, 5 and 6 and Stories 1 and 2: the rules over injected sections and policy data, so each fails on a
# small fixture and passes on the baseline. The real tree is judged by the bin/ci checks step (AC-4.2).
RSpec.describe Collector::ThirdPartyLicences::Policy, type: :model do
  let(:path) { "config/licence_policy.yml" }

  def component(name, *identifiers, version: "1.0", texts: [])
    Collector::ThirdPartyLicences::Component.new(name:, version:, identifiers:, home: nil, copyright: nil, texts:, note: nil)
  end

  def section(key, *components, title: key.to_s.capitalize)
    Collector::ThirdPartyLicences::Section.new(key:, title:, components:)
  end

  def data(allowed: %w[MIT BSD-2-Clause Ruby], exceptions: [])
    { "allowed" => allowed.map { { "id" => it, "reason" => "a reason" } }, "exceptions" => exceptions }
  end

  def problems_for(*sections, data: data(), locked: [])
    described_class.new(data:, path:, sections:, locked_names: locked).problems
  end

  it "passes a bundle of allowed licences, a dual among them (AC-1.5)" do
    sections = [ section(:gems, component("rake", "MIT"), component("erb", "BSD-2-Clause", "Ruby")) ]

    expect(problems_for(*sections)).to be_empty
  end

  it "fails a gem under a licence off the list, naming the gem, its version, the licence and the policy file (AC-1.1)", :aggregate_failures do
    problems = problems_for(section(:gems, component("viral", "GPL-3.0-only", version: "2.1.0")))

    expect(problems.size).to eq(1)
    expect(problems.first).to include("gem viral 2.1.0", "GPL-3.0-only", path)
  end

  it "passes a gem with any one allowed licence and fails one with none, listing every one (AC-1.2)", :aggregate_failures do
    expect(problems_for(section(:gems, component("dual", "GPL-2.0-only", "MIT")))).to be_empty
    expect(problems_for(section(:gems, component("copyleft", "GPL-2.0-only", "Artistic-1.0-Perl"))).first)
      .to include("GPL-2.0-only", "Artistic-1.0-Perl")
  end

  it "fails a gem that declares no licence, and one whose string is not an exact allowed id (AC-1.3, AC-1.4)", :aggregate_failures do
    expect(problems_for(section(:gems, component("bare"))).first).to include("gem bare 1.0", "no licence")
    expect(problems_for(section(:gems, component("filed", texts: [ [ "LICENSE", "text" ] ]))).first).to include("gem filed 1.0", "no licence")
    %w[MIT\ License Apache\ 2.0 MIT\ OR\ Apache-2.0].each do |string|
      expect(problems_for(section(:gems, component("odd", string))).first).to include(string)
    end
  end

  it "reports every offender once, in the order the sections list them, each naming the file (AC-1.6)", :aggregate_failures do
    problems = problems_for(section(:javascript, component("alpha", "GPL-3.0-only")),
      section(:gems, component("charlie", "AGPL-3.0-only"), component("bravo", "LGPL-3.0-only")))

    expect(problems.size).to eq(3)
    expect(problems).to all(include(path))
    expect(problems.map { it[/alpha|bravo|charlie/] }).to eq(%w[alpha charlie bravo])
  end

  it "judges a manifest entry of every section by its identifiers, with decision 2's rule (AC-2.1, AC-2.2)", :aggregate_failures do
    %i[javascript ocr fonts icons].each do |key|
      problems = problems_for(section(key, component("pkg", "GPL-3.0-only"), title: "Kind"))

      expect(problems.first).to include("Kind", "\"pkg\"", "GPL-3.0-only", path)
    end
    expect(problems_for(section(:fonts, component("two", "OFL-1.1", "MIT")))).to be_empty
    expect(problems_for(section(:icons, component("none"))).first).to include("no licence")
  end

  describe "the policy's own shape (AC-3.3)" do
    def shape_problems(value) = problems_for(section(:gems), data: value)

    it "names an allowed entry without an id or a reason, a duplicate id, and a data that is not a mapping", :aggregate_failures do
      expect(shape_problems({ "allowed" => [ { "id" => "MIT" } ] }).first).to include(path, "allowed entry 1")
      expect(shape_problems({ "allowed" => [ { "reason" => "r" } ] }).first).to include("allowed entry 1")
      expect(shape_problems({ "allowed" => [ { "id" => "MIT", "reason" => "r" }, { "id" => "MIT", "reason" => "r" } ] }).first).to include("MIT", "twice")
      expect(shape_problems([ "MIT" ]).first).to include(path, "mapping")
    end

    it "names an exception missing its gem, licences or reason, and a duplicate gem", :aggregate_failures do
      bad = { "gem" => "x", "licences" => [], "reason" => "r" }
      ok = { "gem" => "y", "licences" => [ "GPL-3.0-only" ], "reason" => "r" }

      expect(shape_problems(data(exceptions: [ bad ])).first).to include("exception entry 1", "(x)")
      expect(shape_problems(data(exceptions: [ ok.except("reason") ])).first).to include("exception entry 1")
      expect(shape_problems(data(exceptions: [ ok, ok ])).first).to include("gem y", "twice")
    end

    it "judges nothing while the policy is malformed (it would report every gem)" do
      expect(problems_for(section(:gems, component("viral", "GPL-3.0-only")), data: { "allowed" => "MIT" }).size).to eq(1)
    end
  end
end
```

Implementation, `lib/collector/third_party_licences/policy.rb` (T1.1 builds everything but the exceptions, which T1.2 adds; the class below is the final shape of T1.1):

```ruby
module Collector
  class ThirdPartyLicences
    # Judges the components of {ThirdPartyLicences.build}'s sections against the allowed list and the named exceptions in
    # `config/licence_policy.yml` (spec 091), as a list of problems each naming its offender, the licence and the file.
    #
    # Every input is injected, so a spec shows each rule failing on a small fixture; `for_repository` (T1.3) builds the real ones
    # and the `licences:check` task prints the problems. A component passes if any one of its identifiers is allowed (spec 091
    # decision 2); one with none, or with a string that is not exactly an allowed id, fails (decision 5). Nothing here reads
    # a gem or a licence file: the one reader is {ThirdPartyLicences} (no second reader of the bundle).
    #
    # @see file:catalog-core.md
    # @see file:0031-a-dependency-licence-is-a-decision.md
    class Policy
      # The policy file, relative to `Rails.root`.
      PATH = "config/licence_policy.yml".freeze

      # The decision the failure message points at.
      DECISION = "ADR 0031".freeze

      # A named exception, as the rules use it: the `gem`, its `licences` (sorted, a set) and whether its list is `all_required`.
      # Its `reason` is for the reader of the file; no rule reads it.
      Exemption = Data.define(:gem, :licences, :all_required)

      # @param data [Hash{String=>Array<Hash>}, Object] the loaded policy: `allowed` (each `id`, `reason`) and `exceptions`
      #   (each `gem`, `licences`, `reason`, optional `all_required`); anything but a mapping is a problem, not a crash
      # @param path [String] the policy's path, as the messages print it
      # @param sections [Array<ThirdPartyLicences::Section>] what {ThirdPartyLicences.build} returns
      # @param locked_names [Array<String>] the gem names the lockfile holds, once each
      def initialize(data:, path:, sections:, locked_names:)
        @data = data
        @path = path.to_s
        @sections = sections
        @locked_names = locked_names
      end

      # How many components the sections hold, which is what a passing run reports it judged.
      #
      # @return [Integer]
      def component_count = components.size

      # What is off the policy, one sentence per offender, each naming it, its licence and the policy file.
      #
      # Pure of side effects. While the policy's own shape is wrong it reports only that, because judging against a
      # malformed list would blame every gem.
      #
      # @return [Array<String>] empty when everything agrees; the policy's shape problems alone when it is malformed
      def problems
        shape = shape_problems
        return shape if shape.any?

        judge_problems + exemption_problems
      end

      private

      def components = @sections.flat_map { |section| section.components.map { |component| [ section, component ] } }

      def raw_allowed = Array(@data["allowed"])

      def raw_exceptions = Array(@data["exceptions"])

      def allowed_ids = @allowed_ids ||= raw_allowed.filter_map { it["id"] if it.is_a?(Hash) }

      def filled?(value) = value.is_a?(String) && !value.strip.empty?

      def shape_problems
        return [ "#{@path} isn't a mapping with `allowed` and `exceptions`" ] unless @data.is_a?(Hash)

        allowed_shape + exception_shape
      end

      def allowed_shape
        bad = raw_allowed.each_with_index.reject { |entry, _| entry.is_a?(Hash) && filled?(entry["id"]) && filled?(entry["reason"]) }
          .map { |_, index| "#{@path}: allowed entry #{index + 1} needs an `id` and a `reason`" }
        bad + repeated(allowed_ids).map { "#{@path}: allowed id #{it} is listed twice" }
      end

      def exception_shape
        bad = raw_exceptions.each_with_index.reject { |entry, _| well_formed_exception?(entry) }
          .map { |entry, index| "#{@path}: exception entry #{index + 1} (#{entry.is_a?(Hash) ? entry["gem"] : "not a mapping"}) needs a `gem`, `licences` (a list) and a `reason`" }
        bad + repeated(raw_exceptions.filter_map { it["gem"] if it.is_a?(Hash) }).map { "#{@path}: the exception for gem #{it} is listed twice" }
      end

      def well_formed_exception?(entry)
        entry.is_a?(Hash) && filled?(entry["gem"]) && filled?(entry["reason"]) &&
          entry["licences"].is_a?(Array) && entry["licences"].any? && entry["licences"].all? { filled?(it) }
      end

      def repeated(values) = values.tally.select { |_, count| count > 1 }.keys

      def judge_problems
        components.flat_map { |section, component| judge(section, component) }
      end

      # The sentence(s) for one component: none when it passes.
      def judge(section, component)
        ids = component.identifiers.uniq.sort
        return [ "#{label(section, component)} declares no licence; #{@path} can judge only a declared SPDX id (#{DECISION})" ] if ids.empty?

        allowed?(ids, strict: false) ? [] : [ disallowed(section, component, ids) ]
      end

      def allowed?(ids, strict:)
        strict ? ids.all? { allowed_ids.include?(it) } : ids.any? { allowed_ids.include?(it) }
      end

      def label(section, component)
        section.key == :gems ? "gem #{component.name} #{component.version}" : "#{section.title} entry #{component.name.inspect} (#{component.version})"
      end

      def disallowed(section, component, ids)
        way_out = section.key == :gems ? "allow the licence there, or list the gem under `exceptions` with its reason" : "allow the licence there, or drop the dependency"
        "#{label(section, component)} is under #{ids.join(", ")}, none of which is on the allowed list in #{@path}: #{way_out} (#{DECISION})"
      end

      # T1.2 fills this in; until then there is none.
      def exemption_problems = []
    end
  end
end
```

Verify green (`bin/rspec spec/lib/collector/third_party_licences/policy_spec.rb`), `bin/rubocop -a`. Commit `feat(licences): the policy's rules over injected sections (#402)`.

### T1.2 Exceptions, staleness and `all_required` (AC-3.1, AC-3.2, AC-3.5 first clause, AC-3.6, AC-2.3)

Add to `policy_spec.rb` (red first; the AC-2.3 and AC-3.5 examples already pass on T1.1's code, so they are pins, not red):

```ruby
  describe "exceptions (decision 3)" do
    let(:viral) { component("viral", "GPL-3.0-only") }
    let(:exception) { { "gem" => "viral", "licences" => [ "GPL-3.0-only" ], "reason" => "a tool, never loaded" } }

    def judged(exceptions, *components, locked: %w[viral], allowed: %w[MIT])
      problems_for(section(:gems, *components), data: data(allowed:, exceptions:), locked:)
    end

    it "lets a gem through that an exception names with exactly its licences, in any order (AC-3.1)", :aggregate_failures do
      expect(judged([ exception ], viral)).to be_empty
      two = { "gem" => "two", "licences" => %w[B A], "reason" => "r" }
      expect(judged([ two ], component("two", "A", "B"), locked: %w[two])).to be_empty
    end

    it "calls an exception stale when the lockfile no longer names the gem, the gem's licences changed, or it is allowed without it (AC-3.2)", :aggregate_failures do
      expect(judged([ exception ], locked: [])).to contain_exactly(a_string_including("viral", "lockfile"))
      changed = judged([ exception ], component("viral", "AGPL-3.0-only"))
      expect(changed).to include(a_string_including("viral", "AGPL-3.0-only", "GPL-3.0-only", "stale"))
      expect(changed.size).to eq(2) # the stale exception and the disallowed licence
      expect(judged([ exception ], viral, allowed: %w[MIT GPL-3.0-only])).to contain_exactly(a_string_including("viral", "allowed without it"))
    end

    it "judges nothing of a gem the lockfile names and the bundle doesn't hold, and calls no exception for it stale (AC-3.5)" do
      expect(judged([ exception ], locked: %w[viral])).to be_empty
    end

    it "applies to gems only: a manifest entry of the same name is judged by the list (AC-2.3)" do
      problems = problems_for(section(:javascript, viral, title: "JavaScript"), data: data(exceptions: [ exception ]), locked: %w[viral])

      expect(problems).to include(a_string_including("JavaScript entry", "GPL-3.0-only"))
    end

    describe "`all_required`" do
      let(:vcr) { component("vcr", "Hippocratic-2.1", "MIT") }
      let(:strict) { { "gem" => "vcr", "licences" => %w[Hippocratic-2.1 MIT], "all_required" => true, "reason" => "its MIT is not trusted" } }

      it "passes a dual gem as its allowed id with no exception, and by name with the exception (AC-3.6)", :aggregate_failures do
        expect(judged([], vcr, locked: %w[vcr])).to be_empty
        expect(judged([ strict ], vcr, locked: %w[vcr])).to be_empty
      end

      it "fails a gem whose exception's licences no longer match, because every licence must then be allowed (AC-3.6)", :aggregate_failures do
        problems = judged([ strict ], component("vcr", "Hippocratic-2.1", "MIT", "BSD-2-Clause"), locked: %w[vcr], allowed: %w[MIT BSD-2-Clause])

        expect(problems).to include(a_string_including("vcr", "Hippocratic-2.1", "every licence"))
        expect(problems).to include(a_string_including("stale"))
      end

      it "calls the exception stale once every licence is allowed (AC-3.6)" do
        expect(judged([ strict ], vcr, locked: %w[vcr], allowed: %w[MIT Hippocratic-2.1])).to contain_exactly(a_string_including("vcr", "stale", "allowed without it"))
      end
    end
  end
```

Implementation: replace the T1.1 stand-ins.

```ruby

      def exemptions
        @exemptions ||= raw_exceptions.map do |entry|
          Exemption.new(gem: entry["gem"], licences: entry["licences"].uniq.sort, all_required: entry["all_required"] == true)
        end
      end

      def exemption_for(section, component)
        exemptions.find { it.gem == component.name } if section.key == :gems
      end
```

`judge` becomes:

```ruby
      def judge(section, component)
        ids = component.identifiers.uniq.sort
        return [ "#{label(section, component)} declares no licence; #{@path} can judge only a declared SPDX id (#{DECISION})" ] if ids.empty?

        exemption = exemption_for(section, component)
        return [] if exemption && ids == exemption.licences

        allowed?(ids, strict: exemption&.all_required) ? [] : [ disallowed(section, component, ids, strict: exemption&.all_required) ]
      end
```

`disallowed` takes `strict:` and reads `"#{label} is under #{ids.join(", ")}, which includes #{(ids - allowed_ids).join(", ")}, off the allowed list in #{@path} (every licence of this gem must be allowed): #{way_out} (#{DECISION})"` when strict, else the T1.1 text. `exemption_problems`:

```ruby
      def exemption_problems
        gems = @sections.find { it.key == :gems }&.components.to_a
        exemptions.flat_map do |exemption|
          component = gems.find { it.name == exemption.gem }
          if !@locked_names.include?(exemption.gem)
            [ "#{@path}: the exception for gem #{exemption.gem} is stale: the lockfile no longer names it (#{DECISION})" ]
          elsif component.nil?
            [] # in the lockfile and not installed (a run with a group left out): neither judged nor stale
          else
            stale_problem(exemption, component.identifiers.uniq.sort)
          end
        end
      end

      def stale_problem(exemption, ids)
        if ids != exemption.licences
          [ "#{@path}: the exception for gem #{exemption.gem} is stale: it declares #{ids.join(", ")} now and the exception covers #{exemption.licences.join(", ")}; review it (#{DECISION})" ]
        elsif allowed?(ids, strict: exemption.all_required)
          [ "#{@path}: the exception for gem #{exemption.gem} is stale: the gem is allowed without it (#{DECISION})" ]
        else
          []
        end
      end
```

Green, RuboCop, commit `feat(licences): named exceptions that go stale, and the all_required form (#402)`.

### T1.3 Reading the real inputs (AC-3.3 unreadable file, AC-3.5 second clause)

Red first, in `policy_spec.rb`:

```ruby
  describe ".for_repository" do
    it "reads the lockfile's gem names once each, with no `bundler` (AC-3.5)", :aggregate_failures do
      names = described_class.locked_names

      expect(names).to include("rails", "sqlite3")
      expect(names).to eq(names.uniq)
      expect(names).not_to include("bundler")
    end

    it "raises for a policy file it can't read, and reports a file that isn't a mapping (AC-3.3)", :aggregate_failures do
      Dir.mktmpdir("licence-policy") do |dir|
        list = File.join(dir, "list.yml")
        File.write(list, "- MIT\n")

        expect { described_class.for_repository(policy_path: File.join(dir, "absent.yml"), sections: []) }.to raise_error(SystemCallError)
        expect(described_class.for_repository(policy_path: list, sections: []).problems.first).to include(list.delete_prefix("#{Rails.root}/"), "mapping")
      end
    end
  end
```
The class comment's `for_repository` in backticks becomes the YARD link `{.for_repository}` in this task, once the method exists. Implement:

```ruby
      class << self
        # The policy of this repository: the file at `policy_path`, the sections of the running bundle and manifest, and the
        # lockfile's gem names.
        #
        # Reads the policy and, unless `sections` is given, every licence file {ThirdPartyLicences.build} reads (about 400 KB).
        #
        # @param policy_path [String, Pathname] the policy file; default `config/licence_policy.yml`
        # @param sections [Array<ThirdPartyLicences::Section>] the components to judge; default the real ones
        # @return [Policy]
        # @raise [SystemCallError] when the policy file can't be read
        # @raise [Psych::Exception] when it isn't valid YAML or holds more than plain data
        def for_repository(policy_path: Rails.root.join(PATH), sections: ThirdPartyLicences.build.sections)
          new(data: ThirdPartyLicences.load_manifest(policy_path), path: display_path(policy_path), sections:, locked_names:)
        end

        # The gem names the lockfile holds, once each.
        #
        # A gem the lockfile names for several platforms repeats there (`ffi`, `sqlite3`); `bundler` is in the bundle and
        # not in the lockfile, so it is never among them.
        #
        # @return [Array<String>]
        def locked_names
          Bundler::LockfileParser.new(Bundler.default_lockfile.read).specs.map(&:name).uniq
        end

        private

        # The path as a message prints it: relative to the application when it is inside it.
        def display_path(path) = path.to_s.delete_prefix("#{Rails.root}/")
      end
```
Commit `feat(licences): the policy reads the real file, sections and lockfile names (#402)`.

**Phase 1 verification:** `bin/rspec spec/lib/collector/third_party_licences/policy_spec.rb` green (about 20 examples); `bin/rubocop` clean.

## Phase 2: The real policy, the join, the task and the step

**Implements** FR-1, FR-2 (`for_repository`), FR-3, FR-4; **satisfies** AC-3.4 (first two exceptions), AC-4.1 to AC-4.5. One implementer takes T2.1 and T2.2, another T2.3 and T2.4 (or one takes all four, four commits).

### T2.1 `config/licence_policy.yml`

No code test (AC-3.4 is verified by reading; T2.3's run proves it judges). The file, with the header and the reasons copied exactly (no collectible is named):

```yaml
# The licences Collector's dependencies may be under, and the dependencies that are let through by name (spec 091, ADR 0031).
# `bin/ci checks` fails a gem, a pinned JavaScript package, an OCR package, a font or an icon set under a licence that is not
# in `allowed` and has no entry in `exceptions`. Adding to either list is a decision for the maintainer: say why in `reason`,
# and put the change in a pull request of its own or beside the dependency it is for.
#
# A component with several licences passes if any one is allowed. A licence is compared exactly as an SPDX id: "MIT License"
# or an expression in one string fails. An exception names a gem, the licences it was reviewed under (a set) and a reason; it
# goes stale, and fails the check, when the lockfile no longer names the gem, the gem declares other licences, or the gem is
# allowed without it. `all_required: true` marks a gem whose list of licences is not a choice, so every one must be allowed. Why
# it exists: a gem such as vcr declares Hippocratic-2.1 and MIT, and the rule "any one allowed" would pass it on MIT, so an
# ordinary exception for it would read as stale (the gem is allowed without it). With `all_required` the gem fails without the
# exception, the exception is what lets it through, and it goes stale only when every one of the gem's licences is allowed.
# Copy this form only for a gem whose declared alternatives you do not trust; an ordinary exception is for a gem that fails.

allowed:
  - { id: MIT, reason: "Permissive, notice only: the copyright line and licence text travel with the copies, which the third-party licences page carries (spec 087)" }
  - { id: BSD-2-Clause, reason: "Permissive, notice only; carried by the third-party licences page" }
  - { id: BSD-3-Clause, reason: "Permissive, notice only, and a clause against using the authors' names to endorse; carried by the third-party licences page" }
  - { id: Apache-2.0, reason: "Permissive, with a patent grant and a notice file that travels with the copies; carried by the third-party licences page" }
  - { id: ISC, reason: "Permissive, notice only; the icons' licence" }
  - { id: Ruby, reason: "Ruby's own licence, declared by the default gems, usually beside BSD-2-Clause" }
  - { id: OFL-1.1, reason: "The licence of the self-hosted typefaces: the licence text travels with the font files, which are unmodified copies of their packages" }

exceptions:
  - gem: bundler-audit
    licences: [GPL-3.0-or-later]
    reason: "A command-line audit run by bin/ci; the application never loads it, and it leaves the image when #408 lands"
  - gem: brakeman
    licences: [Brakeman Public Use License]
    reason: "A static analyser run by bin/ci and the commit hook; the application never loads it, and it leaves the image when #408 lands"
```

Commit `feat(licences): the allowed licences and the first two exceptions (#402)`.

### T2.2 `Check` (AC-4.4)

`spec/lib/collector/third_party_licences/check_spec.rb`, red first:

```ruby
require "rails_helper"
require "tmpdir"

# Spec 091 decision 7, AC-4.4: Check joins an injected audit's problems and the policy's, the guard's first.
RSpec.describe Collector::ThirdPartyLicences::Check, type: :model do
  def policy_reporting(*problems) = instance_double(Collector::ThirdPartyLicences::Policy, problems:, component_count: 3)

  def audit_reporting(*problems) = instance_double(Collector::ThirdPartyLicences::Audit, problems:)

  it "lists the audit's problems first and the policy's second, and counts the components the policy judged", :aggregate_failures do
    check = described_class.new(audit: audit_reporting("pin has no entry"), policy: policy_reporting("gem x is under GPL"))

    expect(check.problems).to eq([ "pin has no entry", "gem x is under GPL" ])
    expect(check.component_count).to eq(3)
  end

  it "carries the guard's sentence for an importmap pin with no manifest entry (decision 7)" do
    pin = Collector::ThirdPartyLicences::Audit::Pin.new(name: "lodash", asset: "/x/vendor/javascript/lodash.js")
    audit = Collector::ThirdPartyLicences::Audit.new(manifest: {}, text_dir: Dir.tmpdir, specs: [], ocr_digests: [], pins: [ pin ],
      pin_directories: [], app_javascript: "/x/app/javascript", font_files: {}, icon_files: [])

    expect(described_class.new(audit:, policy: policy_reporting).problems).to eq([ "importmap pin lodash has no javascript entry" ])
  end
end
```

Implementation, `lib/collector/third_party_licences/check.rb`:

```ruby
module Collector
  class ThirdPartyLicences
    # Everything the `licences:check` step reports: spec 087's guard (the manifest, the pins and the bundle agree) and the
    # policy (every component is under an allowed licence), in one list, so a pull request that adds an importmap pin with
    # no entry fails `bin/ci checks` as well as the suite (spec 091 decision 7).
    #
    # @see file:catalog-core.md
    class Check
      # The check of this repository: the real guard and the real policy.
      #
      # Reads the manifest, every licence file and the lockfile; needs the application booted (the importmap).
      #
      # @param policy_path [String, Pathname] the policy file; default `config/licence_policy.yml`
      # @return [Check]
      # @raise [SystemCallError] when the policy or the manifest can't be read
      # @raise [Psych::Exception] when either isn't plain YAML
      def self.for_repository(policy_path: Rails.root.join(Policy::PATH))
        new(audit: Audit.for_repository, policy: Policy.for_repository(policy_path:))
      end

      # @param audit [#problems] spec 087's guard, or a stand-in
      # @param policy [#problems, #component_count] the policy, or a stand-in
      def initialize(audit:, policy:)
        @audit = audit
        @policy = policy
      end

      # The guard's problems, then the policy's.
      #
      # @return [Array<String>] empty when both agree
      def problems = @audit.problems + @policy.problems

      # How many components the policy judged.
      #
      # @return [Integer]
      def component_count = @policy.component_count
    end
  end
end
```

Commit `feat(licences): Check joins the guard's problems and the policy's (#402)`.

### T2.3 `licences:check` (AC-4.2, AC-4.3)

`spec/tasks/licences_rake_spec.rb`, red first (`Don't know how to build task 'licences:check'`):

```ruby
require "rails_helper"
require "rake"
require "tmpdir"

# Spec 091 FR-3, AC-4.2 and AC-4.3. The step judges the repository's own policy in `bin/ci checks` (evidence in verification.md);
# here the task runs in-process, so a licence change in the bundle can't take a shard down: the passing run uses a policy that
# allows every licence the list declares, the failing one a policy that allows nothing.
RSpec.describe "licences rake task", type: :task do # rubocop:disable RSpec/DescribeClass -- rake tasks have no class
  before { Rails.application.load_tasks unless Rake::Task.task_defined?("licences:check") }

  after { Rake::Task["licences:check"].reenable }

  # Runs the task with its output captured and `exit` rescued (RSpec doesn't rescue SystemExit, so an unrescued exit would end
  # the whole process), as [standard output, standard error, exit status].
  def run_check(*args)
    out = StringIO.new
    err = StringIO.new
    original = [ $stdout, $stderr ]
    $stdout, $stderr = out, err
    status = begin
      Rake::Task["licences:check"].invoke(*args)
      0
    rescue SystemExit => error
      error.status
    end
    [ out.string, err.string, status ]
  ensure
    $stdout, $stderr = original
  end

  def with_policy(yaml)
    Dir.mktmpdir("licence-policy") do |dir|
      file = File.join(dir, "policy.yml")
      File.write(file, yaml)
      yield file
    end
  end

  def allow_everything_yaml
    ids = Collector::ThirdPartyLicences.build.sections.flat_map(&:components).flat_map(&:identifiers).uniq
    { "allowed" => ids.map { { "id" => it, "reason" => "a fixture" } }, "exceptions" => [] }.to_yaml
  end

  it "exits 0 and prints how many components it judged on standard output (AC-4.2)", :aggregate_failures do
    with_policy(allow_everything_yaml) do |file|
      out, err, status = run_check(file)

      expect(status).to eq(0)
      expect(out).to match(/Licences: \d+ components judged/)
      expect(err).to be_empty
    end
  end

  it "exits 1 against a policy that allows nothing, printing each dependency, its licence and the file on standard error (AC-4.3)", :aggregate_failures do
    with_policy("allowed: []\nexceptions: []\n") do |file|
      _out, err, status = run_check(file)

      expect(status).to eq(1)
      expect(err).to include("gem rake", "MIT", file)
      expect(err.lines.size).to be > 100
    end
  end

  it "exits 1 naming the file when it can't be read", :aggregate_failures do
    _out, err, status = run_check("/nonexistent/policy.yml")

    expect(status).to eq(1)
    expect(err).to include("/nonexistent/policy.yml")
  end
end
```
The first example doesn't judge the repository's own policy, which `bin/ci checks` does (AC-4.2's evidence is that run, recorded in `verification.md`).

Implementation, `lib/tasks/licences.rake`:

```ruby
# The licence check of spec 091: `bin/ci checks` runs it. It judges every gem of the bundle and every entry of the
# third-party manifest against config/licence_policy.yml, and reports spec 087's guard, so it needs the application.
namespace :licences do
  desc "Fail when a dependency is under a licence config/licence_policy.yml doesn't allow (spec 091); optional policy path"
  task :check, [ :policy ] => :environment do |_task, args|
    policy_path = Rails.root.join(args[:policy].presence || Collector::ThirdPartyLicences::Policy::PATH)
    begin
      check = Collector::ThirdPartyLicences::Check.for_repository(policy_path:)
      problems = check.problems
    rescue SystemCallError, Psych::Exception => error
      warn "Licences: can't read #{policy_path} or the licence manifest: #{error.message}"
      exit 1
    end

    if problems.any?
      warn "Licences: #{problems.size} problem#{"s" unless problems.one?}:", *problems.map { "  - #{it}" }
      exit 1
    end
    puts "Licences: #{check.component_count} components judged; each is under an allowed licence or a named exception."
  end
end
```
Commit `feat(licences): the licences:check task (#402)`.

### T2.4 The `config/ci.rb` step (AC-4.1) and the timing

Red first: add to `spec/config/ci_definition_spec.rb`:

```ruby
  it "runs the licence check in bin/ci checks, directly after the importmap audit and not with the RSpec group (spec 091 AC-4.1)", :aggregate_failures do
    lines = Rails.root.join("config/ci.rb").readlines(chomp: true).map(&:strip)
    audit = lines.index('step "Security: Importmap vulnerability audit", "bin/importmap audit"')
    licences = lines.index('step "Licences: dependencies are under allowed licences", "bin/rails licences:check"')
    guarded = lines.index("unless selection.group == :rspec")

    expect(licences).not_to be_nil
    expect(licences).to eq(audit + 1)
    expect(licences).to be < lines.each_index.find { |i| i > guarded && lines[i] == "end" }
  end
```
Then in `config/ci.rb`, after the importmap audit line, add `    step "Licences: dependencies are under allowed licences", "bin/rails licences:check"`. Green. Run `bin/ci checks` twice and `time` it as the baseline was (`time bin/ci checks`), recording both totals and the step's own line ("passed in N s") for `verification.md`; the first run after the edit includes a cold Bootsnap cache, so record the second. Not a full `bin/ci` and no slot. Commit `feat(ci): the licence check is a step of bin/ci checks (#402)`.

**Phase 2 verification:** `bin/rspec spec/lib/collector/third_party_licences spec/tasks/licences_rake_spec.rb spec/config/ci_definition_spec.rb` green; `bin/ci checks` green with the step's line `Licences: ... components judged`.

## Phase 3: `vcr` (ruled by the maintainer, 2026-11-13: a named exception)

**Satisfies** AC-3.4's third entry and AC-3.6 on the real tree. One task of its own, because the coordinator asked for the entry to be separable; the `all_required` rule is in T1.2's commit and stays whatever happens to the entry. Spec 0.5.1 and ADR 0031 already record the ruling.

### T3.1 The `vcr` exception (spec decisions 2 and 3, AC-3.4, AC-3.6)

Add to `exceptions:` in `config/licence_policy.yml`:

```yaml
  - gem: vcr
    licences: [Hippocratic-2.1, MIT]
    all_required: true
    reason: "A test recorder the application never loads. It declares Hippocratic-2.1 and MIT, ships no licence file, and issue #408 calls it Hippocratic-2.1, so its declared MIT is not trusted. all_required is why this is an exception at all: without it the gem would pass on its MIT and this entry would read as stale. It goes stale only when every licence it declares is allowed"
```
Evidence (no new spec: AC-3.4 is read-and-record): `bin/ci checks` stays green with the entry (the step judges `vcr` by name); with the entry removed, `spec/lib/.../policy_spec.rb`'s `all_required` examples already prove the form, and a local run would then pass `vcr` as `MIT`. Commit `feat(licences): vcr is let through by name, its declared MIT not trusted (#402)`.

## Phase 4: Documents, the core spec and the evidence

**Satisfies** AC-5.1 to AC-5.4. T4.1 is with an implementer; T4.2 and T4.3 are mine (prose, verified by reading).

### T4.1 The core names no collectible (AC-5.1)

Edit `spec/licences_core_spec.rb`'s file list: add `lib/collector/third_party_licences/policy.rb`, `lib/collector/third_party_licences/check.rb`, `lib/tasks/licences.rake` and `config/licence_policy.yml` to `files`, and bump the first example's `expect(files.size).to be > 6` to `> 10`. The new files exist by then, so the edited example passes at once; the task is added coverage, not a red-first change, and its commit body says so. Commit `test(licences): the core spec covers the policy files (#402)`.

### T4.2 Area docs, CLAUDE.md and rules (AC-5.2, AC-5.3), by reading

- `docs/architecture/catalog-core.md`: in "The third-party licences page", a paragraph "**What it may be under**" with the policy file, decisions 2 to 6 of the spec in the doc's style, the step and the task, each with its source inline (spec 091 decision n, AC-n.n; ADR 0031); Named constants: `Policy::PATH`, `Policy::DECISION`; Sources: spec 091, ADR 0031, issue #402; Distillation log row (written by `distill-feature`).
- `docs/architecture/release-and-deploy.md`: the step among the `bin/ci checks` steps (the "`bin/ci` takes one optional group" bullet's order, and the Scope line that lists the checks steps), with its source.
- `CLAUDE.md`: Commands: the Local CI step list names "the licence check" after the importmap audit, and `bin/rails licences:check` is noted as run only through `bin/ci checks` in a session; Project Status: one sentence naming `config/licence_policy.yml`, `Policy`, `Check` and spec 091 / ADR 0031.
- `.claude/rules/testing.md`: the `bin/ci` bullet lists the licence check among what it runs; `.claude/rules/conventions.md`: a ✗ bullet "Don't add a dependency under a licence that isn't in `config/licence_policy.yml` to get CI green: allowing one is the maintainer's decision, with a reason (ADR 0031)".
- `docs/adr/README.md`: 0031's line already carries "(Proposed)"; the distillation step changes it when the PR merges.

### T4.3 Index, roadmap, verification (AC-5.4)

- `docs/specs/README.md`: row 091 status and areas filled by `distill-feature`; `docs/roadmap.md`: the #402 row "Done when its pull request merges".
- `docs/specs/091-licence-check-in-ci/verification.md`: the AC table with evidence (spec runs, the `bin/ci checks` run with the step's line, the before and after times (35.5 s before), the model split, the review rounds), and `## Implementation review` with the verdict first (sdd-review Mode B, Opus 5.5, read-only).

## Spec coverage

| Spec | Task |
|---|---|
| FR-1 | T2.1, T3.1 |
| FR-2 | T1.1 to T1.3, T2.2 |
| FR-3 | T2.2, T2.3 |
| FR-4 | T2.4 |
| AC-1.1 to AC-1.6 | T1.1 |
| AC-2.1, AC-2.2 | T1.1 |
| AC-2.3 | T1.2 |
| AC-2.4, AC-4.2 | T2.3 (in-process), T2.4 (`bin/ci checks` run recorded) |
| AC-3.1, AC-3.2, AC-3.6 | T1.2 |
| AC-3.3 | T1.1 (shape), T1.3 (unreadable), T2.3 (the task) |
| AC-3.4 | T2.1, T3.1 (by reading) |
| AC-3.5 | T1.2 (first clause), T1.3 (second) |
| AC-4.1 | T2.4 |
| AC-4.3 | T2.3 |
| AC-4.4 | T2.2 |
| AC-4.5 | no workflow file in the diff (checked in `verification.md`) |
| AC-5.1 | T4.1 |
| AC-5.2, AC-5.3, AC-5.4 | T4.2, T4.3 |

## Verification and finish

1. `bin/rspec` on the new files after each batch; `bin/ci checks` after T2.4 and after the docs (timings recorded; the step's line in the output is the AC-4.2 evidence).
2. Implementation review (`sdd-review` Mode B, Opus 5.5, read-only) recorded in `verification.md`.
3. `session-wrap`, then `distill-feature` with its digest sent to the coordinator before it is committed.
4. One full `bin/ci` under a coordinator slot, then the push, a draft PR that closes #402, CI green, `gh pr ready`, assignee.

## Owed to the maintainer

- T4.2 edits two files under `.claude/rules/`; if the harness prompts for them, the maintainer answers (nothing here edits `.claude/settings.json`).
- A session can't run `bin/rails licences:check` without a prompt, because `.claude/settings.json` lists no such command; add `Bash(bin/rails licences:check*)` if wanted (the task still runs through `bin/ci checks`).
