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

## bin/ci

Run twice at the end, `bin/ci` in this worktree: Setup, RuboCop (525 files, no offenses), Brakeman (no warnings), bundler-audit and importmap audit pass. **RSpec: 1752 examples, 10 failures, 1 pending.** The first run had an 11th failure of this feature's own, an order-dependent example that compared `config.filter_parameters` literally (Rails compiles it after the first request); it now checks the filter's behaviour and passes in any order. The ten that remain are the development machine, not this change:

| Failing examples | Cause |
|---|---|
| `footer_spec` ×3, `theme_spec`, `card_image_fit_spec` ×3 | The machine is in macOS Dark appearance (`defaults read -g AppleInterfaceStyle` → `Dark`, at 22:27), so headless Firefox reports `prefers-color-scheme: dark` and the examples that expect the light theme's colours get the dark ones (for example `rgb(170, 162, 152)` where `rgb(95, 90, 82)` is expected). The first full run of this branch, in the afternoon, did not show them. |
| `active_storage_variant_transformer_spec` ×2, `libvips_check_spec` | libvips isn't installed (`Could not open library 'libvips.42.dylib'`), as `CLAUDE.md` says development needs it. |

The one pending example is `art_agreement_spec` ("Set COLLECTOR_ART_AGREEMENT to the spike's art-cache directory"), as before. I did not re-run these ten on `main`; their causes are shown above and none touches code this feature changed.

## Implementation review

SPEC-ALIGNED, by the author's own coverage matrix above (every AC and FR has an example, a measurement or a reading; the two measured bars pass), not by an independent reviewer. An independent `sdd-review` Mode B pass before the merge is recommended; the CI caveats above should be re-checked on a machine in light mode with libvips installed.
