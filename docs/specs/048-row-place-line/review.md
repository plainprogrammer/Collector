# Spec 048 review

Read-only `sdd-review` reviews of `spec.md`, two rounds (the most the run allows), 2026-11-06.

## Round 1 (spec 0.1.0): NEEDS REVISION, 0 blocking, 2 major, 10 minor

- **M1** FR-1 fixed `max-width` on a `td` while the spec called it unverified. Probe 2 found Firefox ignores it, so the cap moved onto a `span` inside the cell (0.2.0).
- **M2** The area doc's changes were under-listed (the core-code invariant, a decision entry, the distillation log). Listed (0.2.0).
- **m3** Spec 033 AC-2.2 is extended, not superseded. **m4** Spec 033 FR-5 added to Supersedes. **m5** AC-1.3/1.4 measure once. **m6** AC-2.4 is an explicit-list guard, regex for type and source only. **m7** AC-2.3's Undo. **m8** AC-1.7 names its values. **m9** AC-1.2/1.4 name the glyph. **m10** AC-2.2 uses the browser's computed name. **m11** `docs/design-system/README.md` added. **m12** AC-2.1 names its boundary with spec 037. All fixed (0.2.0).

## Round 2 (spec 0.2.0): NEEDS REVISION (mechanical), 0 blocking, 1 major, 5 minor

All twelve round-1 fixes verified; the span's dependents (one view, request specs selecting `td.c-table__place`, no JS, no Turbo Stream) are covered.

- **M1** AC-1.3/1.4's frame list started at 760px, where a table with a short name is already wider than its container. The wide frames start at 800px; 760px keeps "no page scroll" only (0.3.0).
- **m2** The span is on the named cell only. **m3** Decision 4 states the phone rule's reach (every `.c-collection` table's sub line, the card page's copies line included). **m4** The 20rem measure is named. **m5** AC-2.1's setup is exact. **m6** The guard's file and the seven paths are named. All fixed (0.3.0).

No round 3: the worker checked the 0.3.0 edits against the findings.
