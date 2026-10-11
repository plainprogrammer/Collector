# 0016: SQLite in every environment, one file per role

## Status

Accepted (recorded 2026-10-11, after the fact; decided in spec 001)

**Date:** 2026-10-11
**Feature:** 001-rails-app-skeleton

## Context

Foundation principle 1 asks that anyone can stand up an instance with minimal setup and no required proprietary services. [Spec 001](../specs/001-rails-app-skeleton/spec.md) chose the database with the rest of the stack, and every later spec has built on that choice. It was recorded in `CLAUDE.md` and `.claude/rules/sqlite-and-migrations.md`, with no ADR. This one records it as the [north star](../north-star.md) is written, because data safety (backup, restore, upgrades) and a possible hosted service both rest on it.

## Decision

SQLite is the only database, in production too. There are separate files for the primary database, the queue, the cache and the cable, all under `storage/` on one host's persistent volume. Only the primary needs backing up. Rails 8's SQLite defaults (WAL, busy timeout, IMMEDIATE transactions) are kept.

## Consequences

- A self-hoster runs one container and one volume, with no database server.
- An instance runs on one host. The files can't sit on a network filesystem or be shared across hosts.
- No Postgres-only features are used (`jsonb` operators, arrays, `DISTINCT ON`, advisory locks).
- Write transactions stay short, and only one Solid Queue supervisor may run against the queue file.
- Backup and restore is a file-level operation on the primary database. The mechanism is undecided and is the [roadmap](../roadmap.md)'s item 6, which gets its own ADR.
- A hosted service at a scale one host can't carry would need an ADR that supersedes this one. Nothing in 1.0 is designed around that.
