---
date: 2026-10-08
spec: "011"
tags: [planning, review, ruby]
---

# Lesson: A plan's code blocks still need a run, even after review

## Context

Spec 011's plan (16 phases, about 3,500 lines) gave exact code for every step. It had a read-only Fable review that confirmed the design, the fingerprint ports and the ranking. Implementer subagents then ran each phase with TDD.

## What happened

The subagents found and fixed these bugs in the plan's own code, each recorded as a `Ruling:` in its commit:

- **Ruby parse:** `def confident = nearest if nearest && …`. An endless method with a trailing `if` parses as a modifier around the whole definition, and it raised NameError at class load. It needed parentheses.
- **Name clash:** a private helper `art_status(confident, final)` shadowed the public `art_status` that delegates to the ranking, making it private and two-argument.
- **Matcher:** a spec used `eq([hash_including(...)])`, which can never pass, because `eq` compares with `==` and ignores argument matchers. It needed `match`.
- **Median:** `sorted[n / 2]` takes the upper middle for an even n, and the agreement spec had n=134.
- **Ruby 4.0:** `require "benchmark"` raises LoadError, because benchmark is no longer a default gem.
- **Test isolation:** a system spec corrupted an index at a shared URL that headless Firefox had cached as immutable, so other examples failed depending on order.

The review found none of these. They surfaced only when the code ran.

## What to do next time

Treat a plan's code as a strong draft. Brief implementers that blocks may be wrong, and that a fix must keep the spec's behaviour and be recorded as a ruling. When a plan review can run code, ask it to load each new class and run the new spec files at least once ([[plan-reviews-run-the-code]]).

## Signals to watch for

- Endless methods (`def x = …`) with a trailing modifier.
- Private helpers named like public or delegated methods.
- `eq` wrapped around argument matchers.
- Hand-written medians.
- Stdlib requires that moved to bundled gems in a new Ruby.
- Immutable-cached URLs shared across system examples.
