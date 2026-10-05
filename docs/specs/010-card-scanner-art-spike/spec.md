# Feature 010: Card Scanner Art Spike — The Index on a Phone, and Art on Live Captures

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-10-05
**Last Updated:** 2026-10-05
**Branch:** `010-card-scanner-art-spike`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-05 | Initial draft, from the approved [PRD](prd.md) |

---

## Problem Statement

Spec 009's live sitting ended right first time for 30 of 35 unseen cards ([research.md](../009-card-scanner-confirm-flow/research.md) §8). Every miss and correction had the same cause: the collector line gave no usable printing, so the name chose the newest one. The cards were:
- older frames with no set code: IMG_6808 Plains (M10 233) and IMG_6829 Mana Geyser (CNS 147)
- a lost set code: IMG_6821 Pegasus Guardian (CLB 36)
- corrections through Other printings: IMG_6814 Obsidian Fireheart (ZEN 140) and IMG_6823 Past in Flames (WHO 565)

Art matching was proposed for exactly these cards. Spec 008 put the right artwork first for 33 of 47 held-out photos against the full index of 50,923 artworks ([research.md](../008-card-scanner-phase-2-spike/research.md) §9).

Two things decide how art matching should be built, and both are unmeasured:

- **The index on a phone.** [ADR 0007](../../adr/0007-art-search-in-the-browser.md) proposes that the browser downloads and searches the index. On the desktop the index is 6,007,929 bytes compressed and searches in 77 ms median. Its download time, search time and memory on the maintainer's iPhone are unknown.
- **Art on live captures.** Spec 008 measured art only on photos the detector had straightened. Live captures, which spec 009's misses came from, are cut at the guide box and never straightened.

This spike measures both. The maintainer then rules on spec 011, which builds art matching, and on ADRs 0006 and 0007.

> **Inputs.** The [PRD](prd.md) (approved 2026-10-05) and the maintainer's rulings it records are fixed inputs:
> - two specs (this spike, then spec 011)
> - art on both paths, measured first
> - the full index rebuilt with real fingerprints, after an approved estimate
> - the same 35 cards
> - live-frame data collected through the app's development-only measurement mode
>
> The fingerprint and index format are frozen at `39cdc6e` ([ADR 0006](../../adr/0006-art-fingerprint-and-index.md), Proposed). [ADR 0004](../../adr/0004-card-recognition-in-the-browser.md) (Accepted) holds: in normal use, collectors' pictures never leave the device.

## Goals

- The full art index is rebuilt at the frozen fingerprint settings against the current catalog, after the maintainer approves a committed estimate. Its build cost is reported.
- The maintainer's iPhone loads the full index and searches it, and the findings report the download, readiness, search and fingerprint times, and the index's memory footprint.
- The same 35 cards are captured live on the iPhone with their full frames kept on the dev machine. On the desktop, each frame's art is fingerprinted from the guide box and from the detected, straightened card, and searched against the full index.
- The same 35 cards' unguided photos are put through detection and art on the desktop.
- The findings report art accuracy for each path against spec 009's text-only results on the same cards, name the outcome for each of spec 009's misses and corrections, and end with recommendations for spec 011 and ADRs 0006 and 0007.

## Non-Goals

- Anything collectors use:
  - a catalog artwork id
  - an opt-in setting
  - an index build in the catalog refresh
  - serving the index from the app
  - art in the ranking
  - UI

  All of that is spec 011.
- Choosing ImageMagick or `ruby-vips` for production (ADR 0006). The spike reuses spec 008's tools.
- Changing the fingerprint's settings. They stay frozen at `39cdc6e`, and nothing is tuned.
- Detection on live frames as a product feature. The spike measures it offline only.
- Other phones, other browsers, or downloads over the internet rather than the LAN.
- A pass threshold for any figure.

## Users and Context

**Primary user:** the maintainer. They approve the fetch estimate, run the phone measurement and the live captures on the iPhone (Brave, which is WebKit, on the dev machine's LAN, with the spec 007 certificate trusted), read the findings and rule on spec 011.
**Secondary users:** Claude Code sessions that write spec 011 from the findings. Collectors and self-hosters see no change.
**Usage context:**
- The maintainer sits at the desk with spec 009's 35-card pile and the iPhone.
- The dev machine serves an HTTPS page for the index measurement, and then the app's measurement mode for the captures.
- Everything else runs on the desktop: the index rebuild, the replays and the scoring.

**User mental model:** "Show me whether the art index is usable on my phone, and whether art would have fixed the cards the scanner got wrong, on live captures as well as photos."

**What exists:**
- spec 008's art tools under `spikes/card_scanner/phase2/`
- the development catalog (`default-cards-20261003210542`) and its bulk file
- the 35-card manifest, ground truth and unguided photos at `~/card-scanner-corpus/phase2-sitting/`
- spec 009's text results for the same cards, in the committed fixtures `phase2_sitting_*`
- the shipped detector
- the app's development-only measurement mode

## User Stories

### Story 1: The full art index, rebuilt

**As the** maintainer
**I want** the full index rebuilt only after I've approved its cost
**So that** every figure is measured against the real index, without an unapproved 2.6-hour fetch

**Acceptance criteria:**

- [ ] **AC-1.1** Given the current catalog's bulk file When the artworks are listed Then the list holds one artwork per distinct front-face artwork id among the catalog's entries with an image (spec 008 AC-4.1's definition). The findings report the count and the bulk file it came from, which must be the development catalog's (`default-cards-20261003210542`), or else the one its refresh replaced it with, named.
- [ ] **AC-1.2** Given no artwork is cached When the fetch is about to start Then an estimate is committed first: artworks to fetch, bytes, and hours at the throttled rate, from spec 008's measured bytes and time per artwork. No artwork beyond the 35 cards' own is fetched until the maintainer approves it.
- [ ] **AC-1.3** Given the maintainer's approval When the artworks are fetched Then every request:
  - carries a descriptive `User-Agent` and an `Accept` header
  - comes at least 100 ms after the previous one
  - has open and read timeouts
  - backs off on 429 and 5xx

  The fetch is resumable and never fetches an image twice. Images are cached in `~/card-scanner-corpus/art-cache/`, outside the repository and every worktree.
- [ ] **AC-1.4** Given an image that can't be fetched after the retries When the index is built Then its artwork is left out, and the findings report how many were left out and why.
- [ ] **AC-1.5** Given every cached image When the index is built at the fingerprint settings frozen at `39cdc6e` Then it holds one record per artwork with an image, in spec 008's format (a 16-byte artwork id and a 128-byte fingerprint). The findings report:
  - the record count
  - the size, stored and compressed
  - the fetch's images, bytes and time
  - the fingerprinting time
- [ ] **AC-1.6** Given the index build and the browser fingerprint images with different code When at least 50 cached images are fingerprinted by both Then the findings report the largest difference in bits between them. It must be 0 for the index to be used.

### Story 2: The index on the iPhone

**As the** maintainer
**I want** to know what the full index costs my phone
**So that** I can rule on whether the browser should download and search it (ADR 0007)

**Acceptance criteria:**

- [ ] **AC-2.1** Given the rebuilt index When the maintainer opens the spike's timing page on the iPhone, served over HTTPS from the dev machine Then the page:
  - loads the index from its own origin and nowhere else
  - runs under a Content Security Policy that allows connections only to its own origin
  - reports the bytes transferred and the download time
- [ ] **AC-2.2** Given the download When it completes Then the page reports the time to make the index ready to search, separately from the download.
- [ ] **AC-2.3** Given at least 20 query fingerprints When the page searches the full index with each Then it reports the search time, median and slowest. The queries are the six offset fingerprints per query, as spec 008 searched, taken from the desktop replay of the live frames (Story 4). Each search's top artwork is the same as the desktop's for the same query.
- [ ] **AC-2.4** Given at least 10 straightened cards from the desktop replay When the page fingerprints them on the phone Then it reports the fingerprint time, median and slowest, and the fingerprints are identical to the desktop's.
- [ ] **AC-2.5** Given WebKit exposes no heap size When memory is reported Then the findings give the index's size in memory as the page holds it. They also say whether the page stayed responsive through 100 consecutive searches: no reload, no crash, and no gap of more than 1 second between progress updates.
- [ ] **AC-2.6** Given the page is loaded once with an empty cache and once with the index cached When the findings are written Then they report both loads. They also give the cold download's time at 50, 10 and 2 Mbit/s, computed from the bytes and labelled as arithmetic, not measured.
- [ ] **AC-2.7** Given the measurement When the findings are written Then they name the device, the iOS version and the browser (from the user agent), and say that the download was measured over the LAN.

### Story 3: Live frames kept in measurement mode

**As the** maintainer
**I want** each live capture's full frame kept on the dev machine while I measure
**So that** art can be measured on live captures without changing what the scanner does for collectors

**Acceptance criteria:**

- [ ] **AC-3.1** Given measurement mode is on (development only) and frame keeping is enabled for the run When a live capture is stored Then its full frame is stored losslessly (PNG) beside the capture's strips and text, outside the repository and `storage/`. Beside it go the guide rect the page used (x, y, width and height in frame pixels) and the frame's size.
- [ ] **AC-3.2** Given a frame larger than the strips' 5 MB limit When it is stored Then a frame limit large enough for a full camera frame applies instead, with the limit stated. A file that isn't a PNG, or is over that limit, is refused with the existing "nothing was stored" message, and the capture doesn't count.
- [ ] **AC-3.3** Given measurement mode is off (production, test by default) When any frame upload is attempted Then it answers 404, as every measurement route does today. Normal scanning never sends a frame.
- [ ] **AC-3.4** Given the 35-card manifest When the maintainer captures each card live once Then the first capture is the scored one. A retake is allowed only when the first capture is unusable, as in spec 007's protocol, and retakes are reported. Each capture's text reading is stored as in spec 009.
- [ ] **AC-3.5** Given the live session When the findings are written Then they report:
  - frames stored, skipped rows and retakes
  - the frame size the iPhone delivered
  - the device and browser

### Story 4: Art accuracy on the 35 cards

**As the** maintainer
**I want** art measured on the paths spec 011 could use, on the cards spec 009 already scored
**So that** I can see whether art would have fixed spec 009's misses, and on which path

**Acceptance criteria:**

- [ ] **AC-4.1** Given each stored live frame and its guide rect When the guide-box path runs on the desktop Then the guide rect is taken as the card, and its art box (spec 008's x 0.14–0.86, y 0.16–0.50) is fingerprinted at the six offsets and searched against the full index.
- [ ] **AC-4.2** Given each stored live frame When the detected path runs on the desktop Then the shipped detector looks for the card in the frame. If it finds one, the straightened card is fingerprinted and searched as on the photo path. If it finds none, the frame counts as a miss for that path, and the findings report how many outlines were found.
- [ ] **AC-4.3** Given the 35 cards' unguided photos When the photo path runs on the desktop Then each photo goes through the shipped detector, and the straightened card is fingerprinted and searched. A photo without an outline counts as a miss.
- [ ] **AC-4.4** Given each path's results When the rates are computed Then, for each path, they report:
  - **right artwork first:** the top artwork is the artwork of the card's ground-truth printing
  - **right card first by art:** the top artwork belongs to the card, whichever printing
  - **right artwork in the top 3**

  Each comes with its sample size, overall and split into foils and non-foils.
- [ ] **AC-4.5** Given spec 009's committed text results for the same cards (`phase2_sitting_*`) When the comparison is written Then, for each path, it reports:
  - the right card in the text's top 3 or first by art, against the text's top 3 alone
  - the cards whose exact printing the text didn't identify, and for how many of them the top artwork belongs to exactly one English printing and that printing is the right one

  A secondary table repeats both against the text read in the same new capture. Rescoring it uses the shipped matcher at spec 009's frozen settings.
- [ ] **AC-4.6** Given spec 009's misses and corrections (IMG_6808, IMG_6829, IMG_6821, IMG_6814 and IMG_6823) When the findings are written Then each is named with:
  - its art outcome on every path
  - the right artwork's distance and the nearest wrong artwork's distance
  - whether its artwork is unique to its printing
- [ ] **AC-4.7** Given each path's searches When distances are reported Then the findings give the median distance to the right artwork and to the nearest wrong artwork, and list every card whose right artwork wasn't first, with its likely cause:
  - framing
  - glare or foil
  - an artwork shared with another printing
  - a missing image
- [ ] **AC-4.8** Given the replays When they run Then they run on the desktop with the browser's fingerprint and search code, from the stored frames and photos. The same frame gives the same fingerprints on two runs, and the findings report any difference.

### Story 5: Findings, ADR updates and reusable data

**As the** maintainer
**I want** the measurements written up with recommendations, the ADRs brought up to date and the results kept as text
**So that** I can rule on spec 011, and spec 011 can build on the figures

**Acceptance criteria:**

- [ ] **AC-5.1** Given the measurements When the findings are published Then `docs/specs/010-card-scanner-art-spike/research.md` reports Stories 1–4's figures with sample sizes, labels the desktop and phone figures as such, and sets no pass threshold.
- [ ] **AC-5.2** Given the findings When they end Then they give recommendations for spec 011. These cover:
  - which paths get art (live guide box, live detected, photo)
  - where the search runs
  - how art evidence joins the ranking, grouped by card
  - what the opt-in fetch costs a self-hosted instance

  The maintainer rules on them; no recommendation is a decision.
- [ ] **AC-5.3** Given ADRs 0006 and 0007 When the findings are published Then each ADR's Consequences gain the phone and live-frame figures. Their references to spec 009 are corrected: spec 010 measures, spec 011 builds and decides. Both stay Proposed.
- [ ] **AC-5.4** Given the runs When the spike is complete Then their results are committed as JSON text fixtures under `spec/fixtures/card_scanner/`, prefixed `phase3_`, keyed by manifest `file`:
  - the phone timings
  - per card and path: the top artworks, their distances, outline found
  - the index build's figures

  No image, frame, fingerprint index or cached artwork is committed.
- [ ] **AC-5.5** Given the spike is complete When the branch's changes are inspected Then:
  - the app's code changes are confined to development-only measurement mode (Story 3), with tests
  - the timing page and replay tools live under `spikes/`
  - `bin/ci` passes at every commit

## Functional Requirements

### FR-1: The index

**Must:**
- Use the fingerprint settings frozen at `39cdc6e` and spec 008's index format, unchanged.
- Fetch only after the maintainer approves the committed estimate, following the project's Scryfall etiquette, and cache outside the repository and every worktree.
- Show 0 bits of difference between the build's fingerprints and the browser's before the index is used.

**Must not:**
- Tune or change any fingerprint setting.
- Commit any image or index.

### FR-2: The phone measurement

**Must:**
- Serve the timing page and the index from the dev machine over HTTPS, under a policy allowing connections to its own origin only.
- Report every figure in Story 2, with the device and browser named.

**Must not:**
- Load anything from a third-party host.
- Be reachable from the app in any environment.

### FR-3: Frames in measurement mode

**Must:**
- Store frames only when development measurement mode is on, losslessly, with the guide rect, outside the repository and `storage/`.
- Leave normal scanning unchanged: in normal use the page still sends only the text, the reading key, and the add, Undo and Other printings requests (spec 009 FR-5).

**Must not:**
- Send or store any frame outside development measurement mode.

### FR-4: The art replay

**Must:**
- Use the browser's fingerprint and search code and the shipped detector, on the desktop, from stored frames and photos.
- Score against the committed ground truth and spec 009's committed text results.

**Must not:**
- Use any of the 35 cards to change a setting.

### FR-5: The findings

**Must:**
- Cover Stories 1–4 with sample sizes, recommendations for spec 011, updated ADRs 0006 and 0007 (still Proposed), and text-only fixtures.

**Must not:**
- Set a pass threshold.

## Non-Functional Requirements

### Performance

- The spike sets no targets. It measures and reports the figures in AC-1.5, AC-2.1–AC-2.6 and AC-4.7, plus desktop fingerprint and search times for comparison with spec 008's.

### Security

- Frames, photos, cached artwork and the index stay on the maintainer's machine, outside the repository.
- Scryfall is contacted only by the index-build scripts, following `.claude/rules/external-data-and-portability.md`.
- Frame storage is reachable only when development measurement mode is on; the existing off-mode 404 test is extended to the frame upload.
- The timing page isn't part of the app and no app route serves it.

### Reliability

- The fetch is resumable and fetches no image twice (AC-1.3).
- The replay is deterministic and reports any difference (AC-4.8).
- `bin/ci` passes at every commit.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The maintainer declines the full fetch | No index beyond the 35 cards' artworks is built. The spike stops after Story 1, and the findings say so, with the estimate |
| An artwork image can't be fetched after retries | It's left out of the index; the findings count it (AC-1.4) |
| Scryfall answers 429 or 5xx | The fetch backs off and resumes; nothing already cached is fetched again |
| The bulk file isn't the development catalog's | The findings name the bulk file used, and every count uses it |
| The browser and the build disagree on any image | The index isn't used until the cause is found; the findings report it |
| The index won't load on the iPhone (the page reloads or crashes) | The page reports how far it got. The findings record the failure, the device and the browser as a result, and the rest of Story 2 is reported as not measurable |
| A frame upload fails or is over the limit | The capture isn't counted; measurement mode says so and offers to store it again (AC-3.2) |
| The detector finds no card in a live frame or photo | That item counts as a miss on the detected or photo path; the findings report outlines found (AC-4.2, AC-4.3) |
| A card's artwork has no image in the index | It counts as a miss, and the findings list it with "missing image" as the cause |
| A card's artwork is shared with other printings | Right card first by art can still be met. Printing identification can't, and the findings say so (AC-4.5, AC-4.6) |

## Open Questions

None. Decided in the brainstorm (2026-10-05, maintainer), and recorded in the [PRD](prd.md):
- two specs
- art on both paths, measured first
- a full rebuild after an approved estimate
- the same 35 cards
- Approach A

## Out of Scope (Future Considerations)

- **Spec 011's build:**
  - the catalog artwork id
  - the opt-in instance setting
  - the fetch and index build in the catalog refresh
  - serving the index
  - art evidence in `MTG::Reading`'s ranking
  - grouping art results by card
  - the spec 007 FR-3 amendment (match results may be sent)
  - the UI
- The production decoder (ImageMagick or `ruby-vips`).
- Detection on live frames in the shipped scanner.
- Foil detection (a foil's artwork is its printing's), other languages, other devices.
