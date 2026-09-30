# SearchResults

Search results grouped by card: one heading per card, with its printings as a tile grid under it, and a line of result facts above the groups.

**Markup** — inside the results Turbo Frame, the consumer provides a `c-results__meta` line (the count and the catalog's freshness), then one `c-group` per card: a `c-section__head` with the card name, the printing count and an optional "Show all N printings" link, then a `c-grid` of `TileAdd` cells.

```html
<turbo-frame id="results" target="_top" data-turbo-action="advance">
  <div class="c-results__meta">
    <span class="c-filterbar__count">3 cards</span>
    <span class="c-results__freshness">Catalog updated September 27, 2026</span>
  </div>
  <section class="c-group" aria-labelledby="heading_catalog_identity_1">
    <div class="c-section__head">
      <h2 class="c-section__title" id="heading_catalog_identity_1">Lightning Bolt</h2>
      <span class="c-section__count">34 printings</span>
      <span class="c-section__actions"><a class="c-btn c-btn--ghost c-btn--sm" href="/catalog/identities/…">Show all 34 printings</a></span>
    </div>
    <div class="c-grid">…TileAdd cells…</div>
  </section>
  <nav class="c-pager" aria-label="Pagination">…</nav>
</turbo-frame>
```

- The meta line sits directly beneath the filter bar, inside the frame, so it updates with every search without scripting.
- The count states the number of cards found exactly ("1 card", "3 cards"); freshness is muted `ink-muted` text and never an alert.
- Each group is a labelled section: `aria-labelledby` points at its heading.
- A group shows at most 10 printings; "Show all N printings" appears only when there are more, and leads to the card's printings page.
- Groups are spaced with `space-6`; the grid needs no breakpoints of its own (see `ItemTile`).
