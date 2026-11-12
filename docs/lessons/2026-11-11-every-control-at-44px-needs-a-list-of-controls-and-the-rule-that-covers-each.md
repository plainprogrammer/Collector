---
date: 2026-11-11
spec: 068 (#254)
tags: [design-system, accessibility, touch-targets, acceptance-criteria, system-specs]
---

# Lesson: "every control at least 44px" needs a list of the page's controls and the rule that covers each

## Context

Spec 068 AC-9.1 says of the four proxy pages: "every control is at least 44px on a coarse pointer", with a 60-character name at 360px. Spec 066's AC-5.6 had said the same of the deck page's head. The plan's system example measured overflow at three widths in both themes and nothing about touch size.

## What happened

- The implementation review's first round found the add-a-proxy chooser's `main` lacked the `c-decks` class, which carries the Decks pages' 44px floor for `c-btn` and their long-title wrap. The Search and Choose buttons were 28 to 38px. It also found the deck page's new "Add a proxy" link was 40px on touch. The example had never tried a long deck name either, only a long card name.
- The second round, after those fixes, found the remaining controls: the chooser's Set select was 40px and the form's Finish select 36px. The design system has no coarse-pointer floor for a select anywhere (the card page's Move copies select is 36px too). The fix was one `@media (pointer: coarse)` rule scoped to `.c-decks`, under its own heading comment.
- Headless Firefox has a fine pointer, so no example can measure a coarse pointer's size. The examples read the stylesheet's rule (the media rule, its selectors, the resolved `--touch-floor`) and measure the buttons as drawn, which is only a lower bound.
- The same AC failed in two review rounds because the plan said "every control" and listed none.

## What to do next time

When an acceptance criterion says "every control" (or "each touch target"), the plan lists each control type on each page (button, small button, link, select, number field, menu trigger) and, for each, the rule that gives it the floor and the example that reads that rule. Give the page's heading the worst-case name (60 characters, no space) in the same example. State once that headless Firefox can't emulate a coarse pointer, so the examples read the rule. Where the design system has no rule for a control type, decide in the spec whether the page adds one (scoped to the page) or the AC names an exception.

## Signals to watch for

- "Every control", "each touch target" or "at least 44px" in an AC, with an example that measures only overflow.
- A new page that doesn't carry the class its sibling pages use for the touch floor and the long-name wrap (`c-decks`).
- A `select` or number field on a page that must meet a touch floor: the design system sizes them at 36 to 40px.

## Again in spec 075 (#316): the audit is per control and names the rule that covers each

Spec 075's audit of the small controls (small buttons, filter chips, the view switch) was first a table of pages. Spec review round 1 found it wrong in the way this lesson predicts: two more page families already gave their buttons 44px at every pointer (number entry's list, the scanner's adds, undos and sitting), so an acceptance criterion that every small control with no page rule is under 36px at a fine pointer could not have passed, and several controls (the card search's "Show all", the printings page's quick add, the pagers, four job chips, not five) were missing. The table became one row per control family with a "Rule today" column (`none` for the touch block's 40px, `page` for a page rule), and the examples assert each listed control is drawn, with nothing injected, before the CSS exists, so a wrong selector or fixture fails in the red run and not at the green one.
