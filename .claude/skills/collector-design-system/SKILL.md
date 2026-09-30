---
name: collector-design-system
description: Collector's design system (tokens, c- CSS components, page patterns, voice). Use before building or changing any view, partial, ViewComponent, stylesheet or UI copy in this app.
---

# Collector design system

The design system lives in this repo. Read before writing UI:

1. `docs/design-system/README.md`: the rules (voice, colour, type, layout, mobile/Hotwire, navigation). Always read it first.
2. `docs/design-system/components/<Name>.md`: the markup and rules for each component you use. Read the ones you need before writing their HTML.
3. `docs/design-system/previews/<Name>.html`: the visual reference. Open it in a browser (add `?theme=dark` for dark) and match it.

Where things live:

| What | Path |
| --- | --- |
| Tokens (source of truth) | `docs/design-system/tokens.json` |
| Token CSS variables, `.type-*` text styles, `@font-face` | `app/assets/stylesheets/collector/tokens.css` |
| Component classes (`c-*`) | `app/assets/stylesheets/collector/components.css` |
| Fonts (self-hosted, OFL) | `app/assets/fonts/collector/` |
| Logos | `app/assets/images/collector/` (`image_tag "collector/collector-mark.svg"`) |

The docs say `components/bundle.css` and `fonts/`; in this repo those are `app/assets/stylesheets/collector/components.css` and `app/assets/fonts/collector/`.

## Rules that are easy to break

- Use only token variables (`var(--brand)`, `var(--space-4)`). Never hard-code a hex, px spacing outside the scale, or a new font.
- Reuse `c-*` classes. If something new is needed, add it to `components.css` using tokens, give it a doc in `docs/design-system/components/`, and list it in the README's Components section.
- `brand` is the only action colour. Category colours (`cat-*`) label things; they never act. `foil` is a fill, never text.
- Status colours always come with a word or an icon.
- Collection views: the image grid is the default; the table is a saved preference; bulk actions happen only in the table (`?view=table&bulk=1`).
- Wrap lists in `.c-collection` and detail pages in `.c-main.c-page`. Components switch to their narrow layout below 640px of their container, not the viewport. The app shell (`c-shell`, `c-appbar`, `c-tabbar`) uses the viewport.
- Build narrow first, down to 360px wide. Secondary actions go into a `c-menu` on narrow screens; the primary action stays visible.
- Nothing may need JavaScript to work. Menus are `<details>`; Stimulus only enhances. State lives in URL params; results sit in Turbo Frames; bulk changes answer with Turbo Streams. Mark `c-appbar` and `c-tabbar` with `data-turbo-permanent`.
- Magic mana costs use `c-cost`/`c-mana` pips with an `aria-label`, never Wizards' symbols. Rarity is a word. No set symbols.
- A physical copy is in one place at a time; a deck is a location. "Free to use" = owned − in decks.
- Copy is sentence case, says "you" and never "we", uses no emoji or exclamation marks, and states numbers exactly.

## Checking your work

Render the page at 1280px and 390px wide, in light and dark (`data-theme` on `<html>`), and compare it with the matching preview. Text must hold 4.5:1 contrast; the focus ring must be visible on every interactive element.
