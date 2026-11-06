# Form

A stacked form: one field per row, a label above each control, a hint and per-field errors under it, and the actions last.

**Markup** — the consumer provides `c-form` on the form, a `c-field` per field (label, control, optional hint, errors), and a `c-form__actions` row. Text controls sit in a `c-input` (see `Input`); selects and checkboxes are plain elements inside the field.

```html
<form class="c-form" action="/catalog/entries/…/lots" method="post">
  <div class="c-field c-field--invalid">
    <label class="c-field__label" for="lot_quantity">Quantity</label>
    <label class="c-input"><input type="number" min="1" max="9999" step="1" inputmode="numeric" required id="lot_quantity" name="lot[quantity]"></label>
    <p class="c-field__error">Quantity must be a whole number from 1 to 9,999</p>
  </div>
  <div class="c-field">
    <label class="c-field__label" for="lot_condition">Condition</label>
    <select id="lot_condition" name="lot[condition]"><option value="">Not specified</option><option value="near_mint">Near mint (NM)</option>…</select>
  </div>
  <div class="c-field">
    <label class="c-field__label" for="lot_price_paid">Price paid per copy (USD)</label>
    <label class="c-input"><span aria-hidden="true">$</span><input type="text" inputmode="decimal" placeholder="1.25" id="lot_price_paid" name="lot[price_paid]"></label>
    <p class="c-field__hint">Optional.</p>
  </div>
  <div class="c-field">
    <label class="c-check"><input type="checkbox" name="user[admin]" value="1"> Admin (can manage users and sign-up)</label>
  </div>
  <div class="c-form__actions">
    <input type="submit" class="c-btn c-btn--primary" value="Add to collection">
    <a class="c-btn c-btn--secondary" href="/catalog/entries/…">Cancel</a>
  </div>
</form>
```

- `c-field--invalid` turns the field's `c-input` or `select` border `danger`; the error message under it says what's wrong in words, so colour never carries it alone.
- Errors appear under their own field, one `c-field__error` per message, in the order the fields appear. When a field has errors, point the control at them with `aria-describedby` and an `id` on the message.
- Errors render only through `c-field--invalid` and `c-field__error`. The app's `field_error_proc` leaves a field unwrapped when its record has errors, so no `.field_with_errors` element exists to style or to work around, and a form's 422 request example asserts that none is on the page (spec 044, [ADR 0026](../../adr/0026-forms-show-field-errors-through-the-design-system.md)).
- A failed submission re-renders the form with status 422 (`:unprocessable_content`) and the values kept, so Turbo shows it in place.
- Hints (`c-field__hint`) state limits exactly ("At least 12 characters.") or mark a field "Optional."; don't repeat the label.
- Selects get the same height, border and focus ring as `c-input`; a blank first option says "Not specified" rather than a dash. A select never widens past its form, however long an option (a location's name) is (spec 040 AC-7.1).
- A required select whose first option is a prompt says "Choose…" and submits `""`, so the browser's required check refuses it; "Not specified" is for an optional field's blank (spec 041 decision 6, AC-2.1, AC-2.2).
- `c-check` puts a checkbox before its label on one line; the checkbox uses `accent-color: var(--brand)`.
- A form that follows a `c-pagehead` directly sits one section space (`space-6`) below it (`.c-pagehead + .c-form`), so the first label never touches the page head's stats line.
- Actions: the primary action first, then "Cancel" as a secondary link back to where the collector came from. The form is at most 420px wide.
