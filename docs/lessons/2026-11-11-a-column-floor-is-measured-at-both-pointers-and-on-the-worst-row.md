---
date: 2026-11-11
spec: 074 (#326)
tags: [css, phone-width, coarse-pointer, measurement]
---

# Lesson: measure a column floor at both pointers and on the worst-case row, and record its cost with the ruling

## Context

To keep the deck zones' columns aligned, spec 074 gives the menu column a floor. The cell's width depends on its trigger, and the trigger's size depends on the pointer (28px fine, 40px coarse today, 44px planned by #316).

## What happened

- Headless Firefox has a fine pointer, so the probe measured a 46px column with a trigger; a phone's is 58px. The floor had to clear both, so it is 4rem (64px), the wide layout's own width, not the measured 46px.
- The average rows lose only a few pixels of Card column. The worst-case row (a 60-character name with no space, six pips, 1,234 proxies) is already at its minimum width, so the 18px comes out of overflow: its table spills 19px past its container (1px before at a fine pointer, about 13px at a coarse one). The document never scrolls sideways, so the existing page-level checks stayed green.
- The coordinator ruled the cost acceptable once the numbers were in front of them; the spec records it, and a committed example fails if the page ever scrolls sideways with every coarse rule applied (see `2026-11-11-a-coarse-pointer-example-applies-every-coarse-rule-and-needs-a-can-fail-partner.md`).

## What to do next time

State a floor from the largest size any pointer gives the control, then measure the worst-case row at a true viewport (the narrow frame sized from the measured scrollbar) before and after. Compare the container's `scrollWidth` as well as the document's, and put the numbers in the spec's decision when asking for the ruling.

## Signals to watch for

- A width derived from one measurement in headless Firefox.
- A "fits at 360px" check that reads only the document, not the table's container.
