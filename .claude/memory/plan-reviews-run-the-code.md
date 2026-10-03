---
name: plan-reviews-run-the-code
description: Brief plan reviewers to extract and run the plan's code blocks (specs against implementations), not only read them
metadata:
  type: feedback
---

When dispatching a plan review (`sdd-review` in plan mode), tell the reviewer to extract every code block from `plan.md` into its scratchpad, run the specs against the implementations as written, lint them, and report which pass. For JS, ask it to check equivalence claims directly (for example, two implementations of the same arithmetic on the same input).

**Why:** on 2026-10-02 the spec 008 plan review did this and found two blocking errors that reading couldn't: a spec whose expected lists contradicted the rule it was written for (the implementation was right, the spec text was wrong), and a load order that made Phase 1's steps impossible to run. It also proved `fingerprint.js` bit-identical to the Ruby fingerprint and the JS search identical to the Ruby one, which no amount of reading would have settled. A plan with runnable code is the only kind this project writes (full code in every step), so this is always possible.

**How to apply:** include in the plan-review brief: "extract the code blocks, run the specs and the lints, walk each spec example against its implementation, and report pass/fail with evidence". Treat a reviewer's "I ran it" as the standard; a review that only reads the code is incomplete for this project. Related: [[sdd-review-model-choice]].
