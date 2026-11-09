---
name: design-system-owned-in-code
description: Since 2026-11-09 the project owns the design system in code; no re-export or upstreaming, despite CLAUDE.md/README wording until #248 lands
metadata:
  type: project
---

As of 2026-11-09 the project owns the design system in code; the first export was only the starting point. There are no more re-exports or upstreaming: new patterns go in `collector/additions.css` with a doc under `docs/design-system/components/`, and rules are edited in `docs/design-system/README.md` directly.

**Why:** maintainer's ruling while scoping decks (decision 18 of `docs/superpowers/specs/2026-11-09-decks-and-locations-issues-design.md`); #248 retires the old wording.

**How to apply:** until #248 merges, ignore `CLAUDE.md`'s "replaced wholesale by re-exporting" and the README's "Upstream these…" lines, and never plan an upstream step. See [[design-system-before-features]].
