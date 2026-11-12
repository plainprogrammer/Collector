---
date: 2026-11-11
spec: 071 (#255)
tags: [design-system, system-specs, long-names, screenshots, acceptance-criteria]
---

# Lesson: a "no overflow with a worst-case name" criterion has to run through every state that prints the name, not only the default page

## Context

Spec 071 AC-6.1 says the Add to deck page has no horizontal overflow at 360px, 640px and 1280px, in both themes, with a 60-character deck name, a 60-character place name and a 60-character card name, none with a space. The plan's system example opened the page with that data in each width and theme and measured the select, the "My copies" text and the heading. It passed.

## What happened

- The screenshot walkthrough (a plan task of its own, run before the implementation review) included the refused states. The cap refusal, "Nothing changed. WWWW…W (S1 · 1) would have more than 9,999 copies in one lot.", names the card, and with the 60-character name it ran past the right edge of the 360px frame and was clipped. The example had never submitted the form, so no example had a state where the name sat in a sentence.
- The fix was one rule, `.c-decks .c-field__error { overflow-wrap:anywhere }`, and two examples that reach the refusal through the real form in the narrow frame, one per theme, and measure the drawn text's right edge with a `Range` (the error element's own box read as inside, because its box is clipped to its container: that first version of the example passed for the wrong reason and had to be changed to fail).
- The same class of line (`.c-decks .c-confirm :is(h1, p)`) had been added for the removal pages by an earlier spec, one state at a time.

## What to do next time

When an acceptance criterion names a worst-case value (a 60-character name with no space), list in the criterion and in the plan's example every state of the page that prints it: the default page, each refusal and notice that builds a sentence from it, the empty state, the confirmation. Give each state its own assertion, reached through the real form, and measure the text as drawn (a `Range` over the text), not the element's box. Keep the screenshot walkthrough: it is where a state nobody listed shows up.

## Signals to watch for

- A refusal or notice built by string interpolation from a name (`"#{entry.name} … would have more than …"`).
- An overflow example that only visits the page's `new` URL and never submits it.
- An example that measures an element's `getBoundingClientRect()` for overflow of its own text: a clipped box reads as inside.
