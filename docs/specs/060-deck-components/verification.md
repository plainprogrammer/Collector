# Verification: spec 060, design system deck components and previews

**Spec:** [spec.md](spec.md) 1.0.4 | **Plan:** [plan.md](plan.md) | **Issue:** [#249](https://github.com/plainprogrammer/Collector/issues/249)
**Recorded:** 2026-11-10, on branch `060-deck-components` after merging `origin/main` (`e4986ee8`; main has since moved to `f8b56bba`, merged again at the push).

## Browser criteria (RSpec, headless Firefox)

`script/worktree/with_mise bin/rspec spec/system/design_system_deck_components_spec.rb spec/design_system_files_spec.rb`: **52 + 7 examples, 0 failures** (the guard spec's count is unchanged, "spec 019" and "spec 021" once each). RuboCop on the new spec: no offenses, no `.rubocop.yml` change (a `type: :system` spec is not checked by `RSpec/DescribeClass`, as the plan review found). The full `bin/ci` run is recorded in the pull request (one run, with a CI slot).

| Describe (in `spec/system/design_system_deck_components_spec.rb`) | Criteria |
|---|---|
| ProxyTag | AC-1.2, AC-1.3 |
| DeckShape panel and curve | AC-2.2, AC-2.3, AC-2.4 (with a 150px control) |
| Card types; the mana bar | AC-2.5, AC-2.6, AC-2.7 |
| The deck page: layout, the panel's two copies, zone tables, head, legality marker (both copies), empty zone, shared columns, no panel | AC-3.2 to AC-3.9, AC-3.11, AC-3.12, and the cost and name examples of spec 1.0.1 and 1.0.2 |
| The Decks list and the New deck page | AC-4.2 to AC-4.5 (with the control: the head without `.c-decks` is hidden at 360px) |
| AddToDeck and UseMyCopy | AC-5.2, AC-5.3, AC-6.2 to AC-6.4, and the mono and nowrap example of commit `8faea817`; the four-symbol cost on one line at 360px and in a 390px frame, and the open details copy's corner radii (final visual review) |

### Red runs (test first), as the implementers reported them

| Phase | Red | Reason |
|-------|-----|--------|
| 1 (ProxyTag) | AC-1.2 light and dark | unstyled: `border-top-style` none, height auto, radius 0. AC-1.3 (the text) passed on arrival: it reads the markup |
| 2 (curve) | AC-2.2, AC-2.3 light and dark, the 150px control | every part 0px high, border none; owned background transparent, proxy `background-image` none; the control reported an unstyled panel as fitting. AC-2.4 at 320px and 313px passed on arrival (an unstyled block fits), meaningful now because the control can fail |
| 3 (types, bar) | AC-2.5, AC-2.6, AC-2.7 | counts 167.6 vs 158.9; segments `[214, 214]` against `[186, 67]`, no borders or fills; narrow spans not hidden. A harness error (a braceless hash read as keywords) was fixed to see the real red |
| 4 (deck page) | AC-3.2 to 3.7, 3.9, 3.11, 3.12, the eight-symbol cost and the 640px name | not two columns, details copy displayed at 700px, aside displayed at 639px; group row sticky; the wrapper scrolled with the worst-case row; the eight-symbol `.c-cost` stayed 22px; counts' top 98 against a title bottom of 118; three distinct left edges at 900px and right edges spread 301, 250 and 250px at 360px. Passed on arrival, each beside a failing assertion: the Owned/Proxy fold, AC-3.8 (the existing `c-legal` style), the one-line head at 700px, AC-3.12 at 700px, the six-symbol cost on one line (22 × 142px already) |
| 5 (Decks list) | AC-4.4 at 360px | `.c-pagehead__actions` was `display:none`. Eight examples passed on arrival (Batch B's rules and the export's cover them); the control expects `display:none` without `.c-decks` |
| 6 (pick list) | AC-5.2, AC-5.3, AC-6.2 | page overflowed in the 360px frame; the focused radio's row had `outline-style: none`; lots had no border or ground and a field of 451.75px. AC-6.3 and AC-6.4 passed on arrival (the export's `c-input:focus-within`; attributes in the markup) |
| Fix F (marker under the name) | AC-3.8 at 700px and 360px | one marker at every width, in neither place the spec describes |
| Fix G (`8faea817`) | the mono and nowrap example | `.is-data` spans were sans and `white-space: normal` in the pick label and radio label; the page-head line was already mono and only lacked `nowrap` |

### Measurements recorded

- A mana pip is 22px (`.c-mana` is 20px with a 1px border; the export sets no `box-sizing`), not 20px: six symbols are 6 × 22 + 5 × 2 = 142px and the cell pads 12px a side, so Cost needs 166px. The plan review found this before any code; spec 1.0.1 made Cost 11rem (176px) and the Card column keeps 128px at a 640px table container (fixed columns 176 + 80 + 112 + 80 + 64 = 512px).
- Six-symbol cost at a 640px container: `.c-cost` is 22px high and 142px wide inside its cell, and the cell does not scroll. Eight symbols: it wraps to 46px high, 152px wide.
- A 60-character name at 640px: the name link's right edge is 155.05px, the Cost cell's left edge 168px.
- AC-3.11 at 360px (auto layout): the right edges of Cost, Total and the menu are 262, 314 and 360px, identical in the three tables; Total is 52px and the menu 46px in all of them. The control works: without `width:1%` on Total, its width spread is 46.1px and the example fails.
- Panel widths: 320px side by side; 313px stacked in a 360px frame with the classic scrollbar (360 − 15 − 32); 279px inside its border and padding.

## Document criteria (read against the text)

| AC | Where, and what it says | Verdict |
|----|-------------------------|---------|
| 1.1 | `ProxyTag.md`: "The tag reads without colour: the word and the dashed outline carry it (spec 060 decision 5)"; 20px, `radius-sm`, 1px dashed `ink-muted`, `ink` text; the places it is used; "A row with no proxies shows a muted dash … and no tag"; "A proxy never counts as owned"; the card page's In decks table keeps its plain count | met |
| 2.1 | `DeckShape.md`: the three parts in order; "What the panel is given" (seven `[owned, proxy]` pairs, types, W/U/B/R/G counts, the average, the scope line; Main and Commander only; `mtg_cards.mana_value` of spec 058 "Spec 060 builds nothing that reads it"; a part of zero left out; lands not in the curve); `role="img"` and the `aria-label` each chart carries; no `brand`, no status colour | met |
| 2.8 | README Charts rule: "a hatched `line-strong` fill (45°, 1.5px lines every 5px, as `DeckShape` draws it)"; `ManaCost.md`: "The mana bar of `DeckShape` is where the Charts rule uses the `mana-*` fills (spec 060)" | met |
| 3.1 | `DeckPage.md`: markup (head, `c-deck` with the `details` copy, the `aside` copy and the zones), columns and their fixed widths (decision 25), group rows (the extension supplies the groups), the legality marker, the zone head and the page head, the empty zone, the page with no panel, what each width does; "The shell's rules below name no format and no game" and the sample is a Magic deck, said so | met |
| 3.10 | `DeckPage.md` "The row menu": `TableActions`, trigger "Actions for <card> <set · number>"; a row with proxies lists "Use my copy", "Add a new copy", "Change proxy count", then after a `c-menu__sep` "Remove proxy" (`c-menu__item--danger`) | met |
| 4.1 | `DecksIndex.md`: the Decks page and the New deck page markup; columns; "Cards counts every zone"; the Proxy cell; the phone fold; the empty state "No decks yet. Add a deck to start building one."; the Decks page lists decks only; "New deck stays visible on a phone (spec 060 decision 24)"; the New deck page and its refusals with spec 029's sentences | met |
| 5.1 | `AddToDeck.md`: the `ChoicePage` variant; the select's "Deck › Zone" options under a Decks group; "My copies" only when copies are free and its sentence; the proxy option; nothing chosen with two options, `required` radios, chosen with one; "What #255 decides"; Cancel returns to the card page; the no-deck sentence and link | met |
| 6.1 | `UseMyCopy.md`: markup; the lot row's text and its field named by it; `min` 0 and `max` the free count; every field 0 at first; the sum from 1 to the row's proxies; groups, a group with no lot left out; the empty state; the errors "Enter a number from 1 to N." and "Enter a number from 0 to M." | met |
| 7.1 | README: `DeckShape` and `ProxyTag` in "Current set", the screens in "Full screens", no `c-split`, and the "App additions (spec 060, in `collector/additions.css`)" line naming `c-proxy`, `c-shape`, `c-curve`, `c-types`, `c-manabar`, `c-manacap`, `c-deck`, `c-shapefold`, `c-zone`, `c-decks`, `c-pick` | met |
| 7.2 | The twelve previews' stylesheet links, read: `preview-fonts.css`, `tokens.css`, `components.css`, `additions.css` in that order in every file | met |
| 7.4 | `ItemPage.html` and `ItemPagePhone.html`: the In decks and Format legality sections lost the two leading spaces (their lines now match the sibling sections), and `cmp` says the two files are identical | met |
| 7.6 | `ChoicePage.md` ("`AddToDeck` is a variant: with one option, the option is chosen"), `ManaCost.md`, `TableActions.md` ("Used by … `DeckPage`'s zone tables"), `AppHeader.md` ("except the Decks page's New deck, spec 060 decision 24") | met |

## Previews (AC-7.2, AC-7.3)

Each of the twelve previews was opened in headless Firefox at 1280px and in a 390px same-origin frame, in light and dark, and read: `document.documentElement.scrollWidth <= window.innerWidth` at 390px in every file and theme; at 1280px equal for five files, and 1265 against 1280 for `DeckShape` and `DeckPage`, which is the 15px classic scrollbar of a tall page. Every stylesheet, font and logo URL returned 200. Headless Selenium could not read the browser console, so "no console error" was not read directly: it is evidenced by those loads and by the renders, and said so plainly here. The new previews are drawn at stroke 1.5 from the start.

## Icon strokes (AC-7.5) and the 12px marks

Decision 16 (ruled A): every `stroke-width` attribute in the existing previews is 1.5 (15 of 17 files changed; `Cover.html` and `ManaCost.html` had none to change). The maintainer asked to be told if the 12px marks were too thin at 1.5. They were checked before and after at 1x and 2x, light and dark (the legality check and cross and the badge check are hairlines at 1x, lighter than the bold word beside them, still legible; the filled foil star and the warning triangles read fine). The maintainer ruled on 2026-11-10 to keep 1.5 everywhere, matching the app (whose icon partials are 1.5), and asked for an issue for the app's own 12px icons: [#294](https://github.com/plainprogrammer/Collector/issues/294). The stroke commit is `77bfbfe8`; `git grep -o 'stroke-width="[0-9.]*"' -- docs/design-system/previews` lists only `1.5` (187 hits, plus a CSS `stroke-width:1` on an empty slot in `Cover.html`, which is not an icon).

## Screenshots

In [screenshots/](screenshots/), each in light and dark: the seven pages at 1280px (`ProxyTag`, `DeckShape`, `DeckPage`, `DecksIndex`, `NewDeck`, `AddToDeck`, `UseMyCopy`) and at 390px (the five screens from their `*Phone.html` files, `ProxyTag` and `DeckShape` from their one file).

## Deviations from the plan, and spec patches

- **Spec 1.0.1** (found by the plan review before any code): a pip is 22px, so Cost is 11rem, not 10rem; pips wrap at every width; AC-3.11's narrow clause reads right edges; the `.rubocop.yml` row is dropped.
- **Spec 1.0.2** (plan review round 2): the Card name wraps at every width; Total is `width:1%` below 640px; FR-4 says the Decks table gets only the name wrap.
- **Spec 1.0.3** (found when the documents were checked against the ruling): decision 9 puts the legality marker under the name on a phone, so it is written twice, as the set is (beside the name from 640px, in the `c-table__sub` line below it); AC-3.8 says so.
- The zone builder in the spec gives every row a `TableActions` menu (not only the first proxy row), so the menu column is the same in every table.
- `.is-data` has its mono family only in tables, details and lists, so the pick list gets the rule itself (commit `8faea817`).
- The decks table is exempt from decision 25's column layout although FR-4 once pointed at it (FR-4's wording was corrected to the name wrap only).
- The export's `@media (pointer: coarse) { .c-btn { min-height:44px } }` gives the New deck button its 44px target on a touch device; headless Firefox cannot trigger it, so AC-4.4 reads the height at 36px or more and this record quotes the rule.

## Observations

- The mock-ups of 2026-11-09 were not in the repository, so deck page option B and curve option B were redrawn from the issue text, and the maintainer ruled on 17 questions from shots drawn with the real CSS (the spec's decisions).

## Implementation review

SPEC-ALIGNED WITH MINOR FINDINGS

Read-only Opus review (sdd-review Mode B) of the committed branch and the uncommitted stroke edit, against spec 1.0.3, on 2026-11-10: nothing blocking or major. Verified sound: the 49 examples map to AC-1.2/1.3, 2.2 to 2.7, 3.2 to 3.9, 3.11, 3.12, 4.2 to 4.5, 5.2, 5.3 and 6.2 to 6.4 (`blank_host` removes the Locations page's `c-locations`; each `wrap` drives the right named container; specificity of the Decks head rule, with its control); every document criterion is met in the text; decisions 1 to 17, 23 and 24 are written as ruled; the five refusal sentences match `Location::MESSAGES` and `FULL`; the eight CSS blocks use tokens only, no JavaScript, each under its own heading, after the Locations block, and cannot break `design_system_files_spec.rb`; all twelve previews link the four stylesheets in order, carry the theme script, draw at 1.5, have no `overflow` rule, and each Phone file is byte-identical to its wide file; the sample arithmetic (Main 60 = 52 + 8, curve 30 + 6 and average 2.3, types 60, symbols 44/16, head 69 = 58 + 11, Decks 379) adds up; no shipped spec or area doc is edited; no stale number.

| # | Severity | Finding | Disposition |
|---|----------|---------|-------------|
| 1 | minor | `DeckPage.md`'s sample put the Banned marker on Murktide Regent; the preview puts it on Ragavan | fixed in `d19a58c2` (the document now shows the preview's Ragavan row) |
| 2 | minor | `DecksIndex.md`'s sample rows differed from the preview's | fixed (copied from the preview) |
| 3 | minor | `DeckShape.md` said each copy's `aria-labelledby` points to a unique title, but the `details` copy has no title | fixed (the `aside` copy is labelled by its title, the `details` copy is named by its summary) |
| 4 | minor | `.c-shapefold > summary` and `.c-pick__lot .c-input` hard-coded 44px | fixed (`var(--touch-floor)`) |
| 5 | minor | the record said Phase 12 was done while uncommitted, left a pending line and claimed "no console error" | fixed (this record; Phase 12 committed in `77bfbfe8`; the console was not read and says so) |
| 6 | nit | the Decks list comment said "the same selector list" | fixed (its own rule in the zone tables' narrow container query) |
| 7 | nit | the summary's Show/Hide is `brand` while `DeckShape.md` says the panel never uses `brand` | fixed (the document says the rule is about the charts and fills; Show/Hide is an action) |
| 8 | nit | `aria-label` on a roleless `div` in `DeckShape.html` | fixed (removed) |
| 9 | nit | the spec's builder wrote "Near Mint" where the app and documents write "Near mint" | fixed |

## Distillation

At session wrap (`distill-feature`, 2026-11-10): the rules of this spec live in `docs/design-system/` (the design system is its own reference, as for specs 004's design-system part and 057): the six component documents, the README's Components list, App additions line and Charts rule, and the pointers in `ChoicePage`, `ManaCost`, `TableActions` and `AppHeader`. No area doc changes. `docs/architecture/README.md` names spec 060 in its design-system note; the specs index row reads Frozen, by the design system, with the plan's retirement owed; the spec's header carries its frozen line. Memory: `design-system-guard-and-rubocop-traps` (a wrapper div and `blank_host` for a component with no view; blocks at the end of `additions.css`), `pr-screenshots-workflow` (static previews over a local server), and a new `sdd-gate-blocks-plan-before-approval`. Lessons: `docs/lessons/2026-11-10-a-pip-is-22px-a-width-in-a-spec-comes-from-a-probe.md` and `docs/lessons/2026-11-10-reread-a-ruling-against-what-each-batch-produced.md`. Issue [#294](https://github.com/plainprogrammer/Collector/issues/294) (12px icon strokes) was filed from decision 16.

## Final visual review

The maintainer reviewed the screenshots in the pull request on 2026-11-10 and asked for three changes, each its own commit, all done:

1. **A four-symbol cost wrapped to two lines in the 390px zone table** (Cryptic Command, `1UUU`: 46px high). Cause: the auto layout may shrink the Cost cell to the width of one wrapped pip. Fix `8f6f876f` (spec 1.0.4): `min-width:94px` on `c-cost` inside a zone table (4 × 22px + 3 × 2px); the examples at a 360px container and in a 390px frame went red (46px) and then green (one pip high); the six-symbol, 60-character worst case at 360px still does not overflow. `DeckPage.md` says what still wraps: five or more symbols may take two lines in the narrow layout; six fit one line in the wide layout's 176px.
2. **No "Not legal" marker in the preview.** Sample data, not a CSS bug: the earlier mock-ups had Pyroblast and Spell Queller marked and the first preview drew only a Banned marker on Ragavan. `b45f61e8` adds the marker (both copies) to those rows in `DeckPage.html` and `DeckPagePhone.html`; the previews now show one Banned and two Not legal.
3. **The open `details` copy drew a faint bottom edge.** Cause: the bare panel's square corners and raised background painted over the details' rounded border (8px radius, 1px border). Fix `8a223a8e`: the bare panel's bottom corners take the details' inner radius (7px); the new example failed on `[0, 0]` against `[7, 7]` and a 3x crop shows a continuous border.

The affected screenshots (`DeckPage` and `DeckShape`, wide and phone, light and dark) were re-shot and replaced.

