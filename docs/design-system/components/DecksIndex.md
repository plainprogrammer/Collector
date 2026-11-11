# DecksIndex

The list of a collector's decks, the page that adds one, and the pages that rename and remove one. Shown with Magic: The Gathering formats; the pages name no collectible in their rules.

**Live since spec 062 (create, rename and remove a deck, #49).** The app's Decks page differs from spec 060's preview in three ways, each ruled by the maintainer (D5, 2026-11-10): each row has Rename and Remove ghost buttons, the deck's name is plain text and not the `TableItemLink`, and the table has no Proxy column or tag. **Spec 062 supersedes spec 060 decision 11 and AC-4.1 to AC-4.3 for the page until #253 and #254**: #253 (the deck page) restores the link and may remove the row actions where the deck page offers them; #254 (proxies) adds the Proxy column, the tag and the `Owned` + `Proxy` = `Cards` rule. The static previews (`previews/DecksIndex.html`, `previews/DecksIndexPhone.html`) still draw spec 060's shape, with the Proxy column and the linked name, and are the target #253 and #254 restore; the markup below is what the app renders today.

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
          <td><div class="c-table__item"><div><span>Izzet Tempo</span><span class="c-table__sub">Modern · 58 owned</span></div></div></td>
          <td class="is-opt">Modern</td><td class="is-num">58</td><td class="is-num is-opt">58</td>
          <td class="c-table__actions"><span class="c-decks__actions">
            <a class="c-btn c-btn--ghost c-btn--sm" href="/decks/41/edit">Rename<span class="c-sr"> Izzet Tempo</span></a>
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

and the refusal, for a deck any of whose zones holds a copy (the same page answers a `DELETE` with 409; there is no Remove button and no "Move them in bulk mode" button, because the collection filter by zone is #252's):

```html
<main class="c-main c-page c-decks">
  <section class="c-confirm">
    <h1 class="c-pagehead__title">“Izzet Tempo” isn't empty</h1>
    <p>“Izzet Tempo” holds 12 copies in 3 lots. Move them before removing it.</p>
    <ul class="c-list c-locations__lots" id="held_lots">
      <li><span><a href="/catalog/entries/…?from=collection#copies">Lightning Bolt</a> <span class="c-list__meta c-decks__zone">Izzet Tempo › Main</span> <span class="c-list__meta">…</span></span><span class="c-list__end">×4</span></li>
    </ul>
    <p class="c-locations__more">and 12 more</p>
    <div class="c-form__actions"><a class="c-btn c-btn--secondary" href="/decks">Back to decks</a></div>
  </section>
</main>
```

**The Decks page**

- The page head's count reads "6 decks · 379 cards" (mono, muted): the number of decks ("1 deck"), then the cards in all their zones. "New deck" is the one primary button: a plus and the words, a link to the New deck page (spec 060 decision 13, AC-4.1; spec 062 AC-4.3).
- **New deck stays visible on a phone** (spec 060 decision 24, AC-4.4). The export hides a page head's own buttons below 640px of the viewport, and the header's plus means "Add items" on every page, so a phone would have no way to add a deck. On this page alone, one rule in `additions.css` shows `c-pagehead__actions` below 640px, and the head wraps it beside the title. It is the exception that `AppHeader` names. The header plus is unchanged. The button is a primary `c-btn`, at least 44px high on a coarse pointer, at 1280px and at 360px.
- The Decks page lists decks only, and the Locations page lists places only (spec 057 decision 11; `Locations`; spec 062 AC-4.8). Decks have their own header link and tab (`AppHeader`, `TabBar`).
- **Columns** (spec 062 AC-4.3, AC-4.4, superseding spec 060 decision 11 and AC-4.2 until #253 and #254): Deck, Format, Cards, Owned and a last column of actions with no heading but a screen-reader one ("Actions"). The deck's name is plain text (not `TableItemLink`) until the deck page of #253 exists. Cards and Owned are right-aligned mono. The Format cell is the format's name, or its key when the instance no longer registers it. Decks are ordered by the name's comparison key, then the name.
- **Cards counts every zone**: the copies in Main, Sideboard, Considering and the rest, Considering included, because copies in Considering are in the deck (spec 060 decision 12; the README's Decks section). **Owned is the same number until proxies exist** (#254 adds the Proxy column and the rule that Owned and Proxy add up to Cards). A deck with no cards shows "0".
- **The row actions** (spec 062 decision 5, AC-4.4): "Rename" and "Remove", `c-btn c-btn--ghost c-btn--sm` links like the Locations list's, each followed by a `c-sr` span with the deck's name so a screen reader hears "Rename Izzet Tempo". They sit in `span.c-decks__actions` in the cell `td.c-table__actions`: a flex row at the end of the cell, `space-2` apart, in the sans font, and every `.c-decks .c-btn` is at least the touch floor (44px) high and wide. The cell is as narrow as its buttons (`td.c-table__actions { width: 1% }`).
- **The phone fold** (spec 060 decision 11, AC-4.3; spec 062 AC-4.5). Below 640px of the table's container Format and Owned are hidden and the line under the deck's name (`c-table__sub`) reads the format and the owned count: "Modern · 58 owned" (#254 adds the `ProxyTag` after it). Cards and the actions stay. This is the fold `CollectionTable` describes.
- **Names wrap.** Below 640px of the table's container the Deck cell wraps its name (`white-space: normal`, `overflow-wrap: anywhere`: `.c-decks td:first-child`), so a 60-character name with no space never widens a phone's table and the table has no horizontal overflow at 360px.
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

**The removal pages** (spec 062 AC-3.1 to AC-3.5)

- The confirmation is a `ConfirmPage` on its own page: the question "Remove <name>?", one sentence saying the zones go with the deck and no copy is removed or changed, the one danger button "Remove" and a Cancel link. Success answers 303 to the Decks page with "Removed “<name>”."
- The refusal replaces it for a deck whose zones hold any copy: the heading "“<name>” isn't empty", "“<name>” holds 12 copies in 3 lots. Move them before removing it.", the first 100 lots (`Location::Holdings::LISTED`) each linking to its card page with its zone as "Deck › Zone" in `c-list__meta` and its quantity at the end, "and N more" beyond them, and "Back to decks" as the only action. It reuses the Locations refusal page's `c-list c-locations__lots` and `c-locations__more`, and `c-decks__zone` is a hook with no rule of its own.
- A long name wraps on both pages: `.c-decks .c-confirm :is(h1, p), .c-decks .c-list li > span:first-child` take `min-width: 0` and `overflow-wrap: anywhere`, so a 60-character name with no space breaks inside itself on a phone and the page has no horizontal overflow (the lesson of `.c-locations__name` and `.c-pick`).

**CSS the pages add** (spec 062, one block each at the end of `additions.css`; no colour, spacing or font value of its own): `.c-decks__actions` and `.c-decks .c-btn` (the row actions above), the removal pages' wrapping rule above, and `.c-field__static` (`Form`). `.c-decks` itself was spec 060's: the name's wrap in the narrow container query and the New deck button on a phone.
