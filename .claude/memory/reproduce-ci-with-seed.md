---
name: reproduce-ci-with-seed
description: When CI fails, re-run locally with CI's exact RSpec seed as one of the first reproduction steps
metadata:
  type: feedback
---

When a CI run fails, one of the first reproduction steps is to run the full suite locally with the exact seed from the CI log (`bin/rspec --seed <seed>`; the seed is printed as "Randomized with seed N"). Do this before isolated reruns, load tests or instrumentation.

**Why:** On 2026-09-30, while debugging a CI-only failure on PR #5, the seed rerun came only after isolated loops and a CPU-load experiment. The user asked for it to be among the first steps in the future, because it's the cheapest way to rule order-dependence in or out.

**How to apply:** with `sdd-superpowers:systematic-debugging` on a CI failure, the order is: read the failed log and the screenshot artifact (`gh run view <id> --log-failed`, `gh run download <id> -n screenshots`), then run the full suite with CI's seed, then narrow down (isolated loops, instrumentation). Related: [[precommit-hook-staging]].
