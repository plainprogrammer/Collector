# Verification: spec 067

Evidence for each criterion of [spec 067](spec.md) (0.2.0), on branch `067-deck-refusal-bulk-mode`. Request examples are in `spec/requests/deck_bulk_shortcut_spec.rb` (the "request file" below, 25 examples) and `spec/requests/decks_spec.rb` (AC-1.1 and AC-3.3 of spec 062 as changed), browser examples in `spec/system/deck_bulk_shortcut_spec.rb` (the "system file", 4 examples). Documents are verified by reading, not by RSpec (`.claude/rules/testing.md`).

## Evidence per criterion

| Criterion | Evidence |
|-----------|----------|
| AC-1.1 button first, no Remove | Request file, "is first in the actions row, before Back to decks, with no Remove button (AC-1.1)"; `spec/system/decks_spec.rb`'s 360px refusal example now expects the button and no control starting with "Remove" |
| AC-1.2 refused `DELETE` | Request file, "is on the refusal page a refused DELETE renders (AC-1.2)" |
| AC-1.3 empty deck | Request file, "is not on an empty deck's confirmation page (AC-1.3)" |
| AC-1.4 post form, button, token only | Request file, "is a post form with a button and no field but the token (AC-1.4)"; the accessible name is checked in the AC-1.1 example |
| AC-1.5 page otherwise unchanged | Request file, "keeps the sentence, the list and Back to decks as they were (AC-1.5)"; `spec/requests/decks_spec.rb`'s AC-3.3 example (changed, see below) |
| AC-1.6 place refusal page | Request file, "leaves a place's refusal page as spec 059 defines it (AC-1.6)" |
| AC-2.1 303 and the filtered table | Request file, "answers 303 to the bulk table under the deck, with every lot selected (AC-2.1, AC-2.2)" |
| AC-2.2 every row ticked | Same example; the system file's first example reads "All 5 items selected" and two selected rows in a browser |
| AC-2.3 bar and Move to… | Request file, "offers the bulk actions and opens Move to… for every copy, with no destination left out (AC-2.3)" |
| AC-2.4 replaces a stored selection | Request file, "replaces the stored selection, its ticks included (AC-2.4)" |
| AC-2.5 undo kept | Request file, "leaves an undoable bulk removal undoable (AC-2.5)" |
| AC-2.6 emptied meanwhile | Request file, "lands on the empty-filter table when the deck was emptied meanwhile (AC-2.6)" and "lands on the empty collection's page when no lot is left at all (AC-2.6)" |
| AC-2.7 removed after the 303 | Request file, "reads a deck removed after the redirect as all locations, nothing selected (AC-2.7)" |
| AC-2.8 Done | Request file, "returns to the saved view under the deck on Done (AC-2.8)" |
| AC-2.9 bulk actions | Request file, "using the bulk actions on it (AC-2.9)": Set condition, Move to… and Remove change exactly the deck's lots, each lot keeping its zone unless moved |
| AC-3.1 end to end | System file, "without scripting", "empties a deck from its refusal page through Move to… and on to its removal (AC-5.1, AC-3.1)", under `rack_test` (the example asserts `page.driver` is `Capybara::RackTest::Driver`): Decks page, Remove, the shortcut, "All 5 items selected", Move to…, "Long box", Move, the notice, the empty-filter sentence and "0 of 0 selected", then the removal page and the notice "Removed “Izzet Tempo”." The "with scripting" context runs the same scenario in headless Firefox |
| AC-4.1 another account's deck | Request file, "answers 404 for another account's deck and changes nothing (AC-4.1)" |
| AC-4.2 place, zone, no such id | Request file, "answers 404 for a place's id, a zone's id and an id that doesn't exist, and creates nothing (AC-4.2)" |
| AC-4.3 nothing read | Request file, "ignores a name filter, location, sort, account or user value in the request (AC-4.3)" |
| AC-4.4 signed out | Request file, "sends a signed-out visitor to sign-in and creates nothing (AC-4.4)" |
| AC-4.5 no GET | Request file, "answers no GET, prefetch-marked or not, and changes nothing (AC-4.5)" |
| AC-4.6 place route unchanged | Request file, "keeps the place shortcut's 404 for a deck's and a zone's id, and its answer for a place (AC-4.6)" |
| AC-5.1 no scripting | The same "without scripting" example: the whole scenario, from the Decks page to the removal, runs with no script |
| AC-5.2 360px, 44px, themes | System file, "fits at 360px in both themes with 44px targets and the button first (AC-5.2)": frame width 360, no horizontal overflow, no `main` link or button under 44px, the button first in `.c-form__actions`, in light and in dark. Colour is not an example: text and focus-ring contrast were checked by reading, since the button is `c-btn c-btn--primary` and the page adds no CSS (see below) |
| FR-1 route, one verb | AC-4.5's example; `config/routes.rb` has `resource :selection, only: :create, module: :decks` under `resources :decks` with a comment citing spec 067 |
| FR-3 core names no collectible | `spec/import_apply_core_spec.rb` lists `app/controllers/concerns/bulk_mode_shortcut.rb`; `spec/deck_core_spec.rb`'s count is 27 and its glob covers `app/controllers/decks/selections_controller.rb`; both pass |
| Decision 3 one shared definition | `BulkModeShortcut#open_in_bulk_mode` is called by `Locations::SelectionsController` and `Decks::SelectionsController`; the place shortcut's request and model specs are unchanged and pass |
| Performance NFR | Request file, "costs a number of statements independent of the lots it selects (Performance NFR)" |
| Accessibility NFR | The accessible name (AC-1.1's example) and the system file's keyboard example: tab to the button, a visible focus ring, enter, "All 4 items selected" |
| Security, Reliability NFRs | AC-4.1 to AC-4.4 (404, sign-in, nothing read; the form carries the CSRF token, AC-1.4); AC-2.6 and AC-2.7 (no 500) |

## Guards changed first (spec Notes for the plan)

Each was changed before the code and failed against the old code: `spec/requests/decks_spec.rb`'s AC-3.3 example (red: no button, no form), `spec/system/decks_spec.rb`'s 360px refusal example (red: "expected to find css main button"), `spec/import_apply_core_spec.rb` (red: the listed concern file didn't exist). `spec/deck_core_spec.rb`'s count went from `20 + 6` to `20 + 6 + 1` with the controller. `spec/requests/locations*` examples of spec 062 AC-3.8 are untouched and pass.

## Contrast and focus ring (AC-5.2, by reading)

The deck refusal page adds no colour, spacing or font: the button is `c-btn c-btn--primary` inside the existing `c-form__actions` row, the same markup the place refusal page uses (spec 059), and its hidden tail is `c-sr`. The design system's tokens set the button's text, background and focus-ring contrast in both themes; nothing here overrides them. `docs/design-system/components/DecksIndex.md` shows the new row.

## Measured

- Red run, Task 1: `bin/rspec spec/requests/deck_bulk_shortcut_spec.rb spec/requests/decks_spec.rb`: 66 examples, 21 failures (20 `NoMethodError: undefined method 'deck_selection_path'`, the changed AC-3.3 example on its button expectation); the examples for AC-1.3, 1.5, 1.6, 4.5 and 4.6 already passed, as planned.
- Green, Task 3: the request files, `spec/deck_core_spec.rb`, `spec/import_apply_core_spec.rb`, `spec/system/decks_spec.rb` and `spec/requests/location_bulk_shortcut_spec.rb`: 108 examples, 0 failures.
- System file: `bin/rspec spec/system/deck_bulk_shortcut_spec.rb`: 4 examples, 0 failures (re-run after the review's fix, with the guards and the place shortcut's request spec: 33 examples, 0 failures). With the view's `button_to` line temporarily deleted, all 4 failed.
- Full `bin/ci` on `8b6148cc`: RuboCop, YARD (no warnings), the comment ratchet, Brakeman, bundler-audit, importmap audit and RSpec all passed; RSpec was **3807 examples, 0 failures, 1 pending** (seed 16693), CI total 5 m 56 s.

## Deviations

1. The system file is one top-level `RSpec.describe` with two contexts (`RSpec/MultipleDescribes` rejects the plan's two top-level groups). The no-script context signs in under `rack_test`.
2. `spec/support/system.rb`'s after-hook resized the window with every driver; under `rack_test` that raised `Capybara::NotSupportedByDriverError`, so the resize is skipped for non-Selenium drivers (one line and a comment).
3. The plan's Step 0 regex was written `/\ARemove/` in Ruby (the plan's `/\\ARemove/` was a Markdown escape).
4. Commit trailers name Claude Opus 5.5, as the brief says.
