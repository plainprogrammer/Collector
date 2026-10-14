# Feature 022: Export a Collection as a File

**Status:** Approved with changes by the maintainer (2026-10-14), with rulings on decisions 1 and 6; the changes are applied in 1.2.0
**Version:** 1.2.0
**Created:** 2026-10-14
**Last Updated:** 2026-10-14
**Branch:** `022-export-collection`
**Issue:** [#38](https://github.com/plainprogrammer/Collector/issues/38)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-14 | Written from issue #38, roadmap theme A item 3, and the export format (spec 017, ADR 0020) |
| 1.1.0 | 2026-10-14 | From the spec review. Lots are read in one statement, so the file is one consistent snapshot (decision 8); order by `id`; the fixture gains an unregistered type, a non-card kind and a localized name; the link has no `download` attribute and no prefetch; after signing in from the export, the collector lands on the collection; the system spec reads Firefox's download folder; the cost is stated without an unmeasured time; criteria tightened (AC-1.1, AC-2.1, AC-2.3, FR-6) |
| 1.2.0 | 2026-10-14 | The maintainer's approval with changes, from a second review (Fable). Decisions 1 and 6 ruled; AC-1.9 holds the 10 s / 300 MB bar as a criterion; the unregistered type's lot has no finish or condition; AC-2.1 uses distinctive values; decision 8 says the writer formats times and prices itself; FR-4 names the override of `request_authentication`; both menu orders stated; the download wait and the Firefox preferences named; AC-2.3's reference set; the documents that change listed; the route takes no format suffix; `id` order after a merge |

---

## Problem Statement

Foundation principle 2 says a collector owns their data, and the 1.0 test's second check needs an export of the family's instance restored into a fresh instance and matched. Spec 017 defined the file ([`docs/export-format/README.md`](../../export-format/README.md), format version 1, [`v1.schema.json`](../../export-format/v1.schema.json)). Nothing in the app writes it yet: a collector has no way to take their collection out of Collector.

This spec builds the writer. A signed-in collector downloads one file that holds their profile, the currency and every lot they own, and nothing of anyone else's.

> **Inputs.** The export format document, its schema and its examples are fixed inputs. This spec writes format version 1 exactly as the document defines it and changes none of them. The document's Coverage tables already say which tables and columns go into the file; this spec follows them.
>
> **Terms.** The *file* is one export as the format defines it. The *writer* is the code this spec adds. *Well-formed* has the format's meaning: the file passes `v1.schema.json` and the four rules the schema can't state.

## Goals

- A signed-in collector downloads their whole collection as one well-formed version 1 file, from the account menu (wide) or More (phone).
- The file holds only the signed-in collector's account: their profile and their lots.
- The file holds every lot, whatever its finish, condition, price or catalog entry (retired entries included).
- The cost per account is stated and bounded (hosted-door rule 4).

## Non-Goals

- Import, preview or restore (#39, #40), and the round-trip test (it needs an import; #40 owns it).
- Exporting part of a collection (a filter, a selection), other formats (CSV), or another account's collection (the operator is not the user: hosted-door rule 2; no admin export).
- Scheduled or emailed exports, and an instance backup (#41).
- A stored copy of the file on the server, or a list of past exports.
- Any change to the format, its schema, its examples or its Coverage tables.

## Decisions

### 1. Written in the request, not in a background job (ruled)

**Ruling (maintainer, 2026-10-14).** Built and sent in the request, with no job, held to the bar below: at 50,000 lots the request completes in under 10 seconds and grows the process by under 300 MB (AC-1.9).


The issue asks whether a large collection needs a background job. **No.** The file is built and sent in the request that asks for it.

- *Cost.* The writer reads the account's user and, in one statement, its lots joined to their entries and sets: a fixed number of queries whatever the collection's size, nothing written. A lot is about 320 bytes of JSON. A collection of 50,000 lots (well beyond a large personal collection, which runs to some thousands of distinct printings) is a file of about 16 MB. The plan measures the whole request at that size, time and peak memory, and records both in `verification.md`.
- *Why not a job.* A job needs a stored file (storage per account, a place to keep it, a rule for deleting it), a page that waits for it, and tenant-scoped download of a stored blob. That is more surface for a cost that, at the sizes above, is a second or two of one request.
- *When to revisit.* If the measured request at 50,000 lots takes more than 10 seconds or grows the process by more than 300 MB, or a collector's export times out behind a proxy, a background job with a stored, expiring file replaces this, in its own spec.

The alternative put to the maintainer and not chosen: a background job that writes the file to Active Storage, a page that polls until it is ready, and a download that expires.

### 2. The route is `GET /collection/export`

`resource :export, only: :show, format: false` inside the `collection` resource, module `collections`: `Collections::ExportsController#show`. Reading an export changes nothing, so it is a GET. The response is the file itself, sent as an attachment.

### 3. The file's name is `collector-export-YYYY-MM-DD.json`

The date is the export's `exported_at` date, in UTC. A collector who exports twice in a day gets two files of the same name; their browser handles that as it handles any download.

### 4. The writer is `CollectionExport`, a plain model

`app/models/collection_export.rb`, named for what it does, collectible-agnostic. It takes an account and a time and returns the file as a Hash and as JSON. It never names a collectible type: every entry field comes from the core catalog tables (`catalog_entries`, `catalog_sets`), which every collectible type fills.

| File field | Source |
|---|---|
| `format` | `"collector-export"` |
| `format_version` | `1` |
| `exported_at` | the `at:` the controller passes (`Time.current` when the action runs), UTC, fraction dropped; the filename's date is the same value's |
| `generator` | left out (see decision 5) |
| `profile.name` | `users.name` |
| `profile.email_address` | `users.email_address` |
| `profile.collection_view` | `users.collection_view` |
| `currency` | the instance's currency code (`Rails.configuration.x.currency.code`) |
| `lots[].entry.collectible_type` | `catalog_entries.collectible_type` |
| `lots[].entry.source_id` | `catalog_entries.external_key` |
| `lots[].entry.name` | `catalog_entries.name` (the catalog's name, never `localized_name`) |
| `lots[].entry.set_code` | `catalog_sets.code` |
| `lots[].entry.collector_number` | `catalog_entries.number` |
| `lots[].entry.language` | `catalog_entries.language` |
| `lots[].quantity` | `lots.quantity` |
| `lots[].finish` | `lots.finish`, `null` when not recorded |
| `lots[].condition` | `lots.condition`, `null` when not recorded |
| `lots[].price_paid` | `lots.price_paid_cents` formatted as `Lot#price_paid` does (exact, through `Rational`: 1005 → `"10.05"`), `null` when not recorded |
| `lots[].added_at` | `lots.created_at`, UTC, fraction dropped |
| `lots[].changed_at` | `lots.updated_at`, UTC, fraction dropped |

Lots are written in `id` order, which is the order their rows were added (after an edit merges two lots, the surviving row keeps its own `id` and `created_at`). The format gives order no meaning; a fixed order makes two exports of an unchanged collection identical apart from `exported_at`.

Every column above is `NOT NULL` where the format needs a value (the entry's fields, the set code, quantity, the two times), so every lot can be written, whatever its collectible type, its kind or whether its entry is retired. The writer never asks the catalog's registry about a type (`Catalog.collecting_for`, `Catalog.source_class`, `Catalog::Entry.preload_extensions`): a type removed from the instance still exports.

### 5. `generator` is left out

The format allows it to be left out, and the app has no version it knows at run time (the image is tagged at release, nothing in the app reads the tag). Writing `"Collector"` with no version would only half-meet the field's meaning. When the app learns its version, adding the field is information only and doesn't change the format version.

### 6. The link is "Export collection" in the account menu and on More (ruled)

**Ruling (maintainer, 2026-10-14).** "Export collection" in the avatar (account) menu plus a row on More, per the design system.


The design system places import and export in the avatar menu on wide screens and on More on phones, "never in the main navigation" (`docs/design-system/README.md`, Navigation; `AppHeader.md`; the `CollectionPagePhone` preview shows "Import and export" in that menu). The brief asked for "a link from the collection page"; the design system is followed. "Export collection" is the first `c-menu__item` in the header's account menu (`layouts/_appbar`), followed by a `c-menu__sep` (Menu.md: a separator between groups), so it is reached from the collection page and from every other page with the header; and a row on More (`mores/show`), after "Signed in as", so a phone reaches it from the tab bar. MorePage.md says More "holds what the header's account menu holds", so both change together.

| Who | The account menu, in order |
|---|---|
| An admin | Export collection, separator, Users and sign-up, Catalog, Jobs, separator, Sign out |
| Any other collector | Export collection, separator, Sign out |

More, in order: Signed in as, Export collection, then the admin links for an admin, then Sign out.

It is a plain link outside Turbo Drive (`data-turbo="false"`) and never prefetched on hover (`data-turbo-prefetch="false"`, as the header's Scan link): a prefetch would build the whole file. It carries no `download` attribute: the response's `Content-Disposition: attachment` makes it a download, and with an expired session `download` would save the sign-in page as the export. The browser downloads the file and the page stays. It shows for an empty collection too: an empty file is a complete file. The label says what is exported; "Import and export" waits until import exists.

The alternative put to the maintainer and not chosen: a secondary "Export" button in the collection page's head beside "Scan cards" and "Add items" (what the brief named), which the design system's Navigation rule doesn't place there.

### 7. Scanner sittings are never in the file

The format's Coverage table leaves `scanner_sittings` and `scanner_sitting_entries` out, and spec 009 deletes an ended sitting with its entries. What a sitting added is already in the lots. The writer reads no sitting table, so neither an open nor an ended sitting appears.

### 8. The lots are read in one statement

The lots are read with one `SELECT` that joins `lots` to `catalog_entries` and `catalog_sets` and plucks the columns of decision 4, ordered by `lots.id`. One statement reads one consistent snapshot of the account's lots in SQLite, so the file can't hold two lots of one identity, or count copies twice, when the collector edits, merges or scans in another tab during the export. Reading in batches (`find_each`) could. A transaction around batches isn't used: Rails' SQLite transactions are IMMEDIATE and would hold up the collector's other writes. Joining the global catalog rows is safe: a catalog entry that a lot points at is never deleted (foreign key). The result is strings, integers, times and `nil`. The writer formats the two times (decision 4's form) and the price itself before `JSON.generate`: left to `JSON.generate`, a time would fall through to ActiveSupport's `to_json` and be written with a fraction (`2026-10-14T12:00:00.000Z`), which the schema's time pattern refuses.

### 9. Signing in from the export lands on the collection

A signed-out request for the export is sent to sign in like any page. The export isn't kept as the page to return to: the sign-in form is submitted through Turbo, which can't follow a redirect to a JSON attachment. After signing in the collector lands on the collection page, from where the link is one tap away.

## User Stories

### Story 1: Download my collection

**As a** collector
**I want** to download my whole collection as one file
**So that** I hold my data outside Collector and can restore it elsewhere

- [ ] **AC-1.1** Given a signed-in collector When they request `GET /collection/export` Then the response is 200, its media type `application/json`, `Content-Disposition: attachment` with the filename `collector-export-<UTC date>.json`, and `Cache-Control: no-store`
- [ ] **AC-1.2** Given a fixture collection that holds every shape a lot can take (finish, condition and price each set and each `null`; a price of `"0.00"`; a price over 1,000 with cents that a float would lose, such as 1,000.05; a quantity of 9,999; a non-English printing whose `localized_name` differs from its `name`; a printing whose entry is retired; an entry of a collectible type the instance hasn't registered, whose lot has a `null` finish and condition (a lot of an unknown type can't be saved with either: `Lot` validates them against the type's vocabulary); an entry whose kind isn't `card`) When it is exported Then the file is well-formed: `v1.schema.json` passes and the format's four further rules hold (checked with `spec/support/export_format_rules.rb`)
- [ ] **AC-1.3** Given the same fixture Then the file's `profile`, `currency` and each lot's seven fields equal the values in the source table of decision 4, and the file holds exactly one lot per lot row
- [ ] **AC-1.4** Given a lot created and updated at times with a fraction of a second When exported Then `added_at` and `changed_at` are those times in UTC with the fraction dropped, not rounded
- [ ] **AC-1.5** Given a collector with no lots When they export Then the file is well-formed with `"lots": []`
- [ ] **AC-1.6** Given an unchanged collection exported twice Then the two files are identical apart from `exported_at` (and the same collection by the format's definition)
- [ ] **AC-1.7** Given a signed-out visitor When they request the export Then they are sent to sign in and receive no file, and after signing in they land on the collection page (decision 9)
- [ ] **AC-1.8** Given a collection of 2 lots and one of 30 lots When each is exported Then the export runs the same number of queries
- [ ] **AC-1.9** Measured at 50,000 lots outside the suite (a throwaway spec that inserts the fixture with `insert_all`): the request completes in under 10 seconds and grows the process's RSS by under 300 MB; both numbers and the method are recorded in `verification.md`

### Story 2: Only my collection

**As a** collector on a shared instance
**I want** the file to hold only my account's data
**So that** nobody else's collection or profile leaves with mine

- [ ] **AC-2.1** Given two accounts with lots, including lots of the same printing When the first collector exports Then the file's profile is the first user's, its lots equal the first account's lots as a set, and no parsed lot has the quantity 8888 or the price `"777.77"`, which only a second-account lot holds; the second user's name and email address, chosen so that no other value in the file contains them, appear nowhere in the response body
- [ ] **AC-2.2** Given a collector with an open scanner sitting (spec 009) When they export Then the file's fields are exactly those the format defines (no sitting, reading key or sitting entry), and the lots the sitting added are in the file as lots
- [ ] **AC-2.3** Given the file Then the set of field names at every depth (`ExportFormatRules.field_names`) equals `ExportFormatRules.field_names` of `docs/export-format/examples/valid/collection.json` without `generator`: no password digest, admin flag, session, internal id or the user's or account's dates

### Story 3: Reach it from the account menu and More

**As a** collector
**I want** an "Export collection" link where the app keeps account things
**So that** I don't have to know the address

- [ ] **AC-3.1** Given any page with the header, the collection page included, Then the account menu holds a `c-menu__item` link "Export collection" to `/collection/export` with `data-turbo="false"` and `data-turbo-prefetch="false"` and no `download` attribute, for admins and non-admins alike
- [ ] **AC-3.2** Given the More page Then it holds a row with the same link, after the "Signed in as" row
- [ ] **AC-3.3** Given a collector in the browser When they open the account menu on the collection page and click "Export collection" Then a file `collector-export-<UTC date>.json` lands in the browser's download folder and parses as a well-formed file, and the collection page stays shown (system spec; it waits for the file with Capybara's own retrying wait, `synchronize`, bounded by `Capybara.default_max_wait_time`, never a sleep). The suite's Firefox gets a download folder under `tmp/` through preferences in `spec/support/system.rb` (`browser.download.folderList` = 2 and `browser.download.dir`, plus any preference the plan finds needed to save JSON without a dialog); they apply to every system spec, which otherwise never downloads
- [ ] **AC-3.4** Given the account menu open at 1280px and the More page at 390px, in both themes Then the link is shown in full and nothing scrolls sideways (screenshots in `verification.md`)
- [ ] **AC-3.5** `MorePage.md` shows the new row, and the documents listed under Documents that change say what is built (verified by reading)

## Functional Requirements

- **FR-1** `CollectionExport.new(account:, at:)` returns the file for that account as a Hash (`#to_h`) and as JSON (`#to_json`, through `JSON.generate`). It reads the account's user and the account's lots only, through the account's associations.
- **FR-2** It reads the lots in one statement joined to their entries and sets (decision 8), so the number of queries doesn't depend on the number of lots.
- **FR-3** It writes no row, no file and no cache entry, and enqueues no job.
- **FR-4** `Collections::ExportsController#show` sends `CollectionExport.new(account: Current.account, at: Time.current).to_json` with `send_data`, the headers of AC-1.1, and nothing else. It requires a signed-in user like every other collection page, without keeping itself as the page to return to (decision 9): it overrides `Authentication#request_authentication`, which stores `request.fullpath` for every GET, to redirect to sign-in without storing it. A page to return to that an earlier request stored is still honoured.
- **FR-4a** The route is `resource :export, only: :show, format: false`, so `/collection/export.json` and other suffixes don't route (as the OCR and art-index routes).
- **FR-5** The account menu and More link to it as decision 6 says.
- **FR-6** `app/models/collection_export.rb` and `app/controllers/collections/exports_controller.rb` contain neither `MTG` nor `Scryfall` nor `Catalog.collecting_for`, `Catalog.source_class` or `preload_extensions` (a spec in the style of `spec/admin_catalog_core_spec.rb`).

## Non-Functional Requirements

- **Cost per account (hosted-door rule 4).** Storage: none; the file is never kept. Background work: none. Per export: one request that reads the account's user and lots (a fixed number of queries) and holds the lots' values and the file in memory, about 320 bytes of JSON per lot (16 MB for 50,000 lots). Nothing limits how often a collector exports; each export is one bounded request, and a rate limit is a hosted-service feature (north star, Not before 1.0). AC-1.9 holds the request at 50,000 lots to under 10 seconds and 300 MB.
- **Hosted-door rules.** Rule 1: no source is adopted. Rule 2: only the signed-in collector exports their own collection; no admin page reads it. Rule 3: no setting is added. Rule 4: as above.
- **Security.** The file holds the collector's name and email address (the format says so). It is sent only to its owner, with `Cache-Control: no-store`. The tenant is `Current.account`; no parameter names an account. The log records only the request and `send_data`'s filename, never the file's content; the email address never reaches parameters or the log.
- **Format.** Version 1, unchanged. No collector-owned data is added, so the format and its Coverage tables don't change.
- **Testability.** Well-formedness is checked in RSpec against `v1.schema.json` through `ExportFormatRules.problems`. Tenant isolation is a request spec. The download is a system spec.

## Documents that change

- `CLAUDE.md`: the status line ("export and import aren't built yet") and the export format fact ("Nothing in the app reads or writes it yet").
- `docs/roadmap.md`: theme A item 3 is marked done, as items 1 and 2 are.
- `docs/design-system/components/MorePage.md`: the new row.
- `spec/support/export_format_rules.rb`: its header comment ("the app has no export or import yet").

Each is verified by reading.

## Open Questions

None. Decisions 1 and 6 are ruled.

## Out of Scope

Import (#39, #40), backup (#41), other formats, partial exports, an admin export, and the format document, schema and examples.
