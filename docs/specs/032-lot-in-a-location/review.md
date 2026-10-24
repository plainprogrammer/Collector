# Spec 032 review (sdd-review Mode A)

**Date:** 2026-10-23 · **Spec version reviewed:** 0.1.0 · **Reviewer:** an independent read-only Opus subagent (the project default), with the findings checked against the code and fixed by the drafting session in 0.2.0

## Verdict: NEEDS REVISION at 0.1.0; fixed in 0.2.0 (round 1)

The reviewer found no critical issue. Decisions 1–7 were found coherent, and the import and removal design buildable inside spec 028's one transaction: an applicable file has no problem rows, so every held lot in a location the plan removes is removed with it, and a lot placed after the preview changes the fingerprint (409).

## Found and fixed

- **Important.** Open Questions said nothing blocked the plan and, in the same sentence, that the plan waited for the maintainer's word on P1–P6; the Status line cited a `review.md` that did not exist. Fixed: P1–P6 are confirmed with the approval of the spec, none changes decisions 1–7; this file exists.
- **Important (feasibility).** A row with an unlisted location (`unknown_location`) would lose its readable identity in today's reader, so a held lot it names would be reported removed, against AC-10.3. Fixed: the identity stays readable, as a `duplicate_lot` row's does, and is matched by comparison key.
- **Important (a crash).** A bulk Undo after the location was removed could restore two rows of one identity and raise a unique-index error, and the cap check missed it. Fixed in P5 and new AC-7.8: restored rows merge with each other and the unplaced lot, the cap applies to the sum, all or nothing; a removal made before the migration restores unplaced.
- **Important (round trip).** A lot's location matched by key but compared exactly in "The same collection" could not re-export equal. Fixed in AC-9.4: such an example re-exports with the stored spelling and is outside the round-trip check, like `locations-nfd.json`.
- **Important.** The edit form is also reached from the collection table and the scanner. Fixed in decision 4 and new AC-2.8; "Move copies" stays on the card page only (AC-3.1).
- **Important.** Deleting an account with placed lots depends on lots being deleted before locations. New AC-6.6 and an Error Scenarios row.
- **Important.** Adding a foreign key can rebuild the `lots` table. AC-7.1 now names the selection marks, the bulk removal, the number-entry lines and the scanner entries that point at lots.
- **Important.** AC-11.12 did not test the worst-case file against the 500 MB bar and the 32 MB limit. It now does, with a ruling owed if either fails; the Cost text no longer says a file holds the comparison key.
- **Minor.** Given/When/Then gaps (AC-3.12, 8.6, 10.5, 10.10, 11.4, 11.9) closed; AC-3.1 names the destination default; AC-3.4 split; AC-10.9 names the spelling; AC-11.7 says a version 1 file counts no locations; AC-7.6 gains the partial-move case; a lot-add racing a location removal must never answer 500 (AC-6.7); Story 6 maps to FR-1; AC-9.1 lists the format document's sentences that change.

## Checked and left

- All merge and restore paths are covered by Story 7: `Lot.add!`, `revise!`, `Lot::ConditionChange`, `BulkRemoval#undo!`, number-entry and scanner Undo, Move.
- No criterion contradicts rulings 1–6; supersessions are recorded in both directions; every cited criterion of specs 004, 006, 026, 028 and 029 exists.
- For the plan, not the spec: SQLite treats NULLs in a unique index as distinct, so the place must go into the lot's key for placed lots (unplaced keys unchanged), including the raw SQL in `Lot::ConditionChange#update_alone!` and the apply's `upsert_all` key.

## Owed

- The maintainer's confirmation of P1–P6 and approval of the spec.
- The ADR of decision 1, written with the plan.

---

# Round 2 (sdd-review Mode A, spec 0.2.0)

**Date:** 2026-10-23 · **Reviewer:** an independent read-only Opus subagent (two passes; the first was cut off by a usage limit and re-checked by the second) · **Fixed in:** 1.0.0

## Verdict: NEEDS REVISION (text only, light); fixed in 1.0.0 (READY TO PLAN once the maintainer approves)

0 critical, 2 major, 11 minor; no finding needed a maintainer ruling and none changes D1–D6 or P1–P6. The eight round-1 findings were all confirmed fixed. The maintainer confirmed P1–P6 as proposed on 2026-10-23.

| Finding | Fix in 1.0.0 |
|---|---|
| **M1** header: version, "decisions 1–6", P1–P6 "proposed" | Version 1.0.0; Status maps the maintainer's D1–D6 to decisions 1–7 and records P1–P6 confirmed; the Decisions intro, the P heading and Open Questions say confirmed; changelog line |
| **M2** spec 029 AC-9.15 and spec 028 AC-6.4 break at version 3 | New AC-11.14 says how they read from now on (a version 1 or 2 example re-exports as version 3: the version, `locations` for version 1, every lot's `"location": null`); Supersedes rows for 028 and 029 and the index cells, both directions; the two NFD/case examples stay outside the check; AC-11.2 cites it |
| **m1** criteria out of order | Story 6 (6.5 before 6.6, 6.7) and Story 7 (7.6, 7.7 before 7.8) in numeric order; no renumbering |
| **m2** AC-6.6 depends on declaration order | Said in AC-6.6 and in Notes for the plan |
| **m3** every `lot_key` builder carries the place, the place is the location's id | FR-1 Must, and Notes for the plan naming the four builders and `BulkRemoval.remove!` |
| **m4** supersession cells | Spec 029 cell shortened; 029 decision 10 and AC-9.15 added; spec 025 decision 9 added to the index; ADR 0023's read-versions bullet added to the ADR row |
| **m5** the apply's write order and location-id resolution | FR-4 states today's order, the new order inside the transaction and the one read of at most 500 locations, counted in AC-11.12's bounded statements |
| **m6** "Your copies" lists every printing of the card | Terms; AC-4.1 states the row order (as today, then unplaced first, then location order); AC-4.2 adds "no other printing of the card owned" |
| **m7** AC-9.1 and AC-9.3 miss format-document sentences | AC-9.1 lists every sentence that names two versions or five values; AC-9.3 adds `lots.lot_key`'s "Why" |
| **m8** decision 7 beside "a missing field isn't 'none'" | AC-9.1: a version 1 or 2 lot says nothing about its place; Collector reads it as unplaced because applying is a restore; a missing `location` in version 3 is malformed |
| **m9** AC-6.7's race covers adding only | AC-6.7 and the Error Scenarios row cover add, edit and move: 404 (or 422 with the form), or 409, never 500 |
| **m10** cost undercounts | Cost per account: column, index and the place in the key, about 30 bytes a placed lot |
| **m11** which lot survives a whole move that merges | P6: the destination's lot survives with its added time and id; the moved lot is removed |

**Not taken:** none. M2 is a supersession recorded in this spec and the index; no shipped spec is edited.

## Owed

- The maintainer's approval of the spec (P1–P6 are confirmed).
- The ADR of decision 1, written with the plan.
