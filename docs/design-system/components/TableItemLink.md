# TableItemLink

The card name in a collection table row, as a link to the card's page in the one action colour.

**Markup** — the name link sits in the `c-table__item` cell beside the thumbnail, with the phone-only summary (`c-table__sub`) after it.

```html
<td>
  <div class="c-table__item">
    <img class="c-table__thumb" src="…" alt="" width="24" height="34" loading="lazy">
    <div class="c-table__name"><a href="/catalog/entries/123?from=collection">Lightning Bolt</a><span class="c-table__sub">M10 · 146 · Foil · NM · EN</span></div>
  </div>
</td>
```

- **The name gives in the wide table just above the breakpoint (issue #208):** for containers of 640 to 699px, the link in `c-table__name` is clamped to one line with an ellipsis, so a name that the other columns leave no room for is cut and the table stays inside `.c-collection`. The clamp is an app addition in `additions.css` (`@container collection (min-width: 640px) and (max-width: 699px)`). The `div` lets the name wrap in the table's auto layout (`white-space:normal`, `overflow-wrap:anywhere`) so the column's minimum is a few characters while its natural width is unchanged; a `width`, `max-width` or `contain` on the cell would also zero the natural width and narrow the column in wide layouts. The clamp is on the link, so the focus ring is not clipped and focusing it moves nothing. From 700px up the name is whole, as a long place name (spec 048) makes the Location cell give instead; below 640px the name stays whole and `c-table__sub` carries the rest. Other tables with a `c-table__item` cell (admin jobs, a card's copies) don't take the class and are unchanged.

- The link is `brand` with no underline, so the table reads as data rather than a page of browser-default links; it underlines on hover.
- It shows the focus ring (`focus`, 2px, offset 2px) when reached by keyboard.
- `brand` stays the one action colour: the name is the row's only link, and the row's other cells are plain text.
