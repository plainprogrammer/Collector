---
date: 2026-11-06
spec: "048"
tags: [testing, core-guards, regex]
---

# Lesson: A core guard's `\b` doesn't see `scryfall_id` or `mtg_printing`

## Context

Spec 048 AC-2.4 added `spec/collection_places_core_spec.rb`, a guard that the seven files spec 033 changed in core name no collectible type or source. It copied the pattern of the earlier guards: `/\b(mtg|scryfall|magic)\b/i`. The plan's mutation check appended `<%# MTG %>` to a view and saw the guard fail.

## What happened

The implementation review (Mode B) pointed out that in Ruby `_` is a word character, so `\bscryfall\b` doesn't match inside `scryfall_id`, nor `\bmtg\b` inside `mtg_printing` or `MTGPrinting`, nor `\bmagic\b` inside `magic_cost`. A view that read `entry.scryfall_id` would have passed. The mutation check had used the one spelling that happens to match, a bare word in a comment, so it hid the gap.

The new guard drops the boundaries (`/mtg|scryfall|magic/i`) after a case-insensitive grep of its seven files found no legitimate hit, and its mutation checks now include `scryfall_id` and `MTGPrinting`. The same `\b` pattern is in `number_entry_core_spec.rb`, `import_apply_core_spec.rb`, `collection_import_core_spec.rb`, `collection_export_core_spec.rb`, `admin_catalog_core_spec.rb` and `scanner_sitting_core_spec.rb`: [#209](https://github.com/plainprogrammer/Collector/issues/209).

## What to do next time

- A guard that bans a name should be shown to fail with the spellings the code really uses (`scryfall_id`, `mtg_printing`, `MTGPrinting`), not only the bare word.
- Drop `\b` for names that don't occur inside ordinary words (`mtg`, `scryfall`); keep it, or list exact tokens, for short words that do (`art`, `foil`).
- When copying a guard's pattern into a new guard, run its mutation check with an identifier-shaped name.

## Signals to watch for

- A new `*_core_spec.rb` whose regex was copied from a sibling.
- A mutation check that only inserts the banned word on its own.
