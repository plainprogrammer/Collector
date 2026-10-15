---
branch_pattern: "^[0-9]+-[a-z0-9-]+$"
ticket_prefix: ""
commit_format: "<type>(<scope>): <message>"
allowed_types:
  - feat
  - fix
  - docs
  - chore
  - refactor
  - test
  - perf
  - ci
---

# Git Convention

This file is read by SDD skills to enforce branch naming and commit message standards.
To change these settings, edit this file directly.

## Examples

### Branch names
- `002-scryfall-catalog-search`
- `014-tenant-scoped-exports`

### Commit messages
- `feat(catalog): add Scryfall bulk data sync job`
- `fix(imports): scope CSV import lookups to Current.account`

## Merging

Pull requests are merged with a merge commit, never squashed or rebased (maintainer, 2026-10-15); the repository's settings allow merge commits only. A retired plan is read back from the commit that deleted it (`git show <sha>^:docs/specs/NNN-…/plan.md`, [spec 027](specs/027-architecture-area-docs/spec.md) R6 and D7), so that commit must stay in `main`'s history as it was written.

Rebasing a branch before it merges changes the sha of every commit on it. On a branch that retires a plan, write the retirement pointer after the branch's last rebase, and bring `main` in with a merge from then on.
