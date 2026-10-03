---
date: 2026-10-03
spec: "008"
tags: [sdd, spec-update, verification, provenance]
---

# Lesson: A spec update that changes a checked chain must update its verification steps

## Context

Feature 008 (card scanner Phase 2 spike), Phase 10, added in spec v1.2.0 for full-index art matching, and the Phase 9 integration verification that followed.

## What happened

Spec v1.2.0 (AC-1.3) allowed a second settings commit, `5ce0238`, which adds only the index's description, so the held-out full-index run could pass the held-out guard. The fixtures' top-level `settings_commit` therefore moved from the freeze `39cdc6e` to `5ce0238`. Phase 9's held-out provenance check, written before v1.2.0, compared every held-out slot with that one top-level commit. It reported 189 failures, although every record was correct when checked against its own settings commit. The mismatch surfaced only at verification time. It cost a ruling in a commit body, a note in the plan and an item in the implementation review.

## What to do next time

When a spec update adds a step to a chain that the plan verifies (commits, files, runs, indexes), search the plan for every verification step that reads that chain and update it within the same `sdd-spec-update`. Run the updated check once against the new data before calling the plan revised.

## Signals to watch for

A spec version that adds an exception to a "one X" rule, such as "one settings commit", "one index" or "one run per half". A verification one-liner that compares many records with a single top-level value.
