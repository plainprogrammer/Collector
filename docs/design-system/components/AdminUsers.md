# AdminUsers

The admin's users list: the sign-up setting, an "Add a user" action and a table of users with each one's copies.

**Markup** — a `c-pagehead` with the count and the primary action, a phone-only copy of that action (`c-admin__add`), the `c-admin__signup` setting row, then a `c-table` inside `.c-collection` (see `CollectionTable` and `TableActions`).

```html
<div class="c-pagehead">
  <div><h1 class="c-pagehead__title">Users and sign-up</h1><p class="c-pagehead__stats">2 users</p></div>
  <div class="c-pagehead__actions"><a class="c-btn c-btn--primary" href="/admin/users/new">Add a user</a></div>
</div>
<p><a class="c-btn c-btn--secondary c-admin__add" href="/admin/users/new">Add a user</a></p>

<section class="c-admin__signup">
  <p>Sign-up is closed: only you can add users.</p>
  <form class="button_to" method="post" action="/admin/sign_up_setting">…<button class="c-btn c-btn--secondary" type="submit">Open sign-up</button>…</form>
</section>

<div class="c-collection">
  <table class="c-table">
    <thead><tr><th>Name</th><th class="is-opt">Email</th><th class="is-opt">Role</th><th class="is-num">Copies</th><th><span class="c-sr">Actions</span></th></tr></thead>
    <tbody>
      <tr>
        <td><div>Sam<span class="c-table__sub">sam@example.com · Admin</span></div></td>
        <td class="is-opt is-data">sam@example.com</td>
        <td class="is-opt">Admin</td>
        <td class="is-num">1,204</td>
        <td class="c-table__actions">…"…" menu: Edit, Delete…</td>
      </tr>
    </tbody>
  </table>
</div>
```

- The setting row says in one sentence what the current state means ("Sign-up is open: anyone who can reach this instance can create an account.") and offers the one button that changes it.
- Below 640px the page head's actions are hidden by the export, so `c-admin__add` shows the same action under the head; it is hidden on wide screens, so the action appears once per width.
- Email and role are `is-opt` columns; on phones they drop and reappear in the name's `c-table__sub` line.
- Copies are exact, right-aligned mono numbers.
- The row menu offers "Edit" and, except on your own row, "Delete…", which leads to a `ConfirmPage`.
