---
name: pr5-open-followups
description: Follow-ups left after PR #5 (feature 004) merged on 2026-09-30 - Turbo stale aria-busy decision, back-button flake watch, uncaptured failure
metadata:
  type: project
---

PR #5 (feature 004) merged into `main` on 2026-09-30 as `5bc4779`, with green CI at `8a188ef`. Follow-ups still open:

- **Back-button flake:** the `no-cache` fix (2026-10-01) closed only the snapshot race. The flake came back on PR #8's CI on 2026-10-02 through a second race, the late frame page visit. PR #9 (`004-filter-without-frames`, merged 2026-10-02) removed the results frame, which also makes the stale-busy question moot (see [[turbo-back-navigation-quirks]]). PR #8's CI passed after rebasing onto it. Remove this item if CI stays green on later runs.
- **Uncaptured failure:** one full-suite local failure was seen once and never identified. There have been 23 green full runs since.
- **Next features:** bulk and table views, then export/import.

**Why:** these threads exist only in the 2026-09-30 session; a fresh session couldn't recover them from the code.

**How to apply:** check recent CI runs on `main` before starting related work, and remove each item here once it's resolved. Related: [[turbo-back-navigation-quirks]].
