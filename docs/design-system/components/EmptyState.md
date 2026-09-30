# EmptyState

What a page or section shows when it has nothing to list: one sentence on why, and the next step.

**Markup** — the consumer provides the sentence and, where there is one, a link to the next step.

```html
<p class="c-empty">No cards in your collection yet. Search for a card to start adding. <a href="/catalog/entries">Search cards</a></p>
<p class="c-empty">No cards match "zzz". Check the spelling or try part of the name.</p>
<p class="c-empty">You don't have this card yet. <a href="/catalog/entries/…/lots/new">Add a copy</a></p>
```

- Say what is empty in plain words, to "you", and quote what the collector typed when a search found nothing.
- Offer one next step, as a link, when one exists; don't add a second call to action next to the page's primary button.
- No illustration, emoji or exclamation mark, and no "Oops"; the state is normal, not an error.
- An empty collection shows the empty state instead of the filter bar, since there is nothing to filter.
- It is centred text on `surface-sunken` with `radius-md`, spaced `space-6` from what's around it.
