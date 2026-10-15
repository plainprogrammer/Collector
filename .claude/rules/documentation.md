# Documentation: Area Docs, Specs and Plans

- ✓ The current rules of a subsystem are in its area doc under `docs/architecture/` (list and shape in its README). Read the area docs of the areas you touch before changing them.
- ✓ A change to the behaviour, a constant or a rule of an area that has an area doc updates that doc in the same pull request, with the source of each new statement (spec criterion, ADR or issue) inline. An issue fix adds its issue to the doc's Sources.
- ✓ A change that supersedes part of a shipped spec records the supersession in its own spec ("supersedes spec NNN FR-x: …") and in `docs/specs/README.md`, both directions, and updates the area doc where one covers that part.
- ✓ At every session end, run `sdd-superpowers:session-wrap`, then the `distill-feature` skill (`.claude/CLAUDE.md`): for a finished feature, before the merge, it writes the area docs and marks the index; after the merge it retires the plan.
- ✓ Record a feature's implementation review (`sdd-review` Mode B) in its `verification.md` under a `## Implementation review` heading, with the verdict (for example "SPEC-ALIGNED") on its first line. `distill-feature` reads that heading to know the feature is finished.
- ✓ Keep `docs/specs/README.md` current: a new spec adds its row when it is written; the distillation step changes rows as specs freeze and plans retire.
- ✗ Don't edit a shipped spec, frozen or not, except for its frozen line, its retirement pointer and its links to its own retired plan, each in a commit of its own that names spec 027 D4. Typos stay; supersessions go in the new spec and the index.
- ✗ Don't renumber or rename a spec, a criterion or an ADR; code and tests cite them.
- ✗ Don't restate an area's rules in CLAUDE.md; point to the area doc.
