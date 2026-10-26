# Data portability

How a collector's collection leaves and enters Collector: the export format, the export download, the import preview and the apply, and how they relate to an instance backup. This is the current truth; the specs it distils record what each feature promised when it shipped (see Sources and the [specs index](../specs/README.md)). The format itself is defined by [`docs/export-format/README.md`](../export-format/README.md) with `v1.schema.json`, `v2.schema.json`, `v3.schema.json` and `examples/` beside it; this doc points to it and does not restate the schema.

## Scope

**Covers:**

- The export format's rules for the app: which versions the app reads and writes, how it keeps its schema copies, the rules a schema can't state, and the coverage guard (`ExportFormat::Rules`, `app/models/export_format/v<N>.schema.json`, `spec/export_format_document_spec.rb`, `spec/export_format_examples_spec.rb`; spec 017; ADRs 0020, 0021, 0023, 0025).
- The export: `CollectionExport`, `GET /collection/export`, `Collections::ExportsController` (spec 022; spec 029 AC-6.1–AC-6.8; spec 032 Story 8).
- The import preview: `CollectionImport`, `CollectionImport::Locations`, `Collections::ImportPreviewsController`, the views under `app/views/collections/import_previews/` (spec 025; spec 029 Story 8; spec 032 Story 10).
- The apply: `CollectionImport::Plan`, `CollectionImport::Apply`, `CollectionImport::LocationChanges`, `CollectionImport::WorkingState`, `Collections::ImportsController` (spec 028; spec 029 Story 9; spec 032 Story 11; ADR 0022 as far as the apply reads the stored upload).
- That the number-entry list and the scanner sitting are left out of the export (spec 026 decision 6, FR-5), and the guidance on when to use an export and when a backup (spec 030 decision 11).

**Neighbours:**

- The lot as the unit of ownership (ADR 0019), `Lot`, and locations as a feature (`Location`, `Location::Name`, `/locations`, spec 029 apart from its export and import parts) and a lot's place in the collection (`Lot#location`, Move copies, `Location::Holdings`, spec 032 apart from the export, preview and apply) are **collection and lots** (no area doc yet).
- The stored upload's retention: `ImportUpload`'s expiry, the sweep, the orphan rule, the Active Storage routes' gate and the 40 MB request body caps in Puma, Thruster and kamal-proxy are **release and deploy** (spec 028 decision 9; spec 025 decision 6; ADR 0022). This doc uses only that an upload is stored for an hour, one per account, and is gone when it is applied or refused.
- Backup and restore of an instance (`backup:create`, `backup:restore`, `docs/backup-restore.md`) is **release and deploy** (spec 030).
- Catalog lookups the preview makes (`Catalog.collecting`, `Catalog::Entry`) are **catalog core** (no area doc yet).

## Glossary

- **File / export:** one JSON document in the `collector-export` format that describes one account's collection at one moment (spec 017 FR-1).
- **Well-formed / resolvable:** well-formed depends on the file alone; resolvable on the file against one instance's catalog (spec 017 Glossary; format document).
- **Entry identity / lot identity:** collectible type and source id; and entry identity, finish, condition, price paid and, from version 3, the lot's location by comparison key: six values, the sixth `null` for versions 1 and 2 and for a lot in none (spec 017 Glossary; ADR 0019; spec 032 FR-3, ADR 0025).
- **The same collection:** the format's equality of two files: profile, currency, lots as sets (with quantity and both times), from version 2 locations as sets of names compared as written, and from version 3 each lot's `location` compared as written too (spec 017 FR-7; spec 029 decision 9; spec 032 AC-9.6).
- **Row:** one element of the file's `lots`, numbered from 1; row N is `/lots/N-1` (spec 025 Terms).
- **Problem row:** a row that can't be applied, for any reason in the row-problem table below (spec 025 Terms).
- **Held lot:** a lot in the collector's collection (spec 025 Terms).
- **Outcome:** added, changed, unchanged, held by a problem row or removed, for lots; added, renamed, unchanged or removed, for locations (spec 025 decision 1; spec 029 decision 10).
- **Plan:** what applying the file to the collection as it is now would do (spec 028 Terms; `CollectionImport::Plan`).
- **Fingerprint:** a SHA-256 digest of the stored file's checksum and the plan; stored with the upload and carried in the apply form (spec 028 Terms, decision 2).
- **Nothing to change:** a plan with no added, changed or removed lot, no added, renamed or removed location and no view change (spec 028 Terms, decision 12; spec 029 decision 10).
- **Comparison key:** the Unicode full case folding of a location's name after normalisation; a location's identity in a file and in an account (spec 029 decision 5, ADR 0023).
- **Stored upload:** the previewed file kept briefly so that it can be applied (spec 028 decision 1).

## Invariants

- **The format document is the format's definition.** The app's schema copies are byte-identical to the ones in `docs/export-format/` (one per version), and the suite fails if they differ (ADR 0021; spec 029 AC-7.6).
- **No internal id appears in a file.** A lot points at its entry by collectible type and source id, a location is its name, and a file carries no account or user id (spec 017 FR-1, FR-6, AC-1.4; spec 029 AC-6.5).
- **The meaning of a released version never changes.** A version rises when an older reader would misread a file or lose collector-owned data; a new field of collector-owned data raises it, an information-only field doesn't (spec 017 FR-8, decision 14; ADR 0020; ADR 0023). Version 2 added locations; version 3 adds each lot's `location` (spec 032, ADR 0025).
- **A new table with `account_id` or `user_id`, or a new column on `accounts`, `lots`, `users` or `locations`, fails the suite** until the format document's Coverage tables list it (spec 017 FR-9, AC-3.4, AC-3.5; ADR 0020).
- **The core names no collectible.** The export's, the preview's and the apply's code contain neither `MTG` nor `Scryfall`; the export never asks the catalog registry about a type, so a lot of a type the instance no longer has still exports (spec 022 FR-6, decision 4; spec 025 FR-9; spec 028 FR-8; spec 029 FR-2). Checked by `spec/collection_export_core_spec.rb`, `spec/collection_import_core_spec.rb`, `spec/import_apply_core_spec.rb`; the last also lists the location files.
- **Everything runs through `Current.account`.** No parameter names an account, an upload or a lot; the one parameter besides the confirmation is the fingerprint (spec 022 Security; spec 025 FR-5; spec 028 FR-5, AC-4.2). Another account's data never appears in a response (spec 022 AC-2.1; spec 025 AC-4.1; spec 028 AC-4.1).
- **An export is built in the request and stores nothing.** No job, no row, no file, no cache entry (spec 022 decision 1, FR-3).
- **The preview never writes a lot, user, location or account and never enqueues a job.** The one thing it may write is the account's stored upload, and only for a file that can be applied and has something to change (spec 025 FR-6 as superseded by spec 028 decision 10, AC-1.11; spec 029 AC-8.8).
- **A file's content is never logged or echoed.** A JSON parse error's message is dropped, the `export_file` field is in `filter_parameters`, and the apply logs an error's class and backtrace but not its message (spec 025 FR-6; spec 028 FR-6).
- **Responses of the export, the preview and the apply carry `Cache-Control: no-store`** (spec 022 AC-1.1; spec 025 Security; spec 028 FR-6).
- **Applying is all or nothing,** in one write transaction; it replaces the collection and the locations with the file's, never merges, and applies a file only when it has no problem row (spec 025 decisions 1, 2; spec 028 decisions 3–5; spec 029 decision 11).
- **What is applied is what was previewed.** The form's, the stored and the recomputed fingerprints must be equal, or nothing is written (spec 028 decision 2).
- **Applying the same file twice leaves the collection as the first left it:** the second is refused as nothing to change and writes and clears nothing (spec 028 decision 12, AC-2.2; spec 029 AC-9.7).
- **Applying never changes the collector's name or email address,** only `collection_view` and only to a view the instance knows (spec 025 decision 4; spec 028 decision 5).
- **A changed lot and a renamed location keep their ids,** and an unchanged one isn't written, not even its `updated_at` (spec 028 FR-9, decision 5; spec 029 decision 10).
- **Removing a location never changes a lot** (spec 029 decision 3, AC-9.11) and a location that holds a lot can't be removed, so an apply deletes the lots of a location it removes before the location (spec 032 decision 3, AC-11.6; ADR 0025).
- **An older file's lots are unplaced.** A version 1 or 2 file says nothing about a place, so its lots are read as in none, match only unplaced held lots, and the preview says so (spec 032 decision 7, AC-10.4; ADR 0025).
- **Working state is left out of the export and cleared by an apply that writes a lot:** the number-entry list, the scanner sitting, bulk selections and bulk removals' undo (spec 026 decision 6, FR-5; spec 028 decision 7; spec 029 decision 11, AC-9.17).
- **Only a signed-in collector reaches any of these pages;** a signed-out request is sent to sign in and the reader isn't called (spec 025 AC-4.2; spec 028 AC-4.3). Signing in from the export lands on the collection, not on the file (spec 022 decision 9).

## States and transitions

### The export (`CollectionExport`)

`GET /collection/export` (route `resource :export, only: :show, format: false`) sends the file as an attachment named `collector-export-<UTC date>.json`, type `application/json` (spec 022 decisions 2, 3, AC-1.1). It always writes the newest version, 3, with `locations` present and empty for an account with none and every lot's `location` present (`null` for a lot in none, never an empty string); it doesn't fall back to an older version (spec 029 decision 2, AC-6.1, AC-6.2; spec 032 AC-8.1, AC-8.6). Contents:

- `profile` and `currency` (the instance's `COLLECTOR_CURRENCY`, default `USD`; `generator` is left out because the app doesn't know its version) (spec 022 decisions 4, 5).
- `locations`: names only, ordered by comparison key then name in code-point order, read in one query (spec 029 decision 2, FR-3).
- `lots`: read in one statement joining `lots`, `catalog_entries`, `catalog_sets` and `locations` (left join, so each lot's `location` is its name from the same statement), ordered by lot id; the writer formats times (UTC, fraction dropped, not rounded) and prices (exact, two places) itself (spec 022 decisions 4, 8, AC-1.4).

The lots and the locations are two reads, and a rename or removal of a location between them would leave a lot naming a location the list lacks, so the reads are repeated up to `TRIES` (3) times and then `CollectionExport::Unsettled` is raised (spec 032 AC-8.3, plan review M5). The number of queries doesn't depend on the number of lots or locations (spec 022 AC-1.8, FR-2; spec 032 NFR). Two exports of an unchanged collection are identical apart from `exported_at` (spec 022 AC-1.6; spec 029 AC-6.6). Nothing of a scanner sitting, a number-entry list or any other working state is in it (spec 022 AC-2.2, decision 7; spec 026 decision 6).

### Reading a file (`CollectionImport`, `ExportFormat::Rules`)

The checks run in this order and the first that applies refuses the whole file (preview: 422, the upload page with the reason and no rows) (spec 025 decision 10, AC-3.1; spec 029 decision 10):

| # | The file | Rule | Reason shown (summary) |
|---|---|---|---|
| 1 | No file, empty, or not an upload | `no_file` | "Choose an export file to preview." |
| 2 | Over `MAX_BYTES`, refused before parsing | `too_large` | larger than 32 MB |
| 3 | Not UTF-8, not JSON, a byte order mark, or an object with a key twice | `not_utf8`, `not_json` | "isn't readable JSON" |
| 4 | Not an object; `format` missing or not `collector-export` | `type`, `required`, `const` | "isn't a Collector export" |
| 5 | `format_version` missing, or not a whole number of at least 1 | `required`, `const` | "doesn't say which version" |
| 6 | `format_version` higher than 3 (`4` or `4.0`) | `newer_version` | "written by a newer version … This instance reads version 3." |
| 7 | A schema problem outside `/lots/<row>` (header, profile, currency form, `lots`, and from version 2 `locations`, including `duplicate_location` and `maxItems`), or `exported_at` not a real moment; a version 2 name whose NFC form is over 60 code points | the keyword, `duplicate_location`, `not_a_time`, `maxLength` | "isn't a well-formed export: `<field>` …", naming the first such field in document order |
| 8 | `currency` not the instance's | `other_currency` | "This file's prices are in EUR. This instance uses USD." |

The version is read before the schema, so a newer file is refused as newer, not as malformed; a file with a missing or unknown version is judged by version 1's schema, which names the version (spec 025 decision 10, AC-3.2; format document, Well-formed). A version `1.0` or `2.0` is read as 1 or 2 (spec 025 AC-3.2). The content is judged, never the declared type or name (spec 025 decision 6, AC-3.5). The app checks the lots one at a time against the schema's `$defs/lot`, and the rest of the file with its lots left empty, to bound memory; a schema that moves the lot elsewhere changes this (ADR 0021 amendment). A version 2 or 3 `locations` over 500 is reported at once and only its first 500 are checked (spec 029 review M1; `ExportFormat::Rules.locations_over_limit?`).

**Row problems** (a well-formed file whose row can't be applied). A row that isn't well-formed is not checked against the catalog; a well-formed row is checked in this order: type, then entry (and condition), then finish and condition (spec 025 decision 9, AC-2.4, AC-2.5; spec 028 1.3.4):

| Problem | Rule | Reason shown |
|---|---|---|
| Row not an object; required field missing; wrong type, form or range | `type`, `required`, schema keywords | "This row isn't a lot"; "`<field>` is missing"; "`<field>` isn't valid" |
| A time that isn't a real moment | `not_a_time` | "`<field>` isn't a real moment" |
| `changed_at` before `added_at` | `changed_before_added` | "changed_at is earlier than added_at" |
| Same identity as an earlier row | `duplicate_lot` | "Same card, finish, condition and price as row M" for versions 1 and 2; "…, price and location as row M" for version 3 (spec 032 AC-9.5) |
| From version 3, a lot's location the file's `locations` don't list (by comparison key) | `unknown_location` | "Its location “Box” isn't one of the file's locations." (spec 032 AC-10.3) |
| Collectible type the instance doesn't have | `unknown_type` | "This instance doesn't collect `<type>`" |
| Entry not in the catalog (retired entries are in it) | `not_in_catalog` | "Not in this instance's catalog" |
| Finish the entry doesn't list | `finish_not_listed` | "This printing doesn't come in `<finish>`" |
| Condition not one of the type's | `condition_unknown` | "`<condition>` isn't a condition this instance knows" |
| Price over `MAX_PRICE_CENTS` in cents | `price_too_large` | "price_paid is too large to record" |

A row's identity can be read when its entry type and source id are non-blank strings and its finish, condition, price and (version 3) location pass the schema; a row that fails `unknown_location` keeps a readable identity, so the held lot it matches is held, not removed (spec 032 AC-10.3); a row whose identity can't be read matches no lot (spec 025 decision 1). Descriptive fields never matter: when they disagree with the catalog the id wins and the row is fine; a retired entry is fine (spec 025 AC-2.2, AC-2.3; format document). Entries are looked up by (`collectible_type`, `external_key`), retired or not, in a number of statements that doesn't grow with the rows (spec 025 FR-3, FR-4).

### Outcomes of a plan

For lots, comparing rows with held lots by identity (six values; a held lot in a location has its location's key as the sixth, so a version 1 or 2 file's rows, whose sixth is `null`, match unplaced held lots only: a placed lot is removed and its row added, or changed against an unplaced twin) (spec 032 AC-10.2, AC-10.4, AC-10.5); each held lot has exactly one outcome, taken in this order (spec 025 decision 1, AC-1.2, AC-1.6, AC-1.11):

| Outcome | When |
|---|---|
| Added | a row that isn't a problem row whose identity no held lot has |
| Changed | such a row whose identity a held lot has, with another quantity, `added_at` or `changed_at` (compared to the second; `4.0` is `4`) |
| Unchanged | the same, with equal quantity and times |
| Held by a problem row | a held lot no good row matches, whose identity a problem row has; it is never removed |
| Removed | any other held lot |

For locations in a version 2 or 3 file, held locations become the file's, matched by comparison key after each file name is normalised on read (spec 029 decision 10, AC-8.2, AC-9.18):

| Outcome | When | Applying does |
|---|---|---|
| Added | the file has a key no held location has | creates it |
| Renamed | a held location has the key but not exactly the name ("box" and "Box") | respells it; its id stays |
| Unchanged | a held location has exactly the name | writes nothing |
| Removed | a held location whose key no file location has | deletes it; no lot changes |

A version 1 file says nothing about locations: they stay, the preview says "This file was written before locations existed, so your locations would stay as they are.", and its fingerprint holds nothing of them (spec 029 decision 10, AC-8.4, AC-9.3). A version 1 or 2 file also says "This file was written before lots could be in a location, so its lots would be in none." (spec 032 AC-10.4).

The profile: `collection_view` changes only to the other of `User::COLLECTION_VIEWS` (`grid`, `table`); a view the instance doesn't know is ignored, no line, no problem; a differing name or email address is shown as information and never applied (spec 025 decision 4, AC-1.7).

### The preview page

`GET /collection/import_preview/new` is the upload page; `POST /collection/import_preview` renders the preview (200) or the upload page with the reason (422); both forms are submitted without Turbo Drive (spec 025 decision 8, AC-1.1). The preview shows, in order: the file (export time, row count, currency); whether it can be applied; the "catalog not loaded" notice for the types the file names; the counts of the lot outcomes; the apply form (below); the profile notes; removed lots, each ending "in <location>" when it was in one; the Locations section (version 2 or 3) or the version 1 sentence; problem rows, a row ending "in <location>" with the file's spelling; problem rows with counts by reason (spec 025 decision 9; spec 028 AC-7.1; spec 029 decision 10). Each list (problem rows, removed lots, renamed locations, removed locations) shows its first `LIST_LIMIT` entries then "and N more"; the counts cover all (spec 025 decision 11, AC-2.8; spec 029 AC-8.9). A file with problem rows says it can't be applied and offers no apply (spec 025 decision 2; spec 028 decision 4).

### The stored upload and the apply form

A preview stores the file only when it can be applied and has something to change; a refused file, a file with problem rows and a file with nothing to change store nothing and leave an earlier stored upload alone (spec 028 decision 1, AC-1.11, AC-5.2). A new storing preview replaces the account's one stored upload, with the plan's fingerprint (spec 028 decision 1; ADR 0022). The apply form carries no file field, only the fingerprint and, when the plan removes a lot or a location, a required checkbox "I understand this removes N lots and M locations" (the part that applies), after a link to download the current collection (spec 028 decisions 6, 11, AC-1.1; spec 029 AC-9.10). If storing fails, the preview shows its counts, no apply, and says the file couldn't be kept (spec 028 Error Scenarios).

### The apply (`POST /collection/import`)

Everything that can be done before the lock (reading the stored file, parsing, judging, resolving, building the rows) is done first; then one write transaction re-checks and writes (spec 028 decision 3, FR-2). Checks run in this order and the first that applies decides the response (spec 028 decision 13, AC-3.6):

| # | Situation | Response |
|---|---|---|
| 1 | No stored upload, or it is past its expiry, or its file can't be read | 422, upload page: "Preview the file again." / "Your preview has expired. Choose the file again."; an expired or unreadable upload is removed (AC-3.3, AC-2.5, AC-5.6) |
| 2 | The stored file is now refused or has problem rows (the catalog changed) | 422 with the preview's reasons; the upload is removed (AC-3.4, decision 4) |
| 3 | The plan has nothing to change | 422 "This file has nothing to change"; nothing written or cleared; the upload is removed (decision 12, AC-2.2) |
| 4 | The form's, stored and recomputed fingerprints aren't all equal | 409 with a fresh preview of the stored file and a new fingerprint (AC-3.1, AC-3.2) |
| 5 | The plan removes a lot or location and the box isn't checked | 422 "Confirm the removal to apply this file"; the upload stays (AC-3.5, AC-9.10) |
| 6 | Otherwise | writes, then 303 to the collection with the notice |

An exception in the transaction rolls everything back: 500 with a page saying nothing was changed, and the upload stays so the collector can try again (AC-2.1, AC-9.8). Two requests together: one writes, the other gets 422 or 409, never 500 (AC-2.3).

The write: removed lots are deleted; added and changed rows go in one multi-row `INSERT .. ON CONFLICT` per `BATCH_SIZE` (`Apply#upsert_lots!`, values through `?` placeholders and `sanitize_sql_array`, not `Lot.upsert_all`, whose per-value type casting took 2.6 of the 4 seconds of an apply that replaces 50,000 lots; maintainer's ruling 2026-10-24, spec 032 Phase 8) on the lot identity (`account_id`, `catalog_entry_id`, `lot_key`), setting quantity and both times, so a changed lot keeps its id. The order is: delete the removed lots (the lots of a removed location among them, so the foreign key never fires); write the locations (removed ones deleted first, then one upsert on `account_id` and `name_key` adds new and respells renamed); read the account's locations once (at most 500 rows); then upsert the lots with their `location_id` and a `lot_key` that ends in it; the working state is cleared only when a lot is written; then `collection_view` (spec 032 AC-11.1, AC-11.5, AC-11.6, research R3) (spec 028 decision 5, FR-3, FR-4, FR-9; spec 029 decision 11, FR-5). The bulk statements skip `Lot`'s and `Location`'s validations on purpose, because the reader already checked each row; specs check the written rows against the models (spec 028 FR-3, AC-2.4; spec 029 AC-9.15). Afterwards the upload's record is removed in the transaction and its blob released after it (spec 028 FR-2, decision 9; ADR 0022). The notice is "Imported: N lots added, M changed, K removed", with "; 2 locations added, 1 renamed, 1 removed" for a version 2 file that changes locations (zero parts left out) and no final period (spec 028 decision 11; spec 029 AC-9.14).

### The fingerprint

It covers the stored file's checksum; the row number and outcome of every added and changed row; for every changed and removed lot its id, quantity, `created_at` and `updated_at` at full precision and its place's comparison key (so a lot moved between preview and apply makes the preview stale) (spec 032 AC-11.7); the view change; and, for a version 2 file, the names of added locations, the held and file names of renamed ones and the names of removed ones, with no ids. So a lot or location added, removed, edited or respelled between preview and apply, a catalog change that makes a row stop resolving, or another preview replacing the file, all change it; a location deleted and added again with the same spelling doesn't (spec 028 decision 2, AC-3.7; spec 029 decision 11, AC-9.9; full precision: spec 028 P2).

### Export or backup

An export is one collector's collection (profile, currency, locations, lots), made by the collector, restorable into any instance of a release that reads its version, and replaces that collector's lots and locations. A backup is the whole instance's primary database, made by the operator, restorable onto a fresh instance of the same or a newer release. Neither replaces the other; the 1.0 test asks for an export restored into a fresh instance, and the backup is the operator's safety. `README.md`'s "Your data" and "Export or backup?" carry the table (spec 030 decision 11, AC-6.1). A backup holds no Active Storage file; a restore tolerates a missing stored upload, and an apply then answers "Preview the file again." (spec 030 Active Storage row; spec 028 error scenario for a lost file). The backup restore refuses an export file and points to **Import collection** (spec 030 AC-3.3).

## Named constants

| Name | Value | Defined in | Why this value | Source |
|---|---|---|---|---|
| `CollectionExport::FORMAT` | `collector-export` | `app/models/collection_export.rb` | The fixed name a reader checks | spec 017 FR-2 |
| `CollectionExport::FORMAT_VERSION` | 3 | `app/models/collection_export.rb` | The export always writes the newest version | spec 029 decision 2 |
| `ExportFormat::Rules::VERSIONS` | `[1, 2, 3]` | `app/models/export_format/rules.rb` | The versions the preview and apply read, each against its own schema; `VERSION` is the newest | spec 029 decision 10; ADR 0021, 0023 |
| `ExportFormat::Rules::RULES` | `not_utf8 not_json not_a_time changed_before_added duplicate_lot duplicate_location unknown_location` | `app/models/export_format/rules.rb` | The rules a schema can't state, plus the two that apply before one can | spec 017 FR-1, FR-2, FR-5; spec 025 decision 5; spec 029 decision 9; spec 032 AC-9.4 |
| `ExportFormat::Rules::MAX_LOCATIONS` | 500 (= `Location::MAX_PER_ACCOUNT`) | `app/models/export_format/rules.rb` | Equals `v2.schema.json`'s and `v3.schema.json`'s `maxItems` for `locations`; a spec keeps them equal | spec 029 decision 7 |
| `Location::Name::MAX_LENGTH` | 60 code points | `app/models/location/name.rb` | The name's length in the model, the schema and the document | spec 029 decisions 5, 9 |
| `CollectionImport::MAX_BYTES` | 32,000,000 | `app/models/collection_import.rb` | Refused before parsing; a 50,000-lot export is about 16 MB; the servers refuse a body over 40 MB in front of it | spec 025 decision 6 |
| `CollectionImport::LIST_LIMIT` | 100 | `app/models/collection_import.rb` | Entries shown per list before "and N more" | spec 025 decision 11 |
| `CollectionImport::BATCH_SIZE` | 1,000 | `app/models/collection_import.rb` | Entries read and rows written per statement, below SQLite's limit on bound values | spec 025 FR-4; spec 028 FR-4 |
| `CollectionImport::MAX_PRICE_CENTS` | 9,223,372,036,854,775,807 | `app/models/collection_import.rb` | The largest price the lots table's integer column holds; a bigger one is a problem row | spec 028 1.3.4 |
| `User::COLLECTION_VIEWS` | `grid`, `table` | `app/models/user.rb` | The views a file's `collection_view` may change the collector's to | spec 025 decision 4 |
| Export file name | `collector-export-YYYY-MM-DD.json` | `CollectionExport#filename` | The UTC date of `exported_at` | spec 022 decision 3 |
| `CollectionExport::TRIES` | 3 | `app/models/collection_export.rb` | Reads of the lots and the locations repeated when a location changed between them, then `Unsettled` | spec 032 plan review M5 |
| `Location::Holdings::LISTED` | 100 | `app/models/location/holdings.rb` | Lots listed on the page that refuses a removal, as many as the preview lists (collection and lots; here for the shared limit) | spec 032 P1 |
| Stored upload retention | 1 hour; one per account; at most `MAX_BYTES` | `ImportUpload::EXPIRES_IN` (defined and explained in release and deploy) | The apply treats an upload past it as expired | spec 028 decision 9; ADR 0022 |

Measured bars, not constants (recorded in each spec's `verification.md`): export of 50,000 lots under 10 seconds and 300 MB growth (spec 022 AC-1.9); preview of 50,000 rows under 30 seconds and 500 MB (spec 025 decisions 12, 13, AC-1.10); apply of 50,000 rows under 30 seconds and 500 MB with the write transaction under 4 seconds, below SQLite's 5-second busy timeout (spec 028 decision 3, AC-1.10; spec 029 AC-9.16; spec 032 AC-11.12, whose numbers and the one case near the bar are in its `verification.md`).

## Decisions not in an ADR

- **Written in the request, not a job,** for the export and the apply; a job with a stored, expiring file replaces the export if 50,000 lots exceeds 10 seconds or 300 MB or a proxy times out (maintainer, 2026-10-14; spec 022 decision 1). For the apply, a missed bar needs the maintainer's ruling on a fallback (maintainer, 2026-10-20; spec 028 decision 3).
- **Applying replaces the collection;** merging was not chosen (maintainer, 2026-10-15; spec 025 decision 1).
- **A file with a problem row can't be applied, in part or otherwise** (spec 025 decision 2; spec 028 decision 4).
- **A file in another currency is refused,** even one with no lots, until currency is per account (#64) (spec 025 decision 3).
- **Only `collection_view` is taken from the profile** (spec 025 decision 4).
- **"Export collection" and "Import collection" are the first two items of the account menu and rows on More,** not in the main navigation; "Locations" is in the header and More (spec 022 decision 6; spec 025 decisions 7, 14; spec 029 decision 8). The More page's rows are Signed in as, Locations, Export collection, Import collection, Add by number, then admin links, then Sign out (`app/views/mores/show.html.erb`).
- **The export link is outside Turbo Drive and never prefetched** (it would build the file), and has no `download` attribute (spec 022 decision 6).
- **Signing in from the export lands on the collection** (spec 022 decision 9).
- **`generator` is left out** until the app knows its version; adding it later is information only (spec 022 decision 5).
- **Long lists show their first 100** (maintainer, 2026-10-15; spec 025 decision 11).
- **The app's rules use `json_schemer` and a byte-identical schema copy;** hand-written lot checks proved against the schema are the fallback if the time bar is missed, through an ADR that supersedes ADR 0021 (ADR 0021).
- **One-click apply from a stored upload,** with a confirmation for a removal and the export one click away; no undo (maintainer, 2026-10-20; spec 028 decisions 1, 6).
- **An apply with nothing to change is refused,** and a view-only or location-only apply clears no working state (maintainer, 2026-10-20; spec 028 decisions 7, 12; spec 029 decision 11, AC-9.17).
- **A price too large for the cents column is a problem row,** superseding spec 025 decision 9 in that point (maintainer, 2026-10-21; spec 028 1.3.4).
- **Locations in a file are normalised on read** (NFC, trimmed, collapsed) and matched by comparison key, while "the same collection" compares names as written; a name whose NFC form exceeds 60 code points refuses the file (maintainer, 2026-10-20; spec 029 decisions 9, 10; ADR 0023).
- **A file's locations replace the held ones by name;** a version 1 file leaves them alone (spec 029 decision 10).
- **A lot's location is part of its identity** (the same printing in two places is two lots), and the place is in `lot_key` as the location's id, so a rename keeps every key (maintainer, 2026-10-23; spec 032 decisions 1, 3, 7; ADR 0025). An older file's lots are read as unplaced and applying one needs the removal confirmation when it would unplace lots (spec 032 decision 7).
- **Version 3's "same collection" compares a lot's location as written,** while the reader's matching and `duplicate_lot` use the comparison key (spec 032 AC-9.6).
- **The number-entry list and the scanner sitting are working state,** left out of the export (spec 026 decision 6).

**Accepted limits and open issues:**

- An instance that reads only version 1 can't read exports written from version 2 on (maintainer; spec 029 decision 2; ADR 0023).
- A finish a catalog refresh stops listing between resolving and writing is accepted: the lot is written (spec 028 Error Scenarios).
- On slow hardware a very large apply may hold other writes briefly; import while nothing else is writing (spec 028 decision 3; README).
- The coverage check compares names, not meaning (ADR 0020).
- A source that retires or replaces an id leaves a lot that doesn't resolve; a person repairs it by hand (ADR 0020).
- [#64](https://github.com/plainprogrammer/Collector/issues/64): currency is one instance setting, so a file carries today's instance currency and a file in another is refused.
- CLAUDE.md's earlier claim that no spec enforces that the location files name no collectible type is out of date: `spec/import_apply_core_spec.rb` lists them (checked on `origin/main`).

## Sources

- [Spec 017](../specs/017-export-format/spec.md): all.
- [Spec 022](../specs/022-export-collection/spec.md): all.
- [Spec 025](../specs/025-import-preview/spec.md): all but decision 6's request body limit, which is release and deploy's.
- [Spec 026](../specs/026-typed-entry/spec.md): decision 6 and FR-5, the list left out of the export.
- [Spec 028](../specs/028-apply-import/spec.md): all but decision 9's retention and sweep and decision 8's gate, which are release and deploy's.
- [Spec 029](../specs/029-manage-locations/spec.md): decisions 1, 2, 9–11, Stories 6–9, FR-3–FR-5 (format version 2, the export, the preview and the apply of locations).
- [Spec 032](../specs/032-lot-in-a-location/spec.md): decisions 1, 3, 7, Stories 8–11, FR-3, FR-4 (format version 3, the export, the preview and the apply of a lot's location); it supersedes parts of specs 017, 022, 025, 028 and 029 as its Supersedes table lists.
- [Spec 030](../specs/030-backup-restore/spec.md): decision 11, AC-3.3, AC-6.1 (export versus backup).
- ADRs [0019](../adr/0019-lot-as-the-unit-of-ownership.md), [0020](../adr/0020-export-format.md), [0021](../adr/0021-export-format-rules-in-the-app.md), [0022](../adr/0022-stored-import-upload-retention.md) (as far as the apply reads the upload), [0023](../adr/0023-locations-make-export-format-version-2.md), [0025](../adr/0025-a-lots-location-is-part-of-its-identity.md).
- Reference: [`docs/export-format/README.md`](../export-format/README.md).
- Issues [#37](https://github.com/plainprogrammer/Collector/issues/37), [#38](https://github.com/plainprogrammer/Collector/issues/38), [#39](https://github.com/plainprogrammer/Collector/issues/39), [#40](https://github.com/plainprogrammer/Collector/issues/40), [#44](https://github.com/plainprogrammer/Collector/issues/44), [#45](https://github.com/plainprogrammer/Collector/issues/45); open: [#64](https://github.com/plainprogrammer/Collector/issues/64).

## Distillation log

| Date | Distilled | Pull request |
|---|---|---|
| 2026-10-24 | Spec 032 (format version 3, a lot's location in the export, the preview and the apply): glossary, invariants, export, reading a file, outcomes, preview page, fingerprint, apply order, constants, decisions and sources updated | spec 032's pull request (#45) |
| 2026-10-23 | Specs 017, 022, 025, 028 (all but the stored upload's retention and gate), 026 (the export part), 029 (format version 2, the export, the preview and the apply) and 030 (export versus backup); ADRs 0019–0023; and CLAUDE.md's export, import and locations paragraphs | slice C's pull request |
