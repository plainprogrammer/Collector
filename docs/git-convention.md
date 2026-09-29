---
branch_pattern: "^(feat|fix|docs|chore|refactor|test|perf|ci)/[0-9]+-[a-z0-9-]+$"
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
- `feat/002-scryfall-bulk-sync`
- `fix/014-tenant-scoped-exports`

### Commit messages
- `feat(catalog): add Scryfall bulk data sync job`
- `fix(imports): scope CSV import lookups to Current.account`
