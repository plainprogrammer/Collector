# Feature 008: Card Scanner Phase 2 Spike — Card Detection and Art Matching

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-10-02
**Last Updated:** 2026-10-02
**Branch:** `008-card-scanner-phase-2-spike`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-02 | Initial spec, formalized from [prd.md](prd.md) |

---

## Problem Statement

Phase 1 (spec 007) showed that lining a card up with a live guide makes the scanner usable. On 49 cards that played no part in tuning, the right card was first for 42 and in the top 3 for 45, and the collector line gave the exact printing for 34 of the 44 cards that print a set line ([research.md](../007-card-scanner-live-capture/research.md) §5). Three weaknesses remain that reading text can't fix on its own:

- **The photo path fails without the guide.** Photos of the same 49 cards, taken without the guide, had the right card in the top 3 for 2 of 49. Phase 0's 50 photos reached 24 of 50 through the same path.
- **Careless live framing.** 3 of the 4 live misses were a name cut off at the strip's edge.
- **Printings the text can't identify.** Older frames print no set code (5 of the 49 cards), and foil collector lines are faint (exact printing for 4 of 10 foils).

The scanner roadmap (`~/Downloads/card-scanner-research-and-roadmap.md`, "Phase 2 – Precision") proposes two techniques for these: **card detection** (find the card's edges and straighten it before reading) and **art matching** (compare a fingerprint of the artwork with an index of every artwork). Neither has been tried in this project. Their accuracy, their download size, and the cost of building an art index on a self-hosted instance are unmeasured. This spike measures both on the photos already stored, so the next spec (009: the scan → confirm → add flow) is scoped from evidence.

> **Constraints.** A spike tests specific proposed techniques, so those techniques are fixed inputs, the way the stack is:
> - **Detection:** two in-browser detectors, one built on OpenCV.js and one hand-written with no dependency.
> - **Art matching:** the published fingerprint the roadmap describes (a crop of the art region, four 256-bit difference-hash planes for 1,024 bits, six query offsets), with an index the spike builds itself.
> - **Where recognition runs:** in the browser only ([ADR 0004](../../adr/0004-card-recognition-in-the-browser.md)). Phase 2 keeps spec 007's privacy guarantee (no frame, strip or photo leaves the device in normal use) and adds nothing a self-hoster has to run.
> - **Data:** the stored photos only, on the desktop. No device run and no new card captures (maintainer ruling, 2026-10-02).
>
> The requirements below state the questions and the evidence required. The plan decides how each is run.

> **Phase 2's shape** (maintainer rulings, 2026-10-02). Phase 2 is two specs: this spike, then spec 009, the confirm flow with the reading refinements plus whichever of detection and art matching the spike supports. Detection is inside Phase 2, which replaces the ruling made earlier the same day that it waits for a later phase. Japanese and other languages stay out of Phase 2.

## Goals

- The detection question is answered with measured numbers: can an in-browser detector find and straighten the card in a photo taken without the guide, well enough that the shipped reading chain works on it?
- The art-matching question is answered with measured numbers: can a fingerprint of the artwork, computed in the browser from the straightened card, pick out the right artwork among every artwork in the catalog, and what does it add to reading text?
- The costs are measured: each detector's download size and desktop time per photo, the art index's build cost and size, and the cost of searching it in the browser and on the server.
- The measure is unbiased: settings are tuned on a development half of the photos, frozen, and then measured once on a held-out half.
- The maintainer can rule on spec 009's scope from the findings: for each of detection and art matching, a recommendation to build it with the confirm flow, defer it, or drop it. The spike sets no pass threshold.
- Each recommended technique is recorded as a Proposed ADR, and the runs' text and numbers are committed as fixtures, so spec 009 can be planned and re-scored without repeating the spike.
- The straightened cards and their strips are kept outside the repository, so spec 009 can tune the reading refinements on them without cards.

## Non-Goals

- Any change to the app or to what it serves: nothing under `app/`, `config/`, `db/`, `lib/`, `public/`, `script/` or `vendor/` changes, there is no schema change, and the `Gemfile` is unchanged (AC-5.6 lists what may change).
- The scan → confirm → add flow, the reading refinements, and a navigation entry for the scanner (spec 009).
- Any run on a phone, and any figure for download time or time per frame on a phone.
- New card captures, live frames, or hand-marked card corners.
- Server-side processing of collectors' pictures (ADR 0004).
- Japanese and other non-English cards, bulk or continuous scanning, native apps.
- Art fingerprints for the back faces of double-faced cards.
- Embedding-based matching, or any technique beyond the two detectors and the one fingerprint named in the constraints.
- A pass threshold, and the decision on spec 009's scope. The findings recommend; the maintainer rules.

## Users and Context

**Primary users:** The maintainer, who approves the artwork fetch, reads the findings and rules on spec 009's scope.
**Secondary users:** Claude Code sessions that write spec 009 and its plan from the findings and reuse the fixtures. Collectors and self-hosters are not affected: nothing they use or run changes.
**Usage context:** Everything runs on the maintainer's development machine, in a headless desktop browser driving real browser code, as spec 007's photo replay did. The inputs:

- **99 stored photos** by manifest, outside the repository in `~/card-scanner-corpus/`: Phase 0's 50 (the card fills 69–77% of the frame height, hand-held) and the new corpus's 49 in `phase1-live/` (the card fills about 95%). Each corpus has a manifest and ground truth. No photo was taken with the guide.
  - All display as 3024×4032 portrait. Phase 0's files are stored that way (EXIF orientation 1). The new corpus's are stored as 4032×3024 with EXIF orientation 6, so every tool that reads them must apply the EXIF rotation.
  - `phase1-live/` also holds 2 photos whose rows were dropped from its manifest. They aren't used.
- **The shipped reading chain**, frozen at commit `c68ffbd`: guide-relative strips, on-device text recognition, the collector-line parser and the matcher. `script/scanner/photo_run.rb` drives it through development-only measurement mode, which takes its manifest and run directory from the environment.
- **Committed baselines** in `spec/fixtures/card_scanner/`: the same 99 photos through the shipped photo path (`phase1_photos_*`, `phase1_live_photos_*`), and the new corpus's live captures (`phase1_live_*`).
- **The Scryfall bulk file** the catalog is built from, kept by the app under `storage/catalog/mtg/`. The catalog doesn't store artwork ids, so spike scripts read them from the bulk file at run time. (Claude Code sessions are denied direct reads of `storage/`; running a script that reads it is fine.)
- **Spike code** lives under `spikes/card_scanner/`, beside Phase 0's.

**User mental model:** "Before building detection or art matching into the scanner, show me on the photos I already have what each one fixes and what it costs."

## User Stories

### Story 1: An unbiased measure

**As the** maintainer
**I want** the photos split into a development half and a held-out half before any tuning
**So that** the headline rates aren't inflated by tuning on the cards being measured, as spec 007's tuning cards were

**Acceptance criteria:**

- [ ] **AC-1.1** Given the two manifests When the split is made, before any detector or fingerprint work starts Then, within each corpus, the foil rows and the non-foil rows are each taken in manifest order (data rows, not counting the header) and alternated, the first to development and the second held out. The result is 51 development photos (26 Phase 0, 25 new; 11 foils) and 48 held-out photos (24 Phase 0, 24 new; 9 foils), and the list of files in each half is committed before the first tuning commit.
- [ ] **AC-1.2** Given the split When detector and fingerprint settings are tuned Then only development photos are run, and no held-out photo is run through any detector or fingerprint before the settings are frozen.
- [ ] **AC-1.3** Given tuning is finished When the settings are frozen Then one commit holds them, and the findings name that commit and state which detector feeds art matching: the one with the better development-half rate for the right card in the top 3, or on a tie the one with the smaller download (AC-3.1).
- [ ] **AC-1.4** Given the frozen settings When the held-out photos are run Then each measurement is run once at that commit, its rates are the findings' headline, and the development half's rates are reported beside them, labelled as biased.
- [ ] **AC-1.5** Given a held-out run fails for a reason unrelated to the settings (a crash, a lost connection) When it is run again Then it is run at the same frozen commit, and the findings say that it was repeated and why.
- [ ] **AC-1.6** Given the apparatus is new When the first run is attempted Then five development photos, at least two from each corpus, have gone through the whole chain first (detection, straightening, the shipped reading chain, the fingerprint, the index search), and the findings record what the pilot changed.

### Story 2: Card detection on stored photos

**As the** maintainer
**I want** to know whether an in-browser detector can find and straighten the card in a photo taken without the guide
**So that** I can decide whether detection is worth building into the scanner, and which detector

**Acceptance criteria:**

- [ ] **AC-2.1** Given a stored photo When each detector runs on it in the browser Then it either reports no card, or produces a straightened image of the card. The straightened card is presented to the shipped photo path framed as the guide expects, so the shipped strips, text recognition, parser and matcher run on it unchanged (commit `c68ffbd`).
- [ ] **AC-2.2** Given the held-out photos and the frozen settings When the findings are written Then, for each detector, they report the rates spec 007 reported (right card first and in the top 3 of the final ranking, right card in the name-only top 3, exact printing over the set-line cards, and the lookup outcomes), using spec 007's scoring (`Collector::ScannerFindings`), each with its sample size, for each corpus separately and for both together, and by era, foil and frame treatment.
- [ ] **AC-2.3** Given the same held-out photos When the rate tables are laid out Then each table has a baseline column: the same photos through the shipped photo path, taken from the committed fixtures. For the new corpus's held-out cards, the tables also show the live capture's rates on the same cards, taken from spec 007's committed fixtures.
- [ ] **AC-2.4** Given every photo each detector was run on When the findings are written Then each photo is classed, for each detector, as **found** (the straightened image shows the whole card and nothing else fills it), **not found** (the detector reported no card) or **wrong outline** (the detector straightened something that isn't the whole card). The classes are judged by eye from a contact sheet of the straightened images, the counts are reported per corpus and per half, and the contact sheets are kept outside the repository where the maintainer can check them.
- [ ] **AC-2.5** Given a photo where a detector reports no card or a wrong outline When the rates are computed Then the photo counts as a miss for that detector. It isn't dropped from the sample.
- [ ] **AC-2.6** Given Phase 0's photos, in which the card fills about as much of the frame as the guide asks for When each detector is run on them scaled down so the whole photo is 1080×1440 Then the findings report the same rates as AC-2.2 in a separate table, labelled as a stand-in for a live frame and not a measure of live capture.
- [ ] **AC-2.7** Given each detector's files When they are served the way the app serves the text-recognition engine Then the findings report, for each detector, the number of files, their total size as stored and as compressed for transfer, and the licence of every third-party component with a statement of whether it is compatible with the project's AGPL-3.0 licence.
- [ ] **AC-2.8** Given each detector running on the page When the page is served with the scanner page's current Content Security Policy Then the findings state whether the detector works under it, and if not, exactly which directive would have to be widened and by what.
- [ ] **AC-2.9** Given the runs on the desktop When the findings are written Then they report each detector's median and slowest time per photo for detection and straightening, at full size and at the scaled-down size, labelled as desktop figures.
- [ ] **AC-2.10** Given the development photos When each detector is replayed twice at the frozen settings Then the findings report how many photos' outcomes differ between the two replays.
- [ ] **AC-2.11** Given the held-out photos When the findings are written Then every photo whose right card is not in the final top 3 for the chosen detector is listed with its file, its expected card, its detection class, what was read, and its likely cause.

### Story 3: Art matching on stored photos

**As the** maintainer
**I want** to know whether a fingerprint of the artwork identifies the card where reading text fails
**So that** I can decide whether art matching is worth building, given what its index costs every self-hoster

**Acceptance criteria:**

- [ ] **AC-3.1** Given the straightened cards from one detector, the one with the better development-half rate for the right card in the top 3 When art matching runs Then the fingerprint is computed in the browser from the straightened card's art region and compared with every fingerprint in the index (AC-4.1), trying the six query offsets and keeping the smallest distance.
- [ ] **AC-3.2** Given the held-out photos and the frozen settings When the findings are written Then they report the rate at which the right artwork (the artwork id of the ground-truth printing) ranks first, and the rate at which it is in the top 3, each with its sample size, for each corpus separately and for both together, and by era, foil and frame treatment.
- [ ] **AC-3.3** Given a photo where the chosen detector found no card or a wrong outline When the art-matching rates are computed Then the photo counts as a miss, and the rates over the found photos only are shown beside the rates over all photos.
- [ ] **AC-3.4** Given each held-out photo's ranked artworks When the findings are written Then they report the distance to the right artwork and the distance to the nearest wrong artwork, as a table per photo and as a summary (the median of each, and the number of photos where the right artwork is nearer than every wrong one).
- [ ] **AC-3.5** Given the held-out photos' text results on the same straightened cards When the findings are written Then they report: the number of photos where the right card is not in the text path's final top 3; of those, the number where art matching ranks the right artwork first; and the number of photos where the right card is in the text path's top 3 or is art matching's first choice.
- [ ] **AC-3.6** Given the held-out cards whose collector line did not give the exact printing (including every card whose frame prints no set code) When the findings are written Then, for each, they report the number of English printings that share the card's name and the number that share its artwork, with the median of each and the number of cards whose artwork belongs to exactly one printing.
- [ ] **AC-3.7** Given the runs on the desktop When the findings are written Then they report the median and slowest time to compute one photo's fingerprint in the browser, the time to search the full index in the browser, and the time to search it on the server for a fingerprint sent by the browser, labelled as desktop figures.
- [ ] **AC-3.8** Given the held-out photos When the findings are written Then every photo whose right artwork is not ranked first is listed with its file, its expected card, the artwork ranked first, both distances, and its likely cause.

### Story 4: The art index and its cost

**As the** maintainer
**I want** to know what building and shipping an index of every artwork costs
**So that** I can weigh art matching against the load it puts on every self-hosted instance's catalog refresh

**Acceptance criteria:**

- [ ] **AC-4.1** Given the Scryfall bulk file When the index is built Then it holds one fingerprint for each distinct front-face artwork id among the English entries, from one image per artwork. The findings state the bulk file's version, the number of English entries, the number of distinct artworks, which printing's image and which image size stood for each artwork, and the number of English entries that have no artwork id.
- [ ] **AC-4.2** Given no artwork has been fetched When the fetch starts Then 500 artworks are fetched first, and the cost of the full fetch is extrapolated from them: the number of images, the bytes, and the time at the throttled rate. The estimate is shown to the maintainer, and the full fetch starts only after the maintainer approves it. The approval is recorded in the findings with its date.
- [ ] **AC-4.3** Given the maintainer declines the full fetch When the index is built Then it covers a subset that contains the artwork of all 99 corpus cards. The findings name the subset and its size, and label every art-matching rate as measured against that subset.
- [ ] **AC-4.4** Given the index is built When the findings are written Then they report the build's measured cost: images fetched, bytes downloaded, fetch time, fingerprinting time, and the index's size as stored and as compressed for transfer.
- [ ] **AC-4.5** Given the index-build tool When the findings are written Then they name it, confirm it could run in the app's own container at catalog refresh (it is not a browser), and state what it would add to the app's container image and to a development machine's setup.
- [ ] **AC-4.6** Given the index build and the browser compute fingerprints with different code When the same source image is fingerprinted by both, for at least 100 artworks that include every corpus card's artwork Then the findings report the distance between the two fingerprints of each image (the median and the largest), beside the distances AC-3.4 reports, and state whether the disagreement is small enough to match across the two.
- [ ] **AC-4.7** Given requests to Scryfall When images are fetched Then every request carries a descriptive `User-Agent`, requests are at least 100 ms apart, each has explicit open and read timeouts, and a 429 response is answered by backing off. Images already fetched are kept outside the repository and are not fetched again by a re-run.
- [ ] **AC-4.8** Given an image that can't be fetched after the retries When the index is built Then the artwork is left out, the findings report the number left out, and any corpus card whose artwork is left out is named and counts as an art-matching miss.

### Story 5: Findings, recommendation and reusable data

**As the** maintainer
**I want** one write-up of the evidence with a recommended scope for spec 009
**So that** I can rule on what Phase 2 builds and hand the result straight to `sdd-specify`

**Acceptance criteria:**

- [ ] **AC-5.1** Given both questions are answered When the findings are published Then `docs/specs/008-card-scanner-phase-2-spike/research.md` contains, for detection and for art matching: the question, the method, the measured results as tables, the misses, the costs, and a recommendation. Every rate carries its sample size.
- [ ] **AC-5.2** Given the findings When the maintainer reads the recommendation Then, for each of detection and art matching, it gives one of build with the confirm flow, defer, or drop, with the evidence for and against, and it lays out the options for the maintainer's ruling without setting a pass threshold.
- [ ] **AC-5.3** Given the findings When they list what was not measured Then that list includes every figure for a phone (download time, time per frame) and the effect on real live captures, and nothing in the findings presents an estimate for them as a measurement.
- [ ] **AC-5.4** Given each technique the findings recommend building (which detector, the fingerprint and the index's design, where the search runs) When the findings are published Then each has an ADR in `docs/adr/` with status `Proposed`, following `docs/adr/README.md`, and each is linked from `research.md`. A technique the findings recommend dropping gets no ADR.
- [ ] **AC-5.5** Given the runs When the spike is complete Then their text and numbers are committed as JSON under `spec/fixtures/card_scanner/` with the prefix `phase2_`, one record per photo keyed by manifest file name, holding which half the photo is in, each detector's class and results, and the art-matching ranks and distances. `research.md` documents every field. No photo, straightened card, strip, fetched artwork or index is committed.
- [ ] **AC-5.6** Given the spike is complete When `git diff main --stat` is inspected Then it touches only `docs/`, `spikes/card_scanner/`, `spec/fixtures/card_scanner/`, `.claude/memory/`, and exclusion lines in `.rubocop.yml` or `.gitignore`. Nothing under `app/`, `config/`, `db/`, `lib/`, `public/`, `script/` or `vendor/` changes, the `Gemfile` and `Gemfile.lock` are unchanged, and `bin/ci` passes.
- [ ] **AC-5.7** Given the held-out and development runs When the spike is complete Then every straightened card and both of its strips are kept under `~/card-scanner-corpus/runs/`, in a directory per run that the findings name, with the detector and the settings commit that produced them.

## Functional Requirements

### FR-1: Photos and the split

**Must:**
- Use the 99 photos listed in the two manifests, and their committed ground truth.
- Apply each photo's EXIF orientation in every tool that reads it.
- Split the photos as AC-1.1 describes, and commit the split before tuning.

**Must not:**
- Run a held-out photo through a detector or the fingerprint before the settings are frozen.
- Commit any photo or any image derived from one.
- Send any photo, or any image derived from one, to another host. Detection, straightening and the query fingerprint run in the browser on the maintainer's machine.

### FR-2: Detection run

**Must:**
- Run both detectors in a browser, loaded from the spike page's own origin, not a CDN.
- Feed each straightened card through the shipped reading chain at commit `c68ffbd`, using the shipped measurement tooling as it stands.
- Score every run with spec 007's scoring and rate definitions, so the figures compare directly with specs 005 and 007.
- Treat the card as upright in the photo: neither detector has to work out which way up the card is.

**Must not:**
- Change the strips, the text recognition settings, the parser or the matcher. Reading refinements belong to spec 009.
- Mark card corners by hand, as ground truth or as an aid to a detector.

### FR-3: Art index

**Must:**
- Build the index from the bulk file's artwork ids and from images on Scryfall's image hosts, as AC-4.1 and AC-4.7 describe.
- Build it outside the browser, with a tool the app could run in its own container.
- Keep fetched images and the index outside the repository.

**Must not:**
- Start the full fetch before the maintainer has approved the estimate (AC-4.2).
- Add an artwork id, or anything else, to the catalog's schema.

### FR-4: Art-matching run

**Must:**
- Compute each query fingerprint in the browser, from the card straightened by the detector chosen at the freeze.
- Search the whole index for every query, in the browser and on the server, and time both.
- Read each ground-truth printing's artwork id from the bulk file.

### FR-5: Findings

**Must:**
- Report every number with the sample size it comes from, and label every desktop timing as a desktop figure.
- Keep spike code under `spikes/card_scanner/`, outside the app's load path.
- Treat throwaway spike pages as exempt from the design-system rule in `CLAUDE.md`, because no user sees them.

**Must not:**
- Present an estimate as a measurement.
- Recommend moving recognition to the server. If neither in-browser detector is good enough, the recommendation is to defer or drop (ADR 0004).

## Non-Functional Requirements

### Performance

- The spike sets no performance targets. It measures and reports the figures in AC-2.7, AC-2.9, AC-3.7, AC-4.2 and AC-4.4.

### Security

- Photos, straightened cards, strips, fetched artwork and the index stay on the maintainer's machine, outside the repository.
- The spike page loads nothing from a third-party host. Scryfall is contacted only by the index-build scripts, never by the page.
- Requests to Scryfall follow `.claude/rules/external-data-and-portability.md` (AC-4.7).
- Nothing the spike adds is reachable in production: no spike page, route or asset is under a path the app serves (AC-5.6).

### Reliability

- The detectors' run-to-run differences are reported (AC-2.10).
- A re-run fetches no image twice (AC-4.7), and a failed held-out run is repeated only at the frozen commit (AC-1.5).
- `bin/ci` passes on the branch at every commit that reaches `main`.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A detector reports no card, or straightens the wrong outline | The photo stays in the sample and counts as a miss for that detector, with its class recorded (AC-2.4, AC-2.5). |
| A detector's files won't load or run in the headless browser | The findings record what was tried and the error. That detector is reported as not working, and the other detector's run goes ahead. |
| Neither detector works | The findings say so and recommend deferring or dropping detection. Art matching is then measured on cards straightened by whichever detector found the most development photos, or reported as not measurable if neither found any, with the reason. |
| A new-corpus photo is read without its EXIF rotation | The pilot includes photos from both corpora (AC-1.6), so this shows before the full run. The tool is fixed before any measured run. |
| Scryfall answers 429 or times out | The fetch backs off and retries. An image still missing after the retries is left out and counted (AC-4.8). |
| A ground-truth printing has no artwork id in the bulk file | The card is excluded from the art-matching rates, and the findings list it. |
| The maintainer declines the full fetch | The index covers a named subset that includes every corpus card's artwork, and the rates are labelled as measured against it (AC-4.3). |
| The bulk file is newer than the one the committed ground truth was built from | The findings state both versions. A corpus card whose printing is missing from the newer file is listed as a ground-truth error and excluded from the rates. |
| A held-out run is interrupted | It is repeated at the frozen commit, and the findings say so (AC-1.5). |
| The two fingerprint computations disagree by more than the gap between the right and the nearest wrong artwork | The findings report it as a blocker for building the index with that tool, and recommend what would have to change before art matching could be built. |

## Open Questions

None. Resolved during the brainstorm (2026-10-02, maintainer):

- Phase 2 is a spike (008) and then the confirm flow (009). Detection and art matching are in Phase 2; Japanese is out.
- The spike uses the stored photos only, on the desktop.
- Recognition runs in the browser only (ADR 0004).
- The photos are halved with foils balanced; held-out rates are the headline; no pass threshold.
- The art index covers front faces only, and the full artwork fetch needs the maintainer's approval after a 500-artwork estimate.
- The detector that feeds art matching is the one with the better development-half rate, and a failed detection counts as an art-matching miss.

## Out of Scope (Future Considerations)

- The scan → confirm → add flow and the reading refinements (spec 009). The maintainer's decisions for it are recorded in [prd.md](prd.md), "Decisions carried to spec 009", so that spec doesn't ask again.
- Phone figures for detection and art matching, and their effect on real live captures (spec 009's live sitting).
- An artwork id in the catalog, and building the index during the catalog refresh (spec 009, if art matching is built).
- Amending spec 007 FR-3 to allow a fingerprint to be sent (spec 009, if the search runs on the server; ADR 0004).
- Server-side straightening or fingerprinting of collectors' pictures (ruled out by ADR 0004; needs a superseding ADR).
- Back-face artwork, Japanese and other languages, embedding-based matching.
- Storing what the scanner read on each capture as a tuning dataset (the roadmap's feedback loop).
- Bulk or continuous scanning, and native apps.
