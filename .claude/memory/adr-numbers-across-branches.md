---
name: adr-numbers-across-branches
description: Check origin/main's docs/adr before numbering an ADR; an unmerged ADR takes the next free number on rebase
metadata:
  type: feedback
---

Before numbering a new ADR, check `git fetch && git ls-tree --name-only origin/main docs/adr/`, not only the branch's own `docs/adr/`. When a rebase shows that `main` took the number, the unmerged ADR takes the next free number. Record the old number in its Status line, and update every reference in its spec, plan and memory.

**Why:** spec 012 added ADRs 0008–0010 on `main` while spec 011's ADR 0008 (the ImageMagick decoder) was still on its branch. The maintainer had it renumbered 0011 on rebase (2026-10-08). `docs/adr/README.md` says numbers are never renumbered once written, which holds for merged ADRs only.

**Again (2026-10-08, merging main into spec 011 before its PR):** main had meanwhile taken 0011 (spec 013, GHCR cleanup), so the decoder ADR became 0012. Re-check `origin/main`'s `docs/adr` right before the PR, not just at rebase time.

**How to apply:** when writing ADRs in brainstorm or plan, and after every rebase of a branch that adds one. Related: [[branch-naming-convention]].
