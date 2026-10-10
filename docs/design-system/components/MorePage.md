# MorePage

The page behind the tab bar's "More" tab: who is signed in, account links, and sign out.

**Markup** — a heading and a `c-list c-more`, one row per entry; the consumer adds the admin links (users, catalog, jobs) only for admins.

```html
<main class="c-main">
  <h1 class="c-pagehead__title">More</h1>
  <ul class="c-list c-more">
    <li><span>Signed in as <strong>Sam</strong></span><span class="c-list__meta">sam@example.com</span></li>
    <li><a href="/admin/users">Users and sign-up</a></li>
    <li><a href="/admin/catalog">Catalog</a></li>
    <li><a href="/admin/jobs">Jobs</a></li>
    <li><form class="button_to" method="post" action="/session"><input type="hidden" name="_method" value="delete"><button class="c-btn c-btn--secondary" type="submit">Sign out</button></form></li>
  </ul>
</main>
```

- It holds what the header's account menu holds on wide screens, so phones reach everything from the tab bar.
- No section is marked current in the header or tab bar on this page.
- Sign out is a form (`button_to`, DELETE), never a link, and ends only this session.
- Rows may wrap on narrow screens (`flex-wrap`), so a long email address never forces sideways scrolling.
