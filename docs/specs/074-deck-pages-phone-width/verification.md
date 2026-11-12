# Verification: spec 074 (Deck pages at phone width, #326)

Spec v0.6.1. Implementation commits: `4b7327c3` (the examples), `d5e124f7` (the CSS block), `f5e1e407` (the controller), `1662035e` (the zone menu column floor), `cae54e5f` (previews and fixture), `5da4c143` and `80367f2e` (documents, memory line, index). The implementation review is at the end.

## Evidence for the spec (2026-11-11)

All measured in headless Firefox through throwaway system specs (never committed), with factory data, in the suite's 1400×1400 window (a 1315px viewport) unless stated.

1. **Row menu behind the tab bar (Problem 1).** Deck page in a 375px frame (a 360px viewport with the Mac's 15px classic scrollbar), 640px tall, first proxy row's menu opened by a click: the tab bar at 573px to 640px (67px high); the menu items at 524 to 560, 560 to 596, 596 to 632 and 641 to 677px. Scroll position 0.
2. **The page can't scroll far enough at its end (review finding B1).** The same page with the proxy on the last zone's last row and proxies of two finishes (8 items), scrolled to the end, a `toggle` listener calling `scrollIntoView({block: "nearest"})` and `scroll-margin-bottom: 75px`: without a room box the last items sat at 563px to 635px (behind the bar); with `.c-menu[open] > .c-menu__list::after` (absolute, `top: 100%`, 75px tall) the page scrolled 74px further (maximum scroll 514px to 588px) and the last item ended at 561px. With one finish (4 items) the list fit either way (last item at 557px), so the case needs a long menu or a short footer.
3. **The missing tab bar (Problem 2).** Add to deck with no decks, a 390px frame: the bar is `display: flex`, `position: fixed`, its bottom edge on the frame's bottom edge at frame heights 700px, 815px and 1315px. A frame of 1700px in the 1315px viewport gave a 1315px element screenshot with no bar. An 815px frame in a 1280×800 window (viewport 715px) gave an 815px screenshot with no bar (the picture of spec 071's shots 04 and 05); in a 1280×900 window (viewport 815px) the same shot has the bar. The window spec 071's throwaway used can't be read back, so the cause of its shots is reproduced, not confirmed.
4. **The audit of `Menu` uses.** `git grep -n 'c-menu' -- app/views ':!.kamal/secrets' | grep -v 'c-menu__'` lists the ten menus of the spec's table (`admin/jobs/index`, `admin/users/index`, `catalog/entries/_copies`, `catalog/entries/show`, `collections/_bulk`, `collections/_filter_bar`, `collections/_table`, `decks/_proxy_menu`, `decks/show`, `layouts/_appbar`); `decks/_zone` matches only the column class `c-zone__c-menu`. The Locations views have no `c-menu`.
5. **Supersession search.** `git grep -n -i -E 'menu.*(scroll|clear|below the viewport|opens (down|up))|(open|opens).*menu.*(bottom|upward|down)' -- 'docs/specs/*/spec.md' docs/architecture docs/design-system spec ':!.kamal/secrets'` found no criterion about a menu's placement or scrolling (the hits are about sideways scrolling and the account menu's width). Spec 070's `verification.md` line 79 notes the menu problem as seen, not as a rule. Result: nothing is superseded; spec 060 AC-3.11 is restored (item 7).
6. **Existing examples that open a menu.** `git grep -n 'summary' -- spec/system`, filtered by hand: the narrow-frame ones are `narrow_admin_pages_spec.rb:36`, `narrow_bulk_pages_spec.rb:18` and `:30`, `bulk_mode_spec.rb:122`, `bulk_move_spec.rb:76`; the 1400px-window ones are `bulk_mode_spec.rb:85` (Escape on the account menu, line 91), `admin_jobs_spec.rb:56`, `deck_proxy_replacements_spec.rb:26` and `:40`, `lot_moves_spec.rb:13`.
7. **The zones' columns misalign (Problem 4).** The real page at a true 360px viewport, Main with a proxy row, Sideboard with an owned card: menu column 46px against 16px; Cost's right edge 238px against 268px, Total's 290px against 320px. The design-system example "lines up the right edges of Cost, Total and the menu in every zone at 360px" failed by 30px once its fixture drew the empty cell the page draws.
8. **The floor's cost on the worst case (Decision 6).** Worst-case fixture of `deck_page_spec.rb` (a 60-character name, a six-symbol cost, 123 owned, 1,234 proxies) at a true 360px viewport: without the floor Main's table is 313px in a 312px container (1px spill), the Card column 102px in Main and 134px in Sideboard, menu columns 46px and 16px; with the floor 331px in 312px (19px spill), Card 102px in Main (its minimum, the unbroken "Proxy 1,234" tag) and 86px in Sideboard (48px narrower), menu columns 64px and 64px. The document never scrolls sideways (360 of 360 either way). A coarse pointer's trigger already makes a 58px column today (40px minimum width, border, padding), so there the worst case spills about 13px today and 19px with the floor (+6px). Ruled by the coordinator (Option A, 2026-11-11); wrapping the proxy tag is Out of Scope.
9. **Closing a menu at a page's end.** The deck page's last row (two finishes), scrolled to the end, in a 640px frame: before the open, scroll 512px and page height 1152px; open, scroll 661.25px and height 1301px (the 8-item list and the room box); closed again, scroll 512px and height 1152px, so the page returns exactly where it was (it moves back by 149px with the menu's overflow). Accepted by the spec's Error Scenarios row.

## Spec and plan reviews

- Spec, round 1 (Opus, read-only), REVISE: 1 blocking, 4 major, 9 minor, 3 nit; all taken in v0.2.0. Round 2, REVISE: 0 blocking, 5 major, 6 minor, 4 nit; all taken in v0.3.0; no round 3 (the coordinator accepted the fixes at Gate A).
- Plan, round 1 (Opus, read-only), REVISE: 1 blocking (RuboCop's RSpec cops), 2 major, minors; round 2, REVISE: 2 major (AC-1.12's helper threw once the bar was removed; the outside-click example's heading ended under the bar after the new scroll), 3 minor/nit; all taken; the coordinator accepted Task 1's red run and Task 7's mutation checks as the third read.
- Spec 0.5.0 (AC-1.13, from the coordinator at Gate B) and 0.6.0 (AC-1.14 and AC-1.15, ruled by the coordinator, review of the change only: REVISE, 0 blocking, 1 major (the worst-case overflow), 5 minor, 2 nit; all taken in 0.6.1).
- Left as it is on purpose: the export's `components.css:127` comment ("Stimulus adds outside-click and arrow keys") stays wrong; `components.css` is the design export's file and this spec leaves it unchanged. `Menu.md` is corrected and says so.

## Acceptance criteria

| AC | Evidence |
|---|---|
| 1.1, 1.2, 1.3 (five pages), 1.4, 1.5 (instant and smooth), 1.6 (phone and 1280px), 1.7 (Escape, outside click, hit-test), 1.8, 1.9, 1.10, 1.11 (five pages and the can-fail check), 1.12, 1.13, 1.14, 1.15 (the existing worst-case examples and the committed one) | `spec/system/menu_tab_bar_clearance_spec.rb`, 29 examples |
| 2.1 | the previews carry an empty `td.c-table__actions` on 12 rows each and no "Move copies" (`git grep -n 'Move copies' -- docs/design-system/previews ':!.kamal/secrets'` finds nothing in the two deck previews); screenshots `08-*` |
| 2.2, 3.2 | read: `DeckPage.md`, `Menu.md`, `TableActions.md`, `TabBar.md`, the README's Navigation section |
| 3.1 | the guard in the spec file (fourteen pages, 360px, passes before and after) |
| 3.3 | read: `.claude/memory/pr-screenshots-workflow.md` |
| 3.4 | read: `docs/specs/README.md`, row 074 |

### Red run (Task 1, before the CSS and JS, 27 examples)

Red: AC-1.1 (last item 122px behind the bar), AC-1.3 on all five pages (card page -86px, collection -50, deck page -122, users list -50, jobs list -50), AC-1.5 both, AC-1.6 on a phone (margins `0px`), AC-1.8 (-137.25px), AC-1.9 (list top 465 against 65), AC-1.13 (the menu still open on restore, scroll 556.75 against 244.75). Green: AC-1.2, AC-1.4, AC-1.6 at 1280px, AC-1.7 (three examples), AC-1.10, AC-1.11 (five pages), AC-1.12, the scrolling-ancestor check and AC-3.1. AC-1.14 (added in Task 3b): red before the floor (the smallest menu column 16px, the Cost, Total and menu edges spread by 30px), green after.

### Mutation checks (Task 7, by hand, never committed, each restored)

| Mutation | Examples | Result |
|---|---|---|
| `reveal` always scrolls (`block: "end"`) | AC-1.2, AC-1.10 | both fail (scroll 442.75 against 690.75; 0 against 300) |
| `reveal` returns at once | AC-1.1, AC-1.8 | both fail (-122px, -137.25px) |
| room box without `pointer-events: none` | the hit-test example | fails (the point belongs to the list) |
| room box removed | AC-1.8 | fails (-62px) |
| `scroll-margin-top` removed | AC-1.9 | fails (list top 42 against 65) |
| `min-width: 4rem` floor removed | AC-1.14; the design-system "lines up the right edges" example | both fail (30px spreads) |
| `turbo:before-cache` listener removed | AC-1.13 | fails (one menu open after Back) |
| `render "layouts/tabbar"` removed from `decks/show` | AC-3.1 | fails naming "Deck" |

### Runs

- `spec/system/menu_tab_bar_clearance_spec.rb` alone: 29 examples, 0 failures.
- `menu_tab_bar_clearance_spec`, `design_system_files_spec`, `design_system_deck_components_spec`, `deck_page_spec`, `deck_proxies_spec`, `deck_shape_panel_spec`: 144 examples, 0 failures (AC-1.15: the worst-case examples pass).
- The existing examples that open a menu (`bulk_mode`, `narrow_admin_pages`, `narrow_bulk_pages`, `bulk_move`, `admin_jobs`, `deck_proxy_replacements`, `lot_moves`): 45 examples, 0 failures.
- `bin/rubocop` on the changed Ruby files: no offenses. `bin/yard doc`: no warnings. `bin/brakeman`: 0 warnings (4 ignored, as before). The full `bin/ci` runs at the push.

### Deviations from the plan

- Task 1: the deck page's `ready` selector is `.c-zone:first-child table` (Main's), because Considering has a table too and `find` wants one match.
- Task 3b: the plan's `apply_coarse_rules` joined with `"\n"` inside a Ruby heredoc, which put a real line break in a JS string; the committed line is `.join("\\n")`.
- The Gate A, Gate B and scope rulings are in the spec's changelog (0.4.0, 0.5.0, 0.6.0, 0.6.1).

## Screenshots and a GIF

[`screenshots/`](screenshots/): 24 JPEGs and 1 GIF from factory data and placeholder card images, a 360px viewport in a narrow frame (the frame is 360px plus the measured scrollbar, no taller than the window's viewport, so the tab bar is in every phone shot), light and dark. "Before" is emulated, not built from `main`: the page with the new margins and the room box switched off and the controller's scroll stubbed out (and, for the column shots, `min-width: 0` on the menu column). Headless Firefox has a fine pointer, so the coarse-pointer 44px rows and the coarse trigger are not shown.

- `01-row-menu-near-bottom-{before,after}-360-{light,dark}`: Proxy Card 4's row menu opened with its trigger 40px above the bar. Before, "Add a new copy", "Change proxy count" and "Remove proxy" are behind the bar; after, the page has scrolled and all four items end 8px above it.
- `02-last-row-eight-items-{before,after}-360-{light,dark}`: the last row of the page with proxies of two finishes (eight items), page scrolled to its end. Before, the last four of the eight items (and the separator) are behind or below the bar; after, all eight are clear.
- `03-card-page-copies-menu-after-360-{light,dark}` and `04-collection-table-menu-after-360-{light,dark}`: the card page's copies table and the collection table's row menus, opened near the bottom.
- `05-zone-columns-{before,after}-360-{light,dark}`: Main with a proxy row, Sideboard and Considering with owned cards; before, Cost and Total sit 30px further right in Sideboard; after, the three zones line up.
- `06-worst-case-{before,after}-360-light`: the 60-character unbroken name, six-symbol cost, 1,234 proxies; after, the table spills 19px past its container (visible in the Creatures bar and the right edge), no sideways scroll.
- `07-deck-page-menu-1280-{light,dark}`: a row menu open on the deck page at 1280px, unchanged.
- `08-preview-{DeckPage-1280,DeckPagePhone-390}-{light,dark}`: the two previews, rows with no proxy with an empty menu cell, the open menu on Murktide Regent unchanged.
- `menu-clears-tab-bar-360-light.gif`: the menu opening near the bottom (the first frames after the click show the list behind the bar before the page scrolls it clear).

Every image was looked at. The tab bar is in every phone shot. Nothing needed fixing; the worst case's 19px spill is the recorded cost of Decision 6.

## Implementation review

SPEC-ALIGNED WITH MINOR FINDINGS

Mode B, read-only, on Opus, round 1, over the branch's whole diff, the spec (v0.6.1), the plan, this file, every example of `menu_tab_bar_clearance_spec.rb` and nine of the screenshots. No blocking or major findings; FR-5 holds (no view, helper, model, Rails controller, migration, export or `components.css` change; specs 060 and 068 not edited); area docs: no change owed (`collection-and-lots.md:133`, "a row with no proxy has an empty menu cell", is still true). Findings and what was done:

| # | Finding | Done |
|---|---|---|
| F1 (minor) | AC-1.15's example could pass without the coarse rules applying (the fine-pointer spill, 19px, is within the 20px limit) | `b7942d57`: the example asserts the zone trigger is at least 40px wide after `apply_coarse_rules` |
| F2 (minor) | AC-3.1's example didn't check which tab is current or which page rendered | `b7942d57`: it asserts the page's path (no redirect) and the current tab's label (Decks, or Search or Collection on Add to deck) |
| F3 (minor) | README line 74 still said Stimulus adds "arrow keys" | `847e3b95`: dropped, and the line now names the phone scroll |
| F4 (minor) | No "App additions (spec 074)" entry in the README | `847e3b95`: added, naming both blocks |
| F5 (nit) | `DeckPage.md`'s auto-layout bullet stated the floor twice, and said "no horizontal overflow" beside the 19px spill | `847e3b95`: one statement, "the page does not scroll sideways" |
| F6 (nit) | Two very long CSS comment lines; the floor comment's 62px (58 + 4) vs Decision 6's prose "60px" | `847e3b95`: re-wrapped, "spec 075, not yet built" named; Decision 6's "60px" in the shipped spec's prose is not edited (the table says 62px, and the CSS comment is exact) |
| F7 (nit) | The spec's Status line names only 0.3.0 and 0.4.0 | left: the changelog holds every ruling |
| F8 (nit, process) | AC-1.14 and AC-1.15 were committed in the same commit as the floor CSS (`1662035e`), so git doesn't show the red run | none: this file records it (the menu column 16px against 64px, the 30px spread) and the mutation table backs it up |

After the fixes: `menu_tab_bar_clearance_spec.rb` and `design_system_files_spec.rb`, 36 examples, 0 failures.

## Distillation (`distill-feature`)

No `docs/architecture` area doc covers menus, the tab bar's clearance or the deck zone tables' column widths (the implementation review checked `collection-and-lots.md:133` and found it still true), so no area doc changes. The rules live in the design system's README and component documents, which this branch updated (`Menu`, `TableActions`, `TabBar`, `DeckPage`, the Navigation section, the App additions entry). Index row 074 is Frozen by the design system, its plan's retirement owed (`636c4505`), and the spec carries its frozen line (`fb0956fe`, spec 027 D4). CLAUDE.md restates none of these rules, so it is unchanged.
