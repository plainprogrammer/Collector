# PRD: Card Scanner Phase 2 Spike — Card Detection and Art Matching

**Date:** 2026-10-02
**Feature:** 008-card-scanner-phase-2-spike

## Problem

Phase 1 (spec 007) showed that lining a card up with a live guide makes the scanner usable: on 49 cards that played no part in tuning, the right card was first for 42 and in the top 3 for 45, and the collector line gave the exact printing for 34 of the 44 cards that print a set line ([research.md](../007-card-scanner-live-capture/research.md) §5). Three weaknesses remain that reading text can't fix on its own:

- **The photo path fails without the guide.** Photos of the same 49 cards, taken without the guide, had the right card in the top 3 for 2 of 49. Phase 0's 50 photos reached 24 of 50 through the same path. The strips are cut at fixed positions, so they miss whenever the framing differs from the guide's.
- **Careless live framing.** 3 of the 4 live misses were a name cut off at the strip's edge.
- **Printings the text can't identify.** Older frames print no set code (5 of the 49 cards), and foil collector lines are faint (exact printing for 4 of 10 foils). For these the scanner can name the card but not the printing.

The scanner roadmap (`~/Downloads/card-scanner-research-and-roadmap.md`) proposes two techniques for these, under "Phase 2 – Precision": **card detection** (find the card's edges and straighten it before reading) and **art matching** (compare a fingerprint of the artwork with an index of every artwork). Neither has been tried in this project. Their accuracy, download size, and the cost of building an art index on a self-hosted instance are all unmeasured.

Building either into the scan → confirm → add flow before measuring it would repeat the risk Phase 0 was created to avoid. This spike measures both on the photos already stored, so that the next spec (009) is scoped from evidence.

### How Phase 2 is shaped (maintainer rulings, 2026-10-02)

- **Phase 2 is two specs.** Spec 008 is this spike. Spec 009 is the scan → confirm → add flow with the reading refinements, plus whichever of detection and art matching the spike supports.
- **Detection is inside Phase 2.** This replaces the ruling made earlier the same day that detection waits for a later phase.
- **Japanese and other languages stay out of Phase 2.**

## Users & Context

**Primary user:** the maintainer, who reads the findings and rules on spec 009's scope.

**Secondary users:** Claude Code sessions that write spec 009 from the findings. Collectors and self-hosters are not affected by this spec: nothing they use or run changes.

**What the spike works with:**

- **99 stored photos** by manifest, outside the repo in `~/card-scanner-corpus/`: Phase 0's 50 (the card fills 69–77% of the frame height, hand-held) and the new corpus's 49 in `phase1-live/` (the card fills about 95% of the frame height). Each corpus has a manifest and ground truth. No photo was taken with the guide.
  - All 99 display as 3024×4032 portrait. Phase 0's files are stored that way (EXIF orientation 1). The new corpus's are stored as 4032×3024 with EXIF orientation 6, so every tool that reads them must honour the EXIF rotation. (Checked with `magick identify` on 2026-10-02; spec 007's research.md §2, which had the two the other way round, was corrected the same day.)
  - `phase1-live/` also holds 2 photos whose rows were dropped from its manifest. They aren't used.
- **No stored live frames.** The live runs kept only the two strips per capture, so live capture can't be replayed through a detector.
- **The shipped reading chain**, frozen at commit `c68ffbd`: guide-relative strips, on-device OCR, the collector-line parser and the matcher, driven on the desktop by `script/scanner/photo_run.rb` in headless Firefox through development-only measurement mode.
- **Baselines already committed** as text fixtures in `spec/fixtures/card_scanner/`: the same 99 photos through the shipped photo path.
- **The Scryfall bulk file** the catalog is built from, kept by the app under `storage/catalog/mtg/`. The catalog doesn't store artwork ids, so spike scripts read them from the bulk file at run time. (Claude Code sessions are denied direct reads of `storage/`; running a script that reads it is fine.)
- **Spike code** lives under `spikes/card_scanner/`, beside Phase 0's.

**Constraints:**

- Everything runs on the desktop. There is no device run and no new card capture (maintainer ruling).
- Phase 2 keeps spec 007's privacy guarantee (no frame, strip or photo leaves the device in normal use) and adds nothing a self-hoster has to run. Recognition therefore runs in the browser only ([ADR 0004](../../adr/0004-card-recognition-in-the-browser.md)).
- No Node toolchain, as for the rest of the app.
- The spike may use tools that aren't in the app's bundle, kept under `spikes/` or outside the repo, as Phase 0 did with its OCR engine. The `Gemfile` doesn't change.
- Requests to Scryfall follow `.claude/rules/external-data-and-portability.md`: a descriptive `User-Agent`, throttling, and explicit timeouts.

## Goals

1. **Answer the detection question with measured numbers.** Can an in-browser detector find and straighten the card in a photo taken without the guide, well enough that the shipped reading chain works on it?
   - Two detectors are compared: one built on OpenCV.js, and a small hand-written one with no dependency.
   - Each photo is detected and straightened, then goes through the shipped reading chain unchanged, and is scored with the rate definitions specs 005 and 007 used (`Collector::ScannerFindings`).
   - The rates are reported beside the same photos' baseline through the shipped photo path, and beside the live figures from spec 007.
   - Each detector's download size is measured in bytes over the wire, and its time per photo on the desktop.
   - Phase 0's photos are also run scaled down to the size of a live frame (about 1080×1440), reported separately and labelled as a stand-in for live capture, not a measure of it.
2. **Answer the art-matching question with measured numbers.** Can a fingerprint of the artwork, computed in the browser from the straightened card, pick out the right artwork among every artwork in the catalog?
   - The technique under test is the published fingerprint the roadmap describes: a crop of the art region, four 256-bit difference-hash planes (1,024 bits), and six query offsets.
   - The spike builds its own index: one fingerprint per distinct front-face artwork id among the English entries in the bulk file (not one per entry). It records what building it costs: images fetched, bytes, time, and index size.
   - The index is built outside the browser, with a tool the app could run in its own container at catalog refresh. The plan chooses the tool. The findings name it and say what it would add to the app's image.
   - Art matching runs on the cards straightened by one detector: the one with the better development-half rates, chosen when the settings are frozen. A photo where that detector finds no card counts as an art-matching miss. The rate over detected photos only is shown beside it.
   - For each photo: whether the right artwork ranks first and in the top 3, and the distance gap to the nearest wrong artwork.
   - What art adds to text: how many photos the text path missed (right card not in its top 3) that art matching gets right, and, for cards with no exact printing from the collector line, how many printings share the card's name against how many share its artwork.
   - Whether fingerprints computed at index build and in the browser agree closely enough to match, since the two are computed by different code.
   - The cost of each place the search could run: the index as a browser download, and a server-side search of a fingerprint sent by the browser.
3. **Keep the measure unbiased.**
   - Each corpus is halved before any work starts, balanced on foil (maintainer ruling, 2026-10-02). Within each corpus, the foil rows and the non-foil rows are each taken in manifest order (data rows, not counting the header) and alternated: the first to development, the second held out, and so on.
   - That gives 51 development photos (26 Phase 0, 25 new; 11 foils) and 48 held out (24 Phase 0, 24 new; 9 foils). A plain odd-and-even split was rejected because it put 15 of the 20 foils in the held-out half.
   - Detector and fingerprint settings are tuned on the development half only, then frozen at a commit.
   - The held-out half is run once at the frozen settings. Its rates are the headline. The development half's rates are reported beside them, labelled as biased.
4. **Produce findings spec 009 can be written from:** a recommended scope (for each of detection and art matching: build with the confirm flow, defer, or drop), the options for the maintainer's ruling, every held-out miss with its likely cause, and what stayed unmeasured.
5. **Record the recommended techniques as Proposed ADRs** (which detector, the fingerprint and index design, where the search runs), for spec 009's plan to accept or revise.
6. **Keep reusable data.** Straightened cards and their strips are kept outside the repo in `~/card-scanner-corpus/runs/`, so spec 009 can tune the reading refinements on them. Text and numbers are committed as fixtures.

## Non-Goals

- Any change to the app: nothing under `app/`, `config/`, `db/`, `public/` or `vendor/` changes, there is no schema change, and no `Gemfile` change.
- The scan → confirm → add flow, the reading refinements, and a navigation entry for the scanner (spec 009).
- Any run on a phone, and any figure for download time or time per frame on a phone.
- New card captures, live frames, or hand-marked card corners.
- Server-side processing of collectors' pictures (ADR 0004).
- Japanese and other non-English cards, bulk or continuous scanning, native apps.
- Art fingerprints for back faces of double-faced cards.
- Embedding-based matching (the roadmap's DINOv2 option) or any technique beyond the two detectors and the one fingerprint named above.
- A pass threshold. The findings report the numbers and the maintainer decides.
- Deciding spec 009's scope. The findings recommend; the maintainer rules.

## Success Criteria

- **Detection:** the findings give, for each detector, the held-out rates (right card first, in the top 3, exact printing) with sample sizes, beside the baseline for the same photos, for each corpus separately and together.
- **Detection outcome per photo:** every photo is classed as found, not found or wrong outline, judged from a contact sheet of the straightened cards.
- **Art matching:** the findings give the held-out rates for the right artwork first and in the top 3, the gap to the nearest wrong artwork, and the two "what art adds to text" figures, each with its sample size.
- **Costs:** download bytes for each detector, the index's build cost and size, and desktop timings are measured. Anything not measured (all phone figures, real live capture) is listed as unmeasured, not estimated.
- **Bias control is verifiable:** the split is written down before tuning starts, the settings commit is named, and the held-out run happens after it.
- **A recommendation the maintainer can rule on:** one of build, defer or drop for each technique, with the evidence for and against.
- **Proposed ADRs** exist for each recommended technique.
- **Nothing the app serves has changed,** and `bin/ci` passes.
- **No image is committed.** Photos, straightened cards, strips, fetched artwork and the index stay outside the repo.

## Architecture Decisions

- [0004: Card recognition runs in the browser only](../../adr/0004-card-recognition-in-the-browser.md) — detection, straightening and fingerprinting happen on the collector's device and only text or a fingerprint reaches the app, which keeps spec 007's privacy guarantee and adds nothing for self-hosters to run. The roadmap's server sidecar is ruled out, so the spike tests in-browser techniques only.

Decisions that don't need an ADR, with the reason:

- **The phase's shape** (spike first, then the confirm flow) is a planning ruling, recorded above and in the project memory.
- **The method** (the held-out split, the fetch checkpoint, stored photos only) is how this spike is run and binds nothing after it.
- **Which detector, which fingerprint and index design, and where the search runs** are what the spike is for. They become Proposed ADRs from its findings (Goal 5).

## Out of Scope

Discussed during the brainstorm and excluded:

- **An iPhone cost check** (opening a test page on the phone for the real download size and time per frame). The maintainer chose stored photos only; phone figures wait for spec 009's live sitting.
- **Fresh live frames** of cards the maintainer owns, stored through measurement mode. Excluded for the same reason, and because it needs an app change inside a spike.
- **Testing server-side techniques side by side** with in-browser ones (ADR 0004, Option C).
- **Building the confirm flow first** and spiking afterwards, and **building detection first**. The maintainer chose to spike both unknowns before building.
- **Storing what the scanner read** on each capture as a tuning dataset (the roadmap's feedback loop). The maintainer chose to store only the cards added; see below.
- **Japanese and other languages.**

## Method agreed in the brainstorm

These bind the spec. The plan decides the rest.

- **Where it runs:** in headless Firefox on the desktop, driving real browser code, as spec 007's photo replay did.
- **Isolating what detection adds:** everything after straightening is the shipped code at `c68ffbd`. The straightened card is presented to the shipped photo path the way the guide expects, so the app's code is used but not changed. Any difference from the baseline is then the detector's.
- **Judging detection:** end to end by the rate tables, and by eye from the contact sheet. No card corners are marked by hand.
- **Fetching artwork in two steps:** fetch 500 artworks and extrapolate the full cost in images, bytes and time. The maintainer sees the estimate, and the full fetch goes ahead only on their approval. If they decline, the index is built over a subset that contains the artwork of all 99 corpus cards. The findings name the subset and its size, and label the art-matching rates as measured against it.
- **Pilot first:** five photos from the development half go through the whole chain before the full run.
- **Timings** are desktop figures and are labelled as such.

## Decisions carried to spec 009

Answered by the maintainer during this brainstorm, before the phase was reshaped. They are recorded here so spec 009 doesn't ask again. Nothing here is built in spec 008.

- **The sitting:** built for working through a stack of cards. One tap adds a card and the camera is ready for the next. Each added card offers a way into its details (quantity, condition, price paid).
- **Finish:** each candidate shows one add button per finish its printing comes in. A printing with one finish shows a single Add button.
- **Choosing the printing:** a candidate matched by name only is marked as a guess at the printing and offers "Other printings", which opens the card's printings in place, newest first, with whatever set or number was read used to put likely ones on top. Each has its own add buttons.
- **Records:** a stored list of the sitting's adds, each with Undo and a way into its details, which survives leaving the scanner and returning. It records what was added, not what the camera read.
- **Ranking** (ruled 2026-10-02 on spec 007's findings): when the name and the collector line point to different cards, a strong name match ranks first and the collector-line match second. Spec 009 defines "strong" from the 3 misread-number cases in spec 007's research.md §5.
- **Photo picker** (same ruling): kept as the fallback when there is no HTTPS or no camera, with copy telling the collector to frame the card like the guide.
- **Reading refinements** in spec 009's scope: faint foil collector lines, light names on dark bars, long names, a noise line beating the name in query cleaning, cross-checking a misread number against the named card's printings, and the foil star as a finish hint. The first four are findings in spec 007's research.md §11; the cross-check follows from §11's first finding; the foil star hint is the roadmap's.
- **Evidence for spec 009:** the ranking rule is set and checked on the stored text from earlier runs, then the maintainer scans a pile of cards the scanner has never seen through the whole flow on the iPhone. The findings report how many ended as the right printing and finish, how many needed a correction, and the time per card. No pass threshold.
