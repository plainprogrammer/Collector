# TableActions

The last cell of a table row, just wide enough for the row's "…" menu.

**Markup** — the consumer gives the cell `c-table__actions`, puts a `Menu` inside it, and names the header cell for screen readers only.

```html
<thead><tr>…<th><span class="c-sr">Actions</span></th></tr></thead>
<tbody><tr>
  …
  <td class="c-table__actions">
    <details class="c-menu" data-controller="menu">
      <summary class="c-btn c-btn--ghost c-btn--sm c-btn--icon" aria-label="Actions for M10 · 146 NM"><svg …/></summary>
      <div class="c-menu__list">
        <a class="c-menu__item" href="/lots/1/edit">Edit copy</a>
        <div class="c-menu__sep"></div>
        <a class="c-menu__item c-menu__item--danger" href="/lots/1/removal/new">Remove</a>
      </div>
    </details>
  </td>
</tr></tbody>
```

- The cell is `width:1%`, so it shrinks to its menu and the other columns get the space; never set the width inline.
- The trigger's `aria-label` names the row ("Actions for Sam", "Actions for M10 · 146 NM"), since every row's button looks the same.
- A destructive item is last, after a separator, and links to a `ConfirmPage` rather than acting at once.
- Used by the card page's copies table and the admin users list.
