# Locations

The page where a collector names the places their collection is kept in, and the two pages behind it, rename and remove (spec 029). A location is a name and nothing else.

**Markup** — inside `.c-main.c-page.c-locations`: a page head, a one-field `Form` that adds a location, and the list. With no locations, a `c-empty` paragraph takes the list's place.

```html
<main class="c-main c-page c-locations">
  <div class="c-pagehead">
    <div><h1 class="c-pagehead__title">Locations</h1><p class="c-pagehead__stats">2 locations</p></div>
  </div>
  <form class="c-form c-locations__add" action="/locations" method="post">
    <div class="c-field">
      <label class="c-field__label" for="location_name">Name</label>
      <label class="c-input"><input type="text" id="location_name" name="location[name]" autocomplete="off"></label>
    </div>
    <div class="c-form__actions"><input type="submit" class="c-btn c-btn--primary" value="Add location"></div>
  </form>
  <ul class="c-list c-locations__list">
    <li>
      <span class="c-locations__name">Blue binder</span>
      <span class="c-list__end c-locations__actions">
        <a class="c-btn c-btn--ghost c-btn--sm" href="/locations/1/edit">Rename<span class="c-sr"> Blue binder</span></a>
        <a class="c-btn c-btn--ghost c-btn--sm" href="/locations/1/removal/new">Remove<span class="c-sr"> Blue binder</span></a>
      </span>
    </li>
  </ul>
  <!-- no locations: <p class="c-empty">No locations yet. Add a binder or a box to start recording where things are kept.</p> -->
</main>
```

- Every part is an existing component; `collector/additions.css` adds only what these pages need: a 560px limit on the add form (`c-locations__add`), wrapping rows (`c-locations__list li`), names that wrap anywhere (`c-locations__name`, so a 60-character name never scrolls the page sideways at 360px), the actions' gap, and the 44px floor below (`--touch-floor`, declared in `additions.css` because `tokens.css` has no variable for the design system's 44px touch-target floor).
- Every control on these pages, and the header's back button on the detail pages, is at least 44px by 44px on every pointer, not only on touch (the `c-btn--sm` actions and the `c-input` field are raised inside `.c-locations`). A field's focus ring is on its `c-input` wrapper.
- The list is in the order of the names' comparison key, then the name, both in code-point order, as the export writes them; there is no hand ordering.
- A failed add or rename answers 422 with the reason as the field's `c-field__error` and the typed text kept. The page works without scripting.
- Rename (`GET /locations/:id/edit`) is the same field with "Save" and "Cancel", under `c-appbar--detail`. Remove (`GET /locations/:id/removal/new`) is a `ConfirmPage`: "Remove Blue binder?", one paragraph saying that no lot or copy is removed, the `c-btn--danger` "Remove" and "Cancel". Removing is never done from the list directly.
- **What a location holds (spec 032).** Each row of the list carries `c-locations__holds` under the name (`c-list__meta`): "12 copies in 3 lots", "1 copy in 1 lot" or "Empty", on its own line (`flex-basis:100%`). A location that holds copies is not removed: `GET /locations/:id/removal/new` and a refused `DELETE` (409) render the refusal page, a `ConfirmPage` without the `c-btn--danger` button: the heading "“Blue binder” isn't empty", the sentence "“Blue binder” holds 12 copies in 3 lots. Move them before removing it.", a `c-list` (`c-locations__lots`, `id="held_lots"`) of at most 100 lots, each a link to the card page's copies with its line (set and number, language, finish, condition, price paid) and `×quantity`, then `c-locations__more` "and N more" (the `c-import__more` rule) and one "Back to locations" `c-btn--secondary`. The lot links are not `c-btn`, so `.c-locations__lots a` has the 44px floor of its own. The Location column of the card page's copies table and the Move copies page are existing components used as documented (`CollectionTable`, `Form`, `ConfirmPage`'s layout, `Menu`).
- The pages carry no tab bar tab as current (Locations is reached from More on phones and from the header on wide screens), and the copy names no collectible type.
