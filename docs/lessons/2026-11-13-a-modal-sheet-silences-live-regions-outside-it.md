---
date: 2026-11-13
spec: 082 (#344)
tags: [accessibility, hotwire, design-system, specs]
---

# Lesson: a modal sheet silences the live regions outside it, and so does hiding a region while it is empty

## Context

Spec 082 moved the scanner's sitting control and list into sheets: native `<dialog>` elements opened with `showModal()`. Before it, every answer ("Set", Undo, an add) wrote its sentence into the layout's one `#status` region (spec 047).

## What happened

Two ways of losing an announcement turned up, one while writing the spec and one in the implementation review:

- While a modal dialog is open the rest of the page is inert, and an inert live region is out of the accessibility tree: a sentence written to `#status` behind an open sheet is not announced. Each sheet therefore got its own `role="status"` region, and decision 10's table says which region each answer writes, so that only one of them is ever in a shown, non-inert place.
- The first build hid the empty regions with `:empty { display:none }` to save space. A region that is out of the tree and is filled and shown in the same moment is the case spec 080 decision 8 already warns about: not announced. The review caught it (finding M1); the regions now stay rendered and take no space while empty (margins, not `display`).

## What to do next time

- When a spec puts content into a modal dialog, list every sentence the page announces and say, for each, which region writes it with the dialog open and with it closed.
- Never hide an empty live region with `display:none` or `hidden`; give it no size instead. Write a sentence into a region only after its container is shown (the scanner's `paneSay` waits a frame after the pane opens).
- Keep a screen-reader pass on a real phone in the owed list: headless Firefox can read the text and the element, not whether it was said.

## Signals to watch for

- A `turbo_stream.update("status", …)` answer to a form that lives inside a `<dialog>`.
- `:empty { display:none }` on anything with `role="status"` or `aria-live`.
