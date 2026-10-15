---
date: 2026-10-14
spec: "022, 023"
tags: [testing, tdd, verification, review, routes]
---

# Lesson: Tests that can't go red first prove themselves by mutation

## Context

Spec 022 (export, #38) added `resource :export, only: :show, format: false`, guarded by an example that `GET /collection/export.json` is a 404. Spec 023 (signed-out catalog, #59) had two refactors (lift `prefetch?`, decide collection parts with `collector?`), request specs where nine of 23 examples already passed (pages that must stay closed), and a browser spec written after the code it covers.

## What happened

- **Red-first proved nothing for these examples.** In spec 022's red run every new request example failed except the `format: false` one: with no route at all, the suffixed path was already a 404. A refactor's guards pass before and after. "This page stays closed" passes before the feature opens anything. A system spec written once the code works passes on its first run.
- **Each was proved by a temporary mutation instead.** The guard was broken on purpose with the rest of the code in place, the failure quoted, and the file restored, with `git diff` checked clean:
  - Spec 022: `format: false` removed → 200, not 404. The plan reviewer did the same with the `request_authentication` override (the redirect then went to `/collection/export`).
  - Spec 023: the prefetch header list emptied → 2 of 9 failed; `collector?` forced false → the quick-add full-lot example failed; the `c-shell--untabbed` block deleted → three pages failed with "the footer keeps the tab bar's clearance"; `request.fullpath` → `request.path` → "redirect to …/bolt-a?from=collection but was … /bolt-a".
- **The quotes went into `verification.md`** beside the red runs, so every criterion's evidence shows a failure its test can produce.
- **The thin spots were predicted.** Spec 023's `verification.md` writer listed three criteria with weaker evidence. The final sdd-review raised the first two as its only nits, and they cost one small commit.

## What to do next time

- When an example passes on its first run (a guard, a "stays closed" check, a test written after the code), break just the code it covers, watch the example fail, quote the failure in `verification.md`, and restore with `git diff` clean. Name the mutation in the commit body.
- Count a passing-first example as evidence only once it has a quoted mutation failure.
- Have the `verification.md` writer list criteria with only reading or partial evidence before the final review runs, and close the cheap ones first.

## Signals to watch for

- A new example that passes in the red run, or a TDD subagent reporting "N examples were guards, already passing".
- An example asserting a 404, a refusal or an absence.
- A guard that is one keyword (`format: false`, `only:`, `constraints:`, `skip_before_action … if:`).
- A refactor phase with no new failing test, or system specs written in a phase after the code.
- A `verification.md` row that says "verified by reading" for behaviour code could check.
