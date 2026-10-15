---
name: plan-reviews-run-the-code
description: Plan reviews are read-only (on Opus since 2026-10-12, see sdd-review-model-choice): trace the plan's code against the files it edits and walk each spec example by hand; nobody runs the plan's code before execution (ruled 2026-10-15)
metadata:
  type: feedback
---

A plan review (`sdd-review` in plan mode) is read-only. The reviewer traces every code block in `plan.md` against the files it edits and walks each spec example against its implementation by hand. It doesn't extract, run or lint the plan's code, not even against scratch copies in its scratchpad. It lists what only a run could confirm, and execution confirms it, tests first.

**Why:** on 2026-10-15 the maintainer dropped running a plan's code ahead of execution, first for the planner and then for reviewers: "This sounds like it duplicates work under the guise of verification, and ahead of time." and "Reviews should be read-only." Reading alone has found blocking defects before: the spec 009 read-only review found 3 (a missing fetch recorder, the locale's date format, RuboCop limits) and 2 spec error scenarios with no implementation.

**History:** from 2026-10-02 (spec 008) reviewers ran the plan's specs, at first in a worktree and from spec 012 against scratch copies; from spec 013 the planner also ran every code block before presenting the plan. Both are dropped. Runs found defects reading missed (a contradictory spec, a load order, a matcher that doesn't exist), so brief the reviewer to look for that kind: matchers and methods that must exist, load order, expected values against the rule they test.

**How to apply:** the plan-review brief says "read-only: trace each code block against the files it edits, walk each spec example by hand, check every method and matcher it calls exists, and list what only a run could confirm; run nothing". Don't prototype a plan's code before writing the plan. Related: [[sdd-review-model-choice]].
