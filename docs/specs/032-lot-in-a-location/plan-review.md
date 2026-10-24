# Plan review: spec 032 (put a lot in a location, #45)

**Reviewed:** `plan.md`, `data-model.md`, `contracts/`, `research.md` and ADR 0025 at `a9c3644`, against spec v1.0.1 and the code, by an independent read-only Opus review on 2026-10-24: **NEEDS REVISION**, 0 critical, 6 major, 11 minor, all text fixes (the review's text is kept in the session scratchpad, not in the repository).
**Revised:** 2026-10-24, on spec 1.0.2. Every finding was traced against the file it names (the migration findings against `activerecord-8.1.4`, `bundle show activerecord`) and taken; none was left out. Nothing was run.
**origin/main:** unchanged since the plan (`ae593b2`), so there was nothing to merge.

## Maintainer rulings (2026-10-24)

| # | Ruling | Where it is recorded |
|---|---|---|
| O1 | Accepted. The preview shows "in <location>" on removed lots and problem rows only (it has no added or changed lists); AC-10.7 and AC-10.9 are adjusted to say so | Spec PATCH 1.0.2, commit `9d3f072` (spec changelog, AC-10.7, AC-10.9, the index row's version); plan Open Items; `verification.md` in Phase 8 step 8 |
| O2 | Accepted. When the restored rows alone pass 9,999 on Undo, the refusal names an existing lot first (by the table's sort), else the first overflowing restored row | Plan Open Items; Phase 2 (a test for both cases and the `check_cap!` comment). No spec line: it refines AC-7.8 inside the plan, as research R4 says |
| O3 | Accepted. An edit without the location parameter keeps the lot's place (PATCH semantics) | Plan Open Items; Phase 4 (`update` and its examples); contracts/api.md. No spec line |

## Findings and fixes

| Finding | Verdict | Fix | Where |
|---|---|---|---|
| **M1** Phase 6 isn't green: `round_trip_spec` applies every valid example | Taken. Confirmed: it is the only spec that applies the examples (`git grep 'examples("valid")' -- spec`) | Phase 6 limits the loop to `format_version <= 2` with a comment; Phase 7 removes the limit when it rewrites the spec to AC-11.14. The sentence "no spec applies a placed version 3 file until Phase 7" is replaced by the reason | plan.md Phase 6 intro, Phase 6 files, Phase 7 tests |
| **M2** the suite's "same collection" treats "box"/"Box" on a lot as one | Taken | `compared` keys lots by `compared_identity` = the first five identity values plus the location string as written (version 3 only); `identity` keeps the comparison key for duplicates and matching. A unit example and the `v3-different-lot-location-case` example prove it | plan.md 6.1 items 1 and 3; contracts/export-v3.md |
| **M3** `unlisted_places` lacks the `/locations` guard | Taken | `unlisted_places` returns `[]` when `failed` holds `/locations`; an example with 501 locations and one placed lot expects `maxItems` and no `unknown_location` | plan.md 6.1 item 2 and the rules snippet; contracts/export-v3.md |
| **M4** the migration spec calls `Migration#migrate`, which opens no transaction | Taken, both fixes. Traced: `migration.rb:969` opens none, `ddl_transaction` at `:1594-1604`, class accessor `disable_ddl_transaction` at `:685`, `MigrationContext#run` at `:1283` | A first example asserts `described_class.disable_ddl_transaction` is true; down and up run through `MigrationContext#run` (as `db:rollback` does); the "refuses" example keeps `Migration#migrate` (the Migrator re-wraps errors); the stop condition now can trigger, and the executor deletes the line once to watch the example go red | plan.md Phase 0; data-model.md; research R12 |
| **M5** the export's two reads can write a file Collector refuses | Taken, by the review's second option, not the transaction. Rails opens SQLite transactions IMMEDIATE (`sqlite3_adapter.rb:162`), so a read transaction would hold the write lock for a long export | Lots are read with `location_id`, then the locations, and each place is named from the locations read by id (a rename can't disagree with itself); an id missing from the second read (a location removed meanwhile) repeats the reads, at most 3 times, then `CollectionExport::Unsettled`. Same two statements as before. Two examples force a rename and a removal between the reads with an `sql.active_record` subscriber, no stub | plan.md Phase 7; contracts/export-v3.md; research R11 |
| **M6** (= O1) a deviation from the spec | Ruled (O1) | PATCH 1.0.2 | `9d3f072`; plan.md Phase 6 items 6 and 7 word the examples as 1.0.2 does |
| **m1** split rows share one menu name | Taken | `lot_actions_label(lot)`: "Actions for DMR · 27 NM in Blue binder" / "…, no location"; an `entries_show_spec` example | plan.md Phase 4 |
| **m2** refusal page: touch targets, undefined class | Taken | `.c-locations__lots a` gets the 44px floor in `additions.css`; a system example measures the links; `Locations.md` documents it in Phase 8 | plan.md Phase 3, Phase 8 step 4; contracts/api.md |
| **m3** `lot_line` duplicates `lot_summary` | Taken | `lot_line` = `lot_summary` plus the price paid | plan.md Phase 3 |
| **m4** the duplicate-row reason doesn't name the location | Taken | Version 3 wordings "…, price and location as row M" / "…as an earlier row"; versions 1 and 2 keep the old text; the area doc's problem table is updated in Phase 8 | plan.md Phase 6; Phase 8 step 1; contracts/api.md |
| **m5** AC-6.7's example stubs `Lot.add!` | Taken | Model level: a location deleted after it was found makes `Lot.add!` and `revise!` raise `InvalidForeignKey` (Phase 1). Request level (add, edit, move): a subscriber on `sql.active_record` deletes the location right after the lookup, so the real foreign key answers and `rescue_from` maps it to 404; no stub | plan.md Phases 1, 4, 5 |
| **m6** the Move's retry example is a placeholder | Taken, by dropping the retry. The twin is read inside `Lot.transaction`, which SQLite opens IMMEDIATE, so writers are serialised; the unique index (Phase 1's example) is the backstop | `Lot::Move#call!` has no retry branch; `verification.md` records why | plan.md Phase 5, Phase 8 step 8, Self-Review |
| **m7** new files join the core checks too late | Taken | Phases 3 and 5 add their files to `spec/import_apply_core_spec.rb` as they create them; Global Constraints and the File Structure say so | plan.md |
| **m8** AC-2.4 and AC-2.6 have no request test | Taken | Phase 4 adds by-request examples for the twin merge (AC-2.3), the cap's 422 beside Quantity (AC-2.4) and quantity plus place in one save (AC-2.6); the Requirement Map row lists 2.4 and 2.6 | plan.md Phase 4 and Requirement Map |
| **m9** the crash example doesn't simulate the crash | Taken | The example removes the index first, runs `up`, and asserts the column and the index | plan.md Phase 0 |
| **m10** Phase 0's first commit leaves the suite red | Taken | One commit: migration, schema, migration spec, Coverage row and the document spec's `left_out` line | plan.md Phase 0 |
| **m11** the index row's Supersedes cell is incomplete | Taken now, not in Phase 8 | The row gained spec 025 decision 9 and ADR 0023's "reads versions 1 and 2" bullet | docs/specs/README.md |

The review's two notes (area doc citations at `data-portability.md:152` and `:204`, the cost and 26 MB estimates) are in Phase 8 steps 1 and 7.

## What this revision did not change

No requirement, decision or design: the key, the restrict key, the refusal, version 3 and the apply's order are as the review found them. The plan stays a draft until the maintainer approves it; ADR 0025 stays Proposed until then.

# Second review (2026-10-24)

**Reviewed:** the revised plan at `85fb474` (spec 1.0.2) by an independent read-only Sonnet review: **NEEDS REVISION**, 0 critical, 2 major, 5 minor. All 17 findings of the first round were found fixed; the review's text is kept in the session scratchpad, not in the repository.
**Revised:** 2026-10-24, commit `5f6703c` (`plan.md`, `research.md`, `data-model.md`, `contracts/export-v3.md`). Every finding was taken; nothing was run and the spec was not changed (no PATCH).

| Finding | Verdict | Fix | Where |
|---|---|---|---|
| **Major 1** `Lot::Move` judges a stale in-memory lot; a double submit creates or loses copies | Taken. Traced: a whole move twice to one place finds the moved row as its own twin, adds to it and destroys it; a split of 3 twice sets the source to 1 twice and adds 3 twice | `call!` runs `lot.reload` and `valid?` inside `Lot.transaction` (IMMEDIATE), so the range, "already there" and the twin are judged on the rows under the lock; a lot deleted meanwhile is a 404. Two model examples that fail without the reload: (a) two whole moves to `blue` from two instances, the second refused "Those copies are already there."; (b) two moves of 3 of 4, the second refused "Choose from 1 to 1 copies."; total copies 4 after each call. The m6 argument now says what makes "writers are serialised" true | plan.md Phase 5 (5.1, `call!`), Self-Review, Phase 8 step 8 |
| **Major 2** the M5 fix's second read contradicts NFR Performance bullet 2 (spec.md:414) | Taken, **by changing the plan, not the spec** (no PATCH 1.0.3, no entry in Open Items). A single statement is possible: the lots statement `LEFT JOIN`s `locations`, so each lot's name is read in the statement that reads the lots | `LOT_COLUMNS` ends in `locations.name`, `lot_rows` uses `left_joins(:location)`. The account's locations (the empty ones too) stay a second read, as they always were. The join alone doesn't remove the rename race, because the list is still read separately (a rename between the reads leaves a lot naming a name the list lacks), so the existing check stays, keyed on names: if a placed lot's name isn't among the names just read, both reads repeat, at most 3 times, then `Unsettled`. No long transaction. The rename example now expects the retry (the file lists and names "Crate"), and a third example expects `Unsettled` | plan.md Phase 7 (7.1, 7.2); research R11 and §Performance; data-model.md; contracts/export-v3.md |
| **m-a** the AC-6.7 trigger fires on the list read, so the examples can pass without the foreign key | Taken | The delete fires on the `find`'s statement (`"locations"."id" = `), not the first `FROM "locations"`; a second subscriber records that `INSERT INTO "lots"` / `UPDATE "lots"` ran and the lot table is as it was, so the foreign key is what answered | plan.md Phase 4 (4.1), Phase 5 (5.1) |
| **m-b** the round-trip snippet names an undefined `bytes` | Taken | `JSON.parse(ExportFormatRules.examples("valid").fetch(name))["format_version"] > 2` | plan.md Phase 6 intro |
| **m-c** the statement counts include the subscribers' own SQL | Taken | The race examples count the reads of `FROM "lots"` (2 and 3) and the helper leaves out the subscribers' statements by their SQL text | plan.md Phase 7 (7.1) |
| **m-d** a placeholder (`… as before`) in the export snippet | Taken | The entry hash is written out from `collection_export.rb:36-38` (keys `collector_number`, `language`, …); the Self-Review says so | plan.md Phase 7 (7.2), Self-Review |
| **m-e** O2 and O3 live only in the plan | Taken | Phase 8 step 8 lists O2 and O3 for `verification.md` beside O1, as plan-level rulings the spec has no sentence for (no spec change; the maintainer ruled the PATCH to O1 only) | plan.md Phase 8 step 8 |

**Not taken:** none.

## Approval

The maintainer approved the plan on 2026-10-24 after the Opus review, the Sonnet second review and the two revisions above, accepted ADR 0025 (its Status line becomes Accepted in Phase 8 step 2, as the plan names) and chose Sonnet for execution.
