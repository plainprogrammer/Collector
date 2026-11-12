# SingleStat

A stats block with one stat, for pages where the export's four-up stats grid would leave three empty cells. The card page used it while it had one stat; since spec 073 it uses `c-stats--three`; keep the pattern for a page with one stat.

**Markup** — the export's `c-stats` markup with the `c-stats--single` modifier and one `c-stat`.

```html
<dl class="c-stats c-stats--single">
  <div class="c-stat"><dt>Owned</dt><dd>4</dd><small>2 printings</small></div>
</dl>
```

- One column, at most 240px wide on wide pages; below 640px of the page container it takes the full width. It never becomes a 2 × 2 grid.
- The number is exact and uses `number_with_delimiter` ("1,204"); the small line qualifies it with the right plural ("1 printing", "2 printings").
- Use it only while there is one stat worth showing; when more arrive, use `c-stats--three` for three and the plain `c-stats` grid for four. The card page no longer uses it (spec 073).
- For three stats use `c-stats c-stats--three` instead (three equal columns at every width; see `ItemPage`).
