# StatusAction

A `StatusMessage` that offers one follow-up action, such as the one-time Undo after a bulk removal.

**Markup** — the `shared/status_message` partial renders it inside the `#status` live region when given an `undo`: the sentence in a `span`, then a `button_to` whose form carries `c-status__action`.

```html
<div id="status" class="c-status" role="status" aria-live="polite">
  <div class="c-status__message c-status__message--action">
    <span>Removed 312 items from your collection.</span>
    <form class="c-status__action" data-turbo-frame="_top" method="post" action="/collection/bulk_removals/7/undo"><button class="c-btn c-btn--secondary c-btn--sm" type="submit">Undo</button><input type="hidden" name="return_to" value="/collection?bulk=1&amp;sort=condition&amp;dir=asc"></form>
  </div>
</div>
```

- One sentence and one small secondary button, never more. The sentence says what happened with exact numbers; the button names the action in one word ("Undo").
- The action is a form button (`POST`), never a link, so a prefetch can't trigger it. It carries the page the message was shown on (`return_to`), and lands there afterwards.
- The message and the button wrap onto two lines on narrow screens, with the button kept at the end.
- Offer the action only where the spec says it has no other entry point; when it has expired, the button answers with an alert message ("This removal can no longer be undone.") rather than disappearing silently.
