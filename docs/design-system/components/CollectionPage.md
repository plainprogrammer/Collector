# CollectionPage

The collection screen at desktop width: app header, page head, sticky filter bar and the default image grid.

**What the page provides**: the signed-in collector (avatar initial), the page-head counts (items, unique, estimated value), the current filter state and the first page of items.

```html
<body class="c-shell">
  <header class="c-appbar" id="appbar" data-turbo-permanent>…</header>
  <main class="c-main">
    <div class="c-pagehead">
      <div><h1 class="c-pagehead__title">My collection</h1><p class="c-pagehead__stats">4,812 items · 1,906 unique · est. $3,410</p></div>
      <div class="c-pagehead__actions"><a class="c-btn c-btn--secondary">Import</a><a class="c-btn c-btn--primary">Add items</a></div>
    </div>
    <div class="c-collection">
      <form class="c-filterbar" data-turbo-frame="results" data-turbo-action="advance">…</form>
      <turbo-frame id="results"><div class="c-grid">…tiles…</div></turbo-frame>
    </div>
  </main>
  <nav class="c-tabbar" id="tabbar" data-turbo-permanent>…</nav>
</body>
```

- One page title (`c-pagehead__title`, Fraunces) per screen; the stats line is mono so the numbers read as data.
- `Add items` is the page's one primary action; `Import` is secondary.
- The filter bar sticks under the header (`top: 56px`) while the grid scrolls.
- The filter form targets the `results` frame with `data-turbo-action="advance"`, so every filter state is a URL with a working back button.
- The header and tab bar are `data-turbo-permanent`, so they don't flash between pages.
- The item images in this mock are flat placeholders; the real grid shows each item's own image or the no-image fallback.
