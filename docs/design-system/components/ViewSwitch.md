# ViewSwitch

A segmented control that switches how a collection is shown; the pressed option is filled `brand`.

**Markup** — a `role="group"` with an `aria-label`, holding two to four `<button aria-pressed>` options, each with a label (and optional 14px icon).

```html
<div class="c-seg" role="group" aria-label="View">
  <button aria-pressed="true"><svg …/><span class="c-seg__label">Grid</span></button>
  <button aria-pressed="false"><svg …/><span class="c-seg__label">Table</span></button>
</div>
```

- Grid is the default for every new user. The choice is saved as a user preference and restored on every collection page, not per page.
- While bulk mode is on, Table shows as pressed and Grid is disabled; leaving bulk mode restores the saved choice.
- Wrap labels in `c-seg__label`: below 640px inside `.c-collection` they become screen-reader-only and the switch shows icons alone, so only wrap a label that has an icon beside it; text-only options (Large / Compact) keep their words.
- The choice is a URL param (`?view=table`) saved to the user's preference, so Turbo's back button restores it.
- Use for mutually exclusive views only (grid/table, large/compact); for on/off filters use `c-filter`.
