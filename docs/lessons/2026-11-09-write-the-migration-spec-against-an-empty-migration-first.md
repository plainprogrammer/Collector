---
date: 2026-11-09
spec: none (#229)
tags: [testing, migrations, tdd]
---

# Lesson: for a migration, commit the spec against an empty migration class first

## Context

#229's schema guard had a model spec committed red first: a second row went in. Its migration specs `require` the migration files, so before those existed they failed with a `LoadError`, and the specs were then committed together with the migrations.

## What happened

The Mode B review noted that the data step was never seen failing on its own: a `LoadError` is not a failing example, and the spec and the migration landed in one commit, so the history shows no red for the data migration.

## What to do next time

Create the migration file with an empty class (or empty `up`) and commit the spec first, so red is a failed example that names the behaviour (rows left, ids wrong), then fill the migration. The spec's `require` then loads and the run proves the example can fail.

## Signals to watch for

- A migration spec whose only recorded failure is a `LoadError` or `NameError`.
- A spec and its migration in the same commit.
