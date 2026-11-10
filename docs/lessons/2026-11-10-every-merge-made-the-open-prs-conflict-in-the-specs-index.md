---
date: 2026-11-10
spec: 027 (the specs index and plan retirement), 035 (CI and the pre-push hook)
tags: [process, ci, parallel-workers, merging]
---

# Lesson: every merge made the open PRs conflict in the specs index

## Context

On 2026-11-10, four Orca workers built specs 056 to 059 in parallel (#264, #248, #250, #187) while the coordinator merged PRs as the maintainer approved them: four feature PRs, three plan-retirement PRs, two fixes and five dependency bumps. Every spec adds a row to `docs/specs/README.md`, and distillation and plan retirement change rows again.

## What happened

Almost every merge to `main` made the other open PRs conflict in `docs/specs/README.md`, sometimes in an area doc's distillation log as well:

- #279 conflicted after #280 merged.
- #282 conflicted after #281 merged; it had been green.
- #273 conflicted after #286 merged, right after its own green run; the coordinator had just merged the spec 057 plan retirement.

Each conflict is a one-line fix: keep every row. But all three branches carried code. The pre-push hook judges the whole branch against `origin/main`, so each conflict fix cost a full `bin/ci` (about 5 minutes) and a CI turn, plus a full GitHub run. #273 needed two extra pushes after its first green run. A conflicting PR also gets no GitHub CI at all (#285, the AC-4.2 scratch PR), so a conflict can look like CI that never started.

## What to do next time

- While a PR is in its last push (green CI, waiting to be marked ready), don't merge anything else into `main` unless the maintainer asks. Tell its worker that `main` is held.
- Merge docs-only PRs, plan retirements and distillation fixes after the code PRs they would conflict with, not between them. Retiring two plans in one PR (#281) also saves one conflict.
- Merge in the order PRs became ready, and tell every open worker after each merge (the coordinating skill's rule). Have them merge `origin/main` only when they push anyway or their PR shows a conflict.
- When a PR has "no checks reported" a few minutes after a push, check `gh pr view N --json mergeable` before waiting longer.
