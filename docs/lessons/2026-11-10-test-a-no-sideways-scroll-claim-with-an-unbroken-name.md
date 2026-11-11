---
date: 2026-11-10
spec: 065 (#252)
tags: [css, testing, phone-width, design-system]
---

# Lesson: "the page does not scroll sideways" is only tested by a name with no space in it

## Context

Spec 065's Error Scenarios row says a long deck or zone name is clipped in the select and "the page does not scroll sideways". The first browser examples used a 60-character name made of words and passed at 360px. The throwaway screenshot pass then used `"W" * 60`, and Move copies came back `[360, false]`: its page head's stats line holds the place label, a flex item cannot shrink below an unbroken word, and `.c-pagehead` has no wrap rule. The same page overflowed for a 60-character place name since spec 032; nobody had measured it with a name that has no break point.

## What happened

- A name with spaces wraps at the spaces, so it proves nothing about overflow.
- The page was one of the spec's own surfaces, so the claim was false as written; the smallest correct fix was one rule (`.c-pagehead__stats { overflow-wrap:anywhere; }`), with the example switched back to the unbroken name so it can fail.
- `overflow-wrap:anywhere`, unlike `break-word`, lowers the element's min-content width, so a flex parent shrinks and no `min-width:0` is needed.

## What to do next time

When a spec promises "no horizontal scroll" for a user-chosen name, the example uses the longest allowed name with no space in it (`"W" * 60` for a 60-character limit) in a 360px narrow frame on every page the name reaches, and a failing run (`[360, false]`) is seen once before the fix. Check each page head, table cell, list row and select the name appears in; the browser pass, not the request specs, is where this shows.

## Signals to watch for

- A narrow-frame example whose test data has spaces in the long name.
- A `.c-pagehead__stats` or similar line that interpolates a user's name.
- `open_in_narrow_frame` returning `false` as its second value.
