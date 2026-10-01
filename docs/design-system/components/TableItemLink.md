# TableItemLink

The card name in a collection table row, as a link to the card's page in the one action colour.

**Markup** — the name link sits in the `c-table__item` cell beside the thumbnail, with the phone-only summary (`c-table__sub`) after it.

```html
<td>
  <div class="c-table__item">
    <img class="c-table__thumb" src="…" alt="" width="24" height="34" loading="lazy">
    <div><a href="/catalog/entries/123?from=collection">Lightning Bolt</a><span class="c-table__sub">M10 · 146 · Foil · NM · EN</span></div>
  </div>
</td>
```

- The link is `brand` with no underline, so the table reads as data rather than a page of browser-default links; it underlines on hover.
- It shows the focus ring (`focus`, 2px, offset 2px) when reached by keyboard.
- `brand` stays the one action colour: the name is the row's only link, and the row's other cells are plain text.
