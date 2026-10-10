# AdminJobs

The admin's jobs pages (spec 015): the background jobs by state, one job in full, and the confirmation before a failed job is discarded.

**Markup, the list** — a `c-pagehead` with a link to Catalog (repeated as a `c-admin__add` button for phones), a GET form of `Chip` filter chips with each state's count, then a `c-table c-jobs` inside `.c-collection`, a `Pager`, or an `EmptyState`.

```html
<form class="c-jobs__filters" action="/admin/jobs" method="get">
  <button name="status" value="failed" class="c-filter" aria-pressed="true">Failed <span class="c-jobs__count">2</span></button>
  <button name="status" value="running" class="c-filter" aria-pressed="false">Running <span class="c-jobs__count">0</span></button>
  …
</form>

<div class="c-collection">
  <table class="c-table c-jobs">
    <thead><tr><th>Job</th><th class="is-opt">Queue</th><th class="is-opt">Failed</th><th><span class="c-sr">Actions</span></th></tr></thead>
    <tbody>
      <tr>
        <td class="c-jobs__job"><div class="c-table__item"><div>
          <a href="/admin/jobs/12">Catalog::RefreshJob</a>
          <span class="c-jobs__detail">["mtg","manual"]</span>
          <span class="c-jobs__detail">Catalog::Sources::TransientError: GET /bulk-data returned 503</span>
          <span class="c-table__sub">sync · 9 Oct 2026 03:15 UTC (10 minutes ago)</span>
        </div></div></td>
        <td class="is-opt is-data">sync</td>
        <td class="is-opt">9 Oct 2026 03:15 UTC (10 minutes ago)</td>
        <td class="c-table__actions">…"…" menu: Retry, Discard…</td>
      </tr>
    </tbody>
  </table>
</div>
```

**Markup, one job** — a detail page (`c-main c-page`, `c-appbar--detail`, `c-crumbs`): the job's class as the title with its state under it, "Retry" and "Discard…" for a failed job, a `Details` list, then its arguments and, for a failed job, the error and backtrace in `pre.c-pre`.

- The filters are a GET form, so the state is in the URL (`?status=failed`) and works without scripting. The pressed chip is the state on show; "Failed" is the default. Each chip ends with its count, which stands where `Chip`'s check icon would: exactly one chip is always pressed, and `brand-tint`, the `brand` border and the semibold label mark it.
- The time column is the one that matters to the state (Failed, Started, Queued, Due) and its heading says which. Times are absolute UTC with the relative form in brackets.
- The job cell wraps (`c-jobs__job`), so a long error never forces sideways scrolling; `c-jobs__detail` lines are mono and `ink-muted`. Queue and time are `is-opt` columns that drop on phones and reappear in the `c-table__sub` line.
- A queued job held back by a concurrency limit says "waiting" after its arguments.
- Only a failed job has actions. "Retry" acts at once and is announced in the status message ("Retrying Catalog::RefreshJob."). "Discard…" leads to a `ConfirmPage` that names the job and says it won't run again.
- The confirmation's sentence quotes the job's arguments, so it carries `c-job__note` and wraps anywhere.
- An empty state names the state: "No failed jobs."
- `pre.c-pre` is `surface-sunken`, mono, and scrolls sideways inside itself.
- While any job is running or queued, `<main>` carries `data-controller="poll"`: the page refreshes itself about every 2 seconds with a Turbo morph, keeping the scroll position, and stops when no job is running or queued. The refresh waits while a row's menu is open. Nothing on the page needs the script: reloading shows the same thing.
