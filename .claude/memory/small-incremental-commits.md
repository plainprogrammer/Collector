---
name: small-incremental-commits
description: Commit after each discrete step or change, never one big batch
metadata:
  type: feedback
---

Each setup step, tool addition, config change, or fix lands as its own Conventional Commit (types per `docs/git-convention.md`), with the plan section named in the body.

**Why:** The maintainer asked for small incremental commits when starting feature 001 (2026-09-29), for reviewable, bisectable history.

**How to apply:** In plans, end every work unit with its own commit step; during execution, never batch unrelated changes. Keep the suite green at each commit once tests exist.
