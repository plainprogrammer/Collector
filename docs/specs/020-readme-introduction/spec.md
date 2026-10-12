# Feature 020: An Accurate README

**Status:** Draft
**Version:** 1.2.0
**Created:** 2026-10-12
**Last Updated:** 2026-10-12
**Branch:** `020-readme-introduction`
**Issue:** [#63](https://github.com/plainprogrammer/Collector/issues/63)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-12 | Initial draft from issue #63. Three maintainer choices made while specifying: the whole of `README.md` is checked, not only its introduction (decision 1); the introduction says Collector is pre-1.0 and links the roadmap, with no list of unbuilt features (decision 2); the result is checked by hand and recorded, with no automated test (decision 3) |
| 1.1.0 | 2026-10-12 | Maintainer ruling: the same stale phrase in `CLAUDE.md` ("a public card search proof-of-concept") is corrected in this PR (decision 4, Goals, Non-Goals, AC-2.9, FR-4, AC-3.2, Out of Scope). The rest of `CLAUDE.md` is not swept |
| 1.2.0 | 2026-10-12 | Spec review revisions (Opus, Mode A, NEEDS REVISION, three blocking). **Existing test:** `spec/readme_spec.rb` already pins README phrases; it stays, and an expectation is edited only where a correction changes the phrase it pins (decision 3, FR-2, AC-3.6, Testability, Error Scenarios). **Statements left stale:** a statement the code contradicts, or that needs a ruling, may stay and is recorded (Goals, AC-2.1, AC-3.5, FR-3). **Gaps:** recorded only; this PR opens no issue and doesn't change the roadmap (glossary, AC-3.4, decision 6). **Sorting rules:** "claim", "checkable", "not refuted" and "off-limits" are defined so two people sort alike (glossary, FR-2). **`CLAUDE.md`:** a README correction that `CLAUDE.md` repeats is made there too, which covers its copy of the stale `home_spec.rb` example (decision 5, proposed; AC-2.9, FR-4). **Also:** diffs are read as word diffs (AC-2.7, AC-2.9); AC-2.5 is folded into AC-2.2 with the replacement named; AC-1.8 is folded into AC-2.6; AC-2.2 and AC-2.4 cover Kamal aliases, other tools' commands and variables read outside the app; the opening sentence is fixed verbatim (AC-1.1) |

---

## Problem Statement

`README.md` is the first thing a self-hoster or contributor reads, and its first paragraph is wrong. It says "Accounts and collections are not built yet", while accounts, collections of lots, the card scanner and the admin pages all exist. It also calls catalog search "a public card search page", while search has needed sign-in since accounts landed (opening it to visitors is issue #59, not yet built). A reader who believes the introduction concludes that Collector can't hold a collection. `CLAUDE.md`'s Project Status repeats the second claim ("a public card search proof-of-concept at `/catalog/entries`"), which tells every coding agent that works in the repository the same wrong thing.

The introduction went stale because specs since 004 added to the sections below it and none returned to the top. The same can have happened anywhere in the file: one example is already known (`bin/rspec spec/requests/home_spec.rb:5` names a spec file that no longer exists, in both `README.md` and `CLAUDE.md`).

> **Inputs.** This spec is about one file and its repeats in a second, so it names them. The roadmap ([docs/roadmap.md](../../roadmap.md)), the north star ([docs/north-star.md](../../north-star.md)), the existing `spec/readme_spec.rb` and the repository at the PR's head are the fixed inputs.

### Glossary

- **Introduction:** the first paragraph of `README.md`, between the `# Collector` heading and the paragraph that begins "Built with Rails".
- **Claim:** one thing `README.md` says about the application, its commands, files, paths, routes, settings, defaults or behaviour. A sentence, list item, table row, command or code comment is split into its claims, and each is sorted separately.
- **Checkable:** a claim that can be confirmed or refuted by reading tracked files, or by running a command in a checkout with no network, no container runtime and no phone. A figure that a document under `docs/` merely repeats (a download size, a duration) is not checkable. The behaviour of another tool, a browser, a registry or a device is not checkable; the parts of such a claim that name things in this repository are.
- **Stale:** a checkable claim that isn't true of the repository at the PR's head.
- **Not refuted:** the result for a "never", "only" or "nothing" claim (for example "Photos never leave the phone"). It is checked against the code or spec the record names, and recorded as not refuted, not as true.
- **Off-limits:** a tracked file that agents may not read (`.kamal/secrets`). A claim about it is recorded as unchecked for that reason, unless the maintainer checks it.
- **Gap:** something an operator or contributor would need and can't find in the README, noticed while checking a claim. No reverse sweep of the repository is made to find gaps.
- **Sweep record:** the list, in this spec's `verification.md`, of what was checked and what was found, for `README.md` and for the `CLAUDE.md` changes.

### Decisions

1. **The whole README is checked.** The issue names the introduction; the maintainer widened it to every section (2026-10-12).
2. **Pre-1.0, with a link.** The introduction says Collector is pre-1.0 and links the roadmap. It doesn't list what is missing, so it doesn't go stale as each spec lands (maintainer, 2026-10-12).
3. **Checked by hand and recorded; no test is added.** No behaviour changes. `spec/readme_spec.rb` already pins some README phrases (the safety warnings, the image and scanner notes, the art-matching figures); it stays as it is, and an expectation in it is edited only where a correction changes the phrase it pins (maintainer, 2026-10-12, for "no test added"; the rule for the existing file is from review).
4. **`CLAUDE.md`'s phrase is fixed here.** The stale "public card search proof-of-concept" phrase in `CLAUDE.md`'s Project Status is corrected in the same PR. The rest of that file is not swept (maintainer, 2026-10-12).
5. **A README correction that `CLAUDE.md` repeats is made there too.** *Proposed from review, for the maintainer's ruling at approval.* `CLAUDE.md`'s Commands list holds the same stale `home_spec.rb` example. Fixing one copy and knowingly leaving the other makes the two files disagree, so where the sweep corrects a README claim and `CLAUDE.md` states the same claim, `CLAUDE.md` gets the same correction. This is still not a sweep of `CLAUDE.md`.
6. **Gaps are recorded, not filed.** This PR opens no issue and doesn't change `docs/roadmap.md`: a new housekeeping issue is a new roadmap candidate, and the roadmap changes with its issues. The maintainer decides from the record which gaps become candidates. The roadmap's line for #63 is left as it is, as specs 018 and 019 left theirs (from review).

## Goals

- The introduction describes what Collector does today: accounts, a collection of lots, catalog search, the card scanner and the admin pages.
- The introduction makes no claim that something existing isn't built, and no claim that a page is public when it needs sign-in.
- Every checkable claim in `README.md` is true of the repository at the PR's head, except one the record lists as left stale with its reason (AC-3.5).
- `CLAUDE.md` no longer calls catalog search public, and doesn't disagree with a correction made to the README.
- What was checked, what was corrected and what couldn't be checked is on record.

## Non-Goals

- Documenting features the README doesn't mention today. A gap is recorded, not filled.
- Restructuring the README: no section is added, removed, renamed or reordered.
- Rewording claims that are true, including two true claims that name one thing differently ("avatar menu" and "account menu"). Those are recorded.
- Changing the application, its commands or its configuration to match the README.
- A user guide, screenshots or badges.
- Checking the rest of `CLAUDE.md` against the repository.
- Any other document under `docs/` (the roadmap, the design system, the ADRs), except this spec's own folder.
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
- [ ] **AC-1.7** Given the same When the introduction's rendered text is counted (link text, not addresses) Then it is one paragraph of at most 130 words.
- [ ] **AC-1.8** Given the same When the introduction is read Then everything it says Collector does has a section further down the README or a page in the application.

### Story 2: Every claim in the README is true

**As an** operator or contributor following the README
**I want** each command, path, setting and description in it to match the repository
**So that** nothing I'm told to run or expect fails because the README fell behind

**Acceptance criteria:**

- [ ] **AC-2.1** Given the README at the PR's head When each checkable claim is compared with the repository Then none is stale, except a claim the record lists as left stale (AC-3.5).
- [ ] **AC-2.2** Given a command the README tells the reader to run When it is looked up Then a `bin/` script, rake task or `script/` file exists under that name and takes the arguments shown; a path argument names an existing file, and a `:N` suffix a line inside an example; a `bin/kamal <alias>` is defined under `aliases:` in `config/deploy.yml`. For a command from another tool (`docker compose`, `podman`, `openssl`), only the parts that name things in this repository (a service, a file, a task) are checked.
- [ ] **AC-2.3** Given a file, directory, route or URL path the README names When it is looked up Then it exists in the repository or is served by a route in `config/routes.rb`. A path that is created at run time (under `storage/`, `tmp/`, `log/`, `vendor/ocr/` or the reader's home directory) is checked against the code that writes it.
- [ ] **AC-2.4** Given an environment variable the README names When it is looked up Then something tracked in the repository reads or names it, or the record cites the framework or tool that reads it (Rails, Puma, Kamal); and the default and accepted values the README gives are the ones the code uses.
- [ ] **AC-2.5** Given the README's example of running a single spec When it is read Then it is `bin/rspec spec/requests/health_check_spec.rb:5`.
- [ ] **AC-2.6** Given every link in `README.md`, the introduction's included When it is followed Then a section link lands on an existing heading and a relative link names an existing file.
- [ ] **AC-2.7** Given `git diff --word-diff main -- README.md` When it is read Then outside the introduction every changed word belongs to a correction listed in the record, and no paragraph is re-wrapped.
- [ ] **AC-2.8** Given the README at the PR's head When its headings are compared with `main`'s Then they are the same headings in the same order.
- [ ] **AC-2.9** Given `CLAUDE.md` at the PR's head When its Project Status is read Then the sentence beginning "Feature 002 added" no longer contains "public" or "proof-of-concept", and says the card search at `/catalog/entries` is for signed-in users. When `git diff --word-diff main -- CLAUDE.md` is read Then every changed word is inside that sentence or belongs to a README correction that `CLAUDE.md` repeats (decision 5), each listed in the record.
- [ ] **AC-2.10** Given the stale `home_spec.rb` example When `CLAUDE.md`'s Commands list is read Then its single-spec example is the README's (AC-2.5).

### Story 3: The check is on record

**As the** maintainer reviewing the PR
**I want** a record of what was checked against what
**So that** I can trust the sweep without repeating it, and see what it couldn't cover

**Acceptance criteria:**

- [ ] **AC-3.1** Given the PR When `docs/specs/020-readme-introduction/verification.md` is read Then it lists the text before the first `##` and every `##` and `###` section of the README, and for each one what its claims were checked against.
- [ ] **AC-3.2** Given the same When the record is read Then every correction, in `README.md` and in `CLAUDE.md`, is listed with its old text, its new text and the evidence (a file, a route, a task) that the new text is true.
- [ ] **AC-3.3** Given the same When the record is read Then every claim that isn't checkable or is off-limits is listed with the reason, every "never", "only" or "nothing" claim is listed as not refuted with what it was checked against, and all of them are unchanged in the README.
- [ ] **AC-3.4** Given the same When the record is read Then every gap noticed is listed, and so is every pair of true claims that name one thing differently. No issue is opened and `docs/roadmap.md` is unchanged.
- [ ] **AC-3.5** Given the same When the record is read Then every claim left stale is listed with its text, the evidence that it is stale, and the reason: the code is what's wrong, or the maintainer's ruling on it.
- [ ] **AC-3.6** Given the PR's head When `bin/ci` is run Then it passes, and `spec/readme_spec.rb` has the same examples as on `main`, with an expectation changed only where the record lists a correction to the phrase it pins.
- [ ] **AC-3.7** Given the PR When its description is read Then it closes issue #63.

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
- Update an expectation in `spec/readme_spec.rb` to the corrected text, in the same commit, when a correction changes a phrase it pins.
- Leave a claim that isn't checkable or is off-limits unchanged, and record it.
- Leave true claims, the headings, their order and the line wrapping of untouched paragraphs unchanged.

**Must not:**
- Add documentation for something the README doesn't mention.
- Change application code or configuration to make a claim true.
- Remove a claim because it is hard to check.
- Remove an example from `spec/readme_spec.rb`, or add one.

### FR-3: The sweep record

`verification.md` holds the sweep record described in Story 3.

**Must:**
- Name each README section and what it was checked against.
- List each correction with old text, new text and evidence.
- List each claim that is not checkable, off-limits or not refuted, with its reason or what it was checked against.
- List each claim left stale, with the evidence and the reason.
- List each gap and each pair of inconsistent names.

**Must not:**
- Record a section as checked without naming what it was checked against.

### FR-4: `CLAUDE.md`

The stale phrase in `CLAUDE.md`'s Project Status is corrected, and a README correction that `CLAUDE.md` repeats is made there too.

**Must:**
- Say the card search at `/catalog/entries` is for signed-in users, without rewriting history: feature 002's search was public when it was added, and accounts (spec 004) put it behind sign-in.
- Keep the rest of the sentence's facts (the catalog core, the MTG extension, the Scryfall ingestion) as they are.
- Replace the single-spec example in the Commands list with the README's corrected one.
- Apply any other README correction to the same claim where `CLAUDE.md` states it.

**Must not:**
- Call the search public or a proof-of-concept.
- Change anything in `CLAUDE.md` that isn't one of those corrections.

## Non-Functional Requirements

### Performance

- None. No code runs differently.

### Security

- Neither file gains a secret, a real host name, a real email address or a credential. Examples keep their placeholders (`you@example.com`, `X.Y.Z`, `192.168.0.1`).
- The safety warnings already in the README (the first person to reach an instance becomes its admin; signing in over plain HTTP; never running a plain `bin/kamal deploy` against the published registry) keep their meaning and their prominence. `spec/readme_spec.rb` pins them and keeps doing so.
- The sweep reads no off-limits file.

### Reliability

- The published image is unaffected. `bin/ci` reads `README.md` through `spec/readme_spec.rb` and `CLAUDE.md` through `spec/design_system_files_spec.rb`; both keep passing.

### Testability

- No example is added. The evidence is the sweep record and a passing `bin/ci`. Foundation principle 5 ("new or changed behavior ships with tests") is met because no behaviour changes.

### Roadmap rules

- **Hosted-door rules:** none applies. The spec adopts no source, adds no admin page, adds no setting, and costs an account nothing in storage or background work.
- **One outcome, one PR:** the outcome is "the README says what Collector is today". The `CLAUDE.md` changes are the same false claims in a second file. The PR closes #63.
- **Export covers it:** no collector-owned data is added, so the export format doesn't change.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The README and the code disagree, and the code is what's wrong (the README states the intended behaviour) | The README is left as it is and the record lists the claim as left stale, with the evidence. The maintainer decides whether it becomes an issue |
| A correction would need a decision (two readings are possible, the claim is true but misleading by where it sits, or the true text would contradict a ruling in the roadmap) | The claim is left unchanged and put to the maintainer before the PR is marked ready. The record carries the ruling, and the correction if one was ruled |
| A claim can't be checked, or is about an off-limits file | It is left unchanged and listed in the record with the reason |
| A correction changes text that `spec/readme_spec.rb` expects | The expectation is updated to the corrected text in the same commit; no example is removed; the record lists it |
| Something exists and the README doesn't mention it | It is listed in the record as a gap. The README is not extended and no issue is opened |
| A section link's target heading doesn't exist | The link is corrected to the existing heading it meant; no heading is renamed to fit the link |
| The sweep finds nothing stale beyond what this spec already names | The record says so, section by section. The PR changes the introduction, the single-spec example in both files and the `CLAUDE.md` sentence |

## Open Questions

None. Decision 5 is a proposal the maintainer rules on when approving this spec; if it is refused, AC-2.10 and FR-4's last two "Must" lines are removed and `CLAUDE.md`'s copy of the example is named in Out of Scope.

## Out of Scope (Future Considerations)

- A sweep of `CLAUDE.md` like the README's (decision 4).
- A "Using Collector" section (the collection page, adding a card, lots). The README has never had one; the sweep records it as a gap.
- An automated check that the README's links and section anchors resolve (decision 3).
- Making "avatar menu" and "account menu" one name across the README.
- Updating the introduction when catalog search opens to visitors (issue #59) or when export and import land (issues #38 to #40). Those specs change the README themselves.
