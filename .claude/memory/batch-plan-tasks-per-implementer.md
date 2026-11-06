---
name: batch-plan-tasks-per-implementer
description: In sdd-execute, give one implementer 2–4 consecutive plan tasks that read their sections from plan.md by line range
metadata:
  type: reference
---

A technique that worked (spec 041, 2026-11-06, Sonnet implementers under an Opus supervisor): instead of one dispatch per plan task, give one implementer 2–4 consecutive tasks of one phase. Each task is still its own TDD cycle and its own commit. The implementer reads its task sections from `plan.md` by line range (plus the plan's head: goal, design decisions, files), not pasted text. The supervisor reads each batch's diff against the plan and the spec before dispatching the next. Spec 041 ran 20 tasks in 7 dispatches (models 1–4, 5–7; UI 8–9, 10–11; guards and timing 12–15; documents 16–19; review fixes) with no rework.

**Why:** a 1,600-line plan is too big to inject per task, and the line-range text is the same text. Batching consecutive tasks keeps the context an implementer needs (the model it just wrote) without inheriting the supervisor's session.

**How to apply:** batch by phase, not across phases; tell each implementer which tasks' examples pass on arrival must be called characterisations in the commit; keep the controller's own checks between batches. Related: [[work-ahead-of-human-checkpoints]], [[plan-reviews-run-the-code]].
