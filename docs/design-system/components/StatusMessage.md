# StatusMessage

A one-line message under the header that confirms what just happened ("Added 1 × Lightning Bolt (M10 · 146) to your collection.") or explains why it didn't, announced by screen readers.

**Markup** — the layout renders the live region on every page, directly after the app header; the consumer provides only the message, through the `shared/status_message` partial (from a flash, or from a Turbo Stream that updates `#status`).

```html
<div id="status" class="c-status" role="status" aria-live="polite">
  <p class="c-status__message">Added 1 × Lightning Bolt (M10 · 146) to your collection.</p>
</div>
```

**Modifiers**: `c-status__message--alert` marks a message about something that didn't happen or needs attention ("You already have the most copies one lot can hold (9,999)."). It keeps the text colour and swaps the brand tint for `surface-raised` with a `warning` border, so the words carry the meaning, not the colour.

**Inline notice**: the same message classes, used outside the live region, state a lasting condition of the page itself. They are rendered with the page, not announced, and sit where they apply:

```html
<p class="c-status__message c-status__message--alert">This printing is no longer present in the upstream source.</p>
<p class="c-status__message c-status__message--alert">The card catalog hasn't been loaded yet. Ask an admin to load it.</p>
<p class="c-status__message c-status__message--alert">The card catalog hasn't been loaded yet. <a href="/admin/catalog">Go to the catalog page</a> to load it.</p>
```

- There is one live region per page (`#status`), always present so screen readers register it before it changes; `c-status:empty` hides it when there is no message.
- Messages are one plain sentence that says exactly what happened, with exact numbers: "Removed 3 × Opt (XLN · 65) from your collection.", "Saved.", never "Success!". An inline notice may add one more short sentence saying what to do about the state it describes.
- A redirect carries the message in the flash (`notice` or `alert`); an answer that leaves the page as it was updates `#status` with a Turbo Stream (`turbo_stream.update("status", …)`).
- A link inside a message is a brand link: `brand` colour, semibold, underlined on hover, with the `focus` ring. The catalog notice (spec 015) gives admins the link and tells everyone else who to ask.
- Use the inline notice only for a state the page is in; never put action results outside the live region, or they won't be announced.
- Padding follows the page gutter: `space-8` on wide screens, `space-4` below 640px.
