# Button

Buttons trigger actions; one primary per view, in `brand`, the rest secondary or ghost.

**Markup** — the consumer provides the label (sentence case, a verb) and an optional 16px icon before it:

```html
<button class="c-btn c-btn--primary"><svg …/>Add to collection</button>
```

**Variants**: `c-btn--primary` (the one main action), `c-btn--secondary` (everything else), `c-btn--ghost` (low-emphasis, inline with content), `c-btn--danger` (destructive; always a word, never icon-only). **Sizes**: default 36px, `c-btn--sm` 28px for toolbars and table rows. `c-btn--icon` makes a square icon button; it must carry `aria-label`.

- Do use a `<button>` for actions and an `<a class="c-btn">` only for navigation.
- Do disable with the `disabled` attribute and change the label to say what is happening ("Saving…").
- Don't put two primary buttons side by side, and don't colour a button with a category accent.
- In Rails, `button_to` and `link_to` take `class: "c-btn c-btn--primary"`.
