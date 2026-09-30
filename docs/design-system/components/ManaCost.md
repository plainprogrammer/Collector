# ManaCost

Collector's own mana display for Magic costs: coloured circles with a letter or number. It is not Wizards of the Coast's symbol set and must never imitate it.

**Markup** — the consumer provides one `c-mana` per symbol in the cost, in printed order, and an `aria-label` that reads the whole cost aloud. The pips themselves are `aria-hidden`.

```html
<span class="c-cost" role="img" aria-label="Mana cost: 3 generic, 1 green, 1 green">
  <span class="c-mana" aria-hidden="true">3</span>
  <span class="c-mana c-mana--g" aria-hidden="true">G</span>
  <span class="c-mana c-mana--g" aria-hidden="true">G</span>
</span>
```

- **Colours**: `c-mana--w` white, `--u` blue, `--b` black, `--r` red, `--g` green; no modifier for generic numbers, X and colourless (C). The fills are data colours (`mana-*` tokens), identical in both themes, and are never used anywhere else in the UI.
- **The letter always shows.** Colour is never the only signal: W, U, B, R, G, C, X or the number. Every letter holds at least 5.5:1 on its fill.
- Every pip has a 1px `line-strong` outline, so white and colourless stay visible on paper and black stays visible in the dark theme.
- **Sizes**: 20px inline (type lines, tables); `c-cost--lg` 24px next to a page title. Nothing smaller, so the letters stay at 12px or more.
- **Our own design, not theirs**: plain circles, a letter, a flat fill. No sun, droplet, skull, flame or tree shapes, no bevels or shading.
- **In Rails**, a `mana_cost("{3}{G}{G}")` helper should parse the card data's cost string into pips and build the `aria-label`.
- **Not designed yet**: hybrid (`{W/U}`), Phyrexian (`{G/P}`) and snow costs. Until they are, show those symbols as text in a `c-tag` (`{W/U}`) beside the pips.
