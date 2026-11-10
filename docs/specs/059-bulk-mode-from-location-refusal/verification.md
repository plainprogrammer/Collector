# Verification: spec 059

Evidence for each criterion of [spec 059](spec.md) (0.2.0), on branch `059-bulk-mode-from-location-refusal`. Request examples are in `spec/requests/location_bulk_shortcut_spec.rb` (the "request file" below), browser examples in `spec/system/location_bulk_shortcut_spec.rb` (the "system file"), the model's in `spec/models/bulk_selection_spec.rb`. Documents are verified by reading, not by RSpec (`.claude/rules/testing.md`).

## Evidence per criterion

| Criterion | Evidence |
|-----------|----------|
| AC-1.1 button first, no Remove | Request file, "is first in the actions row, before Back to locations, with no Remove button (AC-1.1)": the actions row's children read "Move them in bulk mode from “Blue binder”" then "Back to locations"; the button is `c-btn c-btn--primary` with the ` from “Blue binder”` tail in a `c-sr` span; no control reads "Remove". `spec/system/locations_spec.rb` "refuses a location that holds lots without scrolling sideways, with 44px targets and the keyboard" now expects the one button, "Move them in bulk mode from “Blue binder”", and no other (spec 032 AC-5.2's "no Remove") |
| AC-1.2 refused `DELETE` | Request file, "is on the refusal page a refused DELETE renders (AC-1.2)": 409 and the shortcut's form is present |
| AC-1.3 empty location | Request file, "is not on an empty location's confirmation page (AC-1.3)": the only form button is "Remove" |
| AC-1.4 post form, button, token only | Request file, "is a post form with a button and no field but the token (AC-1.4)": `method="post"`, one `button`, no input but `authenticity_token`, and no link to the path |
| AC-1.5 page otherwise unchanged | Request file, "keeps the sentence, the list and Back to locations as they were (AC-1.5)" |
| AC-2.1 303 and the filtered table | Request file, "answers 303 to the bulk table under the location, with every lot selected (AC-2.1, AC-2.2)": 303 to `collection_path(bulk: 1, location:)`, the two lots of the location only, the Location select showing it, count line "12 of 40 items" |
| AC-2.2 every row ticked | Same example: both rows `aria-selected`, header `all` checked, bar "All 12 items selected"; the system file's first example reads "All 5 items selected" and two selected rows in a browser |
| AC-2.3 bar and Move to… | Request file, "offers the bulk actions and opens Move to… for every copy, without the location as a destination (AC-2.3)": the bar's extra buttons are "Set condition…", "Move to…", "Remove"; the move page is "Move 12 items" and its To options are "Choose…", "No location", "Long box". The PATCH that presses "Move to…" is built from the rendered table's own fields with nothing touched (header state, shown, baseline and ticked ids, as the browser sends them), so it holds only if the shortcut stored every lot as selected: with `all: false` temporarily in `Locations::SelectionsController`, the example fails (422 instead of the redirect). System file, "empties a location from its refusal page through Move to… and on to its removal (AC-3.1, AC-2.2, AC-2.3)" presses "Move to…" with nothing ticked first |
| AC-2.4 replaces a stored selection | Request file, "replaces the stored selection, its ticks included (AC-2.4)": a selection under another name filter, location and sort with one mark becomes `""`, the location, the default sort key, `all_matching` and no marks, in the account's one row. Model: `spec/models/bulk_selection_spec.rb` "replaces earlier ticks and marks" |
| AC-2.5 undo kept | Request file, "leaves an undoable bulk removal undoable (AC-2.5)" |
| AC-2.6 emptied meanwhile | Request file, "lands on the empty-filter table when the location was emptied meanwhile (AC-2.6)" ("No cards in your collection are in “Blue binder”.", "0 of 0 selected", no header checkbox) and "lands on the empty collection's page when no lot is left at all (AC-2.6)" |
| AC-2.6a removed after the 303 | Request file, "reads a location removed after the redirect as all locations, nothing selected (AC-2.6a)": 200, the whole collection, no selected row |
| AC-2.7 Done | Request file, "returns to the saved view under the location on Done (AC-2.7)": redirect to `collection_path(location:)`, no selection left |
| AC-3.1 end to end | System file, "empties a location from its refusal page through Move to… and on to its removal (AC-3.1, AC-2.2, AC-2.3)", one example: locations page, Remove, the shortcut, Move to…, "Long box", Move, the notice "Moved 5 items to Long box." and no lot left in the location; then the locations page again, Remove, "Remove Blue binder?", Remove, and the notice "Removed “Blue binder”." |
| AC-4.1 another account's location | Request file, "answers 404 for another account's location and changes nothing (AC-4.1)": the account's stored selection attributes are equal before and after, and the other account has none |
| AC-4.2 no such location | Request file, "answers 404 for a location that doesn't exist (AC-4.2)" |
| AC-4.3 nothing read | Request file, "ignores a name filter, location, sort, account or user value in the request (AC-4.3)": `q`, `location`, `sort`, `dir`, `account_id`, `user_id`, `admin` sent; the selection holds the path's location, an empty filter and the default sort, under the signed-in account |
| AC-4.4 signed out | Request file, "sends a signed-out visitor to sign-in and creates nothing (AC-4.4)" |
| AC-4.5 no GET | Request file, "answers no GET, prefetch-marked or not, and changes nothing (AC-4.5)": 404 both ways, no selection created |
| AC-5.1 no scripting | By construction and reading: the shortcut is a plain `button_to` form (AC-1.4's example) and every request example above is the POST a browser without scripting sends; no part of the page's behaviour is in a Stimulus controller (`app/views/locations/removals/refused.html.erb`, `app/controllers/locations/selections_controller.rb`). No example runs a browser with scripting off |
| AC-5.2 360px, 44px, themes | System file, "fits at 360px in both themes with 44px targets and the button first (AC-5.2)": see "Measured" below. The example's light/dark loop checks layout in both themes (no overflow, 44px targets, button order), not colour. Text contrast and focus-ring contrast were checked by reading, not by an example: the button and its focus ring use the design system's tokens only (no new CSS), and the "after" screenshots show both themes |
| FR-1 route, one verb | AC-4.5's example; `config/routes.rb` has `resource :selection, only: :create, module: :locations` under `resources :locations` (one line) |
| FR-3 core names no collectible | `spec/import_apply_core_spec.rb` lists `app/controllers/locations/selections_controller.rb` (the view `refused.html.erb` was already listed) |
| Performance NFR | Request file, "costs a number of statements independent of the lots it selects (Performance NFR)": the same statement count with 2 lots and with 32 |
| Accessibility NFR | The accessible name is AC-1.1's example; the keyboard check is below |
| Security, Reliability NFRs | AC-4.1 to AC-4.4 (404, sign-in, nothing read; CSRF stays on, the forms carry the token, AC-1.4); AC-2.6 and AC-2.6a (no 500) |
| `BulkSelection#restart!(all:)` | Model, `#restart! with all: true (spec 059 decision 3)`: "selects every matching lot of the location in the restart's own write, with no exceptions", "replaces earlier ticks and marks", and "leaves the default restart selecting nothing (Edit many)" |

## Measured

`script/worktree/with_mise bin/rspec spec/system/location_bulk_shortcut_spec.rb` (seed 12032): **3 examples, 0 failures**, 3.85 s. The AC-5.2 example opens the refusal page in a 360px frame (headless Firefox won't go below 500px, so a fixed-width same-origin frame, see `.claude/memory/headless-firefox-narrow-frame.md`), in light and then dark, and finds: frame width 360 and no horizontal overflow (`scrollWidth <= innerWidth`), no link or button of `main` under 44px in height or width (the list of small targets is empty), and the actions row's first child reading "Move them in bulk mode". In the screenshot run on the dev server (2026-11-10), the frame measured a content height of 816px for both the refusal page and the bulk table, with no sideways overflow in either theme.

## Keyboard check

System file, "works with the keyboard alone: tab to the button and press enter (Accessibility NFR)": Tab reaches the button whose text includes "Move them in bulk mode" (`tab_to_text`, `spec/support/keyboard_helpers.rb`, moved out of `locations_spec.rb` so both files use it); the focused element matches `:focus-visible` with a non-zero outline; Enter opens the bulk table and the bar reads "All 4 items selected".

## Screenshots

`screenshots/`: the dev server on port 3761, one account (`Blue binder` with 12 copies in 3 lots, `Long box`, three more lots elsewhere, 21 copies in all), placeholder printings with no card art. The "after" bulk table shots come from pressing the button in the browser (the URL was `/collection?bulk=1&location=<id>`); the phone shots are from a 360px frame. Every shot was looked at for its content and theme. The "before" shots are of the code before Phase 2 (no button).

| Page | Desktop light | Desktop dark | Phone (360px) light | Phone (360px) dark |
|------|---------------|--------------|---------------------|--------------------|
| Refusal page, before | [before-refusal-desktop-light.jpg](screenshots/before-refusal-desktop-light.jpg) | [before-refusal-desktop-dark.jpg](screenshots/before-refusal-desktop-dark.jpg) | [before-refusal-phone-light.jpg](screenshots/before-refusal-phone-light.jpg) | [before-refusal-phone-dark.jpg](screenshots/before-refusal-phone-dark.jpg) |
| Refusal page, after | [after-refusal-desktop-light.jpg](screenshots/after-refusal-desktop-light.jpg) | [after-refusal-desktop-dark.jpg](screenshots/after-refusal-desktop-dark.jpg) | [after-refusal-phone-light.jpg](screenshots/after-refusal-phone-light.jpg) | [after-refusal-phone-dark.jpg](screenshots/after-refusal-phone-dark.jpg) |
| Bulk table it opens, after | [after-bulk-table-desktop-light.jpg](screenshots/after-bulk-table-desktop-light.jpg) | [after-bulk-table-desktop-dark.jpg](screenshots/after-bulk-table-desktop-dark.jpg) | [after-bulk-table-phone-light.jpg](screenshots/after-bulk-table-phone-light.jpg) | [after-bulk-table-phone-dark.jpg](screenshots/after-bulk-table-phone-dark.jpg) |

What they show: on desktop the primary "Move them in bulk mode" sits left of the secondary "Back to locations" under the lot list; on the phone the two stack, each a full-height button; the bulk table has the Location filter on "Blue binder", the count line "12 of 21 items", the bar "All 12 items selected" with "Set condition…", "Move to…", "Remove" and "Done" (on the phone, behind "…" and "Done"), the three lots ticked and the header ticked. The seed is left in the worktree's development database (user `shots059@example.test`).

## Rulings of the decisions

1. **Every matching lot is selected:** ruled by the maintainer on 2026-11-10 (Gate A) as recommended; built as `restart!(all: true)`, so the bar reads "All 12 items selected".
2. **Label "Move them in bulk mode":** ruled by the maintainer on 2026-11-10, kept at Gate A; built with the `c-sr` tail, `c-btn--primary`, first in the row.
3. **A fresh selection, as `Edit many`:** built on `BulkSelection#restart!` in its one transaction, `all:` false by default so `Edit many` and every other caller are unchanged (AC-2.4, the model's third example).
4. **The landing page is bulk mode as it is:** no change to the collection page, the bar or the table (AC-2.1 to AC-2.3, AC-2.6, AC-2.6a).
5. **Both ways to the refusal page get the button:** `GET .../removal/new` and the 409 render the one view (AC-1.1, AC-1.2); the locations list has none (request file, "is not on the locations list (decision 5)").
6. **No collector-owned data, no export change:** the branch holds no migration, no schema, no export or import file and no format document change (`git diff main --stat`).

## Deviations from the plan

None in this phase. The documents changed are those the plan's Phase 3 lists, plus the spec's number in the specs list of CLAUDE.md's "Collection and lots" bullet (059 added to "specs 004, 006, … 041"). The Distillation log row of the area doc is left to `distill-feature`.

## Implementation review

SPEC-ALIGNED WITH FINDINGS (round 1, read-only Opus, `sdd-review` Mode B, over `a29c5987..83ad6de0`): 0 blocking, 1 major, 6 minor, none a defect in the code.

The code matches every FR, decision and non-goal: the controller reads only the path's location id through `Current.account.locations`; the route has no GET; the other `restart!` callers don't pass `all:` and keep `all_matching: false`; the button follows the design system; the supersessions are in the index, both directions, with specs 006, 032 and 041 untouched.

| # | Finding | Disposition |
|---|---------|-------------|
| 1 (major) | No fresh full-run evidence recorded | Closed by the full `bin/ci` run recorded under "Full run" below. |
| 2 | AC-3.1 not followed to the removal in one example | Taken (`1f20be42`): the first system example ends on the emptied location's removal; the redundant second example is gone. |
| 3 | The AC-2.3 request example passed even if nothing was selected | Taken (`6da1d8b2`): it sends the page's own untouched form, and fails with `all: false` in the controller (mutation checked). |
| 4 | Area doc's core-guard sentence omitted the shortcut's controller | Taken (`c9cccacc`). |
| 5 | #187 moved out of "open" in the area doc's Sources before the merge | Not changed: the roadmap says "done when its pull request merges", and the distillation step owns the area doc's Sources after it. |
| 6 | Shared `tab_to` lacked YARD tags and shares a name with `bulk_move_spec.rb`'s | Taken (`79faf576`): renamed `tab_to_text`, documented. |
| 7 | AC-5.2's theme loop measures nothing theme-dependent | Taken (`c9cccacc`): "Measured" says contrast was checked by reading and the screenshots. |

The fixes were minor and not sent for a second review round.

## Distillation

`distill-feature` (before the merge): the area doc `collection-and-lots.md` already carried the feature's rules, written with it (Phase 3), so the step added its Distillation log row (the pull request named "spec 059's pull request" until it has a number), set row 059 of the index to Frozen with its plan "retirement owed", and added the spec's `**Frozen:**` line. No other area has a doc that the spec touches (the design system's `Locations.md` was updated in Phase 2). No ADR is proposed: the decisions are spec-local. The plan is retired after the merge.
