# Badge

Small status markers on tiles and rows: foil/special, and success, warning or danger states.

**Markup** — the consumer provides a 12px icon and a one- or two-word label; both are required, because colour alone never carries meaning. The icon's stroke is 2.5, set by `additions.css` for `c-badge svg` (spec 063), not by its `stroke-width` attribute, which stays 1.5.

```html
<span class="c-badge c-badge--foil"><svg …/>Foil</span>
<span class="c-badge c-badge--warning"><svg …/>Price changed</span>
```

- `c-badge--foil` is the only badge with a solid fill: gold is for things that are special. At most one per tile.
- Status badges are outlined in their colour on `surface-raised`, so they stay readable over images.
- Don't invent new badge colours; add a word instead.
