---
date: 2026-11-09
spec: 055 (#77)
tags: [solid-queue, jobs, concurrency]
---

# Lesson: to run a scheduled Solid Queue job by hand, delete its scheduled entry first

## Context

"Retry now" (spec 055) runs a job that waits in Solid Queue's scheduled executions, from a request, while the queue's own dispatcher may run it too.

## What happened

Reading Solid Queue 1.7.0 showed two facts a design from memory gets wrong:

- `Job#dispatch` does not check that the scheduled entry still exists. Dispatching a concurrency-limited job that is already ready or claimed fails its own semaphore and adds a blocked entry, which later runs the job a second time. The safe move is to delete the scheduled row first, inside a `SolidQueue::Record` transaction, and dispatch only when exactly one row was removed.
- Active Job's `retry_job` queues a new row with the same Active Job id. For a moment a claimed old row and a scheduled retry row share the id, so "one row per Active Job id" is false, and the row to move is the unfinished one that holds the scheduled entry.

The examples that run a moved row use `ActiveJob::Base.execute(row.arguments)`, which is what a worker does, with the job's retry record read from the new scheduled row.

## What to do next time

Treat the scheduled entry as the lock: whoever deletes it owns the dispatch. Match rows by class, argument and "has a scheduled entry", not by Active Job id alone.

## Signals to watch for

- Any code that calls `dispatch` on a job it did not just remove the scheduled entry of.
- A lookup of a job by `active_job_id` that assumes one row.
