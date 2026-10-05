---
name: exitplanmode-for-sdd-plans
description: For long SDD plans, summarise in chat and take the maintainer's go-ahead there; don't present the plan through the ExitPlanMode approval dialog
metadata:
  type: feedback
---

On 2026-10-03/04 (spec 009) the maintainer rejected the ExitPlanMode approval dialog twice for a plan of about 4,000 lines. Each time they steered in chat instead: "review the plan with fable", then "proceed to sdd-execute".

**Why:** a plan that long can't usefully be read in the approval dialog. The maintainer reviews plans through Fable reviews and short chat summaries.

**How to apply:** for SDD plans, draft the plan file, summarise it in chat (phases, decisions, what needs the maintainer), and offer a review. Treat the maintainer's chat instruction as the go-ahead, then write `plan.md` to `docs/specs/…`. Don't call ExitPlanMode again after it has been rejected. Related: [[sdd-review-model-choice]], [[plan-reviews-run-the-code]].
