---
date: 2026-11-13
spec: 091 (#402)
tags: [licences, ci, policy]
---

# Lesson: an exception for a gem that passes the any-one-of rule reads as stale

## Context

Spec 091's licence check passes a gem that declares several licences when any one is allowed. `vcr` declares `Hippocratic-2.1` and `MIT`, and the maintainer ruled it a named exception because its `MIT` is unverified.

## What happened

Under the first draft's rules, `vcr` passed on `MIT`, so an ordinary exception for it was "allowed without it" and the check called it stale. An exception could not express "don't trust the allowed alternative". Spec 0.5.0 added `all_required: true`: every licence of such a gem must be allowed, so the gem fails without the exception, and the exception goes stale only when every licence is allowed.

## What to do next time

- When a rule has an "any one passes" clause, ask what an exception means for a component that already passes by it, before writing the stale rule.
- Say why a non-obvious form exists in the spec and in the file's header, as spec 091 decision 3 and `config/licence_policy.yml` do: the next exception will be copied from it.

## Signals to watch for

- A "stale when it would pass without it" rule beside a rule that lets a component through on one of several values.
