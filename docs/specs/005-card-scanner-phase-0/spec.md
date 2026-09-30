# Feature 005: Card Scanner Phase 0 — Feasibility Spikes

**Status:** Approved
**Version:** 1.0.0
**Created:** 2026-09-30
**Last Updated:** 2026-09-30
**Branch:** `005-card-scanner-phase-0`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-09-30 | Initial approved spec |

---

## Problem Statement

Collectors want to add a card by pointing a phone at it instead of searching by name. The card scanner roadmap (`~/Downloads/card-scanner-research-and-roadmap.md`, "Collector Card Scanner — Tool & Architecture Research", Sept 2026) proposes a Phase 1 design built on three things nobody has tried in this app:

- Text recognition running in the phone's browser can read a card's name bar and collector line from a real phone photo well enough to identify the card.
- The local catalog can fuzzy-match garbled, misread card names quickly.
- A camera page can be tested automatically, with no person or physical camera involved, inside the project's test suite.

If any of these is wrong, Phase 1 would be built on a false premise and need rework. Phase 0 answers each question with measured evidence before Phase 1 is specified.

> **Constraints.** A spike exists to test a specific proposed technique, so the techniques under test are fixed inputs, the way the stack is. They are named in the roadmap: browser-side OCR (Tesseract.js, self-hosted) over fixed name-bar and collector-line strips, a trigram full-text name index in SQLite, and fake-camera media injection in system tests. The requirements below state the questions and the evidence required. The plan decides how each spike is run.

> **Corrections to the roadmap.** Found while reading it against the repo, and recorded here so the findings don't rely on them:
> - There is no existing "resolver chain" to feed parsed collector lines into. A printing lookup by set, collector number and language has to be built, and Phase 0 only prototypes it.
> - The `sdd-init` layout spike is not needed, because the SDD plugin is installed and in use (`docs/specs/NNN-slug/`).
> - System specs use Selenium with headless Firefox, not Chrome with Cuprite.
> - The catalog imports English only unless `COLLECTOR_MTG_LANGUAGES` adds more.
> - The catalog does not store `illustration_id`.

## Goals

- Each of the three spikes (OCR strip accuracy, headless camera testing, fuzzy name index) answers its stated question with measured numbers, the raw data behind them, and a written recommendation.
- The maintainer can make an informed go / no-go / pivot decision on Phase 1's OCR-based design from the findings. Phase 0 sets no pass threshold, so the numbers inform the decision rather than make it.
- Phase 1's spec can be written from the findings: a revised Phase 1 scope, the chosen approach for each question, and the known failure cases.
- The OCR output recorded for the photo corpus is kept as text, so Phase 1 can reuse it as matcher regression fixtures without re-running OCR.

## Non-Goals

- No scanner feature for collectors: no page, route, or navigation entry that users can reach.
- No spike code merged into the application (`app/`, `config/routes.rb`, migrations under `db/migrate/`). Spike code is throwaway and lives outside the app's load path, or on a branch that isn't merged.
- Japanese and other non-English cards (moved to Phase 2, where the roadmap already places lazy Japanese OCR).
- Art hashing, perceptual-hash indexes and Hamming search speed (moved to Phase 2's own spikes).
- Card detection, perspective correction (rectification) and continuous or bulk scanning.
- Native apps (Hotwire Native iOS or Android).
- Deciding go/no-go. The maintainer decides from the findings.
- Changes to catalog ingestion or to the catalog's schema.

## Users and Context

**Primary users:** The maintainer, who decides whether and how Phase 1 proceeds, and who takes the corpus photos and runs the on-device measurements.
**Secondary users:** Claude Code sessions that will write Phase 1's spec and plan from the findings, and Phase 1's test suite, which reuses the recorded OCR text.
**Usage context:** The maintainer photographs their own cards with an iPhone and runs timings in Safari against a development instance on the local network. The desktop replays the same photos so the accuracy numbers can be repeated.
**User mental model:** "Before building the scanner, prove the risky parts work on my cards and my phone, and show me the numbers."

## User Stories

### Story 1: OCR strip accuracy on real photos

**As the** maintainer
**I want** to know how well in-browser OCR on the name bar and collector line identifies my real cards from phone photos
**So that** I can decide whether Phase 1's OCR-based scanner is worth building as designed

**Acceptance criteria:**

- [ ] **AC-1.1** Given the maintainer has taken at least 50 phone photos of English cards When the corpus is assembled Then a ground-truth file lists, for every photo, its file name, the expected card name, set code, collector number, frame era (pre-M15, M15–ONE, MOM and later) and whether it is foil and whether it is borderless or showcase. Every era has at least 5 photos, and at least 5 photos are foil.
- [ ] **AC-1.2** Given the corpus and ground truth When the accuracy run is replayed on the desktop Then, for every photo, it records the raw OCR text of the name strip and the collector strip, the parsed set code and collector number (or "none"), and the top 3 name candidates from the catalog.
- [ ] **AC-1.3** Given the recorded results When the findings are written Then they report, overall and per frame era and for foil vs non-foil: the rate of exact name reads after normalisation, the rate at which the correct card is the top candidate, the rate at which it is in the top 3, and, for photos whose frame prints a collector line, the rate at which the parsed set and number identify the exact printing.
- [ ] **AC-1.4** Given the collector-line prototype When it is given the text `051/302 NEO` (M15–ONE style) Then it yields set NEO and collector number 51, not 302, and the findings show this case among the parser's test inputs.
- [ ] **AC-1.5** Given the same accuracy run is replayed twice on the same machine When the two result sets are compared Then the per-photo OCR text is identical, so the numbers can be repeated.
- [ ] **AC-1.6** Given the maintainer's iPhone in a Safari tab, on a development instance on the local network When the OCR engine is loaded cold (browser cache and site storage cleared) and then warm (same tab, second load) Then the findings report the bytes downloaded before the first scan can start, the time from page load to ready, and the median and slowest per-photo recognition time over at least 10 corpus photos.
- [ ] **AC-1.7** Given the recorded results When the findings are written Then every photo whose correct card is not in the top 3 is listed with its likely cause (glare, blur, misalignment of the fixed strip, unusual frame, parser miss, or matcher miss).

### Story 2: Headless camera testing

**As a** developer of Collector
**I want** to know whether a system test can drive a live-camera page using a known card image, with no person and no physical camera
**So that** Phase 1's scanner can be covered by the automated suite that gates merges (Foundation principle 5)

**Acceptance criteria:**

- [ ] **AC-2.1** Given a throwaway page that shows the camera feed and captures a frame When a system test runs with the project's current headless Firefox driver Then the findings state whether the test can supply a chosen card image as the camera feed, not just a synthetic pattern, and include the exact configuration tried and its result.
- [ ] **AC-2.2** Given a camera feed from a known card image When the captured frame is checked in the test Then the findings state whether the test could assert that the frame matches the card, for example by recognising the card's name from it.
- [ ] **AC-2.3** Given the current driver cannot supply a chosen image When alternatives are tried Then the findings compare at least two alternatives (such as a second browser driver used only for camera tests, or replacing the camera feed from within the page in test mode). The comparison states for each whether it works, the extra setup needed on the dev machine and in CI, how it changes suite run time, and any flakiness seen over 10 consecutive runs.
- [ ] **AC-2.4** Given the chosen approach When it runs 10 times in a row locally Then all 10 runs pass, or the findings record the failure rate and the failure messages.

### Story 3: Fuzzy name index against the real catalog

**As the** maintainer
**I want** to know whether a trigram name index over the local catalog finds the right card from misread names, quickly, and within the app's schema conventions
**So that** Phase 1's matcher can rely on it, or I know what to use instead

**Acceptance criteria:**

- [ ] **AC-3.1** Given a database holding the index When the schema is dumped and a fresh database is loaded from the dump Then the findings state whether the index, including its tokenizer options, survives the round trip intact, and what the fallback is if it does not.
- [ ] **AC-3.2** Given the full English catalog from a real refresh When the index is built Then the findings report the build time, the index's size on disk, and the number of names indexed, one per distinct name and face.
- [ ] **AC-3.3** Given the name-strip OCR text recorded in Story 1 When each is queried against the index, with candidates re-ranked by string similarity Then the findings report the rate at which the correct card is the top candidate and in the top 3, and the median and 95th-percentile query time.
- [ ] **AC-3.4** Given names shorter than 3 characters after normalisation, names with diacritics or ligatures (such as "Æther Vial" and "Lim-Dûl's Vault"), and split, adventure and double-faced cards When each is queried by its printed name and by a one-character misread of it Then the findings report which are found, and propose a fallback for each failing category.
- [ ] **AC-3.5** Given the index must stay consistent with the catalog When the findings are written Then they state how the index would be rebuilt or updated after a catalog refresh, and how long that adds to a refresh.

### Story 4: Findings and Phase 1 recommendation

**As the** maintainer
**I want** one write-up of every spike's evidence and a recommended Phase 1 scope
**So that** I can decide on Phase 1 and hand it straight to `sdd-specify`

**Acceptance criteria:**

- [ ] **AC-4.1** Given all three spikes are complete When the findings are published Then `docs/specs/005-card-scanner-phase-0/research.md` contains, for each spike: the question, the method, the measured results (tables), the failure cases, and a recommendation.
- [ ] **AC-4.2** Given the findings When the maintainer reads the recommendation section Then it states a recommended Phase 1 scope (in, out, and changed from the roadmap) and lists every roadmap assumption that the evidence contradicted.
- [ ] **AC-4.3** Given each technical decision the findings recommend (the OCR engine and its asset hosting, the camera-test approach, the name-index approach) When the findings are published Then each has an ADR under `docs/adr/` with `Status: Proposed`, linked from `research.md`.
- [ ] **AC-4.4** Given the recorded per-photo OCR text and ground truth When Phase 0 is complete Then both are committed as text files (no images), in a form Phase 1's tests can load, and `research.md` documents their format.
- [ ] **AC-4.5** Given Phase 0 is complete When `git diff main` is inspected Then it contains no changes under `app/`, `config/routes.rb`, `db/migrate/` or `db/schema.rb`, and `bin/ci` passes.

## Functional Requirements

### FR-1: Photo corpus

**Must:**
- Hold at least 50 photos of English cards taken with the maintainer's iPhone, covering the eras and finishes listed in AC-1.1.
- Keep photos outside the repository, in a location documented in `research.md` by path convention, not by absolute path.
- Commit a ground-truth file keyed by photo file name.

**Must not:**
- Commit any photo, crop or derived image to the repository.
- Send any photo or crop to a third-party service. All recognition runs in the browser or on the maintainer's machine.

### FR-2: OCR accuracy run

**Must:**
- Crop the name-bar and collector-line strips at fixed positions relative to a card-shaped guide, as the roadmap describes. The spike does no card detection or perspective correction.
- Load the OCR engine, its worker and its language data from the development instance itself, not a CDN.
- Normalise names identically for the ground truth, the OCR text and the catalog (case, punctuation, Unicode compatibility forms, "Æ" to "ae").
- Record results as described in AC-1.2 in a committed, text-only format.

### FR-3: Collector-line prototype

**Must:**
- Parse both the M15–ONE format (`NNN/TTT R` with `SET • EN`) and the MOM and later format (`R NNNN` with `SET • EN`), including promo suffix letters and star or bullet foil markers.
- Accept a parsed set code only if it is a known set code in the catalog.
- Resolve a parsed set, number and language to exactly one catalog printing, or report none.

### FR-4: Findings

**Must:**
- Report numbers with the sample size they come from.
- Keep throwaway spike code out of the app's load path (for example, under a `spikes/` directory excluded from Zeitwerk and CI, or on an unmerged branch). The plan chooses which.

**Must not:**
- Present an estimate as a measurement. Anything not measured is labelled as an estimate.

## Non-Functional Requirements

### Performance

- Phase 0 sets no performance targets. It measures and reports the numbers listed in AC-1.6, AC-3.2, AC-3.3 and AC-3.5.

### Security and privacy

- Photos stay on the maintainer's devices and development machine (FR-1).
- The OCR spike page makes no requests to hosts other than the development instance. The findings confirm this from the browser's network log for one cold iPhone run.
- Any throwaway page or route used on the development instance is unreachable in production and absent from the merged code (AC-4.5).

### Reliability

- The desktop accuracy run is repeatable (AC-1.5).
- `bin/ci` passes on the branch at every commit that reaches `main`.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A photo is unreadable (blurred or cropped out of frame) | It stays in the corpus and counts as a failure in the rates, with its cause recorded (AC-1.7). It isn't silently dropped. |
| A ground-truth entry names a card or printing not in the local catalog | The run reports the entry as a ground-truth error and excludes it from the rates, and the findings list it. |
| The iPhone won't grant camera access over plain HTTP on the LAN | On-device timing uses the photo picker with corpus photos, and the findings note it. Live-camera timing is left to Phase 1. |
| Fake-camera injection doesn't work with any tried approach | The findings record each attempt and its failure, and recommend how Phase 1 covers the camera path instead (for example, testing the post-capture flow from a supplied image). |
| The trigram index doesn't survive the schema round trip | The findings recommend a fallback (such as a SQL-format schema dump, or building the index outside the schema) with its trade-offs. |

## Open Questions

None. Resolved during specification:
- Deliverable: findings and ADRs; no spike code merges into the app.
- Spikes: OCR strip accuracy, headless camera testing, fuzzy name index. The `sdd-init` spike is dropped as already answered, and art-hash search speed moves to Phase 2.
- Corpus: 50+ English photos. Japanese is deferred to Phase 2.
- Go bar: the spike reports only, and the maintainer decides from the numbers.
- Device: the maintainer's iPhone in a Safari tab, plus desktop replay for repeatable accuracy.
- Photo storage: outside the repository.

## Out of Scope (Future Considerations)

- Japanese OCR accuracy and short-name CJK fallback (Phase 2).
- Art-hash index, `illustration_id` in the catalog, and Hamming search speed (Phase 2).
- Rectification via OpenCV.js or a Python accessory (Phase 2).
- Live-camera HTTPS setup for on-device development (Phase 1 plan).
- Scan data model (`scan_sessions`, `scan_attempts`), image retention policy and the confirm-to-collection flow (Phase 1).
- Hotwire Native iOS (Phase 3), bulk scanning (Phase 4), Android (Phase 5).
