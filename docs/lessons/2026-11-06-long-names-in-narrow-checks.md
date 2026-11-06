---
date: 2026-11-06
spec: "040"
tags: [design-system, narrow-width, testing, active-record]
---

# Lesson: Put the longest user-supplied name in every narrow-width check

## Context

Spec 040 put a location's name into two places on the scanner's sitting panel: the section heading ("This sitting: 3 cards, in Blue binder") and the options of a native select. The plan's Phase 5 asked for a 360px system example with a long location name.

## What happened

Every request spec and the design-system reading passed. The 360px example then failed with the page 793px wide. Two separate causes, found with a probe that listed every element whose right edge passed the frame:

- `c-section__title` is `white-space:nowrap` in the exported `components.css`, so a heading carrying a user's name never wraps. `.c-panel > .c-section__title` already had an override for a long catalog name; the scanner's sitting needed the same.
- `.c-field select` is a flex item with the default `min-width:auto`, so its longest option sets its minimum width and it grows past its form. `min-width:0; max-width:100%` fixed it for every form, not only this one.

Separately, a controller built its message from `sitting.location` after `Scanner::Sitting.place!` had destroyed the sitting. A destroyed record keeps its attributes and loads its `belongs_to` from memory, so the message named a place the page no longer had. Checking `persisted?` first fixed it.

## What to do next time

- When a view starts showing a value the collector types (a location, a note, a name), add or extend a 360px example that uses a long value with spaces, and assert `scrollWidth <= 360`. Check headings and selects in particular: the export's section title doesn't wrap, and a select grows to fit its options.
- When narrow-width checks fail, list the elements that overflow (`[...document.querySelectorAll("body *")].filter(e => e.getBoundingClientRect().right > width)`) rather than guessing from the screenshot.
- After a method that may `destroy!` the record it returns, branch on `destroyed?` or `persisted?` before reading its associations.

## Signals to watch for

- A new `c-section__head` or select whose text comes from the collector, not from copy.
- A method that returns "the record, or the record it just deleted".
