---
name: sdd-review-model-choice
description: Run SDD reviews (spec, plan, implementation) on Fable; planning stays in the main session on Opus
metadata:
  type: feedback
---

The user asks for `sdd-superpowers:sdd-review` runs (spec review, plan review, implementation review) to be done by a subagent on the Fable model, while planning (`sdd-plan`) runs in the main session on Opus.

**Why:** In feature 002 (2026-09-29) the user explicitly requested this split; the Fable reviews of both the spec and the plan caught blocking issues before any code was written.

**How to apply:** When an SDD review is due, dispatch it via the Agent tool with `model: "fable"`, read-only, and bring the findings back for the user to decide on. Keep plan drafting in the main session. Related: [[small-incremental-commits]].
