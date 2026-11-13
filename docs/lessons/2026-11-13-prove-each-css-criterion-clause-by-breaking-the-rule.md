---
date: 2026-11-13
spec: 080 (#343)
tags: [design-system, css, testing, process, review]
---

# Lesson: prove each CSS criterion clause by breaking its rule, and map clauses to assertions in the plan

## Context

Spec 080 added design-system blocks (`c-band`, `c-sheet`, `c-scan`, `c-scanpane`, `c-shell--focused`) with criteria that each named several properties: a size, a colour per theme, a position, a scroll rule. The plan's tasks wrote one system example per criterion in headless Firefox, then the rule.

## What happened

- Many examples passed on their first run. The rule they checked was often in the same commit or already implied by a token, so "red before green" was shown for the example as a whole but not for each clause in it.
- The Mode B review's first round returned DRIFT DETECTED. Every criterion had an example, but nine (AC-1.3, 2.1, 2.4, 3.3, 3.4, 3.7, 4.1, 4.4, 4.6) were only partly asserted: a clause such as the dark theme's colour, `box-sizing`, or the second edge of an alignment had no expectation at all.
- The fix (`f1dad843`) added the missing assertions. Each one was then proved by breaking the CSS on purpose, one change at a time (M1–M12), and watching that example fail. The failures are recorded in the commit body. Round 2 returned SPEC-ALIGNED.

## What to do next time

- In the plan of a design-system spec, list each criterion's clauses next to the assertion that checks each one, so the reviewer and the implementer count the same things.
- When an example passes on arrival, break the rule it checks (delete the property, change the value), run the example, see it fail, and restore the rule. Record each mutation and its failure in the commit body.
- A guard over a whole block (no colour literals, no `!important`, `box-sizing` on every sized rule) catches whole classes of omissions that per-criterion examples miss. Add it early, not after review.

## Signals to watch for

- A criterion with "and" in it, or one that names both themes, checked by an example with one expectation.
- A CSS example that is green the first time it runs.
