---
date: 2026-11-11
spec: 075 (#316)
tags: [design-system, system-specs, coarse-pointer, test-helpers]
---

# Lesson: two rules with one selector text are told apart by stylesheet, never by selector text alone or by value

## Context

Spec 075 raises `.c-btn--sm, .c-filter, .c-seg button` to 44px on a coarse pointer in `additions.css`. `components.css` (the design export, not editable) already has a coarse rule with exactly that selector text at 40px, and the new rule wins only by source order. The examples remove or require "the block's rule" through `CoarsePointer#inject_coarse(except:, needs:)`, which spec 072 wrote to match a rule by its selector text.

## What happened

- Keyed on selector text, `needs:` passes before the change (the export's rule has the text), so "an example about a new rule fails by naming it" failed to hold, and `except:` drops both rules, so the "without the block" state shows 28px and not today's 40px.
- The first fix, keying on the stylesheet plus the declared value (`var(--touch-floor)`), was found wrong in spec review round 2: `additions.css` has two other coarse rules at that value (the selects' and the radio rows'), which a value match would also drop, and every page with a select would then change size in the "without" state.
- The helper now names a rule by selector text and a fragment of its stylesheet's URL (`{ sheet: "additions", selector: … }`); a bare selector text still matches any stylesheet, so spec 072's calls are unchanged. The block's second rule has a selector text that exists only there.

## What to do next time

When a new rule repeats an existing rule's selector text in a later stylesheet, name it by selector text and stylesheet in `needs:` and `except:`; never by value. Check what else carries the value you would key on before choosing it.

## Signals to watch for

- A new override rule whose selector list is copied from the file it overrides.
- A helper that identifies rules by text alone or by a shared token such as `var(--touch-floor)`.
- A "without the rule" state that is not today's state.
