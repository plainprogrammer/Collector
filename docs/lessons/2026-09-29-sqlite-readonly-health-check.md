---
date: 2026-09-29
spec: "001"
tags: [sqlite, health-check, operations]
---

# Lesson: Detecting an unwritable SQLite database needs a real write

## Context

Feature 001, review round 1: the spec required `/up` to fail when a database is unreachable or unwritable; the stock Rails health check never touches the DB.

## What happened

On a 0444 SQLite file, `SELECT 1`, `BEGIN IMMEDIATE`, and Rails' default immediate transactions all succeed, and `raw_connection.readonly?` is false. Only an actual write raises `SQLite3::ReadOnlyException`. The fix (`HealthController`) rewrites `PRAGMA user_version` with its current value inside a rolled-back transaction. In the container test, restoring only `production.sqlite3` to 0644 left the DB unwritable: while read-only, SQLite had recreated `production.sqlite3-shm` with 0444.

## What to do next time

Probe writability with a no-op write, not a read or `BEGIN IMMEDIATE`. When recovering from a permissions incident, fix all of `production.sqlite3*` (main, `-wal`, `-shm`) and restart. Known limits: an already-open pooled connection won't notice a file turning read-only until reconnect; a deleted DB file in a writable dir is silently recreated.

## Signals to watch for

A health check or readiness probe for SQLite; "database is locked/readonly" after a restore; a container staying unhealthy after permissions were "fixed".
