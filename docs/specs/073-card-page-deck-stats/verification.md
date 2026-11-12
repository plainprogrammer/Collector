# Verification: Feature 073, "Free to use" and "In decks" on the Card Page

**Spec:** [spec.md](spec.md) (v0.2.5) · **Plan:** [plan.md](plan.md)

Each acceptance criterion with the example (or the document check) that proves it. A path is a spec file; a quoted name is the example's title or its `describe`. Documents are verified by reading, as `.claude/rules/testing.md` requires.

## Acceptance criteria

### Story 1: The strip says what is free

| AC | Proved by |
|---|---|
| AC-1.1 | `spec/requests/catalog/card_page_decks_spec.rb` "shows Owned, In decks and Free to use as three stats for a card in no deck" |
| AC-1.2 | same file, "counts copies in zones, Considering included, as in decks and the rest as free", "writes each number with its delimiter" (24,690 / 12,345 / 12,345 from lots of 9,999 or fewer) |
| AC-1.3 | same file, "has Free to use 0 and In decks equal to Owned when every copy is in a deck" |
| AC-1.4 | same file, "changes none of the three numbers when a proxy is added to a zone of the same deck or of another deck" (read before and after each add), "reads 0, 0 printings and in 0 decks for a card with only a proxy"; "in 1 deck" is in the first; `spec/models/catalog/card_overview_spec.rb` "never counts a proxy as owned, in a deck or free" |
| AC-1.5 | same request file, "gives the card's own numbers and agrees with Lot::FreeCopies" (the fixture's numbers are written out, `Lot::FreeCopies#total` is read beside them); `card_overview_spec.rb` "splits what is owned into in-decks and free, Considering counted as in a deck" |
| AC-1.6 | same request file, "counts nothing of another account's lots and proxies, and shows them on that account's own page" (both records built from the other account; the control signs in as that account); `spec/models/deck/card_uses_spec.rb` "reads only this account's proxies, and only of this card's printings" and, for the proxy filter in its own right, the example that reads the proxy sums of two accounts directly (shown red when `where(account_id:)` is removed: `{2=>1}` expected, `{2=>1, 6=>8}` got) |

### Story 2: The "In decks" section says where

| AC | Proved by |
|---|---|
| AC-2.1 | request file, "follows Printings and precedes Format legality, with the four headers", "makes a row per zone with a link to the deck, the format beside the name and the zone's own name" (the order is by comparison key: "apple" before "Banana") |
| AC-2.2 | request file, "sums across printings, finishes and conditions, and proxies across printings"; `card_uses_spec.rb` "makes one row per zone, summing copies …" |
| AC-2.3 | request file, "has a Considering row, and the table's Owned sums to the strip's In decks, with delimiters" (two lots of 9,999 read "19,998") |
| AC-2.4 | request file, "has a row with Owned 0 and the proxy count, as plain text, for a zone with only a proxy", "shows a muted dash in the Proxy cell for a zone with no proxy" |
| AC-2.5 | request file, "shows the format's key when the extension no longer registers it, and answers 200" |
| AC-2.6 | request file, "words the head count for copies in decks and proxies", "… for one copy, for proxies only and for neither", "does not count a deck that holds only a proxy as a deck in the head count"; `spec/helpers/decks_helper_spec.rb` (delimiters) |
| AC-2.7 | request file, "says the card is in no deck, with an Add to deck link that keeps the collection mark", "has no link in the empty state for a retired printing, and is drawn for an account with no decks" |
| AC-2.8 | request file, "counts a lot of a retired printing as it counts the others" |
| AC-2.9 | request file, "shows nothing of another account's deck, zone, lot or proxy" (the owner's name is built at run time; the control signs in as the other account) |
| AC-2.10 | request file, "shows a renamed deck's new name" |

### Story 3: Where the parts are and where they are not

| AC | Proved by |
|---|---|
| AC-3.1 | `spec/requests/catalog/visitors_spec.rb` "shows a visitor no collection part and no tenant data" (the absent list gains `#in-decks` and the words), "runs no query against lots, locations, decks or deck proxies for a visitor", and its control "reads those tables for a signed-in collector's card page"; `card_overview_spec.rb` "reads nothing for a visitor" (0 statements) |
| AC-3.2 | `spec/requests/catalog/quick_adds_spec.rb` "shows the same stats and In decks table as a plain visit when the no-script add is refused" (a lot at the cap and a lot in a zone; the 422 page's numbers equal a plain GET's) and the existing 422 example now expecting the three stats |
| AC-3.3 | `spec/requests/query_counts_spec.rb` "keeps the card page's queries independent of the number of lots, decks, zones and proxies (spec 073 AC-3.3)". The mutation of the plan's Task 5.2 (the deck preload replaced by a per-row `Deck.find_by`) made it fail with 30 against 50 statements, so it can fail. Lines 58 and 97 of that file: the example at line 58 was re-based (see Findings) and line 97 stayed green |
| AC-3.4 | request file, "does not write to lots, locations, decks or deck proxies" (a characterisation, with a control: the spy sees an insert into `lots`) |

### Story 4: From the card to the deck

| AC | Proved by |
|---|---|
| AC-4.1 | `spec/system/card_page_decks_no_script_spec.rb` "follows the deck's name from the card page to that deck's page, which lists the card" (`rack_test` asserted, `before { driven_by :rack_test }` above the `let!` that signs in; the deck page has neither `#in-decks` nor the text "In decks"); the GIFs `card-to-deck-desktop.gif`, `card-to-deck-phone.gif` show it in a browser |

### Story 5: The parts follow the design system on any device

| AC | Proved by |
|---|---|
| AC-5.1 | `spec/system/card_page_decks_spec.rb` "is three across with nothing clipped at 360px / 390px in the light / dark theme" (Owned 24,690, In decks 12,345, Free 12,345) |
| AC-5.2 | same file, "folds Zone and the format under the name, keeps Owned and Proxy and does not scroll sideways at 360 / 390 / 640 / 1024px in both themes" and "shows all four columns, the format beside the name and no overflow at 1280px in both themes" (60-character deck name). Measured section widths: 297px at 360, 327px at 390, 545px at 640, 597px at 1024, 853px at 1280. At 1280 the first run failed on "Your copies"' Location cell (547px, nowrap, in a 982px table in a 1265px viewport; page scrollWidth 1354) and not on "In decks"; the markup fix of Task 6.2 (`c-table__place`, placed lots only) took the cell to 379px and the page to 1265px |
| AC-5.3 | request file, "uses only c- and is- classes and no inline style, and marks the Owned cell numeric"; system file, "carries the wrap rule, scoped to the section and written with no token"; the wrap rule's cause was shown by measurement: without it the 60-character name stays on one 18px line and the page scrolls sideways at 360px, with it the name takes 54px (three lines) |
| AC-5.4 | The controls the change adds, each with its rule: the deck name link in the table is a text link in a cell, as the collection table's name link is, exempt as spec 062's table links are; the empty state's "Add to deck" is a link inside a sentence, exempt as "Add a copy" is in "Your copies"; no button, select or field is added, so no 44px floor rule is needed. Headless Firefox has a fine pointer and can't emulate a coarse one (spec 068's lesson), so nothing here is measured coarse |
| AC-5.5 | system file, "does not cut the head count and puts it under the title at 360 / 390px in both themes". Found by the screenshot walkthrough (the count read "… · 1 pr…" at 360px); red first (scrollWidth 218 against clientWidth 206 at 360px, and beside the title at both widths), green with the rule. `screenshots/07-headcount-*` |
| AC-5.6 | system file, "keeps the Add to deck link on one line at 390px" (the link had two line boxes before the rule). `screenshots/08-empty-link-*` |

### Story 6: The documents say it (verified by reading)

| AC | Check |
|---|---|
| AC-6.1 | Read `docs/design-system/components/ItemPage.md` (Stats, In decks, the head count, the empty state, the fold width, the wrap rule, "Your copies"' place class), `ItemPagePhone.md` (the fold and the folded cell's order), `previews/ItemPage.html` and `ItemPagePhone.html` (only the count text changed: "4 copies in 2 decks · 1 proxy"), `SingleStat.md` and the README's "What is live" line. The section adds three rules to `additions.css` (the name wrap, the head count on its own line below 640px, the empty-state link on one line) and `ItemPage.md` and `ItemPagePhone.md` say so; "Your copies" takes spec 048's `c-table__place` class and `c-table__place-name` span, also stated. `spec/design_system_files_spec.rb` passes |
| AC-6.2 | Read `collection-and-lots.md` (the card-page paragraphs, line 19's scope bullet, the Considering line, the open-issues line, Sources and the issues line), `catalog-core.md` (the card page's order, the "no collection part reaches a visitor" line, the open-issues lines), `CLAUDE.md`'s deck sentence and `docs/roadmap.md` item 15. Each new statement was re-read against `Catalog::CardOverview`, `Deck::CardUses`, `DecksHelper#card_decks_count_line`, the two partials and the CSS block (the card-page paragraph names all three rules, with their sources: decision 10, AC-5.5, AC-5.6) |
| AC-6.3 | Read `docs/specs/README.md`: the 073 row, the pointers in the 004 and 071 rows' last cell. The three examples that were changed for the new parts are listed under "Findings" |

## How the supersession list was built

From a grep, not from memory (the lesson of 2026-11-11): `git grep -n -E "Free to use|In decks|c-stats--single|\.c-stat\b|<dt>Owned|#50|Owned stat|one stat" -- spec docs app ':!.kamal/secrets'`, plus a grep for `Add to deck` in `spec/` for the ambiguity the empty state's link makes. Existing examples changed: `spec/requests/catalog/entries_show_spec.rb` (the spec 071 AC-1.4 example rewritten; the order example), `quick_adds_spec.rb` (the stats), `query_counts_spec.rb` (the zone example no longer includes the card page; the example at line 58), `spec/system/deck_additions_spec.rb` (two clicks scoped to the head), `spec/requests/zone_place_label_spec.rb` (line 27). Seen and left alone: `deck_additions_spec.rb:228,312` and `visitors_spec.rb:348` read the first `.c-stat dd`, which stays Owned; `spec/system/design_system_deck_rules_spec.rb` builds its own probe markup.

## Findings during implementation

1. `spec/deck_core_spec.rb`'s count went red at the commit that added `Deck::CardUses` (its glob covers `app/models/deck/*.rb`); the plan's Task 5.1 had counted it in one place late. Fixed in a commit of its own (plan Task 5.0).
2. `query_counts_spec.rb:58` (spec 032 NFR, the card page's queries against the number of placed lots) went red (19 against 20), which the plan had said would stay green. Cause: the card page now preloads the lots' places twice (`CardOverview#lots` and `Lot::FreeCopies#lots`); with one placed lot both issue the same statement and the second is a query-cache hit that the counter skips. The baseline now has two lots the two lists order differently (one unpriced: the overview sorts it first and the `lot_key` index last). This leans on SQLite reading `lots` in `lot_key` index order, so it could need a new baseline if that plan changes; the example's comment says so.
3. The AC-3.3 example hit the same trap with one deck (the two parent preloads issue the same statement), fixed in the example by a deck that holds only a proxy, so the two id sets differ in the small run too.
4. The second link named "Add to deck" (the empty state's) made two no-script examples in `spec/system/deck_additions_spec.rb` ambiguous, and the new Zone column made `zone_place_label_spec.rb`'s "no Main outside a label" check find "Main"; both were found in plan review and fixed in the commit that caused them.
5. The screenshot walkthrough found the two defects of AC-5.5 and AC-5.6, fixed test-first (spec 0.2.4).
6. Seen, not ours: the Printings head count ("3 known …") is cut by the same ellipsis on a phone; it is the existing design, not changed here.

## Screenshots

Factory data, placeholder card images, headless Firefox. Desktop is a 1280px window, phone is a 390px (or 360px) frame; both themes; the "before" shots are emulated by injecting the old rule as a style (or removing the class), not built from `main`. In `screenshots/`:

- `01-no-decks-*`: three free copies, the empty state. `02-some-in-decks-*`: 7 copies, 3 in two decks (Considering among them), 4 free, two proxies. `03-all-in-decks-*`: every copy in decks, Free to use 0. `04-proxies-only-*`: no copy, a proxy in a zone. Each as `-desktop-light`, `-desktop-dark`, `-phone-light`, `-phone-dark` (a 390px frame, whose page is 375px wide beside the pinned classic scrollbar).
- `05-wrap-before-phone360-*`, `05-wrap-after-phone360-*`: a 60-character deck name, with the wrap rule neutralised and as built.
- `06-copies-desktop1280-before-*`, `06-copies-desktop1280-after-*`: the same deck at 1280px, with "Your copies"' Location cell as it was and as built.
- `07-headcount-before-phone360-*`, `07-headcount-after-phone360-*`: the head count cut, then whole under the title (crops of the section).
- `08-empty-link-before-phone390-*`, `08-empty-link-after-phone390-*`: the link broken across lines, then whole (crops).
- `card-to-deck-desktop.gif`, `card-to-deck-phone.gif`: the card page (state 2), a scroll to "In decks", a click on "Izzet Tempo", the deck page.

## Implementation review

SPEC-ALIGNED

Mode B (`sdd-review`), a read-only Opus reviewer, two rounds. Round 1 (commit range `b102c2d3..HEAD` at the time) returned NOT SPEC-ALIGNED with one major finding: after the screenshot walkthrough's CSS fix (`2e64c8c5`, two more rules) `ItemPage.md` still said "that one rule is the only CSS the section adds", `ItemPagePhone.md` and the card-page paragraph of `collection-and-lots.md` named one rule, and two rows of this file overclaimed (AC-6.1, AC-6.2). Minors: the `Deck::CardUses` class comment said "none for a card in no deck" (the proxies are read first: it is one statement); the proxy tenancy example could not fail on the `account_id` filter; the index row still read "plan: none yet"; AC-5.3's wording said "the one new rule"; the span on an unplaced lot's cell (accepted: the class is for placed lots, the span for every lot, as decision 10 now says). All fixed or accepted in `4a92f22a`, `4cf8834f`, `d586def2` and `851bfd88`. Round 2 returned SPEC-ALIGNED, with one wording nit (AC-5.3's "or by the card page's own head", fixed in `851bfd88`).

Checked by the reviewer and found sound: every AC has an example that can fail, with run-time controls for each absence (the other account's own page, the collector's table reads, the write spy, a counted-proxy cell); tenancy (every read through the account, a visitor reads nothing, deck names escaped, no inline style or `html_safe`); the complement of `Lot::FreeCopies#lots` as "in decks" (retired printings and other printings included, no location-kind test); the row order; `deck_count`; no migration, schema or export change; no shipped spec of another number edited; the screenshots cover every required state, both themes, both device classes, the before and after of each CSS or markup change and the two GIFs.

## Test runs

Filled in from the final full `bin/ci` run (below).
