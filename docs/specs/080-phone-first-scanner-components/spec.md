# Feature 080: Design System: the Phone-First Scanner

**Status:** Approved by the maintainer at Gate A on 2026-11-12 (version 1.0.0, with my calls 3 to 12); version 1.1.0, revised after the spec review, approved by the maintainer on 2026-11-12 (decisions 13 and 14 ruled, the other changes confirmed); versions 1.2.0 and 1.2.1, revised after the second review and its re-check, confirmed by the maintainer on 2026-11-12; version 1.2.2, found while planning, approved by the maintainer with the plan on 2026-11-13
**Version:** 1.2.2
**Created:** 2026-11-12
**Last Updated:** 2026-11-13
**Depends on:** [the phone-first scanner design](../../superpowers/specs/2026-11-12-scanner-phone-first-design.md) (approved 2026-11-12; decisions 1 to 19 and "What it changes in the design system"), [spec 075](../075-small-controls-touch-floor/spec.md) (the 44px touch floor), [spec 063](../063-small-icon-stroke/spec.md) (icon strokes), [spec 047](../047-sitting-focus-after-redraw/spec.md) (announcements and focus)
**Branch:** `080-phone-first-scanner-components`
**Issue:** [#343](https://github.com/plainprogrammer/Collector/issues/343) (roadmap Theme D, the phone-first layout's first item)
**Frozen:** the current rules are in the [design system](../../design-system/README.md) and its component docs (whole spec: the tokens, the status band, the sheet, the scanner's shell and selection pane, the reduced-motion block, their previews and the CSS in `additions.css`); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.2.2 | 2026-11-13 | PATCH, found while planning, approved by the maintainer with the plan: a focused page's `<body>` carries `c-shell--focused` (the body's 8px margin and `min-height:100vh` would scroll a `100dvh` shell); a two-line band is 56px, not 60px (decision 15 allows no 10px padding); AC-5.9 and Verification name what stands in for the console, which headless Selenium cannot read here; the Files table lists the support files and the guards the plan adds. Decisions 7 and 8, FR-4, AC-3.1, AC-5.1 and AC-5.9 change in wording; no sum changes its outcome |
| 1.2.1 | 2026-11-12 | PATCH, the re-check of 1.2.0 (Fable; text-only, nothing blocking): the row's inline padding centres its first and last image and its block padding is the `space-4` and `space-3` of the sum (F1); an add button's text is 15px/20px with `space-2` side padding, and AC-4.11 includes the star and is in the system spec's list (F2); the two lines over the camera stay in the document and their text is replaced, with Undo outside the live region (F3); FR-3's Must follows decision 13 (F4); Out of Scope's links and the band's duty for #345 (F5); the sheet's bottom inset and a one-screen page with no sheet have owners (F6); the row's `scroll-behavior` rule sits in the app-wide block (F7). AC-3.7, 4.3, 4.6, 4.11 and 5.1 change |
| 1.2.0 | 2026-11-12 | MINOR, the second spec review (Fable; NEEDS REVISION; 0 blocking, 5 major, 10 minor) fixed before any plan, all my calls: the sums of decision 7 hold for a one-line band and set name, and the order when either wraps is stated (N1); the row draws no scrollbar (N2); the add buttons wrap their words, and a finish's label is "Add" and its name (N3); the short-screen rule answers to the shell's height, so a preview's frame and a test's frame behave as a phone does (N4); decision 13 is limited to a one-screen page, #344's duties are listed and go on its issue (N5); the band is one element whose content #345 replaces (N6); the details block's third line is set to 22px and the pane's side padding stated (N7, N8); the reduced-motion block's selectors and its `!important` (N9); the row's scrolling (N10); `[hidden]` and the dialog's defaults in a sheet (N11); Close is the cross icon (N12); the strip's name is one line (N13); the after-add line takes the status line's place (N14); FR-7 (N15); the nits. AC-1.6, 2.1, 2.2, 3.5, 3.7, 4.1, 4.3 to 4.8, 4.10, 5.1, 5.3, 5.11 and 6.4 change; AC-4.11 is new; Story 6 is renamed |
| 1.1.0 | 2026-11-12 | MINOR, the spec review (NEEDS REVISION; 1 blocking, 5 major, 11 minor) fixed before any plan. Ruled by the maintainer: the content notice sits in the foot of a focused page's sheets (decision 13) and one app-wide reduced-motion block (decision 14). My calls: the strip shrinks on a short screen and the pane's spacing is stated, so AC-4.7's sums hold (decision 7); sizes are outer sizes (decision 15); the state hooks are named (decision 8); the previews' frames (decision 10); the star for a foil button (decision 16); `scrim`'s literal; the copy the review found unsettled (decision 11); the after-add line is built by #344. AC-1.1, 1.3, 1.5, 2.1, 2.3, 2.4, 3.2, 3.4, 3.7, 4.1 to 4.3, 4.6, 4.7, 5.1, 5.3, 5.6, 5.8 and 5.9 change; AC-2.7, 4.10, 5.11 and 6.4 are new |
| 1.0.0 | 2026-11-12 | Approved at Gate A by the maintainer, as written: decisions 3 to 12 confirmed, and the bar and button sizes of Story 3 read from the mock-ups. No criterion changes |
| 0.1.0 | 2026-11-12 | Draft from issue #343 and the approved design. Decisions 1 and 2 ruled by the maintainer on 2026-11-12; decisions 3 to 12 are my calls for Gate A |

---

## Problem Statement

The scanner is being rebuilt as one phone screen that never scrolls ([#344](https://github.com/plainprogrammer/Collector/issues/344)) with a selection pane that is swiped through ([#345](https://github.com/plainprogrammer/Collector/issues/345)). The design is approved, but the design system has none of its parts: no page without the header and tab bar, no sheet, no filled status colour, no text colour that reads on one, no row of images that is swiped, and no rule about motion or gestures. An agent building #344 would invent them, and the first invention would become the pattern.

This spec draws them, with the real CSS, before any view is built: the rules in the README, three tokens, two new component documents, `Scanner.md`, the CSS in `additions.css`, and previews of the five steps and the three confidence states. It changes documents, the token files, one stylesheet and the previews. It changes no view, controller, script, helper, model, route or migration, and the scanner as shipped looks and works as it does today; the one thing a shipped page sees is that transitions stop under reduced motion (decision 14).

> **Terms.** The *shell* is the one-screen page: a top bar, the camera stage and a bottom bar. The *stage* is the camera's area between the bars. The *capture strip* is the frozen capture, shrunk, with what was read beside it. The *selection pane* (the *pane*) slides up over the stage after a reading and holds the status band, the row of card images, the details block and the add buttons. A *sheet* is a panel that opens from the bottom edge over a page. The *sitting* is the open run of adds with its condition and location (specs 040, 042).

## Goals

- The README states the rules the scanner's views will follow: focused pages, sheets, a swipe's button equivalent, motion, and the one filled use of a status colour.
- Three tokens exist in both themes: `on-success` and `on-warning`, which hold 4.5:1 on `success` and `warning`, and `scrim`.
- `Sheet` and `StatusBand` are documented as components any page may use, and `Scanner.md` documents the phone-first scanner's markup and copy beside the scanner as built.
- The CSS exists in `collector/additions.css`, in tokens and `c-*` classes only, and is proved in a browser.
- The five steps and the three confidence states are previewed at 390 × 844 in light and dark.

## Non-Goals

- Any view, controller, Stimulus controller, helper, route, model or migration: the page is #344's and the pane's behaviour is #345's.
- The guide's geometry (`scanner/geometry.js`, the stage's ratio and the guide's share of it) and its re-measure on live captures: #344. The previews draw a guide; its numbers are not settled here.
- Where "Use a photo", the artwork-matching line, the photo-framing hint, the camera-unavailable states, "Nothing could be read", "No card matches", the catalog-not-ready notice, the send failures and the art-overrule sentence sit in the new layout: #344 and #345 (the design's "Left to each issue's spec"). Their copy stands as it is today.
- The layout from 640px up, landscape, and the safe-area insets of the bars: #344.
- How many printings load at once, and how further ones arrive: #345.
- Look-up mode (#262), a sitting's language (#58), continuous capture (#54), detection on live frames (#53).
- A new ADR (decision 12).

## Decisions

Decisions 1 and 2 are the maintainer's, ruled on 2026-11-12. The design's own decisions (its numbers 1 to 19) stand and are cited as "design decision N". Decisions 3 to 12 are my calls, confirmed by the maintainer at Gate A on 2026-11-12; the spec review then changed decisions 4, 7, 8, 10 and 11, and the maintainer confirmed those changes and decisions 15 and 16, my calls, on 2026-11-12. The second review (version 1.2.0) changed decisions 6 to 8, 10 and 13 to 15, completed decision 11 (the finish labels, the wrapping add button, Close, the text sizes), narrowed decision 13 to a one-screen page, and added decision 17; version 1.2.1 fixed what its re-check found. Those are my calls, confirmed by the maintainer on 2026-11-12. Decisions 13 and 14 are the maintainer's, ruled on 2026-11-12 after the review.

1. **`Scanner.md` has two sections** (ruled 2026-11-12). It leads with "The phone-first scanner", marked as drawn by this spec and built by #344 and #345, and keeps today's text unchanged below it under "As built, until #344 and #345". Each later issue deletes what it replaces. Alternatives: a full rewrite now; a separate new document.
2. **A sheet is a native `<dialog>`, opened as a modal** (ruled 2026-11-12). The element gives the focus move on opening, Escape, and the focus return on closing. Opening it needs script, so a sheet is used only on a page that already needs script, or its opener is a plain link to a page that holds the same content. Alternative: the rules here and the element left to #344.
3. **The band's text tokens reuse values the palette has** *(my call)*. `on-success` and `on-warning` are `#ffffff` in the light theme (6.56:1 on `success` `#256a3a`, 5.93:1 on `warning` `#8a5a00`), and `#0c1f1f` and `#231a08` in the dark theme (8.03:1 on `success` `#6cc488`, 9.28:1 on `warning` `#e8b75a`; the values of the dark `on-brand` and `on-foil`). White on the dark theme's fills would be 2.12:1 and 1.85:1.
4. **A sheet's backdrop needs a colour, and gets a third token, `scrim`** *(my call)*. No token dims a page today, and `ink` at an opacity would lighten the page in the dark theme. `scrim` is black at 40% in both themes, written `#00000066` in each colour block (an eight-digit literal, which the contrast check's six-digit pattern skips: `scrim` carries no text). A browser whose `::backdrop` does not inherit custom properties draws no dimming, and the sheet's top border still separates it. Alternative: no dimming, the sheet's top border alone separating it from the page.
5. **The camera's area follows the theme** *(my call)*. The mock-ups drew the stage, the status line and the capture strip dark in the light theme; there are no always-dark tokens, and the live picture covers the stage anyway. The stage's ground and the capture strip are `surface-sunken`; the status line and the after-add line are `surface-raised` with a 1px `line-strong` border and `ink` text, so they read over any scene in both themes. Alternative: a set of always-dark tokens for camera chrome.
6. **Previous and Next sit on the neighbours** *(my call)*. The mock-ups drew no buttons. Each is a 44 × 44px button with a chevron, centred vertically on the visible part of the neighbouring image, so the row costs no extra height. Their names are "Previous printing" and "Next printing" ("Previous card" and "Next card" while the row holds possible cards). At either end of the row the button is disabled. Each draws a 20px chevron at stroke 1.5 on a `surface-raised` ground with a 1px `line-strong` border, so it reads over any image. The row scrolls smoothly when a button moves it, and at once under `prefers-reduced-motion: reduce` (`scroll-behavior`); the browser times that scroll, so the 200ms rule, which is about the transitions and animations the stylesheet times, does not bound it. The row draws no scrollbar (`scrollbar-width:none`): the buttons are the way to move it without a swipe, and a classic scrollbar would take 12 to 15px of the pane's height. Alternative: the buttons on the details block's last line, either side of the position, which adds 24px.
7. **The pane gives way on a short screen** *(my call; revised by the spec review)*. The design's sizes are for a 390 × 844 viewport; a phone's browser with its own bars leaves about 660 to 750px. The page is as tall as the dynamic viewport. The pane's fixed parts are stated so the sums can be checked: the band (40px), `space-4` above the row, `space-3` between the row and the details block, the details block (80px with a one-line set name: lines of 28px, 22px and 22px with `space-1` between them; the third line's height is set to 22px, since the tag on it is 20px and would otherwise make the line 20px), at least `space-4` above the add buttons, the add buttons (52px) and `space-4` below them: 232px. The images take the rest, at most 288px and at least 160px high, keeping 63:88; spare room goes above the add buttons. At 844px the pane is 844 − 56 − 96 − 144 = 548px and the images are 288px. In a viewport less than 720px high the capture strip is 96px with a 76px picture, so at 664px the pane is 664 − 56 − 96 − 96 = 416px and the images are 184px. With a one-line band and a one-line set name everything fits without scrolling from 640px (56 + 96 + 96 + 232 + 160); below that the pane's content scrolls inside the pane. A band whose sentence wraps is 56px (two 20px lines and `space-2` above and below) and a wrapped set name adds 22px: the images give up that room first, down to 160px, and then the pane's content scrolls (the longest sentences wrap at 360px and may at 390px, where the 28px spare at 844px takes a second line with the images still 288px; a 360 × 640 viewport scrolls with them). The details block and the add buttons have `space-4` at the sides. The row runs edge to edge: the `space-4` above it and the `space-3` below it in the sum are its own block padding, which also keeps the centred image's 2px outline from being clipped, and its inline padding is half the row's width less half an image's (92px at 390px with 206px images), so the first and the last image can be centred. The short-screen rule answers to the shell's own height (a container query on `c-scan`, whose height is the viewport's on a page), and a sheet's limit is 85% of its containing block, so a preview's 844px frame and a test's frame behave as a phone of that size does. The capture strip's height is fixed (144px or 96px) and the name read is one line ending in an ellipsis. The bars, the capture strip and the band never scroll.
8. **Class names and state hooks** *(my call; the hooks added by the spec review)*. The shell and its parts are a new block, `c-scan`; the pane is `c-scanpane`; the band is `c-band`; the sheet is `c-sheet`. The page's `<body>` carries `c-shell--focused` beside `c-shell--untabbed`: the app's body has the browser's 8px margin and `c-shell`'s `min-height:100vh`, which would scroll a shell that is `100dvh` high, so the class removes both. The layout sets it on a focused page (#344's). The shipped page's `c-scanner` rules are not changed, and the new blocks reuse none of them (the guide is `c-scan__guide`, drawn as `c-scanner__guide` is), so the scanner as built is untouched until #344 moves it. State is in the markup, never in a script's memory: `c-scan--result` on the shell shows the capture strip and the pane (without it the stage is the live camera); the main button's `disabled` attribute is the reading state; the row's centred item carries `aria-current="true"`, which draws its outline; the server renders one details-and-adds panel per card in the row (`c-scanpane__card`), and every panel but the centred card's carries `hidden`, so the collector sees one block. The band is one element above the row: a live region announces a change of its content, not an element revealed with `hidden`, so when the centred card changes its form class, icon and sentence are replaced in place; how they are replaced is #345's. Parts shown and hidden use the `hidden` attribute, and `c-scan`, `c-scanpane` and `c-sheet` each have their own `[hidden]` rule (`.c-scanner [hidden]` does not reach them). A sheet's layout is on `.c-sheet[open]`, so a closed dialog stays closed, and the dialog's default width limit, margin, padding and border are reset. Which script sets the hooks is #344's and #345's.
9. **`StatusBand` and `Sheet` are core components** *(my call)*. Their documents name no collectible and no scanner part beyond "first used by". The band has three forms: success with a check, warning with the alert triangle, warning with a question mark. `danger` has no band: errors stay with `StatusMessage`.
10. **Four previews, phone only** *(my call; the frames added by the spec review)*. `ScannerFlow.html` (the five steps), `ScannerConfidence.html` (the three states), `Sheet.html` (the destination sheet and the sitting's list, open over the shell, each with the content notice in its foot) and `StatusBand.html` (every form and sentence). Each screen is drawn in a 390 × 844 frame. The shell takes its height from the dynamic viewport, and a sheet is fixed to the viewport, so a preview's own `<style>` gives each frame its size, sets the shell's height to the frame's and makes the frame the containing block of a fixed sheet; that `<style>` holds frames and captions only, as the existing previews' do. Because the short-screen rule and the sheet's limit answer to the shell and the containing block (decision 7), a frame draws the 844px layout whatever the window's height. The camera is a flat `surface-sunken` area with a caption, and a card image is a blank 63:88 placeholder with a caption (the captions are the previews' own; the app puts no text on an image), so no card art enters the repository. A sheet in a preview is shown with the `open` attribute, which draws no backdrop; `Sheet.html` says so. `ScannerFlow.html`'s swipe step and one frame of `StatusBand.html`'s page show a middle position ("2 of 14 printings"), so both neighbours show. Icons with no partial yet (the question mark, the chevrons, the torch) are drawn inline in the previews; #344 and #345 add the partials they use. Close is the existing cross.
11. **Copy this spec settles** *(my call, from the design's words; completed by the spec review)*. Sentence case, as the design wrote it: "Add nonfoil", "Add foil" (today's buttons read "Nonfoil" and "Foil"); their accessible names stay today's ("Add Lightning Bolt MOM · 123 Foil"). A finish's button reads "Add" and the finish's name in lower case ("Add etched"). A foil marker read off the card relabels the button "Add foil · read from the card", which is wider than half a pane (two buttons are 175px each at 390px and 160px at 360px), so an add button wraps its words onto two lines, centred, inside its 52px. A sheet's Close is an icon button, the cross at 20px and stroke 1.5, 44 × 44px, named "Close". The main button's text is 16px 600 and an add button's 15px/20px 600, with `space-2` of side padding, so two lines (40px) fit the 50px inside its borders and the long label has 160 − 2 − 16 − 14 − 8 = 120px beside the star at 360px. The top bar's value has four forms: "Atraxa › Main · NM" (a place and a condition), "Blue binder" (a place alone), "No location · NM" (a condition alone) and "No location". The after-add line reads "Added Lightning Bolt MOM · 123, foil" ("Added Lightning Bolt MOM · 123" for a printing with no finish); it names no condition or place, which the top bar shows, and it is what the live region announces. The destination sheet's title is "Adding to"; the list sheet's title is today's heading, "This sitting: 12 cards". The count reads "12 added" (also "0 added" and "1 added") and its accessible name is "12 added. Show this sitting's cards." The back arrow's name is "Back".
12. **No ADR** *(my call)*. The design system is the project's own, in code (spec 057 decision 12); the rules and tokens are recorded in its documents and here.
13. **The content notice sits in the foot of a focused page's sheets** (ruled 2026-11-12, after the spec review). The footer is on every page, the scanner's included ([catalog core](../../architecture/catalog-core.md), spec 018), and a one-screen page that never scrolls has no room for it. A focused page that is one screen high and has no footer shows the notice's lines in the foot of each of its sheets (on the scanner, the destination sheet and the sitting's list), in the footer's own text style; a focused page that scrolls keeps the footer. This spec writes the rule, gives `Sheet` its foot and previews it; the scanner keeps its footer until #344 builds the page, so the rule is written as not yet used by a page. #344 builds it, and its duties are listed in Out of Scope and added to its issue. Alternatives: leave the placement to #344; the footer below the screen, reached by scrolling.
14. **One app-wide reduced-motion block** (ruled 2026-11-12, after the spec review). The export gives a button a 120ms colour fade and a tile a 150ms hover lift, and only `.c-scanner *` turns motion off today. `additions.css` gains one block that removes transitions and animations from every element, `::before`, `::after` and `::backdrop` under `prefers-reduced-motion: reduce`, so the README's motion rule is true of every component. A universal selector loses to any class rule, so the block's two declarations carry `!important`, the stylesheets' only use of it, and the block's comment says why. It is the one change a shipped page sees: buttons and tiles stop easing for a collector who asked for reduced motion. Alternative: a rule limited to the new blocks.
15. **Sizes are outer sizes** *(my call, from the spec review)*. The export sets no `box-sizing`, so every size in this spec is the element's whole size, border and padding included, and each new rule that sets a size sets `box-sizing:border-box`. The top bar is 56px high with `space-2` at its sides; the bottom bar is 96px high (a 64px main button with `space-4` above and below); the count button is 84px wide, so at 390px the main button is 390 − 32 − 24 − 84 − 56 = 194px wide. The bar and button sizes are read from the mock-ups. The band centres its content between its edges and sets a minimum height, and the capture strip centres its content in its fixed height, with no odd padding.
16. **A foil button carries the star** *(my call, from the spec review)*. The mock-ups drew a gold diamond, which only the logo has; the app's mark for a special finish is `FinishBadge`'s filled star. The button for any special finish carries that star at 14px in `foil` before its words, hidden from assistive technology; the words carry the meaning, so the fill's contrast floor for text does not apply.
17. **The after-add line takes the status line's place** *(my call, from the second review)*. Both sit `space-4` below the stage's top edge. While the after-add line shows, the status line is hidden; the next capture hides the after-add line and the status line returns. Each line's `role="status"` element stays in the document and its text is inserted or replaced (decision 8's rule: a reveal with `hidden` is not announced); the wrapper that draws the line may carry `hidden`, and "Undo" sits in the wrapper, outside the live region. How the text is replaced is #344's.

## Users and Context

**Primary users:** the agents and the maintainer who build #344, #345 and later #58 and #262, reading the design system before writing a view.
**Secondary users:** the collector, who meets these components as the scanner's page.
**Usage context:** `collector-design-system` tells every agent to read the README, the component's document and the preview before writing UI.
**User mental model:** scanning is a rhythm of capture, glance, one tap on a finish. The destination is set once and stays in view; a wrong printing is a swipe away; the band says how sure the scanner is.

## User Stories

### Story 1: The status band and its tokens

**As an** agent showing how sure a result is
**I want** a filled band with text that reads on it in both themes
**So that** confidence is seen at a glance and never by colour alone.

**Acceptance criteria:**

- [ ] **AC-1.1** Given the token stylesheet When each of its three colour blocks (light, dark, dark by the system's preference) is read Then `on-success` and `on-warning` are defined in each with decision 3's values and `scrim` with decision 4's, and `tokens.json` lists all three (the JSON is verified by reading; both files are edited by hand)
- [ ] **AC-1.2** Given each of the three colour blocks When the contrast of `on-success` on `success` and of `on-warning` on `warning` is computed Then each is at least 4.5:1, and an automated check fails when a token change takes one below it
- [ ] **AC-1.3** Given a success band and a warning band in the light and in the dark theme When their style is read Then the fill is the `success` or `warning` token, the text and the icon are the matching `on-` token, the text is 14px/20px 600 sans, and the band is at least 40px high with its content centred between its top and bottom edges and `space-4` at its sides
- [ ] **AC-1.4** Given each of the three forms When it is rendered Then it holds a 16px icon (a check, an alert triangle or a question mark in a circle) drawn at stroke 2, and a sentence, so no form is told apart by colour alone and the two warning forms differ by icon and words
- [ ] **AC-1.5** Given a band 360px wide whose sentence is wider than its 328px of content width When it is rendered Then the sentence wraps inside the band, the band grows, the icon stays on the first line, and nothing overflows
- [ ] **AC-1.6** Given `StatusBand.md` When it is read Then it states the markup, the three forms, that the band is a live region (`role="status"`), that `danger` has no band, that a band always carries an icon and words, that it is one element whose content is replaced when what it describes changes (never a second band revealed), the scanner's sentences as its first use, and that it names no collectible

### Story 2: The sheet

**As an** agent opening a page's secondary content without leaving the page
**I want** one bottom sheet with its focus and closing rules written down
**So that** the camera keeps running and I don't invent a dialog.

**Acceptance criteria:**

- [ ] **AC-2.1** Given a `c-sheet` dialog opened as a modal in a 390 × 844 viewport When its layout is read Then it is fixed to the bottom edge, exactly as wide as the viewport (the dialog's default width limit, margin and padding reset), at most 85% of the viewport's height, not displayed while closed, with `surface-raised` as its ground, a 1px `line-strong` top border, `radius-md` top corners, no shadow, and a backdrop rule whose colour is the `scrim` token
- [ ] **AC-2.2** Given an open sheet When its head is read Then it holds a title (`heading`) and a Close button (the cross icon at 20px, 44 × 44px, with the name "Close"), and the head stays in view while the sheet's body scrolls
- [ ] **AC-2.3** Given an open sheet whose content is taller than the sheet When it is scrolled Then the body scrolls inside the sheet, and the body's `overscroll-behavior` is `contain`, so reaching its end does not scroll the page behind
- [ ] **AC-2.4** Given a sheet opening When its motion is read Then the slide up takes at most 200ms, and with `prefers-reduced-motion: reduce` it takes none; closing is instant
- [ ] **AC-2.5** Given a sheet in the light and in the dark theme at 360px wide When it is rendered Then it has no horizontal overflow and a 60-character place name in its body wraps inside it
- [ ] **AC-2.6** Given `Sheet.md` When it is read Then it states the markup (`dialog.c-sheet`, its head, title, Close button and body), that it is opened as a modal, that focus moves into it on opening and returns to the control that opened it on closing, that Close, Escape and a tap on the backdrop close it, that it never navigates on a page that holds the camera, decision 2's rule for pages that work without script, its first two uses (the sitting's destination and the sitting's list), its foot and decision 13's rule, that a tap on the backdrop is closed by the page's script (#344's), and that it names no collectible
- [ ] **AC-2.7** Given a sheet with a foot (`c-sheet__foot`) holding two lines of a content notice, in both themes at 360px wide When it is rendered Then the foot is the last thing in the sheet's body, its text is the footer's (12px/16px `ink-muted`, links in `brand`, underlined on hover, with the focus ring), a 1px `line` rule separates it from the content above, and a long line wraps inside the sheet

### Story 3: The shell

**As an** agent building the one-screen scanner page (#344)
**I want** the top bar, the stage, the bottom bar and the lines over the camera drawn and documented
**So that** capture is always in view and I build the page, not its pattern.

**Acceptance criteria:**

- [ ] **AC-3.1** Given the shell on a `<body>` that carries `c-shell--focused`, in a 390 × 844 and in a 360 × 640 viewport When it is rendered Then it is exactly as tall as the viewport, the document does not scroll, the top bar is at the top, the bottom bar is at the bottom, and the stage fills everything between them
- [ ] **AC-3.2** Given the top bar When it is rendered Then it is 56px high (outer, decision 15) with `space-2` at its sides and holds, in order, a back arrow, the destination button and "Done", each at least 44px high, the arrow and "Done" at least 44px wide, and the arrow's icon is 20px at stroke 1.5
- [ ] **AC-3.3** Given the destination button When it is rendered Then it shows "Adding to" in 12px `ink-muted` above the value in 15px 600 `ink` with a chevron after it, and a value too long for the bar ends in an ellipsis on one line while "Done" keeps its full width
- [ ] **AC-3.4** Given the bottom bar at 390px wide When it is rendered Then it is 96px high and holds, in order, the count button (the number in `data` mono above "added", 84 × 56px), the main button (64px high and 194px wide, the room that is left) and the torch (56 × 56px, a 20px icon at stroke 1.5 with the name "Torch" and `aria-pressed`), with `space-3` between them and `space-4` at the sides, all outer sizes
- [ ] **AC-3.5** Given the main button's three states When each is rendered Then "Capture" is the primary button, "Capture" while a reading runs is disabled (50% opacity), and "Scan again" is the secondary button at the same place and size; the text is 16px 600 in each
- [ ] **AC-3.6** Given a bottom bar with no torch When it is rendered Then the count button keeps its place and size and the main button takes the torch's room
- [ ] **AC-3.7** Given the status line and the after-add line over the stage, in both themes When their style is read Then each has `surface-raised` as its ground, a 1px `line-strong` border, `radius-md` corners and `ink` text; the status line is centred, `space-4` below the stage's top edge, and the after-add line (its text in a `role="status"` element, "Undo" outside it) sits in its place, `space-4` below the stage's top edge, while the status line is hidden (decision 17), and spans the stage's width less `space-4` a side with its "Undo" button (at least 44px high) at its end
- [ ] **AC-3.8** Given an after-add line whose text is wider than the line at 360px When it is rendered Then the text wraps, "Undo" stays at the end on the first line, and nothing overflows
- [ ] **AC-3.9** Given the stage When it is rendered Then its ground is `surface-sunken`, the picture covers it, and the guide is drawn as today (a `brand` line with an `on-brand` dashed line inside it)

### Story 4: The selection pane

**As an** agent building the selection pane (#345)
**I want** the capture strip, the band's place, the image row, the details block and the add buttons drawn and documented
**So that** a confident match is one tap and another printing is a swipe.

**Acceptance criteria:**

- [ ] **AC-4.1** Given a result at 390 × 844 When it is rendered Then the capture strip is 144px high at the top of the stage and holds a 63:88 picture 124px high, centred between the strip's edges, and beside it "Read from the card" in 12px `ink-muted`, the name read in 15px 600 `ink` on one line, ending in an ellipsis when it is too long, and the collector line read in `data` mono (or "nothing read")
- [ ] **AC-4.2** Given the pane at 390 × 844 with a one-line set name When it is rendered Then it starts under the capture strip and ends at the bottom bar, the band is its top edge with `radius-md` top corners, the pane is 548px high, the images are 288px high, and the band, the image row, the details block and the add buttons are all in view with no scrolling inside the pane (decision 7's sum)
- [ ] **AC-4.3** Given the image row at 390px wide with the second of three images centred When it is rendered Then the centred image (`aria-current="true"`) is 206px wide (within 1px) and 63:88 with `radius-card` corners and a 2px `brand` outline that the row does not clip, the gap between images is `space-3`, 80px of each neighbour shows (within 1px: (390 − 206 − 2 × 12) ÷ 2), the row scrolls horizontally with each image snapping to the centre, the row's inline padding is 92px so the first and the last image can be centred, the row draws no scrollbar (its `clientHeight` is its height), and the page does not scroll sideways
- [ ] **AC-4.4** Given the row's Previous and Next buttons When they are rendered Then each is at least 44 × 44px, sits over the visible part of its neighbour, has its name and its chevron on a `surface-raised` ground (decision 6), shows a focus ring on keyboard focus, and is disabled at its end of the row; and the row's `scroll-behavior` is `smooth`, and `auto` under `prefers-reduced-motion: reduce`
- [ ] **AC-4.5** Given the details block When it is rendered Then it has `space-4` at its sides, is 80px high with a one-line set name, and shows, each on its own line, the card's name (20px 600), the set's full name (15px, wrapping when long), and a line with the set code and number as a tag and the year in `data` mono `ink-muted` at the start and the position ("1 of 14 printings") in `data` mono `ink-muted` at the end
- [ ] **AC-4.6** Given the add buttons for two finishes, and for one When they are rendered Then two buttons share the pane's width less `space-4` a side equally with `space-2` between them (175px each at 390px) and one takes the full width, each is a secondary button 52px high with 15px/20px 600 text and `space-2` of side padding, and a special finish's button carries the 14px star in `foil` before its words, hidden from assistive technology (decision 16)
- [ ] **AC-4.7** Given a pane in a 390 × 664 viewport with the band "Matched by its collector line" and a one-line set name When it is rendered Then the capture strip is 96px high with a 76px picture, the images are 184px high (within 2px) and keep 63:88, and the add buttons are in view with no scrolling inside the pane; in a 360 × 640 viewport with the same band the images are 160px high and nothing scrolls; in a 360 × 640 viewport with the band "Not sure of this card. Check it against your capture." the band is two lines, the images stay 160px high and the pane's content scrolls inside the pane; and in a 360 × 560 viewport the pane's content scrolls inside the pane while the bars, the capture strip and the band stay in place
- [ ] **AC-4.8** Given the capture strip shrinking and the pane sliding When their motion is read Then each takes at most 200ms, and with `prefers-reduced-motion: reduce` neither animates
- [ ] **AC-4.9** Given a set name of 60 characters and a card name of 40 at 360px wide When the pane is rendered Then both wrap inside the details block and nothing overflows
- [ ] **AC-4.10** Given a row of three cards whose second is centred When the pane is rendered Then only the centred card's `c-scanpane__card` panel is shown, the other two carry `hidden` and take no room, and a `c-btn` carrying `hidden` anywhere in `c-scan`, `c-scanpane` or `c-sheet` is not displayed
- [ ] **AC-4.11** Given two add buttons at 360px wide, one carrying the star and reading "Add foil · read from the card" When they are rendered Then each is 160px wide and 52px high, the long label wraps onto two centred lines inside its button, and nothing overflows

### Story 5: The rules, the documents and the previews

**As an** agent about to write a scanner view
**I want** the rules in the README, the scanner's document and the previews to agree
**So that** one reading tells me what to build.

**Acceptance criteria:**

- [ ] **AC-5.1** Given the README's Mobile and Hotwire section When it is read Then it states the focused-page rule (a task page may drop the header and the tab bar when it keeps a back arrow and its own primary action in view), that its `<body>` carries `c-shell--focused`, that a focused page of one screen with no footer shows the content notice in the foot of its sheets, that such a page has a sheet or keeps the footer, and that no page does yet (decision 13), that a sheet is the stated exception to "Nothing needs JavaScript to render or work" (decision 2), the sheet rule (decision 2, and that a sheet keeps the page's state where a navigation would lose it), and that a swipe always has a button that does the same
- [ ] **AC-5.2** Given the README's Color section When it is read Then it states that a status colour has one filled use, the status band, with `on-success` and `on-warning` as the text on it, that `danger` is never a fill, and that a band always carries an icon and words; and it names `scrim` as the backdrop of a sheet and nothing else
- [ ] **AC-5.3** Given the README When its motion rule is read Then it states that a transition takes at most 200ms and is instant under `prefers-reduced-motion`, that nothing moves without a cause the collector started, that one block in `additions.css` turns transitions and animations off app-wide under that preference (decision 14), and that a scroll the browser animates is smooth only without the preference
- [ ] **AC-5.4** Given the README's Components section When it is read Then `Sheet` and `StatusBand` are in the current set and an "App additions (spec 080 …)" line lists the classes of decision 8 and the three tokens
- [ ] **AC-5.5** Given `Scanner.md` When it is read Then its first section, "The phone-first scanner", says it is drawn by spec 080 and built by #344 and #345, and states the markup of the shell, the status line, the capture strip, the pane and the after-add line; and its second section, "As built, until #344 and #345", holds the text the document had before this spec, unchanged
- [ ] **AC-5.6** Given the first section of `Scanner.md` When its copy is read Then it gives the words of every state the design decided: the two status sentences, the top bar's four forms (decision 11), "Done", the count, "Capture" and "Scan again", "Read from the card" and "nothing read", the five band sentences and "Not the printing that was read", the two position forms, the add buttons and their accessible names, the after-add line's two forms with "Undo", Previous and Next's names, and the two sheets' titles; and it lists the states of this spec's third Non-Goal as placed by #344 and #345
- [ ] **AC-5.7** Given the first section of `Scanner.md` When its rules are read Then it states that capture and add stay the collector's taps, that the picture and the capture strip are drawn in the page and nothing new is sent, that the status line, the band and the after-add line are live regions, that the centred card is announced, that the band follows the centred card (design decision 14), what the row holds (design decision 17), and that the guide's geometry is #344's
- [ ] **AC-5.8** Given the four previews When their `<link>` tags are read Then each loads `preview-fonts.css`, `tokens.css`, `components.css` and `additions.css` and no other stylesheet file, its own `<style>` holds only the frames and captions of decision 10, and each honours `?theme=dark`
- [ ] **AC-5.9** Given the four previews opened in headless Firefox in the light and in the dark theme When they are rendered Then the five steps, the three states and the two sheets are drawn in 390 × 844 frames with the copy of the mock-ups and of decision 11, `StatusBand.html` shows every form and sentence, each page's four stylesheets load with rules and its inline script runs again without an error (headless Selenium cannot read the console here, as spec 060 recorded), and no frame has horizontal overflow
- [ ] **AC-5.10** Given the previews When their images are read Then no card art, set symbol or mana symbol is used: a card image is a blank 63:88 placeholder with a caption
- [ ] **AC-5.11** Given the README's Iconography section When its list of sizes is read Then it names the band's icons (16px, stroke 2), the foil button's star (14px, filled) and the 20px icons at stroke 1.5: the bars' (the back arrow, the destination's chevron, the torch), the row's chevrons and a sheet's cross

### Story 6: The shipped scanner is unchanged

**As a** collector scanning cards today
**I want** the scanner to look and work as it did
**So that** a design-system change is not a scanner change, and the one app-wide change is the reduced-motion block.

**Acceptance criteria:**

- [ ] **AC-6.1** Given the scanner page as shipped When the branch's suite runs Then every existing scanner example passes unchanged, and no file under `app/views`, `app/javascript`, `app/controllers`, `app/models` or `app/helpers` is changed by the branch
- [ ] **AC-6.2** Given `additions.css` When its existing blocks are compared with `main` Then no existing rule is changed or removed: the branch only adds blocks, each starting with a `/* ----------` heading that names `(spec 080 …)`, with no colour literal and no font family outside the tokens, and no new comment contains "spec 019", "spec 021" or "spec 023" (`spec/design_system_files_spec.rb` counts them)
- [ ] **AC-6.3** Given the repository's checks When `bin/ci checks` and `spec/design_system_files_spec.rb` run Then both pass
- [ ] **AC-6.4** Given a page with a `c-btn` and a tile's `c-tile__media` When the rules of the `prefers-reduced-motion: reduce` block apply Then both have no transition, and without them the transitions are the export's (120ms and 150ms)

## Functional Requirements

### FR-1: Tokens

`on-success`, `on-warning` and `scrim` are added to `tokens.json` and to each colour block of `tokens.css` (decisions 3 and 4).

**Must:**
- Hold 4.5:1 for each `on-` token on its fill in every block, guarded by an automated check beside spec 057's.
- Keep every existing token's value.

**Must not:**
- Be used for anything but text and icons on a band (`on-success`, `on-warning`) and a sheet's backdrop (`scrim`).

### FR-2: StatusBand (`StatusBand.md`, `additions.css`)

A band `c-band` with the forms `c-band--success` and `c-band--warning`; the icon chooses between the two warning forms. Markup: a `p` with `role="status"`, an icon and the sentence.

**Must:**
- Always carry an icon and a sentence; wrap a long sentence.
- Use only `success`, `warning`, `on-success` and `on-warning`.

**Must not:**
- Have a `danger` form, hold a control, or be used as decoration.

### FR-3: Sheet (`Sheet.md`, `additions.css`)

`dialog.c-sheet` with a head (title and "Close") and a body, as AC-2.1 to AC-2.5 and AC-2.7 describe.

**Must:**
- Be opened as a modal, so focus moves in and returns to the opener.
- Close by its Close button and by Escape (the element's own), and by a tap on the backdrop, which the page's script does (documented here, built by #344).
- Carry the content notice in its foot on a one-screen focused page with no footer (decision 13).
- Keep its last content clear of the bottom safe-area inset (`env(safe-area-inset-bottom)` under its body).
- Keep its head in view; scroll its body.

**Must not:**
- Navigate on a page that holds the camera; carry a shadow; be the only way to reach content on a page that works without script (decision 2).

### FR-4: The shell (`Scanner.md`, `additions.css`)

`c-scan`: a column as tall as the dynamic viewport with a top bar, the stage and a bottom bar; the status line and the after-add line over the stage (AC-3.1 to AC-3.9).

**Must:**
- Be the whole viewport: `c-shell--focused` on the `<body>` removes its margin and minimum height.
- Keep the main button in view in every state.
- Keep every control at 44px or more at every pointer.
- Follow the theme (decision 5).

**Must not:**
- Scroll the document; draw the app header or the tab bar; change a `c-scanner` rule.

### FR-5: The selection pane (`Scanner.md`, `additions.css`)

`c-scanpane` and the capture strip (AC-4.1 to AC-4.11): the band, a horizontally scrolling row with scroll snap and its Previous and Next buttons, one details block, the add buttons.

**Must:**
- Show which image is centred by an outline and by the details block, never by colour alone.
- Give way on a short screen as decision 7 says.
- Put no text on the images.

**Must not:**
- Rely on a swipe alone; hide the add buttons below the pane's fold at 390 × 844; scroll the page sideways.

### FR-6: Documents and previews

The README's rules (AC-5.1 to AC-5.4), `Scanner.md` (AC-5.5 to AC-5.7), `Sheet.md`, `StatusBand.md` and the four previews (decision 10). The new documents follow the existing documents' shape: a one-line summary, **Markup**, the rules as bullets.

**Must:**
- Leave the "As built" text of `Scanner.md` as it is.
- Name no collectible in `Sheet.md` or `StatusBand.md`.

**Must not:**
- Describe as live anything #344 or #345 has not built.

### FR-7: Reduced motion, app-wide (`additions.css`, README)

One block under `prefers-reduced-motion: reduce` (decision 14, AC-6.4, AC-5.3).

**Must:**
- Reach every element and the `::before`, `::after` and `::backdrop` pseudo-elements, and win over a class rule.
- Hold the row's `scroll-behavior:auto` too, so the README's "one block" is true.
- Leave every transition as it is without the preference.

**Must not:**
- Use `!important` anywhere else; change or remove the existing `.c-scanner *` rule.

## Non-Functional Requirements

### Accessibility

- Text on a band holds 4.5:1; every other text holds the README's floors on the surface it sits on.
- Nothing is colour-only: the band has an icon and words, the centred card an outline and the details block.
- Every control has a 2px `focus` ring and is at least 44px at every pointer (spec 075).
- Every motion is at most 200ms and absent under `prefers-reduced-motion: reduce`.
- The status line, the band and the after-add line are live regions; a sheet takes focus on opening and returns it on closing (spec 047's rule, kept).

### Layout

- Everything works from 360px wide, in both themes, with no horizontal scroll.
- The shell is as tall as the viewport at every height; a result fits without scrolling from 640px high, and below that the pane's content scrolls inside it (decision 7).

### Hosted door

Checked against the hosted-door rules ([north star](../../north-star.md)): the spec adds no collector-owned data, so there is nothing to export, no per-account state and no admin page; it uses no data of a source. Cost per account: none (documents, tokens, one stylesheet and previews).

### Documentation

- A change of a rule updates the document that states it in the same commit (`.claude/rules/documentation.md`).
- No RSpec example reads a prose document (`.claude/rules/testing.md`): document criteria are verified by reading and recorded in `verification.md`. The token, CSS and layout criteria are proved by examples.

## Error Scenarios

| Scenario | Expected behaviour |
|----------|--------------------|
| The destination's value is very long ("A deck with a very long name › Considering · NM") | One line ending in an ellipsis in the top bar; the full value is in the sheet (AC-3.3) |
| No location and no condition are set | The top bar reads "Adding to" and "No location" |
| The camera reports no torch | The torch is not rendered and the main button takes its room (AC-3.6) |
| The collector line was not read | The capture strip shows "nothing read" in its place |
| A printing has one finish, or none | One full-width "Add" button |
| The row holds one card | No neighbour shows; Previous and Next are both disabled |
| A band's sentence does not fit one line | It wraps and the band grows (AC-1.5) |
| The viewport is short (a browser's own bars, a small phone) | Below 720px high the capture strip is 96px; the images shrink to 160px at least; below 640px the pane's content scrolls inside the pane (AC-4.7) |
| A browser's `::backdrop` does not inherit the tokens | The sheet opens with no dimming; its top border separates it (decision 4) |
| A source supplies no content notice | A sheet has no foot |
| A sheet's content is taller than 85% of the viewport | The sheet's body scrolls; its head stays (AC-2.2, AC-2.3) |
| The collector prefers reduced motion | The shrink, the slide and the sheet are instant, the row scrolls at once, and buttons and tiles app-wide stop easing |
| The name read is long | One line ending in an ellipsis in the capture strip; the strip keeps its height |
| The band's sentence or the set's name wraps on a short screen | The images shrink to 160px at least, then the pane's content scrolls inside the pane (AC-4.7) |
| A browser has no scroll snap | The row still scrolls and Previous and Next still move it |

## Open Questions

None. The maintainer ruled decisions 1, 2, 13 and 14 and confirmed decisions 3 to 12, 15 and 16 and 17, and the changes of 1.2.0 and 1.2.1.

## Out of Scope (Future Considerations)

- The one-screen page, its sheets' contents, the layout's `c-shell--focused` on the page's `<body>`, the after-add line with Undo (its issue names it; #345 keeps it), the script that closes a sheet on a tap on its backdrop, the icon partials it uses, and the guide's geometry and re-measure: [#344](https://github.com/plainprogrammer/Collector/issues/344).
- The content notice on the scanner (decision 13), also #344's: it supersedes spec 018 FR-2's "every page", "at the end of the page" and "with no JavaScript" for the scanner, updates `Footer.md` (one footer per page, a child of the shell, no JavaScript) and the [catalog core](../../architecture/catalog-core.md) area doc, extends `spec/footer_core_spec.rb` to the foot's partial, and says where the notice shows with script off and with the camera unavailable. These bullets are added to issue [#344](https://github.com/plainprogrammer/Collector/issues/344) when this spec is committed; the pane's icon partials and the band's replacement in place (decision 8) are added to [#345](https://github.com/plainprogrammer/Collector/issues/345).
- The pane's behaviour (freeze, shrink, slide, the row's contents, "Scan again"): [#345](https://github.com/plainprogrammer/Collector/issues/345).
- A sitting's language in the destination sheet: [#58](https://github.com/plainprogrammer/Collector/issues/58). Look-up mode: [#262](https://github.com/plainprogrammer/Collector/issues/262).
- Always-dark tokens for camera chrome (decision 5's alternative).

## Supersedes

- Nothing shipped, and no rule of a shipped page but one: under `prefers-reduced-motion` every component loses its transitions (decision 14), which no spec promised. The supersession of spec 018's footer "on every page" (decision 13) is #344's to record when the scanner's footer goes. The supersessions of spec 009 (the candidates grid, "What the scanner read", the Other printings frame) are #345's to record when it replaces them.
- The design's "Left to each issue's spec" item "the sheets' markup": settled here (decision 2). The design is a design document, not a shipped spec; its text is not edited.

## Documents and Files Changed

| File | Change |
|------|--------|
| `docs/design-system/README.md` | Mobile and Hotwire (focused pages and their content notice, sheets, swipes), Color (the status band, `scrim`), the motion rule, Iconography's sizes, Components list and the App additions line |
| `docs/design-system/components/Sheet.md`, `StatusBand.md` | New (FR-2, FR-3) |
| `docs/design-system/components/Scanner.md` | A new first section; today's text kept as the second (decision 1) |
| `docs/design-system/tokens.json`, `app/assets/stylesheets/collector/tokens.css` | `on-success`, `on-warning`, `scrim` |
| `app/assets/stylesheets/collector/additions.css` | New blocks, each under its own `(spec 080 …)` heading, the app-wide reduced-motion block among them (decision 14) |
| `spec/support/` (a reduced-motion helper, modelled on `CoarsePointer`) | New: applies the rules of a `prefers-reduced-motion: reduce` block, for AC-2.4, AC-4.4, AC-4.8 and AC-6.4 |
| `docs/design-system/previews/ScannerFlow.html`, `ScannerConfidence.html`, `Sheet.html`, `StatusBand.html` | New |
| `spec/design_system_tokens_spec.rb` | The `on-` tokens' contrast (AC-1.2) |
| `spec/system/design_system_scanner_components_spec.rb` (new) | The CSS and layout criteria (AC-1.3 to 1.5, 2.1 to 2.5, 2.7, 3.1 to 3.9, 4.1 to 4.11, 6.4) |
| `docs/specs/README.md` | This spec's row |
| Issues #344 and #345 | The bullets of Out of Scope (decision 13's duties, `c-shell--focused`, the backdrop tap, the icon partials, the band's replacement in place) |
| `spec/support/design_system_probe.rb` (new), `spec/system/design_system_deck_rules_spec.rb`, `design_system_deck_components_spec.rb` | The probe helpers, moved from the two deck specs, which now include the module |
| `spec/support/scan_markup.rb` (new) | The parts' markup, for the examples and the previews |
| `spec/design_system_files_spec.rb` | `!important` only in the reduced-motion block; the blocks' guard (AC-6.2) |
| `docs/specs/080-phone-first-scanner-components/screenshots/` | The previews' shots |
| `docs/specs/080-phone-first-scanner-components/verification.md` | The record |

## Verification

- **Document criteria** (AC-1.6, 2.6, 5.1 to 5.7, 5.11, and `tokens.json` in AC-1.1): read against the text; the quotations are recorded in `verification.md`.
- **Token criteria** (AC-1.1, 1.2): examples that read `tokens.css`, beside spec 057's.
- **CSS and layout criteria**: a system example per criterion group, in headless Firefox, adds the components' markup to a real page (no view exists), reads computed style and layout at the stated viewport sizes, and is shown to fail with its rule removed. The shell's examples (AC-3.1, 4.2, 4.7) replace the page's body with the shell inside a frame of the stated size, since the page's own header and content would scroll the document. A backdrop's colour is read from the stylesheet's rule; an implementer who finds the `::backdrop`'s computed style reported adds that expectation.
- **Previews** (AC-5.8 to 5.10): the `<link>` tags are read; each preview is opened in headless Firefox in both themes, the stylesheets' rule counts and a second run of the inline script are read, and the screenshots go in `verification.md` and the pull request.
- **Unchanged scanner** (AC-6.1, 6.2): the branch's diff against `main` is read for the paths named, and the full suite runs.
- **Frames.** A viewport size in a criterion is an iframe of that size (`open_in_narrow_frame` with its `height:`), so the dynamic viewport is the frame's.
- **Repository checks** (AC-6.3): `bin/ci checks`, recorded in `verification.md`; the full `bin/ci` run is in the pull request.
- **Final visual review**: before the pull request is marked ready, screenshots of every preview in both themes go to the maintainer and into the pull request body.
