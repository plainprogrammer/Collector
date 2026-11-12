# Feature 078: A Mana Bar Label Fits Its Segment or Isn't Drawn

**Status:** Draft (awaiting spec review and Gate A); the approach, D1, was ruled by the maintainer on 2026-11-12 (decision 1)
**Version:** 0.1.0
**Created:** 2026-11-12
**Last Updated:** 2026-11-12
**Depends on:** [spec 077](../077-deck-shape-extreme-counts/spec.md) (the abbreviation and the band this closes; its measurements and screenshots are the baseline), [spec 060](../060-deck-components/spec.md) (the `DeckShape` CSS and decision 4's 10% rule), [spec 069](../069-deck-shape-panel/spec.md) (decision 9, the narrow class), all merged
**Branch:** `078-mana-bar-label-fit`
**Issue:** [#330](https://github.com/plainprogrammer/Collector/issues/330) (design-system lane, filed by the maintainer's ruling from spec 077)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-12 | First draft from issue #330, spec 077's decision 2 and measurements, and a throwaway probe in headless Firefox (below). Routing: the issue asks for a ruling between three options and the ruling changes a documented limit of a shipped spec, so it is a spec, not a direct fix. The maintainer ruled **D1** (decision 1) |

## Problem Statement

On the deck shape panel's mana bar a segment shows its label ("U 44", "W 2.6k") whenever the segment is at least 10% of the symbols (spec 060 decision 4, spec 069 decision 9). A label needs more room than that. Its text has a space, so a label that is wider than its segment's content box breaks into two lines ("W" over "12") and the second line is cut off at the bar's 30px. Spec 077 abbreviated four-digit counts (fixing #320's five-equal-segments case) and recorded this band as a documented limit by the maintainer's ruling of 2026-11-11 (its decision 2, option A), offering it as #330.

> **Terms.** A *label* is the span inside a segment ("U 44"). A segment's *content width* is its `clientWidth`: its box less the 1px divider border (the first segment has none). The *bar* is the `c-manabar`; its width is the panel's interior (238px at a 320px viewport, 263px in a 360px frame, 278px at a 360px viewport, 286px in the aside; spec 077's chain).

### Measurement (2026-11-12, headless Firefox on a Mac, the 12px mono face at weight 600)

A label is 29.2px wide for four characters ("W 12", "U 44"), 36.4px for five ("W 120", "W 999") and 43.6px for six ("W 2.6k"): about 7.3px a character. On a bar of 238px (a 320px viewport), a label with these counts is on one line inside its segment only from a share of about 13% for four characters, 16% for five and 19% for six (the segment's content width, its share of the bar less the 1px divider, is at least the label's; issue #330 and spec 077 measured 14%, 17% and 20% with a further 2px gap, which this spec does not ask for, decision 3). A segment between the 10% rule's line and that share wraps its label onto two lines, whatever the count:

| Deck (symbols per colour) | Segment | Share | Content width at 320px | Label | Before | At 360px (278px bar) |
|---|---|---|---|---|---|---|
| W 12, U 13, B 15, R 16, G 44 | "W 12" | 11.7% | 28px | 29.2px | wraps onto two lines | 33px, fits |
| the same | "U 13" | 13.1% | 30px | 29.2px | fits | fits |
| W 120, U 160, B 180, R 190, G 350 | "W 120" | 11.7% | 28px | 36.4px | wraps | wraps (33px) |
| W 1200, U 1800, B 2000, R 2100, G 3900 | "W 1.2k" | 10.6% | 25px | 43.6px | wraps | wraps (30px) |
| the same | "U 1.8k" | 16.4% | 38px | 43.6px | wraps | fits (45px) |

So whether a label fits depends on its length and on the width the bar happens to have, both known only to the browser.

### The probe (not committed; its method is Story 1's example)

A candidate rule, three lines of CSS inside the mana bar block (decision 1), was injected into the three decks above at a 320px and a 360px viewport and in the 1280px aside. Every label that fits (content width at least the label's width) stayed on one line inside its segment, among them the 11.7% "W 12" at 360px and in the aside; every label that does not fit left its segment box (below it, clipped); none wrapped onto two lines inside the segment or was cut off.

## Goals

- On the mana bar, a label either sits on one line inside its segment or isn't drawn, at any width of the bar and for any label length. The caption and the bar's `aria-label` keep the exact count of every colour.
- A label that fits is drawn: the rule hides only what cannot fit (a 12% "W 12" shows on a 360px phone and in the aside, where it fits).
- The rule follows the label's rendered width, so it holds when the font, its weight, the abbreviation or the page's padding change, with no number about fonts in Ruby or in CSS.

## Non-Goals

- The 10% rule and the narrow class (spec 060 decision 4, spec 069 decision 9): kept as they are, a segment under 10% still has no label (decision 2). Retiring the rule (option D2 of the ruling) is not taken.
- Any change to the markup, the figures (`MTG::DeckShape`), the abbreviation, the caption or the `aria-label`s: the whole change is CSS and documents.
- Counts, curve, Card types and caption: spec 077's work, unchanged.
- A real-phone check by an agent: the maintainer checks a phone (WebKit) as a manual item (decision 4).

## Decisions

### 1. The fit rule is CSS and follows the rendered label (ruled D1 by the maintainer, 2026-11-12)

The options, from the issue and the brainstorm, and why this one:

- **A, leave it as the documented limit** (spec 077 decision 2): costs nothing; the label still wraps and is cut off at a 320px viewport, so the issue's outcome is not met.
- **B, a server-side rule by label length:** hides a label below the share it needs at the narrowest interior. It supersedes the 10% rule, hides labels in the aside and on a 360px phone where they fit, and hard-codes font metrics (about 7.3px a character and a 232px bar in Ruby) that drift silently if the font, weight or padding change.
- **C, a container query by width:** a query cannot read content, so it needs the label's length as a class or attribute and a pixel or `ch` threshold per length; right at every width, but a server-set class per length and still an approximation of the font.
- **E, JavaScript that measures the label:** exact, but the design system says nothing needs JavaScript to render (README), it flashes before it runs, and the project's Hotwire rule puts plain HTML and CSS first.
- **D, chosen: the browser's own line breaking decides.** Each segment is a wrapping flex container with `overflow:hidden`. A zero-width `::before` the height of the segment is its first item, and the label is an item that does not shrink. The browser puts the label on the first line only if it fits the content width; otherwise it moves to a second line, below the segment's box, where the `overflow` clips it. No server change, no font number, no JavaScript, no new class, right at every width and for any label length, and the text still centres vertically in the segment when it fits (the `::before`'s height gives the first line the segment's whole height).
- **Trade-offs, recorded:** a clipped label stays in the DOM (the bar is `role="img"` with an exact `aria-label`, so a screen reader reads the figures once; the browser's find-in-page may still match the clipped text); the technique is unusual CSS, so the block says why in a comment; and it relies on flex line breaking (decision 4).

### 2. The 10% narrow class stays (D1)

The server still marks a segment under 10% of the symbols narrow and `.c-manabar__seg--narrow span` still hides its label (spec 060 decision 4, spec 069 decision 9 and AC-4.6, unchanged). The fit rule is added on top: a label is drawn when its segment is at least 10% **and** the label fits. The class is a floor the maintainer ruled, not the fit test; the caption carries the count of a segment under it, as before.

### 3. The gap

A label that exactly fills its segment's content width is drawn (the test is "its width is at most the content width", as spec 077 AC-2.2 after 0.3.3), with no margin added: the 1px or 2px a margin would take would hide labels that fit, and a label at the edge is on one line inside its segment, which is the outcome.

### 4. Browsers and the manual phone check

The rule relies on flex line breaking: in a multi-line flex container an item moves to a new line when the line's items would exceed the container's inner main size, and the first item of a line always stays on it (CSS Flexbox, "collect flex items into flex lines"). That is old and standard behaviour in every browser the app allows (`allow_browser versions: :modern`: Safari 17.2, Chrome 120, Firefox 121 and later). The suite runs it in headless Firefox only, and `percent` heights of a stretched flex item's child (the `::before`'s `height:100%`) are the one other thing it relies on. **The maintainer will check it on a phone (WebKit) as a manual verification item**, recorded in `verification.md` as owed until done.

## Supersedes

| Document | What it says | What changes |
|---|---|---|
| [Spec 077](../077-deck-shape-extreme-counts/spec.md) decision 2 (its "What this leaves" paragraph and option A), its Goal 1's "the unfixed mana band" qualification, its Error Scenarios row "A mana segment between 10% and about 14% …" and Open Questions ("the maintainer ruled decision 2 **A**") | the band of segments between 10% and the label's share is a documented limit: the label wraps and is cut off, offered as #330 | the band is closed by this spec's decision 1: a label that cannot fit is not drawn; the label's abbreviation (the rest of decision 2) and AC-2.1 to AC-2.3 stand |
| `DeckShape.md` "Width" ("Known limits (1)") and the mana bar paragraph's mention of the limit | the limit is recorded with its shares of 14%, 17% and 20% | the limit is replaced by the fit rule; limit (2), the five-digit Card types rows, stays |

Spec 060 decision 4 and AC-2.6's "a segment's label reads its letter and count" and spec 069 decision 9 and AC-4.6 are **not** superseded: the 10% rule stays and a drawn label still reads its letter and count (the README's Charts rule says every segment has its letter and count, the caption carrying one under 10%; the caption now also carries a segment whose label does not fit, which `DeckShape.md` states). Recorded in the specs index, in both directions; spec 077 is frozen and is not edited.

## User Stories

### Story 1: A label fits its segment or isn't drawn

**As a** collector looking at a deck's mana bar on a phone
**I want** every label to sit on one line inside its segment or not be drawn
**So that** the bar never shows half a word or a label spilling into its neighbour, and the caption below still gives me every colour's exact count

- [ ] **AC-1.1** Given three decks whose mana symbols are W 12, U 13, B 15, R 16, G 44 (four-character labels), W 120, U 160, B 180, R 190, G 350 (five) and W 1,200, U 1,800, B 2,000, R 2,100, G 3,900 (six, "W 1.2k") When the open fold is measured at a 320px, a 345px and a 360px viewport, in a 366px and a 640px frame, and in the aside at 1280px, in both themes Then every label is exactly one of: **drawn**, that is on one line (its text box is at most one line high) with its text box inside its segment's box; or **not drawn**, that is its segment is narrow (no box), or its text box lies wholly outside its segment's box (below it) with the segment's `overflow` hidden. No label is on two lines, and none is partly inside and partly outside.
- [ ] **AC-1.2** Given the same measurement When a label's width is at most its segment's content width (`clientWidth`) Then it is drawn; and at a 320px viewport at least one label of the first deck ("W 12", 28px against 29.2px) is not drawn, so the example shows the rule acting. (A label that fits is never hidden; one that cannot fit never wraps.)
- [ ] **AC-1.3** Given a drawn label When its text box's vertical centre and its segment's are compared Then they are within 1px (the label is centred in the bar as before).
- [ ] **AC-1.4** Given the rule is removed (the variant: the three declarations overridden by a `<style>`, restoring the old layout) When AC-1.1 is measured at a 320px viewport on the first deck Then it fails: "W 12" is on two lines. The example can fail.
- [ ] **AC-1.5** Given spec 069's worst-case fixture (five segments of about 2,591, labels "W 2.6k") When AC-1.1 is measured at the widths above Then every label is drawn at every width (as spec 077 AC-2.2 measures: one line, within its content width), unchanged.
- [ ] **AC-1.6** Given a segment under 10% of the symbols When the bar renders Then it still carries `c-manabar__seg--narrow` and no label is drawn (spec 069 AC-4.6 unchanged), and the bar's markup, `aria-label` and caption are unchanged character for character (the request examples of specs 069 and 077 pass unchanged).

### Story 2: The documents

**As a** developer, or an agent, drawing the mana bar
**I want** the component document and the area doc to say when a label is drawn
**So that** the next fixed-width slot is built the same way

- [ ] **AC-2.1** `docs/design-system/components/DeckShape.md` states the fit rule in the mana bar paragraph (a label is drawn when its segment is at least 10% and the label fits on one line; otherwise it is clipped and the caption carries the count), says it relies on flex line breaking and the `::before`'s height, names the browsers (Safari 17.2, Chrome 120, Firefox 121 and later; run in Firefox, a phone check owed to the maintainer), and replaces the "Width" paragraph's Known limit (1) with it; limit (2) stays. (Verified by reading.)
- [ ] **AC-2.2** `docs/design-system/README.md`'s `DeckShape` addition line and `docs/design-system/previews/DeckShape.html` are read for a statement of the limit or of the 10% rule and corrected where they differ (the previews draw the real stylesheet, so no markup changes). (Verified by reading.)
- [ ] **AC-2.3** `docs/architecture/collection-and-lots.md` states the rule in the panel's paragraph, its Issues bullet no longer lists #330 as open and its Sources and Distillation log name this spec; `docs/specs/README.md` has this spec's row with 077 in "Supersedes" and 078 in 077's "Superseded by". (Verified by reading.)
- [ ] **AC-2.4** `verification.md` lists the maintainer's check of the bar on a phone (WebKit) as a manual item, owed until the maintainer records it. (Verified by reading.)

### Story 3: Nothing else moves

**As a** maintainer
**I want** the change to be small
**So that** it merges cleanly beside other CSS work in `additions.css`

- [ ] **AC-3.1** The branch's diff to `app/` is `app/assets/stylesheets/collector/additions.css` only, inside the mana bar block; it adds no colour, font family or spacing literal the tokens could give and no class (`spec/design_system_files_spec.rb` passes unchanged). No view, model or script changes. (Verified by the diff.)
- [ ] **AC-3.2** `spec/deck_core_spec.rb`, `spec/requests/query_counts_spec.rb`, spec 077's system and request examples, spec 069's examples and `spec/system/design_system_deck_components_spec.rb` pass with their assertions unchanged.

## Functional Requirements

- **FR-1.** `additions.css`, inside the DeckShape mana bar block, gives `.c-manabar__seg` `flex-wrap:wrap`, `align-content:flex-start` and `overflow:hidden`; gives `.c-manabar__seg::before` an empty content and `height:100%`; and gives `.c-manabar__seg > span` `flex:none`. A comment says why (spec 078, #330): the browser's line breaking moves a label that does not fit to a second line below the segment, which the `overflow` clips; the `::before` is the first item that always stays on the first line and gives that line the segment's height; the 10% narrow class is separate. The exact declarations are the plan's, checked against AC-1.1 to AC-1.3 (the probe's were these).
- **FR-2.** Examples first, red before the CSS: the AC-1.1 to AC-1.3 and AC-1.5 examples in the nested `describe` of `spec/system/deck_shape_panel_spec.rb` (the spec 077 block) beside the AC-2.2 examples, measured as they are (a `Range` over the label's text for lines and box, the segment's `clientWidth`, the frame sized from the measured scrollbar as `open_fold_in_frame` does, `documentElement.clientWidth` not `innerWidth`), and AC-1.4's variant.
- **FR-3.** The documents of Story 2 and the screenshots of the non-functional requirements.

## Non-Functional Requirements

- **Compatibility:** no migration, no schema change, the export unchanged at version 4, upgrade-safe from the previous release; no view or model change.
- **Hosted-door cost per account (north star rule 4):** none (a stylesheet rule); the other three hosted-door rules do not apply (no catalog source, no admin page, no setting).
- **Accessibility:** unchanged: the bar is `role="img"` with the exact `aria-label`; a clipped label is in the DOM but inside a `role="img"` and below the bar's visible box; the caption stays.
- **Visual change:** yes: a label in the band is no longer drawn (it was wrapped and cut off) and a label that fits is drawn where it was drawn. Before and after screenshots of the bar in the band deck at a 320px, a 360px and the desktop aside, both themes, in the pull request ("before" is the old rule restored by a `<style>`, `.claude/memory/pr-screenshots-workflow.md`).

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| A label exactly as wide as its segment's content width | Drawn (decision 3) |
| A label wider than every segment (a bar of five tiny segments at a narrow width) | None drawn; the caption carries every count |
| A segment under 10% | No label, as before (decision 2); the fit rule never applies to it |
| A label of three characters ("B 4", about 22px) | Drawn when its segment is at least 10% and at least 22px wide (the narrow class decides first; the fit rule second) |
| The font, its weight or the page's padding changes | The rule follows the rendered label and segment, so nothing in the rule changes |
| Text size is enlarged (browser zoom or text-only zoom) | A label that no longer fits is not drawn; a label that fits is |
| The browser lacks multi-line flex or `::before` as a flex item | Not reachable (decision 4) |
| A clipped label found by find-in-page | The text matches but is not visible; recorded as a trade-off (decision 1) |

## Open Questions

None. The approach was ruled by the maintainer (D1, 2026-11-12); the phone check is a manual item (decision 4, AC-2.4).

## Notes for the plan

- The probe is `spec/system/zz_probe_label_spec.rb` (uncommitted, the plan's first example is its descendant); the fixture decks need one `card(cost: "{W}")` of `n` copies per colour, as the probe's `counts` builds them. Delete the probe before committing.
- Spec 077's AC-2.2 example measures a deck in the same nested `describe`; add the band decks beside it and reuse its `at_width`, `open_fold_in_frame` and `measure`-style helpers (in that file, not in `spec/support/narrow_frame.rb`, which the #318 worker is changing to compare with `clientWidth`: if it lands first, merge `main`; don't edit it).
- A label's drawn/not-drawn state is read from geometry, not from `display`: a clipped label is a box below its segment (`range.getBoundingClientRect().top >= segment.getBoundingClientRect().bottom - 0.5`) and `getComputedStyle(segment).overflow` is `hidden`; the example expects at least one of each kind at a 320px viewport so it cannot pass vacuously.
- The aside's bar is the `aside .c-manabar`; the fold's is `details.c-shapefold .c-manabar` (the other copy is `display:none` and measures 0).
- Keep the CSS edit inside the mana bar block; `spec/design_system_files_spec.rb` counts the strings "spec 019", "spec 021" and "spec 023" across the whole file; "spec 078" is fine.
- Run `bin/yard doc` only if a Ruby comment changes (none is expected); run `bin/rspec spec/system/design_system_deck_components_spec.rb` after the CSS edit (it builds its own `c-manabar` markup and reads the segment's paints and the bar's outline).
- Screenshots: a throwaway `spec/system/zz_078_screenshots_spec.rb` (workflow in `.claude/memory/pr-screenshots-workflow.md`): the band deck of each length at a 320px, 360px and 1280px aside, both themes, "before" with the old rule restored by a `<style>`; look at each shot, and at the first of each theme, before trusting the rest.

## Out of Scope (Future Considerations)

- Retiring the 10% rule (option D2) or showing a label's letter alone ("W") in a segment too narrow for its count: a later ruling.
- A tooltip or `title` with the count on a segment that shows no label: the caption carries it.
- A check in Chrome or Safari by an agent.

## Documents that change

- `app/assets/stylesheets/collector/additions.css` (the mana bar block); `spec/system/deck_shape_panel_spec.rb` (new examples).
- `docs/design-system/components/DeckShape.md`; `docs/design-system/README.md` and `docs/design-system/previews/DeckShape.html` only if they state the limit or the rule (AC-2.2).
- `docs/architecture/collection-and-lots.md` (the panel's paragraph, the Issues bullet, Sources and the Distillation log); `docs/specs/README.md` (this spec's row; 077's "Superseded by").
- No ADR: the ruling is this spec's decision 1; no new area doc.
- Left as history, not edited: specs 060, 069 and 077 and their `verification.md` files.
