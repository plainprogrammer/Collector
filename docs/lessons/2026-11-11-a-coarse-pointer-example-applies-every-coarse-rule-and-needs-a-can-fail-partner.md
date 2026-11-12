---
date: 2026-11-11
spec: 072 (#315)
tags: [design-system, touch-targets, system-specs, firefox]
---

# Lesson: a coarse-pointer example applies every coarse rule, names the rule it needs, and has a can-fail partner

## Context

Spec 072 gives every select the 44px touch floor on a coarse pointer, with one rule in `additions.css`. Headless Firefox has a fine pointer, so the examples read the `(pointer: coarse)` rules from the loaded stylesheets and apply them to the page as an adopted stylesheet (spec 068's example had only read one rule by its selectors).

## What happened

- The first plan applied the new select rule alone to measure the layout at 360px. Plan review round 1 saw that no device draws that: with only the select rule applied, buttons and text fields stay at their fine-pointer heights (28px, 36px) beside 44px selects, so the overlap and alignment checks measured a mix nobody sees. The layout examples now apply every rule of every coarse block, in source order, as one sheet; the select rule alone is kept for the one example about reach.
- An example about a new rule can pass before the rule exists (apply nothing, compare identical states). Each example now passes `needs:` with the rules it is about, and the helper raises "the coarse-pointer rule … is not in the loaded stylesheets" when one is missing, so the red run names the missing rule and not a downstream symptom. AC-1.7 ("no other control changes size") and AC-1.5 ("the button is centred on the select") each have a can-fail partner: a variant that adds a taller rule, or drops the alignment rule, must change the measure.
- A taller select can push a page past the 800px frame and add a classic scrollbar, which narrows the layout by 15px and changes every stretched control's width, which is no layout defect. The two-state comparison pins `html { overflow-y: scroll }` in both states. On the scanner pages the camera stage unhides some time after `main` exists, so the example waits for it before measuring.

## What to do next time

When a spec's criterion is about what a touch screen draws, write the examples so that: the page gets every coarse-pointer rule of the shipped stylesheet (one adopted sheet, in source order), not only the new one; an example about the new rule fails by name when the rule is missing; a comparison of two states pins what else could differ between them (scrollbar, async-unhidden parts); and each such check has an example that shows it can fail.

## Signals to watch for

- A plan that applies "the rule" alone and then checks the page's layout or other controls.
- A comparison example whose two states are identical until the CSS exists (it is green before and proves nothing).
- A frame of fixed height and a page that may now grow past it.
