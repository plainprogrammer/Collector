---
date: 2026-11-13
spec: 086 (#375)
tags: [smoke, ci, containers]
---

# Lesson: a smoke leg that expects a refusal must bound its wait

## What happened

The first plan for spec 086's `bin/backup-smoke` leg ran the image's default command in the foreground and failed the leg if it exited zero. The plan review saw the hole: on an image that does not refuse (`main`, or a later regression) the container starts a server that never exits, so the leg never reaches its failure line and the CI job ends at its timeout without naming the spec. The leg now runs the container detached, polls its state for the script's own allowance, fails with the spec's name if it is still running, and asserts the exit status is exactly 1, so a kill is not taken for a refusal.

## What to do next time

- A proof that a container must stop is written to fail fast when it keeps running: detach, poll with a bound, then read the exit code and the log.
- Record the deviation from a spec's wording ("foreground") in `verification.md` when the observable stays the same.
