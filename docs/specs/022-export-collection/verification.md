# Verification: Export a Collection as a File (spec 022)

**Spec:** [spec.md](spec.md) v1.2.1 · **Plan:** [plan.md](plan.md) · **Branch:** `022-export-collection` · **Issue:** [#38](https://github.com/plainprogrammer/Collector/issues/38)

## Rulings

Both by the maintainer, 2026-10-14, with the spec's approval:

- **Decision 1:** the file is built and sent in the request, with no background job, held to a bar: at 50,000 lots the request completes in under 10 seconds and grows the process by under 300 MB (AC-1.9). Measured below: it does.
- **Decision 6:** "Export collection" in the account (avatar) menu, plus a row on More, as the design system's Navigation rule places import and export.

## The examples

`bin/rspec spec/models/collection_export_spec.rb spec/requests/collection_exports_spec.rb spec/collection_export_core_spec.rb spec/system/collection_export_spec.rb spec/requests/shell_spec.rb spec/requests/admin/navigation_spec.rb` on `6e8fe41` (headless Firefox for the system example):

```text
Finished in 10.48 seconds (files took 1.06 seconds to load)
31 examples, 0 failures
```

The plan's steps 1.2, 2.2 and 3.2 ran each new example red before its code. The implementers reported these lines:

| Step | Red | Green |
|---|---|---|
| 1.2 / 1.4 | `0 examples, 0 failures, 1 error occurred outside of examples` (`NameError: uninitialized constant CollectionExport`) | `12 examples, 0 failures` |
| 2.2 / 2.4 | `8 examples, 7 failures` (`NameError` on `collection_export_path`; the core spec `Errno::ENOENT`). "answers no format suffix" passed before the route existed; with the route present and `format: false` removed it fails (200, not 404), so it guards FR-4a | `20 examples, 0 failures` |
| 3.2 / 3.4 | `11 examples, 5 failures` (no link; the system example `Capybara::ElementNotFound`) | `11 examples, 0 failures`; `spec/system` 121 examples, 0 failures, 1 pending (the opt-in art agreement); `spec/requests` 383 examples, 0 failures |

## Acceptance criteria

| Criterion | Held by |
|---|---|
| AC-1.1 | `spec/requests/collection_exports_spec.rb`, "sends a well-formed file as an attachment that isn't cached": 200, `application/json`, `attachment; filename="collector-export-2026-10-14.json"` for a request at 23:59:59 UTC, `Cache-Control` with `no-store`. The UTC date across a time zone: `spec/models/collection_export_spec.rb`, "names the file by the export's UTC date" (23:30 at −05:00 → `2026-10-15`) |
| AC-1.2 | `spec/models/collection_export_spec.rb`, "writes a well-formed file of every shape a lot can take": `ExportFormatRules.problems` is empty for the fixture (finish, condition and price each set and `null`; `0.00`; `1000.05`; quantity `Lot::MAX_QUANTITY` (9,999); a Japanese printing whose `localized_name` is 稲妻; a retired entry; an entry of the unregistered type `comics` with no finish or condition; a `token` entry) |
| AC-1.3 | "writes the header, the profile and the currency" (the whole header, profile and currency, and no `generator`); "writes each lot's seven fields from the lot, its entry and its set"; "writes one lot per lot row, with nulls, free copies, exact prices and the catalog's name" (one lot per row, `name` is the catalog's, never `localized_name`) |
| AC-1.4 | "writes each lot's seven fields…": a lot created at `18:02:11.999` (stored with `with_usec: true`) and updated at `09:15:00.5` is written `18:02:11Z` and `09:15:00Z`: dropped, not rounded |
| AC-1.5 | "writes an empty collection as an empty list of lots" (model, well-formed); "sends an empty collection as a file with no lots" (request) |
| AC-1.6 | "writes the same file twice for an unchanged collection, apart from exported_at", which also asserts `ExportFormatRules.same_collection?` |
| AC-1.7 | `spec/requests/collection_exports_spec.rb`, "sends the visitor to sign in, with no file, and lands them on the collection afterwards"; "keeps a page an earlier request stored as the one to return to" (FR-4's last sentence) |
| AC-1.8 | "runs as many queries for 30 lots as for 2" (the whole request); the model's "reads the lots in one statement, whatever their number" (equal counts, and exactly one statement `FROM "lots"`) |
| AC-1.9 | The measurement below: 1.23 to 1.27 s and +60 to +66 MB at 50,000 lots |
| AC-2.1 | "writes only this account's profile and lots" (model) and "sends only the signed-in collector's account" (request): both accounts hold lots of one printing; the file's lots are the first account's; no lot has 8,888 or `"777.77"`; "Zebulon Otherperson" and `zebulon.otherperson@example.test` appear nowhere in the body |
| AC-2.2 | "writes the lots a scanner sitting added, and nothing of the sitting": the open sitting's lot is in the file; its reading key and the word `sitting` are not |
| AC-2.3 | "writes exactly the fields the format defines": `ExportFormatRules.field_names` of the file equals that of `docs/export-format/examples/valid/collection.json` without `generator` |
| AC-3.1 | `spec/requests/shell_spec.rb`, "links the account menu and More to the export, outside Turbo and never prefetched" (`data-turbo="false"`, `data-turbo-prefetch="false"`, no `download`, on the collection page and More) and "puts the export in the account menu for a collector who isn't an admin"; `spec/requests/admin/navigation_spec.rb`, "links Catalog and Jobs for an admin, on the More page and in the avatar menu" and "shows a member only the export, neither admin link" (the whole menu and More lists, in order, for each) |
| AC-3.2 | The first shell example: More's second row is "Export collection", after "Signed in as" |
| AC-3.3 | `spec/system/collection_export_spec.rb`, "downloads the collection from the account menu": Firefox saves `collector-export-<UTC date>.json` to `tmp/downloads` (waited for with `page.document.synchronize(10)`: bounded at 10 seconds, as the approved plan set it, rather than the spec's `Capybara.default_max_wait_time` (2 s, never set in this suite), and never a sleep), it passes `ExportFormatRules.problems` and holds the one lot, and "My collection" is still shown |
| AC-3.4 | The screenshots below |
| AC-3.5 | By reading, below |

## Functional requirements

| Requirement | Held by |
|---|---|
| FR-1 | `app/models/collection_export.rb`: `CollectionExport.new(account:, at:)`, `#to_h`, `#to_json` (`JSON.generate`), `#filename`; reads `@account.user` and `@account.lots` only. The model examples above |
| FR-2 | One `pluck` over `lots` joined to `catalog_entries` and `catalog_sets`, ordered by `lots.id`; AC-1.8's two examples |
| FR-3 | "writes nothing and enqueues nothing": no `INSERT`, `UPDATE` or `DELETE` statement, no job enqueued. The writer touches no file or cache (by reading) |
| FR-4 | `app/controllers/collections/exports_controller.rb`: `no_store`, then `send_data` as JSON, as an attachment, with the export's filename; `request_authentication` overridden to redirect without storing the page. AC-1.1 and AC-1.7's examples |
| FR-4a | `resource :export, only: :show, format: false` in `config/routes.rb`; "answers no format suffix" (`/collection/export.json` → 404) |
| FR-5 | AC-3.1 and AC-3.2's examples; `app/views/layouts/_appbar.html.erb` and `app/views/mores/show.html.erb` |
| FR-6 | `spec/collection_export_core_spec.rb`, "never names a collectible type, a source or the registry" |

## AC-1.9: the request at 50,000 lots

**Method.** A throwaway request spec outside the repository (the plan's scratch prototype, changed to go through the request), run with `bin/rspec <path>` in the test environment on this branch (`6e8fe41`). It inserts 50,000 `catalog_entries` of one set and one identity, and one lot for each in one account (quantity 4, `foil`, `near_mint`, 1250 cents), with `insert_all!`; signs in with `sign_in_as(user)`; runs `GC.start` and reads `VmRSS` from `/proc/self/status`; times `get collection_export_path` with `Process.clock_gettime(Process::CLOCK_MONOTONIC)` (Ruby 4 has no `benchmark` library); reads `VmRSS` again. The time and the RSS growth cover the whole request through the Rack stack (routing, authentication, the writer, `send_data` and `Rack::ETag`'s digest) as the integration session runs it in-process. The body was then checked with `ExportFormatRules.problems` and parsed for its lot count. Ruby 4.0.7 on a 4-core Intel Xeon E3-1270 v3 at 3.5 GHz, Fedora 44.

| Run | Status | Lots in the file | Time | Body | RSS before | RSS growth | Problems |
|---|---|---|---|---|---|---|---|
| 1 | 200 | 50,000 | 1.23 s | 16.0 MB | 369 MB | +60 MB | none |
| 2 | 200 | 50,000 | 1.23 s | 16.0 MB | 369 MB | +60 MB | none |
| 3 | 200 | 50,000 | 1.27 s | 16.0 MB | 363 MB | +66 MB | none |

A fourth run, to see the example's own pass line, read 1.25 s, 16.0 MB, +60 MB (`1 example, 0 failures`). The bar is 10 s and 300 MB: the request takes about an eighth of the time and a fifth of the memory. The writer alone, measured before planning, was 1.28 s and +68 MB. A body of 16.0 MB for 50,000 lots is the 320 bytes per lot the spec estimated.

**Rack::ETag.** The response carries `Cache-Control: no-store`, but `Rack::ETag` (rack 3.2.7, `lib/rack/etag.rb`) still digests the body: it skips only a response that already has an `ETag` or `Last-Modified` header, whatever its `Cache-Control`. That is one extra pass over the body per export, which the measurement above includes. Harmless at these sizes; nothing is changed for it.

## Screenshots (AC-3.4)

[screenshots/](screenshots/), four PNGs, about 170 KB in all: the account menu open on the collection page at 1280px (`menu-1280-light.png`, `menu-1280-dark.png`), and the More page at 390px (`more-390-light.png`, `more-390-dark.png`; a fixed-width frame, since headless Firefox won't open a window that narrow). Taken with a throwaway script outside the repository, as spec 021's were, for a collector who isn't an admin.

Looked at: the menu reads "Export collection", a separator, "Sign out"; More reads "Signed in as", "Export collection", "Sign out". The label is shown in full in each, the focus ring shows on the link, and nothing scrolls sideways at 390px, in both themes.

## Documents (AC-3.5, verified by reading)

- `docs/design-system/components/MorePage.md`: the markup has the "Export collection" row after "Signed in as", and a bullet says it is a plain download link outside Turbo, never prefetched, for every collector and so before the admin links.
- `spec/support/export_format_rules.rb`: the header comment says the app writes the format (`CollectionExport`, spec 022) but has no import yet.
- `README.md`, "Your data": export is built against the format, from the account menu or More; import isn't in the app yet.
- `CLAUDE.md`: the status line says a collector downloads their collection from the account menu or More (`CollectionExport`, `/collection/export`, spec 022) and import isn't built; the export-format fact says `CollectionExport` writes it and nothing reads it yet.
- `docs/roadmap.md`: theme A item 3 is marked **Done 2026-10-14** with a link to this spec, as items 1 and 2 are.
- `spec.md`: every acceptance box is ticked, each as recorded above.

The format document, its schema, its examples and its Coverage tables are unchanged (`git diff origin/main -- docs/export-format/` prints nothing).

## Not checked here

- `bin/ci` runs before the push and is recorded with the pull request.
- A real phone (the 390px frame stands in for it) and a browser other than Firefox.
- An export behind a reverse proxy with a short timeout: at 1.2 s for 50,000 lots, none is expected.
