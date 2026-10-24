# Spec 032 review (sdd-review Mode A)

**Date:** 2026-10-23 · **Spec version reviewed:** 0.1.0 · **Reviewer:** an independent read-only Opus subagent (the project default), with the findings checked against the code and fixed by the drafting session in 0.2.0

## Verdict: NEEDS REVISION at 0.1.0; fixed in 0.2.0 (READY TO PLAN once the maintainer confirms details P1–P6 and approves)

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
