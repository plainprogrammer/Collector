---
name: sdd-review-model-choice
description: Every PRD, spec and plan gets a read-only review by default before the next step (don't offer to skip it), on Opus since 2026-10-12 (Fable only when the maintainer names it); same for implementation reviews; brainstorm/spec/plan happen in the main session on whatever model it runs (Opus in 002, Fable in 008); implementation on Opus
metadata:
  type: feedback
---

The user asks for `sdd-superpowers:sdd-review` runs (spec review, plan review, implementation review) to be done by a read-only subagent on the Fable model, with the findings brought back for them to decide on. Brainstorm, spec and plan drafting stay in the main session: on Opus in feature 002 (2026-09-29), and on Fable for feature 008 (2026-10-02), when the user said "write the plan here. I want to switch to Opus for implementation."

On 2026-10-09 (feature 014), after I offered to skip the spec review and go straight to planning, the user said: "Check the spec with /sdd-review using a read-only Fable subagent. Remember that this should be the default way PRDs, specs, and plans are handled before starting planning."

**Why:** the user requested the split in feature 002; the Fable reviews of both the spec and the plan caught blocking issues before any code was written. In 008 the same held: the plan reviewer ran the plan's code blocks and found two blocking errors.

**Update (2026-10-12, spec 020):** the maintainer changed the review model: "I now want to conduct plan and spec reviews with Opus for most work. I will specify Fable from time to time. But the default should be Opus going forward for review operations." No reason was given. The earlier Fable instructions above and in [[plan-reviews-run-the-code]] are history; the read-only review itself stays the default.

**How to apply:** Review is the default, not an option: after writing a PRD (with its ADRs), a spec, or a plan, dispatch the review before moving on, and only then ask for approval. Don't recommend skipping it. When an SDD review is due (spec, plan or implementation), dispatch it via the Agent tool with `model: "opus"`, read-only, and bring the findings back. Use `model: "fable"` only when the maintainer asks for Fable for that review. Keep brainstorm/spec/plan drafting in the main session whatever its model. Expect implementation (`sdd-execute`) to run in a session on Opus; don't start executing a plan in the planning session unless asked. Related: [[plan-reviews-run-the-code]], [[small-incremental-commits]].
