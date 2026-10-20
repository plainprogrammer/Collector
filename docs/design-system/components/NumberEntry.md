# NumberEntry

Adding cards from one set by collector number (spec 026): the chosen set and language, one line's fields in a row, a choice when a number matches more than one printing, and the list of what was added, with Undo and Done.

**Markup** — inside `.c-main.c-page`, after the page head:

```html
<div class="c-numentry">
  <div class="c-numentry__set">
    <p class="c-numentry__setname"><strong>Modern Horizons 3</strong> <span class="c-numentry__data">MH3</span></p>
    <form class="c-numentry__language" method="get">…<select id="number_entry_language">…</select><input type="submit" class="c-btn c-btn--secondary c-btn--sm" value="Change language"></form>
    <a class="c-btn c-btn--ghost c-btn--sm" href="…">Change set</a>
  </div>
  <form class="c-numentry__line" method="post" data-controller="number-entry">
    <div class="c-field"><label class="c-field__label" for="line_number">Number</label><label class="c-input"><input id="line_number" name="line[number]" autofocus></label></div>
    <div class="c-field"><label class="c-field__label" for="line_quantity">Quantity</label><label class="c-input"><input type="number" id="line_quantity" name="line[quantity]" value="1"></label></div>
    <div class="c-field"><label class="c-field__label" for="line_finish">Finish</label><select id="line_finish" name="line[finish]">…</select></div>
    <div class="c-numentry__add"><input type="submit" class="c-btn c-btn--primary" value="Add"></div>
  </form>
  <section id="number_entry_list" class="c-numentry__list">
    <div class="c-section__head"><h2 class="c-section__title">This list: 3 lines, 6 cards</h2><span class="c-section__actions"><button class="c-btn c-btn--secondary c-btn--sm">Done</button></span></div>
    <ul class="c-list"><li><span>Psychic Frog</span><span class="c-list__meta"><span class="c-numentry__data">MH3 · 47 · ×4</span> · <span class="is-muted">Nonfoil</span></span><span class="c-list__end"><button class="c-btn c-btn--secondary c-btn--sm">Undo</button></span></li></ul>
  </section>
</div>
```

- The line's fields sit in one row on wide screens (number, quantity, finish, Add) and two columns below 640px of the page, with Add full width. Tab order is number, quantity, finish, Add; Enter in any field adds the line.
- Set codes, numbers and quantities use the `data` face (`c-numentry__data`, Plex Mono).
- A set with one language states it in place of the language form: `<p>Language: <span class="c-numentry__data">EN</span></p>`.
- Add lines up with the inputs, not their labels: its cell is padded by the label's line and the field's gap. Below 640px it spans both columns.
- A special finish shows as the `FinishBadge`; any other as muted text, as in the copies table.
- When a number matches more than one printing, `c-numentry__choice` lists one secondary button per match above the line form, the first focused.
- A line whose copies changed in the collection shows a `c-tag` ("Changed in your collection") in place of Undo.
- The list shows the 10 newest lines; the rest are behind "Show all N" in a `<details>` (`c-numentry__more`).
- The page uses `.c-main.c-page`, the detail-page container (`c-page`, from `ItemPage`), so its parts respond to the page's width below 640px.
- The number and quantity inputs take the `data` face through `c-numentry__data-input`.
- Everything works without scripting. The `number-entry` Stimulus controller selects a rejected number and lets Enter on the finish select add the line.
