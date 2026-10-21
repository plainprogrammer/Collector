# Verification: spec 028, Apply an Import

**Spec:** [spec.md](spec.md) v1.3.3 · **Plan:** [plan.md](plan.md) (approved 2026-10-20) · **Branch:** `plainprogrammer/028-apply-import`

How to read this: each criterion names the example that holds it (`file`, "example title"). Phases 8, 9 and 10 add tests but no code, so those tests passed when written (characterization tests, listed at the end); every other example was run red first for the reason named in its phase (an uninitialised constant, a missing method, or the ungated route).

## Acceptance criteria

| AC | Held by |
|---|---|
| 1.1 | `spec/requests/collection_import_previews_spec.rb`, "offers the apply for a file with something to change, outside Turbo, with the fingerprint"; "stores nothing for a file with problems, a refused file or a file with nothing to change"; "puts the CSRF token in the apply form" |
| 1.2, 1.3, 1.4 | `spec/models/collection_import/apply_spec.rb`, "replacing the collection" (exact lots, the changed lot keeps its id, empty into full, full into empty); HTTP: `spec/requests/collection_imports_spec.rb`, "applies and redirects with the counts" |
| 1.5, 1.7 | `apply_spec`, "afterwards" ("previews as nothing to change", "does not write a lot with fractional times"); `plan_spec`, "has nothing to change for a file the collection already holds", "treats a lot with fractional times as unchanged" |
| 1.6 | `apply_spec`, "the profile" (a known view, an unknown view, the collector's own; name and email unchanged) |
| 1.8 | `apply_spec`, "working state" (cleared when the apply writes; not cleared when stale, unconfirmed or nothing to change) |
| 1.9 | `apply_spec`, "removes the upload, its blob and its file, and queues no job"; `collection_imports_spec`, "refuses a second post with 'Preview the file again.'" |
| 1.10 | Measured, below |
| 1.11 | `collection_import_previews_spec`, "writes only the upload, its blob and its attachment"; "stores nothing for a file with problems…"; "still writes nothing and queues nothing for a file with problem rows" |
| 1.12 | `spec/requests/active_storage_gate_spec.rb` (signed out, another account, owner through the redirect, an unowned blob, direct uploads and the disk PUT, no blob URL in the preview page) |
| 2.1 | `apply_spec`, "rolls everything back when a write fails after the lots were written"; `collection_imports_spec`, "answers 500 with a page saying nothing changed" |
| 2.2 | `apply_spec`, "refuses a second apply of a file already applied as nothing to change" |
| 2.3 | `apply_spec`, "a lost race"; by hand, below (10 trials of two simultaneous applies) |
| 2.4 | `apply_spec`, "writes lots that Lot would accept, with the key Lot gives and the identity of their row" |
| 2.5, 5.6 | `apply_spec`, "answers :missing when the upload was removed after it was read", "judges expiry inside the transaction, whatever the sweep's timing" |
| 3.1, 3.2 | `apply_spec`, "refuses a changed collection as stale…", "refuses a form from a replaced upload as stale"; `collection_imports_spec`, "answers 409 with a fresh preview whose form carries the new fingerprint" |
| 3.3, 3.4, 3.5 | `apply_spec` and `collection_imports_spec`, one example each ("says missing or expired…", "refuses a stored file the catalog no longer resolves…", "needs the removal confirmed…") |
| 3.6 | `apply_spec`, "gives decision 13's response for combined causes" |
| 3.7 | `plan_spec`, "#fingerprint" (equal for two previews; differs for a quantity, either time at full precision, existence, the file, the view) |
| 4.1, 4.2, 4.3 | `apply_spec`, "only this account"; `collection_imports_spec`, "shows nothing of another account in any response", "ignores account, upload and lot parameters", "sends a visitor to sign in without reading anything" |
| 4.4 | `spec/models/import_upload_spec.rb`, "going with its account" |
| 5.1, 5.2 | `import_upload_spec`, ".store!"; `collection_import_previews_spec`, "stores the file as application/json by content, one per account, replacing the earlier" |
| 5.3 | `collection_import_previews_spec`, "stores nothing over 32 MB or that isn't an export" |
| 5.4 | `import_upload_spec`, ".sweep!" (expired, old orphan, fresh orphan, unmarked blob; idempotent; keeps going past a failing item) and "a file that can't be deleted" |
| 5.5 | `spec/config/recurring_spec.rb` (development and production); `spec/export_format_document_spec.rb` (the Coverage line for `import_uploads`) |
| 6.1 to 6.4 | `spec/models/collection_import/round_trip_spec.rb` (nothing to change for the exported collection; restore into an empty account; restore a changed collection; `collection.json`); `collection_import_previews_spec`, "previews the format's empty example, in its own currency, as nothing to change with no apply offered" |
| 6.5 | By hand, below |
| 7.1 | `collection_import_previews_spec`, "offers the apply…" (counts, removal in words, no undo, kept for an hour); the form sits below the counts and above the profile notes (`show.html.erb`) |
| 7.2 | `spec/system/collection_import_apply_spec.rb` |
| 7.3 | Screenshots, below |
| 7.4 | By reading, below |

## Functional requirements

| FR | Held by |
|---|---|
| 1 | `app/models/collection_import/apply.rb`, `plan.rb`; `apply_spec` as above |
| 2 | `apply_spec`, "a lost race", "all or nothing"; the transaction holds the re-check, `replan`, the comparison and the statements only |
| 3 | `apply_spec`, "valid lots"; `Lot.upsert_all` is the documented exception (spec FR-3) |
| 4 | `apply_spec`, "bounded statements" (same statement count within one batch; linear in batches past it) |
| 5 | `apply_spec` "only this account"; `collection_imports_spec` "ignores account, upload and lot parameters" |
| 6 | `collection_imports_spec` (no-store on the 303, the 409; the controller logs the exception class only); `spec/import_apply_core_spec.rb` ("keeps the uploaded file out of the logs") |
| 7 | `collection_import_previews_spec` (AC-5.1, AC-5.3 examples) |
| 8 | `spec/import_apply_core_spec.rb` ("never names a collectible type or a source", "exists, every file of it") |
| 9 | `apply_spec`, "replacing the collection" (the changed lot keeps its id) |
| 10 | `import_upload_spec`, "allows one per account"; `db/migrate/20261020100002_create_import_uploads.rb` |

## Measurements (AC-1.10, AC-6.5, AC-2.3)

**Method.** The development machine, this worktree's own development database. A throwaway runner script in the session scratchpad (never committed) inserted one set, 50,000 identities, entries and `mtg_printings`, and three users; the 50,000-row files were written to a temporary directory (20.9 MB each); everything was deleted afterwards (users, lots, entries, identities, sets, printings, uploads and blobs all back to 0).

**Phase 5 spike: the write transaction** (`transaction.active_record` durations, in-process, `CollectionImport::Apply#call`; bar: under 4 s):

| Case | Transaction | Inside it: `replan` / fingerprint |
|---|---|---|
| (a) 50,000 resolvable rows into an empty account | **2.39 s** | 0.03 s / 0.01 s |
| (b) the same 50,000, every row changed | **3.21 s** | 0.79 s / 0.07 s |
| (c) an empty file against 50,000 lots, removal confirmed | **0.93 s** | 0.55 s / 0.01 s |

All three are under 4 s; the closest margin is 0.79 s, in (b). The lean-read rung and the maintainer's fallback were not needed.

**Phase 11: the whole request**, a real `rails server` (development) on port 3099, `curl` with a session and the form's token; RSS read from `ps` before and after each request:

| Case | Preview | Apply (whole request) | RSS growth, preview / apply |
|---|---|---|---|
| (a) 50,000 rows into an empty account | 4.66 s | 6.72 s (303) | +408 MB / +96 MB |
| (b) every row changed | 5.14 s | 7.56 s (303) | +61 MB / +77 MB |
| (c) empty file, 50,000 removed | 0.67 s | 0.91 s (303) | +13 MB / -25 MB |

Every request is under 30 s and under 500 MB of RSS growth, including the preview of (a), which now also stores the file (P3). The first request of a fresh server grows most (code loading and the first parse), which is why (a) shows the 408 MB; the preview reads the upload twice (`CollectionImport`, then the store), measured here, and stayed under the bar, so `CollectionImport` does not expose its bytes.

**AC-2.3 by hand:** ten trials, each a fresh preview followed by two simultaneous applies of the same fingerprint (`curl … &` twice): every trial gave exactly one 303 and one 422, never a 500 (`303/422`, `422/303`, …), and the collection held the file's 300 lots.

**AC-6.5, as far as one machine shows it:** no real catalog can be loaded offline here, so the check uses the seeded catalog of 50,000 entries, with two accounts of one instance rather than two instances. Account A (50,000 lots) exported its collection through `/collection/export` (14.2 MB); the file was previewed and applied through the pages to the empty account C (preview 4.50 s, apply 7.13 s, 303); C's export has 50,000 lots, no well-formedness problem, and holds the same collection as A's under the format's rule (`ExportFormatRules.same_collection?`, the profile's name and email apart: `true`). The maintainer's own check of their real collection is theirs, as the spec says.

## Screenshots (AC-7.3)

`screenshots/`, light and dark at 1280 px and 390 px, taken through iframes of the page's own HTML in headless Firefox (the browser's narrowest window is 500 px): `preview-apply-*` (the preview with the apply form and the removal checkbox), `stale-409-*` (the notice and the form with the new fingerprint), `refused-422-*` (a stored file the catalog no longer resolves), `applied-notice-*` (the collection with "Imported: …"). Everything is shown in full and nothing scrolls sideways at 390 px.

## Documents and copy, verified by reading (AC-7.4 and "Documents that change")

- The pages use only token variables and existing `c-*` classes (`c-form`, `c-field`, `c-check`, `c-btn`, `c-import__note`, `c-status__message`); no CSS was added. `docs/design-system/components/ImportPreview.md` gains the apply form's markup and rules. The copy says "you", never "we" (the store-failure message reads "This file couldn't be kept…"). Reworded strings: "Previewing changed nothing in your collection." (both messages) and the upload hint "…changes nothing in your collection."
- `CLAUDE.md` (status, "Import preview", "Active Storage variants"), `README.md` ("Your data"), `docs/roadmap.md` (item 5), `docs/adr/0013-…` (the link), `docs/adr/0022-…` (Accepted), `docs/adr/README.md` (the index line), `docs/export-format/README.md` (the Coverage line only), `docs/architecture/README.md` (028 in two rows), `docs/architecture/catalog-operations.md` (the sweep), `docs/releasing.md` (upgrade notes), `docs/specs/README.md` (025's "Superseded by", 028's plan cell), spec 028's `Plan:` line (through `sdd-spec-update`). The data-portability and release-and-deploy area docs are not written yet; `distill-feature` writes them.

## Characterization tests

Written after the code they check, so they passed on first run: `round_trip_spec.rb` and the `empty.json` example (Phase 8), `spec/system/collection_import_apply_spec.rb` (Phase 9), and the "exists" and log-filter examples of `import_apply_core_spec.rb` (Phase 10). The FR-8 "never names" example was written first (Phase 0).

## Deviations from the plan

Each is small and was found by running the plan's own code:
- `replan` also resets `@removed_lots` (the plan's review thought the ivar did not exist; `removed_lots` memoizes it).
- The gate defines `request_authentication` with `main_app.new_session_path`: Active Storage's controllers do not see the app's route helpers.
- The test Disk cleanup keeps `tmp/storage/.keep` (the repository tracks it).
- Plan spec fixes: `update_columns` on a record, not a relation; lets created before a snapshot; held-lot times that make "nothing to change" true; a `X-CSRF-Token` header (a per-form token did not verify in a request spec); a warm-up preview so the query-count example compares like with like.
- No subagents: the phases were executed in this session (sdd-execute's per-task dispatch was not used).

## Findings of the independent implementation review (Sonnet, 2026-10-21) and how they were closed

Spec 028 became 1.3.4 (a PATCH: the price rule below, with its supersession of spec 025's decision 9 on that point recorded in `docs/specs/README.md`, both rows). This section was added after the review; the verdict is under "Implementation review", after the clean `bin/ci` run.

| Finding | Resolution |
|---|---|
| M1, impossible dates | **Rejected: the reader already refuses them.** `ExportFormat::Rules` returns `not_a_time` for a moment that isn't real (`rules.rb`, `rule_problems`), and `collection_import_spec` already held "2026-02-30" as a problem row. The review's premise (the schema pattern alone decides) missed that second pass. Added a preview-level example that proves it end to end: `collection_import_previews_spec`, "refuses an impossible date and a price that doesn't fit, offering no apply" (a `changed_at` of `2026-13-45T00:00:00Z`: "can't be applied", no form, nothing stored). It passed on first run. |
| M1, price | **Fixed (ruled by the maintainer, 2026-10-21).** The reader refuses a well-formed row whose `price_paid`, in cents, exceeds 9,223,372,036,854,775,807 (the lots column is a 64-bit SQLite integer): a problem row, rule `price_too_large`, at `/lots/N/price_paid`, "price_paid is too large to record", so the preview offers no apply. Tests first, red then green: `collection_import_spec` ("refuses a price that doesn't fit the cents column"), the preview example above, and `apply_spec` ("refuses a stored file with a price that doesn't fit, and removes it"). `CollectionImport::MAX_PRICE_CENTS`. |
| M2 | **Fixed.** `ImportUpload#checksum` returns nil when nothing is attached; `Apply` treats that as `:unreadable` (422 "Preview the file again.") and removes the row, both before reading and inside the transaction. `apply_spec`, "answers :unreadable, removing the row, for an upload that has lost its attachment". |
| m1 | **Fixed.** `CLAUDE.md`: "No lot, user or account is written." |
| m2 | **Closed.** The verdict below was rewritten after the clean `bin/ci` run recorded in the next section. |
| m3 | **Partly rejected.** The link to "Export collection" was asserted (page-wide); it is now asserted inside the form. AC-7.1's position is now asserted too: the apply form sits after the counts and the held-lots line and before the profile notes. |
| m4 | **Fixed.** The controller's rescue logs the class and the first five backtrace lines, never the message (it can carry file content). The rescue stays broad: the page must answer 500 for any failure after the lock. |
| m5 | **Fixed.** An expired or unreadable upload is removed when the apply finds it. |
| m6 | **Rejected.** The `.rubocop.yml` exclusions are file-scoped to the three scenario specs, with a comment; the examples are scenarios, and splitting them would hide the before/after reading. |
| m7 | **Left, with the measurement.** The second read of the upload is measured (preview +408 MB, under the 500 MB bar); exposing `CollectionImport`'s bytes is the plan's fallback, not needed. |
| m8 | **Fixed.** The install migration uses `if_not_exists: true` on its three `create_table` calls (rolled back and migrated again here; `db/schema.rb` unchanged). |
| Q1, the 4 s bar | **Ruled (2026-10-21): a development-machine bar.** README "Your data", `docs/releasing.md`'s upgrade note say that on slow hardware a very large import may briefly hold other writes, so import while nothing else is writing. There is no data-portability area doc yet (`distill-feature` writes it); it must carry this note. |
| Q5, AC-6.5 | **Accepted for merge** as one instance with a seeded catalog (above). The maintainer's own restore of their real collection on their NAS is part of the release check (`docs/releasing.md`, "Cutting a release", step 4). |

Specs run for this round (no system specs, no `bin/ci`, as another worker is using the machine): `spec/models`, `spec/requests`, `spec/config`, `spec/lib` and the files touched; results are in the commit messages.

## bin/ci

Run by the coordinator on 2026-10-21 at `7b2e796` (this branch merged with `origin/main`, which includes #119, "pin system specs to the light theme"), in Light mode with ImageMagick and libvips installed. Verbatim result: every step passed (Setup, RuboCop, Brakeman, bundler-audit, importmap audit) and RSpec ran **1757 examples, 0 failures, 1 pending** (`art_agreement_spec`, which needs `COLLECTOR_ART_AGREEMENT`).

The earlier run on this branch (`65d9fa4`, 1752 examples, 10 failures) is superseded. Its failures were the machine, not the change: ImageMagick and libvips were not installed (`active_storage_variant_transformer_spec` ×2, `libvips_check_spec`), and the machine was in macOS Dark appearance, which failed the system specs that assume the light theme (`footer_spec` ×3, `theme_spec`, `card_image_fit_spec` ×3). Installing the libraries and #119 removed them. Its other failure, an order-dependent example of this feature that compared `config.filter_parameters` literally, was fixed in `91b734b` (it now checks the filter's behaviour).

## Implementation review

SPEC-ALIGNED (independent Sonnet review 2026-10-21, after fixes)

**The review.** A read-only Mode B review by Sonnet 5.5 of `1ace7f8..65d9fa4` against spec 1.3.3 found 0 critical, 2 major and 8 minor issues, and issued DRIFT DETECTED (minor) until they were closed. Each was resolved or rejected as below; the table "Findings of the independent implementation review" above has the detail.

| Finding | Resolution | Commit |
|---|---|---|
| M1, impossible dates | Rejected: `ExportFormat::Rules` already refuses them (`not_a_time`). A preview-level example (`2026-13-45T00:00:00Z`) proves it. | `3b13920` |
| M1, price | Fixed: the reader refuses a `price_paid` over the cents column as a problem row (`price_too_large`); tests at reader, preview and apply levels. Spec 1.3.4 records it and the supersession of spec 025 decision 9 on this point (both rows of `docs/specs/README.md`). | `3b13920` (code, tests), `0bc004a` (spec 1.3.4, index) |
| M2, upload without its file | Fixed: `ImportUpload#checksum` is nil without an attachment; `Apply` answers unreadable (422) and removes the row. | `3b13920` |
| m1 CLAUDE.md "Nothing is written" | Fixed. | `3b13920` |
| m2 verdict pre-empted | Closed by this section, after a clean `bin/ci`. | this commit |
| m3 export link, form position | Fixed: asserted inside the form; position asserted (the review's claim that the link was untested was rejected: it was asserted page-wide). | `3b13920` |
| m4 controller log | Fixed: the class and the first five backtrace lines, never the message. | `3b13920` |
| m5 expired or unreadable upload | Fixed: removed when the apply finds it. | `3b13920` |
| m6 `.rubocop.yml` exclusions | Rejected: file-scoped to the three scenario specs, with a comment. | none |
| m7 second read of the upload | Left: measured (+408 MB, under the 500 MB bar); exposing the bytes is the plan's fallback. | none |
| m8 install migration | Fixed: `if_not_exists: true`. | `3b13920` |
| Q1, the 4 s bar | Ruled (2026-10-21) a development-machine bar: a note in README "Your data" and `docs/releasing.md` that very large imports on slow hardware may briefly hold other writes. | `0bc004a` |
| Q5, AC-6.5 | Accepted for merge as one instance; the maintainer's own restore of their real collection on their NAS is a release check (`docs/releasing.md`). | `0bc004a` |

**Fresh verification evidence:** the `bin/ci` result above, at `7b2e796`, after all of these fixes.

### Author's self-review (superseded)

Written before the independent review, kept as history:

> SPEC-ALIGNED, by the author's own coverage matrix above (every AC and FR has an example, a measurement or a reading; the two measured bars pass), not by an independent reviewer. An independent `sdd-review` Mode B pass before the merge is recommended; the CI caveats above should be re-checked on a machine in light mode with libvips installed.
