---
date: 2026-11-11
spec: 070 (#257)
tags: [design-system, css, screenshots, reviews]
---

# Lesson: a paragraph given a label class keeps the browser's margins, and only the screenshot showed it

## Context

Add a new copy shows the proxy's zone as read-only text under a "Location" label. The label controls nothing, so it is a `p.c-field__label` and not a `label`; the value is `p.c-field__value`. The page rendered, every system example passed, and the design review had nothing to say.

## What happened

- Nothing in the collector stylesheets resets a `p`'s margin, and `.c-field__label` sets none, so the label kept the browser's 1em (12px) above and below. The gap around "Location" was larger than the gap around every other field.
- No example measured it and the first review of the code did not see it. It was found when the Mode B reviewer compared `add-new-copy-wide-light.jpg` with its sibling fields; the screenshots had been looked at by the supervisor once and found fine.
- The fix was one CSS rule (a margin reset for `.c-decks .c-field > p.c-field__label`), written test first with a system example that read the computed margins (`12px` before the rule).

## What to do next time

When a view gives a design-system class to an element the design system doesn't draw it on (a `p` for a `label`, a `div` for a `button`), measure the element's computed box in a system example (margins, height, line-height) beside its sibling fields, and compare the screenshot with the field above and below it, not only for overflow. The element's own class doesn't carry the user-agent defaults away.

## Signals to watch for

- A `p`, `div` or `span` carrying `c-field__label`, `c-btn` or another class that the CSS defines for a different element.
- A page whose spacing looks looser around one field in a screenshot and no example covers its box.
