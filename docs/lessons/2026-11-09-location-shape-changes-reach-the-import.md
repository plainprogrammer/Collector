---
date: 2026-11-09
spec: none (decks issue design; #49)
tags: [planning, export-format, locations]
---

# Lesson: a change to what a location is reaches the import's identity rules

## Context

Scoping decks as locations into issues (#248–#262). The draft scoped location names by parent so that every deck could have a "Main".

## What happened

The draft treated the export as "add the new data, raise the version". A builder check of the issue design found that import identifies a location by its name's comparison key and replaces the account's locations by that key. Once names are scoped by parent, that key is no longer unique, so a version 4 file couldn't be read back without a new identity (deck plus zone key). The same check found two more limits the draft hadn't touched: the 500-location limit (would zones use it up?) and the 9,999 merge cap on a "never refused" format change. #49 grew to cover import, and the format change was split off (#251).

## What to do next time

When a change alters a location's or a lot's identity, uniqueness or count, check the import apply path in `docs/architecture/data-portability.md`, the account limits and the merge cap before sizing the issue. Run a builder check on an issue-set design before filing.

## Signals to watch for

- A uniqueness index or comparison key changing on a tenant table that the export covers.
- "Never refused" in a decision that moves or merges lots.
