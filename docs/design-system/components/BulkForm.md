# BulkForm

The table in bulk mode as one form, so every tick reaches the server with whatever the collector presses next, with or without scripting.

**Markup** — one `PATCH` form (`id="bulk"`) holds the table and the pager. The filter bar and the bulk bar sit together in `c-bulkhead`, just before the form, and their controls join it with `form="bulk"`: the filter input, a visually hidden Filter button and every bulk-bar button. The first column holds the checkboxes (`c-table__select`), and rows have no actions menu.

```html
<div class="c-collection" data-controller="search-shortcut bulk-selection">
  <div class="c-bulkhead">
    <div class="c-filterbar" role="search">
      <label class="c-input">…<input type="search" name="q" form="bulk" placeholder="Search your collection" aria-label="Search your collection"><kbd>/</kbd></label>
      <button type="submit" form="bulk" name="go" value="filter" class="c-sr" tabindex="-1">Filter</button>
      <div class="c-filterbar__end"><div class="c-seg" role="group" aria-label="View">…inert buttons…</div></div>
    </div>
    <div class="c-bulkbar" role="region" aria-label="Bulk actions">
      <div class="c-bulkbar__count"><span>2</span> of 4,812 selected</div>
      <div class="c-bulkbar__extra">
        <button type="submit" form="bulk" name="go" value="set_condition" class="c-btn c-btn--secondary c-btn--sm">Set condition…</button>
        <button type="submit" form="bulk" name="go" value="remove" class="c-btn c-btn--danger c-btn--sm">Remove</button>
      </div>
      <details class="c-menu c-bulkbar__more">…the same buttons as c-menu__item, each with form="bulk"…</details>
      <button type="submit" form="bulk" name="go" value="done" class="c-btn c-btn--primary c-btn--sm">Done</button>
    </div>
  </div>
  <form id="bulk" action="/collection/selection" method="post">
    <input type="hidden" name="_method" value="patch">
    <input type="hidden" name="rendered_q" value=""><input type="hidden" name="page" value="1"><input type="hidden" name="all_rendered" value="0">
    <table class="c-table">
      <thead><tr>
        <th class="c-table__select"><input type="checkbox" name="all" value="1" aria-label="Select all"></th>
        <th aria-sort="ascending"><button type="submit" name="go" value="/collection?bulk=1&amp;dir=desc&amp;sort=name" class="c-table__sort">Name</button></th>
        …
      </tr></thead>
      <tbody><tr aria-selected="true">
        <td class="c-table__select">
          <input type="hidden" name="shown_ids[]" value="41">
          <input type="checkbox" name="ticked_ids[]" value="41" checked aria-label="Select M10 · 146 NM">
        </td>
        …
      </tr></tbody>
    </table>
    <nav class="c-pager" aria-label="Pagination">
      <span class="c-pager__position">Page 1 of 41</span>
      <button type="submit" name="go" value="/collection?bulk=1&amp;page=2" class="c-btn c-btn--secondary c-btn--sm">Next</button>
    </nav>
  </form>
</div>
```

- Every control that leaves the page is a submit button named `go`: Filter, the sort headers, Previous/Next, the actions and Done. Links would lose unsubmitted ticks, and a hover prefetch must never change the selection.
- Filter comes first in tree order, so Enter in the search field filters rather than running an action.
- `c-bulkhead` is one sticky block below the app header (`top:56px`, like `.c-shell .c-filterbar`), with the filter bar and the bulk bar static inside it. The export makes both bars sticky at their own offsets, which slides the bulk bar under the app header and the filter bar when the page scrolls; one block keeps the count, the actions and Done in view. Because the block sits outside the form, its buttons join it by id.
- The view switch stays outside the form and is inert: Table pressed, Grid disabled.
- Each submission sends `shown_ids[]`, `ticked_ids[]`, the header checkbox (`all`) and how it was rendered (`all_rendered`), with the filter, sort and page it was rendered with. Every id is re-checked against the account.
- The checkbox column is as narrow as its box (`width:1%`); each checkbox's `aria-label` names its row, and a ticked row carries `aria-selected="true"`.
- Scripting only enhances: it updates the count live, shows the header checkbox's mixed state and leaves bulk mode on Esc.
