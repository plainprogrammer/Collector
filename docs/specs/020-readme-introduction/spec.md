# Feature 020: An Accurate README

**Status:** Approved
**Version:** 1.4.2
**Created:** 2026-10-12
**Last Updated:** 2026-10-12
**Branch:** `020-readme-introduction`
**Issue:** [#63](https://github.com/plainprogrammer/Collector/issues/63)
**Frozen:** the current rules are in [`release-and-deploy.md`](../../architecture/release-and-deploy.md) (whole spec); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-12 | Initial draft from issue #63. Three maintainer choices made while specifying: the whole of `README.md` is checked, not only its introduction (decision 1); the introduction says Collector is pre-1.0 and links the roadmap, with no list of unbuilt features (decision 2); the result is checked by hand and recorded, with no automated test (decision 3) |
| 1.1.0 | 2026-10-12 | Maintainer ruling: the same stale phrase in `CLAUDE.md` ("a public card search proof-of-concept") is corrected in this PR (decision 4, Goals, Non-Goals, AC-2.9, FR-4, AC-3.2, Out of Scope). The rest of `CLAUDE.md` is not swept |
| 1.2.0 | 2026-10-12 | Spec review revisions (Opus, Mode A, NEEDS REVISION, three blocking). **Existing test:** `spec/readme_spec.rb` already pins README phrases; it stays, and an expectation is edited only where a correction changes the phrase it pins (decision 3, FR-2, AC-3.6, Testability, Error Scenarios). **Statements left stale:** a statement the code contradicts, or that needs a ruling, may stay and is recorded (Goals, AC-2.1, AC-3.5, FR-3). **Gaps:** recorded only; this PR opens no issue and doesn't change the roadmap (glossary, AC-3.4, decision 6). **Sorting rules:** "claim", "checkable", "not refuted" and "off-limits" are defined so two people sort alike (glossary, FR-2). **`CLAUDE.md`:** a README correction that `CLAUDE.md` repeats is made there too, which covers its copy of the stale `home_spec.rb` example (decision 5, proposed; AC-2.9, FR-4). **Also:** diffs are read as word diffs (AC-2.7, AC-2.9); AC-2.5 names the replacement; AC-1.8 is folded into AC-2.6; AC-2.2 and AC-2.4 cover Kamal aliases, other tools' commands and variables read outside the app; the opening sentence is fixed verbatim (AC-1.1) |
| 1.3.0 | 2026-10-12 | Maintainer rulings. **`spec/readme_spec.rb` is removed** in this PR, with its RuboCop exclusion: a spec that tests a README's wording is without precedent in the maintainer's experience (decision 3 rewritten, Goals, Story 4, FR-5, AC-3.6, FR-2, Security, Reliability, Testability, Error Scenarios). Its two expectations that read `compose.yaml` and `config/deploy.yml`, not the README, are kept in `spec/image_publishing_spec.rb`. **Decision 5 accepted:** `CLAUDE.md` gets the README corrections it repeats. The rest of 1.2.0 is approved as it stands |
| 1.3.1 | 2026-10-12 | Second review pass (Opus, Mode A, NEEDS REVISION, two blocking; wording only, no decision reopened). **Moved expectations:** neither string is asserted today, so two examples are added to `spec/image_publishing_spec.rb` and the counts are stated (AC-4.2, AC-4.3, Testability). **Not refuted** is a result, not a kind of claim, and a refuted claim is stale (glossary, FR-2, AC-3.3). **Also:** comparisons are against `origin/main...HEAD`, since a local `main` can be behind (AC-2.7 to AC-2.9, AC-4.3); what a correction may do to wrapping and to aligned code comments (AC-2.7, FR-2); the `CLAUDE.md` sentence is given verbatim (AC-2.9, FR-4); how a repeat in `CLAUDE.md` is found (FR-4, AC-3.2); the safety warnings get their own record entry (AC-3.8); true claims are recorded per section (AC-3.1); FR-5's ordering line is removed; the places that say what the PR touches now name the spec files and `.rubocop.yml` |
| 1.3.1 | 2026-10-12 | **Approved by the maintainer**: the 1.2.0 revisions, decision 5 and the removal of `spec/readme_spec.rb`, with a second review asked for after the edits. That review's fixes are the row above and change no decision |
| 1.4.0 | 2026-10-12 | Maintainer ruling, made while planning: "I think it's odd to check documents outside code from RSpec. So, please apply my ruling more broadly." Asked how broadly and where, the maintainer chose **prose documents only**, **inside this spec** (decision 7). Besides `spec/readme_spec.rb`, the suite loses its examples about `docs/releasing.md`, the design system's documents, `CLAUDE.md`, the agent skill file and the ADR index, and the example that the README links the export format. The export format's own checks, the configuration checks and the checks of code files stay. `.claude/rules/testing.md` gains the rule (Story 4 rewritten, FR-5, Goals, Non-Goals, Reliability, Error Scenarios, Out of Scope, One outcome) |
| 1.4.1 | 2026-10-12 | Third review pass (Opus, Mode A, on the 1.4.0 change only: READY TO PLAN, nothing blocking; wording). A prose document is defined by who reads it, not by its extension, so the design system's `tokens.json` and previews count and the export format's schema and examples don't (decision 7, AC-4.7); AC-4.6 uses a wider search with its expected output listed; the list of past specs is replaced by the rule that produces it (Reliability); the PR description names the second outcome (AC-3.7); where the rule line goes (AC-4.7); the new `config/deploy.yml` example reads the file's text (AC-4.2). The maintainer's rulings of 1.4.0 stand; approval of the whole is recorded when given |
| 1.4.2 | 2026-10-12 | From the plan's second review: the PR also carries the session wrap's lessons under `docs/lessons/`, as every spec's PR does (Non-Goals). No requirement changed |
| 1.4.2 | 2026-10-12 | **Approved by the maintainer** with the plan: decision 7, the rule line in `.claude/rules/testing.md` and the lessons clause included |

---

## Problem Statement

`README.md` is the first thing a self-hoster or contributor reads, and its first paragraph is wrong. It says "Accounts and collections are not built yet", while accounts, collections of lots, the card scanner and the admin pages all exist. It also calls catalog search "a public card search page", while search has needed sign-in since accounts landed (opening it to visitors is issue #59, not yet built). A reader who believes the introduction concludes that Collector can't hold a collection. `CLAUDE.md`'s Project Status repeats the second claim ("a public card search proof-of-concept at `/catalog/entries`"), which tells every coding agent that works in the repository the same wrong thing.

The introduction went stale because specs since 004 added to the sections below it and none returned to the top. The same can have happened anywhere in the file: one example is already known (`bin/rspec spec/requests/home_spec.rb:5` names a spec file that no longer exists, in both `README.md` and `CLAUDE.md`).

The suite also pins phrases and section order of the README in `spec/readme_spec.rb` (eight examples, added by the plans of specs 004, 007, 011, 012, 014 and 015). Other spec files do the same to other prose documents: `docs/releasing.md`, the design system's documents, `CLAUDE.md`, an agent skill file, the ADR index. The maintainer finds it odd to check documents outside code from RSpec (decisions 3 and 7), and each such example is one more thing a correction to a document has to satisfy.

> **Inputs.** This spec is about one file and its repeats in a second, and about the examples that check prose documents, so it names them: the four spec files Story 4 changes, `.rubocop.yml` and `.claude/rules/testing.md`. The roadmap ([docs/roadmap.md](../../roadmap.md)), the north star ([docs/north-star.md](../../north-star.md)) and the repository at the PR's head are the fixed inputs. Comparisons "with `origin/main`" mean with the merge base, `origin/main...HEAD`.

### Glossary

- **Introduction:** the first paragraph of `README.md`, between the `# Collector` heading and the paragraph that begins "Built with Rails".
- **Claim:** one thing `README.md` says about the application, its commands, files, paths, routes, settings, defaults or behaviour. A sentence, list item, table row, command or code comment is split into its claims, and each is sorted separately.
- **Checkable:** a claim that can be confirmed or refuted by reading tracked files, or by running a command in a checkout with no network, no container runtime and no phone. A command is checked by reading its source; it is run only if it writes nothing outside `tmp/` and reads no off-limits file. A figure that a document under `docs/` merely repeats (a download size, a duration) is not checkable. The behaviour of another tool, a browser, a registry or a device is not checkable; the parts of such a claim that name things in this repository are.
- **Stale:** a checkable claim that isn't true of the repository at the PR's head.
- **Not refuted:** the result recorded for a checkable claim that says something never happens or always holds, whatever its wording (for example "Photos never leave the phone"), when the code or spec named in the record shows no counter-example. It is not recorded as true. If a counter-example is found, the claim is stale and is treated as any other stale claim.
- **Off-limits:** a file that agents may not read (`.kamal/secrets`, `config/master.key`). A claim about it is recorded as unchecked for that reason, unless the maintainer checks it.
- **Gap:** something an operator or contributor would need and can't find in the README, noticed while checking a claim. No reverse sweep of the repository is made to find gaps.
- **Sweep record:** the list, in this spec's `verification.md`, of what was checked and what was found, for `README.md` and for the `CLAUDE.md` changes.

### Decisions

1. **The whole README is checked.** The issue names the introduction; the maintainer widened it to every section (2026-10-12).
2. **Pre-1.0, with a link.** The introduction says Collector is pre-1.0 and links the roadmap. It doesn't list what is missing, so it doesn't go stale as each spec lands (maintainer, 2026-10-12).
3. **Checked by hand and recorded; the README has no spec.** No behaviour changes, so no test is added. `spec/readme_spec.rb`, which pins phrases and section order in the README, is removed in this PR: a spec that tests a README's wording is without precedent in the maintainer's experience (maintainer, 2026-10-12). This is the one statement of the reason; the rest of the spec cites it. Past specs' README criteria lose their automated evidence, and their `plan.md` and `verification.md` files still name the file, as a record of what was true then. Its last example also reads `compose.yaml` and `config/deploy.yml`; those two expectations check configuration, not the README, and neither string is asserted anywhere else (`spec/image_publishing_spec.rb` checks only that the Compose key is present), so they are kept as two new examples in `spec/image_publishing_spec.rb`. Decision 7 widens this to the other prose documents.
4. **`CLAUDE.md`'s phrase is fixed here.** The stale "public card search proof-of-concept" phrase in `CLAUDE.md`'s Project Status is corrected in the same PR. The rest of that file is not swept (maintainer, 2026-10-12).
5. **A README correction that `CLAUDE.md` repeats is made there too.** `CLAUDE.md`'s Commands list holds the same stale `home_spec.rb` example. Fixing one copy and knowingly leaving the other makes the two files disagree, so where the sweep corrects a README claim and `CLAUDE.md` states the same claim, `CLAUDE.md` gets the same correction. This is still not a sweep of `CLAUDE.md` (proposed from review; accepted by the maintainer, 2026-10-12).
6. **Gaps are recorded, not filed.** This PR opens no issue and doesn't change `docs/roadmap.md`: a new housekeeping issue is a new roadmap candidate, and the roadmap changes with its issues. The maintainer decides from the record which gaps become candidates. The roadmap's line for #63 is left as it is, as specs 018 and 019 left theirs (from review).
7. **No RSpec example checks a prose document.** The maintainer widened decision 3 while planning: "I think it's odd to check documents outside code from RSpec." Asked how far, they chose prose documents only; asked where, they chose this spec and this PR, knowing it adds a second outcome to it (maintainer, 2026-10-12). A **prose document** is a file written for a person or an agent to read and that no code or tool reads: `README.md`, `CLAUDE.md`, the files under `.claude/` (skills, rules), the Markdown under `docs/`, and the design system's reference files beside its Markdown (`docs/design-system/tokens.json`, `previews/`). The export format's schema and examples are not prose documents (the suite validates against them), and neither is a data file that code reads. What goes: `spec/readme_spec.rb`; the `docs/releasing.md` examples in `spec/image_publishing_spec.rb`; the examples and expectations about the design system's documents, the skill file and `CLAUDE.md` in `spec/design_system_files_spec.rb`; the README-link and ADR-index examples in `spec/export_format_document_spec.rb`. What stays, by the same ruling: the export format's document checked against its schema, its examples and the application's tables (the guard that a new collector-owned column reaches the format), the schema and example files' checks, the checks of configuration files (`compose.yaml`, `config/deploy.yml`, the workflows, `.dockerignore`, `orca.yaml`, `.worktreeinclude`) and the checks of code files (stylesheets, the core's views and models).

## Goals

- The introduction describes what Collector does today: accounts, a collection of lots, catalog search, the card scanner and the admin pages.
- The introduction makes no claim that something existing isn't built, and no claim that a page is public when it needs sign-in.
- Every checkable claim in `README.md` is true of the repository at the PR's head, except one the record lists as left stale with its reason (AC-3.5).
- `CLAUDE.md` no longer calls catalog search public, and doesn't disagree with a correction made to the README.
- No example in the suite checks the wording, order, links or existence of a prose document, the export format's document excepted (decision 7).
- What was checked, what was corrected and what couldn't be checked is on record.

## Non-Goals

- Documenting features the README doesn't mention today. A gap is recorded, not filled.
- Restructuring the README: no section is added, removed, renamed or reordered.
- Rewording claims that are true, including two true claims that name one thing differently ("avatar menu" and "account menu"). Those are recorded.
- Changing the application, its commands or its configuration to match the README. (`.rubocop.yml` loses one line, FR-5.)
- Changing any spec file other than the four named in Story 4.
- Removing the export format's checks, the configuration checks or the checks of code files (decision 7).
- A user guide, screenshots or badges.
- Checking the rest of `CLAUDE.md` against the repository.
- Any other document under `docs/` (the roadmap, the design system, the ADRs), except this spec's own folder and the lessons the session wrap adds under `docs/lessons/`, as every spec's PR carries.
- Opening issues.

## Users and Context

**Primary users:** someone deciding whether to self-host Collector, reading the repository's front page on GitHub.
**Secondary users:** an operator following the self-hosting sections; a contributor setting up a checkout; a coding agent, which reads `CLAUDE.md` at the start of every session; the maintainer.
**Usage context:** read top to bottom once, then returned to by section. The introduction is often the only part read. The README's link to the roadmap is for readers on GitHub; `docs/` isn't in the published image, as with the README's existing links into `docs/`.
**User mental model:** the README is the truth about the project today. A reader doesn't cross-check it against the code.

## User Stories

### Story 1: The introduction says what Collector does today

**As a** person deciding whether to self-host Collector
**I want** the README's first paragraph to say what the app does now
**So that** I can tell in one read whether it can hold my collection

**Acceptance criteria:**

- [ ] **AC-1.1** Given the README at the PR's head When the introduction is read Then its first sentence is "Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering."
- [ ] **AC-1.2** Given the same When the introduction is read Then it says each person has their own account and their own collection.
- [ ] **AC-1.3** Given the same When the introduction is read Then it says cards are found in a catalog fed from Scryfall's bulk data and added to the collection, both by searching and with the card scanner.
- [ ] **AC-1.4** Given the same When the introduction is read Then it says an admin manages users and sign-up, the catalog's refreshes and the background jobs.
- [ ] **AC-1.5** Given the same When the introduction is searched, case-insensitively Then it contains neither "not built" nor "public", and no sentence says that accounts, collections, catalog search, the scanner or the admin pages are missing.
- [ ] **AC-1.6** Given the same When the introduction is read Then it contains the words "pre-1.0" and a link to `docs/roadmap.md`, and it names nothing that is an open candidate in `docs/roadmap.md` (for example exporting or importing a collection, locations, typed entry, the open catalog, comics).
- [ ] **AC-1.7** Given the same When the introduction's rendered text is counted (link text, not addresses) Then it is one paragraph of at most 130 whitespace-separated words.
- [ ] **AC-1.8** Given the same When the introduction is read Then everything it says Collector does has a section further down the README or a page in the application, and the record names that section or route for each.

### Story 2: Every claim in the README is true

**As an** operator or contributor following the README
**I want** each command, path, setting and description in it to match the repository
**So that** nothing I'm told to run or expect fails because the README fell behind

**Acceptance criteria:**

- [ ] **AC-2.1** Given the README at the PR's head When each checkable claim is compared with the repository Then none is stale, except a claim the record lists as left stale (AC-3.5).
- [ ] **AC-2.2** Given a command the README tells the reader to run When it is looked up Then a `bin/` script, rake task or `script/` file exists under that name and takes the arguments shown; a path argument names an existing file, and a `:N` suffix a line inside an example; a `bin/kamal` subcommand that isn't Kamal's own is defined under `aliases:` in `config/deploy.yml`. For a command from another tool (`docker compose`, `podman`, `openssl`), only the parts that name things in this repository (a service, a file, a task) are checked.
- [ ] **AC-2.3** Given a file, directory, route or URL path the README names When it is looked up Then it exists in the repository or is served by a route in `config/routes.rb`. A path that is created at run time (under `storage/`, `tmp/`, `log/`, `vendor/ocr/` or the reader's home directory) is checked against the code that writes it.
- [ ] **AC-2.4** Given an environment variable the README names When it is looked up Then something tracked in the repository reads or names it, or the record cites the framework or tool that reads it (Rails, Puma, Kamal); and the default and accepted values the README gives are the ones the code uses.
- [ ] **AC-2.5** Given the README's example of running a single spec When it is read Then it is `bin/rspec spec/requests/health_check_spec.rb:5`.
- [ ] **AC-2.6** Given every link in `README.md`, the introduction's included When it is followed Then a section link lands on an existing heading and a relative link names an existing file.
- [ ] **AC-2.7** Given `git diff --word-diff origin/main...HEAD -- README.md` When it is read Then outside the introduction every changed word belongs to a correction listed in the record. Given the same diff without `--word-diff` Then every changed line outside the introduction contains a listed correction: a corrected line may run past the wrap column and is not re-flowed. The one exception is the padding before a trailing `#` comment in a code block, which may change on neighbouring lines to keep the comments aligned.
- [ ] **AC-2.8** Given the README at the PR's head When its headings (lines beginning `#` outside fenced code) are compared with `origin/main`'s Then they are the same headings in the same order.
- [ ] **AC-2.9** Given `CLAUDE.md` at the PR's head When its Project Status is read Then the sentence beginning "Feature 002 added" ends "Scryfall bulk-data ingestion via a background refresh, and a card search at `/catalog/entries`, which has needed sign-in since accounts (spec 004)." and is otherwise as on `origin/main`. When `git diff --word-diff origin/main...HEAD -- CLAUDE.md` is read Then every changed word is inside that sentence or belongs to a README correction that `CLAUDE.md` repeats (decision 5), each listed in the record.
- [ ] **AC-2.10** Given the stale `home_spec.rb` example When `CLAUDE.md`'s Commands list is read Then its single-spec example is the README's (AC-2.5).

### Story 3: The check is on record

**As the** maintainer reviewing the PR
**I want** a record of what was checked against what
**So that** I can trust the sweep without repeating it, and see what it couldn't cover

**Acceptance criteria:**

- [ ] **AC-3.1** Given the PR When `docs/specs/020-readme-introduction/verification.md` is read Then it lists the text before the first `##` and every `##` and `###` section of the README, and for each one the number of claims checked and the files, routes or tasks they were checked against. True claims are not listed one by one.
- [ ] **AC-3.2** Given the same When the record is read Then every correction, in `README.md` and in `CLAUDE.md`, is listed with its old text, its new text and the evidence (a file, a route, a task) that the new text is true. For each README correction it gives the term searched for in `CLAUDE.md` and the result, "not repeated" included.
- [ ] **AC-3.3** Given the same When the record is read Then every claim that isn't checkable or is off-limits is listed with the reason, every claim recorded as not refuted is listed with what it was checked against, and every claim on those lists is unchanged in the README.
- [ ] **AC-3.4** Given the same When the record is read Then it has a Gaps list and a Differing names list, each with entries or "none". They include at least the missing "Using Collector" section and the "avatar menu" and "account menu" pair. No issue is opened and `docs/roadmap.md` is unchanged.
- [ ] **AC-3.5** Given the same When the record is read Then every claim left stale is listed with its text, the evidence that it is stale, and the reason: the code is what's wrong, with the spec or ADR that states the intended behaviour, or the maintainer's ruling on it.
- [ ] **AC-3.6** Given the PR's head When `bin/ci` is run Then it passes.
- [ ] **AC-3.7** Given the PR When its description is read Then it closes issue #63, and names the removal of the prose-document checks as a second outcome (decision 7).
- [ ] **AC-3.8** Given the PR When the record is read Then it lists the README's three safety warnings (the first person to reach an instance becomes its admin, in Self-hosting and in Upgrading to accounts; signing in over plain HTTP; never running a plain `bin/kamal deploy` against the published registry) and states for each that its text and its position are unchanged from `origin/main`. A warning that is itself stale goes to the maintainer (Error Scenarios, second row).

### Story 4: The suite checks no prose document

**As the** maintainer
**I want** the suite to stop checking prose documents
**So that** documents are kept true by review, not by pinned phrases (decisions 3 and 7)

**Acceptance criteria:**

- [ ] **AC-4.1** Given the PR's head When `git ls-files spec/readme_spec.rb` and `grep readme_spec .rubocop.yml` are run Then both print nothing.
- [ ] **AC-4.2** Given the PR's head When `bin/rspec spec/image_publishing_spec.rb` is run Then it reports 22 examples and 0 failures: `describe "docs/releasing.md"` and its three examples are gone, the other 20 existing examples are unchanged, and there are two new ones. One, under `describe "compose.yaml"`, expects the file's text to include `COLLECTOR_MTG_ART_MATCHING: "${COLLECTOR_MTG_ART_MATCHING:-}"`. One, under `describe "config/deploy.yml"`, expects the file's text (read raw, since the parsed YAML drops comments) to include `# COLLECTOR_MTG_ART_MATCHING: true`.
- [ ] **AC-4.3** Given the PR's head When `bin/rspec spec/design_system_files_spec.rb` is run Then it reports 4 examples and 0 failures. The examples "documents every new pattern and lists it in the README" and "documents the pattern, its three slots and that it overrides the export (AC-4.1, AC-4.2)" are gone. The first example is named "installs the export's stylesheets, fonts and logos" and keeps only its expectations about the stylesheets, the fonts and the logo images; its expectations about `docs/design-system/`, the skill file and `CLAUDE.md` are gone. The other three examples are unchanged.
- [ ] **AC-4.4** Given the PR's head When `bin/rspec spec/export_format_document_spec.rb spec/export_format_examples_spec.rb` is run Then it reports 25 examples and 0 failures: `describe "the repository around it (AC-4.4)"` and its two examples are gone from the first file, its other nine examples are unchanged, and the second file is unchanged.
- [ ] **AC-4.5** Given `git diff --name-status origin/main...HEAD -- spec` When it is read Then it lists exactly `spec/readme_spec.rb` (deleted), `spec/image_publishing_spec.rb`, `spec/design_system_files_spec.rb` and `spec/export_format_document_spec.rb`, and the suite has 13 fewer examples than at the merge base (15 removed, 2 added; 1,219 becomes 1,206 while the merge base is `3ab9864`).
- [ ] **AC-4.6** Given the PR's head When `grep -rnE '\.md\b|docs/' spec --include='*.rb'` is run Then it prints only: the header comments of `spec/image_publishing_spec.rb`, `spec/export_format_document_spec.rb` and `spec/export_format_examples_spec.rb`; the `.dockerignore` rule list in `spec/image_publishing_spec.rb` (`"/docs"`, `"/CLAUDE.md"`); the describe name `research.md §3` in `spec/models/mtg/collector_line_spec.rb`; and the header comment and the `directory` and `document` lines of `spec/support/export_format_rules.rb`.
- [ ] **AC-4.7** Given the PR's head When `.claude/rules/testing.md` is read Then its list has one new line, after the last ✗ line: "✗ Don't check prose documents (`README.md`, `CLAUDE.md`, the files under `.claude/`, the Markdown and reference files under `docs/`) from RSpec; a document criterion is verified by reading and recorded in the spec's `verification.md`. The export format's document is the one exception (spec 020, decision 7)." Nothing else in that file changes.

## Functional Requirements

### FR-1: The introduction

The introduction is rewritten to describe the application as it is at the PR's head.

**Must:**
- Keep the opening sentence (AC-1.1).
- Name accounts, the collection, the catalog and its source, search, the card scanner and the admin pages (AC-1.2 to AC-1.4).
- Say Collector is pre-1.0 and link the roadmap (AC-1.6).
- Stay one paragraph of at most 130 words (AC-1.7).
- Use the words the application's own pages and the rest of the README use: "collection", "account", "admin", "catalog", "card scanner".

**Must not:**
- Say anything is "not built", or name an open roadmap candidate.
- Call any page public.
- Name a spec number, an ADR or an internal class.
- Promise a date, a release or a future feature. "pre-1.0" is the only version named.

### FR-2: The sweep

Every claim in `README.md` is sorted and compared with the repository at the PR's head.

**Must:**
- Cover every section, including tables, code blocks and their comments.
- Sort each claim as checkable, not checkable, or off-limits, by the glossary.
- Correct each stale claim with the smallest change that makes it true, changing only the words of that claim.
- Leave a claim that isn't checkable or is off-limits unchanged, and record it.
- Record each checkable claim's result as true, stale or not refuted.
- Leave true claims, the headings, their order and the line wrapping unchanged; a corrected line is not re-flowed (AC-2.7).

**Must not:**
- Add documentation for something the README doesn't mention.
- Change application code or configuration to make a claim true.
- Remove a claim because it is hard to check.

### FR-3: The sweep record

`verification.md` holds the sweep record described in Story 3.

**Must:**
- Name each README section and what it was checked against.
- List each correction with old text, new text and evidence.
- List each claim that is not checkable, off-limits or not refuted, with its reason or what it was checked against.
- List each claim left stale, with the evidence and the reason.
- List each gap and each pair of differing names.
- List the three safety warnings, each with its text and position confirmed unchanged.
- Give, for each README correction, the term searched for in `CLAUDE.md` and the result.

**Must not:**
- Record a section as checked without naming what it was checked against.

### FR-4: `CLAUDE.md`

The stale phrase in `CLAUDE.md`'s Project Status is corrected, and a README correction that `CLAUDE.md` repeats is made there too.

**Must:**
- End the Project Status sentence that begins "Feature 002 added" with "and a card search at `/catalog/entries`, which has needed sign-in since accounts (spec 004)." Feature 002's search was public when it was added, so the sentence doesn't say feature 002 built it for signed-in users.
- Keep the rest of the sentence's facts (the catalog core, the MTG extension, the Scryfall ingestion) as they are.
- Replace the single-spec example in the Commands list with the README's corrected one.
- For each other README correction, search `CLAUDE.md` for the corrected command, path, variable or phrase, and change only an occurrence that makes the same claim. This search is not a sweep: nothing else in `CLAUDE.md` is checked.

**Must not:**
- Call the search public or a proof-of-concept.
- Change anything in `CLAUDE.md` that isn't one of those corrections.

### FR-5: The prose-document checks are removed

The examples that check a prose document are removed, and what they checked that wasn't a document is kept.

**Must:**
- Delete `spec/readme_spec.rb` and its line in `.rubocop.yml`.
- Keep its two expectations about `compose.yaml` and `config/deploy.yml` as two new examples in `spec/image_publishing_spec.rb`, asserting the same strings against each file's text (AC-4.2).
- Remove `describe "docs/releasing.md"` from `spec/image_publishing_spec.rb` (AC-4.2).
- Remove the two document examples from `spec/design_system_files_spec.rb`, and from its first example the expectations about documents, keeping the ones about stylesheets, fonts and logo images (AC-4.3).
- Remove `describe "the repository around it (AC-4.4)"` from `spec/export_format_document_spec.rb` (AC-4.4).
- Add the rule to `.claude/rules/testing.md`, so later plans don't add such examples again (AC-4.7).

**Must not:**
- Replace any of them with another check of a document's wording, links, structure or existence.
- Change a past spec's `plan.md` or `verification.md` that names a removed example; they record what was true then.
- Remove or change any other example: the export format's nine and sixteen, the configuration checks and the checks of code files stay as they are.
- Change the documents those examples read (`docs/releasing.md`, the design system's documents, the ADR index).

## Non-Functional Requirements

### Performance

- None. No code runs differently.

### Security

- Neither file gains a secret, a real host name, a real email address or a credential. Examples keep their placeholders (`you@example.com`, `X.Y.Z`, `192.168.0.1`).
- The safety warnings already in the README (the first person to reach an instance becomes its admin; signing in over plain HTTP; never running a plain `bin/kamal deploy` against the published registry) keep their meaning and their prominence. No test pins them once `spec/readme_spec.rb` is gone (decision 3), so the record states for each that its text and position are unchanged (AC-3.8).
- The sweep reads no off-limits file.

### Reliability

- The published image is unaffected. After this PR no example reads the root `README.md` or `CLAUDE.md`, so no edit to either can fail `bin/ci`.
- Past specs' document criteria lose their automated evidence: every spec whose plan added an example removed here. Their documents are not changed here, and nothing in the suite keeps them as they are from now on.

### Testability

- No example is added for the README; the evidence is the sweep record and a passing `bin/ci`. Foundation principle 5 ("new or changed behavior ships with tests") is met because no behaviour changes, and the examples removed tested documents, not behaviour (decisions 3 and 7).
- Each of the two new examples (AC-4.2) is shown to fail by a temporary working-tree edit, reverted afterwards: the Compose value changed to `"true"`, the `deploy.yml` comment line deleted. The failure output is in `verification.md`.

### Roadmap rules

- **Hosted-door rules:** none applies. The spec adopts no source, adds no admin page, adds no setting, and costs an account nothing in storage or background work.
- **One outcome, one PR:** the outcome is "the README says what Collector is today". The `CLAUDE.md` changes are the same false claims in a second file. Removing the suite's prose-document checks is a second outcome, which the spec rules would split into its own spec; the maintainer ruled that it is done here (decisions 3 and 7). The PR closes #63.
- **Export covers it:** no collector-owned data is added, so the export format doesn't change.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The README and the code disagree, and the code is what's wrong (a spec or ADR states the behaviour the README describes; without one, the next row applies) | The README is left as it is and the record lists the claim as left stale, with the evidence. The maintainer decides whether it becomes an issue |
| A correction would need a decision (two readings are possible, the claim is true but misleading by where it sits, or the true text would contradict a ruling in the roadmap) | The claim is left unchanged and put to the maintainer before the PR is marked ready. The record carries the ruling, and the correction if one was ruled |
| A claim can't be checked, or is about an off-limits file | It is left unchanged and listed in the record with the reason |
| An example mixes a document expectation with one about code, configuration or assets (the design system's first example) | Only the document expectations are removed; the example keeps the rest and is renamed to say what it still checks |
| Removing an example leaves a `let`, helper or `require` unused in its file | The unused definition is removed with it, and nothing else in the file changes |
| Something exists and the README doesn't mention it | It is listed in the record as a gap. The README is not extended and no issue is opened |
| A section link's target heading doesn't exist | The link is corrected to the existing heading it meant; no heading is renamed to fit the link |
| The sweep finds nothing stale beyond what this spec already names | The record says so, section by section. The PR changes the introduction, the single-spec example in both files, the `CLAUDE.md` sentence, the four spec files, `.rubocop.yml` and `.claude/rules/testing.md` (Story 4), the memory entries under `.claude/memory/` that record the session's rulings, and adds this spec's `plan.md` and `verification.md` |

## Open Questions

None.

## Out of Scope (Future Considerations)

- A sweep of `CLAUDE.md` like the README's (decision 4).
- A "Using Collector" section (the collection page, adding a card, lots). The README has never had one; the sweep records it as a gap.
- An automated check of any prose document's wording, links or section anchors (decisions 3 and 7).
- The checks that stay (decision 7): the export format's document, schema and examples; the configuration files; the code files. Whether the export format's document should also leave the suite was put to the maintainer, who kept it.
- Making "avatar menu" and "account menu" one name across the README.
- Updating the introduction when catalog search opens to visitors (issue #59) or when export and import land (issues #38 to #40). Those specs change the README themselves.
