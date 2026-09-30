# AppHeader

The top bar on every page: logo, main navigation and the account menu; on phones, the logo mark, an add button and the account menu.

**Markup** — the consumer provides the nav links (with `aria-current="page"` on the current section), the collector's initial for the avatar, and the add link shown on phones.

```html
<header class="c-appbar" id="appbar" data-turbo-permanent>
  <a class="c-appbar__brand" href="/" aria-label="Collector home">
    <span class="c-appbar__wordmark"><img class="c-logo--light" src="collector-wordmark.svg" alt=""><img class="c-logo--dark" src="collector-wordmark-reversed.svg" alt=""></span>
    <span class="c-appbar__mark"><img class="c-logo--light" src="collector-mark.svg" alt=""><img class="c-logo--dark" src="collector-mark-reversed.svg" alt=""></span>
  </a>
  <nav class="c-appbar__nav" aria-label="Main"><a href="/collection" aria-current="page">Collection</a>…</nav>
  <div class="c-appbar__actions">
    <a class="c-btn c-btn--primary c-btn--sm c-btn--icon c-appbar__add" href="/items/new" aria-label="Add items">…</a>
    <details class="c-menu"><summary class="c-avatar" aria-label="Account: James">J</summary>…</details>
  </div>
</header>
```

- Default sections: Collection, Decks, Locations, Wishlist. Collectors will be able to choose and reorder them; whatever they pick appears in the same order in the `TabBar` on phones, so the app has one navigation model at every width.
- The current section gets a 2px `brand` underline and `ink` text; the others are `ink-muted`.
- Profile, settings, import/export and sign-out live in the avatar menu, never in the main nav.
- The logo swaps light/dark with `data-theme`; the wordmark shows on wide screens, the mark alone on phones.
- Below 640px (viewport) the nav hides, the mark replaces the wordmark and the icon-only `+` (`c-appbar__add`) appears; the page head's own buttons hide.
- On a shared instance the avatar shows whose collection you are in.
- It is sticky at the top, 56px tall; anything else sticky sits below it.
- On detail pages (`c-appbar--detail`) phones show a back arrow (`c-appbar__back`) instead of the logo, and the `+` is left out because the page has its own primary action.
