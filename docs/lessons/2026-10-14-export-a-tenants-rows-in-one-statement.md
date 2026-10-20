---
date: 2026-10-14
spec: "022"
tags: [export, sqlite, consistency, specs]
---

# Lesson: Export a tenant's rows in one statement

## Context

Spec 022 writes a collector's whole collection as one export file (format version 1). The file has a rule that a reader checks: no two lots may share an identity (entry, finish, condition, price paid).

## What happened

The first draft read lots with `find_each` in batches of 1,000, "so queries grow with batches, not lots". The read-only spec review pointed out that batches are separate statements with no shared snapshot. Suppose the collector edits a lot in another tab, or scans, between two batches. A lot already written as identity X can be revised to Y, and a new lot with identity X can be added at a higher id. The file then holds X twice, so it isn't well-formed. A `revise!` merge can also count copies twice.

Wrapping the batches in a transaction doesn't help here. Rails 8's SQLite transactions are IMMEDIATE, so they would block the collector's other writes for the whole export.

The fix was one `SELECT` that joins `lots` to `catalog_entries` and `catalog_sets` and plucks only the needed columns, ordered by `lots.id`. One statement is one snapshot. It also gives a fixed number of queries. At 50,000 lots it took about 1.25 s and +60 MB.

## What to do next time

When a feature writes a document whose rules span rows (uniqueness, totals, references between rows), read those rows in one statement. Pluck only the columns needed, so memory stays bounded. Don't use batches or several queries for it, and don't wrap reads in a transaction on this stack. State the snapshot reasoning in the spec, and test it with "exactly one statement reads `FROM "lots"`", not just "query count doesn't grow".

## Signals to watch for

- `find_each`, `in_batches` or `includes` in code that produces an export, a report total or a backup.
- A format with a cross-row rule (no duplicates, sums that must match).
- A plan that proposes a transaction to make reads consistent.
