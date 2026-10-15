# Implementation Plan: Area Docs Hold the Current Architecture, Starting with Catalog Operations

**Spec:** [spec.md](spec.md) v1.2.0 (Approved 2026-10-15, rulings OD1–OD6)
**Decisions:** none new. The spec's D1–D9 and rulings R1–R8 and OD1–OD6 bind this plan; ADR 0023 (YARD) is only named as expected (slice B).
**Created:** 2026-10-15
**Branch:** `027-architecture-area-docs`

## Global Constraints

Copied from the spec; every phase is bound by them.

- Documentation and agent-process change only: no file under `app/`, `lib/`, `config/`, `bin/`, `db/`, `spec/` or `script/` changes (Non-Goals; NFR Reliability).
- No RSpec check of any document (D8, `.claude/rules/testing.md`). Every acceptance criterion is verified by reading at the head and recorded in `verification.md`; where a criterion names a command, its output is recorded too.
- Never read `.kamal/secrets`, `config/master.key`, `.env*` or `storage/`, not even with `grep`, `cat` or `ls`. Every `git grep` ends with `':!.kamal/secrets'`. No recursive `grep -r` from the repository root.
- Worktree agents: one git operation per Bash call (`cd <worktree> && git …` only), `git add` and `git commit` in separate calls; edit files with Edit/Write, not heredoc scripts chained to other commands.
- One Conventional Commit per step (`docs(…)`, `chore(memory)`), each ending with exactly `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, regardless of any other reminder.
- Spec ids, criterion numbers and ADR numbers are never changed (NFR Compatibility).
- A shipped spec is not edited except as D4 allows: its frozen line, its retirement pointer, and its links to its own retired plan, each in a commit of its own that names D4 (R3, R8).
- Area docs and the two README files are GitHub-flavoured Markdown with relative links and no front matter (NFR Compatibility).
- After Phase 6 the branch is never rebased: bring `main` in with `git merge origin/main` only, so the retirement pointers' shas stay valid (D7). The pull request is merged with a merge commit (R6).
- Areas (D2 after OD3): catalog operations, catalog core, collection and lots, tenancy and accounts, scanner, data portability, release and deploy. Specs 001 (stack, CI, hooks), 003 and 014 have no area doc; their area is "CLAUDE.md (R5)".

---

## Goal

`docs/architecture/catalog-operations.md` states the current rules of catalog operations, CLAUDE.md points to it, every spec is in `docs/specs/README.md`, the plans of specs 015 and 024 are retired with readable pointers, and the rules, steering file and `distill-feature` skill make every later feature keep its area docs current.

---

## Pre-implementation gates

- **Simplicity:** three kinds of output: the docs (area doc, two READMEs), the agent process (rule, steering, skill, integrations rows, memory), and the record (CLAUDE.md, frozen lines, retirement, roadmap). No dependency is added.
- **Anti-abstraction:** no generator, script or check is written; the index and the area doc are written by hand (D8 rules out an automated check).
- **Integration-first:** there is no API. Its counterpart here is Phase 0, which records the baseline facts (merge base, word counts, link inventory, open issues) every later phase is checked against, before any document changes.
- **Test-first:** not applicable to prose (D8). Each phase ends with its reading checks written into `verification.md`, and the controller reads them before the next phase starts.

## Execution notes

- One implementer subagent per phase (Opus), dispatched by the controller with only its phase's text plus Global Constraints. Phases 1, 2 and 5 are independent of each other; 3 needs 2; 4 needs 3; 6 needs 4; 7 needs 4; 8 runs last. Run phases one at a time anyway: they share `verification.md`.
- No subagent runs `bin/rspec` or `bin/ci`; Phase 8's controller runs `bin/ci` once.
- The drafts below are strong drafts. An implementer checks each factual statement against the code or document it names and corrects the draft where they disagree, recording each correction in `verification.md` (FR-2: the code at the head decides).

---

## Phase 0: Baseline record

**Implements:** NFR Reliability, NFR Performance (baseline) | **Satisfies:** inputs to AC-1.2, AC-1.7, AC-2.1, AC-2.3, AC-5.2, AC-5.3
**Files:** `docs/specs/027-architecture-area-docs/verification.md` (new)
**Interfaces:** Consumes: nothing. Produces: `verification.md` with the sections every later phase appends to: `## Baseline`, `## Phase 1` … `## Phase 8`, and the merge-base sha `<base>` that Phases 2, 3 and 6 compare against.

Record the facts every check is measured from, before anything changes.

- [ ] Find the merge base (one git operation):
  `cd /home/james/orca/projects/Collector/.claude/worktrees/agent-ab56ea75fa029cb55 && git merge-base origin/main HEAD`
  Expected: one sha (at plan time `6b422d1`). Call it `<base>`.
- [ ] Count CLAUDE.md's words at the base:
  `cd <worktree> && git show <base>:CLAUDE.md > <scratchpad>/claude-base.md` then, in its own call, `wc -w <scratchpad>/claude-base.md`. Expected: `2312`. (`<worktree>` is `/home/james/orca/projects/Collector/.claude/worktrees/agent-ab56ea75fa029cb55` or wherever the branch is checked out; `<scratchpad>` is the session's scratchpad directory, outside the repository.)
- [ ] Save the "Admin catalog and jobs" bullet at the base to `<scratchpad>/bullet-base.md` (copy the one line beginning `- **Admin catalog and jobs` from `claude-base.md` with the Read and Write tools) and count it with `wc -w`. Expected: `714`.
- [ ] List the own-plan links in the pilot's folders:
  `cd <worktree> && git grep -n "](plan.md)" -- docs/specs/002-scryfall-catalog-search docs/specs/011-card-scanner-art-matching docs/specs/015-admin-catalog-and-jobs docs/specs/024-refresh-rate-limit-wait ':!.kamal/secrets'`
  Expected: `docs/specs/011-card-scanner-art-matching/research.md:3:…` and `docs/specs/024-refresh-rate-limit-wait/verification.md:3:…`, nothing else (spec AC-5.3).
- [ ] List open issues:
  `gh issue list --state open --limit 200 --json number,title,body > <scratchpad>/open-issues.json`, then read the file and select every issue whose title or body names the catalog refresh, the art build or art index, the admin catalog page or the jobs pages. At plan time those are at least #77 and #86 (AC-1.7).
- [ ] Write `verification.md`:

````markdown
# Verification: Spec 027

**Spec:** [spec.md](spec.md) v1.2.0 · **Plan:** [plan.md](plan.md) · **Branch:** `027-architecture-area-docs`

Every criterion of spec 027 is a prose criterion, verified by reading at the head and recorded here (`.claude/rules/testing.md`; spec D8). Comparisons "with the base" are with the merge base below.

## Baseline

- Merge base: `<base>` (`git merge-base origin/main HEAD`, <date>).
- CLAUDE.md at the base: 2,312 words (`wc -w`); its "Admin catalog and jobs" bullet: 714 words.
- Own-plan Markdown links in the pilot's folders at the base (`git grep -n "](plan.md)"`): `011-card-scanner-art-matching/research.md:3`, `024-refresh-rate-limit-wait/verification.md:3`. `020-readme-introduction/verification.md:479` is a path in quoted `git` output, not a link, and is outside the pilot.
- Open issues bearing on catalog operations (`gh issue list --state open --limit 200 --json number,title,body`, <date>): <list each as "#N title">.

## Phase 1: Rules and process docs
## Phase 2: The catalog operations area doc
## Phase 3: CLAUDE.md and the frozen lines
## Phase 4: The specs index
## Phase 5: The distillation step
## Phase 6: Plan retirement
## Phase 7: Roadmap, ADR index and issues
## Phase 8: Integration verification
````

  Replace `<base>`, `<date>` and the issue list with what the steps above returned.
- [ ] `git add docs/specs/027-architecture-area-docs/verification.md` (own call), then commit: `docs(027): record the baseline for verification`.

---

## Phase 1: Rules and process docs

**Implements:** FR-1, FR-5, FR-6 (rule file, steering file, memory), FR-8 (git convention) | **Satisfies:** AC-4.1, AC-4.2, AC-4.3, AC-4.6, AC-5.1
**Files:** `docs/architecture/README.md` (new), `.claude/rules/documentation.md` (new), `.claude/memory/steering/architecture.md` (new), `.claude/memory/edit-specs-your-change-makes-stale.md`, `.claude/memory/MEMORY.md`, `docs/git-convention.md`, `verification.md`
**Interfaces:** Consumes: nothing. Produces: the area list and D5 section names that Phases 2 and 4 use verbatim (`Scope`, `Glossary`, `Invariants`, `States and transitions`, `Named constants`, `Decisions not in an ADR`, `Sources`, `Distillation log`); the plan-state words of FR-3 (`present`, `retirement owed`, `retired`, `none`) and status words (`Draft`, `Approved`, `Shipped`, `Frozen in part`, `Frozen`) that Phases 4 and 5 use verbatim.

Write down the rules where agents and the SDD skills read them, before any doc exists that they govern.

- [ ] Create `docs/architecture/README.md`:

````markdown
# Architecture

One area doc per subsystem holds the current truth about it: its terms, the rules that always hold, its states, its named constants and why they have their values, and the decisions not recorded in an ADR. Each statement names the spec criterion, ADR or issue behind it. When an area doc and an older spec disagree, the area doc is right: specs record what a feature promised when it shipped, and freeze once an area doc covers them (see the [specs index](../specs/README.md)).

Lasting decisions are in [ADRs](../adr/README.md). What an agent needs before it knows where to look stays in [CLAUDE.md](../../CLAUDE.md).

## Areas

| Area | Doc | Specs it covers | Reference docs |
|---|---|---|---|
| Catalog operations | [catalog-operations.md](catalog-operations.md) | 002 FR-3–FR-6; 011 FR-2 (the build's run); 015; 024 | none |
| Catalog core | not written yet | 002 FR-1, FR-2, FR-7–FR-10; 016; 018; 019; 023 | none |
| Collection and lots | not written yet | 004 (collection, adding cards); 006; 021 | [design system](../design-system/README.md) |
| Tenancy and accounts | not written yet | 004 (accounts, users, admin users) | none |
| Scanner | not written yet | 005; 007; 008; 009; 010; 011 (all but FR-2's build run) | none |
| Data portability | not written yet | 017; 022 | [export format](../export-format/README.md) |
| Release and deploy | not written yet | 001 (container, Compose, Kamal); 012; 013; 020 | [releasing](../releasing.md) |

Specs 001 (stack, CI, hooks), 003 and 014 describe the development environment. Its facts stay in CLAUDE.md, where an agent needs them first, and have no area doc; they freeze with the release and deploy area. Spec 004's design-system part is covered by [`docs/design-system/`](../design-system/README.md).

## The shape of an area doc

Every area doc has these sections, in this order. A section with nothing in it says "None." under its heading.

1. **Scope**: what the area covers and where its edges are, naming the neighbouring areas.
2. **Glossary**: the area's terms.
3. **Invariants**: statements that always hold.
4. **States and transitions**: for each stateful thing, its states, what moves it between them, and what a reader sees.
5. **Named constants**: name, value, where it is defined, why that value, and its source.
6. **Decisions not in an ADR**: each with its source. Accepted limits and open issues go here too.
7. **Sources**: every spec part, ADR and issue the doc distils, linked.
8. **Distillation log**: one row per whole feature distilled into the doc: date, what was distilled, the pull request.

Each statement that came from a spec criterion, ADR or issue names it inline, for example "(spec 015 AC-2.16; #60)". Code comments cite spec criteria; the [specs index](../specs/README.md) leads from a spec to the area doc that holds its current form.

## When an area doc changes

- A pull request that changes the behaviour, a constant or a rule of an area that has an area doc updates the doc in the same pull request. An issue fix adds its issue to Sources; only a whole feature's distillation adds a Distillation log row.
- A feature is distilled into its area docs in its own pull request, after `session-wrap` on the feature branch and before the pull request is marked ready for review. Its plan is retired after the merge. The `distill-feature` skill (`.claude/skills/distill-feature/SKILL.md`) does both, and is offered after every `session-wrap`.
- A change that supersedes part of a shipped spec records the supersession in its own spec and in the specs index, and updates the area doc where one covers that part. It doesn't edit the earlier spec.
````

- [ ] Create `.claude/rules/documentation.md`:

````markdown
# Documentation: Area Docs, Specs and Plans

- ✓ The current rules of a subsystem are in its area doc under `docs/architecture/` (list and shape in its README). Read the area docs of the areas you touch before changing them.
- ✓ A change to the behaviour, a constant or a rule of an area that has an area doc updates that doc in the same pull request, with the source of each new statement (spec criterion, ADR or issue) inline. An issue fix adds its issue to the doc's Sources.
- ✓ A change that supersedes part of a shipped spec records the supersession in its own spec ("supersedes spec NNN FR-x: …") and in `docs/specs/README.md`, both directions, and updates the area doc where one covers that part.
- ✓ When a feature is finished, distil it with the `distill-feature` skill after `session-wrap`: before the merge it writes the area docs and marks the index; after the merge it retires the plan.
- ✓ Keep `docs/specs/README.md` current: a new spec adds its row when it is written; the distillation step changes rows as specs freeze and plans retire.
- ✗ Don't edit a shipped spec, frozen or not, except for its frozen line, its retirement pointer and its links to its own retired plan, each in a commit of its own that names spec 027 D4. Typos stay; supersessions go in the new spec and the index.
- ✗ Don't renumber or rename a spec, a criterion or an ADR; code and tests cite them.
- ✗ Don't restate an area's rules in CLAUDE.md; point to the area doc.
````

- [ ] Create `.claude/memory/steering/architecture.md`:

````markdown
---
scope: architecture
loaded-by: sdd-brainstorm, sdd-specify, sdd-plan, sdd-review
---

# Area Docs

The current rules of each subsystem are in `docs/architecture/<area>.md`; the list of areas and the doc shape are in `docs/architecture/README.md`, and every spec's status, areas and supersessions are in `docs/specs/README.md`.

- **Before writing** a PRD, spec or plan, read the area docs of the areas the feature touches. Where an area has no doc yet, read its specs through the index, newest first, and CLAUDE.md.
- **In a spec or plan,** name the area docs the feature will change, and what it supersedes in earlier specs ("supersedes spec NNN FR-x"), so the index can record both directions. Don't plan edits to a shipped spec (`.claude/rules/documentation.md`).
- **In a review,** check that the change updates every area doc it makes stale, and that a finished feature was distilled (`distill-feature`) before its pull request is marked ready.
````

- [ ] Rewrite `.claude/memory/edit-specs-your-change-makes-stale.md` (Read it first; keep its file name so links to it hold):

````markdown
---
name: edit-specs-your-change-makes-stale
description: When a change makes part of a shipped spec stale, record the supersession in the new spec and the specs index and update the area doc; never edit the earlier spec (rulings R3 and R8 of 2026-10-15, spec 027). Replaces the 2026-10-14 practice of editing it with a version bump
metadata:
  type: feedback
---

When a change makes an acceptance criterion or requirement of a shipped spec incomplete or wrong, don't edit that spec. Record the supersession in the new spec ("supersedes spec NNN AC-x: …"), add it to `docs/specs/README.md` in both directions, and update the area doc under `docs/architecture/` where one covers that part.

**Why:** on 2026-10-15 the maintainer ruled that specs freeze as historical records once an area doc covers them (spec 027, R3), and that freezing applies already (R8): spec 025's plan was told not to edit spec 022 and to record the supersession in spec 025, and spec 026 got the same instruction. Specs 002 and 015 had been amended in place for issues #60–#81, which hid what each promised when it shipped.

**History:** from 2026-10-14 (spec 024) to 2026-10-15 the practice was the opposite: the maintainer asked spec 024's PR to edit spec 015's AC-2.16 with a patch version bump and a changelog line, and spec 002 was edited in the same PR. Those edits stay as they are.

**How to apply:** while specifying or planning, grep `docs/specs/` and `docs/architecture/` for the behaviour, scope or message you change. For each part of a shipped spec it makes stale, write the supersession into your spec, plan the index rows and the area doc edit, and record them in your `verification.md`. Only a spec's frozen line, retirement pointer and links to its retired plan may be added to it (spec 027 D4). Related: [[sdd-review-model-choice]].
````

- [ ] In `.claude/memory/MEMORY.md`, replace the line

  `- [Edit specs your change makes stale](edit-specs-your-change-makes-stale.md) — another spec's AC made incomplete → edit it in the same PR, patch bump + changelog (maintainer, 2026-10-14)`

  with

  `- [Edit specs your change makes stale](edit-specs-your-change-makes-stale.md) — a shipped spec made stale → record the supersession in the new spec and the index, update the area doc; never edit the old spec (R3, R8, 2026-10-15; first used by specs 025, 026)`

- [ ] In `docs/git-convention.md`, append after the `### Commit messages` examples (outside the front matter):

````markdown

## Merging

Pull requests are merged with a merge commit, never squashed or rebased (maintainer, 2026-10-15). A retired plan is read back from the commit that deleted it (`git show <sha>^:docs/specs/NNN-…/plan.md`, [spec 027](specs/027-architecture-area-docs/spec.md) D7), so that commit must stay in `main`'s history as it was written.

Rebasing a branch before it merges changes the sha of every commit on it. On a branch that retires a plan, write the retirement pointer after the branch's last rebase, and bring `main` in with a merge from then on.
````

- [ ] Fill `## Phase 1` of `verification.md`: for AC-4.1, AC-4.2, AC-4.3, AC-4.6 and AC-5.1, one line each quoting the sentence or heading that meets it, with the file and line.
- [ ] Commit each file group separately (each `git add`, then `git commit`, in its own call):
  1. `docs(architecture): add the area docs README` (`docs/architecture/README.md`)
  2. `docs(rules): add the documentation rule for area docs and frozen specs` (`.claude/rules/documentation.md`)
  3. `chore(memory): add the architecture steering file` (`.claude/memory/steering/architecture.md`)
  4. `chore(memory): record supersessions instead of editing shipped specs` (the memory file and `MEMORY.md`)
  5. `docs(git): require merge commits for pull requests` (`docs/git-convention.md`)
  6. `docs(027): record phase 1 verification` (`verification.md`)

---

## Phase 2: The catalog operations area doc

**Implements:** FR-2 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-1.7
**Files:** `docs/architecture/catalog-operations.md` (new), `verification.md`
**Interfaces:** Consumes: the D5 section names (Phase 1, repeated in Global Constraints); `<base>` and the issue list (Phase 0). Produces: `docs/architecture/catalog-operations.md`, linked by Phases 3 and 4 at exactly that path.

Distil specs 002 (FR-3–FR-6 and their Error Scenarios rows), 011 (FR-2's build run), 015 and 024, and CLAUDE.md's bullet, into one doc whose every statement holds at the head.

- [ ] Read the sources in full: `docs/specs/015-admin-catalog-and-jobs/spec.md`; `docs/specs/024-refresh-rate-limit-wait/spec.md`; `docs/specs/002-scryfall-catalog-search/spec.md` FR-3 to FR-6 and its Error Scenarios; `docs/specs/011-card-scanner-art-matching/spec.md` FR-2 and Story 3; the bullet saved in Phase 0; and the files named in the draft's Scope. Then write the draft below to `docs/architecture/catalog-operations.md`, checking every statement and constant against the code as you go.

````markdown
# Catalog operations

How the catalog changes, and how admins start, watch and recover that work: the catalog refresh, the MTG art index build, their rate-limit retries, the admin catalog page (`/admin/catalog`) and the jobs pages (`/admin/jobs`). This is the current truth; the specs it distils record what each feature promised when it shipped (see Sources and the [specs index](../specs/README.md)).

## Scope

**Covers:**

- The refresh's run and its lifecycle: `Catalog::Refresh`, `Catalog::RefreshRun`, `Catalog::Refresh::Progress`, `Catalog::RefreshJob`, the weekly schedule (`config/recurring.yml`) and the `catalog:refresh` and `catalog:status` tasks (`lib/tasks/catalog.rake`).
- Rate limits: `Catalog::RateLimitRetry`, and the waits and timeouts of `MTG::Scryfall::Client`.
- The art index build's run and lifecycle: `MTG::Art::BuildJob`, `MTG::Art::Build`, `MTG::ArtBuild`, `MTG::Art.after_refresh`, `MTG::Art.status_line`.
- The admin pages: `Admin::CatalogsController`, `Admin::Catalogs::OperationStartsController`, `Catalog::Health`, `Catalog::Operation` and `Catalog::Operation::Queue`, `Catalog::RefreshOperation`, `MTG::Art::Operation`, `Catalog::FailureReason`; `Admin::JobsController`, `Admin::Jobs::RetriesController`, `Admin::Jobs::DiscardsController`, `BackgroundJobs::List`, `BackgroundJobs::Entry`; the `poll` Stimulus controller.

**Neighbours:**

- What a refresh writes (entries, sets, identities, retirement and restoring, the name index), the source contract's data methods and catalog search are **catalog core** (no area doc yet; spec 002 FR-1, FR-2, FR-7–FR-10).
- The art fingerprint, the index file's format and matching in the browser are **scanner** (no area doc yet; spec 011, ADRs 0006, 0007, 0012).
- Running Solid Queue inside Puma (`SOLID_QUEUE_IN_PUMA`) is in CLAUDE.md and **release and deploy**.

## Glossary

- **Catalog type:** a kind of collectible with a registered source (`config/initializers/catalog.rb`); today only `mtg` (spec 015 Glossary).
- **Operation:** something an admin can start for a catalog type and watch: the **refresh** (every type, `Catalog::RefreshOperation`) and any extra operation a source adds through its optional `.operations` hook (for `mtg`, the **art index** build, `MTG::Art::Operation`) (spec 015 FR-2).
- **Run:** one attempt of a refresh (`Catalog::RefreshRun`) or of an art build (`MTG::ArtBuild`), with its job id, status, counts and progress or heartbeat (spec 015 FR-1; spec 011 AC-3.2).
- **Loaded:** a catalog type with at least one applied refresh run (spec 015 Glossary).
- **In flight:** an operation with any unfinished job of its class (for a refresh, for its type) in the queue (ready, blocked, scheduled including retry waits, or claimed), or whose run is running and not interrupted (spec 015 Glossary; `Catalog::Operation#in_flight?`).
- **Queued:** in flight with no running run yet.
- **Last progress / heartbeat:** a refresh run's last recorded progress (`heartbeat_at`, or `started_at` before any), an art build's `heartbeat_at`.
- **Stalled:** running, last progress older than the stall threshold, and its job still claimed by a worker. Shown as running or building, never as interrupted (spec 015 AC-3.6, AC-4.11; #79).
- **Interrupted / left behind:** a run still marked running that nothing works on any more: see States and transitions (spec 015 AC-3.2, AC-3.3, AC-3.9, AC-4.10; #60, #73).
- **Waiting retry:** an unfinished job of the same operation (for a refresh, of the same type), other than the starting one, that the queue holds for a later time (spec 024 Terms).
- **Starting job:** the job whose `Catalog::Refresh#call` or `MTG::Art::Build#call` is running the start guard (spec 024 Terms).
- **Stages of a refresh:** download, sync, retire, index, in that order (`Catalog::RefreshRun::STAGES`; spec 015 Glossary).
- **Job states on the jobs pages:** Failed, Running (claimed), Queued (ready, or blocked by a concurrency limit, marked "waiting"), Scheduled (due later, including retry waits) (spec 015 Glossary).

## Invariants

- **Catalog data changes only through jobs.** A refresh runs only in `Catalog::RefreshJob` (weekly schedule, `bin/rails "catalog:refresh[mtg]"`, or "Refresh now"); artwork data only in `MTG::Art::BuildJob`. No page render or request calls a source (spec 002 FR-3 must-not; spec 015 FR-3 must-not; spec 011 FR-2).
- **Nothing queues a refresh by itself.** Only an admin's start request, the schedule or the rake task do; not boot, not sign-up (spec 015 AC-1.5, FR-6).
- **The core never names a collectible.** `app/models/catalog/`, `app/jobs/catalog/` and the admin catalog controllers and views contain no whole word `MTG`, `Scryfall` or `Art`; a source adds what it needs through optional hooks (`.operations`, `.failure_reasons`, `.title`, `#progress=`, `#after_refresh`) (spec 015 AC-5.4, FR-2; `spec/admin_catalog_core_spec.rb`; ADR 0018).
- **Two refreshes of one type never apply at once.** `Catalog::RefreshJob` holds a queue concurrency lock per type (`LOCK_FOR`), and `Catalog::RefreshRun.start!` skips a new run while one is running and not left behind (spec 002 FR-4; spec 015 AC-2.15).
- **Two art builds never work at once.** `MTG::ArtBuild.start!` guards it on the run records and job ids, not on a queue lock, which a first build would outlast (spec 011 AC-3.2).
- **The queue is read before the runs.** Every judgement of a run by its job reads Solid Queue's tables first, and judges no run that started after that reading (spec 015 FR-1, AC-3.3, AC-4.10; #60, #73).
- **No sooner than the source asked.** A job turned away by a rate limit runs again no sooner than the source asked, and no other job of its operation asks the source meanwhile (spec 002 FR-4; spec 024; #74, #78).
- **Progress is written outside the batch transactions** and never lengthens them (spec 015 FR-1 must-not).
- **A retry or discard from the jobs pages changes no run** by itself; a retried job changes runs only when it runs (spec 015 AC-6.11).
- **Pages poll only while work is in flight**, with the `poll` controller, re-rendering from recorded state; jobs never broadcast (spec 015 FR-4; ADR 0015).
- **The jobs pages read Solid Queue's own tables** and retry or discard only failed jobs, through Solid Queue's own operations (spec 015 FR-5; ADR 0014).
- **A failure is shown as a plain sentence, never an error class.** `Catalog::FailureReason` derives it at display time from the stored `"<error class>: <message>"`; the panel keeps the stored text as a "Technical detail" fact; `catalog:status` and the log print the stored text unchanged (#84).

## States and transitions

### Refresh run (`Catalog::RefreshRun`)

Statuses: `running`, `applied`, `skipped`, `failed` (spec 002 FR-4).

- **Start** (`Catalog::RefreshRun.start!`, called by `Catalog::Refresh#call` after it reads the queue):
  1. Close each run still marked running as `failed` with message `interrupted` when its last progress is older than `STALL_AFTER`; or its job id is the starting job's own (the queue re-ran it, or an admin retried it); or its last progress is older than `JOB_ENDED_GRACE` and its job is in the queue's failed list or held by no unfinished job in the queue as read (spec 015 AC-3.3; #60). A run started after the reading isn't judged by it. A run with no job id (a refresh run in a console with `perform_now`) is judged the same way and never matches another by id.
  2. If a run is still running, record the new run as `skipped` with `already running` (spec 015 AC-3.4).
  3. Otherwise, if a waiting retry of the type's refresh exists (`Catalog::Operation::Queue#waiting_to_retry?`, excluding the starting job's own id), record it as `skipped` with `waiting for another job's retry`; it asks the source nothing and runs no `after_refresh` (spec 024 decisions 1–5; #78). Manual and scheduled are treated alike (spec 024 decision 2).
  4. Otherwise the run proceeds. A scheduled run whose source version was already applied with the same language set is skipped as already applied; a manual one applies again (spec 002 FR-4).
- **Running:** records its stage, the stage's done and total (when the source reports them) and running counts at least every `EVERY_RECORDS` records or `EVERY_SECONDS`, and at most once per `AT_MOST_EVERY_SECONDS` (`Catalog::Refresh::Progress`; spec 015 AC-2.9, which allowed up to 5 seconds).
- **Ends:** `applied` with counts; `failed` with `"<error class>: <message>"` and the stage it reached; `skipped`.

What the panel shows (`Catalog::RefreshOperation`):

| Condition | Panel |
|---|---|
| No refresh job in flight, last run applied | the run, its counts, source version, finish time |
| Job in the queue, no running run | "Queued." ("Refresh now" disabled) |
| Running, progress within `STALL_AFTER` | running, the four stages, a percentage in download and sync |
| Running, no progress for `STALL_AFTER`, job still claimed | running with "no progress for N minutes"; "Refresh now" disabled (spec 015 AC-3.6) |
| Running, its job failed or gone, last progress older than `JOB_ENDED_GRACE` | interrupted, with the stage and a link to Failed when its job is there; "Refresh now" enabled unless another refresh job is in flight, then "Queued." (spec 015 AC-3.9; #60) |
| Running, no progress for `STALL_AFTER`, job not claimed | interrupted (spec 015 AC-3.2) |
| Failed, its job scheduled to run again | "Queued to retry. The last run failed …" with "Retrying at" (spec 015 AC-3.7) |
| Failed | the failure's plain sentence, the stage, "Technical detail", and a link to Failed when its job is there (spec 015 AC-3.1; #84) |

The panel shows the most recent run not skipped as `already running` or `waiting for another job's retry` (`Catalog::RefreshRun.attempted`); the recent-runs list (`Catalog::Health::RECENT_RUNS`) shows every run (spec 015 AC-2.16; spec 024 FR-3). `catalog:status` marks a run interrupted or stalled by the same rules (spec 015 AC-3.5).

### Art index build (`MTG::ArtBuild`)

Statuses: `running`, `finished`, `failed`, `skipped`. Only with art matching on (`COLLECTOR_MTG_ART_MATCHING`); queued by `MTG::Art.after_refresh` after a refresh that applied, or that was skipped as already applied while the index isn't built for that version, and from the page (spec 011 AC-3.1; spec 015 AC-4.3, AC-4.9).

- **Start** (`MTG::ArtBuild.start!`, after reading the build jobs' queue): close as `failed` (`interrupted`) each running build whose job id is the starting job's own, or that is left behind (`#left_behind?`: heartbeat older than `STALE_AFTER` unless a worker still holds its job, or older than `JOB_ENDED_GRACE` when its job is failed or gone). Then skip as already running if one still runs, or with `waiting for another job's retry` if another build job waits to run again; otherwise proceed (spec 011 AC-3.2; spec 015 AC-4.10; #73, #78).
- **Running:** beats after every batch of `BATCH` artworks and, inside a batch, after an image once `BEAT_EVERY` has passed (#73). Incremental and resumable: cached images and stored fingerprints survive an interruption (spec 011 AC-3.7, AC-3.8).
- **Ends:** `finished` with counts; `failed` with the error. A rate limit the client gave up on stops the build as failed (no image is counted as failed) and its job runs again through `Catalog::RateLimitRetry` (#74). A busy database fails the run and the job retries (up to 3 attempts); a missing ImageMagick fails it and the job is discarded (`MTG::Art::Decoder::Error`).

`MTG::ArtBuild#stalled?` is asked before `#left_behind?` by the panel and the status line; `#left_behind?` is the one statement of the left-behind rule, asked by `MTG::Art::Operation`, `MTG::Art.status_line` and `MTG::ArtBuild.start!`, each reading the queue's build jobs first (#73, #79).

| Condition | Section |
|---|---|
| Art matching off | says it is off, names the setting, no button (spec 015 AC-4.6) |
| Catalog not loaded | button disabled, refresh first (spec 015 AC-4.5) |
| Never built | never built, "Build art index" |
| Build job queued fresh | "Queued." |
| Failed build whose own job waits to run again | "Queued to retry. The last build failed: …", "Retrying at" (spec 015 AC-4.12; #80) |
| Building | bar, counts, last heartbeat (spec 015 AC-4.2) |
| Heartbeat older than `STALE_AFTER`, job still claimed | building with "no heartbeat for N minutes" and the advice to restart the app; button disabled; page polling (spec 015 AC-4.11; #79) |
| Left behind | interrupted; button enabled unless another build job is in flight; link to Failed when its job is there (spec 015 AC-4.10; #73) |
| Finished / failed | counts and finish time / the plain sentence and the index still in use (spec 015 AC-4.7, AC-4.8; #84) |

### A rate-limited job

1. The Scryfall client waits what a 429's `Retry-After` asks for, at most `MAX_BACK_OFF` seconds before a retry and never after its last of `MAX_ATTEMPTS`, so one call sleeps 60 seconds at most. A longer wait asked for, a 429 on the last attempt, or a 429 with no usable `Retry-After` (a zero counts as none) raises `Catalog::Sources::RateLimitedError` at once (spec 002 FR-3; #74, #81).
2. `Catalog::RateLimitRetry` reschedules the job after the wait asked for, `SHORTEST_WAIT` at least. A wait over `LONGEST_WAIT`, or a fourth rate limit (`MAX_RETRIES` retries done), fails the job instead; it then shows under Failed (spec 002 FR-4; #74). The rule is tried before the job's own `retry_on` for transient errors.
3. While the retry waits, the job holds no concurrency lock; a refresh or build of the same operation that starts meanwhile is skipped (`waiting for another job's retry`) and the waiting job does the work (spec 024; #78).

### Jobs pages (`/admin/jobs`)

Filters Failed (the default), Running, Queued, Scheduled, each with its count; 25 per page (`BackgroundJobs::List::PER_PAGE`), ordered by the state's time; a job page with class, arguments, queue, priority, attempts since queued, times, and for a failed job the error and backtrace (spec 015 AC-6.1–AC-6.5; #61). Retry and "Discard…" (with a confirm page) act on failed jobs only; anything else redirects with "That job isn't failed any more." (spec 015 AC-6.6–AC-6.9).

### Polling

`/admin/catalog`, `/admin/jobs` and job pages poll every 2 seconds (the `poll` controller's `interval` value) while work is in flight, keep the scroll position, and stop when nothing is in flight; a job that is only scheduled doesn't keep the jobs pages polling (spec 015 AC-2.10–AC-2.12, AC-6.10; ADR 0015).

## Named constants

| Name | Value | Defined in | Why this value | Source |
|---|---|---|---|---|
| `Catalog::RefreshRun::STALL_AFTER` | 15 minutes | `app/models/catalog/refresh_run.rb` | Long past any working refresh's gap between progress records; a stalled run with a live job still reads as running | spec 015 FR-1, AC-3.2 |
| `Catalog::RefreshRun::JOB_ENDED_GRACE` | 2 minutes | `app/models/catalog/refresh_run.rb` | Above a working run's longest quiet spell: progress every 2 seconds while downloading and syncing, 0.9 and 4.5 seconds for the retire and index stages on 110,000 entries, about 70 seconds for one hung request; the queue also fails the job of a worker it lost sight of that still works | #60 |
| `Catalog::RefreshJob::LOCK_FOR` | 6 hours | `app/jobs/catalog/refresh_job.rb` | The queue's concurrency lock, separate from the stall rule: a waiting refresh must never start while another's job may still be working | spec 002 FR-4; spec 015 FR-1 |
| `Catalog::Refresh::Progress::EVERY_RECORDS` | 5,000 | `app/models/catalog/refresh/progress.rb` | Progress at least this often in records seen | spec 015 AC-2.9 |
| `Catalog::Refresh::Progress::EVERY_SECONDS` | 2 | `app/models/catalog/refresh/progress.rb` | Progress at least this often in time; tighter than the 5 seconds AC-2.9 allows | spec 015 AC-2.9 |
| `Catalog::Refresh::Progress::AT_MOST_EVERY_SECONDS` | 1 | `app/models/catalog/refresh/progress.rb` | Never more often, so progress writes don't load the database | spec 015 AC-2.9 |
| `Catalog::Health::RECENT_RUNS` | 5 | `app/models/catalog/health.rb` | Recent runs listed per type | spec 015 AC-5.1 |
| `MTG::ArtBuild::STALE_AFTER` | 10 minutes | `app/models/mtg/art_build.rb` | The art build's own stall threshold | spec 011 AC-3.2 |
| `MTG::ArtBuild::JOB_ENDED_GRACE` | 2 minutes | `app/models/mtg/art_build.rb` | Set by how often the build beats: the waits alone leave at most 30 + 60 = 90 seconds between beats; only slow requests or decoding on top pass 2 minutes | #73, #74, #81 |
| `MTG::Art::Build::BATCH` | 50 | `app/models/mtg/art/build.rb` | Artworks per batch and per beat | spec 011 AC-3.9 |
| `MTG::Art::Build::BEAT_EVERY` | 30 seconds | `app/models/mtg/art/build.rb` | A beat between images once this has passed, so a slow batch never leaves a working build quiet for the grace | #73 |
| `MTG::Scryfall::Client::MAX_BACK_OFF` | 30 (seconds) | `app/models/mtg/scryfall/client.rb` | Scryfall limits access for 30 seconds after a 429; a longer wait isn't slept through | #74 |
| `MTG::Scryfall::Client::MAX_ATTEMPTS` | 3 | `app/models/mtg/scryfall/client.rb` | Attempts per call; with `MAX_BACK_OFF`, 60 seconds of waiting at most | spec 002 FR-3 |
| `MTG::Scryfall::Client::OPEN_TIMEOUT`, `READ_TIMEOUT` | 10, 60 (seconds) | `app/models/mtg/scryfall/client.rb` | Explicit timeouts on every call | spec 002 FR-3 |
| `Catalog::RateLimitRetry::SHORTEST_WAIT` | 45 seconds | `app/jobs/catalog/rate_limit_retry.rb` | Scryfall's 30 seconds plus 15 of margin, since the wait runs from when the error is handled | spec 002 FR-4; #74, #81 |
| `Catalog::RateLimitRetry::LONGEST_WAIT` | 1 hour | `app/jobs/catalog/rate_limit_retry.rb` | A longer wait asked for fails the job instead of holding it | #74 |
| `Catalog::RateLimitRetry::MAX_RETRIES` | 3 | `app/jobs/catalog/rate_limit_retry.rb` | Rate-limit retries per job before it fails | #74 (counted over the job's life, #86) |
| `BackgroundJobs::List::PER_PAGE` | 25 | `app/models/background_jobs/list.rb` | Jobs per page | spec 015 FR-5 |
| `poll` controller `interval` | 2,000 ms | `app/javascript/controllers/poll_controller.js` | About 2 seconds, so a change shows within 5 | spec 015 FR-4 |

## Decisions not in an ADR

- **Stalled is not interrupted.** A run or build with no progress past its threshold, whose job a worker still holds, reads as running or building, with the button disabled; restarting the app releases it (maintainer ruling 2026-10-09, spec 015 AC-3.6; #79 for the build).
- **The stall threshold is not the lock.** The 15-minute rule changes the start guard and the page; the 6-hour queue lock stays (spec 015 Open Questions).
- **Skip, not defer, while another job's retry waits**, for the refresh and the build, manual and scheduled alike; any waiting retry counts, not only a rate-limit one; the starting job's own retry never counts; a running run wins over a waiting retry (spec 024 decisions 1–6, rulings 2026-10-14).
- **A refresh and an art build don't block each other's rate limit:** they use different hosts, and the core can't tell whether two operations share a limit (spec 024 Non-Goals).
- **Two queued manual refreshes both apply**, one after the other (maintainer ruling 2026-10-09, spec 015 Error Scenarios).
- **Loaded means an applied run**, per type; no download size is shown before the first refresh; no automatic first refresh (spec 015 Open Questions).
- **Times** are absolute UTC in the form `9 Oct 2026 03:15 UTC`, with a relative form for last progress and list times (spec 015 FR-8).

**Accepted limits and open issues:**

- The art build's milliseconds-wide window between a failed build closing and its retry being queued is accepted (spec 024 decision 4).
- A host suspended long enough for the queue to fail a working job can show its run as interrupted until the worker next records progress; a refresh started in that window runs beside it (spec 015 Error Scenarios).
- A skipped manual refresh behind a scheduled job's retry may end as "already applied" (spec 024 decision 1).
- [#77](https://github.com/plainprogrammer/Collector/issues/77): an admin can't start a refresh or build, or cancel the wait, while a rate-limited job waits to retry.
- [#86](https://github.com/plainprogrammer/Collector/issues/86): rate-limit retries count over a job's whole life, so a long build can run out.

## Sources

- [Spec 002](../specs/002-scryfall-catalog-search/spec.md): FR-3 (the adapter's waits and timeouts), FR-4 (the refresh), FR-5 (schedule and tasks), FR-6 (languages), and their Error Scenarios rows.
- [Spec 011](../specs/011-card-scanner-art-matching/spec.md): FR-2 and Story 3, as far as they concern the build's run.
- [Spec 015](../specs/015-admin-catalog-and-jobs/spec.md): all.
- [Spec 024](../specs/024-refresh-rate-limit-wait/spec.md): all.
- ADRs [0014](../adr/0014-hand-built-admin-jobs-console.md), [0015](../adr/0015-admin-progress-by-polling.md), [0018](../adr/0018-collectible-agnostic-catalog-core.md).
- Issues [#60](https://github.com/plainprogrammer/Collector/issues/60), [#61](https://github.com/plainprogrammer/Collector/issues/61), [#73](https://github.com/plainprogrammer/Collector/issues/73), [#74](https://github.com/plainprogrammer/Collector/issues/74), [#78](https://github.com/plainprogrammer/Collector/issues/78), [#79](https://github.com/plainprogrammer/Collector/issues/79), [#80](https://github.com/plainprogrammer/Collector/issues/80), [#81](https://github.com/plainprogrammer/Collector/issues/81), [#84](https://github.com/plainprogrammer/Collector/issues/84); open: [#77](https://github.com/plainprogrammer/Collector/issues/77), [#86](https://github.com/plainprogrammer/Collector/issues/86).

## Distillation log

| Date | Distilled | Pull request |
|---|---|---|
| 2026-10-15 | Specs 002 (FR-3–FR-6), 011 (FR-2's build run), 015 and 024, issues #60–#84, and CLAUDE.md's "Admin catalog and jobs" bullet | spec 027's pull request |
````

- [ ] Check every constant row against its definition (Read each file named; AC-1.3). Record in `verification.md` a table: constant, value in the doc, file:line at the head, match yes/no.
- [ ] Walk the bullet saved in Phase 0 statement by statement (split at each sentence and each semicolon-separated clause). For each, record where the area doc states it (section and the sentence), or why it is left out (AC-1.2). Statements expected to need care: "`Catalog::RefreshOperation` reads the queue before the runs" (Invariants: the queue is read before the runs); the art build's 90-second arithmetic (Named constants, `JOB_ENDED_GRACE`); `Catalog::Operation::Queue#retry_at` takes the job's id (States, art build table: add it if missing); the `:solid_queue` helpers (they stay in CLAUDE.md, Phase 3; record as "kept in CLAUDE.md").
- [ ] Walk spec 015's Glossary, FR-1–FR-8 and Error Scenarios rows, spec 024's decisions 1–6 and FR-1–FR-5, spec 002's FR-3–FR-6 and its Error Scenarios rows about the refresh, and spec 011's FR-2 bullets about the build's run (AC-1.4). For each, record "stated" (with the doc section), "changed since" (with the issue or spec, and the doc's changed form), or "not in this area" (with the area it belongs to). Known "changed since" at plan time: spec 002 FR-4 and its Error Scenarios rows "Process killed or deployed mid-refresh" and "Refresh triggered while one is already running" still say 6 hours; the current rule is spec 015's 15-minute stall and 2-minute job rule (#60). Add any statement the walk shows missing to the doc.
- [ ] Check AC-1.6: `git grep -n -w -i -e MTG -e Scryfall -e Art -- docs/architecture/catalog-operations.md ':!.kamal/secrets'`, and confirm by reading that every hit is in a statement about `MTG::` code, the Scryfall client, or the art build, never in a statement about `Catalog::` code. Record the hits.
- [ ] Check AC-1.5: every link in Sources resolves (file paths exist at the head; issue numbers exist, `gh issue view <n> --json number`). Check AC-1.7: every issue in Phase 0's list appears under "Accepted limits and open issues". Record both.
- [ ] Check AC-1.1: the doc's `##` headings, in order, are exactly the D5 eight. Record them.
- [ ] Commit (`git add`, then commit in separate calls): `docs(architecture): distil catalog operations into an area doc`; then `docs(027): record phase 2 verification`.

---

## Phase 3: CLAUDE.md and the frozen lines

**Implements:** FR-7, FR-4 | **Satisfies:** AC-2.1, AC-2.2, AC-2.3, NFR Performance; frozen lines for AC-3.4 and AC-4.2's D4
**Files:** `CLAUDE.md`, `docs/specs/002-scryfall-catalog-search/spec.md`, `docs/specs/011-card-scanner-art-matching/spec.md`, `docs/specs/015-admin-catalog-and-jobs/spec.md`, `docs/specs/024-refresh-rate-limit-wait/spec.md`, `verification.md`
**Interfaces:** Consumes: `docs/architecture/catalog-operations.md` (Phase 2). Produces: the frozen-line form that Phase 6 places the retirement pointer under.

Point CLAUDE.md at the area doc, and mark the four specs as covered.

- [ ] In `CLAUDE.md`, replace the whole bullet beginning `- **Admin catalog and jobs (spec 015, ADRs 0014 and 0015):**` (one line) with this line (54 words by `wc -w`; at most 60, AC-2.1):

  ```text
  - **Admin catalog and jobs (specs 015, 024; ADRs 0014, 0015):** the refresh and art build lifecycles, stall and interrupt rules, rate-limit retries and the `/admin/catalog` and `/admin/jobs` pages are in [`docs/architecture/catalog-operations.md`](docs/architecture/catalog-operations.md). In specs, tag an example `:solid_queue` to queue through Solid Queue (no worker runs) and move jobs with `queue_job`, `claim_job`, `fail_job`, `finish_job`.
  ```

- [ ] In `CLAUDE.md`'s opening section, replace

  ```text
  Detailed coding rules: `.claude/rules/`. Feature specs: `docs/specs/`.
  ```

  with (adds 9 words, AC-2.2)

  ```text
  Current rules per subsystem: `docs/architecture/` (area docs). Detailed coding rules: `.claude/rules/`. Feature specs: `docs/specs/` (index: `docs/specs/README.md`).
  ```

- [ ] Check AC-2.1 and NFR Performance: copy the new bullet line to `<scratchpad>/bullet-head.md` and run `wc -w` on it (expected ≤ 60), and `wc -w CLAUDE.md` (expected ≤ 1,682, that is at least 630 fewer than 2,312; by the drafts, 1,661). Check AC-2.3: `git diff <base> -- CLAUDE.md` (one git operation) shows changes only on those two lines. Record all three outputs.
- [ ] Commit (`git add CLAUDE.md`, then commit, separately): `docs(claude): point the admin catalog bullet to the area doc`.
- [ ] Add the frozen line to each of the four specs, as the last line of the header block (after the last `**…:**` header line, before the `---` that follows it), one commit per spec:
  - `docs/specs/002-scryfall-catalog-search/spec.md`:

    ```text
    **Frozen:** the current rules are in [`catalog-operations.md`](../../architecture/catalog-operations.md) (parts: FR-3–FR-6 and their Error Scenarios rows); see the [specs index](../README.md)
    ```
  - `docs/specs/011-card-scanner-art-matching/spec.md`:

    ```text
    **Frozen:** the current rules are in [`catalog-operations.md`](../../architecture/catalog-operations.md) (parts: FR-2, the art build's run); see the [specs index](../README.md)
    ```
  - `docs/specs/015-admin-catalog-and-jobs/spec.md` and `docs/specs/024-refresh-rate-limit-wait/spec.md`:

    ```text
    **Frozen:** the current rules are in [`catalog-operations.md`](../../architecture/catalog-operations.md) (whole spec); see the [specs index](../README.md)
    ```

  Change nothing else in those files: no version, no changelog row (D4). Commit each as `docs(specs): mark spec NNN frozen by the catalog operations area doc (spec 027 D4)`.
- [ ] Check: `git diff <base> -- docs/specs/002-scryfall-catalog-search/spec.md docs/specs/011-card-scanner-art-matching/spec.md docs/specs/015-admin-catalog-and-jobs/spec.md docs/specs/024-refresh-rate-limit-wait/spec.md` (one git operation) shows exactly four added lines. Record it.
- [ ] Commit: `docs(027): record phase 3 verification`.

---

## Phase 4: The specs index

**Implements:** FR-3 | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.5, AC-3.6
**Files:** `docs/specs/README.md` (new), `verification.md`
**Interfaces:** Consumes: the area list (Phase 1), the frozen lines (Phase 3). Produces: `docs/specs/README.md` with one row per spec folder and the column `Plan` that Phase 6 updates for 015 and 024 and that the `distill-feature` skill (Phase 5) reads.

- [ ] List the spec folders at the head: `ls docs/specs`. If folders beyond 001–024 and 027 exist (025 and 026 merged meanwhile), add rows for them in the same form, reading their specs for their areas and supersessions.
- [ ] Sweep for supersessions: for each spec, read its Problem Statement, Inputs, Changelog and Non-Goals, and run `git grep -n -E "spec 0[0-9]{2}" -- docs/specs/NNN-<slug>/spec.md ':!.kamal/secrets'` (one call per spec). Record each place one spec changes what an earlier one promised. The draft below holds those known at plan time; add what the sweep finds, in both rows, and record the sweep's list in `verification.md`.
- [ ] Write `docs/specs/README.md`:

````markdown
# Specs

One folder per feature: `NNN-<slug>/`, with its `spec.md` and, while the feature is in progress, its `plan.md`, plus any research, data model, contracts, screenshots and `verification.md`. Numbers are never reused or changed; code and tests cite specs by number and criterion.

## Freezing

A spec records what one feature promised when it shipped. Once an [area doc](../architecture/README.md) covers it, the area doc holds the current rules and the spec is a frozen historical record. A spec is **Frozen** when area docs cover all of it, and **Frozen in part** when they cover only the parts named. No shipped spec is edited, frozen or not: a later change records what it supersedes in its own spec and in this index, both directions, and updates the area doc that covers that part. The only lines ever added to a shipped spec are its frozen line, its retirement pointer, and plain-text replacements for its links to its own retired plan ([spec 027](027-architecture-area-docs/spec.md) D4).

## Retired plans

A plan is deleted from the tree in a commit of its own after its feature's pull request has merged. The spec's header and this index then carry the pointer "Plan retired in `<sha>`; read it with `git show <sha>^:docs/specs/NNN-<slug>/plan.md`", where `<sha>` is the commit that deleted it. Pull requests are merged with merge commits, which keeps that commit in `main`'s history ([git convention](../git-convention.md#merging)).

## Status and plan words

- **Status:** Draft; Approved (approved, not merged); Shipped (merged; for a spike or research note, its findings ruled on); Frozen in part; Frozen.
- **Plan:** present; retirement owed (distilled, its plan not yet retired); retired (with the pointer); none (no plan was written).

## Index

| Spec | Status | Areas | Plan | Supersedes | Superseded by |
|---|---|---|---|---|---|
| [001 Rails application skeleton](001-rails-app-skeleton/spec.md) | Shipped | Release and deploy (container, Compose, Kamal); CLAUDE.md (stack, CI, hooks) | present | | |
| [002 Scryfall catalog ingestion and card search](002-scryfall-catalog-search/spec.md) | Frozen in part: FR-3–FR-6 and their Error Scenarios rows, by [catalog operations](../architecture/catalog-operations.md) | Catalog operations (FR-3–FR-6); catalog core (FR-1, FR-2, FR-7–FR-10) | present | | Non-Goals and FR-7, public search: 004 (sign-in), 023 (operator setting). FR-4, the 6-hour "already running" rule: 015 (15-minute stall, job rules). FR-3, FR-4 rate limits: amended in place for #74, #81 and 024 |
| [003 Worktree environment setup](003-worktree-environment-setup/spec.md) | Shipped | CLAUDE.md | present | | |
| [004 Design system, accounts, adding cards and the collection grid](004-design-system-collection/spec.md) | Shipped | Collection and lots; tenancy and accounts; [design system](../design-system/README.md) | present | 002 Non-Goals and FR-7: search needs sign-in | |
| [005 Card scanner phase 0](005-card-scanner-phase-0/spec.md) | Shipped | Scanner | present | | |
| [006 Collection table view and bulk editing](006-collection-list-view/spec.md) | Shipped | Collection and lots | present | | |
| [007 Card scanner live capture](007-card-scanner-live-capture/spec.md) | Shipped | Scanner | present | | |
| [008 Card scanner phase 2 spike](008-card-scanner-phase-2-spike/spec.md) | Shipped | Scanner | present | | |
| [009 Card scanner confirm flow](009-card-scanner-confirm-flow/spec.md) | Shipped | Scanner | present | | |
| [010 Card scanner art spike](010-card-scanner-art-spike/spec.md) | Shipped | Scanner | present | | |
| [011 Card scanner art matching](011-card-scanner-art-matching/spec.md) | Frozen in part: FR-2's build run, by [catalog operations](../architecture/catalog-operations.md) | Scanner; catalog operations (FR-2's build run) | present | | AC-3.2's stale-build rule: 015 AC-4.10, AC-4.11 (#73, #79) |
| [012 Build and publish Collector images](012-ghcr-registry-publishing/spec.md) | Shipped | Release and deploy | present | | |
| [013 Clean up untagged GHCR package versions](013-ghcr-untagged-cleanup/spec.md) | Shipped | Release and deploy | present | | |
| [014 Active Storage variants with vips](014-active-storage-vips/spec.md) | Shipped | CLAUDE.md | present | | |
| [015 Admin catalog operations and jobs](015-admin-catalog-and-jobs/spec.md) | Frozen, by [catalog operations](../architecture/catalog-operations.md) | Catalog operations | present | 002 FR-4: the 6-hour "already running" rule; 011 AC-3.2: the stale-build rule | AC-2.16 and the start guard: 024 (amended in place, v1.3.1) |
| [016 Scryfall hosting terms](016-scryfall-hosting-terms/research.md) (research) | Shipped | Catalog core | none | | |
| [017 Export format](017-export-format/spec.md) | Shipped | Data portability | present | | |
| [018 Content notice footer](018-content-notice-footer/spec.md) | Shipped | Catalog core | present | | |
| [019 Fit card images without cropping](019-uncropped-card-images/spec.md) | Shipped | Catalog core | present | | |
| [020 An accurate README](020-readme-introduction/spec.md) | Shipped | Release and deploy | present | | |
| [021 Mark unowned tiles without fading the card image](021-unowned-tile-marker/spec.md) | Shipped | Collection and lots | present | | |
| [022 Export a collection as a file](022-export-collection/spec.md) | Shipped | Data portability | present | | |
| [023 Browse the catalog without signing in](023-signed-out-catalog-browsing/spec.md) | Shipped | Catalog core | present | 002 Non-Goals and FR-7: public search becomes an operator setting | |
| [024 A second refresh or build waits out another's rate limit](024-refresh-rate-limit-wait/spec.md) | Frozen, by [catalog operations](../architecture/catalog-operations.md) | Catalog operations | present | 002 FR-4's rate-limit rule; 015 AC-2.16 (both amended in place) | |
| [027 Area docs hold the current architecture](027-architecture-area-docs/spec.md) | Approved | All (the documentation process) | present | | |
````

  Phase 6 changes the Plan cells of 015 and 024. Spec 027's row stays "Approved" and "present" in this pull request (AC-3.6); the `distill-feature` skill's after-merge state sets it to Shipped and retires its plan.
- [ ] Check AC-3.1: compare `ls docs/specs` (excluding `README.md` and `.gitkeep`) with the index's rows; record both lists. Check AC-3.3: for every "Superseded by" entry, record the matching "Supersedes" entry in the other row, and the reverse; fix any one-sided entry. Check AC-3.4, AC-3.5 and AC-3.6 by quoting the cells and sentences. Check that every link resolves.
- [ ] Commit: `docs(specs): add the specs index`; then `docs(027): record phase 4 verification`.

---

## Phase 5: The distillation step

**Implements:** FR-6 (skill, integrations rows), D6 | **Satisfies:** AC-4.4, AC-4.5 (rows; the firing record is Phase 8)
**Files:** `.claude/skills/distill-feature/SKILL.md` (new), `.claude/integrations.md`, `verification.md`
**Interfaces:** Consumes: the status and plan words (Phase 1, in Global Constraints) and the index's columns (Phase 4: `Spec`, `Status`, `Areas`, `Plan`, `Supersedes`, `Superseded by`). Produces: the skill name `distill-feature`, used verbatim in the integrations rows.

The spec says the skill tells "finished" from a recorded aligned implementation review, but `verification.md` files record it inconsistently (only specs 017 and 019 contain "ALIGNED"). The skill therefore looks for the review result and, when it finds none, asks the maintainer whether the feature is finished instead of guessing (plan decision; spec D6 state 1 still holds when the answer is no).

- [ ] Create `.claude/skills/distill-feature/SKILL.md`:

````markdown
---
name: distill-feature
description: Use after session-wrap, at the end of a session, to distil a finished feature into its area docs before its pull request is ready, or to retire the plan of a feature whose pull request has merged. Says "nothing to do" otherwise.
---

# Distil a feature

Keeps `docs/architecture/` current and retires plans (spec 027; rules in `.claude/rules/documentation.md`). Run it after `session-wrap`. It has three states. Check them in this order and act on the first that applies.

Never read `.kamal/secrets`, `config/master.key`, `.env*` or `storage/`; end every `git grep` with `':!.kamal/secrets'`. In an isolated worktree, run one git operation per Bash call.

## 1. After the merge: retire owed plans

Read `docs/specs/README.md`. For each row whose Plan is "retirement owed", find its feature's pull request (`gh pr list --head <NNN-slug> --state merged --json number,mergeCommit`). For each one that has merged:

1. Make sure the branch you are on will merge into `main` with a merge commit and won't be rebased afterwards (`docs/git-convention.md`, Merging). A housekeeping branch from `origin/main` is the usual place.
2. Delete `docs/specs/NNN-<slug>/plan.md` in a commit that changes nothing else: `git rm docs/specs/NNN-<slug>/plan.md`, then `git commit -m "docs(specs): retire the plan of spec NNN"` with the session's Co-Authored-By trailer.
3. Read that commit's sha (`git rev-parse HEAD`). Call it `<sha>`.
4. In a second commit: put this line under the spec's `**Frozen:**` line (or as the header's last line if it has none), with `<sha>` and the path filled in:

   ```text
   **Plan:** retired in `<sha>`; read it with `git show <sha>^:docs/specs/NNN-<slug>/plan.md`
   ```

   Set the index row's Plan to the same pointer (without `**Plan:**`), and its Status to Shipped if it was Approved. Replace every Markdown link to `plan.md` in the spec's folder (`git grep -n "](plan.md)" -- docs/specs/NNN-<slug> ':!.kamal/secrets'`) with the plain text ``plan (retired in `<sha>`)``. Change nothing else in the spec. Commit: `docs(specs): point to the retired plan of spec NNN (spec 027 D4)`.
5. Check: `git show <sha>^:docs/specs/NNN-<slug>/plan.md` prints the plan.

If no row qualifies, go to 2.

## 2. Before the merge: distil the branch's feature

Applies when the current branch is `NNN-<slug>` with a folder `docs/specs/NNN-*`, its pull request is open and not merged (`gh pr list --head <branch> --state open`), its index row's Plan is "present", and the feature is finished: its `verification.md` records the implementation review (`sdd-review` Mode B) as aligned. If the record is missing or unclear, ask the maintainer whether the feature is finished; if not, go to 3.

1. Read the spec, the plan, the `verification.md`, and the area docs of every area the index lists for the spec (`docs/architecture/README.md` for the list).
2. For each area with a doc: write into it what the feature established or changed, in the doc's own sections (its shape is in `docs/architecture/README.md`), each statement with its source inline (spec NNN AC-x, ADR, issue). Remove or rewrite statements the feature made untrue. Add the spec to Sources and one Distillation log row (date, what was distilled, this pull request).
3. For an area without a doc: write nothing there; its slice of spec 027's follow-ups will distil it. Say so in the summary.
4. A decision of lasting weight that isn't in an ADR: propose an ADR to the maintainer; don't write it without their go-ahead.
5. In `docs/specs/README.md`: set the row's Status to Frozen or Frozen in part (naming the parts and area docs) where area docs now cover it, and its Plan to "retirement owed"; add the spec's supersessions in both directions. Add the spec's `**Frozen:**` line as its header's last line, for a spec covered in whole or in part.
6. If CLAUDE.md restates a rule the feature changed, replace the statement with a pointer to the area doc.
7. Commit: `docs(architecture): distil spec NNN into <area docs>`, and record what was distilled in the feature's `verification.md`.

Don't edit any other spec (`.claude/rules/documentation.md`).

## 3. Nothing to do

Applies when neither 1 nor 2 does: no plan is owed a retirement, and the branch names no spec, or its feature isn't finished, or it is already distilled. Say "distill-feature: nothing to do" with the reason in one line, and stop.
````

- [ ] Replace `.claude/integrations.md` with (Read it first; it has the header and no rows at plan time):

````markdown
# Custom Integrations

| Trigger Skill | Custom Skill | Purpose |
|---|---|---|
| session-wrap | distill-feature | Distil a finished feature into its area docs, or retire a merged feature's plan (spec 027) |
| sdd-superpowers:session-wrap | distill-feature | Distil a finished feature into its area docs, or retire a merged feature's plan (spec 027) |
````

- [ ] Check: no `|` inside a cell value (each row has exactly four `|`); the skill's three states match D6 and run after-merge first (AC-4.4); the skill says it must not change a spec beyond D4. Record in `verification.md`.
- [ ] Commit: `chore(skills): add the distill-feature skill` (the skill); `chore: offer distill-feature after session-wrap` (`.claude/integrations.md`); `docs(027): record phase 5 verification`.

> **Risk noted for Phase 8:** the plugin's hook (`scripts/hooks/post-skill-integration-check.sh`) matches `.tool_input.skill_name`, while the Skill tool's input field in this harness is `skill`. If the field differs, the hook never fires for either row. Phase 8 records what actually happens.

---

## Phase 6: Plan retirement

**Implements:** D7, ruling OD2 | **Satisfies:** AC-5.2, AC-5.3, AC-5.4
**Files:** `docs/specs/015-admin-catalog-and-jobs/plan.md` (deleted), `docs/specs/024-refresh-rate-limit-wait/plan.md` (deleted), `docs/specs/015-admin-catalog-and-jobs/spec.md`, `docs/specs/024-refresh-rate-limit-wait/spec.md`, `docs/specs/024-refresh-rate-limit-wait/verification.md`, `docs/specs/README.md`, `verification.md`
**Interfaces:** Consumes: the frozen lines (Phase 3), the index (Phase 4), `<base>` (Phase 0). Produces: two retirement pointers; from here on the branch is never rebased.

Retire the plans of specs 015 and 024 in two commits each, and prove they read back.

- [ ] Before starting: confirm the branch won't be rebased again (Global Constraints). If `main` has moved, merge it now: `cd <worktree> && git merge --no-edit origin/main` (after a `git fetch -q origin` in its own call).
- [ ] Delete spec 015's plan: `cd <worktree> && git rm -q docs/specs/015-admin-catalog-and-jobs/plan.md`; then commit (own call): `docs(specs): retire the plan of spec 015`.
- [ ] `cd <worktree> && git rev-parse HEAD` → `<sha015>`.
- [ ] Delete spec 024's plan: `cd <worktree> && git rm -q docs/specs/024-refresh-rate-limit-wait/plan.md`; commit: `docs(specs): retire the plan of spec 024`.
- [ ] `cd <worktree> && git rev-parse HEAD` → `<sha024>`.
- [ ] Add the pointers (Edit tool), with the shas from the steps above:
  - In `docs/specs/015-admin-catalog-and-jobs/spec.md`, directly under the `**Frozen:**` line:

    ```text
    **Plan:** retired in `<sha015>`; read it with `git show <sha015>^:docs/specs/015-admin-catalog-and-jobs/plan.md`
    ```
  - In `docs/specs/024-refresh-rate-limit-wait/spec.md`, directly under the `**Frozen:**` line:

    ```text
    **Plan:** retired in `<sha024>`; read it with `git show <sha024>^:docs/specs/024-refresh-rate-limit-wait/plan.md`
    ```
  - In `docs/specs/024-refresh-rate-limit-wait/verification.md` line 3, replace `[plan.md](plan.md)` with ``plan (retired in `<sha024>`)``, leaving the rest of the line as it is.
  - In `docs/specs/README.md`, set the Plan cell of 015 to the text below, and 024's likewise with its own sha and path:

    ```text
    retired in `<sha015>`; `git show <sha015>^:docs/specs/015-admin-catalog-and-jobs/plan.md`
    ```
- [ ] Commit (git add of the four files, then commit, separately): `docs(specs): point to the retired plans of specs 015 and 024 (spec 027 D4)`.
- [ ] Check AC-5.2, one git operation per call: `git show <sha015>^:docs/specs/015-admin-catalog-and-jobs/plan.md > <scratchpad>/015-retired.md`; `git show <base>:docs/specs/015-admin-catalog-and-jobs/plan.md > <scratchpad>/015-base.md`; then `cmp <scratchpad>/015-retired.md <scratchpad>/015-base.md` (expected: no output, exit 0). Same for 024.
- [ ] Check AC-5.3: `git grep -n "](plan.md)" -- docs/specs/015-admin-catalog-and-jobs docs/specs/024-refresh-rate-limit-wait ':!.kamal/secrets'` (expected: no output).
- [ ] Check AC-5.4: `git show --stat <sha015>` and `git show --stat <sha024>` each list exactly one file, deleted.
- [ ] Record all outputs under `## Phase 6`, and commit: `docs(027): record phase 6 verification`.

---

## Phase 7: Roadmap, ADR index and issues

**Implements:** FR-8 (ADR index), FR-9 | **Satisfies:** AC-6.1, AC-6.2
**Files:** `docs/roadmap.md`, `docs/adr/README.md`, `docs/specs/027-architecture-area-docs/spec.md` (its **Issue:** header line only; spec 027 isn't shipped, so this is its own record, not a D4 edit), `verification.md`
**Interfaces:** Consumes: nothing beyond the spec. Produces: issue numbers `<i027>`, `<iB>`, `<iC1>` … `<iC6>`.

The issues are public: **the controller asks the maintainer for the go-ahead before the `gh issue create` steps**, and does them itself if the subagent can't.

- [ ] Create the eight issues, one `gh issue create` per call, each with `--milestone "1.0 — First Major Release" --label housekeeping`:

  | Issue | `--title` | `--body` |
  |---|---|---|
  | `<i027>` | `Area docs hold the current architecture, starting with catalog operations` | `Spec 027 (docs/specs/027-architecture-area-docs/spec.md): the area docs folder and its rules, the specs index, frozen specs, the distill-feature step, and the catalog operations area doc, with CLAUDE.md's bullet replaced by a pointer.` |
  | `<iB>` | `Adopt YARD for Ruby documentation` | `Slice B of spec 027: a developer generates browsable API documentation for the Ruby code, with the area docs (and the ADRs, if its spec decides) linked in, without anything generated being committed or shipped in the image. Expected ADR 0023 (next free number if taken). Starting shape in spec 027's Out of Scope.` |
  | `<iC1>` | `Area doc: catalog core` | `Slice C of spec 027: catalog core gets its area doc, its CLAUDE.md paragraphs become pointers, the specs it covers freeze in the index (002 FR-1, FR-2, FR-7–FR-10; 016; 018; 019; 023), and the plans of specs now wholly frozen are retired.` |
  | `<iC2>` | `Area doc: collection and lots` | `Slice C of spec 027: collection and lots gets its area doc, its CLAUDE.md paragraphs become pointers, the specs it covers freeze in the index (004's collection part; 006; 021), and the plans of specs now wholly frozen are retired.` |
  | `<iC3>` | `Area doc: tenancy and accounts` | `Slice C of spec 027: tenancy and accounts gets its area doc, its CLAUDE.md paragraphs become pointers, the specs it covers freeze in the index (004's accounts part), and the plans of specs now wholly frozen are retired.` |
  | `<iC4>` | `Area doc: scanner` | `Slice C of spec 027: the scanner gets its area doc, its CLAUDE.md paragraphs become pointers, the specs it covers freeze in the index (005; 007–011), and the plans of specs now wholly frozen are retired.` |
  | `<iC5>` | `Area doc: data portability` | `Slice C of spec 027: data portability gets its area doc beside docs/export-format/, its CLAUDE.md paragraphs become pointers, the specs it covers freeze in the index (017; 022), and their plans are retired.` |
  | `<iC6>` | `Area doc: release and deploy` | `Slice C of spec 027: release and deploy gets its area doc, its CLAUDE.md paragraphs become pointers, the specs it covers freeze in the index (001; 012; 013; 020; and 003 and 014, whose facts stay in CLAUDE.md), and the plans of specs now wholly frozen are retired.` |

- [ ] In `docs/roadmap.md`'s housekeeping lane, after the last bullet (`#86`), add:

````markdown
- [#<i027>](https://github.com/plainprogrammer/Collector/issues/<i027>): keep the current architecture in area docs, starting with catalog operations, with a specs index, frozen specs and plans retired after merge (maintainer rulings 2026-10-15). **In progress:** [spec 027](specs/027-architecture-area-docs/spec.md).
- [#<iB>](https://github.com/plainprogrammer/Collector/issues/<iB>): adopt YARD for the Ruby code's documentation, with the area docs linked in (spec 027 slice B). **Expected ADR:** YARD (0023).
- [#<iC1>](https://github.com/plainprogrammer/Collector/issues/<iC1>): area doc for catalog core (spec 027 slice C).
- [#<iC2>](https://github.com/plainprogrammer/Collector/issues/<iC2>): area doc for collection and lots (spec 027 slice C).
- [#<iC3>](https://github.com/plainprogrammer/Collector/issues/<iC3>): area doc for tenancy and accounts (spec 027 slice C).
- [#<iC4>](https://github.com/plainprogrammer/Collector/issues/<iC4>): area doc for the scanner (spec 027 slice C).
- [#<iC5>](https://github.com/plainprogrammer/Collector/issues/<iC5>): area doc for data portability (spec 027 slice C).
- [#<iC6>](https://github.com/plainprogrammer/Collector/issues/<iC6>): area doc for release and deploy (spec 027 slice C).
````

  with the numbers the issues got.
- [ ] In `docs/adr/README.md`, replace the Expected paragraph's last sentence

  `Named by the [roadmap](../roadmap.md) and written with their specs: the backup mechanism (item 6), lots in locations (item 10).`

  with

  `Named by the [roadmap](../roadmap.md) and written with their specs: the backup mechanism (item 6), lots in locations (item 10), and adopting YARD as 0023 (spec 027 slice B), which takes the next free number if another ADR merges first.`
- [ ] In spec 027's header, replace `**Issue:** none yet; opened with the pull request (FR-9)` with `**Issue:** [#<i027>](https://github.com/plainprogrammer/Collector/issues/<i027>)`.
- [ ] Record the eight issue numbers and the two quoted lines under `## Phase 7`.
- [ ] Commits: `docs(roadmap): add spec 027 and its follow-up slices`; `docs(adr): expect ADR 0023 for YARD`; `docs(027): link the spec's issue`; `docs(027): record phase 7 verification`.

---

## Phase 8: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs; AC-4.5's firing record; NFR Reliability
**Files:** `docs/architecture/catalog-operations.md` (Distillation log PR link only), `verification.md`

Run by the controller, not a subagent.

- [ ] If `main` moved, `git fetch -q origin` then `git merge --no-edit origin/main` (never rebase). If 025 or 026 merged, add their index rows (Phase 4's form) and recheck AC-3.1 and AC-3.3.
- [ ] Open the pull request as a draft when the maintainer asks (`gh pr create --draft`, body ending with the attribution line), then get its number with `gh pr list --head 027-architecture-area-docs --json number --jq '.[0].number'` and set the Distillation log row's last cell to `[#<pr>](https://github.com/plainprogrammer/Collector/pull/<pr>)`. Commit: `docs(architecture): link the distillation's pull request`.
- [ ] Links: for every file added or changed (`git diff --name-only <base>`), check each relative link resolves to a file at the head; record the list (NFR Reliability).
- [ ] Application untouched: `git diff --stat <base> -- app lib config bin db spec script` prints nothing.
- [ ] Run `bin/ci` once (the controller only); record its last lines.
- [ ] Walk every AC of spec 027 (AC-1.1 to AC-6.2) and record, per AC, the phase that met it and the evidence line in this file.
- [ ] Hook record (AC-4.5): at the end of this session, after `session-wrap` runs, record whether the hook offered `distill-feature`, and under which trigger name. If no offer appeared, record that and open an issue (with the maintainer's go-ahead) noting the hook reads `.tool_input.skill_name`, so the step is run by name until it's fixed (spec Error Scenarios).
- [ ] Commit: `docs(027): record integration verification`.

---

## Quickstart Validation

1. Open `docs/architecture/catalog-operations.md`: it reads as the current rules of the refresh, the art build, rate limits and the admin pages, each statement with a source.
2. Open CLAUDE.md: the "Admin catalog and jobs" bullet is one short pointer; `wc -w CLAUDE.md` is at most 1,682.
3. Open `docs/specs/README.md`: every folder has a row; 015 and 024 read Frozen with a retirement pointer; `git show <sha015>^:docs/specs/015-admin-catalog-and-jobs/plan.md | head -5` prints the old plan's title.
4. Run `session-wrap`, then confirm the `distill-feature` offer appears (or is recorded as missing, Phase 8).
5. Invoke `distill-feature` on a branch with no spec: it says "nothing to do" in one line.

## Spec coverage

| Requirement | Phase |
|---|---|
| FR-1 | 1 |
| FR-2 | 2 |
| FR-3 | 4, 6 |
| FR-4 | 3 |
| FR-5 | 1 (README, rule) |
| FR-6 | 1 (rule, steering, memory), 5 (skill, rows) |
| FR-7 | 3 |
| FR-8 | 1 (git convention), 7 (ADR index) |
| FR-9 | 7 |
| AC-1.1–AC-1.7 | 2 |
| AC-2.1–AC-2.3 | 3 |
| AC-3.1–AC-3.6 | 4 (3.6 also 6, which keeps 027's row unchanged) |
| AC-4.1–AC-4.3, AC-4.6 | 1 |
| AC-4.4, AC-4.5 | 5, 8 |
| AC-5.1 | 1 |
| AC-5.2–AC-5.4 | 6 |
| AC-6.1, AC-6.2 | 7 |
| NFRs | 0 (baselines), 3 (word count), 8 (links, untouched app, `bin/ci`) |
