# DecksIndex

The list of a collector's decks, the page that adds one, and the pages that rename, change the format of and remove one. Shown with Magic: The Gathering formats; the pages name no collectible in their rules.

**Live since spec 062 (create, rename and remove a deck, #49).** The app's Decks page differs from spec 060's preview in three ways, each ruled by the maintainer (D5, 2026-11-10): each row has Rename, Change format and Remove ghost buttons (Change format since spec 064, #251), the deck's name was plain text and not the `TableItemLink` (since spec 066 it is a link to the deck page, a plain `<a>` inside the `span`), and, since spec 068 (#254), the table has the Proxy column: the `ProxyTag` or a muted dash, with Cards = Owned + Proxy. **Spec 062 superseded spec 060 decision 11 and AC-4.1 to AC-4.3 for the page until #254**; spec 068 restores them (spec 066 restored the link; the row actions stay, as the deck page offers the same three in its head). The static previews (`previews/DecksIndex.html`, `previews/DecksIndexPhone.html`) draw spec 060's shape, with the Proxy column and the linked name, which is what the app renders now.

**Markup, the Decks page** — inside `.c-main.c-page.c-decks`: a page head with the count and the primary "New deck" button, then the table in `.c-collection`. With no decks a `c-empty` paragraph takes the table's place.

```html
<main class="c-main c-page c-decks">
  <div class="c-pagehead">
    <div><h1 class="c-pagehead__title">Decks</h1><p class="c-pagehead__stats">6 decks · 379 cards</p></div>
    <div class="c-pagehead__actions"><a class="c-btn c-btn--primary" href="/decks/new"><svg …plus…/>New deck</a></div>
  </div>
  <div class="c-collection">
    <table class="c-table">
      <thead><tr><th>Deck</th><th class="is-opt">Format</th><th class="is-num">Cards</th><th class="is-num is-opt">Owned</th><th><span class="c-sr">Actions</span></th></tr></thead>
      <tbody>
        <tr>
          <td><div class="c-table__item"><div><span><a href="/decks/41">Izzet Tempo</a></span><span class="c-table__sub">Modern · 58 owned</span></div></div></td>
          <td class="is-opt">Modern</td><td class="is-num">58</td><td class="is-num is-opt">58</td>
          <td class="c-table__actions"><span class="c-decks__actions">
            <a class="c-btn c-btn--ghost c-btn--sm" href="/decks/41/edit">Rename<span class="c-sr"> Izzet Tempo</span></a>
            <a class="c-btn c-btn--ghost c-btn--sm" href="/decks/41/format/edit">Change format<span class="c-sr"> Izzet Tempo</span></a>
            <a class="c-btn c-btn--ghost c-btn--sm" href="/decks/41/removal/new">Remove<span class="c-sr"> Izzet Tempo</span></a>
          </span></td>
        </tr>
      </tbody>
    </table>
  </div>
  <!-- no decks: <p class="c-empty">No decks yet. Add a deck to start building one.</p> -->
</main>
```

The `41` in the URLs is the deck's **location id**, not a row id of a `decks` table: a zone's or a place's id is then never a deck's, and a request with one is a 404 (spec 062 decision 4, AC-3.8).

**Markup, the New deck page** — under `c-appbar--detail`: a page head and a `Form` of Name and Format.

```html
<header class="c-appbar c-appbar--detail">…back link, brand, nav, avatar…</header>
<main class="c-main c-page c-decks">
  <div class="c-pagehead"><div><h1 class="c-pagehead__title">New deck</h1></div></div>
  <form class="c-form" action="/decks" method="post">
    <div class="c-field">
      <label class="c-field__label" for="deck_name">Name</label>
      <label class="c-input"><input type="text" id="deck_name" name="deck[name]" autocomplete="off"></label>
    </div>
    <div class="c-field">
      <label class="c-field__label" for="deck_format">Format</label>
      <select id="deck_format" name="deck[format]"><option value="mtg/casual" selected>Casual</option><option value="mtg/standard">Standard</option><option value="mtg/modern">Modern</option>…</select>
      <p class="c-field__hint">The format sets the deck's zones.</p>
    </div>
    <div class="c-form__actions">
      <input type="submit" class="c-btn c-btn--primary" value="Create deck">
      <a class="c-btn c-btn--secondary" href="/decks">Cancel</a>
    </div>
  </form>
</main>
```

**Markup, the Rename page** (spec 062 AC-2.1) — under `c-appbar--detail`, with the Decks section current: a page head "Rename deck" whose stats line is the deck's current name, and a `Form` of the Name field.

```html
<main class="c-main c-page c-decks">
  <div class="c-pagehead"><div><h1 class="c-pagehead__title">Rename deck</h1><p class="c-pagehead__stats">Izzet Tempo</p></div></div>
  <form class="c-form" action="/decks/41" method="post"><!-- _method=patch -->
    <div class="c-field">
      <label class="c-field__label" for="location_name">Name</label>
      <label class="c-input"><input type="text" id="location_name" name="location[name]" value="Izzet Tempo" autocomplete="off"></label>
    </div>
    <div class="c-form__actions">
      <input type="submit" class="c-btn c-btn--primary" value="Save">
      <a class="c-btn c-btn--secondary" href="/decks">Cancel</a>
    </div>
  </form>
</main>
```

**Markup, the Change format page** (spec 064 AC-1.2, AC-2.6, AC-3.1) — under `c-appbar--detail`, with the Decks section current: a page head "Change format" whose stats line is the deck's name and its current format ("Izzet Tempo · Modern", the stored key when the instance no longer registers the format, AC-1.7), and a `Form` of the Format field, the Rename page's shape with the New deck page's select and a hint.

```html
<main class="c-main c-page c-decks">
  <div class="c-pagehead"><div><h1 class="c-pagehead__title">Change format</h1><p class="c-pagehead__stats">Izzet Tempo · Modern</p></div></div>
  <form class="c-form" action="/decks/41/format" method="post"><!-- _method=patch -->
    <div class="c-field"><!-- c-field--invalid with a c-field__error after the select on "Choose a format." -->
      <label class="c-field__label" for="deck_format">Format</label>
      <select id="deck_format" name="deck[format]"><option value="mtg/casual">Casual</option>…<option value="mtg/modern" selected>Modern</option>…</select>
      <p class="c-field__hint">Cards in zones the new format doesn't have move to Considering.</p>
    </div>
    <div class="c-form__actions">
      <input type="submit" class="c-btn c-btn--primary" value="Save">
      <a class="c-btn c-btn--secondary" href="/decks">Cancel</a>
    </div>
  </form>
</main>
```

A refusal at the cap answers 422 with this page again and the page's alert in the shared status region above it (`#status`, `c-status__message--alert`): "Nothing changed. Lightning Bolt (M10 · 146) would have more than 9,999 copies in one lot.", as the bulk move page shows its own (spec 064 decision 6, AC-2.6).

**Markup, the removal pages** (spec 062 AC-3.1, AC-3.3) — the `ConfirmPage` pattern inside `.c-decks`, with no script needed. The confirmation, for a deck whose zones hold no copy:

```html
<main class="c-main c-page c-decks">
  <section class="c-confirm">
    <h1 class="c-pagehead__title">Remove Izzet Tempo?</h1>
    <p>This removes the deck, and its zones are removed with it. No copy in your collection is removed or changed.</p>
    <div class="c-form__actions">
      <button class="c-btn c-btn--danger" type="submit">Remove</button><!-- a form: DELETE /decks/41 -->
      <a class="c-btn c-btn--secondary" href="/decks">Cancel</a>
    </div>
  </section>
</main>
```

and the refusal, for a deck any of whose zones holds a copy (the same page answers a `DELETE` with 409; there is no Remove button, and the primary "Move them in bulk mode" button comes first: a `button_to` form posting to `/decks/:id/selection` with a `c-sr` tail naming the deck, spec 067 AC-1.1, AC-1.4, [#302](https://github.com/plainprogrammer/Collector/issues/302)):

```html
<main class="c-main c-page c-decks">
  <section class="c-confirm">
    <h1 class="c-pagehead__title">“Izzet Tempo” isn't empty</h1>
    <p>“Izzet Tempo” holds 12 copies in 3 lots. Move them before removing it.</p>
    <ul class="c-list c-locations__lots" id="held_lots">
      <li><span><a href="/catalog/entries/…?from=collection#copies">Lightning Bolt</a> <span class="c-list__meta c-decks__zone">Izzet Tempo › Main</span> <span class="c-list__meta">…</span></span><span class="c-list__end">×4</span></li>
    </ul>
    <p class="c-locations__more">and 12 more</p>
    <div class="c-form__actions">
      <button class="c-btn c-btn--primary" type="submit">Move them in bulk mode<span class="c-sr"> from “Izzet Tempo”</span></button><!-- a form: POST /decks/41/selection -->
      <a class="c-btn c-btn--secondary" href="/decks">Back to decks</a>
    </div>
  </section>
</main>
```

**The Decks page**

- The page head's count reads "6 decks · 379 cards" (mono, muted): the number of decks ("1 deck"), then the cards in all their zones. "New deck" is the one primary button: a plus and the words, a link to the New deck page (spec 060 decision 13, AC-4.1; spec 062 AC-4.3).
- **New deck stays visible on a phone** (spec 060 decision 24, AC-4.4). The export hides a page head's own buttons below 640px of the viewport, and the header's plus means "Add items" on every page, so a phone would have no way to add a deck. On this page alone, one rule in `additions.css` shows `c-pagehead__actions` below 640px, and the head wraps it beside the title. It is the exception that `AppHeader` names. The header plus is unchanged. The button is a primary `c-btn`, at least 44px high on a coarse pointer, at 1280px and at 360px.
- The Decks page lists decks only, and the Locations page lists places only (spec 057 decision 11; `Locations`; spec 062 AC-4.8). Decks have their own header link and tab (`AppHeader`, `TabBar`).
- **Columns** (spec 062 AC-4.3, AC-4.4 and spec 068 AC-5.1; spec 060 decision 11): Deck, Format, Cards, Owned, Proxy and a last column of actions with no heading but a screen-reader one ("Actions"). Proxy is the `ProxyTag` or a muted dash. The deck's name is a plain link to the deck page (not `TableItemLink`, spec 066 decision 1). Cards, Owned and Proxy are right-aligned mono. The Format cell is the format's name, or its key when the instance no longer registers it. Decks are ordered by the name's comparison key, then the name.
- **Cards counts every zone**: the copies in Main, Sideboard, Considering and the rest, Considering included, because copies in Considering are in the deck (spec 060 decision 12; the README's Decks section). Owned and Proxy add up to Cards (spec 068 AC-5.1). A deck with no cards shows "0" and a muted dash.
- **The row actions** (spec 062 decision 5, AC-4.4; spec 064 AC-1.1): "Rename", "Change format" and "Remove", `c-btn c-btn--ghost c-btn--sm` links like the Locations list's, each followed by a `c-sr` span with the deck's name so a screen reader hears "Rename Izzet Tempo" and "Change format Izzet Tempo". They sit in `span.c-decks__actions` in the cell `td.c-table__actions`: a flex row at the end of the cell, `space-2` apart, in the sans font, and every `.c-decks .c-btn` is at least the touch floor (44px) high and wide. The cell is as narrow as its buttons (`td.c-table__actions { width: 1% }`). **The three buttons stay on one line on a wide screen and wrap onto lines of their own below 640px of the viewport** (spec 064 AC-1.1): `.c-decks__actions` is `flex-wrap: nowrap` by default (with wrapping allowed the cell's minimum is one button wide and they would stack at every width) and `@media (max-width: 639px) { .c-decks__actions { flex-wrap: wrap } }` lets a phone's row grow taller instead of wider, so no row widens a 360px page. The real page is what the previews do not draw.
- **The phone fold** (spec 060 decision 11, AC-4.3; spec 062 AC-4.5). Below 640px of the table's container Format, Owned and Proxy are hidden and the line under the deck's name (`c-table__sub`) reads the format and the owned count, then the `ProxyTag` for a deck that has proxies: "Modern · 58 owned" and "Proxy 11" (spec 068 AC-5.2). Cards and the actions stay. This is the fold `CollectionTable` describes.
- **Names wrap.** At every width the Deck cell wraps its name (`white-space: normal`, `overflow-wrap: anywhere`: `.c-decks td:first-child`), so a 60-character name never widens the table: the row's three buttons stay on one line from 640px up, and the page has no horizontal overflow at 360px, 768px or 1024px.
- **No fixed layout.** The columns size themselves; the fixed column widths of `DeckPage`'s zone tables do not apply here (spec 060 decision 25).
- **Empty state** (spec 060 AC-4.1; spec 062 AC-4.6): "No decks yet. Add a deck to start building one." replaces the table, as an `EmptyState`; the page head and its New deck button stay.
- **Cost.** The page reads the decks with their locations and one grouped sum of the copies in all their zones, a bounded number of queries whatever the number of decks, zones or lots (spec 062 AC-4.7).

**The New deck page** (spec 060 decision 13, AC-4.5; spec 062 AC-1.1, AC-1.2)

- The heading is "New deck", under `c-appbar--detail`: a back arrow replaces the logo on phones. The list stays first on the Decks page; the form lives on its own page.
- Name is a `c-input` text field. Format is a native `select` (it never widens past its form, `Form`) with the hint "The format sets the deck's zones." The formats come from the extension (`Catalog::Formats`), in their registered order, with the type's default selected (Casual for Magic); each option's value is `<collectible type>/<format key>` so two collectibles that both have a `standard` stay apart. With formats of more than one collectible type the select groups them in `optgroup`s headed by each type's category name; with one type the list is flat. Create deck is the one primary action, and Cancel is a secondary link back to the Decks page.
- The form is a `Form`: stacked, at most 420px wide, and its fields stack in a 360px frame with no horizontal overflow.
- **A refusal** answers 422, re-renders the form with the typed text and the chosen format kept, and shows the sentence as the Name field's `c-field__error`. A deck is a location, and decks and places share one namespace, so the sentences are the Locations page's own (spec 060 decision 23; spec 029 AC-1.6 and AC-1.9; spec 062 AC-1.7):
  - blank: "Give the location a name."
  - a control character: "Names can't contain control characters."
  - too long: "Names can be at most 60 characters."
  - taken (by a place or another deck): "You already have a location called “<name>”."
  - the limit of 500 places and decks together in an account: "You can have at most 500 places and decks together." One sentence for the Locations page and this one, so it says decks count toward the limit wherever it shows; it replaces spec 029's "You can have at most 500 locations." (spec 062 AC-1.7a).

  The first three and the limit are `Location::MESSAGES` and `Location::FULL`; the taken sentence is built in `Location`. A blank, unregistered or other-type Format value is "Choose a format." on the Format field, and the request is 422 (spec 062 AC-1.8).
- A success answers 303 to the Decks page with the notice "Added “<name>”."

**The Rename page** (spec 062 AC-2.1 to AC-2.4)

- "Rename deck" under `c-appbar--detail` with the Decks tab current; the stats line is the deck's name as it is now, the Name field holds it, and Save is primary with Cancel beside it. It is a page of its own, reached from the row's Rename without scripting. A refusal answers 422 with the typed text kept and the same sentences on the Name field. A success answers 303 to the Decks page with "Renamed “<old>” to “<new>”."; a change of case alone is allowed.
- Only a deck is renamed here: a zone's name is its format's, so a zone's or a place's id is a 404.

**The Change format page** (spec 064 AC-1.1 to AC-1.7, AC-2.1 to AC-2.6, AC-3.1)

- "Change format" under `c-appbar--detail` with the Decks tab current, reached from the row's Change format without scripting. The Format select has the options and grouping of the New deck page, with the deck's own format selected (the default format when the instance no longer registers the deck's, so saving the default is a visible choice: the head line shows the stored key). The hint says what happens to cards, "Cards in zones the new format doesn't have move to Considering."; Save is primary with Cancel beside it.
- A success answers 303 to the Decks page with the notice "Changed “<name>” to <Format>." and, when copies moved, " 12 cards moved to Considering." ("1 card" for one); the format the deck already has is "“<name>” is already <Format>." A bad pair is "Choose a format." on the Format field with 422; a merge past 9,999 copies is the alert described above with 422 and the chosen format kept.
- A long name wraps in the head's stats line: `.c-decks .c-pagehead > div { min-width: 0 }` and the shared `.c-pagehead__stats { overflow-wrap: anywhere }` (spec 065), so a 60-character name with no space breaks inside itself on a phone and the page has no horizontal overflow at 360px (spec 064 AC-1.1).

**The removal pages** (spec 062 AC-3.1 to AC-3.5)

- The confirmation is a `ConfirmPage` on its own page: the question "Remove <name>?", one sentence saying the zones go with the deck and no copy is removed or changed, the one danger button "Remove" and a Cancel link. Success answers 303 to the Decks page with "Removed “<name>”."
- The refusal replaces it for a deck whose zones hold any copy: the heading "“<name>” isn't empty", "“<name>” holds 12 copies in 3 lots. Move them before removing it.", the first 100 lots (`Location::Holdings::LISTED`) each linking to its card page with its zone as "Deck › Zone" in `c-list__meta` and its quantity at the end, "and N more" beyond them, and the actions row: the `c-btn--primary` "Move them in bulk mode" first (a `button_to` form posting to `/decks/:id/selection`, never a link, with a `c-sr` tail ` from “<name>”`, spec 067 AC-1.1, AC-1.4) and then "Back to decks" `c-btn--secondary`. It reuses the Locations refusal page's `c-list c-locations__lots` and `c-locations__more`, and `c-decks__zone` is a hook with no rule of its own.
- A long name wraps on both pages: `.c-decks .c-confirm :is(h1, p), .c-decks .c-list li > span:first-child` take `min-width: 0` and `overflow-wrap: anywhere`, so a 60-character name with no space breaks inside itself on a phone and the page has no horizontal overflow (the lesson of `.c-locations__name` and `.c-pick`).

**CSS the pages add** (spec 062 and 064, one block each at the end of `additions.css`; no colour, spacing or font value of its own): `.c-decks__actions` and `.c-decks .c-btn` (the row actions above, with spec 064's wrap below 640px), the removal pages' wrapping rule above, and the page heads' `.c-decks .c-pagehead > div`. A page head's stats line breaks a long name by spec 065's one `.c-pagehead__stats { overflow-wrap:anywhere }`, which every page head shares (the Decks pages included). `.c-decks` itself was spec 060's: the New deck button on a phone; the name's wrap was spec 060's in the narrow container query and spec 064 made it apply at every width. Spec 065 removed `.c-field__static` (`Form`'s read-only value).
