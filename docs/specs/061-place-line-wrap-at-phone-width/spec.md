# Feature 061: The Phone Line's Wrap Is Stated at a Phone's Width (Restates Spec 048 AC-1.8)

**Status:** Approved by the maintainer (2026-11-10, Gate A, relayed by the coordinator) at 0.3.0, after two spec review rounds
**Version:** 0.3.0
**Created:** 2026-11-10
**Last Updated:** 2026-11-10
**Depends on:** [spec 048](../048-row-place-line/spec.md) (a table row's place line wraps; decision 4, AC-1.7, AC-1.8), [spec 033](../033-location-on-tiles-and-rows/spec.md) (the phone line); [#272](https://github.com/plainprogrammer/Collector/pull/272) (the suite pins classic scrollbars), all merged
**Branch:** `061-place-line-wrap-at-phone-width`
**Issue:** [#288](https://github.com/plainprogrammer/Collector/issues/288) (the cause was found in [#271](https://github.com/plainprogrammer/Collector/issues/271); theme: locations)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.0 | 2026-11-10 | Spec review round 2 (Opus, read-only; APPROVE, 0 blocking, 0 major, 4 minor), minors taken: the room of 146 is stated as what the wrapping lines measure; the fragility row separates raw overflow from the asserted margin; the index rows are aligned; AC-2.2 amends the Sources line. Approved at Gate A by the maintainer, relayed by the coordinator |
| 0.2.0 | 2026-11-10 | Spec review (Opus, read-only), round 1: 1 blocking, 2 major, 7 minor, all taken: the margin's wording (20px of 23px, not "half"); spec 048's Error Scenarios row added to what is superseded; AC-1.4 states how the overlay run is made and what it must record; room is marked "fits" where the line fits; AC-1.3 is met by existing examples; the error row names AC-1.2; FR-1 names the header and factory comments; the history left unedited is listed |
| 0.1.0 | 2026-11-10 | First draft from issue #288, #271 and the measurements below. The maintainer ruled decision 1 (option a) on 2026-11-10 |

## Problem Statement

Spec 048 decision 4 and AC-1.8 say a five-character set code wraps the phone line of the table at 360px ("PMH3A · 146 · Foil · NM · EN"). That holds only when the page's content is 345px wide: a 360px frame less the 15px of a classic scrollbar, which is what the suite's Firefox draws (pinned in #272, as CI's Linux Firefox draws it). A phone draws overlay scrollbars, which take no width, so its content is 360px wide and that line fits with about 8px to spare. The example passes by about 7px, and it tests a wrap phones don't show.

The behaviour is right and the CSS is not at fault: a phone line wider than its cell wraps instead of scrolling the page (spec 033 decision 3, spec 048 decision 1 and decision 4). The criterion names a line that is too short to prove it on a phone. This spec restates it with a line that wraps on a phone, and the example measures how much it wraps by, so a font or width change fails it instead of flipping it. It changes one system example and documents; no stylesheet, view, helper, query, export or migration.

> **Terms** are spec 033's (*row*, *place line*, *lot*, *location*, *unplaced*). The *phone line* is a table row's `c-table__sub` line under the card's name below 640px of container width. Its *room* is the width its cell has for it: the `c-table__sub` element's `clientWidth` while its text wraps (the table's auto layout gives the name column all the width the other columns leave, so the room grows by as much as the content does). Its *unwrapped width* is the width of its text with wrapping switched off. The *content width* of a frame is the width of its page without a scrollbar: the frame's width on a phone, 15px less with a classic scrollbar.

**Probe (2026-11-10; headless Firefox, a fixed-width frame, one lot, quantity 9,999, no location in the account; frames of 345, 360 and 375px with classic scrollbars, which are content widths of 330, 345 and 360px).** Room and unwrapped width are in px.

| Line (set · number · finish · condition · language) | Unwrapped | Room at 330 / 345 / 360 | Wraps at 345 | Wraps at 360 (a phone) |
|---|---|---|---|---|
| MH3 · 146 · Foil · NM · EN (spec 048 AC-1.7) | 138.5 | 131 / 138 (fits) / 138 (fits) | no | no |
| PMH3A · 146 · Foil · NM · EN (spec 048 AC-1.8) | 153.4 | 131 / 146 / 153 (fits) | yes, by 7 | **no**, 8 to spare |
| PLST · PCY-132 · Foil · NM · EN | 166 | 131 / 146 / 161 | yes, by 20 | yes, by 5 |
| PMH3A · 146 · Etched · NM · EN | 171.6 | 131 / 146 / 161 | yes, by 25.6 | yes, by 10.6 |
| **PLST · PCY-132 · Etched · NM · EN** | 184.1 | 131 / 146 / 161 | yes, by 38 | yes, **by 23** |
| PLST · PCY-132 · Etched · DMG · ZHS | 199 | 131 / 146 / 161 | yes, by 53 | yes, by 38 |

"PLST" is the set code of The List and "PCY-132" is the shape of a number it uses (the original set's code and number). The fonts are the design system's own files, so Linux and macOS measure alike.

## Goals

- The criterion that a phone line too wide for its cell wraps says what phones do, and its example passes at a 360px content width with or without a classic scrollbar.
- The example fails loudly, by a measured margin, if the line stops being wider than its room by a clear amount, instead of passing by a few pixels.

## Non-Goals

- Changing a rule, a view or the phone line's content. Spec 048 decision 4 stands: the wrap rule is the `c-table__sub` rule of every narrow table, not scoped away from an account with no location.
- Changing spec 048's AC-1.7 and its 360px and 390px examples (a three-character code fits one line, which is true at every scrollbar setting), or AC-1.1 to AC-1.6 (their wording and examples don't depend on where a line wraps).
- Removing the classic-scrollbar pin of #272: other examples depend on a fixed width, and CI draws classic scrollbars.
- Widening spec 048 AC-1.7's margin: its example fits by only about 7.5px in the suite's 345px content width (138.5 against the 146px room the wrapping lines measure at 345; a line that fits reports its own width), the same thinness in the other direction, but it fits at every scrollbar setting and no wrap is claimed there, so nothing flips.
- Any claim of how the line wraps at 390px: a phone's 390px content is wide enough for this spec's line to fit on one row, and nothing is asked of it there.

## Decisions

### 1. The criterion is restated with a line that wraps at a 360px content width; the example measures its margin (ruled by the maintainer, 2026-11-10, option a)

| | A. A line that wraps at a 360px content width (ruled) | B. Only no sideways scroll, no wrap check | C. A stated content width (345px) |
|---|---|---|---|
| What the criterion says | A phone line wider than its room wraps instead of scrolling, shown with a line that does at a phone's width | A long no-location line never scrolls | The same line, at the width a classic scrollbar leaves |
| What phones do | the criterion and the example match | silent | the example matches a width no phone has |
| Proof that a no-location line wraps | kept | lost (spec 048 AC-1.1 and AC-1.2 prove it only for lines with a place) | kept, at about 7px |
| Fragility | margin 23px at a phone's width, 38px of raw overflow with a classic scrollbar (the asserted margin is 23 either way) | none | the same 7px |

The line is PLST · PCY-132 · Etched · NM · EN: a real set code, number and finish of the vocabulary, 184px wide against a room of 161px at a phone's 360px. The example keeps spec 048's other settings (no location, quantity 9,999, near mint, English). The 20px margin is set against the line's 23px: it leaves 3px for a font's or a rounding's difference and is more than the classic scrollbar's 15px, so a scrollbar setting can't flip the example the way it flipped the old one, and a change of more than a few pixels to a font, a gutter or a column fails it loudly.

### 2. The margin is measured at a phone's content width, whatever scrollbar the browser draws

The example reads the line's unwrapped width, its room, and the page's scrollbar width (the frame's `innerWidth` less its document's `clientWidth`; 15px classic, 0 overlay), and asserts that the unwrapped width exceeds the room plus the scrollbar width by at least 20px. The room moves one for one with the content width (the probe: 131, 146, 161 for 330, 345, 360px), so room plus scrollbar width is the room a 360px content width would give, and the number is the same in the suite (classic: 184 − (146 + 15) = 23) and on a phone (overlay: 184 − (161 + 0) = 23).

### 3. Spec 048 AC-1.8 and the sentences of decision 4 that name it are restated here; the ruling of decision 4 stands

Decision 4's "a four- or five-character set code (PLST, PMH3) can make the line longer than a 360px phone holds" is true of a code with a long number, an Etched finish or a long language code, not of a five-character code alone ("PMH3A · 146 · Foil · NM · EN" fits a phone with 8px to spare). What a phone shows is: a line wider than its room wraps instead of scrolling the page, whatever account it is for. The same goes for spec 048's Error Scenarios row for an account with no location ("a longer code wraps the line at 360px").

## Supersedes

| Spec | What it says | What changes |
|------|--------------|--------------|
| [Spec 048](../048-row-place-line/spec.md) | AC-1.8: a five-character set code ("PMH3A") wraps the phone line at 360px, with no sideways scroll and no Location column or place; decision 4's sentence that a four- or five-character set code can make the line longer than a 360px phone holds; probe 1's last table row, the Error Scenarios row for an account with no location ("a longer code wraps the line at 360px") and the 0.5.0 changelog line that say the same | AC-1.1 of this spec replaces AC-1.8 (a line that is wider than its room wraps; the example line is PLST · PCY-132 · Etched · NM · EN). Decision 4's ruling (the rule isn't scoped to accounts with a location), AC-1.7 and every other criterion stand |

Recorded in the specs index in both directions and in the collection and lots area doc. Spec 048 is frozen and is not edited.

## User Stories

### Story 1: The phone line's wrap is proved at a phone's width

**As a** maintainer
**I want** the criterion and its example to describe a line that wraps on a real phone
**So that** it doesn't pass by luck at a width no phone has, and breaks when something real changes

- [ ] **AC-1.1** Given an account with no location and a lot of set code "PLST", number "PCY-132", Etched, near mint, English, quantity 9,999 When the table renders in a 360px frame Then the line under the name is two lines high (its `c-table__sub` is 20px or more high), the page doesn't scroll sideways, the table has no Location column, and the line carries no place; the result is the same whether the browser draws classic or overlay scrollbars.
- [ ] **AC-1.2** Given the same account and lot When the line's unwrapped width and its room are measured in the 360px frame (decision 2) Then the unwrapped width exceeds the room plus the page's scrollbar width by at least 20px.
- [ ] **AC-1.3** Given spec 048's AC-1.7 lot (set code "MH3", number 146, foil, near mint, English, quantity 9,999, no location) When the table renders at 360px and at 390px Then it is one line (under 20px), as spec 048 AC-1.7 says, unchanged; the existing examples (`spec/system/collection_row_place_spec.rb`, "fits one line under the name at 360px and 390px") meet it and no new example is written.
- [ ] **AC-1.4** Given AC-1.1's and AC-1.2's example When it is run once with overlay scrollbars, by a temporary edit of the `ui.useOverlayScrollbars` preference in `spec/support/system.rb` to 1 that is reverted after the run (nothing is committed for it) Then it passes, and `verification.md` records that run with its measured scrollbar width (0), room (about 161px), unwrapped width (about 184px) and line height; a run that doesn't record a scrollbar width of 0 doesn't meet this criterion. (A verification criterion: the suite keeps the classic pin, decision 1.)

### Story 2: The restatement is written where the next change reads it

**As a** maintainer
**I want** the supersession recorded in both directions and the area doc corrected
**So that** nobody reads "a five-character code wraps at 360px" as a rule

- [ ] **AC-2.1** The specs index adds this spec's row and names its supersession of spec 048 AC-1.8, and spec 048's row names this spec in "Superseded by" (a small edit of the index only, not of spec 048). (Verified by reading.)
- [ ] **AC-2.2** The collection and lots area doc's place line bullet replaces its "a four- or five-character set code can wrap the line at 360px (spec 048 decision 4, AC-1.8)" with the rule of decision 3 and cites this spec's AC-1.1 and AC-1.2; this spec joins its Sources, where the line for spec 048 ("all") says "all, except AC-1.8, restated by spec 061", and its distillation log. (Verified by reading.)

## Functional Requirements

- **FR-1.** The one example of spec 048 AC-1.8 (`spec/system/collection_row_place_spec.rb`) is replaced by one for AC-1.1 and AC-1.2, measured in the narrow frame (`spec/support/narrow_frame.rb`), with the margin assertion of decision 2. Its comments cite this spec and no longer say a five-character code wraps at 360px. The file's header comment (it cites spec 048's criteria) cites this spec too. The factory comment in the same file that says a five-character code "legitimately wraps the phone line at 360px" is reworded to say it can wrap the line in the suite's 360px frame, whose classic scrollbar leaves 345px (the factory's codes, such as `S2000`, wrap there and not on a phone).
- **FR-2.** No stylesheet, view, helper, model, controller, migration or export file changes. If the example's measurement shows the margin is smaller than decision 1 says, the plan adjusts the line, not the 20px.
- **FR-3.** The example is stated by what it measures, never by a scrollbar setting: the scrollbar's width is read, not assumed (decision 2).

## Non-Functional Requirements

- **Compatibility:** no migration, no schema change, export format unchanged at version 3, upgrade-safe from the previous release.
- **Hosted-door cost per account (north star rule 4):** none; a test and documents.
- **Visual change:** none, so no before and after screenshots are owed (the maintainer, 2026-11-10).

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| A font, gutter or column change leaves the line less than 20px wider than its room at a 360px content width | AC-1.2's assertion fails and its message gives the measured numbers (unwrapped width, room, scrollbar width); the plan then picks a longer line or the change is questioned |
| The browser draws overlay scrollbars | The scrollbar width is 0; the margin is the same, 23px (AC-1.4) |
| The line fits on one row at a 360px content width | In the suite (a 345px content width) AC-1.1 can still hold, so AC-1.2's margin is what fails; with overlay scrollbars (AC-1.4) AC-1.1 fails too (the line is under 20px high) |

## Open Questions

None. Decision 1 is the maintainer's ruling of 2026-11-10.

## Notes for the plan

- The measuring code goes in the example file, as spec 048's `measures` does; the narrow frame's helper already returns whether the page scrolls sideways.
- Measure the unwrapped width on a range over the line's contents with `white-space: nowrap` set on the element, then restore it (the probe did).
- Build the margin expectation with a message that gives the numbers, for example `expect(margin).to be >= 20, "unwrapped #{unwrapped}, room #{room}, scrollbar #{scrollbar}"`.
- The first task writes the new example and runs it against the shipped CSS (it should pass: nothing but the test changes); the TDD gate is met by running the example first with the old line "PMH3A · 146 · Foil · NM · EN" and seeing the margin assertion fail (153.4 − (146 + 15) = −7.6px with the suite's classic scrollbars), then with the new line and seeing it pass.

## Out of Scope (Future Considerations)

- Truncating or limiting the phone line, a tooltip for it, or any other change to the line.
- Pinning the example to a width independent of the scrollbar for other specs that depend on a wrap (none is known; #271's lesson says to check the browser's environment first when one fails locally only).

## Documents that change

- `docs/specs/README.md`: this spec's row; spec 048's "Superseded by" cell.
- `docs/architecture/collection-and-lots.md`: the place line bullet (the restated rule and the source), Sources and the distillation log.
- No ADR: the ruling is a test and a criterion, recorded here.
- Left as history, and not edited: spec 048 and its `verification.md`, and the lesson `docs/lessons/2026-11-10-a-local-only-failure-was-the-macs-scrollbar-setting.md`, all of which state the five-character claim as it was found. The design system's `CollectionTable.md` and README make no such claim.
