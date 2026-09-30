# TabBar

The bottom tab bar on phones, in the pattern of native apps: four sections (the collector's choice; Collection, Decks, Locations and Wishlist by default) and More.

**Markup** — five links, each an icon in `c-tabbar__icon` plus a one-word label; the current one has `aria-current="page"`. Place it as a direct child of `c-shell`.

```html
<nav class="c-tabbar" id="tabbar" aria-label="Main" data-turbo-permanent>
  <a href="/collection" aria-current="page"><span class="c-tabbar__icon"><svg …/></span>Collection</a>
  <a href="/decks"><span class="c-tabbar__icon"><svg …/></span>Decks</a>
  <a href="/locations"><span class="c-tabbar__icon"><svg …/></span>Locations</a>
  <a href="/wishlist"><span class="c-tabbar__icon"><svg …/></span>Wishlist</a>
  <a href="/more"><span class="c-tabbar__icon"><svg …/></span>More</a>
</nav>
```

- Shown only below 640px (viewport), fixed to the bottom and padded for the home indicator with `env(safe-area-inset-bottom)`; on wide screens the `AppHeader` nav does the same job. Add `viewport-fit=cover` to the viewport meta tag so the padding works on iOS.
- Never more than five tabs. A new section goes into More until it earns a tab, and then something else moves out.
- Labels always show; icons alone are not enough.
- The current tab is `brand` with a `brand-tint` pill behind its icon.
- Every tab is at least 56px tall and takes an equal share of the width.
- More opens a full page (not a pop-up) listing profile, settings, import and export, and any newer sections.
- It stays visible while scrolling; hide it only while the on-screen keyboard is open (a small Stimulus controller).
- Mark it `data-turbo-permanent` so it doesn't redraw between pages, and update `aria-current` from the URL on `turbo:load`.
