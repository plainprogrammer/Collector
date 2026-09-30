Collector is a free, open-source catalog for physical collectibles — trading cards first, then comics and whatever the community adds. It is built for active collectors: people who play the cards they collect and read the comics they bag. Most instances are self-hosted by one hobbyist for themselves, their family and friends; some will be run by small shops for their community.

It should feel like a well-kept archive that gets used: warm paper, deep ink, one confident teal, and a flash of foil gold where something is special. Calm enough to scan several thousand rows, quick enough to update between games.

## Who it's for

- A collection of a few thousand items is the normal case, not the edge case. Design every list for 5,000 rows first and 50 second: search, filters and bulk edits are primary, not tucked away.
- Players need "where is it" as much as "what is it": in a deck, in a binder, in a box, lent to someone. Location and availability sit next to the item name, not on a detail page.
- A physical copy is in exactly one place at a time. A deck is a location like a binder or a box, so a copy in a deck is not free for another deck, and "Free to use" is always owned minus in decks. (Digital decks that share cards may come later; when they do, their cards are labelled as such and never count against physical copies.)
- Readers need reading state as well as ownership: read, to read, reading.
- Several people may share one instance. Show whose item it is whenever more than one collector is visible.

## Voice

- Plain, precise, collector-literate. Use the hobby's real words: set, printing, condition, foil, playset, deck, binder; for comics issue, volume, variant, run.
- Sentence case everywhere — buttons, headings, menus. ("Add to collection", not "Add To Collection".)
- Speak to the user as "you"; the app never says "we".
- Numbers are facts: show counts and prices exactly ("3 of 4 owned", "$12.40"), never "lots" or "great value".
- No emoji, no exclamation marks, no hype. Empty states say what to do next: "No cards in this binder yet. Search a set to start adding."
- Never use a game's trademarks, set symbols, mana symbols or card-frame art as UI decoration. Card images appear only as the collected item itself. Mana costs use Collector's own `ManaCost` pips (coloured circles with a letter), never Wizards' symbols; rarity is a word.

## Color

- Page ground is `surface`; panels, cards, inputs and menus are `surface-raised`; wells, table stripes and empty binder slots are `surface-sunken`.
- Text is `ink`; secondary text and metadata are `ink-muted`. Both read on `surface`, `surface-raised` and `surface-sunken` in both themes (≥6:1).
- `brand` (vault teal) is the one action colour: primary buttons, links, selected tabs, the checked state. Text on a `brand` fill is `on-brand`, never literal white. Hover/pressed fill is `brand-hover`.
- `brand-tint` marks selection in lists and active filter chips; text on it stays `ink`.
- Each collectible category has an identity accent: `cat-cards` (plum) for trading card games, `cat-comics` (burnt orange) for comics, `cat-other` (slate) for anything the community adds before it earns its own. Each has a `-tint` for chip and banner backgrounds.
- Category accents identify; they never act. Use them for a category chip, a 4px rule under a category's section header, or a dot in navigation. Buttons, links and selection stay `brand` in every category, so the app behaves the same everywhere.
- A category accent always appears with the category's name. It is never the only way to tell categories apart.
- A new category gets its own accent only once it has real users; until then it uses `cat-other`. A new accent must hold 4.5:1 on `surface`, `surface-raised` and its tint in both themes, and differ in lightness or hue family from the existing ones.
- `foil` (gold) means rare, foil or special — a badge fill, a star, the logo's diamond. It is a fill only: it fails as text on paper. Text on it is `on-foil`. Use it sparingly; if everything shines, nothing does.
- `success`, `warning`, `danger` are status only and always come with a word or icon (colour is never the only signal).
- Dividers use `line`; control borders use `line-strong` (≥3:1 on every surface).
- Instance operators (a shop, a club) may re-skin their instance by overriding `brand`, `brand-hover`, `on-brand` and `brand-tint` only, keeping the same contrast floors. Everything else stays fixed so the app remains recognisably Collector.
- Both themes are first-class: set `data-theme="dark"` on `<html>`. Never hard-code a hex; use the tokens.

## Type

- Three families, all open-licensed and self-hosted from `fonts/`: Fraunces (display), IBM Plex Sans (text), IBM Plex Mono (data).
- `display` and `title` (Fraunces 600) are for page titles and hero moments only — one per screen, never in tables or buttons.
- `heading` for section heads, `body` for running text, `body-sm` for dense lists and captions, `label` for form labels, buttons and column headers.
- `data` (Plex Mono) for set codes, collector numbers, quantities and prices, so columns align: `MH3 · 214`, `×4`, `$12.40`.

## Spacing and layout

- Spacing steps are `space-1` 4 through `space-8` 32; use only these.
- Page gutter `space-4` on phones, `space-8` on desktop. Sections separate by `space-6`.
- The image grid (`ItemTile` in `c-grid`) is the default collection view for everyone. The table (`CollectionTable`) is one click away in the view switch, and the choice is saved as a user preference, not per page.
- Bulk actions happen only in the table. Choosing one from the grid switches to the table with the same filters and the bulk bar; `Done` returns to the saved view. The grid never shows checkboxes.
- Because the grid is the default for collections of thousands, every tile carries the quantity, a set tag and the location, so the common questions ("how many?", "where is it?") are answered without switching views. Search and filters sit in the sticky `FilterBar` above it.
- Card images keep the physical 63:88 ratio (`aspect-ratio: 63 / 88`) with `radius-card` corners. Comics use their own ratio; never crop an item to fit.

## Shape and depth

- `radius-sm` for chips, badges and set-code tags; `radius-md` for buttons, inputs, menus and panels.
- Borders, not shadows. The only shadow is `shadow-lift`: on a card image while hovered or dragged, and on an open menu.

## States

- Focus: a 2px solid `focus` ring with a 2px offset on every interactive element, both themes. Never remove it.
- Hover darkens a fill to its `-hover` token or adds a `surface-sunken` background to a row.
- Disabled: 50% opacity, no pointer events, still readable text.

## Mobile and Hotwire

- Every view works from 360px wide up, and is designed narrow first. Nothing is desktop-only.
- Collection components respond to their container, not the viewport: wrap a collection in `.c-collection` and it switches to its narrow layout below `bp-narrow` (640px). This keeps them correct inside Turbo Frames, side panels and previews.
- Phones get a compact header and a bottom tab bar (see Navigation).
- On narrow screens secondary actions move into a "…" `Menu`; the primary action and `Done` stay visible. On wide screens those actions are plain buttons (e.g. `Edit many` in the `FilterBar`).
- On touch devices every target is at least 44px (40px for small buttons, chips and the view switch); `bundle.css` handles this with `pointer: coarse`.
- Nothing needs JavaScript to render or work. Menus are `<details>`; Stimulus only enhances (outside-click to close, arrow keys, `/` to focus search, live selection counts).
- State lives in the URL so Turbo Drive's back button and cache work: search and filters are a GET form, view and bulk mode are params (`?view=table&bulk=1`), and the results sit in a Turbo Frame the form targets.
- Bulk actions submit a form and answer with Turbo Streams that replace the affected rows and the count; undo is a Turbo Stream too.
- Nothing is hover-only: every hover affordance has a tap equivalent.

## Navigation

- The default sections, in this order: Collection, Decks, Locations, Wishlist. Each collector will be able to choose and reorder their own sections; design for any four, and never hard-code a section's position. Wide screens show them in the `AppHeader`; phones show them in a native-style bottom `TabBar` with a fifth tab, More.
- Profile, settings and import/export live in the avatar menu (wide) or More (phone), never in the main navigation.
- The tab bar holds five tabs at most. A new section starts in More.
- Detail pages (a single card, a deck) use `c-appbar--detail`: on phones a back arrow replaces the logo and breadcrumbs.
- The app shell (`c-shell`, `AppHeader`, `TabBar`) responds to the viewport at 640px, because it is the page itself. Everything inside a page responds to its container (`.c-collection` for lists, `.c-page` for a detail page).

## Components

- Components are plain CSS classes (prefix `c-`) in `components/bundle.css`, built only on these tokens. There is no JavaScript bundle: each component's README gives the HTML, which you wrap in a Rails partial or ViewComponent.
- Current set: `AppHeader`, `TabBar`, `Button`, `Menu`, `Input`, `Chip` (category chip, filter chip, tag), `Badge`, `ManaCost`, `ViewSwitch`, `FilterBar`, `ItemTile` (with `c-grid`), `CollectionTable` (with its `c-bulkbar`). Full screens: `CollectionPage` and `ItemPage` (desktop), `CollectionPagePhone` and `ItemPagePhone`. Card-page parts: `c-crumbs`, `c-item`, `c-rules`, `c-stats`, `c-section`, `c-list`, `c-legality`, `c-split`.
- Build new components from these before inventing new styles; a new pattern gets its own entry here first.

## Logo

- The mark is three fanned cards, the front one vault teal with a foil diamond: a collection, one piece of which is special. It is deliberately game-neutral so it grows past trading cards.
- Use `collector-wordmark.svg` in the app header on light grounds and `collector-wordmark-reversed.svg` on dark; the mark alone (`collector-mark.svg` / `-reversed`) for favicons, app icons and tight spaces.
- Minimum size: mark 16px, wordmark 24px tall. Clear space: half the mark's height on every side. Don't recolour, rotate, outline or add effects.

## Iconography

- No icon set chosen yet. Until one is, use Lucide (ISC-licensed, 1.5px stroke, 20px) in `currentColor`, which matches Plex's weight. Flag any other set here before adopting it.
