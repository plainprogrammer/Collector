---
date: 2026-11-13
spec: 090 (#380)
tags: [rails, validations, tenancy, performance]
---

# Lesson: `association(:name)` creates the association, so a guard that reads it can cause the read it avoids

## Context

`User` validates that its membership is in its account's household. The validation must not query on an ordinary update of a signed-in user, whose account the session has already loaded (spec 090 AC-4.5), so it runs only when both associations are loaded.

## What happened

The first draft guarded with `association(:membership).loaded? && association(:account).loaded?`. Calling `association(:membership)` creates the association instance even when nothing was loaded. On the next validation of the same object, the autosave check of a has-one association finds that instance and reads it, which runs a `SELECT` on `memberships` and then on `households`. No ordinary path validates a user twice, so no spec failed; the second Fable review found it by reading the Rails source (`validate_has_one_association`, `association_cached?`).

## What to do next time

- Put `association_cached?(:name)` before `association(:name).loaded?` in any condition that must not load.
- Prove it with an example that loads the record the way the request does (here `Session.includes(user: :account)`), validates it twice and updates it under a subscription to `sql.active_record`, and expects no query naming the table.

## Signals to watch for

- A validation or callback condition that calls `association(:x)` on a record that callers load partially.
- A requirement of the form "an ordinary request reads no X" with only a one-validation example.
