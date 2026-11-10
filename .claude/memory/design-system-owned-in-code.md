---
name: design-system-owned-in-code
description: The project owns the design system in code (spec 057, #248): no re-export or upstreaming; new patterns go in additions.css with a component doc, rules change in the README
metadata:
  type: project
---

The project owns the design system in code; the first export was only the starting point. There are no re-exports or upstreaming: a new pattern goes in `collector/additions.css` with a doc under `docs/design-system/components/` and a line in the README's App additions list, and a rule is edited in `docs/design-system/README.md`. Spec 057 (#248) wrote this into `CLAUDE.md`, the README, the skill and every comment that said otherwise.

**Why:** the maintainer's ruling of 2026-11-09 while scoping decks (decision 18 of `docs/superpowers/specs/2026-11-09-decks-and-locations-issues-design.md`); spec 057 decision 12 retired the old wording.

**How to apply:** never plan an upstream step or wait for a re-export. A rule that `components.css` (the export's file) states and `additions.css` overrides: `components.css` still carries the original, `additions.css` is what applies. See [[design-system-before-features]] and [[design-system-guard-and-rubocop-traps]].
