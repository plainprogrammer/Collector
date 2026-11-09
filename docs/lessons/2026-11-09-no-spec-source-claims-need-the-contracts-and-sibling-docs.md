---
date: 2026-11-09
spec: "none"
tags: [documentation, area-docs, review]
---

# Lesson: Before an area doc says "no spec source", read the spec's contracts; after a ruling, grep every area doc for its issue

## Context

#231 records the maintainer's rulings from #218 and #219 in `docs/architecture/scanner.md`, which marked each of the behaviours "no spec source" (the scanner's policy extras, the replay and strips being local-only, the Other printings 404). The first draft replaced those marks with "decided by #219" and said no shipped spec states them.

## What happened

The implementation review (read-only, Opus) found three of those claims false. Spec 007's `contracts/api.md` lists the scanner's whole header, extras included, and marks the replay and strips "local requests only"; spec 009's contract gives Other printings' 404. The contracts were already in the doc's Sources. What is true is narrower: stated in a contract, in no acceptance criterion. Only the photos route's local-only rule has no spec text at all.

The review also found `tenancy-and-accounts.md` still saying ruling 6 had no source and was open in #218 (a table row, a "Six behaviours" count and an Issues line), so two area docs disagreed about one fact.

## What to do next time

- Before writing "no spec source", grep the spec's `contracts/`, `data-model.md` and `research.md` as well as `spec.md`'s criteria, and say which of them states it ("in the contract, in no criterion").
- When a ruling resolves a "no spec source" item in one area doc, run `git grep -n "#<issue>" docs/architecture/ ':!.kamal/secrets'` and update every doc that lists it, including counts ("Six behaviours").
- In a run with several workers editing one doc, edit only your own clauses and recompute any shared count from the clauses left when you merge `origin/main`.

## Signals to watch for

- An area doc's "no spec source" mark written by the same agent that found the behaviour in code, with no search of the spec directory.
- An issue number that appears in two area docs' open-issue lists.
