# ConfirmPage

A page that asks before a destructive action and says exactly what it will remove, so the confirmation works without scripting.

**Markup** — the consumer provides a `c-confirm` section with a question as the heading, one paragraph stating the consequence, and the actions: the destructive `button_to` first, then "Cancel" back to where the collector came from.

```html
<main class="c-main c-page">
  <section class="c-confirm">
    <h1 class="c-pagehead__title">Remove 3 × Lightning Bolt?</h1>
    <p>M10 · 146 · EN. This removes the whole lot from your collection.</p>
    <div class="c-form__actions">
      <form class="button_to" method="post" action="/lots/1"><input type="hidden" name="_method" value="delete"><button class="c-btn c-btn--danger" type="submit">Remove</button></form>
      <a class="c-btn c-btn--secondary" href="/catalog/entries/…">Cancel</a>
    </div>
  </section>
</main>
```

- Used for removing a lot (`GET /lots/:id/removal/new`) and deleting a user (`GET /admin/users/:id/deletion/new`). The "…" menu links here; it never deletes directly.
- The heading is the question, with exact numbers and names: "Remove 3 × Lightning Bolt?", "Delete Sam?".
- The paragraph states what will be lost, in numbers ("…all 1,204 copies in their collection. It can't be undone."), never a vague "Are you sure?".
- The destructive button uses `c-btn--danger` and names the action ("Remove", "Delete Sam"); it is the only danger-coloured control on the page.
- The section is at most 560px wide; the page keeps the app header and tab bar of the page it came from.
