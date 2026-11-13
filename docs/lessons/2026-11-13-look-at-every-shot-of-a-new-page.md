---
date: 2026-11-13
spec: 087 (#376)
tags: [ui, design-system, screenshots, review]
---

# Lesson: style every link a new template emits, and look at every shot before trusting the specs

## Context

Spec 087's page lists the licences in the image. Its pattern styled the links inside the rows (`.c-licences__row a`), and the two intro paragraphs above the sections held a link of their own.

## What happened

All the page's specs and both reviews passed. The first PR screenshot showed the intro's "AGPL-3.0" link in the browser's default blue, and the intro flush under the heading. No spec asserts a link's colour, and a reviewer reads the markup, not the picture.

## What to do next time

- When a new template emits a link outside the new pattern's container, give that link the brand style in the same block of `additions.css`.
- Take the screenshots before the implementation review, and look at one shot of each theme and width before trusting the rest.

## Signals to watch for

- A new page with prose paragraphs above the pattern's own sections.
- A pattern whose link rule is scoped to a row or an item class.
