---
date: 2026-10-01
spec: "006"
tags: [performance, activerecord, sqlite, bulk]
---

# Lesson: Validated per-row writes don't scale to bulk actions; synthetic perf data must be realistic

## Context

Spec 006's NFR required Set condition and Remove on 5,000 lots to finish in under 2 s. The plan wrote each lot through validated ActiveRecord calls (`update!`, `Lot.add!`) and named single-statement fallbacks to use if the timings missed.

## What happened

- **The worktree's development catalog was empty,** so timings ran in a test-env `bin/rails runner` script that seeds 5,000 synthetic printings and lots inside a transaction it rolls back.
- **The first numbers were wrong.** The synthetic data had no `mtg_printings` rows, so every lot's finish validation re-queried the missing extension.
- **With realistic data the per-lot path was still slow.** Validated writes cost about 1.7 ms per lot: Set condition took 8.5 s and Undo 7.4 s.
- **The plan's fallback fixed most of it, but not all.** Non-merging rows went into one tenant-scoped `update_all` with bound parameters (`lot_key` rebuilt in SQL) and one `insert_all`. Set condition still took 3 s.
- **One query held the rest.** A `lot_key IN (…) AND id NOT IN (5,000 ids)` lookup took 2.9 s on its own. Filtering by `catalog_entry_id` in SQL and the rest in Ruby brought it to about 0.4 s.
- **Remove stays per row** at about 1.8 s, close to its 2 s budget.

## What to do next time

- For any bulk action with a time budget, plan the single-statement path for rows that need no per-row logic from the start. Keep validated per-row writes for rows that do, such as merges.
- Pin it with query-count specs (2 rows vs 12, same number of queries).
- Seed perf data with every table the models touch, including extension rows.
- Profile individual queries before blaming Ruby. Large `NOT IN` id lists in SQLite are slow.

## Signals to watch for

- A bulk NFR in the spec.
- `each(&:update!)` or `find_or_initialize_by` inside a loop over a selection.
- `where.not(id: big_list)`.
- An empty development catalog in a fresh worktree.
