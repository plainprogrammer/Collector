# DecksIndex

The list of a collector's decks and the page that adds one. Shown with Magic: The Gathering formats; the pages name no collectible in their rules.

**Markup, the Decks page** — inside `.c-main.c-page.c-decks`: a page head with the count and the primary "New deck" button, then the table in `.c-collection`. With no decks a `c-empty` paragraph takes the table's place.

```html
<main class="c-main c-page c-decks">
  <div class="c-pagehead">
    <div><h1 class="c-pagehead__title">Decks</h1><p class="c-pagehead__stats">6 decks · 379 cards</p></div>
    <div class="c-pagehead__actions"><a class="c-btn c-btn--primary" href="/decks/new"><svg …plus…/>New deck</a></div>
  </div>
  <div class="c-collection">
    <table class="c-table">
      <thead><tr><th>Deck</th><th class="is-opt">Format</th><th class="is-num">Cards</th><th class="is-num is-opt">Owned</th><th class="is-num is-opt">Proxy</th></tr></thead>
      <tbody>
        <tr>
          <td><div class="c-table__item"><div><a href="/decks/1">Izzet Tempo</a><span class="c-table__sub">Modern · 58 owned · <span class="c-proxy">Proxy <b>11</b></span></span></div></div></td>
          <td class="is-opt">Modern</td><td class="is-num">69</td><td class="is-num is-opt">58</td><td class="is-num is-opt"><span class="c-proxy">Proxy <b>11</b></span></td>
        </tr>
        <tr>
          <td><div class="c-table__item"><div><a href="/decks/2">Krenko, goblin army</a><span class="c-table__sub">Commander · 97 owned · <span class="c-proxy">Proxy <b>3</b></span></span></div></div></td>
          <td class="is-opt">Commander</td><td class="is-num">100</td><td class="is-num is-opt">97</td><td class="is-num is-opt"><span class="c-proxy">Proxy <b>3</b></span></td>
        </tr>
      </tbody>
    </table>
  </div>
  <!-- no decks: <p class="c-empty">No decks yet. Add a deck to start building one.</p> -->
</main>
```

**Markup, the New deck page** — under `c-appbar--detail`: a page head and a `Form` of Name and Format.

```html
<header class="c-appbar c-appbar--detail">…back link, brand, nav, avatar…</header>
<main class="c-main c-page">
  <div class="c-pagehead"><div><h1 class="c-pagehead__title">New deck</h1></div></div>
  <form class="c-form" action="/decks" method="post">
    <div class="c-field">
      <label class="c-field__label" for="deck_name">Name</label>
      <label class="c-input"><input type="text" id="deck_name" name="deck[name]" autocomplete="off"></label>
    </div>
    <div class="c-field">
      <label class="c-field__label" for="deck_format">Format</label>
      <select id="deck_format" name="deck[format]"><option>Standard</option><option>Modern</option><option>Commander</option></select>
      <p class="c-field__hint">The format sets the deck's zones.</p>
    </div>
    <div class="c-form__actions">
      <input type="submit" class="c-btn c-btn--primary" value="Create deck">
      <a class="c-btn c-btn--secondary" href="/decks">Cancel</a>
    </div>
  </form>
</main>
```

**The Decks page**

- The page head's count reads "6 decks · 379 cards" (mono, muted): the number of decks, then the cards in all of them. "New deck" is the one primary button: a plus and the words, a link to the New deck page (spec 060 decision 13, AC-4.1).
- **New deck stays visible on a phone** (spec 060 decision 24, AC-4.4). The export hides a page head's own buttons below 640px of the viewport, and the header's plus means "Add items" on every page, so a phone would have no way to add a deck. On this page alone, one rule in `additions.css` shows `c-pagehead__actions` below 640px, and the head wraps it beside the title. It is the exception that `AppHeader` names. The header plus is unchanged. The button is a primary `c-btn`, at least 44px high on a coarse pointer, at 1280px and at 360px.
- The Decks page lists decks only, and the Locations page lists places only (spec 057 decision 11; `Locations`). Decks have their own header link and tab.
- **Columns** (spec 060 decision 11, AC-4.2): Deck, Format, Cards, Owned and Proxy. The Deck cell is `TableItemLink` (the name links to the deck page). Cards, Owned and Proxy are right-aligned mono.
- **Cards counts every zone**: owned plus proxy in Main, Sideboard, Considering and the rest, Considering included, because copies in Considering are in the deck (spec 060 decision 12; the README's Decks section). Owned and Proxy therefore always add up to Cards. A deck with no cards shows "0" and a dash.
- **The Proxy cell** is the `ProxyTag` for a deck with proxies and a muted dash (`is-muted`) for one without, so no tag is shown for none.
- **The phone fold** (spec 060 decision 11, AC-4.3). Below 640px of the table's container Format, Owned and Proxy are hidden and the line under the deck's name (`c-table__sub`) reads the format, the owned count and the `ProxyTag`: "Modern · 58 owned · Proxy 11"; a deck with no proxies reads "Pioneer · 60 owned". Cards stays. This is the fold `CollectionTable` describes.
- **Names wrap.** Below 640px of the table's container the Deck cell wraps its name (`white-space: normal`, `overflow-wrap: anywhere`), so a 60-character name with no space never widens a phone's table and the table has no horizontal overflow at 360px.
- **No fixed layout.** The columns size themselves; the fixed column widths of `DeckPage`'s zone tables do not apply here (spec 060 decision 25).
- **Empty state** (spec 060 AC-4.1): "No decks yet. Add a deck to start building one." replaces the table, as an `EmptyState`; the page head and its New deck button stay.

**The New deck page** (spec 060 decision 13, AC-4.5)

- The heading is "New deck", under `c-appbar--detail`: a back arrow replaces the logo on phones. The list stays first on the Decks page; the form lives on its own page.
- Name is a `c-input` text field. Format is a native `select` (it never widens past its form, `Form`) with the hint "The format sets the deck's zones." The formats come from the extension; the sample lists three. Create deck is the one primary action, and Cancel is a secondary link back to the Decks page.
- The form is a `Form`: stacked, at most 420px wide, and its fields stack in a 360px frame with no horizontal overflow.
- **A refusal** answers 422, re-renders the form with the typed text kept, and shows the sentence as the Name field's `c-field__error`. A deck is a location, and decks and places share one namespace, so the sentences are the Locations page's own (spec 060 decision 23; spec 029 AC-1.6 and AC-1.9):
  - blank: "Give the location a name."
  - a control character: "Names can't contain control characters."
  - too long: "Names can be at most 60 characters."
  - taken: "You already have a location called “<name>”."
  - the limit of 500 locations in an account: "You can have at most 500 locations."

  The first three and the 500 limit are `Location::MESSAGES` and `Location::FULL`; the taken sentence is built in `Location`.
