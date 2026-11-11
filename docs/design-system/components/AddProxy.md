# AddProxy

The pages that add, change and remove a proxy in a deck zone (spec 068, #254): the chooser that finds a printing, the form that takes a finish and a quantity, the Change proxy count page and the Remove proxy confirmation. They add no class: every part is an existing pattern (`c-pagehead`, `c-filterbar`, `c-group`, `c-list`, `c-form`, `c-field`, `c-confirm`). Shown for a Magic: The Gathering card; the pages name no collectible in their rules.

All four are detail pages: `c-appbar--detail` with a back arrow, Decks the current section, and `main` carries `c-main c-page c-decks` (the form, change and removal pages; the chooser's `main` is `c-main c-page`). `c-decks` is what lets a 60-character name with no space break inside a word: `.c-decks .c-confirm :is(h1, p)` and `.c-decks .c-pagehead__title` take `overflow-wrap: anywhere` (spec 068 AC-9.1). "Cancel" on every page returns to the deck page.

## The chooser

`GET /decks/:deck_id/zones/:zone/proxies/new`. The heading names the deck and the zone ("Add a proxy to Izzet Tempo › Main"); under it a `c-filterbar` with the card search's name field and set filter and a "Search" button, then the results, then "Cancel".

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

- **Finish** is one native `select` of the printing's finishes in the collectible's order ("Choose…" first, nothing chosen, when there are several; the only one chosen, with no blank option, when there is one). A printing that lists none has no Finish field.
- **Quantity** is a `c-input` number field, `min` 1, `max` 9,999, 1 at first.
- "Add proxy" (primary) and "Cancel" (secondary, to the deck page). Adding to a zone that already has a proxy of that printing and finish adds the quantities.
- **Errors** are `c-field__error` paragraphs under their field, tied to it by `aria-describedby`: "Enter a number from 1 to 9,999.", "Choose a finish.", "That finish isn't available for this printing.", and "A zone can hold at most 9,999 proxies of one printing and finish." under Quantity. The page answers 422 and keeps what was typed.

## Change proxy count

`GET /decks/:deck_id/proxies/:id/edit`. The heading names the proxy ("Change the proxies of Lightning Bolt (MH2 · 138, Foil)", the finish only when the proxy has one) and the muted line the zone and the count now ("in Izzet Tempo › Main · 2 now"). One Quantity field holding the count, "Save" (primary) and "Cancel". It refuses 0 with "Enter a number from 1 to 9,999. To remove it, use Remove proxy.", so a removal is never a typing slip.

## Remove proxy

`GET /decks/:deck_id/proxies/:id/removal/new`, a `c-confirm` section: "Remove the proxies of Lightning Bolt (MH2 · 138, Foil) from Izzet Tempo › Main?", a line saying how many proxies go and that no copy in the collection is removed or changed, "Remove" (`c-btn--danger`, a button that sends DELETE) and "Cancel". It works without scripting.

Sources: spec 068 decisions 3 to 6, AC-1.2 to AC-1.9, AC-3.1 to AC-3.4, AC-9.1 to AC-9.3.
