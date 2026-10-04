# Feature 009: Card Scanner — Confirm and Add, and Detection on the Photo Path

**Status:** Draft
**Version:** 1.1.2
**Created:** 2026-10-03
**Last Updated:** 2026-10-03
**Branch:** `009-card-scanner-confirm-flow`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-03 | Initial draft. Open questions resolved by the maintainer: Undo after an edit (AC-4.4), the Done summary (AC-3.5) |
| 1.1.0 | 2026-10-03 | Spec review revisions (Fable). **Idempotency:** each reading carries a reading key minted by the page; one sitting entry per key (AC-1.4, AC-1.5, FR-1, FR-2, FR-5). **Strong** is one named rule over the top name candidate, chosen on the stored text and committed with the settings (AC-5.1). **Ground truth** for tuning round 4 and the new corpus is committed as text before the re-score (AC-5.4). **Supersession** list gains spec 007 AC-4.2 and FR-3. **Done summary** is shown only in the response to Done and isn't stored (AC-3.5, AC-3.7). **Maintainer rulings:** the finish is recorded as tapped, including Nonfoil (AC-1.2); a scanner Undo that removes a lot ends the session's bulk-removal Undo (AC-4.1); messages use spec 004's wording plus the finish (AC-1.3, AC-4.1); a retired printing is refused (Error Scenarios). **Also:** a glossary, FR lines for reachability and reading, timing targets measured outside the gating suite, AC-7.3's reference, AC-2.3's tie-break, Undo on an ended sitting, Done with nothing left |
| 1.1.1 | 2026-10-03 | The live sitting's pile is 35 prepared cards, not about 50 (Goals, AC-9.1) |
| 1.1.2 | 2026-10-03 | Second spec review (Fable, READY TO PLAN after these fixes). **AC-5.4:** the three misread cases are checked on the live run only. **Replays:** a replayed add answers with its sitting entry's current state, a missing or malformed reading key is refused, and keys are unique within a sitting (AC-1.5, Error Scenarios, NFR Security). **AC-5.3:** only the top name candidate is cross-checked, never when the collector-line printing ranks first, and only digits are edited. **Also:** the sitting count's definition and a list of the newest 10 with Show all (maintainer ruling, AC-3.2); the Done summary's delivery (AC-3.5); Other printings lists only printings that aren't retired (AC-2.2); the rank is sent only in measurement mode (AC-9.2); the re-score covers cleaning and ranking together (AC-5.4); spec 007 AC-3.3 joins the supersession list |

---

## Problem Statement

The card scanner (spec 007) reads a card and ranks candidate printings, but it can't add anything: AC-3.10 sends the collector to the catalog search instead. As a result the scanner is a demonstration, not a way to enter a collection. Live capture is good enough to build on (new corpus: right card first 42/49, top 3 45/49, exact printing 34/44; spec 007 [research.md](../007-card-scanner-live-capture/research.md) §5), but three weaknesses reach the collector directly:

- In 3 of 49 cards, a misread collector number named a real printing of a different card. That printing outranked the right name match.
- Foil collector lines are faint. The exact printing was found for 4 of 10 foils.
- The photo picker, which is the fallback without HTTPS or a camera, is close to unusable on unguided photos (2/49 in the top 3).

The Phase 2 spike (spec 008, [research.md](../008-card-scanner-phase-2-spike/research.md)) showed that a small hand-written detector lifts the photo path's held-out top 3 from 10/47 to 32/47.

This feature turns the scanner into a tool for working through a stack of cards. The collector scans, confirms the printing and finish, adds the copy, and moves on to the next card. A list of the sitting's adds supports Undo. Underneath, the feature fixes the ranking and reading weaknesses spec 007 found and adds detection to the photo path.

> **Inputs.** The scope is the maintainer's ruling of 2026-10-03 (spec 008 research.md §14, "The maintainer's ruling"). The confirm-flow decisions come from spec 008's [prd.md](../008-card-scanner-phase-2-spike/prd.md), "Decisions carried to spec 009". They are fixed inputs, as are the scanner's accepted ADRs: [0001](../../adr/0001-browser-ocr-engine-and-asset-hosting.md) (OCR engine and hosting), [0002](../../adr/0002-camera-path-testing.md) (camera-path testing), [0003](../../adr/0003-card-name-index.md) (name index), [0004](../../adr/0004-card-recognition-in-the-browser.md) (recognition in the browser) and [0005](../../adr/0005-hand-written-card-detector-for-the-photo-path.md) (hand-written detector on the photo path). ADRs [0006](../../adr/0006-art-fingerprint-and-index.md) and [0007](../../adr/0007-art-search-in-the-browser.md) belong to the later art-matching spec and stay Proposed.
>
> **Supersedes in spec 007:**
> - AC-1.7 and FR-1's "reachable by URL only": the scanner is now linked (Story 8).
> - AC-3.2, under which a collector-line match is always the first candidate (Story 5).
> - AC-3.3, under which a collector line that matches no printing leaves the candidates to the name match: the one-digit cross-check can now mark the top name candidate's printing as matched by its collector line (AC-5.3).
> - AC-4.2's guide placement on every picked photo: detection runs first, and guide placement is the fallback (AC-7.1, AC-7.2).
> - FR-3's "only recognised text": the add, Undo and Other printings requests, with the reading key, are sent too (FR-5). Still no frame, strip or photo.
> - AC-3.10's "no way to add" (Story 1).
> - FR-1's "Must not create, change or read any tenant data": the scanner now adds lots and keeps a sitting.
> - FR-4's "Must not infer the finish": the foil marker becomes a hint (AC-6.5).
>
> Spec 007 keeps its text as history. This spec is the current rule for those points.

## Goals

- A signed-in collector can work through a stack of cards on their phone. For each card they scan, see the ranked candidates, and add one copy with one tap on the candidate's finish button. The scanner is then ready for the next card, without leaving the page or asking for the camera again.
- When the scanner guessed the printing from the name alone, the collector can pick the right printing in place.
- Every add in the current sitting is listed, with Undo and a link to the copy's details. The list survives leaving the scanner, signing out and switching devices, until the collector ends the sitting.
- When the name and the collector line point to different cards, a strong name match ranks first. A misread collector number is checked against the named card's printings. The rule is checked on the stored text of every earlier run.
- The reading refinements improve the weak cases spec 007 found: faint foil collector lines, light names on dark bars, long names, a noise line beating the name, and the detector's lost bottom edge and name-strip position.
- A photo picked from the library or the camera app is found, straightened and read, instead of being cut at the guide's fixed position.
- The scanner can be reached from the main navigation and from the collection page.
- The ranking is designed so a later art-matching result can join it as another kind of evidence.
- Findings report the flow on the maintainer's iPhone, on 35 cards the scanner has never seen. No pass threshold is set.

## Non-Goals

- Art matching, the artwork id in the catalog, the artwork fetch and the index. That is the next spec, opt-in per instance (ruling, 2026-10-03).
- Detection on live camera frames. Live capture stays as spec 007 built it, apart from the reading refinements.
- OpenCV.js or any other third-party image library.
- Setting a condition, price or quantity during the scan. Each tap adds one copy with condition and price unspecified (maintainer, 2026-10-03). Details are edited afterwards.
- Sitting-wide defaults (one condition or price for every card in a sitting).
- Logging scan attempts or what the camera read in normal use. The sitting records what was added, not what was read (spec 008 PRD).
- Locations, bins or a "Loose" bucket. Added copies go into the account's collection as lots, as the catalog's Add does.
- Non-English cards, flavour names, battle cards (sideways), and cards tilted more than about 6° in a picked photo.
- Automatic or continuous capture. Capture stays a tap.
- Setting a pass threshold for the findings.

## Users and Context

**Primary users:** Signed-in collectors entering a stack of cards, typically on a phone. The maintainer, who also runs the live sitting for the findings.
**Secondary users:** Self-hosters. Nothing new is needed to run this feature: no new dependency, no extra download, and HTTPS only for the live camera, as before. Claude Code sessions that write the art-matching spec from the findings.
**Usage context:** A collector at a table with a pile of new cards, holding each one under their phone in turn. Mostly a WebKit browser on iOS over HTTPS (the maintainer uses Brave). When the camera isn't available, they pick a photo instead, often one taken without any guide.
**User mental model:** "Point, tap, add, next." Then: "if it got one wrong, undo it or fix it from the list". And: "the pile I scanned is now in my collection".

**Terms used in this spec:**
- **Reading:** one capture (or one picked photo) and its result: the recognised text, what was parsed, and the ranked candidates. A new capture starts a new reading.
- **Reading key:** an opaque random value the page mints for each reading. It is not derived from the read text.
- **Candidate:** a printing offered for a reading, at most 3 per reading.
- **Printing:** one catalog entry (`Catalog::Entry`): a card in one set, number and language.
- **Sitting:** the account's run of scanner adds, open until "Done".
- **Sitting entry** (or "entry" in Stories 3 and 4): one add recorded in a sitting. It is never a catalog entry.
- **Strong name match:** see AC-5.1.

## User Stories

### Story 1: Add a candidate from the scanner

**As a** signed-in collector
**I want** to add the scanned card to my collection with one tap on the right finish
**So that** I can move through a stack quickly

**Acceptance criteria:**

- [ ] **AC-1.1** Given a reading with candidates When the page shows them Then each candidate shows one add button per finish its printing comes in. The buttons are labelled with the collectible's finish names, in its finish order (MTG: Nonfoil, Foil, Etched). A printing with one finish, or with no finish listed in the catalog, shows a single button labelled "Add". Each button's accessible name names the card, set · number and finish (for example "Add Tome Shredder STX 117 Foil").
- [ ] **AC-1.2** Given a candidate's add button When the collector activates it Then one copy of that printing is added to the account's collection with condition and price paid unspecified, merging into the lot with the same identity (spec 004 AC-7.4). The finish is recorded as tapped, including Nonfoil. A single "Add" on a one-finish printing records that finish, and only a printing with no finish listed leaves it unspecified. A scanner add therefore merges with lots of the same finish, not with the finish-unspecified lots the catalog's Add makes.
- [ ] **AC-1.3** Given an add succeeded When the page updates Then it stays on the scanner without a full page load. It announces "Added 1 × ‹name› (‹SET› · ‹number›, ‹finish›) to your collection." in the polite live region (spec 004 AC-7.2's wording with the finish added, or without it when unspecified), clears the reading and its candidates, and is ready to capture again. On live capture the camera stream that was running is still running, so no new permission prompt appears and the shutter is enabled. On the photo path the photo picker is ready.
- [ ] **AC-1.4** Given a candidate's add button was activated When the add is in flight Then every add button for that reading is disabled until the response arrives. Once the add has succeeded, that reading offers no add button again.
- [ ] **AC-1.5** Given each reading carries its reading key, and every add request sends it When the app receives a second add with a key the open sitting already has an entry for (a retry after a lost response, a duplicated request, or another add button of the same reading) Then nothing more is added, whatever printing or finish the second request names. The app answers with that sitting entry's current state: added (as if the first add had just succeeded), undone (AC-4.1), or changed in the collection (AC-3.6). The page shows that state and offers no add button for the reading. A key is unique within a sitting, and a sitting holds at most one entry per key. Ended sittings are discarded (FR-2), so a replay that arrives after Done adds to the new sitting.
- [ ] **AC-1.6** Given the lot the add would merge into already holds 9,999 copies When the collector activates an add button Then nothing is added, the reading stays on the page, and the page shows the lot-full message the catalog's Add uses ("You already have the most copies one lot can hold (9,999).").
- [ ] **AC-1.7** Given the collector wants a second copy of the same card When they scan it again and add it Then a second copy is added: the new reading has a new key, so each reading adds at most one copy (AC-1.5) and two readings add two.

### Story 2: Choose another printing

**As a** collector whose card was recognised by name but not by printing
**I want** to see the card's other printings and add the right one
**So that** the copy I add is the printing I own

**Acceptance criteria:**

- [ ] **AC-2.1** Given a candidate that was not matched by its collector line When it is shown Then it is marked as a guess at the printing (for example "Printing not confirmed") and offers "Other printings". A candidate matched by its collector line, directly or through the cross-check (AC-5.3), is marked as matched by its collector line and also offers "Other printings".
- [ ] **AC-2.2** Given "Other printings" on a candidate When the collector activates it Then the card's English printings that aren't retired open in place on the scanner page, without a full page load or leaving the scanner. Each printing shows its set name and code, collector number and release date, with its own add buttons per AC-1.1. The camera stream keeps running.
- [ ] **AC-2.3** Given the reading parsed a set code or a collector number When "Other printings" lists the card's printings Then printings matching what was read come first: the read set and number together, then the read set alone, then the read number alone. All remaining printings follow, newest release first. Ties within each group follow the catalog's newest-first order (release date, then set code, then collector number, then language).
- [ ] **AC-2.4** Given the reading parsed neither a set code nor a number When "Other printings" opens Then printings follow the catalog's newest-first order.
- [ ] **AC-2.5** Given a card with more than 20 printings When "Other printings" opens Then the first 20 in AC-2.3's order show, with a control that reveals the rest in place.
- [ ] **AC-2.6** Given "Other printings" is open When the collector adds one of them Then the add behaves as Story 1 (AC-1.2 to AC-1.6), and the sitting records the printing that was added.

### Story 3: The sitting's list

**As a** collector working through a stack
**I want** a list of what I've added in this sitting
**So that** I can check my work and correct mistakes later, even after leaving the scanner

**Acceptance criteria:**

- [ ] **AC-3.1** Given the account has no open sitting When the collector adds a card from the scanner Then a sitting is opened for the account and the add is its first entry. An account has at most one open sitting.
- [ ] **AC-3.2** Given an open sitting When the scanner page is shown Then it lists the sitting's adds, newest first. Each entry shows the card's name, set · number, finish (or "—" when unspecified) and the time it was added, together with Undo and a link to the copy's details. A heading gives the sitting's count ("This sitting: 12 cards"), which counts the entries not undone, including entries changed in the collection (AC-3.6), the same count as AC-3.5's summary. The 10 newest entries show, with a "Show all" control that reveals the rest in place (maintainer ruling).
- [ ] **AC-3.3** Given an open sitting with adds When the collector leaves the scanner, signs out and signs in again (on the same or another device), then opens the scanner Then the same sitting and its entries are shown, and further adds join it.
- [ ] **AC-3.4** Given an entry's details link When the collector follows it Then it opens the copy's existing Edit copy page (spec 004) for the lot the add went into. Saving or cancelling there returns to the scanner, with the sitting still open.
- [ ] **AC-3.5** Given an open sitting When the collector activates "Done" and confirms Then the sitting ends, its entries are discarded and no longer undoable, and the added copies stay in the collection. The response to Done shows a short summary in place of the list: "Added ‹n› cards in this sitting", with ‹n› the number of entries not undone ("Added 0 cards in this sitting" when every add was undone), and a link to the collection. The summary isn't stored, so a reload or another device shows neither list nor summary (AC-3.7). Either an in-place update in the response, or a message shown once after the redirect, satisfies this. The next add opens a new sitting.
- [ ] **AC-3.6** Given the lot an entry's add went into has since been removed, or merged into another lot by an edit When the sitting's list is shown Then that entry still shows its card, set · number and finish, is marked "Changed in your collection", and offers neither Undo nor a details link.
- [ ] **AC-3.7** Given no open sitting When the scanner is shown, other than in the response to Done (AC-3.5) Then no sitting list, summary or Done control is shown.
- [ ] **AC-3.8** Given two accounts When either account views its scanner Then it sees only its own sitting. A request naming another account's sitting entry (Undo or details) answers 404 and changes nothing.

### Story 4: Undo an add

**As a** collector who added the wrong card or finish
**I want** to undo one entry in the sitting
**So that** the mistaken copy leaves my collection

**Acceptance criteria:**

- [ ] **AC-4.1** Given an entry whose lot still exists When the collector activates its Undo Then one copy is removed from that lot (the lot is removed if that was its last copy), the entry leaves the list, and the page announces "Removed 1 × ‹name› (‹SET› · ‹number›, ‹finish›) from your collection." This happens without leaving the scanner or a full page load. An Undo that removes the lot ends the session's pending bulk-removal Undo, as any single-lot removal does (spec 006 AC-7.6).
- [ ] **AC-4.2** Given an entry has already been undone When an Undo request for it arrives again (a replay or a second tab) Then nothing changes and the app answers 422. The page shows that the entry was already undone.
- [ ] **AC-4.3** Given two entries in the sitting added copies to the same lot When both are undone Then two copies are removed in total, one per entry.
- [ ] **AC-4.4** Given an entry whose lot was edited since the add (condition, price paid, finish or quantity changed), but not removed or merged into another lot When its Undo is activated Then one copy is removed from that lot as in AC-4.1, and the lot is removed if that was its last copy. Undo refuses only when the lot was removed or merged away (AC-3.6). Then it answers 422, and the page says the copy changed in the collection.

### Story 5: Ranking when the name and the collector line disagree

**As a** collector
**I want** the right card ranked first even when the scanner misread a digit of the collector number
**So that** one tap adds the right card

**Acceptance criteria:**

- [ ] **AC-5.1** Given a reading whose collector line identifies exactly one printing, and whose name match is strong for a different card When candidates are ranked Then the name match's card ranks first and the collector-line printing ranks second. Each candidate shows what it was matched by: its collector line, its name, or both. "Strong" is one named rule over the top name candidate. The plan fixes its form, for example a similarity score at or above a threshold, possibly with an exact normalised-name shortcut. Its threshold is chosen on the AC-5.4 fixtures and committed with the settings (AC-6.7), and the findings state the rule and the threshold.
- [ ] **AC-5.2** Given a reading whose collector line identifies exactly one printing, and the name match is not strong for a different card When candidates are ranked Then the collector-line printing ranks first, as in spec 007.
- [ ] **AC-5.3** Given a strong name match whose card differs from the collector line's printing, or a collector line that parses but matches no printing When the top name candidate's card has exactly one English printing in the read set whose collector number is one edit from the read number Then that printing is the candidate for that card, marked as matched by its collector line ("Matched by its collector line, one digit corrected"). The new corpus's three cases resolve this way: `STX 17` → Tome Shredder STX 117, `AFR 202` → Grand Master of Flowers AFR 282, `FRA 5` → Cast Away Doubt FRA 51. The edit is over the number's digits only: one digit added, dropped or changed, ignoring leading zeros. Any letters or symbols in the number (such as `117a`) must match exactly. The cross-check runs only for the top name candidate. It doesn't run in AC-5.2's case (collector-line printing first), where the name candidate shows its printing as spec 007 did.
- [ ] **AC-5.4** Given the stored text of every earlier run (Phase 0 `ocr_results.json`, the Phase 1 photo replay, tuning round 4, the new corpus live and photo runs, all in `spec/fixtures/card_scanner/`) When it is re-scored with this feature's query cleaning (AC-6.1) and ranking together, with the expected card of each reading taken from committed ground truth Then:
  - IMG_6765, IMG_6769 and IMG_6792 in the new corpus's live run (`phase1_live_ocr_results.json`) have the right card first. Their photo-run rows are misframed, so no ranking can recover them.
  - No reading whose right card was first under spec 007's ranking loses that place.
  - The findings list every reading whose first candidate changed, with both rankings.
  - The findings state that "strong" was chosen on these same readings, so its result on them is biased upwards. The live sitting (Story 9) is the unbiased check.
  - Before the re-score, ground truth for tuning round 4 (`~/card-scanner-corpus/tuning/`) and for the new corpus (`~/card-scanner-corpus/phase1-live/`) is committed as text next to `ground_truth.json`, in its format, keyed by manifest `file`. No image is committed.
- [ ] **AC-5.5** Given the ranking When a candidate's support is recorded Then it is expressed as one or more named kinds of evidence (collector line, collector line corrected, name), and the order between candidates follows a single rule over those kinds. Adding a kind of evidence later (an art match) needs a new kind and a change to that one rule. The plan names the rule and where it lives.

### Story 6: Reading refinements

**As a** collector
**I want** the scanner to read hard cards better
**So that** foils, dark name bars and long names are recognised as often as ordinary cards

**Acceptance criteria:**

- [ ] **AC-6.1** Given IMG_6720's recorded `name_text` from the Phase 1 photo replay, in which a long noise line outranks the real name under spec 007's query cleaning When it is matched with this feature's cleaning Then the right card is among the top 3 name candidates. Every stored reading whose right card was in the top 3 name candidates under spec 007 stays there (checked on the AC-5.4 fixtures).
- [ ] **AC-6.2** Given the faint-foil-line refinement When the stored strips of the new corpus's live run (10 foils) are replayed on the desktop with it Then the findings report the exact-printing rate for foils and non-foils against spec 007's 4/10 and 30/34. A refinement that lowers the non-foil rate is not shipped without the maintainer's ruling.
- [ ] **AC-6.3** Given the light-name-on-dark-bar refinement When IMG_6785's stored name strip is replayed Then the findings report whether its name is now read. The name rates of the AC-6.2 replay are reported against spec 007's.
- [ ] **AC-6.4** Given the long-name refinement (the name strip no longer cuts off names that run past its right edge, as IMG_6761's did) When the stored photos are replayed (Phase 0's and the new corpus's) Then the findings report how many names the strip now holds in full that it cut before, and the name rates against spec 007's photo replays.
- [ ] **AC-6.5** Given a collector line whose separator between set code and language reads as the foil marker (the star printed on foil cards from M15 on) When candidates are shown Then the Foil add button of a printing that comes in foil is marked as read from the card ("Foil · read from the card"). The marker does not reorder the add buttons or add anything by itself. Given the separator reads as the non-foil dot, or isn't read, Then no finish is marked. Which recognised characters count as the star is fixed from the stored text and listed in one place. On the stored new-corpus live text, the findings report how many foils and non-foils were marked.
- [ ] **AC-6.6** Given the detector's outline stops above the bottom edge of a card that fills the frame, or the name strip sits below a detected card's name bar (ADR 0005, Consequences) When the refinements for these are tuned on the spike's 52 development photos and then run on its 47 held-out photos Then the findings report both halves against the spike's frozen result (held out: top 3 32/47, right card first 27/47, exact printing 13/43). Development rates are labelled as biased.
- [ ] **AC-6.7** Given the reading, matching and detector settings this feature ships When they are tuned Then tuning uses only the stored runs and the spike's development photos, never cards from the live sitting (Story 9). The settings are committed before the live sitting starts, and the findings name the commit.

### Story 7: Detection on the photo path

**As a** collector without a live camera (no HTTPS, permission denied, no camera)
**I want** a photo of a card, framed any reasonable way, to be read as well as possible
**So that** the fallback is useful

**Acceptance criteria:**

- [ ] **AC-7.1** Given a picked photo When it is processed Then its orientation metadata is applied and the card is detected on the device. When a card outline is found, the card is straightened and placed in the guide's position, and the shipped strips, recognition, parsing and matching run on that image (spec 007 Stories 2 and 3, with this feature's refinements). Nothing but recognised text leaves the device.
- [ ] **AC-7.2** Given a picked photo in which no card outline is found When it is processed Then the guide is placed on the photo as in spec 007 AC-4.2 and reading continues. The page says no card edge was found and shows the framing advice (AC-7.4).
- [ ] **AC-7.3** Given the shipped detector at the spike's frozen settings (`spikes/card_scanner/phase2/settings.json` at `39cdc6e`), before AC-6.6's refinements When it runs on the spike's 99 photos Then each photo's outcome (found or not, and the outline's corners within one pixel at work resolution) matches the spike detector's. The reference is the spike detector re-run at `39cdc6e` on the same photos, since the committed spike results record no corners. The comparison is a recorded check in the findings, not a suite test.
- [ ] **AC-7.4** Given the photo picker is offered (spec 007 AC-4.1, AC-4.3) When it is shown Then copy tells the collector to photograph the whole card, upright, filling most of the photo as the live guide does, on a plain background.
- [ ] **AC-7.5** Given the detector is added When the scanner page is served Then its Content Security Policy is unchanged from spec 007 AC-2.4, and the page loads no third-party library for detection.
- [ ] **AC-7.6** Given live capture When the shutter is used Then no detection runs on the frame. Live capture cuts its strips at the guide as in spec 007 AC-1.3.

### Story 8: Reaching the scanner

**As a** signed-in collector
**I want** to find the scanner from the app's navigation
**So that** I don't need to know its address

**Acceptance criteria:**

- [ ] **AC-8.1** Given a signed-in page that shows the main navigation When it renders Then the navigation has a "Scan" link to the scanner, in both the wide-screen app bar and the phone tab bar, marked as the current page on the scanner.
- [ ] **AC-8.2** Given the collection page When it renders Then its page head offers a "Scan cards" action linking to the scanner.
- [ ] **AC-8.3** Given a visitor who is not signed in When they follow a link to the scanner Then they get the app's usual sign-in redirect, as in spec 007 AC-1.2.
- [ ] **AC-8.4** Given the scanner page When it renders Then the line saying adding from the scanner is coming (spec 007 AC-3.10) is gone.

### Story 9: Findings from a live sitting

**As the** maintainer
**I want** the whole flow measured on cards the scanner has never seen, on my iPhone
**So that** I know how often a scan ends as the right printing and finish, and how long a card takes

**Acceptance criteria:**

- [ ] **AC-9.1** Given a pile of 35 English cards the maintainer owns and has prepared, including any foils among them (the findings report how many), none of them among Phase 0's cards, the tuning cards or the new corpus of spec 007, listed in a manifest of spec 007's format (`file,set,number,foil[,era]`) with each card's finish, and ground truth built from it against the catalog When the maintainer scans each card once through the live flow on the iPhone, at the frozen settings (AC-6.7), and adds it Then the findings report:
  - how many cards ended in the sitting as the right printing and the right finish
  - how many needed a correction, by kind: a candidate other than the first, Other printings, Undo and re-add, or details edited
  - how many couldn't be added from the scanner at all
  - the time per card (median and slowest)
  - each count with its sample size, for foils and non-foils separately
- [ ] **AC-9.2** Given measurement mode is on (development only, spec 007 FR-6) When a card is scanned in the live sitting Then it is attributed to the next manifest row chosen before capture. The app records, outside the repository, the reading's text, the rank of the candidate added (or "Other printings"), any Undo, and the time from the previous add. The rank is sent only when measurement mode is on. Nothing about scans is sent or recorded beyond FR-5's list when it is off.
- [ ] **AC-9.3** Given the same pile When at least 10 of its cards are also photographed without a guide and picked through the photo path on the iPhone Then the findings report, for those photos, the outline found or not, the right card first and in the top 3, and the on-device detection and straightening time (median and slowest).
- [ ] **AC-9.4** Given the live sitting's stored text When it is committed Then it is a text fixture in spec 007's fixture format, under a higher `format_version`, keyed by manifest `file`. No image is committed.
- [ ] **AC-9.5** Given the findings are complete When they are written Then they report every card that didn't end as the right printing and finish, with its read text and likely cause. They set no pass threshold, and end with recommendations for the art-matching spec, including where art evidence would have changed an outcome. ADR 0005 is updated with the phone timing and accuracy (its Consequences require it).

## Functional Requirements

### FR-1: Adding from the scanner

**Must:**
- Add exactly one copy per reading (AC-1.5), identified by its reading key, through the same rules as the catalog's Add: merging into the lot with the same identity and respecting the 9,999 cap (spec 004).
- Refuse an add for a printing that isn't in the catalog or is retired.
- Link the scanner from the main navigation and the collection page (Story 8), replacing spec 007 FR-1's "reachable by URL only".
- Offer only the finishes the printing comes in, named and ordered by the collectible's finish vocabulary. The core stays collectible-agnostic, and MTG finish names and the foil marker live in the MTG extension.
- Keep the collector on the scanner: adds, Undo and Other printings update the page in place, and the camera keeps running.

**Must not:**
- Set condition, price paid or quantity other than 1 when adding.
- Add anything without a tap on an add button (no automatic add, not even from the foil marker).

### FR-2: The sitting

**Must:**
- Be stored by the app as tenant-owned data (`account_id`), with at most one open sitting per account. It persists across sign-out and devices until "Done".
- Record, per entry, the printing, the finish, the time, the lot the copy went into, and the reading key (an opaque value, not what the camera read).
- Discard an ended sitting's entries. They are workflow state, not collection data, and are not part of the collection export.
- Scope every sitting read and write through the current account (multi-tenancy rules), with a request spec proving another account's entry answers 404.

**Must not:**
- Record what the camera read, candidates that weren't added, or any image (outside development measurement mode, FR-5).

### FR-3: Ranking and matching

**Must:**
- Rank by named kinds of evidence under one rule (AC-5.5). Kinds today: collector line, collector line corrected, name.
- Rank a strong name match above a disagreeing collector-line printing (AC-5.1), and correct a one-edit collector number against the named card's printings in the read set (AC-5.3).
- Keep showing at most 3 candidates, with Other printings for more.
- Apply the reading refinements of Story 6 (query cleaning, faint foil lines, light names on dark bars, long names, the foil marker as a hint, and the detector's bottom edge and name-strip position) at settings committed before the live sitting (AC-6.7).
- Keep the collector-line parser, set-code rules, foil marker and number correction inside the MTG extension. Name matching stays collectible-agnostic core (spec 007 FR-4).

**Must not:**
- Call any external service while matching.

### FR-4: Photo-path detection

**Must:**
- Run on the device, first-party, under the scanner's existing Content Security Policy (ADR 0004, ADR 0005).
- Fall back to the guide placement when no outline is found (AC-7.2).

**Must not:**
- Run on live frames (AC-7.6).
- Send any photo, straightened image or outline to the app.

### FR-5: Privacy and measurement

**Must:**
- Keep spec 007 FR-3, extended: in normal use the app receives only recognised text, plus the add, Undo and Other printings requests (printing ids, finishes and the reading key).
- Keep measurement mode development-only and off by default in production and test (spec 007 FR-6), with its stored files outside the repository and `storage/`.

### FR-6: Design system

**Must:**
- Use the Collector design system's tokens and `c-*` components. Any new pattern (add-per-finish buttons, the sitting list, Other printings in place) is added in `collector/additions.css` with its doc under `docs/design-system/components/`, and `Scanner.md` is updated.

## Non-Functional Requirements

### Performance

- An add, from tap to the "Added" announcement, takes a median of no more than 500 ms on the development machine against a seeded catalog. The findings report it on the iPhone.
- Other printings for a card with 100 printings answers in under 300 ms at the 95th percentile on the development machine.
- These targets are measured by a non-gating script and reported in the findings. Suite tests assert the behaviour, not the time.
- Detection and straightening add no more than 1 s per picked photo on the iPhone (median). The findings report the measured figure; if it is higher, that is reported, not hidden.
- The scanner's cold-load download grows by no more than 20 KB compressed over spec 007's, the findings report the figure, and nothing new is fetched from another host.

### Security

- Every add, Undo, details link and Other printings request is authenticated, CSRF-protected, and scoped to `Current.account`. Printing ids and finishes are validated against the catalog and the printing's finishes. Reading keys are validated against a fixed shape (length and characters) that the plan sets.
- The scanner's Content Security Policy is unchanged (AC-7.5). Other pages are unaffected.
- No `account_id` or lot id is taken from parameters except to look a record up within the current account.

### Reliability

- Adds and Undo are safe to retry (AC-1.5, AC-4.2), and concurrent adds into one lot merge rather than fail (spec 004 AC-12.5).
- The new tables come from reversible migrations that are safe for unattended `db:prepare` from any prior version, with an index on every foreign key and on `account_id`.
- The camera page tests (ADR 0002), including adding from a candidate, pass 10 times in a row locally.

### Accessibility

- Adds, Undo, Other printings opening, errors and "no card edge found" are announced in the polite live region.
- Add buttons, Undo and Done are at least 44×44 points. The sitting list and Other printings never push the shutter out of the bottom third of a phone-sized viewport, and never cause sideways scrolling at 360 px.
- Marks such as "Printing not confirmed", "Matched by its collector line" and "Foil · read from the card" use words, not colour alone.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The add request fails (network error or server error) | Show an error on the reading, keep the candidates, and offer a retry. A retry never adds a second copy (AC-1.5) |
| The session expired while scanning | The add, Undo or Other printings request gets the sign-in response. The page says to sign in again, and the open sitting is still there after signing in (AC-3.3) |
| The lot is full (9,999) | Nothing added; show the catalog's lot-full message; the reading stays (AC-1.6) |
| The printing named by the request isn't in the catalog | Answer 422; the page says the card couldn't be added and to scan again; nothing is added |
| The finish named isn't one the printing comes in | Answer 422; nothing is added |
| Undo on an entry already undone | 422, nothing changes, the page says it was already undone (AC-4.2) |
| Undo or details for another account's entry | 404, nothing changes (AC-3.8) |
| Add request with no reading key, or one outside its fixed shape | Answer 422; nothing is added |
| Undo or details for an entry of a sitting that has ended (for example from a second tab after Done) | 404, nothing changes |
| The printing was retired by a catalog refresh between the reading and the add | Answer 422; the page says the card couldn't be added and to scan again; nothing is added |
| Done when every add in the sitting was undone | The sitting ends and the summary reads "Added 0 cards in this sitting" (AC-3.5) |
| An entry's lot was removed or merged away | The entry shows "Changed in your collection", with no Undo or details (AC-3.6) |
| "Done" activated by mistake | A confirmation step precedes ending the sitting (AC-3.5) |
| No card outline in a picked photo | Fall back to guide placement, say no edge was found, show the framing advice (AC-7.2) |
| Battle card or steep tilt in a picked photo | As above, or a wrong reading. The collector uses Other printings or the catalog search |
| Other printings fails to load | Show an error in place with a retry; the candidates stay usable |
| The catalog is refreshed during a sitting | Existing entries and lots are unaffected; new readings use the refreshed catalog |

## Open Questions

None.

Decided while specifying (2026-10-03, maintainer):

- Scope: confirm flow and the hand-written detector on the photo path only. Art matching is its own spec after this one, opt-in per instance (spec 008 research.md §14).
- Condition and price paid stay unspecified when adding. The copy merges into the matching lot.
- A sitting lasts until "Done", across sign-out and devices. Opening the scanner resumes it.
- The scanner is linked from the main navigation and the collection page.
- The live sitting uses 35 unseen cards the maintainer has prepared (first estimated at about 50).
- Undo after the entry's lot was edited still removes one copy from that lot. It refuses only when the lot was removed or merged away (AC-4.4, AC-3.6).
- "Done" shows a short summary with a link to the collection (AC-3.5).
- After the second spec review: the sitting list shows the 10 newest entries, with "Show all" (AC-3.2).
- After the spec review: the finish is recorded as tapped, including Nonfoil (AC-1.2); a scanner Undo that removes a lot ends the pending bulk-removal Undo (AC-4.1); messages use spec 004's wording plus the finish (AC-1.3, AC-4.1); a printing retired since the reading is refused (Error Scenarios).
- The performance targets in the Non-Functional Requirements, 20 printings at a time in Other printings, ended sittings discarded and left out of the export, and one copy per reading were proposed while specifying and accepted.
- Carried from spec 008's PRD and not re-asked: the stack-sitting flow, one add button per finish, Other printings in place with read set and number first, a stored list with Undo and details, the strong-name ranking rule, the photo picker kept as the fallback, and the reading refinements.

## Out of Scope (Future Considerations)

- Art matching: the catalog artwork id, the opt-in artwork fetch and index build, the phone download and search measurement, and art evidence in the ranking (next spec, ADRs 0006 and 0007).
- Detection or alignment feedback on live frames.
- Sitting-wide defaults for condition, price or language; quantity on the scanner.
- Scan-attempt logging as a feedback dataset.
- Locations or a "Loose" bucket for newly scanned cards.
- Non-English cards, flavour names, battle cards, continuous capture, native apps.
