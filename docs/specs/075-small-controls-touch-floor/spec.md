# Feature 075: Small Buttons, Filter Chips and the View Switch Meet the Touch Floor on a Coarse Pointer

**Status:** Draft, awaiting Gate A
**Version:** 0.3.0
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 072](../072-select-touch-floor/spec.md) (selects at 44px, the filter row centred, the coarse-pointer example technique; its Non-Goals named this change as a separate design-system ruling), [spec 063](../063-small-icon-stroke/spec.md) (decision 2: the app's additions go in `additions.css`, never in the export's `components.css`), all merged
**Branch:** `075-small-controls-touch-floor`
**Issue:** [#316](https://github.com/plainprogrammer/Collector/issues/316) (design-system lane, a follow-up of spec 072 / #315, filed by the maintainer's ruling)

---

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.3.0 | 2026-11-11 | Spec review round 2 (Opus, read-only; REVISE: 0 blocking, 1 major, 4 minor, 3 nit), all taken: `except:` matches the selector text and the stylesheet, not the value (two other `additions.css` coarse rules carry `var(--touch-floor)`: the selects' and the radio rows'); a line is a cluster of controls whose vertical extents overlap, counted over the AC-1.2 set; AC-1.8 names 360px for number entry; rows 4 and 5 gain the printings page's quick add and the grid's pager; rows 14b and 15 get widths and "Store again" is exempted by name; the hoisted helper and the re-premised example are stated exactly; a note that AC-2.11's example is not red by itself |
| 0.2.0 | 2026-11-11 | Spec review round 1 (Opus, read-only; REVISE: 1 blocking, 5 major, 3 minor, 3 nit), all taken: the audit is per control and names the rule that covers each, and finds two more page families with their own 44px rules (number entry's list, the scanner's sitting and Add buttons), so AC-1.3 is limited to the controls with no page rule; the rows the review found missing or wrong are fixed (four job chips, "Other printings", "Show all N printings" on the card search, the card page's quick add, the pagers); AC-1.2 runs at two widths and covers `#status`, and asks for a width only of icon-only controls; the examples identify the block's rules by stylesheet and value, not by selector text alone (the min-height rule's text equals `components.css`'s); AC-1.5 defines a line and its rows; the supersession list gains `NumberEntry.md`, the alignment can-fail example, two spec comments and the callers of `apply_coarse_rules`; the view switch's width is stated exactly |
| 0.1.0 | 2026-11-11 | First draft from issue #316 and the audit below. Routing: the change is a design-system rule (the README states the 40px exception), so it is a spec, not a direct fix. Decision 1 is the product call the issue leaves open, with a recommendation |

## Problem Statement

On a touch screen the design system's floor for a target is 44px (`--touch-floor`), and every control meets it except three families, which stop at 40px by the README's Touch rule ("40px for small buttons, chips and the view switch"):

| Control | Class | Fine pointer | Coarse pointer (today) | Where the 40px is written |
|---|---|---|---|---|
| Small button | `.c-btn--sm` | 28px high | 40px high | `components.css`, the touch block |
| Small icon button (the "…" menu triggers, the header's "+") | `.c-btn--sm.c-btn--icon` | 28px × 28px | 40px wide | the same block |
| Filter chip | `.c-filter` | 28px | 40px | the same block |
| View switch | `.c-seg button` | 28px | 40px | the same block |

Everything else is at 44px on a coarse pointer: `.c-btn`, `.c-input`, `.c-menu__item` (`components.css`) and, since spec 072, every select (`additions.css`). Five families of page already raise their small buttons to 44px at every pointer by rules of their own, each a page decision of an earlier spec: Locations (spec 032, `.c-locations .c-btn`), the Decks pages (specs 062, 064, 068, `.c-decks .c-btn`), the deck page's zone heads (spec 068, `.c-deckpage .c-section__actions .c-btn`), number entry's list (`.c-numentry__list .c-btn`) and the scanner's adds, undos and sitting (`.c-scanner__add .c-btn, .c-scanner__undo .c-btn, .c-scanner__sitting .c-btn`). So the same "Search" button is 44px on the add-a-proxy chooser (a `c-decks` page) and 40px on the card search, and the same "Undo" is 44px in number entry's list and 40px in a status message. Spec 072 left a filter bar holding 44px selects beside 40px small buttons, centred so they line up, but the buttons remain the smaller targets (issue #316).

> **Terms.** The *touch floor* is `--touch-floor`, 44px (`additions.css`). A *small control* is a `.c-btn--sm` (any element with the class: button, link, submit, `summary`), a `.c-filter` chip or a `.c-seg button` of the view switch. A *page rule* is one of the five rules above. A *coarse pointer* is a touch screen, `(pointer: coarse)`; a *fine pointer* is a mouse or a trackpad.

### Audit: every small control of the app (2026-11-11)

Built from `git grep -n -E "c-btn--sm|c-filter|c-seg" -- app ':!app/assets' ':!.kamal/secrets'` (run again, and the page rules found with `git grep -n "min-height:\(44px\|var(--touch-floor)\)" -- app/assets/stylesheets/collector/additions.css`, when the plan is written; both commands go in `verification.md`). Sixteen places draw one. "Rule today" is what lifts the control to 44px on a coarse pointer before this spec: `none` is the touch block's 40px, `page` is a page rule that also applies at a fine pointer. Widths: only the icon-only controls (`c-btn--icon`, the view switch's icons below 640px) need a width of 44px; a labelled control is wider by its label.

| # | Page (route) | Small controls | Rule today | How the example reaches it, and at which width |
|---|---|---|---|---|
| 1 | App header, every page | "+" (`c-appbar__add`, icon); "Sign in" (a visitor's header on an open catalog) | none | collection page at 360px for "+" (it shows below a 640px viewport); the open catalog for "Sign in" |
| 2 | Card search (`/catalog/entries?q=…`) | Search (filter row), a tile's quick add, "Show all N printings" (the group's head), Previous and Next | none | factory printings of one name in several sets, enough for a second page; 1280px and 360px |
| 3 | Card page (`/catalog/entries/:key`) | the "…" trigger of each copy's row; "Show all N printings"; the quick add of a printing the collector doesn't own | none | an owned lot, printings of the name not owned; both widths |
| 4 | Printings page (`/catalog/identities/:id`) | "Show all sets" (a set chosen in the URL), the tiles' quick add, Previous and Next | none | more printings than `Catalog::IdentitiesController::PER_PAGE` (12); both widths |
| 5 | Collection, grid | Filter, Edit many (from 640px of the container), the "…" menu (below 640px), the view switch, Previous and Next | none | spec 072's route (`view=grid`, named, it is a saved preference); both widths |
| 6 | Collection, table | the same, each row's "…" trigger, Previous and Next | none | a second page of lots; both widths |
| 7 | Collection, bulk mode | Filter, Set condition…, Move to…, Remove (from 640px), the "…" menu (below), Done, Previous and Next, the view switch | none | spec 072's route; both widths |
| 8 | Number entry (`/collection/number_entry`) | Change language, Change set | none | a chosen set with a second language; both widths |
| 8b | Number entry's list | Done, each line's Undo, "Show all N" | page (`.c-numentry__list .c-btn`) | more lines than the list shows; both widths |
| 9 | Decks (`/decks`) and the deck page (`/decks/:id`) | Rename, Change format, Remove; each zone's Add a proxy | page (`.c-decks .c-btn`, `.c-deckpage .c-section__actions .c-btn`) | a deck; both widths |
| 9b | The deck page | each proxy row's "…" trigger | none | a deck with a proxy; both widths |
| 10 | Add a proxy, the chooser (`/decks/:id/zones/:zone/proxies/new?q=…`) | Search, Choose, Previous and Next | page (`.c-decks .c-btn`) | as spec 072; both widths |
| 11 | Locations (`/locations`) | Rename, Remove | page (`.c-locations .c-btn`) | a location; both widths |
| 12 | Admin jobs (`/admin/jobs`) | the four state chips (failed, running, queued, scheduled), each row's "…" trigger, Previous and Next | none | an admin, a failed job and a scheduled one, with the page's poll stopped (it refreshes while a job runs or is queued); both widths |
| 13 | Admin users (`/admin/users`) | each row's "…" trigger | none | an admin and a second user; both widths |
| 14 | Scanner (`/scanner`), the sitting | the sitting's Done, each entry's Details and Undo, "Show all N", the picker's Set | page (`.c-scanner__sitting .c-btn`, `.c-scanner__undo .c-btn`) | `Scanner::Sitting.add!` for more entries than `Scanner::Sitting::SHOWN`; both widths |
| 14b | Scanner, a candidate | its Add buttons; its "Other printings" link; "Show N more" in the printings frame | Add: page (`.c-scanner__add .c-btn`); the other two: none | the page's own reading flow (`scanner_adding_spec.rb`'s helpers), then "Other printings"; both widths |
| 15 | Scanner measurement mode (dev only) | Skip; "Store again" (hidden until a store fails; AC-1.2 does not require it drawn, and measures it if the setup shows it) | none | spec 072's setup with a manifest; both widths |
| 16 | A status message with Undo (`div#status`, after a bulk removal) | Undo | none | a bulk removal; both widths |

The rows marked `page` are 44px at every pointer already: a coarse pointer changes nothing there, and the examples still list them so a later edit to a page rule is noticed. The rows marked `none` are 40px on a coarse pointer today, and decision 1 raises them. `components.css`'s touch block cannot be edited (it is the design export's file), so the new floor goes in `additions.css`, which the layout links after it (`collector/tokens`, `collector/components`, `collector/additions`), and wins by source order at equal specificity. The old `40px` lines stay in the file, overridden. A re-export of the design system restores them, and still loses to `additions.css`.

A measurement before this spec (a throwaway probe, 2026-11-11, with every coarse rule applied at 360px, the proposed rule injected, factory data): on the collection page (grid, table and bulk mode), the card search, the Decks index and the deck page the small controls go from 40px (42px for the icon `summary`) to 44px (46px), no page overflows, no row gains a line, and the collection's sticky filter bar grows by 4px (173 to 177px). It is evidence for decision 1, repeated as examples below.

## Goals

- On a touch screen every small control (small button, filter chip, view switch) is at least 44px high and 44px wide, as every other control and every select is.
- A fine pointer keeps today's compact heights (28px).
- The design system states one rule for every target, with no exception to remember, and one CSS block carries it.
- No page with a small control overflows at 360px, no control overlaps another and no row of controls gains a line because of the change, on a coarse pointer.

## Non-Goals

- Changing a fine pointer's heights, or a hybrid device's: the rule keys on `(pointer: coarse)`, the primary pointer, as every touch rule of the design system does.
- Changing the Locations, Decks and deck-page rules that give their buttons 44px at every pointer (they are page decisions of specs 032, 062 and 068 and stay).
- Other targets under 44px: the table's 20px checkboxes (`.c-table input[type="checkbox"]`, in components.css's touch block), inline text links (a card's name, breadcrumbs, the footer's links), the tab bar's items and the avatar menu are not small controls in this spec's sense and are not audited here. They are Out of Scope below.
- Any view, helper, controller, model, migration or export change.

## Decisions

### 1. The floor for small controls rises to 44px on a coarse pointer, with no exception (proposed; a product call for Gate A)

| | A. 44px for every small control on a coarse pointer (proposed) | B. Keep 40px, the README states a reasoned exception for dense toolbars | C. 44px only for controls that share a row with a 44px control (the filter bars) | D. 44px at every pointer, as Locations and the Decks pages do |
|---|---|---|---|---|
| Consistency | one number for every target and every select; nothing to remember | the README keeps an exception, so each new page asks which side it is on | two floors on one page (the collection's bar at 44px, its bulk bar at 40px) | one number, one rule |
| Touch target | every small control reaches 44px, including the destructive ones (Remove beside Move to… in the bulk bar, Undo) | a bulk bar's Remove and Move to… stay 4px short | the bulk bar and row menus stay short | as A |
| Fine pointer | unchanged (28px) | unchanged | unchanged | every desktop toolbar grows from 28px to 44px: the compact rows are lost (the issue keeps them) |
| Cost measured at 360px | none: no overflow, no extra line, the collection's sticky bar +4px (probe above) | none | none | not measured; every desktop page changes |
| Evidence the exception was needed | none: the 40px came with the export, and five families of page already ship 44px small buttons | n/a | n/a | n/a |
| Where the rule is | one block in `additions.css`, README sentence | the README's sentence stays and grows a paragraph | one block with a scoped selector | per-page, as today (five scopes already) |

Recommended: **A**. The README's 40px exception has no recorded reason (its source is the export), the app's own pages for Locations, Decks, the proxy chooser, number entry's list and the scanner already use 44px for the same classes, the probe found no layout cost at 360px, and the destructive actions (Remove, Undo) are the controls where a missed tap costs the most. *B* is the alternative if the maintainer values the dense toolbar: the README would then keep "40px for small buttons, chips and the view switch" and add the reason, and this spec would shrink to a README paragraph, the audit and AC-1.4 (no change to CSS); say so at Gate A. *C* leaves two floors on one page. *D* costs the desktop's compact rows, which spec 072 and the issue keep.

### 2. One block of its own in `additions.css`, two rules inside `@media (pointer: coarse)`

The new block, `/* ---------- Small controls meet the touch floor on a coarse pointer (spec 075) ---------- */`, holds:

```css
@media (pointer: coarse) {
  .c-btn--sm, .c-filter, .c-seg button { min-height:var(--touch-floor); }
  .c-btn--sm.c-btn--icon, .c-seg button { min-width:var(--touch-floor); }
}
```

`min-height` and `min-width`, not `height` and `width`: the rule only raises, as `components.css`'s own touch block does, and `var(--touch-floor)` is the token every 44px rule of `additions.css` uses. The selectors repeat `components.css`'s touch rule's so the cascade needs no specificity: the same specificity, the later file wins. `.c-seg button` has a `min-width` because the view switch shows icons alone below 640px of its `.c-collection` container (`c-seg__label` is hidden, absolutely placed, so it adds no width): an icon-only button is a 14px icon and 2 × 12px of padding, 38px wide (39px for the second, with its `border-left`), and a 44px high, 38px wide target is not a 44px target; the issue asks for the floor, not half of it. A labelled control is wider already, so the `min-width` on `.c-btn--sm` is for the icon variant only. The block's comment gives the why (the three families, the page rules that predate it and stay, the 40px lines left in `components.css`, the headless-Firefox limit, where the rule is documented). Two comments of `additions.css` that call a small button "40px on a touch screen" (spec 072's block and spec 068's "Add a proxy" block) are corrected in the same change.

### 3. The five page rules stay

`.c-locations .c-btn`, `.c-decks .c-btn`, `.c-deckpage .c-section__actions .c-btn`, `.c-numentry__list .c-btn` and the scanner's three (`.c-scanner__add .c-btn, .c-scanner__undo .c-btn, .c-scanner__sitting .c-btn`) apply at every pointer by their specs' rulings (a desktop mouse gets 44px there too) and are not touched: they are wider than a touch rule and nobody asked to narrow them. On a coarse pointer the new rule and the page rules agree, so a "Rename" or an "Undo" is 44px on both sides. Each page rule also sets a `min-width` on every `.c-btn` it covers; the new rule's `min-width` is for the icon variant and the view switch only, so a page's text buttons keep their width.

### 4. The examples read the rule and apply it, because headless Firefox can't emulate a coarse pointer

The examples apply every rule of every `@media (pointer: coarse)` block of the loaded stylesheets as one adopted sheet in source order (`CoarsePointer#apply_coarse_rules`, `spec/support/coarse_pointer.rb`; spec 072 decision 3 and its lesson `docs/lessons/2026-11-11-a-coarse-pointer-example-applies-every-coarse-rule-and-needs-a-can-fail-partner.md`), measure the controls as drawn, and fail by name when the rule they are about is missing from the stylesheets. The block's rules are identified by the stylesheet that holds them (`additions`) and their declared value (`var(--touch-floor)`), not by selector text alone: the new min-height rule's selector text, `.c-btn--sm, .c-filter, .c-seg button`, is the same as `components.css`'s 40px rule, so `needs:` on that text passes before the change and `except:` on it would drop the 40px rule too (the "without the block" state would then be 28px, not today's 40px). `needs:` names the min-width rule's selector (`.c-btn--sm.c-btn--icon, .c-seg button`), which exists only in the block, and the helper's `except:` takes the selector text and the stylesheet (`additions`) together, never the value: `additions.css` has two other coarse rules at `var(--touch-floor)` (the selects', spec 072, and the radio rows', spec 071), which a value match would drop from the "without the block" state and make AC-1.7 fail on every page with a select. The selector-text-only form stays, so spec 072's calls keep working. A fine pointer's heights are measured with nothing applied. The comparison examples pin `html { overflow-y: scroll }` in both states, so a taller page can't narrow the frame by a scrollbar. Each "nothing else changes" check has a can-fail partner (a variant that adds a taller rule must change the measure).

## Supersedes

| Document | What it says | What changes |
|---|---|---|
| `docs/design-system/README.md`, the Touch rule (line 73) | "On touch devices every target is at least 44px (40px for small buttons, chips and the view switch)", and "a 40px small button sits level with the 44px select" | every target is at least 44px, the small buttons, chips and the view switch included; the sentence about the filter row's centring says the row centres what is not 44px |
| [Spec 072](../072-select-touch-floor/spec.md) Non-Goals (the first), and its component documents' sentences: `FilterSelect.md` ("so the 40px small button beside it sits level with it") and `NumberEntry.md` ("keeps its select and its 40px \"Change language\" button") | the small buttons, chips and the view switch stay 40px | the floor rises (decision 1). Spec 072 is frozen and is not edited; its documents' sentences say 44px |
| `spec/system/select_touch_floor_spec.rb`, "notices a rule that grows another control" (AC-1.7 can fail: expects the Search button at 40px) and "needs the alignment rule" (AC-1.5 can fail: a 40px button sits off a 44px select's centre) | premises that hold only while a small button is 40px | the first expects 44px before its injection; the second is re-premised: with both at 44px, dropping the row rule need not move the centres, so the example injects a shorter button (`.c-filterbar__filters .c-btn { min-height:30px; height:30px }`, applied after every coarse rule) and expects the offset at most 1px with the row rule and more than 1px without it |
| `spec/system/deck_page_spec.rb`, "gives the row menu's trigger the touch floor of a small icon button (AC-2.11)" (its comment says 40px; it matches `selectorText` exactly) and the comment of the Add a proxy example ("40px on a touch screen") | reads `.c-btn--sm.c-btn--icon`'s coarse `min-width` as at least 40 | reads the rule of `additions.css` (`.c-btn--sm.c-btn--icon, .c-seg button`) as `var(--touch-floor)`, at least 44; the comments say 44px |
| `app/assets/stylesheets/collector/additions.css`, the comments of spec 072's block and of spec 068's "Add a proxy" block | a small button is "40px on a touch screen" (and "36px on a mouse": it is 28px) | the comments say 44px and 28px (their rules are unchanged) |

Examples that apply every coarse rule through `apply_coarse_rules` and so measure the new state, checked and unchanged in meaning (AC-3.2): `card_page_spec.rb` (the head's controls stay on one line with the coarse sizes) and `deck_additions_spec.rb` (every control of the page at 44px or more).

Recorded in the specs index, both directions: spec 072's "Superseded by" gains this spec for the Non-Goal and its documents' 40px sentences. Spec 068 is not superseded (its Add a proxy rule stays; only a comment is corrected).

## User Stories

### Story 1: Every small control is a touch target

**As a** collector on a phone or a tablet
**I want** the small buttons, filter chips and the view switch to be as easy to hit as every other control
**So that** I don't miss Remove, Undo, a chip or a row's menu while aiming for the one beside it

- [ ] **AC-1.1** Given the loaded stylesheets When the coarse-pointer rules are read Then the last rule whose selector text is `.c-btn--sm, .c-filter, .c-seg button` sets `min-height` to `var(--touch-floor)` and is in a later stylesheet than `components.css`'s rule of the same selector (`additions.css`), the last rule whose selector text is `.c-btn--sm.c-btn--icon, .c-seg button` sets `min-width` to `var(--touch-floor)`, and `--touch-floor` resolves to at least 44px.
- [ ] **AC-1.2** Given each page of the audit table at 1280px and at 360px (rows 1 to 16, with an account that has a location, a deck with a proxy, a lot, more printings than a page holds, a set with two languages, a sitting with more entries than it shows, an admin with a failed and a scheduled job, and a bulk removal's message) When every coarse-pointer rule is applied (decision 4) Then every drawn small control of the page (any `.c-btn--sm`, `.c-filter` or `.c-seg button`, in `main`, in the header and in `#status`, not `.c-sr`, outside a closed `<details>` menu other than its own `summary`) is at least 44px high, every icon-only one (`.c-btn--icon`, a view-switch button with its label hidden) is at least 44px wide, and the page draws at that width each small control the table lists for it (the table says which width shows which; so a fixture that lost its controls fails, not passes).
- [ ] **AC-1.3** Given the same pages with nothing applied (a fine pointer) When the small controls with no page rule are measured (those that have no ancestor matching `.c-locations`, `.c-decks`, `.c-deckpage .c-section__actions`, `.c-numentry__list`, `.c-scanner__add`, `.c-scanner__undo` or `.c-scanner__sitting`: the rows marked `none`) Then each is under 36px high: the compact 28px is kept (a control under 36px proves the coarse rule is what raises it).
- [ ] **AC-1.4** Given each page of the audit table at 360px with every coarse-pointer rule applied and the page scrolled to the top (the filter bar is sticky) When it renders Then the page has no horizontal overflow (`scrollWidth` at most `clientWidth`), no two visible controls overlap each other by more than 1px, and no small control extends past the viewport's right edge unless it is inside the filter row, which scrolls sideways inside itself (spec 057 decision 4). Controls and visibility are measured as spec 072 AC-1.4 defines them, with `#status` and the header added.
- [ ] **AC-1.5** Given the rows `.c-filterbar`, `.c-bulkbar`, `.c-pager`, `.c-section__head`, `.c-decks__actions`, `.c-numentry__language`, `.c-jobs__filters` and the page's header, on each page that has one, at 360px and at 1280px When every coarse rule is applied once without this block's two rules and once with them Then each row has the same number of lines in both (a line is a cluster of the row's drawn controls, the AC-1.2 set plus buttons, inputs, selects and links, whose vertical extents overlap; the example counts clusters, so controls of different heights centred on one line are one line), and the `.c-filterbar` of the collection (scrolled to the top, at 360px) grows by at most 8px.
- [ ] **AC-1.6** Given the card search, the collection (grid and bulk mode) and the add-a-proxy chooser with every coarse rule applied When the filter row renders Then its small button and its select are both at least 44px and have the same vertical centre within 1px (spec 072's alignment, now between two 44px controls).
- [ ] **AC-1.7** Given each page of the audit table at 360px When every coarse rule is applied once without this block's two rules and once with them Then every control that is not a small control (`.c-btn` without `c-btn--sm`, inputs, selects, the Quantity field) has the same height and width in both. (One run, two states; a rule that grew another control fails it.)
- [ ] **AC-1.8** (the can-fail partners) Given a variant that adds a rule making every small button 90px high When AC-1.7's comparison runs Then it reports the other controls changed (it can fail); given a variant that adds `min-width:300px` to `.c-btn--sm` When AC-1.5's comparison runs on the bulk bar and on number entry's language row, both at 360px, Then a row gains a line (it can fail; the filter row is nowrap and scrolls sideways, so it can't show it); and given the page with the block's two rules removed from the injection When AC-1.2 measures Then a control is under 44px (it can fail).

### Story 2: The rule is written where the next control is built

**As a** developer, or an agent, adding a small control
**I want** the design system to say how tall a small control is on a touch screen
**So that** a new page doesn't repeat the Locations page's and the Decks pages' own 44px rule

- [ ] **AC-2.1** The README's Touch rule says every target is at least 44px on a coarse pointer, small buttons, filter chips and the view switch included, with no exception; that the compact 28px (small controls), 28px and 36px (selects) are the fine pointer's; where the rules live (`components.css`'s touch block keeps its 40px lines, overridden by `additions.css`'s block, which must stay after it, because `components.css` is the design export's file); that the filter row centres what is not 44px; and points to this spec. (Verified by reading.)
- [ ] **AC-2.2** `Button.md`, `Chip.md`, `ViewSwitch.md`, `TableActions.md`, `BulkForm.md`, `Pager.md` and `AdminJobs.md` each carry one sentence on the small control's touch size in their own words and point to the README; the 40px sentences of `FilterSelect.md` and `NumberEntry.md` are corrected. The previews load `additions.css`, so they follow the rule and change nothing. (Verified by reading.)
- [ ] **AC-2.3** The specs index has this spec's row, with spec 072 in "Supersedes" (the Non-Goal and its documents' 40px sentences) and this spec in 072's "Superseded by". (Verified by reading.)

### Story 3: Nothing else moves

**As a** maintainer
**I want** the change to be one stylesheet block and its documents
**So that** it is easy to review and nothing else changes

- [ ] **AC-3.1** `app/views/`, `app/helpers/`, `app/controllers/`, `app/models/`, `app/javascript/`, `db/`, `config/` and `lib/` are byte-for-byte unchanged, and so is every stylesheet but `additions.css`, where the diff is the new block and the two corrected comments. (Verified by the branch's diff.)
- [ ] **AC-3.2** Given the existing examples that read or measure a small control (spec 072's `select_touch_floor_spec.rb`, `deck_page_spec.rb`, `deck_proxies_spec.rb`, `card_page_spec.rb`, `deck_additions_spec.rb`, the locations and bulk-shortcut examples, `design_system_files_spec.rb`) When the suite runs Then they pass, the examples named in the Supersedes table changed as it says.

## Functional Requirements

- **FR-1.** `additions.css` gets one new block under the heading of decision 2, the two rules and the comment; the two comments of decision 2 are corrected. The block's comment may cite specs 063, 068, 072 and 075; it must not contain the strings "spec 019", "spec 021" or "spec 023", which the guards in `spec/design_system_files_spec.rb` count across the whole file.
- **FR-2.** The README's Touch rule and the component documents change as AC-2.1 and AC-2.2 say; `docs/specs/README.md` gets the row and spec 072's cell (AC-2.3).
- **FR-3.** One system spec file, `spec/system/small_controls_touch_floor_spec.rb`, proves AC-1.1 to AC-1.8 by reading the rules and measuring computed boxes on the real pages (decision 4); it fails before the CSS and passes after. The two existing examples change as the Supersedes table says. The 360px examples use `open_in_narrow_frame` (a window can't go below 500px).
- **FR-4.** No view, helper, controller, model, migration, script or export file changes.

## Non-Functional Requirements

- **Compatibility:** no migration, no schema change, export format unchanged at version 4, upgrade-safe from the previous release.
- **Hosted-door cost per account (north star rule 4):** none; a stylesheet and documents.
- **Accessibility:** larger targets for small controls on touch screens (WCAG 2.5.8's 24px minimum is met already; the design system's floor is 44px); focus ring, labels and names are unchanged.
- **Visual change:** yes, on a touch screen only; a fine pointer sees nothing. The pull request shows before and after of the affected bars at 360px (every coarse rule applied, "before" without this block) and at 1280px, in both themes, and says that headless Firefox can't draw a coarse pointer.

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| A new small control is added with the three classes | covered with no rule of its own; its page is added to the audit table by the author (README says so) |
| A new row of small controls overflows at 360px with 44px targets | AC-1.4 and AC-1.5 fail for pages in the table; the author wraps the row as the filter bar and the Locations rows do |
| A browser reports a hybrid device's primary pointer as fine | the small controls keep their compact size there, as every touch rule of the design system does; not specified further |
| A re-export of the design system restores `components.css`'s 40px lines | `additions.css` loads after it and still wins (AC-1.1 reads the order) |
| A page rule (Locations, Decks) and the new rule disagree | they can't: both are 44px; if one is edited down, AC-1.2 names the page |

## Open Questions

1. **Decision 1** (A raise all, B keep the 40px exception, C and D): the maintainer's call. Recommended A. If B, this spec is withdrawn down to a README paragraph and the audit.

## Notes for the plan

- Task 1 is the system example, written first; its red run is the current CSS. AC-1.2 and AC-1.4 to AC-1.7 each apply the block's rules through `CoarsePointer`: extend it with `except:` and `extra:` (spec 072's own example file has an `inject_coarse` that does this by selector text; hoist it into `spec/support/coarse_pointer.rb` rather than copy it, keep spec 072's file passing, document it, and make `except:` take the selector text and the stylesheet as decision 4 says) and fail by name when a rule named in `needs` is missing, as the lesson says.
- The page list is the audit table; the plan gives, for each page, the setup (the table's last column, with the widths), the small controls the example expects by their visible name or `aria-label`, and the selector. Rows that need a flow (the scanner's candidates after a reading, the status message after a bulk removal) use the helpers the existing system specs use (`scanner_adding_spec.rb`, `bulk_mode_spec.rb`); the sitting's entries are made with `Scanner::Sitting.add!`.
- The plan's "existing examples that change" step is written from a grep of `spec/` and `docs/` for `40`, `c-btn--sm`, `c-filter`, `c-seg`, `touch floor`, `pointer: coarse` and `40px` (the lesson `docs/lessons/2026-11-11-a-supersession-list-written-from-memory-misses-existing-examples.md`); the grep is named in `verification.md`. It already found spec 072's "[ 40, 90 ]" and `deck_page_spec.rb` AC-2.11.
- `deck_page_spec.rb`'s AC-2.11 example matches `selectorText` exactly, so it keeps reading `components.css`'s 40px rule and is not red by itself; its rewrite (it reads the `additions.css` rule) is what makes it test the new rule, and the plan says so.
- The admin jobs page polls while a job runs or is queued: the example stops the poll (as `admin_jobs_spec.rb` does) or measures the failed and scheduled lists. The scanner candidate needs a reading flow and "Show N more" a further click in the printings frame.
- A control's measured height includes its border: a `summary` of `c-btn--icon` measured 42px under `min-height:40px` in the probe (46px under 44). The examples compare against 44 with that in mind (at least 44, not equal), and the fine-pointer example (AC-1.3) uses "under 36px" for the same reason.
- Measure with the sticky filter bar scrolled to the top, pin the scrollbar (`html { overflow-y: scroll }`) in comparison pairs, and wait for the scanner's stage before measuring the scanner pages (spec 072's notes).
- The previews in `docs/design-system/previews/` load `additions.css` (checked by `spec/design_system_files_spec.rb`) and need no edit; the plan confirms with a grep that none hard-codes 40px.
- Run `bin/rspec spec/design_system_files_spec.rb` after the `additions.css` edit (the block counts of its guards).
- Overlap with spec 076 (#317, the gap between a `c-select` label and its select in the same filter bars) and spec 074 (#326, `TableActions` menus): this spec's CSS is its own block and its documents change by a sentence each; if a branch lands first, merge `origin/main` and keep both sides.

## Out of Scope (Future Considerations)

- The table's 20px checkboxes, the tab bar's items, inline text links and the avatar menu: other targets that are not small controls; the checkboxes are the one a later spec may raise (its row would need a label or a larger hit area, not a bigger box).
- `any-pointer` or `hover` media features for hybrid devices.
- Dropping the Locations, Decks and deck-page page rules now that a coarse pointer gets 44px by the app-wide rule: they apply at every pointer by their specs' rulings.
- The filter row's focus ring clipped at the top and bottom on a phone (`overflow-x:auto` clips vertically, `components.css`), recorded by spec 072.

## Documents that change

- `app/assets/stylesheets/collector/additions.css` (one block of two rules added, two comments corrected); one new system spec file; `spec/support/coarse_pointer.rb` (the `except:` and `extra:` options); `spec/system/select_touch_floor_spec.rb` (two examples, and its local `inject_coarse` replaced by the hoisted helper), `spec/system/deck_page_spec.rb` (one example and a comment).
- `docs/design-system/README.md` (the Touch rule), `Button.md`, `Chip.md`, `ViewSwitch.md`, `TableActions.md`, `BulkForm.md`, `Pager.md`, `AdminJobs.md`, `FilterSelect.md`, `NumberEntry.md`.
- `docs/specs/README.md`: this spec's row and spec 072's "Superseded by".
- No area doc: the design system's rules are its README and component documents (specs 057, 060, 063, 072); no ADR: the ruling is decision 1 here.
- Left as history, not edited: spec 072 and its `verification.md`, spec 068.
