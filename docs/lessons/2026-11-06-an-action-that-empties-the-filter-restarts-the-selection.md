---
date: 2026-11-06
spec: "041"
tags: [bulk-mode, selection, spec-review]
---

# Lesson: A bulk action that moves lots out of the selection's filter restarts the selection

## Context

Bulk mode's selection is tied to the name filter, location filter and sort it was made under, and it is either ticked lots or every matching lot with exceptions (spec 006 FR-4; spec 037 decision 5). After Set condition the lots holding the changed copies stay selected through `BulkSelection#include!` (spec 006 AC-6.5); after Remove the selection restarts empty (spec 006 AC-7.3; spec 037 AC-5.6).

## What happened

Spec 041's first draft kept the moved lots selected "as Set condition". Spec review round 1 traced it against `BulkSelection` and `CollectionTable::SelectionState`: under a location filter the moved lots no longer match, so with every matching lot selected, `include!` only drops exceptions and `all_matching` stays true. The header would render ticked over rows that are not selected, the bar would read "0 of <m> selected", and the next action would answer "None of the selected items are in your collection any more." because the header is submitted ticked. The spec settled it in decision 6: under All locations the moved lots stay selected (AC-3.9); under a location or "No location" the selection restarts, as after Remove (AC-3.13). `BulkSelection#after_move!` does exactly that.

## What to do next time

- For any new bulk action, ask whether it can move lots out of the selection's own filter (a place, a name, a condition filter if one comes). If it can, restart the selection under the same context; if it can't, `include!` the changed lots.
- Trace the "every matching lot" state, not just ticked lots: it is where a stale selection shows.

## Signals to watch for

- "As Set condition does" for an action that changes the column a filter reads.
- A selection count of "0 of N" with the header ticked in a review or a screenshot.
