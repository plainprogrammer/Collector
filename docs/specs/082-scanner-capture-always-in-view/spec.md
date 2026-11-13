# Feature 082: Scanner: Capture Always in View

**Status:** Approved at Gate A on 2026-11-13 by the coordinator under the maintainer's delegation (version 0.2.1, as 1.0.0); the maintainer ruled decision 4 (bar A) and confirmed decisions 2 to 25
**Version:** 1.0.3
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Depends on:** [spec 080](../080-phone-first-scanner-components/spec.md) (the shell, the sheet, the lines over the camera, `c-shell--focused`; frozen into the [design system](../../design-system/README.md)), [the phone-first scanner design](../../superpowers/specs/2026-11-12-scanner-phone-first-design.md) (approved 2026-11-12), the scanner as built ([scanner](../../architecture/scanner.md) area doc; specs 007, 009, 011, 040, 042, 047, 065)
**Branch:** `082-scanner-capture-always-in-view`
**Issue:** [#344](https://github.com/plainprogrammer/Collector/issues/344) (roadmap Theme D, the phone-first layout's second item)
**Frozen:** the current rules are in [`scanner.md`](../../architecture/scanner.md) and [`catalog-core.md`](../../architecture/catalog-core.md) (parts: all but Story 7's outcome, the re-measure owed to the maintainer); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.3 | 2026-11-13 | PATCH, at the merge of spec 084 (merged first, at `19cc6dae`), as the coordinator directed: the shared partial is spec 084's (the types' lines, then Collector's licence line), and the scanner is the focused-page exception to spec 084's footer on every page, met through its sheets' foot. Decision 16 and Supersedes change; no criterion changes |
| 1.0.2 | 2026-11-13 | PATCH, found while planning, approved with the plan at Gate B (the coordinator, under the maintainer's delegation): a capture is stored while its result shows, when the status line is hidden, so measurement mode's stored notice shows as the top-bar button's new row and count and a store failure in the pane's `#status` (decision 5, AC-7.1). No other criterion changes |
| 1.0.1 | 2026-11-13 | PATCH, the coordinator's call with spec 084 (#374), accepted by the maintainer on 2026-11-13: the notice's partial is `layouts/_notice_lines.html.erb` with no locals, shared with spec 084, which adds Collector's licence line and makes the footer always present; a sheet always has a foot, which is how the scanner meets spec 084's rule. Decision 16 and one Error Scenarios row change; no criterion changes |
| 1.0.0 | 2026-11-13 | Approved at Gate A (the coordinator, under the maintainer's delegation). The maintainer ruled decision 4, bar A (the paired run; the full framing passes if its right card first is at most one card below the shipped framing's on the same cards and its exact printing at most two below; on a fail the live guide takes the shipped card size in the tall stage, with no second sitting), and confirmed every other call as written. No criterion changes |
| 0.2.1 | 2026-11-13 | The second review (Fable; NEEDS REVISION; 0 blocking, 2 major, 4 minor), text fixes, my calls: the framing is the session's, so every measurement write and the reading's record reach the right run (N1; decision 5, AC-7.1, 7.2); the guide sits in an aiming area below the lines, and "Use a photo" moves into the destination sheet, so nothing covers the guide's strips (N2; decisions 2, 9, 14, AC-2.2, 3.1); the status line's text is emptied when it hides, and a pane sentence is written after the pane shows (N3, N4; decision 10, AC-4.2); an alert flash's style (N5); the catalog-not-loaded sentence as a line at the stage's foot (N6) |
| 0.2.0 | 2026-11-13 | The spec review (Fable, Mode A; NEEDS REVISION; 1 blocking, 7 major, 9 minor), all fixed, my calls. The paired run is executable on one server: measurement mode's framing is chosen on the page, per block of cards, and each framing stores a run of its own (B1; decisions 4, 5). The live guide never gives a card fewer pixels than the shipped framing on a portrait stage, and each capture records the frame's and the stage's size (M1; decision 2, AC-3.1, AC-7.2). A table says which region each answer writes and empties (M2, M3; decision 10). The pane gets an interim scrolling body (M4; decision 11). The states the draft forgot are placed (M5; decisions 14, 22, 23). The run's row and its store failure stay in view (M6; decision 5). The tooling Story 7 needs is listed (M7; AC-7.3, 7.4). The minors: supersessions completed, 360 × 560 in the criteria and the states tabled, the frozen frame is a canvas, focus after an add, the column's sheet rule scoped, the bar's options evenly stated with a fourth, #345's issue text amended, the summary's link outside the live region |
| 0.1.0 | 2026-11-13 | Draft from issue #344, spec 080 and the design. Decision 1 ruled by the maintainer on 2026-11-13 (option C: no cards soon; the live re-measure is the last gate, on a new corpus). Decisions 2 to 21 are my calls for Gate A; the re-measure's bar (decision 4) is a scope question for the maintainer |

---

## Problem Statement

The scanner is one scrolling column: the page heading, a 3:4 camera stage, the controls, "What the scanner read", the candidates, then the sitting's panel with its Condition and Location form. On a phone the candidates land below the camera, so every card is capture, scroll down, add, scroll back up; spec 009 measured a median of 23 s a card. The design of 2026-11-12 makes the scanner one screen, and spec 080 drew its parts in the design system. Nothing renders them yet.

This spec builds the page: the shell of spec 080 with the sitting's destination in the top bar, the camera filling everything between the bars, and the capture button in the bottom bar, always in view. The sitting's choices and its list move into sheets, so opening them never releases the camera. A result opens in the selection pane's place holding today's candidates; after an add the camera is live again with a line confirming it and Undo. The guide grows with the stage, so the reading is measured again on live captures at the new framing before this ships. The pane's own layout (the band, the swipe row, the details block, the add per finish) is [#345](https://github.com/plainprogrammer/Collector/issues/345); the sitting's language is [#58](https://github.com/plainprogrammer/Collector/issues/58).

> **Terms.** As spec 080's: the *shell*, the *stage*, the *pane*, a *sheet*, the *sitting*. The *destination* is the top bar's button showing the sitting's place and condition. The *main button* is the bottom bar's middle button ("Capture", or "Scan again" while a result shows). The *status line* and the *after-add line* are the two lines over the camera (spec 080 decision 17). The *full framing* is this spec's live guide in the full-height stage; the *shipped framing* is the guide of specs 007 to 011 (the stage 3:4, the guide 80% of its height and at most 90% of its width). A *stage notice* is a message centred on the stage when the camera, the engine or the catalog can't be used. The *frozen frame* is the captured frame drawn over the stage while a reading runs and a result shows.

## Goals

- On a phone the scanner is one screen that never scrolls, and the main button is in view in every state.
- The camera is as large as the screen allows; the guide grows with it, and the page's guide and the capture's crop are one geometry.
- The sitting's destination is always visible in the top bar, and the destination and the sitting's list open as sheets that keep the camera running.
- A result is reached and dismissed without scrolling the page; an add returns to the live camera with a line that confirms it and offers Undo.
- The reading is no worse at the full framing than at the shipped framing, measured on live captures of the same cards, before this ships.

## Non-Goals

- The pane's own layout and behaviour: the capture strip, the shrink, the status band, the swipe row with Previous and Next, the details block, one add button per finish under it, "What the scanner read" leaving the page, the Other printings frame's replacement: #345. Today's result partial, candidates grid and Other printings frame move into the pane unchanged.
- Any change to how a card is read or ranked: the strips, the OCR settings, the detector, the art fingerprint, the ranking. Only the live guide's size changes (decision 2).
- The photo path's geometry: a picked photo keeps the shipped framing (decision 3).
- A sitting's language (#58), look-up mode (#262), continuous capture (#54), detection on live frames (#53), Japanese cards (#55).
- New collector-owned data, a migration, or a new route or parameter outside development's measurement mode (decision 20).
- A new ADR (decision 21).

## Decisions

Decisions 1 and 4 are the maintainer's, ruled on 2026-11-13. Decisions 2, 3 and 5 to 25 were my calls, confirmed by the maintainer at Gate A on 2026-11-13. Decisions of the design are cited as "design decision N", of spec 080 as "spec 080 decision N".

1. **The re-measure is the last gate and runs on a new corpus** (ruled 2026-11-13, option C). The cards are not at hand soon; the maintainer may still have the 35 cards of specs 010 and 011 but expects to build a new corpus. So the re-measure (Story 7) names no earlier card: it runs on a corpus the maintainer gathers, verified as `.claude/memory/verify-corpus-manifests.md` lists, and the plan orders it last, with nothing else waiting on it. The pull request stays a draft until it has run. Alternatives: the 35 cards of spec 011 (not at hand); no re-measure (refused by the issue).
2. **The guide grows with the stage, never below the shipped card size on a portrait stage that has room** *(confirmed 2026-11-13)*. The guide lives in the stage's *aiming area*: the stage less its top 64px, which the status line and the after-add line take (16px above a one-line line of 38px, and a 10px gap), so a one-line line never covers the guide. For an aiming area W × A the live guide is 63:88, centred in it, and as wide as the larger of 80% of A in card proportion and the shipped framing's width for that stage width (a 3:4 stage W wide draws a guide 0.7636 W wide), but no wider than 97.5% of W and no taller than 95% of A. At 390 × 844 the stage is 390 × 692, the area 390 × 628 and the guide 360 × 502, its top 127px down the stage; at 360 × 640 the stage is 360 × 488 and the guide 275 × 384, the shipped width, its top 84px down; at 360 × 560 the stage is 360 × 408 and the guide 234 × 327, its top 73px down. Where 95% of A binds (a stage less than about 1.12 W + 64px tall: a small phone with its browser's bars showing, landscape) the guide is smaller than shipped, and the area doc says so (decision 18). A line that wraps to two lines may cross the guide's top edge on such a stage; that is accepted, since it covers the guide's border, not the card's sides the collector aligns, and the capture is unaffected. In a 1080 × 1920 frame a card filling the guide at 390 × 844 is about 1,000 px wide, against about 825 px at the shipped framing; with a 3:4 frame the two are about equal, which is why every measured capture records the frame's and the stage's size (AC-7.2). `scanner/geometry.js` holds the shares; the camera controller draws the guide from them and maps it into the frame with them, so the page and the crop are one geometry (AC-3.1). Alternatives: the shipped card size in the tall stage (decision 4's fallback); 80% of the height alone (a smaller card than shipped on every stage shorter than 4/3 of its width, found by the review); the guide centred in the whole stage (380 × 531 at 390 × 844, but the lines and the stage's corners then cover its name and collector strips on short stages, found by the second review); the guide as wide as the stage (no margin to aim with).
3. **The photo path keeps the shipped framing** *(confirmed 2026-11-13)*. A picked photo is placed in a 3:4 view with the shipped guide, by detection or by guide placement, as today (spec 009 AC-7.1, AC-7.2). The photo has no stage; its geometry was tuned on photos and the detector's strips assume it. `geometry.js` keeps the shipped shares under their own name for the photo path and measurement mode, and the live guide's under another.
4. **The re-measure's bar** (ruled 2026-11-13: option A). A paired run on the same cards in one sitting on one server: the corpus is split into blocks of about 10 cards, captured at the full framing, then the shipped, then the shipped, then the full, block by block (ABBA), so order, light and fatigue fall on both framings alike; the framing is switched on the page (decision 5). The first capture of each row in each framing counts, as in every measured run. The run uses the instance as the maintainer has it, and records whether art matching is on; the bar is read on the rates as recorded. The corpus: about 40 cards the maintainer owns, none of spec 007's 12 tuning cards, at least 10 sets, at least 8 foils, at least 5 cards whose frame prints no set code, a few with a light name on a dark bar; every row resolves to one printing, each foil value is checked against the card, and overlap with earlier corpora is resolved before the run (AC-7.3). The cost: about 80 captures, roughly 45 minutes with the switches. Options:
   - **(A, ruled)** The full framing passes when its right card first is at most one card below the shipped framing's on the same cards and its exact printing (cards whose collector line prints a set code) at most two below. At about 40 cards one card is 2.5 points, within capture-to-capture noise, so A tolerates one unlucky capture and no more. If it fails, the live guide becomes the shipped card size in the tall stage, which the same run has measured, and no second sitting is needed.
   - **(B)** One run at the full framing only, with an absolute bar: at least 31 of every 35 right card first (spec 009's first captures, text only) or 34 of 35 with art on (spec 011). Half the captures, but the rates come from other cards, another phone and other light, so a miss or a pass says little about the framing.
   - **(C)** The paired figures reported with no bar; the maintainer judges them.
   - **(D)** The paired figures and every card one framing got right and the other didn't, shown to the maintainer, who rules ship or fall back on them. A's figures with the judgement A writes down in advance left to the maintainer.
5. **Measurement mode is the same page, and its framing is chosen on the page** *(confirmed 2026-11-13)*. The re-measure needs the stage the collector will use, so measurement mode renders the same shell. Its top bar has one more button, which reads the next row's file and "‹captured› of ‹rows›" (for example "IMG_7001 · 3 of 40") and opens the "Measured run" sheet holding today's run panel (the counts, the card to capture, Skip, Store again) and the framing switch: two buttons, "Full framing" and "Shipped framing", each a form that sets the framing (`full` or `shipped`; anything else answers 422) in the signed-in session and reloads measurement mode (a full page load, as every visit to the scanner is). The framing is the session's, so a reload keeps it, and the button in the top bar shows it ("IMG_7001 · 3 of 40 · shipped"). Every measurement write (a capture, a Skip, an event) and the reading's measurement record (`Scanner::ReadingsController`'s, whose route and parameters are unchanged) use the run of the session's framing; the findings tasks take `FRAMING=`. The stored notice ("Stored IMG_7001 as the measured capture…") shows in the sheet, and the top-bar button, redrawn with every stored capture, shows the next row and the new count; a store failure ("The capture wasn't stored…") shows in the sheet and in the pane's `#status`, which is in view while the capture's result shows; "Store again" stays in the sheet. Each framing stores its run under a directory of its own, `‹run dir›/full` and `‹run dir›/shipped`, so each has its own rows, firsts and retakes and the findings tooling scores each as a run (with none chosen, `full`). The session's framing is read only while measurement mode is on (development-only; every measurement route answers 404 otherwise); the scanner's own page draws the full framing whatever the session holds. Alternatives: a boot-time setting per framing (a server restart per block; the draft's, not executable as decision 4 needs, found by the review); a query parameter (the writes are separate requests that never see it, found by the second review); a switch per capture (rows of one run mixing framings).
6. **The page is a focused page** *(spec 080 decision 8, built here)*. The scanner view asks the layout for a focused page; the layout then gives the `<body>` `c-shell--focused` beside `c-shell--untabbed` and renders no app header, no tab bar, no footer and no `#status` region of its own (the scanner page places its own, decision 11, and shows the flash itself, decision 10). Every other page's layout output is unchanged. The page keeps an `<h1>` "Scan a card" ("Measure the scanner" in measurement mode), visually hidden.
7. **The top bar** *(design decisions 3 and 4; spec 080 decision 11's copy)*. Back is a link to the collection page, named "Back", with the back icon. The destination is a button, "Adding to" above the value ("Atraxa › Main · NM", "Blue binder", "No location · NM", "No location"; the place is its label, a zone as "Deck › Zone", and the condition its short label); it opens the destination sheet. "Done" is the link to today's confirm page and shows only while a sitting is open (spec 009 AC-3.7); with none the destination takes its room. Every answer that changes the sitting (an add, an Undo, a "Set") redraws the destination and Done.
8. **The bottom bar** *(design decision 5; spec 080 decision 11)*. The count button reads the sitting's count over "added" ("0 added" with no sitting), with the accessible name "12 added. Show this sitting's cards.", and opens the list sheet. The main button is "Capture" (primary) while no result shows: enabled with the engine ready and the camera live, disabled while the engine loads, while a reading runs and while the camera is unavailable; it is "Scan again" (secondary) while a result shows, also a result of a picked photo (decision 13). The torch shows only where the camera's track reports one, as today, and its accessible name is "Torch" with `aria-pressed`. Every answer that changes the sitting redraws the count.
9. **The two sheets hold today's panel, divided** *(confirmed 2026-11-13; spec 080 decision 2)*. Each is a `dialog.c-sheet` opened with `showModal()` by a small Stimulus controller, closed by Close, Escape or a tap on its backdrop. The destination sheet, "Adding to", holds its status region, today's Condition and Location form (`_picker`, its fieldset, legend, selects and "Set", unchanged), then "Use a photo" with the photo hint, then the art line (when art matching is on). The list sheet's title is today's heading ("This sitting: 12 cards, Near mint, in Blue binder"), focusable as today (spec 047), and its body holds its status region, then today's entries with Details, Undo and "Show all", or today's empty-state sentences. Neither sheet holds "Done" (the top bar does). Both end with the content notice's foot (decision 16). A form in a sheet answers with a Turbo Stream, as today; nothing in a sheet navigates but "Details" (Edit copy, which ends the scanning, as today).
10. **Where each answer is said** *(confirmed 2026-11-13)*. While a modal dialog is open the rest of the page is inert and a live region outside it is not announced, so each sheet holds its own `role="status"` region at the top of its body, and the page has four more: the status line, the after-add line, and the pane's `#status`. A sheet empties its region when it closes, and the pane's `#status` is emptied whenever the pane closes, so no sentence is shown stale. A line's wrapper shows while its text is not empty (decision 19).

    | Answer | Writes | Empties | Then |
    |---|---|---|---|
    | A reading starts | status line "Reading the card…" | the after-add line | the frozen frame shows |
    | A reading's answer (a result or a refusal) | the pane's `#status` "Done. What the scanner read and its candidates are showing.", after the pane shows | the status line's text (so its wrapper hides) | `c-scan--result` |
    | A send failure | the failure block, then, after the pane shows, the pane's `#status` (today's sentence) | the status line's text | `c-scan--result` |
    | A photo with no card edge found | the pane's `#status` (today's no-edge sentence, after the answer's) | | |
    | A reading that throws | status line "The card couldn't be read. Line it up with the guide and try again." | | the frozen frame goes |
    | An add | the after-add line "Added ‹name› ‹SET› · ‹number›, ‹finish›" and its Undo | `#scanner_result`, the pane's `#status`, the status line's text | the pane closes; the top bar, the count and the list sheet are redrawn |
    | A refused add, a full lot, an add that failed | the pane's `#status` | | the result stays |
    | A replayed add of an undone or changed entry | the pane's `#status` (today's sentence) | `#scanner_result`, so no add button is left (spec 009 AC-1.5) | the pane stays, holding the sentence |
    | Other printings opened or failed | the pane's `#status` (today's sentences) | | |
    | "Set", accepted or refused | the destination sheet's region | | the sheet's form, the top bar redrawn |
    | Undo, from either place, done or refused | the list sheet's region and the after-add line (its Undo removed) | | the list sheet, the top bar and the count redrawn |
    | "Scan again" | status line "Ready. Line the card up with the guide, then capture." | `#scanner_result`, the failure block, the pane's `#status` | the pane closes, the frozen frame goes |
    | A page load with a flash (after Edit copy, a removal, the end of a sitting) | the after-add line: the flash's sentence, or the summary "Added ‹n› cards in this sitting.", in the `role="status"` element, its action ("Open your collection", the flash's Undo) beside it; an alert flash in the alert style (`warning` border, as `c-status__message--alert`) | the status line's text | |

    A region filled while its wrapper or the pane is hidden and then shown is not announced (spec 080 decision 8), so a sentence for the pane is written after the pane shows (the next animation frame after `c-scan--result` is set), and the status line's text is emptied whenever its wrapper hides, so the next sentence written to it is a change. Of the regions an answer writes, only one is in a shown, non-inert place, so each sentence is said once; that is checked by the screen-reader pass owed to the maintainer (NFR Accessibility), and the examples check the text and the element.
11. **A result opens in the pane's place** *(design decision 9's place, #344's interim content)*. On capture the captured frame is drawn on a canvas over the stage (the frozen frame), while the video keeps playing under it and the track stays live; the reading's answer sets `c-scan--result` on the shell, and the pane (`c-scanpane`) fills the stage over the frozen frame, sliding up as spec 080's CSS draws it (200ms, none under reduced motion). The pane holds, from the top: the page's `#status` region, the send failure with its name and collector line, "Send again" and "Sign in" (today's), and `#scanner_result` with today's result partial unchanged ("What the scanner read", the art overrule sentence, the candidates grid with their add buttons, Other printings). An interim scrolling body, `c-scanpane__results`, holds them: it scrolls inside the pane with `overscroll-behavior: contain`, and #345 removes it with the layout it replaces. The bars never move. "Nothing could be read", "No card matches" and "The card catalog isn't ready yet" stay in the result, as today. No capture strip is rendered here (#345's).
12. **After an add the camera is live and the after-add line confirms it** *(design decision 11; spec 080 decisions 11 and 17)*. A successful add clears the result, which removes `c-scan--result` and the frozen frame; the after-add line's text becomes "Added Lightning Bolt MOM · 123, foil" ("Added Lightning Bolt MOM · 123" for a printing with no finish), which is what is announced, with Undo for that entry beside it, outside the live region; the next capture empties the after-add line and the status line shows again. Undo from the line removes the copy as today and the line's text becomes today's "Removed 1 × ‹name› (‹SET› · ‹number›, ‹finish›) from your collection." with no Undo. The after-add line names no condition and no place: the top bar shows them.
13. **"Scan again" is built here** *(confirmed 2026-11-13; design decision 12)*. With the result filling the stage the collector can't aim, and without this button only an add would bring the camera back. While a result shows (of a capture or of a photo), the main button reads "Scan again" in the secondary style at the same place and size; it discards the reading (decision 10's row), and the stage is the live camera again, or the stage notice when the camera is unavailable. The reading's key is dropped with it, so nothing about it is sent. #345 keeps the button and its behaviour; its issue text is amended to say so (decision 25). Alternative: a Close button in the pane (one more control, and a second way to do the same thing once #345 lands).
14. **Where the other controls and lines sit** *(confirmed 2026-11-13; the design suggested a corner of the camera, which the second review found covers the collector line on short stages)*. "Use a photo" is in the destination sheet, after the form, a secondary button with today's file input inside its label and the photo hint under it, enabled whenever the engine is ready; with the camera unavailable it is also in the stage notice, as the way in. The art line is in the destination sheet (decision 9). A stage notice is centred on the stage, on `surface-raised` with a `line-strong` border, for: the camera unavailable (today's reason sentences, "Try the camera again" except for the insecure context, and "Use a photo"); the engine failed ("The scanner couldn't load…", "Load the scanner again"); script off (today's `<noscript>` sentence). The catalog not loaded is no stage notice: today's `catalog/not_loaded` sentence sits at the stage's foot, `space-4` from its edges, as a line in the alert style, for as long as the catalog is unloaded, with no dismissal; capture stays enabled and a reading says the catalog isn't ready, in the pane. With the camera unavailable the status line says "Ready." once the engine is ready, as today.
15. **Focus** *(spec 047, kept)*. A sheet takes focus on opening and returns it to its opener on closing (the element's own); a tap on the backdrop closes it the same way. After "Set" focus goes to "Set" (spec 047 decision 2); after an Undo from the list sheet, to the list sheet's title; after an Undo from the after-add line, and after an add (whose button the redraw removes), to the main button. A redraw that replaces a sheet's content leaves the dialog open: the answer replaces the sheet's body and title, never the `<dialog>` element.
16. **The content notice moves into the sheets' foot on the scanner** *(spec 080 decision 13, built here)*. The scanner has no footer. Each of its sheets ends with the notice's lines in `c-sheet__foot`, from the core partial `layouts/_notice_lines.html.erb` (`render "layouts/notice_lines"`, no locals), which the footer renders too: the types' lines and their links as the footer draws them (spec 018 FR-1, FR-4), and then Collector's licence line, spec 084's (#374). The partial is shared with spec 084, which built it with the licence line and makes the footer always present; the two branches met on that one file (ruled by the maintainer on 2026-11-13, on the coordinator's proposal; spec 084 merged first and its partial is the one kept). The core still names no collectible (`spec/footer_core_spec.rb`, extended to the partial). With script off the notice's lines are in the `<noscript>` stage notice under its sentence; with the camera unavailable the sheets still open, so the notice is in their foot as always. A sheet always has a foot; on the scanner the sheets' foot is how the page meets spec 084's rule that every page shows the small print: the scanner and measurement pages are the focused-page exception to spec 084 decisions 1 and 11 (no footer, no `c-shell--footed`), AC-1.1 and AC-4.3, met through the sheets' foot. The scanner page has no `contentinfo` landmark. Supersedes spec 018 FR-2 for the scanner page (Supersedes).
17. **From 640px up the shell is a centred column** *(confirmed 2026-11-13; the design's suggestion)*. In a viewport 640px wide or wider the shell is at most 480px wide, centred, on `surface-sunken`, and the scanner's sheets are as wide as the shell and centred under it, by a rule scoped to the scanner page (the frozen `.c-sheet[open]` rule is not changed), placed above the reduced-motion block, which stays last. The stage is still everything between the bars, so the guide follows decision 2 in the column.
18. **Landscape and safe areas** *(confirmed 2026-11-13)*. The layout is the same in landscape, a column whose stage is short; the guide fits 95% of the stage's height and is smaller than shipped there, which the area doc records as an accepted limit (hold the phone upright). The page asks for no orientation (a browser lets a page lock it only in full screen). The top bar's height grows by `env(safe-area-inset-top)`, the bottom bar's by `env(safe-area-inset-bottom)`, and both bars pad by the left and right insets; the viewport already has `viewport-fit=cover`.
19. **State is in the markup** *(spec 080 decision 8)*. `c-scan--result` follows whether the pane has something to show (`#scanner_result`, the pane's `#status` or the failure block not empty): one controller sets it from the pane's content, so a Turbo Stream that empties them also returns the shell to the camera. The two lines swap with `hidden` on their wrappers, a wrapper shown while its text is not empty and the status line's hidden while the after-add line or the pane shows; each keeps its `role="status"` element in the document and has its text replaced. The main button's label, style and `disabled` are the reading state.
20. **No new data or route outside development** *(confirmed 2026-11-13)*. The sheets are rendered with the page; "Set", the add, Undo, Done and Other printings keep their routes, parameters and Turbo Stream answers, with targets added for the top bar, the count, the sheets' status regions and the after-add line. The one new request is measurement mode's framing form (decision 5), development-only, behind the measurement routes' 404. The sitting stays working state, not exported (spec 009 FR-2); the hosted door sees no new cost.
21. **No ADR** *(confirmed 2026-11-13)*. The page follows spec 080's patterns; the geometry is a measured setting recorded here and in the area doc's Named constants, as the shipped one was.
22. **A reading that throws, and a photo with no edge** *(confirmed 2026-11-13)*. A reading that throws drops the frozen frame and returns to the camera with today's sentence on the status line. A photo whose card edge isn't found shows its result and, after it, today's no-edge sentence in the pane's `#status`.
23. **Measurement mode with a broken manifest** *(confirmed 2026-11-13)*. The page renders the shell's top bar and a stage notice with today's problem sentence ("… Measurement mode can't start. The scanner itself is unaffected."); no camera is requested.
24. **The scanner page has no navigation** *(design decision 3)*. "Scan" is still in the header and tab bar of every other page and still marks the scanner current where those are drawn (the confirm page of Done); the scanner page draws neither.
25. **#345's issue is amended** *(confirmed 2026-11-13)*. When this spec is approved, issue #345 gains a line saying "Scan again", the after-add line with Undo, and the frozen frame are built by #344 and kept by #345, and that `c-scanpane__results` is #344's interim body for it to remove.

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

- [ ] **AC-1.1** Given the scanner in a 390 × 844, a 360 × 640 and a 360 × 560 viewport When it is shown with a live camera Then the `<body>` carries `c-shell`, `c-shell--untabbed` and `c-shell--focused`, the page has no app header, tab bar or footer and a visually hidden `<h1>` "Scan a card", the document does not scroll (its scroll height equals its client height and its scroll position stays 0 after scrolling to the end), the top bar is at the top, the bottom bar at the bottom, and the stage fills the height between them
- [ ] **AC-1.2** Given the same three viewports and each state in the table below When the page is in that state Then the main button is wholly inside the viewport, its label and state are the table's, and the document does not scroll; a result's content scrolls inside the pane

  | State | Main button |
  |---|---|
  | Engine loading | "Capture", disabled |
  | Aiming | "Capture", enabled |
  | Reading | "Capture", disabled |
  | A result with 3 candidates and Other printings open | "Scan again", enabled |
  | After an add | "Capture", enabled |
  | Camera unavailable | "Capture", disabled |
  | Engine failed | "Capture", disabled |
- [ ] **AC-1.3** Given the top bar When it is rendered Then it holds, in order, "Back" (a link to the collection page with the back icon), the destination button and, while a sitting is open, "Done" (the link to the confirm page); with no sitting open there is no "Done" and the destination takes its room
- [ ] **AC-1.4** Given each of the destination's four forms (a place and a condition, a place alone, a condition alone, neither) When the top bar is rendered Then the value reads "‹label› · ‹short condition›", "‹label›", "No location · ‹short condition›" or "No location", under "Adding to", with a zone's label as "Deck › Zone"; a value too long for the bar ends in an ellipsis on one line
- [ ] **AC-1.5** Given the bottom bar When it is rendered Then it holds the count button ("‹n› added", the sitting's kept entries, "0 added" with none; accessible name "‹n› added. Show this sitting's cards."), the main button and, only where the camera's track reports a torch, the torch ("Torch", `aria-pressed`); without a torch the main button takes its room
- [ ] **AC-1.6** Given the main button When the engine is loading, a reading runs or the camera is unavailable and no result shows Then it reads "Capture", is disabled and `aria-busy` as today; with the camera live and the engine ready it is the enabled primary "Capture"; while a result shows it is the secondary "Scan again" in the same place and size
- [ ] **AC-1.7** Given a viewport 1280 × 900 When the scanner is shown, and its destination sheet opened Then the shell is 480px wide and centred, the stage fills the height between the bars, nothing scrolls, and the sheet is as wide as the shell and under it
- [ ] **AC-1.8** Given the page When its styles are read Then the top bar's height adds `env(safe-area-inset-top)` and the bottom bar's `env(safe-area-inset-bottom)`, and both pad by the left and right insets (verified by reading the stylesheet: a headless browser reports no inset)
- [ ] **AC-1.9** Given every control on the page and in its sheets When its size is measured Then it is at least 44 × 44px at every pointer (spec 075), and the page and its open sheets are in `spec/system/small_controls_touch_floor_spec.rb`'s pages with their controls listed

### Story 2: The destination sheet

**As a** collector starting a sitting
**I want** to set the condition and place from the top bar without losing the camera
**So that** every card I scan goes where I said.

**Acceptance criteria:**

- [ ] **AC-2.1** Given the scanner with a live camera When the collector activates the destination Then a `dialog.c-sheet` titled "Adding to" opens as a modal, focus moves into it, no navigation happens (a marker set on `window` before survives) and the camera's track is still `live`
- [ ] **AC-2.2** Given the open destination sheet When it is read Then it holds a `role="status"` region, today's form (the "This sitting's cards" fieldset with Condition and, while the account has a place or a zone, Location, and "Set"), then "Use a photo" and the photo hint, then, with art matching on, the art line, then the content notice's foot; and picking a photo from it closes the sheet and reads the photo
- [ ] **AC-2.3** Given the open destination sheet When the collector chooses Near mint and Blue binder and activates "Set" Then the sheet stays open, its status region says today's sentence ("Cards you scan now: Near mint, in Blue binder."), focus is on "Set", the top bar's value reads "Blue binder · NM", and the camera's track is still `live`; a refused "Set" (a removed location, an unknown condition) says today's refusal there with focus on "Set"
- [ ] **AC-2.4** Given the open sheet When the collector activates Close, presses Escape, or clicks the backdrop outside the sheet Then the sheet closes, focus returns to the destination button, its status region is empty, and nothing navigates
- [ ] **AC-2.5** Given the sitting's choices set earlier When the scanner is visited again Then the top bar shows them (the sitting stays open across visits until Done, as today)

### Story 3: The camera and the guide

**As a** collector aiming at a card
**I want** the largest camera view the screen allows, with a guide the capture really uses
**So that** lining the card up with the guide is all I need to do.

**Acceptance criteria:**

- [ ] **AC-3.1** Given the stages of AC-1.1's viewports (390 × 692, 360 × 488, 360 × 408) When the guide is drawn Then its box is the one `geometry.js`'s live guide gives for the stage (decision 2: 360 × 502, 275 × 384 and 234 × 327, within 1px, centred in the aiming area, its top 127px, 84px and 73px down the stage), the status line with one line of text and the after-add line with one line do not intersect it, and a capture crops the strips from the frame at that box mapped into the frame (`object-fit: cover`), so a synthetic card drawn at the mapped box is read by OCR ("Lightning Bolt", `MOM`, `0123`)
- [ ] **AC-3.2** Given a synthetic camera frame that is 3:4 and a stage that is taller When a card is captured Then the guide's mapped box lies inside the frame and the strips come from it (the cover crop trims the frame's sides)
- [ ] **AC-3.3** Given a picked photo When it is read Then it is placed in the shipped framing (a 3:4 view, the guide 80% of its height and at most 90% of its width), by detection or by guide placement: the photo-path and detector examples keep their assertions, only their selectors change
- [ ] **AC-3.4** Given the page When the stage resizes (a rotation, the browser's bars) Then the guide is redrawn for the new stage, as today
- [ ] **AC-3.5** Given `geometry.js` When it is read Then the live guide's shares and the shipped framing's are separate constants, each with its source in a comment, and `script/scanner/detector_parity.rb` still passes

### Story 4: A result in the pane's place

**As a** collector who has just captured a card
**I want** the candidates over the camera, in reach, and a way back to the camera
**So that** I never scroll the page to add or to aim again.

**Acceptance criteria:**

- [ ] **AC-4.1** Given a live camera When the collector captures Then a canvas the size of the stage holding the captured frame (the frozen frame) is shown over the video, the main button is disabled, the status line says "Reading the card…", and the camera's track stays `live`
- [ ] **AC-4.2** Given a reading's answer When it arrives Then the shell carries `c-scan--result`, the pane fills the stage holding today's result partial (with its candidates, add buttons and Other printings) in `c-scanpane__results`, the pane's `#status` says "Done. What the scanner read and its candidates are showing.", the status line's text is empty and its wrapper carries `hidden`, and the main button reads "Scan again"
- [ ] **AC-4.3** Given a result with Other printings open in a 360 × 640 viewport When the pane's body is scrolled to its end Then the body scrolled, the document did not, and the bars stayed in place
- [ ] **AC-4.4** Given a result When the collector activates "Scan again" Then `#scanner_result`, the failure block and the pane's `#status` are empty, the shell loses `c-scan--result`, the frozen frame is gone, the main button is the enabled "Capture", and the status line reads "Ready. Line the card up with the guide, then capture."; no request is sent
- [ ] **AC-4.5** Given a send failure (network, server, ended session) When it happens Then the pane shows today's failure with the name and collector line read and "Send again" or "Sign in", the shell carries `c-scan--result`, and "Scan again" discards it
- [ ] **AC-4.6** Given "Nothing could be read", "No card matches what was read" or the catalog not ready When the answer arrives Then the sentence shows in the pane, as today, and "Scan again" returns to the camera
- [ ] **AC-4.7** Given a refused add (not offered, lot full) or an add that failed on the network When it happens Then the result stays, the pane's `#status` says today's sentence, and the add buttons behave as today (spec 009 AC-1.4, AC-1.5)
- [ ] **AC-4.8** Given a replay of an undone add When its answer arrives Then `#scanner_result` is empty, the pane stays showing today's sentence ("You added this card, then undid it. Scan it again to add it.") in its `#status`, and no add button is offered
- [ ] **AC-4.9** Given a picked photo whose card edge isn't found When its result shows Then the pane's `#status` ends with today's no-edge sentence; and given a picked photo while the camera is unavailable When "Scan again" is activated Then the stage shows the camera-unavailable notice with "Use a photo"
- [ ] **AC-4.10** Given a reading that throws When it fails Then the frozen frame is gone, no result shows, and the status line says "The card couldn't be read. Line it up with the guide and try again."

### Story 5: After an add

**As a** collector who has just added a card
**I want** the live camera back at once with a line that says what went in and lets me undo it
**So that** I can go on to the next card and still catch a mistake.

**Acceptance criteria:**

- [ ] **AC-5.1** Given a result When the collector adds a candidate in Foil Then the result and the pane's `#status` are emptied, the shell loses `c-scan--result`, the frozen frame is gone, the main button is the enabled "Capture" and has focus, the after-add line shows "Added Lightning Bolt MOM · 123, foil" in its `role="status"` element with an "Undo" button outside it, the status line's wrapper carries `hidden`, the count reads one more, and "Done" shows
- [ ] **AC-5.2** Given a printing with no finish listed When it is added Then the line reads "Added ‹name› ‹SET› · ‹number›" with no finish
- [ ] **AC-5.3** Given the after-add line When the collector activates its Undo Then the copy is removed as today (spec 009 AC-4.1), the line's text becomes "Removed 1 × ‹name› (‹SET› · ‹number›, ‹finish›) from your collection.", its Undo goes, the count reads one less, and focus is on the main button
- [ ] **AC-5.4** Given the after-add line showing When the collector captures again Then the after-add line's text is emptied and its wrapper carries `hidden`, and the status line shows "Reading the card…"
- [ ] **AC-5.5** Given two adds in a row When the second answer arrives Then the after-add line's `role="status"` element is the same element as after the first (its text replaced, never a new element), and its Undo names the second entry
- [ ] **AC-5.6** Given the sitting ended by Done When the scanner is shown in the response Then the after-add line's `role="status"` element says "Added ‹n› cards in this sitting." with "Open your collection" beside it, outside the live region, and no Undo, and the top bar reads "No location"; and given a page load carrying a flash (for example after Edit copy) Then the after-add line shows the flash's sentence the same way, with the flash's action beside it

### Story 6: The sitting's list sheet

**As a** collector checking what they have added
**I want** the sitting's list over the camera
**So that** I can undo or check a card without leaving the scanner.

**Acceptance criteria:**

- [ ] **AC-6.1** Given a sitting with entries When the collector activates the count Then a `dialog.c-sheet` opens as a modal titled with today's heading ("This sitting: 2 cards…"), holding a `role="status"` region, today's entries newest first with Details and Undo, "Show all ‹n›" past 10, and the content notice's foot; nothing navigates and the camera's track stays `live`
- [ ] **AC-6.2** Given the list sheet When the collector undoes an entry Then the sheet stays open, its status region says "Removed 1 × … from your collection.", focus is on the sheet's title, the list and the title's count are redrawn, the count button reads one less; a refused Undo says today's refusal there
- [ ] **AC-6.3** Given no sitting, or a sitting with no kept entries When the list sheet opens Then it shows today's empty-state sentence ("Nothing added yet.", "Cards you scan now: …", "Everything added in this sitting was undone.")
- [ ] **AC-6.4** Given an entry's "Details" When activated Then it opens the copy's Edit copy page and returns to the scanner, as today (spec 009 AC-3.4), and the scanner shows that page's flash in the after-add line (AC-5.6)
- [ ] **AC-6.5** Given the scanner's sitting files When `spec/scanner_sitting_core_spec.rb` runs Then the new sitting partials (the destination, the count, the sheets, the after-add line) are in its list and none names a collectible or a source

### Story 7: The re-measure at the new framing

**As the** maintainer
**I want** the reading measured on live captures at the full framing against the shipped framing, on the same cards
**So that** the bigger guide ships only if it reads as well.

**Acceptance criteria:**

- [ ] **AC-7.1** Given measurement mode When it is opened in development Then it renders the same shell as the scanner, with a visually hidden `<h1>` "Measure the scanner" and a top-bar button reading the next row's file, "‹captured› of ‹rows›" and the framing that opens the "Measured run" sheet (today's run panel and the framing switch); a capture is stored against the chosen row as today (spec 007 AC-5.2, AC-5.3), the top-bar button shows the next row and the new count after a stored capture, and a store failure also shows in the pane's `#status`
- [ ] **AC-7.2** Given "Shipped framing" chosen in the run sheet When measurement mode reloads, the guide is drawn and a capture cropped Then both use the shipped framing's box inside the tall stage (the box a 3:4 stage of the same width would draw), the top-bar button shows "shipped", the capture, a Skip and the reading's record are stored under `‹run dir›/shipped`, and the capture records its framing, the frame's width and height and the stage's; with "Full framing" or none chosen, the full framing and `‹run dir›/full`; a framing other than the two answers 422; a reload keeps the framing; the scanner's own page draws the full framing whatever the session holds; and with measurement mode off the route answers 404 as today
- [ ] **AC-7.3** Given the maintainer's corpus manifest When it is checked before the run Then every row resolves to one printing (`scanner:ground_truth`), the overlap with the earlier corpora is listed and resolved by the maintainer before the run (`scanner:overlap` aborts on overlap), the foil values are checked against the cards, and the checks of `verify-corpus-manifests` are recorded in `research.md`
- [ ] **AC-7.4** Given the two runs When a paired findings task scores them against the ground truth Then `research.md` reports, per framing: right card first, top 3, exact printing (set-line cards, foils and non-foils), name read, art matching on or off, the phone, browser and frame size, and every card one framing got right and the other didn't; it applies bar A (decision 4) and records the outcome
- [ ] **AC-7.5** Given the bar is not met When the outcome is recorded Then the live guide's shares become the shipped card size in the tall stage, the area doc and `geometry.js` say so with the run as their source, and the pull request says so

## Functional Requirements

### FR-1: The focused layout

The application layout gives a page that asks for it the focused body (decision 6).

**Must:**
- Add `c-shell--focused` and `c-shell--untabbed` to the body, and render no app header, tab bar, footer or `#status`, only for that page.
- Leave every other page's output as it is.

**Must not:**
- Name the scanner or a collectible in the layout.

### FR-2: The shell

The scanner and measurement mode render spec 080's `c-scan` shell with the top bar, the stage and the bottom bar (decisions 7, 8, 14, 17, 18, 24).

**Must:**
- Keep the main button in view in every state, at every portrait height from 560px (AC-1.2).
- Keep every control at 44px or more.
- Keep the camera across opening and closing a sheet; release it on leaving the page as today (spec 007 AC-1.4).

**Must not:**
- Scroll the document; navigate from the destination or the count.

### FR-3: The live guide

`geometry.js` holds the live guide's rule and the shipped framing's shares; the camera controller draws and maps the live guide (decisions 2, 3, 5).

**Must:**
- Draw the guide and crop the capture from one computation of the stage's box.
- Keep the photo path, the strips, `STRIP_SCALE`, `INVERT_DARK_ROWS`, `REFINE`, the detector and the art fingerprint unchanged.

**Must not:**
- Take the framing from anything but the session's choice while measurement mode is on.

### FR-4: The sheets

The destination sheet, the list sheet and, in measurement mode, the run sheet (decisions 5, 9, 10, 15, 16).

**Must:**
- Open as modals from their buttons, close by Close, Escape and a click on the backdrop, and return focus to the opener.
- Hold a `role="status"` region each, emptied on closing; keep the dialog open across a redraw of its content.
- End with the content notice's foot when the sources supply lines.

**Must not:**
- Navigate, except "Details" and the run sheet's framing buttons.

### FR-5: Results and adds

The pane holds a result; an add returns to the camera with the after-add line (decisions 10 to 13, 19, 22).

**Must:**
- Set `c-scan--result` exactly while the pane has something to show.
- Show the frozen frame while a reading runs and a result shows; remove it when the result goes.
- Write and empty the regions as decision 10's table says; replace the lines' text in place; keep Undo and every link outside the live regions.

**Must not:**
- Send anything new: no frame, strip or photo leaves the device (spec 007 FR-3, spec 009 FR-5, spec 011 FR-5).
- Add anything without the collector's tap (spec 007 FR-2, spec 009 FR-1).

### FR-6: The re-measure

Measurement mode on the shell, the framing in the session, the paired run and its findings (decisions 1, 4, 5; Story 7).

**Must:**
- Be development-only; store outside the repository, as today.
- Record each capture's framing, frame size and stage size.
- Run last in the plan; nothing else waits on it.

**Must not:**
- Change the strips or any reading setting on the run's evidence (a Non-Goal); only the guide's size is decided by it.

## Non-Functional Requirements

### Accessibility

- The status line, the after-add line, the pane's `#status` and each sheet's status region are polite live regions; each keeps its element and has its text replaced (spec 080 decision 17).
- A sheet takes focus on opening and returns it on closing; focus after "Set", Undo and an add follows decision 15 (spec 047).
- Every control is at least 44px; nothing is told by colour alone; motion follows the README (spec 080 decision 14).
- Owed to the maintainer, as spec 047's was: a screen-reader pass on a phone over the sheets, an add, an Undo from each place and a refused add, checking each sentence is said once.

### Layout

- From 360px wide, both themes, no horizontal scroll; one screen from 560px high in portrait.
- From 640px wide, a centred 480px column (decision 17).

### Performance

- Opening a sheet requests nothing. The page's cold load grows by the sheet and shell controllers and the new markup only; reported, not gated.

### Security

- The scanner's Content-Security-Policy is unchanged and its pin (`spec/requests/footer_spec.rb`, "under the scanner's Content-Security-Policy") still passes; the new controllers are first-party modules under the nonce, and the frozen frame is a canvas drawn in the page.
- Every scanner request still needs a sign-in; the sitting's data stays scoped by `Current.account` (another account's entry is a 404, as today).

### Hosted door

Checked against the north star's hosted-door rules: no collector-owned data, no per-account state, no admin page, no data of a source; cost per account none.

### Documentation

- `docs/architecture/scanner.md` gains the page, the sheets, the lines, decision 10's table, the guide's rule in Named constants, the landscape limit and the re-measure; `catalog-core.md` the notice's place on the scanner; the design system's `Scanner.md` loses the "As built" parts this page replaces and stops calling the shell "not built"; `Sheet.md` and `Footer.md` say the scanner uses them; the README's "no page does yet" (a focused page's notice in its sheets) changes.
- `docs/specs/README.md` gets the "Superseded by" entries of specs 007, 009, 011, 018, 040, 042 and 047 for what this spec supersedes.
- Document criteria are verified by reading and recorded in `verification.md`.

## Error Scenarios

| Scenario | Expected behaviour |
|----------|--------------------|
| The camera is denied, missing, fails or is lost | A stage notice with today's reason, "Try the camera again" (not for an insecure context) and "Use a photo" (also in the destination sheet); the main button "Capture" disabled; the sheets still open |
| The page is not a secure context | The camera is never requested (spec 007 AC-1.6); the stage notice says so; "Use a photo" works |
| The engine fails to load | A stage notice with today's sentence and "Load the scanner again"; "Use a photo" is not offered |
| The catalog isn't loaded | Today's not-loaded sentence as a line at the stage's foot, not dismissable; capture enabled; a reading says the catalog isn't ready, in the pane |
| Script is off | The stage shows today's `<noscript>` sentence and the content notice's lines; the top bar's links work |
| A reading's send fails | The pane shows today's failure and "Send again" or "Sign in"; "Scan again" discards it (AC-4.5) |
| A reading throws | The status line says so; the camera is live again (AC-4.10) |
| An add is refused or the lot is full | The result stays; the pane's `#status` says today's sentence (AC-4.7) |
| An add of an undone or changed reading is replayed | The pane holds today's sentence and no add button (AC-4.8) |
| "Set" names a removed location or an unknown condition | The destination sheet's status region says today's refusal; focus on "Set" |
| The destination's value is too long | One line with an ellipsis; the sheet holds the full choices |
| The camera reports no torch | No torch; the main button takes its room |
| The sitting is ended on another device | The next add opens a new sitting, as today; the count and the top bar follow the answer |
| The stage is short (a small phone with its browser's bars, landscape) | The guide fits 95% of the stage's height, smaller than shipped; the bars stay; a result scrolls in the pane |
| A source supplies no content notice | The sheets' foot holds what the partial renders (spec 084's licence line once it merges); the `<noscript>` notice likewise |
| Measurement mode's manifest is broken | The top bar and a stage notice with today's problem sentence; no camera (decision 23) |
| The re-measure misses the bar | The live guide takes the shipped card size (AC-7.5) |

## Open Questions

None. The maintainer ruled decisions 1 and 4 and confirmed the rest on 2026-11-13.

## Out of Scope (Future Considerations)

- The pane's layout and behaviour, the capture strip, the band, the row, the details block and the add per finish: [#345](https://github.com/plainprogrammer/Collector/issues/345). It keeps "Scan again", the after-add line and the frozen frame, and removes `c-scanpane__results` (decision 25).
- A sitting's language in the destination sheet: [#58](https://github.com/plainprogrammer/Collector/issues/58). Look-up mode: [#262](https://github.com/plainprogrammer/Collector/issues/262). Continuous capture: [#54](https://github.com/plainprogrammer/Collector/issues/54). Detection on live frames, whose 0.596 card-to-frame figure was measured on the 3:4 stage: [#53](https://github.com/plainprogrammer/Collector/issues/53).
- A camera chooser or zoom; a landscape layout of its own.

## Supersedes

- **Spec 084 decisions 1 and 11, AC-1.1 and AC-4.3** for the scanner and measurement pages: no footer and no `c-shell--footed`; the small print, the licence line last, is in the sheets' foot (decision 16, patch 1.0.3).
- **Spec 018 FR-2** for the scanner page: "every page", "at the end of the page", "with no JavaScript" and the `contentinfo` landmark: the scanner has no footer; its notice is in the foot of its sheets and, with script off, in the `<noscript>` stage notice (decision 16; spec 080 decision 13).
- **Spec 009 AC-1.3, spec 040's notice and spec 042 AC-1.4** (the add's announced sentence, "Added 1 × ‹name› (‹SET› · ‹number›, ‹finish›, NM) in Blue binder to your collection."): on the scanner the add announces the after-add line's "Added ‹name› ‹SET› · ‹number›, ‹finish›" (spec 080 decision 11; decision 12); the top bar shows the condition and place.
- **Spec 009 AC-3.2's and spec 042's place of the sitting panel** (the list, heading and Done on the page, under the result): the list and heading in the list sheet, Done in the top bar, the control in the destination sheet (decisions 7, 9). **Spec 009 AC-3.5's** summary "in place of the list": in the after-add line (AC-5.6).
- **Spec 040 AC-7.1 and spec 042 AC-7.1's "no script is added"** as far as reaching the control: the form is unchanged and needs no script, but it is reached through a sheet opened by script (spec 080 decision 2: a page that needs script anyway).
- **Spec 047's "the `status` live region"** for "Set" and Undo: each sheet's own region, and the after-add line for an Undo (decision 10); the focus targets are kept, with the main button after an Undo from the line and after an add (decision 15).
- **Spec 007 AC-1.1's stage** (the shipped framing's 3:4 stage and its guide shares, the plan's numbers) for live capture: the full-height stage and decision 2's guide; the photo path keeps them (decision 3).
- **Spec 009 AC-7.2 and AC-7.4's framing advice** on the page: the photo hint is in the destination sheet; the no-edge sentence after a photo is in the pane (decisions 14, 22).
- **Spec 011 AC-5.2's art line** as a live region on the page: it is in the destination sheet, where a change is not announced while the sheet is closed (decision 14).
- **Spec 009 AC-8.1**'s "Scan" marked current on the scanner page: the scanner page draws no navigation (decision 24).
- **The scanner's spoken "Done. What the scanner read and its candidates are below."** (no criterion; `card-reader`): "…are showing.", in the pane (decision 10).
- The design system's `Scanner.md` "As built, until #344 and #345" parts this page replaces (spec 080 decision 1: each issue deletes what it replaces).

## Documents and Files Changed

| File | Change |
|------|--------|
| `app/views/layouts/application.html.erb`, a new core partial for the notice's lines, `app/views/layouts/_footer.html.erb` | The focused body (FR-1); the lines in one partial for the footer and the sheets' foot |
| `app/views/scanners/*` (show, the shell, new partials for the top bar's destination and Done, the count, the two sheets, the lines, the stage notices) | The page (FR-2, FR-4, FR-5) |
| `app/views/scanner/measurements/show.html.erb`, `_panel.html.erb` | Measurement mode on the shell, its panel in a sheet, the framing links (decision 5) |
| `app/javascript/scanner/geometry.js`, `controllers/camera_controller.js`, `card_reader_controller.js`, `scanner_reading_controller.js`, `sitting_focus_controller.js`, `measurement_controller.js`, a new sheet controller and a new shell-state controller | FR-2 to FR-6 |
| `app/controllers/concerns/scanner_sitting.rb`, `scanner/sittings/entries_controller.rb`, `entries/undos_controller.rb`, `scanner/sittings_controller.rb`, `scanners_controller.rb`, `scanner/measurements_controller.rb`, `scanner/measurements/captures_controller.rb`, `app/controllers/concerns/measurement_mode.rb`, `app/helpers/scanners_helper.rb` | The streams' targets, the destination's value, the flash, the framing (decisions 5, 10, 12) |
| `app/models/scanner/measurement_run.rb` | The framing's run directory; the framing, frame size and stage size per capture (`EXTRA_FIELDS`) |
| `config/routes.rb`, a measurement framing controller | The development-only framing form (decision 5), under the measurement routes' 404 |
| `lib/tasks/scanner.rake` (and `Collector::ScannerFindings` if needed) | A paired findings task over the two framings' runs (AC-7.4) |
| `app/assets/stylesheets/collector/additions.css` | A `(spec 082 …)` block above the reduced-motion block: the column from 640px and its sheets, the safe-area insets, the not-loaded line at the stage's foot, the stage notice, the frozen frame, `c-scanpane__results`; the `c-scanner` rules the page no longer uses are removed |
| `app/views/icons/` | The torch and the destination's chevron (spec 080 decision 10) |
| `spec/system/scanner_*_spec.rb`, `spec/support/scanner_helpers.rb`, `spec/system/small_controls_touch_floor_spec.rb`, `spec/scanner_sitting_core_spec.rb`, `spec/footer_core_spec.rb`, `spec/requests/footer_spec.rb`, the scanner's request specs | Updated and new examples |
| `docs/architecture/scanner.md`, `catalog-core.md`; `docs/design-system/README.md`, `components/Scanner.md`, `Sheet.md`, `Footer.md`; `docs/specs/README.md` | The current rules and the index (Documentation) |
| Issue #345 | Decision 25's line |
| `docs/specs/082-scanner-capture-always-in-view/research.md`, `verification.md`, `screenshots/` | The re-measure (Story 7), the record, the shots |

## Verification

- **Phone widths** (AC-1.1, 1.2, 2.x, 4.3, 6.1): system examples open the scanner in a fixed-size frame from another page (the scanner's policy has `frame-src 'none'`, so the frame is opened from the collection page; `.claude/memory/headless-firefox-narrow-frame.md`), with the camera substituted in the frame (ADR 0002), at 390 × 844, 360 × 640 and 360 × 560; each is shown to fail once with its rule broken.
- **No navigation** (AC-2.1, 6.1): a marker set on `window` before the sheet opens is read after it closes, and the substituted track's `readyState` is `live`.
- **Geometry** (AC-3.1, 3.2): the guide's box is compared with `geometry.js`'s for the measured stage, and a synthetic card drawn at the mapped box in a 3:4 frame is read.
- **Focus and announcements** (AC-2.3, 2.4, 5.1, 5.3, 5.5, 6.2): `document.activeElement` and the live regions' element identity and text are read; that each sentence is said once is the maintainer's screen-reader pass.
- **Unchanged** (AC-3.3, 6.5): the photo-path, detector and art examples keep their assertions; `spec/scanner_sitting_core_spec.rb`, `spec/footer_core_spec.rb` and the scanner policy's pin pass.
- **The re-measure** (Story 7): run by the maintainer on a phone in development, recorded in `research.md`; the last step of the plan.
- **Documents**: read and recorded in `verification.md`.
- **Screenshots and GIFs** (desktop and phone, both themes; aiming, a result, after an add, both sheets, the camera unavailable) in `screenshots/` and the pull request, embedded by SHA-pinned links.
