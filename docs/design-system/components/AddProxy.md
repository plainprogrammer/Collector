# AddProxy

The pages that add, change and remove a proxy in a deck zone (spec 068, #254): the chooser that finds a printing, the form that takes a finish and a quantity, the Change proxy count page and the Remove proxy confirmation. They add no class (the Add a new copy section below adds one): every part is an existing pattern (`c-pagehead`, `c-filterbar`, `c-group`, `c-list`, `c-form`, `c-field`, `c-confirm`). Shown for a Magic: The Gathering card; the pages name no collectible in their rules.

All four are detail pages: `c-appbar--detail` with a back arrow, Decks the current section, and `main` of all four carries `c-main c-page c-decks`. `c-decks` is what gives their buttons the 44px touch floor (`.c-decks .c-btn`) and lets a 60-character name with no space break inside a word: `.c-decks .c-confirm :is(h1, p)` and `.c-decks .c-pagehead__title` take `overflow-wrap: anywhere` (spec 068 AC-9.1). "Cancel" on every page returns to the deck page.

## The chooser

`GET /decks/:deck_id/zones/:zone/proxies/new`. The heading names the deck and the zone ("Add a proxy to Izzet Tempo › Main"); under it a `c-filterbar` with the card search's name field and set filter and a "Search" button, then the results, then "Cancel". On a coarse pointer the Set select is lifted to the 44px touch floor by `.c-decks .c-select select` (spec 068 AC-9.1; `DecksIndex`).

```html
<div class="c-pagehead"><div><h1 class="c-pagehead__title">Add a proxy to Izzet Tempo › Main</h1>
  <p class="c-pagehead__stats">Choose a printing. A proxy is a card the deck needs that you don't own.</p></div></div>
<div class="c-collection">
  <form class="c-filterbar" role="search" method="get">
    <label class="c-input"><svg …/><input type="search" name="q" aria-label="Card name" placeholder="Lightning Bolt"></label>
    <div class="c-filterbar__filters"><label class="c-select"><span class="c-sr">Set</span><select name="set">…</select></label>
      <input type="submit" value="Search" class="c-btn c-btn--secondary c-btn--sm"></div>
  </form>
  <div class="c-results__meta"><span class="c-filterbar__count">1 card</span></div>
  <section class="c-group" aria-labelledby="…">
    <div class="c-section__head"><h2 class="c-section__title" id="…">Lightning Bolt</h2>
      <span class="c-section__count">Showing 10 of 24 printings. Choose a set to see the others.</span></div>
    <ul class="c-list">
      <li><span class="is-data">MH2 · 138</span>
        <span class="c-list__end"><a class="c-btn c-btn--secondary c-btn--sm" href="…">Choose<span class="c-sr"> Lightning Bolt MH2 · 138</span></a></span></li>
    </ul>
  </section>
  <nav class="c-pager">…</nav>
</div>
```

- The results are the card search's (12 cards a page, each card's newest 10 printings), limited to the deck's collectible type; a retired printing is not listed. A card with more printings says how many are shown and to choose a set (the set filter narrows it). A printing's row reads `SET · number` in mono, with ` · LANG` for a language other than English.
- Empty states: "Type part of a card name to search." before a search; "No cards match. Check the spelling or try part of the name." after one with no result.

## The form

`GET …/proxies/new?entry=<the printing's key>`, the page the preview `previews/AddProxy.html` (and `AddProxyPhone.html`) draws: the heading as above, the card's name and `SET · number` in the muted line, then a `c-form`: a hidden `proxy[entry]`, a Finish select, a Quantity field, and the actions.

- **Finish** is one native `select` of the printing's finishes in the collectible's order ("Choose…" first, nothing chosen, when there are several; the only one chosen, with no blank option, when there is one). A printing that lists none has no Finish field. On a coarse pointer the select is at least the 44px touch floor (`.c-decks .c-field select`, spec 068 AC-9.1).
- **Quantity** is a `c-input` number field, `min` 1, `max` 9,999, 1 at first.
- "Add proxy" (primary) and "Cancel" (secondary, to the deck page). Adding to a zone that already has a proxy of that printing and finish adds the quantities.
- **Errors** are `c-field__error` paragraphs under their field, tied to it by `aria-describedby`: "Enter a number from 1 to 9,999.", "Choose a finish.", "That finish isn't available for this printing.", and "A zone can hold at most 9,999 proxies of one printing and finish." under Quantity. The page answers 422 and keeps what was typed.

## Change proxy count

`GET /decks/:deck_id/proxies/:id/edit`. The heading names the proxy ("Change the proxies of Lightning Bolt (MH2 · 138, Foil)", the finish only when the proxy has one) and the muted line the zone and the count now ("in Izzet Tempo › Main · 2 now"). One Quantity field holding the count, "Save" (primary) and "Cancel". It refuses 0 with "Enter a number from 1 to 9,999. To remove it, use Remove proxy.", so a removal is never a typing slip.

## Remove proxy

`GET /decks/:deck_id/proxies/:id/removal/new`, a `c-confirm` section: "Remove the proxies of Lightning Bolt (MH2 · 138, Foil) from Izzet Tempo › Main?", a line saying how many proxies go and that no copy in the collection is removed or changed, "Remove" (`c-btn--danger`, a button that sends DELETE) and "Cancel". It works without scripting.

## Add a new copy

`GET /decks/:deck_id/proxies/:id/copy/new` and `POST /decks/:deck_id/proxies/:id/copy` (`Decks::Proxies::CopiesController`; spec 070 decision 5, #257): the Add a copy form (`lots/_form`, the card page's) for the proxy's printing, on a deck-side page, so that the copy lands in the proxy's zone while the proxy is lowered by the same quantity. It is a link in the row menu, never a form there. It is a detail page like the four above: `c-appbar--detail`, Decks the current section, `main` of `c-main c-page c-decks`, the heading and the muted line breaking inside a word. The card page's own Add a copy and Edit copy, which share the partial, are unchanged (spec 070 AC-4.9).

```html
<main class="c-main c-page c-decks">
  <div class="c-pagehead"><div>
    <h1 class="c-pagehead__title">Add a new copy of Lightning Bolt</h1>
    <p class="c-pagehead__stats">Replaces 2 proxies in Izzet Tempo › Main · <span class="is-data">MH2 · 138</span>, Foil</p>
  </div></div>
  <form class="c-form" action="/decks/…/proxies/…/copy" method="post">
    <div class="c-field c-field--invalid">
      <label class="c-field__label" for="lot_quantity">Quantity</label>
      <label class="c-input"><input type="number" id="lot_quantity" name="lot[quantity]" min="1" max="2" step="1" value="3" inputmode="numeric" required aria-describedby="lot_quantity-error"></label>
      <p class="c-field__error" id="lot_quantity-error">Enter a number from 1 to 2.</p>
    </div>
    <div class="c-field">
      <label class="c-field__label" for="lot_finish">Finish</label>
      <select id="lot_finish" name="lot[finish]"><option value="">Not specified</option><option value="nonfoil">Nonfoil</option><option value="foil" selected>Foil</option></select>
    </div>
    <div class="c-field">
      <label class="c-field__label" for="lot_condition">Condition</label>
      <select id="lot_condition" name="lot[condition]"><option value="">Not specified</option><option value="near_mint">Near mint (NM)</option>…</select>
    </div>
    <div class="c-field">
      <label class="c-field__label" for="lot_price_paid">Price paid per copy (USD)</label>
      <label class="c-input"><span aria-hidden="true">$</span><input type="text" id="lot_price_paid" name="lot[price_paid]" inputmode="decimal" placeholder="1.25"></label>
      <p class="c-field__hint">Optional.</p>
    </div>
    <div class="c-field">
      <p class="c-field__label">Location</p>
      <p class="c-field__value">Izzet Tempo › Main</p>
    </div>
    <input type="hidden" name="shown_quantity" value="2">
    <div class="c-form__actions">
      <input type="submit" value="Add copy" class="c-btn c-btn--primary">
      <a class="c-btn c-btn--secondary" href="/decks/…">Cancel</a>
    </div>
  </form>
</main>
```

- **The muted line** is Use my copy's (`UseMyCopy`): "Replaces 2 proxies in Izzet Tempo › Main · MH2 · 138, Foil" ("1 proxy"; the finish only when the proxy has one). The heading names the card.
- **The fields** are `lots/_form`'s, in its order: Quantity, Finish, Condition, Price paid per copy, then Location. Finish, Condition and Price paid are the card page's: the finishes and conditions of the collectible's vocabulary, a "Not specified" first option, the price with its currency symbol and the hint "Optional.". The printing is fixed by the page (the proxy's): no field names it. The Finish select has the proxy's finish chosen and stays editable, because Use my copy lists other finishes too (a printing that lists no finish has no Finish select). On a coarse pointer the selects are at least the 44px touch floor (`.c-decks .c-field select`).
- **Quantity** is a `c-input` number field with 1 at first, `min` 1 and `max` the proxy's count, so the field can never ask for more copies than the proxy has (the card page's form has `max` 9,999, the default of the partial's `quantity_max`). It starts at 1 and not at the proxy's count: one click would replace every proxy, the destructive end of the range (spec 070 decision 5).
- **Location is read-only text and not a field.** It is a `c-field__label` paragraph (a `p`, not a `label`, because it labels no control) and under it a `c-field__value` paragraph holding the proxy's zone written Deck › Zone. The zone is not a select, not an input and not a hidden field: the request carries no zone, location or printing, and the copy lands in the proxy's zone whatever a request says (spec 070 AC-4.1, AC-4.7). A collector who wants the copy elsewhere uses the card page's Add a copy. The card page's "Add a location" hint is left out here. `lots/_form` shows this block when it is given a `fixed_place`, and the select otherwise.
- **`c-field__value`** (`collector/additions.css`, "Add a new copy's read-only Location", spec 070 AC-6.1) is the value under a field label that is not a control. It has no margin and `overflow-wrap: anywhere` and is scoped to `.c-decks`, so a deck name of 60 characters with no space breaks inside the word instead of widening the form at 360px; it sets no colour, size or font, so the text is the page's own. It is the only CSS spec 070 added to the design system.
- **The hidden `shown_quantity`** holds the proxy's count as the form showed it. A request whose count is no longer that is refused (below), so a double submit never adds two copies against a proxy one of them already lowered (spec 070 decision 10, AC-4.6a). The card page's form has none.
- **"Add copy"** (primary) and **"Cancel"** (secondary, to the deck page, `cancel_path`; the card page's form keeps its Cancel to the card). On success: 303 to the deck page with the notice "Added 2 × Lightning Bolt (MH2 · 138) to Izzet Tempo › Main, replacing 2 proxies." ("1 proxy"). The lot merges into the zone's lot of that identity when there is one, and the proxy is lowered by the quantity or removed at zero, in one write.
- **Errors** answer 422 with what was typed kept and nothing written, as `c-field__error` paragraphs under their field tied by `aria-describedby`. The form's own sentences are Add a copy's (Quantity "must be a whole number from 1 to 9,999", "One lot can hold at most 9,999 copies." for a merge past the cap, a finish or condition the vocabulary doesn't list, a price that isn't a non-negative amount with at most two places). Two are this page's, both under Quantity: "Enter a number from 1 to N." (N the proxy's count now) for a Quantity over the count, and "This proxy changed. Check the quantity and try again." when the count is no longer the `shown_quantity`; the form is then written again with `shown_quantity` set to the count now and the typed values kept, so submitting it again succeeds. The order is the form's own sentences, then "This proxy changed…", then "Enter a number from 1 to N.". A proxy removed in another tab is a 404 on submit and nothing is written.
- The preview is `previews/AddNewCopy.html` (and `AddNewCopyPhone.html`), drawn with the over-the-count refusal.

Sources: spec 068 decisions 3 to 6, AC-1.2 to AC-1.9, AC-3.1 to AC-3.4, AC-9.1 to AC-9.3; spec 070 decisions 5, 10 and 11, AC-4.1 to AC-4.9, AC-6.1 and AC-6.5.
