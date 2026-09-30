# SingleStat

A stats block with one stat, for pages where the export's four-up stats grid would leave three empty cells.

**Markup** — the export's `c-stats` markup with the `c-stats--single` modifier and one `c-stat`.

```html
<dl class="c-stats c-stats--single">
  <div class="c-stat"><dt>Owned</dt><dd>4</dd><small>2 printings</small></div>
</dl>
```

- One column, at most 240px wide on wide pages; below 640px of the page container it takes the full width. It never becomes a 2 × 2 grid.
- The number is exact and uses `number_with_delimiter` ("1,204"); the small line qualifies it with the right plural ("1 printing", "2 printings").
- Use it only while there is one stat worth showing; when more arrive, switch back to the plain `c-stats` grid.
