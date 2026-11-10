# UseMyCopy

The page that replaces proxies in a deck zone with copies the collector owns: the free copies as lots, each with its own quantity field. Shown here for a Magic: The Gathering card.

**Markup** — under `c-appbar--detail`: a heading that names the card, a line that names the proxy row, then a `c-form` holding a `c-choices c-pick` fieldset of lot rows in groups, and the actions: Use these copies (primary) and Cancel back to the deck.

```html
<header class="c-appbar c-appbar--detail">…back link to the deck, brand, nav, avatar…</header>
<main class="c-main c-page">
  <div class="c-pagehead"><div>
    <h1 class="c-pagehead__title">Use my copy of Lightning Bolt</h1>
    <p class="c-pagehead__stats">Replaces 1 proxy in Izzet Tempo › Main · <span class="is-data">2X2 · 117</span> foil</p>
  </div></div>
  <form class="c-form" action="/decks/…/proxies/…/replacement" method="post">
    <fieldset class="c-choices c-pick">
      <legend class="c-field__label">Which copies</legend>
      <p class="c-pick__group">This printing</p>
      <div class="c-pick__lot">
        <label class="c-pick__label" for="lot_1"><span class="is-data">2X2 · 117</span> foil, Near mint, Blue binder, ×1 free</label>
        <label class="c-input"><input id="lot_1" name="lots[1]" type="number" min="0" max="1" value="0" inputmode="numeric"></label>
      </div>
      <div class="c-pick__lot">
        <label class="c-pick__label" for="lot_2"><span class="is-data">2X2 · 117</span> foil, Lightly played, Red box, ×2 free</label>
        <label class="c-input"><input id="lot_2" name="lots[2]" type="number" min="0" max="2" value="0" inputmode="numeric"></label>
      </div>
      <p class="c-pick__group">Other printings</p>
      <div class="c-pick__lot">
        <label class="c-pick__label" for="lot_3"><span class="is-data">MM3 · 122</span>, Near mint, Red box, ×1 free</label>
        <label class="c-input"><input id="lot_3" name="lots[3]" type="number" min="0" max="1" value="0" inputmode="numeric"></label>
      </div>
    </fieldset>
    <div class="c-form__actions">
      <input type="submit" value="Use these copies" class="c-btn c-btn--primary">
      <a class="c-btn c-btn--secondary" href="/decks/…">Cancel</a>
    </div>
  </form>
</main>
```

- **The page** (spec 060 decision 15). The heading names the card ("Use my copy of Lightning Bolt"). The muted line under it names the proxy row: how many proxies it holds, the deck and zone written Deck › Zone, and the printing and finish, "Replaces 1 proxy in Izzet Tempo › Main · 2X2 · 117 foil".
- **A lot row** reads the lot's `set · number`, its finish, its condition, its place and "×N free", N being the copies of that lot that are free to use. That text is the row's `label`, and the label names the field: the field's accessible name contains the lot's `set · number`, finish, condition and place (spec 060 AC-6.4). A click on the label focuses the field.
- **The field** is a `c-input` number field with `min` 0 and `max` the lot's free count, so one lot can never be asked for more copies than it has free. It is at least 44px high and 6rem wide, so it is hard to mis-tap on a phone (spec 060 decision 15, AC-6.2). When it has keyboard focus the 2px `focus` ring shows on its `c-input` wrapper (AC-6.3).
- **Every field is 0 at first**: nothing is chosen, and the collector enters the number of copies to take from each lot, so copies from several lots can be used at once.
- **The groups.** "This printing" holds the lots of the proxy's own printing and finish. "Other printings" holds the rest. The group label is `c-pick__group` (`ink-muted`, 12px, weight 600). A group with no lot is left out, label included.
- **The rule on the sum.** The copies entered across all the lots must total from 1 up to the proxy row's proxies; a replacement lowers the proxy count by the copies used. With no JavaScript no field's `max` can follow the others' sum, so the server checks it.
- **The row block** (`c-pick__lot`, spec 060 FR-5): a bordered `surface-raised` block with `radius-md` corners, the label first and the field below it, `space-3` between rows. The label wraps and breaks inside a word, so a place name of 60 characters with no space breaks inside the word and the page has no horizontal overflow at 360px (AC-6.2).
- **Errors** answer 422, re-render the page with every entry kept and use the `c-field__error` of `Form`, one sentence each, with `aria-describedby` pointing at it (spec 060 decision 23):
  - The sum is zero or more than the row's proxies: "Enter a number from 1 to N." (N is the row's proxies), under the lots' group (the fieldset).
  - One lot's quantity is over its free copies, or the copies changed meanwhile: "Enter a number from 0 to M." (M is that lot's free copies), under that lot's field.
- **Empty state.** When no copy is free the page shows a sentence and a link back to the deck, and no form (spec 060 decision 23):

```html
<p class="c-empty">You have no free copy of Lightning Bolt to use. <a href="/decks/…">Back to Izzet Tempo</a></p>
```

- **Cancel** and the app bar's back link return to the deck. Use these copies is the only primary action, and the page works without scripting.
