# ItemPage

One card in your collection, at desktop width: the card image, its rules text, what you own, every printing, the decks using it and where it is legal. Shown here for a Magic: The Gathering card.

**What the page provides**: the card's data (name, type line, mana cost, rules text, printings, legality; from your card data source, e.g. MTGJSON), the collector's copies grouped into lots, the decks that use it, and the image of the printing being shown.

```html
<body class="c-shell">
  <header class="c-appbar c-appbar--detail">…back link, brand, nav, avatar…</header>
  <main class="c-main c-page">
    <ol class="c-crumbs">…Collection / Trading cards / Lightning Bolt…</ol>
    <div class="c-item">
      <div class="c-item__media"><div class="c-item__image"><img …></div><p class="c-item__caption">Showing your 2X2 · 117 foil</p></div>
      <div class="c-item__body">
        <div class="c-item__head">…c-item__title, c-item__type (category chip, type line, ManaCost), c-item__actions…</div>
        <p class="c-rules">…rules text…</p>
        <dl class="c-stats">…Owned, In decks, Free to use, Est. value…</dl>
        <section>…Your copies (c-table in .c-collection)…</section>
        <section>…Printings…</section>
        <div class="c-split"><section>…In decks (c-list)…</section><section>…Format legality (c-legality)…</section></div>
      </div>
    </div>
  </main>
</body>
```

**Order of sections** (most-used first): stats, your copies, printings, decks, legality. Keep this order for every card game; a game without formats simply drops the legality section.

- **Stats** answer the player's question first: how many you own, how many are in decks, how many are free to use, and what they're worth. A physical copy can be in only one deck, so "Free to use" is simply owned minus in decks.
- **Your copies** are lots: one row per printing + finish + condition + language + location. A deck is a location, so copies in a deck appear here with the deck's name. Each row has its own "…" menu (edit, move, remove); `Edit many` goes to bulk mode for this card's lots.
- **Printings** lists every known printing. Ones you don't own are muted with an `Add` ghost button, which makes this the fastest way to add a specific printing. The printing shown in the image is tagged `Shown`; clicking a row shows that printing's image.
- **In decks** names each deck, its format and board, and how many copies it uses.
- **Format legality**: `Legal` in `success` with a check; `Not legal` in `ink-muted` with a cross, never red, because not being legal in a format is information, not an error.
- The image column is sticky on desktop so the card stays in view while you scroll its data.

**Magic-specific rules**

- Mana cost uses the `ManaCost` pips (Collector's own coloured circles with letters), never Wizards' mana symbols.
- Rarity is a word (Common, Uncommon, Rare, Mythic), never a set symbol or a rarity colour.
- Set codes and collector numbers are always `SET · number` in mono.
- The category chip reads "Magic: The Gathering", not just "Trading cards", on a card's own page.
- The image in this mock is a flat placeholder; prices and printings are illustrative.
