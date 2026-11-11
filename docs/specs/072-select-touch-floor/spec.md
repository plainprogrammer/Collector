# Feature 072: Selects Meet the Touch Floor on a Coarse Pointer, App-Wide

**Status:** Draft
**Version:** 0.1.0
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 068](../068-deck-proxies/spec.md) (AC-9.1 lifted the deck pages' selects only and left the rest of the app out of scope; this is its follow-up), [spec 057](../057-deck-design-rules/spec.md) (the grouped selects and the filter bar's select), all merged
**Branch:** `072-select-touch-floor`
**Issue:** [#315](https://github.com/plainprogrammer/Collector/issues/315) (design-system lane, filed by the maintainer's ruling from spec 068's implementation review)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
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

Built from a search of `app/` for `<select`, `form.select`, `select_tag`, `collection_select` and `c-select` (the grep is named in `verification.md`). Eleven pages draw a select; no other view does. The issue's list names "import, admin" among the forms, but neither draws a select (the import's preview page and the admin pages have buttons and text fields only).

| # | Page (route) | Select | Shape | Notes |
|---|---|---|---|---|
| 1 | Card search (`/catalog/entries`; the open catalog too) | Set | `c-select` | in the filter bar |
| 2 | Collection (`/collection`, and its bulk mode) | Location (`c-select--wide`) | `c-select` | in the filter bar, shown while the account has a location; on a phone the bar's filter row scrolls sideways (spec 057 decision 4) |
| 3 | Add by number (`/collection/number_entry`) | Language | `c-select` | a row with the "Change language" button, when the set has more than one language |
| 4 | Add by number (same page) | Finish, Location | `c-field` | in the line form, a grid of four columns, two below 640px |
| 5 | Add a copy (`/catalog/entries/:key/lots/new`) and Edit copy (`/lots/:id/edit`) | Condition, Location | `c-field` | one form |
| 6 | Move copies (`/lots/:id/move/new`) | To | `c-field` | |
| 7 | Move to… in bulk mode (`/collection/move/new`) | To | `c-field` | |
| 8 | Scanner (`/scanner`) | Condition, Location of the sitting | `c-field` | in the sitting's form |
| 9 | New deck (`/decks/new`), Change format (`/decks/:id/format/edit`) | Format | `c-field` | the deck pages |
| 10 | Add a proxy, the chooser (`/decks/:id/zones/:zone/proxies/new?q=…`) | Set | `c-select` | in the filter bar |
| 11 | Add a proxy, the form (`…/proxies/new?entry=…`) and Edit a proxy (`/decks/:deck_id/proxies/:id/edit`) | Finish | `c-field` | |
| dev | Scanner measurement mode (`/scanner/measurement`; development only, 404 elsewhere) | Card to capture | `c-field` | the rule reaches it by its class; the examples visit it with measurement mode on |

Existing rule hits (a grep of `app/assets/stylesheets/` for `select` and `pointer`): `.c-field select` (36px), `.c-select select` (28px) and its coarse rule (40px), the grouped-select rules (`optgroup`, `option`), `c-select--wide`'s cap, and the `.c-decks` coarse rule. Spec 068's example `spec/system/deck_proxies_spec.rb` ("lifts the chooser's Set select and the form's Finish select to the touch floor on a coarse pointer (AC-9.1)") reads that last rule by its selectors.

## Goals

- On a touch screen every select of the app is at least 44px high, as every other control is.
- A fine pointer keeps today's heights: the filter bar's compact 28px row on a desktop and the forms' 36px stay.
- The design system states the rule where the next select is built, in its README and the select components' documents, and one CSS rule carries it.
- No page with a select overflows at 360px, and no control on it overlaps another, on a coarse pointer.

## Non-Goals

- Changing the small buttons, chips and the view switch (40px on a coarse pointer, the README's Touch rule): a `c-btn--sm` beside a 44px select stays 40px and is centred against it. Raising them is a separate design-system ruling.
- Changing a select's width, caps, options, grouping or markup (spec 057 decisions 4 and 18 stand: `c-select--wide`'s 300px, 220px elsewhere, 100% of a form).
- Making the open list of options larger: the browser or the phone draws it.
- Changing a fine pointer's heights, or a hybrid device's: the rule keys on `(pointer: coarse)`, the primary pointer, as every touch rule of the design system does.
- Any view, helper, controller, model, migration or export change.

## Decisions

### 1. One coarse-pointer rule gives both select shapes the touch floor (proposed; the issue's outcome)

| | A. One rule on both shapes, `min-height: var(--touch-floor)` on a coarse pointer (proposed) | B. Every select at 44px at every pointer | C. Per-page scoping, as spec 068 did | D. A bare `select` element rule |
|---|---|---|---|---|
| Fine pointer | unchanged (36px, 28px) | all selects 44px: the filter bar's compact row is lost on a desktop (the issue keeps it) | unchanged | unchanged |
| A page added later | covered when its select is `c-field` or `c-select`, the only two shapes the design system documents | covered | needs its own scope class | covered, even a select outside both shapes |
| Selectors | `.c-field select, .c-select select` | | one per page class | `select` |
| Reads like the rest of the design system | yes: it names the components, as `.c-field select` and `.c-select select` do | | | an element selector the design system doesn't otherwise use |

`min-height`, not `height`: the rule only raises a select that is shorter, which is what spec 068's rule and `.c-btn, .c-input { min-height:44px }` do. The value is `var(--touch-floor)`, the token `additions.css` already defines for every 44px rule, not a literal. *Alternative D* is simpler still; it is not proposed because the design system names components, and a select outside `c-field` and `c-select` would be drawn with the browser's own styling, a violation worth finding: AC-1.2's example fails a page whose select is in neither shape, so the next one is found when its page is added to the list.

### 2. The rule has one block of its own in `additions.css`; two earlier rules go

The new block, `/* ---------- Selects meet the touch floor on a coarse pointer (spec 072) ---------- */`, holds the one rule with a comment giving the why (the two shapes' heights, the fine pointer's compact rows kept, the headless-Firefox limit, where the rule is documented). Two rules it makes redundant are deleted in the same change: the `.c-select` coarse rule's 40px (in the filter bar's select block) and the whole block "Deck pages' selects (spec 068 AC-9.1)". The first is raised, not kept beside the new one: two coarse rules for one property, one lower, is the trap the lesson of spec 068 names.

### 3. The examples read the rule and apply it, because headless Firefox can't emulate a coarse pointer

An example reads the coarse-pointer rule from the loaded stylesheets (its selectors, its `min-height`, the resolved `--touch-floor`), then applies the same declarations unconditionally in a `<style>` it adds to the page, and measures the selects as drawn: at least 44px, and the page's layout at 360px. Reading proves the rule exists with the floor; applying it proves it reaches every select of the list and shows what a coarse pointer would draw. A fine pointer's heights are measured with nothing injected (lesson `docs/lessons/2026-11-11-every-control-at-44px-needs-a-list-of-controls-and-the-rule-that-covers-each.md`). This is the example spec 068 AC-9.1 wrote for the deck pages, widened to the list above.

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
- [ ] **AC-1.2** Given each page of the audit table (the eleven pages and measurement mode, with an account that has a location and a deck, a set with two languages, and a lot) When the rule of AC-1.1 is applied unconditionally (decision 3) Then every select on the page is at least 44px high as drawn, the page has at least one select, and every select on it is inside a `.c-field` or a `.c-select`.
- [ ] **AC-1.3** Given the same pages with nothing injected (a fine pointer) When the selects are measured Then each `c-field` select is 36px high and each `c-select` select is 28px high, as before the change.
- [ ] **AC-1.4** Given each page of the audit table at 360px with the rule applied (decision 3) When it renders Then the page has no horizontal overflow, no select is wider than its container, and no two visible controls of the page (select, input, button, link button) overlap each other by more than 1px. (The filter bar's filter row on a phone scrolls sideways inside itself, spec 057 decision 4; the page does not.)
- [ ] **AC-1.5** Given the collection page and the card search at 1280px with the rule applied When the filter bar renders Then the select and the bar's other controls are centre-aligned on one row (the select, 44px, beside the 40px small buttons), with no overlap.
- [ ] **AC-1.6** Given `additions.css` When it is read Then no rule's selector contains `.c-decks` together with `select`, and the filter bar's select block has no coarse-pointer rule.
- [ ] **AC-1.7** Given a fine pointer and the pages of the audit table When they render Then the page's controls other than selects are exactly as tall as before the change (a button, a text field, the filter bar's chips), so the one rule changes only selects.

### Story 2: The rule is written where the next select is built

**As a** developer, or an agent, adding a select
**I want** the design system to say how tall a select is on a touch screen
**So that** a new page doesn't repeat spec 068's find in review

- [ ] **AC-2.1** The README's Touch rule says a select is at least 44px on a coarse pointer, that its compact heights (28px in the filter bar, 36px in a form) are the fine pointer's, where the rule lives (`additions.css`, one block) and that it covers `c-field` and `c-select` selects; it points to this spec. (Verified by reading.)
- [ ] **AC-2.2** `Form.md` and `FilterSelect.md` state the rule in their own words ("Selects get the same height…" and "on touch screens it grows to at least 40px" are corrected), `DecksIndex.md`'s bullet is replaced as the Supersedes table says, and `AddProxy.md`, `AddToDeck.md`, `NumberEntry.md` and `Scanner.md`, which draw selects, each carry one sentence pointing to `Form` or `FilterSelect` for the touch floor. (Verified by reading; the six previews that draw a select, `AddProxy`, `AddProxyPhone`, `AddToDeck`, `AddToDeckPhone`, `NewDeck` and `NewDeckPhone`, already load `additions.css`, so they follow the rule and change nothing.)
- [ ] **AC-2.3** The specs index has this spec's row, with spec 068 in "Supersedes" (AC-9.1's select rule) and this spec in 068's "Superseded by". (Verified by reading.)

### Story 3: Nothing else moves

**As a** maintainer
**I want** the change to be one stylesheet rule and its documents
**So that** it is easy to review and nothing else changes

- [ ] **AC-3.1** `app/views/`, `app/helpers/`, `app/controllers/`, `app/models/`, `db/` and `config/` are byte-for-byte unchanged, and so is every stylesheet but `additions.css`. (Verified by the branch's diff.)
- [ ] **AC-3.2** Given spec 068's AC-9.1 example When the suite runs Then it reads the app-wide rule (not `.c-decks`) and passes, and the width examples of spec 068 for the four proxy pages and spec 064's Change format page still pass.

## Functional Requirements

- **FR-1.** `additions.css` gets one new block, under the heading of decision 2, with the one rule of AC-1.1 and its comment. The comment names no spec number but 072 (the guards in `spec/design_system_files_spec.rb` count other specs' numbers across the whole file) and the rule is its only content. The `.c-decks` block and the filter bar's 40px coarse rule are deleted.
- **FR-2.** The README's Touch rule, `Form.md`, `FilterSelect.md`, `DecksIndex.md`, `AddProxy.md`, `AddToDeck.md`, `NumberEntry.md`, `Scanner.md` change as AC-2.1 and AC-2.2 say; `docs/specs/README.md` gets the row (AC-2.3).
- **FR-3.** One system spec file proves AC-1.1 to AC-1.7 by reading the rule and measuring computed styles and boxes on the real pages (decision 3); it fails before the CSS and passes after. Spec 068's example is rewritten (AC-3.2). The 360px examples use `open_in_narrow_frame` where a window can't be that narrow (headless Firefox's windows stop at 500px).
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
- AC-1.7 measures every other control on the pages before and after: a fine pointer renders them with the same rules, so the example compares computed `height` of each control with the values read from a run of the same example on `main`, or asserts the known heights (button 36px, `c-btn--sm` 28px, `c-input` 36px) as `components.css` states them; the plan picks the second, which has no fixture to keep.
- Run `bin/rspec spec/design_system_files_spec.rb` after the `additions.css` edit (the block counts of its guards).

## Out of Scope (Future Considerations)

- Raising the small buttons, chips and the view switch to 44px on a coarse pointer: a design-system ruling of its own.
- Raising the open option list's rows, which the browser or the phone draws.
- `any-pointer` or `hover` media features for hybrid devices.

## Documents that change

- `app/assets/stylesheets/collector/additions.css` (one block added, two rules deleted); one new system spec file; `spec/system/deck_proxies_spec.rb` (one example rewritten).
- `docs/design-system/README.md` (the Touch rule), `Form.md`, `FilterSelect.md`, `DecksIndex.md`, `AddProxy.md`, `AddToDeck.md`, `NumberEntry.md`, `Scanner.md`.
- `docs/specs/README.md`: this spec's row and spec 068's "Superseded by".
- No area doc: the design system's rules are its README and component documents (specs 057, 060, 063); no ADR: the ruling is decision 1 here.
- Left as history, not edited: spec 068 and its `verification.md`.
