# TileAdd

A tile in search results or a card's printings with an add button beside its link, so one tap adds a copy.

**Markup** — the consumer provides the tile (as `ItemTile`) and a `button_to` form after it, never inside the link.

```html
<div class="c-tilecell" id="tile_catalog_entry_1">
  <a class="c-tile c-tile--owned-none" href="/catalog/entries/…">…ItemTile content…</a>
  <form class="c-tile__add" data-turbo-frame="_top" method="post" action="/catalog/entries/…/quick_add">
    <button class="c-btn c-btn--ghost c-btn--sm" aria-label="Add 1 × Lightning Bolt (M10 · 146)" type="submit"><svg …/>Add</button>
    <input type="hidden" name="return_to" value="/catalog/entries?q=bolt">
  </form>
</div>
```

- The button is outside the link: nested interactive elements are invalid and unusable by keyboard.
- Its accessible name says exactly what is added: quantity, card name and `SET · number`.
- It posts a form (works without JavaScript) and returns to the same URL; Turbo morphs the page so scroll and focus stay.
- Owned tiles show `c-tile__qty`; tiles you don't own use `c-tile--owned-none` and no quantity.
- The button spans the cell's width with its label at the start; in a `c-list` row (the card page's printings) it keeps its natural width.
