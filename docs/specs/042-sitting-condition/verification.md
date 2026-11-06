# Spec 042: Verification

Verified on 2026-11-06 on branch `042-sitting-condition`. The spec was approved at 0.3.1 and the plan at `d2f26f8`. Tasks 1 to 12 were built test-first by one implementer per task, and each task's diff was checked against the plan and the spec before the next began.

## Targeted runs

| Command | Result |
|---|---|
| `bin/rspec spec/migrations/add_condition_to_scanner_sittings_spec.rb spec/migrations/add_location_to_scanner_sittings_spec.rb` | 9 examples, 0 failures |
| `bin/rspec spec/models/scanner spec/helpers/scanners_helper_spec.rb spec/scanner_sitting_core_spec.rb spec/number_entry_core_spec.rb` | 72 examples, 0 failures |
| `bin/rspec spec/requests/scanner spec/requests/scanners_spec.rb spec/requests/locations_spec.rb` | 173 examples, 0 failures |
| `bin/rspec spec/models/collection_import/apply_spec.rb spec/export_format_document_spec.rb spec/models/account_spec.rb spec/backup_guards_spec.rb` | 87 examples, 0 failures |
| `bin/rspec spec/system/scanner_sitting_spec.rb spec/system/scanner_adding_spec.rb spec/system/scanner_measurement_spec.rb spec/system/scanner_spec.rb` | 34 examples, 0 failures |
| `bin/rspec spec/system/scanner_art_spec.rb spec/system/scanner_detection_spec.rb spec/system/scanner_timing_spec.rb` | 14 examples, 0 failures |
| `bin/rubocop` | 636 files, no offenses |
| `bin/brakeman -q` | No warnings |
| `bin/bundler-audit` | No vulnerabilities |
| `ruby script/upgrade/guard.rb` | v0.2.1: its 14 migrations are unchanged |

Before any change, the scanner model and request specs passed (150 examples). The whole suite and `bin/ci` run in a CI slot and in the pre-push hook; their result is recorded in the pull request.

**Red runs.** Each task's new examples failed for the reason the plan gave before its code went in:

- Task 1: LoadError, because the migration didn't exist yet.
- Task 2: 16 of 29 failed, because `choose!` didn't exist.
- Task 3: 6 failed, because adds ignored the condition. AC-4.5 was checked by hand: with the new check removed, the example fails on `Lot`'s `RecordInvalid`.
- Task 4: the guard went red when a guarded file was given the word "magic", which was then reverted.
- Task 5: 3 failed, because the helpers didn't exist.
- Task 6: 16 of 72 failed.
- Task 7: 16 of 60 failed.
- Task 8: 5 of 22 failed.

Tasks 9 and 10 are acceptance examples that pass on arrival, as the plan says.

## Checks by hand

- **The export is untouched.** `git diff origin/main --stat -- docs/export-format app/models/export_format app/models/collection_export.rb` is empty (decision 6, FR-3).
- **The schema.** `db/schema.rb`'s diff against `origin/main` is the version line and `t.string "condition"`.
- **The core guard.** `git grep -n -i -E "\b(mtg|scryfall|magic)\b"` over `app/models/scanner/sitting.rb`, `sitting_entry.rb`, the partials `_sitting`, `_sitting_entry`, `_picker` and `_summary`, and `app/helpers/scanners_helper.rb` finds nothing. The collectible type is named only in `ScannerSitting#scanner_conditions` (`app/controllers/concerns/scanner_sitting.rb`), as decision 5 allows.
- **No environment variable is added** (NFR collector choices).

## Criteria

| Criterion | Evidence |
|---|---|
| AC-1.1 | `spec/requests/scanner/sittings_spec.rb`: "shows the control alone before the first add…", "puts the Location select after Condition…"; screenshots |
| AC-1.2 | `spec/models/scanner/sitting_spec.rb` `.choose!` "opens a sitting…"; `sittings_spec` "opens a sitting holding the condition…"; system "opens a sitting with the condition, keeping the page and its camera" |
| AC-1.3 | `sitting_spec` "adds into the lot of that printing, finish and condition…"; `sitting_entries_spec` condition describe; system "scans into the condition…" |
| AC-1.4 | `sitting_spec` "adds with the condition and the place together"; `sitting_entries_spec` "names the condition and the place together" |
| AC-1.5 | `sitting_spec` "joins the lot with no condition…"; `sittings_spec` "shows the entry with no condition…"; `sitting_entries_spec` "names no condition when the sitting has none" |
| AC-1.6 | `sitting_spec` and `sitting_entries_spec` "refuses at the cap of the lot of that condition…" |
| AC-1.7 | `sittings_spec` "keeps the condition on a reload"; system "keeps the condition on a reload…" |
| AC-1.8 | `sitting_spec` `.choose!` clear, delete and keep examples; `sittings_spec` "clears the condition of a sitting with a card…" |
| AC-2.1 | `sittings_spec` "changes the condition of an open sitting…"; system "…into another once it changes mid-sitting" |
| AC-2.2 | `sittings_spec` "takes Undo of an entry added under another condition…" |
| AC-2.3 | `sittings_spec` "shows the short label after the finish, from the entry's lot as it is now" |
| AC-2.4 | `sitting_spec` `.choose!` "keeps the choice it isn't given…"; `sittings_spec` |
| AC-3.1 | `sittings_spec` "shows the control alone before the first add…" (no locations); screenshots `control-no-locations-*` |
| AC-3.2 | `sittings_spec` "names the sitting's choices in the heading…" |
| AC-3.3 | `sitting_spec` `#pointless?`; `sittings_spec` "keeps a sitting with a condition and no entries…", "drops a sitting with no entries and neither choice…" |
| AC-4.1 | `sittings_spec` "refuses a condition that is not a key…", "refuses a bad condition with no sitting open…" |
| AC-4.2 | `sittings_spec` "answers 400 to a request with neither key…" |
| AC-4.3 | `sittings_spec` "ignores a sitting id, an account id…" (nested and top level), "never touches another account's sitting" |
| AC-4.4 | `sitting_spec` "answers a replayed key with its entry…"; `sitting_entries_spec` "names the entry's lot's condition and place on a replay…" |
| AC-4.5 | `sitting_spec` and `sitting_entries_spec` "refuses a condition the printing's vocabulary doesn't know…" (`:other_collecting`, a second vocabulary) |
| AC-5.1 | `sittings_spec` "ends the sitting with its condition…" |
| AC-5.2 | `sittings_spec` "shows the control on the summary after Done…"; system "…ends with the control on Not specified" |
| AC-5.3 | `spec/models/collection_import/apply_spec.rb` "clears the lists that point at lots when the apply writes" (the sitting holds a condition and a place) |
| AC-6.1 | `spec/migrations/add_condition_to_scanner_sittings_spec.rb` "keeps every sitting, its place and every entry going down and up…", which also checks foreign keys and indexes after the rollback's table copy |
| AC-6.2 | same file, "goes down while a sitting holds a condition…" |
| AC-7.1 | `sittings_spec` markup examples (fieldset, legend, labels); system keyboard example and the fit examples at 360px (long location name) and desktop; screenshots below |
| FR-1 | `.choose!` examples; the redraw after an add, an Undo and "Set" in `sitting_entries_spec` and `sittings_spec` |
| FR-2 | `.add!` condition examples; `sitting_entries_spec` condition describe |
| FR-3 | `spec/scanner_sitting_core_spec.rb`; the export diff above; `spec/export_format_document_spec.rb` green with no Coverage change |
| NFR cost per account | one nullable column (migration); `sittings_spec` "adds no query per entry to the page" |
| NFR Security | refusal, 400, tenant and signed-out examples in `sittings_spec`; Brakeman clean |
| NFR Migration | the migration spec; `ruby script/upgrade/guard.rb`; CI's `bin/upgrade-smoke` runs in the image job |
| NFR Design system | markup examples; the fit examples; `Scanner.md` read below |

## Documents, checked by reading

- **`docs/design-system/components/Scanner.md`** describes:
  - the one control for every collector: the legend "This sitting's cards", Condition, then Location only with locations, then "Set";
  - the "Cards you scan now: …" copy in the panel and the status line, and that the status line is cleared;
  - the condition in the notice, the heading and the entry line;
  - the unchanged Undo and accessible names;
  - the summary's control;
  - the one CSS rule `.c-scanner__place .c-choices { min-width: 0; }` and why it exists. A fieldset is as wide as its widest child by default, and at 360px a long location name made the panel 419px wide. This is the plan's fallback P1, added in Task 6.
- **`docs/architecture/collection-and-lots.md`** covers:
  - the scope line;
  - the merge invariant, including the unknown-condition refusal;
  - "Only some ways of adding choose a place", with spec 042 superseding spec 040 decision 4's "condition (none)";
  - a Sources bullet for spec 042, and #57 in the issues.
- **`docs/architecture/data-portability.md`** puts the sitting's condition in the working-state invariant and its summary line, and adds a Sources bullet. The distillation-log rows wait for the pull request number (`distill-feature`).
- **`docs/roadmap.md`** has item 21a's order sentence amended ("only 21c keeps the order"), and item 21b built, with decision 1's ruling.
- **`docs/specs/README.md`** has the 042 row, and the supersessions are recorded both ways in rows 009, 040 and 042. Specs 009 and 040 are not edited.

## Screenshots

Taken with headless Firefox from a throwaway system spec that was deleted afterwards. The data is factories: one collector, Lightning Bolt (MOM · 123) and two locations. The sitting holds Near mint and Blue binder, with a Foil add and a Nonfoil add. The camera stage shows the specs' fake video, which is solid green. The 390px shots come from a 390px iframe opened on `/collection`, because the scanner sends `frame-src 'none'`.

- `screenshots/sitting-panel-desktop-light.jpg`, `screenshots/sitting-panel-desktop-dark.jpg`: the panel at desktop width. The heading is "This sitting: 2 cards, Near mint, in Blue binder", with the two fields and the entries "… · Foil · NM · in Blue binder · …".
- `screenshots/sitting-panel-390-light.jpg`, `screenshots/sitting-panel-390-dark.jpg`: the same panel at 390px.
- `screenshots/control-no-locations-desktop-light.jpg`, `screenshots/control-no-locations-desktop-dark.jpg`, `screenshots/control-no-locations-390-light.jpg`, `screenshots/control-no-locations-390-dark.jpg`: an account with no locations, before the first add. The legend, Condition on "Not specified" and "Set" show, with no Location select.

## Deviations from the plan

- **Task 6:** the plan's fallback P1, a single CSS rule (see Scanner.md above).
- **Task 4:** `.rubocop.yml` excludes `spec/scanner_sitting_core_spec.rb` from `RSpec/DescribeClass`, as it does for `spec/number_entry_core_spec.rb`, and the comment above the list names it.
- **Tasks 1, 2, 6 and 7:** `:aggregate_failures` was added to examples with several expectations (the project convention, enforced by RuboCop).
- **Task 6:** a `let` became a `def` because of RuboCop's MemoizedHelpers limit.
