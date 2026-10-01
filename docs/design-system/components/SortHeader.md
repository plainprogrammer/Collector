# SortHeader

A table header that states the column's order and leads to the next one, so the collection table can be sorted by any of its sortable columns.

**Markup** — the consumer puts one `c-table__sort` control in each sortable `th` and gives every sortable `th` an `aria-sort`. Outside bulk mode the control is a link; in bulk mode it is a submit button of the bulk form (see `BulkForm`), so the ticks go along.

```html
<!-- outside bulk mode -->
<th aria-sort="ascending"><a class="c-table__sort" href="/collection?dir=desc&amp;sort=name&amp;view=table">Name</a></th>
<th class="is-opt" aria-sort="none"><a class="c-table__sort" href="/collection?dir=asc&amp;sort=set&amp;view=table">Set</a></th>
<th class="is-num" aria-sort="descending"><a class="c-table__sort" href="/collection?dir=asc&amp;sort=quantity&amp;view=table">Qty</a></th>

<!-- in bulk mode -->
<th aria-sort="ascending"><button type="submit" name="go" value="/collection?bulk=1&amp;dir=desc&amp;sort=name" class="c-table__sort">Name</button></th>
```

- The arrow comes from `aria-sort` alone (`↑` ascending, `↓` descending, nothing for `none`), so what screen readers hear and what is shown can't disagree. Never add an arrow to the label.
- Exactly one header is `ascending` or `descending`; the default order reads as Name ascending. Every other sortable header is `none`, and a column that can't be sorted has no `aria-sort` and no control.
- Activating the sorted header reverses it; activating another header sorts that column ascending. The order lives in the URL (`?sort=…&dir=…`) with the current filter, so it can be linked and the back button restores it.
- The control looks like the header text (no underline, no button chrome), turns `brand` on hover and shows the focus ring. In an `is-num` column the arrow sits before the label, so the label stays right-aligned with the numbers.
