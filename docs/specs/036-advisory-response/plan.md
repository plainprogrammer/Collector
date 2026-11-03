# Implementation Plan: Advisory Response for Locked Dependencies

**Spec:** docs/specs/036-advisory-response/spec.md (version 1.0.0, Approved)
**Decisions:** none beyond the spec's Decisions 1–9 (no ADR: nothing here is architecture)
**Created:** 2026-11-03

## Global Constraints

- The audit gate stays: `config/ci.rb`'s two audit steps and the `checks` job are unchanged (Non-Goals).
- `.github/dependabot.yml`: leave every other key of both entries as it is; do not group the `github-actions` entry; do not depend on the repository's "Grouped security updates" setting (FR-1).
- The workflow audits the commit the run is on, uses advisory data fetched during the run, runs both audits in every run, is startable by hand, runs at a minute other than 0, and never runs on pushes or pull requests (FR-2).
- The workflow's token is `contents: read`, it uses no secret and writes nothing; every `uses:` line is pinned to a full commit SHA with its version in a trailing comment, and every action is one `ci.yml` already uses at the same SHA (AC-2.4, NFR Security).
- The importmap step is kept, and nothing claims it checks anything while no pin carries a version (FR-2 Must not, Decision 2).
- Initial schedule: daily at 05:17 UTC (Decision 8).
- Do not restate the rules in CLAUDE.md, do not check a prose document from RSpec, and do not edit a shipped spec (FR-3 Must not; `.claude/rules/documentation.md`, `.claude/rules/testing.md`).
- Commit types are those of `docs/git-convention.md` (`feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `ci`); one commit per phase, with the phase named in the body.
- **Do not push between Phase 0 and the end of Phase 4.** The pre-push hook runs the full `bin/ci`, which fails on the red examples of Phases 0–1.

---

## Goal

A new advisory against a locked gem turns a daily run red, the Ruby gems' Dependabot security updates arrive as one pull request, and the response to a red audit is written down, with the file criteria covered by RSpec and the GitHub-side criteria listed for the maintainer.

---

## Phase 0: Contracts and Tests First

**Implements:** FR-1, FR-2 | **Satisfies:** AC-1.1, AC-1.2, AC-2.1, AC-2.2, AC-2.3, AC-2.4, AC-2.5, AC-2.9, AC-2.11
**Files:** `spec/advisory_response_spec.rb` (new), `.rubocop.yml`
**Interfaces:** Consumes: nothing. Produces: the examples `.github/dependabot.yml` (2) and `.github/workflows/advisory-audit.yml` (6), which Phases 1 and 2 turn green, and the workflow's contract: file `.github/workflows/advisory-audit.yml`, job `audit`, setup steps with ids `checkout` and `ruby`, the audits as the two steps whose `run` starts with `bin/bundler-audit` and `bin/importmap`.

The file-shape contract of both files, written before either exists, in the style of `spec/image_publishing_spec.rb`.

- [ ] Put this plan in the repository, so that `verification.md` can link it: copy it to `docs/specs/036-advisory-response/plan.md`, change the Plan column of spec 036's row in `docs/specs/README.md`, and commit `docs(specs): add the implementation plan of spec 036`. This commit is documentation only, so it may be pushed at once (the pre-push hook then runs only `bin/ci checks`).

  Old: `a scheduled audit workflow) | none | | |`
  New: `a scheduled audit workflow) | present | | |`
- [ ] Exclude the new spec from RuboCop's `RSpec/DescribeClass` (it checks repository files, not a class). In `.rubocop.yml`, change the comment and the list.

  Old:
  ```yaml
  # publishing spec checks the publishing files, and the admin catalog core and
  ```
  New:
  ```yaml
  # publishing spec checks the publishing files, the advisory response spec the
  # Dependabot configuration and the audit workflow, and the admin catalog core and
  ```
  Old:
  ```yaml
      - "spec/admin_catalog_core_spec.rb"
      - "spec/collection_export_core_spec.rb"
  ```
  New:
  ```yaml
      - "spec/admin_catalog_core_spec.rb"
      - "spec/advisory_response_spec.rb"
      - "spec/collection_export_core_spec.rb"
  ```
- [ ] Write the failing examples, `spec/advisory_response_spec.rb`:
  ```ruby
  require "rails_helper"
  require "yaml"

  # File-shape checks for the advisory response (spec 036): Dependabot's security-update group and the daily audit
  # workflow. The criteria that need GitHub (AC-1.3, AC-1.4, AC-2.6 to AC-2.8, AC-2.10) are evidenced in
  # docs/specs/036-advisory-response/verification.md; the document criteria (Story 3) are verified by reading.
  RSpec.describe "Advisory response files" do
    describe ".github/dependabot.yml" do
      let(:config) { YAML.load_file(Rails.root.join(".github/dependabot.yml")) }

      def update_for(ecosystem) = config["updates"].find { |entry| entry["package-ecosystem"] == ecosystem }

      it "groups the Ruby gems' security updates into one pull request (AC-1.1, FR-1)" do
        expect(update_for("bundler")["groups"].values)
          .to include("applies-to" => "security-updates", "patterns" => [ "*" ])
      end

      it "leaves the schedule, the limit and the github-actions entry as they were (AC-1.2, FR-1)", :aggregate_failures do
        weekly = { "directory" => "/", "schedule" => { "interval" => "weekly" }, "open-pull-requests-limit" => 10 }

        expect(update_for("bundler").except("groups")).to eq(weekly.merge("package-ecosystem" => "bundler"))
        expect(update_for("github-actions")).to eq(weekly.merge("package-ecosystem" => "github-actions"))
      end
    end

    describe ".github/workflows/advisory-audit.yml" do
      let(:path) { Rails.root.join(".github/workflows/advisory-audit.yml") }
      let(:workflow) { YAML.load_file(path) }

      def triggers = workflow[true] || workflow["on"] # Psych reads the YAML key `on` as true
      def job = workflow.dig("jobs", "audit")
      def steps = job["steps"]
      def audits = steps.select { |candidate| candidate["run"].to_s.start_with?("bin/bundler-audit", "bin/importmap") }
      def pinned_uses(file) = file.read.scan(%r{uses: (\S+@\h{40}) # v\d}).flatten
      def ci_pins = pinned_uses(Rails.root.join(".github/workflows/ci.yml"))

      it "runs once a day and by hand, never on pushes or pull requests (AC-2.1, FR-2)", :aggregate_failures do
        expect(triggers.keys).to contain_exactly("schedule", "workflow_dispatch")
        expect(triggers["schedule"].size).to eq(1)

        minute, hour, *rest = triggers["schedule"].first["cron"].split
        expect(Integer(minute)).to be_between(1, 59) # a minute other than 0
        expect(Integer(hour)).to be_between(0, 23)
        expect(rest).to eq(%w[* * *])
      end

      it "runs both audits as separate steps that cannot hide a failure (AC-2.2, FR-2)", :aggregate_failures do
        commands = audits.map { |candidate| candidate["run"] }

        expect(commands.size).to eq(2)
        expect(commands.first).to start_with("bin/bundler-audit")
        expect(commands.last).to eq("bin/importmap audit")
        expect(commands).to all(match(%r{\Abin/[\w-]+( [\w-]+)*\z})) # no `||`, `;` or `&&` to hide an exit status
        expect(steps.flat_map(&:keys)).not_to include("continue-on-error")
      end

      it "runs the second audit after the first fails, and neither after a failed setup (AC-2.3, AC-2.9, FR-2)", :aggregate_failures do
        first, second = audits
        setup = steps.select { |candidate| candidate["id"] }

        expect(setup.map { |candidate| candidate["id"] }).to eq(%w[checkout ruby])
        expect(setup.last.dig("with", "bundler-cache")).to be(true) # the gem installation is part of the setup
        expect(first).not_to have_key("if") # the default, success(), runs it only after every earlier step succeeded
        expect(second["if"]).to include("!cancelled()", "steps.checkout.outcome == 'success'", "steps.ruby.outcome == 'success'")
      end

      it "asks for read-only access and uses only actions pinned as ci.yml pins them (AC-2.4, FR-2, NFR Security)", :aggregate_failures do
        expect(workflow["permissions"]).to eq("contents" => "read")
        expect(job.fetch("permissions", { "contents" => "read" })).to eq("contents" => "read")
        expect(path.read.scan(/\buses:/).size).to eq(pinned_uses(path).size) # every `uses:` line is a SHA with a version comment
        expect(pinned_uses(path)).to all(satisfy { |action| ci_pins.include?(action) })
      end

      it "stops a hung run within 10 minutes (AC-2.5, FR-2)" do
        expect(job["timeout-minutes"]).to be_between(1, 10)
      end

      it "keeps no copy of the Ruby advisory database between runs (AC-2.11, FR-2)" do
        names_database = steps.any? { |candidate| candidate.to_s.include?("ruby-advisory-db") }

        expect(audits.first["run"].include?("--update") || !names_database).to be(true)
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/advisory_response_spec.rb` — expect FAIL: `8 examples, 7 failures` (AC-1.1 with `NoMethodError` on `nil.values`; the six workflow examples with `Errno::ENOENT` for `advisory-audit.yml`). AC-1.2 passes today: it guards the keys that must stay as they are, and a mutation in Phase 4 proves it fails when they change.
- [ ] Run: `bin/rubocop spec/advisory_response_spec.rb` — expect `1 file inspected, no offenses detected` (loading the config validates `.rubocop.yml`; naming it as a file would make RuboCop parse it as Ruby).
- [ ] Commit (local only, do not push): `test(ci): add file-shape examples for the advisory response`, body `Spec 036, plan Phase 0: seven failing examples and one guard for dependabot.yml and the audit workflow.`

---

## Phase 1: Dependabot's security updates as one group

**Implements:** FR-1 | **Satisfies:** AC-1.1, AC-1.2
**Files:** `.github/dependabot.yml`
**Interfaces:** Consumes: the two `.github/dependabot.yml` examples of Phase 0. Produces: a `groups.security` entry (`applies-to: security-updates`, `patterns: ["*"]`) in the `bundler` entry, nothing else changed.

- [ ] Run: `bin/rspec spec/advisory_response_spec.rb -e ".github/dependabot.yml"` — expect FAIL: `2 examples, 1 failure` (AC-1.1 fails; AC-1.2 passes because the other keys are as they were, which is what it guards).
- [ ] Implement, `.github/dependabot.yml` in full:
  ```yaml
  version: 2
  updates:
  - package-ecosystem: bundler
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
    # Security updates for the Ruby gems arrive as one pull request, so advisories that land together are fixed
    # together (spec 036 FR-1).
    groups:
      security:
        applies-to: security-updates
        patterns:
          - "*"
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
  ```
- [ ] Run: `bin/rspec spec/advisory_response_spec.rb -e ".github/dependabot.yml"` — expect PASS: `2 examples, 0 failures`.
- [ ] Commit: `ci(deps): group Dependabot's security updates for the Ruby gems`, body `Spec 036, plan Phase 1 (FR-1, AC-1.1, AC-1.2).`

---

## Phase 2: The daily audit workflow

**Implements:** FR-2 | **Satisfies:** AC-2.1, AC-2.2, AC-2.3, AC-2.4, AC-2.5, AC-2.9, AC-2.11
**Files:** `.github/workflows/advisory-audit.yml` (new)
**Interfaces:** Consumes: the six workflow examples of Phase 0 (path, job `audit`, step ids `checkout` and `ruby`). Produces: the workflow whose cron is line 8 and `timeout-minutes` line 17, which Phase 3's Named constants rows cite.

- [ ] Run: `bin/rspec spec/advisory_response_spec.rb -e ".github/workflows/advisory-audit.yml"` — expect FAIL: `6 examples, 6 failures` (`Errno::ENOENT`).
- [ ] Implement, `.github/workflows/advisory-audit.yml` (keep the line numbers: the cron on line 8, `timeout-minutes` on line 17):
  ```yaml
  name: Advisory audit

  # Runs the two security audits of bin/ci (config/ci.rb) on main once a day, so an advisory published against a
  # locked dependency turns a run red within a day, not when a pull request happens to start one (spec 036,
  # docs/architecture/release-and-deploy.md). A run started by hand audits the ref it was started on.
  on:
    schedule:
      - cron: "17 5 * * *" # 05:17 UTC; off the hour, because GitHub delays scheduled runs at the start of every hour
    workflow_dispatch:

  permissions:
    contents: read

  jobs:
    audit:
      runs-on: ubuntu-latest
      timeout-minutes: 10
      steps:
        - name: Checkout code
          id: checkout
          uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

        - name: Set up Ruby
          id: ruby
          uses: ruby/setup-ruby@de492cf36cbab201753d720ce4f4e336cd688c94 # v1.336.0
          with:
            bundler-cache: true

        # --update fetches the Ruby advisory database on every run, whatever a runner kept (AC-2.11).
        - name: Gem audit
          run: bin/bundler-audit check --update

        # Runs whichever way the gem audit ended, but only after a good setup (AC-2.3, AC-2.9). While no pin in
        # config/importmap.rb carries a version it checks nothing (spec 036 FR-2).
        - name: Importmap vulnerability audit
          if: ${{ !cancelled() && steps.checkout.outcome == 'success' && steps.ruby.outcome == 'success' }}
          run: bin/importmap audit
  ```
- [ ] Run: `bin/rspec spec/advisory_response_spec.rb` — expect PASS: `8 examples, 0 failures`.
- [ ] Run: `grep -n -E "cron:|timeout-minutes:" .github/workflows/advisory-audit.yml` — expect `8:    - cron: "17 5 * * *" …` and `17:    timeout-minutes: 10`. If a line moved, Phase 3's rows cite the lines found.
- [ ] Rehearse the two commands in a bare checkout, as the runner will have them (no `bin/setup`, no database, no `config/master.key`, no `storage/`):
  ```bash
  git clone -q /home/user/Collector /tmp/claude-0/-home-user-Collector/b9a4e6ca-87c1-5f2c-877f-b413d6facec5/scratchpad/rehearsal
  cd /tmp/claude-0/-home-user-Collector/b9a4e6ca-87c1-5f2c-877f-b413d6facec5/scratchpad/rehearsal
  bin/bundler-audit check --update
  bin/importmap audit
  ```
  Expect `No vulnerabilities found` and `No vulnerable packages found`, both exit 0 (`--update` pulls the advisory database kept at `~/.local/share/ruby-advisory-db`, which is harmless). If the environment declines this run, say so in `verification.md`: the first run on GitHub (Quickstart step 1) is then the proof, and a failure there is a red daily run, not damage. If either command fails in the clone, stop and record the failure: the fix (a setup step, with an example for it) is a plan revision, asked for before it is made.
- [ ] Commit: `ci(audit): add a daily run of the dependency audits`, body `Spec 036, plan Phase 2 (FR-2, AC-2.1 to AC-2.5, AC-2.9, AC-2.11).`

> **Pre-Implementation Gates:** all passed, so there is no complexity note. Simplicity: one config entry, one workflow file and one spec file (three components), no new dependency. Anti-Abstraction: the workflow calls the repository's own `bin/` commands and `ci.yml`'s pinned actions. Integration-First: the file-shape examples exist before either file (Phase 0).

---

## Phase 3: The area doc states the rules and the response

**Implements:** FR-3 | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4
**Files:** `docs/architecture/release-and-deploy.md`
**Interfaces:** Consumes: the workflow's line numbers from Phase 2 (8 and 17). Produces: the Scope mention, the updated sentence on where the configuration files are checked, four bullets replacing the Dependabot bullet, two Named constants rows, and the Sources entries for spec 036 and issue #164. The README and CLAUDE.md are not edited: the README's sentence stays true (AC-3.4) and CLAUDE.md is not to restate area rules (FR-3 Must not).

Documents are verified by reading (`.claude/rules/testing.md`), so this phase has no test step; the verification is the read-back in Phase 4.

- [ ] In the Scope bullet (line 10), replace:

  Old: ``Dependabot's configuration (`.github/dependabot.yml`), and the release tags``
  New: ``Dependabot's configuration (`.github/dependabot.yml`), the daily audit workflow `.github/workflows/advisory-audit.yml` (spec 036), and the release tags``
- [ ] Replace the Dependabot bullet (line 62) with these four bullets:

  Old (the whole line):
  ```markdown
  - **Dependabot covers gems and GitHub Actions**, not the base image (spec 001 AC-2.6, FR-4; spec 012 Non-Goals; `.github/dependabot.yml`).
  ```
  New:
  ```markdown
  - **Dependabot covers gems and GitHub Actions**, not the base image (spec 001 AC-2.6, FR-4; spec 012 Non-Goals; `.github/dependabot.yml`). Its version updates cover the dependencies a manifest names, so a gem that only another gem needs is never offered one, and a new release also waits out Dependabot's default 3-day cooldown and the weekly run (spec 036 Problem Statement; Dependabot's `allow` and `cooldown` documentation). On 2026-11-03 that left addressable, loofah, nokogiri and rails-html-sanitizer without a pull request while their advisories failed `bin/bundler-audit` on every pull request.
  - **The Ruby gems' security updates are one group.** `groups.security` in the `bundler` entry (`applies-to: security-updates`, `patterns: ["*"]`) makes advisories that land together arrive as one pull request, because a fix per gem can't pass `bin/bundler-audit` while the other advisories stand (spec 036 FR-1, AC-1.1, AC-1.2; Dependabot's `groups` documentation; #164). The repository's own "Grouped security updates" setting combines with it and isn't relied on. Why Dependabot's security updates opened nothing for the five gems of 2026-11-03 is not known; the maintainer owns that question (spec 036 Open Questions, Decision 4).
  - **A daily workflow audits `main`.** `.github/workflows/advisory-audit.yml` runs `bin/bundler-audit check --update` and `bin/importmap audit`, the two security audits of `config/ci.rb` (the gem audit spelled `check --update`, so that it fetches the advisory database on every run), once a day and by hand, with `contents: read` and a 10-minute timeout. The second audit runs after the first fails but not after a failed setup, so one run lists both and a broken setup never reads as a pass (spec 036 FR-2, AC-2.1 to AC-2.5, AC-2.9, AC-2.11). So an advisory published against a locked gem turns a run red within a day, without a pull request or a push. `config/importmap.rb` pins no versioned package, so the importmap audit checks nothing today and no response to it is defined until one does (spec 036 AC-3.3). The notice is the failed run and GitHub's own notification, which goes to whoever created the workflow, last changed its cron or re-enabled it (GitHub's documentation), so the maintainer changes the cron in a commit of their own after the merge (spec 036 Decision 7, AC-2.10). The repository is public, so GitHub disables the schedule after 60 days without repository activity; the next pull request's `checks` still gate (spec 036 Error Scenarios).
  - **A red audit is fixed by one pull request:** run `bin/bundler-audit`, update every flagged gem in one change with `bundle update --conservative <gems>`, run `bin/ci checks` and the suite, and open one pull request (spec 036 AC-3.2; the fix of 2026-11-03 was #162).
  ```
- [ ] Update the sentence that says where the configuration files are checked (line 120), which this change makes partly untrue:

  Old: ``The configuration files (`compose.yaml`, `config/deploy.yml`, the workflows, `.dockerignore`) are checked, in `spec/image_publishing_spec.rb` (spec 020 decisions 3 and 7, AC-4.2, AC-4.7; `.claude/rules/testing.md`).``
  New: ``The configuration files (`compose.yaml`, `config/deploy.yml`, the workflows, `.dockerignore`) are checked, in `spec/image_publishing_spec.rb`, and Dependabot's configuration and the audit workflow in `spec/advisory_response_spec.rb` (spec 020 decisions 3 and 7, AC-4.2, AC-4.7; spec 036 Testability; `.claude/rules/testing.md`).``
- [ ] Add two rows to the Named constants table, after the `Cleanup schedule` row:

  Old:
  ```markdown
  | Cleanup schedule | Sundays 06:00 UTC | `.github/workflows/ghcr-cleanup.yml:8` | Weekly, deleting | spec 013 FR-4, AC-1.5 |
  ```
  New:
  ```markdown
  | Cleanup schedule | Sundays 06:00 UTC | `.github/workflows/ghcr-cleanup.yml:8` | Weekly, deleting | spec 013 FR-4, AC-1.5 |
  | Advisory audit schedule | daily at 05:17 UTC (`17 5 * * *`) | `.github/workflows/advisory-audit.yml:8` | Once a day, at a minute off the hour because GitHub delays scheduled runs at the start of every hour; the maintainer's own commit after the merge moves the minute, so GitHub notifies them | spec 036 FR-2, AC-2.1, AC-2.10, Decision 8 |
  | Advisory audit timeout | `timeout-minutes: 10` | `.github/workflows/advisory-audit.yml:17` | The audits take seconds after setup; a hung run fails instead of spending runner time | spec 036 AC-2.5, NFR Performance |
  ```
- [ ] Add the spec to Sources, after the Spec 035 bullet (line 259):

  Insert after the line that starts ``- [Spec 035](../specs/035-ci-shards/spec.md)``:
  ```markdown
  - [Spec 036](../specs/036-advisory-response/spec.md): all (the grouped security updates, the daily audit workflow and the response to a red audit; the criteria that need GitHub are evidenced in its `verification.md`).
  ```
- [ ] Add the issue to Sources' issues bullet (line 262):

  Old: ``[#109](https://github.com/plainprogrammer/Collector/issues/109) and [#132](https://github.com/plainprogrammer/Collector/issues/132) (actions pinned to SHAs); open:``
  New: ``[#109](https://github.com/plainprogrammer/Collector/issues/109), [#132](https://github.com/plainprogrammer/Collector/issues/132) (actions pinned to SHAs) and [#164](https://github.com/plainprogrammer/Collector/issues/164) (the advisory response, spec 036); open:``
- [ ] Read the README's sentence (``Dependabot keeps gems and GitHub Actions up to date.``, `README.md:137`) against the new bullets — it stays true, so the README is not edited (AC-3.4).
- [ ] Commit: `docs(architecture): record the advisory response in release and deploy`, body `Spec 036, plan Phase 3 (FR-3, AC-3.1 to AC-3.4).`

---

## Phase 4: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs that can be met before the merge (AC-1.1, AC-1.2, AC-2.1 to AC-2.5, AC-2.9, AC-2.11, AC-3.1 to AC-3.4); the others are Quickstart Validation's

Coverage of the spec's criteria:

| Criterion | Where |
|---|---|
| AC-1.1, AC-1.2 | Phase 0 examples, Phase 1 |
| AC-2.1 to AC-2.5, AC-2.9, AC-2.11 | Phase 0 examples, Phase 2 |
| AC-3.1 to AC-3.4 | Phase 3, read back below |
| AC-1.3, AC-1.4, AC-2.6, AC-2.7, AC-2.8, AC-2.10 | Quickstart Validation (needs GitHub, after the merge) |

- [ ] Prove each guard fails when its file is wrong (a guard is proved by mutation). For each row, apply the change, run the named example, expect FAIL, then restore with `git checkout -- <file>`:

  | Mutation | Command | Example that must fail |
  |---|---|---|
  | add a `push:` trigger | `sed -i 's/^  workflow_dispatch:/  push:\n  workflow_dispatch:/' .github/workflows/advisory-audit.yml` | AC-2.1 |
  | cron minute 0 | `sed -i 's/"17 5 \* \* \*"/"0 5 * * *"/' .github/workflows/advisory-audit.yml` | AC-2.1 |
  | `continue-on-error` on the gem audit | `sed -i 's/^        run: bin\/bundler-audit check --update/&\n        continue-on-error: true/' .github/workflows/advisory-audit.yml` | AC-2.2 |
  | drop `!cancelled()` | `sed -i 's/!cancelled() && //' .github/workflows/advisory-audit.yml` | AC-2.3, AC-2.9 |
  | write permission | `sed -i 's/contents: read/contents: write/' .github/workflows/advisory-audit.yml` | AC-2.4 |
  | an unpinned action | `sed -i 's/@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1/@v7/' .github/workflows/advisory-audit.yml` | AC-2.4 |
  | timeout 30 | `sed -i 's/timeout-minutes: 10/timeout-minutes: 30/' .github/workflows/advisory-audit.yml` | AC-2.5 |
  | no `--update`, and a step that names the database | `sed -i 's/^        run: bin\/bundler-audit check --update/        env:\n          CACHE: ruby-advisory-db\n        run: bin\/bundler-audit/' .github/workflows/advisory-audit.yml` | AC-2.11 (AC-2.11 passes when either branch holds, so the mutation must break both) |
  | drop the security group | `sed -i '/^  groups:/,/^        - "\*"/d' .github/dependabot.yml` | AC-1.1 |
  | change the weekly interval | `sed -i '0,/interval: weekly/s//interval: daily/' .github/dependabot.yml` | AC-1.2 |

  After each: `bin/rspec spec/advisory_response_spec.rb` — expect `8 examples, 1 failure`, the failing example being the one named in the row's last column; then restore with `git checkout -- .github/workflows/advisory-audit.yml .github/dependabot.yml`. Finish with `git status --short` — expect no output.
- [ ] Run the whole suite and the checks: `bin/ci` — expect `Continuous Integration passed`, with the new examples among the RSpec run's passes. (The area doc and the new spec file change no application code.)
- [ ] Read the area doc back against Story 3: AC-3.1 (version updates direct-only, the group, the daily workflow, the Scope mention, the Named constants rows, each statement with its source), AC-3.2 (the response), AC-3.3 (the importmap statement), AC-3.4 (the README sentence). Record each as read; for AC-3.4 record that the README sentence is judged true at its level of detail (version updates cover direct gems, security updates the rest) and that the maintainer may prefer it to say so.
- [ ] Write `docs/specs/036-advisory-response/verification.md`:
  ```markdown
  # Spec 036: Verification

  **Spec:** [spec.md](spec.md) (1.0.0) | **Plan:** [plan.md](plan.md)

  ## Before the merge

  | Criterion | Evidence | Result |
  |---|---|---|
  | AC-1.1, AC-1.2 | `spec/advisory_response_spec.rb`, the `.github/dependabot.yml` examples; mutation rows 9 and 10 fail them | the run's `N examples, 0 failures` line |
  | AC-2.1 to AC-2.5, AC-2.9, AC-2.11 | the `.github/workflows/advisory-audit.yml` examples; mutation rows 1 to 8 fail them | the run's `N examples, 0 failures` line |
  | AC-3.1 to AC-3.4 | read against `docs/architecture/release-and-deploy.md` and `README.md:137` | what was read, per criterion |
  | The two audits in a bare checkout | the rehearsal of Phase 2 | its two output lines and exit codes, or "declined by the environment" |
  | `bin/ci` | the full run | its `Continuous Integration passed` line and the RSpec totals |

  ## After the merge (the maintainer's, Quickstart Validation)

  | Criterion | Evidence | Result |
  |---|---|---|
  | AC-2.7 | the hand run on `main` | pending |
  | AC-2.6 | the hand run against the throwaway branch | pending |
  | AC-2.8 | the failed run in the Actions tab and the notification | pending |
  | AC-2.10 | the maintainer's commit moving the cron minute | pending |
  | AC-1.3 | Insights, Dependency graph, Dependabot, the `bundler` job | pending |
  | AC-1.4 | the next batch of security-update pull requests | pending, observed when it happens |
  | Open question (Decision 4) | the Dependabot alerts for the five gems | pending, owned by the maintainer |
  ```
  Fill the Result column of the first table from the real run output; leave the second table as it is.
- [ ] Commit: `docs(specs): record spec 036's verification before the merge`, body `Spec 036, plan Phase 4.`
- [ ] Push the branch (the pre-push hook runs the full `bin/ci`): `git push` — expect the hook's `bin/ci` to pass and the push to update `claude/happy-fermi-y30wzq`.
- [ ] Retitle and re-describe pull request #163 with the GitHub tool `update_pull_request` (`gh` can't write here), so that it names what it now does and closes #164. Title: `ci: advisory response for locked dependencies (spec 036)`. Body:
  ```markdown
  ## Summary

  Spec 036 and its implementation: Dependabot's security updates for the Ruby gems arrive as one group, a new daily workflow audits `main` with the two security audits of `bin/ci`, and the area doc `release-and-deploy.md` records the rules and the response to a red audit.

  Closes #164.

  ## Verification so far

  The evidence lines of the first table of `docs/specs/036-advisory-response/verification.md`: the RSpec totals, the mutation checks, the read-back of the area doc and the `bin/ci` result.

  ## After the merge (the maintainer)

  The seven checks of the plan's Quickstart Validation, in order: the first hand run on `main`, a throwaway branch with a vulnerable lockfile, the failed run's notification, the cron change in a commit of your own, Insights for the `bundler` job, the next batch of security updates, and the Dependabot alerts for the five gems.

  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  https://claude.ai/code/session_01Xrsv3TNnBsw5TawLEvPJZU
  ```
  Leave it a draft until the implementation review (`sdd-review` Mode B) and `distill-feature`.

---

## Quickstart Validation

The maintainer's checks, after the merge, in this order (AC-2.7 before AC-2.6). Run them from a plain terminal: Claude Code's pre-push hook would run `bin/ci` before the push of step 2 and fail on its lockfile. Record each result in the second table of `verification.md` in a commit of its own.

1. **AC-2.7, the first hand run, on `main`.** Do it before the next 05:17 UTC scheduled run, or check that scheduled run as well: both must pass. The helper finds the run a dispatch started, by branch and event, so that the first dispatch never reads an empty list and the second never reads the first's run (step 2 reuses it in the same shell).
   ```bash
   latest() { gh run list --workflow advisory-audit.yml --branch "$1" --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId // empty'; }
   before=$(latest main)
   gh workflow run advisory-audit.yml --ref main
   until id=$(latest main); [ -n "$id" ] && [ "$id" != "$before" ]; do sleep 5; done
   gh run watch "$id" --exit-status
   ```
   Expect the run to pass: both audit steps green.
2. **AC-2.6, a lockfile with advisories, on a throwaway branch cut from `main` after the merge.**
   ```bash
   git fetch origin main && git switch -c throwaway/advisory-check origin/main
   git checkout 922c426 -- Gemfile.lock
   git commit -m "test: lock the vulnerable gems for the advisory audit (do not merge)"
   git push origin throwaway/advisory-check
   before=$(latest throwaway/advisory-check)
   gh workflow run advisory-audit.yml --ref throwaway/advisory-check
   until id=$(latest throwaway/advisory-check); [ -n "$id" ] && [ "$id" != "$before" ]; do sleep 5; done
   gh run watch "$id"
   gh run view "$id" --log-failed
   ```
   (`gh run watch` without `--exit-status` ends normally when the run fails, so the log command still runs.) `922c426` is the `main` of 2026-11-03 before the fix of #162: its lockfile locks addressable 2.9.0, loofah 2.25.2, nokogiri 1.19.4, rails-html-sanitizer 1.7.1 and sqlite3 2.10.1. Expect the run to fail, with the log naming each gem, its locked version, its advisory and its fixed version (for sqlite3: `2.10.1`, `GHSA-4fqr-96q8-xrfx`, `>= 2.10.2`). Then clean up:
   ```bash
   git push origin --delete throwaway/advisory-check
   git switch main && git branch -D throwaway/advisory-check
   ```
3. **AC-2.8.** Open the repository's Actions tab: the run of step 2 is listed as failed; check that GitHub notified you of it, as your notification settings for Actions say.
4. **AC-2.10.** Move the cron minute in a commit of your own and push it to `main` (it has no branch protection). Start from an up-to-date local `main`, because step 2's cleanup leaves it wherever it was, and run the spec before committing:
   ```bash
   git switch main && git pull --ff-only origin main
   sed -i 's/"17 5 \* \* \*"/"19 5 * * *"/; s/05:17 UTC;/05:19 UTC;/' .github/workflows/advisory-audit.yml
   sed -i 's/05:17 UTC (`17 5 \* \* \*`)/05:19 UTC (`19 5 * * *`)/' docs/architecture/release-and-deploy.md
   bin/rspec spec/advisory_response_spec.rb
   git add .github/workflows/advisory-audit.yml docs/architecture/release-and-deploy.md
   git commit -m "ci(audit): move the daily audit to 05:19 UTC"
   git push origin main
   ```
   Expect `8 examples, 0 failures` (the AC-2.1 example accepts any minute from 1 to 59) before the commit, and the push to succeed.
5. **AC-1.3.** In the repository, open Insights, Dependency graph, Dependabot: the `bundler` ecosystem's last job shows no configuration error. (A clean log shows the file is valid, not that the group works; editing the file also starts a version-update run, which may open pull requests.)
6. **AC-1.4**, when it next happens: a day with two or more flagged gems and Dependabot security-update pull requests shows them in one pull request. Record it then.
7. **The deferred question (Decision 4).** Open Security, Dependabot, filter Closed, and look at the alerts for addressable, loofah, nokogiri, rails-html-sanitizer and sqlite3: was an alert created, and did Dependabot report an error? Record the answer in `verification.md`; if no alert was created, `sdd-superpowers:sdd-spec-update` follows before any work on `allow: indirect`.
