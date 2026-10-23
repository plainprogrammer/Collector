# Implementation Plan: Manage Locations

**Spec:** docs/specs/029-manage-locations/spec.md (v1.3.2, Approved)
**Status:** Approved by the maintainer on 2026-10-21, after its two independent reviews (the first NEEDS REVISION, the second APPROVE WITH NITS, each finding and its fix in [plan-review.md](plan-review.md)) with the second review's nits folded in; the maintainer chose Sonnet to execute it. ADR 0023 is accepted in Phase 6
**Decisions:** docs/adr/0023-locations-make-export-format-version-2.md (Proposed, written with this plan); ADR 0016, 0017, 0019, 0020, 0021, 0022 apply
**Created:** 2026-10-21 (on `origin/main` at `acb6e3c`, after spec 028 merged in PR #120 and its plan was retired in PR #121)
**Supporting:** [data-model.md](data-model.md), [contracts/api.md](contracts/api.md), [research.md](research.md), [plan-review.md](plan-review.md)

## Global Constraints

Copied from the spec; each applies to every phase.

- One pull request: the pages, the navigation, format version 2 (document, schema, examples, Coverage), the export, and the preview's and apply's reading of version 2 (decision 13).
- A location has one attribute, its name (decision 4). Names: NFC; White_Space trimmed at both ends and each inner run made one U+0020; a Cc or Cf character left refuses the name; 1 to 60 Unicode code points; the comparison key is the Unicode full case folding of the normalised name; no two of an account's locations share a key; renaming to a name with its own key is allowed (decision 5).
- At most 500 locations per account, enforced in the creating transaction and in the format (`maxItems`) (decision 7). Locations are listed and exported by key, then name, both in code-point order (decision 2, P2).
- Removing a location never deletes, changes or merges a lot (decision 3).
- Routes and words: `GET /locations`, `GET /locations/:id/edit`, `GET /locations/:id/removal/new`, `POST /locations`, `PATCH /locations/:id`, `DELETE /locations/:id`; a success redirects 303 with the notice of decision 6 quoting the normalised name; a failed create or rename answers 422 with the reason beside the field and the typed text kept; the page works without scripting; the copy names no collectible type (decision 6).
- Navigation: "Locations" after "Scan" in the header, a "Locations" row in More before "Export collection", no tab bar change, no tab marked current on the locations pages, not in the account menu (decision 8).
- Format version 2: a required top-level `locations` list of `{ "name" }`; `v1.schema.json` and its examples never change; the export always writes version 2; a name in a file need not be NFC and is normalised on read; `duplicate_location` is judged on comparison keys; "the same collection" compares location names exactly as written; no internal id in a file (decisions 1, 2, 9).
- The preview and the apply read versions 1 and 2, each against its own schema; a version above 2 is refused as newer ("This instance reads version 2."); a bad `locations` refuses the file whole; version 2 replaces locations by comparison key (Added, Renamed, Unchanged, Removed); a version 1 file leaves locations alone (decision 10).
- The apply writes locations in spec 028's one write transaction, in a bounded number of statements, keeping the id of every location it keeps and not writing an unchanged one; the plan, fingerprint, confirmation ("I understand this removes N lots and M locations") and notice cover locations; a location-only or view-only apply clears no working state (decision 11, AC-9.17).
- Everything goes through `Current.account`; another account's id answers 404; the admin pages never show a location (decision 12).
- Spec 028's stored upload, expiry, sweep, bars (whole request under 30 s, write transaction under 4 s, under 500 MB RSS growth) and the working state it clears when it writes lots are unchanged (decision 11).
- No migration edits to released migrations; no application models in migrations; the migration is safe to run unattended (`.claude/rules/sqlite-and-migrations.md`).
- Core code names no collectible type: the new files contain neither `MTG` nor `Scryfall` (FR-2).
- UI uses only design-system tokens and `c-*` classes; a new pattern is in `collector/additions.css` with a doc under `docs/design-system/components/` and a line in the README's app additions.
- Every phase ends green (plan review M3): its last step is the whole `bin/rspec` passing, and an expectation of an existing spec that the phase makes false is changed in that phase, never in a later one. A phase's own run list is for speed while working, not for the end.
- TDD is the hard gate: every implementation step has a failing test before it. Prose documents are verified by reading and recorded in `verification.md`, never by RSpec (`.claude/rules/testing.md`); the export format's document is the one exception.
- Plans here are not executed before approval: this plan was traced against the files it edits and a read-only probe of Ruby's Unicode functions and `json_schemer` (research.md); an executor runs every step.

---

## Goal

A signed-in collector creates, renames and removes the named places their collection is kept in; their export (format version 2) carries those names; and the import preview and apply read that file, replacing the collector's locations by name along with their lots, all or nothing.

---

## Scope Check and Gates

One outcome, ruled to stay in one pull request (decision 13); nine stories. No split.

- **Simplicity (≤3 components):** (1) `Location` with its pages (model, `Location::Name`, two controllers, three views, navigation); (2) format version 2 (`ExportFormat::Rules` reading two versions, `v2.schema.json`, the export, the document, examples, Coverage); (3) the import's locations (`CollectionImport::Locations`, the changes to `Plan`, `Apply`, the preview and notice). No new dependency (`json_schemer` is already in the bundle).
- **Anti-abstraction:** `String#unicode_normalize`, `downcase(:fold)`, Active Record validations and unique index, `upsert_all` (as spec 028 uses for lots) and `form_with` are used directly. `Location::Name` is one module of three functions because the model, the reader and the schema must agree on one definition (AC-7.8); it is not a wrapper.
- **Integration-first:** `contracts/api.md` and `data-model.md` precede code; Phase 0 starts with the failing model specs and the migration; Phase 2 starts with the schema and the parity spec.

## Areas and supersessions

- **Area docs to change:** the data portability and collection-and-lots area docs do not exist yet (`docs/architecture/README.md` lists them as not written; slices #108, #109). Nothing to write there now; `CLAUDE.md` gains a line (Phase 6). `distill-feature` writes the area docs at the end.
- **Supersedes** (recorded in spec 029's Supersedes table and in `docs/specs/README.md`, not by editing earlier specs): ADR 0020's consequence about version 2 (by ADR 0023); spec 017 decision 14, AC-3.3 and its version-history sentence; the roadmap's item 10; specs 022, 025, 028 and 004/009/023 as listed in the spec.

## File Structure

| File | Responsibility |
|---|---|
| `db/migrate/20261021100001_create_locations.rb`, `db/schema.rb` | The `locations` table (FR-1) |
| `app/models/location.rb` | The model: validations, order, the race rescue |
| `app/models/location/name.rb` | `Location::Name`: normalise, key, fault (decision 5) |
| `app/models/account.rb` (edit) | `has_many :locations` |
| `config/routes.rb` (edit) | The locations routes |
| `app/controllers/locations_controller.rb`, `app/controllers/locations/removals_controller.rb` | The pages' actions |
| `app/views/locations/{index,edit}.html.erb`, `app/views/locations/removals/new.html.erb` | The pages |
| `app/views/layouts/_appbar.html.erb`, `app/views/mores/show.html.erb` (edit) | The header link and the More row |
| `app/assets/stylesheets/collector/additions.css` (edit) | `c-locations` rules |
| `app/models/export_format/rules.rb` (edit), `app/models/export_format/v2.schema.json` | Two versions, `duplicate_location`; the app's copy of v2 |
| `docs/export-format/{README.md,v2.schema.json}`, `docs/export-format/examples/**` | The format document, schema, examples |
| `app/models/collection_export.rb` (edit) | Writes version 2 with `locations` |
| `app/models/collection_import.rb` (edit) | Versions 1 and 2, refusals, `locations`, `plan`, `replan` |
| `app/models/collection_import/locations.rb` | What applying does with locations (Added, Renamed, Unchanged, Removed) |
| `app/models/collection_import/location_changes.rb` | The apply's writes of locations (two statements) |
| `app/models/collection_import/plan.rb`, `apply.rb` (edit) | The plan, fingerprint, confirmation; where locations and working state are written |
| `app/controllers/collections/imports_controller.rb` (edit) | The notice |
| `app/views/collections/import_previews/{show,_apply,_locations}.html.erb`, `app/helpers/import_previews_helper.rb` (edit) | The Locations section, the removal wording |
| `spec/factories/locations.rb`, `spec/support/import_helpers.rb`, `spec/support/export_format_rules.rb` (edit) | Builders and the suite's version-aware rules |
| `spec/models/location/name_spec.rb`, `spec/models/location_spec.rb`, `spec/models/location/name_parity_spec.rb` | Model specs and the parity proof (AC-7.8) |
| `spec/requests/locations_spec.rb`, `spec/system/locations_spec.rb` | The pages, tenancy, navigation, widths |
| `spec/models/collection_import/{locations_spec,plan_spec,apply_spec,round_trip_spec}.rb`, `spec/models/collection_import_spec.rb`, `spec/requests/collection_import_previews_spec.rb`, `spec/requests/collection_imports_spec.rb` (edit/new) | Preview and apply of version 2 |
| `spec/export_format_document_spec.rb`, `spec/export_format_examples_spec.rb`, `spec/models/export_format/rules_spec.rb`, `spec/models/collection_export_spec.rb`, `spec/requests/collection_exports_spec.rb` (edit) | Version-aware format specs |
| `spec/requests/{shell_spec,number_entries_spec,admin/navigation_spec}.rb` (edit) | More's rows shift by one |
| `docs/...` | See Phase 6 |

---

## Requirement Map

Every story → phase → the first failing test.

| Requirement | Phase | First failing test |
|---|---|---|
| FR-1 (locations), AC-1.5 to 1.11, 1.13, 2.3, 2.4, 3.5 | 0 | `name_spec` ".normalise"/".fault"; `location_spec` "refuses…", "caps at 500" |
| AC-4.6 | 0 | `location_spec` "goes with its account" |
| Coverage of `locations` (spec 017 AC-3.4, AC-3.5) | 0 | `export_format_document_spec` "accounts for every table…" (fails the moment the table exists) |
| FR-2, Story 1 (AC-1.1 to 1.4, 1.12, 1.14), Story 2, Story 3 | 1 | `locations_spec` "shows the empty state", "adds…", "renames…", "removes…" |
| Story 4 (AC-4.1 to 4.5) | 1 | `locations_spec` "tenancy", "admin pages" |
| Story 5 (AC-5.1 to 5.5) | 1 | `locations_spec` "links Locations…"; system "fits 360px, 640px" |
| FR-4, Story 7 (AC-7.1 to 7.8) | 2 | `rules_spec` "reads version 2 against its own schema"; `name_parity_spec` |
| FR-3, Story 6 (AC-6.1 to 6.8) | 3 | `collection_export_spec` "writes version 2 with locations" |
| FR-5 (reading), Story 8 (AC-8.1 to 8.9) | 4 | `collection_import_spec` "reads version 2"; `locations_spec` (import) "counts"; previews request spec |
| FR-5 (apply), Story 9 (AC-9.1 to 9.18) | 5 | `apply_spec` "restores a version 2 file's locations (AC-9.1)" |
| NFR performance, AC-9.16, cost | 6 | By measurement |
| Documents that change | 6 | By reading |

---

## Spec 028 references

Spec 029 cites spec 028 "as approved at `87308d5`" and "as 028 states them when it merges". Re-checked against `docs/specs/028-apply-import/spec.md` v1.3.4 (the plan, retired in `ee4c4fa40e2223e2d81299885f8a0cabe7771956`, read with `git show ee4c4fa40e2223e2d81299885f8a0cabe7771956^:docs/specs/028-apply-import/plan.md`), ADR 0022, and the code at `origin/main` `acb6e3c`. **Still true** = no change to what 029 requires; **changed** = the merged form differs, with how; **now concrete** = the class, method, constant or number behind the citation. One PATCH (spec 029 v1.3.1, `ef08c5c`) corrected the citations that were stale; it changes no behaviour. Rows 23 and 24 were rulings the maintainer made on 2026-10-21 after the plan review, recorded as PATCH v1.3.2 (`e7285b1`). No question is awaiting the maintainer.

| # | Spec 029 says (where) | Status | What 028 is as merged |
|---|---|---|---|
| 1 | "028 as approved at `87308d5`", "being revised in parallel": an apply with nothing to change is refused, working state is cleared only when the apply writes, Active Storage routes are gated, the write transaction has a hard bar under 4 s (header) | **Changed** (the four revisions landed; header was stale) | Decision 12 is `CollectionImport::Apply#decide` answering `:nothing_to_change`; decision 7 is `Apply#write!` clearing; decisions 8 and 9 are `ActiveStorageGate` (`app/controllers/concerns/active_storage_gate.rb`, `config/initializers/active_storage_gate.rb`); decision 3's bar is in verification (row 14). Merged at `5cca2fb` (PR #120); the plan was retired in PR #121. **PATCH 1.3.1** rewrote the header. |
| 2 | The apply "already exists and reads version 1 only" (decision 10) | **Still true; now concrete** | `ExportFormat::Rules::VERSION = 1`; `CollectionImport#header_refusal` refuses `version > ExportFormat::Rules::VERSION` with `newer(version)`. Phase 2 adds `VERSIONS = [1, 2]` and makes `VERSION` the newest. |
| 3 | "This instance reads version 2." replaces "version 1" (decision 10, AC-8.6) | **Now concrete** | `CollectionImport#newer` builds "…This instance reads version #{ExportFormat::Rules::VERSION}." from the constant, so `VERSION = 2` gives the sentence with no copy edit. |
| 4 | "Nothing to change … now means a plan with no added, changed or removed lot, no added, renamed or removed location, and no view change" (decision 10) | **Still true; now concrete** | `CollectionImport::Plan#nothing_to_change?` (lots and view only today). The preview page (`show.html.erb`), `Collections::ImportPreviewsController#create` (the store condition) and `Apply#decide` (`:nothing_to_change`) all read that one method, so extending it extends all three (Phase 5). |
| 5 | The plan and fingerprint "cover locations" (decision 11) | **Still true; now concrete** | `Plan#fingerprint(file_checksum)` hashes `[checksum, added rows, changed rows with each held lot's id/quantity/exact times, removed lots by id, view_change]`; `ImportUpload.store!` calls it with `blob.checksum`; `Apply#stale` stores the new one. Phase 5 appends a locations part only for a version 2 file. |
| 6 | 029 "builds on 028's `POST /collection/import`, its stored upload, its single all-or-nothing write transaction and its plan fingerprint" (decision 11) | **Still true; now concrete** | `Collections::ImportsController#create`; `ImportUpload` (one per account, `EXPIRES_IN` 1 hour, `remove!`); `ImportUpload.transaction` in `Apply#decide`; `Apply#write!`; `Plan#fingerprint`. |
| 7 | "The parse and the resolve of the file stay outside" the transaction (decision 11) | **Still true; now concrete** | `Apply#call` reads and judges (`CollectionImport.new`, `rows_to_write`) before `decide`; inside, only `import.replan` (one read of the lots and the user), the fingerprint comparison and the writes. Locations follow it: `CollectionImport#locations` is memoized on first use, so in the apply it is first read inside `replan`, in one statement of at most 500 rows, which is within 028 FR-2 (one read of the lots, the locations and the user, no parsing); a preview reads it once in the request. |
| 8 | The checkbox "I understand this removes N lots" becomes "…N lots and M locations" (decision 11, AC-9.10) | **Still true; now concrete** | `_apply.html.erb` writes "I understand this removes #{pluralize(plan.removed_lots.size, "lot")}" inside `if plan.removes?`; the controller reads `params[:confirm_removal] == "1"`; `Apply#decide` answers `:unconfirmed` (422 "Confirm the removal to apply this file") when `plan.removes? && !@confirmed`. `Plan#removes?` is extended; the label comes from a helper. |
| 9 | 028 decision 7 clears the lists "whenever the apply writes" and 029 narrows 028's "whatever the plan" (decision 11, Supersedes, AC-9.17) | **Changed** (quote stale; requirement unchanged) | Merged decision 7 reads "whenever the apply writes", and `Apply#write!` calls `CollectionImport::WorkingState.clear!(@account)` unconditionally, so a view-only apply clears today. 029 requires clearing only when a lot is written: Phase 5 makes it `clear! if plan.writes_lots?`. **PATCH 1.3.1** corrected the quotations (decision 11, Supersedes row). No 028 spec example depends on the view-only clearing (`apply_spec` "working state" uses a lot change). |
| 10 | "Spec 028's round-trip specs (its Story 6) gain locations" (decision 11, AC-9.5, AC-9.6) | **Still true; now concrete** | `spec/models/collection_import/round_trip_spec.rb`: helpers `export`, `same_collection?` (profile name and email apart) and `apply!`; examples "has nothing to change for the collection that was exported" (AC-6.1), "restores an export into an empty account" (6.2), "restores a changed collection" (6.3), and the `collection.json` example (6.4). Phase 5 extends them. |
| 11 | A failure "raised while a location is written, after the lots were written (injected in the spec)" (AC-9.8; 028 AC-2.1) | **Now concrete** | 028's AC-2.1 example stubs `CollectionImport::WorkingState.clear!` to raise after the lot writes (`allow(...).to receive(:clear!).and_raise`). Phase 5 adds the collaborator `CollectionImport::LocationChanges.write!`, called after the lot writes, and stubs it the same way. |
| 12 | Each valid example "that resolves against the catalog the spec builds applies to an empty account" (AC-9.15; 028 AC-6.4) | **Still true; now concrete** | `round_trip_spec.rb` "the format's valid example with lots": `build_catalog(data)` creates one entry and printing per source id; `empty.json` is previewed in `collection_import_previews_spec` "previews the format's empty example, in its own currency, as nothing to change". Phase 3 keeps the version 1 examples in that loop and Phase 5 widens it to every valid example of both versions. A version 1 example exports as version 2, so the comparison adds the version and the empty `locations`; each location name in the example passes through `Location::Name.normalise` first, because the export writes NFC and `valid/locations-nfd.json` holds an NFD name (ruled 2026-10-21, AC-9.15; a deviation noted in `verification.md`). |
| 13 | AC-8.8: "what spec 028 AC-1.11 allows (the account's one stored upload)" | **Still true; now concrete** | `ImportUpload` row, its `ActiveStorage::Blob` and attachment; `collection_import_previews_spec` "writes only the upload, its blob and its attachment". |
| 14 | AC-9.16: 028's bars "as 028 states them when it merges" | **Now concrete** | Whole request under **30 s**, write transaction under **4 s** (hard; a development-machine bar, ruled 2026-10-21, with a note in README and `docs/releasing.md`), under **500 MB** RSS growth (028 decisions 3 and AC-1.10). 028 measured: transaction (a) 2.39 s, (b) 3.21 s (margin 0.79 s), (c) 0.93 s; whole request 6.72 s, 7.56 s, 0.91 s; preview RSS growth +408 MB for (a) (margin 92 MB, from reading the upload twice). 029 adds at most 500 rows read and two statements, so the plan must not read the upload a third time or hold more than the 500 names (Phase 6 re-measures). |
| 15 | AC-4.4: a write with no session cookie "fails forgery protection first (422), as spec 025 and spec 028 say" | **Still true** | 028's error table, last row; `collection_imports_spec` "refuses a post without the CSRF token" sets `ActionController::Base.allow_forgery_protection = true` and resets it in `ensure`. |
| 16 | 028 decision 5 "replace, exactly: lots and the profile only" extended by locations | **Still true; now concrete** | `Apply#write!`: delete removed lots, `Lot.upsert_all` added and changed, clear working state, set `collection_view`. Phase 5 inserts the locations write after the lots and before the view. |
| 17 | The notice "Imported: 3 lots added, 2 changed, 1 removed" (AC-9.14) | **Still true; now concrete** | `Collections::ImportsController#notice_for(counts)`: `"Imported: #{helpers.pluralize(counts[:added], "lot")} added, #{counts[:changed]} changed, #{counts[:removed]} removed"`, no final period; zero lot parts are kept. The locations part follows after "; " with no final period either (row 24, ruled; Phase 5). |
| 18 | The list limit "the first 100 and then 'and N more'" (decision 10, P3; spec 025 decision 11) | **Now concrete** | `CollectionImport::LIST_LIMIT = 100`; the pages print "and N more" in `p.c-import__more`. |
| 19 | 028's "Seams for spec 029" (its plan): the plan, `Apply#write!`, `lot_attributes` | **Still true** | `Plan` is the one place that lists what an apply writes, `Apply#write!` the one place that writes it, `lot_attributes(row, import)` maps a row to a lot. 029 extends the first two and leaves `lot_attributes` alone. |
| 20 | "Spec 028's plan and code … the apply it introduced is extended, not rewritten" (Documents that change) | **Still true** | The plan is retired; 029 reads the code and `git show` of the retired plan. |
| 21 | 028 "its stored upload, expiry, sweep, … stand" (Supersedes row) | **Still true** | `ImportUpload::SweepJob` (every 15 minutes, `config/recurring.yml`) only releases expired uploads and marked orphan blobs; it never touches the `locations` table. Nothing in 029 changes it. |
| 22 | Spec 028 1.3.4's price rule (not cited by 029) | **No effect** | Version 2 files go through the same row reading (`price_too_large`), unchanged. |
| 23 | AC-9.9: "a held location deleted and added again with the same spelling … fingerprints are equal, and the apply goes ahead" | **Interpreted → resolved by the maintainer's ruling of 2026-10-21 (spec 1.3.2)** | The plan review (M4) found that decision 11 ("its id") and AC-9.9 (unconditional) disagree for a renamed or a removed location, whose re-created row has a new id. Ruled: the fingerprint holds no id. It holds, for a renamed location, `[current name, file's name]`, and for a removed location, `[name]`; an unchanged location is not in it. The apply re-reads the held locations inside its transaction (`replan`) and writes by the ids it finds, so an id adds no safety. AC-9.9 now holds as written for every case. Phase 4 changes `fingerprint_part`; Phase 4 and Phase 5 test a renamed, a removed and an unchanged location deleted and re-created with the same spelling (equal fingerprint, apply goes ahead). |
| 24 | AC-9.14: "each part left out when it is zero" | **Interpreted → resolved by the maintainer's ruling of 2026-10-21 (spec 1.3.2)** | Ruled: the notice never ends with a period, for any file, as 028's has none; a location part whose count is zero is left out (and the whole part when all three are zero); a lot count that is zero stays, as in 028. So a location-only apply reads "Imported: 0 lots added, 0 changed, 0 removed; 1 location added", and a version 1 file reads "Imported: 1 lot added, 0 changed, 0 removed". The noun goes on the first location part that is not zero. Phase 5 changes `notice_for` and its examples. |
---

## Phase 0: The locations table, its model and the name function

**Implements:** FR-1, decisions 4, 5, 7; Reliability | **Satisfies:** AC-1.5 to AC-1.11, AC-1.13 (the cap in the creating transaction), AC-2.3, AC-2.4, AC-3.5, AC-4.6, and spec 017 AC-3.4 and AC-3.5 (the new table is listed in Coverage in the phase that adds it)
**Files:** `db/migrate/20261021100001_create_locations.rb`, `db/schema.rb`, `app/models/location.rb`, `app/models/location/name.rb`, `app/models/account.rb`, `spec/factories/locations.rb`, `spec/models/location/name_spec.rb`, `spec/models/location_spec.rb`, `docs/export-format/README.md` (Coverage only), `spec/export_format_document_spec.rb`
**Interfaces:** Consumes: nothing. Produces: `Location::Name.normalise(text) -> String`, `Location::Name.key(normalised) -> String`, `Location::Name.fault(normalised) -> :blank | :control | :too_long | nil`, `Location::Name::MAX_LENGTH` (60); `Location` (`account`, `name`, `name_key`, `typed`, `Location.ordered`, `Location::MAX_PER_ACCOUNT` (500), `Location::MESSAGES`, `#save` that answers false with the duplicate message when the unique index refuses); `Account#locations`; factory `:location`.

The name function is one module because the model, the reader of a file and the schema must agree (AC-7.8). The table is the uniqueness rule's home (the key, not `COLLATE NOCASE`).

- [ ] Write the failing specs and the factory:

```ruby
# spec/factories/locations.rb
FactoryBot.define do
  factory :location do
    account { association(:user).account }
    sequence(:name) { |n| "Binder #{n}" }
  end
end
```

```ruby
# spec/models/location/name_spec.rb
require "rails_helper"

# Spec 029 decision 5: one function makes what a collector types, and what a file holds, into a name.
RSpec.describe Location::Name, type: :model do
  describe ".normalise" do
    it "makes NFC (AC-1.11)" do
      expect(described_class.normalise("Cafe\u0301")).to eq("Café")
    end

    it "trims White_Space at both ends and makes each run inside one space (AC-1.5)", :aggregate_failures do
      expect(described_class.normalise("  Blue   binder ")).to eq("Blue binder")
      [ "\u00A0", "\u3000", "\t", "\u0085", "\u2028", "\n" ].each do |space|
        expect(described_class.normalise("Blue#{space}binder")).to eq("Blue binder"), space.dump
        expect(described_class.normalise("#{space}Blue binder#{space}")).to eq("Blue binder"), space.dump
      end
    end

    it "leaves a Cc or Cf character that isn't White_Space for .fault to refuse", :aggregate_failures do
      expect(described_class.normalise("a\u200Bb")).to eq("a\u200Bb")
      expect(described_class.normalise("a\u0007b")).to eq("a\u0007b")
      expect(described_class.normalise("日本語のバインダー")).to eq("日本語のバインダー")
    end

    it "returns text that isn't valid UTF-8 as it is, and nil as empty", :aggregate_failures do
      broken = "a\xFFb".dup.force_encoding(Encoding::UTF_8)

      expect(described_class.normalise(broken)).to eq(broken)
      expect(described_class.normalise(nil)).to eq("")
    end
  end

  describe ".key" do
    it "is the Unicode full case folding of the normalised name (decision 5)", :aggregate_failures do
      expect(described_class.key("Blue binder")).to eq("blue binder")
      expect(described_class.key("Straße")).to eq(described_class.key("STRASSE"))
      expect(described_class.key(described_class.normalise("Cafe\u0301"))).to eq(described_class.key("CAFÉ"))
    end
  end

  describe ".fault" do
    it "is nil for a name of 1 to 60 code points with no Cc or Cf character", :aggregate_failures do
      expect(described_class.fault("Blue binder")).to be_nil
      expect(described_class.fault("a" * 60)).to be_nil
      expect(described_class.fault("本" * 60)).to be_nil # 180 bytes of UTF-8, 60 code points (AC-1.7)
    end

    it "names each fault", :aggregate_failures do
      expect(described_class.fault("")).to eq(:blank)
      expect(described_class.fault("a" * 61)).to eq(:too_long)
      expect(described_class.fault("本" * 61)).to eq(:too_long)
      [ "\u0000", "\u0007", "\u200B", "\u200E", "\uFEFF" ].each { |char| expect(described_class.fault("a#{char}b")).to eq(:control), char.dump }
      expect(described_class.fault("a\xFFb".dup.force_encoding(Encoding::UTF_8))).to eq(:control)
    end
  end
end
```

```ruby
# spec/models/location_spec.rb
require "rails_helper"

# Spec 029: a location is a name in an account, unique by comparison key.
RSpec.describe Location, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }

  def add(name, to: account) = to.locations.new(name:).tap(&:save)

  def reasons(location) = location.errors.messages_for(:name)

  describe "a name" do
    it "is stored in normal form with its comparison key (AC-1.5, AC-1.11)", :aggregate_failures do
      location = add("  Cafe\u0301   Box ")

      expect(location).to be_persisted
      expect(location.name).to eq("Café Box")
      expect(location.name_key).to eq("café box")
      expect(location.typed).to eq("  Cafe\u0301   Box ")
    end

    it "is refused when blank, with the reason (AC-1.6)", :aggregate_failures do
      [ "", "   ", "\u3000\t" ].each do |blank|
        location = add(blank)
        expect(location).not_to be_persisted
        expect(reasons(location)).to eq([ "Give the location a name." ])
      end
    end

    it "is refused over 60 code points, whatever the bytes (AC-1.7)", :aggregate_failures do
      expect(add("a" * 61).errors.messages_for(:name)).to eq([ "Names can be at most 60 characters." ])
      expect(add("a" * 60)).to be_persisted
      expect(add("本" * 60)).to be_persisted
      expect(add("本" * 61)).not_to be_persisted
    end

    it "is refused with a control or format character, and collapses the White_Space between words (AC-1.8)", :aggregate_failures do
      [ "\u0000", "\u0007", "\u200B", "\u200E", "\uFEFF" ].each do |char|
        expect(reasons(add("a#{char}b"))).to eq([ "Names can't contain control characters." ]), char.dump
      end
      [ "\t", "\u0085", "\u2028" ].each_with_index do |space, index|
        expect(add("Box#{index}#{space}two").name).to eq("Box#{index} two")
      end
    end

    it "is refused when it has the key of another location, quoting the normalised name (AC-1.9)", :aggregate_failures do
      add("Blue binder")
      add("Straße")
      add("Café")

      expect(reasons(add("  blue   BINDER "))).to eq([ "You already have a location called “blue BINDER”." ])
      expect(reasons(add("STRASSE"))).to eq([ "You already have a location called “STRASSE”." ])
      expect(reasons(add("Cafe\u0301"))).to eq([ "You already have a location called “Café”." ])
      expect(account.locations.count).to eq(3)
    end

    it "may repeat another account's name (AC-4.2)" do
      add("Blue binder", to: create(:user).account)

      expect(add("Blue binder")).to be_persisted
    end

    it "is judged again on a rename: its own key is allowed, another's is not (AC-2.3, AC-2.4)", :aggregate_failures do
      box = add("box")
      add("Trade binder")

      box.name = "Box"
      expect(box.save).to be(true)
      expect(box.reload.name).to eq("Box")

      box.name = "TRADE binder"
      expect(box.save).to be(false)
      expect(reasons(box)).to eq([ "You already have a location called “TRADE binder”." ])
      expect(box.reload.name).to eq("Box")

      box.name = "Box"
      expect(box.save).to be(true) # its own name (AC-2.6)
    end
  end

  describe "the limit (decision 7, AC-1.10, AC-1.13)" do
    def fill(count)
      Location.insert_all!(Array.new(count) { |index| { account_id: account.id, name: "Place #{index}", name_key: "place #{index}" } })
    end

    it "refuses the 501st location and allows the 500th", :aggregate_failures do
      fill(499)

      expect(add("The 500th")).to be_persisted
      refused = add("The 501st")
      expect(refused).not_to be_persisted
      expect(reasons(refused)).to eq([ "You can have at most 500 locations." ])
      expect(account.locations.count).to eq(500)
    end

    it "counts only this account's locations" do
      fill(500)

      expect(add("Elsewhere", to: create(:user).account)).to be_persisted
    end
  end

  describe "the database's own rules" do
    it "answers false with the duplicate message when the unique index refuses a save that validation let through (race)", :aggregate_failures do
      location = account.locations.new(name: "Box")
      Location.insert!({ account_id: account.id, name: "box", name_key: "box" }) # another request won the race

      expect(location.save(validate: false)).to be(false)
      expect(reasons(location)).to eq([ "You already have a location called “Box”." ])
      expect(account.locations.count).to eq(1)
    end

    it "refuses a name outside 1 to 60 characters, and an empty key, at the table", :aggregate_failures do
      expect { Location.insert!({ account_id: account.id, name: "", name_key: "x" }) }.to raise_error(ActiveRecord::StatementInvalid)
      expect { Location.insert!({ account_id: account.id, name: "a" * 61, name_key: "x" }) }.to raise_error(ActiveRecord::StatementInvalid)
      expect { Location.insert!({ account_id: account.id, name: "x", name_key: "" }) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe ".ordered (decision 2, AC-1.4)" do
    it "lists by comparison key then name, in code-point order, with no numeric or locale ordering" do
      [ "box", "Binder 2", "Binder 10", "Éclair", "eclair" ].each { |name| add(name) }

      expect(account.locations.ordered.pluck(:name)).to eq([ "Binder 10", "Binder 2", "box", "eclair", "Éclair" ])
    end
  end

  it "goes with its account (AC-4.6)" do
    add("Blue binder")
    add("Box")

    expect { user.destroy! }.to change(Location, :count).by(-2)
  end
end
```

- [ ] Run `bin/rspec spec/models/location/name_spec.rb spec/models/location_spec.rb` — expect: FAIL (`uninitialized constant Location`)
- [ ] Add the migration (a new table; it changes nothing else, so it is safe to run unattended from any prior version; the unique index also covers the `account_id` foreign key):

```ruby
# db/migrate/20261021100001_create_locations.rb
class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :name, null: false
      t.string :name_key, null: false
      t.timestamps
      t.index %i[account_id name_key], unique: true
      t.check_constraint "length(name) BETWEEN 1 AND 60", name: "locations_name_length"
      t.check_constraint "length(name_key) >= 1", name: "locations_name_key_present"
    end
  end
end
```

- [ ] Add the name function:

```ruby
# app/models/location/name.rb
# A location's name as one function (spec 029 decision 5): what a collector types and what a file holds are made
# into the same form before they are compared, judged or stored. The same sets are in the format document and in
# v2.schema.json; spec/models/location/name_parity_spec.rb proves the three agree.
module Location::Name
  MAX_LENGTH = 60
  LEFT_OVER = /[\p{Cc}\p{Cf}]/

  # Steps 1 and 2: NFC, then the White_Space at either end removed and each run inside made one U+0020. Text that
  # isn't valid UTF-8 is returned as it is (unicode_normalize would raise); .fault refuses it.
  def self.normalise(text)
    text = text.to_s
    return text unless text.valid_encoding?

    text.unicode_normalize(:nfc).gsub(/\A\p{White_Space}+|\p{White_Space}+\z/, "").gsub(/\p{White_Space}+/, " ")
  end

  # The comparison key: Unicode full case folding of a normalised name. For uniqueness and matching only.
  def self.key(normalised) = normalised.valid_encoding? ? normalised.downcase(:fold) : normalised

  # Steps 3 to 5 for a normalised name: why it is refused, or nil.
  def self.fault(normalised)
    return :control unless normalised.valid_encoding?
    return :blank if normalised.empty?
    return :control if normalised.match?(LEFT_OVER)

    :too_long if normalised.length > MAX_LENGTH
  end
end
```

- [ ] Add the model and the association:

```ruby
# app/models/location.rb
# A named place a collector keeps part of their collection (spec 029). One attribute, its name (decision 4); unique per
# account by comparison key, in the database as well as here. Collectible-agnostic.
class Location < ApplicationRecord
  MAX_PER_ACCOUNT = 500
  MESSAGES = {
    blank: "Give the location a name.",
    control: "Names can't contain control characters.",
    too_long: "Names can be at most #{Name::MAX_LENGTH} characters."
  }.freeze
  FULL = "You can have at most #{MAX_PER_ACCOUNT} locations.".freeze

  belongs_to :account

  # By comparison key then name, both in code-point order: SQLite compares UTF-8 text by bytes (decision 2).
  scope :ordered, -> { order(:name_key, :name) }

  validate :name_is_acceptable
  validate :name_is_free
  validate :account_has_room, on: :create

  # The name is stored as the normal form of what was assigned; the text as typed stays for a refused form to show.
  def name=(value)
    @typed = value.to_s
    super(Name.normalise(value))
    self.name_key = Name.key(name)
  end

  def typed = @typed || name.to_s

  # Two requests that race to add one name leave one location and one clean error: the unique index refuses the
  # second save, which answers false like a failed validation.
  def save(**)
    super
  rescue ActiveRecord::RecordNotUnique
    errors.add(:name, taken)
    false
  end

  private
    def name_is_acceptable
      fault = Name.fault(name.to_s)
      errors.add(:name, MESSAGES.fetch(fault)) if fault
    end

    def name_is_free
      return if errors.any?

      errors.add(:name, taken) if self.class.where(account_id:, name_key:).where.not(id:).exists?
    end

    # Write transactions are IMMEDIATE and validations run inside save's transaction, so counting and inserting is
    # one step per writer (AC-1.13).
    def account_has_room
      return if errors.any?

      errors.add(:name, FULL) if self.class.where(account_id:).count >= MAX_PER_ACCOUNT
    end

    def taken = "You already have a location called “#{name}”."
end
```

```ruby
# app/models/account.rb: add beside has_many :lots
  has_many :locations, dependent: :delete_all # the foreign key cascades too, as for `import_uploads` and `number_entries` (spec 029 AC-4.6)
```

- [ ] Run `bin/rails db:migrate`, then `git diff db/schema.rb`: expect only the `locations` table, its foreign key line (`add_foreign_key "locations", "accounts", on_delete: :cascade`) and the version bump to `2026_10_21_100001`. If the cache, queue or cable tables appear, or the primary tables vanish (known noise, `migrate-schema-noise`), run `git checkout db/schema.rb` and re-apply those three hunks by hand. Check reversibility: `bin/rails db:rollback:primary`, confirm `locations` is gone from `db/schema.rb`, then `bin/rails db:migrate` again.
- [ ] Run `bin/rspec spec/models/location/name_spec.rb spec/models/location_spec.rb` — expect: PASS
- [ ] Run `bin/rspec spec/export_format_document_spec.rb` — expect: FAIL ("accounts for every table that belongs to an account or a user" and the column example: `locations` has an `account_id`, and Coverage doesn't list it yet). In `spec/export_format_document_spec.rb`, in "marks each table as the spec rules (AC-3.5)": `expect(status).to include("lots" => "Exported", "users" => "Exported", "locations" => "Exported", "accounts" => "Nothing to export")`; in "maps each column to a field…": the left-out list gains `locations.id locations.account_id locations.name_key locations.created_at locations.updated_at`. Then, in `docs/export-format/README.md` "Coverage" (only that section; the rest of the document is Phase 2): the table of tables gains ``| `locations` | Exported | From version 2: the collector's named places. |`` after `lots`, and the table of columns gains the six rows of data-model.md after `lots.updated_at`: `locations.id` and `locations.account_id` (left out: internal ids), `locations.name` → `name`, `locations.name_key` (left out: derived from the name), `locations.created_at` and `locations.updated_at` (left out: facts about the instance). `name` is already a field of the valid examples (a profile's and an entry's), which the mapping example reads, so `locations.name → name` passes before version 2's examples exist. Run `bin/rspec spec/export_format_document_spec.rb` — expect: PASS
- [ ] Run `bin/rspec` — expect: PASS (the whole suite; the phase ends green)
- [ ] Run `bin/rubocop -a app/models/location.rb app/models/location spec/models/location_spec.rb spec/models/location spec/factories/locations.rb db/migrate/20261021100001_create_locations.rb` — expect: no offenses
- [ ] Commit: `feat(locations): add the locations table, its model and the name function` (stage `db/migrate`, `db/schema.rb`, `app/models`, `spec`, `docs/export-format/README.md`)

---

## Phase 1: The locations pages and the way to them

**Implements:** FR-1 (only through the pages, for the signed-in account), FR-2, decisions 3, 6, 8, 12 | **Satisfies:** AC-1.1 to AC-1.4, AC-1.12, AC-1.14, Story 2 (AC-2.1 to AC-2.10), Story 3 (AC-3.1 to AC-3.7), Story 4 (AC-4.1 to AC-4.5), Story 5 (AC-5.1 to AC-5.5)
**Files:** `config/routes.rb`, `app/controllers/locations_controller.rb`, `app/controllers/locations/removals_controller.rb`, `app/views/locations/index.html.erb`, `app/views/locations/edit.html.erb`, `app/views/locations/removals/new.html.erb`, `app/views/layouts/_appbar.html.erb`, `app/views/mores/show.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/requests/locations_spec.rb`, `spec/system/locations_spec.rb`, `spec/requests/query_counts_spec.rb`, `spec/requests/shell_spec.rb`, `spec/requests/number_entries_spec.rb`, `spec/requests/admin/navigation_spec.rb`
**Interfaces:** Consumes: `Location`, `Location.ordered`, `Location#typed`, `Account#locations` (Phase 0); `field_error_describedby`, `shared/field_errors`, `layouts/appbar` (`section:`), `layouts/tabbar`. Produces: routes `locations_path`, `edit_location_path`, `location_path`, `new_location_removal_path`; the header link and More row; `c-locations` CSS.

Reuse over invention: the page is `c-pagehead`, `c-form`/`c-field`/`c-input`, `c-list`, `c-empty` and, for removal, `ConfirmPage`. The only new CSS is the 44px targets and wrapping of long names.

- [ ] Write the failing request spec:

```ruby
# spec/requests/locations_spec.rb
require "rails_helper"

# Spec 029 Stories 1 to 5: the locations pages, tenancy and the ways to them.
RSpec.describe "Locations", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }

  def html = Nokogiri::HTML5(response.body)
  def listed = html.css(".c-locations__list .c-locations__name").map(&:text)
  def field_error = html.at_css("#location_name-error")&.text
  def add(name, **extra) = post(locations_path, params: { location: { name: } }.merge(extra))
  def notice = html.at_css("#status")&.text.to_s.squish

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the heading, the add form and the empty state (AC-1.1)", :aggregate_failures do
      get locations_path

      expect(response).to have_http_status(:ok)
      expect(html.at_css("h1").text).to eq("Locations")
      expect(html.at_css("form[action='#{locations_path}'] input[type=submit]")["value"]).to eq("Add location")
      expect(html.at_css("form[action='#{locations_path}'] input[name='location[name]']")).to be_present
      expect(html.at_css(".c-empty").text).to eq("No locations yet. Add a binder or a box to start recording where things are kept.")
      expect(html.at_css("main").text).not_to match(/magic|mtg|scryfall/i) # the footer's content notice is outside main
    end

    it "adds a location, redirects (303) and says so, in the order of AC-1.4 (AC-1.2, AC-1.4, AC-1.12)", :aggregate_failures do
      add("Blue binder")

      expect(response).to have_http_status(:see_other).and redirect_to(locations_path)
      follow_redirect!
      expect(notice).to eq("Added “Blue binder”.")
      expect(listed).to eq([ "Blue binder" ])
      expect(account.locations.pluck(:name)).to eq([ "Blue binder" ])
      expect(html.css("form[data-controller], form[data-turbo]")).to be_empty # a plain form: no script needed

      [ "box", "Binder 2", "Binder 10", "Éclair", "eclair" ].each { |name| add(name) }
      get locations_path
      expect(listed).to eq([ "Binder 10", "Binder 2", "Blue binder", "box", "eclair", "Éclair" ])
    end

    it "answers 422 with the reason beside the field and the typed text kept (AC-1.6 to AC-1.9)", :aggregate_failures do
      add("Blue binder")
      {
        "   " => "Give the location a name.",
        ("a" * 61) => "Names can be at most 60 characters.",
        "a\u200Bb" => "Names can't contain control characters.",
        "  blue   BINDER " => "You already have a location called “blue BINDER”."
      }.each do |typed, message|
        add(typed)
        expect(response).to have_http_status(:unprocessable_content)
        expect(field_error).to eq(message)
        expect(html.at_css("input[name='location[name]']")["value"]).to eq(typed)
        expect(html.at_css("input[name='location[name]']")["aria-describedby"]).to eq("location_name-error")
      end
      expect(account.locations.count).to eq(1)
    end

    it "refuses the 501st location (AC-1.10)", :aggregate_failures do
      Location.insert_all!(Array.new(500) { |index| { account_id: account.id, name: "Place #{index}", name_key: "place #{index}" } })

      add("One more")

      expect(response).to have_http_status(:unprocessable_content)
      expect(field_error).to eq("You can have at most 500 locations.")
      expect(account.locations.count).to eq(500)
    end

    it "answers 400 without the location parameter (AC-1.14)", :aggregate_failures do
      expect { post locations_path, params: { other: "x" } }.not_to change(Location, :count)
      expect(response).to have_http_status(:bad_request)
    end

    it "stores a name in non-Latin script as typed and a combining accent in NFC (AC-1.11)", :aggregate_failures do
      add("日本語のバインダー")
      add("Cafe\u0301")

      expect(account.locations.pluck(:name)).to contain_exactly("日本語のバインダー", "Café")
    end

    describe "renaming" do
      let!(:location) { create(:location, account:, name: "Blue binder") }

      it "opens the edit page holding the name (AC-2.1, AC-2.7)", :aggregate_failures do
        get edit_location_path(location)

        expect(html.at_css("input[name='location[name]']")["value"]).to eq("Blue binder")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Save")
        expect(html.css("a").find { |link| link.text == "Cancel" }["href"]).to eq(locations_path)
      end

      it "saves, redirects and says what happened, leaving every lot alone (AC-2.2, AC-2.8)", :aggregate_failures do
        lot = create(:lot, account:, quantity: 3)
        before = lot.reload.attributes

        patch location_path(location), params: { location: { name: "Trade binder" } }

        expect(response).to have_http_status(:see_other).and redirect_to(locations_path)
        follow_redirect!
        expect(notice).to eq("Renamed “Blue binder” to “Trade binder”.")
        expect(listed).to eq([ "Trade binder" ])
        expect(lot.reload.attributes).to eq(before)
      end

      it "allows a change of case alone, and the name it already has (AC-2.3, AC-2.6)", :aggregate_failures do
        patch location_path(location), params: { location: { name: "blue BINDER" } }
        expect(response).to have_http_status(:see_other)
        patch location_path(location), params: { location: { name: "blue BINDER" } }
        expect(response).to have_http_status(:see_other)
        expect(location.reload.name).to eq("blue BINDER")
      end

      it "refuses another location's key, and the reasons of a new name, keeping the name (AC-2.4, AC-2.5)", :aggregate_failures do
        create(:location, account:, name: "Trade binder")

        { "TRADE binder" => "You already have a location called “TRADE binder”.", "" => "Give the location a name.",
          ("a" * 61) => "Names can be at most 60 characters.", "a\u0007b" => "Names can't contain control characters." }.each do |typed, message|
          patch location_path(location), params: { location: { name: typed } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(field_error).to eq(message)
        end
        expect(location.reload.name).to eq("Blue binder")
      end

      it "lets the later of two saves stand (AC-2.9)", :aggregate_failures do
        patch location_path(location), params: { location: { name: "First" } }
        patch location_path(location), params: { location: { name: "Second" } }

        expect(location.reload.name).to eq("Second")
      end

      it "answers 404 once the location is gone, creating nothing (AC-2.10, AC-3.7)", :aggregate_failures do
        location.destroy!

        patch location_path(location), params: { location: { name: "Back again" } }
        expect(response).to have_http_status(:not_found)
        get edit_location_path(location)
        expect(response).to have_http_status(:not_found)
        expect(account.locations.count).to eq(0)
      end
    end

    describe "removing" do
      let!(:location) { create(:location, account:, name: "Blue binder") }

      it "asks first, naming the location, and removes nothing on a GET (AC-3.1)", :aggregate_failures do
        get new_location_removal_path(location)

        expect(html.at_css("h1").text).to eq("Remove Blue binder?")
        expect(html.at_css("form[action='#{location_path(location)}'] button")&.text).to eq("Remove")
        expect(html.css("a").find { |link| link.text == "Cancel" }["href"]).to eq(locations_path)
        expect(account.locations.count).to eq(1)
      end

      it "removes on DELETE, redirects and says so, and the name can be added again (AC-3.2, AC-3.5)", :aggregate_failures do
        delete location_path(location)

        expect(response).to have_http_status(:see_other).and redirect_to(locations_path)
        follow_redirect!
        expect(notice).to eq("Removed “Blue binder”.")
        expect(account.locations.count).to eq(0)
        add("Blue binder")
        expect(account.locations.pluck(:name)).to eq([ "Blue binder" ])
      end

      it "never touches a lot (AC-3.4)", :aggregate_failures do
        lots = create_list(:lot, 2, account:, quantity: 4)
        before = lots.map { |lot| lot.reload.attributes }

        delete location_path(location)

        expect(account.lots.order(:id).map(&:attributes)).to eq(before)
      end

      it "answers 404 for one that is already gone, with no message (AC-3.6)", :aggregate_failures do
        delete location_path(location)
        delete location_path(location)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "only this account (Story 4)" do
      let(:other) { create(:user).account }
      let!(:theirs) { create(:location, account: other, name: "Zebulon's crate") }

      it "answers 404 for another account's location on every page and write, leaving it unchanged (AC-4.1)", :aggregate_failures do
        get edit_location_path(theirs)
        expect(response).to have_http_status(:not_found)
        get new_location_removal_path(theirs)
        expect(response).to have_http_status(:not_found)
        patch location_path(theirs), params: { location: { name: "Mine now" } }
        expect(response).to have_http_status(:not_found)
        delete location_path(theirs)
        expect(response).to have_http_status(:not_found)
        expect(theirs.reload.name).to eq("Zebulon's crate")
      end

      it "lists only mine, and lets me use a name another account has (AC-4.2)", :aggregate_failures do
        create(:location, account:, name: "Mine")
        add("Zebulon's crate")
        get locations_path

        expect(listed).to eq([ "Mine", "Zebulon's crate" ])
        expect(account.locations.count).to eq(2)
        expect(other.locations.count).to eq(1)
      end

      it "makes the location mine whatever account_id the request carries (AC-4.3)", :aggregate_failures do
        add("Sneaky", account_id: other.id, location: { name: "Sneaky", account_id: other.id })

        expect(account.locations.pluck(:name)).to eq([ "Sneaky" ])
        expect(other.locations.pluck(:name)).to eq([ "Zebulon's crate" ])
      end
    end

    describe "the ways in (Story 5)" do
      it "adds Locations after Scan in the header, current on its pages, and no tab is marked (AC-5.1, AC-5.3)", :aggregate_failures do
        get collection_path
        expect(html.css(".c-appbar__nav a").map(&:text)).to eq(%w[Collection Search Scan Locations])
        expect(html.css(".c-tabbar a").map { |link| link.text.strip }).to eq(%w[Collection Search Scan More])

        create(:location, account:)
        [ locations_path, edit_location_path(account.locations.first), new_location_removal_path(account.locations.first) ].each do |path|
          get path
          expect(html.css(".c-appbar__nav a[aria-current=page]").map(&:text)).to eq([ "Locations" ]), path
          expect(html.css(".c-appbar__nav a").find { |link| link.text == "Locations" }["href"]).to eq(locations_path)
          expect(html.css(".c-tabbar [aria-current]")).to be_empty, path
        end
      end

      it "puts a Locations row in More before Export collection, and not in the account menu (AC-5.2)", :aggregate_failures do
        get more_path

        rows = html.css(".c-more li").map { |row| row.text.squish }
        expect(rows.first).to start_with("Signed in as")
        expect(html.css(".c-more li a").map(&:text).first(4)).to eq([ "Locations", "Export collection", "Import collection", "Add by number" ])
        expect(html.at_css(".c-more a[href='#{locations_path}']")).to be_present
        expect(html.css(".c-appbar .c-menu__list a").map(&:text)).not_to include("Locations")
      end
    end

    it "shows no location, name or count on the admin pages (AC-4.5)", :aggregate_failures do
      create(:location, account:, name: "Zebulon's crate")
      admin = create(:admin)
      create(:location, account: admin.account, name: "Admin's shelf")
      sign_in_as(admin)

      [ admin_users_path, admin_catalog_path, admin_jobs_path ].each do |path|
        get path
        main = html.at_css("main").text
        expect(response.body).not_to include("Zebulon", "Admin&#39;s shelf", "Admin's shelf"), path
        expect(main.downcase).not_to include("location"), path # the header's own link is outside main
      end
    end
  end

  describe "when signed out (AC-4.4, AC-5.4)" do
    let!(:location) { create(:location, name: "Hidden") }

    def visitor_is_sent_to_sign_in
      [ locations_path, edit_location_path(location), new_location_removal_path(location) ].each do |path|
        get path
        expect(response).to redirect_to(new_session_path), path
      end
      expect(response.body).not_to include("Hidden")
    end

    it "sends a visitor to sign in from every page and shows nothing", :aggregate_failures do
      visitor_is_sent_to_sign_in
    end

    # The OpenCatalog concern opens the catalog's pages only (CLAUDE.md, Open catalog); the locations pages stay closed.
    it "does the same with the catalog open (AC-4.4, FR-1 Must not)", :public_catalog, :aggregate_failures do
      visitor_is_sent_to_sign_in
    end

    it "sends a write with an ended session to sign in and writes nothing", :aggregate_failures do
      user = create(:user)
      owned = create(:location, account: user.account, name: "Mine")
      sign_in_as(user)
      delete session_path

      post locations_path, params: { location: { name: "New" } }
      patch location_path(owned), params: { location: { name: "Changed" } }
      delete location_path(owned)

      expect(response).to redirect_to(new_session_path)
      expect(user.account.locations.pluck(:name)).to eq([ "Mine" ])
    end

    it "fails forgery protection first for a write with no session cookie", :aggregate_failures do
      ActionController::Base.allow_forgery_protection = true

      post locations_path, params: { location: { name: "New" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Location.where(name: "New")).to be_empty
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "shows a visitor of an open catalog no Locations link (AC-5.4)", :public_catalog, :aggregate_failures do
      get catalog_entries_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Locations")
    end
  end
end
```

- [ ] Add the query-count example to `spec/requests/query_counts_spec.rb` (inside the existing `describe`, after the collection page's example):

```ruby
  it "keeps the locations page's queries independent of the number of locations (spec 029 NFR)" do
    create(:location, account: user.account)
    few = queries_for(locations_path)
    29.times { create(:location, account: user.account) }

    expect(queries_for(locations_path)).to eq(few)
  end
```

- [ ] Update the three existing specs that count More's rows (Locations is now the second row, so Export, Import and Add by number move down by one):
  - `spec/requests/shell_spec.rb`: `.c-more li:nth-child(2) a` → `.c-more li:nth-child(3) a` ("Export collection"), and `.c-more li:nth-child(3) a` → `.c-more li:nth-child(4) a` ("Import collection").
  - `spec/requests/number_entries_spec.rb`: `.c-more li:nth-child(4) a` → `.c-more li:nth-child(5) a` ("Add by number").
  - `spec/requests/admin/navigation_spec.rb` has two examples that list More's links exactly, and both change (plan review m1): the admin example (`:15`) becomes `expect(links(".c-more")).to eq([ [ "Locations", locations_path ], *menu, [ "Add by number", collection_number_entry_path ], *admin ])`, and the member example (`:25`) becomes `expect(links(".c-more")).to eq([ [ "Locations", locations_path ], *menu, [ "Add by number", collection_number_entry_path ] ])`; the header comment gains "(spec 029 adds Locations before the export)". The avatar-menu expectations are unchanged (the account menu doesn't list Locations, AC-5.3).
- [ ] Run `bin/rspec spec/requests/locations_spec.rb spec/requests/query_counts_spec.rb spec/requests/shell_spec.rb spec/requests/number_entries_spec.rb spec/requests/admin/navigation_spec.rb` — expect: FAIL (no route `locations_path`; the three updated specs fail on the old rows)
- [ ] Add the routes (after `resource :more, only: :show`):

```ruby
  # Locations (spec 029): the named places a collector keeps part of their collection.
  resources :locations, only: %i[index create edit update destroy] do
    resource :removal, only: :new, module: :locations
  end
```

- [ ] Add the controllers:

```ruby
# app/controllers/locations_controller.rb
# Spec 029: the signed-in collector's locations. Every lookup goes through Current.account, so another account's id is a
# 404; nothing in a request names an account.
class LocationsController < ApplicationController
  before_action :set_location, only: %i[edit update destroy]

  def index
    @location = Location.new
    @locations = Current.account.locations.ordered.to_a
  end

  def create
    @location = Current.account.locations.new(name: location_name)
    if @location.save
      redirect_to locations_path, notice: "Added “#{@location.name}”.", status: :see_other
    else
      @locations = Current.account.locations.ordered.to_a
      render :index, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    before = @location.name
    @location.name = location_name
    if @location.save
      redirect_to locations_path, notice: "Renamed “#{before}” to “#{@location.name}”.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Removing a location never touches a lot (spec 029 decision 3).
  def destroy
    @location.destroy!
    redirect_to locations_path, notice: "Removed “#{@location.name}”.", status: :see_other
  end

  private
    def set_location = @location = Current.account.locations.find(params[:id])

    # The one permitted parameter; a request without the location parameter is a 400.
    def location_name = params.expect(location: [ :name ])[:name]
end
```

```ruby
# app/controllers/locations/removals_controller.rb
# The no-script confirmation page for removing a location (spec 029 decision 6).
class Locations::RemovalsController < ApplicationController
  def new
    @location = Current.account.locations.find(params[:location_id])
  end
end
```

- [ ] Add the views:

```erb
<%# app/views/locations/index.html.erb %>
<% content_for :title, "Locations · Collector" %>
<%= render "layouts/appbar", section: :locations %>
<main class="c-main c-page c-locations">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Locations</h1>
      <p class="c-pagehead__stats"><%= pluralize(@locations.size, "location") %></p>
    </div>
  </div>
  <% messages = @location.errors.messages_for(:name) %>
  <%= form_with model: @location, url: locations_path, class: "c-form c-locations__add" do |form| %>
    <div class="c-field<%= " c-field--invalid" if messages.any? %>">
      <%= form.label :name, "Name", class: "c-field__label" %>
      <label class="c-input"><%= form.text_field :name, value: @location.typed, autocomplete: "off", "aria-describedby": field_error_describedby("location_name-error", messages) %></label>
      <%= render "shared/field_errors", messages:, id: "location_name-error" %>
    </div>
    <div class="c-form__actions"><%= form.submit "Add location", class: "c-btn c-btn--primary" %></div>
  <% end %>
  <% if @locations.empty? %>
    <p class="c-empty">No locations yet. Add a binder or a box to start recording where things are kept.</p>
  <% else %>
    <ul class="c-list c-locations__list">
      <% @locations.each do |location| %>
        <li>
          <span class="c-locations__name"><%= location.name %></span>
          <span class="c-list__end c-locations__actions">
            <%= link_to edit_location_path(location), class: "c-btn c-btn--ghost c-btn--sm" do %>Rename<span class="c-sr"> <%= location.name %></span><% end %>
            <%= link_to new_location_removal_path(location), class: "c-btn c-btn--ghost c-btn--sm" do %>Remove<span class="c-sr"> <%= location.name %></span><% end %>
          </span>
        </li>
      <% end %>
    </ul>
  <% end %>
</main>
<%= render "layouts/tabbar", section: nil %>
```

```erb
<%# app/views/locations/edit.html.erb %>
<% content_for :title, "Rename #{@location.name_was} · Collector" %>
<%= render "layouts/appbar", section: :locations, detail: true, back_path: locations_path %>
<main class="c-main c-page c-locations">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Rename location</h1>
      <p class="c-pagehead__stats"><%= @location.name_was %></p>
    </div>
  </div>
  <% messages = @location.errors.messages_for(:name) %>
  <%= form_with model: @location, url: location_path(@location), method: :patch, class: "c-form c-locations__add" do |form| %>
    <div class="c-field<%= " c-field--invalid" if messages.any? %>">
      <%= form.label :name, "Name", class: "c-field__label" %>
      <label class="c-input"><%= form.text_field :name, value: @location.typed, autocomplete: "off", "aria-describedby": field_error_describedby("location_name-error", messages) %></label>
      <%= render "shared/field_errors", messages:, id: "location_name-error" %>
    </div>
    <div class="c-form__actions">
      <%= form.submit "Save", class: "c-btn c-btn--primary" %>
      <%= link_to "Cancel", locations_path, class: "c-btn c-btn--secondary" %>
    </div>
  <% end %>
</main>
<%= render "layouts/tabbar", section: nil %>
```

```erb
<%# app/views/locations/removals/new.html.erb %>
<% content_for :title, "Remove location · Collector" %>
<%= render "layouts/appbar", section: :locations, detail: true, back_path: locations_path %>
<main class="c-main c-page c-locations">
  <section class="c-confirm">
    <h1 class="c-pagehead__title">Remove <%= @location.name %>?</h1>
    <p>This removes the location from your list. No lot or copy in your collection is removed or changed.</p>
    <div class="c-form__actions">
      <%= button_to "Remove", location_path(@location), method: :delete, class: "c-btn c-btn--danger" %>
      <%= link_to "Cancel", locations_path, class: "c-btn c-btn--secondary" %>
    </div>
  </section>
</main>
<%= render "layouts/tabbar", section: nil %>
```

- [ ] Add the header link and the More row:

```erb
<%# app/views/layouts/_appbar.html.erb: in the collector's nav, after the Scan link %>
        <%= link_to "Locations", locations_path, "aria-current": ("page" if section == :locations) %>
```

```erb
<%# app/views/mores/show.html.erb: after the "Signed in as" row, before "Export collection" %>
    <li><%= link_to "Locations", locations_path %></li>
```

- [ ] Add the styles (tokens only; the 44px floor applies to every pointer, so the system spec can read it):

```css
/* ---------- Locations page (spec 029): composed from c-form, c-list and c-confirm; only touch targets and long names ---------- */
.c-locations__add { max-width:560px; margin-bottom:var(--space-6); }
.c-locations__list li { flex-wrap:wrap; }
.c-locations__name { min-width:0; overflow-wrap:anywhere; }
.c-locations__actions { display:flex; gap:var(--space-2); font-family:var(--font-sans); }
.c-locations .c-btn { min-height:44px; min-width:44px; }
```

- [ ] Run `bin/rspec spec/requests/locations_spec.rb spec/requests/query_counts_spec.rb spec/requests/shell_spec.rb spec/requests/number_entries_spec.rb spec/requests/admin/navigation_spec.rb` — expect: PASS
- [ ] Write the failing system spec (the flow without a pointer for the add, the header at 640px, the pages at 360, 640 and 1200px in both themes, 44px targets):

```ruby
# spec/system/locations_spec.rb
require "rails_helper"

# Spec 029 AC-1.3, AC-5.1, AC-5.5: the flow, the header's four links, and the pages' widths and targets.
RSpec.describe "Locations", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }

  it "adds with the keyboard, renames and removes through the pages (AC-1.3, Story 2, Story 3)", :aggregate_failures do
    visit locations_path
    fill_in "Name", with: "Blue binder"
    find_field("Name").send_keys(:enter)
    expect(page).to have_css("#status", text: "Added “Blue binder”.")
    expect(page).to have_css(".c-locations__name", text: "Blue binder")

    click_on "Rename Blue binder"
    fill_in "Name", with: "Trade binder"
    click_on "Save"
    expect(page).to have_css("#status", text: "Renamed “Blue binder” to “Trade binder”.")

    click_on "Remove Trade binder"
    expect(page).to have_css("h1", text: "Remove Trade binder?")
    click_on "Remove"
    expect(page).to have_css("#status", text: "Removed “Trade binder”.")
    expect(page).to have_css(".c-empty")
  end

  it "keeps Collection, Search, Scan and Locations on one line with the account menu at 640px (AC-5.1)" do
    visit locations_path
    open_in_narrow_frame(locations_path, width: 640, ready: ".c-appbar__nav")
    fits = within_narrow_frame do
      page.evaluate_script(<<~JS)
        (() => {
          const links = [...document.querySelectorAll(".c-appbar__nav a")]
          const nav = document.querySelector(".c-appbar__nav").getBoundingClientRect()
          const actions = document.querySelector(".c-appbar__actions").getBoundingClientRect()
          return [links.length, new Set(links.map((link) => Math.round(link.getBoundingClientRect().top))).size,
            nav.right <= actions.left, document.documentElement.scrollWidth <= window.innerWidth]
        })()
      JS
    end

    expect(fits).to eq([ 4, 1, true, true ])
  end

  # Every control on the page, as the pointer sees it: a field is its label (the `c-input` wrapper), a link or button itself.
  def targets = <<~JS
    [...document.querySelectorAll("main a, main button, main input:not([type=hidden]), .c-appbar a[href='/locations'], .c-appbar__back")]
      .filter((el) => el.getClientRects().length > 0) // only what is rendered at this width: the header link from 640px, the back button below it
      .map((el) => el.closest("label.c-input") || el)
  JS

  it "never scrolls sideways at 360px, 640px and a 1200px desktop frame in both themes, with 44px targets and a focus ring (AC-5.5)", :aggregate_failures do
    long = create(:location, account: user.account, name: "A very long name for a binder of cards")
    create(:location, account: user.account, name: "Box")
    paths = [ locations_path, edit_location_path(long), new_location_removal_path(long) ]

    [ 360, 640, 1200 ].product(%w[light dark], paths).each do |width, theme, path|
      expect(open_in_narrow_frame(path, width:, ready: "main")).to eq([ width, true ]), "#{path} at #{width}px"
      within_narrow_frame do
        page.execute_script("document.documentElement.setAttribute('data-theme', arguments[0])", theme)
        expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true), "#{path} at #{width}px, #{theme}"
        # Measured, not declared: the box each target really has (plan review m4).
        small = page.evaluate_script("#{targets}.filter((el) => { const box = el.getBoundingClientRect(); return box.height < 44 || box.width < 44 }).map((el) => el.outerHTML.slice(0, 60))")
        expect(small).to eq([]), "#{path} at #{width}px, #{theme}: a target under 44px"
      end
    end
  end

  it "shows a focus ring on every control the keyboard reaches, on each page (AC-5.5)", :aggregate_failures do
    long = create(:location, account: user.account, name: "Box")

    [ locations_path, edit_location_path(long), new_location_removal_path(long) ].each do |path|
      visit path
      stops = page.evaluate_script("#{targets}.length")
      rings = []
      (stops + 6).times do
        page.driver.browser.action.send_keys(:tab).perform
        rings << page.evaluate_script("(() => { const el = document.activeElement; const style = getComputedStyle(el); return !el.matches('main *, .c-appbar *') || (el.matches(':focus-visible') && style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0) })()")
      end
      expect(rings).to all(be(true)), path
    end
  end
end
```

- [ ] Run `bin/rspec spec/system/locations_spec.rb` — expect: PASS. **If the 640px header example fails** (AC-5.1 is a stated criterion, so a miss is a decision, not a CSS tweak in passing): stop, record the measured values (`nav.right`, `actions.left`, the four links' widths) and take them to the maintainer, as the plan does for the 4 s bar. The remedies to put to the maintainer are: a shorter label for the link, or moving it into More only at that width (decision 8 would change); the executor chooses neither. If a *header* target other than the Locations link and the back button measures under 44px, that is the design system's own header, not this spec's: record the sizes in `verification.md` and do not change them here.
- [ ] Run `bin/rspec` — expect: PASS (the whole suite; the phase ends green)
- [ ] Run `bin/rubocop -a` on the new controllers, specs and `config/routes.rb` — expect: no offenses
- [ ] Commit: `feat(locations): add the locations pages, the header link and the More row`

---

## Phase 2: Export format version 2: the schema, the rules, the examples and the document

**Implements:** FR-4, decisions 1, 5, 9, 10 (the reader's rules) | **Satisfies:** AC-7.1 to AC-7.8
**Files:** `docs/export-format/v2.schema.json`, `app/models/export_format/v2.schema.json`, `app/models/export_format/rules.rb`, `docs/export-format/README.md`, `docs/export-format/examples/{valid,invalid,comparison}/*.json` (new files only), `docs/export-format/examples/problems.json`, `spec/support/export_format_rules.rb`, `spec/export_format_document_spec.rb`, `spec/export_format_examples_spec.rb`, `spec/models/export_format/rules_spec.rb`, `spec/models/location/name_parity_spec.rb`, `spec/models/collection_import_spec.rb`, `spec/requests/collection_import_previews_spec.rb`
**Interfaces:** Consumes: `Location::Name.normalise`, `.key`, `.fault`, `Location::Name::MAX_LENGTH` (Phase 0). Produces: `ExportFormat::Rules::VERSIONS` (`[1, 2]`), `VERSION` (2, the newest), `RULES` (gains `duplicate_location`), `SCHEMA_DIRECTORY`, `.schema_file(version = VERSION)`, `.schema(version = VERSION)`, `.schemer(version = VERSION)`, `.lot_schemer(version = VERSION)`, `.schema_version(data)` (the version whose schema judges the data: its own if this instance reads it, else the oldest, so a file with a missing or unreadable version keeps exactly the one problem version 1 gave it), `.whole_number(value)`, and `.problems` / `.problems_in` that judge each file against its own version's schema and add `duplicate_location` at `/locations/<i>`; `ExportFormatRules.schema(version = nil)`, `.schema_file_for(version)`, `.versions`; the examples of version 2.

Version 1 never changes: `v1.schema.json`, its examples and its meaning stay byte for byte. `SCHEMA_FILE` goes (one constant for one file); nothing but `rules.rb` and `rules_spec.rb` used it.

- [ ] Update the suite's version-aware support (`spec/support/export_format_rules.rb`): add after `schema_file`:

```ruby
  # Every version this instance reads (ExportFormat::Rules), and the schema file of one.
  def self.versions = ExportFormat::Rules::VERSIONS

  def self.schema_file_for(version) = directory.join("v#{version}.schema.json")
```

  replace `def self.schema = JSON.parse(schema_file.read)` with `def self.schema(version = nil) = JSON.parse((version ? schema_file_for(version) : schema_file).read)`, and make `compared` include the locations of a version 2 file, names exactly as written:

```ruby
  def self.compared(file)
    [ file.fetch("profile").slice("name", "email_address", "collection_view"), file["currency"],
      file.fetch("lots").to_h { |lot| [ identity(lot), lot.values_at("quantity", "added_at", "changed_at") ] },
      file["locations"]&.map { |location| location["name"] }&.to_set ]
  end
```

- [ ] Write the failing specs. First `spec/models/location/name_parity_spec.rb` (AC-7.8):

```ruby
# spec/models/location/name_parity_spec.rb
require "rails_helper"

# Spec 029 AC-7.8, decision 9: the model, v2.schema.json and the format document agree on what a well-formed name is,
# tried on every Unicode scalar value in four forms. The model's verdict is Location::Name (what Location validates
# besides uniqueness and the limit); the schema's is its name definition (type, minLength, maxLength, pattern).
RSpec.describe Location::Name, "parity with v2.schema.json", type: :model do
  let(:scalars) { (0..0xD7FF).to_a + (0xE000..0x10FFFF).to_a }
  let(:definition) { ExportFormat::Rules.schema(2).dig("$defs", "location_name") }
  let(:pattern) { Regexp.new(JSONSchemer::EcmaRegexp.ruby_equivalent(definition["pattern"])) }

  def well_formed?(string) = string.length.between?(definition["minLength"], definition["maxLength"]) && pattern.match?(string)

  def accepted(text)
    normalised = described_class.normalise(text)
    normalised if described_class.fault(normalised).nil?
  end

  def forms(char) = [ char, "a#{char}b", "a#{char}#{char}b", "#{char}#{char}" ]

  it "agrees on every scalar value: what the model stores is well-formed, and what is well-formed the model accepts (AC-7.8 a, b)" do
    disagreements = []
    scalars.each do |scalar|
      forms([ scalar ].pack("U")).each do |text|
        stored = accepted(text)
        disagreements << [ :stored_but_not_well_formed, text ] if stored && !well_formed?(stored)
        next unless well_formed?(text)

        normalised = described_class.normalise(text)
        disagreements << [ :well_formed_but_refused, text ] if stored.nil? && normalised.length <= described_class::MAX_LENGTH
      end
    end

    expect(disagreements.first(5).map { |kind, text| [ kind, text.codepoints.map { |cp| format("U+%04X", cp) } ] }).to eq([])
  end

  it "exports what the model stores as a well-formed file (AC-7.8 c), for a sample of every 997th scalar", :aggregate_failures do
    scalars.each_slice(997).map(&:first).each do |scalar|
      stored = accepted("a#{[ scalar ].pack("U")}b")
      next unless stored

      file = JSON.parse(Rails.root.join("docs/export-format/examples/valid/empty-v2.json").read).merge("locations" => [ { "name" => stored } ])

      expect(ExportFormat::Rules.problems_in(file)).to eq([]), format("U+%04X", scalar)
    end
  end

  it "reads the pattern the way json_schemer does, on a sample (the regular expression stands for the validator)" do
    schemer = JSONSchemer.schema(definition, regexp_resolver: "ecma")
    sample = scalars.each_slice(233).map { |slice| "a#{[ slice.first ].pack("U")}b" }

    expect(sample.reject { |text| schemer.valid?(text) == well_formed?(text) }).to eq([])
  end
end
```

  Expected run time: tens of seconds to about two minutes (about 4.4 million small checks); record it in `verification.md`. If it passes two minutes, restrict the third and fourth forms (`"a#{char}#{char}b"`, `"#{char}#{char}"`) to scalars matching `/[\p{White_Space}\p{Cc}\p{Cf}\p{M}]/`, the only categories where repeating a character changes the verdict, and say so in this spec's comment.

  Then `spec/models/export_format/rules_spec.rb`: (1) in "keeps a byte-identical copy of every documented schema", use `described_class::SCHEMA_DIRECTORY.join(file.basename)` and `include("v1.schema.json", "v2.schema.json")`; (2) in `whole_file_problems`, judge by the data's version: `JSONSchemer.schema(described_class.schema(described_class.schema_version(data)), regexp_resolver: "ecma")`; (3) in "checking each lot on its own", the data is version 1's `base`, so use `described_class.schemer(1)` and `described_class.lot_schemer(1)` wherever the block says `described_class.schemer` or `.lot_schemer`; (4) add:

```ruby
  describe "version 2 (spec 029)" do
    def v2 = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/v2-base.json").read)

    def locations(*names) = v2.merge("locations" => names.map { |name| { "name" => name } })

    it "judges a file against the schema of its own version", :aggregate_failures do
      expect(described_class.schema_version(base)).to eq(1)
      expect(described_class.schema_version(v2)).to eq(2)
      expect(described_class.schema_version(v2.merge("format_version" => 2.0))).to eq(2)
      expect(described_class.schema_version(v2.merge("format_version" => 3))).to eq(1) # a version it doesn't read: the oldest names the version
      expect(described_class.schema_version(base.except("format_version"))).to eq(1)
      expect(described_class.schema_version(base.merge("format_version" => "1"))).to eq(1)
      expect(described_class.schema_version([ v2 ])).to eq(2)
      expect(problems_of(v2)).to eq([])
      expect(problems_of(base.merge("format_version" => 2))).to eq([ %w[required /locations] ])
      expect(problems_of(base.except("format_version"))).to eq([ %w[required /format_version] ]) # the version 1 invalid examples keep their one problem
      expect(problems_of(base.merge("format_version" => "1"))).to eq([ %w[const /format_version] ])
      expect(problems_of(v2.merge("format_version" => 3))).to eq([ %w[const /format_version] ])
      expect(problems_of(v2.merge("format_version" => 1))).to eq([]) # an unknown field is ignored by version 1
    end

    it "finds a location problem under its pointer and checks the lots too", :aggregate_failures do
      data = locations("Blue binder", "a  b", "")
      data["lots"][0]["quantity"] = 0

      expect(problems_of(data)).to eq([ %w[pattern /locations/1/name], %w[minLength /locations/2/name], %w[minimum /lots/0/quantity] ])
    end

    it "finds a repeated key at the later location, by case, case folding and normalisation form (AC-7.3)", :aggregate_failures do
      expect(problems_of(locations("box", "Box"))).to eq([ %w[duplicate_location /locations/1] ])
      expect(problems_of(locations("Straße", "STRASSE"))).to eq([ %w[duplicate_location /locations/1] ])
      expect(problems_of(locations("Café", "Cafe\u0301", "CAFE\u0301"))).to eq([ %w[duplicate_location /locations/1], %w[duplicate_location /locations/2] ])
      expect(problems_of(locations("Cafe\u0301"))).to eq([]) # a name in NFD is well-formed
    end

    it "compares no location whose name fails the schema, as it compares no lot with an unreadable identity" do
      expect(problems_of(locations("a  b", "a  b"))).to eq([ %w[pattern /locations/0/name], %w[pattern /locations/1/name] ])
    end

    it "reports a location that isn't an object and checks the others" do
      data = v2.merge("locations" => [ 5, { "name" => "Box" }, { "name" => "box" } ])

      expect(problems_of(data)).to eq([ %w[type /locations/0], %w[duplicate_location /locations/2] ])
    end
  end
```

  Then `spec/export_format_examples_spec.rb`:
  - `"has valid, invalid and comparison examples"`: `expect(valid.keys).to match_array(%w[valid/collection-v2.json valid/collection.json valid/empty-v2.json valid/empty.json valid/location-name-60.json valid/locations-500.json valid/locations-nfd.json])`, `expect(invalid.size).to eq(40)`, `expect(comparison.size).to eq(13)`.
  - `"is defined by a schema that is itself valid"`: `ExportFormatRules.versions.each { |version| expect(JSONSchemer.valid_schema?(ExportFormatRules.schema(version))).to be(true), "v#{version}" }`.
  - keep the `[ %w[format_version], 0 ] => %w[const /format_version]` line of `malformed_variants` as it is (version 0 is judged by version 1's schema, so it still has the one problem), and replace the example "fails version 1's schema for a file of another version…" with:

```ruby
  it "judges a file of a version this instance doesn't read by version 1's schema, which names the version, and a version 2 file by its own (FR-8, AC-7.4)", :aggregate_failures do
    expect(problems_of(changed(%w[format_version], 0))).to eq([ { "rule" => "const", "at" => "/format_version" } ])
    expect(problems_of(changed(%w[format_version], 3))).to eq([ { "rule" => "const", "at" => "/format_version" } ])
    expect(problems_of(changed(%w[format_version], 2))).to eq([ { "rule" => "required", "at" => "/locations" } ])
  end
```

  - add the version 2 variants and edges, and the version 2 "same collection" (the existing `describe "the same collection (FR-7)"` stays for version 1):

```ruby
  describe "version 2 (spec 029)" do
    def v2base = comparison.fetch("comparison/v2-base.json")

    def v2changed(path, value)
      data = JSON.parse(v2base)
      *parents, last = path
      target = parents.empty? ? data : data.dig(*parents)
      value == :absent ? target.delete(last) : target[last] = value
      JSON.generate(data)
    end

    it "finds each listed variant of a malformed locations value (AC-7.2)", :aggregate_failures do
      {
        [ %w[locations], :absent ] => %w[required /locations],
        [ %w[locations], {} ] => %w[type /locations],
        [ %w[locations], "Box" ] => %w[type /locations],
        [ %w[locations], Array.new(501) { |index| { "name" => "Binder #{index}" } } ] => %w[maxItems /locations],
        [ [ "locations", 0, "name" ], :absent ] => %w[required /locations/0/name],
        [ [ "locations", 0, "name" ], "" ] => %w[minLength /locations/0/name],
        [ [ "locations", 0, "name" ], " " ] => %w[pattern /locations/0/name],
        [ [ "locations", 0, "name" ], "本" * 61 ] => %w[maxLength /locations/0/name],
        [ [ "locations", 0, "name" ], " Blue binder" ] => %w[pattern /locations/0/name],
        [ [ "locations", 0, "name" ], "Blue binder\n" ] => %w[pattern /locations/0/name],
        [ [ "locations", 0, "name" ], "Blue  binder" ] => %w[pattern /locations/0/name],
        [ [ "locations", 0, "name" ], 5 ] => %w[type /locations/0/name]
      }.each do |(path, value), (rule, at)|
        expect(problems_of(v2changed(path, value))).to eq([ { "rule" => rule, "at" => at } ]), "#{path.join('/')} = #{value.inspect}"
      end
    end

    it "accepts the values at the edges of each rule", :aggregate_failures do
      [
        [ %w[locations], [] ], [ [ "locations", 0, "name" ], "本" * 60 ],
        [ %w[locations], Array.new(500) { |index| { "name" => "Binder #{index}" } } ]
      ].each { |path, value| expect(problems_of(v2changed(path, value))).to be_empty, path.join("/") }
      expect(problems_of(v2changed([ "locations", 0, "name" ], "Cafe\u0301"))).to be_empty
    end

    it "holds the same collection for the same names in another order and what the rule ignores (AC-6.6, AC-7.4)", :aggregate_failures do
      original = JSON.parse(v2base)
      same = JSON.parse(comparison.fetch("comparison/v2-same.json"))

      expect(same["locations"]).to eq(original["locations"].reverse)
      expect(ExportFormatRules.same_collection?(original, same)).to be(true)
    end

    it "differs in the case of a name and in the set of names (AC-6.8, AC-7.4)", :aggregate_failures do
      original = JSON.parse(v2base)
      different = parsed(comparison).select { |name, _file| name.start_with?("comparison/v2-different-") }

      expect(different.keys.map { |name| name[/v2-different-(.+)\.json/, 1] }).to eq(%w[location-case location-missing locations])
      different.each { |name, file| expect(ExportFormatRules.same_collection?(original, file)).to be(false), name }
    end
  end
```

  Then `spec/export_format_document_spec.rb`:
  - replace "states the version that the schema and the valid examples carry (AC-4.1)" with:

```ruby
  it "states the newest version, which its schema and a valid example carry, and every version has its schema and a row (AC-4.1, AC-7.1)", :aggregate_failures do
    version = ExportFormatRules.version
    carried = ExportFormatRules.examples("valid").values.map { |bytes| JSON.parse(bytes)["format_version"] }

    expect(version).to eq(ExportFormat::Rules::VERSION)
    expect(ExportFormatRules.schema_file.basename.to_s).to eq("v#{version}.schema.json")
    (1..version).each { |each| expect(ExportFormatRules.schema(each).dig("properties", "format_version", "const")).to eq(each) }
    expect(carried).to include(version)
    expect(carried.uniq - (1..version).to_a).to be_empty
    expect(ExportFormatRules.table(ExportFormatRules.section("Versions"), "Version").map { |row| row["Version"] }).to eq((1..version).map(&:to_s))
  end
```

  - (the Coverage expectations for `locations` were changed in Phase 0, where the table appears.)
  Then the two examples about the newer version, which `VERSION = 2` makes false, change in this phase (plan review M3). In `spec/models/collection_import_spec.rb`, "refuses a newer version as newer, before the schema (AC-3.2)" uses version 3 and the sentence "(format version 3). This instance reads version 2.", `format_version: 3.0` for the float, and keeps `expect(import(file([], format_version: 1.0))).not_to be_refused`. In `spec/requests/collection_import_previews_spec.rb`, the newer-version row (`:151`) becomes `file([], format_version: 3) => "This file was written by a newer version of Collector (format version 3). This instance reads version 2."` (AC-8.6). `CollectionImport#newer` builds its sentence from `ExportFormat::Rules::VERSION`, so no code changes for this.
- [ ] Run `bin/rspec spec/export_format_document_spec.rb spec/export_format_examples_spec.rb spec/models/export_format spec/models/location/name_parity_spec.rb spec/models/collection_import_spec.rb spec/requests/collection_import_previews_spec.rb` — expect: FAIL (no `v2.schema.json`, no `schema_version`, no `v2` examples)
- [ ] Write the schema, `docs/export-format/v2.schema.json` (version 1's, with the version, the required `locations`, the list and the name's definition; the name's pattern lets the empty string through so that `minLength` alone fails it and a lone space fails the pattern alone, research.md 2; it does not use `\s`, which `json_schemer` translates without U+0085 and U+2028, research.md 1):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:collector:export-format:v2",
  "title": "Collector export, format version 2",
  "description": "The part of a well-formed Collector export that a schema can state. README.md beside this file defines the format and lists the rules a schema can't state: the file is UTF-8 JSON with no repeated key, every time is a real moment, no lot was changed before it was added, no two lots have the same identity, and no two locations have the same name once the names are normalised (NFC) and case folded.",
  "type": "object",
  "required": ["format", "format_version", "exported_at", "profile", "currency", "locations", "lots"],
  "properties": {
    "format": { "const": "collector-export" },
    "format_version": { "const": 2 },
    "exported_at": { "$ref": "#/$defs/time" },
    "generator": { "type": "string" },
    "profile": {
      "type": "object",
      "required": ["name", "email_address", "collection_view"],
      "properties": {
        "name": { "$ref": "#/$defs/text" },
        "email_address": { "$ref": "#/$defs/text" },
        "collection_view": { "$ref": "#/$defs/text" }
      }
    },
    "currency": { "type": "string", "pattern": "^[A-Z]{3}$" },
    "locations": { "type": "array", "maxItems": 500, "items": { "$ref": "#/$defs/location" } },
    "lots": { "type": "array", "items": { "$ref": "#/$defs/lot" } }
  },
  "$defs": {
    "text": {
      "description": "A string that isn't empty or only whitespace.",
      "type": "string",
      "pattern": "\\S"
    },
    "recorded_text": {
      "description": "A string that isn't empty or only whitespace, or null when not recorded.",
      "type": ["string", "null"],
      "pattern": "\\S"
    },
    "time": {
      "description": "RFC 3339 in UTC with a Z and no fraction of a second.",
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
    },
    "location": {
      "type": "object",
      "required": ["name"],
      "properties": {
        "name": { "$ref": "#/$defs/location_name" }
      }
    },
    "location_name": {
      "description": "1 to 60 code points: words with no Cc or Cf character and no White_Space other than U+0020, separated by single U+0020 and not padded. The empty string passes the pattern so that minLength alone fails it.",
      "type": "string",
      "minLength": 1,
      "maxLength": 60,
      "pattern": "^([^\\p{Cc}\\p{Cf}\\t-\\r\\u0085\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000 ]+( [^\\p{Cc}\\p{Cf}\\t-\\r\\u0085\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000 ]+)*)?$"
    },
    "lot": {
      "type": "object",
      "required": ["entry", "quantity", "finish", "condition", "price_paid", "added_at", "changed_at"],
      "properties": {
        "entry": { "$ref": "#/$defs/entry" },
        "quantity": { "type": "integer", "minimum": 1, "maximum": 9999 },
        "finish": { "$ref": "#/$defs/recorded_text" },
        "condition": { "$ref": "#/$defs/recorded_text" },
        "price_paid": {
          "description": "The price of one copy with exactly two decimal places, or null when not recorded.",
          "type": ["string", "null"],
          "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{2}$"
        },
        "added_at": { "$ref": "#/$defs/time" },
        "changed_at": { "$ref": "#/$defs/time" }
      }
    },
    "entry": {
      "type": "object",
      "required": ["collectible_type", "source_id", "name", "set_code", "collector_number", "language"],
      "properties": {
        "collectible_type": { "$ref": "#/$defs/text" },
        "source_id": { "$ref": "#/$defs/text" },
        "name": { "$ref": "#/$defs/text" },
        "set_code": { "$ref": "#/$defs/text" },
        "collector_number": { "$ref": "#/$defs/text" },
        "language": { "$ref": "#/$defs/text" }
      }
    }
  }
}
```

  Then `cp docs/export-format/v2.schema.json app/models/export_format/v2.schema.json` (ADR 0021: the app's copy is byte-identical; `rules_spec` checks it). A name with a `\n` fails the pattern (`$` is `\z`), and the `lot`, `entry`, `text` and `time` definitions are version 1's, character for character.
- [ ] Make the rules read both versions: replace `app/models/export_format/rules.rb`'s header, constants and the methods named below (the lot-level methods `parse`, `problems`, `identity`, `identity_readable?`, `non_finite?`, `changed_before_added?` and `moment?` stay as they are):

```ruby
require "json_schemer"

# The export format's rules for a well-formed file, versions 1 and 2 (docs/export-format/README.md, specs 017 and 029),
# as the app applies them when it reads a file (spec 025, ADR 0021). The v<N>.schema.json files beside this file are
# byte-identical copies of those in docs/export-format/, which the published image leaves out;
# spec/models/export_format/rules_spec.rb keeps them equal.
module ExportFormat
  module Rules
    Problem = Data.define(:rule, :at)

    FORMAT = "collector-export".freeze
    # The versions this instance reads, each against its own schema. VERSION is the newest: the one the export writes and
    # the highest a reader accepts (spec 029 decision 10).
    VERSIONS = [ 1, 2 ].freeze
    VERSION = VERSIONS.max
    # The rules a schema can't state, and the two that apply before a schema can.
    RULES = %w[not_utf8 not_json not_a_time changed_before_added duplicate_lot duplicate_location].freeze
    SCHEMA_DIRECTORY = Pathname(__dir__)
    TIME = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\z/
    JSON_TYPES = %w[array boolean integer null number object string].freeze
    # The fields under a lot that make its identity (ADR 0019).
    IDENTITY_FIELDS = %w[entry entry/collectible_type entry/source_id finish condition price_paid].freeze

    def self.schema_file(version = VERSION) = SCHEMA_DIRECTORY.join("v#{version}.schema.json")

    def self.schema(version = VERSION) = (@schemas ||= {})[version] ||= JSON.parse(schema_file(version).read)

    def self.schemer(version = VERSION) = (@schemers ||= {})[version] ||= JSONSchemer.schema(schema(version), regexp_resolver: "ecma")

    # The schema of one lot, $defs/lot, whose own $refs resolve against the whole schema of its version.
    def self.lot_schemer(version = VERSION) = (@lot_schemers ||= {})[version] ||= schemer(version).ref("#/$defs/lot")

    # The version whose schema judges +data+: its own when this instance reads it, else the oldest. A file with a missing,
    # unreadable or unknown version is then judged as it always was: by version 1's schema, which names the version
    # (required or const at /format_version) and has no locations to miss (plan review M1; spec 029 AC-7.4: every
    # version 1 invalid example keeps exactly its one problem).
    def self.schema_version(data)
      version = data.is_a?(Hash) ? whole_number(data["format_version"]) : nil
      VERSIONS.include?(version) ? version : VERSIONS.min
    end

    # A whole number (a zero fraction is allowed, spec 017), or nil.
    def self.whole_number(value)
      case value
      when Integer then value
      when Float then value.to_i if value.finite? && value == value.floor
      end
    end

    # Why parsed data isn't well-formed. Schema problems carry the keyword that failed. The time rules then apply to each
    # time the schema accepted, duplicate_lot to the lots whose identity can be read (spec 025 FR-2), and from version 2
    # duplicate_location to the locations whose name can be read.
    def self.problems_in(data)
      found = schema_problems(data, schema_version(data))
      found + rule_problems(data, found.to_set(&:at))
    end

    # The schema's problems, in the order a whole-file pass gives them. The lots are checked one at a time against
    # $defs/lot, each lot's errors mapped before the next lot's (spec 025 decision 13: json_schemer holds a result tree
    # for everything it validates in one call). The rest of the file, locations included, is checked with no lots; its
    # errors at the root (a missing key) follow the lots', as json_schemer reports what "properties" finds before the
    # root's own "required". Data that isn't an object, or whose lots aren't an array, is checked whole: no lot is
    # checked then, so its tree is small.
    def self.schema_problems(data, version)
      return problems_from(schemer(version).validate(data)) unless data.is_a?(Hash) && data["lots"].is_a?(Array)

      root, header = schemer(version).validate(data.merge("lots" => [])).partition { |error| error["data_pointer"].empty? }
      lots = data["lots"].each_with_index.flat_map { |lot, index| problems_from(lot_schemer(version).validate(lot), "/lots/#{index}") }
      problems_from(header) + lots + problems_from(root)
    end

    def self.rule_problems(data, failed)
      return [] unless data.is_a?(Hash)

      lots = data["lots"].is_a?(Array) ? data["lots"].each_with_index.select { |lot, _index| lot.is_a?(Hash) } : []
      times = [ [ "/exported_at", data["exported_at"] ] ] +
        lots.flat_map { |lot, index| %w[added_at changed_at].map { |name| [ "/lots/#{index}/#{name}", lot[name] ] } }
      checked = times.reject { |at, _value| failed.include?(at) }
      real = checked.select { |_at, value| moment?(value) }.to_set { |at, _value| at }
      not_times = checked.reject { |at, _value| real.include?(at) }.map { |at, _value| Problem.new("not_a_time", at) }
      backwards = lots.select { |lot, index| changed_before_added?(lot, "/lots/#{index}", real) }
        .map { |_lot, index| Problem.new("changed_before_added", "/lots/#{index}/changed_at") }
      repeats = lots.select { |lot, index| identity_readable?(lot, "/lots/#{index}", failed) }.group_by { |lot, _index| identity(lot) }.values
        .flat_map { |group| group.drop(1).map { |_lot, index| Problem.new("duplicate_lot", "/lots/#{index}") } }
      not_times + backwards + repeats + (schema_version(data) >= 2 ? repeated_locations(data, failed) : [])
    end

    # The locations whose comparison key an earlier location already has (spec 029 decision 9): the key of the name after
    # normalisation and case folding. A name that fails the schema has no key to compare, as a lot whose identity can't
    # be read isn't compared.
    def self.repeated_locations(data, failed)
      return [] unless data["locations"].is_a?(Array)

      seen = Set.new
      data["locations"].each_with_index.filter_map do |location, index|
        at = "/locations/#{index}"
        next unless location.is_a?(Hash) && location["name"].is_a?(String) && !failed.include?(at) && !failed.include?("#{at}/name")

        Problem.new("duplicate_location", at) unless seen.add?(Location::Name.key(Location::Name.normalise(location["name"])))
      end
    end

    private_class_method :schema_problems, :rule_problems, :repeated_locations
  end
end
```

  Keep `problems_from` (unchanged, private) and the other lot-level methods exactly as in the file today; `private_class_method` then lists `:non_finite?, :schema_problems, :problems_from, :rule_problems, :repeated_locations, :changed_before_added?, :moment?`.
- [ ] Run `bin/rspec spec/models/export_format/rules_spec.rb spec/models/location/name_parity_spec.rb` — expect: the rules examples that don't need the v2 examples PASS (`version 2` examples that read `comparison/v2-base.json` still FAIL until the examples exist, next step); the parity example PASS. If the parity example reports a disagreement, fix the pattern or `Location::Name` until it reports none; the pattern and the function are the two halves of one definition. Do not commit yet: this phase is one commit, so that no commit of it is red.
- [ ] Generate the examples. One command writes every new file; `v1` files and `collection.json`, `empty.json`, `base.json`, `same.json` are only read. Invisible characters are written as `\u` escapes so a person can read and review the files:

```sh
ruby -rjson <<'RUBY'
dir = "docs/export-format/examples"
load = ->(path) { JSON.parse(File.read("#{dir}/#{path}")) }
escape = ->(json) { json.gsub(/[\u0080-\u009F\u00A0\u0300-\u036F\u2000-\u200F\u2028-\u202F\u205F-\u206F\u3000\uFEFF]/) { format("\\u%04x", $&.ord) } }
write = ->(path, data) { File.write("#{dir}/#{path}", escape.call(JSON.pretty_generate(data)) + "\n") }
v2 = lambda do |data, names|
  data.each_with_object({}) do |(key, value), out|
    out[key] = key == "format_version" ? 2 : value
    out["locations"] = names.map { |name| { "name" => name } } if key == "currency"
  end
end
empty = load.("valid/empty.json")

write.("valid/collection-v2.json", v2.(load.("valid/collection.json"), [ "Blue binder", "Trade binder", "Long box on the shelf", "日本語のバインダー" ]))
write.("valid/empty-v2.json", v2.(empty, []))
write.("valid/location-name-60.json", v2.(empty, [ "本" * 60 ]))
write.("valid/locations-500.json", v2.(empty, (1..500).map { |number| "Binder #{number}" }))
write.("valid/locations-nfd.json", v2.(empty, [ "Cafe\u0301", "Straße" ]))

defects = {
  "locations-not-a-list" => nil,
  "locations-501" => (1..501).map { |number| "Binder #{number}" },
  "location-name-61" => [ "本" * 61 ], "location-name-empty" => [ "" ], "location-name-padded" => [ " Blue binder " ],
  "location-name-double-space" => [ "Blue  binder" ], "location-name-tab" => [ "Blue\tbinder" ],
  "location-name-no-break-space" => [ "Blue\u00A0binder" ], "location-name-ideographic-space" => [ "Blue\u3000binder" ],
  "location-name-next-line" => [ "Blue\u0085binder" ], "location-name-line-separator" => [ "Blue\u2028binder" ],
  "location-name-control" => [ "Blue\u0007binder" ], "location-name-format" => [ "Blue\u200Bbinder" ],
  "location-duplicate-case" => %w[box Box], "location-duplicate-fold" => [ "Straße", "STRASSE" ],
  "location-duplicate-nfd" => [ "Café", "Cafe\u0301" ]
}
defects.each do |name, names|
  data = v2.(empty, names || [])
  data["locations"] = { "name" => "Blue binder" } if names.nil?
  write.("invalid/#{name}.json", data)
end
write.("invalid/locations-missing.json", v2.(empty, []).except("locations"))
write.("invalid/location-name-missing.json", v2.(empty, []).merge("locations" => [ {} ]))

base = load.("comparison/base.json")
write.("comparison/v2-base.json", v2.(base, [ "Blue binder", "Trade binder" ]))
write.("comparison/v2-same.json", v2.(load.("comparison/same.json"), [ "Trade binder", "Blue binder" ]))
write.("comparison/v2-different-location-case.json", v2.(base, [ "Blue binder", "trade binder" ]))
write.("comparison/v2-different-location-missing.json", v2.(base, [ "Blue binder" ]))
write.("comparison/v2-different-locations.json", v2.(base, [ "Blue binder", "Trade binder", "Old crate" ]))

why = {
  "locations-missing" => [ "The locations list is missing from a version 2 file.", "required", "/locations" ],
  "locations-not-a-list" => [ "The locations are an object, not a list.", "type", "/locations" ],
  "locations-501" => [ "The list holds 501 locations; at most 500 are allowed.", "maxItems", "/locations" ],
  "location-name-missing" => [ "A location has no name.", "required", "/locations/0/name" ],
  "location-name-empty" => [ "A location's name is empty.", "minLength", "/locations/0/name" ],
  "location-name-61" => [ "A location's name is 61 code points long; at most 60 are allowed.", "maxLength", "/locations/0/name" ],
  "location-name-padded" => [ "A location's name has a space at its start and at its end.", "pattern", "/locations/0/name" ],
  "location-name-double-space" => [ "A location's name has two spaces in a row.", "pattern", "/locations/0/name" ],
  "location-name-tab" => [ "A location's name has a tab between its words, a White_Space character other than a space.", "pattern", "/locations/0/name" ],
  "location-name-no-break-space" => [ "A location's name has a no-break space (U+00A0) between its words.", "pattern", "/locations/0/name" ],
  "location-name-ideographic-space" => [ "A location's name has an ideographic space (U+3000) between its words.", "pattern", "/locations/0/name" ],
  "location-name-next-line" => [ "A location's name has a next line character (U+0085) between its words.", "pattern", "/locations/0/name" ],
  "location-name-line-separator" => [ "A location's name has a line separator (U+2028) between its words.", "pattern", "/locations/0/name" ],
  "location-name-control" => [ "A location's name has a control character (U+0007).", "pattern", "/locations/0/name" ],
  "location-name-format" => [ "A location's name has a zero width space (U+200B), a format character.", "pattern", "/locations/0/name" ],
  "location-duplicate-case" => [ "Two locations have names that differ only in case.", "duplicate_location", "/locations/1" ],
  "location-duplicate-fold" => [ "Two locations have names that differ only by full case folding (ß and SS).", "duplicate_location", "/locations/1" ],
  "location-duplicate-nfd" => [ "Two locations hold the same name in NFC and in NFD.", "duplicate_location", "/locations/1" ]
}
path = "#{dir}/problems.json"
text = File.read(path).sub(/\n\}\s*\z/, "")
why.each do |name, (reason, rule, at)|
  text << ",\n  #{JSON.generate("invalid/#{name}.json")}: {\n    \"why\": #{JSON.generate(reason)},\n    \"rule\": #{JSON.generate(rule)},\n    \"at\": #{JSON.generate(at)}\n  }"
end
File.write(path, text + "\n}\n")
RUBY
```

  Then check by eye: `git status --short docs/export-format/examples` shows 5 + 18 + 5 new files and `problems.json` modified; `git diff docs/export-format/examples/problems.json` adds 18 entries and changes no earlier line; `wc -l docs/export-format/examples/valid/locations-500.json` is about 1,500 lines (500 two-line objects and their braces); `git diff --stat -- docs/export-format/examples/valid/collection.json docs/export-format/examples/valid/empty.json docs/export-format/examples/comparison/base.json docs/export-format/examples/comparison/same.json docs/export-format/v1.schema.json app/models/export_format/v1.schema.json` is empty (version 1 unchanged, AC-7.2).
- [ ] Update the format document (`docs/export-format/README.md`), by reading afterwards (AC-7.1). The edits, in order of the file:

  1. The header line `**Format version:** 1` becomes `**Format version:** 2` (the suite reads this line for the newest version; keep it exactly in this form).
  2. The opening sentence becomes: "An export is one file that holds one collector's data: their profile, the currency their prices are in, the locations they keep their collection in, and every lot in their collection."
  3. In "This document defines the format…", name both schemas and the new ADR: "[`v1.schema.json`](v1.schema.json) and [`v2.schema.json`](v2.schema.json) state the same rules for a program, one for each version", and add "Locations and the version 2 are the decision of [ADR 0023](../adr/0023-locations-make-export-format-version-2.md)."
  4. In the top-level table, the `format_version` row reads "The version of this format that the file follows: 1 or 2. See [Versions](#versions)."; add a row after `currency`: ``| `locations` | A list | Version 2 only: the places the collection is kept. See [Locations](#locations). It may be empty, and its order has no meaning. A version 1 file has no `locations`. |``; and the example of an empty collection becomes version 2 with `"locations": [],` after `"currency": "EUR",`.
  5. A new section between "Entry" (the end of "Lots") and "Lot identity":

```markdown
## Locations

A **location** is a named place the collector keeps part of their collection: a binder, a box. A version 2 file carries the collector's set of locations. A version 1 file says nothing about them, and a reader must not read that as "none".

| Field | Value | Meaning |
|---|---|---|
| `name` | A string of 1 to 60 Unicode code points, as [Names](#names) says | The location's name. |

The list has at most 500 elements. A file carries no id for a location, and in version 2 a lot carries no reference to one.

### Names

A well-formed name:

- is 1 to 60 Unicode code points long (a character made of several code points counts each);
- has no character of general category Cc (control) or Cf (format): U+0000, U+0007, U+200B, U+200E, U+FEFF and the rest of those two categories;
- has no character with the Unicode White_Space property other than U+0020 (a tab, a line feed, U+00A0, U+0085, U+2028, U+3000 and the rest of that property), and no U+0020 at its start or its end or beside another U+0020.

Any other character is allowed, in any script.

`v2.schema.json` states these rules as one pattern that uses Unicode property escapes (`\\p{Cc}`, `\\p{Cf}`), which is ECMA-262 syntax with the `u` flag. A program that validates with a regular expression engine without them (Python's `re`, for one) can't compile the pattern as it stands; the rules in words above are the definition, and the pattern is their statement for a validator that can read it.

A writer writes a name in Unicode normalisation form NFC, as Collector does. A name in another form is still well-formed, because a schema can't state the form. A reader **normalises each name on read**: it makes it NFC, then removes White_Space at both ends and makes each run of White_Space inside the name one U+0020, before it matches, compares, judges duplicates or stores the name. For a well-formed name the second step changes nothing.

### Location identity

A location is identified by its **comparison key**: the Unicode full case folding of its name after normalisation. "Blue binder" and "blue binder" are one name, and so are "Straße" and "STRASSE", and "Café" written in NFC and in NFD. A file never holds two locations with the same identity.

The key is for matching and for the duplicate rule only. It is never written in a file.
```

  6. "Well-formed and resolvable": the paragraph gains a sentence: "A file whose version this document doesn't define (a version above the newest, or a version that is missing or isn't a whole number) is judged by the schema of version 1, which names the version as the problem." Then the first sentence of the well-formed paragraph becomes "A file is well-formed when it passes the schema of its own version ([`v1.schema.json`](v1.schema.json) or [`v2.schema.json`](v2.schema.json)) and the rules that a schema can't state:"; add the bullet "- from version 2, no two locations have the same [identity](#location-identity)"; and "The schema and these rules are version 1's." becomes "Each version has its own schema; the rules are the same for both, with the rule about locations from version 2."
  7. "The same collection": "Two well-formed files of the same version hold the same collection when all of these are true:" gains a last bullet: "- From version 2, their locations are equal as sets of names, compared exactly, character for character, as written in the files, without normalising either. \"box\" and \"Box\" are different locations here, although a reader treats them as one when it matches locations (see [Location identity](#location-identity)); the order of the locations never counts."
  8. "Versions": the table gets the row ``| 2 | <date of the commit> | Locations: the required top-level list `locations`, with the rule `duplicate_location`. Lots are unchanged. |``; the paragraph "Two changes are already expected…" becomes: "Two changes are already expected. Putting a lot in a location will add where each lot is kept, which is the collector's data, so it will raise the version to 3 ([ADR 0023](../adr/0023-locations-make-export-format-version-2.md)). Collections shared by a household will change who owns a lot and will raise it again ([ADR 0017](../adr/0017-row-level-tenancy-one-user-per-account.md))."
  9. "Coverage": already done in Phase 0 (the `locations` rows); here only the sentence of its "Why" for `locations` loses "From version 2:" if the Versions row now says it.
  10. "Examples": the opening sentence of the table says the folders hold files of both versions (version 1's examples are unchanged); a sentence describes `valid/locations-nfd.json`: "A location named in NFD (`Cafe` and a combining acute accent): well-formed, because a reader normalises names on read. Collector exports it as `Café` in NFC, so a collection restored from this file exports a file whose name is the NFC spelling, not this one's" (ruled 2026-10-21, AC-9.15); the rules table gains ``| `duplicate_location` | A location has the same comparison key as an earlier location in the file. |``, and the rule list in the paragraph above it gains `minLength`, `maxLength` and `maxItems`.
  11. The document must not name a collectible type outside "Collectible types" (the suite checks it): the new text above says "binder" and "box", never a game.
- [ ] Run `bin/rspec spec/export_format_document_spec.rb spec/export_format_examples_spec.rb spec/models/export_format spec/models/location spec/models/collection_import_spec.rb spec/requests/collection_import_previews_spec.rb` — expect: PASS. The examples spec runs the two version 1 invalid examples that have no version or a non-numeric one (`invalid/format-version-missing.json`, `invalid/format-version-not-a-number.json`) and finds each wrong for the one reason `problems.json` names, now that `schema_version` judges them by version 1's schema (M1, AC-7.4).
- [ ] Run `bin/rspec` — expect: PASS (the whole suite; the phase ends green)
- [ ] Run `bin/rubocop -a` on the changed specs and `app/models/export_format/rules.rb` — expect: no offenses
- [ ] Commit: `feat(format): read and define export format version 2: the schema, the rules, the examples and the document`

---

## Phase 3: The export writes version 2

**Implements:** FR-3, decision 2 | **Satisfies:** AC-6.1 to AC-6.8
**Files:** `app/models/collection_export.rb`, `spec/models/collection_export_spec.rb`, `spec/requests/collection_exports_spec.rb`, `spec/models/collection_import/round_trip_spec.rb`
**Interfaces:** Consumes: `Account#locations`, `Location.ordered` (Phase 0); `ExportFormatRules.problems`, `.same_collection?` (Phase 2). Produces: `CollectionExport::FORMAT_VERSION == 2`; `CollectionExport#to_h` with `"locations" => [ { "name" => String }, … ]` (one extra query).

The export always writes the newest version, with `locations` present and empty for an account with none. Only the name is written; no id, account or time (AC-6.5).

- [ ] Update `spec/models/collection_export_spec.rb`: the header example's expectation becomes `file.except("lots", "locations")` with `"format_version" => 2` (and its description says "the header, the profile and the currency"); the describe's comment says "format-v2 file"; then add:

```ruby
  describe "locations (spec 029)" do
    def locations(*names) = names.each { |name| create(:location, account:, name:) }

    it "writes version 2 with the names only, in order, and a well-formed file (AC-6.1, AC-6.4, AC-6.5)", :aggregate_failures do
      locations("Trade binder", "Blue binder")
      fixture_collection
      file = parsed

      expect(file["format_version"]).to eq(2)
      expect(file["locations"]).to eq([ { "name" => "Blue binder" }, { "name" => "Trade binder" } ])
      expect(file["locations"].flat_map(&:keys).uniq).to eq([ "name" ])
      expect(file["lots"].size).to eq(7)
      expect(ExportFormatRules.problems(export.to_json)).to eq([])
    end

    it "writes an empty list for an account with none (AC-6.2)", :aggregate_failures do
      expect(parsed["format_version"]).to eq(2)
      expect(parsed["locations"]).to eq([])
      expect(ExportFormatRules.problems(export.to_json)).to eq([])
    end

    it "orders by comparison key then name, in code-point order (AC-6.3)" do
      locations("box", "Binder 2", "Binder 10", "Éclair", "eclair")

      expect(parsed["locations"].map { |location| location["name"] }).to eq([ "Binder 10", "Binder 2", "box", "eclair", "Éclair" ])
    end

    it "writes none of another account's (AC-6.7)", :aggregate_failures do
      locations("Blue binder")
      create(:location, name: "Zebulon's crate")

      expect(parsed["locations"]).to eq([ { "name" => "Blue binder" } ])
      expect(export.to_json).not_to include("Zebulon")
    end

    it "writes the same file twice for an unchanged collection, apart from exported_at (AC-6.6)", :aggregate_failures do
      locations("Blue binder", "Trade binder")
      later = described_class.new(account:, at: at + 1.hour)

      expect(JSON.parse(later.to_json).except("exported_at")).to eq(parsed.except("exported_at"))
      expect(ExportFormatRules.same_collection?(parsed, JSON.parse(later.to_json))).to be(true)
    end

    it "holds a different collection when a name differs in case, and the same one when the order does (AC-6.8)", :aggregate_failures do
      box = create(:location, account:, name: "box")
      create(:location, account:, name: "Binder")
      first = parsed
      box.update!(name: "Box")

      expect(ExportFormatRules.same_collection?(first, parsed)).to be(false)
      swapped = parsed.merge("locations" => parsed["locations"].reverse)
      expect(ExportFormatRules.same_collection?(parsed, swapped)).to be(true)
    end
  end
```

- [ ] Update `spec/requests/collection_exports_spec.rb`: add inside the signed-in context:

```ruby
    it "sends this account's locations and no other account's (AC-6.7)", :aggregate_failures do
      create(:location, account: user.account, name: "Blue binder")
      create(:location, name: "Zebulon's crate")

      get collection_export_path

      expect(JSON.parse(response.body)["locations"]).to eq([ { "name" => "Blue binder" } ])
      expect(response.body).not_to include("Zebulon")
    end

    it "runs as many queries for 30 locations as for 2 (NFR)" do
      2.times { create(:location, account: user.account) }
      few = count_queries { get collection_export_path }
      28.times { create(:location, account: user.account) }

      expect(count_queries { get collection_export_path }).to eq(few)
    end
```

- [ ] Update `spec/models/collection_import/round_trip_spec.rb` for the export now being version 2 (plan review M3; `same_collection?` raises on files of different versions, `spec/support/export_format_rules.rb:37`). Add the helper beside `same_collection?`, and replace the describe "the format's valid example with lots (AC-6.4)" (it applied `collection.json` alone) with one that loops over the version 1 valid examples; Phase 5 widens the loop to both versions:

```ruby
  # An export of this instance is version 2. A version 1 example is compared as the version 2 file it becomes with no
  # locations, and each location name as the export writes it: in NFC (decision 5), which a valid example in NFD isn't
  # (ruled 2026-10-21: AC-9.15 holds for the example once its names are normalised).
  def as_version_two(data)
    data = data.merge("format_version" => 2, "locations" => []) unless data["format_version"] == 2
    data.merge("locations" => data["locations"].map { |location| { "name" => Location::Name.normalise(location["name"]) } })
  end

  describe "every valid example of the format (AC-6.4, AC-9.15)" do
    # One entry and printing per source id (the examples repeat ids across lots), with the finishes of its lots.
    def build_catalog(data)
      data["lots"].group_by { |lot| lot.dig("entry", "source_id") }.each_value do |lots|
        entry = lots.first["entry"]
        set = Catalog::Set.find_by(collectible_type: entry["collectible_type"], code: entry["set_code"]) || create(:catalog_set, code: entry["set_code"])
        created = create(:catalog_entry, external_key: entry["source_id"], set:, number: entry["collector_number"], language: entry["language"], name: entry["name"])
        create(:mtg_printing, entry: created, finishes: (%w[nonfoil foil etched] + lots.filter_map { |lot| lot["finish"] }).uniq)
      end
    end

    # Version 1 only until Phase 5 reads locations; that phase removes the filter.
    ExportFormatRules.examples("valid").select { |_name, bytes| JSON.parse(bytes)["format_version"] == 1 }.each_key do |name|
      it "applies #{name} to an empty account and exports the same collection, or has nothing to change", :aggregate_failures do
        data = JSON.parse(ExportFormatRules.examples("valid").fetch(name))
        allow(Rails.configuration.x).to receive(:currency).and_return(Collector::Currency.fetch!(data["currency"]))
        build_catalog(data)
        user = create(:user, name: data.dig("profile", "name"), email_address: data.dig("profile", "email_address"))

        if data["lots"].empty?
          import = CollectionImport.new(account: user.account, file: StringIO.new(JSON.generate(data)))
          expect([ import.refused?, import.plan.nothing_to_change? ]).to eq([ false, true ])
        else
          expect(apply!(user, data).outcome).to eq(:applied)
          expect(same_collection?(as_version_two(data), export(user))).to be(true)
          expect(user.account.lots.count).to eq(data["lots"].size)
        end
      end
    end
  end
```

- [ ] Run `bin/rspec spec/models/collection_export_spec.rb spec/requests/collection_exports_spec.rb spec/models/collection_import/round_trip_spec.rb` — expect: FAIL (the header is version 1, no `locations`; the round trip compares a version 1 example with a version 2 export)
- [ ] Change `app/models/collection_export.rb`: the first comment line reads "format version 2 (spec 022, spec 029, docs/export-format/README.md)", `FORMAT_VERSION = 2` (the newest version, written literally: a version is a decision about a file's shape, not a constant to bump), `to_h` writes `"locations" => locations` between `"currency"` and `"lots"`, and:

```ruby
    # The names only, in the order of spec 029 decision 2 (comparison key, then name, in code-point order), so two
    # exports of one collection are the same file apart from their time. One query.
    def locations = @account.locations.ordered.pluck(:name).map { |name| { "name" => name } }
```

- [ ] Run `bin/rspec spec/models/collection_export_spec.rb spec/requests/collection_exports_spec.rb spec/system/collection_export_spec.rb spec/collection_export_core_spec.rb spec/models/collection_import` — expect: PASS
- [ ] Run `bin/rspec` — expect: PASS (the whole suite; the phase ends green)
- [ ] Commit: `feat(export): write export format version 2 with the collector's locations`

---

## Phase 4: The preview reads versions 1 and 2, and shows the locations

**Implements:** FR-5 (reading, the plan's "nothing to change", the preview page), decision 10 | **Satisfies:** AC-8.1 to AC-8.9, AC-9.3 (the preview side), AC-9.4 (the preview side), AC-9.9 (the fingerprint, plan side), AC-9.10 (the label), AC-9.18 (the preview side)
**Files:** `app/models/collection_import.rb`, `app/models/collection_import/locations.rb`, `app/models/collection_import/plan.rb`, `app/views/collections/import_previews/{show,_apply,_locations}.html.erb`, `app/helpers/import_previews_helper.rb`, `spec/support/import_helpers.rb`, `spec/models/collection_import/locations_spec.rb`, `spec/models/collection_import/plan_spec.rb`, `spec/models/collection_import_spec.rb`, `spec/requests/collection_import_previews_spec.rb`
**Interfaces:** Consumes: `ExportFormat::Rules.whole_number`, `.problems_in`, `VERSION`; `Location::Name` (Phases 0, 2); `CollectionImport::LIST_LIMIT`, `Plan`. Produces: `CollectionImport#locations -> CollectionImport::Locations` (`counted?`, `added` (names), `renamed` (`Renamed(held:, name:)`), `removed` (`Held(id:, name:, key:)`), `unchanged` (Integer), `counts`, `nothing_to_change?`, `removes?`, `listed_renamed`, `more_renamed`, `listed_removed`, `more_removed`, `fingerprint_part`, by name); `CollectionImport::Plan#locations`, `#writes_lots?`, and `#nothing_to_change?`, `#removes?`, `#fingerprint` extended; `ImportHelpers#import_file_v2`; `import_removals(import)` and `import_removed_counts(plan)` helpers.

What applying would do with locations is a replace by comparison key (decision 10). `CollectionImport::Locations` is built from the account's locations (one read of at most 500 rows) and the file's normalised names; for a version 1 file it is "not counted" and says nothing. The plan, its "nothing to change" test, its confirmation and its fingerprint read it, so everything that already reads the plan (the store condition, the apply form, `Apply#decide`) follows.

- [ ] Add the builder to `spec/support/import_helpers.rb` (after `import_file`):

```ruby
  # A version 2 file (spec 029): the same, with its locations by name.
  def import_file_v2(user, lots, locations: [], **fields)
    import_file(user, lots, format_version: 2, locations: locations.map { |name| { "name" => name } }, **fields)
  end
```

- [ ] Write the failing specs. `spec/models/collection_import/locations_spec.rb`:

```ruby
# spec/models/collection_import/locations_spec.rb
require "rails_helper"

# Spec 029 decision 10: what applying a file would do with the collector's locations (replace by comparison key).
RSpec.describe CollectionImport::Locations, type: :model do
  def held(id, name) = described_class::Held.new(id:, name:, key: Location::Name.key(name))

  def outcomes(held_names, file_names) = described_class.new(held_names.each_with_index.map { |name, index| held(index + 1, name) }, file_names)

  it "adds, renames, keeps and removes by comparison key (AC-8.2)", :aggregate_failures do
    result = outcomes([ "Trade binder", "box", "Old crate" ], [ "Blue binder", "Box", "Trade binder" ])

    expect(result.added).to eq([ "Blue binder" ])
    expect(result.renamed.map { |renamed| [ renamed.held.name, renamed.name ] }).to eq([ %w[box Box] ])
    expect(result.unchanged).to eq(1)
    expect(result.removed.map(&:name)).to eq([ "Old crate" ])
    expect(result.counts).to eq(added: 1, renamed: 1, unchanged: 1, removed: 1)
    expect([ result.counted?, result.nothing_to_change?, result.removes? ]).to eq([ true, false, true ])
  end

  it "removes every held location for a file with none (AC-8.3)", :aggregate_failures do
    result = outcomes(%w[a b c], [])

    expect(result.removed.map(&:name)).to eq(%w[a b c])
    expect(result.counts).to eq(added: 0, renamed: 0, unchanged: 0, removed: 3)
  end

  it "has nothing to change when the names are the held ones, in any order" do
    expect(outcomes(%w[Box Binder], %w[Binder Box]).nothing_to_change?).to be(true)
  end

  it "matches a name in another case or form to the held location, and keeps a held NFC spelling unchanged (AC-9.18)", :aggregate_failures do
    result = outcomes([ "Café" ], [ "Café" ]) # the reader normalises each file name, so NFD arrives here as NFC
    expect(result.unchanged).to eq(1)

    renamed = outcomes([ "Café" ], [ "CAFÉ" ])
    expect(renamed.renamed.map(&:name)).to eq([ "CAFÉ" ])
    expect(renamed.added).to eq([])
  end

  it "says nothing for a version 1 file, whatever is held (AC-8.4)", :aggregate_failures do
    result = outcomes(%w[a b], nil)

    expect(result.counted?).to be(false)
    expect([ result.added, result.renamed, result.removed, result.unchanged ]).to eq([ [], [], [], 0 ])
    expect([ result.nothing_to_change?, result.removes? ]).to eq([ true, false ])
  end

  it "lists the first 100 renamed and removed, in the page's order, and counts the rest (AC-8.9)", :aggregate_failures do
    held_names = (1..300).map { |number| format("old %03d", number) }
    file = (1..150).map { |number| format("OLD %03d", number) } # 150 renamed by case, 150 removed
    result = outcomes(held_names, file)

    expect(result.renamed.size).to eq(150)
    expect(result.removed.size).to eq(150)
    expect(result.listed_renamed.size).to eq(100)
    expect(result.more_renamed).to eq(50)
    expect(result.listed_removed.map(&:name).first(2)).to eq([ "old 151", "old 152" ])
    expect(result.more_removed).to eq(50)
  end

  it "gives the part of a fingerprint from what changes, by name and holding no id, and nothing for unchanged ones (decision 11, ruled 2026-10-21)", :aggregate_failures do
    part = outcomes([ "box", "Old crate", "Same" ], %w[Box Same New]).fingerprint_part

    expect(part).to eq([ [ "New" ], [ %w[box Box] ], [ [ "Old crate" ] ] ])
    expect(outcomes([ "box", "Old crate", "Same" ], %w[Box Same New]).fingerprint_part).to eq(
      CollectionImport::Locations.new([ held(7, "box"), held(8, "Old crate"), held(9, "Same") ], %w[Box Same New]).fingerprint_part) # other ids, the same part
  end
end
```

  The reader's examples, added to `spec/models/collection_import_spec.rb` in a new describe (the two examples about the newer version were changed in Phase 2):

```ruby
  # A version 2 file: the same, with its locations by name (spec 029).
  def file_v2(lots, locations: [], **fields) = file(lots, format_version: 2, locations: locations.map { |name| { "name" => name } }, **fields)

  def location_names(preview) = [ preview.locations.added, preview.locations.renamed.map(&:name), preview.locations.removed.map(&:name) ]

  describe "version 2 (spec 029 decision 10)" do
    it "reads version 1 and version 2, each against its own schema (AC-8.1)", :aggregate_failures do
      expect(import(file([]))).not_to be_refused
      expect(import(file_v2([]))).not_to be_refused
      expect(import(file_v2([], format_version: 2.0))).not_to be_refused
      expect(refusal_of(file([]).merge("format_version" => 2))).to eq([ "required", "/locations", "This file isn't a well-formed export: locations is missing." ])
    end

    it "refuses a bad locations list whole, naming the field and the reason (AC-8.5, P6)", :aggregate_failures do
      expect(refusal_of(file_v2([]).except("locations"))).to eq([ "required", "/locations", "This file isn't a well-formed export: locations is missing." ])
      expect(refusal_of(file_v2([]).merge("locations" => "Box")).last).to eq("This file isn't a well-formed export: locations isn't valid.")
      expect(refusal_of(file_v2([], locations: [ "Box", "a  b" ]))).to eq([ "pattern", "/locations/1/name", "This file isn't a well-formed export: locations.1.name isn't valid." ])
      expect(refusal_of(file_v2([], locations: [ "Box", "box" ]))).to eq(
        [ "duplicate_location", "/locations/1", "This file isn't a well-formed export: locations.1 has the same name as an earlier location, ignoring case." ])
      expect(refusal_of(file_v2([], locations: [ "Café", "Cafe\u0301" ])).first).to eq("duplicate_location")
      expect(refusal_of(file_v2([], locations: Array.new(501) { |index| "Binder #{index}" })).first(2)).to eq([ "maxItems", "/locations" ])
    end

    it "refuses a name whose normal form is over 60 code points, as a whole (AC-8.5)", :aggregate_failures do
      name = "#{"本" * 59}\u0344" # well-formed as written (60 code points); NFC is 61 (a CJK character composes with nothing)
      expect(ExportFormat::Rules.problems(JSON.generate(file_v2([], locations: [ name ])))).to eq([])

      expect(refusal_of(file_v2([], locations: [ name ]))).to eq(
        [ "maxLength", "/locations/0/name", "This file isn't a well-formed export: locations.0.name isn't valid." ])
    end

    it "reads a name in NFD as its NFC spelling, matching a held location of that name (AC-9.18)", :aggregate_failures do
      create(:location, account:, name: "Café")
      create(:location, account:, name: "Old crate")
      preview = import(file_v2([], locations: [ "Cafe\u0301", "Straße" ]))

      expect(preview.locations.unchanged).to eq(1)
      expect(location_names(preview)).to eq([ [ "Straße" ], [], [ "Old crate" ] ])
    end

    it "judges the lots of a version 2 file as it does a version 1 file's (AC-8.7)", :aggregate_failures do
      a = printing
      held(a, quantity: 3)
      one = import(file([ row(a, quantity: 5), stranger ]))
      two = import(file_v2([ row(a, quantity: 5), stranger ], locations: [ "Box" ]))

      expect(two.problem_rows.map(&:number)).to eq(one.problem_rows.map(&:number))
      expect([ two.added, two.changed, two.unchanged, two.removed, two.held ]).to eq([ one.added, one.changed, one.unchanged, one.removed, one.held ])
    end

    it "has no outcomes for locations in a version 1 file, whatever the account holds (AC-8.4, AC-9.3)", :aggregate_failures do
      create(:location, account:, name: "Box")
      preview = import(file([]))

      expect(preview.locations.counted?).to be(false)
      expect(preview.plan.nothing_to_change?).to be(true)
    end

    it "reads the locations from the account only (AC-9.13)", :aggregate_failures do
      create(:location, name: "Elsewhere")
      create(:location, account:, name: "Mine")

      expect(location_names(import(file_v2([], locations: [ "Mine" ])))).to eq([ [], [], [] ])
      expect(location_names(import(file_v2([], locations: [])))).to eq([ [], [], [ "Mine" ] ])
    end
  end
```

  `spec/models/collection_import/plan_spec.rb`, new examples (its helper `import(lots, **fields)` builds a version 1 file; add `def import_v2(lots, locations: [], **fields) = CollectionImport.new(account:, file: import_io(import_file_v2(user, lots, locations:, **fields)))`):

```ruby
  describe "locations (spec 029)" do
    def import_v2(lots, locations: [], **fields) = CollectionImport.new(account:, file: import_io(import_file_v2(user, lots, locations:, **fields)))

    it "has something to change for a file whose only change is a location, and nothing for one that matches (AC-9.4)", :aggregate_failures do
      held_lot(account, a, quantity: 3)
      create(:location, account:, name: "Box")

      expect(import_v2([ import_row(a, quantity: 3) ], locations: [ "Box" ]).plan.nothing_to_change?).to be(true)
      plan = import_v2([ import_row(a, quantity: 3) ], locations: [ "Box", "Crate" ]).plan
      expect([ plan.nothing_to_change?, plan.writes_lots?, plan.removes? ]).to eq([ false, false, false ])
      expect(import_v2([ import_row(a, quantity: 3) ], locations: [ "BOX" ]).plan.nothing_to_change?).to be(false) # a change of case alone
    end

    it "removes when it removes lots or locations, and writes lots only when a lot changes (AC-9.10, AC-9.17)", :aggregate_failures do
      held_lot(account, a, quantity: 3)
      create(:location, account:, name: "Old crate")
      only_locations = import_v2([ import_row(a, quantity: 3) ], locations: [])
      only_view = import_v2([ import_row(a, quantity: 3) ], locations: [ "Old crate" ], profile: { "name" => user.name, "email_address" => user.email_address, "collection_view" => "table" })
      lots = import_v2([ import_row(a, quantity: 4) ], locations: [ "Old crate" ])

      expect([ only_locations.plan.removes?, only_locations.plan.writes_lots? ]).to eq([ true, false ])
      expect([ only_view.plan.nothing_to_change?, only_view.plan.writes_lots? ]).to eq([ false, false ])
      expect([ lots.plan.removes?, lots.plan.writes_lots? ]).to eq([ false, true ])
    end

    it "leaves a version 1 file's plan and fingerprint to the lots (AC-9.3)", :aggregate_failures do
      create(:location, account:, name: "Box")
      plan = import([ import_row(a) ]).plan

      expect(plan.locations.counted?).to be(false)
      expect(plan.fingerprint("sum")).to eq(import([ import_row(a) ]).plan.fingerprint("sum"))
    end

    describe "#fingerprint (AC-9.9)" do
      def fingerprint(*names, lots: [ import_row(a) ]) = import_v2(lots, locations: names).plan.fingerprint("sum")

      it "is equal for two previews of one file and account, and differs for a location added, removed or respelled", :aggregate_failures do
        box = create(:location, account:, name: "box")
        baseline = fingerprint("Box", "New")

        expect(fingerprint("Box", "New")).to eq(baseline)
        create(:location, account:, name: "New") # added by another tab
        expect(fingerprint("Box", "New")).not_to eq(baseline)
        Location.where(name: "New").destroy_all
        box.update!(name: "Box") # respelled, so the rename became unchanged
        expect(fingerprint("Box", "New")).not_to eq(baseline)
        box.update!(name: "box")
        expect(fingerprint("Box", "New")).to eq(baseline)
        box.destroy!
        expect(fingerprint("Box", "New")).not_to eq(baseline)
      end

      it "differs for another file, and holds no id: a renamed, a removed and an unchanged location deleted and added again with the same spelling change nothing (AC-9.9, ruled 2026-10-21)", :aggregate_failures do
        [ "box", "Old crate", "Same" ].each { |name| create(:location, account:, name:) } # "box" is renamed to Box, "Old crate" is removed
        baseline = fingerprint("Box", "Same", "Other")

        expect(fingerprint("Box", "Same", "Another")).not_to eq(baseline)
        account.locations.each do |location|
          name = location.name
          location.destroy!
          create(:location, account:, name:) # a new id each, the same plan
        end
        expect(fingerprint("Box", "Same", "Other")).to eq(baseline)
      end
    end
  end
```

  `spec/requests/collection_import_previews_spec.rb` (its newer-version row was changed in Phase 2): add a `def file_v2(lots, locations: [], **fields) = file(lots, format_version: 2, locations: locations.map { |name| { "name" => name } }, **fields)` helper and, inside the signed-in context:

```ruby
    describe "locations (spec 029)" do
      let!(:entry) { printing }

      before do
        create(:location, account: user.account, name: "Trade binder")
        create(:location, account: user.account, name: "box")
        create(:location, account: user.account, name: "Old crate")
      end

      def locations_stat(label) = html.css("#locations .c-stat").find { |stat| stat.at_css("dt").text == label }&.at_css("dd")&.text

      it "reads the collector's own version 2 export and shows what happens to the locations (AC-8.1, AC-8.2)", :aggregate_failures do
        preview(file_v2([ row(entry) ], locations: [ "Blue binder", "Box", "Trade binder" ]))

        expect(response).to have_http_status(:ok)
        expect([ "Locations added", "Locations renamed", "Locations unchanged", "Locations removed" ].map { |label| locations_stat(label) }).to eq(%w[1 1 1 1])
        expect(html.css("#renamed_locations li").map { |item| item.text.squish }).to eq([ "box → Box" ])
        expect(html.css("#removed_locations li").map { |item| item.text.squish }).to eq([ "Old crate" ])
        expect(Location.pluck(:name)).to contain_exactly("Trade binder", "box", "Old crate") # nothing is written
      end

      it "says all would be removed for an empty list (AC-8.3)", :aggregate_failures do
        preview(file_v2([ row(entry) ], locations: []))

        expect(locations_stat("Locations removed")).to eq("3")
        expect(html.css("#removed_locations li").map { |item| item.text.squish }).to eq([ "box", "Old crate", "Trade binder" ])
      end

      it "says a version 1 file leaves them alone, and shows no removed locations (AC-8.4)", :aggregate_failures do
        preview(file([ row(entry) ]))

        expect(html.at_css("#locations_stay").text).to eq("This file was written before locations existed, so your locations would stay as they are.")
        expect(html.at_css("#locations, #removed_locations")).to be_nil
      end

      it "refuses a version 2 file whose locations are not well-formed, as a whole, with the reason (AC-8.5, P6)", :aggregate_failures do
        {
          file_v2([ row(entry) ]).except("locations") => "locations is missing",
          file_v2([ row(entry) ], locations: [ "Box", "box" ]) => "locations.1 has the same name as an earlier location, ignoring case",
          file_v2([ row(entry) ], locations: [ "a\u200Bb" ]) => "locations.0.name isn't valid"
        }.each do |data, reason|
          preview(data)

          expect(response).to have_http_status(:unprocessable_content)
          expect(html.at_css(".c-field--invalid .c-field__error")&.text).to include(reason)
          expect(html.at_css(".c-stats, #problem_rows")).to be_nil
        end
      end

      it "shows a name in NFD as its NFC spelling, matched to the held location (AC-9.18)", :aggregate_failures do
        create(:location, account: user.account, name: "Café") # held before the preview, so it reads the file's NFD name as a rename of it
        preview(file_v2([ row(entry) ], locations: [ "CAFE\u0301", "Trade binder", "box", "Old crate" ]))

        expect(html.css("#renamed_locations li").map { |item| item.text.squish }).to eq([ "Café → CAFÉ" ]) # NFC, as the page shows and the apply writes
        expect(locations_stat("Locations unchanged")).to eq("3")
      end

      it "counts all and lists the first 100 of each, with the rest counted (AC-8.9)", :aggregate_failures do
        Location.where(account_id: user.account.id).delete_all
        Location.insert_all!((1..300).map { |number| { account_id: user.account.id, name: format("old %03d", number), name_key: format("old %03d", number) } })

        preview(file_v2([ row(entry) ], locations: (1..150).map { |number| format("OLD %03d", number) }))

        expect([ locations_stat("Locations renamed"), locations_stat("Locations removed") ]).to eq(%w[150 150])
        expect(html.css("#renamed_locations li").size).to eq(100)
        expect(html.css("#removed_locations li").size).to eq(100)
        expect(html.css(".c-import__more").map(&:text)).to eq([ "and 50 more", "and 50 more" ])
      end

      it "offers the apply, and stores the file, when the only change is a location (AC-9.4)", :aggregate_failures do
        held_lot(user.account, entry, quantity: 1)
        preview(file_v2([ row(entry) ], locations: [ "Trade binder", "box", "Old crate", "Crate" ]))

        expect(html.at_css("form[action='#{collection_import_path}']")).to be_present
        expect(user.account.reload.import_upload).to be_present
        expect(html.at_css("form[action='#{collection_import_path}'] label.c-check")).to be_nil # nothing is removed: no checkbox
      end

      it "words the confirmation for the lots and the locations that would go (AC-9.10)", :aggregate_failures do
        held_lot(user.account, printing, quantity: 2) # the file doesn't name this lot's entry, so it is removed
        preview(file_v2([ row(entry) ], locations: [ "Trade binder" ]))

        expect(html.at_css("label.c-check").text.squish).to eq("I understand this removes 1 lot and 2 locations")
        expect(html.at_css("form[action='#{collection_import_path}'] .c-import__note").text).to include("removes 1 lot (2 copies) and 2 locations and can't be undone")
      end

      it "words it for locations alone when no lot goes (AC-9.10)", :aggregate_failures do
        held_lot(user.account, entry, quantity: 1)
        preview(file_v2([ row(entry) ], locations: [ "Trade binder", "box" ]))

        expect(html.at_css("label.c-check").text.squish).to eq("I understand this removes 1 location")
        expect(html.at_css("form[action='#{collection_import_path}'] .c-import__note").text).to include("removes 1 location and can't be undone")
      end

      it "writes only the upload, its blob and its attachment for a version 2 file (AC-8.8)" do
        before = snapshot
        preview(file_v2([ row(entry) ], locations: [ "Blue binder" ]))

        expect(snapshot.reject { |table, rows| before[table] == rows }.keys).to match_array(%w[import_uploads active_storage_blobs active_storage_attachments])
      end
    end
```

- [ ] Run `bin/rspec spec/models/collection_import spec/models/collection_import_spec.rb spec/requests/collection_import_previews_spec.rb` — expect: FAIL (`uninitialized constant CollectionImport::Locations`)
- [ ] Add `app/models/collection_import/locations.rb`:

```ruby
# What applying a file would do with the collector's locations (spec 029 decision 10): replace by comparison key. A
# version 1 file says nothing about locations (+names+ is nil), so theirs stay as they are and nothing here counts.
class CollectionImport::Locations
  Held = Data.define(:id, :name, :key)
  Renamed = Data.define(:held, :name)

  attr_reader :added, :renamed, :removed, :unchanged

  # +held+: the account's locations as Held. +names+: the file's names, each normalised on read, or nil for version 1.
  def initialize(held, names)
    @counted = !names.nil?
    @added = []
    @renamed = []
    @removed = []
    @unchanged = 0
    return unless @counted

    held_by_key = held.index_by(&:key)
    file = names.index_by { |name| Location::Name.key(name) }
    file.each do |key, name|
      kept = held_by_key[key]
      if kept.nil?
        @added << name
      elsif kept.name == name
        @unchanged += 1
      else
        @renamed << Renamed.new(held: kept, name:)
      end
    end
    @removed = held.reject { |location| file.key?(location.key) }
    @added.sort_by! { |name| [ Location::Name.key(name), name ] }
    @renamed.sort_by! { |renamed| [ renamed.held.key, renamed.name ] }
    @removed.sort_by! { |location| [ location.key, location.name ] }
  end

  def counted? = @counted

  def counts = { added: added.size, renamed: renamed.size, unchanged:, removed: removed.size }

  def nothing_to_change? = added.empty? && renamed.empty? && removed.empty?

  def removes? = removed.any?

  def listed_renamed = renamed.first(CollectionImport::LIST_LIMIT)

  def more_renamed = renamed.size - listed_renamed.size

  def listed_removed = removed.first(CollectionImport::LIST_LIMIT)

  def more_removed = removed.size - listed_removed.size

  # What the plan's fingerprint takes from the locations (decision 11, ruled 2026-10-21): the name of each added one; the
  # current name and the file's name of each renamed one; the name of each removed one. No id, and an unchanged one isn't
  # in it, so a location deleted and added again with the same spelling changes nothing (AC-9.9). The lists are already in
  # the order of the comparison key then the name, which is unique per account, so the part is the same every time. The
  # apply writes by the ids `replan` reads inside its transaction, so the fingerprint needs none.
  def fingerprint_part
    [ added, renamed.map { |item| [ item.held.name, item.name ] }, removed.map { |location| [ location.name ] } ]
  end
end
```

- [ ] Change `app/models/collection_import/plan.rb`:

```ruby
  attr_reader :added_rows, :changed_rows, :removed_lots, :view_change, :locations

  def initialize(outcomes, view_change, locations)
    @added_rows = outcomes.fetch(:added_rows)
    @changed_rows = outcomes.fetch(:changed_rows)
    @removed_lots = outcomes.fetch(:removed_lots)
    @matched = outcomes.fetch(:matched_lots)
    @view_change = view_change
    @locations = locations
  end

  # Nothing to change: no lot, no location and no view change (spec 028 decision 12, spec 029 decision 10).
  def nothing_to_change? = !writes_lots? && view_change.nil? && locations.nothing_to_change?

  # Whether the apply writes a lot; only then does it clear the working state that points at lots (spec 029 AC-9.17).
  def writes_lots? = added_rows.any? || changed_rows.any? || removed_lots.any?

  def removes? = removed_lots.any? || locations.removes?
```

  and in `fingerprint`, after building `parts`, `parts << locations.fingerprint_part if locations.counted?` (a version 1 file's fingerprint is what it was, so an upload stored before this change stays applicable); keep `Digest::SHA256.hexdigest(JSON.generate(parts))`. Also update the class comment: "…and, for a version 2 file, of the locations (spec 029 decision 11)".
- [ ] Change `app/models/collection_import.rb`:
  - the class comment's first line gains "(spec 025; spec 029 reads version 2)";
  - `plan` and `replan`:

```ruby
  # What applying would do to the collection as it was when this was first asked (the preview's view, spec 028).
  def plan = @plan ||= Plan.new(outcomes, view_change, locations)

  # The same, against the collection as it is now: one read of the lots, of the locations and of the user, no parsing
  # (spec 028 FR-2, spec 029 decision 11). It replaces the memoized plan, outcomes and locations, so that the page an apply
  # renders afterwards shows what the apply decided.
  def replan
    user.reload
    @removed_lots = nil # memoized from the outcomes below by #removed_lots
    @locations = nil
    @outcomes = outcomes_for(held_lots)
    @plan = Plan.new(@outcomes, view_change, locations)
  end

  # What applying would do with the collector's locations: nothing counted for a version 1 file (spec 029 decision 10).
  def locations = @locations ||= Locations.new(held_locations, @version >= 2 ? file_location_names : nil)
```

  - `header_refusal`, `field_reason` and two small methods (the old private `whole_number` goes; `ExportFormat::Rules.whole_number` is the one):

```ruby
    def header_refusal
      return refuse("type", "", NOT_AN_EXPORT) unless @data.is_a?(Hash)
      return refuse("required", "/format", NOT_AN_EXPORT) unless @data.key?("format")
      return refuse("const", "/format", NOT_AN_EXPORT) unless @data["format"] == ExportFormat::Rules::FORMAT
      return refuse("required", "/format_version", NO_VERSION) unless @data.key?("format_version")

      @version = ExportFormat::Rules.whole_number(@data["format_version"])
      return refuse("const", "/format_version", NO_VERSION) unless @version&.positive?
      return refuse("newer_version", "/format_version", newer(@version)) if @version > ExportFormat::Rules::VERSION

      @problems = ExportFormat::Rules.problems_in(@data)
      outside = @problems.reject { |problem| ROW.match?(problem.at) }
      first = outside.min_by { |problem| [ position(problem.at), outside.index(problem) ] }
      return refuse(first.rule, first.at, "This file isn't a well-formed export: #{field_reason(first.rule, field_name(first.at))}.") if first

      long_location
    end

    # A well-formed name whose NFC form is over 60 code points (U+0344 decomposes to two) can't be stored, so the file is
    # refused as a whole (spec 029 decision 9, an accepted limit).
    def long_location
      return unless @version >= 2

      index = @data["locations"].index { |location| Location::Name.normalise(location["name"]).length > Location::Name::MAX_LENGTH }
      index && refuse("maxLength", "/locations/#{index}/name", "This file isn't a well-formed export: #{field_reason("maxLength", "locations.#{index}.name")}.")
    end

    def field_reason(rule, field)
      case rule
      when "required" then "#{field} is missing"
      when "not_a_time" then "#{field} isn't a real moment"
      when "duplicate_location" then "#{field} has the same name as an earlier location, ignoring case"
      else "#{field} isn't valid"
      end
    end

    def file_location_names = @data["locations"].map { |location| Location::Name.normalise(location["name"]) }

    # The account's locations, in one statement (at most 500 rows).
    def held_locations
      @account.locations.pluck(:id, :name, :name_key).map { |id, name, key| Locations::Held.new(id:, name:, key:) }
    end
```

    (`newer(version)` keeps its text: "This instance reads version #{ExportFormat::Rules::VERSION}." now says 2. The comment above `header_refusal` gains "and, from version 2, its locations".)
- [ ] Add the helpers to `app/helpers/import_previews_helper.rb`:

```ruby
  # What an apply removes, in words: "3 lots (12 copies) and 2 locations" (spec 028 decision 6, spec 029 decision 11).
  def import_removals(import)
    plan = import.plan
    parts = []
    parts << "#{pluralize(number_with_delimiter(plan.removed_lots.size), "lot")} (#{import_copies(import.removed.copies)})" if plan.removed_lots.any?
    parts << pluralize(number_with_delimiter(plan.locations.removed.size), "location") if plan.locations.removes?
    parts.to_sentence
  end

  # The counts in the checkbox's label: "1 lot", "3 lots and 2 locations".
  def import_removed_counts(plan)
    parts = []
    parts << pluralize(number_with_delimiter(plan.removed_lots.size), "lot") if plan.removed_lots.any?
    parts << pluralize(number_with_delimiter(plan.locations.removed.size), "location") if plan.locations.removes?
    parts.to_sentence
  end
```

- [ ] Change `app/views/collections/import_previews/_apply.html.erb` (the lot-only text is character for character what it was):

```erb
    <% if plan.removes? %>
      <p class="c-import__note">Applying removes <%= import_removals(import) %> and can't be undone. <%= link_to "Download your current collection first", collection_export_path %>.</p>
      <div class="c-field">
        <label class="c-check"><%= check_box_tag :confirm_removal, "1", false, required: true %> I understand this removes <%= import_removed_counts(plan) %></label>
      </div>
```

- [ ] Add `app/views/collections/import_previews/_locations.html.erb` and render it in `show.html.erb` after the "Lots removed" section and before "Rows with problems" (`<%= render "collections/import_previews/locations", import: @import %>`), so that the Locations section sits with the lots' outcomes and its lists come after the apply form as the lots' lists do (decision 10, "shown as the lots' lists are"; plan review m11). The counts of added, renamed, unchanged and removed locations are therefore below the apply form, as the removed lots' list is:

```erb
<%# locals: (import:) %>
<% locations = import.locations %>
<% if locations.counted? %>
  <section id="locations">
    <div class="c-section__head"><h2 class="c-section__title">Locations</h2></div>
    <dl class="c-stats">
      <div class="c-stat"><dt>Locations added</dt><dd><%= number_with_delimiter(locations.added.size) %></dd></div>
      <div class="c-stat"><dt>Locations renamed</dt><dd><%= number_with_delimiter(locations.renamed.size) %></dd></div>
      <div class="c-stat"><dt>Locations unchanged</dt><dd><%= number_with_delimiter(locations.unchanged) %></dd></div>
      <div class="c-stat"><dt>Locations removed</dt><dd><%= number_with_delimiter(locations.removed.size) %></dd></div>
    </dl>
    <% if locations.renamed.any? %>
      <ul class="c-list c-import__list" id="renamed_locations">
        <% locations.listed_renamed.each do |renamed| %><li><span><%= renamed.held.name %> → <%= renamed.name %></span></li><% end %>
      </ul>
      <% if locations.more_renamed.positive? %><p class="c-import__more">and <%= number_with_delimiter(locations.more_renamed) %> more</p><% end %>
    <% end %>
    <% if locations.removed.any? %>
      <ul class="c-list c-import__list" id="removed_locations">
        <% locations.listed_removed.each do |location| %><li><span><%= location.name %></span></li><% end %>
      </ul>
      <% if locations.more_removed.positive? %><p class="c-import__more">and <%= number_with_delimiter(locations.more_removed) %> more</p><% end %>
    <% end %>
  </section>
<% else %>
  <p class="c-import__note" id="locations_stay">This file was written before locations existed, so your locations would stay as they are.</p>
<% end %>
```

- [ ] Run `bin/rspec spec/models/collection_import spec/models/collection_import_spec.rb spec/requests/collection_import_previews_spec.rb spec/models/export_format spec/export_format_examples_spec.rb` — expect: PASS. The "reports the rule and place problems.json names for each example refused as a whole (AC-2.7)" example of `collection_import_spec.rb` now also reads the 18 invalid version 2 examples through the reader and must match their `problems.json` entries; if one does not, the reader's refusal order or the example is wrong, not the example's entry.
- [ ] Run `bin/rspec` — expect: PASS (the whole suite; the phase ends green)
- [ ] Run `bin/rubocop -a` on the files of this phase; run `bin/rspec spec/import_apply_core_spec.rb spec/collection_import_core_spec.rb` — expect: PASS (the new files name no collectible type; add `app/models/collection_import/locations.rb`, `app/models/collection_import/location_changes.rb` (Phase 5), `app/models/location.rb`, `app/models/location/name.rb`, `app/controllers/locations_controller.rb`, `app/views/locations/index.html.erb` and `app/views/collections/import_previews/_locations.html.erb` to the file list in `spec/import_apply_core_spec.rb`, whose "exists, every file of it" example then also proves they exist; `location_changes.rb` is added in Phase 5)
- [ ] Commit: `feat(import): read export format version 2 in the preview, with a Locations section`

---

## Phase 5: Applying a version 2 file, and the round trip

**Implements:** FR-5 (the apply), decision 11 | **Satisfies:** AC-9.1 to AC-9.15, AC-9.17, AC-9.18, AC-8.8 (apply side), spec 028 AC-6.x with locations
**Files:** `app/models/collection_import/location_changes.rb`, `app/models/collection_import/apply.rb`, `app/controllers/collections/imports_controller.rb`, `spec/import_apply_core_spec.rb`, `spec/models/collection_import/apply_spec.rb`, `spec/models/collection_import/round_trip_spec.rb`, `spec/requests/collection_imports_spec.rb`, `spec/requests/collection_import_previews_spec.rb`, `spec/system/collection_import_apply_spec.rb`
**Interfaces:** Consumes: `Plan#locations`, `#writes_lots?`, `#removes?`, `#nothing_to_change?`, `#fingerprint` (Phase 4); `CollectionImport::Locations` (`added`, `renamed`, `removed`); `CollectionImport::BATCH_SIZE`; `Location::Name.key`. Produces: `CollectionImport::LocationChanges.write!(account, locations)` (the injection point of AC-9.8); `Apply#write!` that clears working state only when a lot is written and writes the locations after the lots; the notice of AC-9.14.

The seams spec 028's plan left (`Plan`, `Apply#write!`) are the only two places extended. The locations are written in the apply's one transaction, after the lots, in two statements whatever their number: one `delete_all` of the removed ones (first, so an added key never meets a removed one), one `upsert_all` on `[account_id, name_key]` that inserts the added and respells the renamed with their ids kept and `updated_at` set; an unchanged location is not in either. Bulk statements skip callbacks and validations on purpose, as 028 FR-3 does for lots (ruled 2026-10-20 for the bar): the names were validated by the reader (`ExportFormat::Rules`, `Location::Name`), and a spec checks the rows written against `Location`.

- [ ] Write the failing specs. In `spec/models/collection_import/apply_spec.rb` add (inside the describe, after "valid lots"):

```ruby
  describe "locations (spec 029 decisions 10 and 11)" do
    def preview_v2!(lots, locations: [], **fields) = store_import!(account:, data: import_file_v2(user, lots, locations:, **fields))

    def location_rows = account.locations.order(:id).pluck(:id, :name, :name_key, :created_at, :updated_at)

    def location_statements
      statements = []
      counter = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\b(INSERT INTO|UPDATE|DELETE FROM) "locations"/) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      statements.size
    end

    it "makes the account's locations the file's, keeping a renamed one's id and not writing an unchanged one (AC-9.1)", :aggregate_failures do
      trade, box = travel_to(Time.utc(2026, 10, 1)) { [ create(:location, account:, name: "Trade binder"), create(:location, account:, name: "box") ] }
      create(:location, account:, name: "Old crate")
      trade_before = trade.reload.attributes
      preview_v2!([ import_row(a) ], locations: [ "Blue binder", "Box", "Trade binder" ])

      expect(apply.outcome).to eq(:applied)

      expect(account.locations.ordered.pluck(:name)).to eq([ "Blue binder", "Box", "Trade binder" ])
      expect(box.reload.name).to eq("Box")
      expect(box.name_key).to eq("box")
      expect(box.updated_at).to be > Time.utc(2026, 10, 1)
      expect(trade.reload.attributes).to eq(trade_before)
    end

    it "fills an empty account with the file's lots and locations and nothing else (AC-9.2)", :aggregate_failures do
      preview_v2!([ import_row(a), import_row(b, quantity: 2), import_row(c) ], locations: [ "Blue binder", "Box", "Crate" ])

      expect(apply.outcome).to eq(:applied)
      expect(account.lots.count).to eq(3)
      expect(account.locations.ordered.pluck(:name)).to eq(%w[Blue\ binder Box Crate])
      expect(Location.where.not(account_id: account.id)).to be_empty
    end

    it "leaves the account's locations as they were for a version 1 file, with the same ids and times (AC-9.3)", :aggregate_failures do
      travel_to(Time.utc(2026, 10, 1)) { create(:location, account:, name: "Box") }
      before = location_rows
      preview!([ import_row(a) ])

      expect(apply.outcome).to eq(:applied)
      expect(location_rows).to eq(before)
    end

    it "applies a file whose only change is a location, changing no lot and clearing no working state (AC-9.4, AC-9.17)", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      removal = working_state_for(lot)
      create(:location, account:, name: "Old crate")
      preview_v2!([ import_row(a, quantity: 2) ], locations: [ "Blue binder" ])
      lots_before = lots_state

      expect(apply.outcome).to eq(:applied)
      expect(account.locations.pluck(:name)).to eq([ "Blue binder" ])
      expect(lots_state).to eq(lots_before)
      expect([ NumberEntry.count, Scanner::Sitting.count, BulkSelection.count, BulkSelection::Mark.count ]).to eq([ 1, 1, 1, 1 ])
      expect(removal.reload).to be_undoable
    end

    it "clears the working state when a lot is written, and leaves it for a change of view alone (AC-9.17)", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      removal = working_state_for(lot)
      profile = { "name" => user.name, "email_address" => user.email_address, "collection_view" => "table" }
      preview_v2!([ import_row(a, quantity: 2) ], locations: [], profile:)

      expect(apply.outcome).to eq(:applied)
      expect(user.reload.collection_view).to eq("table")
      expect(NumberEntry.count + Scanner::Sitting.count + BulkSelection.count).to eq(3) # a view change writes no lot
      expect(removal.reload).to be_undoable # the fourth kind of working state (plan review m8)

      preview_v2!([ import_row(a, quantity: 5) ], locations: [], profile:)
      expect(apply.outcome).to eq(:applied)
      expect(NumberEntry.count + Scanner::Sitting.count + BulkSelection.count).to eq(0)
    end

    it "writes nothing the second time, and the same file then previews as nothing to change (AC-9.7)", :aggregate_failures do
      create(:location, account:, name: "box")
      upload = preview_v2!([ import_row(a) ], locations: [ "Box", "Crate" ])
      first = apply(upload)
      after = location_rows

      expect(first.outcome).to eq(:applied)
      import = CollectionImport.new(account: account.reload, file: StringIO.new(JSON.generate(import_file_v2(user, [ import_row(a) ], locations: [ "Box", "Crate" ]))))
      expect(import.plan.nothing_to_change?).to be(true)
      expect(import.locations.unchanged).to eq(2)
      forced = store_import!(account:, data: import_file_v2(user, [ import_row(a) ], locations: [ "Box", "Crate" ]), forced: true)
      expect(apply(forced).outcome).to eq(:nothing_to_change)
      expect(location_rows).to eq(after)
    end

    it "rolls everything back when a location can't be written after the lots were, keeping the upload (AC-9.8)", :aggregate_failures do
      create(:location, account:, name: "Old crate")
      held_lot(account, d, quantity: 3)
      upload = preview_v2!([ import_row(a) ], locations: [ "Blue binder" ])
      before = snapshot
      allow(CollectionImport::LocationChanges).to receive(:write!).and_raise(RuntimeError, "disk full")

      expect { apply(upload) }.to raise_error(RuntimeError, "disk full")
      expect(snapshot).to eq(before)
      expect(account.reload.import_upload).to eq(upload)

      allow(CollectionImport::LocationChanges).to receive(:write!).and_call_original
      expect(apply(upload).outcome).to eq(:applied)
      expect(account.locations.pluck(:name)).to eq([ "Blue binder" ])
    end

    describe "a location changed after the preview (AC-9.9)" do
      let!(:box) { create(:location, account:, name: "box") }
      let!(:upload) { preview_v2!([ import_row(a) ], locations: [ "Box", "Same" ]) }

      it "is refused as stale when one was added, writing nothing", :aggregate_failures do
        create(:location, account:, name: "Late")
        before = snapshot

        expect(apply(upload).outcome).to eq(:stale)
        expect(snapshot).to eq(before)
        expect(account.locations.pluck(:name)).to match_array(%w[box Late])
      end

      it "is refused as stale when one was respelled, with the fresh plan showing it (a change of case alone)", :aggregate_failures do
        box.update!(name: "Box") # the rename became unchanged
        before = snapshot

        result = apply(upload)

        expect(result.outcome).to eq(:stale)
        expect(result.import.locations.counts).to eq(added: 1, renamed: 0, unchanged: 1, removed: 0)
        expect(snapshot).to eq(before)
      end

      it "is refused as stale when one was removed, writing nothing", :aggregate_failures do
        box.destroy!
        before = snapshot

        expect(apply(upload).outcome).to eq(:stale)
        expect(snapshot).to eq(before)
      end
    end

    it "applies after a renamed, a removed and an unchanged location were each deleted and added again with the same spelling (AC-9.9, ruled 2026-10-21)", :aggregate_failures do
      box, crate, same = [ "box", "Old crate", "Same" ].map { |name| create(:location, account:, name:) } # box is renamed, Old crate removed
      upload = preview_v2!([ import_row(a) ], locations: [ "Box", "Same", "New" ])
      recreated = [ box, crate, same ].map do |location|
        name = location.name
        location.destroy!
        create(:location, account:, name:) # new ids, the same names
      end

      expect(apply(upload).outcome).to eq(:applied)
      expect(account.locations.ordered.pluck(:name)).to eq(%w[Box New Same])
      expect(account.locations.find_by!(name: "Box").id).to eq(recreated.first.id) # the apply wrote by the ids it read inside its transaction
    end

    it "needs the confirmation only when it removes lots or locations (AC-9.10)", :aggregate_failures do
      create(:location, account:, name: "Old crate")
      removes = preview_v2!([ import_row(a) ], locations: [])

      expect(apply(removes, confirmed: false).outcome).to eq(:unconfirmed)
      expect(account.locations.count).to eq(1)
      expect(apply(removes, confirmed: true).outcome).to eq(:applied)
      expect(account.locations.count).to eq(0)

      create(:location, account:, name: "Old crate")
      renames = preview_v2!([ import_row(a) ], locations: [ "OLD CRATE", "New" ])
      expect(apply(renames, confirmed: false).outcome).to eq(:applied) # only additions and renames: no checkbox
      expect(account.locations.pluck(:name)).to match_array([ "OLD CRATE", "New" ])
    end

    it "removes a location without touching a lot (AC-9.11)", :aggregate_failures do
      held_lot(account, a, quantity: 4)
      create(:location, account:, name: "Old crate")
      upload = preview_v2!([ import_row(a, quantity: 4) ], locations: [])
      lots_before = lots_state

      expect(apply(upload).outcome).to eq(:applied)
      expect(lots_state).to eq(lots_before)
      expect(account.locations.count).to eq(0)
    end

    it "replaces 500 held locations with the file's 500 others, with no failure from the limit (AC-9.12)", :aggregate_failures do
      Location.insert_all!(Array.new(500) { |index| { account_id: account.id, name: "Place #{index}", name_key: "place #{index}" } })
      names = Array.new(500) { |index| "Other #{index}" }
      upload = preview_v2!([ import_row(a) ], locations: names)

      expect(apply(upload).outcome).to eq(:applied)
      expect(account.locations.pluck(:name)).to match_array(names)
    end

    it "touches only this account's locations (AC-9.13)", :aggregate_failures do
      other = create(:user)
      create(:location, account:, name: "Box")
      create(:location, account: other.account, name: "Box")
      theirs = other.account.locations.order(:id).pluck(:id, :name, :updated_at)
      upload = preview_v2!([ import_row(a) ], locations: [ "Blue binder" ])

      expect(apply(upload).outcome).to eq(:applied)
      expect(other.account.locations.order(:id).pluck(:id, :name, :updated_at)).to eq(theirs)
    end

    it "writes locations that Location would accept, with the key it gives (FR-3 of spec 028, for locations)", :aggregate_failures do
      create(:location, account:, name: "box")
      preview_v2!([ import_row(a) ], locations: [ "Box", "Straße", "Cafe\u0301", "日本語のバインダー" ])

      apply

      account.locations.each do |location|
        expect(location).to be_valid, location.name
        expect(location.name_key).to eq(Location::Name.key(location.name))
        expect(location.name).to eq(Location::Name.normalise(location.name))
      end
      expect(account.locations.pluck(:name)).to include("Café")
    end

    it "reads a name in NFD as its NFC spelling: unchanged against a held one, added as NFC without one, renamed when only the case differs (AC-9.18)", :aggregate_failures do
      held = create(:location, account:, name: "Café")
      before = held.reload.attributes
      preview_v2!([ import_row(a) ], locations: [ "Cafe\u0301", "Straße" ])
      expect(apply.outcome).to eq(:applied)
      expect(held.reload.attributes).to eq(before)
      expect(account.locations.pluck(:name)).to match_array([ "Café", "Straße" ])

      preview_v2!([ import_row(a) ], locations: [ "CAFE\u0301", "Straße" ])
      expect(apply.outcome).to eq(:applied)
      expect(held.reload.name).to eq("CAFÉ")
    end

    it "writes the locations in as many statements for 150 changes of each kind as for one (NFR)", :aggregate_failures do
      create(:location, account:, name: "box")
      create(:location, account:, name: "Old crate")
      few = preview_v2!([ import_row(a) ], locations: [ "Box", "New" ])
      few_statements = location_statements { apply(few) }

      Location.where(account_id: account.id).delete_all
      Location.insert_all!((1..300).map { |number| { account_id: account.id, name: format("old %03d", number), name_key: format("old %03d", number) } })
      many = preview_v2!([ import_row(a, quantity: 2) ], locations: (1..150).map { |number| format("OLD %03d", number) } + (1..150).map { |number| format("new %03d", number) })

      expect(location_statements { apply(many) }).to eq(few_statements)
    end
  end
```

  In `spec/models/collection_import/round_trip_spec.rb`, add helpers and examples (the existing `before` builds the lots; locations are made per example):

```ruby
  def locations(user, *names) = names.map { |name| create(:location, account: user.account, name:) }

  def names(user) = user.account.locations.order(:id).pluck(:name)

  it "restores an export's locations by name, exactly spelled, into an empty account (AC-9.5)", :aggregate_failures do
    locations(source, "Blue binder", "Trade binder", "box")
    original = export(source)

    expect(apply!(target, original).outcome).to eq(:applied)

    expect(names(target)).to match_array([ "Blue binder", "Trade binder", "box" ])
    expect(same_collection?(original, export(target))).to be(true)
    expect(export(target)["locations"]).to eq(original["locations"])
    expect(ExportFormatRules.problems(JSON.generate(export(target)))).to be_empty
  end

  it "restores a changed set of locations from the file, and then has nothing to change (AC-9.6)", :aggregate_failures do
    blue, = locations(source, "Blue binder", "Trade binder", "Old crate")
    original = export(source)
    source.account.locations.find_by!(name: "Blue binder").update!(name: "Green binder")
    source.account.locations.find_by!(name: "Old crate").destroy!
    create(:location, account: source.account, name: "New box")

    expect(apply!(source, original).outcome).to eq(:applied)

    expect(names(source)).to match_array([ "Blue binder", "Trade binder", "Old crate" ])
    expect(same_collection?(original, export(source))).to be(true)
    expect(CollectionImport.new(account: source.account, file: StringIO.new(JSON.generate(original))).plan.nothing_to_change?).to be(true)
    expect(Location.exists?(blue.id)).to be(false) # the respelled "Green binder" went
    expect(source.account.locations.find_by!(name: "Blue binder").id).not_to eq(blue.id) # and "Blue binder" came back as a new row
  end

  it "previews the exported collection, locations and all, as nothing to change (AC-6.1 of spec 028, with locations)", :aggregate_failures do
    locations(source, "Blue binder", "box")
    import = CollectionImport.new(account: source.account, file: StringIO.new(JSON.generate(export(source))))

    expect(import.locations.unchanged).to eq(2)
    expect(import.plan.nothing_to_change?).to be(true)
    expect(ImportUpload.count).to eq(0)
  end

  The describe "every valid example of the format (AC-6.4, AC-9.15)" that Phase 3 added (with `as_version_two`, which passes each location name through `Location::Name.normalise`, and its `build_catalog`) is widened here to both versions: remove the `.select { … format_version == 1 }` from its `each_key` loop (and its comment), change the empty branch's condition to `data["lots"].empty? && data.fetch("locations", []).empty?`, and add after the lots count `expect(user.account.locations.count).to eq(data.fetch("locations", []).size)`. For `valid/locations-nfd.json` the comparison holds because the expected file has "Cafe\u0301" as "Café" (NFC), which is what the apply stored and the export wrote; the example's own bytes differ from the export's, and the example says so in the format document. `verification.md` records this as the reading of AC-9.15 that the maintainer ruled (2026-10-21, spec 1.3.2).

  In `spec/requests/collection_imports_spec.rb` add (inside the signed-in context; `preview!` there builds version 1, so add `def preview_v2!(lots, locations: []) = store_import!(account:, data: import_file_v2(user, lots, locations:))`):

```ruby
    it "adds the locations to the notice, with no final period (AC-9.14)", :aggregate_failures do
      create(:location, account:, name: "box")
      create(:location, account:, name: "Old crate")
      preview_v2!([ import_row(a) ], locations: [ "Box", "Blue binder", "Trade binder" ])

      apply
      follow_redirect!

      expect(response.body).to include("Imported: 1 lot added, 0 changed, 0 removed; 2 locations added, 1 renamed, 1 removed")
      expect(html.at_css("#status").text.strip).not_to end_with(".") # never a final period (ruled 2026-10-21)
    end

    it "names only the location parts that are not zero, but keeps the zero lot parts, after a version 2 file that changes only locations (AC-9.14)", :aggregate_failures do
      create(:location, account:, name: "Old crate")
      preview_v2!([], locations: [])

      apply
      follow_redirect!
      expect(html.at_css("#status").text.strip).to eq("Imported: 0 lots added, 0 changed, 0 removed; 1 location removed")
    end

    it "says nothing about locations after a version 1 file (AC-9.14)", :aggregate_failures do
      create(:location, account:, name: "Box")
      preview!([ import_row(a) ])

      apply
      follow_redirect!

      expect(html.at_css("#status").text.strip).to eq("Imported: 1 lot added, 0 changed, 0 removed")
    end

    it "answers 409 with a fresh preview, locations included, when a location changed after the preview (AC-9.9)", :aggregate_failures do
      upload = preview_v2!([ import_row(a) ], locations: [ "Blue binder" ])
      create(:location, account:, name: "Late")

      apply(upload)

      expect(response).to have_http_status(:conflict)
      expect(html.at_css("#locations")).to be_present
      expect(html.css("#removed_locations li").map { |item| item.text.squish }).to eq([ "Late" ])
      expect(html.at_css("input[name=fingerprint]")["value"]).not_to eq(upload.fingerprint)
      expect(account.locations.pluck(:name)).to eq([ "Late" ])
    end

    it "asks for the confirmation when only locations are removed, and writes nothing without it (AC-9.10)", :aggregate_failures do
      create(:location, account:, name: "Old crate")
      upload = preview_v2!([ import_row(a) ], locations: [])

      apply(upload, confirm_removal: "0")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Confirm the removal to apply this file", "I understand this removes 1 location")
      expect(account.locations.count).to eq(1)
    end

    it "shows nothing of another account's locations in any response (AC-9.13)", :aggregate_failures do
      create(:location, name: "Zebulon's crate")
      create(:location, account:, name: "Mine")
      upload = preview_v2!([ import_row(a) ], locations: [ "Mine", "New" ])
      create(:location, account:, name: "Late")

      apply(upload) # 409
      conflict = response.body
      apply(account.reload.import_upload) # 303
      follow_redirect!

      [ conflict, response.body ].each { |body| expect(body).not_to include("Zebulon") }
    end
```

  and in `spec/requests/collection_import_previews_spec.rb`, next to the empty-example preview, add:

```ruby
    it "previews each empty example, version 1 and version 2, in its own currency, as nothing to change (AC-9.15)", :aggregate_failures do
      %w[valid/empty.json valid/empty-v2.json].each do |name|
        allow(Rails.configuration.x).to receive(:currency).and_return(Collector::Currency.fetch!("EUR"))
        post collection_import_preview_path, params: { export_file: import_upload_file(ExportFormatRules.examples("valid").fetch(name)) }

        expect(response).to have_http_status(:ok), name
        expect(response.body).to include("nothing to change"), name
        expect(ImportUpload.count).to eq(0)
      end
    end
```

  and a system example in `spec/system/collection_import_apply_spec.rb`:

```ruby
  it "applies a version 2 file's locations with the removal confirmed, and the locations page shows them (spec 029 Story 9)", :aggregate_failures do
    create(:location, account: user.account, name: "Old crate")
    path.write(JSON.generate(import_file_v2(user, [], locations: [ "Blue binder" ])))

    visit new_collection_import_preview_path
    attach_file "Export file", path.to_s
    click_on "Preview import"
    expect(page).to have_css("#renamed_locations, #removed_locations", text: "Old crate")
    check "I understand this removes 1 location"
    click_on "Apply import"

    expect(page).to have_css("#status", exact_text: "Imported: 0 lots added, 0 changed, 0 removed; 1 location added, 1 removed")
    visit locations_path
    expect(page).to have_css(".c-locations__name", text: "Blue binder")
    expect(page).to have_no_css(".c-locations__name", text: "Old crate")
  end
```

- [ ] Run `bin/rspec spec/models/collection_import spec/requests/collection_imports_spec.rb spec/requests/collection_import_previews_spec.rb` — expect: FAIL (`uninitialized constant CollectionImport::LocationChanges`; the notice has no locations; the working state is cleared for a view-only apply)
- [ ] Add `app/models/collection_import/location_changes.rb`:

```ruby
# Writes what an apply decided about the collector's locations (spec 029 decision 11), inside the apply's one write
# transaction and in at most two statements whatever their number: the removed ones are deleted first, so that an added
# key never meets a removed one, then one upsert on [account_id, name_key] inserts the added ones and respells the renamed
# ones, whose ids stay. An unchanged location isn't written, not even its updated_at. The names were validated by the
# reader, so the bulk statements skip Location's validations on purpose, as the lots' do (spec 028 FR-3); a spec checks the
# rows against Location. Collectible-agnostic.
module CollectionImport::LocationChanges
  def self.write!(account, locations)
    return if locations.nothing_to_change?

    locations.removed.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| account.locations.where(id: ids).delete_all }
    now = Time.current
    rows = (locations.added + locations.renamed.map(&:name)).map do |name|
      { account_id: account.id, name:, name_key: Location::Name.key(name), created_at: now, updated_at: now }
    end
    rows.each_slice(CollectionImport::BATCH_SIZE) do |slice|
      Location.upsert_all(slice, unique_by: %i[account_id name_key], update_only: %i[name updated_at], record_timestamps: false, returning: false)
    end
  end
end
```

- [ ] Change `Apply#write!` in `app/models/collection_import/apply.rb` (its comment gains "and the locations (spec 029)"):

```ruby
    def write!(plan, rows)
      plan.removed_lots.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.lots.where(id: ids).delete_all }
      (plan.added_rows + plan.changed_rows).each_slice(CollectionImport::BATCH_SIZE) do |slice|
        Lot.upsert_all(slice.map { |row| rows.fetch(row.number) }, unique_by: %i[account_id catalog_entry_id lot_key],
          update_only: %i[quantity created_at updated_at], record_timestamps: false, returning: false)
      end
      # Only a written lot makes the lists that point at lots wrong (spec 029 decision 11, AC-9.17).
      CollectionImport::WorkingState.clear!(@account) if plan.writes_lots?
      CollectionImport::LocationChanges.write!(@account, plan.locations)
      @account.user.update!(collection_view: plan.view_change) if plan.view_change
    end
```

- [ ] Change `Collections::ImportsController`: `when :applied then redirect_to collection_path, notice: notice_for(result.plan), status: :see_other`, and

```ruby
    def notice_for(plan)
      counts = plan.counts
      lots = "Imported: #{helpers.pluralize(counts[:added], "lot")} added, #{counts[:changed]} changed, #{counts[:removed]} removed"
      locations = location_sentence(plan.locations)
      locations ? "#{lots}; #{locations}" : lots
    end

    # "2 locations added, 1 renamed, 1 removed": the noun on the first part that isn't zero, the zero parts left out; nil
    # for a version 1 file and when no location changes. The notice never ends with a period, as 028's has none (spec 029
    # AC-9.14, ruled 2026-10-21).
    def location_sentence(locations)
      return unless locations.counted?

      parts = locations.counts.slice(:added, :renamed, :removed).reject { |_verb, count| count.zero? }
      return if parts.empty?

      parts.map.with_index { |(verb, count), index| index.zero? ? "#{helpers.pluralize(count, "location")} #{verb}" : "#{count} #{verb}" }.join(", ")
    end
```

- [ ] Add `app/models/collection_import/location_changes.rb` and `app/models/collection_import/locations.rb` to the file list in `spec/import_apply_core_spec.rb` (they name no collectible type; its "exists, every file of it" example proves they exist)
- [ ] Run `bin/rspec spec/models/collection_import spec/models/collection_import_spec.rb spec/requests/collection_imports_spec.rb spec/requests/collection_import_previews_spec.rb spec/models/import_upload_spec.rb spec/import_apply_core_spec.rb` — expect: PASS
- [ ] Run `bin/rspec spec/system/collection_import_apply_spec.rb spec/system/collection_import_preview_spec.rb` — expect: PASS
- [ ] Run `bin/rspec` — expect: PASS (the whole suite; the phase ends green)
- [ ] Run `bin/rubocop -a` on the files of this phase — expect: no offenses
- [ ] Commit: `feat(import): apply the locations of a version 2 file in the apply's one transaction`

---

## Phase 6: Measure, document and verify

**Implements:** NFR (performance, cost), AC-9.16, AC-7.1 (review), AC-5.5 (screenshots), the "Documents that change" list | **Satisfies:** AC-9.16, AC-7.1, "Documents that change"
**Files:** `docs/specs/029-manage-locations/verification.md`, `CLAUDE.md`, `README.md`, `docs/roadmap.md`, `docs/specs/README.md`, `docs/adr/0020-export-format.md` (Status line only), `docs/adr/0023-locations-make-export-format-version-2.md` (Status), `docs/design-system/components/Locations.md`, `docs/design-system/components/{AppHeader,MorePage,ImportPreview}.md`, `docs/design-system/README.md`, `docs/releasing.md`
**Interfaces:** Consumes: everything above. Produces: `verification.md` and the documents.

- [ ] Measure the bars of spec 028 with 500 locations (AC-9.16), by the method of 028's `verification.md` ("Measurements"): the development machine, this worktree's own development database, a throwaway runner script in the session scratchpad that is never committed, and a real `rails server` with `curl`, a session and the form's token; RSS read from `ps` before and after each request; everything deleted afterwards. 50,000-row files of version 2, each with locations: (a) all resolvable into an empty account, 500 locations in the file; (b) the same file applied to an account holding those 50,000 lots and 500 locations, every row changed and every location renamed by case (`Place n` held, `PLACE n` in the file); (c) a file with no lots and `locations: []` applied to 50,000 lots and 500 locations, removal confirmed. Record per case: the write transaction (`transaction.active_record` durations, in-process, `CollectionImport::Apply#call`), the whole request (preview and apply), RSS growth. **Bars (spec 028, as merged):** transaction under 4 s (028 measured 2.39 s, 3.21 s, 0.93 s), whole request under 30 s (6.72 s, 7.56 s, 0.91 s), RSS growth under 500 MB (028's preview of (a) grew 408 MB). A bar that is missed goes to the maintainer; it is not changed here. Also record, with 500 locations: the locations page's time, the export's time, and the number of statements the apply wrote to `locations` (at most two).
- [ ] Run by hand, once, two simultaneous adds at 499 locations and two simultaneous adds of one name (`curl … &` twice, with a session and a token): exactly one location is added each time and the other answers 422 with the message of AC-1.10 or AC-1.9 (AC-1.13; the deterministic specs cover the sequence and the unique index). Record the ten trials in `verification.md`, as spec 028 did for AC-2.3.
- [ ] Take screenshots for AC-5.5 as spec 028 did (headless Firefox, an iframe of the page's own HTML, light and dark at 1280 px and 390 px): the locations page (empty, with names, with an error), the rename page, the removal page, the preview's Locations section and the apply form with "removes 1 lot and 2 locations", under `docs/specs/029-manage-locations/screenshots/`.
- [ ] Add the design-system doc `docs/design-system/components/Locations.md` (the markup of `locations/index.html.erb`: `c-pagehead`, the add `c-form` with one `c-field`, a `c-list c-locations__list` of rows with a name and two `c-btn c-btn--ghost c-btn--sm` actions, `c-empty` when there are none; the rules: 44px targets on every pointer, long names wrap, the removal uses `ConfirmPage`, the page works without scripting, the copy names no collectible type) and the line in `docs/design-system/README.md`: "App additions (spec 029, in `collector/additions.css`): `Locations`. Upstream it into the published design system before the next export replaces this folder." Update `AppHeader.md` (the collector's links: Collection, Search, Scan, Locations), `MorePage.md` (Locations before Export collection), `ImportPreview.md` (the Locations section and the removal wording) and the README's Navigation list if it names the header's links.
- [ ] Update the documents, each verified by reading and listed in `verification.md`:
  - `CLAUDE.md`: the status paragraph ("A collector manages the places their collection is kept in at `/locations`, `Location`, spec 029; the export is format version 2 and the preview and apply read versions 1 and 2"); the "Export format" fact (version 2, `v2.schema.json`, `ExportFormat::Rules::VERSIONS`, the Coverage line for `locations`); the "Import preview" fact (the Locations section, `CollectionImport::Locations`, a location-only file is applicable); a new fact "Locations (spec 029, ADR 0023)": names (`Location::Name`: NFC, White_Space, Cc/Cf, 1 to 60 code points, comparison key), 500 per account, removing a location never removes lots, the apply writes locations in two statements (`CollectionImport::LocationChanges`) and clears working state only when a lot is written.
  - `README.md`: the "Your data" paragraph (locations; exports are version 2, which an older instance reads as newer than it can read) and the navigation if it lists it.
  - `docs/releasing.md`: an upgrade note: one new migration (`locations`); exports written by this release are format version 2 and can't be read by an earlier release.
  - `docs/roadmap.md`: item 9 marked done with spec 029 and the pull request; item 10's "raises the export format to version 2" becomes "version 3"; a line in the decision log that ruling 32 stands for the locations list (as spec 029's Supersedes says).
  - `docs/adr/0020-export-format.md`: its Status line gains "The consequence about a lot in a location raising the format to version 2 is superseded by [ADR 0023](0023-locations-make-export-format-version-2.md)." (the one edit the spec calls for); `docs/adr/0023-…md`: Status becomes "Accepted (<date of approval>)" when the maintainer approves this plan.
  - `docs/specs/README.md`: the 029 row's status moves to "Approved (028 merged; plan: …)" and its Plan cell to "plan.md"; both directions of the supersessions of spec 029's table are in the index (the 017, 022, 025 and 028 rows' "Superseded by" cells gain 029 where they name the item). Spec 028's own row and spec 028 are not edited beyond the "Superseded by" cell the index owns.
  - `.rubocop.yml`: nothing, unless `spec/models/collection_import/apply_spec.rb` or `round_trip_spec.rb` now exceed an existing scenario exclusion (they are already excluded by name).
- [ ] Write `docs/specs/029-manage-locations/verification.md`: every AC and FR → the example that holds it (file and title), the measurements above, the screenshots, the documents verified by reading (AC-7.1 on the format document: version 2, `locations`, `duplicate_location`, version 1's definitions as they were, the version-history row), and the deviations from this plan. Notes it must carry: (1) AC-9.15 is held for `valid/locations-nfd.json` once the example's names are normalised to NFC, as ruled on 2026-10-21 (spec 1.3.2); (2) the measured sizes of any header target other than the Locations link and the back button, if under 44px (not changed here); (3) the 640px header measurements (AC-5.1); (4) the run time of the parity example.
- [ ] Run the full local CI: `bin/ci` — expect: every step passes (setup, RuboCop, Brakeman, bundler-audit, importmap audit, RSpec). If RSpec fails, reproduce with the CI seed first (`reproduce-ci-with-seed`). `git diff --stat db/schema.rb` shows only the `locations` table.
- [ ] Run `sdd-superpowers:sdd-review` (Mode B, an independent implementation review, read-only) against spec 1.3.2 and record its verdict in `verification.md` under `## Implementation review` with the verdict on its first line; then `distill-feature` before the merge (CLAUDE.md, `.claude/CLAUDE.md`).
- [ ] Commit: `docs(029): record the measurements, the screenshots and the verification of spec 029`

---

## Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run the whole suite: `bin/rspec` — expect: 0 failures (the parity example reports its run time)
- [ ] Walk the stories by hand against the running app (`bin/dev`, the worktree's port): add, rename (a case change, a clash), remove a location; More and the header; export a collection with locations; preview and apply it into a second account (with and without a removed location and the checkbox); a version 1 file leaves the locations alone
- [ ] Confirm `git diff origin/main --stat -- docs/export-format/v1.schema.json app/models/export_format/v1.schema.json docs/export-format/examples/valid/collection.json docs/export-format/examples/valid/empty.json docs/export-format/examples/comparison/base.json docs/export-format/examples/comparison/same.json` is empty (version 1 unchanged), and that `cmp docs/export-format/v2.schema.json app/models/export_format/v2.schema.json` is silent
- [ ] Confirm spec 028 and every other shipped spec are unedited: `git diff origin/main --stat -- docs/specs/*/spec.md` lists only spec 029's
- [ ] Commit: `feat: manage locations, with export format version 2` (if anything is left uncommitted)

---

## Quickstart Validation

1. `bin/setup --skip-server`, `bin/rails db:prepare`, `bin/dev`, sign in.
2. Open More, then Locations. Add "Blue binder", then "  blue   BINDER ": the second is refused with "You already have a location called “blue BINDER”.". Rename "Blue binder" to "blue binder" (allowed). Remove it through its confirmation page.
3. Add "Trade binder" and "box". Open Export collection: the file's `format_version` is 2 and its `locations` are `[{"name": "box"}, {"name": "Trade binder"}]` (by comparison key, so "box" first).
4. Rename "box" to "Box" and add "Old crate". Open Import collection and choose the exported file: the Locations section says 1 renamed (Box → box) and 1 removed (Old crate); the apply form asks "I understand this removes 1 location". Check it and apply: the notice reads "Imported: 0 lots added, 0 changed, 0 removed; 1 location renamed, 1 removed" (no final period) and the locations page lists "box" and "Trade binder".
5. Choose the same file again: the preview says there is nothing to change and offers no apply.
6. Open the format document and the examples under `docs/export-format/`: version 2 is defined next to version 1, and `bin/rspec spec/export_format_document_spec.rb spec/export_format_examples_spec.rb` passes.
