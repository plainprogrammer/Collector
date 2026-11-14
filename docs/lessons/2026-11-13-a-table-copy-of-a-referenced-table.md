---
date: 2026-11-13
spec: 090 (#380)
tags: [migrations, sqlite, upgrade, tenancy]
---

# Lesson: copying a table that others reference needs enforcement off before the transaction, one transaction, and a before-and-after check

## Context

Spec 090's third migration makes `accounts.household_id` `NOT NULL`. SQLite can't do that in place, so Rails copies `accounts`, which thirteen tables reference (eleven with `ON DELETE CASCADE`).

## What happened

- Inside a transaction, `PRAGMA foreign_keys = OFF` does nothing, so the copy's `DROP TABLE` runs the cascades and deletes every collector's decks, places and working state with no error. The migration therefore turns enforcement off first and opens its own transaction around the stragglers step, the copy and the sequence restore, so a failure rolls all three back.
- The copy builds a TEMP table with `AUTOINCREMENT`, which gives the connection a `temp.sqlite_sequence`; a bare `sqlite_sequence` then resolves to it. Restoring the id sequence there restores nothing. Two spec reviews and two plan reviews traced the Rails code and missed it; the first implementer found it by running the spec on a fresh test database. Read and write `main.sqlite_sequence`.
- The first post-check reported every `PRAGMA foreign_key_check` row. A database an operator edited with the `sqlite3` command (which doesn't enforce keys) holds dangling rows already, so the check would have stopped every boot after that. The check now compares the state before and after the copy (row counts of the thirteen tables, and the key violations pointing at `accounts` or `households`) and raises only on a difference.
- Rails runs no check after a copy, so the migration checks enforcement is off before it starts and the counts after.

## What to do next time

- A migration that copies a referenced table: enforcement off before the transaction, one transaction for everything that must commit together, the id sequence restored in it (as `main.sqlite_sequence`), and a post-check that compares with the state before, never with a clean database.
- Prove it with a committed spec that fills a row in every referencing table and counts them before and after, and one that makes the copy itself fail after the `DROP`.
- The refusals a migration makes on its own (an account with no user) must say how to clear them and be written in `docs/releasing.md`'s Upgrade note.

## Signals to watch for

- A migration that calls `change_column_null`, `remove_column` or `add_foreign_key` on a table with cascading children and runs inside Rails' migration transaction.
- A reading of `sqlite_sequence` with no schema prefix.
