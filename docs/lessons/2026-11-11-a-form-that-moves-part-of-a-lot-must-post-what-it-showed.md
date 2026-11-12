---
date: 2026-11-11
spec: 070 (#257)
tags: [forms, double-submit, concurrency, lots, sdd, reviews]
---

# Lesson: a form that moves part of a lot can't detect its own replay from the number typed, so it must post what it showed

## Context

Spec 070's Use my copy page lists free lots, each with a number field, and moves that many copies into a zone while lowering a proxy. The first spec draft said a lot "that holds fewer copies than the page showed is a refusal" and that a second submit of one form (two tabs, a double click) never moves twice. The form posted only `lots[<id>]=N`.

## What happened

- The spec review's blocking finding: the server never learns what the page showed, so "fewer than the page showed" can't be checked. A lot of 5, 2 entered, a proxy of 4: the first submit splits it (2 move, 3 stay) and lowers the proxy to 2; the second finds the lot still free with 3 copies, 2 fits, the sum 2 fits the proxy's 2, so it moves 2 more and removes the proxy. `Lot::Move`'s own double-submit protection covers a whole move to the same place only, because a split leaves a valid lot behind.
- The fix was a hidden `shown[<lot id>]` per lot (the quantity as drawn) and, on Add a new copy, a hidden `shown_quantity` (the proxy's count). A chosen lot whose quantity is no longer the shown one, or that is no longer free, is refused with "Those copies changed…", and a missing or malformed `shown` value fails closed. A first submit always changes every chosen lot (a split lowers it, a whole move takes it out of the free set or destroys it into the zone's lot), so a second submit can't pass.
- Round 2 found the next gap: a refused page that echoed the posted `shown` values would refuse every resubmit, so the refused page writes every `shown` again from a read made after the rollback, and an example refuses once and then succeeds.
- The one hole left, a lot that returns to its shown quantity by another path between the two submits, is not a double submit and is said so in the spec.

## What to do next time

When a form takes a number of copies from a row, or lowers a count, and a replay must not repeat the write, make it post the state it showed (the quantity, the count) and have the server judge that state under the write lock, failing closed when it is missing. Write the refused page from a fresh read so its hidden fields are the current state, and add an example that submits twice and one that resubmits the refused page. Say in the spec what a "double submit" case proves and what it doesn't.

## Signals to watch for

- An acceptance criterion that says "never a double move" or "judged against what the page showed" for a form that posts only the typed numbers.
- A refusal re-rendered from the request's own parameters.
- A split (some copies) written next to a whole move (all copies): only the whole move changes the row's identity.
