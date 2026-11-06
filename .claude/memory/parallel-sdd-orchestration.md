---
name: parallel-sdd-orchestration
description: How the maintainer runs several issues through SDD in parallel (current split since 2026-11-06 run 2). One Sonnet-high Orca worker per issue writes spec, plan and code; Fable reviews specs, Opus reviews plans and Mode B; 2 review rounds, then the maintainer. The coordinator holds gates and slots, merges approved PRs when green, retires plans and removes worktrees.
metadata:
  type: feedback
---

The maintainer starts a parallel pass by asking for 3–5 ready issues (bugs, housekeeping, cross-cutting) to be "run through /sdd-workflow" in parallel sessions the coordinator supervises with them. The split below is from the second run of 2026-11-06 (issues #178/#179, #188, #182, #104, #142; PRs #205–#207, #210, #212). It replaces the first run's (specs 041–044: Opus workers, 3 review rounds).

**Picking the slate:** issues that need no ruling first and touch disjoint files; leave out ones waiting on a maintainer decision, unreproduced flakes, and ones whose edits hit an `ask` rule (workflows, Dockerfile). Hand out spec numbers up front (one per issue that may need one) and ADR numbers first come. Note shared files that will conflict (`docs/specs/README.md`, `.claude/memory/MEMORY.md`).

**Per issue:** one Orca worker, `orca orchestration worker-start --spec-file <brief> --worktree new-top-level --repo id:<repo> --name <NNN-slug> --base-branch main --agent claude --model claude-sonnet-5-5 --effort high`. The brief is the issue section plus a shared "how this run works" section (the coordinator kept it in its scratchpad as `briefs/common.md`).

1. **Routing:** the worker runs `sdd-workflow`; a direct fix with no spec, or an area-doc slice ([[area-doc-slices-under-spec-027]]), is confirmed by the coordinator before coding. Bugs still go failing-test first.
2. **Spec:** the Sonnet worker writes PRD/ADRs/spec; read-only reviews on **Fable**, at most **2 rounds**.
3. **Gate A** (coordinator), with product rulings taken to the maintainer as AskUserQuestion with options and a recommendation.
4. **Plan:** the Sonnet worker writes it; read-only **Opus** reviews, at most **2 rounds**. A blocking fix after round 2 is checked by the coordinator itself rather than a round 3.
5. **Gate B** (coordinator).
6. **Build:** Sonnet implementers, test-first, the worker checks each batch's diff; **Opus** Mode B review.
7. **Finish:** session-wrap committed and pushed (with a slot) → CI green → `gh pr ready` + `gh pr edit --add-assignee @me` → `worker_done`.

**Why:** the maintainer set this split on 2026-11-06 and asked that review cycles stop at two before asking them; they review each PR themselves and then say "merge #N when green".

**How to apply:**
- **The coordinator approves:** routing, Gates A and B, session-wrap entries, CI/push slots ([[one-bin-ci-at-a-time]]).
- **The maintainer decides:** product rulings, anything blocking after two review rounds, permission prompts, and merges. After their approval the coordinator merges when green (`gh pr merge N --merge`), pulls `main`, tells open workers to merge `main`, removes the worktree ([[worktree-cleanup]]) and retires the plan on a `NNN-retire-plan` branch with `distill-feature` (its own PR, merge commit).
- **Record approvals as delegated:** "approved by the coordinator under the maintainer's delegation".
- **A red shard on several PRs at once** is usually main's, not the branches': fix it on its own branch first (as #213/#214) and hold the workers.
- **This split is for parallel runs:** in single-session work, [[sdd-review-model-choice]] still holds.
- **Pre-merge order:** see [[session-wrap-before-merge]].
