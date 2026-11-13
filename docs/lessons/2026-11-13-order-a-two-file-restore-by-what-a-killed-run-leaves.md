---
date: 2026-11-13
spec: 081 (#363)
tags: [backup, restore, databases, reviews]
---

# Lesson: order a two-file restore by what a killed run leaves, then trace the next boot

## Context

Spec 081's backup holds two SQLite files, the primary and the prices database. A restore links each into place, and two links can't be one atomic step: a run killed between them (`kill -9`, a power loss) runs no cleanup.

## What happened

- **The order was chosen by the killed case.** Prices go first and the primary last, so a killed run never leaves a primary without its history. With the other order, the first start would have created an empty prices database beside the restored primary and lost the history without a word.
- **What happens next was first written down wrong.** The spec said that starting Collector on a volume with a prices file and no primary "gives a blank instance". The second spec review traced `db:prepare`: it leaves alone a database that already has its `schema_migrations`. So a start creates a blank primary and keeps the stale prices. The new catalog then hands out new printing ids, and the old history attaches to the wrong printings. That is worse than blank.
- **The fix had three parts.** The restore's refusal and the documents now say never to start on such a volume. A start that refuses it became its own issue, #375.

## What to do next time

- For any multi-file write that can't be atomic, list each state a kill can leave. Then for each state, trace what the next command does with it: the restore's re-run, and also the app's start (`db:prepare`, initializers, jobs). Write that trace into the spec.
- Prefer the order whose leftover is refused loudly by the next command over one whose leftover is silently built on.

## Signals to watch for

- A spec that says what a leftover file "gives" without naming the code path that reads it.
- "Both or neither" claimed for more than one rename or link.
