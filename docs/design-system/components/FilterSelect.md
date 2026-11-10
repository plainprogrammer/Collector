# FilterSelect

A select inside the filter bar that narrows results by one choice, such as the set.

**Markup** — the consumer provides a `c-select` label wrapping a visually hidden name and a native `<select>`, placed in `c-filterbar__filters`, followed by a submit button for browsers without scripting.

```html
<div class="c-filterbar__filters">
  <label class="c-select"><span class="c-sr">Set</span><select name="set" id="set"><option value="">All sets</option><option value="m10">Magic 2010 (M10)</option>…</select></label>
  <input type="submit" value="Search" class="c-btn c-btn--secondary c-btn--sm">
</div>
```

- The select is a native element: it works with keyboard, screen readers and phone pickers without scripting.
- Its name is announced (`c-sr` text), even though the visible first option ("All sets") already implies it.
- It matches the filter bar's small controls: 28px tall, `line-strong` border, `radius-md`; on touch screens it grows to at least 40px.
- It is at most 220px wide; long option names are clipped by the browser, never wrapped. The one exception is the collection's location filter, whose label also carries `c-select--wide`: its cap is 300px when the collection is 640px wide or wider (so a zone, the part that tells zones apart, shows) and 220px below that, where the filter row scrolls sideways. The Set select on search and the Language select on number entry stay at 220px (spec 057 decisions 4, 18).
- When the account has a deck, the location filter lists "All locations" and "No location" first, outside any group, then an `optgroup` "Places", then an `optgroup` "Decks". Inside "Decks" each deck has one option "<Deck> (all zones)" first, then its zones written "Deck › Zone" (spec 057 decisions 2, 3, 15). With no deck it is flat, as it is today. The group and option styling is the same as `Form`'s, and the browser draws the open list.
- The choice is a URL parameter of the filter bar's GET form, so results, the back button and shared links all keep it.
- Used by the catalog search (the set, button "Search") and the collection page (the location, button "Filter", spec 037). In the collection's bulk mode the select and its button join the bulk form by its id (`form="bulk"`), and the button is the bulk form's default "Filter" submit made visible, so Enter in the name field still applies the filters; it is shown only while the account has a location.
