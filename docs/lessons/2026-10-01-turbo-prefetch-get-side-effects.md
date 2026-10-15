---
date: 2026-10-01
spec: "006"
tags: [hotwire, turbo, prefetch, spec-review, session, system-spec]
---

# Lesson: Turbo 8 hover prefetch turns GET side effects into bugs

## Context

Spec 006 added a grid/table view switch whose choice is saved per user, plus a bulk mode whose selection is stored on the server. The design system's docs describe the switch and `Done` as links (`?view=table`, `href="?view=grid"`).

## What happened

Three Fable spec reviews each found a blocker in the same family:
- v2 saved the view on any GET naming it. Turbo 8 (turbo-rails 2.0.23) prefetches `<a>` links on hover, and nothing in the app turned that off, so pointing at "Table" would have saved it.
- v3 fixed the view but made `Done` (and "leaving bulk mode") a link that cleared the selection. A hover would have wiped the collector's ticks.
- The fix that held:
  - State changes go only through buttons and POST/PATCH forms (`Edit many`, `Done`, the bulk form).
  - The view switch is buttons in a GET form. Turbo never prefetches buttons.
  - The server refuses to save from prefetch-marked requests (`Sec-Purpose`, `X-Sec-Purpose`, `X-Moz`, `Purpose`).
  - A system spec counts `turbo:before-prefetch` events, with a positive control.

## What to do next time

When a spec has a GET that changes anything (preferences, selections, "last seen" markers), treat hover prefetch as a requirement from the start:
- Make the trigger a button.
- Ignore prefetch headers on the server.
- Test both: a request spec with the headers, and a system spec that counts `turbo:before-prefetch`.

Don't copy link-based markup from the design docs for anything with side effects.

## Second instance: the return path (spec 023, 2026-10-14)

A visitor's catalog GET stores `request.fullpath` in `session[:return_to_after_authenticating]` (an `after_action`), so signing in lands back on that page. With hover prefetch on, pointing at a card tile on the way to "Sign in" prefetched the card page. That prefetch is a request carrying the session cookie, and it would overwrite the return path. The `prefetch?` header check (lifted unchanged from `CollectionsController` to `ApplicationController`) refuses to store a prefetch. Belt and braces, visitor catalog pages also render `<meta name="turbo-prefetch" content="false">` (`catalog/_visitor_head`), so nothing is prefetched at all.

Proving the absence in a browser took a settle marker:
- A check that `#prefetched` never appears passes at once, before Turbo has had a chance to prefetch.
- The example's page script adds `#prefetched` on `turbo:before-prefetch`, and adds `#settled` 1s after the pointer enters a tile. Turbo prefetches about 100ms after hover.
- The spec waits for `#settled`, then asserts no `#prefetched`. There is no Ruby `sleep`.
- Mutation proof: dropping the meta line made it fail ("expected not to find css \"#prefetched\", found 1 match"). It also made the hover → click → sign in example land on `/catalog/entries?q=bolt&set=` instead of the card.

**Rule (added):** any session write in an `after_action` on a GET (return paths, "last seen", breadcrumbs) is a prefetch side effect. Exclude prefetches on the server, and turn prefetch off on the pages where it can fire. To test a prefetch *not* happening, assert after an in-page settle marker, never against nothing.

## Signals to watch for

- A spec sentence like "the URL param … is saved".
- A design-system snippet using `<a>` for a stateful action.
- Any controller writing in `show`/`index`.
- `session[...] =` in an `after_action` or `before_action` on a GET.
- A system spec that asserts something did *not* happen, with nothing to wait for first.
