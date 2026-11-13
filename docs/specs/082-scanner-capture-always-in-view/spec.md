# Feature 082: Scanner: Capture Always in View

**Status:** Draft for Gate A
**Version:** 0.1.0
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Depends on:** [spec 080](../080-phone-first-scanner-components/spec.md) (the shell, the sheet, the lines over the camera, `c-shell--focused`; frozen into the [design system](../../design-system/README.md)), [the phone-first scanner design](../../superpowers/specs/2026-11-12-scanner-phone-first-design.md) (approved 2026-11-12), the scanner as built ([scanner](../../architecture/scanner.md) area doc; specs 007, 009, 011, 040, 042, 047, 065)
**Branch:** `082-scanner-capture-always-in-view`
**Issue:** [#344](https://github.com/plainprogrammer/Collector/issues/344) (roadmap Theme D, the phone-first layout's second item)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-13 | Draft from issue #344, spec 080 and the design. Decision 1 ruled by the maintainer on 2026-11-13 (option C: no cards soon; the live re-measure is the last gate, on a new corpus). Decisions 2 to 21 are my calls for Gate A; the re-measure's bar (decision 4) is a scope question for the maintainer |

---

## Problem Statement

The scanner is one scrolling column: the page heading, a 3:4 camera stage, the controls, "What the scanner read", the candidates, then the sitting's panel with its Condition and Location form. On a phone the candidates land below the camera, so every card is capture, scroll down, add, scroll back up; spec 009 measured a median of 23 s a card. The design of 2026-11-12 makes the scanner one screen, and spec 080 drew its parts in the design system. Nothing renders them yet.

This spec builds the page: the shell of spec 080 with the sitting's destination in the top bar, the camera filling everything between the bars, and the capture button in the bottom bar, always in view. The sitting's choices and its list move into sheets, so opening them never releases the camera. A result opens in the selection pane's place holding today's candidates; after an add the camera is live again with a line confirming it and Undo. The guide grows with the stage, so the reading is measured again on live captures at the new framing before this ships. The pane's own layout (the band, the swipe row, the details block, the add per finish) is [#345](https://github.com/plainprogrammer/Collector/issues/345); the sitting's language is [#58](https://github.com/plainprogrammer/Collector/issues/58).

> **Terms.** As spec 080's: the *shell*, the *stage*, the *pane*, a *sheet*, the *sitting*. The *destination* is the top bar's button showing the sitting's place and condition. The *main button* is the bottom bar's middle button ("Capture", or "Scan again" while a result shows). The *status line* and the *after-add line* are the two lines over the camera (spec 080 decision 17). The *full framing* is this spec's guide in the full-height stage; the *shipped framing* is the guide of specs 007 to 011 (the stage 3:4, the guide 80% of its height and at most 90% of its width). A *stage notice* is a message centred on the stage when the camera or the engine can't be used.

## Goals

- On a phone the scanner is one screen that never scrolls, and the main button is in view in every state.
- The camera is as large as the screen allows; the guide grows with it, and the page's guide and the capture's crop are one geometry.
- The sitting's destination is always visible in the top bar, and the destination and the sitting's list open as sheets that keep the camera running.
- A result is reached and dismissed without scrolling the page; an add returns to the live camera with a line that confirms it and offers Undo.
- The reading is no worse at the full framing than at the shipped framing, measured on live captures of the same cards, before this ships.

## Non-Goals

- The pane's own layout and behaviour: the capture strip, the shrink and slide, the status band, the swipe row with Previous and Next, the details block, one add button per finish under it, "What the scanner read" leaving the page, the Other printings frame's replacement: #345. Today's result partial, candidates grid and Other printings frame move into the pane unchanged.
- Any change to how a card is read or ranked: the strips, the OCR settings, the detector, the art fingerprint, the ranking. Only the live guide's size changes (decision 3).
- The photo path's geometry: a picked photo keeps the shipped framing (decision 3).
- A sitting's language (#58), look-up mode (#262), continuous capture (#54), detection on live frames (#53), Japanese cards (#55).
- New collector-owned data, a migration, a new route or request parameter (decision 20).
- A new ADR (decision 21).

## Decisions

Decision 1 is the maintainer's, ruled on 2026-11-13. Decisions 2 to 21 are my calls for Gate A. Decisions of the design are cited as "design decision N", of spec 080 as "spec 080 decision N".

1. **The re-measure is the last gate and runs on a new corpus** (ruled 2026-11-13, option C). The cards are not at hand soon; the maintainer may still have the 35 cards of specs 010 and 011 but expects to build a new corpus. So the re-measure (Story 7) names no earlier card: it runs on a corpus the maintainer gathers, verified as `.claude/memory/verify-corpus-manifests.md` lists, and the plan orders it last, with nothing else waiting on it. The pull request stays a draft until it has run. Alternatives: the 35 cards of spec 011 (not at hand); no re-measure (refused by the issue).
2. **The guide grows with the stage, and the shipped framing stays measurable** *(my call)*. The live guide is centred in the stage, 80% of the stage's height and at most 97.5% of its width, keeping 63:88. At 390 × 844 the stage is 390 × 692 and the guide 380 × 531 (the design's "about 380 × 536"); at 360 × 640 the stage is 360 × 488 and the guide 279 × 390. On a phone whose camera delivers 1080 × 1920, a card filling the guide is about 1,050 px wide in the frame, against about 825 px at the shipped framing. `scanner/geometry.js` holds the shares; the camera controller draws the guide from them and maps it into the frame with them, so the page and the crop are one geometry (AC-3.1). Measurement mode can draw the shipped framing instead (decision 5), so both are measured on the same cards. Alternatives: the shipped framing's card size in the tall stage (no re-measure needed, but a smaller card on a larger screen, against design decision 2); the guide as wide as the stage (no margin to aim with).
3. **The photo path keeps the shipped framing** *(my call)*. A picked photo is placed in a 3:4 view with the shipped guide, by detection or by guide placement, as today (spec 009 AC-7.1, AC-7.2). The photo has no stage; its geometry was tuned on photos and the detector's strips assume it. `geometry.js` keeps the shipped shares under their own name for the photo path and measurement mode, and the live guide's shares under another.
4. **The re-measure's bar** *(my recommendation; a scope question for the maintainer at Gate A)*. A paired run on the same cards in one sitting: each card is captured once at the shipped framing and once at the full framing, in alternating order per card. The full framing passes when its right card first is at most one card below the shipped framing's on the same cards, and its exact printing (cards whose collector line prints a set code) at most two below. If it fails, the full framing's guide becomes the shipped framing's card size inside the tall stage (decision 2's first alternative), which the same run has measured, and no further sitting is needed. The corpus: about 40 cards the maintainer owns, none of the 12 tuning cards of spec 007, at least 10 sets, at least 8 foils, at least 5 cards whose frame prints no set code, a few with a light name on a dark bar; every row resolves to one printing (`scanner:ground_truth`), overlap with earlier corpora is reported, and each foil value is checked against the card. Alternatives: (B) one run at the full framing with an absolute bar, at least 31 of every 35 right card first (spec 009's first captures, text only) or 34 of 35 with art on (spec 011), which can't be compared fairly across corpora and phones; (C) report the figures with no bar, the maintainer judging them.
5. **Measurement mode is the same page** *(my call)*. The re-measure needs the stage the collector will use, so measurement mode renders the same shell; its run panel (the manifest row, the counts, Skip, Store again, its notices) opens as a third sheet, "Measured run", from a button in the top bar that only measurement mode renders. The framing it draws and crops with is a development setting read once at boot (`COLLECTOR_SCANNER_FRAMING`, `full` by default, `shipped` for the paired run's other half), recorded with each capture, and run directories differ per framing (`COLLECTOR_SCANNER_RUN_DIR`), so the findings tooling scores each framing as a run of its own. The setting is ignored, and cannot be set, outside measurement mode. Alternatives: a framing switch on the page (a run would mix framings within one manifest row); the old page kept for measurement (it measures nothing the collector will use).
6. **The page is a focused page** *(spec 080 decision 8, built here)*. The scanner view asks the layout for a focused page; the layout then gives the `<body>` `c-shell--focused` beside `c-shell--untabbed`, renders no app header, no tab bar, no footer and no `#status` region of its own (the scanner page places its own, decision 11). Every other page's layout output is unchanged.
7. **The top bar** *(design decisions 3 and 4; spec 080 decision 11's copy)*. Back is a link to the collection page, named "Back", with the back icon. The destination is a button, "Adding to" above the value ("Atraxa › Main · NM", "Blue binder", "No location · NM", "No location"; the place is its label, a zone as "Deck › Zone", and the condition its short label); it opens the destination sheet. "Done" is the link to today's confirm page and shows only while a sitting is open (spec 009 AC-3.7); with none the destination takes its room. Every answer that changes the sitting (an add, an Undo, a "Set") redraws the destination and Done.
8. **The bottom bar** *(design decision 5; spec 080 decision 11)*. The count button reads the sitting's count over "added" ("0 added" with no sitting), with the accessible name "12 added. Show this sitting's cards.", and opens the list sheet. The main button is "Capture" (primary) while the camera is live and no result shows, disabled while the engine loads, while a reading runs and while the camera is unavailable; it is "Scan again" (secondary) while a result shows (decision 13). The torch shows only where the camera's track reports one, as today, and its accessible name is "Torch" with `aria-pressed`. Every answer that changes the sitting redraws the count.
9. **The two sheets hold today's panel, divided** *(my call; spec 080 decision 2)*. Each is a `dialog.c-sheet` opened with `showModal()` by a small Stimulus controller, closed by Close, Escape or a tap on its backdrop. The destination sheet, "Adding to", holds today's Condition and Location form (`_picker`, its fieldset, legend, selects and "Set", unchanged), then the art line (when art matching is on) and the photo hint. The list sheet's title is today's heading ("This sitting: 12 cards, Near mint, in Blue binder"), focusable as today (spec 047), and its body holds today's entries with Details, Undo and "Show all", or today's empty-state sentences. Neither sheet holds "Done" (the top bar does). Both end with the content notice's foot (decision 16). A form in a sheet answers with a Turbo Stream, as today; nothing in a sheet navigates but "Details" (Edit copy, which ends the scanning, as today).
10. **A sheet's announcements are inside it** *(my call)*. While a modal dialog is open the rest of the page is inert, and a live region outside it is not announced. So each sheet holds its own `role="status"` region at the top of its body: "Set"'s sentence (accepted or refused) goes into the destination sheet's, and an Undo's sentence into the list sheet's. The same answer also writes into the after-add line (decision 12): of the two, only the one in a shown, non-inert place is announced, so a collector hears each sentence once whichever control sent it.
11. **A result opens in the pane's place** *(design decision 9's place, #344's interim content)*. On capture the live picture pauses on the captured frame (the track keeps running) while "Reading the card…" shows; the reading's answer sets `c-scan--result` on the shell, and the pane (`c-scanpane`) fills the stage over the frozen frame. The pane holds, from the top: the page's `#status` region (the add's refusals and failures, Other printings' announcements), the send failure with its name and collector line, "Send again" and "Sign in" (today's), and `#scanner_result` with today's result partial unchanged ("What the scanner read", the art overrule sentence, the candidates grid with their add buttons, Other printings). The pane's content scrolls inside it; the bars never move. "Nothing could be read", "No card matches" and "The card catalog isn't ready yet" stay in the result, as today. The capture strip is #345's: no strip is rendered here. The reading's spoken line becomes "Done. What the scanner read and its candidates are showing." (today's "…are below.").
12. **After an add the camera is live and the after-add line confirms it** *(design decision 11; spec 080 decisions 11 and 17)*. A successful add clears the result, which removes `c-scan--result` and resumes the live picture; the after-add line's text becomes "Added Lightning Bolt MOM · 123, foil" ("Added Lightning Bolt MOM · 123" for a printing with no finish), which is what is announced, with Undo for that entry beside it, outside the live region; the status line is hidden while the after-add line shows, and the next capture empties and hides the after-add line and shows the status line. Undo from the line removes the copy as today and the line's text becomes today's "Removed 1 × ‹name› (‹SET› · ‹number›, ‹finish›) from your collection." with no Undo. A replay of an undone or changed add, a refused add and a full lot keep the result showing and say so in the pane, as today. The after-add line names no condition and no place: the top bar shows them.
13. **"Scan again" is built here** *(my call; design decision 12)*. With the result filling the stage the collector can't aim, and without this button only an add would bring the camera back. While a result shows, the main button reads "Scan again" in the secondary style at the same place and size; it discards the reading (empties the result and the send failure), removes `c-scan--result`, resumes the live picture and gives the status line "Ready. Line the card up with the guide, then capture.". The reading's key is dropped with it, so nothing about it is sent. #345 keeps the button and its behaviour. Alternative: a Close button in the pane (one more control, and a second way to do the same thing once #345 lands).
14. **Where the other controls and lines sit** *(my call; the design's suggestions)*. "Use a photo" is a secondary button at the stage's bottom-left corner, `space-4` in from its edges, over the camera, 44px high, with today's file input inside its label, and is shown whenever the engine is ready, the camera live or not. The art line and the photo hint are in the destination sheet (decision 9). A stage notice is centred on the stage, on `surface-raised` with a `line-strong` border, for: the camera unavailable (today's reason sentences, "Try the camera again" except for the insecure context, and "Use a photo" as the way in); the engine failed ("The scanner couldn't load…", "Load the scanner again"). Today's `<noscript>` sentence is a stage notice too.
15. **Focus** *(spec 047, kept)*. A sheet takes focus on opening and returns it to its opener on closing (the element's own); a tap on the backdrop closes it the same way. After "Set" focus goes to "Set" (spec 047 decision 2); after an Undo from the list sheet, to the list sheet's title; after an Undo from the after-add line, to the main button, since the line's Undo is gone. An add's redraw names no focus target, as today. A redraw that replaces a sheet's content leaves the dialog open: the answer replaces the sheet's body and title, never the `<dialog>` element.
16. **The content notice moves into the sheets' foot on the scanner** *(spec 080 decision 13, built here)*. The scanner has no footer. Each of its sheets ends with the notice's lines in `c-sheet__foot`, from one core partial that the footer renders too (the lines and their links as the footer draws them, spec 018 FR-1, FR-4), so the core still names no collectible (`spec/footer_core_spec.rb`, extended to the partial). With script off the notice's lines are in the `<noscript>` stage notice under its sentence; with the camera unavailable the sheets still open, so the notice is in their foot as always. A source that supplies no notice gives no foot. Supersedes spec 018 FR-2's "every page", "at the end of the page" and "with no JavaScript" for the scanner page (Supersedes).
17. **From 640px up the shell is a centred column** *(my call; the design's suggestion)*. In a viewport 640px wide or wider the shell is at most 480px wide, centred, on `surface-sunken`, and a sheet on the scanner is as wide as the shell and centred under it. The stage is still everything between the bars, so the guide follows decision 2 in the column.
18. **Landscape and safe areas** *(my call)*. The layout is the same in landscape, a column whose stage is short; the guide fits the stage's height. The page asks for no orientation (a browser lets a page lock it only in full screen). The top bar's height grows by `env(safe-area-inset-top)`, the bottom bar's by `env(safe-area-inset-bottom)`, and both bars pad by the left and right insets; the viewport already has `viewport-fit=cover`.
19. **State is in the markup** *(spec 080 decision 8)*. `c-scan--result` follows whether the pane has something to show (a result or a send failure): one controller sets it from the pane's content, so a Turbo Stream that empties `#scanner_result` also returns the shell to the camera. The two lines swap with `hidden` on their wrappers and keep their `role="status"` elements in the document, whose text is replaced. The main button's label, style and `disabled` are the reading state.
20. **No new data, route or parameter** *(my call)*. The sheets are rendered with the page; "Set", the add, Undo, Done and Other printings keep their routes, parameters and Turbo Stream answers, with targets added for the top bar, the count, the sheets' status regions and the after-add line. The sitting stays working state, not exported (spec 009 FR-2); the hosted door sees no new cost.
21. **No ADR** *(my call)*. The page follows spec 080's patterns; the geometry is a measured setting recorded here and in the area doc's Named constants, as the shipped one was.

## Users and Context

**Primary user:** the collector adding a pile of cards on a phone, a deck, box or binder at a time (design, "How the maintainer scans").
**Secondary users:** a collector on a desktop or tablet; the maintainer measuring the scanner in development.
**Usage context:** a phone held in one hand over a card on a table, often in poor light, HTTPS on the instance; a sitting set once and resumed across visits.
**User mental model:** aim, capture, glance, add, next card. The destination is chosen once and stays in view; the camera never goes away while scanning.

## User Stories

### Story 1: One screen, capture always in view

**As a** collector scanning on a phone
**I want** the capture button and the camera on one screen that never scrolls
**So that** each card is aim, capture, add without scrolling.

**Acceptance criteria:**

- [ ] **AC-1.1** Given the scanner in a 390 × 844 viewport and in a 360 × 640 viewport When it is shown with a live camera Then the `<body>` carries `c-shell`, `c-shell--untabbed` and `c-shell--focused`, the page has no app header, tab bar or footer, the document does not scroll (its scroll height equals its client height and its scroll position stays 0 after scrolling to the end), the top bar is at the top, the bottom bar at the bottom, and the stage fills the height between them
- [ ] **AC-1.2** Given the same two viewports When the page is in each state (engine loading, aiming, reading, a result with at least 3 candidates and Other printings open, after an add, the camera unavailable, the engine failed) Then the main button is wholly inside the viewport and the document does not scroll; a result's content scrolls inside the pane
- [ ] **AC-1.3** Given the top bar When it is rendered Then it holds, in order, "Back" (a link to the collection page with the back icon), the destination button and, while a sitting is open, "Done" (the link to the confirm page); with no sitting open there is no "Done" and the destination takes its room
- [ ] **AC-1.4** Given each of the destination's four forms (a place and a condition, a place alone, a condition alone, neither) When the top bar is rendered Then the value reads "‹label› · ‹short condition›", "‹label›", "No location · ‹short condition›" or "No location", under "Adding to", with a zone's label as "Deck › Zone"; a value too long for the bar ends in an ellipsis on one line
- [ ] **AC-1.5** Given the bottom bar When it is rendered Then it holds the count button ("‹n› added", the sitting's kept entries, "0 added" with none; accessible name "‹n› added. Show this sitting's cards."), the main button and, only where the camera's track reports a torch, the torch ("Torch", `aria-pressed`); without a torch the main button takes its room
- [ ] **AC-1.6** Given the main button When the engine is loading, a reading runs or the camera is unavailable Then it reads "Capture", is disabled and `aria-busy` as today; with the camera live and the engine ready it is the enabled primary "Capture"; while a result shows it is the secondary "Scan again" in the same place and size
- [ ] **AC-1.7** Given a viewport 1280 × 900 When the scanner is shown Then the shell is 480px wide and centred, the stage fills the height between the bars, and nothing scrolls
- [ ] **AC-1.8** Given the page When its styles are read Then the top bar's padding adds `env(safe-area-inset-top)` and the bottom bar's `env(safe-area-inset-bottom)`, and both add the left and right insets (verified by reading the stylesheet: a headless browser reports no inset)
- [ ] **AC-1.9** Given every control on the page and in its sheets When its size is measured Then it is at least 44 × 44px at every pointer (spec 075), and the page is in `spec/system/small_controls_touch_floor_spec.rb`'s pages with its controls listed

### Story 2: The destination sheet

**As a** collector starting a sitting
**I want** to set the condition and place from the top bar without losing the camera
**So that** every card I scan goes where I said.

**Acceptance criteria:**

- [ ] **AC-2.1** Given the scanner with a live camera When the collector activates the destination Then a `dialog.c-sheet` titled "Adding to" opens as a modal, focus moves into it, no navigation happens (a marker set on `window` before survives) and the camera's track is still `live`
- [ ] **AC-2.2** Given the open destination sheet When it is read Then it holds a `role="status"` region, today's form (the "This sitting's cards" fieldset with Condition and, while the account has a place or a zone, Location, and "Set"), then, with art matching on, the art line, then the photo hint, then the content notice's foot
- [ ] **AC-2.3** Given the open destination sheet When the collector chooses Near mint and Blue binder and activates "Set" Then the sheet stays open, its status region says today's sentence ("Cards you scan now: Near mint, in Blue binder."), focus is on "Set", the top bar's value reads "Blue binder · NM", and the camera's track is still `live`; a refused "Set" (a removed location, an unknown condition) says today's refusal there with focus on "Set"
- [ ] **AC-2.4** Given the open sheet When the collector activates Close, presses Escape, or taps the backdrop Then the sheet closes, focus returns to the destination button, and nothing navigates
- [ ] **AC-2.5** Given the sitting's choices set earlier When the scanner is visited again Then the top bar shows them (the sitting stays open across visits until Done, as today)

### Story 3: The camera and the guide

**As a** collector aiming at a card
**I want** the largest camera view the screen allows, with a guide the capture really uses
**So that** lining the card up with the guide is all I need to do.

**Acceptance criteria:**

- [ ] **AC-3.1** Given the stage at 390 × 692 and at 360 × 488 (the stages of AC-1.1's viewports) When the guide is drawn Then its box is the one `geometry.js`'s live guide gives for the stage (centred, 80% of the stage's height, at most 97.5% of its width, 63:88; 380 × 531 and 279 × 390, within 1px), and a capture crops the strips from the frame at that box mapped into the frame (`object-fit: cover`), so a synthetic card drawn at the mapped box is read by OCR ("Lightning Bolt", `MOM`, `0123`)
- [ ] **AC-3.2** Given a synthetic camera frame that is 3:4 and a stage that is taller When a card is captured Then the guide's mapped box lies inside the frame and the strips come from it (the cover crop trims the frame's sides)
- [ ] **AC-3.3** Given a picked photo When it is read Then it is placed in the shipped framing (a 3:4 view, the guide 80% of its height and at most 90% of its width), by detection or by guide placement, exactly as before: every existing photo-path example passes unchanged
- [ ] **AC-3.4** Given the page When the stage resizes (a rotation, the browser's bars) Then the guide is redrawn for the new stage, as today
- [ ] **AC-3.5** Given the scanner's named constants When `geometry.js` is read Then the live guide's shares and the shipped framing's are separate constants, each with its source in a comment, and `script/scanner/detector_parity.rb` still passes

### Story 4: A result in the pane's place

**As a** collector who has just captured a card
**I want** the candidates over the camera, in reach, and a way back to the camera
**So that** I never scroll the page to add or to aim again.

**Acceptance criteria:**

- [ ] **AC-4.1** Given a live camera When the collector captures Then the live picture pauses on the captured frame, the main button is disabled, and the status line says "Reading the card…"; the camera's track stays `live`
- [ ] **AC-4.2** Given a reading's answer When it arrives Then the shell carries `c-scan--result`, the pane fills the stage holding today's result partial (with its candidates, add buttons and Other printings), the main button reads "Scan again", and the status line's text is "Done. What the scanner read and its candidates are showing."
- [ ] **AC-4.3** Given a result with Other printings open in a 360 × 640 viewport When the pane is scrolled to its end Then the pane's content scrolled, the document did not, and the bars stayed in place
- [ ] **AC-4.4** Given a result When the collector activates "Scan again" Then the result is emptied, the shell loses `c-scan--result`, the live picture resumes, the main button is the enabled "Capture", and the status line reads "Ready. Line the card up with the guide, then capture."; no request is sent
- [ ] **AC-4.5** Given a send failure (network, server, ended session) When it happens Then the pane shows today's failure with the name and collector line read and "Send again" or "Sign in", the shell carries `c-scan--result`, and "Scan again" discards it
- [ ] **AC-4.6** Given "Nothing could be read", "No card matches what was read" or the catalog not ready When the answer arrives Then the sentence shows in the pane, as today, and "Scan again" returns to the camera
- [ ] **AC-4.7** Given a refused add (not offered, lot full) or an add that failed on the network When it happens Then the result stays, the pane's `#status` region says today's sentence, and the add buttons behave as today (spec 009 AC-1.4, AC-1.5)

### Story 5: After an add

**As a** collector who has just added a card
**I want** the live camera back at once with a line that says what went in and lets me undo it
**So that** I can go on to the next card and still catch a mistake.

**Acceptance criteria:**

- [ ] **AC-5.1** Given a result When the collector adds a candidate in Foil Then the result is emptied, the shell loses `c-scan--result`, the live picture resumes, the main button is the enabled "Capture", the after-add line shows "Added Lightning Bolt MOM · 123, foil" in its `role="status"` element with an "Undo" button outside it, the status line's wrapper carries `hidden`, the count reads one more, and "Done" shows
- [ ] **AC-5.2** Given a printing with no finish listed When it is added Then the line reads "Added ‹name› ‹SET› · ‹number›" with no finish
- [ ] **AC-5.3** Given the after-add line When the collector activates its Undo Then the copy is removed as today (spec 009 AC-4.1), the line's text becomes "Removed 1 × ‹name› (‹SET› · ‹number›, ‹finish›) from your collection.", its Undo goes, the count reads one less, and focus is on the main button
- [ ] **AC-5.4** Given the after-add line showing When the collector captures again Then the after-add line's text is emptied and its wrapper carries `hidden`, and the status line shows "Reading the card…"
- [ ] **AC-5.5** Given two adds in a row When the second answer arrives Then the after-add line's `role="status"` element is the same element as after the first (its text replaced, never a new element), and its Undo names the second entry
- [ ] **AC-5.6** Given the sitting ended by Done When the scanner is shown in the response Then the after-add line's place shows today's summary ("Added ‹n› cards in this sitting." and "Open your collection") with no Undo, and the top bar reads "No location"

### Story 6: The sitting's list sheet

**As a** collector checking what they have added
**I want** the sitting's list over the camera
**So that** I can undo or check a card without leaving the scanner.

**Acceptance criteria:**

- [ ] **AC-6.1** Given a sitting with entries When the collector activates the count Then a `dialog.c-sheet` opens as a modal titled with today's heading ("This sitting: 2 cards…"), holding a `role="status"` region, today's entries newest first with Details and Undo, "Show all ‹n›" past 10, and the content notice's foot; nothing navigates and the camera's track stays `live`
- [ ] **AC-6.2** Given the list sheet When the collector undoes an entry Then the sheet stays open, its status region says "Removed 1 × … from your collection.", focus is on the sheet's title, the list and the title's count are redrawn, the count button reads one less; a refused Undo says today's refusal there
- [ ] **AC-6.3** Given no sitting, or a sitting with no kept entries When the list sheet opens Then it shows today's empty-state sentence ("Nothing added yet.", "Cards you scan now: …", "Everything added in this sitting was undone.")
- [ ] **AC-6.4** Given an entry's "Details" When activated Then it opens the copy's Edit copy page and returns to the scanner, as today (spec 009 AC-3.4)
- [ ] **AC-6.5** Given the scanner's sitting files When `spec/scanner_sitting_core_spec.rb` runs Then the new sitting partials (the destination, the count, the sheets, the after-add line) are in its list and none names a collectible or a source

### Story 7: The re-measure at the new framing

**As the** maintainer
**I want** the reading measured on live captures at the full framing against the shipped framing, on the same cards
**So that** the bigger guide ships only if it reads as well.

**Acceptance criteria:**

- [ ] **AC-7.1** Given measurement mode When it is opened in development Then it renders the same shell as the scanner, with a top-bar button that opens the "Measured run" sheet holding today's run panel (the counts, the card to capture, Skip, Store again, its notices), and a capture is stored against the chosen row as today (spec 007 AC-5.2, AC-5.3)
- [ ] **AC-7.2** Given `COLLECTOR_SCANNER_FRAMING=shipped` in development When measurement mode draws the guide and crops a capture Then it uses the shipped framing's box inside the tall stage (the guide as a 3:4 stage of the same width would draw it), and each stored capture records its framing; unset or `full`, the full framing; outside measurement mode the setting is never read
- [ ] **AC-7.3** Given the maintainer's corpus manifest When it is checked before the run Then every row resolves to one printing (`scanner:ground_truth`), overlap with earlier corpora is reported (`scanner:overlap`), and the checks of `verify-corpus-manifests` are recorded in `research.md`
- [ ] **AC-7.4** Given the paired run When its findings are written Then `research.md` reports, per framing: right card first, top 3, exact printing (set-line cards, foils and non-foils), name read, art matching on or off, the phone and browser, and every card one framing got right and the other didn't; and it applies decision 4's bar and records the outcome
- [ ] **AC-7.5** Given the bar is not met When the outcome is recorded Then the live guide's shares become the shipped framing's card size in the tall stage, the area doc and `geometry.js` say so with the run as their source, and the pull request says so

## Functional Requirements

### FR-1: The focused layout

The application layout gives a page that asks for it the focused body (decision 6).

**Must:**
- Add `c-shell--focused` and `c-shell--untabbed` to the body, and render no app header, tab bar, footer or `#status`, only for that page.
- Leave every other page's output as it is.

**Must not:**
- Name the scanner or a collectible in the layout.

### FR-2: The shell

The scanner and measurement mode render spec 080's `c-scan` shell with the top bar, the stage and the bottom bar (decisions 7, 8, 14, 17, 18).

**Must:**
- Keep the main button in view in every state, at every height from 560px (AC-1.2).
- Keep every control at 44px or more.
- Keep the camera across opening and closing a sheet; release it on leaving the page as today (spec 007 AC-1.4).

**Must not:**
- Scroll the document; navigate from the destination or the count.

### FR-3: The live guide

`geometry.js` holds the live guide's shares and the shipped framing's; the camera controller draws and maps the live guide (decisions 2, 3, 5).

**Must:**
- Draw the guide and crop the capture from one computation of the stage's box.
- Keep the photo path, the strips, `STRIP_SCALE`, `INVERT_DARK_ROWS`, `REFINE`, the detector and the art fingerprint unchanged.

**Must not:**
- Read the framing setting outside measurement mode.

### FR-4: The sheets

The destination sheet, the list sheet and, in measurement mode, the run sheet (decisions 5, 9, 10, 15, 16).

**Must:**
- Open as modals from their buttons, close by Close, Escape and a tap on the backdrop, and return focus to the opener.
- Hold a `role="status"` region each; keep the dialog open across a redraw of its content.
- End with the content notice's foot when the sources supply lines.

**Must not:**
- Navigate, except "Details".

### FR-5: Results and adds

The pane holds a result; an add returns to the camera with the after-add line (decisions 11 to 13, 19).

**Must:**
- Set `c-scan--result` exactly while the pane has a result or a send failure.
- Pause the picture while a reading runs and a result shows; resume it when the result goes.
- Replace the lines' text in place; keep Undo outside the live region.

**Must not:**
- Send anything new: no frame, strip or photo leaves the device (spec 007 FR-3, spec 009 FR-5, spec 011 FR-5).
- Add anything without the collector's tap (spec 007 FR-2, spec 009 FR-1).

### FR-6: The re-measure

Measurement mode on the shell, the framing setting, the paired run and its findings (decisions 1, 4, 5; Story 7).

**Must:**
- Be development-only; store outside the repository, as today.
- Run last in the plan; nothing else waits on it.

**Must not:**
- Change the strips or any reading setting on the run's evidence (a Non-Goal); only the guide's size is decided by it.

## Non-Functional Requirements

### Accessibility

- The status line, the after-add line, the pane's `#status` and each sheet's status region are polite live regions; each keeps its element and has its text replaced (spec 080 decision 17).
- A sheet takes focus on opening and returns it on closing; focus after "Set" and Undo follows decision 15 (spec 047).
- Every control is at least 44px; nothing is told by colour alone; motion follows the README (spec 080 decision 14).
- A screen-reader pass on a phone over the sheets, an add and an Undo is owed to the maintainer, as spec 047's was.

### Layout

- From 360px wide, both themes, no horizontal scroll; one screen from 560px high in portrait.
- From 640px wide, a centred 480px column (decision 17).

### Performance

- Opening a sheet requests nothing. The page's cold load grows by the size of the sheet controller and the new markup only; reported, not gated.

### Security

- The scanner's Content-Security-Policy is unchanged and its pin (`spec/requests/footer_spec.rb`, "under the scanner's Content-Security-Policy") still passes; the new controllers are first-party modules under the nonce.
- Every scanner request still needs a sign-in; the sitting's data stays scoped by `Current.account` (another account's entry is a 404, as today).

### Hosted door

Checked against the north star's hosted-door rules: no collector-owned data, no per-account state, no admin page, no data of a source; cost per account none.

### Documentation

- `docs/architecture/scanner.md` gains the page, the sheets, the lines, the guide's new shares and the re-measure; `catalog-core.md` the notice's place on the scanner; the design system's `Scanner.md` loses its "As built" parts that this page replaces and stops calling the shell "not built"; `Sheet.md` and `Footer.md` say the scanner uses them; `README.md`'s rule "no page does yet" (focused page, notice in sheets) changes.
- Document criteria are verified by reading and recorded in `verification.md`.

## Error Scenarios

| Scenario | Expected behaviour |
|----------|--------------------|
| The camera is denied, missing, fails or is lost | A stage notice with today's reason, "Try the camera again" (not for an insecure context) and "Use a photo"; the main button "Capture" disabled; the sheets still open |
| The page is not a secure context | The camera is never requested (spec 007 AC-1.6); the stage notice says so; "Use a photo" works |
| The engine fails to load | A stage notice with today's sentence and "Load the scanner again"; "Use a photo" is not offered |
| Script is off | The stage shows today's `<noscript>` sentence and the content notice's lines; the top bar's links work |
| A reading's send fails | The pane shows today's failure and "Send again" or "Sign in"; "Scan again" discards it (AC-4.5) |
| An add is refused or the lot is full | The result stays; the pane's `#status` says today's sentence (AC-4.7) |
| An add of an undone or changed reading is replayed | The result shows today's sentence in place of the candidates, as today |
| "Set" names a removed location or an unknown condition | The destination sheet's status region says today's refusal; focus on "Set" |
| The destination's value is too long | One line with an ellipsis; the sheet holds the full choices |
| The camera reports no torch | No torch; the main button takes its room |
| The sitting is ended on another device | The next add opens a new sitting, as today; the count and the top bar follow the answer |
| The viewport is under 560px high (landscape on a phone) | The stage is short and the guide fits its height; the bars stay; a result scrolls in the pane |
| A source supplies no content notice | The sheets have no foot; the `<noscript>` notice has no lines |
| The re-measure misses the bar | The live guide takes the shipped framing's card size (AC-7.5) |

## Open Questions

- **The re-measure's bar** (decision 4): the paired run with "no more than one card worse on right card first, two on exact printing" (recommended), an absolute bar on one run (B), or figures with no bar (C). For the maintainer at Gate A.

## Out of Scope (Future Considerations)

- The pane's layout and behaviour, the capture strip, the band, the row, the details block and the add per finish: [#345](https://github.com/plainprogrammer/Collector/issues/345). It keeps "Scan again" (decision 13) and the after-add line.
- A sitting's language in the destination sheet: [#58](https://github.com/plainprogrammer/Collector/issues/58). Look-up mode: [#262](https://github.com/plainprogrammer/Collector/issues/262). Continuous capture: [#54](https://github.com/plainprogrammer/Collector/issues/54). Detection on live frames, whose 0.596 card-to-frame figure was measured on the 3:4 stage: [#53](https://github.com/plainprogrammer/Collector/issues/53).
- A camera chooser or zoom; a landscape layout of its own.

## Supersedes

- **Spec 018 FR-2** for the scanner page: "every page", "at the end of the page" and "with no JavaScript": the scanner has no footer, and its notice is in the foot of its sheets and, with script off, in the `<noscript>` stage notice (decision 16; spec 080 decision 13).
- **Spec 009 AC-1.3, spec 040's notice and spec 042 AC-1.4** (the add's announced sentence, "Added 1 × ‹name› (‹SET› · ‹number›, ‹finish›, NM) in Blue binder to your collection."): on the scanner the add announces the after-add line's "Added ‹name› ‹SET› · ‹number›, ‹finish›" (spec 080 decision 11; decision 12); the top bar shows the condition and place.
- **Spec 009 AC-3.2's and spec 042's place of the sitting panel** (the list, heading and Done on the page, under the result): the list and heading in the list sheet, Done in the top bar, the control in the destination sheet (decisions 7, 9). Spec 009 AC-3.5's summary in place of the list: in the after-add line's place (AC-5.6).
- **Spec 047's "the `status` live region"** for "Set" and Undo: each sheet's own region, and the after-add line for an Undo from it (decision 10); the focus targets are kept, with the main button after an Undo from the line (decision 15).
- **Spec 007 AC-1.1's stage** (the shipped framing's 3:4 stage and its guide shares, the plan's numbers) for live capture: the full-height stage and decision 2's guide; the photo path keeps them (decision 3).
- **The scanner's spoken "Done. What the scanner read and its candidates are below."** (no criterion; `card-reader`): "…are showing." (decision 11).
- The design system's `Scanner.md` "As built, until #344 and #345" parts this page replaces (spec 080 decision 1: each issue deletes what it replaces).

## Documents and Files Changed

| File | Change |
|------|--------|
| `app/views/layouts/application.html.erb`, a new core partial for the notice's lines, `app/views/layouts/_footer.html.erb` | The focused body (FR-1); the lines in one partial for the footer and the sheets' foot |
| `app/views/scanners/*` (show, the shell, new partials for the top bar's destination and Done, the count, the two sheets, the lines, the stage notices) | The page (FR-2, FR-4, FR-5) |
| `app/views/scanner/measurements/show.html.erb`, `_panel.html.erb` | Measurement mode on the shell, its panel in a sheet (decision 5) |
| `app/javascript/scanner/geometry.js`, `controllers/camera_controller.js`, `card_reader_controller.js`, `scanner_reading_controller.js`, `sitting_focus_controller.js`, a new sheet controller and a new shell-state controller | FR-2 to FR-5 |
| `app/controllers/concerns/scanner_sitting.rb`, `scanner/sittings/entries_controller.rb`, `entries/undos_controller.rb`, `scanner/sittings_controller.rb`, `scanners_controller.rb`, `scanner/measurements_controller.rb`, `app/helpers/scanners_helper.rb`, `MeasurementMode` and `config/environments/development.rb` (the framing setting) | The streams' new targets, the destination's value, the framing (decisions 5, 10, 12) |
| `app/assets/stylesheets/collector/additions.css` | A `(spec 082 …)` block: the column from 640px, the safe-area insets, "Use a photo"'s corner, the stage notice; the old `c-scanner` rules the page no longer uses are removed |
| `app/views/icons/` | The torch and the destination's chevron (spec 080 decision 10) |
| `spec/system/scanner_*_spec.rb`, `spec/support/scanner_helpers.rb`, `spec/system/small_controls_touch_floor_spec.rb`, `spec/scanner_sitting_core_spec.rb`, `spec/footer_core_spec.rb`, `spec/requests/footer_spec.rb`, request specs of the scanner | Updated and new examples |
| `docs/architecture/scanner.md`, `catalog-core.md`; `docs/design-system/README.md`, `components/Scanner.md`, `Sheet.md`, `Footer.md`; `docs/specs/README.md` | The current rules (Documentation) |
| `docs/specs/082-scanner-capture-always-in-view/research.md`, `verification.md`, `screenshots/` | The re-measure (Story 7), the record, the shots |

## Verification

- **Phone widths** (AC-1.1, 1.2, 2.x, 4.3, 6.1): system examples open the scanner in a fixed-size frame from another page (the scanner's policy has `frame-src 'none'`, so the frame is opened from the collection page; `.claude/memory/headless-firefox-narrow-frame.md`), with the camera substituted in the frame (ADR 0002), at 390 × 844, 360 × 640 and 360 × 560; each is shown to fail once with its rule broken.
- **No navigation** (AC-2.1, 6.1): a marker set on `window` before the sheet opens is read after it closes, and the substituted track's `readyState` is `live`.
- **Geometry** (AC-3.1, 3.2): the guide's box is compared with `geometry.js`'s for the measured stage, and a synthetic card drawn at the mapped box in a 3:4 frame is read.
- **Focus and announcements** (AC-2.3, 2.4, 5.3, 5.5, 6.2): `document.activeElement` and the live regions' element identity and text are read.
- **Unchanged** (AC-3.3, 6.5): the photo-path, detector and art examples, `spec/scanner_sitting_core_spec.rb`, `spec/footer_core_spec.rb` and the scanner policy's pin pass.
- **The re-measure** (Story 7): run by the maintainer on a phone in development, recorded in `research.md`; the last step of the plan.
- **Documents**: read and recorded in `verification.md`.
- **Screenshots and GIFs** (desktop and phone, both themes; aiming, a result, after an add, both sheets, the camera unavailable) in `screenshots/` and the pull request, embedded by SHA-pinned links.
