---
date: 2026-09-29
spec: "002"
tags: [sdd, review, process, planning]
---

# Lesson: Independent reviews of the spec and the plan paid for themselves before any code

## Context

Feature 002. The approved spec and the approved plan were each reviewed by a separate Fable subagent (sdd-review) before execution.

## What happened

- The spec review found a blocking contradiction: "skip if the source version was already applied" meant a language-setting change never took effect. Plus unbounded result groups (basic lands), unescaped LIKE wildcards, and an undecided adapter namespace.
- The plan review extracted and ran the plan's code: a regex that could never pass (`finish` matched `finished_at`), missing time helpers, 23 RuboCop offenses that would fail `bin/ci`, and a refresh that would retire the whole catalog on an unreadable file.
- The Scryfall bulk format was verified live during planning (curl against the API), removing the biggest unknown.
- With those fixed, all 8 implementation phases ran with almost no rulings, and the final implementation review found only wording gaps (spec PATCH 1.1.1).

## What to do next time

For features of this size, run a spec review and a plan review (with the reviewer executing the plan's code in a scratch copy) before `sdd-execute`, and verify external data formats live during planning.

## Signals to watch for

A plan with full code for many phases; a spec with interacting rules (skip conditions, caps, filters); an external data source whose format is known only from secondhand docs.
