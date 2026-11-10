---
date: 2026-11-10
spec: 055 (FR-2), issue #283, PRs #277, #284
tags: [dependencies, dependabot, solid-queue, testing]
---

# Lesson: a stale Dependabot branch, and a patch release that rewrote job rows

## Context

Five Dependabot PRs were waiting on 2026-11-10. Four were green and merged. #277 (`solid_queue` 1.7.0 → 1.7.2) failed one example, `spec/models/catalog/operation/queue_spec.rb:123` (spec 055 FR-2: "Retry now" leaves a job's Active Job id and arguments as they were).

## What happened

**A patch release changed what is stored in a job's row.** solid_queue 1.7.2 gives a concurrency slot back only to the semaphore it came from (rails/solid_queue#831). To know which semaphore that is, it records it under `solid_queue_concurrency_lock` in the job's stored `arguments` when it dispatches a concurrency-limited job. `Catalog::RefreshJob` uses `limits_concurrency`, so `Catalog::Operation::Queue#run_now` now changed the column. The example compared the whole column. The job's own Active Job arguments and id hadn't changed. The maintainer ruled (#283, option A) that FR-2 means the Active Job id and arguments, and #284 narrowed the example and recorded the reading in `catalog-operations.md`.

**The Dependabot branch was stale.** By the time #277 was looked at, `main` had moved through several merges: four other bumps, specs 058 and 059, and plan retirements. Diffing `main` against the Dependabot branch showed 59 files and about 2,000 lines, and reverted all of that work. Its real change was two lines of `Gemfile.lock`: the gem's version and checksum. #284 applied just those two lines on a fresh branch from `origin/main`, and #277 was closed as replaced.

## What to do next time

- Before merging a Dependabot PR that `main` has passed, check `gh pr view N --json mergeable` and diff its branch against `origin/main`. If the branch is behind, take only its manifest and lockfile lines onto a fresh branch, or ask Dependabot to rebase (`@dependabot rebase`). Don't merge a stale branch's tree.
- Applying the lockfile lines by hand also avoids `bundle update`, which asks permission in this project.
- A spec that compares a whole stored column of a library's table (Solid Queue's `arguments`) depends on that library's bookkeeping, which can change in a patch release. Compare the fields the spec actually promises.
- When a bump fails a spec, read the release notes before changing either the code or the spec. Here they named the cause in one sentence.
