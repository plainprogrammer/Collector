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
- A Stimulus `menu` controller adds close on outside click and Esc, focus return to the trigger on Esc, and, on a phone, the scroll below; without it the menu still opens and closes. (There is no arrow-key movement: an earlier version of this line, and the comment above `.c-menu` in `components.css`, claimed it; the export's comment is left as it is and the next export fixes it, spec 074.)
- **A menu opened near the bottom of a phone is scrolled clear of the tab bar** (spec 074, #326). Below 640px, on a page with a tab bar, the controller scrolls the page just far enough that the open list's bottom edge ends `space-2` above the bar (plus `env(safe-area-inset-bottom)`), and a list taller than the room between the app bar and the bar starts just under the app bar. It does nothing when the list is already clear, at 640px and wider, or on a page with no tab bar (`c-shell--untabbed`), and it scrolls instantly under `prefers-reduced-motion: reduce` and smoothly otherwise. The clearances are `scroll-margin-top` and `scroll-margin-bottom` on `.c-menu__list` and a room box (an `::after` on the open list, as wide as the list, `pointer-events: none`) that lets the page scroll that far at its end, all in one block of `additions.css`; a menu is never put inside a scrolling container, or the room box would show as a scrollbar in it. A menu is closed before Turbo caches the page (`turbo:before-cache`), so Back restores the page with every menu closed and without a scroll. The 57px (app bar) and 67px (tab bar) in the block are the bars' drawn heights: change them with the bars.
- The list opens to the right edge of its trigger; add `left:0; right:auto` when the trigger sits at the left.
- Never hide the one primary action, or `Done`, in a menu.
