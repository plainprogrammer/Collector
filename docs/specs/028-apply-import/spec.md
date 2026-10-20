# Feature 028: Apply an Import

**Status:** Approved by the maintainer (2026-10-20), with rulings on decisions 1, 3, 6, 7, 9 and 10 and the error scenario for a failed store; decisions 2, 4, 5 and 8 confirmed
**Version:** 1.2.0
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
| 1.2.0 | 2026-10-20 | Approved by the maintainer: decisions 6, 7, 9 and 10 and the error scenario "Storing the preview's file fails" ruled as recommended; decisions 2, 4, 5 and 8 confirmed. No open questions remain |
| 1.1.1 | 2026-10-20 | Mode A review fixes (verdict in `review.md`): the form carries the fingerprint, so an apply from a page whose upload was replaced is refused (decision 2, AC-3.2); AC-3.3, AC-5.6 and the error rows made exact; the open marker removed |
| 1.1.0 | 2026-10-20 | The maintainer ruled decisions 1 and 3 (through the coordinator): the previewed upload is stored briefly with Active Storage and applied with one click; applying runs in the request in one short write transaction. Added the stored upload (decisions 1, 8, 9), its retention and sweep (decision 9) and ADR 0013's owed validation (decision 8), the supersession of spec 025's "never stored" (decision 10), and the Coverage line |

---

## Problem Statement

A collector can take their collection out of Collector (spec 022) and see what an export file would do to their collection (spec 025), but cannot make it so. Restoring an export into a fresh instance is the 1.0 test's second check ("an export of that instance has been restored into a fresh instance and matched"), and no part of the app can do it.

This spec builds the second half of import. A signed-in collector who has previewed a file applies it with one click, and their collection then holds exactly what the file describes. It is all or nothing, applying the same file twice leaves the collection as the first application did, and it touches the collector's own account only. It ships with the export → import round-trip test that the 1.0 test's second check relies on.

> **Inputs.** The export format document ([`docs/export-format/README.md`](../../export-format/README.md)), `v1.schema.json` and the examples are fixed inputs, as they were for spec 025: this spec reads format version 1 and changes none of them except the Coverage table's new line (decision 9). The reading of a file (`CollectionImport`, spec 025) is reused as it is: its refusals, its problem rows and its outcomes (spec 025 decisions 1, 2, 9, 10) keep their meaning and are not restated here except where applying needs them.
>
> **Terms.** *File*, *row*, *problem row*, *held lot*, *preview* and *applying* are as in spec 025. The *outcomes* are spec 025 decision 1's: added, changed, unchanged, held by a problem row, removed. The *plan* of a file is what applying it to the collection as it is now would do: for each added, changed and removed entry, which row or lot and the quantity and times involved, and whether the collection view would change. The *fingerprint* of a plan is a short digest of the stored file's checksum and the plan, kept with the stored upload when the preview is made, shown to the browser in the apply form, and checked when applying (decision 2). The *stored upload* is the previewed file, kept for a short time so that it can be applied (decision 1). *Nothing to change* means a plan with no added, changed or removed lot and no view change.

## Goals

- A collector who has previewed a file that can be applied applies it with one click, and the collection then holds exactly the file's lots: every added row is a lot, every changed lot has the file's quantity and times, every lot no row names is gone, and every unchanged lot is untouched.
- Applying is all or nothing: either every change is made or none is, whatever fails.
- Applying is idempotent: applying the same file a second time changes nothing, not even a lot's `updated_at`.
- What is applied is what the collector was shown. If the collection is not as the preview found it, nothing is written and the collector is shown what applying would do now.
- Applying touches `Current.account` only.
- The previewed upload is kept for a bounded time and no longer, per account, privately, and is removed when applied, replaced, expired or when its account goes.
- The export → import round trip is tested: a collection exported and applied into an empty account of the same catalog is restored and exports to the same file.

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

Decisions 1, 3, 6, 7, 9 and 10 were ruled by the maintainer on 2026-10-20, through the coordinator, 6, 7, 9 and 10 as recommended; decisions 2, 4, 5 and 8, which follow from spec 025, issue #40 and ADR 0013, were confirmed with them.

### 1. The previewed upload is stored briefly and applied with one click (ruled)

Spec 025 left open how the file reaches the apply step. The maintainer ruled: the upload is stored via Active Storage, scoped to `Current.account`, with an expiry and clean-up, and applied with one click from the preview. This is the first Active Storage upload, so decision 8 carries ADR 0013's owed validation.

- A preview that can be applied, and has something to change, stores its file and shows an "Apply import" button. Applying reads the stored file, judges it again exactly as the preview does, and applies it.
- A file that is refused, has problem rows, or has nothing to change is not stored (there is nothing to apply, and storage stays bounded).
- An account has at most one stored upload. A new preview that stores a file replaces the account's earlier one, which is removed. A preview that doesn't store one leaves the earlier one alone.
- The alternative not chosen: ask the collector to choose the file again at the apply, with the fingerprint carried in the form. It stores nothing but costs a second file choice, and spec 025's preview is where the collector looked.

### 2. What is applied is what was previewed: the fingerprint (confirmed)

The stored upload carries the fingerprint of the plan the preview showed, and the apply form carries the same fingerprint in a hidden field. Applying recomputes the plan inside its write transaction (decision 3) and writes only when the form's fingerprint, the stored one and the recomputed one are all equal. Otherwise nothing is written: the collector is shown the preview of the stored file against the collection as it is now (with a new fingerprint, stored with the upload and put in the new form), and a line saying that the collection or the stored file changed since they looked. A request whose upload is missing, expired or already applied is treated as in AC-3.3.

The fingerprint covers: the checksum of the stored file; the row number and outcome of every added and changed row; for every changed and removed lot, its id, quantity and both times; and the view change, if any. So it changes when the collector (or a scanner sitting, or another tab) adds, edits or removes a lot between the preview and the apply, when a catalog change makes a row stop resolving, and when another preview replaced the stored file. It is not a secret: a collector who forges it only gets a refusal (it must equal the stored one) or applies their own stored file to their own collection.

The alternative not chosen: apply whatever the file does to the collection at the moment of the request, and report it afterwards. Replacement is destructive, and a collector who previewed "2 lots removed" could silently lose a third.

### 3. Applying runs in the request, in one short write transaction (ruled)

The maintainer ruled: in the request, parse and resolve outside the transaction, then one short all-or-nothing write transaction, with the measured bar below. If the bar is missed, the maintainer rules on a fallback (a job and a stored upload, the stored upload now being what decision 1 has).

- **In the request, not a job.** Applying is one request: reading the stored file, judging and resolving it happens first, outside any transaction (the work spec 025 measured at about 10.6 s for 50,000 rows); then one write transaction does the writes. `.claude/rules/background-jobs.md` asks for large work to be split into batches and jobs, but all or nothing (issue #40) means one transaction; it holds writes only, with no parsing, no catalog lookups and no network inside it (`.claude/rules/sqlite-and-migrations.md`).
- **Bar:** a 50,000-row file applies, the whole request, in under 30 seconds, of which the write transaction is under 10 seconds, with under 500 MB of RSS growth (spec 025 decisions 12 and 13), measured outside the suite and recorded in `verification.md` (AC-1.10). 30 seconds is also kamal-proxy's default response timeout, so the bar is a limit, not a goal.
- **Writers are serialised.** SQLite's IMMEDIATE transactions allow one writer; another request writing to the account's lots while the apply's transaction runs waits (the busy timeout) and then proceeds against the applied collection.

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

### 6. Before applying, the collector can export what they have (proposed)

Applying replaces the collection and has no undo, so the page leads the collector to the safeguard the product already has. The page states in words how many lots and copies applying removes and links to "Export collection" ("Download your current collection first"). When the plan removes any lot, the apply button is replaced by a form with a checkbox, "I understand this removes N lots", which must be checked to apply; with nothing to remove there is no checkbox. The alternatives not chosen: a link with no checkbox; a forced export (a download can't be required).

### 7. Working state that points at lots is cleared (ruled)

Four kinds of per-account working state refer to lots, and a replaced collection makes them wrong: an Undo on a number-entry line or a scanner sitting entry subtracts copies from a lot that now holds the file's quantity; a bulk removal's undo would bring back lots that clash with the imported ones; a bulk selection holds lot ids that may be deleted. Applying therefore, in the same transaction, ends every bulk removal's chance to undo, deletes the account's bulk selections, and clears the account's number-entry list and scanner sitting (the effect of "Done", specs 026 and 009), whatever the plan. Nothing the collector owns is lost: what those lists added is already in the lots. The alternative not chosen: leave them and let Undo fail where it must.

### 8. The stored upload is validated and private (ADR 0013's owed validation; confirmed)

ADR 0013 and `.claude/rules/security.md` owe validation to the first Active Storage upload. For the stored upload:

- **Content type:** judged by content, never by the type or name the browser declares (spec 025 decision 6). A file is stored only after it has been read as UTF-8 JSON that is an export; the blob is recorded with the type `application/json`, whatever the browser declared and whatever name it carried (the name is not kept; the blob is named for the account and time).
- **Size:** at most `CollectionImport::MAX_BYTES` (32 MB), checked before the file is read or stored; the 40 MB body caps of spec 025 decision 6 still apply to the upload request.
- **Pixel limits:** none, since it is no image. No variants or image analysis are made for it, and none of ADR 0013's libvips transformers touch it.
- **Tenant-scoped, never served:** the stored upload belongs to its account and is reached only as `Current.account`'s. No page, response, header or link includes its URL, key or signed id, and the app's Active Storage routes can't be used to fetch it (AC-1.12). There is no permanent or public blob URL.
- **Disk:** it is stored by the configured Active Storage service (the disk under `storage/` in every deployment, on the persistent volume).

### 9. Retention, replacement and the sweep (ruled)

- **Expiry:** a stored upload expires 1 hour after it was stored (`ImportUpload::EXPIRES_IN`, ruled). An expired one is never applied: the apply says the preview has expired and asks the collector to choose the file again.
- **Removed when:** applied (after the transaction commits), replaced by a newer preview, expired, or its account is deleted.
- **The sweep:** a recurring job (`config/recurring.yml`, queue `default`, every 15 minutes) removes every expired stored upload with its file and any stored file whose upload record is gone. It is idempotent and takes no argument.
- **A failed apply** (the transaction rolled back) leaves the stored upload until it expires, so the collector can try again without choosing the file again.
- **Storage per account:** at most one file of at most 32 MB, for at most an hour.
- **Coverage:** the stored upload's table has `account_id`, so the export format's Coverage table (a rule of the format, not a version change) gets a line for it: "Left out: transient working state; the file it holds is the collector's own export, already restored into the lots by applying it." `docs/export-format/README.md` changes only by that line; the version, the schema and the examples don't. The suite fails until it is there.
- **Expected ADR:** upload retention (what is stored, how long, where, and the sweep). It is written with the plan, and takes the next free number on `origin/main`'s `docs/adr` when written.

### 10. This supersedes spec 025's "never stored" (ruled)

Spec 025 decision 6 says the file is "read in the request and never stored", its goals say "Nothing is written: no lot, user, account or other row, no stored file, no job", AC-1.8 checks it, FR-6 says previewing creates, changes and deletes no row and writes no file, and its security and cost notes repeat it. After this spec the preview of a file that can be applied stores the upload (decision 1), and only that. Spec 025 isn't edited; this spec records the supersession here and in `docs/specs/README.md`, and the preview's specs are updated by this spec's plan:

- **Still true of the preview:** it creates, changes and deletes no lot, user or account, writes no cache entry, enqueues no job; a refused file, a file with problem rows and a file with nothing to change write nothing at all (AC-1.11).
- **Changed:** a file that can be applied and has something to change is stored, replacing the account's earlier stored upload.

### 11. The pages

- Spec 025's preview page (`POST /collection/import_preview`) gains, for a stored upload, an "Apply import" form (decision 6) with no file field: it posts to `/collection/import` with the CSRF token and, when the plan removes lots, the confirmation checkbox. The stored upload is the account's, so the form names nothing else.
- `POST /collection/import`: applies the account's stored upload and redirects (303) to the collection with a notice that gives the counts ("Imported: 3 lots added, 2 changed, 1 removed"). When the plan has changed (decision 2) it answers 409 with the fresh preview; when the upload is missing or expired, or the file is refused or has problem rows, or the removal isn't confirmed, 422. Routed in the `collection` resource's `collections` module as `resource :import, only: %i[create]`: `Collections::ImportsController`.
- The form is submitted without Turbo Drive (`data-turbo="false"`), like the preview's, because it answers with renders on 409 and 422.
- A signed-in collector only, as every collection page.

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
- [ ] **AC-1.6** Given a file whose `collection_view` is the other known view When applied Then the collector's `collection_view` becomes it; given a view the instance doesn't know, or the collector's own Then it doesn't change; given a file whose name or email address differs Then the user's name and email address are those from before
- [ ] **AC-1.7** Given a lot with a fractional `created_at` and `updated_at` and a row with the same identity, quantity and the times without the fraction Then it is unchanged and is not written to (spec 025 AC-1.6, now at apply)
- [ ] **AC-1.8** Given lots that number-entry lines and scanner sitting entries point at, a bulk selection and an undoable bulk removal, and a file that changes and removes some of those lots When applied Then the bulk removal can no longer be undone, the bulk selections are gone, the number-entry list and the scanner sitting are cleared, and no table holds a reference to a deleted lot; given a file whose plan changes only one other lot Then they are cleared all the same (decision 7)
- [ ] **AC-1.9** Given an apply that succeeded Then the stored upload and its file are gone from the account, a second post to `/collection/import` gets 422 with "Preview the file again", and nothing is written by it
- [ ] **AC-1.10** Measured outside the suite: each of two 50,000-row files (all resolvable, applied to an empty account; the same file applied to an account holding those 50,000 lots with every row changed) applies, the whole request, in under 30 seconds, the write transaction in under 10, with under 500 MB RSS growth; the measurements and method are recorded in `verification.md` (decision 3)
- [ ] **AC-1.11** Given a preview of a refused file, a file with problem rows, or a file with nothing to change Then no row is created, changed or deleted in any table of the primary database (row counts, and `updated_at` maxima where the column exists, compared before and after), no file is stored and no job is enqueued; given a preview of a file that can be applied Then the only rows created are the account's one upload record and its blob and attachment, no lot, user or account row changes and no job is enqueued
- [ ] **AC-1.12** Given a stored upload Then no response from the app contains its blob's URL, key or signed id, and a request to Active Storage's blob routes with a valid signed id for it, signed in as its account or not, does not return its content

### Story 2: All or nothing, and safe to repeat

**As a** collector
**I want** an import to either complete or leave my collection as it was
**So that** a failure never leaves me with half a collection

- [ ] **AC-2.1** Given a file that can be applied and a failure raised while the third of its writes is made (injected in the spec) Then no lot is created, changed or deleted, no view or working state changes, the stored upload is still there, the response is 500 with a page saying nothing was changed, and a following apply (no failure) of the same upload succeeds
- [ ] **AC-2.2** Given the apply step called on an upload and then called again on a new preview of the same file against the changed collection (a plan with nothing to change) Then the second call writes nothing: no row of any table is created, changed or deleted, and every lot's attributes and `updated_at` are those after the first
- [ ] **AC-2.3** Given two apply requests for the same stored upload that arrive together Then exactly one writes; the other finds the upload gone or the plan changed and writes nothing
- [ ] **AC-2.4** Given any applied file Then every lot of the account passes `Lot`'s validations (quantity 1 to 9,999; finish offered by its printing; condition known; price paid not negative), carries the `lot_key` that `Lot.key_for` gives it, and its identity in the database matches its row's
- [ ] **AC-2.5** Given the apply is resubmitted by the browser after the 303 Then it gets 422 and writes nothing (AC-1.9)

### Story 3: What was previewed is what is applied

**As a** collector
**I want** nothing to be applied that I didn't see
**So that** a change made in between never costs me a lot

- [ ] **AC-3.1** Given a stored upload and a lot of the collection removed, added or edited after the preview When the apply is posted Then the response is 409, no lot is created, changed or deleted, the page shows the preview of the stored file against the collection as it now is with a new apply form, and says that the collection changed since the preview
- [ ] **AC-3.2** Given a stored upload replaced by a newer preview of another file (another tab), and an apply posted from the older page with its older fingerprint Then the response is 409, nothing is written, and the page shows the preview of the file now stored with its own fingerprint
- [ ] **AC-3.3** Given an apply for an account with no stored upload, or one past its expiry Then the response is 422, the upload page is shown with "Your preview has expired. Choose the file again." for an expired one and "Preview the file again." when none is stored, and nothing is written
- [ ] **AC-3.4** Given a stored upload whose file has become not applicable by the time of the apply (the catalog changed so a row no longer resolves, or the catalog was emptied) Then the response is 422 with the preview's reasons for the file, nothing is written, and the stored upload is removed (decision 4)
- [ ] **AC-3.5** Given a plan that removes lots and a request with the checkbox not checked Then the response is 422 with "Confirm the removal to apply this file", nothing is written and the upload stays; given a plan that removes no lots Then no checkbox is needed
- [ ] **AC-3.6** Given two previews of the same file and collection, made apart Then their fingerprints are equal; given any change to a lot's quantity, either time or existence, to the stored file, or to the view change Then they differ

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

- [ ] **AC-5.1** Given a file that can be applied When previewed Then one upload is stored for the account with a blob of type `application/json` whatever type and name the browser declared, no image analysis or variant is made, and it expires `ImportUpload::EXPIRES_IN` after it was stored
- [ ] **AC-5.2** Given a second preview of another applicable file Then the account has one stored upload, the second, and the first's file is gone; given a preview that stores nothing Then the earlier upload stays
- [ ] **AC-5.3** Given an upload of more than 32 MB, or one that isn't an export Then nothing is stored (spec 025 AC-3.1 to AC-3.3 hold)
- [ ] **AC-5.4** Given stored uploads, some expired and some not, and a stored file whose upload record is gone When the sweep runs Then it removes every expired upload with its file and the orphaned file, keeps the unexpired, and run again changes nothing
- [ ] **AC-5.5** Given `config/recurring.yml` Then the sweep is scheduled there every 15 minutes in every environment that runs the queue (a spec reads the file); given the Coverage table in `docs/export-format/README.md` Then it has a line for the upload table, and the suite's coverage check passes (spec 017)
- [ ] **AC-5.6** Given an expired upload that the sweep has not yet run for When the collector applies Then it is treated as expired (AC-3.3), whatever the sweep's timing

### Story 6: The round trip

**As a** collector (and the maintainer, for the 1.0 test)
**I want** an export that I apply to a fresh account to restore my collection
**So that** I can move instances and trust my backup

- [ ] **AC-6.1** Given a collection of lots of varied finishes, conditions, prices (some none), quantities and times, whose every lot resolves, exported with `CollectionExport` and previewed Then every row is unchanged, the page says there is nothing to change, and no upload is stored (the round trip's no-op half; spec 025 AC-1.3)
- [ ] **AC-6.2** Given the same export previewed and applied to an empty account on the same catalog Then the new account's lots match the first's one-to-one by identity, each with the same quantity, `created_at` and `updated_at` (to the second), and exporting the new account gives a document equal to the original but for `exported_at` and the profile's name and email address, which are those of the new account's collector
- [ ] **AC-6.3** Given the export of AC-6.2 with the original account's collection then changed (a lot edited, one removed, one added) and the file applied back Then the account's lots equal the file's again (the restore half), exporting gives the file but for `exported_at`, and applying the same file again is a preview of nothing to change
- [ ] **AC-6.4** Given each valid example in `docs/export-format/examples/valid/` that resolves against a catalog the spec builds Then it applies to an empty account, and exporting the result equals the example but for `exported_at` and the profile's name and email
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

- **FR-1** An apply step takes the account and its stored upload and either writes (every change of decision 5 and the clearing of decision 7) or refuses with the reason; it writes nothing on a refusal. It builds on `CollectionImport` (spec 025): the reading of the file and its outcomes are not reimplemented, and the plan and its fingerprint come from them.
- **FR-2** Applying is one database transaction that contains writes only. The stored file is read, parsed, judged and resolved before it begins. Inside it, the account's lots are read again, the plan is recomputed and its fingerprint compared with the stored upload's (decision 2), then the changes and the clearing are written, and the stored upload's record is deleted. Any failure rolls the transaction back; nothing outside it is written. The stored file is removed after the transaction commits; the sweep removes it if that removal fails.
- **FR-3** The writes use the same lot identity as `Lot` (`Lot.key_for`) and satisfy `Lot`'s validations (AC-2.4). Where the plan uses bulk statements that skip callbacks and validations (a documented exception to `.claude/rules/models.md`, for the 50,000-row bar), the rows written are the ones the reader already resolved and checked, and a spec checks them against `Lot`.
- **FR-4** The number of queries doesn't grow with each row: the lots are read in one statement and written in a bounded number of statements (batched only past a fixed size, below SQLite's limit on bound values), as for the preview.
- **FR-5** Everything is read and written through `Current.account`, including the stored upload (`Current.account`'s one upload). No parameter names an account, an upload or a lot; the one parameter besides the confirmation is the fingerprint (decision 2).
- **FR-6** The file's content is never logged; its field stays filtered from the logs (spec 025 FR-6), and the stored file is read only by the app. Responses carry `Cache-Control: no-store`.
- **FR-7** The upload is limited and judged by content exactly as the preview's (spec 025 decision 6), before anything is stored (decision 8).
- **FR-8** The files of the apply and the stored upload under `app/models/`, their controller and their views contain neither `MTG` nor `Scryfall` (a spec in the style of spec 025 FR-9).
- **FR-9** A changed lot keeps its id; no lot is deleted and recreated to change it (decision 5).
- **FR-10** The stored upload is a tenant-owned table with `account_id`, indexed, with a unique index so an account has at most one (decision 1).

## Non-Functional Requirements

- **Cost per account (hosted-door rule 4).** Storage: at most one file of at most 32 MB per account, for at most 1 hour (decision 9), and the lots the collector's file describes. Background work: none per account; one recurring sweep for the instance, every 15 minutes, whose cost is the number of expired uploads. Per apply: one request that reads at most 32 MB, and one write transaction of at most one statement batch per 1,000 lots. AC-1.10 holds a 50,000-row file to the bars of decision 3. A limit on imports per account is a hosted-service feature (north star, Not before 1.0).
- **Hosted-door rules.** Rule 1: no source is adopted. Rule 2: a collector applies into their own collection only; no admin page reads a file, an upload or a collection (the admin catalog and jobs pages show only the sweep's job record). Rule 3: no setting is added (the expiry is a constant). Rule 4: as above.
- **Data safety.** All or nothing (AC-2.1); no apply without a matching preview (decision 2); a removal needs a confirmation (AC-3.5); the export is one click away (decision 6).
- **Security.** The upload is a CSRF-protected form; the stored file is validated (decision 8), private to its account and never served; Brakeman stays clean; no mass assignment of lot, upload or account attributes from the request. ADR 0013's owed validation is met here, and CLAUDE.md's note of it is updated.
- **Format.** Version 1, unchanged. The upload table is left out of the export (decision 9). If a later spec adds a column to `lots`, the round-trip specs of Story 6 fail until applying handles it (spec 017's Coverage rule, in effect).
- **Testability.** Request specs for every response, model specs for the plan, fingerprint, apply and sweep, the round trip (Story 6), one system spec for the flow.

## Error Scenarios

| Situation | What happens |
|---|---|
| File refused as a whole, or with problem rows, at the preview | As spec 025; nothing is stored (AC-1.11) |
| Stored file refused or with problem rows at the apply | 422, the reasons as the preview gives them, nothing written, the upload removed (AC-3.4) |
| Plan, or the form's fingerprint, differs from the stored upload's | 409, fresh preview of the stored file with a new fingerprint, nothing written (AC-3.1) |
| No upload, expired, or already applied | 422, the upload page, nothing written (AC-1.9, AC-3.3, AC-5.6) |
| Removal not confirmed | 422, nothing written, the upload stays (AC-3.5) |
| A write fails (constraint, disk, busy timeout past its wait) | The transaction rolls back; an error page says nothing was changed and the collector may try again; the upload stays (AC-2.1) |
| Storing the preview's file fails | The preview shows the counts but no apply button, and says the file couldn't be kept; nothing else is written (ruled 2026-10-20; failing the whole preview instead was not chosen) |
| The catalog is refreshed during an apply | Entries are never deleted (retired instead), so a row still resolves. A finish a refresh stops listing between resolving and writing is accepted: the lot is written, and later edits to it meet the usual finish check (accepted limit) |
| A scanner or number-entry add lands in the account during the apply | It waits for the write transaction and then runs against the applied collection |
| Two browser tabs apply | One commits and removes the upload; the other gets 422 (AC-2.3) |
| The session ended when the form is submitted | Redirect to sign in; the collector previews again (AC-4.3) |
| A form posted with no session cookie | Fails CSRF protection first, as for any such request (422), as spec 025 says |

## Supersedes

- Spec 025 decision 6 ("read in the request and never stored"), its Goal "Nothing is written … no stored file", AC-1.8, FR-6's "writes no file" and its Security and Cost notes on never storing, for a file that can be applied and has something to change (decision 10). Spec 025 is not edited; this line and the row in [`docs/specs/README.md`](../README.md) carry it.

## Documents that change

- `CLAUDE.md`: the status line ("applying an import isn't built yet"), the "Import preview" fact (it stores the upload now) and the Active Storage fact ("ADR 0013's owed validation stays with the first Active Storage upload" is met by this feature).
- `README.md`: the "Your data" paragraph; the 40 MB limit; that a previewed file is kept for an hour.
- `docs/roadmap.md`: theme A item 5 marked done.
- `docs/adr/`: the upload-retention ADR (decision 9) and its line in `docs/adr/README.md`; `docs/adr/0013-active-storage-variants-with-vips.md` links to it from its consequence about the owed validation.
- `docs/export-format/README.md`: the Coverage table's new line, and nothing else.
- `docs/architecture/`: the data portability and the release-and-deploy area docs, if they exist by then (spec 027 slice C, #108, #109), else the areas stay listed as not written.
- `docs/specs/README.md`: this spec's row (done with the draft), and the "Superseded by" cell of spec 025 when this spec ships.
- `docs/design-system/components/` for the apply form and the stale-plan notice, if new patterns.

Each is verified by reading.

## Open Questions

None. The maintainer ruled on 2026-10-20: decisions 1, 3, 6, 7, 9 and 10, and the error scenario for a failed store (show the counts without an apply button); and confirmed decisions 2, 4, 5 and 8.

## Out of Scope

Undo of an import, partial application, merge semantics, a background job for applying (unless the bar fails and the maintainer rules it), downloading or showing a stored upload, other formats and other tools' files, repairing rows, backup and restore of an instance (#41), upgrade proof (#42), an admin import, and the format document's version, schema and examples.
