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
      <p class="c-manacap">Blue 44 · 73% · Red 16 · 27%</p></div>
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
- The mana value is `mtg_cards.mana_value` of spec 058. Spec 060 builds nothing that reads it. How 6+ and half values fall into the seven columns, which faces of a double-faced card count and the order of the card types are #256's, as are hybrid and Phyrexian symbols in the mana bar (spec 060 Non-Goals).
- Card types take a name with its owned and proxy counts.
- The mana bar takes the counts of coloured symbols for W, U, B, R and G. It draws only those five, never generic or colourless symbols, and always in W, U, B, R, G order (spec 060 decision 4).
- The average mana value and the scope line are given as text.
- A part of zero is left out of the markup: a column with no owned has no `c-curve__owned` element, and one with no proxy has no `c-curve__proxy`, so the borders draw no 2px sliver. A colour with no symbols has no segment and is not named in the caption (spec 060 Error Scenarios).
- A deck with no nonland cards shows seven columns of "0" with no bars, the legend "Owned 0 · Proxy 0" and no average line. A deck with only proxies has hatched columns only, and each type's "N proxy" equals its count. A deck with no coloured symbols leaves out the bar and its caption, and the part says "No coloured mana symbols." (spec 060 Error Scenarios).

**The curve** (`c-curve`, spec 060 decisions 1 and 20, AC-2.2, AC-2.3).

- A column is a count above a bar of at most 96px, with the proxy part on top of the owned part, and one baseline in `line-strong` under the seven columns. The mana values 0 to 6+ are labelled under it. The count above a column is owned plus proxy, in mono.
- The numbers are custom properties in a `style` attribute: `--owned`, `--proxy` and `--max` (the tallest column's owned plus proxy), all unitless. The CSS makes a part's height `96px × part ÷ max`. No value in a `style` attribute is a colour.
- Owned is a solid `ink-muted` fill. Proxy is the hatch: lines at 45°, 1.5px wide in `line-strong` every 5px on `surface-raised`, with a 1px `ink-muted` outline. The two outlines share one line.
- Under the chart sit the legend, with a swatch for each series ("Owned 30", "Proxy 6"), and "Average mana value 2.3". Counts, legend and average repeat what the chart shows, so no value is carried by fill or pattern alone.
- The chart is `role="img"` and its `aria-label` reads every column: the scope, the number of nonland cards, then each mana value with its card count and the owned and proxy split, then the average. The columns and the labels are `aria-hidden`, so a screen reader gets the label once. A part of zero is left out of the sentence ("1, 12 cards (11 owned, 1 proxy)"; "0, 4 cards (4 owned)").

**Card types** (`c-types`, spec 060 decision 2, AC-2.5).

- Each type is one row: its name, its count (owned plus proxy, mono) at the end, and, when it has proxies, a muted "N proxy" (mono, 12px, `ink-muted`) after the count. Rows are divided by `line`.
- A type with no proxies keeps an empty `c-types__proxy`. The element has a minimum width of 4.5rem, so the counts of every row line up whether or not a row has a suffix.

**The mana bar** (`c-manabar`, `c-manacap`, spec 060 decisions 3 and 4, AC-2.6, AC-2.7).

- One bar, 32px high, with a 1px `line-strong` outline and `radius-sm` corners, split into segments whose widths are proportional to their symbol counts (`--n`). Consecutive segments are divided by a 1px `line-strong` border.
- Each segment fills with its `mana-*` token and its text is the matching `on-mana-*` token, the same in both themes. The segment's label is its letter and count ("U 44"), in mono.
- A segment under 10% of the symbols adds `c-manabar__seg--narrow`, which hides its label: the server sets the class, with no JavaScript. The caption carries that segment's count.
- The caption (`c-manacap`) names every colour present with its count and its percentage: "Blue 44 · 73% · Red 16 · 27%". In a five-colour deck whose white segment is under 10%, that segment shows no label and the caption still gives white's count and percentage.
- The bar is `role="img"` and its `aria-label` reads the counts ("Coloured mana symbols in Main: blue 44, red 16").
- The `mana-*` fills are used here and in `ManaCost`'s pips only (README Charts rule).

**Colour and contrast** (spec 060 FR-2).

- The panel uses `ink-muted`, `line-strong`, `surface-raised`, `line`, `ink` and, in the mana bar only, `mana-*` with `on-mana-*`. It never uses `brand`, which means an action, and never a status colour. The rule is about the panel's charts and fills: the `details` summary's "Show" or "Hide" is an action, so it is `brand`.
- The panel itself is `surface-raised` with a 1px `line` border, `radius-md` corners, `space-4` padding and `space-6` between its parts. The title is the sans family at 20px and weight 600; the scope line is mono and `ink-muted`.
- Fills and outlines hold 3:1 on `surface`, `surface-raised` and `surface-sunken` in both themes (the tokens' contrast is guarded by spec 057 AC-2.3).

**Width.** The panel works in 279px, the space inside its border and padding when it stacks in a 360px frame (313px wide, 279px inside); every count, the legend and the types fit with no horizontal overflow (spec 060 AC-2.4). Beside the zones it is 320px wide (spec 060 decision 6).

**The two copies** (spec 060 decision 7, AC-3.4). A closed `details` hides its content whatever the CSS says, and `::details-content` would put a browser floor under the page, so the deck page renders the panel twice and each copy hides the other with `display: none`.

- The `aside` copy shows from 640px of the page container. The `details` copy shows below 640px, closed: its summary reads "Deck shape" and the facts line "Main · 60 cards · average mana value 2.3", with "Show" or "Hide" at the end, and is at least 44px high. It works without JavaScript and from the keyboard (Enter or Space).
- The panel's root has no `id`. The `aside` copy's `section` is labelled by its title (`aria-labelledby` points to a title id the view generates); the `details` copy has no title of its own and is named by its `summary`. The hidden copy is not in the tab order or the accessibility tree.
- The `details` copy's panel is `c-shape c-shape--bare`: no outer border, a `line` rule above the parts, because the `details` draws the box.
- Where the copies sit and how the page lays them out is in `DeckPage`.
