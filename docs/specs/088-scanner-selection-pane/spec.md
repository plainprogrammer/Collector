# Feature 088: Scanner: the Selection Pane

**Status:** Draft, for Gate A
**Version:** 0.3.0
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Depends on:** [spec 080](../080-phone-first-scanner-components/spec.md) (the pane, the band, the strip and the row, drawn with their CSS), [spec 082](../082-scanner-capture-always-in-view/spec.md) (the one-screen page, the sheets, the lines, "Scan again", decisions 10, 11 and 13), [the phone-first scanner design](../../superpowers/specs/2026-11-12-scanner-phone-first-design.md) (approved 2026-11-12; decisions 8 to 19), the scanner as built ([scanner](../../architecture/scanner.md) area doc; specs 009, 011, 040, 042, 047)
**Branch:** `088-scanner-selection-pane`
**Issue:** [#345](https://github.com/plainprogrammer/Collector/issues/345) (roadmap Theme D, the phone-first layout's third item)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.0 | 2026-11-13 | The first spec review (Fable; NEEDS REVISION; 2 blocking, 6 major, 9 minor), fixed, my calls: the opening sentence is hidden text and alerts stay visible, the mechanism for a refused reading, the add forms target `_top`, the more item's tail and the 200 cap, focus fallbacks, the layout's two container steps and the numbers of AC-5.2, the supersession list completed. The review's M1 (cards 2 and 3 of a confident row) was already ruled by the maintainer (question 2) and is written as a trade in decision 3 |
| 0.2.0 | 2026-11-13 | The maintainer ruled the seven scope questions as recommended (decisions 2 to 4, 7, 8, 11, 12); the pending marks go. Decisions 3 and 11 now say what the collector does when the scanner is confidently wrong about the card and that a failed read shows no capture, so the trade is written down |
| 0.1.0 | 2026-11-13 | Draft from issue #345, specs 080 and 082 and the design. Decisions marked *(pending)* are my recommendations on the scope questions sent to the coordinator; every other decision is my call for Gate A |

---

## Problem Statement

Spec 082 made the scanner one screen, and a result opens in its pane. What the pane holds is still spec 009's page: "What the scanner read", a grid of up to three candidate tiles each with its own badge, add buttons and "Other printings" link, and a frame of printings below them, all in an interim scrolling body (`c-scanpane__results`, spec 082 decision 11). On a phone the add buttons sit below the fold, the capture isn't seen beside the match, and a wrong printing is reached through a link and a list. The maintainer saw those quirks at spec 082's sitting and expects this story to settle them.

This spec builds what spec 080 drew and the design decided: after a capture the frozen picture shrinks into a strip beside what was read from it, and the pane slides up with a status band that says how sure the scanner is, a row of card images to swipe (or step with Previous and Next) with the best match centred, one details block for the centred card and one add button per finish under it. A confident match is added with one tap on a finish, a wrong printing is a swipe away, and the band says in words and an icon when the scanner is less sure. It removes the interim body and what it held, and it changes nothing about how a card is read or ranked (ruled 2026-11-13: reading accuracy is left to later scanner stories).

> **Terms.** As specs 080 and 082: the *shell*, the *stage*, the *pane*, the *strip* (the capture strip: the capture's picture and, beside it, what was read), the *band* (`StatusBand`), the *row* (the swipe row of card images), a *panel* (`c-scanpane__card`: one card's details block and add buttons), the *main button*, the *status line*, the *after-add line*, the *frozen frame*. The *matched* printing is the ranking's first candidate's printing. A *selection* is the row with its panels, as one server-rendered Turbo Frame. *Sure of the card*, *printing confirmed* and *not sure* are decision 2's.

## Goals

- After a capture the collector sees their capture beside the match, and the pane's controls (band, Previous and Next, the add buttons) are in view without scrolling at 390 × 844, 360 × 640 and 360 × 560, for a confident match.
- A confident match is added with one tap on a finish; another printing is a swipe, or Previous and Next, away; the centred card is announced.
- The scanner being less sure is told in an icon and words: the card is right and the printing a guess, or the card itself is in doubt.
- The interim scrolling body, "What the scanner read", the candidates grid and the Other printings frame leave the page.

## Non-Goals

- A sitting's language (#58), look-up mode (#262), continuous capture (#54), detection on live frames (#53), Japanese cards (#55).
- Any change to how a card is read or ranked: the strips, the OCR settings, the detector, the art fingerprint, the evidence kinds and `Candidate#rank_key`. One new reading of them, a predicate over the evidence (decision 2), changes nothing the ranking does.
- Measurement mode's filing of retakes ([#419](https://github.com/plainprogrammer/Collector/issues/419)); the run sheet's row logic is not touched. Measurement mode keeps recording everything it records today (the reading's candidates, tier and overrule; add, Undo and Details events).
- New collector-owned data, a migration, a new export field, or a new ADR (decision 17).
- A mouse drag on the row (decision 7).

## Decisions

Decisions 2 to 4, 7, 8, 11 and 12 are the maintainer's, ruled on 2026-11-13 as I recommended them (questions 1 to 7 of the scope questions, relayed by the coordinator). Decisions 1, 5, 6, 9, 10 and 13 to 17 are my calls for Gate A. Decisions of the design are cited as "design decision N", of spec 080 as "spec 080 decision N", of spec 082 as "spec 082 decision N".

1. **The pane is the band, the pane's region, the failure block and one result container** *(my call; supersedes spec 082 decision 11's interim body)*. `c-scanpane` holds, from the top: the band (`p#scanner_band.c-band`, `role="status"`, kept in the document and empty while no result shows), the pane's `#status` region (spec 082 decision 10, unchanged), the send-failure block (now only its explanation's buttons, "Send again" or "Sign in": the name and collector line read are in the strip), and `#scanner_result`, which holds the selection (`turbo-frame#scanner_selection.c-scanpane__body`). `c-scanpane__results` is removed. The strip (`c-scan__strip`) is a sibling of the pane in the stage, above it, rendered with the page: its capture canvas is drawn by the page, and "Read from the card", the name and the collector line are written by the page from the reading (`textContent`; "nothing read" for a blank text). `scan-shell` still sets `c-scan--result` from `#scanner_result`, the pane's `#status` and the failure block, and does not count the band. An empty band takes no space and stays rendered (`.c-band:empty`, as the other regions, spec 080 decision 8). `#scanner_result` is a flex column that takes the pane's remaining height (`flex:1 1 auto; min-height:0`), so the frame, a grid by its class, sizes as spec 080's body did; the rule `.c-scan__pane-status:empty { margin-bottom: calc(-1 * var(--space-4)) }` took back the removed results body's flex gap and is replaced by the empty region taking no space in the pane's own column.
2. **Three states, from today's evidence** *(ruled by the maintainer, 2026-11-13)*. The ranking's first candidate decides, with no change to the ranking: *printing confirmed* is `Candidate#printing_confirmed?` (collector-line evidence, or art that belongs to one printing: today's success badge); *sure of the card* is a new predicate, `Candidate#card_sure?`: collector-line evidence, confident art, or a strong name match. The band is: success with a check and the evidence ("Matched by its collector line", "Matched by its collector line, one digit corrected", "Matched by its artwork") when the printing is confirmed; warning with the alert triangle, "Printing not confirmed. Swipe to check.", when the card is sure and the printing is not; warning with the question mark in a circle, "Not sure of this card. Check it against your capture.", when it is not sure. Two colours, as design decision 13.
3. **What the row holds** *(ruled by the maintainer, 2026-11-13)*. Sure of the card: the matched printing first, then the card's other English, non-retired printings in today's Other printings order (`Scanner::OtherPrintings`: shared artwork, read set and number, read set, read number, the rest; newest first), the position "1 of 14 printings". The other candidate cards are not in the row. Not sure: the candidate cards, up to three, each as its own printing, in ranked order, "1 of 3 possible cards" and Previous and Next named "Previous card" and "Next card"; each panel there also holds a ghost "All printings" button (44px, on the position line, which makes that state's line 44px) that navigates the selection frame to that printing's card: the card's printings with that printing first, its band by that printing's own evidence ("Printing not confirmed. Swipe to check." for a name match). Item *i* of a printings row but the first reads "Not the printing that was read" in warning with the alert triangle (design decision 14), also when the match was only a guess. Alternative: also keep cards 2 and 3 after the match, which breaks "1 of 14". **The trade, written down:** when the scanner is sure of the card and is wrong (a strong name match or a collector line that names another card), the row holds that card's printings only, so the other candidate cards of spec 009's grid are no longer one tap away; the collector sees it against their capture beside the row and taps "Scan again" to capture the card once more. The band cannot say it: the scanner does not know it is wrong.
4. **Twenty printings at a time** *(ruled by the maintainer, 2026-11-13)*. The selection renders the first `Scanner::OtherPrintings::SHOWN` (20) printings; the position counts all of them. With more, the row's last item is a "‹n› more printings" item whose panel (the card's name, "‹n› more printings", and a "Show 20 more" button in the adds' place) navigates the selection frame with `limit` raised by 20 and `current` naming the printing before the more item (the last one the collector saw), so the frame renders again with more and that card centred (scrolled there at once, never smoothly, so nothing announces on the way) and focus on Next. `limit` is at most 200: a card with more English printings (a basic land) shows the first 200 with no more item, an accepted limit the area doc records. This is the issue's "further printings arrive in a Turbo Frame": the row and the panels are siblings, so one frame holds both and is rendered whole by the server. The more item has no band of its own (the band stays as the previous item's) and no position. Alternative: a Turbo Stream that appends.
5. **The band is one element whose content is copied from the centred panel** *(spec 080 decision 8; my call for the mechanism)*. The server renders each panel with a `<template data-band="c-band--success|c-band--warning">` holding the band's icon and sentence (escaped by ERB, with the icon partials); the `selection` controller replaces the band's form class and children from the centred panel's template, in place. The band is never a second element revealed with `hidden`. The icons added are the question mark and the left and right chevrons, as partials under `app/views/icons/` (the star and the downward chevron exist).
6. **A small Stimulus controller notes the centred card** *(the issue)*. `selection`, on `c-scanpane`: when the row's scrolling stops (about 100ms after the last scroll event, so a fling announces once), it takes the item whose centre is nearest the row's, sets `aria-current="true"` on it alone, shows its panel and hides the others (`hidden`), copies the band, disables Previous at the first item and Next at the last, and writes the announcement (decision 8). A tap on a neighbour centres it. It restores the centred item the server marked (`aria-current` in the markup) when the frame renders again (decision 4), scrolling there with `behavior: "instant"` (the row's `scroll-behavior: smooth` would otherwise animate it and announce on the way). It empties the band when the row's target disconnects (an add, "Scan again"), and the page empties the strip's texts then. It holds no other state: the markup says which is centred and the server rendered everything else.
7. **Swiping is never the only way** *(ruled by the maintainer, 2026-11-13; design decision 19)*. Previous and Next are always shown (44px, over the neighbours, disabled at the ends; spec 080 decision 6), and do what a swipe does, a step of one item, smooth with no preference and at once under `prefers-reduced-motion`. The row (the list) is focusable (`tabindex="0"`), inside a `role="group"` named "Printings" or "Possible cards" on `c-scanpane__rowwrap`, so the list keeps its semantics; it takes Left and Right arrows as Previous and Next, and a trackpad or shift-wheel scrolls it natively. Each image's `alt` is "‹name›, ‹set name›, ‹SET · number›". There is no drag-to-scroll with a mouse. When the focused button becomes disabled at an end, focus moves to the other one; when both are disabled (a row of one) it moves to the row (spec 047). There is no way back from "All printings" to the possible cards but "Scan again".
8. **The centred card is announced through the band** *(ruled by the maintainer, 2026-11-13)*. The band's sentence is followed by a visually hidden tail naming the centred card, so its text changes with every swipe and is said each time: "Not the printing that was read. Printing 2 of 14: Lightning Bolt, Double Masters 2022, 2X2 · 117." ("Card 2 of 3: …" in the possible-cards row). When the result opens the pane's region says "Done. " and that same sentence, in place of spec 082's "Done. What the scanner read and its candidates are showing.", written once the pane shows (spec 082 decision 10); the band's own text is set while the pane is hidden and so is not announced at that moment, which is why the region says it. That opening sentence is a visually hidden paragraph (`c-sr`) in the region, not a visible one: a visible three-line sentence at 360px would take about 60px of the pane and repeat the band; the sentences that are alerts (a refusal, a failure, a refused add) stay visible, and a visible alert may make the body scroll at the smallest sizes. The details panels are not live regions. The more item (decision 4) gets a tail too: "10 more printings. Show 20 more."
9. **The strip** *(spec 080 AC-4.1; my call for the drawing)*. A capture draws the card's box (the live guide's box mapped into the frame, or a photo's straightened picture or guide placement) onto the strip's canvas, so the strip shows the card and not the whole frame; the frozen frame is still drawn under the pane for the reading. The shrink starts from `--from`, which the page sets to the guide's height over the picture's. The strip's name and collector line are what the reader read, escaped and on one line each. On a send failure the strip stays and shows them; nothing is sent that wasn't (spec 007 FR-3).
10. **One add button per finish under the details, with the existing add** *(the issue)*. "Add nonfoil", "Add foil", "Add etched" (the finish's name in lower case), "Add" alone for one finish or none listed (spec 080 decision 11); a special finish carries the star in `foil` (`special_finishes` of the collecting vocabulary, so the partial names no collectible); the foil marker read off the card relabels its button "Add foil · read from the card" and chooses nothing; the accessible name is today's, "Add Lightning Bolt MOM · 123 Foil". The add forms carry `data-turbo-frame="_top"`, since they sit inside the selection frame and an ended session's redirect must be a page visit as today and not a frame navigation (`scanner-reading` is updated to the new selectors, `.c-scanpane__add` and `scanner_selection`). An add is `POST /scanner/sitting/entries` with the printing, the finish and the reading key, answered as today (spec 082 decisions 10, 12; the pane closes, the after-add line and Undo, focus on the main button); one reading adds one copy; every button of the reading is disabled while one add is in flight (spec 009 AC-1.4; `scanner-reading`). The forms keep `data-scanner-event="add"` and the rank for measurement mode: the candidate's rank in the cards row and the first item of a printings row that the reading's answer rendered (rank 1), "other" otherwise (including the first item after "All printings").
11. **Where the other outcomes show** *(ruled by the maintainer, 2026-11-13; design "Left to each issue's spec")*. "Nothing could be read" and "No card matches what was read" (today's sentences) are said on the live camera's status line, the frozen frame goes and no pane opens, so the collector retakes with no extra tap; the answer is a stream that writes the status line (escaped) and leaves `#scanner_result` empty. The page learns the outcome from the markup, not the answer's kind: after the stream renders, `card-reader` hides the frozen frame when `c-scan--result` is not set; and `paneSay` (which waited for the pane and wrote anyway after about two seconds, which would reopen it) drops its sentence when the pane never shows, so neither "Done." nor the photo's no-edge sentence is written for a refusal (the no-edge sentence follows "Done." for a result and is dropped with it otherwise). Measurement mode's "capture wasn't stored" note is written to the pane's region unconditionally, as spec 082 decision 5 has it, so with a refused reading in development it opens the pane with the strip and the note and "Scan again" returns; its row logic is not touched. **The trade, written down:** a failed read shows no capture and no strip, so the collector cannot compare what was read with their picture to see why it failed (a blurred strip, a glare); the status line's sentence ("Line the card up with the guide and capture it again") is the whole answer, and measurement mode still stores the capture and the text. The same applies to a confidently wrong card (decision 3): "Scan again" is the way out. "The card catalog isn't ready yet" (today's sentence) and the 422 refusals (too long, no key) show in the pane with the strip, as today; a send failure shows the strip and the failure block with "Send again" or "Sign in", and "Scan again" discards it. A replay of an undone or changed entry (spec 082 AC-4.8) still empties `#scanner_result` and says its sentence in the pane's region.
12. **What leaves the page** *(ruled by the maintainer, 2026-11-13)*. "What the scanner read" and its rows; the candidates grid and each candidate's badge and evidence lines ("Matched by its name", "Artwork looks similar", the second "Matched by its artwork" line); the art-overrule sentence; the Other printings frame and its "Show N more" (`scanner_printings`); the interim body. Measurement mode keeps recording the parsed fields, outcomes, tier and overrule in its stored record, unchanged. With art matching off the band says nothing about art; the destination sheet's art line is unchanged.
13. **The pane fits the three phone sizes** *(my call; supersedes spec 080 decision 7's floors for a short shell)*. Spec 080's sums (a 232px fixed part, images 288px at most and 160px at least, the strip 144px or 96px under 720px) leave the add buttons below the fold at 360 × 560 and, with a band that wraps, at 360 × 640. This spec changes two numbers, both in `additions.css`: the images' floor is 96px (they still take what is left, 288px at most, so 390 × 844, 390 × 664 and 360 × 640 with a one-line band are as spec 080 drew them: 288, 184, 160), and a shell less than 600px high has a 64px strip with a 52px picture. At 360 × 560 the stage is 408px: 64 + band 56 + 28 + 80 + 16 + 52 + 16 leaves 96px for the images with a two-line band, so the band, Previous and Next, the details and the add buttons are all in view with no scrolling inside the pane. Below those sums, or with a wrapped set name (22px each), the pane's body scrolls inside the pane and the bars, strip and band never move; that is the accepted limit and the area doc says so. Spec 080's AC-4.7 and decision 7 are superseded for those two numbers, in this spec and in the index. In CSS this is the body's `grid-template-rows` floor (`minmax(calc(96px + …), …)`) and a second step, `@container scan (max-height: 599px)`, placed after spec 080's 719px one. Two of spec 080 AC-4.7's outcomes flip, not only its numbers: at 360 × 640 with a two-line band the images are 144px and nothing scrolls (it had them at 160px and scrolling), and at 360 × 560 nothing scrolls for a confident match (it scrolled). The two-line "…one digit corrected" band at 360 × 560 leaves exactly 96px, so the examples allow 1px. The 64px strip's text block (16 + 4 + 22 + 4 + 18) is exactly 64px.
14. **A captured frame is drawn once and the pane rises from the bottom, at rest before it is measured** *(spec 082's lesson)*. The strip's shrink and the pane's rise (200ms, none under reduced motion) are spec 080's. The system examples measure at rest: they wait for the pane's region to say its sentence and for the band to hold its text before reading a box, and run with `prefers-reduced-motion` where a box is read.
15. **The selection's request** *(my call)*. `GET /scanner/printings` (the route and controller of spec 009 Story 2, reworked) answers the selection frame for one card: params `card` (the identity's external key), `key` (the reading key), `set`, `number`, `finish_hint`, `artwork` (as today, validated as today), `match` (the printing that goes first, a printing of that card), `band` (one of `collector_line`, `collector_line_corrected`, `art`, `guess`: the first printing's band, a closed list; any other value is `guess`), `limit` (a multiple of 20, 20 to 200) and `current` (the printing to centre). A malformed key or unknown card answers 404 as today; an ended session answers the sign-in page, which the page shows as it did (`scanner-reading#printingsMissing`). The first selection is rendered by the reading's answer by the same partial. No new data is stored; nothing is sent to another host.
16. **The page's security and sitting-file rules are unchanged** *(my call)*. The new partials and controllers are first-party under the scanner's nonce and policy (`spec/requests/footer_spec.rb`'s pin passes unchanged); the card images come from the hosts candidates' images come from today (`catalog_url`). Every string a Turbo Stream writes is escaped (`ERB::Util.html_escape`) or comes from a partial, and the page writes the reader's text with `textContent` (`.claude/memory/turbo-stream-string-is-html-safe.md`). The new scanner partials that are the sitting's name no collectible (`spec/scanner_sitting_core_spec.rb`); the pane's partials are the scanner's controllers' and the collecting vocabulary's.
17. **No ADR, and the hosted door is unaffected** *(my call)*. The page follows spec 080's patterns; no collector-owned data, per-account state, admin page or source is added.

## Users and Context

**Primary user:** the collector adding a pile of cards on a phone, a deck, box or binder at a time (design, "How the maintainer scans").
**Usage context:** a phone held in one hand over a card on a table; most readings are confident and need one tap; a wrong printing is the common correction.
**User mental model:** capture, glance at my picture beside the match, one tap on foil or nonfoil; if it's the wrong printing, swipe; if the band is amber, look closer.

## User Stories

### Story 1: The capture beside the match

**As a** collector who has just captured a card
**I want** my capture beside what was read and the match under it
**So that** I can check the match by eye.

**Acceptance criteria:**

- [ ] **AC-1.1** Given a live capture When the answer shows a result Then the shell carries `c-scan--result`, the strip shows the capture's card box on its canvas (not the whole frame), "Read from the card", the name read and the collector line read on one line each ("nothing read" for a blank), and the pane is under it holding the band, the row and the first panel; the interim body is gone from the markup
- [ ] **AC-1.2** Given the strip When a reading's text has markup characters (`<b>x</b>`, `&amp;`) Then they show as text and no element is created
- [ ] **AC-1.3** Given a picked photo When its result shows Then the strip shows the photo's straightened picture, or the guide's box when no edge was found, and the same texts
- [ ] **AC-1.4** Given a send failure When it shows Then the strip shows what was read, the pane holds the failure's sentence in its region and "Send again" or "Sign in", no band shows text, and "Scan again" discards it

### Story 2: The status band

**As a** collector
**I want** the band to say how sure the scanner is
**So that** I know when to look closer.

**Acceptance criteria:**

- [ ] **AC-2.1** Given a first candidate with collector-line evidence When the pane shows Then the band is one `p.c-band.c-band--success` with the check icon and "Matched by its collector line", with ", one digit corrected" for the corrected evidence, and "Matched by its artwork" for art that belongs to one printing
- [ ] **AC-2.2** Given a first candidate that is sure of the card but whose printing isn't confirmed When the pane shows Then the band is `c-band--warning` with the alert triangle and "Printing not confirmed. Swipe to check."
- [ ] **AC-2.3** Given a first candidate that isn't sure of the card (name-only, no strong match, no art) When the pane shows Then the band is `c-band--warning` with a question mark in a circle and "Not sure of this card. Check it against your capture.", and the row holds the candidate cards
- [ ] **AC-2.4** Given a printings row When the collector swipes or steps to a printing other than the matched one Then the same band element reads "Not the printing that was read" in `c-band--warning` with the alert triangle, its form class, icon and sentence replaced in place (the band's element is the same node before and after, and no second band exists, hidden or not); on the matched printing again it reads the evidence sentence
- [ ] **AC-2.5** Given the band When it is read Then it has `role="status"`, its icon is `aria-hidden`, it holds a sentence at every state, and it is empty (and takes no space) while no result shows
- [ ] **AC-2.6** Given art matching off When a reading shows Then nothing about art is said in the band or the pane, and the destination sheet's art line is not in the pane's markup

### Story 3: The swipe row

**As a** collector whose printing is wrong
**I want** to swipe to the right one
**So that** choosing a printing is easy.

**Acceptance criteria:**

- [ ] **AC-3.1** Given a confident match of a card with 14 printings When the pane shows Then the row holds the matched printing first and the other 13 in `OtherPrintings` order, exactly one item carries `aria-current="true"` (the first), exactly one panel is not `hidden` (the first), the position reads "1 of 14 printings", and every item has its own panel with its add buttons rendered by the server
- [ ] **AC-3.2** Given the row When Next is activated Then the row scrolls one item, the second item alone carries `aria-current="true"` and the second panel alone is shown, the position reads "2 of 14 printings", the band is replaced (AC-2.4), Previous is enabled, and the camera's track is still `live`; Previous goes back
- [ ] **AC-3.3** Given the first and the last item centred When the row is read Then Previous is `disabled` at the first and Next at the last; and given focus on Next when the last item becomes centred Then focus moves to Previous
- [ ] **AC-3.4** Given the row focused When Right or Left Arrow is pressed Then it does what Next or Previous does
- [ ] **AC-3.5** Given the row scrolled with the scroll wheel or by script When it comes to rest Then the nearest item is centred and the controller notes it as AC-3.2 says (a fling announces once)
- [ ] **AC-3.6** Given a neighbour image When it is tapped Then it is centred
- [ ] **AC-3.7** Given the row When its styles are read Then it scrolls horizontally with scroll snap, draws no scrollbar, and its `scroll-behavior` is `smooth`, `auto` under `prefers-reduced-motion: reduce` (spec 080 AC-4.3, AC-4.4 unchanged)
- [ ] **AC-3.8** Given the first candidate isn't sure of the card When the pane shows Then the row holds the candidate cards (up to three, ranked), the position reads "1 of 3 possible cards" and the buttons are named "Previous card" and "Next card"; and the other candidate cards are not in a confident row
- [ ] **AC-3.9** Given a possible-cards row When "All printings" on a card's panel is activated Then the selection frame (not the page) is replaced by that card's printings row with that printing first, the position reads "1 of ‹n› printings", the band follows that printing's evidence, focus is on Next (on the row when Next is disabled), and the camera's track is still `live`
- [ ] **AC-3.10** Given a card with 30 printings When the pane shows Then 20 items and a "10 more printings" item show; the position reads "1 of 30 printings"; and when the more item's "Show 20 more" is activated the frame renders again with all 30 printings and no more item, the printing that was centred before it is centred, and focus is on Next
- [ ] **AC-3.11** Given the selection frame's request When it fails (network, server error, an ended session) Then the pane's region says "More printings couldn't be loaded. Tap “Show 20 more” again." or "The card's printings couldn't be loaded. Tap “All printings” again." (alert, for the button that was used), or the sign-in page shows, and the row stays as it was

### Story 4: The details block and one add per finish

**As a** collector
**I want** one block that describes the centred card and one button per finish under it
**So that** a confident match is one tap.

**Acceptance criteria:**

- [ ] **AC-4.1** Given the centred card When its panel is read Then it holds, each on its own line, its name, the set's full name (free to wrap), and the set code and number as a tag with the release year and the position at the end; the images carry no text
- [ ] **AC-4.2** Given a printing in nonfoil and foil When its panel is read Then it holds "Add nonfoil" and "Add foil", the foil one with the star icon (`aria-hidden`), their accessible names "Add Lightning Bolt MOM · 123 Nonfoil" and "Add Lightning Bolt MOM · 123 Foil"; one finish or none gives a single "Add"; a third finish gives "Add etched"
- [ ] **AC-4.3** Given the collector line's separator read as the foil marker When the panel is read Then the Foil button reads "Add foil · read from the card", its accessible name is unchanged, and no button is chosen or added
- [ ] **AC-4.4** Given a confident match When "Add foil" is activated Then one copy of that printing in foil is added with the sitting's condition and place (spec 009 AC-1.2, spec 040, spec 042), the pane closes, the camera is live, the after-add line says "Added Lightning Bolt MOM · 123, foil" with Undo, the main button has focus, and the count and top bar are redrawn (spec 082 AC-5.1)
- [ ] **AC-4.5** Given a swipe to another printing When its add button is activated Then that printing is added, not the matched one; and while one add is in flight every add button of the reading is disabled until the answer, which hands them back when it is a refusal (spec 009 AC-1.4)
- [ ] **AC-4.6** Given a refused add, a full lot, a failed add or a replay of an undone or changed entry When the answer arrives Then spec 082's AC-4.7 and AC-4.8 hold in the new pane: the result stays (or empties for a replay), the pane's region says today's sentence; and given an add after the session ended When the answer is the sign-in redirect Then it is a page visit (the add forms target `_top`), not a frame navigation

### Story 5: The pane fits the phone

**As a** collector on a small phone
**I want** the band, the buttons and the add buttons in view
**So that** I never scroll to add.

**Acceptance criteria:**

- [ ] **AC-5.1** Given a confident match (band "Matched by its collector line", a one-line set name) at rest in a 390 × 844, a 360 × 640 and a 360 × 560 viewport When the pane shows Then the band, Previous and Next, the details block and the add buttons are wholly inside the pane, the pane's body does not scroll, the document does not scroll, the images are 288, 160 and 112px high (within 1px; 96px at 360 × 560 with a two-line band), and the strip is 144, 96 and 64px
- [ ] **AC-5.2** Given the same viewports and the band "Not sure of this card. Check it against your capture." (a two-line band at 360px, and the 44px "All printings" line: a fixed part of 270px) When the pane shows Then at 390 × 844 the images are 278px and at 360 × 640 122px (within 2px) and the add buttons are inside the viewport with no scrolling inside the pane; at 360 × 560 the images are at their 96px floor and the pane's body scrolls by about 22px, the bars, strip and band in place
- [ ] **AC-5.3** Given the pane at rest in every state of AC-5.1 and AC-5.2 When the boxes of the strip, band, row, Previous, Next, details and add buttons are compared Then no two of them overlap but Previous and Next over the row's neighbours
- [ ] **AC-5.4** Given a 60-character set name and a 40-character card name at 360px wide When the pane shows Then both wrap inside the details block and nothing overflows horizontally
- [ ] **AC-5.5** Given the pane in the light and the dark theme When it is read Then every colour is a token (`on-success`, `on-warning` on the band) and the band's contrast holds (spec 080 AC-1.2)
- [ ] **AC-5.6** Given every control of the pane (Previous, Next, the add buttons, "All printings", "Show 20 more", "Send again", "Sign in") When its size is measured Then it is at least 44 × 44px, and the pane's controls are in `spec/system/small_controls_touch_floor_spec.rb`'s list

### Story 6: The other outcomes

**As a** collector whose capture didn't read
**I want** to be back at the camera at once
**So that** I retake without extra taps.

**Acceptance criteria:**

- [ ] **AC-6.1** Given "Nothing could be read" or "No card matches what was read" When the answer arrives Then the status line says today's sentence (escaped), no pane or strip shows, nothing is written to the pane's region (not "Done.", and not a photo's no-edge sentence), the frozen frame is gone, the main button is "Capture" and enabled, and nothing needs a "Scan again" tap
- [ ] **AC-6.2** Given the catalog isn't ready When the answer arrives Then the pane shows the strip and today's sentence in the alert style, and "Scan again" discards it; given a send failure, AC-1.4
- [ ] **AC-6.3** Given a card whose name or set name contains markup characters When any pane text, band sentence, announcement, status-line sentence or stream string is written Then it shows as text (request example with `<script>` in a name; system example reading the DOM)

### Story 7: Focus and live regions

**As a** collector using a screen reader or a keyboard
**I want** the pane announced and focus to stay where I am
**So that** I can use it without sight of the screen.

**Acceptance criteria:**

- [ ] **AC-7.1** Given a result opening When it shows Then the pane's `#status` holds a visually hidden paragraph "Done. " and the band's sentence with its tail, written after the pane shows, once, in the one region that is in view
- [ ] **AC-7.2** Given a swipe, Next or Previous When the centred item changes Then the band's text changes (its tail names "Printing ‹k› of ‹n›: ‹name›, ‹set›, ‹SET · number›"), the band element is the same node and keeps `role="status"`, and nothing is written to the pane's `#status`
- [ ] **AC-7.3** Given a sheet open over a result When it is open Then its own region still receives its sentences (the destination sheet's "Set" says its sentence there), the pane's regions are not the ones written, and an empty region stays rendered (spec 082 decision 10, AC-2.3)
- [ ] **AC-7.4** Given an add When it succeeds Then focus is on the main button as spec 082 decision 15 says, and the band and the strip are empty and hidden, the pane's `#status` empty, and the frozen frame gone
- [ ] **AC-7.5** Given "Scan again" When activated Then the band is emptied, `#scanner_result` and the pane's `#status` are emptied, the strip is hidden with the shell's `c-scan--result`, and the status line reads "Ready. Line the card up with the guide, then capture." (spec 082 AC-4.4)

### Story 8: What the page keeps and loses

**As the** maintainer
**I want** the old result gone and the rest unchanged
**So that** one pane replaces spec 009's page.

**Acceptance criteria:**

- [ ] **AC-8.1** Given the scanner page When its markup is read Then it holds none of `c-scanpane__results`, "What the scanner read", `c-scanner__candidate`, `c-scanner__result` or `scanner_printings`, and `#scanner_result`, the strip, the band and the selection frame exist
- [ ] **AC-8.2** Given measurement mode When a reading is stored Then its record is as before (the parsed fields, outcomes, tier, overrule, the events); the add event's rank is as decision 10 says; the run sheet and its row logic are not touched
- [ ] **AC-8.3** Given the scanner's policy and sitting files When `spec/requests/footer_spec.rb`'s scanner policy example and `spec/scanner_sitting_core_spec.rb` run Then both pass without change to their expectations (the core spec's list gains the new partials if any are the sitting's)
- [ ] **AC-8.4** Given the design system When it is read Then `Scanner.md`'s "What #345 builds" and "The result partial, until #345" sections are replaced by the pane as built, `StatusBand.md` and the README record the band's first use, and spec 080's decision 7 and AC-4.7 are recorded as superseded for the two numbers of decision 13

## Functional Requirements

### FR-1: The selection

`Scanner::Selection` turns a reading, or a card with a printing to put first, into the items the pane renders (decisions 2 to 4, 15).

**Must:**
- Rank nothing: take the reading's candidates as ranked and the printings in `Scanner::OtherPrintings` order.
- Name no collectible: the controllers hand it the reading and the vocabulary.
- Render every item's panel, band template and add buttons on the server.

**Must not:**
- Change `MTG::Reading`'s ranking or evidence, or add a query per item.

### FR-2: The pane's markup and controllers

The pane, the strip and the controllers (decisions 1, 5 to 10).

**Must:**
- Keep the band, the pane's region and the live regions of spec 082 rendered while empty.
- Replace the band's form, icon and sentence in place; keep Previous and Next's focus rule; note the centred card from the row's scrolling only.

**Must not:**
- Render a second band, build HTML from strings in script, send anything new, or add a copy without the collector's tap.

### FR-3: The layout numbers

Two numbers in `additions.css` (decision 13), proved at three sizes.

## Non-Functional Requirements

### Accessibility

- The band is a polite `role="status"` element that is announced at every change of the centred card (decision 8); the pane's region says the result opened; focus follows spec 047 and decision 7; every control is 44px or more; nothing is told by colour alone (icon and words); motion follows the README (spec 080 decision 14).
- Owed to the maintainer, as spec 082's was: a screen-reader pass on a phone over a result, a swipe, Previous and Next, an add and a refused add, checking each sentence is said once.

### Layout

- From 360px wide, both themes, no horizontal scroll; the pane's controls in view from 560px high in portrait for a confident match (decision 13).

### Performance

- A result's answer renders at most 21 items with their panels; images load lazily; no request is made by opening, swiping or stepping. Reported, not gated.

### Security

- See decision 16: the policy is unchanged, strings are escaped, the add and the selection need a sign-in and the sitting stays scoped by `Current.account`.

## Error Scenarios

| Scenario | Expected behaviour |
|----------|--------------------|
| Nothing read, or no card matches | The status line says so; no pane; the camera is live (AC-6.1) |
| The catalog isn't ready | The pane shows the strip and the sentence; "Scan again" (AC-6.2) |
| A send fails | The strip and "Send again" or "Sign in" (AC-1.4) |
| The selection request fails or the session ended | The pane's region says so, or the sign-in page shows; the row stays (AC-3.11) |
| A card with one printing | A row of one: Previous and Next disabled, "1 of 1 printings" reads "1 of 1 printing" |
| A printing with no image | The item shows the name and set number as text on `surface-sunken` (the tile's missing-image treatment), not an empty box |
| A printing with an unknown release date | The year is left out of the line |
| A refused add, a full lot, a failed add, a replay | spec 082 AC-4.7 and AC-4.8 in the new pane (AC-4.6) |
| Scripts off | The page needs script already (spec 082 decision 14) |

## Open Questions

None. The maintainer ruled questions 1 to 7 on 2026-11-13 (decisions 2 to 4, 7, 8, 11 and 12).

## Out of Scope (Future Considerations)

- A sitting's language: [#58](https://github.com/plainprogrammer/Collector/issues/58). Look-up mode, whose pane replaces the add buttons with the card's page link and what is owned: [#262](https://github.com/plainprogrammer/Collector/issues/262). Continuous capture: [#54](https://github.com/plainprogrammer/Collector/issues/54).
- Drag-to-scroll with a mouse; a gesture to choose a card from the possible cards.

## Supersedes

- **Spec 082 AC-4.2 (the interim body and "Done. What the scanner read…"), AC-4.3 (the body that scrolled: the selection scrolls only at the smallest sizes), AC-4.5 (the failure's name and collector line: in the strip), AC-4.6 (nothing read and no match go to the status line, decision 11) and AC-4.9 (the no-edge sentence follows a result only).**
- **Spec 080 AC-4.7's outcomes** at 360 × 640 with a two-line band and at 360 × 560 (decision 13).
- **Spec 009's candidate tile's link to the card page** (the tile is gone; the card page is reached from the collection or search), and the helpers `collector_outcome`, `scanner_art_outcome` and `scanner_overrule_note`, which become dead and are removed.
- **Spec 009's candidates grid and what hangs on it:** AC-1.1 as to where the add buttons are (now in the centred card's panel, one per finish, labelled as decision 10; their rule and names stand), AC-2.1 (the candidate tiles' badges: the band), AC-2.2 to AC-2.6 (the Other printings frame, its order stands in the row, its 20 and "Show N more" in decision 4), AC-5.5's page (the ranking stands), AC-6.5 (the foil marker's relabel stands, as "Add foil · read from the card"), and "What the scanner read" on the page (spec 009 AC-4.x as far as it lists the parsed set, number and language, and "Printing" and "Artwork" outcomes: the strip shows the name and collector line; measurement mode keeps the rest).
- **Spec 011 AC-7.1 to AC-7.5 as the page shows them:** the Artwork row, the badges and evidence lines, the overrule sentence (decision 12); the artwork's printings first stands in the row's order (AC-7.5's rule).
- **Spec 082 decision 11's interim body** (`c-scanpane__results`) and its "today's result partial unchanged"; spec 082's `Done. What the scanner read and its candidates are showing.` for decision 8's sentence; decision 25's removal is done here. "Scan again", the after-add line and the frozen frame are kept.
- **Spec 080 decision 7 and AC-4.7** for the images' floor (160px to 96px) and the strip under 600px (64px), decision 13; its AC-4.1 as to the strip's picture (the capture's card box, decision 9).
- **The design's decision 17 and 19** are built as written but for decisions 3 and 7 (cards 2 and 3 are not in a confident row; no mouse drag).

## Documents and Files Changed

| File | Change |
|------|--------|
| `app/models/scanner/selection.rb` (new), `app/models/scanner/other_printings.rb`, `app/models/mtg/reading.rb` (`Candidate#card_sure?`) | The selection, its items and bands; the predicate (FR-1) |
| `app/views/scanners/_scanner.html.erb`, new `_strip`, `_band`, `_selection`, `_panel`, `_item`, `_add_buttons`; removed `_result`, `_candidate`, `scanner/printings/*` | The pane (decisions 1, 5, 10) |
| `app/controllers/scanner/readings_controller.rb`, `printings_controller.rb`, `app/helpers/scanners_helper.rb`, `app/views/icons/` | The answer, the selection request, band and label helpers, the question mark, the chevrons and the star |
| `app/javascript/controllers/selection_controller.js` (new), `card_reader_controller.js`, `scanner_reading_controller.js`, `scan_shell_controller.js` | The centred card, the strip, the outcomes, the add lock, the announcement |
| `app/assets/stylesheets/collector/additions.css` | A `(spec 088 …)` block: the empty band, the pane's result container, the images' floor and the compact strip; `c-scanpane__results` and the unused `c-scanner__*` rules removed |
| `spec/system/scanner_*_spec.rb`, `spec/requests/scanner/*`, `spec/models/scanner/selection_spec.rb`, `spec/system/small_controls_touch_floor_spec.rb`, `spec/system/design_system_scanner_components_spec.rb` | Updated and new examples |
| `docs/architecture/scanner.md`, `docs/design-system/components/Scanner.md`, `StatusBand.md`, `Sheet.md` as needed, `README.md`; `docs/specs/README.md`; `CLAUDE.md` | The current rules and the index (Documentation) |
| `docs/specs/088-scanner-selection-pane/verification.md`, `screenshots/` | The record, the shots |

## Verification

- **Three sizes at rest** (AC-5.1 to 5.4): system examples open the scanner in a fixed-size frame from the collection page (the policy's `frame-src 'none'`; `.claude/memory/headless-firefox-narrow-frame.md`), substitute the camera (ADR 0002), capture, wait for the pane's region and the band's text, run with reduced motion, and compare boxes; each is shown to fail once with a rule broken.
- **The band** (AC-2.x): on the markup, per state, from request examples (`readings_spec`) and the system example that swipes; the element's identity is read before and after.
- **Focus and regions** (AC-3.3, 4.4, 7.x): `document.activeElement` and the regions' text and node identity are read; that each sentence is said once is the maintainer's screen-reader pass.
- **Escaping** (AC-1.2, 6.3): a card named `<script>` and a reading of `<b>`.
- **Unchanged** (AC-8.3): the scanner policy's pin and the sitting core spec.
- **Screenshots and GIFs** (desktop and phone, both themes; a confident match, a swipe, the three bands, a short phone, a failure) in `screenshots/` and the pull request, embedded by SHA-pinned links, looked at before the specs are trusted.
- **Documents**: read and recorded in `verification.md`.
