Collector is a free, open-source catalog for physical collectibles — trading cards first, then comics and whatever the community adds. It is built for active collectors: people who play the cards they collect and read the comics they bag. Most instances are self-hosted by one hobbyist for themselves, their family and friends; some will be run by small shops for their community.

It should feel like a well-kept archive that gets used: warm paper, deep ink, one confident teal, and a flash of foil gold where something is special. Calm enough to scan several thousand rows, quick enough to update between games.

## Who it's for

- A collection of a few thousand items is the normal case, not the edge case. Design every list for 5,000 rows first and 50 second: search, filters and bulk edits are primary, not tucked away.
- Players need "where is it" as much as "what is it": in a deck, in a binder, in a box, lent to someone. Location and availability sit next to the item name, not on a detail page.
- A physical copy is in exactly one place at a time. A deck is a kind of location whose copies live in its zones, so a copy in a deck is not free for another deck; the Decks section below defines the words, "Free to use" among them. (Digital decks that share cards may come later; when they do, their cards are labelled as such and never count against physical copies.)
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
- Text is `ink`; secondary text and metadata are `ink-muted`. Both read on `surface`, `surface-raised` and `surface-sunken` in both themes (5.5:1 or better).
- `brand` (vault teal) is the one action colour: primary buttons, links, selected tabs, the checked state. Text on a `brand` fill is `on-brand`, never literal white. Hover/pressed fill is `brand-hover`.
- `brand-tint` marks selection in lists and active filter chips; text on it stays `ink`.
- Each collectible category has an identity accent: `cat-cards` (plum) for trading card games, `cat-comics` (burnt orange) for comics, `cat-other` (slate) for anything the community adds before it earns its own. Each has a `-tint` for chip and banner backgrounds.
- Category accents identify; they never act. Use them for a category chip, a 4px rule under a category's section header, or a dot in navigation. Buttons, links and selection stay `brand` in every category, so the app behaves the same everywhere.
- A category accent always appears with the category's name. It is never the only way to tell categories apart.
- A new category gets its own accent only once it has real users; until then it uses `cat-other`. A new accent must hold 4.5:1 on `surface`, `surface-raised` and its tint in both themes, and differ in lightness or hue family from the existing ones.
- `foil` (gold) means rare, foil or special — a badge fill, a star, the logo's diamond. It is a fill only: it fails as text on paper. Text on it is `on-foil`. Use it sparingly; if everything shines, nothing does.
- `success`, `warning`, `danger` are status only and always come with a word or icon (colour is never the only signal).
- **Status band.** A status colour has one filled use, the `StatusBand`: `success` or `warning` as the ground of a band that says how sure a result is, with `on-success` or `on-warning` for the sentence and the icon on it (4.5:1 or better in both themes; the dark theme's `success` and `warning` are light, so white fails on them). `danger` is never a fill: something that went wrong is a `StatusMessage`. A band always carries an icon and words (spec 080).
- `scrim` (black at 40% in both themes) dims the page behind an open `Sheet`, as the dialog's backdrop, and is used for nothing else (spec 080 decision 4).
- **Mana colours.** The `mana-*` colours are data colours, used only to show mana: the `ManaCost` pips and charts of mana symbols. The fills stay apart from `success`, `warning` and `danger` and are the same in both themes. The letter or number always shows, and every use has a 1px `line-strong` outline.
- **Charts.** Fills are neutral: `ink-muted` for the main series, a hatched `line-strong` fill (45°, 1.5px lines every 5px, as `DeckShape` draws it) with an `ink-muted` outline for a second series stacked on it; never `brand` (brand means an action) and never a status colour. Every column or segment carries a word or a number (a count above a column; a letter and count in a segment; a segment too narrow for its label shows them in the caption beneath), and a legend or caption names each series, so colour or pattern is never the only signal. The chart is `role="img"` with an `aria-label` that reads the values. Fills and outlines hold 3:1 against the ground they sit on. A chart of mana symbols may use the `mana-*` fills, each with a 1px `line-strong` outline, and a divider between segments, because the white and black fills disappear on the light and dark ground.
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

## Motion

- Nothing moves without a cause the collector started: a tap, a capture, opening a sheet.
- A transition or an animation takes 200ms at most and is instant under `prefers-reduced-motion: reduce`. One block, the last in `collector/additions.css`, turns every transition and animation off under that preference, app-wide (spec 080 decision 14). Its two declarations are the stylesheets' only `!important`, because a universal selector loses to any class rule. A new block goes above it.
- A scroll the browser animates (`scroll-behavior: smooth`) is smooth only without the preference: its `auto` sits in the same block.

## Mobile and Hotwire

- Every view works from 360px wide up, and is designed narrow first. Nothing is desktop-only.
- Collection components respond to their container, not the viewport: wrap a collection in `.c-collection` and it switches to its narrow layout below `bp-narrow` (640px). This keeps them correct inside Turbo Frames, side panels and previews.
- Phones get a compact header and a bottom tab bar (see Navigation).
- **Focused pages.** A page for one task done many times in a row may drop the app header and the tab bar when it keeps a back arrow and its own primary action in view at all times. Its `<body>` carries `c-shell--focused` beside `c-shell--untabbed`, which removes the body's margin and minimum height so the page is exactly the screen (spec 080). The phone-first scanner is the first (`Scanner`); no page is built this way yet.
- A focused page that is one screen high and has no footer shows the content notice's lines, and the licence line, through the same partial as the footer, in the foot of each of its sheets (`Sheet`; spec 084 decision 12); such a page has a sheet or keeps the footer, and a focused page that scrolls keeps the footer. No page does this yet: the scanner keeps its footer until #344 builds the one-screen page (spec 080 decision 13).
- **Sheets.** Content that would otherwise take the collector off a page whose state a navigation would lose (a running camera) opens in a `Sheet`, a bottom sheet over the page, which keeps that state. A sheet is a native `<dialog>` opened as a modal, which needs script. It is the one exception to "Nothing needs JavaScript" below: use it only on a page that already needs script, or give its opener a plain link to a page that holds the same content (spec 080 decision 2).
- **Swipes.** A swipe always has a button that does the same: Previous and Next beside a row that is swiped. The buttons are the way for a keyboard, switch access and a fine pointer (spec 080).
- On narrow screens secondary actions move into a "…" `Menu`; the primary action and `Done` stay visible. On wide screens those actions are plain buttons (e.g. `Edit many` in the `FilterBar`).
- On touch devices every target is at least 44px, with no exception: buttons, inputs, menu items and selects, and the small buttons (`c-btn--sm`), filter chips (`c-filter`) and view-switch buttons (`c-seg`) too (spec 075, [#316](https://github.com/plainprogrammer/Collector/issues/316), the maintainer's ruling of 2026-11-11, which ended the 40px of earlier versions); a small icon button and a view-switch button are 44px wide as well. The compact sizes, 28px for the small controls and the filter bar's select and 36px for a form's select, are the fine pointer's. The rules are `pointer: coarse` blocks: `collector/components.css` holds the export's (it still writes 40px for the small controls, which `additions.css` overrides), and `collector/additions.css` holds the app's (the selects', spec 072, [#315](https://github.com/plainprogrammer/Collector/issues/315): `min-height: var(--touch-floor)` on `.c-field select` and `.c-select select`; the small controls', spec 075: `.c-btn--sm`, `.c-filter` and `.c-seg button`; one block each); the app's blocks must stay after the export's in the layout, which is why the export's file is not edited. On a coarse pointer the filter row (`c-filterbar__filters`) centres its controls, so a control that is not 44px (a label, a shorter field) sits level with the select. A new select is a `c-field` or `c-select` select and a new small control carries one of the three classes: each meets the floor with no rule of its own, and the author adds the page to the `pages` of `spec/system/small_controls_touch_floor_spec.rb` (the audit of [spec 075](../specs/075-small-controls-touch-floor/spec.md)) so its controls are measured; a select outside both shapes is a design-system violation, not something the rule hides. The pages that give their buttons 44px at every pointer (Locations, the Decks pages, number entry's list, the scanner's adds, undos and sitting), and the rules drawn for the phone-first scanner's shell and pane and a sheet's Close (spec 080; no page uses them yet), keep their own rules.
- Nothing needs JavaScript to render or work. Menus are `<details>`; Stimulus only enhances (outside-click to close, `/` to focus search, live selection counts, and, on a phone, scrolling an opened menu clear of the tab bar). A `Sheet` is the one exception (Sheets, above).
- State lives in the URL so Turbo Drive's back button and cache work: search and filters are a GET form, view and bulk mode are params (`?view=table&bulk=1`), and the results sit in a Turbo Frame the form targets.
- Bulk actions submit a form and answer with Turbo Streams that replace the affected rows and the count; undo is a Turbo Stream too.
- Nothing is hover-only: every hover affordance has a tap equivalent.

## Navigation

- A collector's wide header, in order: Collection, Decks, Search, Scan, Locations. The phone tab bar, in order: Collection, Decks, Search, Scan, More; Locations stays in More. Each collector will later be able to choose and reorder their own sections, so never hard-code a section's position. Wishlist is planned. Decks is live in both since spec 062 (a collector's header links Collection, Decks, Search, Scan and Locations, and the tab bar holds Collection, Decks, Search, Scan and More; a visitor's header on an open catalog has no Decks link, AC-4.9); the order is the rule for both (spec 057 decision 6; spec 062 AC-4.1). The Decks, New deck, Rename, Change format and removal pages mark Decks current. Wide screens show the sections in the `AppHeader`; phones show them in a native-style bottom `TabBar` with More as its fifth tab.
- Profile, settings and import/export live in the avatar menu (wide) or More (phone), never in the main navigation.
- The tab bar holds five tabs at most and is now full (Collection, Decks, Search, Scan, More): a new section starts in More.
- A menu opened near the bottom of a phone is scrolled clear of the tab bar, so no item is hidden behind it (`Menu`, spec 074, [#326](https://github.com/plainprogrammer/Collector/issues/326)); nothing changes at 640px and wider.
- With five links the header has no room for the wordmark between 640px and 719px: the logo mark stands in for it there, while the nav holds five or more links, and the wordmark returns from 720px (spec 057 decision 19).
- Detail pages (a single card, a deck) use `c-appbar--detail`: on phones a back arrow replaces the logo and breadcrumbs.
- The app shell (`c-shell`, `AppHeader`, `TabBar`) responds to the viewport at 640px, because it is the page itself. Everything inside a page responds to its container (`.c-collection` for lists, `.c-page` for a detail page).

## Decks

The words every deck screen uses (spec 057 FR-3). They name no format and no collectible; a deck's formats and zones are defined where decks are built.

- **Deck:** a kind of location. Its copies live in its zones.
- **Zone:** a named part of a deck, such as Main or Sideboard. Which zones a deck has depends on its format; every deck has Considering.
- **Considering:** the zone for cards you are thinking about. Copies there are in the deck.
- **Proxy:** a stand-in for a card you do not own, recorded against a deck zone with a printing. A proxy never counts as owned; it is not in Owned, In decks or Free to use.
- **"Deck › Zone":** how a zone is named wherever a place is shown or chosen (tiles, rows, pickers): the deck's name, a single right angle quote (›), the zone's name. A zone is never shown without its deck.
- **Free to use:** copies you own minus copies in any deck zone, Considering included. Proxies don't change it.
- **Places:** your locations that are not decks (a binder, a box). "Places" is the picker's group label; the page is still "Locations".
- **What is live** (spec 062, #49): a collector creates, renames, changes the format of and removes a deck on the Decks pages (`DecksIndex`; the format change is spec 064, #251), and a deck is removed only while no zone holds a copy. "Deck › Zone" is shown wherever a lot's place is shown, from one label (`Lot#place_label`). Since spec 065 (#252) the grouped location picker (`Form`) is live in the lot form, Move copies, bulk Move to…, number entry and the scanner sitting, and the collection filter lists the zones and "<Deck> (all zones)" (`FilterSelect`); a lot in a zone's Edit copy shows the select with the zone chosen, and the read-only field is gone. The tiles show no place line under a filter, a deck's included, and the table shows each row's "Deck › Zone" (spec 065 decision 13). A deck's name links to the deck page (spec 066, #253), and since spec 068 (#254) a collector adds proxies to a zone, changes or removes them from the row's menu (`DeckPage`, `AddProxy`), and the Decks page has the Proxy column; a proxy is shown with the dashed `ProxyTag`, counted in a deck's cards and never in Owned. Since spec 070 (#257) a proxy row's menu also lists "Use my copy" (`UseMyCopy`: free copies moved into the zone) and "Add a new copy" (`AddProxy`: the Add a copy form for the proxy's printing), and either one lowers the proxy as it moves or adds the copies. Since spec 073 (#50) the card page's stats (Owned, In decks, Free to use) and its "In decks" section are live (`ItemPage`), and the card page no longer uses the single stat.

## Components

- Components are plain CSS classes (prefix `c-`) in `collector/components.css`, with the app's additions in `collector/additions.css`, built only on these tokens. There is no JavaScript bundle: each component's README gives the HTML, which you wrap in a Rails partial or ViewComponent.
- Current set: `AppHeader`, `TabBar`, `Button`, `Menu`, `Input`, `Chip` (category chip, filter chip, tag), `Badge`, `ManaCost`, `ViewSwitch`, `FilterBar`, `ItemTile` (with `c-grid`), `CollectionTable` (with its `c-bulkbar`), `DeckShape`, `DeckCheck`, `ProxyTag` (parts), `StatusBand` and `Sheet`. Full screens: `CollectionPage` and `ItemPage` (desktop), `CollectionPagePhone` and `ItemPagePhone`, `DeckPage`, `DecksIndex` (with its New deck, Rename and removal pages), `AddToDeck`, `UseMyCopy` (built by spec 070, #257) and `AddProxy` (with its Add a new copy page, a use of `lots/_form`, spec 070). Card-page parts: `c-crumbs`, `c-item`, `c-rules`, `c-stats`, `c-section`, `c-list`, `c-legality`.
- Build new components from these before inventing new styles; a new pattern gets its own entry here first.
- The design system is the project's own, in code (spec 057 decision 12). A new pattern goes in `collector/additions.css`, with a doc under `components/` and a line in the App additions list below; a rule changes in this README, in the same change as the code.

App additions (spec 004, in `collector/additions.css`): `StatusMessage`, `Form`, `AuthPage`, `ConfirmPage`, `SearchResults`, `TileAdd`, `FinishBadge`, `FilterSelect`, `Pager`, `EmptyState`, `Details`, `SingleStat`, `MorePage`, `AdminUsers`, `TableActions`, `SystemLogo`.

App additions (spec 006, in `collector/additions.css`): `SortHeader`, `StatusAction`, `BulkConfirmPage`, `ChoicePage`, `BulkForm`, `ViewSwitchForm`, `TableItemLink`.

App additions (spec 007, in `collector/additions.css`): `Scanner`.

App additions (spec 015, in `collector/additions.css`): `AdminJobs`, `AdminCatalog`, `StageList`, `ProgressMeter`.

App additions (spec 018, in `collector/additions.css`): `Footer`; spec 084 adds the licence line.

App additions (spec 019, in `collector/additions.css`): `ImageFit`. It overrides the export's image fitting.

App additions (spec 021, in `collector/additions.css`): `UnownedTile`. It overrides the export's fade on `ItemTile`'s `c-tile--owned-none`.

App additions (spec 023, in `collector/additions.css`): `VisitorHeader`. It is `AppHeader`'s signed-out form, and marks a shell with no `TabBar` `c-shell--untabbed`.

App additions (spec 025, in `collector/additions.css`): `ImportPreview`.

App additions (spec 026, in `collector/additions.css`): `NumberEntry`.

App additions (spec 029, in `collector/additions.css`): `Locations`.

App additions (spec 032, in `collector/additions.css`): `c-locations__more`, `c-locations__holds` and the 44px floor of `c-locations__lots` links, documented in `Locations`.

App additions (spec 033, in `collector/additions.css`): `c-tile__place` and its parts, and the wrapping of `c-table__sub` on narrow collections, documented in `ItemTile` and `CollectionTable`.

App additions (spec 048, in `collector/additions.css`): `c-table__place-name` (the Location cell's name, capped at 20rem and broken inside a word when it must), the wrapping of the named `c-table__place` cell and `overflow-wrap` on the phone `c-table__sub`, documented in `CollectionTable`. The cell's rule overrides the export's `.c-table td { white-space:nowrap }`.

App additions (spec 057, in `collector/additions.css`): the label and option rules of a grouped select (documented in `Form` and `FilterSelect`), `c-select--wide` (`FilterSelect`), `c-stats--three` (`ItemPage`) and the logo mark's stand-in for the wordmark from 640px to 719px while the header holds five links (`AppHeader`).

App additions (spec 060, in `collector/additions.css`; spec 068's `AddProxy` adds no class, only `.c-decks .c-pagehead__title`): `ProxyTag` (`c-proxy`), `DeckShape` (`c-shape`, `c-curve`, `c-types`, `c-manabar`, `c-manacap`, `c-manacap__item`), `DeckPage` (`c-deck`, `c-shapefold`, `c-zone`), `DecksIndex` (`c-decks`) and the pick list (`c-pick`) of `AddToDeck` and `UseMyCopy`.

App additions (spec 062 and 064, in `collector/additions.css`): `DecksIndex`'s row actions (`c-decks__actions`: Rename, Change format and Remove on one line on a wide screen, wrapping onto lines of their own below 640px, spec 064), the removal pages' wrapping rule (`.c-decks .c-confirm`) and the Rename and Change format heads' `.c-decks .c-pagehead > div` (`min-width: 0`, spec 064). Spec 065 (#252) removed `c-field__static`, the read-only field's rule that spec 062 added for the Edit copy form's Location, which no view uses any more; the grouped picker and "Deck (all zones)" use spec 057's rules, and the app adds no CSS for them. Spec 065 adds one rule to `collector/additions.css`: `.c-pagehead__stats` breaks inside a word (`overflow-wrap:anywhere`) on every page head, so a 60-character place or deck name in a stats line (Move copies', the Decks pages') stays inside a 360px frame; it is the one wrap rule, and spec 064's copy scoped to `.c-decks` is gone.

App additions (spec 070, #257, in `collector/additions.css`): `c-field__value`, the read-only value under a `c-field__label` paragraph (`.c-decks .c-field__value`: no margin, a break inside a word; the label paragraph above it, `.c-decks .c-field > p.c-field__label`, has no margin either), used by Add a new copy's fixed Location and documented in `AddProxy`. `UseMyCopy` is built as drawn and adds no class.

App additions (spec 063, in `collector/additions.css`): the stroke of small icons, set by the component that draws them (`c-badge`, `c-legal`, `c-btn`, `c-input`, `c-menu__item`, `c-filter`, `c-seg`), documented in Iconography.

App additions (spec 074, #326, in `collector/additions.css`): two blocks, no new class. `Menu`'s clearance of the phone tab bar (`scroll-margin-top` and `scroll-margin-bottom` on `.c-menu__list` and a room box, an `::after` on the open list, below 640px on a tabbed shell; the controller's scroll is in `menu_controller.js`), and `DeckPage`'s zone tables' menu column floor (`th.c-zone__c-menu`, 4rem below 640px of the table's container). See `Menu` and `DeckPage`.

App additions (spec 079, #258, in `collector/additions.css`): `DeckCheck` (`c-deckcheck`, `c-deckcheck__title`, `c-deckcheck__summary`, `c-deckcheck__list`, `c-deckcheck__row` with `--pass`, `--fault` and `--plain`, `c-deckcheck__status`, `c-deckcheck__text`), the Check deck results.

App additions (spec 080, #343, in `collector/additions.css`; no view uses them yet): `StatusBand` (`c-band`, `c-band--success`, `c-band--warning`); `Sheet` (`c-sheet` and its `__head`, `__title`, `__dismiss`, `__close`, `__body`, `__foot`); the phone-first `Scanner`'s shell (`c-scan` with `c-scan--result`, its `__top`, `__back`, `__dest` with `__dest-label`, `__dest-value` and `__dest-text`, `__done`, `__stage`, `__video`, `__guide`, `__line` with `__line--status`, `__line--added` and `__line-text`, `__undo`, `__strip`, `__capture`, `__read` with `__read-label`, `__read-name` and `__read-line`, `__bottom`, `__count`, `__main`, `__torch`, and `c-shell--focused` on the `<body>`) and pane (`c-scanpane` and its `__body`, `__rowwrap`, `__row`, `__item`, `__nav` with `__nav--prev` and `__nav--next`, `__card`, `__details`, `__name`, `__set`, `__meta`, `__position`, `__adds`, `__add`); and the app-wide reduced-motion block (Motion). Tokens: `on-success`, `on-warning`, `scrim`.

App additions (spec 087, #376, in `collector/additions.css`): `Licences` (`c-licences`, `c-licences__title`, `__count`, `__list`, `__row`, `__details`, `__heading`, `__name`, `__meta`, `__home`, `__copyright`, `__file`, `__text`, `__missing`), the third-party licences page at `/licences`: a row per work, its licence text in a disclosure.

## Logo

- The mark is three fanned cards, the front one vault teal with a foil diamond: a collection, one piece of which is special. It is deliberately game-neutral so it grows past trading cards.
- Use `collector-wordmark.svg` in the app header on light grounds and `collector-wordmark-reversed.svg` on dark; the mark alone (`collector-mark.svg` / `-reversed`) for favicons, app icons and tight spaces.
- Minimum size: mark 16px, wordmark 24px tall. Clear space: half the mark's height on every side. Don't recolour, rotate, outline or add effects.

## Iconography

- No icon set chosen yet. Until one is, use Lucide (ISC-licensed) in `currentColor`, which matches Plex's weight. Flag any other set here before adopting it.
- Stroke follows the size an icon is drawn at (spec 063). A stroke scales with its icon, so a Lucide stroke of 1.5 draws 1.25px on screen at 20px but 0.75px at 12px, a hairline beside a 600-weight word. Below 20px an icon keeps about 1.25px on screen: the stroke is `30 ÷ size`, with the size in px, rounded to a half, never below 1.5 or above 2.5. The app draws 1.5 at 20px and above (the tab bar's 22px), 2 at 14px to 16px (buttons, inputs, menu items, the view switch, filter chips) and 2.5 at 12px (badges, legality marks, `DeckCheck`'s status icons). Spec 080 adds the `StatusBand`'s icons at 16px and stroke 2, the foil add button's star at 14px (filled, so it has no stroke), and 20px icons at stroke 1.5 inside controls, where the component sets the 1.5 (back from the 2 a `c-btn` gives its icons, for those in a `c-btn`): the phone-first scanner's bars (the back arrow, the destination's chevron, the torch), the row's Previous and Next chevrons and a sheet's Close cross.
- Every icon keeps `stroke-width="1.5"` in its markup (the weight at 20px, so a copied icon looks right on its own). `additions.css` sets the heavier stroke by the component that draws the icon, so an icon placed in one of those components needs nothing more. An icon drawn at a size no component sets gets its stroke by the rule above, and its size and stroke are added to the list of sizes above.
