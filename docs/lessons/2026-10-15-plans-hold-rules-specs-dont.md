---
date: 2026-10-15
spec: "027"
tags: [documentation, area-docs, plans, distillation]
---

# Lesson: Plans and code hold rules their specs don't, so distil from the code

## Context

Spec 027 distilled specs 002 (FR-3–FR-6), 011 (FR-2's build run), 015 and 024, and CLAUDE.md's 714-word "Admin catalog and jobs" bullet, into `docs/architecture/catalog-operations.md`. It then retired the plans of 015 and 024. The plan's draft of the area doc was written from the specs and the bullet.

## What happened

- **The draft was wrong where the specs were silent or out of date.** Checked against the code, the Phase 2 implementer corrected eight things:
  - The art build's left-behind rule doesn't depend on a worker holding the job. That condition is `#stalled?`, which only changes what the panel shows.
  - A console `perform_now` run has a job id and is judged by the 2-minute rule.
  - The core-boundary invariant covers the 15 files `spec/admin_catalog_core_spec.rb` checks, not whole folders. Spec 024's wider claim is contradicted by five comments.
  - The panel's wording changed after #84.
  - Five constants and several hooks and panel rows were missing.
- **One behaviour had no source at all.** The `poll` controller pauses while the tab is hidden, while Turbo is busy, and while a menu is open (`poll_controller.js:19-20`). It came from spec 015's plan, together with a system example that cites FR-4, but FR-4 doesn't state it. With the plan retired, the code and that example are its only record. The maintainer ruled that it gets an issue (#111).
- **Supersessions were under-recorded.** The plan expected about six supersession pairs. Phase 4's sweep of every spec's Changelog, Inputs and Supersedes lists found twelve more. It also showed that many changes were in-place amendments for issues, with no later spec, which the index records as unpaired notes.

## What to do next time

- When distilling (a slice C area doc, or `distill-feature`'s before-merge state), take the area's rules from the code at the head, read through its specs, and check every statement and constant against a file:line. The spec and any CLAUDE.md paragraph only say what to look for.
- Before a plan is retired, search it for behaviour its spec doesn't state: in its tests, comments and "also" steps. Put that behaviour in the area doc, or in an issue when no source covers it (see the memory `no-spec-source-gets-an-issue`).
- Find supersessions with a per-spec sweep: `git grep` for "spec 0NN", "feature 0NN", "specs" and "supersed", plus each spec's Changelog. Don't rely on what the planner remembers.

## Signals to watch for

- A test whose description cites a spec criterion that doesn't actually state the behaviour it checks.
- A code comment explaining a "wait while …" or "skip when …" condition with no spec or issue named.
- An area-doc draft written before anyone has opened the code.
