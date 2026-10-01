# ChoicePage

A detail page that asks for one choice from a short list, such as the condition to give every selected item, so the choice works without scripting.

**Markup** — a page heading that states what will change, then a `c-form` holding a `c-choices` fieldset of `c-check` radios and the actions: Apply (primary) and Cancel back to where the collector came from. The app bar has a Back link to the same place.

```html
<main class="c-main c-page">
  <div class="c-pagehead"><div><h1 class="c-pagehead__title">Set the condition of 12 items</h1></div></div>
  <form class="c-form" action="/collection/condition_change" method="post">
    <fieldset class="c-choices">
      <legend class="c-field__label">Condition</legend>
      <label class="c-check"><input required type="radio" value="near_mint" name="condition">Near mint (NM)</label>
      <label class="c-check"><input required type="radio" value="lightly_played" name="condition">Lightly played (LP)</label>
      …
      <label class="c-check"><input type="radio" value="" name="condition">Not specified</label>
    </fieldset>
    <div class="c-form__actions">
      <input type="submit" value="Apply" class="c-btn c-btn--primary">
      <a class="c-btn c-btn--secondary" href="/collection?bulk=1">Cancel</a>
    </div>
  </form>
</main>
```

- Used for Set condition from the bulk bar (`GET /collection/condition_change/new`). The heading names the action and the exact count ("Set the condition of 1 item").
- Options are radios in a fieldset with a visible legend, one per line, labelled in words with any short form after ("Near mint (NM)"). An option that clears the value says so ("Not specified").
- Nothing is chosen at first, and Apply without a choice is refused by the browser; a refusal from the server re-renders the page with an alert message.
- Apply is the only primary action; Cancel and the Back link return to the bulk table with the selection kept.
- Keep the list short enough to read at once (about ten options); a longer list belongs in a `FilterSelect`.
