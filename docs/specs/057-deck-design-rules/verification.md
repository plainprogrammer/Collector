# Verification: spec 057, design system deck rules, navigation and pickers

**Spec:** [spec.md](spec.md) 1.1.0 | **Plan:** [plan.md](plan.md) | **Issue:** [#248](https://github.com/plainprogrammer/Collector/issues/248)
**Recorded:** 2026-11-10, on branch `057-deck-design-rules` after merging `origin/main` (b0e699d3).

## Browser and unit criteria (RSpec, headless Firefox)

Run with `script/worktree/with_mise bin/rspec` on the four files below: **44 examples, 0 failures**.

| File | Examples | Criteria |
|------|----------|----------|
| `spec/system/design_system_deck_rules_spec.rb` (new) | 16 | AC-1.3 to 1.6, 4.2 to 4.4, 5.2 to 5.4 |
| `spec/design_system_tokens_spec.rb` (new) | 6 | AC-2.3 |
| `spec/design_system_files_spec.rb` | 7 | AC-7.3 (guard: "spec 019" once, "spec 021" once, no "font" in the image-fit block, 3 rules in the untabbed-shell block) |
| `spec/requests/collection_location_select_spec.rb` | 15 | AC-4.6 (normal and bulk) |

The full `bin/ci` run is recorded in the pull request (one run, with a CI slot).

### Red runs (test first), as the implementers reported them

| Phase | Red | Reason |
|-------|-----|--------|
| 1 (AC-4.6) | 2 failures | `expected "c-select c-select--wide" got "c-select"` (the edited example and the new bulk-mode example) |
| 2 (AC-4.2, 4.3) | 4 of 4 failed | Firefox's group label was `rgb(31, 29, 26)`, weight 700, italic; the option background was `rgba(0, 0, 0, 0)` (form and filter select, light and dark) |
| 3 (AC-4.4) | 1 of 2 failed | at 700px `expected "300px" got "220px"` (normal view and bulk mode); the 390px example passed as the plan said |
| 4 (AC-5.2 to 5.4) | 3 of 3 failed | 900px: 4 columns, not 3; 328px: 2 columns, borders wrong; AC-5.4's helper needed a one-line fix (`stats[1] ? … : null`) for the single-stat strip, then its control passed without CSS (it guards the default and single strips) |
| 5 (AC-1.3 to 1.6) | 2 of 7 failed | AC-1.3 at 640px (the account menu ends 54.6px past the bar, the wordmark shows) and at 719px (the wordmark shows; five links and the wordmark fit there). AC-1.5 (720px), AC-1.6, AC-1.4 and both controls passed. The finding that five links overflow at 640px led to spec 1.1.0, decision 19 |
| 6 (AC-2.3) | no red | a guard on a floor that already holds; its control (`line-strong` set to `#b0a898`) is flagged, so the check can fail |

Phase 6's lowest pair is `line-strong` on the light `surface-sunken`, 3.0100269:1; next 3.350 (`line-strong` on light `surface`) and 3.511 (`line-strong` on dark `surface-raised`). AC-1.4's five tabs at 360px are 67.4px each in a 345px bar; the widest label ("Collection", 55.87px) leaves 11.5px.

### Measurements recorded

- Header at 640px with five links (before decision 19): nav 379.6px, wordmark 138px, bar padding 32px, 625px layout width, account menu 54.6px past the content edge. Link widths 89.2, 63.4, 69.05, 55.8 and 86.17px.
- Five links with the wordmark first fit at a 695px viewport (classic scrollbar); the swap ends at 720px (25px spare). Probes of the alternatives (not chosen): padding 16px leaves 6.6px over; link padding 8px leaves 14.6px over; both together 0.
- `AppHeader.html` (the preview), read in headless Firefox: at 640px the mark shows, the wordmark is hidden, five links on one row, page scroll width 640; at 720px the wordmark shows, the mark is hidden, five links on one row, scroll width 720.

## Document criteria (read against the text)

| AC | Where, and what it says | Verdict |
|----|-------------------------|---------|
| 1.1 | `docs/design-system/README.md` Navigation, lines 81 to 84: "A collector's wide header, in order: Collection, Decks, Search, Scan, Locations. The phone tab bar, in order: Collection, Decks, Search, Scan, More; Locations stays in More. Each collector will later be able to choose and reorder their own sections, so never hard-code a section's position. Wishlist is planned. Decks joins … when the deck pages ship"; "The tab bar holds five tabs at most and is now full". "Decks and Wishlist don't exist yet" is gone; "Wishlist" is in the README once, as "Wishlist is planned" | met |
| 1.2 | `AppHeader.md` line 21 (order; "Wishlist is planned"), the line after it ("the five links share one line with the account menu") and the new mark bullet; `TabBar.md` (first paragraph: "four sections (Collection, Decks, Search and Scan, in that order; Locations stays in More) and More … The five tabs are full", markup with the five tabs and the Decks icon: a card and the one behind it, plus the icon bullet); `MorePage.md` ("it stays in More because the tab bar's fifth tab is More and its five tabs are full") | met |
| 2.1 | README line 34 and `ManaCost.md` line 15: "data colours, used only to show mana: the `ManaCost` pips and charts of mana symbols"; "stay apart from `success`, `warning` and `danger`"; "identical/the same in both themes"; "the letter or number always shows"; "every use has a 1px `line-strong` outline". `git grep -i "never used anywhere"` over `docs/design-system`: no hit | met |
| 2.2 | README line 35, "Charts.": neutral fills (`ink-muted`; a hatched `line-strong` fill with an `ink-muted` outline for a second series), "Every column or segment carries a word or a number", "`role="img"` with an `aria-label`", "hold 3:1 against the ground", "a chart of mana symbols may use the `mana-*` fills, each with a 1px `line-strong` outline, and a divider between segments" | met |
| 2.4 | README line 25: "Both read on `surface`, `surface-raised` and `surface-sunken` in both themes (5.5:1 or better)"; no "≥6:1" | met |
| 3.1 | README `## Decks` (line 88), after Navigation and before Components, defines Deck, Zone, Considering, Proxy, "Deck › Zone", Free to use and Places (lines 91 to 97). It names no format and no collectible (the zones named are "Main or Sideboard", as spec FR-3 states them) | met |
| 3.2 | README line 9 ("A deck is a kind of location whose copies live in its zones … the Decks section below defines the words, 'Free to use' among them"); `ItemPage.md` line 30 ("Free to use is the copies you own minus the copies in any deck zone, Considering included. A proxy never counts"); `SKILL.md` line 37 ("a deck is a location with zones … 'Free to use' = owned − copies in any deck zone (Considering included); a proxy never counts"). None says "a location like a binder or a box" | met |
| 4.1 | `Form.md` line 40: flat with no deck; "No location", then `optgroup` "Places", then `optgroup` "Decks" written "Deck › Zone"; an empty group omitted; "The browser or the phone draws the open list … nothing depends on it (decision 16)". `FilterSelect.md` lines 17 and 18: 220px, the one exception (`c-select--wide`, 300px from a 640px collection, Set and Language stay 220px), "All locations" and "No location" first, "<Deck> (all zones)" first in each deck's run | met |
| 5.1 | `ItemPage.md` lines 17 to 33: Owned, In decks, Free to use, small lines "N printings", "in N decks", "not in a deck"; "Est. value waits for prices: when it returns, the strip is the plain four-up `c-stats` again"; order "stats, your copies, printings, in decks, format legality"; "full-width section after Printings … columns Deck …, Zone, Owned and Proxy … the Proxy column is always shown, with a muted dash for none"; "A proxy never counts in Owned, In decks or Free to use". `ItemPagePhone.md` lines 8 and 11: "stats stay three across", "Zone folded under the deck name and the format" | met |
| 5.5 | `SingleStat.md` last bullet: "For three stats use `c-stats c-stats--three` instead" | met |
| 6.1 | `Locations.md` line 35: "The page lists places only … Its count counts places only. Decks live on their own page (Decks, with its own header link and tab) … the Locations page carries no pointer to Decks" | met |
| 7.1 | `CLAUDE.md` "UI and design system": "The design system is the project's own, in code: new patterns go in `collector/additions.css` with a doc per pattern under `docs/design-system/components/`, and a rule changes in `docs/design-system/README.md`"; "replaced wholesale" is gone | met |
| 7.2 | README Components ownership bullet ("The design system is the project's own, in code (spec 057 decision 12). A new pattern goes in `collector/additions.css`, with a doc under `components/` and a line in the App additions list below; a rule changes in this README"); 14 "Upstream …" sentences removed (script printed `removed 14`), each line keeps its spec, classes and facts; a 15th "App additions (spec 057 …)" line added | met |
| 7.3 | `additions.css` heading comment and the two override comments now say where the rule came from ("this block is the rule (spec 057 decision 12)", "the first rule here is what applies"); the comment at `design_system_files_spec.rb` lines 48 and 49; `ImageFit.md`, `UnownedTile.md`, `ItemTile.md` (its `c-tile--owned-none` sentence points to `UnownedTile`), `catalog-core.md`, `collection-and-lots.md` (the unowned-tile bullet's "until the published `ItemTile` drops the fade" now says `components.css` still carries the fade; the open-question line says `ItemTile.md` points to `UnownedTile`). Guard spec green (7 examples); "spec 019" and "spec 021" once each in `additions.css` | met |
| 8.1 | The four navigation previews read, in headless Firefox: `AppHeader` Collection/Decks/Search/Scan/Locations; `TabBar` Collection/Decks/Search/Scan/More; `CollectionPage` and `CollectionPagePhone` both. `git grep -i wishlist` over those four files: no hit. (`ItemPage.html` and `ItemPagePhone.html` keep their "Add to wishlist" menu item by the plan: Wishlist is planned, and no rule of this spec touches the item) | met |
| 8.2 | `ItemPage.html` and `ItemPagePhone.html`: `c-stats--three` once each, the In decks section (two `In decks` strings: the stat and the title) full width before Format legality, no `Est. value`, no `c-split`, five links and five tabs; screenshots at 1280px and 390px in both themes below | met |
| 8.3 | All six previews' stylesheet links read: `preview-fonts.css, tokens.css, components.css, additions.css` | met |

## AC-7.4: the `git grep` hits

`git grep -n -i -e "re-export" -e "replaced wholesale" -e "Upstream" -e "before the next export" -e "an export that" -e "published design system" -- CLAUDE.md .claude/skills docs/design-system docs/architecture app/assets/stylesheets spec ':!.kamal/secrets'`

| Hit | Reading |
|-----|---------|
| `docs/architecture/catalog-core.md:69` | the "no longer present in the upstream source" notice text: unrelated (the card source, not the design system) |
| `docs/architecture/release-and-deploy.md:253` | "nothing filed upstream (#177)", a container-engine limit: unrelated |
| `docs/design-system/components/StatusMessage.md:18` | the sample message "no longer present in the upstream source": unrelated |
| `spec/lib/collector/push_scope_spec.rb:69` | `git push --set-upstream`: unrelated |
| `spec/models/collection_import/round_trip_spec.rb:141` | "re-exports with the stored spelling": the import round trip, unrelated |
| `spec/requests/catalog/entries_show_spec.rb:128` | the same notice text: unrelated |
| `spec/script/upgrade/release_spec.rb:79` | `git fetch <upstream> --tags`: unrelated |

No hit is an instruction or an expectation. Every hit that was one (the README's 14 lines, the `CLAUDE.md` note, the `additions.css` comments, `ImageFit.md`, `UnownedTile.md`, `ItemTile.md`, the two area docs, the guard spec's comment) was edited.

## Screenshots

In [screenshots/](screenshots/), each in light and dark: `AppHeader-1280`, `CollectionPage-1280`, `ItemPage-1280` (full page at 1280px); `TabBar-390`, `CollectionPagePhone-390`, `ItemPagePhone-390`, `ItemPage-390` (a 390px frame); `AppHeader-header-640`, `-719`, `-720` (the header at the swap's edges: mark, mark, wordmark); `grouped-select-420` (the form select and the filter select as open lists; the real dropdown is the browser's own, decision 16); `filter-cap-700` and `filter-cap-390` (the location filter against the Set select, 300px and 220px).

## Deviations from the plan

- **Spec 1.1.0 (decision 19).** The Phase 5 header guard found that the app's own header with five links overflows from 640px. The maintainer ruled option A; AC-1.3 was rewritten, AC-1.5 and AC-1.6 added and a fourth CSS block (the logo swap) added. Two calls inside the ruling, for the visual review: the swap applies only while the nav holds five or more links (`:has(.c-appbar__nav > :nth-child(5))`), and it ends at 720px (the measured 695px plus 25px).
- Phase 3: a stray blank line in the plan's snippet was left out (RuboCop).
- Phase 4: the `layout` helper's single-stat read was made safe (see the red table).
- FR-4 puts `font-size: inherit` and `font-family: inherit` "on the options"; the CSS puts them on the `optgroup` (the plan's round-1 fix), because Firefox's own stylesheet gives the optgroup a system font which the options inside it would inherit. The options keep the select's font and AC-4.3's example proves it; no `font` shorthand is used.

## Observations

- The README's Components list still names `c-split` among the card-page parts; no page uses it since "In decks" went full width. The class stays in `components.css`, so the list is still true; a later cleanup may drop it.
- The Decks tab and link in the system examples are cloned from Collection's in the page; the real ones arrive with #49, whose own examples will measure them.

## Implementation review

SPEC-ALIGNED WITH MINOR FINDINGS

Read-only Opus review (sdd-review Mode B) of `git diff origin/main...HEAD` against spec 1.1.0, on 2026-11-10: nothing blocking or major; four minor findings and five nits, all stale or inconsistent wording, none a functional defect. Verified sound: the only `app/` changes are `additions.css` and the one view class; the four CSS blocks (headings, specificity, no colour literal, no `font` shorthand, no JavaScript) and the guard spec's block counts by hand; the 16 system examples and the tokens spec are not vacuous (selectors match what the app renders, the controls can fail); every quotation and line number in this record; decision 19 consistent across spec, plan, README, `AppHeader.md`, the CSS comment and the previews; the six previews; the index rows and Superseded-by cells; no shipped spec edited; the Files table matches the diff.

| # | Severity | Finding | Disposition |
|---|----------|---------|-------------|
| 1 | minor | `AppHeader.md` still said "the wordmark shows on wide screens, the mark alone on phones" | fixed (the bullet now names the 640px to 719px stand-in) |
| 2 | minor | `SingleStat.md` said "switch back to the plain `c-stats` grid" beside the new `c-stats--three` bullet | fixed ("use `c-stats--three` for three and the plain `c-stats` grid for four") |
| 3 | minor | spec 057 decision 12 missing from the Sources lists of `catalog-core.md` and `collection-and-lots.md` | fixed (a Spec 057 line in each) |
| 4 | minor | `.claude/memory/` files (`spec-019-followups.md`, `design-system-owned-in-code.md`, the index line) still say "upstream" and "re-export" | fixed at session wrap, in this PR (the ownership memory reworded as settled, the spec 019 follow-ups memory deleted; AC-7.4's scope does not include `.claude/memory`) |
| 5 | nit | `font-size`/`font-family: inherit` are on the optgroup, FR-4 says on the options | recorded under Deviations |
| 6 | nit | `ManaCost.md` said "data colours" twice | fixed |
| 7 | nit | the unowned-tile comment in `additions.css` was left with a short line | fixed (rewrapped) |
| 8 | nit | the In decks and Format legality sections in `ItemPage.html`/`ItemPagePhone.html` keep the two-space indent of the removed `c-split`; the two previews are byte-identical | left as is (harmless) |
| 9 | nit | AC-4.2's "unaffected" wording: the option rule styles every option; the example checks that no label style leaks onto an ungrouped option | left as is (the spec is approved; the example proves what matters, and the plan's honest note says so) |

## Distillation

At session wrap (`distill-feature`, 2026-11-10): the rules of this spec live in `docs/design-system/` (the design system is its own reference, as for spec 004's design-system part); `catalog-core.md` and `collection-and-lots.md` carry decision 12's wording, a Spec 057 line in their Sources and a Distillation log row ("spec 057's pull request", to be named once it merges); `docs/architecture/README.md` lists the spec in both rows and in the design-system note; the specs index row reads Frozen and its Plan "retirement owed"; the spec's header carries its frozen line. The `.claude/memory/` files the review flagged were fixed (the ownership memory reworded, the spec 019 follow-ups memory deleted, since PR #66 merged on 2026-10-12), and a lesson was written (`docs/lessons/2026-11-10-measure-the-apps-header-not-the-preview.md`).
