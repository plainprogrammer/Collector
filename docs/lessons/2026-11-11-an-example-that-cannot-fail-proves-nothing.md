---
date: 2026-11-11
spec: 066 (#253)
tags: [testing, deck-page, specs]
---

# Lesson: an example whose fixture cannot produce the thing it asserts absent proves nothing

## Context

Spec 066 AC-6.6 says a printing with no face data is in Other with a muted dash and no legality marker. Magic's answer (`MTG::Collecting.deck_card`) was written, reviewed and had a model example for exactly that sentence, and the whole branch was green.

## What happened

- The model example built a printing with `faces: []` and a `"banned"` legality for Modern, but asked for the deck's format as `"casual"`. Casual has no rules, so no card ever has a marker there: the example passed whatever the code did with the faces.
- The code checked only that an extension record existed before reading the stored legalities, so in a real Modern deck a printing with no face data showed "Banned". The Mode B reviewer flagged the proof as partial; the implementer who tried to write the missing request example in a Modern deck found the page contradicted the criterion.
- The fix was one condition (`printing && face && …`), written test first once the example used a format with rules.

## What to do next time

Before trusting an "absent" assertion (no marker, no row, no error), check that the fixture could produce the present case: change one input of the example to the value that should make the thing appear (here, a printing with face data in the same Modern deck) and see that it fails. Put the rule-bearing input in the example, not a neutral one.

## Signals to watch for

- An example whose title says "no X" and whose setup uses the one input (a default, a no-rules format, an empty list) under which X never appears.
- A criterion proved in a model spec only, with the request or system spec for it left out of the plan.
