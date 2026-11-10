---
date: 2026-11-10
spec: 059 (#187)
tags: [system-specs, keyboard, accessibility]
---

# Lesson: a `tab_to(text)` that matched the focused `<body>` never pressed Tab

## Context

Spec 059 needed a keyboard check on the refusal page, so its plan moved `tab_to` out of `spec/system/locations_spec.rb` into a shared helper. The plan review found that the helper's first test, "does the focused element's text include the words?", is true before any Tab press: with nothing focused, `document.activeElement` is the `<body>`, and the body's text includes every word on the page.

## What happened

- The old `tab_to("Back to locations")` in the locations spec returned true at once, so its keyboard check never tabbed (spec 029 AC-5.5, spec 032 AC-5.2).
- Excluding `document.body` made it tab for real; the existing check still passes, so the page was fine, but the check had proved nothing until then.
- A second helper named `tab_to(id)` in `spec/system/bulk_move_spec.rb` takes an id and asserts; it shadowed the shared one inside that file. The shared helper is now `tab_to_text`.

## What to do next time

When a helper searches focus, test it against the state before any key press, and break the page once to see it fail (no button there, `tab_to_text` returns false). Name a helper for what it takes (`tab_to_text`, `tab_to_id`) so two of them can't shadow each other.

## Signals to watch for

- A keyboard example that passes with the control removed from the page.
- Two helpers of one name in `spec/support` and an example group.
