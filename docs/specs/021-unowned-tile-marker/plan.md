# Implementation Plan: Mark Unowned Tiles Without Fading the Card Image

**Spec:** [spec.md](spec.md) (v1.0.0; direction ruled by the maintainer on 2026-10-13)
**Decisions:** no ADR. Decision 1 is the maintainer's ruling; decisions 2 to 8 are the spec's.
**Created:** 2026-10-13
**Issue:** [#65](https://github.com/plainprogrammer/Collector/issues/65)

**How this plan was made.** As spec 019's was: the change was applied to this worktree uncommitted, and each phase's examples were run red before its change and green after. The red runs are quoted in [verification.md](verification.md).

## Global Constraints

- `components.css` and `tokens.css` stay byte-for-byte as exported. `ItemTile.md` and `TileAdd.md` aren't edited.
- Every style change is in one block of `additions.css`, headed `Unowned tile (spec 021)`, placed after the `Image fit (spec 019)` block. Token variables and `c-*` classes only.
- One view changes: `app/views/catalog/entries/_tile.html.erb`. No controller, model, helper, JavaScript, gem, setting or migration.
- Nothing from the mock-up branch `065-unowned-tile-options` is merged: no `?unowned=` switch, no looks B or C.
- Each commit passes the suite: a phase's examples are committed with its change, after being seen to fail without it.
- Conventional Commits, one per step, staged and committed in separate commands. Nothing is pushed.
- Out of scope: `docs/roadmap.md`, `Gemfile`, the `×N` badge, the export format, the muted rows.

## Phase 1: The marker in the markup (AC-1.2, AC-1.3, AC-1.4 markup, AC-1.5)

**Red.** In `spec/requests/catalog/entries_search_spec.rb`, the example "shows owned quantities and fades printings you don't own" becomes "…marks printings you don't own as not owned": the owned tile has `×3`, the class `c-tile` alone and no "Not owned"; the unowned tile has no badge and two `c-tile__meta` rows, `[set · number, language]` then `["Not owned"]`, the second being the link's last child. A second example covers an unowned entry with an image (the slot holds the `img` and nothing else) and one without (the slot holds `c-tile__missing`), both ending in the marker. `spec/requests/catalog/identities_spec.rb` gets the same check for the printings page.

**Green.** `_tile.html.erb`:

```erb
<% unowned = owned.to_i.zero? %>
…class_names("c-tile", "c-tile--owned-none": unowned)…
    <div class="c-tile__meta"><span class="c-tag">…</span><span class="c-tag">…</span></div>
    <% if unowned %><div class="c-tile__meta"><span class="c-tag">Not owned</span></div><% end %>
```

**Commit:** `feat(021): say "Not owned" on the tile of a card you don't own`.

## Phase 2: The image as supplied, and level rows (AC-1.1, AC-1.4, AC-1.6, AC-1.7, AC-2.1, AC-3.2, AC-3.3)

**Red.** A new `spec/system/unowned_tile_spec.rb` (headless Firefox, `:card_images`, so no picture is fetched from a source):

1. For the unowned image and the unowned placeholder, the computed `opacity`, `filter`, `mix-blend-mode` and `backdrop-filter` of the element and of every ancestor up to its `c-tilecell` are `1 none normal none`; the slot's and the link's `::before` and `::after` draw nothing; the slot has one child. Repeated in the dark theme.
2. The marker is visible in the link, the browser's computed accessible name of the link ends with "Not owned", and the owned tile has `×3` and no marker.
3. Four tiles (owned, unowned, unowned without an image, owned): at 1280px all four add forms have one top edge; in a 390px frame (two columns) each row's two do, the page doesn't scroll sideways and the marker isn't cut off.

`spec/system/card_image_fit_spec.rb`'s search-results example asserted the fade (spec 019 AC-1.8, "as today"); it now expects an opacity of 1 and says spec 021 replaced that half of the criterion. `spec/design_system_files_spec.rb` gets a `describe` beside 019's: one block, its two rules, no colour literal or font; and, across the app's stylesheets, the only rules naming `c-tile` that set `opacity`, `filter` or `mix-blend-mode` are the export's `opacity:.45` and this block's `opacity:1`, so a new fading rule fails the suite even on an element no example renders.

**Green.** `additions.css`:

```css
.c-tile--owned-none .c-tile__media > img, .c-tile--owned-none .c-tile__missing { opacity:1; }
.c-tilecell > .c-tile__add { margin-top:auto; }
```

The first repeats the export's selectors, so it wins by source order: the layout loads `collector/additions` after `collector/components`. The second matches the add form only where it is a direct child of a tile cell: not in `c-list` rows, and not in a scanner candidate, which has no `c-tile__add` (AC-2.2, by reading `scanners/_candidate` and `scanners/_add_buttons`).

**Commit:** `fix(021): show an unowned tile's image as supplied and keep its row level`.

## Phase 3: The design system documents the pattern (AC-3.4)

- `docs/design-system/components/UnownedTile.md`: markup, the rules, that it overrides the export, and that the published `ItemTile` should drop the fade at its next export (and `TileAdd`'s markup gain the marker row).
- `docs/design-system/README.md`: one line under the app additions, as spec 019's.

**Commit:** `docs(021): document the unowned tile pattern`.

## Phase 4: Verification

- Screenshots of search results before (on `origin/main`'s stylesheet and partial) and after: 1280px and 390px, light and dark, from a dev server seeded with real cards by the mock-up's `seed.rb` (through the app's own refresh), captured with its `capture.rb` cut down to one look. Each is looked at. Saved as JPEG under `screenshots/`.
- In the same dev pages, with real Scryfall images: the computed opacity, filter and blending of every tile image, and the add buttons' top edges per row.
- `bin/ci`, and `git diff --stat origin/main -- app/assets/stylesheets/collector/components.css app/assets/stylesheets/collector/tokens.css` printing nothing (AC-3.1).
- A read-only review of the branch against the spec.
- `verification.md` records all of it, and what was verified only by reading.

**Commit:** `docs(021): record the verification`.
