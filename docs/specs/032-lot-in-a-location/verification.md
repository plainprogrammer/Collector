# Verification: Feature 032, Put a Lot in a Location

- **Spec:** [spec.md](spec.md) (1.0.2), plan (retired in `91700487e563dd2821dc5cb5ea294f0af104061e`; read it with `git show 91700487e563dd2821dc5cb5ea294f0af104061e^:docs/specs/032-lot-in-a-location/plan.md`) (approved by the maintainer on 2026-10-24)
- **Branch:** `032-lot-in-a-location` (issue [#45](https://github.com/plainprogrammer/Collector/issues/45))
- **Date:** 2026-10-24
- **Executor:** Sonnet 5.5 (an Orca worker; the maintainer chose the model)

**Not run, or owed:**

- **The implementation review (`sdd-review` Mode B) is not here.** The coordinator runs it after this file; it adds the `## Implementation review` heading.
- **Spec 031's upgrade check is not on `origin/main`** (checked 2026-10-24: `script/upgrade` doesn't exist), so plan step 8.9 is **deferred**. Nothing of 031 needs a change for this migration: it adds a nullable column, creates no table and rewrites no lot row, so it needs no `expected_changes.yml` entry and no seed exception, and `script/upgrade/seeds/next.rb` is optional (the independent review, 2026-10-25). `next.rb` also runs in the previous image under `--previous-ref`, where `location_id` and `Lot.add!(location:)` may not exist, so if it ever places a lot it must guard that with `Lot.column_names.include?("location_id")`. The follow-up issue is for the coordinator to file; nothing was posted to GitHub from this run.
- **No CI run on GitHub exists yet** (nothing is pushed). The amd64 and arm64 image builds run only there.
- The local `bin/ci` result is at the end of this file.

Evidence cells name a spec file and the example's wording (all under `spec/` unless a path says otherwise), a measurement, or a reading of a document. Phases 0 to 7 ran every example red first, for the reason each phase's tests name (a missing column, method, route or file; or the old behaviour); the exceptions are examples that pin behaviour that already held and say so (`AC-7.2`, `AC-7.6` after a whole move, the "an unplaced copy" examples).

## Rulings and deviations

| Item | What | Source |
|---|---|---|
| O1 | "in <location>" goes on the removed lots and on the problem rows, the two lists the preview has; AC-10.7 is checked by the counts and the removed lot's line | spec PATCH 1.0.2 (`9d3f072`); plan Open Items; `collection_import_spec` "adds one lot and removes one for a file that moves a lot between places, naming the place it leaves", "carries the file's location on a problem row"; `collection_import_previews_spec` "puts 'in <location>' on a removed lot and the reason on a problem row" |
| O2 | When only the restored rows pass 9,999, the first restored row is named as an unsaved lot; an existing lot that would overflow is named first by the table's sort | plan Open Items (a plan-level ruling the spec has no sentence for; it refines AC-7.8 in `BulkRemoval#check_cap!`); `bulk_removal_spec` "raises the cap error naming the entry when only the restored rows pass 9,999", "names an existing lot that would overflow before a restored row" |
| O3 | An edit without `lot[location_id]` keeps the lot's place; a blank one is "No location" | plan Open Items (a plan-level rule beside AC-2.x; no spec sentence); `lots_spec` "keeps the place when the parameter is absent and unplaces on a blank one" |
| M1 (round 2) | `Lot::Move#call!` has no retry: it reads the lot again under SQLite's IMMEDIATE write lock and judges the move against it, so writers are serialised; the unique index is the backstop | plan review round 2 M1, m6; `move_spec` "refuses a second whole move built from the same stale lot…", "refuses a second split…", "the unique index refuses two lots of one identity in one place even past validations" |
| Price order | The refusal page orders lots with the same price text by cents, not by the preview's price text | plan 3.2; `holdings_spec` "lists at most 100 lots, ordered by …" |
| Export reads | The export reads each lot's location name in the statement that reads the lots (a `LEFT JOIN`), and the locations in a second one; if a lot's name is not among them the reads repeat, at most 3 times, then `CollectionExport::Unsettled` | plan review M5, round 2 M2; `collection_export_spec` "a location changed between the export's two reads" (three examples) |
| Commit shape | Phase 3's two plan commits are one (`598409a`): the controller's index and destroy and the core-file list share files | commit message |
| Remedy 2 | The apply writes its lots with one multi-row `INSERT .. ON CONFLICT` per batch through `?` placeholders (`Apply#upsert_lots!`) instead of `Lot.upsert_all`, after the write transaction missed its bar in one measured case; no behaviour changed | maintainer's ruling of 2026-10-24; Measurements below; `apply_spec` "writes the lots in one multi-row statement per batch, one that upserts on the lot's identity" |
| Spec patches | None beyond PATCH 1.0.2 (before execution). The spec was not changed by this run | |
| Shipped specs | Not edited. The supersessions are in spec 032's Supersedes table and in the index row (both directions, already merged with the spec), re-read below | |

## Acceptance criteria and requirements

"lots_spec" is `spec/requests/lots_spec.rb` (the describe "in a location"), "moves_spec" is `spec/requests/lot_moves_spec.rb`, "locations_spec" is `spec/requests/locations_spec.rb` (the describe "a location that holds lots"), "import_spec" is `spec/models/collection_import_spec.rb` (the describe "version 3"), "apply_spec" is `spec/models/collection_import/apply_spec.rb` (the describe "lots in locations"), "rules_spec" is `spec/models/export_format/rules_spec.rb` (the describe "version 3"), "examples_spec" is `spec/export_format_examples_spec.rb` (the describe "version 3"), "export_spec" is `spec/models/collection_export_spec.rb` (the describe "a lot's location").

### Decisions and details

| Item | Evidence |
|---|---|
| D1 (identity includes the location; unique, backed by the database; FR-1) | `lot_spec` ".key_for carries the place…", ".add! in a place", "the unique index" ("tells a placed lot from an unplaced one…", "rejects a duplicate identity even when validations are skipped"); `add_location_to_lots_spec` (the column, index and foreign key) |
| D2 (unplaced is a real state; nothing backfilled) | `add_location_to_lots_spec` "keeps every lot, mark, line, entry and undoable removal going down and up" (every `location_id` is null after) |
| D3 (a location that holds copies can't be removed) | locations_spec "refuses on the confirmation page…", "answers 409 to DELETE…", "refuses a delete after the confirmation opened empty and a lot was put in meanwhile"; `location_spec` "can't be deleted while a lot is in it, even by SQL" |
| D4 (a place is set by the add form, the edit form and Move copies) | lots_spec, moves_spec (below) |
| D5 (the grid, table, quick add, typed entry, scanner and bulk bar add unplaced copies) | `quick_adds_spec` "adds an unplaced copy beside a lot in a location"; `number_entry_spec` and `sitting_spec` ".add! beside a lot in a location"; `collections_spec` "counts a lot in a location like any other and shows no location"; the forms of those pages gained no field (no view of them changed) |
| D6 (another account's id is 404) | lots_spec "answers 404 for another account's location or a missing one…" (add, edit); moves_spec "answers 404 for another account's lot or destination…"; locations_spec "answers 404 for another account's location on the confirmation and the delete" |
| D7 (older files are read as unplaced) | import_spec "reads a version 1 or 2 file's lots as unplaced…"; apply_spec "makes an older file's lots unplaced, needing the removal confirmation"; `collection_import_previews_spec` "says an older file's lots would be in no location…" |
| P1 (the refusal page lists 100 lots in the preview's order, "and N more") | `holdings_spec`; locations_spec "lists 100 lots in order and says how many more" |
| P2 ("12 copies in 3 lots", "1 copy in 1 lot", "Empty") | locations_spec "counts what each location holds on the locations page" |
| P3 (no locations: no select, a link; Move says so) | lots_spec "offers no select and a link to add a location…"; moves_spec "says there are no locations yet and offers no Move…" |
| P4 (a move to the lot's own place is refused) | `move_spec` "refuses a move to the lot's own place, unplaced included"; moves_spec "refuses a move to where the lot already is" |
| P5 (Undo restores a lot whose location is gone unplaced and says so) | `bulk_removal_spec` "restores a lot whose location was removed unplaced and says how many"; `bulk_removal_spec` (request) "says how many lots came back without a location…" |
| P6 (a split makes a new lot; a whole move keeps the id; a merge keeps the destination's) | `move_spec` ".call! moves every copy to an empty place, keeping the lot's id…", "splits…", "merges a whole lot into the twin, which survives with its id and created_at" |

### Story 1 (add) and Story 2 (edit)

| Item | Evidence |
|---|---|
| AC-1.1 | lots_spec "offers No location (selected) then the account's locations in order" |
| AC-1.2 | lots_spec "puts the copies in the chosen location and says so", "says 'to your collection' for No location and for no key" |
| AC-1.3, AC-1.4 | `lot_spec` ".add! in a place" "merges only into the lot in the same place"; lots_spec "adds to the lot in the same place and keeps a separate lot per place" |
| AC-1.5 | `lot_spec` "holds 9,999 per place"; lots_spec "holds 9,999 per place and refuses the next with the cap message" |
| AC-1.6 | lots_spec "keeps the chosen location selected on a 422" |
| AC-1.7 | lots_spec "answers 404 for another account's location or a missing one, creating nothing"; `lot_spec` "refuses another account's location" |
| AC-1.8 | lots_spec "says 'to your collection' for No location and for no key" |
| AC-1.9 | lots_spec "offers no select and a link to add a location when the account has none" |
| AC-2.1 | lots_spec "selects the lot's place, and No location for an unplaced lot" |
| AC-2.2 | lots_spec "moves the same lot to the chosen place"; `lot_spec` "#revise! to a place" "moves the same lot, keeping its id and created_at" |
| AC-2.3 to AC-2.6 | `lot_spec` "merges into a twin in the new place", "refuses a merge over the cap and changes neither lot", "merges into the unplaced lot when revised to no location", "ends with the new quantity in the new place when both change"; lots_spec "makes one lot when the place already holds a twin", "refuses a merge past 9,999 beside Quantity, changing neither lot", "ends with the new quantity in the new place when both change" |
| AC-2.7 | lots_spec "answers 404 for another account's location, leaving the lot as it was" |
| AC-2.8 | lots_spec "returns to the collection table's page when it came from there" |

### Story 3 (Move copies)

| Item | Evidence |
|---|---|
| AC-3.1 | moves_spec "opens a page titled for the lot, with Copies, To, Move and Cancel", "starts an unplaced lot's select on the first location", "offers Move copies in the card page's lot menu, not in the collection table's" |
| AC-3.2, AC-3.3, AC-3.5 | moves_spec "moves the copies and says so"; `move_spec` "moves every copy…", "splits…", "moves to no location, joining or starting the unplaced lot" |
| AC-3.4, AC-3.4a | `move_spec` "adds some copies to the twin in the destination", "merges a whole lot into the twin…" |
| AC-3.6, AC-3.7 | `move_spec` "refuses a result over 9,999…", "refuses copies outside 1 to the quantity"; moves_spec "answers 422 with the reasons beside Copies and To, keeping the choice" |
| AC-3.8 | `move_spec` "leaves both lots unchanged when a write fails after the source changed" (a trigger forces the failure) |
| AC-3.9 | moves_spec "answers 404 for another account's lot or destination, or a missing one, changing nothing" |
| AC-3.10 | moves_spec "says there are no locations yet and offers no Move when there are none" |
| AC-3.11 | moves_spec "puts the move under a lot" and the routing example in `spec/routing/routes_spec.rb`; signed out: moves_spec "when signed out sends the page and the write to sign in" |
| AC-3.12 | `spec/system/lot_moves_spec.rb` "moves 2 of 4 copies and cancels another move, with the keyboard, at 360px" |

### Story 4 (see where copies are) and Story 5 (remove only when empty)

| Item | Evidence |
|---|---|
| AC-4.1, AC-4.2 | `entries_show_spec` "lists a row per lot with its Location, unplaced first and then by location", "carries the place on the phone line under the printing" |
| AC-4.3 | locations_spec "counts what each location holds on the locations page" |
| AC-4.4 | `collections_spec` "counts a lot in a location like any other and shows no location" |
| AC-4.5 | locations_spec "escapes a location name with markup on the list and the refusal page"; `entries_show_spec` "escapes a location name with markup" |
| AC-5.1 | locations_spec (the existing "asks first, naming the location…" for an empty one, unchanged); "removes the location once its lots are gone" |
| AC-5.2 | locations_spec "refuses on the confirmation page, counting and listing, with no Remove button"; `spec/system/locations_spec.rb` "refuses a location that holds lots without scrolling sideways, with 44px links and the keyboard" |
| AC-5.3 | locations_spec "lists 100 lots in order and says how many more" |
| AC-5.4, AC-5.5 | locations_spec "answers 409 to DELETE with the same page, removing nothing", "refuses a delete after the confirmation opened empty and a lot was put in meanwhile"; `location_spec` "can't be deleted while a lot is in it, even by SQL" |
| AC-5.6 | `spec/system/lot_moves_spec.rb` "empties a location one lot at a time, then removes it" |
| AC-5.7 | locations_spec "shows no count, lot or name of another account's same-named location" |

### Story 6 (tenancy) and Story 7 (other changes keep working)

| Item | Evidence |
|---|---|
| AC-6.1, AC-6.2 | lots_spec, moves_spec (404 rows above, two accounts with "Box" in moves_spec; the other's rows and `updated_at` unchanged) |
| AC-6.3 | locations_spec "shows no count, lot or name of another account's same-named location" |
| AC-6.4 | locations_spec "shows no location, name or count on the admin pages" (now with a placed lot) |
| AC-6.5 | locations_spec "when signed out sends the refusal page's routes to sign in" (and spec 029's existing signed-out examples); moves_spec "when signed out" |
| AC-6.6 | `account_spec` "deletes its lots before its locations, so lots in locations don't block it" |
| AC-6.7 | lots_spec "answers 404, not 500, when the location is removed after it was found, the foreign key refusing the write" and the edit's twin; moves_spec "answers 404, not 500, when the destination is removed after it was found". The delete fires on the `find`'s statement and a second subscriber records that the `INSERT`/`UPDATE` of `lots` ran: the foreign key answered, nothing is stubbed. At the model: `lot_spec` "raises the foreign key's error, writing nothing, when the location is gone meanwhile" (add and revise) |
| AC-7.1 | `add_location_to_lots_spec` (the whole file: down and up keep every lot and every pointer to one; refuses to go down with a placed lot; finishes a run that stopped between its two steps; the guard of `disable_ddl_transaction!`, see Migration below); `lot_spec` ".key_for carries the place…" ("today's key" for an unplaced lot) |
| AC-7.2 | `quick_adds_spec`, `number_entry_spec`, `sitting_spec` (the AC-7.2 examples; they pin behaviour that held once the factory could place a lot) |
| AC-7.3 | `condition_change_spec` "with locations" (three examples: keeps the place, merges only within a place, caps per place) |
| AC-7.4, AC-7.5 | `bulk_removal_spec` "with locations": "saves each lot's place", "restores each lot to its place and merges per place", "restores a lot whose location was removed unplaced and says how many" |
| AC-7.6 | `line_spec` and `sitting_entry_spec` "#undo! after a move", "#undo! after Move copies" (whole move to an empty place undoes against the lot where it is; a merge makes it not undoable / `:changed`; a split below the line's quantity is not undoable) |
| AC-7.7 | lots_spec "removes a lot in a location, leaves the location and ends an earlier bulk removal's Undo" |
| AC-7.8 | `bulk_removal_spec` "merges restored rows that share an identity once their location is gone", "restores saved lots with no location key unplaced", and the O2 rows above |

### Stories 8 to 11 (the format, the export, the preview, the apply)

| Item | Evidence |
|---|---|
| AC-8.1 to AC-8.6 | export_spec ("writes the stored name or null for every lot, never an empty string", "writes a printing in two places as two lots", "lists an empty location and every lot's location among the names", "writes nothing of another account's places", "writes the same file twice, apart from exported_at", "writes null everywhere and no locations for an account with none"); "writes exactly the fields the format defines" compares with `valid/collection-v3.json` |
| AC-9.1 | The document read (below); `export_format_document_spec` "names every field that appears in the valid examples" and "states the newest version…"; examples_spec "carries a lot in a location, a printing in two, an unplaced lot and an empty location in one valid example" |
| AC-9.2 | Versions 1 and 2 files, schemas and examples are unchanged (`git diff --stat 9f10edb..HEAD -- docs/export-format/v1.schema.json docs/export-format/v2.schema.json` is empty and no existing example file changed; `problems.json` only gained entries); `rules_spec` "keeps a byte-identical copy of every documented schema" (now three) and "judges a file against the schema of its own version" |
| AC-9.3 | `export_format_document_spec` "accounts for every column of a table that isn't left out whole" and "maps each column to a field…" (`lots.location_id` → `location`) |
| AC-9.4 | rules_spec "finds a lot whose location the file's locations don't list, but not one listed in another case or form"; examples_spec "accepts the values at the edges of the rule" |
| AC-9.5 | rules_spec "finds a missing, mistyped or ill-formed lot location where the schema says", "gives a lot six identity values…", "finds the repeat of a lot whose location differs only in case…"; examples_spec "finds each listed variant of a malformed lot location"; every invalid example in `problems.json` is judged for its one reason |
| AC-9.6 | examples_spec "holds the same collection for the same lots in another order…", "differs for a changed or re-cased lot location", "compares a lot's location exactly, though the identity treats 'Box' and 'box' as one place" |
| AC-9.7 | `name_parity_spec` "a lot's location in v3.schema.json" (every scalar value in four forms, and the same pattern and limits as a name) |
| AC-9.8 | rules_spec "ignores a location on a lot of a version 1 or 2 file" |
| AC-10.1 | import_spec "reads versions 1, 2 and 3, each against its own schema"; "refuses a newer version as newer, before the schema" (format version 4, "This instance reads version 3.") |
| AC-10.2 | import_spec "matches a held lot on printing, finish, condition, price paid and location, 'box' being 'Box'" |
| AC-10.3 | import_spec "makes a problem row of a lot whose location the file doesn't list, holding back the lot it matches" |
| AC-10.4, AC-10.5 | import_spec "reads a version 1 or 2 file's lots as unplaced…"; `collection_import_previews_spec` "says an older file's lots would be in no location…" |
| AC-10.6 | import_spec "has nothing to change for the account's own version 3 file"; `round_trip_spec` "previews the exported collection, locations and all, as nothing to change" |
| AC-10.7 | import_spec "adds one lot and removes one for a file that moves a lot between places, naming the place it leaves" (as 1.0.2 words it) |
| AC-10.8 | import_spec "lists a rename and changes no lot" |
| AC-10.9 | import_spec "carries the file's location on a problem row"; request spec "puts 'in <location>' on a removed lot and the reason on a problem row"; the system example at a 500px window (the narrowest headless Firefox opens) "fits a 500px window for a version 3 file with a removed lot in a location and a problem row" |
| AC-10.10 | import_spec "lists every lot of a location the file drops as removed, with the location" |
| AC-10.11 | import_spec "reads only its own account's lots and locations" |
| AC-11.1 | apply_spec "puts every lot in the file's location or none, with the key that carries the place" |
| AC-11.2, AC-11.14 | `round_trip_spec` "restores lots in two locations, a printing in both, an unplaced lot and an empty location" (the second export equals the first but for `exported_at` and the profile); "every valid example of the format" applies each example of versions 1, 2 and 3 (except `lot-location-nfd.json`, which re-exports with the stored spelling, AC-9.4) and compares with `as_current_version` (version 3; no locations for a version 1 example; every lot's `location` null for an older example) |
| AC-11.3 | apply_spec "moves a lot from one place to another: one added, one removed" |
| AC-11.4 | apply_spec "makes an older file's lots unplaced, needing the removal confirmation" |
| AC-11.5 | apply_spec "keeps a location's id and its lots untouched when only its spelling changes" |
| AC-11.6 | apply_spec "deletes the lots of a removed location first and answers stale when a lot was placed there after the preview" |
| AC-11.7 | apply_spec "answers stale when a lot was moved to another place between preview and apply"; `plan_spec` "changes the fingerprint when a held lot's place changes" |
| AC-11.8 | apply_spec "has nothing to change the second time" |
| AC-11.9 | apply_spec "applies a file whose only change is one lot's place" |
| AC-11.10 | apply_spec "rolls back locations, lots and working state when a write fails after the locations were written" (a trigger fails the lot insert) |
| AC-11.11 | apply_spec "resolves 'Box' to its own account's location and leaves another account's alone" |
| AC-11.12 | Measured below; apply_spec "runs the same number of write statements for 5,000 lots in 500 locations as for 50 in 5" |
| AC-11.13 | apply_spec "clears the working state when a lot is written, not when only a location changes" |

### Non-functional requirements

| Item | Evidence |
|---|---|
| Performance, queries per page | `query_counts_spec` (card page with 1 and 20 placed lots, the add form with 1 and 30 locations, the locations page and the refusal page, Move copies with 1 and 30 locations); `holdings_spec` ".counts runs two statements whatever the number of locations or lots"; export_spec "reads the lots and their places in one statement…" (one `FROM "lots"` read at 3 and at 23 lots). Measured at 500 locations and 5,000 lots below |
| Security | Every lookup is through `Current.account` (the 404 rows above); `account_id` is never permitted (`params.expect(lot: %i[quantity finish condition price_paid location_id])`, `move: %i[copies location_id]`); `bin/brakeman` clean (`bin/ci` below); the one hand-written SQL, `Apply#upsert_lots!`, binds every value through `?` and `sanitize_sql_array`; `Lot::ConditionChange`'s `update_all` SQL is constant text with bound values (existing comment kept) |
| Reliability (migration) | Below |
| Cost per account | Below |
| Core names no collectible (FR-1) | `spec/import_apply_core_spec.rb` lists each new file (`location/holdings.rb`, `refused.html.erb`, `locations_helper.rb`, `lot/move.rb`, `lots/moves_controller.rb`, `lots/moves/new.html.erb`) and both of its examples pass |

## Migration

`db/migrate/20261023100001_add_location_to_lots.rb` adds `lots.location_id integer REFERENCES locations (id) ON DELETE RESTRICT` with `ALTER TABLE .. ADD COLUMN` (SQLite copies no table), and an index; both steps are guarded, so a run that stopped between them is finished by the next. It runs with `disable_ddl_transaction!`, because dropping the column on the way down rebuilds `lots`, and with foreign keys enforced inside a transaction the rebuild's `DROP TABLE` would run the `ON DELETE` actions of the tables that point at lots.

- **Reversibility (the plan's proof):** `add_location_to_lots_spec` goes down and up through the Migrator (`MigrationContext#run`, as `db:rollback` does) with a bulk selection's marks, a number-entry line, a scanner entry and an undoable removal, and each lot and each pointer is as it was. Down refuses with `ActiveRecord::IrreversibleMigration` ("1 lot is in a location; move them out before rolling back") while a lot is placed; no lot changes.
- **The guard works:** with `disable_ddl_transaction!` commented out the spec's first and third examples went red (the marks cascade away during the rebuild); the line was put back. (A first version of the spec ticked no lot, so its marks were empty; the examples now pass `shown_ids` too, which was found and fixed in Phase 2.)
- **`db/schema.rb`** gained `t.integer "location_id"`, its index, the foreign key and the version `2026_10_23_100001`; the cache, queue and cable schema files were restored after each `db:migrate` and are unchanged in the diff.
- **Time on 50,000 lots:** `ADD COLUMN` plus `CREATE INDEX` 0.010 s; the way down 0.09 s (measured below).

## Measurements (AC-11.12 and the NFRs)

**Machine and method.** Apple M1, 16 GB, macOS, Ruby 4.0.7. A throwaway runner in the session scratchpad (never committed) ran in the test environment against a database created under `tmp/measure/` (`DATABASE_URL=sqlite3:tmp/measure/m.sqlite3`; the schema was loaded into that file only; nothing under `storage/` was read or written and no maintainer data was involved), through `ActionDispatch::Integration::Session` requests (sign-in, the preview's POST, the apply's POST) so each figure is a whole request. It seeded one set, 50,000 identities, entries and printings, and four users, and deleted its database afterwards. The write transaction is the longest `transaction.active_record` duration seen while the apply request ran; RSS is `ps -o rss` before and after the request. Files: (a) a version 3 file, 50,000 lots each in one of 500 locations whose names are 60 CJK characters (23.3 MB, under the 32 MB `MAX_BYTES`), into an empty account; (b) a version 2 copy of it (every lot loses its place), applied with the removal confirmed to the account that (a) filled: 50,000 deletes and 50,000 inserts, the heaviest case.

**First measurement (before the remedy), two runs:**

| Case | Write transaction (bar 4 s) | Statements | Preview / apply request (bar 30 s) | RSS growth (bar 500 MB) |
|---|---|---|---|---|
| (a) 50,000 lots, 500 locations, into an empty account | 2.93 s, 2.94 s | 50 lot INSERTs + 1 locations INSERT | 7.3 s / 10.1 s | +180 MB, +236 MB |
| (b) a version 2 copy over the 50,000 placed lots | **3.95 s, 4.08 s (missed in run 2)** | 50 DELETEs + 50 INSERTs | 5.5 s / 8.8 s, 9.2 s | +172 MB, +146 MB |

The miss was put to the maintainer, who ruled remedy 2 (a no-behaviour-change optimisation first, then measure both cases twice). A profile of (b) found the SQL itself fast (DELETE 0.22 s, INSERT 0.13 s of statement time) and the rest Ruby: `Lot.upsert_all` spent about 2.6 s of the 50,000 rows in per-value type casting (a raw multi-row `INSERT .. ON CONFLICT` of the same rows took 0.32 s; the preview's parse and `replan` are 0.8 s each and unchanged). The apply now writes its lots with `Apply#upsert_lots!` (commit `139d55e`).

**After the remedy, two runs each:**

| Case | Write transaction (bar 4 s) | Preview / apply request (bar 30 s) | RSS growth (bar 500 MB) |
|---|---|---|---|
| (a) | **0.87 s, 0.96 s** | 7.5 s, 7.4 s / 8.2 s, 8.3 s | +188 MB, +170 MB |
| (b) | **1.84 s, 2.00 s** | 5.5 s / 6.7 s, 7.1 s | +160 MB, +110 MB |

Both cases are under every bar with at least 2x on the write transaction. Statements: no lot or location is written one at a time (50 lot statements for 50,000 lots in each direction, one for the locations).

**Other numbers (same runs):**

- The export of the 50,000 placed lots: 0.63 to 0.75 s, 23,312,896 bytes, the same size as the file; it equals the file but for `exported_at` (and the order of the locations, the export listing them by comparison key).
- **Queries per page, 500 locations and 5,000 lots against one location and one lot** (bob and carol of the runner): locations page 7 and 7, card page 16 and 16, Move copies 9 and 9, refusal page 10 and 10. The time per page was 0.004 to 0.044 s in both.
- **Migration on 50,000 lots:** `ADD COLUMN` plus `CREATE INDEX` 0.0099 to 0.0101 s; the way down (the table rebuild) 0.093 to 0.095 s.
- **Cost per account:** the database file with the 50,000 entries only was 23,719,936 bytes; after (a) it was 29,618,176 (+5.9 MB for 50,000 placed lots, 500 locations of 60 CJK characters and the index on `location_id`, about 118 bytes a lot); after (b) it was 30,519,296 (the freed pages of the deleted lots are not returned without a `VACUUM`).

## Documents (read, not run)

| Item | Reading |
|---|---|
| `docs/export-format/README.md` | Header "3"; the intro names three schemas and ADR 0025; the `format_version` and `locations` rows; "Not recorded" says `null` for a lot in none; Lots gains `location` and "all eight fields"; Locations and Names reach a lot's `location`; Lot identity has six values; Well-formed lists the new rule and three schemas; The same collection compares a lot's location exactly; Versions has the row for 3 (2026-10-23) and the rewritten expected-changes sentence; Coverage maps `lots.location_id` to `location`; Examples lists the version 3 files; the rule table has `unknown_location`. Each change of `contracts/export-v3.md`'s table is made |
| `docs/architecture/data-portability.md` | Updated in this pull request, each statement with its source inline (spec 032 criteria, ADR 0025): scope, glossary, invariants, the export, reading a file (version 4 is newer; `unknown_location`; six-value `duplicate_lot`), outcomes, the preview page, the apply's order, the fingerprint, the constants, the decisions, the limits (the #45 line removed), Sources, and a Distillation log row. `git grep -n "version 2" docs/architecture/data-portability.md ':!.kamal/secrets'` was read: every remaining hit is about version 2 itself or about a version 2 or 3 file. `docs/architecture/release-and-deploy.md` states nothing this spec changes (its "version" lines are the backup format's) and is not touched |
| ADRs | ADR 0025 is Accepted (2026-10-24) and its row in `docs/adr/README.md` has no "(Proposed)"; ADR 0019's and ADR 0023's Status lines point to ADR 0025 |
| Supersessions, both directions | Re-read against what shipped: spec 032's Supersedes table (specs 004, 006, 009, 017, 022, 025, 026, 028, 029; ADRs 0019 and 0023) and the index's 032 row and the Supersedes cells of those rows agree; the shipped specs are not edited. PATCH 1.0.2 is in the spec and the index |
| `docs/roadmap.md` | Item 10 is marked built with spec 032 and ADR 0025 (its pull request is recorded when it merges); the YARD line's expected ADR is "the next free number after 0025" |
| Design system | `Locations.md` gains the holdings text, the refusal page, `c-locations__more` and the lot links' 44px floor, and says the Location column and the Move copies page are existing components; the README's app additions have the spec 032 line; `additions.css` has `c-locations__holds`, `c-locations__more` and `c-locations__lots a` (tokens and `--touch-floor` only). Screenshots at 1280px and 390px in light and dark are in `screenshots/` (card page, Move copies, refusal page, locations page; the import preview at 1280px); they were read and show the new column, the form, the refusal page and the holds line without overflow |
| `CLAUDE.md`, `README.md` | The status sentence, the export bullet (version 3, `[1, 2, 3]`), a "Lots in locations" bullet and the Locations bullet, each pointing at the area doc; the README's "Your data" and the export-or-backup table say version 3, read versions 1 to 3 and that a location that holds copies can't be removed |
| `docs/specs/README.md` | The 032 row's status is left "Approved (v1.0.2, 2026-10-24)" for the implementation review and the distillation step, as 030's row was handled; its Plan cell and Supersedes cells were written with the plan |

## bin/ci

`bin/ci` ran in this worktree on 2026-10-24 at the last commit before this file (`139d55e` plus the documents), exit 0:

```
✅ Security: Gem audit passed in 0.65s
✅ Security: Importmap vulnerability audit passed in 1.37s
Finished in 21 minutes 43 seconds (files took 2.91 seconds to load)
2181 examples, 0 failures, 1 pending
✅ Tests: RSpec passed in 21m46.71s
✅ Continuous Integration passed in 21m59.71s
```

RuboCop and Brakeman (earlier steps of the same run) passed; the one pending example is the art agreement spec that needs `COLLECTOR_ART_AGREEMENT` (not this feature's). The suite took 21 minutes in this run against 2 minutes 45 seconds in the phases' own runs because the machine was shared with other work at the time, not because of this feature.

## Implementation review

SPEC-ALIGNED (independent Sonnet review 2026-10-25, after fixes)

Mode B, read-only, at `9a06e97`: 0 critical, 0 major, 5 minor. Every minor is fixed, one commit each, and `bin/ci` is green after them.

| Finding | Fix |
|---|---|
| m1. CLAUDE.md still said `Lot.upsert_all` skips validations | `9b97045`: names `Location.upsert_all` and `CollectionImport::Apply#upsert_lots!` |
| m2. Design system README omitted `c-locations__holds` | `0128ee4`: added to the app additions line |
| m3. No test fed the hand-built lot SQL awkward text | `159cdbd`: an example stores a finish with `'`, `?`, `;`, `--`, `"`, a backslash and non-ASCII, and a condition with `'` and `?`, plus microsecond times, and reads them back unchanged. It passed on first run (the quoting was already sound), so it pins behaviour rather than fixing a defect |
| m4. The note on spec 031's `seeds/next.rb` was wrong | `385ecf2`: 032 needs no `expected_changes.yml` entry and no seed exception, `next.rb` is optional, and a placed lot there needs a `Lot.column_names.include?("location_id")` guard because `--previous-ref` runs it in the previous image |
| m5. CLAUDE.md bullet restated area rules | `2edd3bd`: replaced by a pointer to `docs/architecture/data-portability.md` (spec 027 R5); the collection-and-lots area doc, when written, takes the rest |

`bin/ci` after the fixes: `✅ Tests: RSpec passed in 21m31.97s`, `✅ Continuous Integration passed in 21m43.73s`; 2182 examples, 0 failures, 1 pending (the art agreement spec, needs `COLLECTOR_ART_AGREEMENT`).

Open for the maintainer, from the review's questions: a 500 on an export racing a rename, "No location" shown on every row for an account without locations, and whether `seeds/next.rb` places a lot once 031 and 032 are both on `main`.

## Distillation

`distill-feature` ran on 2026-10-25 before the pull request. The data portability area doc already held what spec 032 established in its area (format version 3, a lot's location in the export, the preview and the apply; Phase 8, with its log row). The distillation added spec 032 to the areas table, marked it Frozen in part (those parts) in the index with its plan's retirement owed (the plan is retired after the merge), and added the spec's frozen line (spec 027 D4). Its collection-and-lots part (a lot's place, Move copies, the refusal to remove a non-empty location) has no area doc yet (#105) and stays in the spec. The supersessions of specs 017, 022, 025, 028 and 029 were already recorded in both directions.
