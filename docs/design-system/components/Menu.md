# Menu

A "…" overflow menu for secondary actions, built on `<details>` so it works before any JavaScript loads.

**Markup** — the consumer provides the trigger (a `summary` styled as an icon `c-btn` with an `aria-label`) and the items: links for navigation, buttons (inside a form, or `button_to`) for actions, `c-menu__sep` between groups, `c-menu__item--danger` last.

```html
<details class="c-menu" data-controller="menu">
  <summary class="c-btn c-btn--secondary c-btn--icon" aria-label="More actions"><svg …/></summary>
  <div class="c-menu__list">
    <a class="c-menu__item" href="?view=table&bulk=1"><svg …/>Edit many</a>
    <div class="c-menu__sep"></div>
    <button class="c-menu__item c-menu__item--danger">Delete binder</button>
  </div>
</details>
```

- Its main job is responsive overflow: on narrow screens, actions that are buttons on wide screens move in here (`Edit many` in `FilterBar`, the bulk actions in `CollectionTable`). The same action appears once per width, never twice.
- A Stimulus `menu` controller adds close on outside click and Esc, arrow-key movement and focus return to the trigger; without it the menu still opens and closes.
- The list opens to the right edge of its trigger; add `left:0; right:auto` when the trigger sits at the left.
- Never hide the one primary action, or `Done`, in a menu.
