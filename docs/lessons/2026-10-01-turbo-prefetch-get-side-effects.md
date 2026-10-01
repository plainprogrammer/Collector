---
date: 2026-10-01
spec: "006"
tags: [hotwire, turbo, prefetch, spec-review]
---

# Lesson: Turbo 8 hover prefetch turns GET side effects into bugs

## Context

Spec 006 added a grid/table view switch whose choice is saved per user, plus a bulk mode whose selection is stored on the server. The design system's docs describe the switch and `Done` as links (`?view=table`, `href="?view=grid"`).

## What happened

Three Fable spec reviews each found a blocker in the same family:
- v2 saved the view on any GET naming it. Turbo 8 (turbo-rails 2.0.23) prefetches `<a>` links on hover, and nothing in the app turned that off, so pointing at "Table" would have saved it.
- v3 fixed the view but made `Done` (and "leaving bulk mode") a link that cleared the selection. A hover would have wiped the collector's ticks.
- The fix that held:
  - State changes go only through buttons and POST/PATCH forms (`Edit many`, `Done`, the bulk form).
  - The view switch is buttons in a GET form. Turbo never prefetches buttons.
  - The server refuses to save from prefetch-marked requests (`Sec-Purpose`, `X-Sec-Purpose`, `X-Moz`, `Purpose`).
  - A system spec counts `turbo:before-prefetch` events, with a positive control.

## What to do next time

When a spec has a GET that changes anything (preferences, selections, "last seen" markers), treat hover prefetch as a requirement from the start:
- Make the trigger a button.
- Ignore prefetch headers on the server.
- Test both: a request spec with the headers, and a system spec that counts `turbo:before-prefetch`.

Don't copy link-based markup from the design docs for anything with side effects.

## Signals to watch for

- A spec sentence like "the URL param … is saved".
- A design-system snippet using `<a>` for a stateful action.
- Any controller writing in `show`/`index`.
