# 0026: Forms show field errors through the design system, not Rails' wrapper

## Status

Accepted (2026-11-06). Ruled by the maintainer on 2026-11-06 (spec 044 decision 1, option A) and written with spec 044. The number was assigned by the coordinator of the parallel run that wrote specs 041 to 044; the YARD ADR the [index](README.md) expected at 0026 takes the next free number. It supersedes the advice of the lesson [`2026-11-06-clear-record-errors-after-copying-field-messages`](../lessons/2026-11-06-clear-record-errors-after-copying-field-messages.md) to clear a record's errors before re-rendering; the lesson stays as written.

**Date:** 2026-11-06
**Feature:** 044-form-error-wrappers

## Context

Rails' default `ActionView::Base.field_error_proc` wraps every form-builder label and control whose attribute has errors in `<div class="field_with_errors">`. Collector's forms draw their errors themselves, as the design system's [Form](../design-system/components/Form.md) has them: `c-field--invalid` on the field, one `c-field__error` per message under the control (`shared/field_errors`), and `aria-describedby` from the control to each message. The wrapper sits between `c-field` and its children, so on a refused submission the control shrinks to its content width and the label shifts.

Spec 038 found it on the Currency page and cleared the record's errors in its controller. A probe on 2026-11-06 found the wrapper on seven more refused forms (lots add and edit, Move copies, locations add and rename, sign-up, admin add and edit user; [spec 044](../specs/044-form-error-wrappers/spec.md)). No CSS, JavaScript or view reads the wrapper.

## Options considered

### Option A: The app's `field_error_proc` returns the tag unchanged (chosen)

`config.action_view.field_error_proc = ->(html_tag, _instance) { html_tag }` in `config/application.rb`.

**Pros:** one line covers every form, today's and those added later (spec 041's bulk Move among them); views and form objects keep reading the record's own errors; nothing to remember per controller. **Cons:** a form that forgets to render its errors shows no sign of them at all; the views' own `c-field--invalid` and messages are the only marking, which is already the design system's rule.

### Option B: Spec 038's pattern in each controller

Copy the record's messages to the view, `errors.clear`, render. **Pros:** no global setting. **Cons:** five controllers change and every new form must repeat it; the lesson exists because one form didn't; views that read `record.errors` would have to read copies.

### Option C: A proc that marks the control instead of wrapping it

Add a class (for example `c-field--invalid`) to the tag. **Pros:** a forgotten view still marks the field. **Cons:** duplicates what the views put on the field, ties the form builder to the design system's class names, and parses HTML in the proc.

## Decision

Option A. A form shows a field's errors only through the design system's Form markup (`c-field--invalid`, `shared/field_errors`, `aria-describedby`); Rails' wrapper is never rendered. A form that re-renders with 422 has a request example asserting no `.field_with_errors` on the page, and the suite checks that the proc returns its tag unchanged. Spec 038's `errors.clear` in `CurrenciesController#update` is removed.

## Consequences

- No page carries `field_with_errors`; nothing is styled for it.
- A view must render the errors it wants shown; an attribute's errors the view doesn't render are invisible (as on the Currency page before this ADR).
- The rule is in the design system's [Form](../design-system/components/Form.md) doc, where a new form's author looks.
