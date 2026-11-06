# Plan: Spec 044, Forms Re-rendered with 422 Get No `field_with_errors` Wrapper

**Spec:** [spec.md](spec.md) 0.4.0 (approved 2026-11-06)
**ADR:** [0026](../../adr/0026-forms-show-field-errors-through-the-design-system.md), already written and indexed (AC-3.2 is met by it; nothing to add)
**Issue:** [#180](https://github.com/plainprogrammer/Collector/issues/180)

## Goal

Set `config.action_view.field_error_proc` to return the tag unchanged, so no refused form renders `<div class="field_with_errors">`. Prove it with a guard that renders through Rails' own form-builder path and with an assertion in each form's existing 422 example. Remove spec 038's now-pointless `errors.clear`. Write the rule in the design system's Form doc. Check each refused state by eye in screenshots.

## Global Constraints

- Tests first: each task writes its failing assertion, states which examples are red today and why, then makes the change. Where an example passes today it is a regression example, and the plan says so.
- No view, helper, controller (other than `CurrenciesController`), model, stylesheet or spec outside those named here changes. No CSS is added (spec Non-Goals). Bulk-mode views and spec 041's areas are untouched.
- No area doc under `docs/architecture/` changes (spec decision 5). `CLAUDE.md` does not change.
- Specs tag their type explicitly (`type: :request`); multi-expectation examples use `:aggregate_failures`. Request specs read the page with Nokogiri: each file has its own `def html = Nokogiri::HTML5(response.body)` (lot moves, locations, currencies) or writes `Nokogiri::HTML5(response.body)` inline (lots, registrations, sessions, admin users, number entries). Follow each file's own style; do not add a shared helper.
- Commands are targeted `bin/rspec` files only. The full suite and `bin/ci` need a slot from the coordinator.
- One Conventional Commit per task, each ending with the trailer the session's attribution reminder gives. `Gemfile.lock` has an unrelated working-tree change; never stage it (`git add <paths>`, never `-A`).
- Code blocks are strong drafts, not pre-run (plans are reviewed read-only). Where a run disagrees, the deviation is recorded in the commit body and in `verification.md`.

## Facts the plan rests on

- Rails applies `config.action_view.field_error_proc` through the ActionView railtie's `on_load` (`send "#{k}="`), and calls it as `@template_object.instance_exec(html_tag, self, &Base.field_error_proc)` only when the attribute has errors (actionview 8.1.4.1, `helpers/active_model_helper.rb:28-38`). So the guard must render a form builder field on a record with an error; a direct `.call` of the proc proves nothing about whether Rails applied it.
- The probe (spec Problem Statement) found the wrapper on lots add and edit, Move copies, locations add and rename, sign-up, admin add and edit user. Sign-in and number entry build no record, and the Currency controller clears its record's errors, so those three pass today.
- `config/environments/test.rb` sets `allow_forgery_protection = false`, so a form rendered by `ApplicationController.render` carries no authenticity token and two renders can be compared byte for byte.
- The Currency view reads `@messages` only (`app/views/currencies/edit.html.erb`), never `@account.errors`, so removing `errors.clear` changes nothing it draws.
- Precedent for screenshots: spec 038 committed `.jpg` files under `docs/specs/038-currency-per-account/screenshots/` and no script (`ls script/` has `backup ci scanner upgrade` only). So the capture script lives in the session scratchpad and is not committed.

## File map

| File | Task | Change |
|---|---|---|
| `spec/field_error_proc_spec.rb` | 1 | new guard (AC-1.1) |
| `config/application.rb` | 1 | the `field_error_proc` line |
| `spec/requests/lots_spec.rb` | 2 | assertions in the add and edit 422 examples |
| `spec/requests/lot_moves_spec.rb` | 2 | assertions in the two Move copies 422 examples |
| `spec/requests/locations_spec.rb` | 2 | assertions in the add and rename 422 examples |
| `spec/requests/registrations_spec.rb` | 2 | assertions in the sign-up 422 example |
| `spec/requests/admin/users_spec.rb` | 2 | assertions in the add example; status and `#admin-error` in the edit example |
| `spec/requests/sessions_spec.rb` | 2 | regression assertion (sign-in) |
| `spec/requests/number_entries_spec.rb` | 2 | regression assertion (number entry) |
| `spec/requests/currencies_spec.rb` | 3 | none expected; the existing assertion is re-run |
| `app/controllers/currencies_controller.rb` | 3 | remove `errors.clear` and its comment |
| `docs/design-system/components/Form.md` | 4 | one bullet |
| `docs/specs/044-form-error-wrappers/screenshots/*.jpg` | 5 | 30 images |
| `docs/specs/044-form-error-wrappers/verification.md` | 5 | AC table, rulings, `## Implementation review` heading left to the review |
| `docs/specs/README.md` | 5 | the 044 row's Status, at the moment the maintainer approves the plan and at merge, as `distill-feature` directs |

File overlap, for a parallel worker: tasks 1 and 2 touch disjoint files, but task 2's red proof needs task 1's config line to revert, so they run in order. Task 3 touches one controller and can run beside task 4. Task 5 needs 1 to 3 merged in the worktree.

## Task 1: The rule and its guard (spec decision 1, decision 2; AC-1.1)

**Implements:** Story 1 | **Satisfies:** AC-1.1 | **Files:** `spec/field_error_proc_spec.rb`, `config/application.rb` | **Interfaces:** `config.action_view.field_error_proc` (a callable of `(html_tag, instance)`)

**Test first.** Create `spec/field_error_proc_spec.rb`. A top-level spec like `spec/footer_core_spec.rb` and `spec/currency_reads_spec.rb`, which carry no `type:` (nothing here needs request or view spec infrastructure; `ApplicationController.render` is a plain call). The class is named with `stub_const` because `ActiveModel::Name` refuses an anonymous class. `url: "/"` is required because an `ActiveModel::Model` record has no route.

```ruby
require "rails_helper"

# Spec 044 AC-1.1, ADR 0026: a form builder field comes out as written when its record has an error. Rails calls
# field_error_proc with instance_exec only when the attribute has errors, so this renders a form instead of calling the
# proc: a config key Rails never applied would pass a direct call and fail here.
RSpec.describe "The form builder's field errors" do
  before do
    stub_const("FieldErrorProbe", Class.new do
      include ActiveModel::Model

      attr_accessor :name
    end)
  end

  def render_form(record)
    ApplicationController.render(layout: false, locals: { record: }, inline: <<~ERB)
      <%= form_with model: record, url: "/" do |form| %>
        <%= form.label :name %>
        <%= form.text_field :name %>
      <% end %>
    ERB
  end

  def parse(markup) = Nokogiri::HTML5.fragment(markup)

  let(:plain) { parse(render_form(FieldErrorProbe.new)) }
  let(:invalid) do
    record = FieldErrorProbe.new
    record.errors.add(:name, "can't be blank")
    parse(render_form(record))
  end

  it "wraps nothing when an attribute has an error", :aggregate_failures do
    expect(plain.css(".field_with_errors")).to be_empty # the template itself holds no wrapper
    expect(invalid.css(".field_with_errors")).to be_empty
    expect(invalid.at_css("form").element_children.map(&:name)).to eq(%w[label input])
  end

  it "writes the form's label and input exactly as it does without the error" do
    expect(invalid.at_css("form").inner_html.squish).to eq(plain.at_css("form").inner_html.squish)
  end
end
```

The `form` element's direct children are the label and the input only if the template adds nothing else; `form_with` in test adds no token (see Facts) and a hidden `utf8`/method field only for non-POST verbs. A POST for a non-persisted record adds neither. If the first example's last line fails on a stray hidden input, narrow it to `element_children.reject { it["type"] == "hidden" }`; record that in the commit body.

Run: `bin/rspec spec/field_error_proc_spec.rb`

**Expected red (today):** both examples' `invalid` side fails. Rails' default proc wraps the label and the input, so `.field_with_errors` is found (two elements) and the form's children are two `div.field_with_errors`; and the form's inner HTML differs from the plain render's by the two wrapper `div`s (a per-element comparison would miss that, since each wrapped element's own HTML is unchanged, so the second example compares the form's whole inner HTML). The `plain` side passes in both.

**Code.** `config/application.rb`, after the last `config.x` line inside `class Application`:

```ruby
    # The open catalog (spec 023): off until config/initializers/public_catalog.rb reads the environment.
    config.x.public_catalog = false

    # Fields render unwrapped when a record has errors; the views draw them (spec 044, ADR 0026).
    config.action_view.field_error_proc = ->(html_tag, _instance) { html_tag }
  end
end
```

Run: `bin/rspec spec/field_error_proc_spec.rb` — expected green, 2 examples. Then `bin/rubocop config/application.rb spec/field_error_proc_spec.rb`.

**Commit** (stage the two files in one Bash call, commit in another): `fix(forms): leave form fields unwrapped when a record has errors`, body: spec 044 decision 1, ADR 0026, issue #180.

## Task 2: Each form's refused state asserts no wrapper (decision 2; AC-1.2 to AC-1.11, AC-1.13)

**Implements:** Story 1 | **Satisfies:** AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-1.7, AC-1.8, AC-1.9, AC-1.10, AC-1.11, AC-1.13 | **Files:** the seven request specs in the file map | **Interfaces:** none (assertions only; no production code)

The assertion goes into the existing 422 example of each form, so no new request is made. Each is one line, `expect(<page>.css(".field_with_errors")).to be_empty`, beside the example's existing message assertions, which stay (they are AC-1.13: messages, `c-field--invalid`, `aria-describedby` and kept values unchanged).

**Write the assertions** (each shown with the lines around it; line numbers are today's, verified when the plan was written; the examples are found by name):

1. `spec/requests/lots_spec.rb`, "rejects invalid values with a message per field" (line 70, add; AC-1.2). After `expect(response).to have_http_status(:unprocessable_content)`:

   ```ruby
      expect(response).to have_http_status(:unprocessable_content)
      page = Nokogiri::HTML5(response.body)
      expect(page.at_css("#lot_quantity-error").text).to include("Quantity must be a whole number from 1 to 9,999")
      expect(page.css(".field_with_errors")).to be_empty
   ```

   (the existing `expect(response.body).to include(...)` and `expect(Lot.count).to eq(0)` stay below).

2. Same file, "rejects invalid values with 422 and leaves the lot unchanged" (line 126, edit; AC-1.3). The quantity there is `"lots"`, not a whole number:

   ```ruby
      expect(response).to have_http_status(:unprocessable_content)
      page = Nokogiri::HTML5(response.body)
      expect(page.at_css("#lot_quantity-error").text).to include("Quantity must be a whole number from 1 to 9,999")
      expect(page.css(".field_with_errors")).to be_empty
   ```

3. `spec/requests/lot_moves_spec.rb` (AC-1.4), which has `def html`:
   - "answers 422 with the reasons beside Copies and To, keeping the choice" (line 89): after the `#move_copies-error` assertion on the first request, add `expect(html.css(".field_with_errors")).to be_empty`; after the second request's `#move_copies-error` assertion (`Lot::FULL_MESSAGE`) add the same line.
   - "refuses a move to where the lot already is (P4)" (line 100): after the `#move_location_id-error` assertion add `expect(html.css(".field_with_errors")).to be_empty`. (Together these are AC-1.4's Copies and To.)

4. `spec/requests/locations_spec.rb` (has `def html` and `def field_error`):
   - Add, "answers 422 with the reason beside the field and the typed text kept" (line 43; AC-1.5): inside the `.each` loop, after `expect(response).to have_http_status(:unprocessable_content)`, add `expect(html.css(".field_with_errors")).to be_empty`.
   - Rename, "refuses another location's key, and the reasons of a new name, keeping the name" (line 114; AC-1.6): inside the loop, after `expect(response).to have_http_status(:unprocessable_content)`, add `expect(html.css(".field_with_errors")).to be_empty`.

5. `spec/requests/registrations_spec.rb`, "shows each invalid field's message with 422" (line 59; AC-1.7), after the existing `include` expectation:

   ```ruby
      page = Nokogiri::HTML5(response.body)
      %w[name email_address password password_confirmation].each { |field| expect(page.at_css("##{field}-error")).not_to be_nil, field }
      expect(page.css(".field_with_errors")).to be_empty
   ```

6. `spec/requests/admin/users_spec.rb`:
   - "links an invalid email field to its message" (line 53; AC-1.8): after the existing last expectation add `expect(page.css(".field_with_errors")).to be_empty`.
   - "refuses to delete yourself or demote the only admin" (line 88; AC-1.9). Replace the last three lines so the status, the id and the wrapper are checked:

   ```ruby
      patch admin_user_path(admin), params: { user: { name: "Ann", email_address: admin.email_address, admin: "0" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(admin.reload).to be_admin
      page = Nokogiri::HTML5(response.body)
      expect(page.at_css("#admin-error").text).to eq("Collector needs at least one admin.")
      expect(page.css(".field_with_errors")).to be_empty
      expect(response.body).to include("Collector needs at least one admin.")
   ```

   (The `#admin-error` text is the whole message: `shared/field_errors` renders one `<p>` per `full_messages_for(:admin)`. If the model's full message prefixes the attribute, as `full_messages_for` does for other fields, use `include` instead of `eq`; the existing `include` of the plain sentence shows it is not prefixed, so `eq` is expected to hold. Confirm on the first run.)

7. `spec/requests/sessions_spec.rb`, "rejects a wrong password without saying which field was wrong" (line 23; AC-1.10). Regression example, green today (no record):

   ```ruby
    expect(response.body).to include("Email or password is incorrect.")
    expect(Nokogiri::HTML5(response.body).css(".field_with_errors")).to be_empty
   ```

8. `spec/requests/number_entries_spec.rb`, "keeps the line when no entry has the number" (line 307; AC-1.11). Regression, green today. After the 422 expectation:

   ```ruby
        expect(response).to have_http_status(:unprocessable_content)
        page = Nokogiri::HTML5(response.body)
        expect(page.at_css("#line_number_error").text).to eq("No card numbered 999 in Modern Horizons 3 (EN).")
        expect(page.css(".field_with_errors")).to be_empty
   ```

   (Number entry's message id is `line_number_error`, with an underscore, as in `app/views/collections/number_entries/_line_form.html.erb`.)

9. AC-1.12: `spec/requests/currencies_spec.rb` line 71 already asserts it (the "refuses a code outside the 20" example, line 63). No edit; task 3 re-runs it.

**Prove the red.** The config line from task 1 already exists, so take it away for one run, then restore it. Two Bash calls:

1. `git checkout HEAD~1 -- config/application.rb` (the working tree now has the file as it was before task 1).
2. Run `bin/rspec spec/requests/lots_spec.rb spec/requests/lot_moves_spec.rb spec/requests/locations_spec.rb spec/requests/registrations_spec.rb spec/requests/admin/users_spec.rb spec/requests/sessions_spec.rb spec/requests/number_entries_spec.rb:307`.

**Expected red, without the proc:** failing because the wrapper is on the page: lots add (line 70) and edit (126), both Move copies examples (89, 100), locations add (43) and rename (114), sign-up (59), admin add (53) and admin edit (88). That is nine examples, every one in the probe table. The admin edit example also had two additions that would pass on their own (`:unprocessable_content`, `#admin-error`), so its red is the wrapper line only. **Green already, regression examples, not red:** sign-in (sessions, line 23) and number entry (307); say so in the commit body.

3. `git checkout HEAD -- config/application.rb` restores the line. `git diff HEAD --stat -- config/application.rb` must print nothing.

**Run green:** the same `bin/rspec` command as step 2. Expected: all examples pass. Then `bin/rubocop` on the seven spec files.

**Commit:** stage the seven spec files by path; `test(forms): refused forms render no field_with_errors wrapper`, body: red run listing the nine examples, the two regression examples, AC-1.12's example is unchanged.

## Task 3: The Currency controller stops clearing the record's errors (decision 4; AC-1.12)

**Implements:** Story 1 | **Satisfies:** AC-1.12 | **Files:** `app/controllers/currencies_controller.rb` | **Interfaces:** `CurrenciesController#update` (unchanged signature and responses)

**Test first.** There is nothing to write: spec 038's example "refuses a code outside the 20 with a field error, changing nothing" (`spec/requests/currencies_spec.rb:63`) already asserts the 422, `#account_currency-error`, `aria-describedby`, the saved code selected and `html.css(".field_with_errors")` empty (line 71). It passes today through the controller's `errors.clear`, and after task 1 it would pass without it. That is the point: this task is a removal protected by an existing example, not a red-to-green change, and the plan says so rather than invent a failing test. As a before check, run `bin/rspec spec/requests/currencies_spec.rb` — expected green.

**Code.** In `update`, remove the `errors.clear` line and its comment (the `restore_attributes` line and its comment stay):

```ruby
      @messages = @account.errors.messages_for(:currency)
      @account.restore_attributes # Current.account must not keep the rejected code, and the select shows the saved one
      @priced = priced_lots
      render :edit, status: :unprocessable_content
```

The line removed is:

```ruby
      @account.errors.clear # the page shows @messages; left on the record, Rails would wrap the field in .field_with_errors
```

`Current.account` now keeps its errors for the rest of the request. Nothing else in the request builds a form on it or reads them, and `restore_attributes` leaves errors alone (spec decision 4).

Run: `bin/rspec spec/requests/currencies_spec.rb` — expected green, every example including the one at line 63. To show the example now exercises the app's proc rather than the controller, run it once more with the config line reverted, as in task 2 (`git checkout HEAD~1 -- config/application.rb`, but note that `HEAD~1` is then the task 2 commit, which already has the line: use `git checkout HEAD~2 -- config/application.rb`, check with `git diff HEAD -- config/application.rb` that the line is gone, run `bin/rspec spec/requests/currencies_spec.rb:63`, expect red on the `.field_with_errors` line, then `git checkout HEAD -- config/application.rb`). Record the result in `verification.md`. Then `bin/rubocop app/controllers/currencies_controller.rb`.

**Commit:** `refactor(currency): drop the errors.clear the app-wide proc replaces`, body: spec 044 decision 4; spec 038 criteria unchanged.

## Task 4: The rule where the next form's author reads it (decision 5; AC-3.1, AC-3.2)

**Implements:** Story 3 | **Satisfies:** AC-3.1, AC-3.2 | **Files:** `docs/design-system/components/Form.md` | **Interfaces:** none

Documents are verified by reading (`.claude/rules/testing.md`: no RSpec on prose), so there is no test step. The check is a read against the criterion.

**Edit.** In the bullet list after the markup example, add this bullet directly after the "Errors appear under their own field…" bullet:

```markdown
- Errors render only through `c-field--invalid` and `c-field__error`. The app's `field_error_proc` leaves a field unwrapped when its record has errors, so no `.field_with_errors` element exists to style or to work around, and a form's 422 request example asserts that none is on the page (spec 044, [ADR 0026](../../adr/0026-forms-show-field-errors-through-the-design-system.md)).
```

The surrounding bullets are unchanged. The ADR link is relative to `docs/design-system/components/`, as the export's other links to `../../` docs are. This file is an app addition that is upstreamed before a re-export replaces the folder (`docs/design-system/README.md`), so the commit body says the bullet must travel with that upstream.

AC-3.2 (the ADR states the rule, the options, that it covers forms added later, and that it supersedes the lesson's advice) is already met by the committed ADR 0026 (read: Decision, Options considered, Consequences, Status). No edit; `verification.md` cites it.

**Commit:** `docs(design-system): errors render only through the Form markup`, body names ADR 0026 and the upstream note.

## Task 5: Screenshots and verification (decision 3, Story 2; AC-2.1, AC-1.13)

**Implements:** Story 2 | **Satisfies:** AC-2.1 and the evidence for every other AC | **Files:** `docs/specs/044-form-error-wrappers/screenshots/*.jpg`, `docs/specs/044-form-error-wrappers/verification.md`, `docs/specs/README.md` | **Interfaces:** none

No test: the criterion is read (spec AC-2.1). The method follows the memories `pr-screenshots-workflow`, `headless-firefox-narrow-frame` and `background-servers-via-task`. The capture script is written in the session scratchpad and not committed (spec 038, the precedent, committed images only).

**Dev data.** A fresh worktree's development database is empty. A scratch `bin/rails runner` script in the scratchpad (never committed; the dev database is the worktree's own) creates: an admin user and a second, plain user with known passwords; one applied `Catalog::RefreshRun` so the app is past first run; the printings and lots needed for the states below (two printings of one name in set `mh3` with a number the number-entry page can look up; one lot of 4 copies in a location "Long box"); a second location "Blue binder"; and sign-up opened (`InstanceSetting.current.update!(sign_up_open: true)`). `FactoryBot` is available in development (`factory_bot_rails`, group `:development, :test`), so the script may call the factories. Say in `verification.md` that tiles show placeholders, not card art.

**Server.** Start `bin/dev` as its own `run_in_background` Bash call on the worktree's port (printed by `bin/setup`, or `PORT=`), check readiness in a separate call with a `Net::HTTP` request to `/up` from a short Ruby one-liner (or curl), and stop it with `TaskStop` when done. Never also run `bin/jobs`.

**Capture** (a Ruby script with `selenium-webdriver`, headless Firefox, `$stdout.sync = true`):

- Sign in once as the admin through the real form. Set `data-theme` from the shot's name (`-light` or `-dark`) on `<html>` right before each save, and pause about 0.6 s after every switch. Headless Firefox reports `prefers-color-scheme: dark`, so a page with no `data-theme` renders dark; set the light theme explicitly, and look at the first shot of each theme before trusting the rest.
- Reach each refused state by submitting the real form (no mocked HTML), so the 422 is the page's own: add a lot with quantity 0; edit a lot with quantity `lots` (the browser's `required` and `min` would stop a real click, so set `novalidate` on the form by script or submit with `form.submit` through `execute_script`); Move copies with 9 copies of 4, and then To = the lot's own place; add a location with a blank name; rename a location to another's name; sign up (signed out, in a separate session) with an empty name and a short password; admin add a user with an email `nope`; admin edit: untick Admin on the only admin and save; sign in with a wrong password (signed out); number entry with a number the set lacks (`999`); Currency with `XYZ` (set the option's value by script).
- 12 states: add a lot, edit a lot, Move copies (Copies), Move copies (To), add a location, rename a location, sign up, add a user, edit a user, sign in, number entry, currency.
- Desktop: window 1280 wide, full-page screenshot per state in `light` then `dark`: 24 images.
- Phone (390 px, add a lot, add a location, sign up only, light and dark): the window cannot go below 500 px, so open the refused page's URL state in a same-origin fixed-width iframe. A refused state is the result of a POST, so a plain `src` would reload the form empty. Instead inject the 422's HTML into the frame: fetch the refused page's HTML from the page that already shows it (`document.documentElement.outerHTML` before the frame is made), write it with `iframe.contentDocument.write`, or, simpler, submit the form from inside the frame (open the form's GET page in the frame, then fill and submit it in the frame so its 422 renders there). Grow the frame to its content height, resize the window taller than the frame, take an element screenshot of the frame (`find_element(id: "narrow").save_screenshot`), and set `data-theme` inside the frame's document, with the 0.6 s pause. 6 images.
- Total: 30 images. Compress to JPEG as the memory says: `magick in.png -resize 1000x -quality 82 out.jpg` (phone shots at their own width), for about 150 to 300 KB each; check the folder's size and lower the quality to 55 if it passes 6 MB.
- Names: `<state>-desktop-light.jpg`, `<state>-desktop-dark.jpg`, and `<state>-phone-light.jpg` and `<state>-phone-dark.jpg` for the three, with `<state>` one of `lot-add`, `lot-edit`, `move-copies`, `move-to`, `location-add`, `location-rename`, `sign-up`, `user-add`, `user-edit`, `sign-in`, `number-entry`, `currency`.
- Look at every image. In each: the label above its control, the control as wide as its siblings, the message under it. A control shrunk to content width or a shifted label is a defect of this spec, so stop and diagnose (not a new style).

**verification.md.** Write `docs/specs/044-form-error-wrappers/verification.md` in spec 038's shape: header with spec, plan and branch; `## Rulings` (decisions 1 and 4 as ruled by the maintainer, 2026-11-06, option A; the screenshot ruling of 0.4.0; deviations recorded in commit bodies); `## Evidence`, one row per AC:

| Criterion | Proved by |
|---|---|
| AC-1.1 | `spec/field_error_proc_spec.rb` (both examples; red before the config line, green after) |
| AC-1.2, 1.3 | `spec/requests/lots_spec.rb` "rejects invalid values with a message per field" and "…with 422 and leaves the lot unchanged" |
| AC-1.4 | `spec/requests/lot_moves_spec.rb` "answers 422 with the reasons beside Copies and To…" and "refuses a move to where the lot already is" |
| AC-1.5, 1.6 | `spec/requests/locations_spec.rb` add and rename 422 examples |
| AC-1.7 | `spec/requests/registrations_spec.rb` "shows each invalid field's message with 422" |
| AC-1.8, 1.9 | `spec/requests/admin/users_spec.rb` "links an invalid email field to its message"; "refuses to delete yourself or demote the only admin" (status and `#admin-error` added) |
| AC-1.10, 1.11 | `sessions_spec.rb` and `number_entries_spec.rb`, regression examples (green before the config line, as stated in task 2's commit) |
| AC-1.12 | `spec/requests/currencies_spec.rb:63`, kept; the controller no longer clears (task 3), and the example fails with the config line reverted |
| AC-1.13 | each form's existing assertions, all green in the same runs |
| AC-2.1 | the 30 images in `screenshots/`, listed with a one-line reading of each (by looking) |
| AC-3.1 | `docs/design-system/components/Form.md`, the added bullet (by reading) |
| AC-3.2 | `docs/adr/0026-…md` (by reading) |

Also record: the screenshots' dev data and its limits; the measured red lists of tasks 1 to 3; the full `bin/ci` result; and, after `sdd-review` (Mode B), the `## Implementation review` heading with its verdict on its first line (`.claude/rules/documentation.md` rule; `distill-feature` reads it). Do not write that heading before the review.

**README index.** `docs/specs/README.md`'s 044 row: `distill-feature` and the coordinator own its Status changes (Approved now; frozen at the merge), so this task changes it only if the coordinator asks. No area doc changes, so the row's links stay.

**Final verification.** Ask the coordinator for a CI slot, then run `bin/ci` (the whole branch: RuboCop, Brakeman, bundler-audit, importmap audit, RSpec). Before that, `bin/rspec spec/field_error_proc_spec.rb spec/requests/lots_spec.rb spec/requests/lot_moves_spec.rb spec/requests/locations_spec.rb spec/requests/registrations_spec.rb spec/requests/admin/users_spec.rb spec/requests/sessions_spec.rb spec/requests/number_entries_spec.rb spec/requests/currencies_spec.rb` — expected green. Do not claim completion without the `bin/ci` output.

**Commits:** `docs(specs): spec 044 screenshots of the refused states`, `docs(specs): spec 044 verification`.

## Coverage

| Criterion | Task |
|---|---|
| AC-1.1 | 1 |
| AC-1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11 | 2 |
| AC-1.12 | 3 (and the existing line 71 assertion; red proof in task 3) |
| AC-1.13 | 2 (the existing assertions stay and pass in the same runs) |
| AC-2.1 | 5 |
| AC-3.1 | 4 |
| AC-3.2 | met by the committed ADR 0026; cited in 5's `verification.md` |

Decision 1 is task 1, decision 2 tasks 1 and 2, decision 3 task 5, decision 4 task 3, decision 5 task 4 (and no area doc, by decision).

## Pre-implementation gates

- Simplicity: one config line, one guard spec, assertions in existing examples, one removal, one doc bullet. No new component, dependency or abstraction.
- Anti-abstraction: the framework's own `field_error_proc` setting is used directly; no wrapper class, no helper.
- Integration-first: the guard renders through Rails' own builder path before any form example relies on the setting.

## What only a run can confirm

- That the guard's first example's `form` children are exactly `label` and `input` under `ApplicationController.render` (a stray hidden input is handled in task 1's note).
- That `ApplicationController.render(inline:, locals:, layout: false)` accepts `layout:` with `inline:` in Rails 8.1.4 (if not, drop `layout: false`; `inline` renders without a layout by default).
- That the second guard example is red today (it compares the form's whole inner HTML, so the wrapper `div`s show).
- That `#admin-error` holds exactly "Collector needs at least one admin." (task 2, item 6).
- That `git checkout HEAD~1 -- config/application.rb` restores the pre-task-1 file (task 1 must be exactly one commit that touched it).
- That the narrow-frame capture of a refused state, by submitting inside the frame, works for add a lot, add a location and sign up; sign-up needs a signed-out session for the frame, so the script uses a second browser session for it.
- That 30 images fit comfortably under the repository's habit (about 280 KB for eight at quality 55, 150 to 300 KB at 82).

## Deviations and risks

- AC-1.10 and AC-1.11 (sign-in and number entry) and AC-1.12's Currency assertion pass before any change. They are regression examples the issue asks for, not red-to-green, and the plan says so in each commit body rather than pretend.
- A config-only fix cannot be seen to fail by an example that renders no record; only the guard and the nine wrapped forms' examples are red without it.
- Removing `errors.clear` leaves errors on `Current.account` for the rest of one request (spec decision 4); no reader exists today, and a future form built on `Current.account` after a failed `update` would draw its own errors, which is the app-wide rule.
