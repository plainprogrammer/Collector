# Feature 020: An Accurate README

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-10-12
**Last Updated:** 2026-10-12
**Branch:** `020-readme-introduction`
**Issue:** [#63](https://github.com/plainprogrammer/Collector/issues/63)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-12 | Initial draft from issue #63. Three maintainer choices made while specifying: the whole of `README.md` is checked, not only its introduction (decision 1); the introduction says Collector is pre-1.0 and links the roadmap, with no list of unbuilt features (decision 2); the result is checked by hand and recorded, with no automated test (decision 3) |

---

## Problem Statement

`README.md` is the first thing a self-hoster or contributor reads, and its first paragraph is wrong. It says "Accounts and collections are not built yet", while accounts, collections of lots, the card scanner and the admin pages all exist. It also calls catalog search "a public card search page", while search has needed sign-in since accounts landed (opening it to visitors is issue #59, not yet built). A reader who believes the introduction concludes that Collector can't hold a collection.

The introduction went stale because specs 004 to 019 each added to the sections below it and none returned to the top. The same can have happened anywhere in the file: one example is already known (`bin/rspec spec/requests/home_spec.rb:5` names a spec file that no longer exists).

> **Inputs.** This spec is about one file, so it names it. The roadmap ([docs/roadmap.md](../../roadmap.md)), the north star ([docs/north-star.md](../../north-star.md)) and the repository at the PR's head are the fixed inputs that the README is checked against.

### Glossary

- **Introduction:** the first paragraph of `README.md`, between the `# Collector` heading and the paragraph that begins "Built with Rails".
- **Statement:** a sentence, list item, table row, code comment or command in `README.md` that says something about the application, its commands, files, paths, routes, settings, defaults or behaviour.
- **Stale:** a statement that isn't true of the repository at the PR's head.
- **Checkable:** a statement that can be confirmed or refuted from the repository alone (its code, configuration, tasks, routes and documents), without running a deployment, a phone or an external service.
- **Sweep record:** the list, in this spec's `verification.md`, of what was checked and what was found.

### Decisions

1. **The whole README is checked.** The issue names the introduction; the maintainer widened it to every section (2026-10-12).
2. **Pre-1.0, with a link.** The introduction says Collector is pre-1.0 and links the roadmap. It doesn't list what is missing, so it doesn't go stale as each spec lands (maintainer, 2026-10-12).
3. **Checked by hand and recorded.** No automated test is added: no behaviour changes, and a test of the README's wording would fail on every honest edit (maintainer, 2026-10-12).

## Goals

- The introduction describes what Collector does today: accounts, a collection of lots, catalog search, the card scanner and the admin pages.
- The introduction makes no claim that something existing isn't built, and no claim that a page is public when it needs sign-in.
- Every checkable statement in `README.md` is true of the repository at the PR's head.
- What was checked, what was corrected and what couldn't be checked is on record.

## Non-Goals

- Documenting features the README doesn't mention today. A gap is recorded, not filled (FR-3).
- Restructuring the README: no section is added, removed, renamed or reordered.
- Rewording statements that are true.
- Changing the application, its commands or its configuration to match the README. Where the README and the code disagree and the code is what's wrong, the README isn't changed and an issue is opened (Error Scenarios).
- A user guide, screenshots or badges.
- Any other document: `CLAUDE.md`, `docs/`, the design system, the ADRs.

## Users and Context

**Primary users:** someone deciding whether to self-host Collector, reading the repository's front page on GitHub.
**Secondary users:** an operator following the self-hosting sections; a contributor setting up a checkout; the maintainer.
**Usage context:** read top to bottom once, then returned to by section. The introduction is often the only part read.
**User mental model:** the README is the truth about the project today. A reader doesn't cross-check it against the code.

## User Stories

### Story 1: The introduction says what Collector does today

**As a** person deciding whether to self-host Collector
**I want** the README's first paragraph to say what the app does now
**So that** I can tell in one read whether it can hold my collection

**Acceptance criteria:**

- [ ] **AC-1.1** Given the README at the PR's head When the introduction is read Then it still opens by saying Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering.
- [ ] **AC-1.2** Given the same When the introduction is read Then it says each person has their own account and their own collection.
- [ ] **AC-1.3** Given the same When the introduction is read Then it says cards are found in a catalog fed from Scryfall's bulk data and added to the collection, both by searching and with the card scanner.
- [ ] **AC-1.4** Given the same When the introduction is read Then it says an admin manages users and sign-up, the catalog's refreshes and the background jobs.
- [ ] **AC-1.5** Given the same When the introduction is searched Then it contains neither "not built" nor "public", and no sentence says that accounts, collections, the scanner or the admin pages are missing.
- [ ] **AC-1.6** Given the same When the introduction is read Then it says Collector is pre-1.0 and links `docs/roadmap.md`, and it names no feature as unbuilt.
- [ ] **AC-1.7** Given the same When the introduction is measured Then it is one paragraph of at most 130 words.
- [ ] **AC-1.8** Given the same When each link in the introduction is followed Then a section link lands on a heading that exists in `README.md`, and a file link names a file that exists in the repository.
- [ ] **AC-1.9** Given the same When the introduction is read Then every feature it names has a section further down the README or a page in the application, and it names no feature on the roadmap that isn't built (exporting or importing a collection, locations, typed entry, comics).

### Story 2: Every statement in the README is true

**As an** operator or contributor following the README
**I want** each command, path, setting and description in it to match the repository
**So that** nothing I'm told to run or expect fails because the README fell behind

**Acceptance criteria:**

- [ ] **AC-2.1** Given the README at the PR's head When each checkable statement is compared with the repository Then none is stale.
- [ ] **AC-2.2** Given a command the README tells the reader to run (a `bin/` script, a rake task, a `script/` file) When it is looked up Then the script, task or file exists under that name, and takes the arguments the README shows.
- [ ] **AC-2.3** Given a file, directory, route or URL path the README names When it is looked up Then it exists in the repository or is served by a route in `config/routes.rb`. A path that is created at run time (under `storage/`, `tmp/`, `log/` or the reader's home directory) is checked against the code that writes it.
- [ ] **AC-2.4** Given an environment variable the README names When it is looked up Then the application, `compose.yaml` or `config/deploy.yml` reads it, and the default and accepted values the README gives are the ones the code uses.
- [ ] **AC-2.5** Given the example command `bin/rspec spec/requests/home_spec.rb:5` When the README is read Then the example names a spec file that exists.
- [ ] **AC-2.6** Given every link in `README.md` When it is followed Then a section link lands on an existing heading and a relative link names an existing file.
- [ ] **AC-2.7** Given a statement that was true before this PR When the README's diff is read Then that statement is unchanged, apart from the introduction, which is rewritten as a whole.
- [ ] **AC-2.8** Given the README at the PR's head When its headings are compared with `main`'s Then they are the same headings in the same order.

### Story 3: The check is on record

**As the** maintainer reviewing the PR
**I want** a record of what was checked against what
**So that** I can trust the sweep without repeating it, and see what it couldn't cover

**Acceptance criteria:**

- [ ] **AC-3.1** Given the PR When `docs/specs/020-readme-introduction/verification.md` is read Then it lists every `##` and `###` section of the README, and for each one what its statements were checked against.
- [ ] **AC-3.2** Given the same When the record is read Then every stale statement found is listed with its old text, its new text and the evidence (a file, a route, a task) that the new text is true.
- [ ] **AC-3.3** Given the same When the record is read Then every statement that isn't checkable is listed with the reason (for example: a download size, the steps on an iPhone, the behaviour of a registry), and is left unchanged in the README.
- [ ] **AC-3.4** Given the same When the record is read Then every gap found (something that exists and the README doesn't mention) is listed, each with the issue opened for it or the reason none was opened.
- [ ] **AC-3.5** Given the PR When its description is read Then it closes issue #63.
- [ ] **AC-3.6** Given the PR's head When `bin/ci` is run Then it passes.

## Functional Requirements

### FR-1: The introduction

The introduction is rewritten to describe the application as it is at the PR's head.

**Must:**
- Keep the opening description of what Collector is (AC-1.1).
- Name accounts, the collection, the catalog and its source, search, the card scanner and the admin pages (AC-1.2 to AC-1.4).
- Say Collector is pre-1.0 and link the roadmap (AC-1.6).
- Stay one paragraph of at most 130 words (AC-1.7).
- Use the words the application's own pages and the rest of the README use: "collection", "account", "admin", "catalog", "card scanner".

**Must not:**
- Say anything is "not built", or list unbuilt features.
- Call any page public.
- Name a spec number, an ADR or an internal class.
- Promise a date, a version or a future feature.

### FR-2: The sweep

Every statement in `README.md` is compared with the repository at the PR's head.

**Must:**
- Cover every section, including tables, code blocks and their comments.
- Correct each stale checkable statement with the smallest change that makes it true.
- Leave a statement that isn't checkable unchanged, and record it.
- Leave true statements, the headings and their order unchanged.

**Must not:**
- Add documentation for something the README doesn't mention.
- Change application code, configuration or another document to make a statement true.
- Remove a statement because it is hard to check.

### FR-3: The sweep record

`verification.md` holds the sweep record described in Story 3.

**Must:**
- Name each README section and what it was checked against.
- List each correction with old text, new text and evidence.
- List each uncheckable statement with its reason.
- List each gap, with its issue or the reason there is none.

**Must not:**
- Record a section as checked without naming what it was checked against.

## Non-Functional Requirements

### Performance

- None. No code runs differently.

### Security

- The README must not gain a secret, a real host name, a real email address or a credential. Examples keep their placeholders (`you@example.com`, `X.Y.Z`, `192.168.0.1`).
- The safety warnings already in the README (the first person to reach an instance becomes its admin; signing in over plain HTTP; never running a plain `bin/kamal deploy` against the published registry) keep their meaning and their prominence.

### Reliability

- The published image is unaffected: `README.md` is documentation and no build step reads it.

### Roadmap rules

- **Hosted-door rules:** none applies. The spec adopts no source, adds no admin page, adds no setting, and costs an account nothing in storage or background work.
- **One outcome, one PR:** the outcome is "the README is true". The PR closes #63.
- **Export covers it:** no collector-owned data is added, so the export format doesn't change.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The README and the code disagree, and the code is what's wrong (the README states the intended behaviour) | The README is left as it is, an issue is opened for the code, and the record lists the statement with the issue |
| A correction would need a decision (two readings of the code are possible, or the true statement would contradict a ruling in the roadmap) | The statement is left unchanged and put to the maintainer before the PR is marked ready; the record carries the ruling |
| A statement can't be checked from the repository | It is left unchanged and listed in the record with the reason |
| A feature exists and the README doesn't mention it | It is listed in the record as a gap, with an issue if it matters to an operator or contributor; the README is not extended |
| A section link's target heading doesn't exist | The link is corrected to the existing heading it meant; no heading is renamed to fit the link |
| The sweep finds nothing stale outside the introduction | The record says so, section by section; the PR changes the introduction alone |

## Open Questions

None.

## Out of Scope (Future Considerations)

- `CLAUDE.md`'s Project Status repeats "a public card search proof-of-concept". It is the same stale phrase in a different file, and is left for a separate change.
- A "Using Collector" section (the collection page, adding a card, lots). The README has never had one; the sweep records it as a gap.
- An automated check that the README's links and section anchors resolve (decision 3 rules it out here).
- Updating the introduction when catalog search opens to visitors (issue #59) or when export and import land (issues #38 to #40). Those specs change the README themselves.
