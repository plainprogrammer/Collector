---
name: parallel-sdd-orchestration
description: How the maintainer runs several issues through SDD in parallel. One Opus Orca worker per issue; Fable reviews the spec, Sonnet plans with Opus reviews, Sonnet implements. The coordinator approves the gates under delegation, and rulings go to the maintainer.
metadata:
  type: feedback
---

On 2026-11-06 (specs 041–044, Orca run `run_97a753dc75cb`) the maintainer asked for four issues worked in parallel with this split. Each issue gets one Orca worker, on Opus, in its own worktree.

1. **Spec:** the worker writes the PRD, ADRs and spec itself, on Opus.
2. **Spec review:** read-only Fable reviewers, up to 3 rounds. Blocking findings left after round 3 go to the coordinator.
3. **Gate A:** the coordinator approves the spec.
4. **Plan:** a Sonnet subagent writes `plan.md`. Read-only Opus reviewers check it, up to 3 rounds, and the same Sonnet planner revises between rounds.
5. **Gate B:** the coordinator approves the plan.
6. **Build:** Sonnet implementers, test-first. The Opus worker checks every task's diff.
7. **Finish:** an Opus implementation review (Mode B), screenshots, distill-feature and session-wrap, then a draft PR that stops when its CI is green.

**Why:** the maintainer wanted the process "as hands-off as possible", with the coordinator keeping the sessions on track. They delegated spec, plan and memory approvals to the coordinator.

**How to apply:**
- **The coordinator approves:** the spec and plan gates, ADR numbers, session-wrap entries, and CI and push slots. See [[one-bin-ci-at-a-time]].
- **The maintainer decides:** product and scope rulings, sent to them with options and a recommendation; permission prompts, since the coordinator never answers one; and merges, unless the maintainer says "merge #N when green".
- **Record approvals as delegated:** a spec's status says "approved by the coordinator under the maintainer's delegation", not "by the maintainer".
- **This split is for parallel runs:** in single-session work, [[sdd-review-model-choice]] still holds (Opus reviews by default).
- **Pre-merge order:** see [[session-wrap-before-merge]].
