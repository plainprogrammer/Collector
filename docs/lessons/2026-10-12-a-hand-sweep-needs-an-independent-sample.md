---
date: 2026-10-12
spec: "020"
tags: [verification, review, documents, subagents]
---

# Lesson: A hand sweep needs an independent sample

## Context

Spec 020 required every checkable claim in `README.md` to be true of the repository. Four read-only checkers swept the file's fifteen sections in parallel and sorted 372 claims.

## What happened

The checkers found two stale claims and raised three questions. The record then said every checkable claim was true "on the four checkers' findings". The implementation review was briefed to verify at least 25 claims against the code itself, favouring numbers, defaults and names. It checked 34, and one failed: "A scheduled run is skipped when the same Scryfall file and language set were already applied" has an exception (`reapply?`) on `app/models/catalog/refresh.rb:27`, the same line the checker had cited as its evidence for the neighbouring correction. The checker read the line for one claim and didn't re-read it for the next.

The review also found that a correction made by ruling ("the ids of the closest artworks") left out the distances the same code sends.

## What to do next time

When a criterion rests on a reading ("every claim is true", "no other caller exists"), brief the final review to re-check a stated number of items independently, chosen for being specific and easy to get wrong, and to re-verify each correction's new text against the code. Report the sample size and the misses in the record. Treat a correction's new wording as a new claim.

## Signals to watch for

- A record that says "pass, on the checkers' findings".
- A conditional (`&&`, `unless`, `||`) on a line cited as evidence for a simple claim.
- A correction written from a summary of the code, not from the code.
