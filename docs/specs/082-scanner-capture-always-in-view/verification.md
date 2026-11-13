# Verification: spec 082, scanner: capture always in view

**Spec:** [spec.md](spec.md) 1.0.3 | **Plan:** [plan.md](plan.md) | **Issue:** [#344](https://github.com/plainprogrammer/Collector/issues/344)
**Branch:** `082-scanner-capture-always-in-view`
**Commits:** `main..HEAD`, 54 commits, `bd0515db` (first, "draft spec 082") to `c896cf62` (last, "engine loading, a result with Other printings and the after-add line are proved at the three viewports"); the record was written at `c4cbfe7e` and updated at `c896cf62` after the implementation review's two rounds; merge base with `main` `19cc6dae` (spec 084's merge).
**Recorded:** 2026-11-13.

Each criterion with the example or the reading that proves it. Documents are verified by reading, never by RSpec (`.claude/rules/testing.md`). Examples are cited as `file:line` of the `it`. The red runs, rulings and proofs by breaking are as the implementers reported them in their commit bodies. No example was run to write this record; the full run is under CI, below.

## Acceptance criteria

"By reading" means a document or a stylesheet was read. "Owed" names who owes it. "Not proved by an example" is said plainly where a clause of a criterion has none; the example listed for the rest of the criterion stands for that part only.

### Story 1: One screen, capture always in view

| AC | Proof |
|---|---|
| AC-1.1 | `spec/system/scanner_page_spec.rb:11` (390 × 844, 360 × 640 and 360 × 560 in a frame: the body's three classes, no `#appbar`, `.c-tabbar` or `footer.c-footer`, `expect_one_screen`: scroll height equals client height, scroll position 0 after scrolling to the end, top bar at 0, bottom bar at the viewport's bottom, stage between them). The hidden `<h1>` "Scan a card", the body's classes and the absent header, tab bar, footer and `#status`: `spec/requests/scanners_spec.rb:128`. Shown to fail with the rule broken (Proof by breaking) |
| AC-1.2 | `spec/system/scanner_page_spec.rb:194` at all three viewports: aiming (enabled "Capture"), reading (disabled), a result ("Scan again"), after an add (enabled "Capture"), camera unavailable (disabled), the main button in view and one screen in each. Engine loading as a live state (`startEngine`'s synchronous part read in one script: "Capture", disabled, `aria-busy`, in view, no scroll): `spec/system/scanner_page_spec.rb:157` at all three (`c896cf62`); the markup's `disabled` and `aria-busy` also in `spec/requests/scanners_spec.rb:17`. Engine failed: `:210` at all three. A result with Other printings open scrolls inside the pane with the page one screen, at all three: `spec/system/scanner_result_spec.rb:100` (`c896cf62`; the pane's own scroll is asserted at the two short viewports, since the tall one may fit it all) |
| AC-1.3 | `spec/requests/scanners_spec.rb:128` (no sitting: children are Back then the destination, Back's `href` is the collection page, no "Done"). The order with a sitting open, Back, the destination, Done, on the markup: `spec/requests/scanners_spec.rb:107` (`dfa44292`), and spec 080's example, `spec/system/design_system_scanner_components_spec.rb:308`. With a sitting open, "Done" shows after an add: `spec/system/scanner_sitting_spec.rb:320`, and is absent after the sitting is cleared: `:287` |
| AC-1.4 | The four forms under "Adding to": `spec/helpers/scanners_helper_spec.rb:60` ("Blue binder · NM", "Blue binder", "No location · NM", "No location"). A zone reads "Deck › Zone": `spec/helpers/scanners_helper_spec.rb:67` and, on the page, `spec/requests/scanners_spec.rb:115` ("Izzet Tempo › Main"; `dfa44292`). The ellipsis on one line: `spec/system/scanner_sitting_spec.rb:143` (a long place at 360px, `scrollWidth > clientWidth`) and the CSS in `spec/system/design_system_scanner_components_spec.rb:320` |
| AC-1.5 | Order and names: `spec/requests/scanners_spec.rb:128` (count, main, torch; the count's accessible name "0 added. Show this sitting's cards."). The count after adds: `spec/system/scanner_adding_spec.rb:30`, `spec/system/scanner_sitting_spec.rb:25` ("1 added. Show this sitting's cards.", "2 added…"). The torch only with a torch track, "Torch" and `aria-pressed`: `spec/system/scanner_spec.rb:44`. Without a torch the main button takes its room (no gap to the bar's padding; with the torch it is 68px narrower, the torch's width and the bar's gap): `spec/system/scanner_page_spec.rb:95` (`03e995f8`, shown to fail with `.c-scan__main`'s `flex` at `0 1 auto`) |
| AC-1.6 | Disabled and `aria-busy` while loading: `spec/requests/scanners_spec.rb:17` and `spec/system/scanner_page_spec.rb:157`. Disabled while reading, enabled and primary when live, the secondary "Scan again" while a result shows: `spec/system/scanner_result_spec.rb:67` and `:84`; disabled with the camera unavailable: `spec/system/scanner_page_spec.rb:194`. Same place and size: `spec/system/scanner_result_spec.rb:129` (Scan again's rectangle equals Capture's; `03e995f8`) |
| AC-1.7 | `spec/system/scanner_page_spec.rb:42` (1280 × 900: the shell 480px wide and centred, one screen, the open destination sheet with the shell's left and width) |
| AC-1.8 | By reading `app/assets/stylesheets/collector/additions.css`, the block "Scanner page (spec 082 …)" at line 883. `.c-scan__top { … height:calc(56px + env(safe-area-inset-top)); padding:env(safe-area-inset-top) calc(var(--space-2) + env(safe-area-inset-right)) 0 calc(var(--space-2) + env(safe-area-inset-left)); }` (line 893) and `.c-scan__bottom { … height:calc(96px + env(safe-area-inset-bottom)); padding:0 calc(var(--space-4) + env(safe-area-inset-right)) env(safe-area-inset-bottom) calc(var(--space-4) + env(safe-area-inset-left)); }` (line 894). Both bars grow by their inset and pad by the left and right ones. A headless browser reports no inset, so no example |
| AC-1.9 | `spec/system/small_controls_touch_floor_spec.rb:430` (at a fine pointer, nothing injected, both sheets shown: Back, the destination, Done, the count, the main button, the torch and the sheets' `c-btn` are each at least 44 × 44, at least 6 measured). The controls the page draws only in some states, the after-add line's "Open your collection" and Undo, the failure block's "Send again" and "Sign in" and a stage notice's button: `:459` (`7783f23f`); the floor example measures injected markup shaped like `_added_action`, as the reviewer noted (Rulings). The page and its controls are listed in the spec's `pages`: the "scanner" row (line 209: Undo, Details, Show all and Set inside the sheets) and the "measurement mode" row (line 212: Skip); the selects' page list is `spec/system/select_touch_floor_spec.rb:50` and `:56`. The sheets' selects are not in the 44px list at a fine pointer: spec 072's rule makes them 36px there and 44px at a coarse one, a ruling (commit `b9fc02cc`, Rulings) |

### Story 2: The destination sheet

| AC | Proof |
|---|---|
| AC-2.1 | `spec/system/scanner_page_spec.rb:54` (the destination opens as `dialog#scanner_destination_sheet[open]`, focus inside it, a `window` marker survives, every track `readyState === 'live'`) |
| AC-2.2 | Parts in order, region, form, "Use a photo" and hint, foot: `spec/system/scanner_page_spec.rb:110` (`scanner_destination_status`, `scanner_picker`, `c-scan__photo`, `c-sheet__foot`). Photo hint: `spec/system/scanner_detection_spec.rb:67`. Art line in the sheet: `spec/system/scanner_art_spec.rb:39` (`.c-scanner__art[role=status]` read after opening the sheet). The sheet's title "Adding to" and its foot: `spec/requests/scanners_spec.rb:128`; the form (Condition, Location, "Set") in the sheet is used by every example of `spec/system/scanner_sitting_spec.rb`. Picking a photo closes the sheet and reads it: `spec/system/scanner_result_spec.rb:225`. The foot's links: `spec/system/footer_spec.rb:163` |
| AC-2.3 | Chosen place alone, status sentence, top bar value, camera live: `spec/system/scanner_sitting_spec.rb:85` ("Cards you scan now: condition not specified, in Blue binder.", `.c-scan__dest` "Blue binder"); condition alone: `:174`; Near mint and Blue binder together, the top bar reading exactly "Blue binder · NM" and the status "Cards you scan now: Near mint, in Blue binder.": `:347` (`ec8a6609`); "No location · NM" after Set with the sheet open: `:437`; focus on "Set", and again on a repeat: `:270`, `:287`; the status "Cards you scan now: Near mint, no location.": `:270`. A refused "Set" says today's refusal with focus on "Set": request-level, `spec/requests/scanner/sittings_spec.rb:791` and `:798`, and the top bar and sitting redrawn in the 422 answer too: `:272` (`f0a2c4f1`); not proved by a system example |
| AC-2.4 | Close, Escape and a click on the backdrop each close it and focus returns to the destination: `spec/system/scanner_page_spec.rb:54`; focus returns after a "Set" redrew the destination while open: `spec/system/scanner_sitting_spec.rb:437`. Nothing navigates: the marker in `spec/system/scanner_page_spec.rb:54`. The status region empty after closing, by Close and by Escape: `spec/system/scanner_page_spec.rb:71` (`03e995f8`, shown to fail with `sheets#emptyRegions` no longer emptying); and emptied on opening, so an Undo's sentence written while the sheet was closed is not shown stale: `spec/system/scanner_sitting_spec.rb:49` (`502c6a92`) |
| AC-2.5 | `spec/system/scanner_sitting_spec.rb:25` (a sitting survives signing out and the scanner resumes with the count); the place and condition kept on a reload, the select reading them: `:114`, `:202`; `spec/requests/scanner/sittings_spec.rb:228`. The top bar's own value after leaving the scanner and coming back: `spec/system/scanner_sitting_spec.rb:358` ("Blue binder · NM" and Done; `ec8a6609`) |

### Story 3: The camera and the guide

| AC | Proof |
|---|---|
| AC-3.1 | The boxes at the three stages, within a tenth of a pixel: `spec/system/scanner_geometry_spec.rb:23` (359.7 × 502.4 at y 126.8; 274.9 × 384.0 at y 84.0; 234.0 × 326.8 at y 72.6). The drawn box equals the rule at 390 × 844, 360 × 640 and 360 × 560, and the status line holding one line of text stays clear of it: `spec/system/scanner_result_spec.rb:54` (`03e995f8`). A synthetic card drawn at the mapped box is read ("Matched by its collector line"): `spec/system/scanner_result_spec.rb:28`. The helper draws the synthetic card where the live guide maps into the frame: `spec/support/scanner_helpers.rb:13`. The after-add line, however many lines its sentence wraps to, clear of the guide at the three sizes: `spec/system/scanner_page_spec.rb:194` (the `added_line_clear_of_guide` check, `:131`; `c896cf62`). Decision 2 accepts a two-line status line crossing the guide's top edge on a short stage, so its example checks one line. The OCR reading "Lightning Bolt", `MOM` and `0123` is the example's candidate and the "Matched by its collector line" note, not the strips' text |
| AC-3.2 | `spec/system/scanner_geometry_spec.rb:43` (the live guide mapped into a 900 × 1200 frame for a 390 × 692 stage lies inside the frame); a capture reads from it: `spec/system/scanner_result_spec.rb:28` |
| AC-3.3 | `spec/system/scanner_geometry_spec.rb:35` (the shipped shares, `GUIDE` `{ height: 0.8, maxWidth: 0.9 }`, `STAGE_ASPECT` 0.75, `guideRect` and a photo's `guideInFrame`); the photo and detector examples keep their assertions: `spec/system/scanner_detection_spec.rb:23`, `:31`, `:38`, `:43`, `:47`, `:54`, `spec/system/scanner_spec.rb:78`, `spec/system/scanner_adding_spec.rb:51` |
| AC-3.4 | `spec/system/scanner_result_spec.rb:266` (the window resized to 900 × 1000, the drawn guide equals the rule for the new stage) |
| AC-3.5 | Separate constants with their source in a comment: by reading `app/javascript/scanner/geometry.js` (`LIVE_GUIDE`, `shippedGuideWidth` and `liveGuideRect` beside the shipped `GUIDE`; commit `78c92256`, "the shipped framing's `guideRect`, `GUIDE` and every reading setting are unchanged"). Proved by diff: `git diff main...HEAD` leaves `detector.js` untouched (no lines), and in `geometry.js` leaves `guideRect`, `GUIDE` and `STAGE_ASPECT` as they were; `guideInFrame`'s new fifth parameter defaults to `guideRect(viewWidth, viewHeight)`, the old computation. The `script/scanner/detector_parity.rb` run itself is owed to the maintainer (it needs the spike corpus and a dev server; Rulings and deviations) |

### Story 4: A result in the pane's place

| AC | Proof |
|---|---|
| AC-4.1 | `spec/system/scanner_result_spec.rb:67` (a reading held open: `canvas.c-scan__frozen:not([hidden])`, `#scanner_status_text` "Reading the card…", the main button disabled, every track live). Shown to fail with the frozen-frame line removed (Proof by breaking). The canvas being the stage's size: not asserted |
| AC-4.2 | `spec/system/scanner_result_spec.rb:67` (`.c-scan.c-scan--result .c-scanpane__results #scanner_result`, `#status` "Done. What the scanner read and its candidates are showing.", `.c-scan__line--status[hidden]`, the secondary "Scan again"). The status line's text being empty: `spec/system/scanner_result_spec.rb:84` reads `#status` empty after "Scan again", and `spec/requests/scanner/sitting_entries_spec.rb:27` the status text emptied by an add; the empty text on the reading's answer is asserted at `spec/system/scanner_result_spec.rb:79` (`#scanner_status_text`'s text is "" once the result shows) |
| AC-4.3 | `spec/system/scanner_result_spec.rb:100` (at 390 × 844, 360 × 640 and 360 × 560, Other printings open, `.c-scanpane__results` scrolled to its end: `scrollTop > 0` at the two short viewports, and `expect_one_screen`: the document not scrollable, scroll position 0, the top bar at 0, the bottom bar at the viewport's bottom; `03e995f8`, `c896cf62`) |
| AC-4.4 | `spec/system/scanner_result_spec.rb:84` (no `.c-scan--result`, the canvas hidden, "Ready. Line the card up with the guide, then capture.", the enabled primary "Capture", `#status` empty, no new request: `scanner_sent` unchanged) |
| AC-4.5 | `spec/system/scanner_result_spec.rb:115` for the ended session (the pane holds "Your session has ended" and a "Sign in" link, "Scan again" discards both). The network and server failures, each with the pane's sentence, the name and collector line read, "Send again" and no "Sign in", and "Send again" sending again to a candidate: `spec/system/scanner_result_spec.rb:153` (two examples, `03e995f8`); "Scan again" discarding the failure and sending nothing: `:169`. Shown to fail with the failure block no longer shown, and with "Send again" always hidden |
| AC-4.6 | The sentences come from the answer, as today: `spec/requests/scanner/readings_spec.rb:89` and `:166` ("Nothing could be read"), `:170` ("The card catalog isn't ready yet"). Each of the three in the pane, with "Scan again" returning to the camera ("Ready. Line the card up with the guide"): `spec/system/scanner_result_spec.rb:199` (nothing read), `:204` ("No card matches what was read"), `:209` (catalog not ready); `03e995f8` |
| AC-4.7 | A refused add or a failed add leaves the result and says today's sentence in the pane's `#status`: `spec/system/scanner_adding_spec.rb:84` (a server failure: the sentence in `#status`, the candidate still shown, the add button enabled); a network failure, then the add once the network is back: `:95` (`03e995f8`); the lot-full and not-offered answers, 422 with the sentences: `spec/requests/scanner/sitting_entries_spec.rb:84`, `:92` |
| AC-4.8 | `spec/system/scanner_adding_spec.rb:61` (`#status` "You added this card, then undid it. Scan it again to add it.", no `.c-scanner__add`); the answer at request level, `#scanner_result` emptied and the sentence in `#status`: `spec/requests/scanner/sitting_entries_spec.rb:69` |
| AC-4.9 | The no-edge sentence in the pane's `#status`: `spec/system/scanner_detection_spec.rb:54` (it asserts the sentence is there, not that it ends `#status`). Scan again after a photo with the camera unavailable shows the stage notice with "Use a photo": `spec/system/scanner_result_spec.rb:253` |
| AC-4.10 | `spec/system/scanner_result_spec.rb:215` (a `grab` that throws: `#scanner_status_text` says "The card couldn't be read. Line it up with the guide and try again.", no `.c-scan--result`, the canvas hidden) |

### Story 5: After an add

| AC | Proof |
|---|---|
| AC-5.1 | `spec/system/scanner_sitting_spec.rb:320` (`#scanner_added_text` exactly "Added Lightning Bolt MOM · 123, foil", `.c-scan__added-action` button "Undo", `.c-scan__line--status[hidden]`, no `.c-scan--result`, the enabled "Capture", focus on `[data-scan-main]`, `.c-scan__done` "Done"). The count one more: `spec/system/scanner_adding_spec.rb:30` ("1 added. Show this sitting's cards."). The result and `#status` emptied: `spec/requests/scanner/sitting_entries_spec.rb:27`; `spec/system/scanner_adding_spec.rb:30` (no `.c-scanner__candidate`). The frozen frame gone after an add: `spec/system/scanner_sitting_spec.rb:369` (`ec8a6609`) |
| AC-5.2 | `spec/requests/scanner/sitting_entries_spec.rb:55` and `spec/helpers/scanners_helper_spec.rb:83` ("Added Lightning Bolt MOM · 123" with no finish) |
| AC-5.3 | `spec/system/scanner_sitting_spec.rb:38` (Undo on the line: "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.", the copy gone, focus on the main button, nothing navigated). The line's Undo going and the count one less: `:379` (two adds, one Undo: "Removed 1 × Lightning Bolt", no "Undo" button, the action element empty, the count 1; `ec8a6609`, shown to fail with the after-add action not redrawn after an Undo and with the count redrawn one too high); the refused Undo's line is `spec/requests/scanner/sittings_spec.rb:103` |
| AC-5.4 | `spec/system/scanner_sitting_spec.rb:468` (the next capture: `.c-scan__line--added[hidden]`, `.c-scan__line--status:not([hidden])`). The status line's text "Reading the card…" at that moment is `spec/system/scanner_result_spec.rb:67`'s |
| AC-5.5 | `spec/system/scanner_sitting_spec.rb:320` (after a second add, `#scanner_added_text` is the same element as after the first). That the Undo names the second entry: `:391` (a Lightning Bolt then a Counterspell: "Undo Counterspell (MOM · 124, Foil)" and not the Bolt's, and the Undo removes the Counterspell; `ec8a6609`) |
| AC-5.6 | The summary and "Open your collection" with the collection's `href`, no hidden attribute: `spec/requests/scanners_spec.rb:65`; `spec/requests/scanner/sittings_spec.rb:120`; in the browser, `spec/system/scanner_sitting_spec.rb:114` ("Added 1 card in this sitting.", the link, the top bar "No location"), and the link beside the sentence, outside its live region, in the same wrapper: `:415` (`ec8a6609`). A flash from a page the scanner was left for, once: `spec/requests/scanners_spec.rb:77`; the flash's Undo beside the sentence, outside the live region, posting to the bulk removal's undo with `return_to` the scanner: `spec/requests/scanners_spec.rb:89` (`e977d110`; request-level, since the flash has no real path to the scanner, Rulings). A plain visit leaves the line empty and hidden: `spec/requests/scanners_spec.rb:121` |

### Story 6: The sitting's list sheet

| AC | Proof |
|---|---|
| AC-6.1 | The sheet opens from the count with the camera running and nothing navigating, titled "This sitting: 0 cards": `spec/system/scanner_page_spec.rb:119`. The entries newest first with Details, Undo and "Show all" past 10: `spec/requests/scanner/sittings_spec.rb:25`, `:40`. The foot: `spec/system/footer_spec.rb:163`. The sheet's `role="status"` region: `spec/requests/scanners_spec.rb:128` (the sheet's title and foot); the region by id, `#scanner_list_status`, is read in `spec/system/scanner_sitting_spec.rb:304` |
| AC-6.2 | `spec/system/scanner_sitting_spec.rb:304` (Undo from the sheet by keyboard: `#scanner_list_status` "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.", `#scanner-sitting-heading:focus` "This sitting: 1 card", the list redrawn to "Everything added in this sitting was undone."; the title's ring). The refused Undo's refusal in the list's region: `spec/requests/scanner/sittings_spec.rb:90`, `:103`, `:805`. The count button one less after an Undo in the sheet: `spec/system/scanner_sitting_spec.rb:425` (`ec8a6609`, shown to fail with the count redrawn one too high) |
| AC-6.3 | `spec/system/scanner_page_spec.rb:119` ("Nothing added yet."); "Cards you scan now: …" and "Everything added in this sitting was undone.": `spec/requests/scanner/sittings_spec.rb:208`, `:493`; `spec/system/scanner_sitting_spec.rb:304` |
| AC-6.4 | `spec/requests/scanner/sittings_spec.rb:576` (Edit copy returns to the scanner) and `spec/requests/scanners_spec.rb:77` (the flash on the after-add line). The Details link itself: `spec/requests/scanner/sittings_spec.rb:25` |
| AC-6.5 | `spec/scanner_sitting_core_spec.rb:14` and `:18` (12 files, among them `_count`, `_added_line`, `_added_action`, `_destination_sheet`, `_list_sheet`, `_sitting_bar`; none matches `mtg`, `scryfall` or `magic`) |

### Story 7: The re-measure at the new framing

Story 7 is owed in part: AC-7.3, AC-7.4's run and AC-7.5 wait on the maintainer's paired run (plan Phase 9). The tooling has examples.

| AC | Proof |
|---|---|
| AC-7.1 | The same shell, the top-bar button with the next row, "‹captured› of ‹rows›" and the framing, and the run sheet holding the panel: `spec/system/scanner_measurement_spec.rb:102` ("IMG_1.jpeg · 0 of 1 · full", the "Card to capture" select in `#measurement_sheet`), the store from a capture and the button after it ("All done · 1 of 1 · full", "Stored IMG_1.jpeg as the measured capture", the strip file on disk): `:102`, `:120`, `:134`. The hidden `<h1>` "Measure the scanner" and the framing switch's two buttons in the sheet: `:62`; a store failure showing in the pane's `#status` as well as the sheet's line: `:72` (`ec8a6609`; the fix `423301e6`). The button reading the framing: `spec/requests/scanner/measurements_spec.rb:159`. The three sheets' feet: `spec/requests/footer_spec.rb:238` |
| AC-7.2 | The shipped framing's box in the tall stage: `spec/system/scanner_geometry_spec.rb:30` (297.8 × 416.0 at y 170.0 for 390 × 692). The session's framing, its form, the 422 for another value (and for a hash or a list, `:177`, `fc22bb48`), the 404 with measurement mode off, a capture and the reading's record under `‹run dir›/shipped` with the framing, frame size and stage size, the scanner's own page drawing the full framing: `spec/requests/scanner/measurements_spec.rb:159`, `:169`, `:186`, `:198`. The run directory per framing, and `.framing_in`: `spec/models/scanner/measurement_run_spec.rb:131`, `:140`; the sizes in a capture: `:147`. A reload keeping the framing is `spec/requests/scanner/measurements_spec.rb:159`'s second request. A Skip stored under `shipped`, with the shipped framing's guide drawn in the browser: `spec/system/scanner_measurement_spec.rb:84` (`ec8a6609`) |
| AC-7.3 | Owed to the maintainer, with the corpus and `research.md` (Phase 9). The tasks it names, `scanner:ground_truth` and `scanner:overlap`, are existing tooling, not changed here |
| AC-7.4 | The tooling: `spec/lib/collector/scanner_findings/paired_report_spec.rb:48`, `:54`, `:59`, `:65` (one column per framing, the discordant cards, the sizes, bar A passing and failing, a card measured by one framing left out and listed), and the task `scanner:paired_findings` (`lib/tasks/scanner.rake:145`). The report on real runs in `research.md`: owed to the maintainer |
| AC-7.5 | Owed to the maintainer, after the run: only if bar A fails (spec decision 4). Not applicable until then |

## Functional requirements

- **FR-1, the focused layout:** `spec/requests/scanners_spec.rb:128` (the classes, no header, tab bar, footer or `#status`); every other page's output is unchanged by the footer examples that still pass, `spec/requests/footer_spec.rb:40`. The layout naming no scanner or collectible: `spec/footer_core_spec.rb:17`.
- **FR-2, the shell:** the main button in view and one screen, `spec/system/scanner_page_spec.rb:194`; controls at 44px, `spec/system/small_controls_touch_floor_spec.rb:430`; the camera kept across a sheet, `spec/system/scanner_page_spec.rb:54`, `:119`; released on leaving the page, `spec/system/scanner_spec.rb:31`; no navigation from the destination or the count, the same two examples.
- **FR-3, the live guide:** one computation for the page and the crop, `spec/system/scanner_result_spec.rb:28`, `spec/system/scanner_geometry_spec.rb:23`, `:43`; the photo path, strips and detector unchanged, `spec/system/scanner_geometry_spec.rb:35`, `spec/system/scanner_detection_spec.rb:72`; the framing taken from the session only while measurement mode is on, `spec/requests/scanner/measurements_spec.rb:169`, `:198`.
- **FR-4, the sheets:** modals opened by their buttons, closed three ways, focus back, no navigation, `spec/system/scanner_page_spec.rb:54`, `:119`; the region emptied on closing, `spec/system/scanner_page_spec.rb:71`; the dialog kept across a redraw, `spec/system/scanner_sitting_spec.rb:270`; the foot, `spec/system/footer_spec.rb:163`, `spec/requests/footer_spec.rb:217`.
- **FR-5, results and adds:** `c-scan--result` exactly while the pane has something, `spec/system/scanner_result_spec.rb:67`, `:84`, `spec/system/scanner_sitting_spec.rb:320`; the frozen frame, `spec/system/scanner_result_spec.rb:67`; the table's regions, `spec/requests/scanner/sitting_entries_spec.rb:27`, `spec/requests/scanner/sittings_spec.rb:103`, `:829`; the lines' text replaced in place, `spec/system/scanner_sitting_spec.rb:320`; nothing new sent, `spec/system/scanner_detection_spec.rb:47`, `spec/system/scanner_art_spec.rb:23`, `:39`, `spec/system/scanner_result_spec.rb:84`; nothing added without a tap, the add routes unchanged (`spec/system/scanner_adding_spec.rb:30`, `:44`).
- **FR-6, the re-measure:** development-only and stored outside the repository, `spec/requests/scanner/measurements_spec.rb:40`, `:69`; each capture's framing and sizes, `spec/models/scanner/measurement_run_spec.rb:147`; last in the plan with nothing waiting on it, plan Phase 9. The run itself is owed.

## Error scenarios

- **The camera is denied, missing, fails or is lost:** `spec/system/scanner_spec.rb:69` (a blocked camera, "Try the camera again"), `spec/system/scanner_page_spec.rb:194` (the main button disabled, one screen), `spec/system/scanner_result_spec.rb:253` ("Use a photo" in the stage notice). The sheets still opening: the sheets open over a running camera in `spec/system/scanner_page_spec.rb:54`, `:119`; with the camera unavailable specifically, not proved by an example.
- **The page is not a secure context:** `spec/system/scanner_spec.rb:55`.
- **The engine fails to load:** `spec/system/scanner_page_spec.rb:210` (the notice, "Load the scanner again", the main button disabled and in view at three viewports; the retry button's reload is not proved, commit `33278a49`, Rulings).
- **The catalog isn't loaded:** `spec/system/scanner_page_spec.rb:222` (the line at the stage's foot, "Capture" enabled). That a reading says the catalog isn't ready: `spec/requests/scanner/readings_spec.rb:170`. Not dismissable: not asserted.
- **Script is off:** `spec/system/footer_spec.rb:183` (the `<noscript>` notice holds the content links), `spec/requests/scanners_spec.rb:128` (the `<noscript>` sentence "The scanner needs JavaScript" and the foot). The top bar's links working with script off: not proved by an example.
- **A reading's send fails:** the ended session, `spec/system/scanner_result_spec.rb:115`; network and server failures, `spec/system/scanner_result_spec.rb:153` (AC-4.5).
- **A reading throws:** `spec/system/scanner_result_spec.rb:215`.
- **An add is refused or the lot is full:** `spec/system/scanner_adding_spec.rb:84`, `spec/requests/scanner/sitting_entries_spec.rb:84`.
- **A replayed add of an undone or changed reading:** `spec/system/scanner_adding_spec.rb:61`, `spec/requests/scanner/sitting_entries_spec.rb:69`.
- **"Set" names a removed location or an unknown condition:** `spec/requests/scanner/sittings_spec.rb:791`, `:798` (request level).
- **The destination's value is too long:** `spec/system/scanner_sitting_spec.rb:143`.
- **The camera reports no torch:** `spec/system/scanner_spec.rb:44`.
- **The sitting is ended on another device:** `spec/requests/scanner/sittings_spec.rb:112` (the entry's Undo answers 404 once the sitting has ended); the next add opening a new sitting is spec 009's.
- **The stage is short:** `spec/system/scanner_page_spec.rb:194` at 360 × 560 (the bars stay, one screen), `spec/system/scanner_geometry_spec.rb:23` (the guide's box at 360 × 408), `spec/system/scanner_result_spec.rb:99` (a result scrolls in the pane, at 360 × 640).
- **A source supplies no content notice:** the licence line alone in the foot, `spec/requests/footer_spec.rb:192` (spec 084's example, for the shared partial).
- **Measurement mode's manifest is broken:** `spec/requests/scanner/measurements_spec.rb:147` ("No manifest at", the scanner itself unaffected). The top bar and a stage notice with no camera requested: not proved by an example.
- **The re-measure misses the bar:** AC-7.5, owed.

## Documentation requirement

The documents are verified by reading, under "Documents verified by reading" below.

## Proof by breaking

Cases the commit bodies record: a rule or a line was broken, the example failed, the code was restored.

- **AC-1.1, `28859afe`:** with spec 080's `.c-shell--focused` rule removed, the three "is one screen" examples fail (the page scrollable, `scrollY` 16, the top bar at -8); restored, they pass.
- **AC-4.1, `6f590c0d`:** with `this.frozenTarget.hidden = false` deleted, the freeze example fails (`canvas.c-scan__frozen:not([hidden])` not found); restored.
- **AC-2.4's focus ring, `8233d050`:** the list sheet title's ring was missing under `:focus-visible` (Firefox gives programmatic focus none once the focused Undo is replaced); the example failed until the rule used `:focus`.
- **Decision 10's table, `eee51d7a`:** red first, the refused Undo's 422 answer had no `scanner_added_text` stream; then fixed.
- **AC-3.1, `6f590c0d`:** the drawn guide came out 364px wide against the rule's 360 until `box-sizing:border-box` was added (a red run, not a deliberate break).
- **AC-1.9, `b9fc02cc`:** the eight red touch-floor examples were found to be the spec's own waits and selectors, not the app's (root cause recorded in the commit).

Cases the review's fix commits record (Broke to see red, then restored):

- **AC-1.5, `03e995f8`:** with `.c-scan__main`'s `flex` at `0 1 auto`, the "takes the torch's room" example fails; restored.
- **AC-2.4, `03e995f8`:** with `sheets#emptyRegions` no longer emptying, the "region empty once the sheet closes" example fails; restored.
- **AC-4.5, `03e995f8`:** with the failure block no longer shown, and with "Send again" always hidden, the network and server failure examples fail; restored.
- **AC-5.3, `ec8a6609`:** with the after-add action not redrawn after an Undo, the Undo example fails; restored.
- **AC-5.3 and AC-6.2, `ec8a6609`:** with the count redrawn one too high, the count examples (after an Undo from the line and from the list sheet) fail; restored.
- **The alert-class fix, `bdc24acf` and `f7b19c1a`:** the two examples ("drops the alert style from the after-add line on the next capture" and "…once an Undo from the list sheet writes its answer on the line", `spec/system/scanner_sitting_spec.rb:449`, `:458`) came with the fixes; `f7b19c1a`'s body records the second as the gap the second review round found, and no deliberate break.
- **Code-fix items 1 and 2 (`7783f23f`, the after-add line's action, the failure block and the stage notices' buttons at 44px; `bf5824c6`, the empty live regions kept rendered):** each came with its example (`spec/system/small_controls_touch_floor_spec.rb:459`, `spec/system/scanner_page_spec.rb:24`); their commit bodies record no deliberate break, so none is claimed.
- **AC-1.2, AC-2.x other than AC-2.4, AC-4.3 and AC-6.1:** no recorded break beyond the ones above.

## Rulings and deviations

Each `Ruling:` line in the commit bodies, with its commit.

- `5882601f`: the re-measure's bar is A, the paired run (the maintainer, 2026-11-13). The other calls are confirmed as written.
- `3e07d3b3`: the notice's partial is `layouts/_notice_lines.html.erb` with no locals, shared with spec 084, and a sheet always has a foot (the coordinator, 2026-11-13).
- `f5c8d950`: the shared notice partial and its consequences are accepted (the maintainer, 2026-11-13).
- `910c9cd0`: `.c-scanner__status` stays (the replay page uses it) and so does the `.c-scanner *` reduced-motion rule, which the frozen block's comment names; it matches nothing now and costs nothing (cost if wrong: one dead rule).
- `8d4ef229`: `spec/requests/scanner/measurements_spec.rb` now looks for `#scanner_picker select#sitting_condition`, since the control moved out of `#scanner_sitting` into the destination sheet.
- `8d4ef229`: `spec/system/footer_spec.rb`'s sheet-foot example read the sheets with `visible: :all` until the sheets controller existed; `28859afe` switched it to open them.
- `28859afe`: the "Done" sentence kept its text ("…candidates are below.") and went to the pane's `#status` as a `c-status__message` paragraph, since existing specs asserted it; `6f590c0d` then changed the wording (spec decision 10).
- `28859afe`: the backdrop-close example dispatches a `MouseEvent` on the dialog, as the plan allows; a real tap on the scrim is not exercised.
- `28859afe`: `scanner_art_spec.rb` opens the destination sheet to read the art line and closes it before capturing, since a modal sheet blocks the main button.
- `6f590c0d`: `.c-scan__guide` gets `box-sizing:border-box` in the spec 082 CSS block, since spec 080's rule sets none and the 2px border made the drawn guide 364px against the rule's 360 (cost if wrong: a 4px larger guide).
- `6f590c0d`: `states_at` is named `expect_states_at`, since `RSpec/NoExpectationExample` only accepts `expect_` helpers.
- `6f590c0d`: `expect_states_at` waits for `window.__release` before calling it, since the held request is made only after OCR and the call raced.
- `6f590c0d`: the photo examples wait for the picker to be enabled before picking, since `pick` returns while the engine loads.
- `8233d050`: the list sheet title's focus ring is `:focus`, not `:focus-visible`; Firefox gives programmatic focus no `:focus-visible` once the focused Undo was replaced by the answer. The title is `tabindex -1` and focused only by the redraw.
- `b9fc02cc`: the sheets' selects are not in AC-1.9's 44px list; spec 072 makes them 36px at a fine pointer and they meet the floor at a coarse one.
- `b9fc02cc`: the AC-1.4 overlap example closes all sheets but the first, since `settle` shows every sheet at once and two open sheets overlap; only the sheets' own layout is measured.
- `b9fc02cc`: `report_roots` and `scanner_sheets` are methods, not a constant (no constants in a `describe`).
- `33278a49`: the engine failure is made by serving no engine files under a fresh version path (a stubbed `VERSION` and `path_for` returning nil), not by the plan's `createWorker` stub and `retryEngine`; the loaded worker is cached for the page's life and a stubbed `path_for` on the old version still loaded from the browser cache. Cost if wrong: the example proves the first load's failure, not the retry button's reload.
- `6422ad8e`: the measurement panel's own heading is an `h3` "Run" inside the run sheet, whose `h2` is "Measured run"; two headings both reading "Measured run" in one sheet repeat themselves.
- `6422ad8e`: `render_panel` also replaces the run button in the same response by a second Turbo Stream; the plan said the button is replaced with every answer, and a stream response can carry two actions.
- `7d36c47e`: the other run-scoring tasks read `FRAMING` (default `full`, empty for the configured directory itself), since measurement mode now writes under the framing's directory, so unset must score where captures land. A stale run in the bare directory needs `FRAMING=` to score.
- `7d36c47e`: the paired spec's cards are Lightning Bolt and Counterspell with explicit identities; a short name (Opt) was not a name candidate and the factory's default identity differs from the entry name (spec data).

Rulings from the implementation review's two rounds (the commits `7783f23f` to `c896cf62`):

- `7783f23f`: the after-add line's action, the failure block's buttons and the stage notices' buttons are 44px at every pointer (AC-1.9); the floor example measures injected markup shaped like `_added_action` (the reviewer's note), since those controls exist only in some states.
- `bf5824c6`: empty live regions stay rendered and take no space (`:empty` rules), not `hidden` or `display: none`, since a region taken out of the accessibility tree while empty is not announced when it is filled (spec 080 decision 8).
- `f0a2c4f1`: a refused "Set" redraws the top bar and the sitting too, since they show what the sitting holds (spec 082 decision 10).
- `502c6a92`: a sheet's live regions are emptied on opening as well as on closing, since an Undo from the after-add line writes into the list sheet's region while it is closed.
- `e1390c6f`: a photo picked while a result shows clears the result and its frozen frame first.
- `bdc24acf`, `f7b19c1a`: a capture, and an answer replacing the sentence (a list-sheet Undo), drop the alert style the after-add line was loaded with.
- `423301e6`: the pane's sentence no longer replaces measurement mode's store failure.
- `fc22bb48`: a framing sent as a hash or a list answers 422, not 400.
- `f1b360a0`: the broken-manifest page carries the small print in its notice.
- `7bfd66da`: stale comments and docs match the built page (the README's "no page uses them yet", the Undo class `c-scan__undo` in `Scanner.md`, the sheets' regions emptied on opening in `scanner.md`).
- `fa4bf23c`: the paired report states per framing whether art matching was on (from a capture's `art_ms` or a recorded reading's `art_status`) and the user agents seen, and bar A's boundaries are examples (right card first one below passes, two below fails; exact printing two below passes, three below fails).
- `e977d110`: the AC-5.6 flash-with-Undo has no real path to the scanner (only bulk removals set `flash[:undo]`, and they redirect to the collection page), so its request example reaches the scanner directly after a bulk removal.
- m9, accepted (development-only): a flash on measurement mode's page is lost.
- Accepted (development-only): the `data-pane-keep` store-failure note can reopen the pane alone after an add.
- The AC-1.9 floor example (`7783f23f`) measures injected markup shaped like `_added_action`, not the page's own render, as the reviewer noted.

Deviations from the plan and the run:

- **The detector parity script could not run here (AC-3.5).** `script/scanner/detector_parity.rb` needs the spike corpus under `~/card-scanner-corpus/runs/phase2` and a dev server. Owed: the maintainer runs it. `78c92256` changed `guideInFrame` (a fifth `rect` parameter that defaults to the old computation) and left the shipped framing's `guideRect`, `GUIDE`, `STAGE_ASPECT` and the detector untouched (checked by diff against `main`), so a failure is not expected; the run is the maintainer's.
- **The `scanner_page_spec.rb` "states" examples were red between T4 and T5.1, as declared** in `6f590c0d`: the three "keeps the main button in view …" examples (390 × 844, 360 × 640, 360 × 560) reached the add step and failed on the sitting answer (unknown local `choices`) until T5.1 (`33b110dc`) rewrote the answers. Other examples were red between tasks as each commit body lists (the sitting and adding examples until `8233d050`, the touch floors until `b9fc02cc`, `scanner_measurement_spec` until T7.2, `select_touch_floor_spec` until T6.3); none was red at the head.
- **The main session ran on Sonnet 5.5 for part of the run, against the brief's Opus 5.5.** The 25 commits `dee35908` through `cf5b0790` carry a Sonnet 5.5 `Co-Authored-By` trailer, the supervisor's own commits among them; the spec's drafting and revisions (`bd0515db` through `f5c8d950`), the merge `57841039` and the last commit `c4cbfe7e` carry Opus 5.5.
- The plan's Phase 9 (the re-measure) did not run; the pull request stays a draft until it has (spec decision 1).
- **Two statements in the design system were stale** (found in this reading, fixed in `7bfd66da`; see Documents verified by reading); as found: `docs/design-system/README.md` line 85, in the touch-target bullet, still says of the rules drawn for the shell, pane and a sheet's Close "(spec 080; no page uses them yet)", and the spec's Documentation item names the README's "no page does yet". The scanner uses the shell, the sheet and Close now. `docs/design-system/components/StatusBand.md` line 18 and `Scanner.md` line 89 say "no view renders" a band or the pane; those are about #345's pane and stay true.

## Documents verified by reading

Each of the Documentation requirement's items, read in this worktree at `c4cbfe7e`; the two statements the implementation review found stale were fixed in `7bfd66da` and re-read at `c896cf62`.

- **`docs/architecture/scanner.md`: the page, the sheets, the lines, decision 10's table, the guide's rule in Named constants, the landscape limit and the re-measure.** It says: "The scanner is one screen that never scrolls, and its main button is always in view. On a phone the document never scrolls (its scroll height equals its client height) in 390 × 844, 360 × 640 and 360 × 560 portrait viewports…". The table "Where each answer is said" is at line 120, the sheets at line 142, the paired findings and the framing in the session in the changed paragraphs. The guide's rule is the Named constants row `LIVE_GUIDE` (`top` 64 px, `height` 0.8, `maxWidth` 0.975, `maxHeight` 0.95, line 243) and the framings row `FRAMINGS` (line 244); the paired findings and `FRAMING=` are at lines 215 to 221. The landscape limit is the bullet "Landscape and short stages (accepted limit)" at line 289.
- **`docs/architecture/catalog-core.md`: the notice's place on the scanner.** It says: "**The notice on the scanner.** The scanner is a one-screen focused page with no footer, so its small print is not the footer's. `layouts/_notice_foot`, the `c-sheet__foot` that ends each of the scanner's sheets … renders `layouts/_notice_lines`…" (line 136), and the footer rule at line 61 names the one exception.
- **`docs/design-system/README.md`: the "no page does yet" replaced by a focused page's notice in its sheets.** It says: "A focused page that is one screen high and has no footer shows the content notice's lines, and the licence line, through the same partial as the footer, in the foot of each of its sheets … The scanner does (spec 082 decision 16)" (line 81), and "The phone-first scanner is the first [focused page], built by spec 082" (line 80). The stale clause at line 85 is fixed (`7bfd66da`); it now says: "…and the rules drawn for the phone-first scanner's shell and pane and a sheet's Close (spec 080; the scanner uses them, spec 082), keep their own rules."
- **`components/Scanner.md`: loses the "As built" parts and stops calling the shell "not built".** It says: "The card scanner. Three parts: the one-screen page, built by #344 (spec 082) on spec 080's shell; what the selection pane will be, drawn by spec 080 and built by #345; and the result partial that fills the pane until #345 replaces it." Its remaining "None of it is built" (line 87) and "no view renders it yet" (line 89) are about the pane, which is #345's. The stale Undo bullet (line 67) is fixed (`7bfd66da`): it now names the form `form.c-scan__undo` (it said `form.c-scanner__undo`), "in the list or on the after-add line", and says "from the after-add line the line says the same and focus goes to the main button, as it does after an add".
- **`components/Sheet.md`: says the scanner uses it.** It says: "Uses, on the phone-first scanner (`Scanner`, spec 082): the sitting's destination ("Adding to", `#scanner_destination_sheet`), the sitting's list (`#scanner_list_sheet`) and, in development's measurement mode, the "Measured run" sheet."
- **`components/Footer.md`: says the scanner is the exception.** It says: "The exception is a one-screen focused page (the scanner), which has no footer, no `contentinfo` landmark and no `c-shell--footed`: its sheets carry the same lines, the licence line last, in their foot (`Sheet`)…"
- **`docs/specs/README.md`, both directions.** Spec 082's row (line 99) lists "018 FR-2 for the scanner page; 009 AC-1.3, 040's notice and 042 AC-1.4 (the add's sentence); the sitting panel's place (009 AC-3.2, AC-3.5; 042); 040 AC-7.1 and 042 AC-7.1's "no script is added" as far as reaching the control; 047's status region for "Set" and Undo; 007 AC-1.1's stage for live capture; 009 AC-7.2, AC-7.4 …". Each "Superseded by" cell of specs 007, 009, 011, 018, 040, 042, 047 and 084 carries a 082 entry (counts of "082" in the rows: 007: 1, 009: 5, 011: 1, 018: 1, 040: 2, 042: 3, 047: 1, 084: 1), for example spec 009's "AC-3.2's and AC-3.5's place of the sitting panel, list, heading and summary: 082 (decisions 7, 9; AC-5.6)". The row of spec 082 says "Approved" and its plan "present", as it should before the merge.

## Screenshots

In [screenshots/](screenshots/) (commit `cf5b0790`), factory data and a synthetic card, JPEG for the shots and GIF for the flows; phone shots are a 390 × 844 frame and desktop 1280 × 900, each in light and dark (`-light`, `-dark`):

- `phone-aiming-*.jpg`, `desktop-aiming-*.jpg`: the live camera with the guide, the top bar's destination, the count and the main button.
- `phone-result-*.jpg`: a result over the frozen frame, "Scan again" as the main button. The pane holds today's result partial: the add buttons sit below the pane's fold, which #345 replaces (the band, the swipe row, the details block and one add per finish).
- `phone-after-add-*.jpg`: the live camera after an add, the after-add line with its Undo and the count one more.
- `phone-destination-*.jpg`, `desktop-destination-*.jpg`: the destination sheet open over the camera (the Condition and Location form, "Use a photo", the foot).
- `phone-list-*.jpg`: the list sheet with the sitting's entries.
- `phone-camera-unavailable-*.jpg`: the stage notice with "Use a photo" and "Try the camera again"; the status line reads "Ready." here, as decision 14 says for the camera unavailable once the engine is ready.
- `flow-capture-add.gif`: capture, the result, the add and the camera live again with the after-add line.
- `flow-sheets.gif`: the two sheets opened and closed over the running camera.

The images were not opened to write this record; their content is as the commit body of `cf5b0790` and the spec describe it, and the final visual review is the maintainer's.

## Owed to the maintainer

- **The paired re-measure (Phase 9, Story 7).** The corpus (AC-7.3), the two runs, the report from `scanner:paired_findings` and bar A's outcome in `research.md` (AC-7.4), and, only on a miss, the fall-back (AC-7.5). The pull request stays a draft until it has run.
- **A screen-reader pass on a phone** over the sheets, an add, an Undo from each place and a refused add, checking each sentence is said once (NFR Accessibility, decision 10).
- **The detector parity run:** `SCANNER_EMAIL=… SCANNER_PASSWORD=… bundle exec ruby script/scanner/detector_parity.rb` on a dev server with the spike corpus (AC-3.5).
- **A phone check of the frozen canvas's crop:** `object-fit: cover` on a `canvas` (`.c-scan__frozen`) is read by the examples only as a hidden or shown element; whether the cover crop of a canvas matches the video's crop on a real phone is not shown (plan, Risks).
- **The safe-area insets on a notched phone** (AC-1.8 is by reading only), and the final visual review of the screenshots.

## CI

- `bin/ci checks` at `c4cbfe7e`: passed (after `c4cbfe7e` added the two helper summaries the comment ratchet named).
- Full `bin/ci` at `c4cbfe7e` (seed 20210): every step green but RSpec, 4,764 examples, 1 failure, 1 pending. The failure, `spec/requests/licence_line_spec.rb:20`, was spec 084's footer example listing the scanner, which since patch 1.0.3 has no footer; fixed in `feb9a5aa` and `4a737f4f` (the scanner's example asserts the licence line in each sheet's foot and the noscript notice, and no footer), `spec/requests/licence_line_spec.rb` 17 examples, 0 failures. The next full run is recorded below once the review's fixes are in.

## Implementation review

SPEC-ALIGNED, by the supervisor after round 2 (not the reviewer's own verdict), and the coordinator checked the three commits that closed it; Story 7's AC-7.3 to 7.5 are owed to the maintainer's re-measure by design (decision 1).

- Round 1 (Opus, read-only, sdd-review Mode B): INCOMPLETE. No blocking finding; 4 major (empty live regions hidden from the accessibility tree; AC-4.5's network and server failures unproved; three controls under 44px; the paired report missing art on/off and the user agents and bar A's boundaries), 9 minor, and partly-proved clauses of AC-1.2 to 1.6, 2.3 to 2.5, 3.1, 4.2, 4.3, 4.5 to 4.7, 5.1, 5.3, 5.5, 5.6, 6.2, 7.1, 7.2. All fixed in `7783f23f`..`7bfd66da` and proved in `fa4bf23c`..`ec8a6609`; m9 accepted (development-only).
- Round 2 (the same reviewer): INCOMPLETE. Every round-1 finding fixed, no spec drift, nothing new broken; four clauses still without an example (AC-1.2's engine loading and Other printings at all three sizes, AC-3.1's after-add line clear of the guide, AC-5.6's flash action) and the alert style left after a list-sheet Undo. Closed in `e977d110`, `f7b19c1a`, `c896cf62`; the supervisor checked the diff and the run (305 examples, 0 failures; `bin/ci checks` passing) rather than spend a third review round (the run's limit is two).
- Owed: the paired re-measure (Phase 9), the detector parity run, a screen-reader pass on a phone, a phone check of the frozen canvas's crop.

## Distillation

Distilled on 2026-11-13 (`distill-feature`, state 2), before the pull request: the area docs `docs/architecture/scanner.md` and `catalog-core.md` were written with the feature (`231c8b8b`) and updated at the merge of spec 084 (`57841039`); `e2e35985` adds their distillation log rows ("spec 082's pull request" until it has a number), sets the index row to Frozen in part (all but Story 7's outcome, the re-measure owed to the maintainer) with its plan owed a retirement, and names spec 082 in CLAUDE.md's card scanner paragraph; `2879cb0b` adds the spec's frozen line (spec 027 D4). Not distilled: Story 7's outcome. Phase 9 adds `research.md`, and the area doc and `geometry.js` change only if bar A fails (AC-7.5). The design-system documents (`Scanner`, `Sheet`, `Footer`, the README) were written in `855c786e`.
