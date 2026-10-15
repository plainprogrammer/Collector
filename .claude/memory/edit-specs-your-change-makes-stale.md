---
name: edit-specs-your-change-makes-stale
description: When a change makes another (already shipped) spec's acceptance criterion incomplete, edit that spec in the same PR with a patch version bump and changelog line; don't just flag it (maintainer, 2026-10-14)
metadata:
  type: feedback
---

Spec 024's plan said spec 015's AC-2.16 ("the most recent run that wasn't skipped as already running") would become incomplete. That spec is outside the branch's documents, so the plan said the PR would only note it. When approving the plan on 2026-10-14, the maintainer said: "Also edit spec 015's AC-2.16 wording in this PR so it covers the new 'waiting for another job's retry' skip (bump its version per house style)." Spec 015 went to v1.3.1 with a changelog line, in the same docs commit as spec 002's update.

**Why:** an approved spec that no longer describes the code misleads the next reader, and a note in a PR body gets lost once the PR merges.

**How to apply:** while planning, grep `docs/specs/` for the behaviour, scope or message you change (here, `already running`). For each acceptance criterion or requirement the change makes incomplete or wrong, plan an edit to that spec in the same PR: a patch version bump for a wording fix (minor if a requirement changes), Last Updated, a changelog line naming the issue, and a line in your own `verification.md`. Ask only if the edit changes what that spec promised, not just how it is worded. Related: [[sdd-review-model-choice]].
