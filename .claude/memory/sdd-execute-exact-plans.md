---
name: sdd-execute-exact-plans
description: Executing a plan — one subagent per phase even for a small plan (maintainer, 2026-10-11); plan code isn't pre-run (ruled 2026-10-15), so implementers treat blocks as strong drafts, see red then green, and record deviations as rulings; the prototype-branch method is dropped
metadata:
  type: feedback
---

Execute a plan with one implementer subagent per phase, as `sdd-execute` prescribes, even for a small plan. Give each subagent its phase's line range of `plan.md` plus the header lines (Global Constraints), rather than pasting the phase into the prompt.

**Why:** maintainer's feedback (2026-10-11, spec 018, relayed by the Orca coordinator at the session wrap). In spec 018 the five phases were executed in the main session instead, by checking out prototype commits phase by phase. The code came out byte-identical to the plan, but that wasn't an approved method. A brief that allows reusing prepared code doesn't waive the subagent per phase.

**Plans aren't pre-run (2026-10-15):** the maintainer dropped running a plan's code before execution, for the planner and for the plan reviewer: "This sounds like it duplicates work under the guise of verification, and ahead of time." See [[plan-reviews-run-the-code]]. A plan's blocks are therefore not byte-exact.

**How to apply:** brief each implementer that the phase's blocks are a strong draft and may be wrong. It runs the phase's examples and sees them fail for the stated reason before the implementation, then sees them pass. A fix must keep the spec's behaviour and is recorded as a ruling in the commit body. Run the whole suite at the end of the last phase. Related: [[subagent-commit-trailers]], [[work-ahead-of-human-checkpoints]].

**History (dropped 2026-10-15):** specs 013–019 built a prototype first (a never-pushed `NNN-plan-phases` branch, uncommitted trees per phase, or scratch files), rendered `plan.md` from it by script, had implementers apply the blocks by script and `git apply`, and checked the result was byte-identical to the prototype. Spec 015's ten phases and spec 019's five landed with no code deviation this way. Don't build a prototype branch or render plans from tested files anymore.
