# Verification: Preview an Import (spec 025)

**Spec:** [spec.md](spec.md) v1.5.0 · **Plan:** [plan.md](plan.md) · **ADR:** [0021](../../adr/0021-export-format-rules-in-the-app.md) · **Branch:** `025-import-preview` · **Issue:** [#39](https://github.com/plainprogrammer/Collector/issues/39)

## Rulings

All by the maintainer, 2026-10-15:

- **Decisions 1 to 7 and 11**, as proposed, with the spec's approval.
- **Decision 12:** the time bar for a 50,000-row preview is 30 seconds, keeping the whole schema checked by `json_schemer`.
- **Decision 13:** the memory bar is 500 MB of RSS growth. The first measurement missed it (below), and the maintainer ruled the plan's named fallback, **Option A**: the header is validated with `lots: []`, then each lot on its own against the schema's `$defs/lot`, each pointer prefixed `/lots/<i>`. Tests in `f8ca320`, the change in `861f076`, with ADR 0021 amended. The re-run passes.
- **Decision 14:** "Import collection" sits between "Export collection" and the menu's separator, and after "Export collection" on More. This supersedes spec 022 decision 6 in that respect; spec 022 isn't edited (`git diff origin/main...HEAD -- 'docs/specs/022*'` prints nothing).

## The commits

`git log --oneline origin/main..HEAD`, oldest first: `181a700` spec, `36d1e79` plan and ADR 0021, `d27855e`/`e2baa23` the format's rules in the app (Phase 1), `08d2e98`/`df21a5c` the reader (Phase 2), `decb755`/`6c6c228` the pages and links (Phase 3), `f1fb396`/`7191f45` the request body limit (Phase 4), `37939ee` documents (Phase 5), `f38451e` screenshots, `f8ca320`/`861f076` the per-lot schema pass (Phase 6, ruled fallback). Each `test` commit ran red before its `feat` or `perf` commit.

## Acceptance criteria

Spec files, relative to the repository: `collection_import_spec.rb` is `spec/models/collection_import_spec.rb`; `collection_import_previews_spec.rb` is `spec/requests/collection_import_previews_spec.rb`; `rules_spec.rb` is `spec/models/export_format/rules_spec.rb`.

| Criterion | Held by |
|---|---|
| AC-1.1 | `collection_import_previews_spec.rb`, "offers the upload form, outside Turbo (AC-1.1)": 200, `no-store`, action `/collection/import_preview`, `post`, `multipart/form-data`, `data-turbo="false"`, `accept=".json,application/json"`, "Preview import"; "puts the CSRF token in the upload form (AC-1.1)" (forgery protection on) |
| AC-1.2 | `collection_import_previews_spec.rb`, "shows what applying the file would do (AC-1.2)": the four stats read 1 / 6 copies, 2 / 6 copies become 9, 1 / 3 copies, 1 / 7 copies, D listed as removed, held 0. `collection_import_spec.rb`, "counts lots added, changed, unchanged and removed, with their copies (AC-1.2)" (the tallies) |
| AC-1.3 | `collection_import_spec.rb`, "previews a collection's own export as unchanged (AC-1.3)": a `CollectionExport` of two lots previews applicable, 0 added, 0 changed, 2 unchanged, 0 removed |
| AC-1.4 | `collection_import_spec.rb`, "adds every row to an empty collection (AC-1.4)": 3 lots, 3 copies added |
| AC-1.5 | `collection_import_spec.rb`, "removes every lot for a file with none (AC-1.5)": 2 lots, 3 copies removed, both listed |
| AC-1.6 | `collection_import_spec.rb`, "compares times to the second and whole numbers by value (AC-1.6)": a lot with fractional `created_at`/`updated_at` and quantity 4 against a row of quantity `4.0` without the fraction is unchanged, nothing changed |
| AC-1.7 | `collection_import_spec.rb`, "says nothing when the file's profile agrees" (the collector's own view: no line), "gives the view a file would change to, and the file's own name and email address when they differ", "ignores a view the instance doesn't know" (`gallery`); `collection_import_previews_spec.rb`, "shows what the profile would change, and only then (AC-1.7)" (the three lines, ending "Importing won't change yours.", then no `#profile_notes` for an agreeing file) |
| AC-1.8 | `collection_import_previews_spec.rb`, "writes nothing and queues nothing (AC-1.8)": every table's row count and `MAX(updated_at)` equal before and after, no job enqueued. The model's "writes nothing (FR-6)" as well |
| AC-1.9 | `collection_import_previews_spec.rb`, "runs as many queries for 30 rows as for 2 (AC-1.9)" |
| AC-1.10 | Measured, below |
| AC-1.11 | `collection_import_spec.rb`, "holds a lot that a problem row names, rather than removing it (AC-1.11)": the lot named by a row whose `added_at` is 2026-02-30 is held (1 lot, 2 copies); the lot whose only row has no `entry` is removed (1 lot, 5 copies) |
| AC-2.1 | `collection_import_spec.rb`, "says why a well-formed row doesn't resolve (AC-2.1)" (reasons, rule and place for each, counts, the good row still added); `collection_import_previews_spec.rb`, "lists each row that can't be applied, with its reasons and counts (AC-2.1)" (row number, name, set code, collector number, language, both reasons, "can't be applied: 2 rows have problems", the counts). Order of checks: "checks the catalog in order: the type, then the entry, then finish and condition"; a registered type with no collecting vocabulary: "treats a registered type without a collecting vocabulary as one it doesn't collect" |
| AC-2.2 | `collection_import_spec.rb`, "resolves a retired entry and ignores descriptive fields that disagree (AC-2.2, AC-2.3)" |
| AC-2.3 | The same example: a row whose name, set code and language disagree is applicable |
| AC-2.4 | `collection_import_spec.rb`, "says why a row isn't well-formed, and doesn't check it against the catalog (AC-2.4)": missing quantity, quantity 0, price `"12.5"`, 2026-02-30, `changed_at` before `added_at`, duplicate of row 1, a row that is `7`, and an unknown entry with quantity 0 that gets only "quantity isn't valid"; the one good row is still added. "names nested fields with a point" (`entry.source_id is missing`) |
| AC-2.5 | `collection_import_spec.rb`, "shows every reason a row has (AC-2.5)" |
| AC-2.6 | `collection_import_spec.rb`, "names the unloaded catalogs of the types the file names" (under `#unloaded_catalog_titles (AC-2.6)`); `collection_import_previews_spec.rb`, "shows the catalog notice for an unloaded type the file names (AC-2.6)"; `spec/models/catalog_spec.rb`, "lists only the unloaded types it is asked about, ignoring types it doesn't know (spec 025 AC-2.6)" |
| AC-2.7 | `rules_spec.rb`, "reports exactly what examples/problems.json names for each invalid example (AC-2.7)" and "finds nothing wrong with the valid and comparison examples (AC-2.7)"; `collection_import_spec.rb`, "reports the rule and place problems.json names for each example refused as a whole (AC-2.7)". `spec/support/export_format_rules.rb` passes `problems` and `identity` to `ExportFormat::Rules`, so the examples specs run the same model |
| AC-2.8 | `collection_import_spec.rb`, "lists the first 100 problem rows and counts them all, by reason (AC-2.8)" and "lists the first 100 removed lots by name and counts them all (AC-2.8)"; `collection_import_previews_spec.rb`, "lists the first 100 rows with problems, then says how many more (AC-2.8)" and "lists the first 100 removed lots, then says how many more (AC-2.8)" ("and 50 more") |
| AC-3.1 | Every case's rule, place and reason: `collection_import_spec.rb`, under "a file refused as a whole (decision 10)": "asks for a file when there is none, it is empty, or the field isn't an upload", "refuses a file over 32 MB without reading it (AC-3.3)", "refuses a file it can't read as JSON", "refuses JSON that isn't an export", "refuses a file that doesn't say its version", "refuses a newer version as newer, before the schema (AC-3.2)", "names the first field outside the lots that isn't well-formed, in the file's order", "refuses a file in another currency, even with no lots (decision 3)". The 422 page: `collection_import_previews_spec.rb`, "refuses a file it can't read, showing the upload form again with the reason (AC-3.1)", for a field that isn't an upload, no field, not JSON, format version 2 and EUR (422, the reason as the field's error, no stats or rows). The other cases (too large, not UTF-8, not an object, format, version, header schema) are checked through the request only by sharing that controller branch, not each by its own request |
| AC-3.2 | `collection_import_spec.rb`, "refuses a newer version as newer, before the schema (AC-3.2)": version 2 with no `lots` or `profile` is `newer_version`; `2.0` too; `1.0` isn't refused |
| AC-3.3 | `collection_import_spec.rb`, "refuses a file over 32 MB without reading it (AC-3.3)": `too_large`, and `read` is never called |
| AC-3.4 | `spec/config/request_body_limit_spec.rb`: "is above the largest file the import preview reads", "is set in Puma, which every environment runs" (`Puma::Configuration` loads `config/puma.rb`: 40,000,000), "is set for Thruster in the published image" (`ENV MAX_REQUEST_BODY="40000000"`), "is set for kamal-proxy, which otherwise buffers up to 1 GB to disk" (`proxy.buffering.max_request_body` 40,000,000). By hand, below |
| AC-3.5 | `collection_import_previews_spec.rb`, "judges a file by its content, not its declared type or name (AC-3.5)": `image/png` named `cards.txt` previews (200); `"not json at all"` as `application/json` is refused (422) |
| AC-4.1 | `collection_import_spec.rb`, "compares the file with this account's lots only (AC-4.1)"; `collection_import_previews_spec.rb`, "compares the file with this collector's lots only (AC-4.1)": 1 added, 0 removed, and the body holds neither "7,919", "79.19", "Zebulon Otherperson" nor `zebulon.otherperson@example.test` |
| AC-4.2 | `collection_import_previews_spec.rb`, "sends a visitor to sign in from either page, reading no file (AC-4.2)": the GET redirects; the POST with its session row deleted redirects, and `CollectionImport.new` is never called |
| AC-5.1 | `spec/requests/shell_spec.rb`, "puts the import right after the export, in the account menu and on More (spec 025 AC-5.1, AC-5.2)" (`a.c-menu__item`, first two items); `spec/requests/admin/navigation_spec.rb`, "links Catalog and Jobs for an admin, on the More page and in the avatar menu" and "shows a member only the export and the import, neither admin link" (the whole list, in order, for each) |
| AC-5.2 | The same shell example: More's third row is "Import collection" to `/collection/import_preview/new`, after "Export collection"; the navigation examples above |
| AC-5.3 | `spec/system/collection_import_preview_spec.rb`, "previews an export file chosen from the account menu": a `CollectionExport` file, chosen through the avatar menu, previews as "This file can be applied." with 1 lot unchanged |
| AC-5.4 | Screenshots, below. `spec/system/narrow_pages_spec.rb` now includes the upload page at 360px |
| AC-5.5 | Read, below |

Every acceptance criterion has evidence. AC-3.1's 422 page is exercised by request for five of decision 10's cases; the others' reasons are held by the model examples (see its row).

## Functional requirements

| Requirement | Held by |
|---|---|
| FR-1 | `app/models/collection_import.rb`; the model examples above, and "says what applying would do with each row and which lot it matches (FR-1)" (`row_outcome`, `held_lot_for`) |
| FR-2 | `app/models/export_format/rules.rb` (`problems_in`: the schema, then the time rules and `duplicate_lot` limited to what the schema accepted); `rules_spec.rb`, "checks the times of a lot whose other fields fail the schema", "leaves a time that fails the schema to the schema", "finds the duplicate of a lot whose quantity fails the schema", "compares no lot whose identity can't be read" |
| FR-3 | The AC-2.1 examples; FR-9's spec for the core boundary |
| FR-4 | AC-1.9's example |
| FR-5 | AC-4.1's examples; the controller passes `Current.account` (`app/controllers/collections/import_previews_controller.rb`) |
| FR-6 | AC-1.8's example; "keeps the uploaded field out of the logs (FR-6)" (`export_file` is `[FILTERED]`) |
| FR-7 | AC-3.3, AC-3.4 and AC-3.5 |
| FR-8 | AC-5.1 and AC-5.2 |
| FR-9 | `spec/collection_import_core_spec.rb`, "exists, every file of it" and "never names a collectible type or a source" (the reader, the rules, the controller, both views and the helper) |

## AC-1.10: a 50,000-row preview

**Method.** On the development machine (Ruby 4.0.7, a 4-core Intel Xeon E3-1270 v3 at 3.5 GHz, Fedora 44), in the development database. A throwaway `bin/rails runner` script in the session scratchpad (never committed) inserted one set, 50,000 identities, 50,000 entries and their `mtg_printings` (finishes `nonfoil` and `foil`) with `insert_all`, a verify user, and an applied refresh run, all tagged `verify025`; and wrote three pretty-printed files of 50,000 rows each (about 22 MB): **resolvable** (every row names an inserted entry), **unresolvable** (every `source_id` unknown) and **bad price** (`"price_paid": "1"` on every row). For each file: a fresh `bin/dev` server; sign in with curl (cookie jar, the session form's token); one warm-up preview of `docs/export-format/examples/valid/collection.json`; read Puma's `VmRSS` (and, in the re-run, `VmHWM`) from `/proc/<pid>/status`; `curl -F export_file=@<file> -w "%{http_code} %{time_total}"` to `/collection/import_preview` with the form's CSRF token; read `VmRSS` and `VmHWM` again. The time is the whole request as curl saw it. The inserted rows were deleted afterwards (the dev database then held 0 users, accounts, entries, lots, refresh runs, printings, identities and sets), and every page showed the "catalog not loaded" notice, since the seed loads no real catalog.

**Bars:** under 30 seconds and under 500 MB of RSS growth (decisions 12 and 13).

### First run, at `7191f45` (whole-file schema pass): misses the memory bar

| File | Status | Time | RSS before | RSS after | Growth | VmHWM after |
|---|---|---|---|---|---|---|
| Resolvable | 200 | 10.98 s | 160,944 kB | 1,204,856 kB | **+1,019 MB** | 1,266,360 kB |
| Unresolvable | 200 | 10.25 s | 160,216 kB | 1,191,628 kB | **+1,007 MB** | 1,267,584 kB |
| Bad price | 200 | 10.70 s | 160,464 kB | 1,360,252 kB | **+1,171 MB** | 1,360,252 kB |

The time bar passes; the memory bar fails by about two times. An earlier pass with all three files on one server gave 11.39 s / +1,055 MB, 8.97 s / +161 MB and 8.38 s / −75 MB; Ruby keeps memory it has grown, so the later files there understate their cost, and the fresh-server figures are the ones recorded.

Where it goes, measured with a runner script outside the server (RSS within one process, cumulative):

| Stage | Resolvable | Bad price |
|---|---|---|
| After reading the file | 146 MB | 146 MB |
| After `JSON.parse` | 203 MB | 203 MB |
| After `ExportFormat::Rules.problems_in` (the whole-file `json_schemer` pass) | 1,056 MB (9.5 s) | 1,280 MB (10.4 s) |
| After the full `CollectionImport` | 1,225 MB | 1,802 MB |

Almost all of the growth is the schema pass, which holds a result tree for every lot, as the plan review predicted. Decision 13 sent the fallback to the maintainer, who ruled Option A.

### Re-run, at `861f076` (per-lot schema pass): passes

Same method and files (regenerated byte-identical, checked by MD5), a fresh server per file on port 3014.

| File | Status | Time | RSS before | RSS after | Growth | Peak growth (VmHWM − before) | The page |
|---|---|---|---|---|---|---|---|
| Resolvable | 200 | 10.63 s | 161,048 kB | 485,104 kB | **+316 MB** | 316 MB | Lots added 50,000 |
| Unresolvable | 200 | 8.29 s | 161,116 kB | 303,492 kB | **+139 MB** | 139 MB | "Not in this instance's catalog": 50,000 rows; 100 listed, "and 49,900 more" |
| Bad price | 200 | 8.55 s | 160,104 kB | 283,296 kB | **+120 MB** | 133 MB | "price_paid isn't valid": 50,000 rows; 100 listed, "and 49,900 more" |

Every file passes both bars: the slowest is 10.6 s against 30 s, the largest growth 316 MB against 500 MB.

Stages, the same runner script (`problems_in` is now the per-lot pass):

| File | Start | Read | Parsed | `problems_in` | Full `CollectionImport` |
|---|---|---|---|---|---|
| Resolvable | 126 MB | 146 MB | 203 MB | 264 MB (0 problems, 6.6 s) | 518 MB (9.0 s) |
| Bad price | 125 MB | 146 MB | 203 MB | 273 MB (50,000 problems, 7.7 s) | 361 MB (8.6 s) |

The schema check now adds about 60 to 70 MB. The last stage overstates a request: it runs a whole `CollectionImport` while the earlier stages' bytes and parsed data are still held, which is why 518 MB is above the server's 485 MB.

## AC-3.4 by hand: a 41 MB body

Against the running Puma (`bin/dev`, development): `curl -X POST -H "Content-Type: application/octet-stream" --data-binary @big.bin …/collection/import_preview`, with `big.bin` 41,000,000 bytes of zeros, unauthenticated. curl sent `Content-Length: 41000000` with `Expect: 100-continue`; Puma answered `100 Continue`, then **`413 Content Too Large`** with `connection: close` and the 17-byte body "Payload Too Large", after 0.001 s and 524,288 bytes sent. A signed-in multipart upload of the same file also got **413** (after 196,608 bytes); the connection wasn't reset.

Only Puma was exercised locally. Thruster's limit (`ENV MAX_REQUEST_BODY="40000000"` in the `Dockerfile`) and kamal-proxy's (`proxy.buffering.max_request_body: 40_000_000` in `config/deploy.yml`) are configured, checked by `spec/config/request_body_limit_spec.rb`, and verified by reading; no image or proxy was run.

## Screenshots (AC-5.4)

[screenshots/](screenshots/), twelve PNGs (commit `f38451e`, about 1.1 MB in all):

- `upload-1280-light.png`, `upload-1280-dark.png`, `upload-390-light.png`, `upload-390-dark.png`: the upload page.
- `refused-1280-light.png`, `refused-1280-dark.png`, `refused-390-light.png`, `refused-390-dark.png`: a file in EUR, refused with "This file's prices are in EUR. This instance uses USD."
- `preview-1280-light.png`, `preview-1280-dark.png`, `preview-390-light.png`, `preview-390-dark.png`: 1 lot added, 1 changed, 3 unchanged, 2 removed (listed), profile notes for a view change and another name, and 5 rows with problems (an unknown printing, an etched finish the printing doesn't come in, a bad price, `changed_at` before `added_at`, a duplicate), one with a long name that wraps.

Taken with a throwaway script outside the repository: headless Firefox through Selenium, submitting the real form, the dark ones with Firefox's dark preference; the 390px shots through a fixed-width same-origin iframe, since headless Firefox won't open a window that narrow. The script found no horizontal overflow on any of the twelve pages (at 390px the frame's `innerWidth` was 390 and its `scrollWidth` 378, the scrollbar's difference). Everything is shown in full.

Looked at:

- At 390px a long line's count (the "×3" after a removed lot with a long description, "1 row" after "Same card, finish, condition and price as an earlier row") wraps to its own right-aligned line. It reads correctly.
- The problem counts and the numbered rows are two lists back to back, so a slightly heavier double rule shows between them.
- In the refused state the file input, the browser's own control, gets no invalid border; the red message under it marks the field.
- No screenshot shows a non-zero "Held by rows with problems" count; the request and model examples cover it (AC-1.11, and `#held_lots` in AC-1.2's request example).

The preview page isn't in the 360px system spec (`spec/system/narrow_pages_spec.rb` opens pages by GET, and the preview renders from a POST); the upload page is. The screenshots cover the preview at 390px.

## Deviations from the plan

- **Phase 2, `Row#text`:** the plan's `def text(value) = value if value.is_a?(String)` is written `def text(value) = (value if value.is_a?(String))` (`app/models/collection_import.rb`, line 56), so the endless method's body is the whole conditional rather than a modifier on the definition.
- **Phase 2, `read_rows`'s `failed` set:** the plan built it from every problem's pointer; the code leaves out `duplicate_lot` pointers (`app/models/collection_import.rb`, `read_rows`, line 196, with the comment "A duplicate is found by its identity, so its own pointer doesn't make that identity unreadable."). Otherwise a duplicate row's identity would be unreadable and the held lot it names couldn't be counted through the pair (decision 1).
- **Phase 3, AC-1.2's request example:** it builds its three held lots with matching times in a loop (`{ a => 3, b => 2, c => 4 }.each { … }`) instead of three `create` lines, to keep the example within RuboCop's 15-line limit (`spec/requests/collection_import_previews_spec.rb`, "shows what applying the file would do (AC-1.2)").
- **Phase 3, AC-1.8's example:** it builds the file (`data = file(…)`, which creates printings) before taking the snapshot, so the snapshot compares only what the preview does (`spec/requests/collection_import_previews_spec.rb`, "writes nothing and queues nothing (AC-1.8)").
- **Phase 4:** none.
- **Phase 6, the per-lot schema pass:** the plan's named fallback, applied after the maintainer's ruling (decision 13). `ExportFormat::Rules.schema_problems` validates the file with `"lots" => []` and then each lot with `ExportFormat::Rules.lot_schemer` (`schemer.ref("#/$defs/lot")`), prefixing each lot's pointers with `/lots/<i>` and putting root-level errors after the lots' so the order matches a whole-file pass; data that isn't an object, or whose `lots` isn't a list, is still validated whole (`app/models/export_format/rules.rb`, line 26 and `schema_problems`, lines 72–78). `rules_spec.rb`'s "checking each lot on its own" examples prove the same problems in the same order as the whole-file pass on every example and nine variants. ADR 0021 gains an amendment and a consequence saying so.

## Documents (verified by reading)

Read in `git diff origin/main...HEAD` (against the merge base `6b422d1`):

- `CLAUDE.md`: the status line says a collector previews importing a file (`CollectionImport`, `/collection/import_preview/new`, spec 025) and applying isn't built; the Active Storage fact says no Active Storage upload exists and ADR 0013's owed validation stays with the first one; the export format fact names `CollectionImport`, `ExportFormat::Rules`, the schema's copy and `json_schemer` in the app's bundle; a new Import preview fact gives the routes, the 32 MB refusal and the 40 MB limits at Puma, Thruster and kamal-proxy.
- `README.md`: Compose gains an "Upload limit" bullet (40 MB at Puma and Thruster, above the 32 MB file limit; keep a reverse proxy's at 40 MB or more); Kamal gains a sentence on `buffering: max_request_body: 40_000_000`; the Kamal HTTPS step now says to uncomment `ssl: true` under `proxy:`, matching `config/deploy.yml`, whose `proxy:` is now uncommented; "Your data" says a collector can preview an import from the account menu or More and applying isn't in the app yet.
- `docs/roadmap.md`: theme A item 4 is **Done 2026-10-15** with links to spec 025 and ADR 0021 (the PR link is added once the PR exists).
- `docs/adr/README.md`: ADR 0021's line under Data safety.
- `docs/adr/0020-export-format.md`: the consequence about where import's copy of the rules lives links to ADR 0021.
- `docs/adr/0021-export-format-rules-in-the-app.md`: options A to C, Option A chosen, and the 2026-10-15 amendment for the per-lot pass with its consequence (the schema must keep the lot as `$defs/lot`).
- `docs/design-system/components/ImportPreview.md`: the pattern's markup (the form with `c-file`, `c-import`, `c-stats`, `c-import__list`, `c-import__rows`, `c-import__reasons`, `c-import__more`) and its rules, matching the two views. `docs/design-system/README.md` lists `ImportPreview` as spec 025's app addition.
- `docs/design-system/components/MorePage.md`: the "Import collection" row after "Export collection" in the markup, and a bullet saying it follows export and opens the upload page. `AppHeader.md` lists no menu items (only "import/export … live in the avatar menu"), so it isn't changed.
- `spec/support/export_format_rules.rb`: the header comment says well-formedness and lot identity are the app's (`ExportFormat::Rules`, ADR 0021) and the module passes them through.
- AC-5.5: the views use only `c-*` classes that exist in `components.css` or `additions.css`, and no inline styles; the new rules in `collector/additions.css` (`c-file`, `c-import`, `c-import__*`) use only token variables for colour, spacing and font family.
- `docs/export-format/` is unchanged (`git diff origin/main...HEAD --stat -- docs/export-format/` prints nothing).
- Spec 022 is unchanged (decision 14).
- The plan's stale-statement grep (`nothing reads`, `import isn't`, `no upload feature`) finds only the two new "applying … isn't" lines.

## The suite and CI

- `bin/ci` at `7191f45`: every step passed (Setup, RuboCop, Brakeman, bundler-audit, importmap audit); RSpec 1580 examples, 0 failures, 1 pending, seed 33583.
- `bin/rspec` at `861f076`: 1583 examples, 0 failures, 1 pending, seed 49764.
- **bin/ci at <SHA>: to be recorded**

The pending example predates this branch.

## Not checked here

- Thruster and kamal-proxy refusing a 41 MB body in a running image or deployment (configured and read only).
- A real phone (the 390px frame stands in for it) and a browser other than Firefox.
- The preview at 50,000 rows behind a reverse proxy with a short timeout: at about 11 s, a proxy timeout under that would cut it off.
