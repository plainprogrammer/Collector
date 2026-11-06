---
date: 2026-11-06
spec: "038"
tags: [merge, documentation, parallel-work]
---

# Lesson: Parallel specs conflict in the same doc rows; keep both sides, and drop lines both sides deleted

## Context

Spec 038 was built in parallel with specs 037, 039 and 040. Each merged to `main` first, and 038's branch merged `main` twice before its pull request could merge.

## What happened

Every merge conflicted in the same places:

- an area doc's Sources line, its Issues line ("open: …") and its Distillation log;
- the specs index's rows, both the merging spec's own row and the Superseded-by cells of older specs that two specs supersede in part;
- `db/schema.rb`'s version line.

None was a real disagreement: each side had added its own spec. One conflict looked like a choice but wasn't. Spec 040 closed #56 and spec 038 closed #64, and each deleted its own line from the area doc's "Accepted limits and open issues" list. Git showed the two deletions as a conflict between the two remaining lines, but the right resolution drops both lines.

## What to do next time

- **Sources and Distillation log:** keep both specs' rows.
- **Issues line:** rebuild it, putting every issue either side closed under closed and leaving open only what neither side closed.
- **Accepted-limits block:** when each side deleted a different item, drop both items.
- **Index Superseded-by cell:** take `main`'s cell and append this branch's sentence. For the spec's own row, take each spec's row from the side that owns it.
- **`db/schema.rb`:** take either side, then run `bin/rails db:migrate` and restore the cable, cache and queue schema files. Check that `git diff origin/main -- db/schema.rb` shows only this branch's columns.
- **Afterwards:** run the specs that pin shared lists (navigation positions, the export Coverage guard, the seeds) before pushing.

## Signals to watch for

- `<<<<<<< HEAD` inside a `## Sources`, `## Distillation log` or "Accepted limits" section.
- A conflict block where each side holds a line the other side deleted.
- Several specs in flight against the same area doc at once.
