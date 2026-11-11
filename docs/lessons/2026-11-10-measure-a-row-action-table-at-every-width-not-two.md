---
date: 2026-11-10
spec: 064 (#251)
tags: [css, tables, widths, deck-pages]
---

# Lesson: a third row button overflowed the Decks page between 640px and about 1,100px, where no example measured

## Context

Spec 064 added "Change format" beside Rename and Remove in each Decks row. The row's actions sit in `td.c-table__actions`, which the export gives `width:1%`, and the name column is `nowrap` under the export's `.c-table td` rule. Spec 062's examples measured the Decks page at 360px and 1280px, and so did the first examples written for the new button.

## What happened

- The first CSS, `flex-wrap:wrap` on the buttons, stacked them one per line at every width: with a 1% cell, the cell's min-content is one button wide, so wrapping was always allowed. The plan review caught that one by reading the CSS. The fix was nowrap on a wide screen and wrap below 640px.
- That left a gap no example covered. The three buttons stay on one line from 640px up, and the name wraps only inside the zone tables' narrow container query, so a 60-character name beside three buttons made the page scroll sideways at 768px, and at 1024px when the name had no space. Only the implementation review thought to measure those widths; the frame helper takes any width, and four new examples failed three times before a CSS rule (the name wraps at every width) fixed it.

## What to do next time

When a button, a column or a longer string goes into a table row, measure `fits?` at phone, tablet and laptop widths (360, 768, 1024 and 1280), with a 60-character name both with and without spaces, before the implementation review. A breakpoint written as a viewport media query and another written as a container query disagree in the band between them: look for a rule that stops at 639px of a container while a neighbour starts at 640px of the viewport.

## Signals to watch for

- A rule inside `@container …` that makes a cell wrap, next to a rule inside `@media …` that decides whether its neighbours wrap.
- A test plan that lists only the two widths the earlier spec measured.
