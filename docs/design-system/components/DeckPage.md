# DeckPage

One deck at desktop and phone width: its zones as tables and, beside or above them, the shape panel. Shown for a Magic: The Gathering deck; the shell is collectible-agnostic (spec 060 decision 21).

**As built (specs 068, 069 and 070, #254, #256 and #257, on spec 066's page):** the page head's line reads `Format · N cards · N owned · N proxy`; a zone's head is its name, `N cards · N owned · N proxy` and "Add a proxy" (a link to the add-a-proxy pages, `AddProxy`); the table has Card, Cost, Owned, Proxy, Total and the row menu; a row with proxies shows the `ProxyTag` in its Proxy cell and in the line under its name on a phone, and its menu lists "Use my copy", "Add a new copy", "Change proxy count" and, after a separator, "Remove proxy" (spec 070, #257; the finish named in each item when the row has proxies of two finishes); a row with no proxy has an empty menu cell; a printing with a proxy and no owned copy is a row of Owned 0; Total is owned plus proxy and a group row's count is its Total; the card name links to the card page at its copies (`/catalog/entries/:key?from=collection#copies`). The page has no `form` (every action is a link). Spec 069 (#256) renders the shape panel when the deck's collectible draws one: the `details` copy, then the `aside` copy, then the zones, inside `c-deck` (the core partial `decks/_shape` draws each copy's frame, the extension's partial the three parts), so the second column holds the panel from 992px; a deck whose collectible draws none renders neither copy and leaves the column empty. The page's `main` carries `c-deckpage`, whose only rules let the head's name wrap anywhere (`overflow-wrap:anywhere`, `min-width:0`) so a 60-character deck name with no space stays inside a 360px screen. A group is its own `tbody` whose first row is the `th scope="rowgroup"` group row (a collectible that groups nothing gets one `tbody` and no group row)

**What the page provides**: the deck's name, its format and counts, its zones with their rows, and the extension's contribution. The shell's rules below name no format and no game. The extension supplies the shape panel (`DeckShape`), the Cost column (`ManaCost` or a muted dash), the legality marker and the groups of a zone's rows; the sample's groups are a Magic deck's top-level card types.

**Markup** — a detail page (`c-appbar--detail`): a page head in `c-item__head`'s pattern, then `c-deck` holding, in DOM order, the `details` copy of the panel, the `aside` copy, and the zones. The grid places the zones in the first column and the `aside` in the second, so tab order and reading order agree at every width.

```html
<header class="c-appbar c-appbar--detail">…back link, brand, nav, avatar…</header>
<main class="c-main c-page">
  <div class="c-item__head">
    <div>
      <h1 class="c-item__title">Izzet Tempo</h1>
      <p class="c-item__type">Modern · 69 cards · 58 owned · 11 proxy</p>
    </div>
    <div class="c-item__actions">
      <a class="c-btn c-btn--secondary" href="#">Edit deck</a>
      <details class="c-menu"><summary class="c-btn c-btn--secondary c-btn--icon" aria-label="More actions"><svg …three dots…/></summary>
        <div class="c-menu__list"><a class="c-menu__item" href="#">Change format</a><div class="c-menu__sep"></div><a class="c-menu__item c-menu__item--danger" href="#">Remove deck</a></div></details>
    </div>
  </div>
  <div class="c-deck">
    <details class="c-shapefold">…DeckShape, the details copy…</details>
    <aside class="c-deck__shape">…DeckShape, the aside copy…</aside>
    <div class="c-deck__zones">
      <section class="c-zone">
        <div class="c-section__head"><h2 class="c-section__title">Main</h2><span class="c-section__count">60 cards · 52 owned · 8 proxy</span><div class="c-section__actions"><a class="c-btn c-btn--ghost c-btn--sm" href="#"><svg …plus…/>Add a proxy<span class="c-sr"> to Main</span></a></div></div>
        <div class="c-collection"><table class="c-table"><thead><tr>
          <th>Card</th><th class="c-zone__c-cost">Cost</th><th class="c-zone__c-owned is-num is-opt">Owned</th><th class="c-zone__c-proxy is-num is-opt">Proxy</th><th class="c-zone__c-total is-num">Total</th><th class="c-zone__c-menu"><span class="c-sr">Actions</span></th></tr></thead>
        <tbody>
          <tr class="c-zone__group"><th scope="rowgroup" colspan="6">Creatures<span class="c-zone__groupcount">12</span></th></tr>
          <tr><td><div class="c-table__item"><div><a href="#">Murktide Regent</a><span class="is-opt"><br><span class="c-zone__set">MH2 · 52</span></span><span class="c-table__sub"><span class="c-zone__set">MH2 · 52</span> <span class="c-proxy">Proxy <b>2</b></span></span></div></div></td>
            <td><span class="c-cost" role="img" aria-label="Mana cost: 5 generic, 1 blue, 1 blue">…pips…</span></td><td class="is-num is-opt">2</td><td class="is-num is-opt"><span class="c-proxy">Proxy <b>2</b></span></td><td class="is-num">4</td>
            <td class="c-table__actions"><details class="c-menu" open>…TableActions, trigger "Actions for Murktide Regent MH2 · 52"…</details></td></tr>
          <tr><td><div class="c-table__item"><div><a href="#">Ragavan, Nimble Pilferer</a><span class="is-opt"> <span class="c-legal c-legal--no">…cross…Banned</span></span><span class="is-opt"><br><span class="c-zone__set">MH2 · 138</span></span><span class="c-table__sub"><span class="c-zone__set">MH2 · 138</span> <span class="c-legal c-legal--no">…cross…Banned</span></span></div></div></td>
            <td><span class="c-cost" role="img" aria-label="Mana cost: 1 red">…pips…</span></td><td class="is-num is-opt">4</td><td class="is-num is-opt"><span class="is-muted">–</span></td><td class="is-num">4</td>
            <td class="c-table__actions"><details class="c-menu">…TableActions, trigger "Actions for Ragavan, Nimble Pilferer MH2 · 138"…</details></td></tr>
        </tbody></table></div>
      </section>
      <!-- Sideboard, Considering: the same markup -->
    </div>
  </div>
</main>
```

A card that is not legal in the deck's format has its `<span class="c-legal c-legal--no">…cross…Banned</span>` written twice, as the set is: after its name link inside `<span class="is-opt"> …</span>` and again at the end of the `c-table__sub` line (the sample shows both on its Ragavan, Nimble Pilferer row, which is Banned, and on its Pyroblast and Spell Queller rows, which are Not legal; Murktide Regent, the proxy row with the open menu, has none). A card with no cost, or no proxy, shows `<span class="is-muted">–</span>` in that cell. An empty zone replaces the table with `<p class="c-zone__empty">No cards in Sideboard yet.</p>`.

**Widths** (spec 060 decisions 6 and 7, FR-3). The deck's layout answers to its page container (`.c-page`, `@container page`), not the viewport.

- **992px of the page container and wider:** two columns. The zones take the first column (`minmax(0, 1fr)`), the panel the second at 320px, with a `space-8` gap. The panel is `position: sticky`, its top at the header's 56px plus `space-6`, so it stays in view while the zones scroll (AC-3.2). 992px is the zone table's 640px, the panel's 320px and the 32px gap.
- **640px to 991px:** one column, the `aside` copy of the panel above the zones, open, as wide as the zones, with no summary and not sticky (AC-3.3). The gap is `space-6`.
- **Below 640px:** the `aside` copy is not displayed and the `details` copy is: closed, above the zones, its summary reading "Deck shape" and its facts, at least 44px high (AC-3.4). From 640px the `details` copy is not displayed. The reason for two copies and their ids are in `DeckShape`.
- **No shape panel** (a deck whose collectible draws no panel): leave out both copies. From 992px the zones keep the first column's width and the second column stays empty; below 992px the page is one column of zones with neither the `aside` nor the `details` (AC-3.12).
- The page has no horizontal overflow at 360px.

**The page head** (spec 060 decision 10). The deck's name in `c-item__title`; a muted line `c-item__type` reading "Modern · 69 cards · 58 owned · 11 proxy" (format, then the counts of every zone, Considering included: owned plus proxy is the cards, spec 060 decision 12); the actions "Edit deck" (secondary) and a "…" `Menu` holding "Change format" and then, after a `c-menu__sep`, "Remove deck" (`c-menu__item--danger`, last, to a `ConfirmPage`). The head wraps its actions below 640px as the card page's head does (`ItemPage`). The page is a detail page: `c-appbar--detail`, with a back arrow on phones.

**A zone** (spec 060 decision 10, AC-3.7, AC-3.9).

- A zone's head is `c-section__head`: its name, the muted counts "60 cards · 52 owned · 8 proxy" (a single card reads "1 card") and "Add a proxy" at the end (ghost, small, with a plus). The button's visible text is "Add a proxy"; a `c-sr` tail " to Main" names the zone for screen readers. It has the 44px touch floor at every pointer (`.c-deckpage .c-section__actions .c-btn`, spec 068 NFR Accessibility).
- From 640px of the page container the head is one line. Below it the name and "Add a proxy" share the first line and the counts take their own line, uncut: a cut count is information lost.
- Zones stack in a column with a `space-8` gap.
- An empty zone keeps its head with the counts "0 cards · 0 owned · 0 proxy" and "Add a proxy", and shows "No cards in Sideboard yet." in a `surface-sunken` block (`c-zone__empty`) instead of a table.

**The zone table** (spec 060 decisions 9 and 25, AC-3.5, AC-3.6, AC-3.11). It is `CollectionTable`'s pattern: a `c-table` in `.c-collection`, numeric cells `is-num`, columns that drop on phones `is-opt`.

- Columns, in order: Card, Cost, Owned, Proxy, Total and the row menu. Do not add a column.
- Card: the name as `TableItemLink` documents, a plain `div` inside `c-table__item` and no thumbnail, with `set · number` under it in mono, `ink-muted` (`c-zone__set`). The Card cell wraps its name at every width (`white-space: normal`, `overflow-wrap: anywhere`), so a 60-character name with no space stays inside the cell instead of spilling into Cost. The 640px to 699px clamp that `TableItemLink` describes belongs to `c-table__name` and is not used here.
- Cost: the extension's cost display (the sample uses `ManaCost`), or a muted dash for a card with no cost. The cost wraps inside the cell at every width (`flex-wrap: wrap` on `c-cost`), so a long cost never spills into the next cell or widens the table. A cost of up to four symbols never wraps: `c-cost` in a zone table has `min-width: 94px` (4 × 22px + 3 × 2px), because the auto layout of a phone's table would otherwise shrink the cell to one wrapped pip. Five or more symbols may take two lines in the narrow layout; six fit one line in the wide layout's 176px.
- Proxy: the `ProxyTag`, or a muted dash. Owned and Total are right-aligned mono; Total is owned plus proxy. A proxy never counts in Owned.
- **Fixed layout from 640px of the table's container.** Every zone table uses `table-layout: fixed` with these widths on its header cells (`box-sizing: border-box`, so a width is the whole column, padding included): Cost 11rem (176px), Owned 5rem, Proxy 7rem, Total 5rem and the menu 4rem. Card takes the rest: 128px in a 640px container, where a name wraps. The columns therefore sit at the same x in Main, Sideboard and Considering. Cost has 176px because a pip is 22px (20px and a 1px border each side), so six symbols are 6 × 22px + 5 × 2px = 142px, and the cell pads 12px a side: 166px needed. The Proxy tag, about 66px, fits 7rem. The widths belong to the zone tables; the Decks table's columns size themselves.
- **Auto layout below 640px of the table's container.** Zones are stacked there, and a fixed Cost would leave a 313px phone container 25px for the name (313 − 176 − 56 − 56). Owned and Proxy are hidden. Total takes its content width (`width: 1%`), as the menu does, so the auto layout does not stretch it. The cell's line under the name (`c-table__sub`) carries `set · number`, the `ProxyTag` for a row with proxies and the legality marker for a card that is not legal. The columns are Card, Cost, Total and the menu, with no horizontal overflow at 360px (a 60-character name with no space and a six-symbol cost is the worst case).
- **Group rows** are `tr.c-zone__group` with a `th scope="rowgroup"` spanning every column: the group's name and its count (`c-zone__groupcount`, mono) on `surface-sunken`, `ink-muted`, 12px at weight 600. They do not stick (the export's `th` rule sticks header cells; the group rows undo it) and have no hover fill. The extension supplies the groups and their order; the sample's groups are the top-level card types of a Magic deck.

**The legality marker** (spec 060 decision 8, AC-3.8). A card that is not legal in the deck's format gets `c-legal c-legal--no`, a cross and the word: "Banned", "Restricted" or "Not legal". It is written twice, as the set is. From 640px of the table's container the copy beside the name shows (inside `is-opt`, after the name link) and the copy in the line under the name is hidden; below 640px the copy in the `c-table__sub` line shows, after the set and the Proxy tag, and the copy beside the name is hidden (decision 9). Either way it is in `ink-muted`, never red: not being legal is information, as on the card page (`ItemPage`). A legal card has no marker, and a format with no rules has none at all. The sample shows Banned (Ragavan, Nimble Pilferer) and Not legal (Pyroblast in Sideboard, Spell Queller in Considering).

**The row menu** (spec 060 decision 17, AC-3.10 in part; built by spec 068 decision 5, AC-2.6). The last cell of a row that has a proxy is `TableActions`: a "…" `Menu` whose trigger is named for the row, "Actions for <card> <set · number>" ("Actions for Murktide Regent MH2 · 52"), because a zone can hold two printings of one card. A row with no proxy has an empty `td.c-table__actions` and no trigger.

- The items are links to pages, never forms, in this order (spec 070 decision 1, AC-1.1; spec 060 decision 17): "Use my copy" (to `UseMyCopy`), "Add a new copy" (to the Add a new copy page, `AddProxy`), "Change proxy count" (to the Change proxy count page), then, after a `c-menu__sep`, "Remove proxy" (`c-menu__item--danger`, last, to the confirmation). A row with proxies of two finishes has the item for each, the finish named as the collectible labels it, grouped by verb: every "Use my copy for Foil proxy" and "Use my copy for Nonfoil proxy", then both "Add a new copy for …", then "Change Foil proxy count" and "Change Nonfoil proxy count", the separator, and "Remove Foil proxy" and "Remove Nonfoil proxy" (AC-1.2).
- A proxy whose printing's collectible the instance no longer registers leaves "Use my copy" and "Add a new copy" out (their pages need that collectible's vocabulary); its menu has Change proxy count and Remove proxy (spec 070 AC-1.4).
- "Move copies" is not offered on the deck page (a card's copies are moved from the card page's "Your copies").
- The previews (`DeckPage.html`, `DeckPagePhone.html`) draw the empty `td.c-table__actions` on every row with no proxy, as the page does, and the menus of the proxy rows with the items above (spec 074, #326; they showed "Move copies" on rows with no proxy until then). A row menu near the bottom of a phone is scrolled clear of the tab bar: see `Menu`.
