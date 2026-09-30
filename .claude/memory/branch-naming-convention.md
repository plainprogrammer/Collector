---
name: branch-naming-convention
description: Feature branches always follow docs/git-convention.md (NNN-slug), even in worktrees created with another branch name
metadata:
  type: feedback
---

Branches for SDD features are named per `docs/git-convention.md` (`^[0-9]+-[a-z0-9-]+$`, e.g. `004-design-system-collection`; no type prefix, since the SDD session-start hook finds the active spec from a leading `NNN`), even when the Orca/Claude worktree was created on a differently named branch (e.g. `plainprogrammer/design-system-implementation`).

**Why:** On 2026-09-29, when the worktree branch didn't match the convention, the user said to "use a branch name following the naming convention" for 004.

**How to apply:** At the start of `sdd-execute`, create the convention-named branch from the worktree's current branch (`git switch -c NNN-slug`) rather than committing to the worktree's original branch. Write the chosen name into the spec's **Branch:** field. Specs 001–004 used the old `feat/NNN-slug` convention (changed 2026-09-30); their **Branch:** fields record history and stay as they are. Related: [[small-incremental-commits]].
