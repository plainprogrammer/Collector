---
date: 2026-11-13
spec: 086 (#375)
tags: [start-check, sqlite, reviews, measurement]
---

# Lesson: measure what the app's own connection leaves before a check relies on a file's size

## What happened

Spec 086's decision 7 made a primary "there" only if it is not empty, so that a `runner` that merely connects on an orphan volume would not disarm the start check. It assumed that opening a connection to a new path leaves an empty file. A bare SQLite open does (a probe showed 0 bytes), but the application's own connection does not: Rails' SQLite adapter sets WAL mode on connect, which writes the first page. The round-2 spec review caught it by reading the adapter; the plan's measure example, run in a child with `app_command`, showed 4096 bytes. The size rule covers only a `touch` or a bare open, and the spec records the rest as an accepted limit.

The same decision turned on direction. The restore refuses cautiously, counting a dangling symlink as occupied. A start check must err the other way for the primary: a dangling link is not a primary, because `db:prepare` would create a blank database at its target.

## What to do next time

- A rule that depends on what a tool leaves on disk is measured with the app's own path (a child process through `app_command`), not with a bare library open, before the spec states it.
- When reusing a check's definition (here `Databases#occupied`), ask which way its error is cautious and whether the new use needs the opposite.
