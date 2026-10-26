# Plan: Show the Location on Tiles and Rows (spec 033)

**Spec:** [spec.md](spec.md) 1.0.0 (approved 2026-10-26). **Branch:** `033-location-on-tiles-and-rows`. No migration, no ADR, no export change.

## Global constraints

- Test first: each example is seen failing for the stated reason, then passing. Blocks below are strong drafts, not byte-exact.
- Views get prepared values; no queries in views. Tokens and `c-*` classes only. Tag spec types explicitly, `:aggregate_failures` on multi-expectation examples.
- Run `bin/rubocop -a` on edited Ruby; whole suite (`bin/rspec`) at the end.

## Phase 1: the places of a page (model)

Files: `app/models/collection_filter.rb`, `app/models/collection_grid.rb`, `app/models/collection_table.rb`, `spec/models/collection_grid_spec.rb`, `spec/models/collection_table_spec.rb`.

1. `CollectionFilter#places?` = `@account.locations.exists?`, memoized (FR-3).
2. `CollectionGrid::Tile` gains `place` (`Place = Data.define(:name, :more)`; `name` nil when the first place is unplaced; `nil` for the whole value when the account has no locations).
   One grouped statement over `account.lots.where(catalog_entry_id: ids).left_joins(:location).group(:catalog_entry_id, :location_id)`, `SUM(quantity)`, `locations.name`, `locations.name_key`. Order per printing in Ruby: `[-quantity, unplaced ? 1 : 0, name_key, name]` (Decision 1). `more` = other places (unplaced counts).
   Examples: AC-1.2, 1.3, 1.4 (one place; 3+1; 2+2 tie; with unplaced; all unplaced), AC-1.5 (no locations → nil), AC-1.8, and a query-count example (same count for 1 and 20 tiles, AC-3.2).
3. `CollectionTable#lots` preloads `:location`; example: no extra query per lot.

## Phase 2: the tile

Files: `app/views/collections/_tile.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/requests/collection_views_spec.rb`, `docs/design-system/components/ItemTile.md`, README app-additions line.

- A second `c-tile__meta` row with `<span class="c-tile__place">`: the name (escaped, ellipsis, own span) and ` +N more`; "No location" for an unplaced first place. Muted by the meta ink. A small `additions.css` rule (marked spec 033) so the name truncates and the "+N more" does not; documented under `ItemTile`.
- Request examples: AC-1.1–1.7 as rendered HTML (escaping of `<b>`, 60-code-point name stays one element, tile link text contains the whole line), no line without locations, tenant isolation (AC-3.1), signed-out and catalog tiles unchanged (AC-3.4).

## Phase 3: the row

Files: `app/views/collections/_table.html.erb`, `_lot_cells.html.erb`, `app/helpers/lots_helper.rb`, `spec/requests/collection_views_spec.rb` (or `collection_table`), `spec/system/collection_table_spec.rb`, `docs/design-system/components/CollectionTable.md`.

- `th.is-opt` "Location" (plain, not sortable) after Qty, before Paid; `td.is-opt` with the name or muted "No location"; both only when `table.places?`; the `_lot_cells` local `places:`.
- `LotsHelper#lot_row_summary(lot, places:)` = `lot_summary` plus the location name last (nothing for unplaced); `lot_summary` itself unchanged (card page and refusal page).
- Request examples: AC-2.1, 2.4, 2.5, 2.6 (rename; bulk Set condition keeps place), bulk mode rows (AC-2.3), escaping. System example (narrow frame, memory `headless-firefox-narrow-frame`): column hidden at 360px, place in the line under the name, no sideways scroll (AC-2.2).

## Phase 4: documents and verification

- `docs/specs/README.md` (row already added; status stays Approved until merge), `docs/roadmap.md` item 11 (built, small), `CLAUDE.md` one clause on the place line in the locations bullet.
- `docs/specs/033-…/verification.md`: each AC with its example; screenshots at 1280 and 390, light and dark, in `screenshots/`; `## Implementation review` after `sdd-review` Mode B.
- `bin/ci`; then `distill-feature` at session end (no area doc exists for collection and lots, #105: raised, not written).
