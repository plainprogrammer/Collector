# BulkConfirmPage

A `ConfirmPage` for a destructive action on many items at once, stating the exact number of items and lots before anything is removed.

**Markup** — the same `c-confirm` section as `ConfirmPage`, on a detail page whose app bar has a Back link to the bulk table. The destructive button names the action with the count; Cancel returns to the bulk table with the selection kept.

```html
<header class="c-appbar c-appbar--detail" data-turbo-permanent>
  <a class="c-btn c-btn--ghost c-btn--icon c-appbar__back" aria-label="Back" href="/collection?bulk=1"><svg …/></a>
  …
</header>
<main class="c-main c-page">
  <section class="c-confirm">
    <h1 class="c-pagehead__title">Remove 12 items?</h1>
    <p>This removes 12 items in 5 lots from your collection. You can undo this right afterwards.</p>
    <div class="c-form__actions">
      <form class="button_to" method="post" action="/collection/bulk_removals"><button class="c-btn c-btn--danger" type="submit">Remove 12 items</button></form>
      <a class="c-btn c-btn--secondary" href="/collection?bulk=1">Cancel</a>
    </div>
  </section>
</main>
```

- Reached from the bulk bar's Remove (`GET /collection/bulk_removals/new`); the bulk table never removes directly.
- The heading is the question with the exact item count ("Remove 1 item?", "Remove 9,999 items?"). The paragraph states items and lots in numbers and says whether it can be undone.
- The danger button repeats the count ("Remove 12 items"), so the collector confirms the number, not just the action. It is the only danger-coloured control on the page.
- After the removal the collector returns to the bulk table on the same filter and sort, and the status message offers Undo (see `StatusAction`).
- The page keeps the tab bar; on phones the app bar's Back link replaces the logo.
