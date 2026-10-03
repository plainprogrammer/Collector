---
name: sdd-review-model-choice
description: Run SDD reviews (spec, plan, implementation) as read-only Fable subagents; brainstorm/spec/plan happen in the main session on whatever model it runs (Opus in 002, Fable in 008); implementation on Opus
metadata:
  type: feedback
---

The user asks for `sdd-superpowers:sdd-review` runs (spec review, plan review, implementation review) to be done by a read-only subagent on the Fable model, with the findings brought back for them to decide on. Brainstorm, spec and plan drafting stay in the main session: on Opus in feature 002 (2026-09-29), and on Fable for feature 008 (2026-10-02), when the user said "write the plan here. I want to switch to Opus for implementation."

**Why:** the user requested the split in feature 002; the Fable reviews of both the spec and the plan caught blocking issues before any code was written. In 008 the same held: the plan reviewer ran the plan's code blocks and found two blocking errors.

**How to apply:** When an SDD review is due, dispatch it via the Agent tool with `model: "fable"`, read-only, and bring the findings back. Keep brainstorm/spec/plan drafting in the main session whatever its model. Expect implementation (`sdd-execute`) to run in a session on Opus; don't start executing a plan in the planning session unless asked. Related: [[plan-reviews-run-the-code]], [[small-incremental-commits]].
