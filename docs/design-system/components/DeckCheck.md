# DeckCheck

The results of Check deck on the deck page: a full-width section between the page head and the zones, with a heading, a summary line and one row per result (spec 079, #258). The section names no game, format or zone; the core draws it (`decks/_check`) from `Catalog::DeckChecks`' report.

**Markup** — a `section.c-check` labelled by its heading, then the summary and a `ul.c-check__list` of rows. A row is a status word with its icon (`c-check__status`) and a sentence (`c-check__text`), or a sentence alone for a line that is no check.

```html
<section class="c-check" aria-labelledby="deck-check-title">
  <h2 class="c-section__title c-check__title" id="deck-check-title" tabindex="-1" autofocus>Deck check</h2>
  <p class="c-check__summary">2 findings</p>
  <ul class="c-check__list">
    <li class="c-check__row c-check__row--fault"><span class="c-check__status"><svg …alert…/>Short</span><span class="c-check__text">Main: 58 cards; Standard needs at least 60.</span></li>
    <li class="c-check__row c-check__row--pass"><span class="c-check__status"><svg …check…/>Pass</span><span class="c-check__text">Sideboard: 0 cards; Standard allows at most 15.</span></li>
    <li class="c-check__row c-check__row--fault"><span class="c-check__status"><svg …alert…/>Owned and proxy</span><span class="c-check__text">Lightning Bolt in Main: 2 owned, 1 proxy.</span></li>
  </ul>
</section>
```

A deck whose format has no rules starts its list with a plain row, then owned plus proxy:

```html
<li class="c-check__row c-check__row--plain"><span class="c-check__text">Casual has no rules to check.</span></li>
```

**Classes**

- `c-check`: the section, a column with a `space-3` gap and `space-6` above it, as sections separate. The root class is also `Form`'s checkbox row (`label.c-check`); the section's rule is scoped to the deck page (`.c-deckpage > .c-check`), outranks the label's and puts back what it sets (`align-items`, font). Never use the section outside the deck page's `main`.
- `c-check__title`: the heading, "Deck check", in `c-section__title`'s `heading` style.
- `c-check__summary`: "3 findings", "1 finding" or "No findings", in `data` (mono 13/18), `ink-muted`.
- `c-check__list`: the rows on `surface-raised` with a 1px `line` border and `radius-md` corners; rows are divided by `line`.
- `c-check__row`: one result, `space-3` by `space-4` padding.
- `c-check__status`: the status word at 13/18, weight 600, `ink`, after its 12px icon.
- `c-check__text`: the sentence in `body` (15/22), `ink`.

**States** (spec 079 decision 6, AC-6.2)

- `c-check__row--pass`: the word "Pass" with `icons/check` in `success`.
- `c-check__row--fault`: a finding, its word "Short", "Over", "Over the limit" or "Owned and proxy", with `icons/alert` in `warning`. A finding is advice, never an error: the check blocks nothing, so it is never `danger`.
- `c-check__row--plain`: no status, only the sentence ("Casual has no rules to check."), across the row's full width.

**Colour is never the only signal.** The status word says pass or fault and the icon's shape repeats it (a tick or a triangle); the icon's colour only repeats both. The word stays `ink`, so it reads at 4.5:1 on `surface-raised` in both themes.

**Focus** (AC-6.3). The heading has `tabindex="-1"` and `autofocus`: following Check deck lands keyboard and screen reader focus on "Deck check", and the next Tab goes on through the results and the zones in reading order, the section being before the zones in the DOM. The heading shows the 2px `focus` ring at `radius-sm` when focus is visible.

**Widths** (AC-6.1, AC-6.4). The section answers to the page container (`@container page`).

- **Below 640px:** a row is one column: the status word on its line, the sentence under it.
- **From 640px:** two columns, the status in 11rem (wide enough for "Owned and proxy" on one line) and the sentence in the rest, on one baseline with a `space-4` gap; a plain row's sentence spans both.
- A row breaks inside a word (`overflow-wrap: anywhere`, `minmax(0, 1fr)`), so a 60-character card or zone name with no space wraps and the page does not scroll sideways at 360px in either theme. The zone heads and the shape fold's facts line wrap a long zone name too (`DeckPage`).

**Icon.** `icons/check` and `icons/alert` drawn at 12px with a stroke of 2.5, as a badge's icon is (`.c-check__status svg`; README, Iconography). The markup keeps `stroke-width="1.5"`.

**Why not a badge or a list.** `c-badge` is one line and one or two words, and "Over the limit" and "Owned and proxy" are three; `c-list` rows do not wrap; and the deck page had no block between its head and `c-deck`.
