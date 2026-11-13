---
date: 2026-11-13
spec: 081 (#363)
tags: [testing, databases, backup, plans]
---

# Lesson: a second test database has three traps

## Context

Spec 081 added a prices database to every environment, so the test environment went from one SQLite file to two. The backup examples run the app's commands in child processes on scratch volumes (`app_command` in `spec/support/backup_helpers.rb`).

## What happened

Each of these traps was found by a plan review, not by a failing run:

- **`DATABASE_URL` reaches the primary only.** Rails reads `<NAME>_DATABASE_URL` for every other database (`database_configurations.rb`, `environment_value_for`). A child process given only `DATABASE_URL` opened and migrated the suite's own `storage/test_prices.sqlite3`.
- **`SCHEMA` becomes every database's schema file.** `schema_dump_path` returns `ENV["SCHEMA"]` for each database. One shared path means one database's dump is loaded into the other on the next command.
- **A plain `db:migrate VERSION=` with two databases runs only pending versions.** So a rollback to an older version silently does nothing, and the example that relied on it would have gone red without saying why. `db:migrate:primary VERSION=` rolls the primary back.

## What to do next time

- When a change adds a database, grep the suite for `DATABASE_URL`, `SCHEMA` and `db:migrate` with `VERSION` before planning. Each child process gets a URL per database. Each command gets its own `SCHEMA` path that doesn't exist yet, so both databases are built by migrations. Every rollback names its database.
- Make the cleanup of committed examples cover every database, and add an example that proves it.

## Signals to watch for

- A helper that sets `DATABASE_URL` and nothing else.
- A fixed `SCHEMA` path reused across commands in one example.
- `db:migrate` with `VERSION` and no database name in a multi-database app.
