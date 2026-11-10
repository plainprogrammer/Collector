# Feature 063: Small Icons Keep Their Weight (Stroke Follows Size)

**Status:** Approved by the maintainer (2026-11-10, Gate A, relayed by the coordinator) at 0.3.0, after two spec review rounds
**Version:** 0.3.0
**Created:** 2026-11-10
**Last Updated:** 2026-11-10
**Depends on:** [spec 060](../060-deck-components/spec.md) (decision 16: every icon in the previews is at the app's stroke, 1.5; this issue is its follow-up), [spec 057](../057-deck-design-rules/spec.md) (the design system's rules and additions), all merged
**Branch:** `063-small-icon-stroke`
**Issue:** [#294](https://github.com/plainprogrammer/Collector/issues/294) (design-system lane)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.0 | 2026-11-10 | Spec review round 2 (Opus, read-only; REVISE: 1 major, 4 minor), all taken: `Cover` draws no icon, so nine previews gain the link, not ten; AC-2.2 names the two changes that come from the app's own `additions.css` rules (ItemTile's unowned tile, CollectionTable's phone sub line) and measures `c-menu__item` and `c-filter` too; FR-1's no-other-spec-number rule covers the block's comment |
| 0.2.0 | 2026-11-10 | Spec review round 1 (Opus, read-only; REVISE: 1 blocking, 2 major, 7 minor), all taken: ten previews don't load `additions.css` and gain the link (decision 2, AC-2.2, FR-2); AC-1.5 measures rendered icons only (width above 0, a stroke that isn't `none`); AC-2.3's TabBar sample is corrected to match the preview, not a partial; the Problem Statement says menu items and filter chips draw icons in the previews only; the inline icons number 195; the previews' More dots are filled; FR-1 names every guarded spec number; the index row's plan is "none"; FR-3 says one spec file |
| 0.1.0 | 2026-11-10 | First draft from issue #294 and the measurements below. The maintainer ruled decisions 1 and 2 on 2026-11-10 (the coordinator relayed them: option A of each) |

## Problem Statement

The app draws every icon with `stroke-width="1.5"` on a 24-unit viewBox (`app/views/icons/*.html.erb`), Lucide's own weight at 20px. The stylesheets draw some of them smaller: 16px in buttons, inputs and menu items, 14px in the view switch and filter chips, 12px in badges and legality marks. A stroke scales with the icon, so its weight on screen is the stroke times the icon's size over 24:

| Drawn at | Where | Stroke 1.5 on screen |
|---|---|---|
| 22px | the tab bar | 1.375px |
| 20px | Lucide's intended size | 1.25px |
| 16px | `c-btn`, `c-input`, `c-menu__item` (the last in the previews only) | 1.0px |
| 14px | `c-seg`, `c-filter` (the last in the previews only) | 0.875px |
| 12px | `c-badge`, `c-legal` | **0.75px** |

At 12px the check and the cross of the legality grid ("Legal", "Not legal", "Banned") and the check of a badge ("Matched by its collector line") are visibly lighter than the weight-600 word beside them, in light and dark, at 1x and 2x (the stem of Plex Sans 600 at 12px is near 1.4px). They stay legible: the foil star is filled and the warning triangle reads fine. At 14px to 16px the icons are lighter than their labels but not hairlines. The maintainer ruled on 2026-11-10 to keep the previews at 1.5 to match the app (spec 060 decision 16) and asked for this issue for the app itself.

> **Terms.** An icon's *weight* is its stroke width on screen in px: `stroke-width × drawn size ÷ 24`. An *icon partial* is a file of `app/views/icons/`. A *small icon* is one drawn below 20px.

**Probe (2026-11-10; headless Firefox, light and dark, 1x and 2x, classic scrollbars as the suite pins them).** Candidate strokes were injected as a style on the real card page (the Format legality grid), on the real partials' badge markup inside a `c-badge`, and on the collection page's header, search field and view switch. Weights on screen: at 12px, stroke 1.5 is 0.75px, 2 is 1.0px, 2.5 is 1.25px, 3 is 1.5px. At 12px, 2.5 matches the bold word ("Legal", "Read") in both themes and the cross beside the regular-weight "Not legal" is fine; 2 is a touch under it; 3 is heavy in the badges. At 14px to 16px, 2 balances the weight-600 labels ("Add items", "Grid"); 2.25 starts to look bold. The comparison shots are not committed; the verification records the final before and after.

## Goals

- The check and the cross at 12px, and the other small icons, read at about the weight of the word beside them, in light and dark.
- The design system's Iconography rule says how stroke follows size, so the next icon at a new size gets a stroke by the rule and not by guess.
- The previews match the app.

## Non-Goals

- Choosing an icon set or redrawing an icon: Lucide stays (the README's Iconography line).
- Changing an icon at 20px or larger: the tab bar's 22px icons and any icon the app draws at 20px keep 1.5.
- Changing a partial's markup or interface: the `stroke-width="1.5"` attribute stays on every partial (decision 2), so existing and in-flight calls (the deck views of spec 062) are unaffected.
- Changing the previews' 195 inline icons: they take the weight from `additions.css` (decision 2); spec 060 AC-7.5 (every `stroke-width` attribute in the previews is 1.5) stays true. Nine previews that draw an icon don't load `additions.css` yet and gain the `<link>` (AC-2.2); no icon markup changes.
- Changing the filled icon (the foil star, `fill="currentColor" stroke="none"`) or any icon's size.

## Decisions

### 1. Stroke follows the size an icon is drawn at, in three steps (ruled by the maintainer, 2026-11-10, option A)

| | A. Three steps that hold about 1.25px on screen below 20px (ruled) | B. Two steps: 12px to 16px at 2 | C. Only the hairlines: 12px at 2.5 |
|---|---|---|---|
| 12px (badges, legality) | 2.5 → 1.25px | 2 → 1.0px | 2.5 → 1.25px |
| 14px to 16px (buttons, inputs, menu items, view switch, filter chips) | 2 → 1.17px to 1.33px | 2 → 1.17px to 1.33px | 1.5 → 0.88px to 1.0px |
| 20px and up (tab bar at 22px) | 1.5 → 1.25px to 1.375px | 1.5 | 1.5 |
| Result | every stroked icon draws between 1.17px and 1.375px | the 12px check sits a little under the bold word | buttons and view switch stay lighter than their labels |

The rule behind A is a stroke of `30 ÷ size` (the stroke that gives 1.25px at that size) rounded to the nearest half, never below 1.5 or above 2.5: 12px gives 2.5, 14px 2.14 → 2, 16px 1.88 → 2, 18px 1.67 → 1.5, 20px and up 1.5. The README states it (AC-2.1).

### 2. The stroke is set in CSS, by the component that draws the icon; the partials keep their attribute (ruled, option A)

| | A. CSS only (ruled) | B. The partials take a size or a modifier | C. One constant on-screen stroke with `vector-effect: non-scaling-stroke` |
|---|---|---|---|
| Where the stroke lives | one block in `additions.css`, under its own `(spec 063 …)` heading | each partial writes the stroke | one rule |
| Partials' interface | unchanged | changes; every call that sets a size changes | unchanged |
| An icon placed in a component later | takes the right weight at once | must pass the size | takes it, but a 20px icon changes too |
| Previews | match once they load `additions.css` (nine gain the `<link>`, no icon edit) | 195 inline icons to rewrite | match, but the 20px ones change |
| Follows Lucide's scaling | yes, in three steps | yes | no |

A CSS declaration beats an SVG presentation attribute on the same element, so `.c-badge svg { stroke-width: 2.5 }` wins over the partial's `stroke-width="1.5"` while the attribute still states the 20px weight and keeps the partials, the previews and a copied icon from a design export correct on their own. The selectors name the components that set the size (`components.css` lines 8, 26, 43, 54, 65, 137, 215, 300), not the icons, so an icon drawn in them takes the weight whichever partial it is. The rules go in `additions.css`, not `components.css`, which is the export's file (the design system's own rule for what the app adds).

| Component's svg | Drawn at | `stroke-width` |
|---|---|---|
| `.c-badge`, `.c-legal` | 12px | 2.5 |
| `.c-btn`, `.c-input`, `.c-menu__item`, `.c-filter`, `.c-seg button` | 16px (14px for `c-filter` and `c-seg`) | 2 |
| `.c-tabbar` | 22px | none: the attribute's 1.5 |

### 3. An icon drawn at a size no component sets is given its stroke by the rule when it is added

When a component is added with an icon at a size not in the table, its CSS block sets the stroke by decision 1's rule, and the README's table of sizes gets the row. The guard of AC-1.5 fails an icon whose weight is outside 1.1px to 1.4px, which is how the next such icon is found. No selector for sizes is written in advance.

## Supersedes

| Document | What it says | What changes |
|---|---|---|
| `docs/design-system/README.md`, Iconography | "Lucide (ISC-licensed, 1.5px stroke, 20px) in `currentColor`" | The line says that 1.5 is the stroke at 20px and above and how stroke follows size below it (AC-2.1). The icon set and the colour rule stand |
| [Spec 060](../060-deck-components/spec.md) decision 16 | The previews' icons are at the app's stroke, 1.5 | Extended, not superseded: their attributes stay 1.5 (AC-7.5 stays true) and the weight below 20px now comes from `additions.css`, as the app's does |

Recorded in the specs index. Spec 060 is frozen and is not edited.

## User Stories

### Story 1: The check and the cross read as heavy as their word

**As a** collector
**I want** the small icons to be as heavy as the text beside them
**So that** the legality marks and badges read at a glance, in light and dark

- [ ] **AC-1.1** Given the card page of a printing with legal and not-legal formats When the Format legality grid renders Then each `c-legal` check and cross is drawn at 12px with a computed stroke width of 2.5 (a weight of 1.25px).
- [ ] **AC-1.2** Given a `c-badge` holding the check partial and a `c-badge` holding the alert partial (the scanner's "Matched by…" and "Printing not confirmed" badges) When they render Then each icon is drawn at 12px with a computed stroke width of 2.5.
- [ ] **AC-1.3** Given the collection page When its search field, buttons and view switch render Then the `c-input` icon and the `c-btn` icons (16px) and the `c-seg` icons (14px) have a computed stroke width of 2.
- [ ] **AC-1.4** Given the collection page on a phone (a 390px frame) When the tab bar renders Then its icons are 22px with a computed stroke width of 1.5, unchanged.
- [ ] **AC-1.5** Given the card page, the collection page (grid and table) and the catalog search, and the collection page in a 390px frame When every rendered stroked icon on them is measured (an `svg` whose drawn width is above 0 and whose computed `stroke` is not `none`: the tab bar on a wide screen, the appbar's add and back buttons where they are hidden and the filled star are not measured) Then each has a weight (computed stroke width × drawn width ÷ 24) of 1.1px to 1.4px, and at least one icon is measured on each page. (A guard: an icon at a new size or in a new component outside the rule fails it, and so does an icon that shrinks.)
- [ ] **AC-1.6** Given the filled foil star When it renders Then it has no stroke (computed `stroke` is `none`) and is drawn as before.
- [ ] **AC-1.7** Given the legality grid, the badges, the buttons and the view switch, in light and dark, at 1x and 2x When the maintainer compares them with the shots from before the change Then the 12px check and cross read at about the weight of the word beside them and the 14px to 16px icons balance their labels. (A verification criterion: the maintainer's visual review of the before and after shots, recorded in `verification.md` and shown in the pull request; the More dots, drawn as circles, are in the shots.)

### Story 2: The rule is written where the next icon reads it

**As a** developer, or an agent, adding an icon
**I want** the design system to say how stroke follows size
**So that** I don't guess a weight, and the previews and the app agree

- [ ] **AC-2.1** The README's Iconography states the rule of decision 1 with its sizes (1.5 at 20px and above, 2 at 14px to 16px, 2.5 at 12px; about 1.25px on screen below 20px; `30 ÷ size` rounded to a half) and says where it lives (`additions.css`, by component; the partials keep 1.5), and points to this spec. (Verified by reading.)
- [ ] **AC-2.2** The previews draw the same weights as the app. Nine previews that draw a stroked icon don't load `additions.css` (`Badge`, `Button`, `Chip`, `CollectionTable`, `FilterBar`, `Input`, `ItemTile`, `Menu`, `ViewSwitch`) and gain its `<link>`, after `components.css` as the other previews have it; no icon markup changes and every `stroke-width` attribute in the previews is still 1.5 (spec 060 AC-7.5). When a preview of each component of decision 2's table is loaded with the real stylesheets in headless Firefox (Badge, ItemPage's legality, Button, Input, ViewSwitch and TabBar as AC-1.1 to AC-1.4 state; Menu's `c-menu__item`, 16px, and Chip's `c-filter`, 14px, at a computed stroke width of 2), its icons have the stated computed stroke widths, and the nine previews that gained the link look the same as before outside their icons, with two exceptions that come from the app's own rules in `additions.css` and are recorded as such: `ItemTile`'s unowned tile (`c-tile--owned-none` with a `c-tile__missing` fallback) loses the export's 45% fade, as the app draws it (spec 021, `UnownedTile.md`), and `CollectionTable`'s phone frame may wrap a `c-table__sub` line the export left on one line (`additions.css`, below 640px of container width). (A verification criterion, measured once and recorded in `verification.md` with the before and after shots of the nine; the previews' More dots are filled circles, not the app's stroked ones, so AC-1.7's dots come from the app.)
- [ ] **AC-2.3** The one component document that carries a `stroke-width` attribute, `docs/design-system/components/TabBar.md` (`stroke-width="2"` in the Decks icon of its markup sample, which the design system draws itself and no partial does), is corrected to 1.5, as `previews/TabBar.html` and the partials draw; `Badge.md` says the 12px icon's weight comes from the stylesheet. (Verified by reading.)
- [ ] **AC-2.4** The specs index has this spec's row. (Verified by reading.)

### Story 3: Nothing that draws an icon changes

**As a** worker building the decks views (spec 062)
**I want** the icon partials to stay as they are
**So that** my calls and the markup I copy keep working

- [ ] **AC-3.1** `app/views/icons/*.html.erb` are byte-for-byte unchanged, and no view, helper or other stylesheet file changes. (Verified by the branch's diff.)

## Functional Requirements

- **FR-1.** `additions.css` gets one new block, `/* ---------- Small icon stroke (spec 063) ---------- */`, holding the two rules of decision 2's table (12px components at 2.5, 14px to 16px components at 2), with a comment giving the why (the weight formula, the 1.25px aim, the CSS-over-attribute order) and pointing to the README. The block, its heading and its comment, names no spec number but 063 (the guards in `spec/design_system_files_spec.rb` count "spec 019", "spec 021" and "spec 023" across the whole file) and every rule in it sits under it.
- **FR-2.** The README's Iconography, `TabBar.md` and `Badge.md` change as AC-2.1 and AC-2.3 say; the nine previews of AC-2.2 gain the stylesheet link; `docs/specs/README.md` gets the row.
- **FR-3.** One system spec file (`spec/system/icon_stroke_spec.rb`) proves AC-1.1 to AC-1.6 by measuring computed styles and drawn sizes on the real pages; it fails before the CSS and passes after. The 390px frame is `open_in_narrow_frame`.
- **FR-4.** No partial, view, helper, model, migration or export file changes. The partials' attribute and the README's "1.5 at 20px and above" are the same number, so a copied icon from a design export looks right on its own.

## Non-Functional Requirements

- **Compatibility:** no migration, no schema change, export format unchanged at version 3, upgrade-safe from the previous release.
- **Hosted-door cost per account (north star rule 4):** none; a stylesheet and documents.
- **Accessibility:** a heavier stroke raises the icon's contrast on its ground; the icons are `aria-hidden` and a word or a label always comes with them (the README's status rule), unchanged.
- **Visual change:** yes, small and deliberate. Before and after shots (light and dark, 1x and 2x) of the card page's legality grid, a badge row, the collection page header and view switch, and the More button (its menu items carry no icons) are owed to the maintainer's review before the pull request is ready, and go in the pull request body.

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| An icon is added in a component outside the table (a new size) | AC-1.5's guard fails with the icon's weight; the author sets the stroke by decision 1's rule in the component's block and adds the README row (decision 3) |
| A browser ignores a CSS `stroke-width` over the attribute | None known (CSS beats a presentation attribute in the SVG specification, and the system example runs in Firefox); a failure would show as a computed stroke of 1.5 in AC-1.1 to AC-1.3 |
| An icon is used outside the components (a bare `svg` in a page) | It keeps the attribute's 1.5, as it did; it is at 1.25px only if it is drawn at 20px, so a small bare icon is a design-system violation, not something this rule hides |
| The More dots (circles of radius 1.5) at stroke 2 touch or merge | The dots are 7 units apart with an outer radius of 2.5, a gap of 2 units; AC-1.7's shots show them, and the maintainer's review is where a change is asked for |

## Open Questions

None. Decisions 1 and 2 are the maintainer's rulings of 2026-11-10.

## Notes for the plan

- The system example is the first task and is written first. Its red run is the current CSS (12px icons at 1.5 fail AC-1.1 and AC-1.2). Read `getComputedStyle(svg).strokeWidth` and `svg.getBoundingClientRect().width` and parse the number (Firefox may return `"2.5"` or `"2.5px"`), and for AC-1.2 inject the real partials' markup (`ApplicationController.render(partial: "icons/check")`) into a `c-badge` on the card page, as the scanner's badge is not worth the scanner's setup here. AC-1.5 lists the pages by path; the tab bar is visible only below 640px, so its examples run in the 390px frame (a frame has a classic scrollbar: no matter for a weight).
- Run `bin/rspec spec/design_system_files_spec.rb` after the `additions.css` edit (the block counts of its guards).
- Shots (AC-1.7, `verification.md`, the pull request): a throwaway system spec under `spec/system/` that saves element shots with factory data, light and dark, 1x (`layout.css.devPixelsPerPx` unset) and 2x (set to 2), "before" by injecting the old rule as a `<style>` (`stroke-width: 1.5 !important` on the same selectors), "after" with the shipped CSS, as `.claude/memory/pr-screenshots-workflow.md` describes; commit them under `docs/specs/063-small-icon-stroke/screenshots/`, delete the throwaway spec before committing. Say "factory data, placeholder printings" in the pull request. AC-2.2's measure of the previews is served with `python3 -m http.server` over the worktree and read by a scratch script (the memory's static-previews recipe).
- Measure the app's pages, not only the previews (lesson `docs/lessons/2026-11-10-measure-the-apps-header-not-the-preview.md`): the probe above did.

## Out of Scope (Future Considerations)

- Sizes the app doesn't draw (18px): decision 3's rule covers them when they appear.
- An icon set of the design system's own, or per-icon optical adjustments (a thinner `more` or a heavier `alert`): the shots show none is needed.

## Documents that change

- `docs/design-system/README.md`: Iconography.
- `docs/design-system/components/TabBar.md` (the sample's attribute), `docs/design-system/components/Badge.md` (one sentence).
- `app/assets/stylesheets/collector/additions.css` (the block); `spec/system/icon_stroke_spec.rb` (new).
- `docs/specs/README.md`: this spec's row.
- The nine previews of AC-2.2 (`<link>` to `additions.css` only).
- No area doc: the design system's rules are its README and component documents (spec 057, spec 060); no ADR: the rulings are decisions 1 and 2 here.
- Left as history, not edited: spec 060 and its `verification.md` (decision 16 and AC-7.5 stand).
