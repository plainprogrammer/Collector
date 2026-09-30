# CollectionTable

The alternate collection view, and the only place bulk actions happen: one dense row per item, for scanning, sorting and editing many items at once.

**Markup** — a plain `<table class="c-table">`; the consumer provides the columns. Mark numeric cells `is-num` (right-aligned mono), codes `is-data` (mono), secondary text `is-muted`, and a selected row with `aria-selected="true"`. Mark columns that can drop on phones `is-opt` and repeat their key facts in a `c-table__sub` line under the name. Wrap the collection in `.c-collection`.

```html
<table class="c-table">
  <thead><tr><th>…</th><th>Name</th><th>Set</th><th class="is-num">Qty</th>…</tr></thead>
  <tbody><tr><td><input type="checkbox" …></td><td><div class="c-table__item"><img class="c-table__thumb" …>Lightning Bolt</div></td><td class="is-data">2X2 · 117</td><td class="is-num">4</td>…</tr></tbody>
</table>
```

- Available through the view switch; the user's choice is remembered. Grid stays the default.

**Bulk mode.** All multi-item operations (move, set condition, update prices, remove, lend) live here and nowhere else.

- Choosing a bulk action anywhere — including from the grid — opens the table with the same search, filters and sort, with checkboxes shown and the `c-bulkbar` pinned above it.
- The bar shows the selection count against the filtered total ("2 of 4,812 selected"), the actions as `c-btn--sm` secondary buttons, `Remove` as `c-btn--danger`, and `Done` as the one primary.
- "Select all" in the header selects every item matching the filters, not only the visible page, and the count says so.
- `Done` (or Esc) leaves bulk mode and returns to the user's saved view (usually the grid), keeping search and filters. Bulk mode never changes the saved preference.
- Narrow (below 640px): `is-opt` columns hide and `c-table__sub` shows set and location under the name; the bar keeps the count, a "…" menu (`c-bulkbar__more`) holding the actions, and `Done`. Wrap the wide-screen action buttons in `c-bulkbar__extra` so they hide.
- Actions submit forms and answer with Turbo Streams that replace the changed rows and the count.
- Destructive bulk actions confirm with the count ("Remove 12 items?") and offer undo afterwards.

```html
<div class="c-bulkbar" role="region" aria-label="Bulk actions">
  <div class="c-bulkbar__count"><span>2</span> of 4,812 selected</div>
  <div class="c-bulkbar__extra">
    <button class="c-btn c-btn--secondary c-btn--sm">Move to…</button>
    <button class="c-btn c-btn--danger c-btn--sm">Remove</button>
  </div>
  <details class="c-menu c-bulkbar__more">…the same actions as c-menu__item…</details>
  <a class="c-btn c-btn--primary c-btn--sm" href="?view=grid">Done</a>
</div>
```
- Default columns: select, name (with a 24px thumbnail), set · number, condition, quantity, location, price. Comics swap set for series · issue and condition for grade.
- The header sticks; columns sort on click with `aria-sort`.
- Prices and quantities are always right-aligned mono so digits line up.
