# Feature 027: Area Docs Hold the Current Architecture, Starting with Catalog Operations

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-10-15
**Last Updated:** 2026-10-15
**Branch:** `027-architecture-area-docs`
**Issue:** none yet; opened with the pull request (FR-9)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-15 | Initial draft from the maintainer's rulings of 2026-10-15 (R1–R7) and the documentation survey of the same day. Splits the work into three slices and specifies the first (decision D1); YARD is slice B |

---

## Problem Statement

Collector's current architecture has no home. Each feature is written as a spec and a plan, and the truth then drifts across three places:

- **Specs amended in place.** Spec 002 (v1.2.0–v1.4.0) and spec 015 (v1.2.0–v1.3.1) were edited for issues #60, #61, #73, #74, #78, #79, #80 and #81, so a reader can't tell what a spec promised when it shipped from what was bolted on later.
- **Specs superseded silently.** Other features supersede forward and leave the old spec as it was: spec 002 still says "search is public" (its Non-Goals and FR-7), which spec 004 (sign-in) and spec 023 (an operator setting) changed. Nothing in spec 002 says so.
- **CLAUDE.md as the de facto architecture doc.** Its "Non-obvious Facts" section is 1,614 of its 2,312 words. One bullet, "Admin catalog and jobs", is 714 words: it compresses specs 002, 015 and 024 and issues #60, #73, #74, #78–#81 and #84 into a single paragraph that every session loads, and spec 024's AC-3.3 had to require hand-editing it.

Plans are the bulk of the record and are read once. `docs/specs/` holds 24 folders and about 54,400 lines; the 23 `plan.md` files are 41,473 of them (75%), mostly code in fences. Outside their own folders plans are mentioned 7 times, all in `.claude/memory/`, and none as a source of a rule. Code and tests, by contrast, cite specs at the level of numbered criteria (333 lines naming a spec and 318 citing an AC or FR in `app`, `lib`, `config`, `bin`, `script` and `db`; 152 and 542 in `spec/`), so spec ids and criterion numbers must stay stable forever.

The maintainer ruled on 2026-10-15 (R1–R7 below) that the current truth moves into one doc per subsystem, specs freeze as history once a doc covers them, plans are retired from the tree after their feature merges, and CLAUDE.md is slimmed to what an agent needs before it knows where to look. This spec delivers the structure and rules, and proves them on one area: catalog operations.

### Glossary

- **Area doc**: `docs/architecture/<area>.md`, the current truth about one subsystem: its glossary, invariants, state rules, named constants with their reasons, and the decisions not in an ADR, each linked to the spec, ADR or issue behind it.
- **Area**: a subsystem with (or due) an area doc. The list is in `docs/architecture/README.md` (FR-1).
- **Distil**: write what a spec, its plan and the issues fixed after it established into the area doc of each area the spec belongs to, so that the area doc alone states the current rule.
- **Covers**: an area doc covers a spec, or a named part of it (an FR, a story, a section), when everything that part established and that is still true is stated in the area doc, and everything later changed is stated in its changed form.
- **Frozen spec**: a spec, or a named part of one, that an area doc covers. A frozen part is a historical record of what was promised and shipped; later changes go to the area doc (R3).
- **Specs index**: `docs/specs/README.md`, the list of every spec folder with its status, areas, plan state and supersession links (R4).
- **Retire a plan**: delete a `plan.md` from the tree in its own commit after the feature's pull request has merged, and leave a pointer from which the plan can be read back from history (R6).
- **Retirement pointer**: the line "Plan retired in `<sha>`; read it with `git show <sha>^:docs/specs/NNN-<slug>/plan.md`", where `<sha>` is the commit that deleted the plan.
- **Distillation step**: the step, run after `sdd-superpowers:session-wrap`, that distils a finished feature into area docs (and ADRs where a decision has lasting weight), and, once the feature's pull request has merged, retires its plan (R1, R6; decision D6).

### Rulings (maintainer, 2026-10-15)

These are settled and not re-asked.

- **R1. Distil at the end of work.** When a feature is finished, its spec and plan are distilled into area docs, and into ADRs where a decision has lasting weight.
- **R2. Area docs.** `docs/architecture/<area>.md`, one per subsystem, each holding the current truth: glossary, invariants, state rules, named constants with their reasons, and decisions not in an ADR, with links to the specs and ADRs behind them. They are the up-to-date source. Candidate areas: catalog operations, catalog core, collection and lots, scanner, tenancy and accounts, release and deploy.
- **R3. Specs freeze.** Once an area doc covers a spec, the spec is a frozen historical record. Later changes, issue fixes included, update the area doc, not the old spec.
- **R4. Specs index.** `docs/specs/README.md` lists each spec's status and area, with "superseded by" and "supersedes" links in both directions.
- **R5. Slim CLAUDE.md.** The subsystem paragraphs of "Non-obvious Facts" move into area docs and leave short pointers. CLAUDE.md keeps what an agent needs before it knows where to look: commands, worktree and dev-port facts, off-limits paths, spec tags.
- **R6. Retiring plans.** Retiring a plan is a step of a process that follows `session-wrap`, where other learnings are distilled too. At that step `plan.md` is deleted in a commit after the feature's pull request has merged, and the spec and the index get the retirement pointer. History is kept because **merge commits stay the rule** for pull requests; that rule is written down where the git convention lives.
- **R7. Adopt YARD** as the documentation format for Ruby code, with the area docs, and possibly the ADRs, linked into its output. The spec that adopts it decides its shape; its ADR is expected as 0023.

### Decisions

**D1. Three slices; this spec is slice A; YARD is not in it.**

| Slice | Outcome in one sentence |
|---|---|
| **A (this spec, 027)** | A reader finds the current rules of catalog operations in one area doc, and the index, the freezing rule and the distillation step keep every later feature's docs current the same way. |
| **B: adopt YARD** | A developer generates browsable API documentation for the Ruby code, with the area docs (and the ADRs, if its spec so decides) linked in, without anything generated being committed or shipped in the image; ADR 0023 records the choice. |
| **C1–C7: back-fill one area per PR** | Each remaining area (decision D2) gets its area doc, its CLAUDE.md paragraphs become pointers, the specs it covers freeze in the index, and the plans of specs that are now wholly frozen are retired. One candidate per area: catalog core, collection and lots, tenancy and accounts, scanner, data portability, release and deploy, development environment. |

Why YARD is not in slice A: it is a separate outcome (a reader of the Ruby API, not of the architecture) with its own gem, configuration, binstub, ignore rules and ADR, and it needs a code review and a `bin/ci` decision that the documentation rules don't. Area docs are useful on GitHub and in an editor without it, and the value of linking them into YARD grows with the number of area docs, which slice C supplies. Slice A only has to keep the door open: area docs are plain Markdown with relative links and no front matter that YARD would render (NFR "Compatibility"). The shape slice B should start from is under Out of Scope.

Why slice A isn't split further: the index, the freezing rule and the distillation step are only checkable when one area doc exists to freeze specs against and one plan exists to retire, and the pilot is only safe to write when the rules saying how later changes reach it exist. Each part alone leaves `main` with a rule nobody follows or a doc nobody maintains.

**D2. The area list.** R2's six candidates, plus two the survey of `docs/specs/` needs, with the initial assignment of every spec. The index (FR-3) is built from this table; the author of each slice C may move a spec between areas by editing the index and saying so in that slice's spec.

| Area (file) | Specs, or parts of them | Existing reference doc it links to |
|---|---|---|
| Catalog operations (`catalog-operations.md`) | 002 FR-3–FR-6 and their Error Scenarios rows; 011 FR-2 (the art build's run, not the fingerprint); 015 (all); 024 (all) | none |
| Catalog core (`catalog-core.md`) | 002 FR-1, FR-2, FR-7–FR-10; 016; 018; 019; 023 | none |
| Collection and lots (`collection-and-lots.md`) | 004 (collection and adding cards); 006; 021 | `docs/design-system/` |
| Tenancy and accounts (`tenancy-and-accounts.md`) | 004 (accounts, users, admin users) | none |
| Scanner (`scanner.md`) | 005; 007; 008; 009; 010; 011 (all but its FR-2's art build run) | none |
| Data portability (`data-portability.md`) | 017; 022 | `docs/export-format/README.md` |
| Release and deploy (`release-and-deploy.md`) | 001 (container, Compose, Kamal); 012; 013; 020 | `docs/releasing.md` |
| Development environment (`development-environment.md`) | 001 (stack, CI, hooks); 003; 014 | none |

The design system keeps `docs/design-system/` as its reference (its files are replaced wholesale by re-export, CLAUDE.md "UI and design system"); it gets no area doc, and the index names it for spec 004's design-system part.

**D3. Freezing is per part.** A spec is frozen whole when every part of it is covered, and frozen in part otherwise; the index says which parts (FR-3). This matters now for spec 002, whose refresh parts the pilot covers and whose search parts wait for catalog core. Until a part is covered, it follows today's practice (`.claude/memory/edit-specs-your-change-makes-stale.md`: edit it with a patch or minor version bump and a changelog line).

**D4. What may still change in a frozen spec.** Only three things, each in a commit of its own whose message names this rule:

1. a **frozen line** under its header: "Frozen: the current rules are in [`<area doc>`](…) (parts: …); see the [specs index](../README.md)". One line per spec, naming every area doc that covers it.
2. the **retirement pointer**, under the frozen line, once its plan is retired.
3. **links to its own retired plan** in the same folder (`spec.md`, `verification.md`, `research.md`), rewritten as plain text that names the retirement pointer, so no link is left broken.

Nothing else: no typo fixes, no "superseded" notes, no version bump. Supersession is recorded in the index only (R4), so a frozen spec reads as it did when it shipped.

**D5. Area doc shape.** Every area doc has these sections, in this order, and leaves a section out only by saying "None." under its heading: **Scope** (what the area covers and where its edges are, naming neighbouring areas); **Glossary**; **Invariants** (statements that always hold); **States and transitions** (for each stateful thing: its states, what moves it between them, what a reader sees); **Named constants** (a table of name, value, where it is defined, and why that value, each row with its source); **Decisions not in an ADR** (each with its source); **Sources** (every spec part, ADR and issue the doc distils, with links); **Distillation log** (one row per distillation: date, what was distilled, the pull request). Each statement that came from a spec criterion, ADR or issue names it inline (for example "(spec 015 AC-2.16; #60)"), so code comments that cite spec criteria lead to the area doc through the index and back.

**D6. Where the distillation step lives: a project skill, offered after `session-wrap` through the integrations manifest.** `session-wrap` is a plugin skill and can't be edited here. Of the three places R6 allows:

- A **steering file** doesn't reach it: `session-wrap`'s skill file has no steering step (checked 2026-10-15; only `sdd-brainstorm`, `sdd-specify`, `sdd-plan`, `sdd-review`, `sdd-execute`, `sdd-init` and `using-git` mention `loaded-by` files).
- An **`sdd-integrations` row** is the plugin's own mechanism for "when this SDD skill completes, offer that custom skill" (`.claude/integrations.md`, empty today), but a row needs a skill to name.
- So: a project skill, `.claude/skills/distill-feature/SKILL.md`, holding the step, and a row in `.claude/integrations.md` with `session-wrap` as its trigger. The skill runs in either of two states, which it tells apart by whether the feature's pull request has merged: **before the merge** it distils the feature into area docs (and proposes ADRs), and records the plan's retirement as owed; **after the merge** it retires the plan (decision D7). The skill is readable by any agent, and the row makes the offer automatic without editing the plugin.

The steering file is still added for the skills that do load steering (FR-6), so that brainstorm, specify, plan and review read the area docs first.

**D7. Retiring a plan takes two commits.** The pointer names the commit that deleted the plan, so it can't be in that commit: the first commit deletes `plan.md` (and nothing else), the second adds the pointer to the spec and the index and rewrites the folder's links to the plan (D4). Both land through a pull request that is merged with a merge commit, so the deleting commit stays in `main`'s history and `git show <sha>^:…` keeps working; a squash or rebase merge would lose the sha, which is why R6 depends on merge commits.

**D8. No RSpec check of the area docs.** `.claude/rules/testing.md` forbids checking prose documents from RSpec; the export format is the one exception because it is a contract with files outside the app. An area doc describes the code rather than binding it, so its constants and statements are verified by reading against the code at the pull request's head and recorded in `verification.md` (AC-1.3). A checked constants table was considered and rejected for that reason; a later spec may argue it as a second exception.

**D9. No ADR in this slice.** The documentation rules are a process for this repository, not a decision about the application's architecture, and they live in the two README files that state them (FR-1, FR-3), as the ADR conventions live in `docs/adr/README.md`. The pilot distils existing decisions and makes none of its own, so it needs no ADR either. ADR 0023 (YARD) is expected with slice B and is listed as expected now (FR-8); if another ADR merges first, it takes the next free number, as `docs/adr/README.md` says.

## Goals

- `docs/architecture/catalog-operations.md` states the current rules of catalog operations completely enough that CLAUDE.md's 714-word "Admin catalog and jobs" bullet becomes a pointer of at most 60 words.
- Every spec folder appears in `docs/specs/README.md` with its status, areas, plan state and supersession links in both directions.
- The rules for area docs, frozen specs and plan retirement are written where agents and the SDD skills read them, and the distillation step is offered after every `session-wrap`.
- The merge-commit rule is written in `docs/git-convention.md`.

## Non-Goals

- Adopting YARD (slice B).
- Area docs for any area other than catalog operations, or moving any CLAUDE.md bullet other than "Admin catalog and jobs" (slice C).
- Retiring plans other than those the pilot freezes whole (Open Decision 2).
- Changing any application code, test or configuration. This is a documentation and agent-process change only.
- Renumbering or renaming any spec, criterion or ADR, or editing the code comments that cite them.

## Users and Context

**Primary users:** the maintainer and the agents (Claude Code sessions and subagents) who specify, plan, implement and fix Collector.
**Secondary users:** contributors and self-hosters reading the repository on GitHub.
**Usage context:** before changing a subsystem, a reader needs its current rules; today they reconstruct them from CLAUDE.md, the spec's changelog and later specs. After a feature or fix, the author needs to know which document to update.
**User mental model:** a spec says what one feature promised; an ADR says why a lasting choice was made; an area doc says how the subsystem works now; CLAUDE.md says where to look.

## User Stories

All criteria are verified by reading at the pull request's head and recorded in `verification.md`, per `.claude/rules/testing.md`; where a criterion names a command, its output is recorded too.

### Story 1: The current rules of catalog operations are in one place

**As an** agent about to change the catalog refresh, the art build or the admin pages
**I want** one document that states their current rules
**So that** I don't reconstruct them from four specs, nine issues and a 714-word paragraph

**Acceptance criteria:**

- [ ] **AC-1.1** Given `docs/architecture/catalog-operations.md` at the head When its headings are read Then it has the D5 sections in the D5 order, each with content or "None."
- [ ] **AC-1.2** Given the "Admin catalog and jobs" bullet of CLAUDE.md at the merge base When each of its statements is looked up in the area doc Then every statement is there (in the area doc's own words), or `verification.md` records it as left out with a reason (for example, no longer true at the head); the lookup is recorded statement by statement
- [ ] **AC-1.3** Given the area doc's Named constants table When each row is compared with its definition in the code at the head Then name, value and file match for every row, and the table holds at least `Catalog::RefreshRun::STALL_AFTER`, `Catalog::RefreshRun::JOB_ENDED_GRACE`, `Catalog::RefreshJob::LOCK_FOR`, `MTG::ArtBuild::STALE_AFTER`, `MTG::ArtBuild::JOB_ENDED_GRACE`, `MTG::Art::Build::BEAT_EVERY`, `MTG::Scryfall::Client::MAX_BACK_OFF`, `Catalog::RateLimitRetry::SHORTEST_WAIT`, `Catalog::RateLimitRetry::LONGEST_WAIT` and `Catalog::RateLimitRetry::MAX_RETRIES`, each with its reason
- [ ] **AC-1.4** Given spec 015's Glossary, Functional Requirements and Error Scenarios, spec 024's Decisions, spec 002's FR-3–FR-6 and their Error Scenarios rows, and spec 011's FR-2 as far as it concerns the build's run When each is compared with the area doc Then each requirement or decision still true at the head is stated, each one changed since is stated in its changed form with the issue or spec that changed it, and `verification.md` lists the comparison item by item
- [ ] **AC-1.5** Given the area doc's Sources section When it is read Then it links specs 002, 011, 015 and 024 (naming the parts), ADRs 0014, 0015 and 0018, and issues #60, #61, #73, #74, #78, #79, #80, #81 and #84, and every link resolves to a file or issue that exists
- [ ] **AC-1.6** Given the area doc When it is read Then it names no collectible in a statement about the core (`Catalog::`) and keeps MTG-specific rules (the art build, the Scryfall client) in statements that name `MTG::`, as CLAUDE.md's bullet and `spec/admin_catalog_core_spec.rb` do
- [ ] **AC-1.7** Given open issues that bear on catalog operations at the head (at least #77 and #86) When the area doc is read Then it states each as a known limit with its issue link, and states no behaviour those issues would add

### Story 2: CLAUDE.md points instead of explaining

**As an** agent starting a session
**I want** CLAUDE.md to tell me where catalog operations are documented, with only what I need before I look
**So that** every session doesn't load 714 words most sessions never use

**Acceptance criteria:**

- [ ] **AC-2.1** Given CLAUDE.md at the head When the "Admin catalog and jobs" bullet is read Then it is at most 60 words (counted with `wc -w`), links `docs/architecture/catalog-operations.md`, and keeps the `:solid_queue` example tag and the helper names `queue_job`, `claim_job`, `fail_job`, `finish_job` (R5: spec tags stay)
- [ ] **AC-2.2** Given CLAUDE.md at the head When its opening paragraph's list of documents ("Mission and principles: … Feature specs: `docs/specs/`.") is read Then it names `docs/architecture/` as the current rules per subsystem and `docs/specs/README.md` as the specs index
- [ ] **AC-2.3** Given CLAUDE.md at the merge base and at the head When they are compared Then nothing outside the "Admin catalog and jobs" bullet and the opening paragraph's list of documents has changed

### Story 3: Every spec is in an index

**As a** reader of an old spec
**I want** an index that says whether it is current, what superseded it and where its current rules live
**So that** I don't trust spec 002's "search is public"

**Acceptance criteria:**

- [ ] **AC-3.1** Given `docs/specs/` at the head When its folders are compared with the index's rows Then every spec folder at the head (001–024 and 027 today, plus any merged meanwhile, such as 025 and 026) has exactly one row, and every row names a folder that exists
- [ ] **AC-3.2** Given an index row When it is read Then it has the spec's number and linked title, its status in the FR-3 vocabulary, its areas per D2 (linked where the area doc exists), its plan state (present, retired with the retirement pointer, or none), and its "supersedes" and "superseded by" entries
- [ ] **AC-3.3** Given every "superseded by" entry in the index When the superseding spec's row is read Then it has the matching "supersedes" entry, naming the same part, and the reverse holds too
- [ ] **AC-3.4** Given spec 002's row When it is read Then it records that its public search (Non-Goals, FR-7) is superseded by spec 004 (sign-in) and spec 023 (the operator setting), and that its FR-3–FR-6 are frozen by the catalog operations area doc
- [ ] **AC-3.5** Given the index When its introduction is read Then it states the status vocabulary, the freezing rule (R3, D3, D4), and the retirement pointer's form, and links `docs/architecture/README.md`

### Story 4: The rules reach every author

**As an** author of the next feature or issue fix
**I want** to be told, wherever I start, to update the area doc and not a frozen spec, and to be offered the distillation step when I wrap up
**So that** the area docs stay current without the maintainer reminding anyone

**Acceptance criteria:**

- [ ] **AC-4.1** Given `docs/architecture/README.md` When it is read Then it states the purpose of area docs, the D5 shape, the area list with one row per D2 area (marked "not written yet" where no doc exists), when an area doc is updated (FR-5), and links the specs index
- [ ] **AC-4.2** Given `.claude/rules/` at the head When it is read Then one rule file states: change an area doc in the same pull request as a change to its area; don't edit a frozen part of a spec except as D4 allows; a part not yet covered follows the current practice; and name the distillation step
- [ ] **AC-4.3** Given `.claude/memory/steering/` at the head When its files' `loaded-by` front matter is read Then one file is loaded by `sdd-brainstorm`, `sdd-specify`, `sdd-plan` and `sdd-review` and tells them to read the area docs of the areas a feature touches before writing, and to name in a spec or plan the area docs it will change
- [ ] **AC-4.4** Given `.claude/skills/distill-feature/SKILL.md` When it is read Then it describes both states of D6 (before the merge: distil into area docs, propose ADRs, mark parts frozen in the index, record the retirement as owed; after the merge: retire the plan in the two commits of D7), and it says it must not change a spec beyond D4
- [ ] **AC-4.5** Given `.claude/integrations.md` When it is read Then it has a row with trigger skill `session-wrap` and custom skill `distill-feature`, with no `|` character inside any cell value
- [ ] **AC-4.6** Given `.claude/memory/edit-specs-your-change-makes-stale.md` and its line in `.claude/memory/MEMORY.md` When they are read Then they say the practice applies only to parts not yet frozen, and that a change to a frozen part updates the area doc instead (R3)

### Story 5: Retired plans can be read back

**As a** reader who needs the code-level reasoning of a shipped feature
**I want** a retired plan to be one command away
**So that** removing 41,000 lines from the tree loses nothing

**Acceptance criteria:**

- [ ] **AC-5.1** Given `docs/git-convention.md` at the head When it is read Then a section states that pull requests are merged with merge commits, never squashed or rebased, and that retired plans depend on it (R6)
- [ ] **AC-5.2** Given every plan this pull request retires (Open Decision 2) When `git show <sha>^:<path>` from its retirement pointer is run Then it prints the plan as it was at the merge base, byte for byte (compared with `git show <merge-base>:<path>`, recorded in `verification.md`)
- [ ] **AC-5.3** Given a retired plan's folder When its Markdown is searched for links to `plan.md` Then none is left as a link; each names the retirement pointer instead (D4)
- [ ] **AC-5.4** Given the commits of this pull request When the commit that deletes a plan is read with `git show --stat` Then it deletes that `plan.md` and changes nothing else (D7)

### Story 6: The follow-up slices are on the roadmap

**As the** maintainer
**I want** slices B and C on the roadmap with their issues
**So that** the rest of the work is tracked as every other candidate is

**Acceptance criteria:**

- [ ] **AC-6.1** Given `docs/roadmap.md` at the head When its housekeeping lane is read Then it has a line for this spec and one per follow-up slice of D1 (B and C1–C7), each linking its GitHub issue on the 1.0 milestone with the `housekeeping` label
- [ ] **AC-6.2** Given `docs/adr/README.md` at the head When its "Expected" paragraph is read Then it names the YARD adoption (slice B) as expected ADR 0023, subject to the next-free-number rule

## Functional Requirements

### FR-1: The area docs folder

`docs/architecture/README.md` introduces area docs and lists the areas.

**Must:**
- State the purpose (R2), the D5 shape, the D2 area list with links (or "not written yet"), and when an area doc is updated (FR-5).
- Link the specs index, the ADR index and the existing reference docs D2 names.

**Must not:**
- Restate any area's rules; the README is a map, not a summary.

### FR-2: The catalog operations area doc

`docs/architecture/catalog-operations.md`, distilled from the sources of AC-1.4 and AC-1.5.

**Must:**
- Cover: the refresh's run and its stages, progress and heartbeat; stalled and interrupted runs; the art build's run, its heartbeat, left-behind and stalled builds; the queue lock and the concurrency rules; the rate-limit waits of the Scryfall client and of `Catalog::RateLimitRetry`; a refresh or build skipped while another job's retry waits; the admin catalog panel's states and wording rules; failure reasons and the technical detail; the jobs pages; polling while work is in flight; the source hooks (`.operations`, `.failure_reasons`); and the rule that the core never names a collectible.
- State each state's reader-visible wording only where a spec fixed it.
- Mark each statement with its source (D5).

**Must not:**
- Add, change or reinterpret a rule. Where sources disagree, the code at the head decides and `verification.md` records the disagreement.
- Contain code blocks longer than a signature or a constant's definition.

### FR-3: The specs index

`docs/specs/README.md`, one row per spec folder.

**Must:**
- Use this status vocabulary: **Draft**, **Approved** (approved, not yet merged), **Shipped** (its pull request merged; for a spike or research note, its findings ruled on), **Frozen in part** (D3, naming the parts and their area docs), **Frozen** (wholly covered).
- Give each row: number, linked title, status, areas (D2), plan state, supersedes, superseded by.
- Record supersession by part (for example "002 FR-7 public search → 004, 023").
- Be updated by every later spec's pull request (its own row) and by every distillation step.

**Must not:**
- Change any spec's own **Status:** line. The index's status is its own column.

### FR-4: Frozen specs

**Must:**
- Add the D4 frozen line to specs 002, 011, 015 and 024 under their header, naming the parts the pilot covers (002 FR-3–FR-6 and their Error Scenarios rows; 011 FR-2's build run; 015 and 024 whole).

**Must not:**
- Change anything else in those specs (D4).

### FR-5: When an area doc changes

Stated in `docs/architecture/README.md` and the rule file (AC-4.2).

**Must:**
- A pull request that changes the behaviour, a constant or a rule of an area with an area doc updates that doc in the same pull request and adds a Distillation log row.
- A feature's spec and plan are distilled before its pull request is marked ready for review (Open Decision 1), after `session-wrap`.

**Must not:**
- Edit a frozen part of a spec, except as D4 allows.

### FR-6: Reaching agents and the SDD skills

**Must:**
- Add a rule file under `.claude/rules/` (AC-4.2), a steering file (AC-4.3), the `distill-feature` project skill (AC-4.4) and its integrations row (AC-4.5).
- Update the memory that conflicts with R3 (AC-4.6).

**Must not:**
- Edit plugin files, or any skill other than the new one.

### FR-7: CLAUDE.md

**Must:**
- Replace the "Admin catalog and jobs" bullet with the AC-2.1 pointer and add the AC-2.2 entries.

**Must not:**
- Move any other bullet (slice C).

### FR-8: Git convention and ADR index

**Must:**
- Add a "Merging" section to `docs/git-convention.md` (AC-5.1), outside its front matter.
- Add the slice B expectation to `docs/adr/README.md` (AC-6.2).

### FR-9: Roadmap and issues

**Must:**
- Add housekeeping lane lines for this spec and for slices B and C1–C7 (AC-6.1), with an issue for each, opened before the pull request is marked ready for review, on the 1.0 milestone with the `housekeeping` label; this spec's header then links its issue.

**Must not:**
- Change the main line or the decision log, except to record a new ruling with its date if the maintainer makes one while reviewing this spec.

## Non-Functional Requirements

### Performance

- CLAUDE.md shrinks by at least 630 words (2,312 at the merge base, counted with `wc -w`; the bullet goes from 714 to at most 60, and AC-2.2 adds at most 20).

### Security

- No document, command or check in this work reads `.kamal/secrets`, `config/master.key`, `.env*` or `storage/`; every `git grep` it runs or prescribes ends with `':!.kamal/secrets'`.
- Nothing new is copied into the container image: `docs/`, `.claude/` and `CLAUDE.md` are already in `.dockerignore`.

### Reliability

- The suite and `bin/ci` are unchanged and pass at the head (no application file changes).
- Every relative link added or changed by this pull request resolves (checked by reading, recorded in `verification.md`).

### Compatibility

- Area docs and the two README files are GitHub-flavoured Markdown with relative links and no front matter, so that slice B can include them in YARD's output unchanged.
- Spec numbers, criterion numbers and ADR numbers are never changed; code comments citing them stay valid.

### Hosted-door and roadmap rules

- No hosted-door rule is affected: no application, setting, data or background work changes; the cost per account is zero.
- One outcome, one pull request: the outcome is the first sentence of Story 1 with the rules that keep it true; nothing in it is releasable apart from the rest (D1).
- No collector-owned data is added, so the export format is untouched.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A statement in CLAUDE.md's bullet is no longer true at the head | The area doc states the current behaviour; `verification.md` records the stale statement; CLAUDE.md loses it with the bullet |
| Two sources disagree (for example a spec criterion and a later issue fix) | The code at the head decides; the area doc states it with both sources; `verification.md` records the disagreement |
| The code contradicts every source | The area doc states the code's behaviour, marked as having no spec source, and an issue is opened for the maintainer to rule on; the area doc doesn't wait for the ruling |
| A plan retirement's pull request is squash-merged by mistake | The pointer's sha is unreachable from `main`; the next distillation step replaces each such pointer with one naming the feature's merge commit (`git show <merge sha>:<path>`), and `verification.md` of that step records it |
| A later feature changes catalog operations but its author doesn't update the area doc | Its implementation review (`sdd-review` Mode B) finds the gap through the steering file and rule file, as it finds a missing test today |
| Another ADR merges as 0023 before slice B | Slice B's ADR takes the next free number and updates `docs/adr/README.md`'s Expected line |
| The integrations row isn't offered after `session-wrap` (a plugin change) | The rule file and steering file still name the step; the author runs `distill-feature` by name |

## Open Questions

Decisions for the maintainer, each with a recommendation. None blocks planning; the plan follows the recommendation unless ruled otherwise.

1. **When is a feature distilled?** (a) In the feature's own pull request, after `session-wrap` and before it is marked ready for review, with the plan retired after the merge in the next housekeeping pull request (as the session-learnings pull requests #99 and #100 were); (b) both distillation and retirement after the merge, in a housekeeping pull request. **Recommendation: (a).** The feature's reviewer then reviews the area doc change with the code that made it true, `main` never holds code whose area doc is stale, and it matches how CLAUDE.md is edited in feature pull requests today. Only retirement needs the merge (R6).
2. **Does this pull request retire the plans of specs 015 and 024?** Both features merged long ago and the pilot freezes both specs whole. **Recommendation: yes,** as the first run of D7 and the check of AC-5.2–AC-5.4. Spec 002's and 011's plans wait for catalog core and scanner (slice C). If no, Story 5 keeps only AC-5.1, and AC-5.2–AC-5.4 move to slice C.
3. **The two added areas (D2).** Data portability (017, 022) and development environment (001, 003, 014) aren't in R2's candidate list. **Recommendation: keep both;** without them those six specs have no area, and their CLAUDE.md bullets ("Export format", "Worktrees", "Dev mirrors prod", "Active Storage variants") have nowhere to move. The alternative folds data portability into collection and lots and development environment into release and deploy.
4. **Does the pilot cover the jobs pages (`/admin/jobs`)?** They are spec 015's and generic, not catalog-specific. **Recommendation: yes,** under catalog operations, because spec 015 freezes whole only if they are covered and the same polling and queue-reading rules apply; a later slice may split an "admin and background jobs" area out if it grows.

## Out of Scope (Future Considerations)

- **Slice B: adopt YARD** (D1). A starting shape for its spec, not decided here: the `yard` gem in the development group with `require: false`; a `.yardopts` that reads `app` and `lib` and adds `docs/architecture/*.md` (and the ADRs, if decided) with `--files`; a `bin/yard` binstub; output in `doc/`, added to `.gitignore` and `.dockerignore`; `bin/ci` checking that documentation builds without warnings, but not coverage, at first; existing comments citing "spec NNN AC-x" kept as they are, with new ones written as `@see` tags pointing at the specs index or an area doc. ADR 0023 records the choice.
- **Slices C1–C7: one area per pull request** (D1, D2), each moving its CLAUDE.md bullets, freezing its specs and retiring the plans of the specs it leaves wholly frozen (the 21 plans not retired here, or 23 if Open Decision 2 is no).
- Checking area docs automatically against the code (D8).
- Distilling `docs/lessons/` or `.claude/memory/` into area docs; `session-wrap` keeps them.
- Changing the SDD plugin's skills.
