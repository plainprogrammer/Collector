# Licences

The page at `/licences`: every third-party work in the image, one row each, with its licence text a click away (spec 087). It is for everyone, signed in or not, and holds no tenant data.

**Markup**: `licences/show` renders a section per kind of work (JavaScript, OCR engine, Fonts, Icons, Ruby gems) and `licences/_component` renders each row. The page sits in `c-main c-page` with the usual `c-pagehead`; a signed-in collector has the application header and tab bar, a visitor the brand-only header.

```html
<section class="c-licences" aria-labelledby="licences-fonts">
  <h2 class="c-licences__title" id="licences-fonts">Fonts <span class="c-licences__count">3</span></h2>
  <ul class="c-list c-licences__list">
    <li class="c-licences__row">
      <details class="c-licences__details">
        <summary><span class="c-licences__name">Fraunces</span> <span class="c-licences__meta">5.3.0 (Fontsource) · OFL-1.1</span></summary>
        <p class="c-licences__home"><a rel="noopener" href="https://fontsource.org/fonts/fraunces">https://fontsource.org/fonts/fraunces</a></p>
        <p class="c-licences__copyright">Copyright 2020 The Fraunces Project Authors</p>
        <h3 class="c-licences__file">LICENSE</h3>
        <pre class="c-licences__text">SIL OPEN FONT LICENSE Version 1.1 …</pre>
      </details>
    </li>
    <li class="c-licences__row">
      <div class="c-licences__heading"><span class="c-licences__name">@tesseract.js-data/eng</span> <span class="c-licences__meta">1.0.0 · MIT (as the package declares)</span></div>
      <p class="c-licences__home"><a rel="noopener" href="https://github.com/naptha/tessdata">https://github.com/naptha/tessdata</a></p>
      <p class="c-licences__missing">Licence text not found</p>
    </li>
  </ul>
</section>
```

- A row with a licence text is a closed native `<details>`: the summary is the name, the version and the identifiers, and opening it shows the home link, the copyright line and each text under its file name. A row with no text has no disclosure: the heading, the home link and "Licence text not found" in `ink-muted`, so a missing text is said and never hidden.
- The text sits in a `pre` in `font-mono` on the `surface-sunken` ground. It wraps (`pre-wrap`, `overflow-wrap:anywhere`), is at most 24rem tall and scrolls inside its own box (`overflow:auto`), so a long text never lengthens the page by much and nothing scrolls the page sideways at 360px. Long names and addresses wrap too.
- `c-list` supplies only the `line` divider; the row takes block flow (`c-list`'s rows are flex), with `space-3` above and below.
- The summary shows the browser's disclosure marker and a pointer cursor, so it reads as clickable. It takes the `focus` ring on `:focus-visible`, as the footer's links do.
- The two intro paragraphs sit in `c-licences__intro`, whose links take the same brand style as the rows' (without it the intro's AGPL-3.0 link showed in the browser's default blue).
- Links are brand links at the text's own weight, underlined on hover, with the `focus` ring; they open in the same tab with `rel="noopener"`. A home address that is not an absolute http or https address is not shown.
- The section's count is `ink-muted` mono, a number and not a claim. Every value goes through the template's escaping; a text is data, never markup.
- `c-licences__heading`, `c-licences__home` and `c-licences__copyright` are named for the markup and for specs; the first wraps long names, the others take the row's paragraph rule.
- Accessibility: each section is a `section` labelled by its `h2`; the disclosure is the native element, so the keyboard (Enter and Space) and screen readers work with no JavaScript and no inline style. The text is plain text in a `pre`, `ink` on `surface-sunken`.

**Why a new pattern**: the design system has no disclosure that holds a scrolling text box. `Details` is a fact list (a `dl`), not a disclosure, and `c-menu` is a `<details>` that holds actions, positioned as a popover. The page uses the native element for its behaviour and adds the rules above in `collector/additions.css`, in the block headed "Licences (spec 087)".
