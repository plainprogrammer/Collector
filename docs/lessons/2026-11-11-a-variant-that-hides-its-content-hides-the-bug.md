---
date: 2026-11-11
spec: 076 (#317)
tags: [design-system, css, components, testing, screenshots]
---

# Lesson: a variant that hides its content hides the bug in a shared component

## Context

`.c-select` is a label wrapping a name and a native select. Every filter-bar use (the collection's Location, the card search's and the proxy chooser's Set) hides its name with `c-sr`, which is absolute. Number entry's Language shows its name, as inline text, and the component had no gap between the two (#317, filed from spec 072's implementation; it looked the same before spec 072).

## What happened

- The bug could only show on the one use with a visible name; the other uses can't show it, so the issue's "check the other uses at desktop and 360px, both themes" produced 16 shots that prove nothing (the card-search pairs came out byte-identical before and after, and the collection pairs differed only in a factory set code).
- The checks that could fail were two geometry examples: the visible case measures the gap against `--space-2`, resolved by the browser through a probe element (so the example reads the design system's value and fails, not passes, if the stylesheet doesn't load), and the hidden case measures that the select starts at the label's left edge, which fails if a hidden name is ever put in flow, since the gap would push the select right.
- The fix is one rule in the component, `display: inline-flex; align-items: center; gap: var(--space-2)`. It is `inline-flex`, not `flex`, so a future `.c-select` in normal flow stays inline as before.

## What to do next time

When a shared component has a variant that hides part of itself (a `c-sr` name, a collapsed section, an empty slot), give each variant its own measurement that can fail, and don't count screenshots of the hiding variant as evidence. Read design-system values (`--space-*`, `--touch-floor`) from the browser in the example, not as numbers in the spec.

## Signals to watch for

- A component fix whose issue says "check the other uses", where the other uses draw the broken part invisibly.
- A before and after pair that is pixel-identical: it proves no regression, not that the rule works.
- A spacing rule added to one page's class instead of the component the page's markup already uses.
