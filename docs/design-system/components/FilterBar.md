# FilterBar

The sticky bar at the top of every collection: search, quick filters, result count and the view switch.

**Markup** — the consumer provides a search `c-input`, a `c-filterbar__filters` group of `c-filter` buttons, and a `c-filterbar__end` holding the count, the `Edit many` button (`c-filterbar__bulk`), the `c-seg` view switch and a `c-menu` with class `c-filterbar__more` holding `Edit many` again for narrow screens. Wrap the whole collection in `.c-collection`.

```html
<div class="c-filterbar">
  <label class="c-input">…</label>
  <div class="c-filterbar__filters">…c-filter buttons…</div>
  <div class="c-filterbar__end">
    <span class="c-filterbar__count">4,812 items</span>
    <a class="c-btn c-btn--secondary c-btn--sm c-filterbar__bulk" href="?view=table&bulk=1">Edit many</a>
    <div class="c-seg">…</div>
    <details class="c-menu c-filterbar__more">…<a class="c-menu__item" href="?view=table&bulk=1">Edit many</a>…</details>
  </div>
</div>
```

- It sticks to the top while the grid scrolls; the page provides the scroll container.
- The count always reflects the current filters ("312 of 4,812 items" when filtered).
- `/` focuses search from anywhere on the page.
- `Edit many` enters bulk mode: it links to the table view with `bulk=1` and the current params. Below 640px it moves into the "…" menu.
- Narrow layout (below 640px of `.c-collection`): search takes the full width, quick filters scroll sideways on one line, and the count, view switch (icons only) and "…" menu share the last row.
- It is a GET form targeting the results Turbo Frame, so every filter state is a URL.
- Works well as a Turbo Frame: filters update the results frame without a full reload.
