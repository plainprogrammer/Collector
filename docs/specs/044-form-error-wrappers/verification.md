# Verification: Forms Re-rendered with 422 Get No `field_with_errors` Wrapper (spec 044)

**Spec:** [spec.md](spec.md) · **Plan:** [plan.md](plan.md) · **Branch:** `044-form-error-wrappers`

## Rulings

By the maintainer, 2026-11-06, with the spec's approval: decisions 1 and 4, option A (an app-wide `field_error_proc` that wraps nothing; the currency controller's `errors.clear` removed), recorded in [ADR 0026](../../adr/0026-forms-show-field-errors-through-the-design-system.md). The screenshot ruling of spec 0.4.0 (round 2 m3, option b): all 12 refused states at desktop in both themes, and phone in both themes for add a lot, add a location and sign up (30 images, decision 3, AC-2.1).

Deviations from the plan are recorded in the commit bodies. The capture script and the dev-data script live in the session scratchpad and are not committed (spec 038's precedent: images only).

## Evidence

| Criterion | Proved by |
|---|---|
| AC-1.1 | `spec/field_error_proc_spec.rb` (both examples, lines 33 and 39; red in task 1c, green after task 3's config line) |
| AC-1.2, 1.3 | `spec/requests/lots_spec.rb:70` "rejects invalid values with a message per field" and `:129` "rejects invalid values with 422 and leaves the lot unchanged" |
| AC-1.4 | `spec/requests/lot_moves_spec.rb:89` "answers 422 with the reasons beside Copies and To, keeping the choice…" and `:102` "refuses a move to where the lot already is (P4)" |
| AC-1.5, 1.6 | `spec/requests/locations_spec.rb:43` (add, 422 with the reason beside the field) and `:115` (rename to another's name) |
| AC-1.7 | `spec/requests/registrations_spec.rb:59` "shows each invalid field's message with 422" (each `#<field>-error` compared with its own message since `d1602f7`) |
| AC-1.8, 1.9 | `spec/requests/admin/users_spec.rb:53` "links an invalid email field to its message"; `:89` "refuses to delete yourself or demote the only admin" (status and `#admin-error` added) |
| AC-1.10 | `spec/requests/sessions_spec.rb:23` "rejects a wrong password without saying which field was wrong" (regression: no wrapper after a wrong password; green before the config line, as the test commit's body says) |
| AC-1.11 | `spec/requests/number_entries_spec.rb:307` "keeps the line when no entry has the number (AC-4.1)" (regression, same note) |
| AC-1.12 | `spec/requests/currencies_spec.rb:63` (the example at `:71` asserts no wrapper), kept; the controller no longer clears (task 2), and the example fails without the app's proc (task 2's red run, below) |
| AC-1.13 | each form's existing assertions, all green in the same runs |
| AC-2.1 | the 30 images below, each read by looking |
| AC-3.1 | `docs/design-system/components/Form.md`, the added bullet (by reading) |
| AC-3.2 | `docs/adr/0026-forms-show-field-errors-through-the-design-system.md` (by reading: Decision, Options considered, Consequences, Status) |

## Measured runs

Counts and reasons are from the runs' saved output (the raw files are in the session scratchpad: `red-task1.txt`, `red-task2.txt`, `green-task3.txt`).

- **Task 1c, red** (the new and extended examples, before any fix): 127 examples, 11 failures. Both `field_error_proc_spec.rb` examples failed (a `.field_with_errors` wrapper in the output, and the form's children being wrapped rather than `label input`), as did the wrapper assertions in the lots add and edit, Move copies (both examples), locations add and rename, sign-up and the two admin users examples. Every failure was `expect(….css(".field_with_errors")).to be_empty` (or the markup comparison) finding the Rails `div`. Sign-in and number entry were green, as expected: their forms have no record to wrap.
- **Task 2, red** (the currency controller's `errors.clear` removed, no app-wide proc yet): `bin/rspec spec/requests/currencies_spec.rb`, 7 examples, 1 failure: `currencies_spec.rb:63` (spec 038 AC-1.7's refused code), on the `.field_with_errors` assertion, four parts of the aggregate. This proves the example now exercises the app's proc and not the controller.
- **Task 3, green** (after the one config line): the nine spec files of the plan's final verification, 183 examples, 0 failures (seed 52051).

## Screenshots

**Dev data and its limits.** Captured against the worktree's own development server (`PORT=3153`, `bin/dev`) with a scratch seed: an admin (Ada Admin) and a plain user, one applied `Catalog::RefreshRun`, three printings in set `mh3` (Modern Horizons 3; numbers 138, 311 and 32), one lot of 4 copies of number 138 in the location "Long box", a second location "Blue binder", and sign-up opened. The printings have no card art, so tiles and card images show placeholders. Each refused state is the page's own 422, reached by submitting the real form after `form.noValidate = true` and `form.requestSubmit()` (native validation would stop four of them), with `data-theme` set from the file name before each save.

Capture notes that change what an image shows, none a defect of this spec:

- Edit a lot: the quantity was set to the text `lots` (the field's type was changed to `text` for the submit, since a number input refuses it), so the refused page shows an empty Quantity.
- Move copies (To): the lot's own place is not among the select's options (`set_destinations` drops it), so the script added an option with the lot's location id. The refused page re-renders the select without it and so shows "No location".
- Currency: the select's option value was set to `XYZ`; the refused page shows `USD — $` selected.
- Sign-in and sign-up keep no password, so those fields show empty.
- Phone images are 390 px wide element screenshots of a same-origin frame (sign-up in a signed-out session), 916 px tall.

In every image the theme is the one named, the page is the 422 (not the empty form), the label is above its control, the control is as wide as its siblings, and the message is under it. The one exception to "as wide as its siblings" is number entry, whose line is a row of fields by design (spec 026); its Number field is the narrow first column of that row, with its message under it.

| State | Desktop light | Desktop dark | Phone light | Phone dark | Reading |
|---|---|---|---|---|---|
| Add a lot (quantity 0) | [light](screenshots/lot-add-desktop-light.jpg) | [dark](screenshots/lot-add-desktop-dark.jpg) | [light](screenshots/lot-add-phone-light.jpg) | [dark](screenshots/lot-add-phone-dark.jpg) | Quantity label above a full-width field in the error colour, "Quantity must be a whole number from 1 to 9,999" under it; the other fields as wide. |
| Edit a lot (`lots`) | [light](screenshots/lot-edit-desktop-light.jpg) | [dark](screenshots/lot-edit-desktop-dark.jpg) | | | Same layout and message under an empty Quantity. |
| Move copies (9 of 4) | [light](screenshots/move-copies-desktop-light.jpg) | [dark](screenshots/move-copies-desktop-dark.jpg) | | | Copies field full width, "Choose from 1 to 4 copies." under it; To unchanged below. |
| Move copies (To = own place) | [light](screenshots/move-to-desktop-light.jpg) | [dark](screenshots/move-to-desktop-dark.jpg) | | | The To select full width in the error colour, "Those copies are already there." under it. |
| Add a location (blank) | [light](screenshots/location-add-desktop-light.jpg) | [dark](screenshots/location-add-desktop-dark.jpg) | [light](screenshots/location-add-phone-light.jpg) | [dark](screenshots/location-add-phone-dark.jpg) | Name field full width, "Give the location a name." under it, the list below. |
| Rename a location (duplicate) | [light](screenshots/location-rename-desktop-light.jpg) | [dark](screenshots/location-rename-desktop-dark.jpg) | | | Typed name kept, "You already have a location called “Long box”." under it. |
| Sign up (empty name, short password) | [light](screenshots/sign-up-desktop-light.jpg) | [dark](screenshots/sign-up-desktop-dark.jpg) | [light](screenshots/sign-up-phone-light.jpg) | [dark](screenshots/sign-up-phone-dark.jpg) | Name and Password in the error colour, each with its message under it; Email and Confirm password plain, all the same width. |
| Add a user (email `nope`) | [light](screenshots/user-add-desktop-light.jpg) | [dark](screenshots/user-add-desktop-dark.jpg) | | | Email field in the error colour, "Email must look like name@example.com" under it. |
| Edit a user (untick the only admin) | [light](screenshots/user-edit-desktop-light.jpg) | [dark](screenshots/user-edit-desktop-dark.jpg) | | | The Admin checkbox unticked, the "Admin can't be removed…" message under it. |
| Sign in (wrong password) | [light](screenshots/sign-in-desktop-light.jpg) | [dark](screenshots/sign-in-desktop-dark.jpg) | | | The "Email or password is incorrect." notice above, both fields plain and equal in width (no record, so no field errors). |
| Number entry (999) | [light](screenshots/number-entry-desktop-light.jpg) | [dark](screenshots/number-entry-desktop-dark.jpg) | | | The Number field focused (focus ring), "No card numbered 999 in Modern Horizons 3 (EN)." under it in the error colour; Quantity, Finish and Location in the same row. |
| Currency (`XYZ`) | [light](screenshots/currency-desktop-light.jpg) | [dark](screenshots/currency-desktop-dark.jpg) | | | The select full width (it narrowed under the wrapper in spec 038), the hint and "Choose one of the listed currencies." under it. |

## Full run

Full `bin/ci` (2026-11-06, on `75c5c2c`, the last code commit; the later commits are documents and images): every step passed, RSpec 2605 examples, 0 failures, 1 pending, 4 min 38 s.

## Implementation review

SPEC-ALIGNED (sdd-review Mode B, Opus, read-only, 2026-11-06): 0 blocking, 0 major, 4 minor; all 16 criteria met.

The reviewer re-ran the nine spec files green (183 examples, 0 failures) and, with `ActionView::Base.field_error_proc` set back to Rails' default in memory, red on exactly the 12 expected examples: the guard's two, the nine wrapped forms' and the currency example; sign-in and number entry stayed green. It found no file changed outside the plan's file map (no view, no CSS, no bulk-mode file), no `html_safe` or `raw`, and the screenshots matching their readings.

Minor findings and what was done:

1. `Gemfile.lock` has an uncommitted local change (darwin platform gems). Not reverted: it predates this branch and is the maintainer's to decide; it is never staged here.
2. Two evidence rows cited assertion lines, not example lines. Fixed above (sessions `:23`, number entry `:307`).
3. The number-entry reading said "selected in the error colour"; the image shows the focus ring. Fixed above.
4. The sign-up example checked only that each message element existed. Fixed in `d1602f7`: each `#<field>-error` is now compared with its own message (a deliberately wrong text failed at `registrations_spec.rb:68`, then 7 examples, 0 failures).

Outside this spec: on sign-up the hint and field errors render at the input's size, not Form's caption size; no view or CSS changed here, so it predates the branch. Filed as [#188](https://github.com/plainprogrammer/Collector/issues/188).

## Distillation

`distill-feature`, 2026-11-06, before the merge: spec 044's one area is the design system, which has no area doc under `docs/architecture/` (`docs/architecture/README.md`: spec 004's design-system part is covered by `docs/design-system/`). Its rule is already written where the next form's author reads it, the Form doc (`docs/design-system/components/Form.md`, AC-3.1) and [ADR 0026](../../adr/0026-forms-show-field-errors-through-the-design-system.md); no area doc changed, and the spec is not frozen. The index row reads "present; retirement owed", so the plan is retired after the merge. No supersessions (the spec's Supersedes table: none). CLAUDE.md restates nothing this feature changed.
