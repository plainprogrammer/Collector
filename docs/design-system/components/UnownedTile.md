# UnownedTile

A tile for a card you don't own, in search results and a card's printings: the card image exactly as supplied, a dashed frame, and the words "Not owned" under it. It overrides the export, whose `ItemTile` fades such a tile's image to 45%.

**Markup** — the consumer adds `c-tile--owned-none` to the tile and a second `c-tile__meta` row holding one `c-tag`, as the last thing inside the link. No quantity badge.

```html
<div class="c-tilecell" id="tile_catalog_entry_1">
  <a class="c-tile c-tile--owned-none" href="/catalog/entries/…">
    <div class="c-tile__media"><img src="…" alt="Lightning Bolt" loading="lazy" width="146" height="204"></div>
    <div class="c-tile__name">Lightning Bolt</div>
    <div class="c-tile__meta"><span class="c-tag">M10 · 146</span><span class="c-tag">EN</span></div>
    <div class="c-tile__meta"><span class="c-tag">Not owned</span></div>
  </a>
  <form class="c-tile__add" …>…</form>
</div>
```

- Never fade, filter, tint or blend a card image, and never lay anything over it to show a state. A source's terms may forbid altering its images; Scryfall's do ("Do not blur, sharpen, desaturate, or color-shift card images. Do not add your own watermarks, stamps, or logos to card images."). State is said in words beside the image.
- The image and the missing-image fallback (`c-tile__missing`) are shown at full opacity. The fallback is not a card image, but it is marked the same way so every unowned tile reads alike and its text keeps its contrast.
- The copy is exactly "Not owned": sentence case, no punctuation. It is visible text inside the link, so a screen reader hears it as part of the tile's name; don't add an `aria-label` or hidden text for it.
- The dashed `line-strong` frame is the export's and stays. It frames the slot and doesn't touch the image. It is never the only signal: the words are.
- An owned tile is unchanged: `c-tile__qty` on the image, no marker row.
- An unowned tile is one line taller than an owned one. Inside `c-tilecell` the add control sits at the foot of the cell, so the buttons of a row that mixes the two stay level; that rule is `TileAdd`'s and is documented there.
- Rows mark the same state with `ink-muted` text (`c-table tr.is-unowned`, `c-list li.is-unowned`); they show no image and are not part of this pattern.
- A wishlist or set checklist built later uses this pattern, not the fade.
- This overrides the export: `components.css` still carries `.c-tile--owned-none .c-tile__media > img, .c-tile--owned-none .c-tile__missing { opacity:.45; }`, and the exported `ItemTile.md` still says the modifier "fades an item you don't own". Where it differs from this document, this one holds. Upstream it: at its next export the published design system's `ItemTile` should drop the fade and take the marker row. Once an export carries that, delete the opacity rule from `collector/additions.css` and bring `spec/design_system_files_spec.rb`'s two examples for this block in line (one pins the export's `opacity:.45`); the add control's rule and the browser examples (`spec/system/unowned_tile_spec.rb`) stay as they are.
