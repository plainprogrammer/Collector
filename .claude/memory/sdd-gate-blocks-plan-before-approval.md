---
name: sdd-gate-blocks-plan-before-approval
description: a PreToolUse hook refuses to write docs/specs/NNN/plan.md while spec.md's Status is not Approved; draft elsewhere or wait for Gate A
metadata:
  type: reference
---

A `PreToolUse` hook (message "SDD Gate: spec.md exists but is not approved. Set Status: Approved in spec.md before planning.") refuses a Write of `plan.md` in a spec folder until that folder's `spec.md` has `Status: Approved`. It fired on spec 060 (2026-11-10) while the plan was being drafted ahead of Gate A.

**Why:** it enforces "no plan without an approved spec".

**How to apply:** don't try to get round it. Either keep a draft in the session scratchpad and Write it after the approval commit (the content is re-emitted, so keep it short enough to repeat), or do the Gate A approval commit first, as the worker flow does (spec Status line to Approved, a changelog row, the index row, one commit), then write the plan. A spec patch after approval (1.0.1, 1.0.2) does not re-block: the status stays Approved. See [[orca-supervised-stages]] and [[work-ahead-of-human-checkpoints]].
