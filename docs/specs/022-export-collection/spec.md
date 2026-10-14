# Feature 022: Export a Collection as a File

**Status:** Draft, for the maintainer's approval
**Version:** 1.0.0
**Created:** 2026-10-14
**Last Updated:** 2026-10-14
**Branch:** `022-export-collection`
**Issue:** [#38](https://github.com/plainprogrammer/Collector/issues/38)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-14 | Written from issue #38, roadmap theme A item 3, and the export format (spec 017, ADR 0020) |

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

### 1. Written in the request, not in a background job (for the maintainer's ruling)

The issue asks whether a large collection needs a background job. **Recommendation: no.** The file is built and sent in the request that asks for it.

- *Cost.* The writer reads the account's user and its lots with their entries and sets: a fixed number of queries per 1,000 lots, nothing written. A lot is about 320 bytes of JSON. A collection of 50,000 lots (well beyond a large personal collection, which runs to some thousands of distinct printings) is a file of about 16 MB; generating that JSON takes under 0.1 s on the development machine, and the plan measures the whole request at that size and records it in `verification.md`.
- *Why not a job.* A job needs a stored file (storage per account, a place to keep it, a rule for deleting it), a page that waits for it, and tenant-scoped download of a stored blob. That is more surface for a cost that, at the sizes above, is a second or two of one request.
- *When to revisit.* If the measured request at 50,000 lots takes more than 10 seconds, or a collector's export times out behind a proxy, a background job with a stored, expiring file replaces this, in its own spec.

The alternative, for the ruling: a background job that writes the file to Active Storage, a page that polls until it is ready, and a download that expires.

### 2. The route is `GET /collection/export`

`resource :export, only: :show` inside the `collection` resource, module `collections`: `Collections::ExportsController#show`. Reading an export changes nothing, so it is a GET. The response is the file itself, sent as an attachment.

### 3. The file's name is `collector-export-YYYY-MM-DD.json`

The date is the export's `exported_at` date, in UTC. A collector who exports twice in a day gets two files of the same name; their browser handles that as it handles any download.

### 4. The writer is `CollectionExport`, a plain model

`app/models/collection_export.rb`, named for what it does, collectible-agnostic. It takes an account and a time and returns the file as a Hash and as JSON. It never names a collectible type: every entry field comes from the core catalog tables (`catalog_entries`, `catalog_sets`), which every collectible type fills.

| File field | Source |
|---|---|
| `format` | `"collector-export"` |
| `format_version` | `1` |
| `exported_at` | the time the request began, UTC, fraction dropped |
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
| `lots[].price_paid` | `lots.price_paid_cents` as `"<units>.<two digits>"`, `null` when not recorded |
| `lots[].added_at` | `lots.created_at`, UTC, fraction dropped |
| `lots[].changed_at` | `lots.updated_at`, UTC, fraction dropped |

Lots are written in the order they were added (`created_at`, then `id`). The format gives order no meaning; a fixed order makes two exports of an unchanged collection identical apart from `exported_at`.

### 5. `generator` is left out

The format allows it to be left out, and the app has no version it knows at run time (the image is tagged at release, nothing in the app reads the tag). Writing `"Collector"` with no version would only half-meet the field's meaning. When the app learns its version, adding the field is information only and doesn't change the format version.

### 6. The link is "Export collection" in the account menu and on More (for the maintainer's ruling)

The design system places import and export in the avatar menu on wide screens and on More on phones, "never in the main navigation" (`docs/design-system/README.md`, Navigation; `AppHeader.md`; the `CollectionPagePhone` preview shows "Import and export" in that menu). The brief asked for "a link from the collection page". **Recommendation:** follow the design system. "Export collection" is a `c-menu__item` in the header's account menu (`layouts/_appbar`), above the separator that precedes the admin links or Sign out, so it is reached from the collection page and from every other page with the header; and a row on More (`mores/show`), after "Signed in as", so a phone reaches it from the tab bar. MorePage.md says More "holds what the header's account menu holds", so both change together.

It is a plain link with `download`, outside Turbo Drive (`data-turbo="false"`), so the browser downloads the file and the page stays. It shows for an empty collection too: an empty file is a complete file. The label says what is exported; "Import and export" waits until import exists.

The alternative, for the ruling: a secondary "Export" button in the collection page's head beside "Scan cards" and "Add items" (what the brief named), which the design system's Navigation rule doesn't place there.

### 7. Scanner sittings are never in the file

The format's Coverage table leaves `scanner_sittings` and `scanner_sitting_entries` out, and spec 009 deletes an ended sitting with its entries. What a sitting added is already in the lots. The writer reads no sitting table, so neither an open nor an ended sitting appears.

## User Stories

### Story 1: Download my collection

**As a** collector
**I want** to download my whole collection as one file
**So that** I hold my data outside Collector and can restore it elsewhere

- [ ] **AC-1.1** Given a signed-in collector When they request `GET /collection/export` Then the response is 200, `Content-Type: application/json`, `Content-Disposition: attachment` with the filename `collector-export-<UTC date>.json`, and `Cache-Control: no-store`
- [ ] **AC-1.2** Given a fixture collection that holds every shape a lot can take (finish, condition and price each set and each `null`; a price of `"0.00"`; a price over 1,000; a quantity of 9,999; a non-English printing; a printing whose entry is retired) When it is exported Then the file is well-formed: `v1.schema.json` passes and the format's four further rules hold (checked with `spec/support/export_format_rules.rb`)
- [ ] **AC-1.3** Given the same fixture Then the file's `profile`, `currency` and each lot's seven fields equal the values in the source table of decision 4, and the file holds exactly one lot per lot row
- [ ] **AC-1.4** Given a lot created and updated at times with a fraction of a second When exported Then `added_at` and `changed_at` are those times in UTC with the fraction dropped, not rounded
- [ ] **AC-1.5** Given a collector with no lots When they export Then the file is well-formed with `"lots": []`
- [ ] **AC-1.6** Given an unchanged collection exported twice Then the two files are identical apart from `exported_at` (and the same collection by the format's definition)
- [ ] **AC-1.7** Given a signed-out visitor When they request the export Then they are sent to sign in and receive no file

### Story 2: Only my collection

**As a** collector on a shared instance
**I want** the file to hold only my account's data
**So that** nobody else's collection or profile leaves with mine

- [ ] **AC-2.1** Given two accounts with lots, including lots of the same printing When the first collector exports Then the file holds only the first account's profile and lots, and no value from the second account's user or lots appears anywhere in the response body
- [ ] **AC-2.2** Given a collector with an open scanner sitting (spec 009) When they export Then the file's fields are exactly those the format defines (no sitting, reading key or sitting entry), and the lots the sitting added are in the file as lots
- [ ] **AC-2.3** Given the file Then it holds no password digest, admin flag, session, internal id (`id`, `account_id`, `catalog_entry_id`) or the user's or account's dates

### Story 3: Reach it from the account menu and More

**As a** collector
**I want** an "Export collection" link where the app keeps account things
**So that** I don't have to know the address

- [ ] **AC-3.1** Given any page with the header, the collection page included, Then the account menu holds a `c-menu__item` link "Export collection" to `/collection/export` with `download` and `data-turbo="false"`, for admins and non-admins alike
- [ ] **AC-3.2** Given the More page Then it holds a row with the same link, after the "Signed in as" row
- [ ] **AC-3.3** Given a collector in the browser When they open the account menu on the collection page and click "Export collection" Then the browser receives the file and the collection page stays shown (system spec)
- [ ] **AC-3.4** Given the account menu open at 1280px and the More page at 390px, in both themes Then the link is shown in full and nothing scrolls sideways (screenshots in `verification.md`)
- [ ] **AC-3.5** `MorePage.md` (and the README's app additions if a pattern doc changes) shows the new row (verified by reading)

## Functional Requirements

- **FR-1** `CollectionExport.new(account:, at:)` returns the file for that account as a Hash (`#to_h`) and as JSON (`#to_json`). It reads the account's user and the account's lots only, through the account's associations.
- **FR-2** It reads lots with their entries and sets in batches of 1,000, so the number of queries grows with the number of batches, not lots.
- **FR-3** It writes no row, no file and no cache entry, and enqueues no job.
- **FR-4** `Collections::ExportsController#show` sends `CollectionExport.new(account: Current.account, at: Time.current).to_json` with `send_data`, the headers of AC-1.1, and nothing else. It requires a signed-in user like every other collection page.
- **FR-5** The account menu and More link to it as decision 6 says.
- **FR-6** No code under the writer names a collectible type (`spec` check alongside `spec/admin_catalog_core_spec.rb`'s style: the writer's file holds no `MTG`).

## Non-Functional Requirements

- **Cost per account (hosted-door rule 4).** Storage: none; the file is never kept. Background work: none. Per export: one request that reads the account's user and lots (a fixed number of queries per 1,000 lots) and holds the file in memory once, about 320 bytes per lot (16 MB for 50,000 lots). The plan measures the request at 50,000 lots and records the time and the peak memory in `verification.md`.
- **Hosted-door rules.** Rule 1: no source is adopted. Rule 2: only the signed-in collector exports their own collection; no admin page reads it. Rule 3: no setting is added. Rule 4: as above.
- **Security.** The file holds the collector's name and email address (the format says so). It is sent only to its owner, with `Cache-Control: no-store`. The tenant is `Current.account`; no parameter names an account.
- **Format.** Version 1, unchanged. No collector-owned data is added, so the format and its Coverage tables don't change.
- **Testability.** Well-formedness is checked in RSpec against `v1.schema.json` through `ExportFormatRules.problems`. Tenant isolation is a request spec. The download is a system spec.

## Open Questions

- Decision 1 (request vs background job) and decision 6 (where the link sits) are put to the maintainer.

## Out of Scope

Import (#39, #40), backup (#41), other formats, partial exports, an admin export, and the format document, schema and examples.
