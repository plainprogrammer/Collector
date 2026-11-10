# AddToDeck

The page that adds a card to a deck zone, from the card page's "Add to deck" button: a `ChoicePage` variant with a grouped select, a quantity and a choice of what to use. Shown here for a Magic: The Gathering card.

**Markup** — under `c-appbar--detail`: a page heading that names the card, then a `c-form` holding the Deck and zone select, a How many field, a `c-choices c-pick` fieldset of `c-check` radios and the actions: Add to deck (primary) and Cancel back to the card page.

```html
<header class="c-appbar c-appbar--detail">…back link to the card page, brand, nav, avatar…</header>
<main class="c-main c-page">
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
      <label class="c-check"><input required type="radio" value="proxy" name="use">A proxy of <span class="is-data">2X2 · 117</span> foil</label>
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
- **How many** is a `c-input` number field, `min` 1, with 1 in it at first.
- **What to use** has up to two options, in this order:
  - "My copies", shown only when copies are free. Its sentence gives the free count and where they are, "3 free: 2 in Blue binder, 1 in Red box", so the collector sees which places they would come from.
  - "A proxy of `2X2 · 117` foil", naming the printing the page shows, with `SET · number` in mono (`is-data`) and the finish after it.
- **With two options nothing is chosen at first**, and both radios are `required`, so the browser refuses a submission without a choice, as `ChoicePage` does. **With one option** (no copy is free, so only the proxy), that option is chosen (`checked`) at first (spec 060 decision 14, which makes the one exception to `ChoicePage`'s "Nothing is chosen at first").
- **The pick list** (`c-pick`, spec 060 FR-5). A fieldset is as wide as its widest child, so the fieldset has `min-width: 0` and its rows wrap and break inside a word (`overflow-wrap: anywhere`): a place name of 60 characters with no space in the "My copies" option wraps and the page has no horizontal overflow at 360px (spec 060 AC-5.2; spec 042 AC-7.1). A radio's row shows the 2px `focus` ring while its control has keyboard focus (AC-5.3), because `c-check` has none of its own.
- **What #255 decides**: which lots a count takes its copies from when the collector asks for fewer than are free, and the server's own refusals (a count past the free copies, a choice missing past the browser's check). This document draws the fields; #255 draws those refusals (spec 060 Non-Goals, Error Scenarios).
- **Cancel** and the app bar's back link return to the card page.
- **No deck yet.** When the account has no deck the page shows a sentence and a link, and no form (spec 060 decision 23). The heading stays:

```html
<p class="c-empty">You have no decks yet. Add a deck first. <a href="/decks/new">New deck</a></p>
```
