---
date: 2026-10-01
spec: "006"
tags: [process, sdd, review, subagents]
---

# Lesson: Repeat reviews until they stop finding blockers; have implementers log rulings

## Context

Spec 006 (table view and bulk editing) went through three Fable spec reviews, one Fable plan review and two Fable implementation reviews. It was then implemented by one fresh subagent per plan phase.

## What happened

- **Each spec review found a blocker the previous revision had introduced:** a cross-tenant 404 that leaked existence, the view preference saved by prefetch, and `Done` clearing the selection on a GET. Most were in the no-script protocol, the most complex part.
- **The plan review caught code that would have crashed.** `"".split("-", 2)` → `parse()` with no arguments, on the default sort key. It also caught a phone-width test that couldn't run, and RuboCop length violations that would have blocked the pre-push.
- **Implementers stopped improvising silently.** They followed the plan's code verbatim and recorded every deviation as a `Ruling: <what> — <why> — <cost if wrong>` line in the commit body. Examples: digit-only id parsing (empty lists arrive as `[""]`), and the status line preferring an alert. That made the implementation review's job concrete.
- **Not every review finding was right.** Some had to be declined, with evidence:
  - The "nothing selected" message on action pages: cascaded marks make "never selected" and "all gone" indistinguishable.
  - `aria-sort` on unsortable columns: the spec's wording was patched instead (v4.0.1).

## What to do next time

- For specs with an intricate protocol, especially a no-script one, keep running spec reviews until one returns only minor issues.
- Always review the plan before execution.
- Brief implementer subagents with a shared context file plus the verbatim phase text, and require `Ruling:` lines for deviations.
- Triage review findings against the spec and code before implementing them.

## Signals to watch for

- A review revision that adds a new mechanism, which is where the next blocker usually hides.
- An implementer reporting DONE with no rulings on a complex phase. Check whether it was really verbatim.
