# Verification: Spec 040, Scan a Sitting into a Location

Spec 0.2.2; plan approved 2026-11-03. Evidence for every acceptance criterion, requirement and document change. Spec paths: `M` = `spec/migrations/add_location_to_scanner_sittings_spec.rb`, `S` = `spec/models/scanner/sitting_spec.rb`, `R` = `spec/requests/scanner/sittings_spec.rb`, `E` = `spec/requests/scanner/sitting_entries_spec.rb`, `Y` = `spec/system/scanner_sitting_spec.rb` (headless Firefox), `A` = `spec/models/collection_import/apply_spec.rb`.

Whole suite at `7a6256a` (Phase 5): 2467 examples, 0 failures, 1 pending (the art agreement example that needs the spike's cache). `bin/ci` passed in full as the pre-push hook at `d259770`; its first run had failed one example, `Upgrade::Harness removes its temporary directory`, because the spec 039 worker's suite in another worktree made an `upgrade-smoke*` folder in the shared temp directory during the check (#178; the example passes alone).

## Acceptance criteria

| AC | Evidence |
|---|---|
| AC-1.1 | R:146 (control alone, "No location" first and selected, locations in `/locations` order, no heading or Done); Y:59 |
| AC-1.2 | S:136; R:165 (Turbo Stream replaces only `#scanner_sitting` and `#status`, never `#scanner_result`); R:197 (heading ", in Blue binder", "Cards you scan now go into Blue binder.", all-undone copy kept); Y:59 (page and camera stay: the window mark survives, the video is still there) |
| AC-1.3 | S:86; E:86 (notice "… in Blue binder to your collection."); R:183 (entry line); Y:71 |
| AC-1.4 | S:95 |
| AC-1.5 | E:94; S:17 and spec 009's existing add examples (unchanged) |
| AC-1.6 | S:110 (refused in Blue binder, nothing recorded; added in Long box); E:102 (the existing "full" message) |
| AC-1.7 | R:217; Y:84 |
| AC-1.8 | S:150, S:157 (none added and all undone; `place!` runs the check and the delete in one transaction); R:223; Y:84 |
| AC-2.1 | S:142; R:175; Y:71 |
| AC-2.2 | R:281 (Undo of an add made into Blue binder after the place changed takes its copy from Blue binder, and the lot goes) |
| AC-2.3 | R:183 (a moved lot names its new place; a removed lot's entry says "Changed" and names none) |
| AC-3.1 | R:159 (`#scanner_sitting[hidden]`, no control); spec 009's existing examples unchanged |
| AC-3.2 | S:103 (add after the place's location went: unplaced); E:119 (notice names no place; redrawn panel has no select); R:291 (entry-less placed sitting dropped on the next render, `#scanner_sitting[hidden]`, P1 as ruled); R:300 (all-undone sitting stays: "This sitting: 0 cards", Done, no select); A:318–326 (an import apply that removes only a location clears the place and keeps the sitting); M:70 (the foreign key) |
| AC-3.3 | R:239 (`sitting` with no `location_id`, and no `sitting` at all: 400, place unchanged); R:223 ("No location" as a present blank value) |
| AC-4.1 | R:248 (another account's id, a removed id, `abc`, `<id>abc`: 422, the decision 7 alert, panel as stored); R:260 (no sitting opened) |
| AC-4.2 | R:266 |
| AC-4.3 | S:119; E:110 (the replay names the entry's lot's place, Blue binder, while the sitting is in Long box) |
| AC-5.1 | R:310 (copies stay in Blue binder; sitting gone; summary counts) |
| AC-5.2 | R:310 (summary plus the control on "No location"; choosing a place replaces the summary); R:323 (no control without locations); Y:84 |
| AC-5.3 | A:148 (a placed sitting is destroyed by an apply that writes a lot) |
| AC-6.0 | M:45 (down then up: every sitting and entry row unchanged, every place nil); M:41 (no transaction); M:60 (down with a placed sitting); M:78 (a run stopped between steps finishes) |
| AC-7.1 | `app/views/scanners/_picker.html.erb` (native select with a `<label for>`, submit button, no script); Y:99 (Tab from the select reaches "Set", Enter submits); Y:109 (360px frame, long location name, no sideways scroll); screenshots below |

## Requirements

- **FR-1:** place stored on the sitting (M:45); read on every add inside its transaction (S:103); resolved through `Current.account.locations` (R:248); opens (S:136), deletes (S:157); panel redrawn after add (E:86), Undo (R:281) and change (R:165); entries' lots and locations preloaded (S:201, at most 5 queries for 3 entries in 2 places); same `find_or_create_by!` as an add on the unique `account_id` index (S:142). Must-nots: another account's locations never listed (`sitting_locals` reads `Current.account.locations`), R:266, no location created, no lot's other values changed (S:86).
- **FR-2:** `Lot.add!(location: sitting.location)` in the transaction that records the entry (`app/models/scanner/sitting.rb`); nothing recorded on failure (S:110).
- **FR-3:** `git grep -i 'mtg\|scryfall'` over the picker, the sittings controller and the concern is empty; `git diff origin/main -- docs/export-format lib/export_format app/models/export* app/models/collection_export*` is empty.

## Non-functional requirements

- **Migration:** raw `ADD COLUMN … REFERENCES locations (id) ON DELETE SET NULL`, `disable_ddl_transaction!`, guarded steps; `db/schema.rb` changes only the version, the column, its index and the foreign key; `ruby script/upgrade/guard.rb` passes. The upgrade proof (`bin/upgrade-smoke`) runs in CI's image job.
- **Security:** `params.expect(sitting: :location_id)`; Brakeman clean; R:248 and R:266.
- **Cost:** one nullable integer column on a row an account has at most one of; locations load once per request; no background work.
- **Design system:** the stacked `Form` (`c-form`, `c-field`, `c-form__actions`) with no new component (plan P2 ruled in Phase 4). Phase 5's 360px example found two overflows, fixed in `collector/additions.css`: the sitting's heading now wraps (as `.c-panel`'s title does) and `.c-field select` no longer grows past its form with a long option. `docs/design-system/components/Scanner.md` describes the control and the copy.

## Documents (verified by reading)

- `docs/architecture/collection-and-lots.md`: the scanner neighbour line, "Only some ways of adding choose a place", the removing-a-location rule (sitting's place cleared), the #56 open item removed, spec 040 in Sources.
- `docs/roadmap.md`: item 21a built, and that it ran before the spikes by ruling (decision 1).
- `docs/specs/README.md`: the 009 and 032 rows name 040 under "Superseded by"; the 040 row names 009 and 032. Specs 009 and 032 are not edited.
- `docs/architecture/data-portability.md`: checked, no change (the sitting stays left out; the export, its version and coverage are unchanged).

## Screenshots

Taken with headless Firefox against the worktree's dev server, whose empty database was seeded by a scratch script (one collector, three printings, two locations; tiles show placeholders, not art). The add uses a picked photo (the specs' synthetic card), as there is no camera headless. The 390px shots come from a 390px iframe on `/collection`, as the scanner sends `frame-src 'none'`.

- `screenshots/sitting-into-location.gif`: choose Blue binder, pick a photo, add the Foil copy, see the lot in Blue binder in the collection.
- `screenshots/sitting-panel-390-light.jpg`, `screenshots/sitting-panel-390-dark.jpg`: the panel at 390px.
- `screenshots/sitting-panel-desktop-light.jpg`, `screenshots/sitting-panel-desktop-dark.jpg`: the panel at desktop width.
- `screenshots/collection-lot-in-blue-binder.jpg`: the added lot's tile names Blue binder.

## Implementation review

SPEC-ALIGNED (sdd-review Mode B, read-only, Opus, 2026-11-06, on `d259770`; findings handled at the commit that adds this section).

The reviewer's coverage matrix matched the table above: every AC, FR and NFR covered. It flagged AC-4.1's alert class as asserted by text only, and AC-7.1's Space key and screen reader as confirmed by reading only. It found no drift: the field name `sitting[location_id]`, the "Nothing added yet." copy and the status messages are the plan's; 400 and 422 match the spec; P1 is the narrower rule; strict locals hold in every partial, including measurement mode's.

| Finding | Severity | Handled |
|---|---|---|
| `verification.md` missing | major | Written (this file) |
| Dropping an empty sitting on render checked and deleted outside one transaction; an add from another tab in between would lose its entry | minor | Fixed, tests first: `Scanner::Sitting#drop_if_pointless!` reloads, checks and deletes in one write transaction (S `#drop_if_pointless!`, including a sitting placed since it was loaded) |
| Measurement mode skipped the drop | minor | Fixed: `current_sitting` moved into `ScannerSitting`, used by both pages (`spec/requests/scanner/measurements_spec.rb`, "drops a sitting with no entries and no place") |
| No test that another account's locations stay out of the select (FR-1) | minor | Added to R's AC-1.1 example (the exact options list, with another account's location present) |
| `.c-field select`'s width rule is app-wide but undocumented | minor | `docs/design-system/components/Form.md` says a select never widens past its form |
| Focus drops to the body after Set; clearing that deletes the sitting empties `#status`; the picker-only section has no name | minor | Kept: focus after a panel redraw is spec 009's Undo pattern, and the plan rules no message when clearing deletes the sitting |
| `place!` inserts then updates when it opens a sitting | nit | Kept: correct under the unique account index, and the row is written once per choice |

## Distillation

2026-11-06, before the merge (`distill-feature`): `collection-and-lots.md` holds decisions 2, 4 and 7 as they touch lots and locations (the scanner adds into its sitting's place; removing a location clears a sitting's place; the #56 open item closed); `data-portability.md` holds decision 5, AC-5.3 and AC-3.2's import case (the sitting's place is working state). The index marks 040 Frozen in part, plan retirement owed; the spec carries its frozen line. The scanner has no area doc, so the sitting's own rules (the control, the copy, P1's drop) stay in this spec until one is written. No ADR proposed: the place follows ADR 0025 and spec 032's migration pattern.
