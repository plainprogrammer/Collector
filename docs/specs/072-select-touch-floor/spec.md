# Feature 072: Selects Meet the Touch Floor on a Coarse Pointer, App-Wide

**Status:** Approved by the coordinator under the maintainer's delegation (2026-11-11, Gate A) at 0.3.0, after two spec review rounds
**Version:** 0.3.1
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 068](../068-deck-proxies/spec.md) (AC-9.1 lifted the deck pages' selects only and left the rest of the app out of scope; this is its follow-up), [spec 057](../057-deck-design-rules/spec.md) (the grouped selects and the filter bar's select), all merged
**Branch:** `072-select-touch-floor`
**Issue:** [#315](https://github.com/plainprogrammer/Collector/issues/315) (design-system lane, filed by the maintainer's ruling from spec 068's implementation review)
**Frozen:** the current rules are in [`design-system/README.md`](../../design-system/README.md) (whole spec); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.1 | 2026-11-11 | Patch from the implementation review (Mode B, minor m1): AC-1.4's definition of a visible control adds the two clauses the examples need, controls inside a closed `<details>` menu other than its own `summary` (Firefox keeps a layout box for a closed menu's items, which overlapped the table under it) and that controls are measured within `main`; no behaviour changes |
| 0.3.0 | 2026-11-11 | Spec review round 2 (Opus, read-only; REVISE: 0 blocking, 0 major, 4 minor, 5 nit), all taken: AC-1.5 gains bulk mode; AC-2.2 asks `FilterSelect.md` for the centring sentence; notes for the plan on the `c-select` label's height (with a fallback) and on measurement mode's manifest; Story 3's wording; the README's second `bundle.css` mention; `.c-sr` controls in AC-1.4; source-order injection; the filter row's clipped focus ring recorded as out of scope |
| 0.2.0 | 2026-11-11 | Spec review round 1 (Opus, read-only; REVISE: 5 major, 4 minor, 3 nit), all taken: the audit gains the Currency page and loses Edit a proxy, which has no select, and row 5 gains Finish; the layout examples inject every coarse-pointer rule, not the select rule alone (decision 3), and AC-1.7 compares two states so it can fail; the filter row's controls are centred by a coarse-pointer alignment rule of the same block, which the review found missing (decision 2, AC-1.5); AC-1.4 defines visible and container; `components.css` is named as an alternative; the README's stale `bundle.css` is corrected; FilterSelect's "Used by" is corrected; FR-1's spec-number rule is exact |
| 0.1.0 | 2026-11-11 | First draft from issue #315 and the audit below. Routing: the change is a design-system rule, so it is a spec, not a direct fix |

## Problem Statement

On a touch screen every other control of the app reaches the design system's 44px touch floor (`.c-btn`, `.c-input` and `.c-menu__item` at 44px, the small buttons, chips and the view switch at 40px: the README's Touch rule), and a select does not. A select is drawn at one of two heights, by which of two component classes wraps it:

| Shape | Class | Height at a fine pointer | Height on a coarse pointer (today) |
|---|---|---|---|
| A field in a form | `.c-field select` | 36px | 36px (no coarse rule) |
| A control in the filter bar and the number-entry language row | `.c-select select` | 28px | 40px (`@media (pointer: coarse) { .c-select select { min-height:40px } }`) |

Spec 068 (#254, AC-9.1) found this on the deck pages, where "every control is at least 44px on a coarse pointer" was an acceptance criterion, and lifted the selects of `.c-decks` pages only (`@media (pointer: coarse) { .c-decks .c-select select, .c-decks .c-field select { min-height:var(--touch-floor) } }`, under its own heading in `additions.css`). Its own words were that raising the floor app-wide was out of scope and a possible follow-up; the maintainer filed this issue for it on 2026-11-11. So today the same Set select is 44px on the add-a-proxy chooser and 40px on the card search, and the Location select of the lot form, Move copies, bulk Move to…, number entry and the scanner's sitting is 36px on a phone.

> **Terms.** The *touch floor* is `--touch-floor`, 44px (`additions.css`). A *select* is a native `<select>` element, drawn by `c-field` or `c-select`. A *coarse pointer* is a touch screen, the CSS media feature `(pointer: coarse)`. A *fine pointer* is a mouse or a trackpad.

### Audit: every page with a select (2026-11-11)

Built from a search of `app/` for `<select`, `form.select`, `f.select`, `select_tag`, `collection_select`, `grouped_collection_select` and `c-select` (the exact command is in `verification.md`). Twelve pages draw a select, and the card page's "Add to deck" page (`AddToDeck.md`) will (it is not built yet; its `c-field` select takes the rule when it is). No other view does. The issue's list names "import, admin" among the forms, but neither draws a select (the import's preview page and the admin pages have buttons and text fields only).

| # | Page (route) | Select | Shape | Notes |
|---|---|---|---|---|
| 1 | Card search (`/catalog/entries`; the open catalog too) | Set | `c-select` | in the filter bar |
| 2 | Collection (`/collection`, and its bulk mode) | Location (`c-select--wide`) | `c-select` | in the filter bar, shown while the account has a location; on a phone the bar's filter row scrolls sideways (spec 057 decision 4) |
| 3 | Add by number (`/collection/number_entry`) | Language | `c-select` | a row with the "Change language" button, when the set has more than one language |
| 4 | Add by number (same page) | Finish, Location | `c-field` | in the line form, a grid of four columns, two below 640px |
| 5 | Add a copy (`/catalog/entries/:key/lots/new`) and Edit copy (`/lots/:id/edit`) | Finish (when the printing lists finishes), Condition, Location | `c-field` | one form |
| 6 | Move copies (`/lots/:id/move/new`) | To | `c-field` | |
| 7 | Move to… in bulk mode (`/collection/move/new`) | To | `c-field` | |
| 8 | Scanner (`/scanner`) | Condition, Location of the sitting | `c-field` | in the sitting's form |
| 9 | New deck (`/decks/new`), Change format (`/decks/:id/format/edit`) | Format | `c-field` | the deck pages |
| 10 | Add a proxy, the chooser (`/decks/:id/zones/:zone/proxies/new?q=…`) | Set | `c-select` | in the filter bar |
| 11 | Add a proxy, the form (`…/proxies/new?entry=…`) | Finish | `c-field` | Edit a proxy has a Quantity field only |
| 12 | Currency (`/currency/edit`) | Currency | `c-field` | |
| dev | Scanner measurement mode (`/scanner/measurement`; development only, 404 elsewhere) | Card to capture | `c-field` | the rule reaches it by its class; the examples visit it with measurement mode on |

Another fact the audit found: `.c-filterbar__filters` has no `align-items`, so its children use the default `stretch`; a `c-btn--sm` has an explicit height and does not stretch, so beside a taller select it would sit at the top of the row (decision 2).

Existing rule hits (a grep of `app/assets/stylesheets/` for `select` and `pointer`): `.c-field select` (36px), `.c-select select` (28px) and its coarse rule (40px), the grouped-select rules (`optgroup`, `option`), `c-select--wide`'s cap, and the `.c-decks` coarse rule. Spec 068's example `spec/system/deck_proxies_spec.rb` ("lifts the chooser's Set select and the form's Finish select to the touch floor on a coarse pointer (AC-9.1)") reads that last rule by its selectors.

## Goals

- On a touch screen every select of the app is at least 44px high, as every other control is.
- A fine pointer keeps today's heights: the filter bar's compact 28px row on a desktop and the forms' 36px stay.
- The design system states the rule where the next select is built, in its README and the select components' documents, and one CSS rule carries it.
- No page with a select overflows at 360px, no control on it overlaps another, and a filter row's controls stay centred on one line, on a coarse pointer.

## Non-Goals

- Changing the small buttons, chips and the view switch (40px on a coarse pointer, the README's Touch rule): a `c-btn--sm` beside a 44px select stays 40px and is centred against it. Raising them is a separate design-system ruling.
- Changing a select's width, caps, options, grouping or markup (spec 057 decisions 4 and 18 stand: `c-select--wide`'s 300px, 220px elsewhere, 100% of a form).
- Making the open list of options larger: the browser or the phone draws it.
- Changing a fine pointer's heights, or a hybrid device's: the rule keys on `(pointer: coarse)`, the primary pointer, as every touch rule of the design system does.
- Any view, helper, controller, model, migration or export change.

## Decisions

### 1. One coarse-pointer rule gives both select shapes the touch floor (proposed; the issue's outcome)

| | A. One rule on both shapes, `min-height: var(--touch-floor)` on a coarse pointer (proposed) | B. Every select at 44px at every pointer | C. Per-page scoping, as spec 068 did | D. A bare `select` element rule | E. The same rule in `components.css`'s Touch block |
|---|---|---|---|---|---|
| Fine pointer | unchanged (36px, 28px) | all selects 44px: the filter bar's compact row is lost on a desktop (the issue keeps it) | unchanged | unchanged | unchanged |
| A page added later | covered when its select is `c-field` or `c-select`, the only two shapes the design system documents | covered | needs its own scope class | covered, even a select outside both shapes | covered |
| Selectors | `.c-field select, .c-select select` | | one per page class | `select` | as A |
| Reads like the rest of the design system | yes: it names the components, as `.c-field select` and `.c-select select` do | | | an element selector the design system doesn't otherwise use | the place every other coarse rule is, but `components.css` is the design export's file and the app's additions go in `additions.css` (spec 063 decision 2; `.c-field select` and `.c-select select`'s own heights are already there) |

`min-height`, not `height`: the rule only raises a select that is shorter, which is what spec 068's rule and `.c-btn, .c-input { min-height:44px }` do. The value is `var(--touch-floor)`, the token `additions.css` already defines for every 44px rule, not a literal. *Alternative D* is simpler still; it is not proposed because the design system names components, and a select outside `c-field` and `c-select` would be drawn with the browser's own styling, a violation worth finding: AC-1.2's example fails a page whose select is in neither shape, so the next one is found when its page is added to the list.

### 2. The rules have one block of their own in `additions.css`; two earlier rules go

The new block, `/* ---------- Selects meet the touch floor on a coarse pointer (spec 072) ---------- */`, holds two rules, both inside `@media (pointer: coarse)`: the select rule of decision 1, and `.c-filterbar__filters { align-items:center }`. The second is needed because the filter row's children use the default `stretch` and a `c-btn--sm` (40px on a coarse pointer, an explicit height) does not stretch: beside a 44px select it would sit at the top of the row, 4px short at the bottom. It applies on a coarse pointer only, so a fine pointer's rows are not touched. The block's comment gives the why (the two shapes' heights, the fine pointer's compact rows kept, the headless-Firefox limit, where the rule is documented). Two rules it makes redundant are deleted in the same change: the `.c-select` coarse rule's 40px (in the filter bar's select block) and the whole block "Deck pages' selects (spec 068 AC-9.1)". The first is raised, not kept beside the new one: two coarse rules for one property, one lower, is the trap the lesson of spec 068 names.

### 3. The examples read the rule and apply it, because headless Firefox can't emulate a coarse pointer

An example reads the coarse-pointer rule from the loaded stylesheets (its selectors, its `min-height`, the resolved `--touch-floor`). Two injections follow, each a `<style>` the example adds with the media wrapper removed: **the select rule alone** (AC-1.2: proves the rule's selectors reach every select of the list, and that nothing else is needed to make each at least 44px), and **every rule inside every `@media (pointer: coarse)` block of the loaded stylesheets** (AC-1.4, AC-1.5, AC-1.7: the layout a touch screen draws, with the buttons at 40px and 44px, the text fields at 44px and the selects at 44px together, not the mix of a fine pointer's buttons and a coarse pointer's selects, which no device draws). A fine pointer's heights are measured with nothing injected (lesson `docs/lessons/2026-11-11-every-control-at-44px-needs-a-list-of-controls-and-the-rule-that-covers-each.md`). This is the example spec 068 AC-9.1 wrote for the deck pages, widened to the list above.

## Supersedes

| Document | What it says | What changes |
|---|---|---|
| [Spec 068](../068-deck-proxies/spec.md) AC-9.1, its verification's note "raising the select floor app-wide is out of scope" and the `.c-decks` coarse rule it shipped (`additions.css`, heading "Deck pages' selects") | the deck pages' selects reach the floor by a rule scoped to `.c-decks` | the criterion stands (every control of the four proxy pages is at least 44px on a coarse pointer); the rule that meets it for selects is now the app-wide one, and the scoped rule is deleted. The example that reads it (`spec/system/deck_proxies_spec.rb`, "lifts the chooser's Set select …") is rewritten to read the new rule |
| `docs/design-system/components/DecksIndex.md`, the bullet "Selects take the touch floor on a coarse pointer" | "selects elsewhere keep the design system's own heights" | the bullet points to the app-wide rule in `Form` and `FilterSelect` and keeps no scoped rule |
| `docs/design-system/components/FilterSelect.md` | "on touch screens it grows to at least 40px" | at least 44px (the touch floor) |
| `docs/design-system/README.md`, Touch rule | "On touch devices every target is at least 44px (40px for small buttons, chips and the view switch)" | the sentence names selects: 44px on a coarse pointer, their compact 28px (filter bar) and 36px (form) kept at a fine one |

Recorded in the specs index, in both directions. Spec 068 is frozen and is not edited.

## User Stories

### Story 1: Every select is a touch target

**As a** collector on a phone or a tablet
**I want** every select to be as easy to hit as a button
**So that** I don't miss the Location or Set control I'm aiming for

- [ ] **AC-1.1** Given the app's stylesheets as loaded on a page When the rules inside `@media (pointer: coarse)` are read Then exactly one of them sets `min-height` on a select, its selectors are `.c-field select` and `.c-select select`, its `min-height` is `var(--touch-floor)` and `--touch-floor` resolves to at least 44px (no other coarse-pointer rule gives either selector a `min-height`, so the old 40px is gone).
- [ ] **AC-1.2** Given each page of the audit table (the twelve pages and measurement mode, with an account that has a location and a deck, a set with two languages, and a lot) When the select rule of AC-1.1 alone is applied unconditionally (decision 3) Then every select on the page is at least 44px high as drawn, the page has at least one select, and every select on it is inside a `.c-field` or a `.c-select`.
- [ ] **AC-1.3** Given the same pages with nothing injected (a fine pointer) When the selects are measured Then each `c-field` select is 36px high and each `c-select` select is 28px high, as before the change.
- [ ] **AC-1.4** Given each page of the audit table at 360px with every coarse-pointer rule applied (decision 3) and the page scrolled to the top (the filter bar is sticky) When it renders Then the page has no horizontal overflow (`document.documentElement.scrollWidth` is at most the viewport width), no select is wider than its container (the nearest `.c-form`, `.c-numentry__line`, `.c-filterbar__filters` or `main`, whichever is nearest), and no two visible controls of the page (select, input, button, link button) overlap each other by more than 1px. Controls are measured within `main`. A control is visible when it is not a `.c-sr` (visually hidden) control, is not inside a closed `<details>` other than that menu's own `summary` (Firefox keeps a layout box for a closed menu's items), its box has a non-zero area and intersects the visible box of its nearest scrolling ancestor, except that a control of the filter row (spec 057 decision 4: the row scrolls sideways inside itself on a phone) is only required to overlap no other. The page itself does not scroll sideways.
- [ ] **AC-1.5** Given the collection page (an account with a location) in its list view and in bulk mode, the card search and the add-a-proxy chooser at 1280px and at 360px, with every coarse-pointer rule applied When the filter bar renders Then the filter row's select and its button have the same vertical centre within 1px (the 44px select beside the 40px small button), and no two controls overlap.
- [ ] **AC-1.6** Given `additions.css` When it is read Then no rule's selector contains `.c-decks` together with `select`, and the filter bar's select block has no coarse-pointer rule.
- [ ] **AC-1.7** Given each page of the audit table When it renders twice with every coarse-pointer rule applied, once with the new block's two rules removed from the injection and once with them Then every control that is not a select (button, link button, text field, chip, the Quantity field) has the same height and width in both. (One run, two states: it needs no fixture, and a rule or a flex stretch that grew another control would fail it; the rules of AC-1.1 and the alignment rule are the only difference.)

### Story 2: The rule is written where the next select is built

**As a** developer, or an agent, adding a select
**I want** the design system to say how tall a select is on a touch screen
**So that** a new page doesn't repeat spec 068's find in review

- [ ] **AC-2.1** The README's Touch rule (its sentence "`bundle.css` handles this with `pointer: coarse`" and the later mention of `components/bundle.css` are corrected to name `components.css` and `additions.css`, where the coarse rules are) says a select is at least 44px on a coarse pointer, that its compact heights (28px in the filter bar, 36px in a form) are the fine pointer's, where the rule lives (`additions.css`, one block) and that it covers `c-field` and `c-select` selects; it points to this spec. (Verified by reading.)
- [ ] **AC-2.2** `Form.md` and `FilterSelect.md` state the rule in their own words ("Selects get the same height…" and "on touch screens it grows to at least 40px" are corrected, `FilterSelect.md` gains one sentence that on a coarse pointer the filter row centres its controls (a 44px select beside a 40px small button), and FilterSelect's "Used by" list gains the add-a-proxy chooser's Set and number entry's Language), `DecksIndex.md`'s bullet is replaced as the Supersedes table says, and `AddProxy.md`, `AddToDeck.md`, `NumberEntry.md` and `Scanner.md`, which draw selects, each carry one sentence pointing to `Form` or `FilterSelect` for the touch floor. (Verified by reading; the six previews that draw a select, `AddProxy`, `AddProxyPhone`, `AddToDeck`, `AddToDeckPhone`, `NewDeck` and `NewDeckPhone`, already load `additions.css`, so they follow the rule and change nothing.)
- [ ] **AC-2.3** The specs index has this spec's row, with spec 068 in "Supersedes" (AC-9.1's select rule) and this spec in 068's "Superseded by". (Verified by reading.)

### Story 3: Nothing else moves

**As a** maintainer
**I want** the change to be one stylesheet block and its documents
**So that** it is easy to review and nothing else changes

- [ ] **AC-3.1** `app/views/`, `app/helpers/`, `app/controllers/`, `app/models/`, `db/` and `config/` are byte-for-byte unchanged, and so is every stylesheet but `additions.css`. (Verified by the branch's diff.)
- [ ] **AC-3.2** Given spec 068's AC-9.1 example When the suite runs Then it reads the app-wide rule (not `.c-decks`) and passes, and the width examples of spec 068 for the four proxy pages and spec 064's Change format page still pass.

## Functional Requirements

- **FR-1.** `additions.css` gets one new block, under the heading of decision 2, with the two rules of decision 2 and its comment. The block's comment may cite specs 057, 068 and 072 for the why; it must not contain the strings "spec 019", "spec 021" or "spec 023", which the guards in `spec/design_system_files_spec.rb` count across the whole file. The `.c-decks` block and the filter bar's 40px coarse rule are deleted.
- **FR-2.** The README's Touch rule, `Form.md`, `FilterSelect.md`, `DecksIndex.md`, `AddProxy.md`, `AddToDeck.md`, `NumberEntry.md`, `Scanner.md` change as AC-2.1 and AC-2.2 say; `docs/specs/README.md` gets the row (AC-2.3).
- **FR-3.** One system spec file proves AC-1.1 to AC-1.7 by reading the rules and measuring computed styles and boxes on the real pages (decision 3); it fails before the CSS and passes after. Spec 068's example is rewritten (AC-3.2). The 360px examples use `open_in_narrow_frame` where a window can't be that narrow (headless Firefox's windows stop at 500px).
- **FR-4.** No view, helper, controller, model, migration or export file changes.

## Non-Functional Requirements

- **Compatibility:** no migration, no schema change, export format unchanged at version 4, upgrade-safe from the previous release.
- **Hosted-door cost per account (north star rule 4):** none; a stylesheet and documents.
- **Accessibility:** a larger target for a select on touch screens (WCAG 2.5.8's 24px minimum is met already; the design system's floor is 44px); focus ring, labels and names are unchanged.
- **Visual change:** yes, on a touch screen only. A fine pointer sees nothing. Before and after shots of one `c-select` (the card search's Set) and one `c-field` select (the lot form's Location) are not possible on a coarse pointer in headless Firefox; the pull request shows both selects with the rule applied (decision 3's injection), light and dark, at 360px, and says so.

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| A select is added outside `c-field` and `c-select` | AC-1.2's "inside `.c-field` or `.c-select`" fails for any page in the list; a page not in the list is found by the audit grep when the author adds it (the README's Touch rule says where to put the page) |
| A new `c-select` row at 360px overflows with a 44px select | AC-1.4 fails for pages in the list; the author wraps the row as the filter bar does (the filter row scrolls sideways) |
| A browser reports a hybrid device's primary pointer as fine | The select keeps its compact height there, as every touch rule of the design system does; not specified further |
| An option of a select is long (a location's name) | The width rule is unchanged: the closed select clips (spec 040 AC-7.1, spec 057), and a taller box shows the same text |

## Open Questions

None.

## Notes for the plan

- Task 1 is the system example, written first. Its red run is the current CSS: AC-1.1 finds the `.c-decks` rule and the 40px rule and no rule with the new selectors, and AC-1.2 to AC-1.5, which apply that rule, fail for the same reason (there is no rule to apply), so each example reads the rule before it uses it and says so in its failure message. Read the rule with the technique spec 068's example used (`document.styleSheets`, `CSSMediaRule`, `conditionText.includes("pointer: coarse")`) and apply it by building a `<style>` from the rule's `cssText` with the media wrapper removed.
- The page list is the audit table; the plan lists, for each page, the setup the example needs (an account with a location and a deck with a zone for the pages above, a printing with a second language for number entry's language row, a lot for Edit copy and Move copies, a selection for bulk Move to…, `Rails.configuration.x.scanner_measurement` set for the dev page as `spec/requests/footer_spec.rb` does) and the select's id or label.
- The plan's "existing examples that change" step is written from a grep of `spec/` and `docs/` for `c-decks .c-select`, `c-decks .c-field`, `40px`, `pointer: coarse` and "touch floor" (the lesson `docs/lessons/2026-11-11-a-supersession-list-written-from-memory-misses-existing-examples.md`); the grep is named in `verification.md`.
- AC-1.7 is one run with two injections of the same page (decision 3): the controls' boxes are recorded after injecting every coarse rule except the new block's two, then after injecting those too, and compared. Its failure case is written first: a variant that injects a stretch (`align-items:stretch`) or a taller rule must make it fail, so the plan's task includes the mutation check the lesson `an-example-that-cannot-fail-proves-nothing` asks for.
- Inject the coarse rules in source order, as one `<style>` (a later rule of equal specificity then beats an earlier one as it does in the files).
- `c-select` is a plain `label` with no rule of its own; `align-items:center` centres the label, so the first green run confirms the label is as tall as its select (AC-1.5 fails if not). If it isn't, the fallback is `.c-filterbar__filters .c-select { display:flex }` in the same coarse block, which keeps AC-3.1 true; decide it then and record it in `verification.md`.
- Measurement mode draws its select only with a valid manifest and run directory (`app/views/scanner/measurements/show.html.erb`): `scanner_measurement` alone shows the "can't start" message. The example sets `Rails.configuration.x.scanner_measurement` with a temporary manifest and run directory, reusing the existing measurement specs' helper.
- Measure with the sticky filter bar scrolled to the top, and note that headless Firefox's windows stop at 500px: the 360px examples use `open_in_narrow_frame`, so a page's own `main` is measured inside the frame.
- Run `bin/rspec spec/design_system_files_spec.rb` after the `additions.css` edit (the block counts of its guards).

## Out of Scope (Future Considerations)

- Raising the small buttons, chips and the view switch to 44px on a coarse pointer: a design-system ruling of its own.
- Raising the open option list's rows, which the browser or the phone draws.
- `any-pointer` or `hover` media features for hybrid devices.
- The filter row's focus ring clipped at the top and bottom on a phone (`overflow-x:auto` clips vertically, `components.css`): it is so at 28px and 40px today, and a taller select doesn't change it.

## Documents that change

- `app/assets/stylesheets/collector/additions.css` (one block of two rules added, two rules deleted); one new system spec file; `spec/system/deck_proxies_spec.rb` (one example rewritten).
- `docs/design-system/README.md` (the Touch rule), `Form.md`, `FilterSelect.md`, `DecksIndex.md`, `AddProxy.md`, `AddToDeck.md`, `NumberEntry.md`, `Scanner.md`.
- `docs/specs/README.md`: this spec's row and spec 068's "Superseded by".
- No area doc: the design system's rules are its README and component documents (specs 057, 060, 063); no ADR: the ruling is decision 1 here.
- Left as history, not edited: spec 068 and its `verification.md`.
