# AdminCatalog

The admin's catalog page (spec 015): a panel per catalog type with its facts, what an admin can start for it, and how that is going.

**Markup** — a `c-pagehead` with a link to Jobs (repeated as a `c-admin__add` button for phones), then one `section.c-panel` per catalog type. Inside a panel: the type's title, an `EmptyState` while it has no cards, a `Details` list, one `section.c-operation` per operation, and "Recent refreshes" as a `c-list c-runs`.

```html
<section class="c-panel" id="catalog_mtg" aria-labelledby="catalog_mtg_title">
  <h2 class="c-section__title" id="catalog_mtg_title">Magic: The Gathering</h2>
  <dl class="c-details">
    <div><dt>Cards</dt><dd class="is-data">108,412</dd></div>
    <div><dt>Last applied refresh</dt><dd><time datetime="…">5 Oct 2026 03:20 UTC</time> <span class="c-tag">default-cards-20261005</span></dd></div>
    <div><dt>Next scheduled refresh</dt><dd>12 Oct 2026 03:15 UTC</dd></div>
  </dl>

  <section class="c-operation" id="mtg_refresh">
    <div class="c-operation__head">
      <h3 class="c-operation__title">Refresh</h3>
      <form class="c-operation__start" method="post" action="/admin/catalog/operation_starts">…<button class="c-btn c-btn--secondary" disabled>Refresh now</button></form>
    </div>
    <p class="c-operation__summary">Running.</p>
    <ol class="c-stages">…</ol>
    <dl class="c-details">…</dl>
  </section>

  <section class="c-operation">
    <h3 class="c-operation__title">Recent refreshes</h3>
    <ul class="c-list c-runs">
      <li><span>5 Oct 2026 03:15 UTC</span><span class="c-list__meta">scheduled · applied</span><span class="c-list__end">108,412 seen · 412 changed</span></li>
    </ul>
  </section>
</section>
```

- A panel is `surface-raised` with a `line` border and `radius-md`; its parts are `space-4` apart and each operation starts with a `line` rule. Its title wraps, so a long catalog name never forces sideways scrolling.
- An operation's summary is one sentence that begins with its state in a word ("Queued.", "Running.", "Applied.", "Failed while syncing cards: …"), so the state never depends on colour. A failed run whose job is in the failed list adds a brand link, "See its failed job".
- Each operation has at most one button, named for what it starts ("Refresh now", "Build art index"). It is `c-btn--secondary`, and disabled while the operation is queued or running or can't run yet; the summary says why. "Refresh now" is `c-btn--primary` only while the catalog has no cards, when it is the page's one next step. An operation that is switched off shows no button, and its summary says how to switch it on.
- While the catalog has no cards and nothing is in flight, the panel opens with an `EmptyState` that says what the first refresh does and which languages are set.
- Times are absolute UTC (`9 Oct 2026 03:15 UTC`, in a `<time>`); a last-progress or heartbeat time adds the relative form in brackets, "(2 minutes ago)".
- While anything is queued or running, `<main>` carries `data-controller="poll"` and the page keeps itself current, as `AdminJobs` describes; it stops when the work ends.
- A new catalog type gets its panel from its source; the page's markup never names a type.
