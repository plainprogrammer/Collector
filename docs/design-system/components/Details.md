# Details

A list of labelled facts about an item, such as a card printing's set, language, rarity, finishes, release date and artist.

**Markup** — a `<dl class="c-details">` with each term and value wrapped in a `<div>`; the consumer marks codes with `is-data` and can put a `c-tag` inside a value.

```html
<dl class="c-details">
  <div><dt>Set</dt><dd>Magic 2010 <span class="c-tag">M10 · 146</span></dd></div>
  <div><dt>Language</dt><dd class="is-data">EN</dd></div>
  <div><dt>Rarity</dt><dd>Common</dd></div>
  <div><dt>Finishes</dt><dd>Nonfoil, Foil</dd></div>
  <div><dt>Released</dt><dd>July 17, 2009</dd></div>
  <div><dt>Artist</dt><dd>Christopher Moeller</dd></div>
</dl>
```

- The grid fills as many 180px-minimum columns as fit, so it needs no breakpoints; on a phone it is one or two columns.
- Labels are small, semibold and `ink-muted`; values are regular `ink`. Codes (language, set numbers) are mono through `is-data`.
- Rarity and finishes are words, never symbols or colours.
- A fact the data doesn't have says "Unknown" rather than leaving the value blank; a fact that doesn't apply is left out.
- The collectible's extension renders its own list (for Magic, `mtg/printings/_details`); the core page only places it.
