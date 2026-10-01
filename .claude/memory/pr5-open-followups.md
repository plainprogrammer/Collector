---
name: pr5-open-followups
description: Follow-ups left after PR #5 (feature 004) merged on 2026-09-30 - Turbo stale aria-busy decision, back-button flake watch, uncaptured failure
metadata:
  type: project
---

PR #5 (feature 004) merged into `main` on 2026-09-30 as `5bc4779`, with green CI at `8a188ef`. Follow-ups still open:

- **Stale busy state:** decide whether to add a local workaround that clears stale `busy`/`aria-busy` after a restore visit, or to report it to Turbo. The user has been asked but hasn't answered.
- **Back-button flake:** root-caused 2026-10-01 to Turbo's frame-advance snapshot race (see [[turbo-back-navigation-quirks]]) and fixed with `turbo-cache-control: no-cache` on the collection and search pages. The earlier hardening in `8a188ef` was a hypothesis and was not the cause.
- **Uncaptured failure:** one full-suite local failure was seen once and never identified. There have been 23 green full runs since.
- **Next features:** bulk and table views, then export/import.

**Why:** these threads exist only in the 2026-09-30 session; a fresh session couldn't recover them from the code.

**How to apply:** check recent CI runs on `main` before starting related work, and remove each item here once it's resolved. Related: [[turbo-back-navigation-quirks]].
