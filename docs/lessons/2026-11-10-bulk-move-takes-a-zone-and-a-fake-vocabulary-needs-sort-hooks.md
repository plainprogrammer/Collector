---
date: 2026-11-10
spec: 064 (#251)
tags: [lots, bulk-move, specs, vocabulary]
---

# Lesson: `Lot::BulkMove` takes a deck's zone as its destination unchanged, and a fake vocabulary used with its sort must answer the sort's hooks

## Context

Spec 064 moves the lots of a dropped zone into the deck's Considering zone. The plan reused `Lot::BulkMove` with that zone as `to`, rather than writing a sixth `lot_key` builder, and the plan review traced `existing_targets`, `key_for`, `check_cap!` and `move_alone!` to confirm that a zone's id works exactly as a place's does. Only the class's comment changed.

## What happened

- The reuse worked with no change of behaviour: lots keyed by the zone's id, merges into the lot already in Considering, the cap checked for every merge before any write, and `moved` as the number of copies. It also gave the cap refusal its message and its choice of the lot to name for free.
- The one example that moves lots out of two zones of a registered test format (the type `fake`, two formats) failed with `undefined method 'finish_order'`. `BulkMove` sorts through `CollectionTable::Sort.default_order`, which asks every registered collectible's vocabulary for `finish_order` and `conditions`, not only the one the lots belong to. The vocabulary the plan borrowed from the import's apply spec (`formats` only) had never met that sort.

## What to do next time

A test vocabulary registered in `Catalog.collecting` for the decks seam must also answer `finish_order` and `conditions` (an empty array and an empty hash do) as soon as anything under it goes through a sort that reads every registered type: the bulk move, the collection table, the bulk removal's Undo. `Lot::BulkMove` may take a zone of the account as its destination when the caller's lookup keeps a lot out of a deck's own row; its comment says so, and the collection's Move to… still passes a place or none.

## Signals to watch for

- `undefined method` for a vocabulary hook in a spec that registers a fake type.
- A new caller of a "move to a place" class that passes a different kind of location: read the class's key builder and its destination lookups first.
