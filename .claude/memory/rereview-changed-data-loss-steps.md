---
name: rereview-changed-data-loss-steps
description: when a plan step that can lose a collector's data changes after its review, run the read-only review again on the changed step before its batch (spec 090's phase 6)
metadata:
  type: feedback
---

A plan review traced migration (c) as first written; the plan then changed it (guards, a fault test, the corrected `down`). The coordinator asked for a second read-only Fable review limited to the changed step before its batch ran, and it found a boot loop on dangling rows that the first review of the unchanged step could not have.

**Why:** a trace is of the code it read; a fix to that code is new code. On a step that deletes data on a failure, the cost of one more read-only review is small.

**How to apply:** after any change to a data-loss step (a table copy, a delete, a backfill) that follows its review, dispatch the review again, limited to the step and what changed, and send its verdict to the coordinator before the implementer batch starts. See [[plan-reviews-run-the-code]] for how plan reviews trace.
