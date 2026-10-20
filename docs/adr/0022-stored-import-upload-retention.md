# 0022: A previewed import file is stored for an hour, privately, and swept

## Status

Proposed (2026-10-20, written with the plan for spec 028; the decisions it records were ruled by the maintainer in spec 028 v1.3.2 and in the rulings on the plan's reviews, 2026-10-20). It becomes Accepted when the plan is approved.

**Date:** 2026-10-20
**Feature:** 028-apply-import

## Context

Spec 025 reads an export file in the request and keeps nothing ("never stored", its decision 6). Applying the file needs the same bytes a second time, after the collector has looked at the preview. Spec 028 decision 1 (ruled 2026-10-20) keeps the previewed upload briefly so that applying is one click. This is the first Active Storage upload in the app, so [ADR 0013](0013-active-storage-variants-with-vips.md)'s owed validation (content type, size, pixel limits; `.claude/rules/security.md`) lands here.

Facts that shape the decision:

- Active Storage's tables are not installed yet (the engine is required, `config/application.rb`, but nothing uses it).
- Active Storage's routes are public by default: anyone with a signed id can fetch a blob. Once the tables exist, its direct-upload route and the disk service's upload `PUT` also work for any caller.
- The Disk service writes under `storage/`, the directory that also holds the SQLite databases and `storage/catalog/`. Nothing may delete paths in it by walking it.
- `ActiveStorage::Blob#purge` destroys the blob's row before it deletes the file (`activestorage-8.1.4`, `blob.rb`), so a failing delete would leave a file that no row names.
- Solid Queue runs inside Puma in development and production, so a recurring job runs in both.

## Options considered

### Option A: Store the upload with Active Storage, gate its routes, sweep it (chosen)

**Pros:** it uses the framework (`.claude/rules/conventions.md`); the blob, its checksum and its disk service come for free; ADR 0013's validation duty is met where the first upload is.
**Cons:** Active Storage's tables and routes arrive in every instance; its routes must be gated (below).

### Option B: Ask for the file again at the apply, carrying the fingerprint in the form

Spec 028 decision 1's alternative: nothing is stored, but the collector chooses the same file twice. Not chosen by the maintainer.

### Option C: Keep the bytes in a column of `import_uploads`

**Pros:** no Active Storage, no routes. **Cons:** up to 32 MB in the primary SQLite database, which is the only one backed up and the one writers contend for; it would also leave the validation duty of ADR 0013 to the next upload. Not chosen.

### Option D: Draw no Active Storage routes (`config.active_storage.draw_routes = false`)

**Pros:** nothing to gate; the stored upload is read by the app only. **Cons:** every later upload feature would have to redraw and gate them. The maintainer ruled (2026-10-20) that the routes stay drawn and gated, so later uploads inherit one rule.

### Option E: `dependent: :purge` or `purge_later` for the removal

`:purge` runs inside an Active Storage callback after the commit, where a failing delete would fail an apply whose lots were already replaced; `purge_later` queues a job, which the maintainer ruled out. Not chosen: the removal is one explicit path (below).

## Decision

- **What is stored:** the previewed export file, only when it can be applied and has something to change. One per account (`import_uploads`, unique `account_id`), at most 32 MB (`CollectionImport::MAX_BYTES`). It is recorded as `application/json` whatever the browser declared, after the content was read as an export. The record holds the plan's fingerprint and `expires_at`.
- **How long:** `ImportUpload::EXPIRES_IN`, 1 hour. It is removed earlier when applied, refused, replaced by a newer preview, or when its account goes. An orphan blob is removed by the sweep once it is more than 10 minutes old, so within 25 minutes of its creation (10 minutes of grace plus the 15-minute schedule).
- **Where:** the configured Active Storage service (the Disk service under `storage/` on the persistent volume). The blob is created identified and analyzed, with a fixed `import_upload` marker in its metadata, so no analysis job is queued.
- **One removal path:** `has_one_attached :file, dependent: false`. Every removal (a replacing preview, the sweep, an apply, a refusal, an account's deletion) is `ImportUpload#remove!`: the upload row and its attachment are destroyed, and after the commit the blob is released inside `begin/rescue StandardError`, logging the exception class only. Release deletes the file first and then the blob row, so a failure leaves a marked, unattached blob row that the sweep finds. The request still succeeds.
- **The sweep:** `ImportUpload::SweepJob`, every 15 minutes, queue `default`, in `development` and `production` of `config/recurring.yml`. It removes expired uploads and orphans (a marked blob with no attachment, created more than 10 minutes ago), rescuing and logging per item so that one failure never stops the others. It never lists or deletes paths on disk.
- **Active Storage's routes stay drawn, gated app-wide:** every Active Storage controller requires sign-in, and every route that reads a blob also requires that the blob has an attachment whose record belongs to the signed-in account (otherwise 404). Direct-upload creation (`POST /rails/active_storage/direct_uploads`) and the disk service's upload `PUT` answer 404, signed in or not, until a feature needs them. The first such feature defines its own owner rule, quota and clean-up.

## Consequences

- **The gate authorises original blobs only.** The representation route passes the gate for an owner (it carries the original blob's signed id) and then redirects to the variant file's disk URL, which the gate refuses: a variant record's file, and a preview image, are attached to records with no `account_id` (the variant record, the blob). So variants are not served. The first image feature (the comics and graded-card images ADR 0013 expects) must extend ownership to variant records and preview images, resolving them to the original blob's attachments, before its variants can be served. This ADR does not implement it. A record type attached to blobs must answer `account_id`; a blob attached to a record without one is not served to anyone. Active Storage use for global (non-account) records, such as catalog artwork, stays blocked until an ADR supersedes this one.
- ADR 0013's owed upload validation is met for this file by content (never the declared type), size, and no pixel limits (it is no image). Image uploads still owe pixel limits.
- `import_uploads` has `account_id`, so the export format's Coverage table lists it as left out (transient working state); the format's version, schema and examples do not change.
- A failed file delete after the commit leaves a marked, unattached blob row, found by the sweep within 25 minutes at most (10 minutes of grace plus the 15-minute schedule). If the row's delete keeps failing, the sweep logs and tries again each run; the operator sees the class in the log.
- **Accepted limit:** an account removed by raw SQL (a console or a script that bypasses callbacks) cascades its `import_uploads` row away but leaves the attachment row pointing at a record that no longer exists, so the blob is not an orphan to the sweep (it still has an attachment) and its file stays. The application's own deletions run the callbacks (`User belongs_to :account, dependent: :destroy`), so only out-of-band SQL is affected (maintainer, 2026-10-20).
- Self-hosters get two new migrations (Active Storage's install, then `import_uploads`), safe to run unattended from any prior version, and blob files under `storage/` for at most an hour per account.
