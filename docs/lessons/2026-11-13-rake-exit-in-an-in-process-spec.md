---
date: 2026-11-13
spec: 091 (#402)
tags: [rake, specs, plans]
---

# Lesson: a rake task that calls `exit` ends the RSpec process unless the spec rescues it

## Context

Spec 091's `licences:check` task prints its problems and calls `exit 1`, like `start:check`. Its spec runs the task in-process, so a failing run is observed without a child process.

## What happened

The plan's first rake example expected the task to pass and said that a problem "fails the example". RSpec doesn't rescue `SystemExit`, so a problem would have ended the whole process, with no summary, and taken a CI shard down. The plan review (Fable, read-only) found it before any code was written. The spec now has a `run_check` helper that swaps `$stdout` and `$stderr`, rescues `SystemExit` and returns the output and the status, and the passing example runs against a policy that allows every licence the bundle declares, so a licence change fails the step in `bin/ci checks` and not a shard.

## What to do next time

- Run a task that can `exit` through a helper that rescues `SystemExit` and returns the status, never through a bare `invoke`.
- Judge the real tree in the CI step, not in a spec that a licence or dependency change can break in a shard.

## Signals to watch for

- A task spec whose passing example calls `Rake::Task[...].invoke` on a task with an `exit` branch.
