---
date: 2026-11-13
spec: "083 (#361)"
tags: [spike, research, data, reviews]
---

# Lesson: A data spike's counts need cross-checks, not just totals

## Context

Research 083 counted what Scryfall's bulk files carry as prices for non-English printings, pairing each with the English printing of the same set and collector number, to settle what such a printing shows (ruling 41).

## What happened

The first findings were right in their totals and wrong in three places a reader would act on:

- **Capped examples generalised.** The script printed three examples per outcome per language. The three Spanish exceptions shown were all Portal (`por`), and the note said "11 Spanish Portal printings"; four were the Introductory Two-Player Set (`itp`).
- **A mechanism stated, not counted.** The note said the copied EUR prices sat "under the twin's `cardmarket_id`" and cited a table that counted ids and prices separately, never together.
- **A dimension not compared across the pair.** Coverage was counted per finish of the non-English printing only. 1,697 Japanese pairs are for a finish the English twin hasn't, so the recommended option had an unstated gap.

The Fable reviewer streamed the bulk file itself and found all three. The fixes were new counts (§0, §4c, §5a), not rewording.

## What to do next time

- List every exception uncapped. Sample only the common outcomes.
- For every claimed mechanism (this id explains that price), cross-count the two together in one table.
- Check the join: the key is unique on the side looked up, and a pair is the same entity (here, the same `oracle_id`).
- Compare across the pair every dimension the later display depends on (here, the finish), not only one side's.
- Record a checksum of each input file when the source doesn't keep old versions.

## Signals to watch for

- A finding that names a cause ("because of the id") with no table that holds both.
- An example table whose rows all share a set, a language or a value.
- A display rule ("show the twin's price") whose lookup key carries one dimension (set and number) while the shown value depends on another (finish).
