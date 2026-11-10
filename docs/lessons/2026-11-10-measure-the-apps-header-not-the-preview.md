---
date: 2026-11-10
spec: 057 (#248)
tags: [design-system, navigation, system-specs, guards]
---

# Lesson: five header links fit in the previews and overflowed the app's header by 54.6px

## Context

Spec 057 adds Decks to the header's links (five in all). The mock-ups and the design system's own `AppHeader.html` preview showed five links fitting at 640px, where the nav first appears, so the spec and plan said "five links share one line" and planned the header check as a guard with no red run.

## What happened

- The guard measured the app's own `layouts/_appbar` (real partials, real CSS and fonts, a classic 15px scrollbar, a Decks link cloned in) in a 640px frame and failed: the account menu ended 54.6px past the bar's content edge (nav 379.6px, wordmark 138px, bar padding 32px, 625px layout width). Four links fit with about 35px to spare.
- The preview had hidden it: its header is the export's markup, not the app's, and it has no scrollbar. The same overflow would have shipped with #49, the issue that adds the Decks link.
- The maintainer chose the logo mark in place of the wordmark from 640px to 719px while the nav holds five or more links (spec 1.1.0, decision 19), measured as five links plus the wordmark fitting from a 695px viewport.

## What to do next time

Measure the app's own partials, in a frame at the real breakpoint with the real scrollbar, before a spec says that something fits; a preview or mock-up is a drawing of the design, not of the app. Give a guard a failing run before trusting it, or a control that fails when the measure sees a bad case (here the examples at 640px and 719px failed first, then the CSS turned them green).

## Signals to watch for

- A fit claim in a spec whose only evidence is a preview or mock-up.
- A guard that passes on the first run: ask what it would show if the thing were wrong.
- A width check at a breakpoint without the scrollbar's 15px (a 640px frame is 625px wide inside).
