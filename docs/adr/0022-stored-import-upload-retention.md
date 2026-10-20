# 0022: A previewed import file is stored for an hour, privately, and swept

## Status

Proposed (2026-10-20, written with the plan for spec 028; the decisions it records were ruled by the maintainer in spec 028 v1.3.1). It becomes Accepted when the plan is approved.

**Date:** 2026-10-20
**Feature:** 028-apply-import

## Context

Spec 025 reads an export file in the request and keeps nothing ("never stored", its decision 6). Applying the file needs the same bytes a second time, after the collector has looked at the preview. Spec 028 decision 1 (ruled 2026-10-20) keeps the previewed upload briefly so that applying is one click. This is the first Active Storage upload in the app, so [ADR 0013](0013-active-storage-variants-with-vips.md)'s owed validation (content type, size, pixel limits; `.claude/rules/security.md`) lands here.

Facts that shape the decision:

- Active Storage's tables are not installed yet (the engine is required, `config/application.rb`, but nothing uses it).
- Active Storage's routes are public by default: anyone with a signed id can fetch a blob.
- The Disk service writes under `storage/`, the directory that also holds the SQLite databases and `storage/catalog/`. Nothing may delete paths in it by walking it.
- Solid Queue runs inside Puma in development and production, so a recurring job runs in both.

## Decision

- **What is stored:** the previewed export file, only when it can be applied and has something to change. One per account (`import_uploads`, unique `account_id`), at most 32 MB (`CollectionImport::MAX_BYTES`). It is recorded as `application/json` whatever the browser declared, after the content was read as an export. The record holds the plan's fingerprint and `expires_at`.
- **How long:** `ImportUpload::EXPIRES_IN`, 1 hour. It is removed earlier when applied, refused, replaced by a newer preview, or when its account goes. An orphan blob is removed 10 minutes after it was created at the latest.
- **Where:** the configured Active Storage service (the Disk service under `storage/` on the persistent volume). The blob is created identified and analyzed, with a fixed `import_upload` marker in its metadata, so no analysis job is queued. Every removal purges synchronously (`purge`, never `purge_later`), after and outside the write transaction.
- **The sweep:** `ImportUpload::SweepJob`, every 15 minutes, queue `default`, in `development` and `production` of `config/recurring.yml`. It purges expired uploads and orphans (a marked blob with no attachment, created more than 10 minutes ago). It only calls `purge`; it never lists or deletes paths on disk.
- **Active Storage's routes stay drawn, gated app-wide:** every Active Storage controller requires sign-in, and every route that reads a blob also requires that the blob has an attachment whose record belongs to the signed-in account (otherwise 404). Direct-upload creation and the disk service's upload PUT require sign-in only, since no blob exists to own yet.

## Consequences

- Every later upload (the comics and graded-card images ADR 0013 expects) inherits the gate. A record type that is attached to blobs must answer `account_id`; a blob attached to a record without one is not served to anyone. A future feature that needs public or shared blobs must supersede this ADR.
- The first feature that uses direct uploads must add its own owner rule for the blob it creates; this ADR only requires sign-in for them.
- ADR 0013's owed upload validation is met for this file by content (never the declared type), size, and no pixel limits (it is no image). Image uploads still owe pixel limits.
- `import_uploads` has `account_id`, so the export format's Coverage table lists it as left out (transient working state); the format's version, schema and examples don't change.
- A removal whose file delete fails after its row is gone leaves a file the sweep cannot find. Active Storage's service delete tolerates a missing file, and a failure to delete an existing one is a disk fault the operator sees in the log; the sweep is only the backstop for rows.
- Self-hosters get a new migration (Active Storage's install, then `import_uploads`), safe to run unattended from any prior version.
