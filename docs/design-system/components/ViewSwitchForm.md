# ViewSwitchForm

How the collection page's `ViewSwitch` and `Edit many` work as forms, so switching views and entering bulk mode carry the current filter and sort without scripting or links.

**Markup** — the `c-seg` options and both `Edit many` buttons sit in the filter bar but submit forms by id. The forms are hidden and rendered with the results, so they always carry the page's current filter and sort.

```html
<form class="c-filterbar" role="search" action="/collection" method="get">
  …
  <div class="c-filterbar__end">
    <button type="submit" form="edit-many" class="c-btn c-btn--secondary c-btn--sm c-filterbar__bulk">Edit many</button>
    <div class="c-seg" role="group" aria-label="View">
      <button type="submit" form="view-switch" name="view" value="grid" aria-pressed="true"><svg …/><span class="c-seg__label">Grid</span></button>
      <button type="submit" form="view-switch" name="view" value="table" aria-pressed="false"><svg …/><span class="c-seg__label">Table</span></button>
    </div>
    <details class="c-menu c-filterbar__more" data-controller="menu">
      <summary class="c-btn c-btn--secondary c-btn--sm c-btn--icon" aria-label="More actions"><svg …/></summary>
      <div class="c-menu__list"><button type="submit" form="edit-many" class="c-menu__item">Edit many</button></div>
    </details>
  </div>
</form>
<form id="view-switch" action="/collection" method="get" hidden>
  <input type="hidden" name="q" value="bolt"><input type="hidden" name="sort" value="set"><input type="hidden" name="dir" value="asc">
</form>
<form id="edit-many" action="/collection/selection" method="post" hidden>
  <input type="hidden" name="q" value="bolt"><input type="hidden" name="sort" value="set"><input type="hidden" name="dir" value="asc">
</form>
…
```

- The view switch is a `GET` form: the chosen view is a URL param and the page that names it saves the preference. A request the browser marks as a prefetch never saves it.
- `Edit many` is a `POST`, never a link, because it starts a new, empty selection; it opens the bulk table with the same filter and sort. On wide screens it is a button in the bar; below 640px it moves into the "…" menu (`c-filterbar__more`).
- The hidden forms carry only the filter and sort that apply; empty values are left out of the URL.
- In bulk mode the switch is inert and outside the bulk form: Table is pressed, Grid is disabled, and neither submits (see `BulkForm`).
