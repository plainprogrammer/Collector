# Feature 021: Mark Unowned Tiles Without Fading the Card Image

**Status:** Direction approved by the maintainer's ruling of 2026-10-13 (decision 1). Decisions 2 to 8 are the implementer's and are put to the maintainer in the pull request
**Version:** 1.1.0
**Created:** 2026-10-13
**Last Updated:** 2026-10-13
**Branch:** `021-unowned-tile-marker`
**Issue:** [#65](https://github.com/plainprogrammer/Collector/issues/65)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-13 | Written from issue #65 and the maintainer's ruling of 2026-10-13 (decision 1) |
| 1.1.0 | 2026-10-13 | From the branch review. `TileAdd.md` is the app's own document (spec 004), not the export's, and never described the fade: only `ItemTile.md` is exported and does. The Inputs, Non-Goals, decision 7, FR-4, AC-3.4 and Open Questions say so, and `TileAdd.md` now documents the add control's place at the foot of its cell. The status line says what is approved and what is still put to the maintainer |

---

## Problem Statement

Scryfall's image guidelines say: "Do not blur, sharpen, desaturate, or color-shift card images. Do not add your own watermarks, stamps, or logos to card images." ([research 016](../016-scryfall-hosting-terms/research.md)). A tile for a card you don't own shows its image at 45% opacity, so the image blends with the surface behind it and reads as washed out. The rule is the design system export's:

```css
.c-tile--owned-none .c-tile__media > img, .c-tile--owned-none .c-tile__missing { opacity:.45; }
```

(`app/assets/stylesheets/collector/components.css:104`). Spec 019 left it out of scope and issue #65 asked for a ruling.

> **Inputs.** The design system and its export arrangement are fixed inputs, as in spec 019: `components.css`, `tokens.css` and the exported documents under `docs/design-system/` are replaced wholesale on re-export, and app patterns live in `app/assets/stylesheets/collector/additions.css` with a document each. Of the two documents that describe these tiles, `ItemTile.md` is the export's and describes the fade ("`c-tile--owned-none` fades an item you don't own"); `TileAdd.md` is the app's own (spec 004) and doesn't mention it.
>
> **Terms.**
> - An *unowned tile* is a tile rendered by `catalog/entries/_tile` for an entry the signed-in account owns no copy of (`c-tile--owned-none`). That partial is the only place the class is used.
> - The *slot* is the tile's image box (`c-tile__media`).
> - The *placeholder* is the missing-image fallback (`c-tile__missing`): the card's name and set number on `surface-sunken`. It is not a card image.
> - The *marker* is the visible text "Not owned" on an unowned tile.

**Where an unowned tile can render** (every use of the partial):

| Page | View |
|---|---|
| Search results (`/catalog/entries`) | `catalog/entries/_group` |
| "Show all N printings" (`/catalog/identities/:id`) | `catalog/identities/show` |

The card page's printings are rows (`c-list li.is-unowned`), and the collection table marks rows with `c-table tr.is-unowned`. Both mute text and touch no image; they stay as they are. The collection grid shows only owned lots, and the scanner's candidates (`scanners/_candidate`) carry no ownership state.

## Goals

- An unowned tile shows its card image exactly as supplied: full opacity, no filter, no blending, nothing laid over it.
- An unowned tile is still told apart from an owned one at a glance, by visible text and not by colour or opacity alone.
- The add buttons of a grid row stay level when the row mixes owned and unowned tiles.
- The change survives a re-export of the design system, and the suite fails if the fade comes back.

## Non-Goals

- Changing owned tiles, the collection grid, the table or list rows, or the scanner's candidates.
- Editing `components.css`, `tokens.css`, or the exported document `ItemTile.md` (which still describes the fade).
- Publishing a change to the design system or re-exporting it.
- The `×N` quantity badge (see Open Questions).

**Spec 019.** Its AC-1.8 asserted that an unowned tile "is faded, as today". This spec replaces that half of the criterion; the example that held it (`spec/system/card_image_fit_spec.rb`) now expects full opacity. Spec 019's document is not edited.

## Decisions

### 1. Look D: the image as supplied, with a visible "Not owned" marker below it (ruled)

**Ruling (maintainer, 2026-10-13).** The maintainer compared four rendered looks at desktop and phone width in both themes: the current fade; B, the image at full opacity and nothing else; C, B with the tile's name muted; D, B with a visible "Not owned" tag under the set and language row. The maintainer chose D. The mock-up is on the local branch `065-unowned-tile-options`; it is a reference and nothing from it is merged.

### 2. The marker is a `c-tag`, on a `c-tile__meta` row of its own

No new class. The tag is what the maintainer saw and chose, and a status phrase in a `c-tag` has a precedent: the scanner's "Changed in your collection" (`Scanner.md`). `Chip.md` describes the tag as "for data"; ownership is a fact about the printing, shown beside its set code and language in the same `ink-muted` monospace. A marker class of its own would add a pattern to upstream for no visible difference. The row is a second `c-tile__meta` so it takes the existing spacing and, if a tile is ever too narrow, the export's ellipsis.

### 3. The dashed frame stays

`c-tile--owned-none` also gives the slot a dashed `line-strong` border (`components.css:103`). The border is the slot's own, outside the image's box: it neither covers nor changes the image. It stays because it is the export's, it was in the look the maintainer chose, and it gives a second cue at the picture's level when scanning a large grid. The marker carries the meaning in words, so the frame is never the only signal.

### 4. The copy is "Not owned"

Sentence case, no punctuation, the hobby's own word, and the same word the design system uses elsewhere ("3 of 4 owned", the "Owned" filter). It states a fact and asks nothing; the add button beside it is the action.

### 5. The placeholder loses its fade too

The placeholder is not a card image, so the guideline doesn't reach it. It is shown at full opacity all the same: every unowned tile is then marked one way, and its name and set number keep the contrast the design system promises (`ink` and `ink-muted` on `surface-sunken`), which 45% opacity took away.

### 6. A screen reader hears the marker as part of the tile's link

The marker is plain text inside the tile's `<a>`, after the name, the set tag and the language tag, so it is part of the link's accessible name, which ends with it: for example "Lightning Bolt Lightning Bolt M10 · 146 EN Not owned" (the image's alternative text, the name, the two tags, the marker). No `aria-label`, no hidden text. An owned tile's name carries "×3" as it does today.

### 7. The add button goes to the foot of its cell

An unowned tile is one line taller (the tag's 18px and the tile's 8px gap). A grid row stretches its cells to one height, so in a mixed row the owned tiles' add buttons would sit a line higher. The add form takes `margin-top:auto` inside `c-tilecell`. The mock-up stretched the tile's link instead (`flex:1`); the outcome on screen is the same, but the margin leaves the link's box, and so its click area, the size of its content, and the selector (`.c-tilecell > .c-tile__add`) can't match a scanner candidate, which shares `c-tilecell` and has no such form. Where the add control sits is `TileAdd`'s behaviour, so `TileAdd.md` documents it and it outlives this override.

### 8. An override in `additions.css`, not a re-export

As spec 019's decision 1, for the same reasons. One block, headed `Unowned tile (spec 021)`; a pattern document `UnownedTile.md`; a line in the README's app additions. The document says the published `ItemTile` should drop the fade at its next export.

## User Stories

### Story 1: An unowned tile shows the card as supplied and says it isn't owned

**As a** collector searching the catalog
**I want** a card I don't own to show its picture untouched and say "Not owned"
**So that** I can see the card properly and still tell at a glance what I have

- [ ] **AC-1.1** Given an entry with an image that the account doesn't own When search results are rendered Then its tile's image has a computed opacity of 1, no filter and normal blending, as does every element between it and the tile cell, and the slot holds nothing but the image
- [ ] **AC-1.2** Given the same tile Then it shows the text "Not owned" in a `c-tag`, inside the tile's link, on a row after the set and language row, and no quantity badge
- [ ] **AC-1.3** Given an entry the account owns three copies of When search results are rendered Then its tile shows `×3` and no "Not owned" text
- [ ] **AC-1.4** Given an unowned entry with no image Then its tile shows the placeholder at a computed opacity of 1 and the marker
- [ ] **AC-1.5** Given an unowned entry When the card's printings page ("Show all N printings") is rendered Then its tile carries the marker, and an owned one doesn't
- [ ] **AC-1.6** Given an unowned tile Then its link's accessible name, as the browser computes it, ends with "Not owned"
- [ ] **AC-1.7** Given search results with owned and unowned tiles When rendered at 1280px and at 390px, in the light and the dark theme Then the marker is shown in full (not cut off), and the page doesn't scroll sideways (screenshots)
- [ ] **AC-1.8** Given a copy of an unowned card is added with the tile's add button Then the tile shows `×1` and no marker (the existing quick-add flow; its example gains the marker's before and after)

### Story 2: Rows stay level

- [ ] **AC-2.1** Given a grid row that mixes owned and unowned tiles When rendered at 1280px and at 390px Then every add button in the row has the same top edge
- [ ] **AC-2.2** Given the scanner's candidates Then the new rule matches nothing in them (markup: a candidate has no `c-tile__add`)

### Story 3: The change survives a re-export

- [ ] **AC-3.1** `components.css` and `tokens.css` are byte-for-byte unchanged
- [ ] **AC-3.2** The rules are in one block of `additions.css` headed `Unowned tile (spec 021)`, with no colour literal and no font
- [ ] **AC-3.3** With the block removed, the browser examples for AC-1.1, AC-1.4 and AC-2.1 fail
- [ ] **AC-3.4** `docs/design-system/components/UnownedTile.md` documents the pattern, says it overrides the export and that the published `ItemTile` should drop the fade; the README's app additions list it; `TileAdd.md` shows the marker row and says the add control sits at the foot of its cell (verified by reading)

## Functional Requirements

- **FR-1** `catalog/entries/_tile` renders, for an unowned entry only, `<div class="c-tile__meta"><span class="c-tag">Not owned</span></div>` as the last child of the tile's link.
- **FR-2** `additions.css` sets `opacity:1` on the two selectors the export fades, and puts the add form at the foot of its cell.
- **FR-3** No shipped rule reduces the opacity of, filters or blends a card image on a tile.
- **FR-4** The pattern is documented in `UnownedTile.md`, and the add control's place in the app's own `TileAdd.md`. The exported `ItemTile.md` is not edited.

## Non-Functional Requirements

- **Accessibility.** The marker is `ink-muted` text, which holds at least 6:1 on `surface` in both themes (design system README, Color). Ownership is stated in words, never by the frame alone.
- **Performance, security, data.** No query, no JavaScript, no setting, no migration, no stored data; the export format is untouched. The hosted-door rules: this closes a gap against the first (source terms); the others don't apply.
- **Testability.** Markup is checked by request specs. The computed styles, the accessible name and the row's alignment are checked in the suite's browser, the way spec 019 checked its fitting rules (`spec/system/card_image_fit_spec.rb`), because a stylesheet's effect can't be read from its text. The block's shape is checked in `spec/design_system_files_spec.rb`, as 019's is. Documents are verified by reading (`.claude/rules/testing.md`).

## Open Questions

- **The `×N` quantity badge sits on the image's top right corner.** Whether a badge laid over a card image counts as a "stamp" under the same guideline has not been ruled on. Not acted on here.
- **`ItemTile.md` still describes the fade** until the published design system changes and is re-exported. `UnownedTile.md` says which document holds.

## Out of Scope

`docs/roadmap.md`, `Gemfile`, the export format, the muted rows (`c-list li.is-unowned`, `c-table tr.is-unowned`), wishlists and set checklists (not built; `ItemTile.md` names them as the modifier's other uses, and they inherit this pattern when they are).
