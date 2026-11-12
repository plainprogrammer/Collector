---
date: 2026-11-11
spec: 073 (#50)
tags: [design-system, phone-width, screenshots, css]
---

# Lesson: a section head with a count needs the narrowest width measured, and a grep for the rule the deck pages already wrote

## Context

Spec 073 put an "In decks" section on the card page with a count beside its heading ("3 copies in 2 decks · 2 proxy"). The spec, two plan reviews, the system examples (overflow at 360, 390, 640, 1024 and 1280px, both themes) and the implementation all passed. The screenshots were the first thing to show two phone defects.

## What happened

- At 360px `.c-section__count`'s ellipsis cut the count to "2 copies in 1 deck · 1 pr…", which loses the proxy count. At 390px the empty state's link broke as "Add / to deck".
- The repo had already met the first one: for the deck pages `additions.css` lets the count take its own line below 640px of the page container ("a cut count is information lost", `.c-zone .c-section__head`). Nobody grepped for it while drafting the spec.
- The overflow examples could not see it: a cut count is inside its box (`overflow:hidden`), so `scrollWidth > innerWidth` is false. It needed a measure of the count's own `scrollWidth` against its `clientWidth`.
- Fixed test first as spec 0.2.4 (AC-5.5, AC-5.6, plan Task 6.3) with two more rules under the section's heading.

## What to do next time

When a page section gets a count beside its heading, before the first spec draft: `git grep -n 'c-section__count' -- app/assets ':!.kamal/secrets'` for a rule that already wraps it, write the criterion as "the count is not cut" (its `scrollWidth` at most its `clientWidth`, at 360px, with the longest real count), and take the screenshots before the implementation review so the reviewer sees them. Look at every phone shot yourself: a text link inside a centred sentence may also break across lines.

## Signals to watch for

- A new `c-section__count` or any ellipsis-clipped text in a spec whose width criteria say only "no horizontal overflow".
- A criterion about a long name tested at one width and a count or tag tested at none.
