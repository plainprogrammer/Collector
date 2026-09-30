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
- It is at most 220px wide; long option names are clipped by the browser, never wrapped.
- The choice is a URL parameter of the filter bar's GET form, so results, the back button and shared links all keep it.
