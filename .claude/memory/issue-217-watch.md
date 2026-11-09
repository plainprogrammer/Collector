---
name: issue-217-watch
description: "#217 (backup smoke arm64 flake) stays open after its fix (#223) until Image (linux/arm64) on main has stayed green; the CI trigger was never reproduced"
metadata:
  type: project
---

#217 ("the lot isn't on the collection page" in `bin/backup-smoke`, arm64 only) was fixed by PR #223, merged 2026-11-06 (`59c1309e`), with "Refs", not "Closes". The fix removes a proven mechanism: `curl | grep -q` under `pipefail` fails when GNU grep exits early on a page delivered in pieces. The CI failure itself was never reproduced locally.

**Why:** before the fix it failed on about 2 of 11 `main` runs, so one green arm64 job proves little. The maintainer accepted closing on sustained green `main` runs rather than on the merge.

**How to apply:** check `gh run list --branch main` for `Image (linux/arm64)` results since run 42285985125. About ten consecutive green runs: close #217 with the run ids. Another "isn't on the collection page" failure: the check now prints status, bytes, redirect, cookie and the first 300 bytes, so read that output and reopen the diagnosis on #217. Delete this memory when #217 closes.
