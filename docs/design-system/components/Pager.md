# Pager

Previous/next links around the current page position, for results and collections that are split into pages.

**Markup** — the consumer provides the links (only those that apply) and the position; it renders nothing when there is one page.

```html
<nav class="c-pager" aria-label="Pagination">
  <a rel="prev" class="c-btn c-btn--secondary c-btn--sm" href="/collection?page=1">Previous</a>
  <span class="c-pager__position">Page 2 of 5</span>
  <a rel="next" class="c-btn c-btn--secondary c-btn--sm" href="/collection?page=3">Next</a>
</nav>
```

- The page number lives in the URL (`?page=`), alongside the current filters, so every page can be linked and the back button works.
- The links are plain Turbo Drive visits; they don't target a results frame (see `SearchResults` for why).
- The position states the page and total exactly, in mono `ink-muted` text; on the first or last page the missing link is left out, not disabled.
- An out-of-range or invalid page number shows the nearest real page rather than an error.
- Centred under the grid with `space-6` above and below; it needs no narrow layout.
