# ImageFit

How a card image sits in its slot: whole and in its own proportions, never cropped or stretched. It overrides the export until the published design system fits images this way.

**Markup** — unchanged. The rule applies to the image in each of the three slots: the tile's, the card page's and the table thumbnail's.

```html
<div class="c-tile__media"><img src="…" alt="Lightning Bolt" loading="lazy" width="146" height="204"></div>
<div class="c-item__image"><img src="…" alt="Lightning Bolt" width="300" height="419"></div>
<img class="c-table__thumb" src="…" alt="" width="24" height="34" loading="lazy">
```

- A slot keeps the card's 63:88 shape whatever the image's proportions, so grid rows and table rows line up and nothing moves when an image loads.
- The image is scaled to the largest size that fits inside the slot and centred. Where its proportions differ from 63:88, the leftover shows the slot's `surface-sunken` ground, equal on both sides.
- Never use `object-fit: cover` or `fill` on an item's image, and never size a slot from its image. A source's terms may forbid cropping or distorting its images; Scryfall's do.
- The thumbnail's `width` and `height` attributes are layout hints only. Its height comes from 63:88 of its 24px width, so it matches the empty thumbnail shown when there is no image.
- The card page's slot is positioned, so the missing-image fallback (`c-tile__missing`) stays inside its own slot and never lies over another face's image.
- A new image slot (a comic's cover, a deck's card list) follows the same rule: a fixed slot, with the whole image inside it.
- This overrides the export, whose `c-tile__media` and `c-item__image` crop with `cover` and whose `c-table__thumb` stretches the image to its box. Upstream it; once an export carries it, delete the block from `collector/additions.css`.
