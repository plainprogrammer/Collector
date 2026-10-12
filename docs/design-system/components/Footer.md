# Footer

The small print at the end of every page: what the owners of the catalogs' content ask to be said, and where the data comes from. For Magic cards that is Wizards of the Coast's unofficial-content notice and the Scryfall attribution.

**Markup**: the layout renders it on every page, after the page's `<main>` and before the tab bar, through the `layouts/footer` partial, and adds `c-shell--footed` to the shell (`<body class="c-shell c-shell--footed">`) when it does. A page provides nothing. The lines come from each catalog type's source (`.content_notice`, see `app/models/catalog/sources.rb`), never from a view.

```html
<footer class="c-footer">
  <p>Collector is unofficial Fan Content permitted under the <a rel="noopener" href="https://company.wizards.com/en/legal/fancontentpolicy">Fan Content Policy</a>. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.</p>
  <p>Card data and images provided by <a rel="noopener" href="https://scryfall.com">Scryfall</a>.</p>
</footer>
```

- One `<footer>` per page, a direct child of the shell, so it is the page's `contentinfo` landmark. When no catalog type supplies a notice there is no element at all.
- One line per paragraph, in the order the types are registered and each type gives its lines. No heading, no type name, no list.
- Text only, apart from the links a line names: no logo, image, icon, set symbol or button. A source's name is a name, never a mark, and the wording never suggests the source or the owner endorses Collector.
- A line's wording belongs to its catalog type. Don't edit, shorten or translate a notice in a view; an owner's required wording is shown word for word.
- Small print: `ink-muted`, 12px on a 16px line (IBM Plex Sans 400), under a `line` divider, on the page gutter (`space-8` wide, `space-4` below 640px).
- Links are brand links at the line's own weight, as breadcrumb links are: `brand`, underlined on hover, with the `focus` ring. They open in the same tab. Inline links keep the line's height, as `StatusMessage` and breadcrumb links do; the 44px touch rule is applied to buttons and inputs.
- It follows the content in normal flow, directly after it, even when the page is shorter than the screen. It is never fixed or sticky.
- It is part of the shell, so it follows the viewport's 640px breakpoint. Below it the tab bar is fixed over the end of the page. The footer scrolls with the content and carries the clearance for the bar (its bottom padding); under `c-shell--footed`, `c-main` gives its own up, so the last line always stops above the bar with no empty band before the footer.
- It needs no JavaScript and no inline style, so it renders unchanged under the scanner pages' Content-Security-Policy.
