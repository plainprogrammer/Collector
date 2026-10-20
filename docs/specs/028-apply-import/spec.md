# Feature 028: Apply an Import

**Status:** Approved by the maintainer (2026-10-20), with rulings on decisions 1, 3, 6, 7, 9 and 10 and the error scenario for a failed store; decisions 2, 4, 5 and 8 confirmed; revised after the independent review with the rulings of 2026-10-20 on M1, M3, M4, Q4 and Q5 (version 1.3.1)
**Version:** 1.3.1
**Created:** 2026-10-20
**Last Updated:** 2026-10-20
**Branch:** `028-apply-import`
**Issue:** [#40](https://github.com/plainprogrammer/Collector/issues/40)
**Plan:** none yet

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-20 | Written from issue #40, roadmap theme A item 5, spec 025 (the preview), the export format (spec 017, ADR 0020) and the export (spec 022) |
| 1.3.1 | 2026-10-20 | The maintainer ruled P1 to P4 (2026-10-20): the order of an apply's checks (decision 13, nothing to change before the fingerprint), the fingerprint's full-precision `updated_at` (decision 2), AC-1.10's removal-heavy case and preview re-measure, and the 10-minute orphan grace (decision 9). Marked ruled, Open Questions emptied; no other change |
| 1.3.0 | 2026-10-20 | Revised against the independent Opus review (`review.md`). **Ruled by the maintainer (2026-10-20):** the write transaction's hard bar is under 4 s for 50,000 rows, below SQLite's 5 s busy timeout (decision 3, AC-1.10, FR-2); an apply with nothing to change is refused (new decision 12, AC-2.2, FR-1) and decision 7 clears only when the apply writes; Active Storage's routes stay drawn but are gated behind sign-in and ownership, blobs are created analyzed, every removal purges synchronously outside the write transaction with the sweep as the backstop, the install migration is listed (decisions 8 and 9, AC-1.11, AC-1.12); the sweep runs in development too (AC-5.5); decision 11, FR-3's bulk-write exception and the catalog-refresh accepted limit are confirmed. **Reviewer fixes applied:** round-trip ACs use the format's "same collection" rule and handle the generator and `empty.json` (AC-6.2 to AC-6.4); the sweep's orphan is defined in Active Storage terms (decision 9, AC-5.4); a missing stored file is a 422 and presence, expiry and fingerprint are re-checked in the transaction (FR-2, AC-2.3, error rows). **Proposed, awaiting confirmation:** P1 to P4 (ruled in 1.3.1). Minors: see `review.md` |
| 1.2.0 | 2026-10-20 | Approved by the maintainer: decisions 6, 7, 9 and 10 and the error scenario "Storing the preview's file fails" ruled as recommended; decisions 2, 4, 5 and 8 confirmed. No open questions remain |
| 1.1.1 | 2026-10-20 | Mode A review fixes (verdict in `review.md`): the form carries the fingerprint, so an apply from a page whose upload was replaced is refused (decision 2, AC-3.2); AC-3.3, AC-5.6 and the error rows made exact; the open marker removed |
| 1.1.0 | 2026-10-20 | The maintainer ruled decisions 1 and 3 (through the coordinator): the previewed upload is stored briefly with Active Storage and applied with one click; applying runs in the request in one short write transaction. Added the stored upload (decisions 1, 8, 9), its retention and sweep (decision 9) and ADR 0013's owed validation (decision 8), the supersession of spec 025's "never stored" (decision 10), and the Coverage line |

---

## Problem Statement

A collector can take their collection out of Collector (spec 022) and see what an export file would do to their collection (spec 025), but cannot make it so. Restoring an export into a fresh instance is the 1.0 test's second check ("an export of that instance has been restored into a fresh instance and matched"), and no part of the app can do it.

This spec builds the second half of import. A signed-in collector who has previewed a file applies it with one click, and their collection then holds exactly what the file describes. It is all or nothing, applying the same file twice leaves the collection as the first application did (the second is refused as nothing to change), and it touches the collector's own account only. It ships with the export → import round-trip test that the 1.0 test's second check relies on.

> **Inputs.** The export format document ([`docs/export-format/README.md`](../../export-format/README.md)), `v1.schema.json` and the examples are fixed inputs, as they were for spec 025: this spec reads format version 1 and changes none of them except the Coverage table's new line (decision 9). The reading of a file (`CollectionImport`, spec 025) is reused as it is: its refusals, its problem rows and its outcomes (spec 025 decisions 1, 2, 9, 10) keep their meaning and are not restated here except where applying needs them.
>
> **Terms.** *File*, *row*, *problem row*, *held lot*, *preview* and *applying* are as in spec 025. The *outcomes* are spec 025 decision 1's: added, changed, unchanged, held by a problem row, removed. The *plan* of a file is what applying it to the collection as it is now would do: for each added, changed and removed entry, which row or lot and the quantity and times involved, and whether the collection view would change. The *fingerprint* of a plan is a short digest of the stored file's checksum and the plan, kept with the stored upload when the preview is made, shown to the browser in the apply form, and checked when applying (decision 2). The *stored upload* is the previewed file, kept for a short time so that it can be applied (decision 1). *Nothing to change* means a plan with no added, changed or removed lot and no view change.

## Goals

- A collector who has previewed a file that can be applied applies it with one click, and the collection then holds exactly the file's lots: every added row is a lot, every changed lot has the file's quantity and times, every lot no row names is gone, and every unchanged lot is untouched.
- Applying is all or nothing: either every change is made or none is, whatever fails.
- Applying is idempotent: once a file is applied, the same file previews as nothing to change and an apply of it is refused, so a second application changes nothing, not even a lot's `updated_at` (decision 12).
- What is applied is what the collector was shown. If the collection is not as the preview found it, nothing is written and the collector is shown what applying would do now.
- Applying touches `Current.account` only.
- The previewed upload is kept for a bounded time and no longer, per account, privately, and is removed when applied, replaced, refused, expired or when its account goes.
- The export → import round trip is tested: a collection exported and applied into an empty account of the same catalog is restored and exports to the same collection (the export format's rule), the profile's name and email address apart.

## Non-Goals

- Applying a file with problem rows, in part or with those rows skipped (spec 025 decision 2 stands; decision 4 below).
- Undoing an applied import. The collector's way back is the export they download first (decision 6); the page says so.
- A background job for applying (decision 3). The one background job added is the sweep of expired uploads (decision 9).
- Merging a file into a collection instead of replacing it (spec 025 decision 1 stands).
- Downloading, listing or showing a stored upload: it is read by the app only.
- Backup and restore of a whole instance (#41), upgrade proof (#42), files from other tools, CSV, or any format but `collector-export` version 1.
- Repairing rows, choosing another printing for an unresolved id, an admin import, or importing into another account (hosted-door rule 2).
- Any change to the format, its schema or its examples, or to what spec 025 refuses or reports (spec 025's rule about writing is superseded by decision 10).

## Decisions

Decisions 1, 3, 6, 7, 9 and 10 were ruled by the maintainer on 2026-10-20, through the coordinator, 6, 7, 9 and 10 as recommended; decisions 2, 4, 5 and 8, which follow from spec 025, issue #40 and ADR 0013, were confirmed with them. After the independent review the maintainer ruled further (2026-10-20): decision 3's hard write-transaction bar, decision 12, the gated Active Storage routes and removals of decisions 8 and 9, the sweep in development, and confirmed decision 11, FR-3's bulk-write exception and the catalog-refresh accepted limit. Nothing below is labelled *proposed*; P1 to P4 were ruled on 2026-10-20 (version 1.3.1).

### 1. The previewed upload is stored briefly and applied with one click (ruled)

Spec 025 left open how the file reaches the apply step. The maintainer ruled: the upload is stored via Active Storage, scoped to `Current.account`, with an expiry and clean-up, and applied with one click from the preview. This is the first Active Storage upload, so decision 8 carries ADR 0013's owed validation.

- A preview that can be applied, and has something to change, stores its file and shows an "Apply import" button. Applying reads the stored file, judges it again exactly as the preview does, and applies it.
- A file that is refused, has problem rows, or has nothing to change is not stored (there is nothing to apply, and storage stays bounded).
- An account has at most one stored upload. A new preview that stores a file replaces the account's earlier one, which is removed. A preview that doesn't store one leaves the earlier one alone.
- The alternative not chosen: ask the collector to choose the file again at the apply, with the fingerprint carried in the form. It stores nothing but costs a second file choice, and spec 025's preview is where the collector looked.

### 2. What is applied is what was previewed: the fingerprint (confirmed)

The stored upload carries the fingerprint of the plan the preview showed, and the apply form carries the same fingerprint in a hidden field. Applying recomputes the plan inside its write transaction (decision 3) and writes only when the form's fingerprint, the stored one and the recomputed one are all equal. Otherwise nothing is written: the collector is shown the preview of the stored file against the collection as it is now (with a new fingerprint, stored with the upload and put in the new form), and a line saying that the collection or the stored file changed since they looked. A request whose upload is missing, expired or already applied is treated as in AC-3.3. The order in which an apply's checks run is decision 13's.

The fingerprint covers: the checksum of the stored file; the row number and outcome of every added and changed row; for every changed and removed lot, its id, quantity and `updated_at` at full precision, not truncated to the second (ruled 2026-10-20, P2); and the view change, if any. So it changes when the collector (or a scanner sitting, or another tab) adds, edits or removes a lot between the preview and the apply, when a catalog change makes a row stop resolving, and when another preview replaced the stored file. It is not a secret: a collector who forges it only gets a refusal (it must equal the stored one) or applies their own stored file to their own collection.

The alternative not chosen: apply whatever the file does to the collection at the moment of the request, and report it afterwards. Replacement is destructive, and a collector who previewed "2 lots removed" could silently lose a third.

### 3. Applying runs in the request, in one short write transaction (ruled)

The maintainer ruled: in the request, parse and resolve outside the transaction, then one short all-or-nothing write transaction. On 2026-10-20 he made the transaction's bar a hard one (below). If the bar can't be met, the maintainer rules on a fallback (a job on the stored upload that decision 1 has).

- **In the request, not a job.** Applying is one request: reading the stored file, judging and resolving it happens first, outside any transaction (the work spec 025 measured at about 10.6 s for 50,000 rows); then one write transaction. `.claude/rules/background-jobs.md` asks for large work to be split into batches and jobs, but all or nothing (issue #40) means one transaction. It holds writes, one read of the account's lots and the comparison of the plan's fingerprint (FR-2), and no parsing, no catalog lookups and no network (`.claude/rules/sqlite-and-migrations.md`).
- **Bar (ruled 2026-10-20):** a 50,000-row file applies, the whole request, in under 30 seconds with under 500 MB of RSS growth (spec 025 decisions 12 and 13), and the write transaction, from its start to its commit and counting that read and comparison, takes **under 4 seconds**. 4 seconds is below the 5-second busy timeout of every database (`config/database.yml`), so any other writer (a scanner add, a number-entry add, a lot edit, a catalog refresh) that meets the apply's lock always waits and then runs; none fails because of it. The bar is hard: it is measured outside the suite and recorded in `verification.md` (AC-1.10). 30 seconds is also kamal-proxy's default response timeout, so the whole-request bar is a limit, not a goal.
- **Writers are serialised.** SQLite's IMMEDIATE transactions allow one writer; another write to the account's lots waits for the apply's transaction (at most 4 seconds) and then proceeds against the applied collection.

### 4. A file with problem rows can't be applied; held lots stay (from spec 025 decision 2; confirmed)

Spec 025 decision 2 says a file with a problem row can't be applied. This spec makes that true of the apply: no upload is stored for such a file, no apply button is shown, and an apply whose stored file now has problem rows (the catalog changed in between) is refused (422) with the preview's reasons, nothing written. So the *held by a problem row* outcome exists only in a preview; it never reaches the apply, and a lot held by a problem row is never removed. The collector fixes the file, or the catalog (a refresh that loads the missing printings), and previews again.

### 5. Replace, exactly (from spec 025 decision 1; confirmed)

Applying a file that can be applied, to the collection as the preview found it:

- **Added:** a lot is created for the row, with the file's quantity, finish, condition and price paid, and `created_at` and `updated_at` taken from `added_at` and `changed_at`. The collection's lots are the file's, so the times are the file's too (a row carries them for this, spec 017).
- **Changed:** the existing lot (same lot, same id, so anything that points at it stays pointed) is set to the file's quantity and times. The quantity is replaced, never summed.
- **Unchanged:** nothing is written to it. Its `updated_at` stays as it was.
- **Removed:** the lot is deleted.
- **Profile:** `collection_view` is set to the file's when it is a view the instance knows and differs from the collector's (spec 025 decision 4). Name and email address are never changed. A view the instance doesn't know is ignored.

Afterwards the account's lots are in one-to-one correspondence with the file's rows by lot identity. Every lot written is one `Lot` would accept (AC-2.4).

### 6. Before applying, the collector can export what they have (ruled)

Applying replaces the collection and has no undo, so the page leads the collector to the safeguard the product already has. The page states in words how many lots and copies applying removes and links to "Export collection" ("Download your current collection first"). When the plan removes any lot, the apply button is replaced by a form with a checkbox, "I understand this removes N lots", which must be checked to apply; with nothing to remove there is no checkbox. The alternatives not chosen: a link with no checkbox; a forced export (a download can't be required).

### 7. Working state that points at lots is cleared (ruled)

Four kinds of per-account working state refer to lots, and a replaced collection makes them wrong: an Undo on a number-entry line or a scanner sitting entry subtracts copies from a lot that now holds the file's quantity; a bulk removal's undo (`BulkRemoval#undo!`, which adds its lots back through `Lot.add!`) would bring back lots the file removed, or add their copies to lots the file set; a bulk selection holds lot ids that may be deleted. Applying therefore, in the same transaction, ends every bulk removal's chance to undo, deletes the account's bulk selections, and clears the account's number-entry list and scanner sitting (the effect of "Done", specs 026 and 009), whenever the apply writes. An apply that is refused, including one with nothing to change (decision 12), clears nothing. Nothing the collector owns is lost: what those lists added is already in the lots. The alternative not chosen: leave them and let Undo fail where it must.

### 8. The stored upload is validated and private (ADR 0013's owed validation; confirmed)

ADR 0013 and `.claude/rules/security.md` owe validation to the first Active Storage upload. For the stored upload:

- **Content type:** judged by content, never by the type or name the browser declares (spec 025 decision 6). A file is stored only after it has been read as UTF-8 JSON that is an export; the blob is recorded with the type `application/json`, whatever the browser declared and whatever name it carried (the name is not kept; the blob is named for the account and time).
- **Size:** at most `CollectionImport::MAX_BYTES` (32 MB), checked before the file is read or stored; the 40 MB body caps of spec 025 decision 6 still apply to the upload request.
- **Pixel limits:** none, since it is no image. No variants are made for it, and none of ADR 0013's libvips transformers touch it.
- **Tenant-scoped; routes gated (ruled 2026-10-20):** the stored upload belongs to its account and is reached by the app only as `Current.account`'s. No page, response, header or link includes its URL, key or signed id. Active Storage's routes stay drawn, but every one of them (blobs, representations, direct uploads) is gated behind sign-in and a tenant check: a blob can be fetched only by a signed-in collector whose account owns it. This holds app-wide, so every later upload (ADR 0013's expected image variants) inherits it, and the upload-retention ADR records that consequence. There is no permanent or public blob URL (AC-1.12).
- **Created analyzed (ruled 2026-10-20):** the blob is created already identified and analyzed, with its type and size known, so Active Storage enqueues no analysis job for it.
- **Installation (ruled 2026-10-20):** Active Storage's tables aren't in the schema yet (the engine is required but never installed). The plan adds the framework's install migration (blobs, attachments and variant records), which must be safe to run unattended from any prior version.
- **Disk:** it is stored by the configured Active Storage service (the disk under `storage/` in every deployment, on the persistent volume).

### 9. Retention, replacement and the sweep (ruled)

- **Expiry:** a stored upload expires 1 hour after it was stored (`ImportUpload::EXPIRES_IN`, ruled). An expired one is never applied: the apply says the preview has expired and asks the collector to choose the file again.
- **Removed when:** applied, refused at the apply (decision 4), replaced by a newer preview, expired, or its account is deleted. Every removal purges the blob and its file synchronously (`purge`, never `purge_later`), after and outside the write transaction, so no removal enqueues a job and nothing is left to a queue (ruled 2026-10-20). The sweep is the backstop for a removal that failed.
- **The sweep:** a recurring job (`config/recurring.yml`, queue `default`, every 15 minutes, in production and in development, where Solid Queue runs inside Puma; ruled 2026-10-20) removes every expired stored upload with its file, and every *orphan*. An orphan is an Active Storage blob that carries the import-upload marker (a fixed key in its metadata, set when the preview creates it), has no attachment, and was created more than 10 minutes ago (ruled 2026-10-20, P4); the delay keeps it from a blob a concurrent preview has created and not yet attached. The sweep only calls `purge` on such blobs and on expired uploads; it never lists, walks or deletes paths on disk, which also hold the databases and the catalog (`storage/`). It is idempotent and takes no argument.
- **A failed apply** (the transaction rolled back, or an apply refused for a plan changed, decision 2, or an unconfirmed removal) leaves the stored upload until it expires, so the collector can try again without choosing the file again.
- **Storage per account:** at most one file of at most 32 MB, for at most an hour (and an orphan at most 10 minutes more, then the sweep).
- **Coverage:** the stored upload's table has `account_id`, so the export format's Coverage table (a rule of the format, not a version change) gets a line for it: "Left out: transient working state; the file it holds is the collector's own export, already restored into the lots by applying it." `docs/export-format/README.md` changes only by that line; the version, the schema and the examples don't. The suite fails until it is there.
- **Expected ADR:** upload retention (what is stored, how long, where, and the sweep). It is written with the plan, and takes the next free number on `origin/main`'s `docs/adr` when written.

### 10. This supersedes spec 025's "never stored" (ruled)

Spec 025 decision 6 says the file is "read in the request and never stored", its goals say "Nothing is written: no lot, user, account or other row, no stored file, no job", AC-1.8 checks it, FR-6 says previewing creates, changes and deletes no row and writes no file, and its security and cost notes repeat it. After this spec the preview of a file that can be applied stores the upload (decision 1), and only that. Spec 025 isn't edited; this spec records the supersession here and in `docs/specs/README.md`, and the preview's specs are updated by this spec's plan:

- **Still true of the preview:** it creates, changes and deletes no lot, user or account, writes no cache entry, enqueues no job; a refused file, a file with problem rows and a file with nothing to change write nothing at all (AC-1.11).
- **Changed:** a file that can be applied and has something to change is stored, replacing the account's earlier stored upload.

### 11. The pages (confirmed 2026-10-20)

- Spec 025's preview page (`POST /collection/import_preview`) gains, for a stored upload, an "Apply import" form (decision 6) with no file field: it posts to `/collection/import` with the CSRF token and, when the plan removes lots, the confirmation checkbox. The stored upload is the account's, so the form names nothing else.
- `POST /collection/import`: applies the account's stored upload and redirects (303) to the collection with a notice that gives the counts ("Imported: 3 lots added, 2 changed, 1 removed"). When the plan has changed (decision 2) it answers 409 with the fresh preview; when the upload is missing, expired or unreadable, or the file is refused or has problem rows, or the plan has nothing to change, or the removal isn't confirmed, 422. Routed in the `collection` resource's `collections` module as `resource :import, only: %i[create]`: `Collections::ImportsController`.
- The form is submitted without Turbo Drive (`data-turbo="false"`), like the preview's, because it answers with renders on 409 and 422.
- A signed-in collector only, as every collection page.

### 12. An apply with nothing to change is refused (ruled 2026-10-20)

Because a preview with nothing to change stores no upload (decision 1), a post to `/collection/import` reaches a plan with nothing to change only when the collection changed after the preview (the file's changes were made some other way, for example by an earlier apply of it from another tab). The apply step refuses such a plan, whatever the fingerprints say, since nothing is at stake: 422, "This file has nothing to change", nothing written, and nothing cleared (decision 7 applies only when the apply writes). This is how applying the same file twice is idempotent: the first apply changes the collection, the second is refused, and the collection is as the first left it. The upload, if one is still stored, is removed.

### 13. The order of an apply's checks (ruled 2026-10-20, P1)

Each request is judged in this order, and the first that applies decides the response: no stored upload, or one past its expiry (422); the stored file can't be read (422); the file refused or with problem rows (422); a plan with nothing to change (422, decision 12); the form's, the stored and the recomputed fingerprints not all equal (409); a removal that isn't confirmed (422). So a request that is both stale and unconfirmed gets the 409 and a fresh preview, and one whose plan has become empty is told so rather than shown a stale page. Presence, expiry and the fingerprints are decided once, inside the write transaction, with the rest checked before it (FR-2).

## Users and Context

**Primary users:** a signed-in collector moving their collection onto a new instance, or restoring a backup file into their account.
**Usage context:** occasional; one file at a time, from their own export, on a desktop or a phone.
**User mental model:** "I looked at what this file does. Now do it, exactly that."

## User Stories

### Story 1: Apply a previewed file

**As a** collector
**I want** to apply a file I have previewed
**So that** my collection holds what the file describes

- [ ] **AC-1.1** Given a file that can be applied and has something to change When it is previewed Then the page holds a form posting to `/collection/import` with `data-turbo="false"` and the CSRF token, no file field, a button "Apply import", the counts of lots and copies to be added, changed and removed, and a link to "Export collection"; given a file with problem rows, a refused file, or a file with nothing to change Then neither the form nor the button is on the page
- [ ] **AC-1.2** Given held lots A (quantity 3, same identity, quantity and times as row 1), B (quantity 2, same identity as row 2, whose quantity is 5 and `changed_at` later), C (quantity 4, same as row 3) and D (quantity 7, no row has its identity), and row 4 (quantity 6) whose identity no lot has When the file is previewed and the apply is posted with the removal confirmed Then the response is 303 to the collection, and the collection holds exactly: A as it was, B with quantity 5 and the row's times (same id), C as it was, row 4 as a new lot of quantity 6 with the row's finish, condition, price and times, and no D
- [ ] **AC-1.3** Given a collector with no lots and a resolvable file of 3 rows When previewed and applied Then the collection holds those 3 lots and nothing else, each with the row's `added_at` as `created_at` and `changed_at` as `updated_at`
- [ ] **AC-1.4** Given a well-formed file with no lots and a collector with 2 lots, the removal confirmed When applied Then the collection holds no lots
- [ ] **AC-1.5** Given an applied file When the same file is previewed again Then every row is unchanged, the page says there is nothing to change, offers no apply, stores no upload, and no lot's attributes, `id` or `updated_at` differ from before the first apply
- [ ] **AC-1.6** Given a file that also changes at least one lot (so that an apply is offered; a view change alone also counts as something to change) and whose `collection_view` is the other known view When applied Then the collector's `collection_view` becomes it; given a view the instance doesn't know, or the collector's own, with the lot change Then the view doesn't change; given a file whose name or email address differs Then the user's name and email address are those from before
- [ ] **AC-1.7** Given a lot with a fractional `created_at` and `updated_at` and a row with the same identity, quantity and the times without the fraction Then it is unchanged and is not written to (spec 025 AC-1.6, now at apply)
- [ ] **AC-1.8** Given lots that number-entry lines and scanner sitting entries point at, a bulk selection and an undoable bulk removal, and a file that changes and removes some of those lots When applied Then the bulk removal can no longer be undone, the bulk selections are gone, the number-entry list and the scanner sitting are cleared, and no table holds a reference to a deleted lot; given an apply that is refused (a stale plan, no confirmation, nothing to change) Then none of them is cleared (decision 7)
- [ ] **AC-1.9** Given an apply that succeeded Then the stored upload, its blob and its file on disk are gone from the account, no job was enqueued, and a second post to `/collection/import` (a resubmitted form, a second tab) gets 422 with "Preview the file again." and writes nothing
- [ ] **AC-1.10** Measured outside the suite, for 50,000-row files: (a) all resolvable, applied to an empty account; (b) the same file applied to an account holding those 50,000 lots with every row changed; (c) an empty file (no lots) applied to an account of 50,000 lots, the removal confirmed (50,000 deletes, with the cascade to bulk selection marks). Each applies, the whole request, in under 30 seconds with under 500 MB RSS growth, and its write transaction (decision 3) in **under 4 seconds**, a hard bar. Also (ruled 2026-10-20, P3): the preview of the file of (a), which now also stores up to 32 MB, still meets spec 025 decision 12's 30 seconds and decision 13's 500 MB. The measurements and method are recorded in `verification.md`; if a bar is missed, the maintainer rules the fallback (decision 3)
- [ ] **AC-1.11** Given a preview of a refused file, a file with problem rows, or a file with nothing to change Then no row is created, changed or deleted in any table of the primary database (row counts, and `updated_at` maxima where the column exists, compared before and after), no file is stored and no job is enqueued; given a preview of a file that can be applied Then the only rows created are the account's one upload record and its blob and attachment (an earlier upload's removed with its file), no lot, user or account row changes, and no job is enqueued (the blob is created analyzed, decision 8)
- [ ] **AC-1.12** Given a stored upload Then no response from the app contains its blob's URL, key or signed id; and given a valid signed id for its blob, a request to Active Storage's blob route signed out is sent to sign in and returns no content, signed in as another account returns no content (404), and only signed in as the owning account returns the content (decision 8)

### Story 2: All or nothing, and safe to repeat

**As a** collector
**I want** an import to either complete or leave my collection as it was
**So that** a failure never leaves me with half a collection

- [ ] **AC-2.1** Given a file that can be applied and an exception raised after the lot writes have begun (after the first write statement; injected in the spec through a stubbed collaborator of the apply step, not `Lot` or ActiveRecord itself) Then no lot is created, changed or deleted, no view or working state changes, the stored upload and its file are still there, the response is 500 with a page saying nothing was changed, and a following apply (no failure) of the same upload succeeds
- [ ] **AC-2.2** Given a file applied, and the same stored upload still present (kept by the spec) When a second apply is posted for it (with the first's fingerprint, now stale) Then the response is 422 "This file has nothing to change", no row of any table is created, changed or deleted, no working state is cleared, and every lot's attributes and `updated_at` are those after the first apply (decision 12)
- [ ] **AC-2.3** Given two apply requests for the same stored upload that arrive together Then exactly one writes (the first to take the write lock), and the other, whether it finds the upload gone, its file missing or the plan changed, answers 422 "Preview the file again." (or 409 with a fresh preview when the upload is still there and the plan changed) and writes nothing; neither answers 500
- [ ] **AC-2.4** Given any applied file Then every lot of the account passes `Lot`'s validations (quantity 1 to 9,999; finish offered by its printing; condition known; price paid not negative), carries the `lot_key` that `Lot.key_for` gives it, and its identity in the database matches its row's
- [ ] **AC-2.5** Given an upload that expires, is replaced or is swept after the request began reading it and before the transaction (simulated in the spec by removing it at that point) Then the response is 422 "Preview the file again." and nothing is written (FR-2)

### Story 3: What was previewed is what is applied

**As a** collector
**I want** nothing to be applied that I didn't see
**So that** a change made in between never costs me a lot

- [ ] **AC-3.1** Given a stored upload and a lot of the collection removed, added or edited after the preview When the apply is posted Then the response is 409, no lot is created, changed or deleted, the page shows the preview of the stored file against the collection as it now is with a new apply form, and says that the collection changed since the preview
- [ ] **AC-3.2** Given a stored upload replaced by a newer preview of another file (another tab), and an apply posted from the older page with its older fingerprint Then the response is 409, nothing is written, and the page shows the preview of the file now stored with its own fingerprint
- [ ] **AC-3.3** Given an apply for an account with no stored upload, or one past its expiry Then the response is 422, the upload page is shown with "Your preview has expired. Choose the file again." for an expired one and "Preview the file again." when none is stored, and nothing is written
- [ ] **AC-3.4** Given a stored upload whose file has become not applicable by the time of the apply (the catalog changed so a row no longer resolves, or the catalog was emptied) Then the response is 422 with the preview's reasons for the file, nothing is written, and the stored upload and its file are removed (decision 4)
- [ ] **AC-3.5** Given a plan that removes lots and a request with the checkbox not checked Then the response is 422 with "Confirm the removal to apply this file", nothing is written and the upload stays; given a plan that removes no lots Then no checkbox is needed
- [ ] **AC-3.6** Given a request that is both stale and unconfirmed, or refused and stale, or a stale plan that has become one with nothing to change Then the response is the one decision 13's order gives (stale and unconfirmed: 409; refused and stale: 422 with the refusal; stale with nothing to change: 422 "nothing to change") and nothing is written. (ruled 2026-10-20, P1)
- [ ] **AC-3.7** Given two previews of the same file and collection, made apart Then their fingerprints are equal; given any change to a lot's quantity, either time or existence, to the stored file, or to the view change Then they differ

### Story 4: Only my collection

**As a** collector on a shared instance
**I want** applying a file to touch my collection only
**So that** nobody else's collection or upload is changed or shown

- [ ] **AC-4.1** Given two accounts that both own lots of a printing in the file, and a stored upload for each When the first collector applies Then the second account's lots, user, working state, views and upload are unchanged (row counts and `updated_at` of every table compared), and nothing of the second account's appears in any response
- [ ] **AC-4.2** Given a request that carries an `account_id`, an upload id or a lot id in any parameter (the fingerprint apart) Then it is ignored: the account applied to and the upload applied are the signed-in collector's (FR-5)
- [ ] **AC-4.3** Given a signed-out visitor, or a session that has ended When they post to `/collection/import` Then the response redirects to sign in, the reader isn't called and nothing is written
- [ ] **AC-4.4** Given an account with a stored upload When its user is deleted Then the upload record and its file are gone

### Story 5: The stored upload

**As a** collector and operator
**I want** the kept file to be small, private and short-lived
**So that** keeping it costs little and leaks nothing

- [ ] **AC-5.1** Given a file that can be applied When previewed Then one upload is stored for the account with a blob of type `application/json` whatever type and name the browser declared, no image analysis job or variant is made, and it expires `ImportUpload::EXPIRES_IN` after it was stored
- [ ] **AC-5.2** Given a second preview of another applicable file Then the account has one stored upload, the second, and the first's file is gone; given a preview that stores nothing Then the earlier upload stays
- [ ] **AC-5.3** Given an upload of more than 32 MB, or one that isn't an export Then nothing is stored (spec 025 AC-3.1 to AC-3.3 hold)
- [ ] **AC-5.4** Given stored uploads, some expired and some not, an orphan (a marked blob with no attachment, created more than 10 minutes ago), a fresh unattached marked blob (created a minute ago) and an unrelated blob with no marker When the sweep runs Then it purges every expired upload with its file and the old orphan, keeps the unexpired uploads, the fresh blob and the unrelated blob, touches no path on disk except through `purge`, and run again changes nothing
- [ ] **AC-5.5** Given `config/recurring.yml` Then the sweep is scheduled there every 15 minutes in production and in development (a spec reads the file); given the Coverage table in `docs/export-format/README.md` Then it has a line for the upload table, and the suite's coverage check passes (spec 017)
- [ ] **AC-5.6** Given an expired upload that the sweep has not yet run for When the collector applies Then it is treated as expired (AC-3.3), whatever the sweep's timing, judged once inside the write transaction

### Story 6: The round trip

**As a** collector (and the maintainer, for the 1.0 test)
**I want** an export that I apply to a fresh account to restore my collection
**So that** I can move instances and trust my backup

- [ ] **AC-6.1** Given a collection of lots of varied finishes, conditions, prices (some none), quantities and times, whose every lot resolves, exported with `CollectionExport` and previewed Then every row is unchanged, the page says there is nothing to change, and no upload is stored (the round trip's no-op half; spec 025 AC-1.3)
- [ ] **AC-6.2** Given the same export previewed and applied to an empty account on the same catalog Then the new account's lots match the first's one-to-one by identity, each with the same quantity, `created_at` and `updated_at` (to the second), and exporting the new account gives a file that holds *the same collection* as the original under the export format's rule ([*The same collection*](../../export-format/README.md#the-same-collection): lots equal as sets, `exported_at`, `generator` and lot order never counting), but for the profile's `name` and `email_address`, which are the new account's collector's, since applying never changes them (decision 5)
- [ ] **AC-6.3** Given the export of AC-6.2 with the original account's collection then changed (a lot edited, one removed, one added) and the file previewed and applied back Then the account's lots equal the file's again (the restore half), exporting gives a file that holds the same collection as the file, and previewing the file again says there is nothing to change. (Lot order is not compared: the added lot is written last.)
- [ ] **AC-6.4** Given each valid example in `docs/export-format/examples/valid/`, with the spec's instance currency set to the example's and a catalog the spec builds that holds the example's entries and finishes Then `collection.json` applies to an empty account and exporting the result holds the same collection as the example (its `generator` and `exported_at` not counting, the profile's name and email apart); and `empty.json`, which has nothing to change for an empty account, is previewed with nothing to change and no apply offered
- [ ] **AC-6.5** Outside the suite, once: an export of a development instance holding a real catalog is applied to a second, empty instance by hand through the pages, and the second instance's export is compared with the first; the steps and the result are recorded in `verification.md` (the 1.0 test's second check, as far as one instance pair shows it; the maintainer's own check of their real collection is theirs)

### Story 7: Reach it

**As a** collector
**I want** the apply where the preview is
**So that** I don't look for it

- [ ] **AC-7.1** Given a previewed file with an apply Then the apply form is on the preview page, below the counts and above the profile notes, with the lots and copies it removes stated in words, and the page says that applying has no undo and that the preview is kept for an hour
- [ ] **AC-7.2** Given a collector in the browser When they open "Import collection", choose an export file, press "Preview import" and press "Apply import" Then they are on the collection page, with a notice that gives the counts, and the collection shows the file's lots (system spec)
- [ ] **AC-7.3** Given the preview with an apply form, the stale-plan page, a refused apply and the notice after applying, at 1280px and 390px in both themes Then everything is shown in full and nothing scrolls sideways (screenshots in `verification.md`)
- [ ] **AC-7.4** The pages use only the design system's tokens and `c-*` classes; any new pattern is in `collector/additions.css` with its doc under `docs/design-system/components/` (verified by reading)

## Functional Requirements

- **FR-1** An apply step takes the account and its stored upload and either writes (every change of decision 5 and the clearing of decision 7) or refuses with the reason, in decision 13's order; it writes and clears nothing on a refusal, including a plan with nothing to change (decision 12). It builds on `CollectionImport` (spec 025): the reading of the file and its outcomes are not reimplemented, and the plan and its fingerprint come from them.
- **FR-2** Applying is one database transaction. The stored file is read, parsed, judged and resolved before it begins; a stored file that can't be read (removed by another apply, a newer preview or the sweep) is a 422, not a 500. Inside the transaction there are writes, one read of the account's lots and the comparison of fingerprints, and nothing else: it re-checks, once, that the account's upload is still there, not past its expiry and carrying the fingerprint of the form, recomputes the plan and compares, then writes the changes and the clearing and deletes the upload's record. Any failure rolls the transaction back; nothing outside it is written. After the commit and outside it, the blob and its file are purged synchronously (decision 9); the sweep removes them if that fails. The transaction takes under 4 seconds for 50,000 rows (decision 3).
- **FR-3** The writes use the same lot identity as `Lot` (`Lot.key_for`) and satisfy `Lot`'s validations (AC-2.4). Where the plan uses bulk statements that skip callbacks and validations (a documented exception to `.claude/rules/models.md`, for the 50,000-row bar; confirmed 2026-10-20), the rows written are the ones the reader already resolved and checked, and a spec checks them against `Lot`.
- **FR-4** The number of queries doesn't grow with each row: the lots are read in one statement and written in a bounded number of statements (batched only past a fixed size, below SQLite's limit on bound values), as for the preview.
- **FR-5** Everything is read and written through `Current.account`, including the stored upload (`Current.account`'s one upload). No parameter names an account, an upload or a lot; the one parameter besides the confirmation is the fingerprint (decision 2).
- **FR-6** The file's content is never logged; its field stays filtered from the logs (spec 025 FR-6), and the stored file is read only by the app. Responses carry `Cache-Control: no-store`.
- **FR-7** The upload is limited and judged by content exactly as the preview's (spec 025 decision 6), before anything is stored (decision 8).
- **FR-8** The files of the apply and the stored upload under `app/models/`, their controller and their views contain neither `MTG` nor `Scryfall` (a spec in the style of spec 025 FR-9).
- **FR-9** A changed lot keeps its id; no lot is deleted and recreated to change it (decision 5).
- **FR-10** The stored upload is a tenant-owned table with `account_id`, indexed, with a unique index so an account has at most one (decision 1).

## Non-Functional Requirements

- **Cost per account (hosted-door rule 4).** Storage: at most one file of at most 32 MB per account, for at most 1 hour (decision 9), and the lots the collector's file describes. Background work: none per account; one recurring sweep for the instance, every 15 minutes, whose cost is the number of expired uploads and orphans. Per apply: one request that reads at most 32 MB, and one write transaction of at most one statement batch per 1,000 lots. AC-1.10 holds a 50,000-row file to the bars of decision 3, the write transaction to under 4 seconds. A limit on imports per account is a hosted-service feature (north star, Not before 1.0).
- **Hosted-door rules.** Rule 1: no source is adopted. Rule 2: a collector applies into their own collection only; no admin page reads a file, an upload or a collection (the admin catalog and jobs pages show only the sweep's job record). Rule 3: no setting is added (the expiry is a constant). Rule 4: as above.
- **Data safety.** All or nothing (AC-2.1); no apply without a matching preview (decision 2); a removal needs a confirmation (AC-3.5); the export is one click away (decision 6).
- **Security.** The upload is a CSRF-protected form; the stored file is validated (decision 8), private to its account and fetchable only through Active Storage's gated routes by its owner; Brakeman stays clean; no mass assignment of lot, upload or account attributes from the request. ADR 0013's owed validation is met here, and CLAUDE.md's note of it is updated.
- **Format.** Version 1, unchanged. The upload table is left out of the export (decision 9). If a later spec adds a column to `lots`, the round-trip specs of Story 6 fail until applying handles it (spec 017's Coverage rule, in effect).
- **Testability.** Request specs for every response, model specs for the plan, fingerprint, apply and sweep, the round trip (Story 6), one system spec for the flow.

## Error Scenarios

| Situation | What happens |
|---|---|
| File refused as a whole, or with problem rows, at the preview | As spec 025; nothing is stored (AC-1.11) |
| Stored file refused or with problem rows at the apply | 422, the reasons as the preview gives them, nothing written, the upload removed (AC-3.4) |
| Plan, or the form's fingerprint, differs from the stored upload's | 409, fresh preview of the stored file with a new fingerprint, nothing written (AC-3.1) |
| No upload, expired, or already applied | 422, the upload page, nothing written (AC-1.9, AC-3.3, AC-5.6) |
| The stored file can't be read (removed by another apply, a newer preview or the sweep) | 422 "Preview the file again.", nothing written (AC-2.3, AC-2.5) |
| The plan has nothing to change | 422 "This file has nothing to change", nothing written or cleared (AC-2.2) |
| Removal not confirmed | 422, nothing written, the upload stays (AC-3.5) |
| A write fails (constraint, disk full) | The transaction rolls back; 500 with a page saying nothing was changed and the collector may try again; the upload stays (AC-2.1). The apply's own write cannot fail on the busy timeout past its wait: another writer holds the lock for under 4 seconds when it does (decision 3), and if the apply cannot take the lock within 5 seconds it fails as any write does, with nothing changed |
| Storing the preview's file fails | The preview shows the counts but no apply button, and says the file couldn't be kept; nothing else is written (ruled 2026-10-20; failing the whole preview instead was not chosen) |
| The catalog is refreshed during an apply | Entries are never deleted (retired instead), so a row still resolves. A finish a refresh stops listing between resolving and writing is accepted: the lot is written, and later edits to it meet the usual finish check (accepted limit, confirmed 2026-10-20) |
| A scanner, number-entry, lot-edit or refresh write lands during the apply | It waits for the write transaction (under 4 seconds, below the busy timeout, so it does not fail) and then runs against the applied collection |
| Two browser tabs apply | One commits and removes the upload; the other gets 422 or 409, never 500 (AC-2.3) |
| The session ended when the form is submitted | Redirect to sign in; the collector previews again (AC-4.3) |
| A form posted with no session cookie | Fails CSRF protection first, as for any such request (422), as spec 025 says |

## Supersedes

- Spec 025 decision 6 ("read in the request and never stored"), its Goal "Nothing is written … no stored file", AC-1.8, FR-6's "writes no file" and its Security and Cost notes on never storing, for a file that can be applied and has something to change (decision 10). Spec 025 is not edited; this line and the row in [`docs/specs/README.md`](../README.md) carry it.

## Documents that change

- `CLAUDE.md`: the status line ("applying an import isn't built yet"), the "Import preview" fact (it stores the upload now) and the Active Storage fact ("ADR 0013's owed validation stays with the first Active Storage upload" is met by this feature).
- `README.md`: the "Your data" paragraph; the 40 MB limit; that a previewed file is kept for an hour.
- `docs/roadmap.md`: theme A item 5 marked done.
- `docs/adr/`: the upload-retention ADR (decision 9; it records the gated Active Storage routes and their consequence for ADR 0013's future uploads) and its line in `docs/adr/README.md`; `docs/adr/0013-active-storage-variants-with-vips.md` links to it from its consequence about the owed validation.
- `docs/export-format/README.md`: the Coverage table's new line, and nothing else.
- `docs/architecture/`: the data portability and the release-and-deploy area docs, if they exist by then (spec 027 slice C, #108, #109), else the areas stay listed as not written.
- `docs/specs/README.md`: this spec's row (done with the draft), and the "Superseded by" cell of spec 025 (decision 10) in the plan's documentation task, so that both directions are recorded when this spec ships (`.claude/rules/documentation.md`).
- `db/migrate/`: Active Storage's install migration (decision 8), in the same pull request as the apply, the sweep and the storage, so that `main` stays releasable.
- `docs/design-system/components/` for the apply form and the stale-plan notice, if new patterns.

Each is verified by reading.

## Open Questions

None of the maintainer's questions is open. Ruled 2026-10-20: decisions 1, 3 (with the hard 4-second transaction bar), 6, 7 (clearing only when the apply writes), 9 (with the synchronous purge and the sweep in development), 10, 12, and the Active Storage gating, created-analyzed blobs and install migration of decision 8; the error scenario for a failed store; and confirmed decisions 2, 4, 5, 8 and 11, FR-3's bulk-write exception and the catalog-refresh accepted limit.

Ruled 2026-10-20 (version 1.3.1): **P1** the order of an apply's checks (decision 13, AC-3.6), nothing to change checked before the fingerprint; **P2** the fingerprint hashes lots' `updated_at` at full precision (decision 2); **P3** AC-1.10's removal-heavy case and the preview re-measure with the store; **P4** the sweep purges an orphan only after 10 minutes (decision 9, AC-5.4).

## Out of Scope

Undo of an import, partial application, merge semantics, a background job for applying (unless the bar fails and the maintainer rules it), downloading or showing a stored upload, other formats and other tools' files, repairing rows, backup and restore of an instance (#41), upgrade proof (#42), an admin import, and the format document's version, schema and examples.
