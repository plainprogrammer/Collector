# ItemTile

One collected item in the image grid, the default collection view: image, quantity, flags, name, set and location.

**Markup** — the consumer provides the link to the item, an image (or the missing-image fallback), the owned quantity, up to two flag badges, the name, a set-code tag and the location.

```html
<div class="c-collection"><div class="c-grid">
  <a class="c-tile" href="/items/123">
    <div class="c-tile__media">
      <img src="…" alt="Lightning Bolt" loading="lazy">
      <span class="c-tile__qty">×4</span>
      <span class="c-tile__flags"><span class="c-badge c-badge--foil">…Foil</span></span>
    </div>
    <div class="c-tile__name">Lightning Bolt</div>
    <div class="c-tile__meta"><span class="c-tag">2X2 · 117</span><span>Binder 2</span></div>
  </a>
</div></div>
```

**Modifiers**: `c-tile--comic` keeps the same slot as a card (so mixed rows line up) and shows the whole cover inside it, uncropped, with square-ish corners; `c-tile--owned-none` fades an item you don't own (wishlist, set checklist). Tiles are never selectable: bulk actions happen in `CollectionTable`. `c-grid--compact` fits more per row.

- Card images keep 63:88 and the physical corner (`radius-card`); never crop art to fit.
- Always show the quantity, even ×1, so the grid answers "how many" without a click.
- Location sits under the name: players need "where is it" as much as "what is it".
- With no image, keep the fallback (name on `surface-sunken`) rather than a generic placeholder picture.
- Choosing a bulk action from the grid switches to the table with the same search and filters (see `CollectionTable`).
- Phones get two columns by default and three with `c-grid--compact`; the grid needs no breakpoints of its own.
- For thousands of items, lazy-load images (`loading="lazy"`) and paginate or infinite-scroll in pages of about 120.
