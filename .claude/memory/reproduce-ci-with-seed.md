---
name: reproduce-ci-with-seed
description: When CI fails, re-run locally with CI's exact RSpec seed as one of the first reproduction steps
metadata:
  type: feedback
---

When a CI run fails, one of the first reproduction steps is to run the full suite locally with the exact seed from the CI log (`bin/rspec --seed <seed>`; the seed is printed as "Randomized with seed N"). Do this before isolated reruns, load tests or instrumentation.

**Why:** On 2026-09-30, while debugging a CI-only failure on PR #5, the seed rerun came only after isolated loops and a CPU-load experiment. The user asked for it to be among the first steps in the future, because it's the cheapest way to rule order-dependence in or out.

**How to apply:** with `sdd-superpowers:systematic-debugging` on a CI failure, the order is: read the failed log and the screenshot artifact (`gh run view <id> --log-failed`, `gh run download <id> -n screenshots`), then run the full suite with CI's seed, then narrow down (isolated loops, instrumentation). Related: [[precommit-hook-staging]].

**A flake outside the Image smoke (coordinator's ruling, spec 037, PR #174, 2026-11-06):** CI sharded RSpec prints a replay line ("Replay: CI=true bin/rspec --seed N …" with the shard's files); run that. If it passes locally, ask the coordinator (or the maintainer) before re-running the job; the standing permission covers only the `Image (linux/amd64)` smoke kill. Re-run once (`gh run rerun <id> --failed`); if it fails again the same way, don't re-run a second time: report the job URL and log excerpt. Either way, the report names the run, job, example and error (there: `spec/system/collection_spec.rb:49`, `Net::ReadTimeout` at `visit new_session_path`) so the flake can be filed.
