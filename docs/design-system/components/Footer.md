# Footer

The small print at the end of every page: the catalog types' notices, then Collector's own licence line. The notices say what the owners of the catalogs' content ask to be said, and where the data comes from; for Magic cards that is Wizards of the Coast's unofficial-content notice and the Scryfall attribution. The licence line says which version of Collector runs, that it is free software under the AGPL-3.0, where its source is, and where the third-party licences are (specs 084 and 087).

**Markup**: the layout renders it on every page, after the page's `<main>` and before the tab bar, through the `layouts/footer` partial, which wraps the `layouts/notice_lines` partial that renders the lines, and always adds `c-shell--footed` to the shell (`<body class="c-shell c-shell--footed">`). A page provides nothing. The types' lines come from each catalog type's source (`.content_notice`, see `app/models/catalog/sources.rb`), never from a view; the licence line comes from `Collector::BuildFacts#licence_parts` (spec 084 decisions 1 and 12).

```html
<footer class="c-footer">
  <p>Collector is unofficial Fan Content permitted under the <a rel="noopener" href="https://company.wizards.com/en/legal/fancontentpolicy">Fan Content Policy</a>. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.</p>
  <p>Card data and images provided by <a rel="noopener" href="https://scryfall.com">Scryfall</a>.</p>
  <p>Collector 0.3.0 (a9f6de7) is free software under the <a rel="noopener" href="https://www.gnu.org/licenses/agpl-3.0.html">AGPL-3.0</a>. Get the <a rel="noopener" href="https://github.com/plainprogrammer/Collector/tree/…">source code</a>. Read the <a rel="noopener" href="/licences">third-party licences</a>.</p>
</footer>
```

- One `<footer>` per page, a direct child of the shell, so it is the page's `contentinfo` landmark. There is always a footer: with no catalog type's notice it holds the licence line alone, and the shell is always `c-shell--footed` (spec 084 decisions 1 and 11).
- One line per paragraph, in the order the types are registered and each type gives its lines, then the licence line. No heading, no type name, no list.
- The licence line is last, is the core's and not a type's, and is never dropped as a repeat of a type's line. Its three links sit on its fixed words, "AGPL-3.0" (the licence's text), "source code" (the source of the running build) and "third-party licences" (`/licences`, the page `Licences` describes, a relative link to the same origin; spec 087 decision 1); the version and the short SHA are plain text, so a version can never move or drop a link. The line reads "Collector 0.3.0 (a9f6de7)", "Collector 0.3.0" with no revision, or "Collector (unknown version)" when the build's facts aren't known, or "Collector (unknown version, a9f6de7)" when the revision is valid but the version fails its rule (spec 084 AC-2.14) (spec 084 decision 2). Each reading ends with the third sentence, "Read the third-party licences." (spec 087 AC-2.2).
- Text only, apart from the links a line names: no logo, image, icon, set symbol or button. A source's name is a name, never a mark, and the wording never suggests the source or the owner endorses Collector.
- A type's line's wording belongs to its catalog type. Don't edit, shorten or translate a notice in a view; an owner's required wording is shown word for word.
- Small print: `ink-muted`, 12px on a 16px line (IBM Plex Sans 400), under a `line` divider, on the page gutter (`space-8` wide, `space-4` below 640px).
- Links are brand links at the line's own weight, as breadcrumb links are: `brand`, underlined on hover, with the `focus` ring. They open in the same tab. Inline links keep the line's height, as `StatusMessage` and breadcrumb links do; the 44px touch rule is applied to buttons and inputs.
- It follows the content in normal flow, directly after it, even when the page is shorter than the screen. It is never fixed or sticky.
- It is part of the shell, so it follows the viewport's 640px breakpoint. Below it the tab bar is fixed over the end of the page. The footer scrolls with the content and carries the clearance for the bar (its bottom padding); under `c-shell--footed`, `c-main` gives its own up, so the last line always stops above the bar with no empty band before the footer. A page with no tab bar (a visitor's catalog page, sign-in, sign-up) is the exception: the shell is marked `c-shell--untabbed` and the footer gives the bar's clearance up (see `VisitorHeader`).
- It needs no JavaScript and no inline style, so it renders unchanged under the scanner pages' Content-Security-Policy.
