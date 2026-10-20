---
scope: architecture
loaded-by: sdd-brainstorm, sdd-specify, sdd-plan, sdd-review
---

# Area Docs

The current rules of each subsystem are in `docs/architecture/<area>.md`; the list of areas and the doc shape are in `docs/architecture/README.md`, and every spec's status, areas and supersessions are in `docs/specs/README.md`.

- **Before writing** a PRD, spec or plan, read the area docs of the areas the feature touches. Where an area has no doc yet, read its specs through the index, newest first, and CLAUDE.md.
- **In a spec or plan,** name the area docs the feature will change, and what it supersedes in earlier specs ("supersedes spec NNN FR-x"), so the index can record both directions. Don't plan edits to a shipped spec (`.claude/rules/documentation.md`).
- **In a review,** check that the change updates every area doc it makes stale, and that a finished feature was distilled (`distill-feature`) before its pull request is marked ready.
