---
date: 2026-11-11
spec: 074 (#326)
tags: [testing, design-system, fixtures, deck-page, phone-width]
---

# Lesson: correcting a fixture to match the page can expose the page's own bug

## Context

Spec 068 gave a deck row with no proxy an empty menu cell. The design-system fixture (`menu_cell` in `design_system_deck_components_spec.rb`) and the two DeckPage previews kept drawing a menu on every row. Spec 060's example "lines up the right edges of Cost, Total and the menu in every zone at 360px" stayed green on that fixture.

## What happened

- Spec 074's first task was to make the previews true. With the fixture also corrected, that example failed by 30px.
- A probe on the real page (Main with a proxy row, Sideboard with an owned card, a 360px viewport) showed it was the page: the menu column was 46px in Main and 16px in Sideboard, so Cost and Total sat 30px apart. The bug had shipped with spec 068.
- Fixing it (a 4rem floor on the menu column) grew the issue by a spec version, an Opus review of the change and a worst-case measurement.

## What to do next time

When a fixture or a preview is corrected to match what the page builds, run every example that reads it before committing. Treat a new failure as the page's until a probe on the real page (not the fixture) says otherwise, and stop and ask before changing an assertion.

## Signals to watch for

- A fixture comment that says "every row has X" where the page renders X for some rows only.
- A layout example that has never seen a zone, row or state whose cells are empty.
