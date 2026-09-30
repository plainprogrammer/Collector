# Chip

Three small labels: the category chip, the toggleable filter chip, and the monospace set-code tag.

**Category chip** (`c-chip c-chip--cards|comics|other`) names an item's category in its accent colour on its tint. It is a label, not a control. Always include the category name; the dot alone is not enough.

**Filter chip** (`c-filter`) is a `<button>` with `aria-pressed`; pressed turns `brand-tint` with a `brand` border and a check icon. Use for quick on/off filters in the filter bar.

**Tag** (`c-tag`) is for data: set code and collector number (`MH3 · 214`), condition (`NM`), language. Plex Mono so codes align.

```html
<span class="c-chip c-chip--comics"><span class="c-chip__dot"></span>Comics</span>
<button class="c-filter" aria-pressed="true"><svg …/>Owned</button>
<span class="c-tag">MH3 · 214</span>
```

- Don't use a category chip as a button or a filter; filters are always `c-filter`, in brand colours.
- A new community category uses `c-chip--other` until it has its own accent.
