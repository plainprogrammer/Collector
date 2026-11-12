# UseMyCopy

The page that replaces the proxies of a deck zone with copies the collector owns: the free copies of the card as lots, each with its own quantity field. Shown here for a Magic: The Gathering card; the page names no collectible in its rules. Built by spec 070 (#257) as drawn by spec 060 decision 15 (ruled B: a quantity on every lot), with the changes listed under "As built".

**Route** — `GET /decks/:deck_id/proxies/:id/replacement/new` is the page and `POST /decks/:deck_id/proxies/:id/replacement` is the form's action: the proxy by its id under its deck (`Decks::Proxies::ReplacementsController`). It is a link in the row menu of the deck page (`DeckPage`), never a form there.

**Markup** — under `c-appbar--detail`, a `main` that carries `c-main c-page c-decks`: a heading that names the card, a line that names the proxy row, then a `c-form` holding a `c-choices c-pick` fieldset of lot rows in groups, and the actions: Use these copies (primary) and Cancel back to the deck.

```html
<header class="c-appbar c-appbar--detail">…back link to the deck, brand, nav, avatar…</header>
<main class="c-main c-page c-decks">
  <div class="c-pagehead"><div>
    <h1 class="c-pagehead__title">Use my copy of Lightning Bolt</h1>
    <p class="c-pagehead__stats">Replaces 1 proxy in Izzet Tempo › Main · <span class="is-data">2X2 · 117</span>, Foil</p>
  </div></div>
  <form class="c-form" action="/decks/…/proxies/…/replacement" method="post">
    <fieldset class="c-choices c-pick">
      <legend class="c-field__label">Which copies</legend>
      <p class="c-pick__group">This printing</p>
      <div class="c-pick__lot">
        <label class="c-pick__label" for="lot_1"><span class="is-data">2X2 · 117</span> Foil, Near mint, paid $1.25, Blue binder, ×1 free</label>
        <label class="c-input"><input id="lot_1" name="lots[1]" type="number" min="0" max="1" step="1" value="0" inputmode="numeric"></label>
        <input type="hidden" name="shown[1]" value="1">
      </div>
      <div class="c-pick__lot">
        <label class="c-pick__label" for="lot_2"><span class="is-data">2X2 · 117</span> Foil, Lightly played, Red box, ×2 free</label>
        <label class="c-input"><input id="lot_2" name="lots[2]" type="number" min="0" max="2" step="1" value="0" inputmode="numeric"></label>
        <input type="hidden" name="shown[2]" value="2">
      </div>
      <p class="c-pick__group">Other printings</p>
      <div class="c-pick__lot">
        <label class="c-pick__label" for="lot_3"><span class="is-data">MM3 · 122</span>, Near mint, No location, ×1 free</label>
        <label class="c-input"><input id="lot_3" name="lots[3]" type="number" min="0" max="1" step="1" value="0" inputmode="numeric"></label>
        <input type="hidden" name="shown[3]" value="1">
      </div>
    </fieldset>
    <div class="c-form__actions">
      <input type="submit" value="Use these copies" class="c-btn c-btn--primary">
      <a class="c-btn c-btn--secondary" href="/decks/…">Cancel</a>
    </div>
  </form>
</main>
```

- **The page** (spec 060 decision 15; spec 070 AC-2.1). The heading names the card ("Use my copy of Lightning Bolt"). The muted line under it names the proxy row: how many proxies it holds ("1 proxy", "2 proxies"), the deck and zone written Deck › Zone, and then, after " · ", the printing in mono (`SET · number`, with ` · LANG` after it for a language other than English), and ", " and the finish as the collectible's vocabulary labels it ("Foil"), only when the proxy has one: "Replaces 1 proxy in Izzet Tempo › Main · 2X2 · 117, Foil".
- **`main` carries `c-decks`** (spec 070 AC-6.2), as every deck page's does: it gives the buttons the 44px touch floor (`.c-decks .c-btn`) and lets a 60-character deck, zone or card name with no space break inside a word in the heading (`.c-decks .c-pagehead__title`).
- **A lot row** reads, in this order and separated by commas: the printing in mono (`SET · number`, with ` · LANG` for a language other than English), then the finish as the vocabulary labels it ("Foil", straight after the printing with a space), the condition as the vocabulary labels it ("Near mint"), "paid $1.25" in the account's currency, the place ("No location" when the lot is in none) and "×N free", N being the copies of that lot that are free to use. The finish, the condition and the price are left out when the lot has none (spec 070 decision 4). The price is in the label because two lots of one printing, finish, condition and place that differ only by price would read the same; spec 060's label left it out. That text is the row's `label`, and the label names the field: the field's accessible name contains the lot's printing, finish, condition, price and place (spec 060 AC-6.4). A click on the label focuses the field.
- **The field** is a `c-input` number field with `min` 0 and `max` the lot's free count, so one lot can never be asked for more copies than it has free. It is at least 44px high and 6rem wide, so it is hard to mis-tap on a phone (`.c-pick__lot .c-input`; spec 060 decision 15, AC-6.2). When it has keyboard focus the 2px `focus` ring shows on its `c-input` wrapper (AC-6.3).
- **The hidden `shown[<lot id>]` field** sits next to each field and holds the lot's quantity as the page drew it. It is not shown and has no label and no id. The form posts what it showed: a lot with a number above 0 whose quantity is no longer the shown one, or that is no longer free, is refused with "Those copies changed…" (below), which is what stops two submits of one form (two tabs, a double click) from moving twice, and what makes a missing or non-digit value fail closed (spec 070 decision 9, AC-3.9, AC-3.11). A page that follows a refusal is written again from a fresh read, with every `shown` field holding what the lot holds now and the numbers typed kept, so correcting the numbers and submitting again succeeds.
- **Every field is 0 at first**: nothing is preselected, and the collector enters the number of copies to take from each lot, so copies from several lots can be used at once. A blank field is 0.
- **The groups.** "This printing" holds the lots whose printing and finish are the proxy's. "Other printings" holds the rest, another finish of the proxy's printing included. The group label is `c-pick__group` (`ink-muted`, 12px, weight 600). A group with no lot is left out, label included.
- **The order of the lots** within a group is the order of the card page's "Your copies": newest printing first, then finish, condition, price paid and place. Retired printings are listed. A lot in any deck zone (Considering included) is never listed: only free copies are (spec 070 decision 2).
- **The rule on the sum.** The copies entered across all the lots must total from 1 up to the proxy row's proxies; a replacement lowers the proxy count by the copies used, and a total equal to the count removes the proxy. With no JavaScript no field's `max` can follow the others' sum, so the server checks it (spec 070 decision 13).
- **The fieldset** carries `aria-describedby` pointing at its error paragraphs while it has any (`replacement-error`, then `replacement-error-2`), and each lot's number field carries one pointing at that lot's (`lot_<id>-error`).
- **The row block** (`c-pick__lot`, spec 060 FR-5): a bordered `surface-raised` block with `radius-md` corners, the label first and the field below it, `space-3` between rows; a refused lot's block also carries `c-field--invalid`. The label wraps and breaks inside a word, so a place name of 60 characters with no space breaks inside the word and the page has no horizontal overflow at 360px (AC-6.2).
- **Errors** answer 422, write the page again with every number kept and use the `c-field__error` of `Form`, one sentence each, with `aria-describedby` pointing at it (spec 060 decision 23, extended by spec 070 decision 9):
  - One lot's number is not a whole number from 0 to its free copies: "Enter a number from 0 to M." (M is that lot's free copies now), under that lot's field.
  - The sum is zero or more than the row's proxies, and no single field is refused: "Enter a number from 1 to N." (N is the row's proxies now), under the lots' fieldset.
  - A move would put more than 9,999 copies in one lot of the zone: "One lot can hold at most 9,999 copies.", under that lot's field. Nothing is moved, the earlier lots included.
  - A lot with a number above 0 is no longer free or no longer holds what the page showed (removed, taken into a zone, or had copies moved or removed since): "Those copies changed. Check the numbers and try again.", under the lots' fieldset. A lot of another account or another card counts as no longer free, so the page never tells them apart. A lot that also exceeds its free copies shows its own "Enter a number from 0 to M." too.
  - A lot whose stored finish or condition the vocabulary no longer lists, with a number above 0: "Edit this copy first: its finish or condition isn't offered any more.", under that lot's field. The lot stays listed and is never moved by skipping its validation; the collector changes it with Edit copy first.
- **Empty state.** When no copy is free the page shows a sentence and, as a secondary button that is a link, "Back to <Deck>" (a `c-btn c-btn--secondary` in a `c-form__actions` block, so it has the 44px touch floor), and no form (spec 060 decision 23; spec 070 AC-2.6). The fieldset's sentence ("Those copies changed…") can still show above it when the only lot was taken meanwhile:

```html
<p class="c-empty">You have no free copy of Lightning Bolt to use.</p>
<div class="c-form__actions"><a class="c-btn c-btn--secondary" href="/decks/…">Back to Izzet Tempo</a></div>
```

- **Cancel** and the app bar's back link return to the deck. Use these copies is the only primary action. On success the answer is 303 to the deck page with the notice "Replaced 2 proxies of Lightning Bolt (MH2 · 138, Foil) in Izzet Tempo › Main with copies you own." The page works without scripting and carries no script of its own (spec 070 decision 13).

**As built (spec 070, #257), against spec 060's drawing:** `main` carries `c-decks`; the lot's label carries the price and writes the finish as the vocabulary labels it ("Foil", not "foil"); each field has a hidden `shown[<lot id>]`; the fieldset and the fields carry `aria-describedby`; two sentences are new ("Those copies changed…", "Edit this copy first…"); the empty state's link is a secondary button. The page is built as drawn otherwise, and no CSS was added for it: its rules are spec 060's `c-pick` rules in `collector/additions.css`.

Sources: spec 060 decision 15, decision 23, AC-6.1 to AC-6.4; spec 070 decisions 1 to 4, 9, 11 and 13, AC-2.1 to AC-2.6, AC-3.5 to AC-3.9, AC-3.14, AC-6.2 to AC-6.4.
