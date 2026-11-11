---
name: name-the-guards-that-go-red-between-plan-commits
description: When a plan splits a feature into commits, name every guard that goes red between them and mark it pending until the task that turns it green
metadata:
  type: feedback
---

A plan that lands a feature in per-task commits must say, for each task, which existing guards go red at its commit and which later task turns them green, and that task's implementer marks the guard `pending: "<reason, the task that turns it on>"` in the same commit (RSpec fails a pending example that passes, so the later task must remove the marker and the example proves it went green).

**Why:** spec 062's plan reviews (2026-11-10) found 13 majors of this kind in two rounds: the export-format document spec's hard-coded left-out list and its "field appears in a valid example" rule went red when the migration landed; examples pinned at format version 3 went red when `VERSIONS` became `[1,2,3,4]` while `CollectionExport::FORMAT_VERSION` stayed 3 (so pinning those *pending* would have failed, since they still passed); the upgrade seeds spec failed as soon as the `decks` table existed; a task needed code a later task built. Fixed by reordering tasks and naming each intermediate state in the plan.

**How to apply:** when writing or reviewing a plan, for each task grep the specs for what it breaks: the guard specs named in CLAUDE.md (coverage tables, `VERSIONS`, `name_parity`, core-names-no-collectible, backup guards, upgrade seeds and `script/upgrade`), anything pinning a constant the task changes, and the old sentence of a message the task rewrites. Decide per example: change it in the task that breaks it (a pin that must move), or mark it pending (a guard that can only pass once a later task lands), and say which in the plan. Related: [[batch-plan-tasks-per-implementer]], [[plan-reviews-run-the-code]].
