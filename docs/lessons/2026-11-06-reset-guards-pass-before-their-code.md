---
date: 2026-11-06
spec: "043"
tags: [testing, tdd, jobs]
---

# Lesson: A guard for a reset passes before the reset exists; prove it red by removing the line

## Context

Spec 043 has `Catalog::RefreshJob` and `MTG::Art::BuildJob` answer `rate_limit_progress?` from the operation of the attempt a rate limit ended. Each `perform` starts with `@refresh = nil` (or `@build = nil`), so an attempt whose operation can't even be built doesn't answer with the previous attempt's object (spec 043 decision 4; the job specs reuse one job instance across `perform_now` calls).

## What happened

The plan review asked for an example on one job instance: an attempt that makes progress (count 1), then an attempt whose `Catalog::Refresh.new` raises, which must leave the count at 2. Written before the job answered at all, the example passed: the default answer is "no progress", so 1 then 2 was already true. TDD's red step couldn't show that the example detects a missing reset.

The plan made the implementer write the green code, delete the reset line, run the example (red: `expected: 2, got: 1`), restore the line, run it green, and record both runs in the commit body and `verification.md`. The same was done for the build job, and for the core guard spec (a "scryfall" comment added and reverted).

## What to do next time

- When an example guards against a bug that can only appear once later code exists (a stale memo, a missing reset, a leaked state), expect it to pass when written. Say so in the plan.
- Prove it once by breaking the code it guards, after the green step, and record the red run's output in `verification.md`, not only in a commit body.

## Signals to watch for

- A plan step "write the failing example" for an example whose subject's default already gives the expected answer.
- Instance variables assigned in `perform` or `call` and read by a later callback or rescue handler.
