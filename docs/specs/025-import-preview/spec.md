# Feature 025: Preview an Import

**Status:** Approved by the maintainer (2026-10-15), with rulings on decisions 1–7 and 11–14
**Version:** 1.5.0
**Created:** 2026-10-15
**Last Updated:** 2026-10-15
**Branch:** `025-import-preview`
**Issue:** [#39](https://github.com/plainprogrammer/Collector/issues/39)
**Frozen:** the current rules are in [`data-portability.md`](../../architecture/data-portability.md) (parts: all but decision 6's request body limit) and [`release-and-deploy.md`](../../architecture/release-and-deploy.md) (parts: decision 6, the request body limit); see the [specs index](../README.md)
**Plan:** retired in `f62edb57955f78aca0836e16b3129e9cb29219ea`; read it with `git show f62edb57955f78aca0836e16b3129e9cb29219ea^:docs/specs/025-import-preview/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-15 | Written from issue #39, roadmap theme A item 4, the export format (spec 017, ADR 0020) and the export (spec 022) |
| 1.1.0 | 2026-10-15 | From the spec review (Opus). A held lot that a row with problems names is *held by a problem row*, never removed (decision 1); the round trip holds when every lot resolves (AC-1.3); a hard cap on request bodies in front of Rails (decision 6); long lists show their first 100 rows with counts by reason (decision 11, proposed); ADR 0013's debt stays with the first Active Storage upload; changed copies defined; refusals carry rule and place; whole numbers with a zero fraction; documents that change completed |
| 1.2.0 | 2026-10-15 | The maintainer ruled decisions 1–7 as proposed |
| 1.3.0 | 2026-10-15 | Approved by the maintainer: decision 11 accepted, the 40 MB server cap (decision 6) and "held by a problem row" (decisions 1 and 2) accepted as written |
| 1.4.1 | 2026-10-15 | From the plan review: a stray header row removed from decision 10's table |
| 1.5.0 | 2026-10-15 | The maintainer's plan approval: the memory bar is 500 MB (decision 13); Import collection supersedes spec 022 decision 6's menu order, and spec 022 isn't edited (decision 14) |
| 1.4.0 | 2026-10-15 | From the second spec review (Fable). Outcomes partition the held lots (decision 1); the hard cap at every layer that receives the body (decision 6); the catalog checks' order and each row problem's rule and place (decision 9); each refusal's rule and place (decision 10); a tie-break for removed lots (decision 11); AC-2.7 checks the well-formedness model; the preview's time bar is 30 seconds, ruled by the maintainer (decision 12); the file field is filtered from the logs; FR-9 names its files |

---

## Problem Statement

A collector can take their collection out of Collector (spec 022) but can't bring a file back in. Restoring an export into a fresh instance is the 1.0 test's second check, and an import that writes before the collector has seen what it will do is unsafe: a file from another instance can name printings this catalog doesn't hold, finishes a printing doesn't come in, or a different currency.

This spec builds the first half of import. A signed-in collector uploads an export file and sees what applying it would do to their collection, with every row that can't be applied listed and the reason given. Nothing is written. Applying is issue #40.

> **Inputs.** The export format document ([`docs/export-format/README.md`](../../export-format/README.md)), `v1.schema.json` and the examples are fixed inputs: this spec reads format version 1 as the document defines it and changes none of them.
>
> **Terms.** The *file* is the uploaded export. A *row* is one element of the file's `lots`, numbered from 1 in the file's order (the format's `at` pointers count from 0: row 1 is `/lots/0`). A *problem row* is a row that can't be applied, for any reason in decision 9. *Well-formed* and *resolvable* have the format's meanings. A *held lot* is a lot in the collector's collection. The *preview* is the page that says what applying the file would do. *Applying* is #40's step; this spec defines what it would do (decision 1) so that the preview can say so.

## Goals

- A signed-in collector uploads an export file and sees, on one page, what applying it would do to their collection.
- Every row that can't be applied is reported with its position, what the file says it is, and why.
- A file that can't be read at all (not JSON, not an export, a newer version, too large, another currency) is refused with the reason, and no rows are shown.
- Nothing is written: no lot, user, account or other row, no stored file, no job.
- The upload is validated by size and content (security rule). ADR 0013's owed validation (content type, size and pixel limits of Active Storage image uploads) stays with the first Active Storage upload: this upload is never stored and is no image.
- The reading of a file is a model #40 can apply from, so this spec doesn't block it.

## Non-Goals

- Applying an import, and the export → import round-trip test (#40).
- Deciding how the file reaches the apply step (a second upload, or a stored copy): #40 decides.
- Files from other tools, CSV, or any format but `collector-export` version 1 (north star, Not before 1.0).
- Repairing a row (choosing another printing for an unresolved id).
- An admin import, or importing into another account (hosted-door rule 2).
- Any change to the format, its schema, its examples or its Coverage tables.

## Decisions

Decisions 1 to 7 and 11 to 14 were ruled by the maintainer on 2026-10-15, each as proposed, with the alternatives named here put to them.

### 1. Applying replaces the collection (ruled)

Applying a file makes the collection hold exactly the file's lots: #40's outcome, "their collection then holds what the file describes", and the 1.0 test's restore-and-match. So, comparing rows with held lots by [lot identity](../../export-format/README.md#lot-identity):

| Outcome | When | Copies counted |
|---|---|---|
| **Added** | A row that isn't a problem row, whose identity no held lot has. | the row's quantity |
| **Changed** | A row that isn't a problem row, whose identity a held lot has, and the lot's quantity, added time or changed time differs from the row's. Times are compared to the second, as the file writes them. | held copies before and file copies after ("2 lots, 7 copies become 9") |
| **Unchanged** | A row that isn't a problem row, whose identity a held lot has with the same quantity and both times. | the row's quantity |
| **Held by a problem row** | A held lot whose identity a problem row has (a row whose identity can be read, below). | the held quantity |
| **Removed** | A held lot whose identity no row has. | the held quantity |

A row's identity **can be read** when its `entry` is an object whose `collectible_type` and `source_id` are strings that aren't blank, and its `finish`, `condition` and `price_paid` each pass the schema's rule for that field. A row whose identity can't be read matches no lot. So a lot the file plainly names is never reported as removed because its row has, say, a bad time; it is "held by a problem row", which the file must fix before it can be applied (decision 2).

The outcomes partition the held lots: each held lot has exactly one, taken in this order. If a row that isn't a problem row has its identity, the lot is changed or unchanged by that row. Otherwise, if a problem row has its identity, it is held by a problem row. Otherwise it is removed. So the two rows of a `duplicate_lot` pair count the held lot once, through the first row.

A whole number with a zero fraction is the same number (`4.0` is `4`), as the format says, so a row of quantity `4.0` and a lot of 4 have the same quantity.

The alternative not chosen: *merge*, where the file's lots are added or set to the file's quantity and every other lot is kept, so nothing is ever removed.

### 2. A file with a problem row can't be applied (ruled)

#40 is all or nothing, and the format says a reader never drops a lot without saying so. The preview reports every problem row, says that the file can't be applied until they are fixed, and still shows what the other rows would do. The alternative not chosen: preview what applying only the good rows would do.

A consequence: a held lot can stop resolving after it was added (a type the instance no longer registers, which the export still writes, spec 022 decision 4; a finish a catalog refresh no longer lists). The collector's own export of such a collection then previews with that lot's row as a problem row. That is intended: applying would have to write a lot this catalog can't hold.

### 3. A file in another currency is refused (ruled)

Every `price_paid` is in the file's currency. A file whose `currency` isn't the instance's (`Rails.configuration.x.currency.code`) would change what its prices mean, so it is refused as a whole, even one with no lots (the rule stays simple). When currency becomes each collector's choice (#64), that spec revisits this. The alternative not chosen: a warning only.

### 4. The profile: only the collection view is applied (ruled)

Applying never changes the collector's name or email address: on this instance they are who signs in. It takes `collection_view` from the file, a preference. The preview says when the view would change, and notes, as information, when the file's name or email address differs from the collector's, showing the file's value. The known views are `User::COLLECTION_VIEWS` (`grid`, `table`); a `collection_view` the instance doesn't know is ignored, as the format says: no line, no problem. The alternatives not chosen: take nothing from the profile; take all three fields.

### 5. The format's rules live in the app (ruled; ADR 0021)

The app reads files, so it needs the rules the suite holds today in `spec/support/export_format_rules.rb`, and `docs/` isn't in the published image. ADR 0020's consequences leave this to import.

- `json_schemer` (already locked, test group) moves to the app's bundle, with its dependencies (hana, regexp_parser, simpleidn); bundler-audit covers them.
- A copy of `v1.schema.json` lives inside the app, and the suite checks it is byte-identical to `docs/export-format/v1.schema.json`.
- The well-formedness rules (the schema, plus `not_utf8`, `not_json`, `not_a_time`, `changed_before_added`, `duplicate_lot`) move from the suite's support file into an app model, and the support file uses it. The suite checks the app reports exactly `examples/problems.json` (rule and place) for every invalid example and nothing for the valid ones.

The alternatives not chosen: a hand-written validator with no gem at run time; shipping `docs/export-format/` in the image and reading it there. ADR 0021 records the decision.

### 6. The upload is read in the request and never stored (ruled)

- The file is read and judged in the request that uploads it. Nothing keeps it: no Active Storage, no row, no cache entry. The web server's temporary copy of the upload goes when the request ends.
- **Size:** a file over 32 MB is refused with the reason before it is parsed. An export of 50,000 lots is about 16 MB (spec 022).
- **Hard cap:** every layer that receives the request body refuses one over 40 MB before it is kept, so a huge upload never fills the disk with a temporary copy: Puma (`http_content_length_limit`, in every environment), Thruster in the published image (`MAX_REQUEST_BODY`, which is unlimited by default), and kamal-proxy in a Kamal deployment (`proxy.buffering.max_request_body`, which buffers up to 1 GB to disk by default). Past 40 MB the collector sees a plain "413 Payload Too Large" or, when the server closes the connection mid-upload, the browser's own failed-request page; between 32 and 40 MB they see decision 10's reason. Nothing else in the app sends a body near that size.
- **Content:** the file is judged by what it holds (UTF-8 JSON that is an export), never by the type or name the browser declares. The file field asks the browser for `.json` files, as a convenience only.
- **Cost bar:** a 50,000-row file previews in under 30 seconds and grows the process by under 500 MB, measured and recorded in `verification.md` (AC-1.10). Decision 12 changed the time from spec 022's 10 seconds, and decision 13 the memory from its 300 MB.

The alternative not chosen: store the upload so #40 can apply it without a second upload. That is writing; #40 decides it.

### 7. The link is "Import collection" in the account menu and on More (ruled)

As ruled for export in spec 022 (decision 6) and the design system's Navigation rule: "Import collection" goes in the account menu right after "Export collection", and on More as the row after "Export collection". It opens the upload page. The alternatives not chosen: one "Import and export" item leading to a page with both (spec 022 kept that label until import exists); an "Import" secondary button in the collection page's head, as the design system's `CollectionPage.md` mock shows.

### 8. The pages

- `GET /collection/import_preview/new`: the upload page. A file field and a "Preview import" button. It says that previewing changes nothing.
- `POST /collection/import_preview`: reads the file and renders the preview (200), or, for a file that is refused as a whole, the upload page again with the reason (422). Routed as `resource :import_preview, only: %i[new create]` in the `collection` resource's `collections` module: `Collections::ImportPreviewsController`. #40 can add its own resource for applying.
- The form is submitted without Turbo Drive (`data-turbo="false"`): Turbo Drive rejects a 200 render after a form submission, and the preview is an ordinary page the browser shows.
- Both need a signed-in collector, as every collection page does.

### 9. What the preview shows

In order:

1. **The file:** when it was exported (`exported_at`), its number of rows, and its currency.
2. **Whether it can be applied:** "This file can be applied." or "This file can't be applied: N rows have problems." (decision 2).
3. **What applying would do:** the counts of lots and copies for each outcome of decision 1. Removed lots are listed (name, set code, collector number, language, finish, condition, price paid, quantity), because removing is the one destructive outcome. The other outcomes are counts only.
4. **The profile:** a line when the collection view would change, and a note when the name or email address differs (decision 4). Nothing when they agree.
5. **Problem rows:** the count of problem rows for each reason, then the rows, each with its row number, the name, set code, collector number and language the file gives (where the file gives them as strings), and every reason that applies to it, in plain words (table below).
6. If a collectible type the file names is registered on this instance but its catalog isn't loaded, the existing "catalog not loaded" notice (`catalog/_not_loaded`) for those types only (`Catalog.unloaded_titles` restricted to the types the file names, with `named:` as More passes it), so that a fresh instance's collector knows why every row is unresolved.

A link back to the collection and a way to choose another file are on the page. Nothing on it applies the file.

Fields are named by their path in the row, with a point between levels (`quantity`, `entry.source_id`).

| A row's problem | Reason shown |
|---|---|
| The row isn't an object | "This row isn't a lot" |
| A required field is missing (schema `required`) | "`<field>` is missing" |
| A field has the wrong type or form, or is out of range (any other schema keyword: quantity outside 1–9999, a price not in the format's form, a time not in its form, `entry` not an object) | "`<field>` isn't valid" |
| `not_a_time` | "`<field>` isn't a real moment" |
| `changed_before_added` | "`changed_at` is earlier than `added_at`" |
| `duplicate_lot` | "Same card, finish, condition and price as row M" (M the earlier row's number) |
| Collectible type the instance doesn't have | "This instance doesn't collect `<type>`" |
| Entry not in the catalog (retired entries are in it) | "Not in this instance's catalog" |
| Finish not one the catalog lists for that entry | "This printing doesn't come in `<finish>`" |
| Condition not one of the type's conditions | "`<condition>` isn't a condition this instance knows" |

Each row problem carries the format's rule and place as well (`rule`: the schema keyword or one of the five rules, or `unknown_type`, `not_in_catalog`, `finish_not_listed`, `condition_unknown`; `at`: a JSON Pointer into the file, such as `/lots/0/quantity`).

A row that isn't well-formed isn't checked against the catalog; its well-formedness reasons are shown. `duplicate_lot` compares only rows whose identity can be read (decision 1), and the time rules apply to every row whose times pass the schema.

A well-formed row is checked against the catalog in this order:

- Its collectible type isn't one the instance has: that reason only.
- Its entry isn't in the catalog: that reason, and the condition reason if its condition isn't one of the type's. The finish isn't checked: it needs the entry.
- Its entry is in the catalog: the finish reason and the condition reason, each when it applies.

### 10. When a file is refused as a whole

The upload page is shown again (422) with one reason, and no rows:

| The file | Reason shown | Rule and place |
|---|---|---|
| No file chosen, empty, or a form field that isn't an upload | "Choose an export file to preview." | `no_file`, `""` |
| Over 32 MB (and not over the hard cap) | "This file is larger than 32 MB, so it can't be an export Collector reads." | `too_large`, `""` |
| Not UTF-8, not JSON, a byte order mark, or an object with a key twice | "This file isn't a Collector export: it isn't readable JSON." | `not_utf8` or `not_json`, `""` |
| Not an object | "This file isn't a Collector export." | `type`, `""` |
| `format` missing or not `collector-export` | "This file isn't a Collector export." | `required` or `const`, `/format` |
| No `format_version`, or one that isn't a whole number of at least 1 | "This file doesn't say which version of the export format it follows." | `required` or `const`, `/format_version` |
| `format_version` a whole number higher than 1 (`2` or `2.0`) | "This file was written by a newer version of Collector (format version N). This instance reads version 1." | `newer_version`, `/format_version` |
| A schema problem outside `/lots/<row>` (the header, the profile, the currency's form, `lots` missing or not a list), or `exported_at` not a real moment | "This file isn't a well-formed export: `<field>` …", naming the first such field in document order | the schema keyword or `not_a_time`, at that field |
| `currency` isn't the instance's | "This file's prices are in EUR. This instance uses USD." (decision 3) | `other_currency`, `/currency` |

The checks run in the table's order and the first that applies is the reason. The version is read before the schema, as the format requires: a newer file is refused as newer, not as malformed. A refusal carries its rule and place as well as the reason shown; the rules that aren't the format's (`no_file`, `too_large`, `newer_version`, `other_currency`) are the app's own.

### 11. Long lists show their first 100 rows (ruled)

A fresh instance with no catalog loaded makes every row of a large file a problem row, and an empty file previewed against a large collection removes every lot. Listing 50,000 of either is a page of many megabytes. So each list (problem rows, removed lots) shows its first 100 entries, in the file's order for rows and for lots by name, then set code, collector number, language and lot identity, followed by "and N more". The counts by reason (decision 9, item 5) and by outcome cover them all. The alternative not chosen: list every row.

### 12. The preview's time bar is 30 seconds (ruled)

Checking a 50,000-row file against the whole schema with `json_schemer` takes 6 to 8.4 seconds on the development machine (measured while specifying: 8.35 s for `valid?`, 7.07 s for `validate`; parsing takes about 0.16 s), most of a 10-second bar before the file is resolved, compared or shown. The maintainer kept decision 5 as it is (the schema over the whole file, no hand-written lot checks) and set the preview's bar at 50,000 rows in under 30 seconds. The memory bar stayed at 300 MB until decision 13. The alternatives not chosen: hand-written checks for the lot rows, proved equal to the schema by the suite, keeping 10 seconds; keeping 10 seconds at 10,000 rows; measuring with no threshold.

### 13. The preview's memory bar is 500 MB (ruled)

The plan review found that `json_schemer` keeps a tree of results for every lot it checks, so a 50,000-row file may grow the process by more than spec 022's 300 MB. When approving the plan, the maintainer set the bar at under 500 MB of RSS growth for a 50,000-row preview; the time bar stays at 30 seconds (decision 12). If the measurement misses 500 MB, the plan's fallback (still `json_schemer`, with the header and each lot checked separately against the schema's own `$defs/lot`) needs the maintainer's ruling before it is applied.

### 14. Import collection supersedes spec 022 decision 6's menu order (ruled)

Spec 022 decision 6 says "Export collection" is followed by a `c-menu__sep`, and gives the menu's and More's order. "Import collection" (decision 7) now sits between "Export collection" and that separator, and between "Export collection" and the admin links on More:

| Who | The account menu, in order |
|---|---|
| An admin | Export collection, Import collection, separator, Users and sign-up, Catalog, Jobs, separator, Sign out |
| Any other collector | Export collection, Import collection, separator, Sign out |

More, in order: Signed in as, Export collection, Import collection, then the admin links for an admin, then Sign out.

This supersedes spec 022 decision 6 in that respect. Spec 022 isn't edited: a shipped spec stays as it was approved (the maintainer's practice from 2026-10-15).

## Users and Context

**Primary users:** a signed-in collector moving their collection between instances, or checking a backup file before restoring it.
**Usage context:** occasional; a file from their own export, on a desktop or a phone.
**User mental model:** "Upload my file, see what it would do, nothing happens yet."

## User Stories

### Story 1: Preview what a file would do

**As a** collector
**I want** to see what applying an export file would do to my collection
**So that** nothing surprises me when I apply it

- [ ] **AC-1.1** Given a signed-in collector When they open `GET /collection/import_preview/new` Then the response is 200 and the page holds a file field that accepts `.json` and a "Preview import" button, in a form posting to `/collection/import_preview` as `multipart/form-data` with `data-turbo="false"` and the CSRF token
- [ ] **AC-1.2** Given held lots A (quantity 3, same identity, quantity and times as row 1), B (quantity 2, same identity as row 2, whose quantity is 5), C (quantity 4, same identity, quantity and `added_at` as row 3, whose `changed_at` is later) and D (quantity 7, no row has its identity), and row 4 (quantity 6) whose identity no lot has When the file is previewed Then the response is 200 and the preview reads: added 1 lot, 6 copies; changed 2 lots, 6 copies become 9; unchanged 1 lot, 3 copies; removed 1 lot, 7 copies; and lists D as removed
- [ ] **AC-1.3** Given a collection whose every lot resolves, exported with `CollectionExport`, and that file previewed unchanged Then every row is unchanged, nothing is added, changed or removed, and the page says the file can be applied (the round trip's preview half)
- [ ] **AC-1.4** Given a collector with no lots and a well-formed, resolvable file of 3 rows When previewed Then 3 lots are added and nothing is removed
- [ ] **AC-1.5** Given a well-formed file with no lots and a collector with 2 lots When previewed Then both lots are listed as removed
- [ ] **AC-1.6** Given a lot whose `created_at` and `updated_at` carry a fraction of a second, and a row with the same identity, quantity and those times without the fraction Then the row is unchanged; given a row of quantity `4.0` and a lot of 4 otherwise equal Then the row is unchanged
- [ ] **AC-1.7** Given a file whose `collection_view` is the other known view Then the preview says the view would change to it; given a `collection_view` the instance doesn't know, or the collector's own Then no view line is shown and it isn't a problem; given a file whose name or email address differs Then the preview shows the file's value and says applying won't change it; given a profile that agrees Then no profile line is shown
- [ ] **AC-1.8** Given a preview of any file Then no row in any table of the primary database is created, changed or deleted (row counts, and `updated_at` maxima where the column exists, compared before and after) and no job is enqueued
- [ ] **AC-1.9** Given two files of 2 rows and 30 rows, all resolvable When each is previewed Then both previews run the same number of queries
- [ ] **AC-1.10** Measured outside the suite: each of three 50,000-row files (all resolvable; all unresolvable; all not well-formed, a bad price on every row) previews, the whole request, in under 30 seconds with under 500 MB RSS growth (decisions 12 and 13); the measurements and the method are recorded in `verification.md`
- [ ] **AC-1.11** Given a held lot and a problem row with the same identity (its `added_at` not a real moment) Then the lot is counted as held by a problem row, not removed; given a row whose `entry` is missing Then it matches no lot

### Story 2: See every row that can't be applied

**As a** collector
**I want** each row that can't be applied reported with the reason
**So that** I can fix the file or my catalog before applying

- [ ] **AC-2.1** Given a well-formed file with rows whose entry isn't in the catalog, whose collectible type the instance doesn't have, whose finish the printing doesn't come in, and whose condition isn't known When previewed Then each of those rows is listed with its row number, the name, set code, collector number and language the file gives, and the reason from decision 9's table; the page says the file can't be applied, gives the number of problem rows and the count for each reason
- [ ] **AC-2.2** Given a row whose entry is retired in the catalog Then it isn't a problem row
- [ ] **AC-2.3** Given a row whose descriptive fields disagree with the catalog's entry for its id Then it isn't a problem row (the id wins)
- [ ] **AC-2.4** Given a file whose rows aren't well-formed (a missing field, a quantity of 0, a price `"12.5"`, a time that isn't a real moment, `changed_at` before `added_at`, a duplicate of an earlier row, a row that isn't an object) When previewed Then each such row is listed with its reason from decision 9's table, and isn't checked against the catalog; rows that are well-formed and resolvable are still counted under decision 1
- [ ] **AC-2.5** Given a row with more than one problem Then every reason is shown on that row
- [ ] **AC-2.6** Given a file naming a collectible type that is registered but whose catalog isn't loaded Then the page shows the "catalog not loaded" notice
- [ ] **AC-2.7** For every file in `docs/export-format/examples/invalid/`, the app's well-formedness model (decision 5, the one `spec/support/export_format_rules.rb` uses) reports exactly the problems `examples/problems.json` names for it (rule and place), and for every file in `examples/valid/` and `examples/comparison/` it reports none
- [ ] **AC-2.8** Given 150 problem rows When previewed Then the first 100 are listed, followed by "and 50 more", and the counts by reason cover all 150; given 150 removed lots Then the same holds for the removed list

### Story 3: A file that can't be read is refused

**As a** collector
**I want** a file that isn't an export Collector can read to be refused with the reason
**So that** I know what's wrong

- [ ] **AC-3.1** Given each case of decision 10's table When uploaded Then the response is 422, the upload page is shown again with that case's reason, and no rows are shown
- [ ] **AC-3.2** Given a file of format version 2 (or `2.0`) that is otherwise not well-formed under version 1 Then the reason is the newer-version one; given `format_version` `1.0` Then it is read as version 1
- [ ] **AC-3.3** Given a file over 32 MB Then it is refused with decision 10's reason and the reader never parses it
- [ ] **AC-3.4** Given a request whose body is over 40 MB Then Puma answers 413 before the request reaches Rails: a spec loads `config/puma.rb` through `Puma::Configuration` and finds the limit 40,000,000, and a request of 41 MB to a running server is answered 413 once by hand (recorded in `verification.md`); the Dockerfile sets `MAX_REQUEST_BODY` to 40,000,000 and `config/deploy.yml` sets `proxy.buffering.max_request_body` to 40,000,000 (checked by specs of those files)
- [ ] **AC-3.5** Given a well-formed export uploaded with any declared content type or file name (`image/png`, `cards.txt`) Then it is previewed; given a non-JSON file declared as `application/json` Then it is refused as not JSON

### Story 4: Only my collection

**As a** collector on a shared instance
**I want** the preview to compare the file with my collection only
**So that** nobody else's collection is shown or counted

- [ ] **AC-4.1** Given two accounts that both own lots of a printing in the file When the first collector previews Then the outcomes are computed against the first account's lots only, and nothing of the second account's (its lots' distinctive quantity and price, its user's name and email address) appears in the response
- [ ] **AC-4.2** Given a signed-out visitor When they request either page Then the response redirects to sign in and the reader isn't called

### Story 5: Reach it

**As a** collector
**I want** "Import collection" where the app keeps account things
**So that** I find it beside export

- [ ] **AC-5.1** Given any page with the header Then the account menu holds a `c-menu__item` link "Import collection" to `/collection/import_preview/new`, right after "Export collection", for admins and non-admins alike
- [ ] **AC-5.2** Given the More page Then it holds a row with the same link, right after "Export collection"
- [ ] **AC-5.3** Given a collector in the browser When they open the account menu, follow "Import collection", choose an export file and press "Preview import" Then the preview page shows the counts (system spec)
- [ ] **AC-5.4** Given the upload page, a refused file, and a preview with removed lots and problem rows, at 1280px and 390px in both themes Then everything is shown in full and nothing scrolls sideways (screenshots in `verification.md`)
- [ ] **AC-5.5** The pages use only the design system's tokens and `c-*` classes; any new pattern is in `collector/additions.css` with its doc under `docs/design-system/components/`, and `MorePage.md` shows the new row (verified by reading)

## Functional Requirements

- **FR-1** A reader model takes the uploaded bytes and the account and returns either a refusal (decision 10: its reason, and its problems as rule and place) or a preview: the file's header facts, the problem rows with their problems (decision 9), the outcome of each row and of each held lot (decision 1), and the profile notes (decision 4). It writes nothing (FR-6) and is usable by #40 to apply from.
- **FR-2** Well-formedness is decided by the app's copy of the version 1 rules (decision 5), with the version read first. The schema applies to the whole file; the time rules apply to every row whose times pass the schema; `duplicate_lot` compares only rows whose identity can be read.
- **FR-3** Resolution looks up entries by (`collectible_type`, `source_id`) = (`catalog_entries.collectible_type`, `external_key`), retired or not. A type is unknown when the instance's registry doesn't have it, decided before the registry is asked for the type's vocabulary. Finishes come from the type's collecting vocabulary for that entry, conditions from its conditions. The core reader never names a collectible type.
- **FR-4** The number of queries doesn't grow with each row: entries, what their finishes need, and the account's lots are read in a bounded number of statements (batched only past a fixed size, below SQLite's limit on bound values).
- **FR-5** Comparison with the collection uses only `Current.account`'s lots. No parameter names an account.
- **FR-6** Previewing creates, changes and deletes no row, writes no file or cache entry, and enqueues no job. Nothing logs the file's content: a JSON parse error is rescued and its message, which quotes the file, is never logged or shown, and the file field's name joins `config.filter_parameters`, so a string posted in its place isn't logged.
- **FR-7** The upload is refused over 32 MB before parsing, the app server refuses bodies over 40 MB, and the file is judged by content, not declared type (decision 6).
- **FR-8** The account menu and More link to the upload page (decision 7).
- **FR-9** The reader's files under `app/models/`, `app/controllers/collections/import_previews_controller.rb`, the views under `app/views/collections/import_previews/` and any helper they add contain neither `MTG` nor `Scryfall` (a spec in the style of `spec/admin_catalog_core_spec.rb`, naming the files).

## Non-Functional Requirements

- **Cost per account (hosted-door rule 4).** Storage: none; the file is never kept beyond the request's temporary copy. Background work: none. Per preview: one request that reads at most 32 MB (40 MB at the server), parses it, and reads the account's lots and the matching catalog entries in a bounded number of statements. AC-1.10 holds a 50,000-row file to under 30 seconds and 500 MB (decisions 12 and 13). A rate limit on previews is a hosted-service feature (north star, Not before 1.0).
- **Hosted-door rules.** Rule 1: no source is adopted. Rule 2: a collector previews into their own collection only; no admin page reads a file or a collection. Rule 3: no setting is added (the size limits are constants, not settings). Rule 4: as above.
- **Security.** The file holds a name and an email address; it is never stored, logged or echoed beyond what the preview shows its owner (the file's own name and email address only when they differ, decision 4). Responses carry `Cache-Control: no-store`. The upload is a CSRF-protected form. JSON is parsed with duplicate keys refused and the parser's default nesting limit. Brakeman stays clean.
- **Format.** Version 1, unchanged. No collector-owned data is added, so the format and its Coverage tables don't change.
- **Testability.** Request specs for every page and outcome, model specs for the reader, the examples check (AC-2.7), and one system spec for the flow.

## Error Scenarios

The whole-file cases are decision 10's table; the row cases are decision 9's. A catalog refresh running during a preview doesn't change what one preview reads in a way that matters: entries are never deleted (retired instead). A session that has ended (its `sessions` row deleted) when the form is submitted is sent to sign in (AC-4.2) and must choose the file again. A form posted with no session cookie at all fails CSRF protection first and is answered as any such request is (422), before sign-in is asked for; AC-4.2's POST case is set up with a deleted session row.

## Documents that change

- `CLAUDE.md`: the status line ("import isn't built yet"); the export format fact ("nothing reads it yet", and "`json_schemer`, test group, `require: false`"); the Active Storage fact's "No upload feature exists yet", reworded so that it says the import preview's upload is never stored and ADR 0013's owed validation stays with the first Active Storage upload.
- `README.md`: the "Your data" paragraph's "Import isn't in the app yet", and the Compose and Kamal sections' note of the 40 MB request limit (decision 6).
- `docs/roadmap.md`: theme A item 4 is marked done.
- `docs/adr/0021-…` and its line in `docs/adr/README.md` (Data safety).
- `docs/adr/0020-export-format.md`: its consequence that import "has to decide where its copy of the rules lives" links to ADR 0021.
- `docs/design-system/components/MorePage.md`, and `AppHeader.md` if it lists the menu's items; a doc for any new pattern.
- `spec/support/export_format_rules.rb`: its header comment.
- `docs/export-format/README.md` is not changed.

Each is verified by reading.

## Open Questions

None. Decisions 1 to 7 and 11 to 14 are ruled.

## Out of Scope

Applying (#40), backup (#41), other formats and other tools' files, repairing rows, an admin import, and the format document, schema and examples.
