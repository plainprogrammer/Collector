---
name: plan-reviews-run-the-code
description: Plan reviews trace the plan's code against the code it edits; default to a read-only Fable review, run the code (in a worktree) only when the maintainer asks
metadata:
  type: feedback
---

When dispatching a plan review (`sdd-review` in plan mode), tell the reviewer to extract every code block from `plan.md` into its scratchpad, run the specs against the implementations as written, lint them, and report which pass. For JS, ask it to check equivalence claims directly (for example, two implementations of the same arithmetic on the same input).

**Why:** on 2026-10-02 the spec 008 plan review did this and found two blocking errors that reading couldn't: a spec whose expected lists contradicted the rule it was written for (the implementation was right, the spec text was wrong), and a load order that made Phase 1's steps impossible to run. It also proved `fingerprint.js` bit-identical to the Ruby fingerprint and the JS search identical to the Ruby one, which no amount of reading would have settled. A plan with runnable code is the only kind this project writes (full code in every step), so this is always possible.

**How to apply:** include in the plan-review brief: "extract the code blocks, run the specs and the lints, walk each spec example against its implementation, and report pass/fail with evidence". Treat a reviewer's "I ran it" as the standard; a review that only reads the code is incomplete for this project. Related: [[sdd-review-model-choice]].

**Update (2026-10-04, spec 009):** the maintainer cancelled a plan review that applied and ran the plan's code in an isolated worktree, and chose a read-only Fable review instead. Read-only, with the brief to trace every code block against the files it edits and walk each spec example by hand, it still found 3 blocking issues: a missing fetch recorder, the locale's date format, and RuboCop limits. It also found 2 spec error scenarios that had no implementation. So offer the read-only review by default. Run the code only when the maintainer asks, and have the read-only reviewer list what only a run could confirm.

**Update (2026-10-08, spec 012):** a read-only Fable reviewer ran the plan's specs against scratch copies of the planned files (extracted from the plan's code blocks, in its scratchpad) without touching the repository. It found four blocking defects that reading alone missed: a first-run redirect the smoke script didn't expect, a matcher that doesn't exist (`not_include`), a case mismatch, and a sentence the plan wrapped across a line break. Running against scratch copies is still read-only, so include it in the default plan-review brief.

**Update (2026-10-08, spec 013):** the planner ran the code too, before presenting the plan: every code block was drafted as scratch files, run with `bin/rspec -r <scratch lib file> <scratch specs>` from the worktree (the real `rails_helper` and WebMock), linted with `bin/rubocop -c .rubocop.yml`, and the command was dry-run against the live package. The read-only Fable plan review then found no blocking issue on its first pass, and Mode B found the commits byte-identical to the plan. Do this for code-heavy plans; render the plan's code blocks from the tested files with a script rather than retyping them.
