---
date: 2026-11-09
spec: 055 (#77)
tags: [admin, queries, views, tdd]
---

# Lesson: a predicate the view calls on every operation puts its cheapest guard first

## Context

Spec 055 added `Catalog::Operation#retry_job_id`, which the admin catalog view asks of every operation to decide whether to show "Retry now". The plan had it read the operation's latest record, then the queue, and check `unavailable_reason` last.

## What happened

With art matching off the art operation has no start button, so the view's new `operation.retry_now?` was the first thing to touch it: it read the latest build and the queue's jobs for an operation that is switched off. An existing example, "runs the same queries however many runs and jobs there are", went red in Phase 3. The fix moved the `unavailable_reason` check to the top of the method.

## What to do next time

When a view adds a predicate that every operation (not only the active ones) answers, put the guard that needs no reads first, and look for the page's query-count example in the specs before adding the call. A model change that is correct in isolation can still add queries to every panel.

## Signals to watch for

- A new `if operation.<predicate>?` in `_operation.html.erb` or another per-operation partial.
- A plan that orders a method's conditions by how the spec words them, not by what each one costs to answer.
