# Feature 007: Card Scanner Phase 1 — Live Capture and Re-measure

**Status:** Approved
**Version:** 2.0.0
**Created:** 2026-09-30
**Last Updated:** 2026-10-01
**Branch:** `007-card-scanner-live-capture`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-09-30 | Initial approved spec |
| 1.1.0 | 2026-09-30 | Spec review revisions (Fable). **Comparable rates:** top 1 / top 3 are reported both over name candidates alone (Phase 0's definition, research.md §5) and over the page's final ranking (AC-6.2, AC-6.3). **Parser cases** are the verbatim multi-line `collector_text` of named Phase 0 fixture rows, with the known set codes listed exactly (AC-3.6); the loose fallback uses a fixed exclusion list and the `SET • LANG` shape wins (AC-3.7). **Measurement mode** is behind a setting (on in development, off in production and test by default, switchable in tests) so it can be tested (AC-5.1, FR-6, NFR Security). **Headless-verifiable camera ACs:** track state, the requested facing mode, torch capability and secure-context detection replace device-only observations, with device checks recorded as manual steps (AC-1.1, AC-1.4–1.6, AC-6.5). **Query cleaning order** fixed, with IMG_6730 as a case; "similar length" is ±1 character (AC-3.4, AC-3.5). **Language:** a lookup with no language read assumes English (AC-3.2, FR-4; maintainer ruling). **Name index** is collectible-agnostic catalog data keyed by collectible type, fed by each collectible's source (FR-4, FR-5; maintainer ruling), and is also rebuilt when a refresh is skipped while the index is empty (AC-3.9, FR-5). **CSP:** the app sends no policy today, so other pages still send none; the scanner's policy allows a per-request nonce for its own inline tags (AC-2.3, AC-2.4). **Also:** conditional-request wording (AC-2.2), new error rows (request failure, expired session, engine can't start), fixture keys and `format_version` (AC-5.2, AC-6.6), ground truth from `ground_truth.json` (AC-6.2), a separate tuning manifest (AC-6.1), a capture protocol (AC-5.4), lookup time in the findings (AC-6.5), dev HTTPS wording (AC-7.1), checksum verification (AC-7.3), control placement instead of "one-handed" (NFR Accessibility) |
| 1.1.1 | 2026-09-30 | From the spec re-review (Fable, READY TO PLAN): "mostly-alphabetic" is defined as at least half the non-space characters being letters (AC-3.4); the engine files are present in a development checkout after `bin/setup`, so the checksum test can run (AC-7.3). Clarifications only |
| 2.0.0 | 2026-10-01 | **The measured run is a photo replay** (maintainer ruling): the 50 corpus cards were borrowed and returned, so they couldn't be re-captured live. The 50 Phase 0 photos are replayed on the desktop through the shipped photo-picker path instead (AC-6.2–AC-6.6, Goals, Problem Statement, Users and Context, Story 6). The tuning rounds' live captures on the iPhone are reported as the only live-alignment evidence, labelled as biased because the settings were tuned on those cards (new AC-6.8). AC-6.5's on-device recognition times come from the tuning rounds, and its download sizes from a load test on the iPhone. Story 5's evidence (retakes, skips, desktop replay) comes from the tuning runs. Nothing else changes; no FR changes |

---

## Problem Statement

Collectors want to add a card by pointing a phone at it instead of searching by name. Phase 0 (spec 005, [research.md](../005-card-scanner-phase-0/research.md)) showed that the parts work: the self-hosted OCR engine is fast on the maintainer's iPhone (median 626 ms per photo, n=11), the trigram name index works within `schema.rb`, and a camera page can be tested headlessly. Accuracy is the problem. On hand-held photos cut at fixed positions, the right card was in the top 3 candidates for 26 of 50 photos, and the collector line identified the exact printing for 7 of 45. 19 of the 24 misses come from the fixed guide: the card drifted by about ±4% of the image, so the strips had to be tall, and they either clipped the name or filled up with art.

The roadmap's real premise, that the user lines the card up with a guide they can see before the shutter, was never tested, because Phase 0 had no live camera. Phase 1 builds that live capture in the app, fixes the parser and matcher gaps Phase 0 found, and measures again. The 50 Phase 0 cards were borrowed and had to be returned, so they couldn't be re-captured live. The measured run replays their 50 photos through the shipped photo path instead. Live alignment is measured only on the tuning cards, whose captures informed the settings. Only then does the maintainer decide whether to build the scan → confirm → add-to-collection flow (research.md §8, "a measurement gate between the capture step and the scan → confirm flow").

> **Inputs.** The scope follows research.md §8 (recommended Phase 1 scope) and §9 (roadmap assumptions it contradicted), not the original roadmap (`~/Downloads/card-scanner-research-and-roadmap.md`). The techniques chosen in Phase 0's Proposed ADRs are fixed inputs, the way the stack is: the OCR engine and its self-hosting ([ADR 0001](../../adr/0001-browser-ocr-engine-and-asset-hosting.md)), camera-path testing ([ADR 0002](../../adr/0002-camera-path-testing.md)) and the name index ([ADR 0003](../../adr/0003-card-name-index.md)). Phase 1's plan accepts or revises each ADR; it does not reopen the choice without new evidence.

## Goals

- A signed-in collector can open a scanner page on their phone, see the live camera feed with a card-shaped guide over it, line up a card, capture it, and see what was read and the ranked candidate printings, all without any photo leaving their device.
- The 50 Phase 0 photos are replayed through the shipped photo-picker path (guide placement, strips, OCR, parsing and matching) and scored with Phase 0's rate definitions, so the maintainer can compare the two directly. The tuning rounds' live captures are reported alongside them as the only live-alignment evidence, labelled as biased. Together they inform the decision on whether the scan → confirm flow (a future spec) is built.
- The findings separate the gain from live alignment from the gain from parser and matcher fixes, by re-scoring Phase 0's recorded OCR text with Phase 1's matcher.
- Captured strips from the tuning runs and the photo replay are kept on the maintainer's machine, so later tuning can replay them without capturing again.
- Phase 0's Proposed ADRs are accepted or revised, and the scanner's HTTPS requirement is documented for development and for self-hosters.

## Non-Goals

- Adding a scanned card to the collection: no lots, no confirm step, no quantities. That is the next spec, written only if the maintainer rules the re-measure good enough.
- A navigation entry or any link to the scanner page. It's reachable by URL only until the confirm flow ships.
- Storing scan records (scan sessions, scan attempts, corrections) or any image in normal use.
- Card detection, perspective correction (rectification) and art hashing. Detection stays the fallback if live alignment isn't enough (research.md §8, Out).
- Reading foil, etched or any other finish from the image. The finish is a confirm-step choice for the next spec.
- Japanese and other non-English cards, flavour-name matching (needs a catalog field the catalog doesn't have), bulk or continuous scanning, and native apps.
- Setting a pass threshold for the re-measure. The findings report the numbers and the maintainer decides.
- Deleting or rewriting the Phase 0 spike code under `spikes/card_scanner/`.

## Users and Context

**Primary users:** The maintainer, who captures the tuning cards live, runs the on-device checks and makes the go/no-go call on the confirm flow. Signed-in collectors on the maintainer's instance can also use the page by URL.
**Secondary users:** Self-hosters, who need HTTPS for the scanner to use the camera and who serve the OCR engine files themselves. Claude Code sessions that write the next spec from the findings.
**Usage context:** A collector at a table, holding a card under their phone. On the iPhone that means a WebKit browser (the maintainer uses Brave, which is WebKit on iOS), reaching the app over HTTPS. In development, the app runs on the maintainer's machine and the phone reaches it over the local network.
**User mental model:** "Point my phone at the card, line it up with the box, tap, and it tells me which card it is." For the maintainer: "Show me whether lining the card up live, and the new matcher, fixed the accuracy problem."

## User Stories

### Story 1: Live camera capture with a card guide

**As a** signed-in collector
**I want** to see my phone's camera feed with a card-shaped guide over it and capture when the card fits the guide
**So that** the card is lined up before the picture is taken, rather than guessed afterwards

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in user on a device with a camera, in a secure context (HTTPS or localhost) When they open the scanner page and grant camera permission Then the page requests a video-only stream that prefers the rear-facing (environment) camera, shows the live feed with a guide of card proportions (63:88) drawn over it, and shows a shutter control. (Headless tests assert the requested constraints through ADR 0002's substitution; that the iPhone actually opens its rear camera is a manual check recorded in the findings, AC-6.5.)
- [ ] **AC-1.2** Given a visitor who is not signed in When they request the scanner page Then they get the app's usual sign-in redirect and no camera is requested.
- [ ] **AC-1.3** Given the live feed is showing When the user activates the shutter Then the page captures one frame from the feed at the camera's full delivered resolution and cuts the name-bar strip and the collector-line strip from it, at fixed positions relative to the guide as drawn over that frame.
- [ ] **AC-1.4** Given the camera is running When the user leaves the page (link, back, closing the tab, or a Turbo visit) Then every camera track the page obtained has ended (`readyState` `ended`) and the video element no longer holds the stream; returning to the page requests the camera again and shows a live feed, not a cached picture of the old one. (That the iPhone's camera-in-use indicator goes off is a manual check recorded in the findings, AC-6.5.)
- [ ] **AC-1.5** Given the active video track's capabilities report a torch When the page shows the live feed Then a labelled torch toggle is shown, and toggling it applies the torch setting on and off to that track; Given the capabilities report no torch Then no torch control is shown. (Whether the iPhone's light actually turns on is a manual check recorded in the findings, AC-6.5.)
- [ ] **AC-1.6** Given the page runs in an insecure context (the browser reports it is not a secure context, as when opened over plain HTTP from another device) When it loads Then it does not request the camera, explains that the live camera needs HTTPS, and offers the photo-picker fallback (Story 4). (Tests simulate the insecure context through a page seam, since localhost is always secure; the real plain-HTTP case on the iPhone is a manual check recorded in the findings, AC-6.5.)
- [ ] **AC-1.7** Given any page of the app other than the scanner When it is rendered for a signed-in user Then it contains no link to the scanner page.

### Story 2: On-device text recognition of tight strips

**As a** collector
**I want** the card's name bar and collector line read on my phone
**So that** the photo of my card never leaves my device

**Acceptance criteria:**

- [ ] **AC-2.1** Given a captured frame (Story 1) or a picked photo (Story 4) When recognition runs Then the name-bar strip and collector-line strip are read on the device by the OCR engine named in ADR 0001, at its pinned versions, and only the recognised text is sent to the app.
- [ ] **AC-2.2** Given a browser with no cached engine files When the scanner page loads Then every engine file (library, worker, core build and language data) comes from the app's own origin under a path that carries the engine version, with a response that marks it cacheable as immutable for at least a year; Given a conditional request for one of those files (either `If-Modified-Since` or `If-None-Match`) Then the app answers `304 Not Modified` without a body.
- [ ] **AC-2.3** Given any page of the app other than the scanner page When it loads Then it does not load the OCR engine, and it sends no Content-Security-Policy header, as today (the app has no policy yet).
- [ ] **AC-2.4** Given the scanner page When it is served Then its Content Security Policy allows scripts, workers and connections only from the app's own origin, plus `blob:` for the engine's worker, `'wasm-unsafe-eval'` to compile the engine, and a per-request nonce for the page's own inline tags (such as the import map); it allows no other host for scripts, workers, connections or frames.
- [ ] **AC-2.5** Given the scanner page has loaded When the engine is still loading Then the shutter shows a busy state and can't start a recognition; When the engine is ready Then the shutter is enabled.
- [ ] **AC-2.6** Given recognition is running When the user activates the shutter again Then a second recognition does not start until the first finishes.

### Story 3: What was read, and the candidate printings

**As a** collector
**I want** to see what the scanner read and which printings it thinks the card is
**So that** I can judge whether it recognised my card

**Acceptance criteria:**

- [ ] **AC-3.1** Given recognition has finished When the text reaches the app Then the page shows the name-strip text, the collector-strip text, the parsed set code, collector number and language (each, or "not found"), and a ranked list of at most 3 candidate printings, each with its card name, set name and code, and collector number.
- [ ] **AC-3.2** Given the parsed set, collector number and language identify exactly one printing in the catalog When candidates are ranked Then that printing is the first candidate, and it is marked as matched by its collector line. When no language was read, the lookup uses English.
- [ ] **AC-3.3** Given the collector line parses but its set and number match no printing, or several When candidates are ranked Then the page states "no printing" or "several printings" for the collector line, and the candidates come from the name match.
- [ ] **AC-3.4** Given name candidates are needed When the name-strip text is matched Then candidates come from the catalog name index per ADR 0003: the query is cleaned first (tokens shorter than 3 characters are dropped from every line, then the longest remaining mostly-alphabetic line, one in which at least half the non-space characters are letters, is the query), names are normalised identically to queries, and each card appears at most once. IMG_6730's recorded `name_text` in `spec/fixtures/card_scanner/ocr_results.json` (`"A) ae ea i Rd TE NC DORA AA Sa pr\nCosmic Hunger"`) yields Cosmic Hunger among the top 3 candidates.
- [ ] **AC-3.5** Given the name-strip text normalises to nothing When matching runs Then the raw text is matched exactly against card names; Given a cleaned query of 5 characters or fewer (Phase 0's failures were `Ox`, `Fixe`, `Ixe`, `St0mp`) Then names whose normalised length differs by at most 1 character and whose edit distance is at most 1 are candidates.
- [ ] **AC-3.6** Given the known set codes are exactly `neo dmu mom pmom cmm nec fin one sta` (so `xyz` and `ffv` are unknown) When each input below is parsed Then it yields the expected result. Inputs named by file are that row's verbatim `collector_text` in `spec/fixtures/card_scanner/ocr_results.json` (Phase 0, run-a), multi-line as recorded:

  | Input | Problem in Phase 0 | Expected |
  |---|---|---|
  | IMG_6723: `"\| F \\ ; 3 4\n© Gg\nM0149\nMOM + EN dw DARREN TAN"` | rarity letter glued to the number | set `MOM`, number `149` |
  | IMG_6732: `"M0697\nCMM*EN > Scori b"` | rarity letter glued to the number | set `CMM`, number `697` |
  | IMG_6711: `"Vig 204\n—Shigeki, Jukar v1\n120 Ke\nNEC » EN do SAM BURLEY\n— eww"` | slash lost; a rules-text number (`204`) comes first | set `NEC`, number `120` |
  | IMG_6714: `"Equip 3\n“I must say, I quite en\n\\\n0258 FFV\nFIN oo EN Wo ELIZABETH PEIRO"` | no rarity letter; an unknown code (`FFV`) next to the number | set `FIN`, number `258` |
  | IMG_6728: `"“One brother fou\nMultiverse. The o\n—The Elderspe"` | flavour-text "One" read as set `ONE` | set not found |
  | IMG_6736: `"~: Add ¢.\nI, ©: Add one"` | rules-text "one" read as set `ONE` | set not found |
  | `"R 0123\nONE • EN"` | (new) the real ONE set in the `SET • LANG` shape | set `ONE`, number `123`, language `en` |
  | every input in research.md §3 "Collector-line parser inputs" | none (they pass today) | the result listed there |

- [ ] **AC-3.7** Given a set code that appears only outside the `SET • LANG` shape When the parser falls back to a loose set-code match Then it accepts the code only if it is a known catalog set code and is not on a fixed exclusion list of set codes that are also English words, held in one place, including at least `one`; Given the same code in the `SET • LANG` shape Then the exclusion list does not apply (AC-3.6's `ONE • EN` case).
- [ ] **AC-3.8** Given the catalog has never been refreshed, or its name index is empty When a recognition result arrives Then the page says the card catalog isn't ready yet, instead of showing an empty candidate list.
- [ ] **AC-3.9** Given a catalog refresh run that finishes `applied`, or that is skipped because its source version is already applied while the name index is empty When it completes Then the name index is rebuilt in full from the catalog as part of the same background work, and a card name added by an applied refresh is found by a name query.
- [ ] **AC-3.10** Given the page shows candidates When the user looks for a way to add a candidate to their collection Then there is none; a line tells them that adding from the scanner is coming, and links to the catalog search, where they can add the card today.

### Story 4: Photo-picker fallback

**As a** collector whose browser can't show a live camera (plain HTTP, permission denied, no camera)
**I want** to pick or take a photo of a card instead
**So that** I can still use the scanner

**Acceptance criteria:**

- [ ] **AC-4.1** Given the live camera is unavailable (insecure context, permission denied, no camera found, or the camera failed to start) When the page shows why Then it offers a photo picker that accepts images and, on phones, can open the camera app.
- [ ] **AC-4.2** Given a picked photo When it is processed Then the photo's orientation metadata is applied, the guide is placed on the photo as it is on a live frame, and the same strips, recognition, parsing and matching run (Stories 2 and 3).
- [ ] **AC-4.3** Given the live camera is available When the user prefers a photo Then the photo picker is also reachable from the live view.

### Story 5: Measurement mode for the re-measure

**As the** maintainer
**I want** each live capture of a corpus card recorded against its known identity, with the strips kept on my machine
**So that** I can score each run exactly, and replay it later without capturing again

**Acceptance criteria:**

- [ ] **AC-5.1** Given the measurement-mode setting is off (its default in production and test) When the measurement mode is requested in any way Then it is not available: every measurement route and upload endpoint answers 404, and the scanner page shows no measurement controls; Given the setting is on (its default in development; tests switch it on) Then measurement mode is available as Story 5 describes.
- [ ] **AC-5.2** Given measurement mode is on and a corpus manifest is configured (the Phase 0 format, `file,set,number,foil[,era]`, default `~/card-scanner-corpus/manifest.csv`) When the maintainer opens the scanner in measurement mode Then, before each capture, the page shows the next manifest row (its `file` value, which identifies the row everywhere including the fixtures, and the expected card), and every capture is attributed to that row, never to anything derived from the OCR. A tuning run (AC-6.1) uses its own manifest and its own output directory, separate from the measured run's.
- [ ] **AC-5.3** Given a capture in measurement mode When recognition finishes Then the app stores, for that row: the name-strip and collector-strip text, both strip images, the recognition time, the device's user agent and the capture time, in a directory outside the repository (default under the corpus directory); nothing is stored inside the repository or `storage/`.
- [ ] **AC-5.4** Given a row already has a capture When the maintainer captures that row again Then the first capture stays the measured one; later captures are stored as retakes and are excluded from the rates, and the findings report how many retakes were taken. The findings state the capture protocol: one deliberate shot per row, with an accidental shutter press counting as the measured capture.
- [ ] **AC-5.5** Given a manifest row is skipped (the card isn't to hand) When the run finishes Then the row is recorded as skipped and counted as not captured; the findings list skipped rows.
- [ ] **AC-5.6** Given the stored strips of a measured run When they are replayed on the desktop through the same recognition code headlessly Then the replay records each strip's text and the findings report how many rows' text differs from the on-device text, with the differing strings.

### Story 6: Re-measure findings

**As the** maintainer
**I want** the photo replay and the live tuning captures scored against Phase 0 with the same definitions
**So that** I can decide whether to build the scan → confirm flow

**Acceptance criteria:**

- [ ] **AC-6.1** Given the strip geometry, OCR settings and matcher settings for the measured run When they are tuned Then the tuning uses only captures of cards outside the 50-card corpus, the settings are committed before the measured run starts, and the findings name the commit.
- [ ] **AC-6.2** Given the measured run, a replay of the 50 Phase 0 corpus photos on the desktop through the shipped photo-picker path (the guide placed on each photo as AC-4.2 describes, the same strips, recognition, parsing and matching, with captures stored as in measurement mode), When the findings are written Then they report, overall, per frame era, for foil vs non-foil and for borderless or showcase vs regular frames, each with its sample size, against `spec/fixtures/card_scanner/ground_truth.json` (card name, front-face name, era, foil, frame treatment per manifest `file`), using research.md §3 and §5's definitions: name read (the raw name-strip text, normalised, against the front-face name and against the catalog name); top 1 and top 3 reported twice, once over the name candidates alone (Phase 0's definition, comparable with it) and once over the page's final ranking with any collector-line match first (what the collector sees); and, over the M15–ONE and MOM+ cards only, exact printing from the collector line, with none and ambiguous counted separately.
- [ ] **AC-6.3** Given Phase 0's committed OCR text (`spec/fixtures/card_scanner/ocr_results.json`) When it is re-scored with Phase 1's parser and matcher Then the findings report the same rates for it, including both top-N rankings, so each rate appears three times: Phase 0, Phase 0's text with Phase 1's matcher, and the Phase 1 photo replay.
- [ ] **AC-6.4** Given the photo replay and the final tuning round's live captures When the findings are written Then, separately for each, every card whose correct card is not in the top 3 is listed with its strip text and likely cause (glare, blur, misalignment, unusual frame, parser miss, matcher miss, or catalog gap).
- [ ] **AC-6.5** Given the tuning rounds' live captures on the maintainer's iPhone, the photo replay, and a cold and a warm load of the scanner page on the iPhone When the findings are written Then they report the median and slowest on-device recognition time per capture (from the tuning rounds), the median and 95th-percentile app-side candidate lookup time (from the photo replay), the bytes downloaded on the cold load and on the warm load, the device and browser used, and the result of each manual device check (rear camera opened, camera indicator off after leaving, torch lights, plain-HTTP fallback shown).
- [ ] **AC-6.6** Given the photo replay and the final tuning round When they end Then their strip text and parsed results are committed as text fixtures alongside Phase 0's, keyed by manifest `file`, in Phase 0's format extended with the new fields (recognition time, user agent, capture time) under a higher `format_version`; no image, crop or photo is committed.
- [ ] **AC-6.7** Given the findings are complete When they are written Then they end with options for the maintainer (build the confirm flow, bring card detection forward, or stop) and set no pass threshold; the next spec is not written until the maintainer rules.
- [ ] **AC-6.8** Given the live captures of every tuning round When the findings are written Then they report each round's rates with the definitions of AC-6.2 (each with its sample size), what changed between rounds, and a plain statement that these cards also chose the settings, so their rates are biased upwards and are the only live-alignment evidence in Phase 1.

### Story 7: HTTPS and documentation

**As a** self-hoster or developer
**I want** to know that the scanner needs HTTPS and how to provide it
**So that** the camera works on phones

**Acceptance criteria:**

- [ ] **AC-7.1** Given a developer following the README When they want to use the scanner from a phone on the local network Then a documented, repeatable procedure serves the development app over HTTPS to the phone, without editing committed files (documented environment variables are allowed) and without committing any certificate or key.
- [ ] **AC-7.2** Given a self-hoster reading the README's Compose and Kamal sections When they read about the scanner Then it states that the live camera needs the app served over HTTPS, that without HTTPS only the photo picker works, and how each deployment path provides HTTPS.
- [ ] **AC-7.3** Given a self-hoster building or deploying the app as documented When the build finishes Then the OCR engine files are present at their versioned path with no extra manual step, as they are in a development checkout after `bin/setup` (committed or fetched; ADR 0001 leaves the choice to the plan); and Given the test suite runs Then a test checks every engine file against its pinned checksum.
- [ ] **AC-7.4** Given ADRs 0001, 0002 and 0003 When Phase 1's plan is approved Then each is `Accepted`, or revised and then `Accepted`, with any change from its Proposed text recorded in the ADR.

## Functional Requirements

### FR-1: Scanner page access

**Must:**
- Require a signed-in user (the app's existing sign-in), like other signed-in pages.
- Follow the Collector design system (`docs/design-system/`): its tokens and `c-*` components, with any new pattern added as an app-specific pattern with its own doc.
- Be reachable by URL only; no link anywhere in the app.

**Must not:**
- Create, change or read any tenant data. Scanning in this feature doesn't touch lots or collections.

### FR-2: Live capture

**Must:**
- Prefer the rear-facing camera, at a resolution high enough for the strips to be read; the plan chooses it and the findings report it.
- Cut strips relative to the guide as drawn, so what the user aligns is what is read.
- Stop all camera tracks when the page is left, including before any snapshot of the page is cached for back navigation, and never keep the camera across page visits.

**Must not:**
- Capture automatically; capture happens only when the user activates the shutter.
- Keep the camera element or stream alive across navigation.

### FR-3: Recognition and privacy

**Must:**
- Run text recognition on the device, with the engine served from the app's own origin per ADR 0001.
- Send only recognised text to the app in normal use.

**Must not:**
- Send any frame, strip or photo to the app outside development measurement mode, or to any other host at all.
- Load the engine on any page except the scanner.

### FR-4: Parsing and matching

**Must:**
- Parse collector lines in the pre-M15, M15–ONE and MOM+ shapes, including the Phase 0 inputs and the AC-3.6 cases.
- Accept a set code only if it is a known catalog set code.
- Look printings up by set, collector number and language, with three outcomes: one printing, none, or several.
- Look printings up in English when no language was read.
- Match names through the name index (ADR 0003), with query cleaning and the two fallbacks of AC-3.5.
- Keep the collector-line parser and set-code rules inside the MTG extension; the name index and name matching are collectible-agnostic catalog core, keyed by collectible type.

**Must not:**
- Infer the finish (foil, etched) from the recognised text.
- Call any external service while matching.

### FR-5: Name index upkeep

**Must:**
- Hold the name index in the primary database as global catalog data (no `account_id`), keyed by collectible type and kept in `schema.rb`. Each collectible's source supplies the names to index; for MTG, each distinct full name and each face name of multi-face cards.
- Rebuild it in full in the background work of a refresh run that finishes applied, or that is skipped while the index is empty.
- Be created by an unattended upgrade (`db:prepare`) from any prior version. An upgraded instance whose catalog is already current gets a populated index from its next scheduled or manual refresh run, even when that run is skipped for an already-applied version; until it is populated, the scanner says the catalog isn't ready (AC-3.8).

### FR-6: Measurement mode

**Must:**
- Be controlled by a setting that is on by default in development and off by default in production and test (AC-5.1).
- Attribute every capture to a manifest row chosen before capture.
- Store text and strip images outside the repository and outside `storage/`.

**Must not:**
- Commit or upload any image. Committed fixtures are text only.

## Non-Functional Requirements

### Performance

- The findings report on-device recognition time per capture (median and slowest over the tuning rounds' live captures) and app-side candidate lookup time (median and 95th percentile). Phase 0's reference is a median of 626 ms per photo (n=11) and a name-query 95th percentile of 114 ms (n=50); a slower result is reported against these, not hidden.
- A cold load of the scanner page downloads one core build, not all of them, and a warm load re-downloads no engine file.

### Security

- The scanner page's Content Security Policy is as AC-2.4 states; the rest of the app's policy is unchanged (AC-2.3).
- Candidate card images, if shown, come only from the hosts the catalog pages already use for card images; no frame or strip is ever sent to them.
- The recognition endpoint accepts only bounded text (the plan sets the limit) and validates it; the measurement upload accepts only images of an allowed type and size and answers 404 whenever measurement mode is off. Production deployments as documented never turn measurement mode on.
- No certificate, private key or engine file outside the pinned set is committed.

### Reliability

- The camera page tests (ADR 0002) run in the suite that gates merges and pass 10 times in a row locally.
- Losing the camera mid-session (device locked, another app takes it) leaves the page usable through the photo picker.

### Accessibility

- State changes (engine loading, ready, reading, results, errors) are announced through a polite live region.
- The shutter and torch controls are at least 44×44 points and placed in the bottom third of the viewport on a phone-sized screen; the guide's alignment cues do not rely on colour alone; motion respects reduced-motion preferences.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Camera permission denied | Explain that the camera was blocked and how to allow it; offer the photo picker (AC-4.1) |
| No camera, or the camera fails to start | Say so; offer the photo picker |
| Insecure context (plain HTTP from another device) | Don't request the camera; explain HTTPS is needed; offer the photo picker (AC-1.6) |
| Engine files fail to load, or the engine loads but can't start (for example, WebAssembly disabled, as in iOS Lockdown Mode) | Say the scanner couldn't load and offer a retry; the shutter stays disabled; the photo picker can't help either, so say so |
| Sending the recognised text to the app fails (network error or server error) | Show an error, keep the recognised text on the page, and offer a retry |
| The session expired while the page was open | Sending the text gets the app's sign-in response; the page says to sign in again instead of failing silently |
| Recognition reads nothing from either strip | Say nothing could be read, suggest lining the card up with the guide and trying again |
| Collector line unreadable, name readable | Show "not found" for the parsed fields; candidates come from the name |
| Collector line matches several printings | Show "several printings"; candidates come from the name (AC-3.3) |
| Catalog empty or name index empty | Say the catalog isn't ready yet (AC-3.8) |
| Recognition text exceeds the size limit or is malformed | The app rejects it with an error state the page shows; nothing is matched |
| Torch unsupported | No torch control shown (AC-1.5) |
| User leaves the page while recognition runs | Camera stops; the result is discarded; nothing is sent after the page is gone |
| Measurement upload fails | Show the failure on the page and allow a retry; the capture isn't counted until stored |
| Manifest missing or malformed in measurement mode | Measurement mode says so and doesn't start; normal mode is unaffected |

## Open Questions

None. Decided while specifying (2026-09-30, maintainer):

- Scope: capture and re-measure only; the confirm flow is a later spec gated on the findings.
- The page is in the app, signed-in, unlinked; the same 50 physical cards were to be re-captured (superseded on 2026-10-01, below); measurement mode sends text and strip images (no full frames) to the development machine; the page shows read text and candidates; no pass threshold; extras are the photo-picker fallback and a torch toggle; the development HTTPS mechanism is left to the plan.

Decided during execution (2026-10-01, maintainer):

- The 50 corpus cards were borrowed and returned, so the measured run replays their Phase 0 photos through the photo-picker path instead of re-capturing them live. The tuning rounds' live captures are reported as the only live-alignment evidence, labelled as biased. Download sizes come from a load test on the iPhone.

## Out of Scope (Future Considerations)

- The scan → candidates → confirm → add-to-lot flow, with the finish chosen by the user, an undo and a recent-scans list (next spec, if the maintainer rules go).
- Scan records (`scan_attempts`, corrections) as a feedback dataset.
- Card detection and rectification (Phase 2, or earlier if this re-measure calls for it).
- Live alignment feedback before the shutter.
- A Chrome file-capture test of the real media path (ADR 0002's optional test).
- Japanese OCR, flavour names, art hashing, bulk scanning, native apps.
