---
name: session-wrap-before-merge
description: Run sdd-superpowers:session-wrap before a feature's pull request merges, so its approved memories and lessons ride in that PR, not in a later one
metadata:
  type: feedback
---

Run `sdd-superpowers:session-wrap` for a feature before its pull request merges, not after. Commit the approved memories and lessons on the feature branch, so they land with the feature.

**Why:** on 2026-11-06 the maintainer said "Make sure to run /sdd-superpowers:session-wrap before merging too", after spec 043's memories had to ride in its plan-retirement PR (#195) because the wrap came after #191 merged.

**How to apply:**
- A worker proposes its entries to the coordinator. The coordinator approves them under the maintainer's delegation, or brings them to the maintainer.
- The worker commits them on its PR branch, ideally folded into its last push. A memory-only commit is documentation-only, so the pre-push hook runs `bin/ci checks` only.
- The coordinator doesn't merge the PR until that commit is on it and CI is green.

Plan retirement still comes after the merge.

Related: [[parallel-sdd-orchestration]].
