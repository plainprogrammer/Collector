# Feature 044: Forms Re-rendered with 422 Get No `field_with_errors` Wrapper

**Status:** Draft. The maintainer ruled decisions 1 and 4 on 2026-11-06, as recommended (option A; the currency controller's `errors.clear` removed); the rule is [ADR 0026](../../adr/0026-forms-show-field-errors-through-the-design-system.md)
**Version:** 0.1.0
**Created:** 2026-11-06
**Last Updated:** 2026-11-06
**Depends on:** [spec 004](../004-design-system-collection/spec.md) (the design system's Form, sign-up, sign-in, admin users), [spec 029](../029-manage-locations/spec.md) (locations), [spec 032](../032-lot-in-a-location/spec.md) (Move copies), [spec 026](../026-typed-entry/spec.md) (number entry), [spec 038](../038-currency-per-account/spec.md) (the Currency page), all merged
**Branch:** `044-form-error-wrappers`
**Issue:** [#180](https://github.com/plainprogrammer/Collector/issues/180)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-06 | Written from issue #180, the lesson [`2026-11-06-clear-record-errors-after-copying-field-messages`](../../lessons/2026-11-06-clear-record-errors-after-copying-field-messages.md), the design system's [Form](../../design-system/components/Form.md), and a probe of today's 422 pages. |

---

## Problem Statement

Rails' default `ActionView::Base.field_error_proc` wraps every form-builder label and control whose attribute has errors in `<div class="field_with_errors">`. Collector's forms draw errors themselves, the design system's way: `c-field--invalid` on the field, one `c-field__error` per message under the control, and `aria-describedby` pointing at it ([Form](../../design-system/components/Form.md)). The extra `div` sits between `c-field` and its children, so the label and the control no longer stack as the design system draws them: a select or input shrinks to its content width and the label shifts (found by spec 038 in the Currency page's screenshot; [lesson](../../lessons/2026-11-06-clear-record-errors-after-copying-field-messages.md)). The app sets no `field_error_proc`, so every form built on a record with errors gets the wrapper. Spec 038 cleared the record's errors in its own controller; the other forms still carry the wrapper.

**Probe (2026-11-06).** Wrapping `field_error_proc` to log its calls while running the 422 request examples of the forms below found the wrapper on:

| Form | Controller | Record | Wrapped attributes |
|---|---|---|---|
| Add a lot | `LotsController#create` | `Lot::Form` | `quantity` (label and control) |
| Edit a lot | `LotsController#update` | `Lot::Form` | `quantity` |
| Move copies | `Lots::MovesController#create` | `Lot::Move` | `copies`, `location_id` |
| Add a location | `LocationsController#create` | `Location` | `name` |
| Rename a location | `LocationsController#update` | `Location` | `name` |
| Sign up | `RegistrationsController#create` | `User` | `name` (and any other invalid field) |
| Add a user (admin) | `Admin::UsersController#create` | `User` | `email_address` (and any other invalid field) |
| Edit a user (admin) | `Admin::UsersController#update` | `User` | `admin` (the checkbox inside `c-check`) |

and none on sign-in (`form_with url:`, no record), number entry's line form (`form_with url:`, tag helpers) and the Currency page (spec 038 clears the record's errors).

**Outcome (issue #180):** no form's refused state carries the wrapper, today's forms and any added later, so every 422 renders with the design system's field layout.

## Goals

- No page rendered by Collector contains a `field_with_errors` element.
- Each form the issue names has a 422 request example that proves it.
- The rule is written where the next form's author reads it: the design system's Form doc and an ADR.

## Non-Goals

- **Changing any message, field, status or what a form keeps on a refusal.** Every 422 keeps its messages, its `c-field--invalid`, its `aria-describedby` and its typed values exactly as its own spec has them.
- **New styles.** No CSS is added for `field_with_errors`; the wrapper stops existing.
- **The bulk-mode views and spec 041's bulk Move form.** Not edited here; the rule (decision 1) covers them when they land, and their spec owns their examples.
- **Forms with no 422** (filters, the language picker, the scanner's place picker) and **Turbo Stream refusals** (quick add, the scanner sitting): they render no record's errors through a form builder.

## Decisions

### 1. The app sets `field_error_proc` to return the tag unchanged (ruled 2026-11-06)

`config/application.rb` sets `config.action_view.field_error_proc = ->(html_tag, _instance) { html_tag }`. Every form builder field and label renders as written, with or without errors. The views already show errors through `c-field--invalid` and `shared/field_errors`; nothing read the wrapper (no CSS, JavaScript or spec selects `.field_with_errors` except spec 038's assertion that it is absent).

It is an app-wide rule, so [ADR 0026](../../adr/0026-forms-show-field-errors-through-the-design-system.md) records it: forms show a field's errors through the design system's Form markup, never through Rails' wrapper; a view that renders a record's errors does so with `c-field--invalid` and `shared/field_errors`.

Alternatives:

- **B. Spec 038's per-controller pattern in each controller** (copy the record's messages, `errors.clear`, render). Five controllers change, `Lot::Form#absorb` and the views that read `record.errors` would read copies instead, and every future form must remember the step; the lesson exists because one did not. Rejected.
- **A custom proc that adds a class instead of a `div`** (for example `c-field--invalid` on the control). It duplicates what the views already put on the field and couples the builder to the design system's class names. Rejected.

### 2. One 422 example per form, plus a guard on the rule

Each form in the probe table, plus sign-in, number entry and the Currency page, gets (or keeps) a request example that submits an invalid value, expects 422, and expects `html.css(".field_with_errors")` to be empty while the field's own message is still under it. Where an existing 422 example already renders the refused state, the assertion is added to it rather than a new request made. A further example proves the rule itself: `ActionView::Base.field_error_proc` returns its tag unchanged (the same object or an equal safe string), so a form added later is covered before its own spec writes its example.

### 3. Screenshots of every refused state

Verification captures each form's 422 in light and dark at desktop and phone width (the memories `pr-screenshots-workflow` and `headless-firefox-narrow-frame`), committed under `docs/specs/044-form-error-wrappers/screenshots/`, and shows in each that the label sits above a control as wide as its siblings.

### 4. The Currency controller's `errors.clear` goes (ruled 2026-11-06)

With decision 1 the line in `CurrenciesController#update` that clears the record's errors "so Rails would not wrap the field" no longer does anything for the wrapper. It is removed with its comment, and the page keeps showing `@messages`; spec 038's examples (including its `.field_with_errors` assertion) still pass.

### 5. Where the rule is written

- [Form](../../design-system/components/Form.md) gains a bullet: errors render through `c-field--invalid` and `c-field__error` only; the app's `field_error_proc` leaves fields unwrapped (spec 044, the ADR); a 422 example asserts no `.field_with_errors`.
- [ADR 0026](../../adr/0026-forms-show-field-errors-through-the-design-system.md) and its index row.
- No area doc under `docs/architecture/` describes form markup, so none changes; the forms' behaviour is unchanged.
- The lesson stays as written (lessons are history); its advice to clear errors is superseded by the ADR, which says so.

## User Stories

### Story 1: A refused form keeps the design system's layout

**As a** collector who submits a form with a mistake, **I want** the form to come back with each field drawn as before, its message under it, **so that** the page doesn't shift and I can see what to fix.

- [ ] **AC-1.1** Given `ActionView::Base.field_error_proc` When it is called with an HTML tag and a tag instance Then it returns that tag unchanged (decision 1).
- [ ] **AC-1.2** Add a lot: Given a quantity of 0 When the add form is submitted Then 422, `#lot_quantity-error` holds the quantity message, and no `.field_with_errors` is on the page.
- [ ] **AC-1.3** Edit a lot: Given a quantity of 0 When the edit form is submitted Then 422, the quantity message under Quantity, no `.field_with_errors`.
- [ ] **AC-1.4** Move copies: Given copies outside 1 to the lot's quantity, and separately the lot's own place as To When submitted Then 422, the message under Copies (or To), no `.field_with_errors`.
- [ ] **AC-1.5** Add a location: Given an empty name When submitted Then 422, "Give the location a name." under Name, no `.field_with_errors`.
- [ ] **AC-1.6** Rename a location: Given another location's name When submitted Then 422, the duplicate message under Name, no `.field_with_errors`.
- [ ] **AC-1.7** Sign up: Given an empty name and a short password When submitted Then 422, each message under its field, no `.field_with_errors`.
- [ ] **AC-1.8** Admin add a user: Given an invalid email When submitted Then 422, the message under Email, no `.field_with_errors`.
- [ ] **AC-1.9** Admin edit a user: Given the only admin unticking Admin on themself When submitted Then 422, the message under the Admin checkbox, no `.field_with_errors`.
- [ ] **AC-1.10** Sign in: Given a wrong password When submitted Then 422 with "Email or password is incorrect." and no `.field_with_errors`.
- [ ] **AC-1.11** Number entry: Given a line with a number the set doesn't have When submitted Then 422, the message under Number, no `.field_with_errors`.
- [ ] **AC-1.12** Currency: Given `XYZ` When submitted Then 422, "Choose one of the listed currencies." under the select, no `.field_with_errors` (spec 038 AC-1.7's example, kept), and per decision 4 the controller no longer clears the record's errors.
- [ ] **AC-1.13** Given AC-1.2 to AC-1.12 Then each form's messages, `c-field--invalid`, `aria-describedby` and kept values are as their own specs have them (their existing examples pass unchanged).

### Story 2: The refused states are seen, not only asserted

**As the** maintainer, **I want** a screenshot of each refused form in both themes, **so that** the layout is checked by eye as spec 038's lesson asks.

- [ ] **AC-2.1** Given the 11 refused states of AC-1.2 to AC-1.12 When captured in light and dark at desktop (1280 px) and phone (390 px, in a fixed-width frame) width Then each image shows the label above its control, the control as wide as the field, and the message under it; the images are committed and linked from `verification.md` and the PR (read).

### Story 3: The next form follows the rule without knowing it

**As a** contributor adding a form (spec 041's bulk Move, for example), **I want** the rule written where I look, **so that** I neither add the wrapper's workaround nor style the wrapper.

- [ ] **AC-3.1** Given the design system's [Form](../../design-system/components/Form.md) doc When read Then it says errors render only through `c-field--invalid` and `c-field__error`, that the app leaves fields unwrapped, and that a form's 422 example asserts no `.field_with_errors`, citing this spec and the ADR (read).
- [ ] **AC-3.2** Given the ADR When read Then it states the rule, the alternatives of decision 1, that it covers forms added later, and that it supersedes the lesson's advice to clear a record's errors (read).

## Supersedes

| Spec | What | Where |
|---|---|---|
| none | Spec 038's `errors.clear` is code and a verification note, not a criterion; decision 4 removes the line without changing any of 038's criteria | — |

## Error Scenarios

| Scenario | Expected |
|---|---|
| A record has errors on an attribute the view renders no message for | The field renders unwrapped and unmarked, as today on the Currency page; the view decides what it shows (unchanged rule of each spec) |
| A future gem or Rails upgrade changes `field_error_proc`'s signature | AC-1.1's example fails |

## Non-Functional Requirements

- **Security.** The proc returns Rails' own `SafeBuffer` unchanged; no `html_safe`, `raw` or interpolation is added.
- **Performance.** None: one fewer `div` per invalid field.
- **Self-hosting and upgrades.** No migration, setting or data change.

## Verification

`docs/specs/044-form-error-wrappers/verification.md`: an AC table pointing at each example, the screenshots, and the implementation review under `## Implementation review`.
