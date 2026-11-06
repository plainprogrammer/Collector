# Verification: spec 048

Evidence for each criterion. Screenshots (`screenshots/`, factory data, placeholder printings with no card art): the table at 1280px light and dark, 390px light and dark, and 800px light, with a 60-character name with spaces, a 60-character name with no space, a short name and an unplaced lot. Each was read one by one. The 800px shot shows the cost the maintainer accepted with option B: the Location column shrinks to its longest word, so the unbroken name takes eight lines there; at 1280px the same name takes three and the spaced name two.

| Criterion | Evidence |
|-----------|----------|
| AC-1.1 phone, name with spaces | `spec/system/collection_row_place_spec.rb` "shows a name with spaces whole in the line under the name, with no sideways scroll, at 360px / 390px" (green before the change as a guard; mutation (b) fails it) |
| AC-1.2 phone, 60 "W"s | same file, "… with no space …" at 360 and 390px (red on the shipped CSS: `[w, false]`, a real overflow of about 440px; green after) |
| AC-1.3 wide, spaces | same file, "keeps a name with spaces whole in the cell, within 20rem and within the table's container" at 800, 900, 1024 and 1280px; and "does not scroll the page sideways … at 760px" |
| AC-1.4 wide, 60 "W"s | same file, the "with no space" examples at the same frames; mutation (a) (no `overflow-wrap:anywhere`) fails five of them |
| AC-1.5 escaped | `spec/requests/collection_places_spec.rb` "escapes a name on the row, in the cell's span and in the line under the name" |
| AC-1.6 tile cut | spec 033's `spec/system/collection_table_spec.rb` "keeps a long place name to one line on a tile, and its +N more visible", unchanged and green; `.c-tile__place*` untouched (`git diff` of the rules) |
| AC-1.7 no location | same system file, "for an account with no location … fits one line under the name at 360px / 390px"; mutation (c) (a 4ch line) fails it on the line's height |
| AC-2.1 name filter | `collection_places_spec.rb` "shows all of a matching printing's places under a name filter, and no other printing" and "shows only the matching lots' rows under a name filter, each with its place"; mutation (`places_of` reading one lot's place) fails the first |
| AC-2.2 tile accessible name | system file, "names the whole place line in its link's accessible name, after the card's name"; mutation (`aria-hidden` on the "+N more" span) fails it |
| AC-2.3 bulk Set condition and Undo | `collection_places_spec.rb` "after a bulk action": "keeps each lot's place when Set condition is applied", "… when a bulk Remove is undone from the bulk table's message" (it asserts the Undo's `return_to` is `collection_path(bulk: 1)` before posting); mutation (the cell not rendered) fails both |
| AC-2.4 core guard | `spec/collection_places_core_spec.rb` (2 examples; the file added to `.rubocop.yml`'s `RSpec/DescribeClass` exclusions as the other core guards are); the regex has no word boundaries, so `scryfall_id` and `mtg_printing` also fail it; mutations (`<%# MTG %>`, `<%# entry.scryfall_id %>` in `_tile.html.erb`, `<%# MTGPrinting %>` in `_lot_cells.html.erb`) fail it |
| AC-2.5 tie by comparison key | `spec/models/collection_grid_spec.rb` "orders a tie by comparison key, where the raw name would order it the other way" and `collection_places_spec.rb` "orders a tie by comparison key on the rendered tile"; mutation (`key.to_s` to `name.to_s`) fails both |
| AC-2.6 only the place line changes | `collection_places_spec.rb` "changes nothing about a tile but its place line when the lots are placed"; mutation (quantity minus one on a placed tile) fails it |
| AC-3.1 design-system docs | By reading: `docs/design-system/components/CollectionTable.md` names `c-table__place`, `c-table__place-name` and the wrap rules of the cell and the line; `docs/design-system/README.md` has the spec 048 app-additions paragraph; `additions.css`'s comment cites spec 048 decisions 1–3 |
| AC-3.2 index and area doc | See "Distillation" |

## Runs (2026-11-06, after `origin/main` was merged in)

- `bin/rspec` on `spec/system/collection_row_place_spec.rb`, `spec/system/collection_table_spec.rb`, `spec/system/collection_spec.rb`, `spec/requests/collection_places_spec.rb`, `spec/models/collection_grid_spec.rb`, `spec/models/collection_table_spec.rb`, `spec/requests/collections_spec.rb`, `spec/requests/collection_views_spec.rb`, `spec/requests/bulk_condition_spec.rb`, `spec/requests/bulk_removal_spec.rb`, `spec/collection_places_core_spec.rb`, `spec/requests/query_counts_spec.rb`: **141 examples, 0 failures**. This branch adds 27 of them (17 system, 7 request, 1 model, 2 core). RuboCop on the four spec files: no offenses.
- Task 1's red run on the shipped CSS: 32 examples, 13 failures, all the planned ones (the two no-space phone examples, the eight wide examples, the two 760px examples and the new request example).
- Mutation checks, each reverted: (a) to (d) on `additions.css` as in the plan's Task 2; one per Phase 2 example as above. Each failed for the reason named.

## Deviations from the plan and the spec

- Spec FR-1 and the plan agree: `white-space: normal` is on the named cell (`.c-table td.c-table__place:not(.is-muted)`), and the span holds the cap and the break rule. An earlier plan draft put it on the span; plan review round 1 (m5) moved it back so the "No location" cell keeps one line and the spec's decision 5 and AC-3.1 wording hold.
- Task 8's `bin/rubocop spec/collection_places_core_spec.rb .rubocop.yml` fails because RuboCop reads the YAML as Ruby; the spec file alone is clean and `.rubocop.yml` is a plain data file. Run on the spec file only.
- No example failed on unmutated code, so spec 033 has no bug to report from the gaps.

## Out of scope, recorded

- The table is up to about 20px wider than its container for containers of 640 to about 660px even with a short name (probe 2). It is not a place's doing, nothing scrolls, and it is filed as [#208](https://github.com/plainprogrammer/Collector/issues/208).

## Implementation review

DRIFT DETECTED at first, SPEC-ALIGNED after the fixes below (no blocking finding; 1 major, 3 minor). The review was an independent read-only `sdd-review` Mode B on Opus, run on `5fcb211` (2026-11-06). It read the diff, the stylesheet cascade, the design-system documents and the screenshots; it ran no specs.

**Findings and what was done**
1. **Major, AC-2.4:** the guard's `\b(mtg|scryfall|magic)\b` let `scryfall_id`, `mtg_printing` and `magic_cost` through, since `_` is a word character. The regex is now `/mtg|scryfall|magic/i`; a case-insensitive grep of the seven files finds none; two new mutations fail it (commit `2d728850`).
2. **Minor, AC-2.3:** the Undo example now asserts the form's `return_to` is the bulk table's URL before posting (`e2f138a0`).
3. **Minor, AC-2.5:** a rendered-tile example joins the model one (`e9074f03`).
4. **Minor, AC-3.1:** `CollectionTable.md` said the cell breaks an unbroken name; the rule is on the `c-table__place-name` span, and the sentence now says so (`a8f5a4b`).

**Checked and holding (from the review):** AC-1.1 to AC-1.7 and AC-2.1, AC-2.2, AC-2.6 meet their wording; `.c-table td.c-table__place:not(.is-muted)` (specificity 0,3,1) beats the export's `.c-table td` and `additions.css` loads after `components.css`; `.c-collection` is the `collection` container so the phone rule applies to `.c-table__sub`; the cap is on the span (decision 2); tiles untouched; the guard's file list matches `git diff --name-only a3baf0d^1 a3baf0d` less the stylesheet.

**Rule checks:** testing (explicit types, `:aggregate_failures`, no prose documents from RSpec) holds; no query or logic in views; output escaped (AC-1.5); tokens and `c-*` classes only, the 20rem cap being a width like the other literals in `additions.css`; the design-system documents are updated in the same pull request; the area doc and the index wait for the distillation step.
