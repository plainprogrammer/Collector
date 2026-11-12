# TabBar

The bottom tab bar on phones, in the pattern of native apps: four sections (Collection, Decks, Search and Scan, in that order; Locations stays in More) and More. The five tabs are full: a new section starts in More. Collectors will later be able to choose and reorder their sections (spec 057 decision 6).

**Markup** — five links, each an icon in `c-tabbar__icon` plus a one-word label; the current one has `aria-current="page"`. Place it as a direct child of `c-shell`.

```html
<nav class="c-tabbar" id="tabbar" aria-label="Main" data-turbo-permanent>
  <a href="/collection" aria-current="page"><span class="c-tabbar__icon"><svg …/></span>Collection</a>
  <a href="/decks"><span class="c-tabbar__icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="8" y="3" width="12" height="16" rx="2"/><path d="M5 7v12a2 2 0 0 0 2 2h9"/></svg></span>Decks</a>
  <a href="/catalog/entries"><span class="c-tabbar__icon"><svg …/></span>Search</a>
  <a href="/scanner"><span class="c-tabbar__icon"><svg …/></span>Scan</a>
  <a href="/more"><span class="c-tabbar__icon"><svg …/></span>More</a>
</nav>
```

- Shown only below 640px (viewport), fixed to the bottom and padded for the home indicator with `env(safe-area-inset-bottom)`; on wide screens the `AppHeader` nav does the same job. Add `viewport-fit=cover` to the viewport meta tag so the padding works on iOS.
- Never more than five tabs. A new section goes into More until it earns a tab, and then something else moves out.
- Labels always show; icons alone are not enough.
- Decks' icon is the design system's own, a card and the one behind it, the same as the card page's "Add to deck" button, so one icon means deck everywhere (spec 057 decision 5). The app draws it from the partial `app/views/icons/_decks.html.erb`, at `stroke-width="1.5"` like the other tab icons (the sample above is that partial), and the tab is `link_to decks_path` after Collection, current on every Decks page (spec 062 AC-4.1).
- The current tab is `brand` with a `brand-tint` pill behind its icon.
- Every tab is at least 56px tall and takes an equal share of the width.
- More opens a full page (not a pop-up) listing profile, settings, import and export, and any newer sections.
- It stays visible while scrolling; hide it only while the on-screen keyboard is open (a small Stimulus controller).
- A `Menu` opened near the bar is scrolled clear of it (`Menu`, spec 074); when you shoot a phone page, size the window taller than the frame, or the fixed bar is clipped out of the picture (a frame taller than the window's viewport loses it).
- Mark it `data-turbo-permanent` so it doesn't redraw between pages, and update `aria-current` from the URL on `turbo:load`.
