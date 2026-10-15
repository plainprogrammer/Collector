---
name: session-wrap-before-pr-review
description: Run session-wrap before marking a PR ready for review, so the memory and lesson commits ride in the PR
metadata:
  type: feedback
---

Run `sdd-superpowers:session-wrap` before a PR is marked ready for review, and commit what the maintainer approves to the feature branch.

**Why:** on 2026-10-09 (spec 014, PR #30), with the implementation review SPEC-ALIGNED and the PR still a draft, the maintainer said: "let's do our /session-wrap first so we can commit any findings before opening the PR for review." In the same wrap they asked for the plan's post-merge memory housekeeping to be done now, in the PR.

**How to apply:** in the finishing step, after the implementation review and before marking the PR ready, offer session-wrap. Commit the approved memories and lessons (`chore(memory): …`), push, then mark the PR ready. When a plan schedules memory housekeeping for "after the merge", offer to do it in the wrap instead. Related: [[sdd-review-model-choice]], [[small-incremental-commits]].

**Update (2026-10-15, PR #99):** follow-up memories written in a wrap describe their PR as it is then ("PR #97 draft", "merge #95 first, retarget #96"), and go stale the moment those PRs merge. When the maintainer asked me to address the memory PR after #95–#98 merged, that meant rewriting `spec-022-followups` and `spec-024-followups` as merged, with the finished merge steps dropped, as well as resolving its `MEMORY.md` conflict. That's my reading of "address the memories"; no reason was given. **How to apply:** when merging `main` into a memory branch after feature PRs land, update every follow-up memory that names those PRs (state, index line) and keep only what is still owed.
