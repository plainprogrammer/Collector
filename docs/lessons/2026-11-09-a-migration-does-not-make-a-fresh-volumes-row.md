---
date: 2026-11-09
spec: none (#229)
tags: [migrations, sqlite, db-prepare, test-database, backup]
---

# Lesson: a migration doesn't make a row a fresh volume needs

## Context

#229 asked for `instance_settings` to hold exactly one row: a migration that creates the row if it is missing, a database guard against a second, and `InstanceSetting.current` no longer creating it.

## What happened

On a blank volume `db:prepare` creates the database from `db/schema.rb` and records every migration as run without running one. The test database is built the same way. A data migration that inserts the row therefore helps only instances that already exist. With `current` no longer creating the row, a fresh instance, the suite and the first sign-up would have had no row. A restored older backup has the opposite problem: it brings its own row (or none), and the first start's migrations only reshape it. Seeds don't close the gap: they run only when `db:prepare` creates the database, and the suite would then depend on a `before(:suite)` insert and re-inserts in every spec that clears tables.

The fix: `CHECK (id = 1)` with the primary key holds the table to one row (SQLite's idiom for it; Rails' `add_check_constraint` rebuilds the table, which is safe when no table points at it), a data migration normalises what existing instances hold (lowest id kept as id 1, the rest removed), and `current` is `find_by(id: 1) || create_or_find_by!(id: 1)`, so two first reads at once leave one row. The area doc records the departure from the issue's text.

## What to do next time

A row the application needs to exist belongs to code that creates it with a constant key and a unique constraint (`create_or_find_by!`), not to a migration or a seed. A migration only normalises what existing instances hold. Before writing "a migration creates it", ask which of a fresh volume, the test database and a restored older backup it reaches.

## Signals to watch for

- An issue that says a migration creates a record the app reads at runtime.
- A model method that stops creating its record and relies on a migration or a seed for it.
- A suite that passes only because every example creates its own row.
