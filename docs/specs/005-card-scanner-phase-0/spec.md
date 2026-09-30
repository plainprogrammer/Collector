# Feature 005: Card Scanner Phase 0 — Feasibility Spikes

**Status:** Approved
**Version:** 1.1.1
**Created:** 2026-09-30
**Last Updated:** 2026-09-30
**Branch:** `005-card-scanner-phase-0`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-09-30 | Initial approved spec |
| 1.1.0 | 2026-09-30 | Spec review revisions. **Merged-code check:** AC-4.5 lists the only paths the branch may change, so OCR assets in `public/`, vendored JS, importmap pins and gems are caught too (NFR Security, Non-Goals). **Where the spike page is served:** "same origin as the spike page" replaces "the development instance" (FR-2, Users and Context, AC-1.6, NFR Security). **Matcher ownership:** Story 1 records OCR text and parsed collector lines only; top-1/top-3 rates move to Story 3 with the per-era, foil and frame-treatment breakdowns (AC-1.2, AC-1.3, AC-1.7, AC-3.3). **Repeatability:** replays report their differences instead of requiring identical text (AC-1.5, new error row, NFR Reliability). **Eras:** defined by what the collector line prints; the exact-printing rate counts M15–ONE and MOM-and-later photos only; the parser can report ambiguous (AC-1.1, AC-1.3, FR-3). **No third-party hosts:** proven by a strict self-only Content Security Policy on the cold iPhone run, not by a Safari network log (NFR Security). **Newly defined:** ADR location and format (AC-4.3, Goals), fixture paths and format (AC-4.4, FR-1, FR-2). **Also:** ground truth uses catalog names; the 50-photo minimum counts rated photos; both full and per-face names are indexed; the similarity measure is stated; AC-2.2 asserts something card-specific; AC-2.4 covers the chosen approach; the spike page is exempt from the design system (FR-4) |
| 1.1.1 | 2026-09-30 | From planning: the quoted policy header blocked WebAssembly compilation, so the NFR now states the rule (only `'self'`, `blob:` for the worker, `'wasm-unsafe-eval'` for the engine; no other host) and the findings quote the header actually sent. Same intent (NFR Security) |

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
- The repo gains an ADR convention (`docs/adr/`), so Phase 0's recommended decisions, and later ones, are recorded in one place.

## Non-Goals

- No scanner feature for collectors: no page, route, or navigation entry that users can reach.
- No spike code or spike assets merged into the application or anything it serves: nothing under `app/`, `public/`, `vendor/`, `config/` or `db/`, and no `Gemfile` change (AC-4.5 lists what may change). Spike code is throwaway and lives outside the app's load path, or on a branch that isn't merged.
- Japanese and other non-English cards (moved to Phase 2, where the roadmap already places lazy Japanese OCR).
- Art hashing, perceptual-hash indexes and Hamming search speed (moved to Phase 2's own spikes).
- Card detection, perspective correction (rectification) and continuous or bulk scanning.
- Native apps (Hotwire Native iOS or Android).
- Deciding go/no-go. The maintainer decides from the findings.
- Changes to catalog ingestion or to the catalog's schema.

## Users and Context

**Primary users:** The maintainer, who decides whether and how Phase 1 proceeds, and who takes the corpus photos and runs the on-device measurements.
**Secondary users:** Claude Code sessions that will write Phase 1's spec and plan from the findings, and Phase 1's test suite, which reuses the recorded OCR text.
**Usage context:** The maintainer photographs their own cards with an iPhone and runs timings in Safari against a server on their development machine, reached over the local network. The desktop replays the same photos so the accuracy numbers can be repeated.
**User mental model:** "Before building the scanner, prove the risky parts work on my cards and my phone, and show me the numbers."

## User Stories

### Story 1: OCR strip accuracy on real photos

**As the** maintainer
**I want** to know how well in-browser OCR on the name bar and collector line identifies my real cards from phone photos
**So that** I can decide whether Phase 1's OCR-based scanner is worth building as designed

**Acceptance criteria:**

- [ ] **AC-1.1** Given the maintainer has taken phone photos of English cards When the corpus is assembled Then a ground-truth file lists, for every photo, its file name, the expected card name as the catalog stores it (for example "Aether Vial", not the printed "Æther Vial"), set code, collector number, frame era, whether it is foil, and whether it is borderless or showcase. Frame era is defined by what the printed collector line shows: `pre-M15` (no set code printed), `M15–ONE` (`NNN/TTT R` then `SET • EN`), or `MOM+` (`R NNNN` then `SET • EN`). After excluding ground-truth errors (Error Scenarios), at least 50 photos remain, every era has at least 5 of them, and at least 5 are foil.
- [ ] **AC-1.2** Given the corpus and ground truth When the accuracy run is replayed on the desktop Then, for every photo, it records the raw OCR text of the name strip and the collector strip, the parsed set code and collector number (or "none"), and the printing lookup's outcome: one printing, none, or ambiguous (FR-3). Name candidates come from Story 3's matcher, not from this run.
- [ ] **AC-1.3** Given the recorded results When the findings are written Then they report, overall, per frame era, for foil vs non-foil and for borderless or showcase vs regular frames, each with its sample size: the rate at which the normalised name-strip text equals the normalised catalog name, and, over the `M15–ONE` and `MOM+` photos only, the rate at which the parsed set and number identify the exact printing, with the none and ambiguous outcomes counted separately.
- [ ] **AC-1.4** Given the collector-line prototype When it is given the text `051/302 NEO` (M15–ONE style) Then it yields set NEO and collector number 51, not 302, and the findings show this case among the parser's test inputs.
- [ ] **AC-1.5** Given the same accuracy run is replayed twice on the same machine When the two result sets are compared Then the findings report how many photos' OCR text differs between the runs (with the differing strings) and both runs' rates, and the committed fixture (AC-4.4) states which run it came from.
- [ ] **AC-1.6** Given the maintainer's iPhone in a Safari tab, loading the spike page from the maintainer's development machine over the local network When the OCR engine is loaded cold (browser cache and site storage cleared) and then warm (same tab, second load) Then the findings report the bytes downloaded before the first scan can start, the time from page load to ready, and the median and slowest per-photo recognition time over at least 10 corpus photos.
- [ ] **AC-1.7** Given the recorded results When the findings are written Then every photo whose correct card is not in Story 3's top 3 candidates is listed with its likely cause (glare, blur, misalignment of the fixed strip, unusual frame, parser miss, or matcher miss).

### Story 2: Headless camera testing

**As a** developer of Collector
**I want** to know whether a system test can drive a live-camera page using a known card image, with no person and no physical camera
**So that** Phase 1's scanner can be covered by the automated suite that gates merges (Foundation principle 5)

**Acceptance criteria:**

- [ ] **AC-2.1** Given a throwaway page that shows the camera feed and captures a frame When a system test runs with the project's current headless Firefox driver Then the findings state whether the test can supply a chosen card image as the camera feed, not just a synthetic pattern, and include the exact configuration tried and its result.
- [ ] **AC-2.2** Given a camera feed from a known card image When the captured frame is checked in the test Then the findings state whether the test could assert something specific to that card (its name recognised from the frame, or a pixel or hash comparison against the source image), not merely that a non-blank frame was captured.
- [ ] **AC-2.3** Given the current driver cannot supply a chosen image When alternatives are tried Then the findings compare at least two alternatives (such as a second browser driver used only for camera tests, or replacing the camera feed from within the page in test mode). The comparison states for each whether it works, the extra setup needed on the dev machine and in CI, how it changes suite run time, and any flakiness seen over 10 consecutive runs.
- [ ] **AC-2.4** Given the approach the findings recommend (the current driver if AC-2.1 succeeds, otherwise the chosen alternative from AC-2.3) When it runs 10 times in a row locally Then all 10 runs pass, or the findings record the failure rate and the failure messages.

### Story 3: Fuzzy name index against the real catalog

**As the** maintainer
**I want** to know whether a trigram name index over the local catalog finds the right card from misread names, quickly, and within the app's schema conventions
**So that** Phase 1's matcher can rely on it, or I know what to use instead

Story 3's candidate lists are the ones Story 1's findings use (AC-1.7).

**Acceptance criteria:**

- [ ] **AC-3.1** Given a database holding the index When the schema is dumped and a fresh database is loaded from the dump Then the findings state whether the index, including its tokenizer options, survives the round trip intact, and what the fallback is if it does not.
- [ ] **AC-3.2** Given the full English catalog from a real refresh When the index is built Then the findings report the build time, the index's size on disk, and the number of names indexed. Each distinct full name is indexed, and for multi-face cards each face name as well, de-duplicated.
- [ ] **AC-3.3** Given the name-strip OCR text recorded in Story 1 When each is queried against the index, with candidates re-ranked by a string-similarity measure the findings name Then the findings report the rate at which the correct card is the top candidate and the rate at which it is in the top 3, overall, per frame era, for foil vs non-foil and for borderless or showcase vs regular frames, each with its sample size, plus the median and 95th-percentile query time.
- [ ] **AC-3.4** Given names shorter than 3 characters after normalisation, names with diacritics or ligatures (such as "Æther Vial" and "Lim-Dûl's Vault"), and split, adventure and double-faced cards When each is queried by its printed name and by a one-character misread of it Then the findings report which are found, and propose a fallback for each failing category.
- [ ] **AC-3.5** Given the index must stay consistent with the catalog When the findings are written Then they state how the index would be rebuilt or updated after a catalog refresh, and how long that adds to a refresh.

### Story 4: Findings and Phase 1 recommendation

**As the** maintainer
**I want** one write-up of every spike's evidence and a recommended Phase 1 scope
**So that** I can decide on Phase 1 and hand it straight to `sdd-specify`

**Acceptance criteria:**

- [ ] **AC-4.1** Given all three spikes are complete When the findings are published Then `docs/specs/005-card-scanner-phase-0/research.md` contains, for each spike: the question, the method, the measured results (tables), the failure cases, and a recommendation.
- [ ] **AC-4.2** Given the findings When the maintainer reads the recommendation section Then it states a recommended Phase 1 scope (in, out, and changed from the roadmap) and lists every roadmap assumption that the evidence contradicted.
- [ ] **AC-4.3** Given each technical decision the findings recommend (the OCR engine and its asset hosting, the camera-test approach, the name-index approach) When the findings are published Then each has an ADR at `docs/adr/NNNN-<slug>.md` (four digits, starting at 0001) with the sections Title, Status (`Proposed`), Context, Decision and Consequences. `docs/adr/README.md` states this convention, and each ADR is linked from `research.md`.
- [ ] **AC-4.4** Given the recorded per-photo OCR text and ground truth When Phase 0 is complete Then both are committed as JSON under `spec/fixtures/card_scanner/` (`ground_truth.json` and `ocr_results.json`), one record per photo keyed by file name, holding at least the fields AC-1.1 and AC-1.2 list. No images are committed, and `research.md` documents every field.
- [ ] **AC-4.5** Given Phase 0 is complete When `git diff main --stat` is inspected Then it touches only `docs/`, the spike directory the plan chooses, `spec/fixtures/card_scanner/`, and exclusion lines in `.rubocop.yml` or `.gitignore`. In particular nothing under `app/`, `public/`, `vendor/`, `config/` or `db/` changes, the `Gemfile` is unchanged, and `bin/ci` passes.

## Functional Requirements

### FR-1: Photo corpus

**Must:**
- Hold at least 50 photos of English cards taken with the maintainer's iPhone, covering the eras and finishes listed in AC-1.1.
- Keep photos outside the repository, in a location documented in `research.md` by path convention, not by absolute path.
- Commit a ground-truth file keyed by photo file name (AC-4.4).

**Must not:**
- Commit any photo, crop or derived image to the repository.
- Send any photo or crop to a third-party service. All recognition runs in the browser or on the maintainer's machine.

### FR-2: OCR accuracy run

**Must:**
- Crop the name-bar and collector-line strips at fixed positions relative to a card-shaped guide, as the roadmap describes. The spike does no card detection or perspective correction.
- Load the OCR engine, its worker and its language data from the same origin as the spike page, not a CDN. That origin is a server on the maintainer's machine: the Rails development server on an unmerged branch, or a static file server over the spike directory. The plan chooses which.
- Normalise names identically for the ground truth, the OCR text and the catalog (case, punctuation, Unicode compatibility forms, "Æ" to "ae").
- Record results as described in AC-1.2 in the committed JSON fixture (AC-4.4).

### FR-3: Collector-line prototype

**Must:**
- Parse both the M15–ONE format (`NNN/TTT R` with `SET • EN`) and the MOM and later format (`R NNNN` with `SET • EN`), including promo suffix letters and star or bullet foil markers.
- Accept a parsed set code only if it is a known set code in the catalog.
- Resolve a parsed set, number and language to exactly one catalog printing, or report none, or report ambiguous when more than one printing matches. The findings count each outcome.

### FR-4: Findings

**Must:**
- Report numbers with the sample size they come from.
- Keep throwaway spike code out of the app's load path (for example, under a `spikes/` directory excluded from Zeitwerk and CI, or on an unmerged branch). The plan chooses which.
- Treat the throwaway spike pages as exempt from the design-system rule in `CLAUDE.md`, because no user sees them.

**Must not:**
- Present an estimate as a measurement. Anything not measured is labelled as an estimate.

## Non-Functional Requirements

### Performance

- Phase 0 sets no performance targets. It measures and reports the numbers listed in AC-1.6, AC-3.2, AC-3.3 and AC-3.5.

### Security and privacy

- Photos stay on the maintainer's devices and development machine (FR-1).
- The OCR spike page makes no requests to any host other than its own origin. It is served with a Content Security Policy in which every directive allows only `'self'`, the `blob:` scheme (for the OCR worker), or `'wasm-unsafe-eval'` (to compile the engine), with no other host and violations reported to the page's own origin. OCR still succeeds on one cold iPhone run, which shows no other host was needed. The findings quote the header sent. Where a desktop browser's network log of the same page is available, it is attached as well.
- Any throwaway page, route or asset is absent from the merged code, so it can't reach production (AC-4.5).

### Reliability

- The desktop accuracy run is replayed twice and its run-to-run differences are reported (AC-1.5).
- `bin/ci` passes on the branch at every commit that reaches `main`.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A photo is unreadable (blurred or cropped out of frame) | It stays in the corpus and counts as a failure in the rates, with its cause recorded (AC-1.7). It isn't silently dropped. |
| A ground-truth entry names a card or printing not in the local catalog | The run reports the entry as a ground-truth error and excludes it from the rates, and the findings list it. |
| The iPhone won't grant camera access over plain HTTP on the LAN | On-device timing uses the photo picker with corpus photos, and the findings note it. Live-camera timing is left to Phase 1. |
| Fake-camera injection doesn't work with any tried approach | The findings record each attempt and its failure, and recommend how Phase 1 covers the camera path instead (for example, testing the post-capture flow from a supplied image). |
| Two desktop replays give different OCR text for some photos | Both runs are kept. The findings report the number of differences and their likely cause. Phase 1 treats the committed fixture as one run's output, not canonical truth. |
| The trigram index doesn't survive the schema round trip | The findings recommend a fallback (such as a SQL-format schema dump, or building the index outside the schema) with its trade-offs. |

## Open Questions

None. Resolved during specification:
- Deliverable: findings and ADRs; no spike code merges into the app.
- Spikes: OCR strip accuracy, headless camera testing, fuzzy name index. The `sdd-init` spike is dropped as already answered, and art-hash search speed moves to Phase 2.
- Corpus: 50+ English photos. Japanese is deferred to Phase 2.
- Go bar: the spike reports only, and the maintainer decides from the numbers.
- Device: the maintainer's iPhone in a Safari tab, plus desktop replay for repeatable accuracy.
- Photo storage: outside the repository.
- From the spec review (v1.1.0): where the spike page is served (the plan chooses), how "no third-party hosts" is shown (a self-only Content Security Policy), and the ADR and fixture conventions.

## Out of Scope (Future Considerations)

- Japanese OCR accuracy and short-name CJK fallback (Phase 2).
- Art-hash index, `illustration_id` in the catalog, and Hamming search speed (Phase 2).
- Rectification via OpenCV.js or a Python accessory (Phase 2).
- Live-camera HTTPS setup for on-device development (Phase 1 plan).
- Scan data model (`scan_sessions`, `scan_attempts`), image retention policy and the confirm-to-collection flow (Phase 1).
- Hotwire Native iOS (Phase 3), bulk scanning (Phase 4), Android (Phase 5).
