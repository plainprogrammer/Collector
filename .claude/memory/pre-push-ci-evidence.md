---
name: pre-push-ci-evidence
description: A passing pre-push hook shows no bin/ci output; cite the pushed SHA and get the example count with bin/rspec --dry-run
metadata:
  type: reference
---

The pre-push hook (`.claude/hooks/pre_push_ci.rb`) prints `bin/ci`'s output only when it fails and blocks the push. A push that succeeds is the evidence that `bin/ci` passed on that head, but leaves no example count in the session.

**Why:** spec 040's final report needed a test count after a hooked push, and none had been printed (2026-11-06).

**How to apply:** when a report needs local `bin/ci` results after a hooked push, cite the pushed SHA as "`bin/ci` passed as the pre-push hook at `<sha>`" and take the count from `bin/rspec --dry-run` (it counts without running). Don't run the dry run while another suite uses the worktree's test database ([[worktree-shared-test-db]]).
