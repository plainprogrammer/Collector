# Feature 091: CI Fails on a Dependency Whose Licence Isn't Allowed

**Status:** Approved (2026-11-13, Gate A: the coordinator under the maintainer's delegation, v0.4.0; amended to 0.5.1: the maintainer ruled `vcr` a named exception, 2026-11-13)
**Version:** 0.5.2
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Depends on:** [spec 087](../087-third-party-licences-in-app/spec.md) (the reader of the bundle and the manifest, and the guard; frozen, by [catalog core](../../architecture/catalog-core.md)), [spec 035](../035-ci-shards/spec.md) (`bin/ci checks`; frozen, by [release and deploy](../../architecture/release-and-deploy.md))
**Branch:** `091-licence-check-in-ci`
**Issue:** [#402](https://github.com/plainprogrammer/Collector/issues/402) (the 1.0 milestone, housekeeping lane)
**ADR:** [0031](../../adr/0031-a-dependency-licence-is-a-decision.md) (Proposed; the maintainer ruled decision 9 on 2026-11-13).
**Frozen:** the current rules are in [`catalog-core.md`](../../architecture/catalog-core.md) and [`release-and-deploy.md`](../../architecture/release-and-deploy.md) (whole spec); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.5.2 | 2026-11-13 | Decision 3 says plainly why `all_required` exists (the coordinator's request at Gate B); no requirement changed |
| 0.5.1 | 2026-11-13 | **The maintainer's ruling on `vcr`** (2026-11-13, relayed by the coordinator): `vcr` is a named exception in `config/licence_policy.yml`, beside `bundler-audit` and `brakeman`; it is a test-only tool the application never loads, its gemspec lists `Hippocratic-2.1` beside `MIT`, it ships no licence file, and whether the `MIT` is a real choice is unverified. The any-one-of rule stays as ruled for `rdoc` and `diff-lcs`. The *(pending)* marks come off; AC-3.4's `vcr` clause is unconditional and its reason clause no longer says "never shipped". No other requirement changed |
| 0.5.0 | 2026-11-13 | **`vcr` (pending the maintainer).** The coordinator recommends a named exception for `vcr` instead of letting it in on its declared `MIT` (it ships no licence file and issue #408 calls it Hippocratic-2.1). An exception can't express that under 0.4.0's rules, because without it `vcr` would pass as `MIT` and the exception would be stale, so decision 3 gains the `all_required` form and AC-3.6 proves it. The default of the draft is the exception form; the policy's `vcr` entry is a task of its own in the plan, so the maintainer's ruling either way is one task. The rest is unchanged |
| 0.4.0 | 2026-11-13 | The maintainer's rulings of 2026-11-13, relayed by the coordinator: decisions 1 to 9 as recommended (the list of seven, any one of a dual, named stale-checked exceptions for `bundler-audit` and `brakeman`, every group, no normalising, the manifest judged, the `bin/ci checks` step extending spec 087, `config/licence_policy.yml`, and ADR 0031). The *(pending)* marks come off; decision 2's table names every gem the dual rule lets in. Open question 2 (OFL-1.1 for every kind) is closed by decision 1's one list. No requirement changed |
| 0.3.0 | 2026-11-13 | Spec review round 2 (Fable, Mode A, APPROVE WITH CHANGES, 0 blocking, 1 major, 7 minor) fixed: a `Check` joins an injected audit's problems and the policy's, so AC-4.4 has a seam (FR-3, decision 7); the lockfile names' de-duplication is `Policy.for_repository`'s and proved on the real lockfile (AC-3.5); AC-2.4 and AC-4.2 are evidenced by the recorded `bin/ci checks` run; double reports are stated (AC-1.6); AC-4.3 says how the path is passed and that a spec runs the task in-process; the header version. Old AC-4.4 (a task-level stand-in) became a criterion on the new seam, the timing criterion moved into the Performance NFR, and the workflow criterion is AC-4.5. No requirement was removed |
| 0.2.0 | 2026-11-13 | Spec review round 1 (Fable, Mode A, APPROVE WITH CHANGES, 0 blocking, 4 major, 8 minor) fixed. The step also reports spec 087's guard, so a pin with no entry fails `bin/ci checks` too (decision 7); `Policy.for_repository` is named and AC-4.4 dropped; the exception rules say order-insensitive, take the lockfile's gem names as an input and have an AC for a gem the lockfile names and the bundle doesn't hold (decision 3, AC-3.5); the fallout in the area docs, CLAUDE.md and `.claude/rules/testing.md` is listed and the step's place proved in `spec/config/ci_definition_spec.rb` (Story 4, Story 5); the limits of the manifest's section keys and of the image are stated (decisions 6 and 8); house style. No requirement was removed |
| 0.1.0 | 2026-11-13 | First draft from issue #402, the licensing research of 2026-11-13 and the task brief. Decisions 1 to 9 are the author's recommendations, put to the coordinator and so to the maintainer as scope questions; they are marked *(pending)* until ruled. The allowed list and the exceptions are the maintainer's to rule |

## Problem Statement

Collector is AGPL-3.0 and will be offered as a hosted service on the same code (the [households and hosted service design](../../superpowers/specs/2026-11-13-households-and-hosted-service-design.md)). A dependency's licence is then a decision of the project's, not a detail of a pull request: a copyleft or field-of-use licence that arrives with a new gem, or with a JavaScript package an agent pins, binds what the project may do with the code. Today nothing looks. Spec 087 lists the licences on a page and its guard fails when a pin or a font has no entry, but no check reads *which* licence a dependency is under, so a gem under the GPL-3.0 would pass `bin/ci` and ship.

Measured on `main` at `71212946`, the bundle holds **142 gems** in every group (the suite's view), with 13 distinct sets of licences. **Two** are under a licence a permissive-only list would not allow: `bundler-audit` (GPL-3.0-or-later) and `brakeman` (Brakeman Public Use License), both development and test tools the app never loads. Three more pass only because a gem declares several licences: `rdoc` (Ruby and GPL-2.0-only), `diff-lcs` (MIT, Artistic-1.0-Perl and GPL-2.0-or-later) and `vcr` (Hippocratic-2.1 and MIT). The manifest side holds MIT (Turbo, Stimulus, the OCR language data), Apache-2.0 (the OCR engine), OFL-1.1 (three fonts) and ISC (the icons).

> **Terms.** *Allowed list*: the SPDX identifiers the project has decided to depend on, in `config/licence_policy.yml` (decision 1). *Exception*: a named gem that is under a licence off the list, with the licence it was reviewed under and the reason (decision 3). *Component*: one entry of the list spec 087's reader builds, a gem or a manifest entry (JavaScript, OCR engine, font, icon). *Judged*: compared with the allowed list and the exceptions by this spec's rules.

## Goals

- A pull request that adds a gem, or a JavaScript package, font or icon set the manifest lists, under a licence the project hasn't allowed fails `bin/ci checks`, and the failure names the dependency, its licence and the file that holds the allowed list.
- The allowed licences, and each exception with its reason, are recorded in the repository. Allowing a copyleft dependency is a change to that file, so it shows in review.
- The check reads the list spec 087's reader builds, so the page and the check can't disagree about what the image holds or under which licence.
- Each rule is proved by injection on a small fixture and the real tree is shown to pass, as spec 087's guard is.

## Non-Goals

- Deciding whether a licence is compatible with the AGPL-3.0, or any legal conclusion. The list is the maintainer's decision, recorded; the check enforces it and claims nothing about why it is right.
- Reading a licence from a gem's files. The check trusts the declared identifiers (decision 5); a gem that declares one thing and ships another is a risk it states and doesn't close.
- Verifying a manifest entry's `spdx` against the package's own metadata: there is no `node_modules`, and CI reads no network (decision 6).
- Changing what the image installs ([#408](https://github.com/plainprogrammer/Collector/issues/408)), or the contribution policy ([#401](https://github.com/plainprogrammer/Collector/issues/401)).
- Checking Ruby, its default gems the lockfile doesn't name, or the operating system's packages in the image (spec 087's Non-Goals).
- A change to `.github/workflows/**`, the `Dockerfile` or a deploy file: GitHub runs `bin/ci checks`, which gains the step.
- Judging the licences of Collector's own code, or an SPDX expression parser (decision 5).

## Users and Context

**Primary users:** a maintainer or an agent adding or bumping a dependency, who must be told by CI that its licence needs a ruling and where to record one.
**Secondary users:** the maintainer reviewing a change to the allowed list, and an operator or contributor who wants to know what the project allows.
**Usage context:** read in CI output and in a pull request's diff of one small file.

## Decisions *(ruled by the maintainer, 2026-11-13, as recommended)*

1. **The allowed list is seven identifiers, by SPDX id, in `config/licence_policy.yml`.** `MIT`, `BSD-2-Clause`, `BSD-3-Clause`, `Apache-2.0`, `ISC`, `Ruby` and `OFL-1.1`. Each has a one-line `reason`. What each lets in today:

   | Id | Lets in today |
   |---|---|
   | `MIT` | 100 gems declare it alone, plus `nio4r` and `marcel` (each also under another allowed id) and `diff-lcs` and `vcr` (decision 2); the JavaScript (Turbo, Stimulus) and the OCR language data |
   | `BSD-2-Clause` | `rexml`, `rubyzip`, `nio4r` and 23 default and Ruby-project gems (`base64`, `bigdecimal`, `drb`, `logger`, `securerandom`, `uri`, `racc`, `prettyprint`, `pp`, `erb`, `tsort`, `rbs`, `io-console`, `irb`, `timeout`, `date`, `net-protocol`, `net-imap`, `net-pop`, `net-smtp`, `matrix`, `debug`, `ostruct`; each also `Ruby`) |
   | `BSD-3-Clause` | `ffi`, `puma`, `sqlite3` |
   | `Apache-2.0` | `websocket-driver`, `websocket-extensions`, `addressable`, `msgpack`, `selenium-webdriver`, `marcel`; `tesseract.js` and `tesseract.js-core` |
   | `ISC` | the icons (Lucide) |
   | `Ruby` | `json`, `reline`, `rdoc` (see decision 2) and the 23 gems above |
   | `OFL-1.1` | the three font families; no gem |

   Not allowed, so a decision when one arrives: any GPL, LGPL, AGPL, MPL or EPL licence, Artistic, a field-of-use or ethical licence (Hippocratic), a source-available licence, `0BSD`, `Unlicense`, `CC0-1.0` and `BSD-3-Clause-Clear`. Adding `0BSD` or `Unlicense` the first time one is met is a one-line change.
2. **A component with several identifiers passes if any one is allowed.** The gemspec's `licenses` list is a choice of licences by convention, and spec 087's reader shows it as a list of identifiers. Three gems pass today only because of this rule, so the maintainer rules on names (the table; `nio4r` and `marcel` below it pass on either id):

   | Gem | Declares | Passes as | Ids that aren't allowed |
   |---|---|---|---|
   | `rdoc` 8.1.0 | `Ruby`, `GPL-2.0-only` | `Ruby` | `GPL-2.0-only` |
   | `diff-lcs` 1.6.2 | `MIT`, `Artistic-1.0-Perl`, `GPL-2.0-or-later` | `MIT` | `Artistic-1.0-Perl`, `GPL-2.0-or-later` |
   | `vcr` 6.4.1 | `Hippocratic-2.1`, `MIT` | `MIT` | `Hippocratic-2.1` |

   In prose: **`rdoc` 8.1.0** (`Ruby`, with `GPL-2.0-only`; passes as `Ruby`), **`diff-lcs` 1.6.2** (`MIT`, `Artistic-1.0-Perl` and `GPL-2.0-or-later`; passes as `MIT`; its files hold `LICENCE.md` and `docs/COPYING.txt`) and **`vcr` 6.4.1** (`Hippocratic-2.1` and `MIT`; passes as `MIT`; the gem ships no licence file, so its licence page row has no text). `nio4r` and `marcel` pass on either id. The rule trusts the declared `MIT` of the last two (`diff-lcs` ships its licence texts, `vcr` ships none, so only `vcr` rests on the declaration alone, and issue #408 calls it Hippocratic-2.1). **`vcr` is a named exception (ruled 2026-11-13):** in decision 3's `all_required` form, so `vcr` fails the any-one-of rule and is let through by name with the reason, because whether its `MIT` is a real choice is unverified. The rule stays as ruled for `rdoc` and `diff-lcs`, which pass on `Ruby` and `MIT`.
3. **Exceptions are named per gem, in the same file, each with the licences it was reviewed under and a reason.** An exception is `gem`, `licences` (the identifiers the gem declares, compared as a set, so order doesn't matter: the bundle already holds both orders of one pair) and `reason`. It lets that gem pass while it declares exactly those. It is stale, and fails the check, when the lockfile no longer names the gem, when the gem declares other identifiers (a new release changed its licence, which is a new decision), or when the gem would pass without it. A gem the lockfile names and the bundle doesn't hold (a run with `BUNDLE_WITHOUT`) is neither judged nor stale. The lockfile's names are a second input, read with `Bundler::LockfileParser` and de-duplicated (`ffi`, `sqlite3` and others repeat per platform); `bundler` itself is in the bundle and not in the lockfile, so an exception for it would always be stale, and it declares an allowed licence anyway. An exception may say `all_required: true`, meaning the gem's list is not a choice: every identifier must be allowed, so the gem fails without the exception, and the exception is stale when every identifier is now allowed (not when one is). **Why the form exists, plainly:** `vcr` declares `Hippocratic-2.1` and `MIT`, so the any-one-of rule would pass it on `MIT` and an ordinary exception for it would be stale ("allowed without it"); `all_required` is how an exception can mean "don't trust the allowed alternative". The policy file's header says the same, for whoever copies the form. Today three: **`bundler-audit`** (`GPL-3.0-or-later`; a command-line audit run by `bin/ci` and never loaded by the application) and **`brakeman`** (`Brakeman Public Use License`; a static analyser run by `bin/ci` and the commit hook, never loaded). The third is **`vcr`** (`Hippocratic-2.1` and `MIT`, `all_required: true`; a test-group HTTP recorder never loaded by the application; reason: its declared `MIT` is not trusted, since it ships no licence file and the issue calls it Hippocratic-2.1). The first two leave the image when #408 lands; the exceptions then stay as development-tool exceptions. Exceptions are for gems; a manifest entry under a disallowed licence is a change to the list or no dependency.
4. **Every bundle group is judged.** The check reads `Bundler.load.specs`, as spec 087's reader does, which in development and CI holds every group. A development or test tool under a restricted licence is then a recorded exception and not a silent pass, and the rule doesn't depend on what the image installs (#408) or on the `Dockerfile`. A run with `BUNDLE_WITHOUT` set judges only what is installed; CI and development install every group.
5. **No licence, or one that isn't an allowed id, fails; nothing is normalised.** A component with no identifiers fails (spec 087's guard accepts a gem with a licence file and no declaration, for display; the policy can't judge a file). An identifier is compared exactly with the list: `MIT License`, `Apache 2.0` and an expression in one string such as `MIT OR Apache-2.0` all fail, naming the string, and the fix is the exception or the list. This costs an occasional exception for a misspelt but fine licence and guarantees nothing is let in by a guess.
6. **The manifest's entries are judged by the same rule.** Every entry of `config/third_party_licences.yml` (JavaScript, OCR engine, fonts, icons) is judged by its `spdx`. Spec 087's guard already fails an importmap pin or an OCR package with no entry, so a JavaScript package arrives with an entry, and the entry must then pass. Two limits are stated. A key of the manifest that the reader doesn't list (`ThirdPartyLicences::TITLES`) is neither shown nor judged, as spec 087 leaves it. And `spdx` is typed from the package's metadata by whoever adds the entry (each entry's `source` says where); the check can't read a package it doesn't have.
7. **The check is a `config/ci.rb` step in `bin/ci checks`, over a new class that reads spec 087's list.** The step "Licences: dependencies are under allowed licences" runs `bin/rails licences:check`, in the group of the other checks (not the RSpec group), so GitHub's checks job runs it with no workflow change. A new class under `lib/collector/third_party_licences/`, `Policy`, judges the sections `Collector::ThirdPartyLicences.build` returns, with `Policy.for_repository(policy_path:)` building the real inputs as `Audit.for_repository` does; there is no second reader of the bundle (the lockfile's gem names, decision 3, are the one added input). A small `Check.new(audit:, policy:)` joins the two: the guard's problems first, then the policy's, as one list of sentences for the task to print; it takes any audit that answers `problems`, so a spec injects a stand-in. The task so reports spec 087's `Audit.for_repository.problems`, so an importmap pin or an OCR package with no manifest entry fails `bin/ci checks` as the issue's outcome says and not only the RSpec shards; the guard spec stays. The rules are proved in an RSpec file like `audit_spec.rb` (the shards run them); the real tree is judged by the step's run (AC-4.2) and not by a duplicate spec. The task takes the policy's path as an argument, so a spec (and a maintainer) can run the real task against a policy that allows nothing.
8. **The file is `config/licence_policy.yml`, apart from the page's manifest.** The manifest is display data (names, digests, texts) and its reader ignores unknown keys; a ruling the maintainer makes belongs in a file whose diff is one decision. It sits in `config/`, which the image keeps, and so do the class and the task (autoloaded from `lib/`); that is intended and harmless, as the manifest is. The task needs `:environment` (the importmap and the asset load path), unlike `start:check` and the backup tasks. Its header says how to propose an addition.
9. **An ADR for the rule, if the maintainer wants one.** I recommend ADR 0031: "a copyleft dependency is a decision" is of lasting weight (it constrains what the hosted service may build on), and the rules (any one of several, every group, named exceptions that go stale) are why-not-what. The YAML holds the list and the reasons; the ADR holds the rule. The alternative is no ADR, with the rule in `catalog-core.md` as spec 087 did.

## User Stories and Acceptance Criteria

### Story 1: A gem under a licence that isn't allowed fails CI

**As** a maintainer **I want** `bin/ci checks` to fail when a gem is added under a licence I haven't allowed **so that** a copyleft dependency is my decision and not an accident.

- [ ] **AC-1.1** Given a stand-in bundle with a gem declaring `GPL-3.0-only` and an allowed list without it When the policy is judged Then it fails once, and the message names the gem and its version, its licence `GPL-3.0-only`, and the policy file's path as it was given (`config/licence_policy.yml` for the real one).
- [ ] **AC-1.2** Given a gem declaring `MIT` and `GPL-2.0-only` When it is judged Then it passes (decision 2); given one declaring only `GPL-2.0-only` and `Artistic-1.0-Perl` Then it fails and the message lists both.
- [ ] **AC-1.3** Given a gem with no declared licence, with or without a licence file When it is judged Then it fails and says it declares none.
- [ ] **AC-1.4** Given a gem declaring `MIT License`, `Apache 2.0` or `MIT OR Apache-2.0` When it is judged Then it fails and names the string as written.
- [ ] **AC-1.5** Given a stand-in bundle of gems, each under an allowed id (including the dual `BSD-2-Clause` and `Ruby`) When it is judged Then there is no problem.
- [ ] **AC-1.6** Given several offenders When they are judged Then the problems name each, one sentence per component, in the order `ThirdPartyLicences.build` lists them (sections in page order, then name regardless of case), each naming the policy file's path. A component the guard also reports (a gem with neither identifier nor licence file, an entry with no `spdx`) is reported by both and by `Check` twice, once per source; the policy's own rules give one sentence per component, a stale exception and a disallowed licence for the same gem being two sentences.

### Story 2: The JavaScript, fonts and icons the manifest lists are judged too

**As** a maintainer **I want** a pinned JavaScript package, a font or an icon set held to the same list as a gem **so that** the importmap side can't carry a licence the gems couldn't.

- [ ] **AC-2.1** Given a stand-in manifest whose JavaScript entry says `spdx: GPL-3.0-only` When it is judged Then it fails naming the entry, the section and the licence; likewise an OCR, font or icon entry.
- [ ] **AC-2.2** Given a manifest entry with several `spdx` identifiers When it is judged Then decision 2's rule applies, and one with none fails.
- [ ] **AC-2.3** Given a gem exception for a gem name that is also a manifest entry's name When the entry is judged Then the exception doesn't apply (decision 3: exceptions are for gems).
- [ ] **AC-2.4** Given the repository's real manifest When it is judged against the real policy Then there is no problem (verified by the run of AC-4.2, not by a spec on the real tree).

### Story 3: Exceptions are named and stay honest

**As** the maintainer **I want** each licence I let through to be a named exception with a reason, which CI stops me forgetting **so that** the list of exceptions is always the true one.

- [ ] **AC-3.1** Given a gem under a disallowed licence with an exception naming that gem and exactly its licences When it is judged Then it passes.
- [ ] **AC-3.2** Given an exception whose gem the lockfile no longer names, one whose `licences` differ from what the gem now declares, or one for a gem that is allowed without it When it is judged Then it fails as stale, naming the exception and which of the three it is; an exception whose `licences` list the same identifiers in another order is not stale (decision 3).
- [ ] **AC-3.3** Given a policy entry missing its `id` or `reason`, or an exception missing its `gem`, `licences` or `reason`, a duplicate id, or a duplicate exception When the policy is loaded Then it fails naming the entry; a policy file that can't be read or isn't a mapping fails the step with the path.
- [ ] **AC-3.4** Given the real policy file When it is read Then it allows exactly the identifiers of decision 1 and excepts exactly `bundler-audit`, `brakeman` and `vcr` (the last in `all_required` form), each with a reason that names why the application never loads the gem.
- [ ] **AC-3.6** Given a gem declaring `MIT` and `Hippocratic-2.1` When it is judged with no exception Then it passes as `MIT`; with an `all_required` exception naming it and exactly those licences Then it is let through by name, and without that exception but with the form's rule on Then it fails naming `Hippocratic-2.1`; given an `all_required` exception for a gem whose licences are all allowed Then it is stale.
- [ ] **AC-3.5** Given a gem the lockfile names that the bundle doesn't hold (`BUNDLE_WITHOUT`), with or without an exception When the policy is judged Then it is neither judged nor reported stale; given the real `Gemfile.lock` When `Policy.for_repository` reads its gem names (it de-duplicates them; the policy itself takes names as an injected input) Then they hold no repeat and no `bundler`.

### Story 4: The step runs in `bin/ci checks` and shows its failure

**As** a contributor **I want** the failure to say what to do **so that** I record a decision or drop the dependency, and don't hunt through the output.

- [ ] **AC-4.1** Given `config/ci.rb` When it is read Then it has the step "Licences: dependencies are under allowed licences" running `bin/rails licences:check`, inside the block `bin/ci rspec` skips, after "Security: Importmap vulnerability audit" (proved in `spec/config/ci_definition_spec.rb`, as the YARD and ratchet steps are).
- [ ] **AC-4.2** Given today's tree When `bin/rails licences:check` runs Then it exits 0, prints how many components it judged on standard output, and reports no problem of spec 087's guard either.
- [ ] **AC-4.3** Given the task run, in-process with its `SystemExit` rescued, as `bin/rails "licences:check[path]"` passes the path (as `catalog:refresh[mtg]` passes its argument), against a policy file that allows no licence When it runs Then it exits 1, and on standard error prints one line per component with the dependency's name, its licence and the policy file's path (the fixture's `allowed: []` is valid and holds no exceptions).
- [ ] **AC-4.4** Given `Check` with a stand-in audit that reports one problem and a policy that reports another When it runs Then it lists the audit's problem first and the policy's second, and with a stand-in audit built from a manifest with an importmap pin and no entry Then the guard's sentence is among them (decision 7).
- [ ] **AC-4.5** Given `.github/workflows/**` When the pull request is read Then no workflow changed.

### Story 5: It lives where an agent looks

**As** an agent **I want** the rule written where I read the commands and the area docs **so that** I know before I add a dependency.

The criteria that name a document (AC-3.4, AC-4.5, AC-5.x) are verified by reading and recorded in `verification.md`, as `.claude/rules/testing.md` asks; AC-2.4 and AC-4.2 are evidenced by the `bin/ci checks` run recorded there.

- [ ] **AC-5.1** Given `spec/licences_core_spec.rb` When it runs Then its file list covers the policy file and the new class, and none names a collectible, source or rights holder.
- [ ] **AC-5.2** Given the area doc [catalog core](../../architecture/catalog-core.md) When the work is done Then it records the policy file, the rules of decisions 2 to 6, the task and the step, each with its source inline, and its Named constants table lists the new constants; [release and deploy](../../architecture/release-and-deploy.md) lists the step among the `bin/ci checks` steps.
- [ ] **AC-5.3** Given `CLAUDE.md` When the work is done Then its Commands list has `bin/rails licences:check` (and its Local CI step list names the step) and its Project Status names the policy file; `.claude/rules/testing.md` lists the step among what `bin/ci` runs, and `.claude/rules/conventions.md` says a new dependency under a licence off the list is a decision, not a fix for CI.
- [ ] **AC-5.4** Given `docs/roadmap.md` and `docs/specs/README.md` When the work is done Then the roadmap's #402 row is marked, and the index has spec 091's row.

## Functional Requirements

- **FR-1** `config/licence_policy.yml`: `allowed` (each `id`, `reason`) and `exceptions` (each `gem`, `licences`, `reason`), read with `YAML.safe_load`.
- **FR-2** A class under `lib/collector/third_party_licences/` that judges `ThirdPartyLicences.build`'s sections against a policy and the lockfile's gem names and returns one sentence per problem; every input injectable, as the audit's are.
- **FR-3** `Check`, which joins an injected audit's problems and the policy's (the guard's first), and `licences:check`, a rake task that builds the real audit and policy, prints the joined problems on standard error and exits 1 when there are any, and prints the count on standard output when there are none; it takes an optional policy path.
- **FR-4** The `config/ci.rb` step.

## Non-Functional Requirements

- **Performance:** the step reads the licence files `ThirdPartyLicences.build` reads (about 400 KB) and boots the application; `bin/ci checks` is recorded before (35.5 s total on the author's machine, 2026-11-13, `main` at `71212946`) and after in `verification.md`, with the step's own time. It adds no database work.
- **Security:** the policy is read with `YAML.safe_load`; the task reads no network and writes nothing.
- **Collectible-agnostic core:** AC-5.1.
- **Self-hosting:** nothing to configure; the check runs in CI and in development, not in the image.

### Hosted-door rules

- No source is touched, no collection data is read, no choice is stored, and no export field is added, so the export format is unchanged.

## Error Scenarios

| Situation | Result |
|---|---|
| A new gem under an unlisted licence | `bin/ci checks` fails at the step, naming the gem, its version, the licence and `config/licence_policy.yml` (AC-1.1) |
| A new importmap pin with no manifest entry | The step reports spec 087's guard and fails (AC-4.4), as do the RSpec shards; once the entry exists the step judges it (decision 6) |
| A gem's new release changes its licence | An exception for it is stale and fails (AC-3.2); the gem without one fails if the new licence is off the list |
| The policy file is missing or malformed | The step fails naming the file (AC-3.3) |
| `BUNDLE_WITHOUT` hides the test group | The check judges what is installed and doesn't call an exception for a missing gem stale if the lockfile still names it (AC-3.5) |

## Open Questions

None open. The maintainer ruled decisions 1 to 9 as recommended on 2026-11-13 and `vcr` a named exception the same day. The one list holds `OFL-1.1` for every kind, as the ruling of decision 1 states it (no per-kind scope; none was put to the maintainer, so a scope is a later change).

## Out of Scope (Candidates)

- An SPDX expression parser (`MIT OR Apache-2.0` in one string).
- Reading a licence from a package's own files to compare with its declaration.
- A scheduled run of the check on `main` for a licence that changes without a pull request (Dependabot's updates arrive as pull requests, which run the step).
