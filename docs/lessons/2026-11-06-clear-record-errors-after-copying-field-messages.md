---
date: 2026-11-06
spec: "038"
tags: [design-system, forms, rails, screenshots]
---

# Lesson: A form that renders its own field errors must clear the record's

## Context

Spec 038's Currency page: one `form.select :currency` on `Current.account`, re-rendered with 422 and "Choose one of the listed currencies." when the code is refused. The view renders the messages itself (`shared/field_errors`, `c-field--invalid`) from a copy the controller takes, and `restore_attributes` puts the saved code back.

## What happened

Every request example passed, and the review found no fault. The refused page's screenshot showed the select shrunk to its content width and the label nudged down: the record still carried its errors, so Rails' default `field_error_proc` wrapped the label and the select in `<div class="field_with_errors">`, which breaks the `c-field` column's stretch. The app sets no `field_error_proc`, so any form builder field on a record with errors gets the wrapper.

## What to do next time

When a controller copies a record's messages for the design system's field errors and re-renders the form, clear the record's errors (`record.errors.clear`) after the copy, and assert `html.css(".field_with_errors")` is empty in the 422 example. Look at the refused state in a screenshot, not only the valid one.

## Signals to watch for

- A `c-field` control narrower than its siblings, or a label shifted, only after a failed submission.
- A form built with `form.select`/`form.text_field` on a model that is re-rendered with 422.
- Other forms (lots, locations, admin users) may carry the same wrapper today; check them when touching their refused state.
