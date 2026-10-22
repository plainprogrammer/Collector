# Verification: spec 029, Manage Locations

**Spec:** [spec.md](spec.md) v1.3.2 · **Plan:** [plan.md](plan.md) (approved 2026-10-21) · **Branch:** `029-manage-locations`

How to read this: each criterion names the example that holds it (`file`, "example title", or the part of the title that finds it) or the manual check. Prose documents are verified by reading and listed under "Documents". Phases 0 to 5 ran every example red first for the reason their phase names; Phase 6 adds measurements and documents, not code.

## Acceptance criteria

### Story 1: add a location

| AC | Held by |
|---|---|
| 1.1 | `spec/requests/locations_spec.rb`, "shows the heading, the add form and the empty state" |
| 1.2, 1.4, 1.12 | `locations_spec`, "adds a location, redirects (303) and says so, in the order of AC-1.4"; `spec/models/location_spec.rb`, ".ordered" |
| 1.3 | `spec/system/locations_spec.rb`, "adds with the keyboard, renames and removes through the pages" |
| 1.5, 1.11 | `spec/models/location/name_spec.rb`, ".normalise" (NFC; White_Space trimmed and collapsed); `location_spec`, "is stored in normal form with its comparison key"; `locations_spec`, "stores a name in non-Latin script as typed and a combining accent in NFC" |
| 1.6, 1.7, 1.8, 1.9 | `location_spec`, "is refused when blank…", "…over 60 code points, whatever the bytes", "…with a control or format character…", "…when it has the key of another location, quoting the normalised name"; `locations_spec`, "answers 422 with the reason beside the field and the typed text kept" |
| 1.10 | `location_spec`, "refuses the 501st location and allows the 500th"; `locations_spec`, "refuses the 501st location" |
| 1.13 | Deterministic: `location_spec`, "the limit" (the count and the insert are one step per writer) and "the database's own rules" (the unique index refuses a save that validation let through, answering with AC-1.9's message). By hand, below (ten trials of each race) |
| 1.14 | `locations_spec`, "answers 400 without the location parameter" |

### Story 2: rename

| AC | Held by |
|---|---|
| 2.1, 2.7 | `locations_spec`, "opens the edit page holding the name" |
| 2.2, 2.8 | `locations_spec`, "saves, redirects and says what happened, leaving every lot alone" |
| 2.3, 2.6 | `locations_spec`, "allows a change of case alone, and the name it already has"; `location_spec`, "is judged again on a rename" |
| 2.4, 2.5 | `locations_spec`, "refuses another location's key, and the reasons of a new name, keeping the name" |
| 2.9 | `locations_spec`, "lets the later of two saves stand" |
| 2.10 | `locations_spec`, "answers 404 once the location is gone, creating nothing" |

### Story 3: remove

| AC | Held by |
|---|---|
| 3.1 | `locations_spec`, "asks first, naming the location, and removes nothing on a GET" |
| 3.2, 3.5 | `locations_spec`, "removes on DELETE, redirects and says so, and the name can be added again" |
| 3.3 | `spec/system/locations_spec.rb` (Cancel is a link back to the list); `locations_spec`, "asks first…" |
| 3.4 | `locations_spec`, "never touches a lot" |
| 3.6 | `locations_spec`, "answers 404 for one that is already gone, with no message" |
| 3.7 | `locations_spec`, "answers 404 once the location is gone, creating nothing" |

### Story 4: tenancy

| AC | Held by |
|---|---|
| 4.1 | `locations_spec`, "answers 404 for another account's location on every page and write, leaving it unchanged" |
| 4.2 | `locations_spec`, "lists only mine, and lets me use a name another account has"; `location_spec`, "may repeat another account's name" |
| 4.3 | `locations_spec`, "makes the location mine whatever account_id the request carries" |
| 4.4 | `locations_spec`, "when signed out": "sends a visitor to sign in from every page and shows nothing", "does the same with the catalog open", "sends a write with an ended session to sign in and writes nothing", "fails forgery protection first for a write with no session cookie" |
| 4.5 | `locations_spec`, "shows no location, name or count on the admin pages" |
| 4.6 | `location_spec`, "goes with its account" |

### Story 5: reach the page

| AC | Held by |
|---|---|
| 5.1 | `locations_spec`, "adds Locations after Scan in the header, current on its pages, and no tab is marked"; `spec/system/locations_spec.rb`, "keeps Collection, Search, Scan and Locations on one line with the account menu at 640px". Measured widths below |
| 5.2 | `locations_spec`, "puts a Locations row in More before Export collection, and not in the account menu"; `spec/requests/admin/navigation_spec.rb`, `shell_spec.rb` and `number_entries_spec.rb` (More's rows shift by one) |
| 5.3 | `locations_spec`, "adds Locations after Scan in the header…" (no tab marked current) |
| 5.4 | `locations_spec`, "shows a visitor of an open catalog no Locations link" |
| 5.5 | `spec/system/locations_spec.rb`, "never scrolls sideways at 360px, 640px and a 1200px desktop frame in both themes, with 44px targets and a focus ring" and "shows a focus ring on every control the keyboard reaches, on each page". Screenshots below |

### Story 6: the export

| AC | Held by |
|---|---|
| 6.1, 6.4, 6.5 | `spec/models/collection_export_spec.rb`, "writes version 2 with the names only, in order, and a well-formed file" |
| 6.2 | `collection_export_spec`, "writes an empty list for an account with none" |
| 6.3 | `collection_export_spec`, "orders by comparison key then name, in code-point order" |
| 6.6 | `collection_export_spec`, "writes the same file twice for an unchanged collection, apart from exported_at" |
| 6.7 | `collection_export_spec`, "writes none of another account's"; `spec/requests/collection_exports_spec.rb`, "sends this account's locations and no other account's" |
| 6.8 | `collection_export_spec`, "holds a different collection when a name differs in case, and the same one when the order does" |

### Story 7: format, schema, Coverage

| AC | Held by |
|---|---|
| 7.1 | By reading, below |
| 7.2 | `spec/export_format_examples_spec.rb`, "version 2 (spec 029)": "finds each listed variant of a malformed locations value", "accepts the values at the edges of each rule" |
| 7.3 | `spec/models/export_format/rules_spec.rb`, "finds a repeated key at the later location, by case, case folding and normalisation form"; the invalid examples `location-duplicate-case`, `-fold`, `-nfd`; the valid `locations-nfd` |
| 7.4 | `export_format_examples_spec`, "finds nothing wrong with any valid or comparison example", "finds each invalid example wrong for the one reason it names", "holds the same collection for the same names in another order and what the rule ignores", "differs in the case of a name and in the set of names" (every case of decision 9 has an example under `docs/export-format/examples/`) |
| 7.5 | `spec/export_format_document_spec.rb`, "coverage" ("accounts for every table…", "…every column…", "maps each column to a field of the format or says why it is left out") |
| 7.6 | `rules_spec`, "keeps a byte-identical copy of every documented schema"; also `cmp docs/export-format/v2.schema.json app/models/export_format/v2.schema.json` is silent (checked at the end of Phase 6) |
| 7.7 | `spec/models/collection_import/round_trip_spec.rb`; `collection_export_spec` (well-formed under version 2) |
| 7.8 | `spec/models/location/name_parity_spec.rb`, "agrees on every scalar value…" (a, b over all 1,112,064 scalar values and the four string shapes), "exports what the model stores as a well-formed file" (c, a sample of every 997th scalar), "reads the pattern the way json_schemer does, on a sample". Run time of the file: 19.92 s (3 examples) on the machine below |

### Story 8: previewing

| AC | Held by |
|---|---|
| 8.1, 8.2 | `spec/requests/collection_import_previews_spec.rb`, "reads the collector's own version 2 export and shows what happens to the locations"; `spec/models/collection_import/locations_spec.rb`, "adds, renames, keeps and removes by comparison key" |
| 8.3 | `previews_spec`, "says all would be removed for an empty list"; `locations_spec`, "removes every held location for a file with none" |
| 8.4 | `previews_spec`, "says a version 1 file leaves them alone, and shows no removed locations"; `collection_import_spec`, "has no outcomes for locations in a version 1 file" |
| 8.5 | `previews_spec`, "refuses a version 2 file whose locations are not well-formed, as a whole, with the reason"; `collection_import_spec`, "refuses a bad locations list whole…", "refuses a name whose normal form is over 60 code points" |
| 8.6 | `collection_import_spec`, "reads version 1 and version 2, each against its own schema" (a version 3 file is refused as newer: "This instance reads version 2.") |
| 8.7 | `collection_import_spec`, "judges the lots of a version 2 file as it does a version 1 file's" |
| 8.8 | `previews_spec`, "writes only the upload, its blob and its attachment for a version 2 file" |
| 8.9 | `locations_spec` (model), "lists the first 100 renamed and removed…"; `previews_spec`, "counts all and lists the first 100 of each, with the rest counted" |

### Story 9: applying

| AC | Held by |
|---|---|
| 9.1 | `spec/models/collection_import/apply_spec.rb`, "makes the account's locations the file's, keeping a renamed one's id and not writing an unchanged one" |
| 9.2 | `apply_spec`, "fills an empty account with the file's lots and locations and nothing else" |
| 9.3 | `apply_spec`, "leaves the account's locations as they were for a version 1 file, with the same ids and times"; `plan_spec`, "leaves a version 1 file's plan and fingerprint to the lots" |
| 9.4 | `apply_spec`, "applies a file whose only change is a location, changing no lot and clearing no working state"; `plan_spec`, "has something to change for a file whose only change is a location…"; `previews_spec`, "offers the apply, and stores the file, when the only change is a location" |
| 9.5, 9.6 | `spec/models/collection_import/round_trip_spec.rb`, "restores an export's locations by name, exactly spelled, into an empty account", "restores a changed set of locations from the file, and then has nothing to change", "previews the exported collection, locations and all, as nothing to change" |
| 9.7 | `apply_spec`, "writes nothing the second time, and the same file then previews as nothing to change" |
| 9.8 | `apply_spec`, "rolls everything back when a location can't be written after the lots were, keeping the upload" |
| 9.9 | `apply_spec`, "a location changed after the preview" (added, respelled, removed: stale) and "applies after a renamed, a removed and an unchanged location were each deleted and added again with the same spelling"; `plan_spec`, "#fingerprint"; `spec/requests/collection_imports_spec.rb`, "answers 409 with a fresh preview, locations included…" |
| 9.10 | `apply_spec`, "needs the confirmation only when it removes lots or locations"; `collection_imports_spec`, "asks for the confirmation when only locations are removed, and writes nothing without it"; `previews_spec`, "words the confirmation for the lots and the locations that would go", "words it for locations alone when no lot goes" |
| 9.11 | `apply_spec`, "removes a location without touching a lot" |
| 9.12 | `apply_spec`, "replaces 500 held locations with the file's 500 others, with no failure from the limit" |
| 9.13 | `apply_spec`, "touches only this account's locations"; `collection_imports_spec`, "shows nothing of another account's locations in any response" |
| 9.14 | `collection_imports_spec`, "adds the locations to the notice, with no final period", "names only the location parts that are not zero, but keeps the zero lot parts…", "says nothing about locations after a version 1 file" |
| 9.15 | `round_trip_spec`, "every valid example of the format": one example per file under `docs/export-format/examples/valid/` (see note 1); `previews_spec`, "previews each empty example, version 1 and version 2, in its own currency, as nothing to change" |
| 9.16 | Measured, below |
| 9.17 | `apply_spec`, "applies a file whose only change is a location, changing no lot and clearing no working state", "clears the working state when a lot is written, and leaves it for a change of view alone" |
| 9.18 | `collection_import_spec`, "reads a name in NFD as its NFC spelling…"; `locations_spec` (model), "matches a name in another case or form…"; `apply_spec`, "reads a name in NFD as its NFC spelling: unchanged against a held one, added as NFC without one, renamed when only the case differs"; `previews_spec`, "shows a name in NFD as its NFC spelling, matched to the held location" |

## Functional and non-functional requirements

| Requirement | Held by |
|---|---|
| FR-1 | `location_spec` (all), `db/migrate/20261021100001_create_locations.rb` (unique index on `[account_id, name_key]`, check constraints, cascading foreign key) |
| FR-2 | `locations_spec`, `spec/system/locations_spec.rb`; no collectible type is named: `git grep -i 'mtg\|scryfall'` over the location model, controllers, views and import files is empty |
| FR-3 | `collection_export_spec` (the profile, currency and lots are as version 1 wrote them) |
| FR-4 | `export_format_examples_spec`, `export_format_document_spec`, `rules_spec`, `name_parity_spec`; `v1.schema.json` and the version 1 examples are unchanged (`git diff` of them since the plan's base is empty) |
| FR-5 | `collection_import_spec`, `apply_spec`, `plan_spec`, `previews_spec`, `collection_imports_spec` |
| NFR, queries | `spec/requests/query_counts_spec.rb`, "keeps the locations page's queries independent of the number of locations"; `collection_exports_spec`, "runs as many queries for 30 locations as for 2" |
| NFR, statements | `apply_spec`, "writes the locations in as many statements for 150 changes of each kind as for one"; measured below (one statement in each of the three cases) |
| Reliability, migration | Rolled forward on the development and test databases; adds one table and nothing else (`git diff` of `db/schema.rb` since the plan's base shows only the `locations` table, its two check constraints, its index, its foreign key and the schema version) |

## Measurements (AC-9.16 and the NFR)

**Machine and method.** Apple M1, 16 GB, macOS 26.5.2, Ruby 4.0.7, this worktree's own development database (SQLite, WAL), as spec 028's measurements were taken. A throwaway runner script in the session scratchpad (never committed) seeded one set, 50,000 identities, entries and printings and four users, and wrote three version 2 files; everything was deleted afterwards (users, accounts, lots, locations, entries, identities, sets, printings, uploads and blobs all back to 0, checked with counts). The write transaction is the longest `transaction.active_record` duration seen while `CollectionImport::Apply#call` ran in process; the whole request is `curl`'s total time against a real `rails server` (development, port 3099) with a session and the form's token; RSS is `ps -o rss` of the Puma process before and after each request. Files: (a) 50,000 resolvable lots and 500 locations ("Place 1" to "Place 500", 13.5 MB) into an empty account; (b) the same lots with quantity 2 and the locations spelled "PLACE n", applied to an account holding the 50,000 lots at quantity 1 and the 500 locations as "Place n" (every row changed, every location renamed by case); (c) a file with no lots and `locations: []`, applied to 50,000 lots and 500 locations with the removal confirmed.

| Case | Write transaction (bar 4 s) | Statements written to `locations` (bar: at most 2) | Whole request, preview / apply (bar 30 s) | RSS growth, preview / apply (bar 500 MB) |
|---|---|---|---|---|
| (a) 50,000 lots, 500 locations, into an empty account | **2.42 s** | 1 (one upsert) | 4.83 s / 7.58 s (303) | +377 MB / +107 MB |
| (b) every row changed, every location renamed by case | **3.31 s** (margin 0.69 s) | 1 (one upsert; none deleted) | 5.34 s / 7.86 s (303) | +129 MB / +86 MB |
| (c) empty file against 50,000 lots and 500 locations | **0.91 s** | 1 (one delete) | 0.68 s / 0.90 s (303) | +20 MB / +9 MB |

Spec 028's own figures for the same cases without locations were transaction 2.39 s, 3.21 s and 0.93 s, whole request 6.72 s, 7.56 s and 0.91 s, and preview RSS growth +408 MB for (a): locations add about 0.03 s to 0.1 s to the transaction and nothing measurable to memory (the plan reads the upload no more often than 028 did). Every bar holds. Earlier in-process runs gave (a) 2.42 to 2.64 s and (b) 3.16 to 3.48 s, so the margin of (b) was never under 0.5 s. The first two runs of the script read the held locations through an association it had cached before holding them (so (c) removed none, and (b) saw the locations as added, with the same single upsert); the script was corrected to read fresh records, and the table is from the corrected runs.

**Round trip at this size.** After (a) was applied, the account's export (13,527,289 bytes, the same size as the file) equals the file but for `exported_at` and the order of the locations (the file listed them by number, the export lists them by comparison key then name), 50,000 lots and 500 locations.

**Pages with 500 locations.** The locations page: 0.027 to 0.040 s per request (222 KB of HTML), the same for an account with 50,000 lots and one with none. The export: 0.010 s for 500 locations and no lots (10,608 bytes); 0.53 to 0.57 s for 50,000 lots and 500 locations (13.5 MB).

**AC-1.13 and AC-1.9 by hand** (the account with 500 locations; `curl … &` twice with a session and the form's token, ten trials each, the account reset before each):

- Two adds of different names at 499 locations: every trial gave exactly one 303 and one 422 (`303/422` or `422/303`, never a 500), the 422 page said "You can have at most 500 locations.", and the account held 500.
- Two adds of one name (spelled "Same name n" and "same NAME n"): every trial gave one 303 and one 422, the 422 page said "You already have a location called “…”.", and the account held 2 (the seed and the one added).

## Screenshots (AC-5.5)

`screenshots/`, light and dark at 1280 px and 390 px, taken as spec 028's were: headless Firefox, the page's own HTML (copied from the rendered page) loaded into an iframe of that width, the element shot at its full height. `locations-empty-*`, `locations-names-*` (four names, one of 60 characters wrapping), `locations-error-*` (a refused duplicate, the typed text kept), `rename-*`, `removal-*`, `preview-locations-*` (a preview whose Locations section shows 1 added, 1 renamed, 0 unchanged, 2 removed) and `apply-form-*` (the apply form reading "Applying removes 1 lot (2 copies) and 2 locations…" and the checkbox "I understand this removes 1 lot and 2 locations"). Every one of the 28 files was checked for horizontal overflow by the probe (`scrollWidth <= innerWidth`, all true), and the 360px, 640px and 1200px frames are asserted in the system spec. A sample of the 390px error page, the 1280px preview and the dark apply form was looked at by the author.

## Documents, verified by reading

- **Format document, AC-7.1.** `docs/export-format/README.md` says `**Format version:** 2`; defines `locations` (a required list of `{ name }`, its character sets, normalisation on read, the 500 and 60 limits, "The same collection" comparing names exactly); lists the rule `duplicate_location` (line 404) and the `locations` Coverage rows (lines 363 to 368); keeps version 1's definitions (its schema and examples are byte-for-byte unchanged); its version history has the row `| 2 | 2026-10-21 | Locations: … |`. The sentence that putting a lot in a location will raise the version to 3 follows the table, in the paragraph "Two changes are already expected", not inside the row (the criterion's words "has a row … and the sentence" are met by the table and the paragraph under it).
- `CLAUDE.md`: the status paragraph, the "Export format" fact (version 2, `v2.schema.json`, `VERSIONS`, the Coverage line), the "Import preview" fact (the Locations section, `CollectionImport::Locations`, a location-only file is applicable) and a new fact "Locations (spec 029, ADR 0023)".
- `README.md` ("Your data"), `docs/releasing.md` (an upgrade note: one migration; exports are version 2 and an earlier release refuses them), `docs/roadmap.md` (item 9 done, item 10 raises the format to version 3, a decision-log row 34 that ruling 32 stands for the locations list).
- `docs/adr/0020-export-format.md` (Status line only), `docs/adr/0023-…md` (Accepted, 2026-10-21) and the index line of `docs/adr/README.md` (no longer "proposed").
- `docs/specs/README.md`: the 029 row (status, Plan cell) and the "Superseded by" cells of the 004, 009, 017, 022, 023, 025, 026 and 028 rows, in both directions with spec 029's own Supersedes table. No shipped spec is edited (`git diff` of every `docs/specs/*/spec.md` since the plan's base is empty).
- `docs/design-system/`: `components/Locations.md` (new), `AppHeader.md`, `MorePage.md`, `ImportPreview.md` and the README (the app additions line for spec 029, the navigation note). `.rubocop.yml` needed no change.
- The apply, the preview's wording and the area docs: the data portability and collection-and-lots area docs do not exist yet; `distill-feature` writes them, and `CLAUDE.md` carries the line until then.

## Notes the plan asked for

1. **AC-9.15 and NFD.** The valid example `locations-nfd.json` holds a name in NFD, which is well-formed, but the export writes NFC. As ruled on 2026-10-21 (spec 1.3.2), the round-trip example compares each location name after it passes through `Location::Name.normalise`; every other example is compared as written. This is the one deviation from reading AC-9.15 literally, ruled.
2. **Header targets under 44px.** Measured at 640px and 1200px (a probe, not committed): the header's four navigation links are 57px tall (89.2, 69.1, 55.8 and 86.2px wide); the account avatar (`summary.c-avatar`) is 34 by 34px and the account menu's three links ("Export collection", "Import collection", "Sign out") are 200 by 36px. They are not changed by this feature (spec 029 raises only the Locations link and the back button to 44px, as the plan says); they are the design system's existing sizes.
3. **640px header, AC-5.1.** Measured at a 640px iframe: the nav runs from x=202 to x=514 (312.2px), the four links share one line (all at the same top, y=8), the account actions begin at x=551, so there is a 37px gap between the nav and the account menu, and the page's `scrollWidth` (625) is not wider than the frame. Phase 1's system example holds the same (`[4, 1, true, true]`). At 1200px the nav is the same width and the gap is 597px. (Phase 1 recorded only that the fit passed; these are measured now.)
4. **Run time of the parity example.** `spec/models/location/name_parity_spec.rb`: 19.92 s for the file's three examples, run alone.

## Plan test bugs fixed during execution

Found by running the plan's own code, each fixed in its phase with the test that shows it:

- Phase 1: the admin pages example needed the admin's sign-in session (the plan's example did not establish it); the focus ring is on the `c-input` label wrapper, not the input, so the focus example reads the wrapper; `.c-locations .c-input` and the header's back button needed an extra 44px floor in `additions.css` (the plan's CSS left the fields and the back button under 44px on pointer devices).
- Phase 2: `schema_version` returns 1 when the file is not an object (the plan's code did not), so the reader judges it by version 1's schema.
- Phase 3: the reference example `collection-v2.json` (a version 2 counterpart of `collection.json` with locations) was added so the round trip and the examples loop have a version 2 file with lots.

## Deviations from the plan

- The measurement runner reads the held locations through fresh records (a first run read an association the script had cached, so a removal looked like "nothing"); not an application fault, and the table is from the corrected runner.
- The screenshots are taken with a probe spec in the scratchpad, as 028's were taken with a throwaway script; the probe is not committed.
- Phase 6's commits are three (the design-system documents, the other documents, the verification with the screenshots) rather than one.

## Deferred / follow-ups

- ~~`ExportFormat::Rules` validates all locations before reporting `maxItems`.~~ Fixed after the implementation review (M1, below).
- The area docs for collection and lots and for data portability are not written yet (slices #108 and #109); `distill-feature` carries spec 029 into them.
- The maintainer's own check of a real export restored on a fresh instance (spec 028's release check) now also covers locations.

## bin/ci

Run on 2026-10-21 in this worktree (Apple M1, light appearance, ImageMagick and libvips installed) at commit `06e1542` plus the uncommitted `Gemfile.lock` change (not part of this feature), before this file was committed. Every step passed: Setup, RuboCop, Brakeman, bundler-audit and importmap audit, then RSpec. Verbatim final lines:

```
1893 examples, 0 failures, 1 pending

Randomized with seed 6325

✅ Tests: RSpec passed in 2m28.44s
✅ Continuous Integration passed in 2m42.39s
```

The one pending example is `art_agreement_spec`, which needs `COLLECTOR_ART_AGREEMENT` (as in spec 028's run). `git diff` of `db/schema.rb` since the plan's base shows only the `locations` table (schema version 2026_10_21_100001).

## Implementation review

SPEC-ALIGNED (independent Sonnet review 2026-10-21, after fixes)

The review (sdd-review Mode B, spec 029 v1.3.2 at `74afc27`) said NEEDS FIXES: 0 critical, 1 major, 3 minor. Every AC, FR and error scenario traced to code and a test; its own `bin/rspec` run matched the 1893 examples above. Each finding is fixed in its own commit:

| Finding | Fix commit |
|---|---|
| **M1** A version 2 file with a very long `locations` list was validated and case-folded in full before `maxItems` was reported. | `0f3de14` fix(export-format): a list over 500 is reported at once (`maxItems` at `/locations`) and only its first 500 items are checked; a refused list lists no `duplicate_location`. A list at or under 500, and version 1, give the problems they gave. Specs: nothing past the limit is validated or passed to `Location::Name.key`, the first items' problems still show, the limit equals the schema's `maxItems` and `Location::MAX_PER_ACCOUNT`. |
| **m1** `save!`, `update!` and `create!` didn't turn a unique-index race into a refusal. | `217c1e4` fix(locations): `save!` raises `RecordInvalid` with the same message `save` gives (spec: `save!` on a new and a renamed location). |
| **m2** Literal 44px in the new CSS. | `22f4464` fix(design-system): no token exists, so `additions.css` declares `--touch-floor` once and the Locations rules use it; `components/Locations.md` says why. The 560px matches `.c-confirm`, as the review allowed. |
| **m3** The roadmap said "Done" before the merge. | `793809a` docs(roadmap): "Built 2026-10-21, done when its pull request merges". |

### M1 measurements

`ExportFormat::Rules.problems` on a version 2 file of 500,000 `{"name":"L<n>"}` locations (9,389,751 bytes), one `bin/rails runner` per row in the test environment, no database, before = `74afc27`'s `rules.rb`, after = `0f3de14` (scratchpad `many_locations_rules.rb`, Apple M1):

| | Time | RSS before → after the call | Peak RSS of the process |
|---|---|---|---|
| Before | 8.62 s | 274 → 2,176 MB (+1.9 GB) | 2,282 MB |
| After | 0.38 s | 268 → 335 MB (+67 MB) | 351 MB |
| 500 locations (reference) | 0.06 s | 138 → 148 MB | 156 MB |

Both give the one problem `maxItems` at `/locations`. What remains after the fix is the parse of the file itself (spec 025 decision 13). The review measured +1.6 GB with json_schemer alone; this run measured the whole call.

### bin/ci

Run on 2026-10-21 in this worktree at `793809a` plus the uncommitted `Gemfile.lock` change. Every step passed; final lines:

```
1898 examples, 0 failures, 1 pending

✅ Tests: RSpec passed in 2m34.29s
✅ Continuous Integration passed in 2m45.16s
```

The one pending example is `art_agreement_spec` (needs `COLLECTOR_ART_AGREEMENT`).

### Not verified by the review

AC-9.16's timings and the screenshots (taken from the sections above), AC-1.13 as a true concurrent race, and whether other regexp engines accept the schema's `\p{…}` pattern (the format document states the caveat). The review's question 3 (a second, explicit character list in the format document) is left to the maintainer.
