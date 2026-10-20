---
date: 2026-10-15
spec: "026"
tags: [css, design-system, plans, plan-review]
---

# Lesson: A plan's CSS must be checked against the export's selector specificity

## Context

Spec 026's plan drafted the number entry pattern's CSS in `collector/additions.css` (`c-numentry`). The plan's review read the rules against the spec, not against the classes in `components.css` that the same elements also carry.

## What happened

- The number and quantity inputs were meant to use the mono face through `.c-numentry__data-input`. The export's `.c-input input` (a class and an element) outranks a single class, so the inputs stayed in the sans face. The fix was `.c-input .c-numentry__data-input`.
- Add's cell was padded `--space-6` to line it up with the inputs. That put it 4px low, and no 20px token exists, so it became `calc(var(--space-4) + var(--space-1))`.
- The choice's `c-list` kept its top border, which showed a stray line under the prompt.

All three were seen only in Phase 7's screenshots and fixed by rulings.

## What to do next time

- When a plan adds a rule for an element that also carries a `c-*` class from `components.css`, find the export's selectors for that element and compare specificity before the plan is approved. A plan review checks this by reading; it runs nothing.
- Check vertical alignment against the token scale by sums (label height plus gap). Don't assume a single token lines things up.
- Screenshot the new pattern in the phase that styles it, and look at each shot before calling the phase done.

## Signals to watch for

- A new `c-<pattern>__*` class set on an input, select or list that already takes `c-input`, `c-select` or `c-list` styling.
