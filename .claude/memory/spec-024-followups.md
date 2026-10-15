---
name: spec-024-followups
description: Spec 024 (issue #78, skip while another job's retry waits) — draft PR #96 stacked on #95; retarget to main after #95 merges; #77 must discard or run the waiting job first
metadata:
  type: project
---

State on 2026-10-14. Delete this memory when PR #96 merges and #77 is specified.

- **PR:** [#96](https://github.com/plainprogrammer/Collector/pull/96), a draft, base `084-plain-failure-messages` (PR #95, issue #84), not `main`. The maintainer had the branch rebased onto #84's branch before the push, because both change `Catalog::RefreshOperation`, `MTG::Art::Operation` and CLAUDE.md's admin paragraph. **Merge order:** #95 first, then retarget #96 to `main` (`gh pr edit 96 --base main`) and check that it is mergeable before it is marked ready. See [[pr-exists-and-conflicts-check]].
- **For #77 ("start fresh while a retry waits"):** a refresh or art build that starts while any other job of its operation waits in the queue to run again is now skipped as `waiting for another job's retry`, whoever started it (the maintainer's ruling: manual behaves like scheduled; an override belongs to #77). So #77's "start fresh" is skipped too unless it first discards the waiting job or runs it now. Its spec has to say which.
- **Accepted limits, in spec 024:** any job held for a later time counts, not only a rate-limit retry (the queue row can't tell them apart). With two waiting retries, the one due first is skipped. The art build has no concurrency lock, so a build that starts in the milliseconds between a failing build closing its record and its retry being queued still goes ahead, as it did before.

**Why:** the stacked base and the #77 constraint live only in the PR body and the spec's "Interactions" section, which a session starting #77 or merging PRs won't read by default.

**How to apply:** check `gh pr view 96 --json baseRefName,state` before relying on this. When specifying #77, start from the second bullet.
