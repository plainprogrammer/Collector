# AuthPage

The sign-in and sign-up page: the brand-only header, a heading and one `Form`, centred in a narrow column.

**Markup** — the page renders the brand-only `AppHeader` (logo, no navigation, no tab bar) and puts `c-auth` on `c-main`; the consumer provides the heading, an optional explanatory paragraph and the form.

```html
<header class="c-appbar" id="appbar">
  <span class="c-appbar__brand">…wordmark and mark, alt="Collector"…</span>
</header>
<main class="c-main c-auth">
  <h1 class="c-pagehead__title">Sign in</h1>
  <form class="c-form" action="/session" method="post">
    <div class="c-field">
      <label class="c-field__label" for="email_address">Email</label>
      <label class="c-input"><input type="email" autocomplete="username" required id="email_address" name="email_address"></label>
    </div>
    <div class="c-field">
      <label class="c-field__label" for="password">Password</label>
      <label class="c-input"><input type="password" autocomplete="current-password" required id="password" name="password"></label>
    </div>
    <div class="c-form__actions"><input type="submit" class="c-btn c-btn--primary" value="Sign in"></div>
  </form>
</main>
```

**Closed state** — when sign-up is closed, the sign-up page keeps its heading and replaces the form with the reason and a way out:

```html
<main class="c-main c-auth">
  <h1 class="c-pagehead__title">Sign up</h1>
  <p>Sign-up is closed on this instance. Ask the person who runs it for an account.</p>
  <p><a class="c-btn c-btn--secondary" href="/session/new">Sign in</a></p>
</main>
```

- The column is at most 480px wide and centred; its parts are spaced with `space-6`.
- The header shows only the brand: nothing else is reachable before signing in. Its logo images carry `alt="Collector"`, since there is no link text.
- The first-run page is titled "Set up Collector" and says in one sentence that this account becomes the instance's admin; its button says "Create admin account".
- Use the right `autocomplete` values (`username`, `current-password`, `new-password`) so password managers work.
- A failed sign-in says so in the status region without saying which of email or password was wrong.
