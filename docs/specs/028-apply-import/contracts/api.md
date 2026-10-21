# Contracts: Apply an Import

**Spec:** [spec.md](spec.md) v1.3.2 (decisions 11, 13) · **Plan:** plan (retired in `ee4c4fa40e2223e2d81299885f8a0cabe7771956`; read it with `git show ee4c4fa40e2223e2d81299885f8a0cabe7771956^:docs/specs/028-apply-import/plan.md`)

## POST /collection/import_preview (spec 025; changed by this spec)

**Purpose:** preview a file; store it when it can be applied and has something to change.
**Spec requirement:** decisions 1, 8, 10; AC-1.1, AC-1.11, AC-5.1 to AC-5.3.

### Request
Multipart `export_file`. CSRF token. Signed in.

### Response
- 200, `import_previews/show`: the counts. A stored upload adds the apply form (hidden `fingerprint`, `confirm_removal` checkbox when lots are removed, "Apply import", link to `/collection/export`). A file with nothing to change says so and offers no form. A failed store shows the counts, no form, and "We couldn't keep this file, so it can't be applied. Choose it again."
- 422, `import_previews/new`: refused file (as spec 025).

## POST /collection/import

**Purpose:** apply the signed-in account's stored upload.
**Spec requirement:** decisions 2, 3, 4, 7, 11, 12, 13; FR-1, FR-2, FR-5.

### Request
Form fields `fingerprint` (string), `confirm_removal` ("1" or absent). CSRF token. No other parameter is read.

### Response
| Status | When | Body |
|---|---|---|
| 303 to `/collection` | applied | flash notice "Imported: 3 lots added, 2 changed, 1 removed" |
| 422 | no upload; expired; stored file missing or unreadable | `import_previews/new` with "Preview the file again." or "Your preview has expired. Choose the file again." |
| 422 | stored file now refused or with problem rows | `new` (refused) or `show` (problem rows) with the preview's reasons; upload removed |
| 422 | plan has nothing to change | `show`, "This file has nothing to change"; upload removed |
| 409 | form, stored and recomputed fingerprints not all equal | `show` for the stored file against the collection now; the **new** fingerprint is stored with the upload and is the one in the form; "The collection or the file changed since you looked." |
| 422 | plan removes lots and `confirm_removal` is not "1" | `show`, "Confirm the removal to apply this file" |
| 500 | an exception after writes began | `imports/failed`: "Nothing was changed. You can try again."; upload stays |
| 302 to sign in | signed out | |

Order of checks: decision 13. Every response, the 303 included, carries `Cache-Control: no-store`. A failure to delete the stored file after the commit never changes the response (the 303 stays a 303).

## Active Storage routes (gated app-wide)

`/rails/active_storage/...` (blobs, representations, disk `GET`): signed out → 302 to sign in; signed in, blob not an original blob held by a record of `Current.account` → 404 (variant records and preview images are not authorised yet); owner → as Active Storage. Direct uploads (`POST /rails/active_storage/direct_uploads`) and the disk service's upload (`PUT /rails/active_storage/disk/:token`): 404, signed in or not, until a feature needs them. **Spec requirement:** decision 8; AC-1.12.
