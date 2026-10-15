---
name: worktree-shared-test-db
description: Everything run in one worktree shares its SQLite test database; when bin/ci runs in the background, brief parallel subagents not to run RSpec
metadata:
  type: reference
---

Each worktree has its own databases, but within a worktree `bin/ci`, `bin/rspec`, and every subagent working in it share one SQLite test database (`storage/test.sqlite3`; the path is off-limits for reads). Two suite runs at once would truncate and seed each other's tables.

In spec 023 (2026-10-14) a background `bin/ci` (3.5 minutes) ran alongside a subagent writing `verification.md` and a read-only sdd-review subagent. Both briefs said "DO NOT run RSpec or bin/ci (a CI run is using the test database); reading code and git is fine". Both finished without touching the suite, and CI stayed green.

**How to apply:**
- Start `bin/ci` in the background only when the subagents in flight are documents-only or read-only, and say "don't run RSpec" in their briefs.
- A subagent that must run specs (TDD units, mutation proofs) runs alone. Run CI after it commits.
- A document commit that lands after the CI run doesn't need a re-run. Record the SHA CI ran at.

Related: [[background-servers-via-task]], [[orca-supervised-stages]].
