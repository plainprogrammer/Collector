# DeckShape

A panel that answers what a deck does from the catalog alone: its mana curve, its card types and the coloured mana symbols of its costs. Shown for Magic: The Gathering; the panel is Magic-specific (spec 060 decision 21).

**Markup** — a `c-shape` section holding a title, a scope line and three `c-shape__part`s in this order: Mana curve, Card types, Mana symbols. The deck page renders the panel twice, as an `aside` and as a closed `details` (see "The two copies").

```html
<aside class="c-deck__shape">
  <section class="c-shape" aria-labelledby="shape-title-aside">
    <div><h2 class="c-shape__title" id="shape-title-aside">Deck shape</h2><p class="c-shape__scope">Main · 60 cards</p></div>
    <div class="c-shape__part"><h3 class="c-shape__heading">Mana curve</h3>
      <div class="c-curve">
        <div role="img" aria-label="Mana curve of the 36 nonland cards in Main: mana value 0, 4 cards (4 owned); 1, 12 cards (11 owned, 1 proxy); … ; 6+, 4 cards (2 owned, 2 proxy). Average mana value 2.3.">
          <div class="c-curve__cols" aria-hidden="true">
            <div class="c-curve__col"><span class="c-curve__count">12</span><div class="c-curve__bar"><div class="c-curve__proxy" style="--proxy:1;--max:12"></div><div class="c-curve__owned" style="--owned:11;--max:12"></div></div></div>
            <!-- six more columns, mana value 0 to 6+; a part of zero has no element -->
          </div>
          <div class="c-curve__labels" aria-hidden="true"><span>0</span><span>1</span><span>2</span><span>3</span><span>4</span><span>5</span><span>6+</span></div>
        </div>
        <ul class="c-curve__legend"><li><span class="c-curve__swatch c-curve__swatch--owned"></span>Owned 30</li><li><span class="c-curve__swatch c-curve__swatch--proxy"></span>Proxy 6</li></ul>
        <p class="c-curve__avg">Average mana value <b>2.3</b></p>
      </div></div>
    <div class="c-shape__part"><h3 class="c-shape__heading">Card types</h3>
      <ul class="c-types"><li><span>Lands</span><span class="c-types__n">24</span><span class="c-types__proxy">2 proxy</span></li><li><span>Artifacts</span><span class="c-types__n">4</span><span class="c-types__proxy"></span></li></ul></div>
    <div class="c-shape__part"><h3 class="c-shape__heading">Mana symbols</h3>
      <ul class="c-manabar" role="img" aria-label="Coloured mana symbols in Main: blue 44, red 16"><li class="c-manabar__seg c-manabar__seg--u" style="--n:44"><span>U 44</span></li><li class="c-manabar__seg c-manabar__seg--r" style="--n:16"><span>R 16</span></li></ul>
      <p class="c-manacap"><span class="c-manacap__item">Blue 44 · 73% ·</span> <span class="c-manacap__item">Red 16 · 27%</span></p></div>
  </section>
</aside>
```

The `details` copy, shown below 640px of the page container, holds the same three parts under a bare panel with no title of its own:

```html
<details class="c-shapefold">
  <summary><span class="c-shapefold__title">Deck shape</span><span class="c-shapefold__facts">Main · 60 cards · average mana value 2.3</span></summary>
  <div class="c-shape c-shape--bare">…the three c-shape__part blocks…</div>
</details>
```

**What the panel is given** (spec 060 AC-2.1, FR-2). The panel draws the numbers it receives and reads no data of its own.

- Figures come from the deck's Main zone and its Commander zone only, never Sideboard or Considering. The scope line says which and how many cards ("Main · 60 cards").
- The curve takes seven `[owned, proxy]` pairs, for mana value 0 to 6+, counting nonland cards. Lands are not in the curve; they are in the card types.
- The mana value is `mtg_cards.mana_value` of spec 058, which spec 069 (#256) reads. Spec 069 settled what spec 060 left to it:
  - **Bucketing:** column `n` from 0 to 5 holds the values from `n` up to but not including `n + 1` (floor, so 0.5 is in column 0 and 2.5 in column 2) and 6+ holds every value from 6 (spec 069 decision 4).
  - **The average** is exact (the mean of the curve's cards, in rational arithmetic), shown to one decimal rounded half up with the trailing zero kept ("3.0") and a thousands delimiter, and is left out when no card is in the curve (decision 5, decision 14).
  - **The order of the types** is the zone tables' groups (`MTG::DeckGroups::NAMES`), only those that have a card, each type once (decision 3).
  - **The cost that counts** is the first face's: a double-faced or split card's symbols are its first face's, and its mana value is Scryfall's number for the card (decision 7).
  - **Symbols:** a hybrid counts one toward each colour, a Phyrexian symbol one toward its colour, `{2/W}` and `{C/W}` one toward the colour only; generic, `{X}`, `{C}`, snow and half symbols never count (decision 8). A percentage is the colour's share, rounded half up on its own (decision 9).
  - **A nonland card with no mana value** is left out of the curve and the average, and a note in a second `c-curve__avg` paragraph after the average line reads "N nonland cards have no mana value yet." ("1 nonland card has no mana value yet."), absent when there is none (decision 6, decision 12).
- Card types take a name with its owned and proxy counts.
- The mana bar takes the counts of coloured symbols for W, U, B, R and G. It draws only those five, never generic or colourless symbols, and always in W, U, B, R, G order (spec 060 decision 4).
- The average mana value and the scope line are given as text.
- A part of zero is left out of the markup: a column with no owned has no `c-curve__owned` element, and one with no proxy has no `c-curve__proxy`, so the borders draw no 2px sliver. A colour with no symbols has no segment and is not named in the caption (spec 060 Error Scenarios).
- A deck with no nonland cards shows seven columns of "0" with no bars, the legend "Owned 0 · Proxy 0" and no average line. A deck with only proxies has hatched columns only, and each type's "N proxy" equals its count. A deck with no coloured symbols leaves out the bar and its caption, and the part says "No coloured mana symbols." (spec 060 Error Scenarios).

**The curve** (`c-curve`, spec 060 decisions 1 and 20, AC-2.2, AC-2.3).

- A column is a count above a bar of at most 96px, with the proxy part on top of the owned part, and one baseline in `line-strong` under the seven columns. The mana values 0 to 6+ are labelled under it. The count above a column is owned plus proxy, in mono. From 1,000 it is abbreviated, one decimal under 10,000 and whole from there ("1.4k", "12k", "1.3m"), half up, never longer than four characters, so it fits a 30px column at a 320px viewport (spec 077 decisions 1 and 5; `MTG::DeckShape#short_count`). The exact column count is in the chart's `aria-label` only; the legend shows the curve's totals. Everything else is exact and delimited: the legend, the types' counts and suffixes, the caption, the zone heads and every `aria-label`.
- The numbers are custom properties in a `style` attribute: `--owned`, `--proxy` and `--max` (the tallest column's owned plus proxy), all unitless. The CSS makes a part's height `96px × part ÷ max`. No value in a `style` attribute is a colour.
- Owned is a solid `ink-muted` fill. Proxy is the hatch: lines at 45°, 1.5px wide in `line-strong` every 5px on `surface-raised`, with a 1px `ink-muted` outline. The two outlines share one line.
- Under the chart sit the legend, with a swatch for each series ("Owned 30", "Proxy 6"), and "Average mana value 2.3" (and, when a nonland card has no mana value, the note as a second `c-curve__avg` paragraph, spec 069 decision 12). Counts, legend and average repeat what the chart shows, so no value is carried by fill or pattern alone.
- The chart is `role="img"` and its `aria-label` reads every column: the scope, the number of nonland cards, then each mana value with its card count and the owned and proxy split, then the average. The columns and the labels are `aria-hidden`, so a screen reader gets the label once. A part of zero is left out of the sentence ("1, 12 cards (11 owned, 1 proxy)"; "0, 4 cards (4 owned)"). With one card the label reads "Mana curve of the 1 nonland card in Main: …", and with none "Mana curve of the 0 nonland cards in Main: no cards." (spec 069 decision 14).

**Card types** (`c-types`, spec 060 decision 2, AC-2.5).

- Each type is one row: its name, its count (owned plus proxy, mono) at the end, and, when it has proxies, a muted "N proxy" (mono, 12px, `ink-muted`) after the count. Rows are divided by `line`.
- The list is a grid of three columns (`minmax(0, 1fr) auto auto`, a `space-2` column gap) and each row is a `subgrid` of it, so the count column is as wide as the widest count and the suffix column as wide as the widest suffix: every count ends at one x whatever a suffix says ("1,234 proxy" is wider than the old 4.5rem minimum). A type with no proxies keeps an empty `c-types__proxy`, which keeps a 4.5rem floor so a list with short suffixes looks as it did. The name cell has `min-width:0` and `overflow-wrap:anywhere`: with a five-digit count and suffix at a 320px viewport ("Planeswalkers 12,345 12,345 proxy") the name wraps inside its cell, even mid-word, and no row passes the list (spec 077 decision 3). Counts and suffix are exact.
- With no card in the counted zones the part keeps its heading and says "No cards yet." in a `c-manacap` paragraph in place of the list (spec 069 decision 14).

**The mana bar** (`c-manabar`, `c-manacap`, `c-manacap__item`, spec 060 decisions 3 and 4, AC-2.6, AC-2.7).

- One bar, 32px high, with a 1px `line-strong` outline and `radius-sm` corners, split into segments whose widths are proportional to their symbol counts (`--n`). Consecutive segments are divided by a 1px `line-strong` border.
- Each segment fills with its `mana-*` token and its text is the matching `on-mana-*` token, the same in both themes. The segment's label is its letter and count ("U 44"), in mono. From 1,000 the count is abbreviated ("W 2.6k": six characters, about 43.5px, which fits one line in the narrowest five-equal-segment bar at a 320px viewport); the caption and the `aria-label` keep the exact count (spec 077 decision 2).
- A segment under 10% of the symbols adds `c-manabar__seg--narrow`, which hides its label: the server sets the class, with no JavaScript. The caption carries that segment's count.
- The caption (`c-manacap`) names every colour present with its count and its percentage: "Blue 44 · 73% · Red 16 · 27%". In a five-colour deck whose white segment is under 10%, that segment shows no label and the caption still gives white's count and percentage. The caption is a run of `c-manacap__item` spans, "Blue 44 · 73% ·" and, last, "Red 16 · 27%", separated by one space, each `white-space:nowrap`: a line breaks only between colours, so no line begins with "·" and a name never parts from its count; the paragraph's text is the same string as before (spec 077 decision 4; `MTG::DeckShape#caption_items`).
- The bar is `role="img"` and its `aria-label` reads the counts ("Coloured mana symbols in Main: blue 44, red 16").
- With no coloured symbol the part has no bar and no caption and says "No coloured mana symbols." in a `c-manacap` paragraph (spec 069 decision 14).
- The `mana-*` fills are used here and in `ManaCost`'s pips only (README Charts rule).

**Colour and contrast** (spec 060 FR-2).

- The panel uses `ink-muted`, `line-strong`, `surface-raised`, `line`, `ink` and, in the mana bar only, `mana-*` with `on-mana-*`. It never uses `brand`, which means an action, and never a status colour. The rule is about the panel's charts and fills: the `details` summary's "Show" or "Hide" is an action, so it is `brand`.
- The panel itself is `surface-raised` with a 1px `line` border, `radius-md` corners, `space-4` padding and `space-6` between its parts. The title is the sans family at 20px and weight 600; the scope line is mono and `ink-muted`.
- Fills and outlines hold 3:1 on `surface`, `surface-raised` and `surface-sunken` in both themes (the tokens' contrast is guarded by spec 057 AC-2.3).

**Width.** The panel works in 238px, the space inside its border and padding at a 320px viewport (a phone's 320px less 16px body margin, 32px page padding, 2px border and 32px panel padding), and every count, the legend, the types and the mana labels fit with no horizontal overflow at the worst-case counts of spec 069's fixture (spec 077 AC-1.3, AC-2.2, AC-3.1). It was drawn for 279px (spec 060 AC-2.4); the measured interiors are 238px (a 320px viewport), 263px (a 360px browser frame, which keeps a 15px scrollbar a phone doesn't), 278px (a 360px viewport) and 286px (the 320px aside; beside the zones the panel is 320px wide, spec 060 decision 6). **Known limits:** (1) a mana segment narrower than its label: a label of four characters ("U 44") needs about 14% of the bar, five ("W 999") about 17% and six ("W 2.6k") about 20% at a 320px viewport (measured to the half percent on a 236px bar), and the rule hides a label only under 10% (spec 060 decision 4), so a segment between 10% and those shares wraps its label and cuts it off; the caption carries the count; it exists at ordinary counts too, and is [#330](https://github.com/plainprogrammer/Collector/issues/330) (spec 077 decision 2, ruled option A). (2) A Card types row with a five-digit count and suffix at a 320px viewport wraps its name, even mid-word; counts of six digits are not specified.

**The two copies** (spec 060 decision 7, AC-3.4). A closed `details` hides its content whatever the CSS says, and `::details-content` would put a browser floor under the page, so the deck page renders the panel twice and each copy hides the other with `display: none`.

- The `aside` copy shows from 640px of the page container. The `details` copy shows below 640px, closed: its summary reads "Deck shape" and the facts line "Main · 60 cards · average mana value 2.3", with "Show" or "Hide" at the end, and is at least 44px high. It works without JavaScript and from the keyboard (Enter or Space).
- The panel's root has no `id`. The `aside` copy's `section` is labelled by its title (`aria-labelledby` points to a title id the view generates); the `details` copy has no title of its own and is named by its `summary`. The hidden copy is not in the tab order or the accessibility tree.
- The `details` copy's panel is `c-shape c-shape--bare`: no outer border, a `line` rule above the parts, because the `details` draws the box.
- Where the copies sit and how the page lays them out is in `DeckPage`.
