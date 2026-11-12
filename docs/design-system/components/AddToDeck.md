# AddToDeck

The page that adds a card to a deck zone, from the card page's "Add to deck" button: a `ChoicePage` variant with a grouped select, a quantity and a choice of what to use. Shown here for a Magic: The Gathering card.

**Markup** — under `c-appbar--detail`: a page heading that names the card, then a `c-form` holding the Deck and zone select, a How many field, a `c-choices c-pick` fieldset of `c-check` radios and the actions: Add to deck (primary) and Cancel back to the card page.

```html
<header class="c-appbar c-appbar--detail">…back link to the card page, brand, nav, avatar…</header>
<main class="c-main c-page c-decks">
  <div class="c-pagehead"><div><h1 class="c-pagehead__title">Add Lightning Bolt to a deck</h1></div></div>
  <form class="c-form" action="/catalog/entries/…/deck_additions" method="post">
    <div class="c-field">
      <label class="c-field__label" for="deck_zone">Deck and zone</label>
      <select id="deck_zone" name="zone_id" required>
        <option value="">Choose a deck and zone…</option>
        <optgroup label="Decks"><option value="1">Izzet Tempo › Main</option><option value="2">Izzet Tempo › Sideboard</option><option value="3">Izzet Tempo › Considering</option></optgroup>
      </select>
    </div>
    <div class="c-field">
      <label class="c-field__label" for="how_many">How many</label>
      <label class="c-input"><input type="number" id="how_many" name="quantity" min="1" value="1" inputmode="numeric"></label>
    </div>
    <fieldset class="c-choices c-pick">
      <legend class="c-field__label">What to use</legend>
      <label class="c-check"><input required type="radio" value="copies" name="use">My copies (3 free: 2 in Blue binder, 1 in Red box)</label>
      <label class="c-check"><input required type="radio" value="proxy:nonfoil" name="use">A proxy of <span class="is-data">2X2 · 117</span> Nonfoil</label>
      <label class="c-check"><input required type="radio" value="proxy:foil" name="use">A proxy of <span class="is-data">2X2 · 117</span> Foil</label>
    </fieldset>
    <div class="c-form__actions">
      <input type="submit" value="Add to deck" class="c-btn c-btn--primary">
      <a class="c-btn c-btn--secondary" href="/catalog/entries/…">Cancel</a>
    </div>
  </form>
</main>
```

- **The page.** It is a `ChoicePage` variant (spec 060 decision 14): the heading names the action and the card ("Add Lightning Bolt to a deck"), the choice is a fieldset of radios with a visible legend, Add to deck is the only primary action, and the page works without scripting. The form is a `Form`, at most 420px wide.
- **Deck and zone.** One native `select` (spec 060 decision 14; spec 057 decision 2). Its options are written "Deck › Zone" under an `optgroup` labelled "Decks". There is no "Places" group, because only a zone can be chosen. The first option, "Choose a deck and zone…", submits an empty value, so the browser refuses a submission without a choice (`Form`). A long deck name is cut inside the select; it never widens the form (spec 060 AC-5.2; spec 040 AC-7.1).
- On a coarse pointer the select is at least the touch floor (44px) high, as every select is (`Form`, spec 072).
- **How many** is a `c-input` number field, `min` 1, with 1 in it at first.
- **What to use** has "My copies" when copies are free, then one proxy option per finish the printing lists (spec 071 decision 9; spec 060 decision 14 drew a single proxy option for a printing with one finish), in the vocabulary's order. The option's words are the printing and the finish's label: "A proxy of `2X2 · 117` Foil", `SET · number` in mono (`is-data`), the finish in the vocabulary's case, nothing after the number for a printing that lists no finish. Radio values are `copies`, `proxy:<finish key>` and `proxy` (no finish). "My copies" gives the free count and where the copies are, "3 free: 2 in Blue binder, 1 in Red box", in the order a count takes them, copies with no location as "1 with no location", at most five places and then "and 2 more places".
- **With one option nothing else is needed and it is chosen** (`checked`: a printing with one finish or none, and no free copy); with two or more nothing is chosen and every radio is `required`, as `ChoicePage` does (spec 060 decision 14).
- **The pick list** (`c-pick`, spec 060 FR-5). A fieldset is as wide as its widest child, so the fieldset has `min-width: 0` and its rows wrap and break inside a word (`overflow-wrap: anywhere`): a place name of 60 characters with no space in the "My copies" option wraps and the page has no horizontal overflow at 360px (spec 060 AC-5.2; spec 042 AC-7.1). A radio's row shows the 2px `focus` ring while its control has keyboard focus (AC-5.3), because `c-check` has none of its own.
- **Which lots a count takes** is the server's (spec 071 decision 5): the shown printing's free lots first, then the card's other printings newest first, within a printing in the card page's "Your copies" order; whole lots, then the rest from the next lot. **The server's refusals** (spec 071 decision 11) are one sentence each under the field they belong to, as `Form` documents: "Choose a deck and zone." under the select, "Enter a number from 1 to N." under How many (N the free copies for My copies, 9,999 for a proxy), "Choose what to use." and "You have no free copy of Lightning Bolt to use." under the options, and above the actions "Nothing changed. Lightning Bolt (MH2 · 138) would have more than 9,999 copies in one lot." or "… can't be moved until it is edited."
- **The page's `main` carries `c-decks`** (the Decks pages' 44px floor for buttons at every pointer, and their long-name wrap). The select and the number field take the app-wide coarse floors (`.c-field select`, spec 072; `.c-input`), and the radio rows `min-height:var(--touch-floor)` on a coarse pointer under `.c-decks .c-pick`, the one rule that is this page's own (spec 071 AC-6.3).
- **Cancel** and the app bar's back link return to the card page, keeping its collection mark (spec 071 decision 10).
- **No deck yet.** When the account has no deck the page shows a sentence and a link, and no form (spec 060 decision 23). The heading stays:

```html
<p class="c-empty">You have no decks yet. Add a deck first. <a href="/decks/new">New deck</a></p>
```
