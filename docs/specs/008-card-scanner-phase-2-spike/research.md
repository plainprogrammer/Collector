# Feature 008: Card Scanner Phase 2 Spike — Findings

**Spec:** [spec.md](spec.md) (v1.2.0) | **Plan:** [plan.md](plan.md)
**Measured:** 2026-10-03 (UTC; the evening of 2026-10-02 local time), the full art index 2026-10-03 03:44–14:41 UTC | **Branch:** `008-card-scanner-phase-2-spike` | **Settings:** commit `39cdc6e` (frozen), and `5ce0238` (index metadata only, AC-1.3)

Every rate carries its sample size. Held-out rates are the headline; development rates sit beside them, labelled "development, biased", because the development photos chose the settings. Every timing is a desktop figure. Art matching was measured twice, at the same frozen fingerprint settings: first against a 598-artwork subset, while the maintainer had declined the full artwork fetch, then, after the maintainer approved it (spec v1.2.0), against the full index of 50,923 artworks (every one of the catalog's 50,959 artworks that has an image). The full index's rates are the headline; the subset's sit beside them (§7, §9). Anything not measured is listed in §12 and is not estimated as if it were measured. The spike sets no pass threshold: the maintainer rules on spec 009's scope from §14.

---

## 1. Summary

**What was measured.** Two in-browser card detectors (a hand-written one with no dependency, and one built on OpenCV.js 4.13.0) and the roadmap's art fingerprint, on the 99 stored photos, on the desktop, in headless Firefox 156. The photos were split before any tuning: 52 development, 47 held out (§2). Settings were tuned on the development half, frozen at `39cdc6e`, and each held-out measurement was then run once at that commit. Art matching was then measured against the full index (50,923 artworks), with no fingerprint setting changed, held out once at `5ce0238`, a settings commit that adds only the index's description (§2).

**What was not measured.** Anything on a phone (download time, time per frame, including the full index's download and search), and real live capture (§12).

**Detection, held out (n=47).** Each detector straightened the card, and the shipped photo path (strips, text recognition, parser and matcher, unchanged since `c68ffbd`) read the result.

| Held out (47 photos) | Hand-written | OpenCV.js | Baseline: shipped photo path, same photos | Live capture, same cards (spec 007; new corpus only) |
|---|---|---|---|---|
| Right card first, final ranking | 27/47 (57.4%) | 12/47 (25.5%) | 10/47 (21.3%) | 18/23 (78.3%) |
| Right card in the top 3, final ranking | 32/47 (68.1%) | 13/47 (27.7%) | 10/47 (21.3%) | 19/23 (82.6%) |
| Exact printing (set-line cards) | 13/43 (30.2%) | 6/43 (14.0%) | 7/43 (16.3%) | 17/21 (81.0%) |
| Development, biased: top 3, final ranking | 43/52 (82.7%) | 14/52 (26.9%) | 16/52 (30.8%) | 26/26 (100.0%) |

- The hand-written detector more than triples the photo path's top 3 (10/47 to 32/47). On the new corpus's 23 held-out cards it reaches 13/23 in the top 3, against 1/23 for the shipped photo path and 19/23 for live capture of the same cards.
- It loses the collector line on the new corpus: exact printing 2/21, against 17/21 live. Its outline often stops above the card's bottom edge when the card fills the frame (§4).
- OpenCV.js does little better than the baseline (top 3 13/47 against 10/47), and worse on Phase 0's photos (8/24 against 9/24). It doesn't run under the scanner page's policy without `'unsafe-eval'` (§2).

**Art matching, held out (n=47), against the full index (50,923 artworks).** The fingerprint was computed in the browser from the hand-written detector's straightened cards (the detector chosen at the freeze). The subset's figures, measured earlier with the same fingerprints, are beside them.

| Held out (47 photos) | Full index (50,923): all photos | Full index: photos classed found | 598-artwork subset: all photos | Subset: photos classed found |
|---|---|---|---|---|
| Right artwork first | 33/47 (70.2%) | 20/24 (83.3%) | 34/47 (72.3%) | 21/24 (87.5%) |
| Right artwork in the top 3 | 33/47 (70.2%) | 20/24 (83.3%) | 35/47 (74.5%) | 21/24 (87.5%) |
| Development, biased: right artwork first | 46/52 (88.5%) | 32/35 (91.4%) | 49/52 (94.2%) | 34/35 (97.1%) |

- **What the full index costs in accuracy.** 85 times as many wrong artworks cost one held-out first choice (`IMG_6709`) and one more top 3 (`IMG_6759`), and three development first choices. Every one of these was a weak match, its right-artwork distance 330 bits or more; no match nearer than 296 bits was lost (§9).
- **What art adds to text.** The text path missed the right card (not in its final top 3) for 15 of 47. Art matching against the full index put the right artwork first for 8 of those 15, as against the subset. Text top 3 or art first: 40/47 (85.1%), against 32/47 for text alone.
- **Printings.** 34 held-out cards didn't get their exact printing from the collector line. For 14 of the 34, the right artwork belongs to exactly one printing in the catalog's entries; the full index put that artwork first for 10 of the 14.
- **Margin.** Where the right artwork was ranked, its median distance was 203 bits against 346 for the nearest wrong artwork (211 against 385.5 on the subset), and it was nearer than every wrong artwork for 33 of 33.

**Costs (desktop figures).**

| Cost | Hand-written | OpenCV.js |
|---|---|---|
| Files, stored / gzip | 5 files, 12,843 B / 5,062 B | 7 files, 10,980,573 B / 3,570,593 B |
| Runs under the scanner page's policy as sent | Yes, no reports | No: needs `'unsafe-eval'` in `script-src` |
| Detection per photo, median / slowest (full size, n=47) | 104 / 138 ms | 8 / 982 ms |
| Straightening per photo, median / slowest | 111 / 169 ms (n=43) | 113 / 167 ms (n=35) |

| Art matching, full index (held out, n=43 with a fingerprint) | Median | Slowest |
|---|---|---|
| Fingerprint one photo, browser | 76 ms | 100 ms |
| Search the full index, browser | 77 ms | 93 ms |
| Search the full index, Ruby on the server | 2,667.4 ms | 3,314.7 ms |

The full index is 7,332,912 bytes as stored (50,923 × 144) and 6,007,929 bytes compressed. Beyond the 598 images the subset had cached, it took 50,325 image fetches (699,685,259 bytes, 9,340.5 s of fetching, about 2.59 hours), beside the estimate of 50,361 fetches, about 702 MB and about 2.52 hours; the 36 artworks without an image URL were never requested. Fingerprinting the 50,923 images took 1,066.6 s (desktop).

**Recommendation (§14), for the maintainer's ruling.** Drop the OpenCV.js detector. Build the hand-written detector into spec 009 for the photo-picker path only, with live capture staying the primary path ([ADR 0005](../../adr/0005-hand-written-card-detector-for-the-photo-path.md), Proposed). Build art matching into spec 009, with the index built server-side from the catalog's images during the catalog refresh and searched in the browser ([ADR 0006](../../adr/0006-art-fingerprint-and-index.md) and [ADR 0007](../../adr/0007-art-search-in-the-browser.md), Proposed). Its download and search time on a phone are spec 009's first measurement.

## 2. Method and apparatus

- **Photos (FR-1).** The 99 photos in the two manifests in `~/card-scanner-corpus/`: Phase 0's 50 (stored 3024×4032, EXIF orientation 1; the card fills 69–77% of the frame height) and the new corpus's 49 in `phase1-live/` (stored 4032×3024, EXIF orientation 6; the card fills about 95%). Every tool applied the EXIF rotation. No photo was taken with the guide.
- **Split (AC-1.1)**, committed in `spec/fixtures/card_scanner/phase2_split.json` (commit `80a78d5`) before the first tuning commit. Within each corpus, the foil rows and the non-foil rows were each alternated in manifest order, starting with development. `IMG_6763` (Leyline Immersion `mat 71`, also Phase 0's `IMG_6718`) was forced to development.

  | Corpus | Development | Held out |
  |---|---|---|
  | Phase 0 | 26 (5 foil) | 24 (4 foil) |
  | New corpus | 26 (6 foil) | 23 (5 foil) |
  | Both | 52 (11 foil) | 47 (9 foil) |

- **Ground truth.** The spike scores against its own copies of the ground truth (`truth_copies.rb`, under `tmp/card_scanner_phase2/truth/`). The only difference from the committed Phase 0 ground truth is that `IMG_6718` is era `pre-M15`, because its frame prints no set code. The Phase 0 baseline column was re-scored with the same copy, so its set-line sample is one smaller than specs 005 and 007 published (44 Phase 0 set-line cards, not 45). `IMG_6718` is in the development half, so the held-out samples are unaffected.
- **Catalog and bulk file.** Scoring and the art index used the worktree's catalog, built from Scryfall `default-cards-20261002210553`: 106,697 entries and 35,946 names. Spec 007 scored against `default-cards-20260930210545`; here the baseline and live columns are re-scored from their committed text against the same catalog as the spike's runs.
- **The shipped reading chain**, at the settings frozen at `c68ffbd`, on the branch head. `git diff c68ffbd HEAD -- app/javascript/scanner app/models/catalog app/models/mtg` is empty, so the strips, text recognition settings, parser and matcher are the ones spec 007 measured. Each straightened card was placed, exactly filling the guide's box (1008×1408 at (156, 176)), in a 1320×1760 picture whose remainder is flat grey (`#808080`). That picture went through `script/scanner/photo_run.rb` and development-only measurement mode, and `Collector::ScannerFindings` scored it, as in spec 007.
- **Browser and machine.** Headless Firefox 156 (`rv:156.0`, Linux x86_64) driven by Selenium, on the maintainer's development machine. Every timing in these findings is from this machine.
- **Medians.** Medians are the middle value, or the mean of the two middle values for an even count.
- **The detectors.** The hand-written detector (`public/hand_detector.js`, no dependency) finds the strongest near-horizontal and near-vertical edge lines in a downscaled copy and pairs them into a card-shaped quad. The OpenCV.js detector (`public/opencv_detector.js`) runs blur, Canny, contours and polygon approximation on OpenCV.js 4.13.0 (`opencv.js`, 10,964,323 bytes, SHA-256 `63366510248adf3a7eddf3e793dd825404efb7df3749f4d6f8557c7fa4ca8aa0`), fetched by `fetch_opencv.rb` into the ignored `tmp/card_scanner_phase2/opencv/4.13.0/` and served by the spike server from its own origin. Both share one warp (`public/warp.js`).
- **Frozen settings (AC-1.3)**, every key of `spikes/card_scanner/phase2/settings.json` at `39cdc6e`:

  | Key | Value |
  |---|---|
  | `frozen` | `2026-10-03` |
  | `chosen_detector` | `hand` |
  | `development_top3_final` | hand `43/52 (dev-hand-3)`, opencv `14/52 (dev-opencv-5)` |
  | `hand` | `workWidth` 480, `blur` 2, `edgePercentile` 0.55, `thetaRangeDeg` 6, `minSeparation` 0.65, `minArea` 0.15, `aspectRange` [0.5, 0.9] |
  | `opencv` | `workWidth` 320, `blur` 3, `canny` [20, 60], `approxEpsilon` 0.04, `minArea` 0.15, `aspectRange` [0.5, 0.9] |
  | `warp` | `width` 1008, `height` 1408, `fill` `#808080` (the straightened card's size and the flat colour around it, AC-2.1) |
  | `fingerprint.box` | x 0.14–0.86, y 0.16–0.50 of the straightened card |
  | `fingerprint.grid` | 17×16 per plane (grey, blue, green, red), horizontal neighbour differences: 4 × 256 = 1,024 bits |
  | `fingerprint.offsets` | six boxes: (0, 0), (+0.02, 0), (−0.02, 0), (0, +0.02), (0, −0.02) as fractions of the card, and the unshifted box inset by 0.03 |
  | `fingerprint.imageSize` | `small` (Scryfall's 146×204 image stands for each artwork in the index) |
  | `art_index` (added at `5ce0238`, below) | `full: 50923 artworks, small images, bulk default-cards-20261002210553, built 2026-10-03` |

  Area resampling to 17×16 is done the same way in the browser and in Ruby: each grid cell is the mean of the source pixels it covers, with fractional edge weights. §8 shows the two agree exactly.
- **Settings commit and the chosen detector (AC-1.3).** `39cdc6ef8d6dbb19f8ddcc98a6e9dd2d80da3ce7` (2026-10-03T02:05:47Z). The rule chose the detector with the better development top 3 (final ranking) over all 52 development photos: hand 43/52 (`dev-hand-3`) against OpenCV 14/52 (`dev-opencv-5`), so no tie. The freeze commit added only `frozen`, `chosen_detector` and `development_top3_final`; no detector or fingerprint value changed after round 4 (`8152021`). The agreement check (§8) ran at `8152021`, so its result holds for the frozen settings.
- **The index-metadata settings commit (AC-1.3).** `5ce0238589f61d40541f2addc8610d921fe77453` (2026-10-03T14:37:47Z) is the one later commit to the settings file that AC-1.3 allows. It adds only the top-level `art_index` key naming the full index; `git diff -U0` of the settings file at that commit:

  ```
  @@ -3,0 +4 @@
  +  "art_index": "full: 50923 artworks, small images, bulk default-cards-20261002210553, built 2026-10-03",
  ```

  The `fingerprint`, `hand`, `opencv` and `warp` values are equal to those at `39cdc6e` (compared as JSON; the only key that differs is `art_index`). No fingerprint setting changed between the subset runs and the full-index runs (AC-3.9): the six fingerprints of every photo are bit-identical between `held-hand-art` and `held-hand-art-full` (0 of 43 photos with a fingerprint differ) and between `dev-hand-3-art` and `dev-hand-3-art-full` (0 of 52), so only the index changed.
- **Held-out provenance (AC-1.2, AC-1.4, AC-1.5).** Every held-out run at the freeze (`held-hand`, `held-opencv`, `held-hand-scaled`, `held-opencv-scaled`, `held-hand-art`) records code commit `39cdc6e`, settings commit `39cdc6e` and a clean tree. Every one of their records is later than the settings commit: the earliest is 2026-10-03T02:07:08Z, the last 02:34:54Z. Nothing was committed between the freeze and the last of these runs. The held-out full-index run, `held-hand-art-full`, records code commit `5ce0238`, settings commit `5ce0238` and a clean tree for all 47 photos; its records run from 2026-10-03T14:37:55Z to 14:38:45Z, after the commit, and nothing was committed between `5ce0238` and the end of its scoring (14:40:54Z; the fixtures commit `fb79cd1` followed at 14:42:07Z). Each held-out measurement ran once; none was repeated.
- **Tuning rounds (development half, biased).** Classes by eye from contact sheets; top 1 and top 3 over the final ranking; exact printing over the 45 development set-line cards. The baseline on the same 52 photos is top 1 15/52, top 3 16/52, exact printing 11/45.

  | Round | Settings changed | Hand run | found / not found / wrong outline | Top 1 | Top 3 | Exact | OpenCV run | found / not found / wrong outline | Top 1 | Top 3 | Exact |
  |---|---|---|---|---|---|---|---|---|---|---|---|
  | 0 | pilot-tuned hand; the plan's OpenCV | dev-hand-1 | 17 / 5 / 30 | 28 | 28 | 12 | dev-opencv-1 | 1 / 42 / 9 | 1 | 1 | 0 |
  | 1 | hand `edgePercentile` 0.85→0.7; OpenCV `canny` 50/150→30/90 | dev-hand-2 | 24 / 1 / 27 | 37 | 39 | 16 | dev-opencv-2 | 5 / 34 / 13 | 4 | 4 | 1 |
  | 2 | hand `edgePercentile` 0.7→0.55; OpenCV `canny` →20/60 | dev-hand-3 | 35 / 0 / 17 | 40 | 43 | 20 | dev-opencv-3 | 8 / 28 / 16 | 6 | 6 | 3 |
  | 3 | OpenCV `blur` 5→3, `approxEpsilon` 0.02→0.04 (hand unchanged) | — | — | — | (43) | — | dev-opencv-4 | 18 / 21 / 13 | 12 | 13 | 6 |
  | 4 | OpenCV `workWidth` 480→320 (hand unchanged) | — | — | — | (43) | — | dev-opencv-5 | 22 / 12 / 18 | 14 | 14 | 5 |

  Tuning stopped after round 4 (hand +0, OpenCV +1). Detect-only probes of the hand detector's other knobs (blur 1 and 3, work width 360 and 640, theta range 3, edge percentile 0.5) each moved at most two outlines, with gains offset by losses. The remaining hand misses were the new corpus's bottom edges (a black border against a shadowed hand), which no single `minSeparation` reaches without losing Phase 0's smaller cards. OpenCV's misses were mostly contours that fingers break into more than four corners. The probe runs (`probe-*`) are kept beside the others and weren't scored.
- **The pilot (AC-1.6)**, on 5 development photos: `IMG_6688`, `IMG_6689` (foil), `IMG_6704` (foil) from Phase 0; `IMG_6755` (foil), `IMG_6758` from the new corpus.
  - **Hand detector, 4 rounds.** The detector reported a card for 2/5 at the plan's defaults (`pilot-hand`), then 4/5 (`pilot-hand-2` to `pilot-hand-4`). The defaults paired a card edge with an internal line (the type bar, the text box), giving landscape quads that the aspect check rejected. The pilot changed `edgePercentile` 0.92→0.85, `minSeparation` 0.3→0.65, `blur` 1→2 and `thetaRangeDeg` 25→6. `IMG_6704` (a green border on a green background) was never found: its strongest horizontal line is the type bar, and both card edges lie closer to it than any separation the other photos allow.
  - **OpenCV detector.** The plan's loader waited for `onRuntimeInitialized`, which OpenCV.js 4.13.0 never fires, so the first runs hung. 4.13.0 exposes `cv` as a thenable that resolves with itself; the loader was rewritten to wait on it. The page then showed that OpenCV.js needs `'unsafe-eval'` (below). With it, the detector reported a card for 1/5 at the plan's settings (an inner frame, not the card). Four further rounds (Canny 20/60, work width and blur variants, work width 960) found nothing better, so the pilot kept the plan's settings.
  - **Reading chain and art matching.** The pilot reading run (`pilot-hand-4`) found that `score.rb` broke its miss table into pieces and leaked carriage returns into cells; fixed in `ba0cc5b`. The art pilot (`pilot-hand-4-art`) ran on `pilot-hand-4`, the older hand settings, so its art and text results came from different detector settings than the later runs.
- **The policy (AC-2.8).** The app's scanner pages send `ScannerPage`'s directives with a per-request nonce on `script-src`. The spike server sent the same directives, in the same order, with a nonce and its own `report-uri`:

  ```
  default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'nonce-…'; worker-src 'self' blob:; connect-src 'self';
  img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; font-src 'self'; object-src 'none'; frame-src 'none';
  base-uri 'self'; form-action 'self'; frame-ancestors 'self'; report-uri /csp-report
  ```

  One difference: the app's `img-src` also lists the catalog's image hosts. The spike page loads no image from them, so it omitted them.
  - **Hand-written detector, fingerprint and search:** ran under this policy with no reports.
  - **OpenCV.js 4.13.0:** does not run under it. The report is violated directive `script-src`, blocked URI `eval`, from `opencv.js` line 30 (Emscripten embind's `createNamedFunction`, which calls `new Function`). With `'unsafe-eval'` added to `script-src` (`SPIKE_UNSAFE_EVAL=1`), it runs. It then also reports `connect-src` blocking `data` (it tries to fetch its base64-embedded WebAssembly), which it survives by decoding the base64 itself. So OpenCV.js would need `script-src` widened by `'unsafe-eval'`; `connect-src data:` is optional. `tmp/card_scanner_phase2/logs/csp-reports.jsonl` holds 2 `script-src`/`eval` reports and 39 `connect-src`/`data` reports, all from OpenCV runs, and none naming an external host.

## 3. Detection rates (AC-2.2, AC-2.3)

Held-out photos, frozen settings, scored with spec 007's definitions. The baseline column is the same photos through the shipped photo path (committed fixtures `phase1_photos_*` and `phase1_live_photos_*`). The live column is spec 007's live capture of the same cards (`phase1_live_*`); it exists only for the new corpus, so in the both-corpora tables it covers that corpus's 23 cards. A photo where the detector reported no card counts as a miss (AC-2.5).

Lookup outcomes over the 43 held-out set-line cards: hand one 15, none 28; OpenCV one 9, none 34; baseline one 8, none 35; live (21 cards) one 18, none 3. No lookup was ambiguous (0).

**Both corpora, held out:**

| Top 1, final ranking, both corpora | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 27/47 (57.4%) | 12/47 (25.5%) | 10/47 (21.3%) | 18/23 (78.3%) |
| era | M15–ONE | 15/22 (68.2%) | 7/22 (31.8%) | 6/22 (27.3%) | 10/12 (83.3%) |
| era | MOM+ | 10/21 (47.6%) | 3/21 (14.3%) | 4/21 (19.0%) | 8/9 (88.9%) |
| era | pre-M15 | 2/4 (50.0%) | 2/4 (50.0%) | 0/4 (0.0%) | 0/2 (0.0%) |
| foil | foil | 6/9 (66.7%) | 3/9 (33.3%) | 2/9 (22.2%) | 2/5 (40.0%) |
| foil | non-foil | 21/38 (55.3%) | 9/38 (23.7%) | 8/38 (21.1%) | 16/18 (88.9%) |
| frame treatment | borderless/showcase | 6/13 (46.2%) | 5/13 (38.5%) | 1/13 (7.7%) | 4/6 (66.7%) |
| frame treatment | regular | 21/34 (61.8%) | 7/34 (20.6%) | 9/34 (26.5%) | 14/17 (82.4%) |

| Top 3, final ranking, both corpora | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 32/47 (68.1%) | 13/47 (27.7%) | 10/47 (21.3%) | 19/23 (82.6%) |
| era | M15–ONE | 16/22 (72.7%) | 7/22 (31.8%) | 6/22 (27.3%) | 11/12 (91.7%) |
| era | MOM+ | 12/21 (57.1%) | 4/21 (19.0%) | 4/21 (19.0%) | 8/9 (88.9%) |
| era | pre-M15 | 4/4 (100.0%) | 2/4 (50.0%) | 0/4 (0.0%) | 0/2 (0.0%) |
| foil | foil | 7/9 (77.8%) | 3/9 (33.3%) | 2/9 (22.2%) | 3/5 (60.0%) |
| foil | non-foil | 25/38 (65.8%) | 10/38 (26.3%) | 8/38 (21.1%) | 16/18 (88.9%) |
| frame treatment | borderless/showcase | 7/13 (53.8%) | 5/13 (38.5%) | 1/13 (7.7%) | 5/6 (83.3%) |
| frame treatment | regular | 25/34 (73.5%) | 8/34 (23.5%) | 9/34 (26.5%) | 14/17 (82.4%) |

| Top 1, name only, both corpora | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 25/47 (53.2%) | 10/47 (21.3%) | 5/47 (10.6%) | 15/23 (65.2%) |
| era | M15–ONE | 11/22 (50.0%) | 4/22 (18.2%) | 3/22 (13.6%) | 8/12 (66.7%) |
| era | MOM+ | 11/21 (52.4%) | 4/21 (19.0%) | 2/21 (9.5%) | 7/9 (77.8%) |
| era | pre-M15 | 3/4 (75.0%) | 2/4 (50.0%) | 0/4 (0.0%) | 0/2 (0.0%) |
| foil | foil | 5/9 (55.6%) | 2/9 (22.2%) | 1/9 (11.1%) | 3/5 (60.0%) |
| foil | non-foil | 20/38 (52.6%) | 8/38 (21.1%) | 4/38 (10.5%) | 12/18 (66.7%) |
| frame treatment | borderless/showcase | 5/13 (38.5%) | 4/13 (30.8%) | 1/13 (7.7%) | 4/6 (66.7%) |
| frame treatment | regular | 20/34 (58.8%) | 6/34 (17.6%) | 4/34 (11.8%) | 11/17 (64.7%) |

| Top 3, name only, both corpora | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 27/47 (57.4%) | 11/47 (23.4%) | 5/47 (10.6%) | 15/23 (65.2%) |
| era | M15–ONE | 11/22 (50.0%) | 5/22 (22.7%) | 3/22 (13.6%) | 8/12 (66.7%) |
| era | MOM+ | 12/21 (57.1%) | 4/21 (19.0%) | 2/21 (9.5%) | 7/9 (77.8%) |
| era | pre-M15 | 4/4 (100.0%) | 2/4 (50.0%) | 0/4 (0.0%) | 0/2 (0.0%) |
| foil | foil | 6/9 (66.7%) | 3/9 (33.3%) | 1/9 (11.1%) | 3/5 (60.0%) |
| foil | non-foil | 21/38 (55.3%) | 8/38 (21.1%) | 4/38 (10.5%) | 12/18 (66.7%) |
| frame treatment | borderless/showcase | 5/13 (38.5%) | 5/13 (38.5%) | 1/13 (7.7%) | 4/6 (66.7%) |
| frame treatment | regular | 22/34 (64.7%) | 6/34 (17.6%) | 4/34 (11.8%) | 11/17 (64.7%) |

| Exact printing (M15–ONE, MOM+), both corpora | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 13/43 (30.2%) | 6/43 (14.0%) | 7/43 (16.3%) | 17/21 (81.0%) |
| era | M15–ONE | 8/22 (36.4%) | 5/22 (22.7%) | 5/22 (22.7%) | 10/12 (83.3%) |
| era | MOM+ | 5/21 (23.8%) | 1/21 (4.8%) | 2/21 (9.5%) | 7/9 (77.8%) |
| foil | foil | 3/8 (37.5%) | 1/8 (12.5%) | 1/8 (12.5%) | 2/4 (50.0%) |
| foil | non-foil | 10/35 (28.6%) | 5/35 (14.3%) | 6/35 (17.1%) | 15/17 (88.2%) |
| frame treatment | borderless/showcase | 3/13 (23.1%) | 4/13 (30.8%) | 1/13 (7.7%) | 4/6 (66.7%) |
| frame treatment | regular | 10/30 (33.3%) | 2/30 (6.7%) | 6/30 (20.0%) | 13/15 (86.7%) |

<details>
<summary>Phase 0, held out (24 photos)</summary>

Lookup outcomes over 22 set-line cards: hand one 13, none 9; OpenCV one 4, none 18; baseline one 7, none 15.

| Top 1, final ranking, Phase 0 | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path |
|---|---|---|---|---|
| overall | all | 16/24 (66.7%) | 7/24 (29.2%) | 9/24 (37.5%) |
| era | M15–ONE | 8/10 (80.0%) | 4/10 (40.0%) | 5/10 (50.0%) |
| era | MOM+ | 7/12 (58.3%) | 2/12 (16.7%) | 4/12 (33.3%) |
| era | pre-M15 | 1/2 (50.0%) | 1/2 (50.0%) | 0/2 (0.0%) |
| foil | foil | 3/4 (75.0%) | 1/4 (25.0%) | 2/4 (50.0%) |
| foil | non-foil | 13/20 (65.0%) | 6/20 (30.0%) | 7/20 (35.0%) |
| frame treatment | borderless/showcase | 3/7 (42.9%) | 2/7 (28.6%) | 1/7 (14.3%) |
| frame treatment | regular | 13/17 (76.5%) | 5/17 (29.4%) | 8/17 (47.1%) |

| Top 3, final ranking, Phase 0 | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path |
|---|---|---|---|---|
| overall | all | 19/24 (79.2%) | 8/24 (33.3%) | 9/24 (37.5%) |
| era | M15–ONE | 9/10 (90.0%) | 4/10 (40.0%) | 5/10 (50.0%) |
| era | MOM+ | 8/12 (66.7%) | 3/12 (25.0%) | 4/12 (33.3%) |
| era | pre-M15 | 2/2 (100.0%) | 1/2 (50.0%) | 0/2 (0.0%) |
| foil | foil | 3/4 (75.0%) | 1/4 (25.0%) | 2/4 (50.0%) |
| foil | non-foil | 16/20 (80.0%) | 7/20 (35.0%) | 7/20 (35.0%) |
| frame treatment | borderless/showcase | 4/7 (57.1%) | 2/7 (28.6%) | 1/7 (14.3%) |
| frame treatment | regular | 15/17 (88.2%) | 6/17 (35.3%) | 8/17 (47.1%) |

| Top 1, name only, Phase 0 | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path |
|---|---|---|---|---|
| overall | all | 16/24 (66.7%) | 7/24 (29.2%) | 5/24 (20.8%) |
| era | M15–ONE | 6/10 (60.0%) | 3/10 (30.0%) | 3/10 (30.0%) |
| era | MOM+ | 8/12 (66.7%) | 3/12 (25.0%) | 2/12 (16.7%) |
| era | pre-M15 | 2/2 (100.0%) | 1/2 (50.0%) | 0/2 (0.0%) |
| foil | foil | 3/4 (75.0%) | 1/4 (25.0%) | 1/4 (25.0%) |
| foil | non-foil | 13/20 (65.0%) | 6/20 (30.0%) | 4/20 (20.0%) |
| frame treatment | borderless/showcase | 3/7 (42.9%) | 2/7 (28.6%) | 1/7 (14.3%) |
| frame treatment | regular | 13/17 (76.5%) | 5/17 (29.4%) | 4/17 (23.5%) |

| Top 3, name only, Phase 0 | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path |
|---|---|---|---|---|
| overall | all | 16/24 (66.7%) | 7/24 (29.2%) | 5/24 (20.8%) |
| era | M15–ONE | 6/10 (60.0%) | 3/10 (30.0%) | 3/10 (30.0%) |
| era | MOM+ | 8/12 (66.7%) | 3/12 (25.0%) | 2/12 (16.7%) |
| era | pre-M15 | 2/2 (100.0%) | 1/2 (50.0%) | 0/2 (0.0%) |
| foil | foil | 3/4 (75.0%) | 1/4 (25.0%) | 1/4 (25.0%) |
| foil | non-foil | 13/20 (65.0%) | 6/20 (30.0%) | 4/20 (20.0%) |
| frame treatment | borderless/showcase | 3/7 (42.9%) | 2/7 (28.6%) | 1/7 (14.3%) |
| frame treatment | regular | 13/17 (76.5%) | 5/17 (29.4%) | 4/17 (23.5%) |

| Exact printing (M15–ONE, MOM+), Phase 0 | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path |
|---|---|---|---|---|
| overall | all | 11/22 (50.0%) | 3/22 (13.6%) | 6/22 (27.3%) |
| era | M15–ONE | 6/10 (60.0%) | 3/10 (30.0%) | 4/10 (40.0%) |
| era | MOM+ | 5/12 (41.7%) | 0/12 (0.0%) | 2/12 (16.7%) |
| foil | foil | 2/4 (50.0%) | 0/4 (0.0%) | 1/4 (25.0%) |
| foil | non-foil | 9/18 (50.0%) | 3/18 (16.7%) | 5/18 (27.8%) |
| frame treatment | borderless/showcase | 2/7 (28.6%) | 2/7 (28.6%) | 1/7 (14.3%) |
| frame treatment | regular | 9/15 (60.0%) | 1/15 (6.7%) | 5/15 (33.3%) |
</details>

<details>
<summary>New corpus, held out (23 photos)</summary>

Lookup outcomes over 21 set-line cards: hand one 2, none 19; OpenCV one 5, none 16; baseline one 1, none 20; live one 18, none 3.

| Top 1, final ranking, new corpus | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 11/23 (47.8%) | 5/23 (21.7%) | 1/23 (4.3%) | 18/23 (78.3%) |
| era | M15–ONE | 7/12 (58.3%) | 3/12 (25.0%) | 1/12 (8.3%) | 10/12 (83.3%) |
| era | MOM+ | 3/9 (33.3%) | 1/9 (11.1%) | 0/9 (0.0%) | 8/9 (88.9%) |
| era | pre-M15 | 1/2 (50.0%) | 1/2 (50.0%) | 0/2 (0.0%) | 0/2 (0.0%) |
| foil | foil | 3/5 (60.0%) | 2/5 (40.0%) | 0/5 (0.0%) | 2/5 (40.0%) |
| foil | non-foil | 8/18 (44.4%) | 3/18 (16.7%) | 1/18 (5.6%) | 16/18 (88.9%) |
| frame treatment | borderless/showcase | 3/6 (50.0%) | 3/6 (50.0%) | 0/6 (0.0%) | 4/6 (66.7%) |
| frame treatment | regular | 8/17 (47.1%) | 2/17 (11.8%) | 1/17 (5.9%) | 14/17 (82.4%) |

| Top 3, final ranking, new corpus | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 13/23 (56.5%) | 5/23 (21.7%) | 1/23 (4.3%) | 19/23 (82.6%) |
| era | M15–ONE | 7/12 (58.3%) | 3/12 (25.0%) | 1/12 (8.3%) | 11/12 (91.7%) |
| era | MOM+ | 4/9 (44.4%) | 1/9 (11.1%) | 0/9 (0.0%) | 8/9 (88.9%) |
| era | pre-M15 | 2/2 (100.0%) | 1/2 (50.0%) | 0/2 (0.0%) | 0/2 (0.0%) |
| foil | foil | 4/5 (80.0%) | 2/5 (40.0%) | 0/5 (0.0%) | 3/5 (60.0%) |
| foil | non-foil | 9/18 (50.0%) | 3/18 (16.7%) | 1/18 (5.6%) | 16/18 (88.9%) |
| frame treatment | borderless/showcase | 3/6 (50.0%) | 3/6 (50.0%) | 0/6 (0.0%) | 5/6 (83.3%) |
| frame treatment | regular | 10/17 (58.8%) | 2/17 (11.8%) | 1/17 (5.9%) | 14/17 (82.4%) |

| Top 1, name only, new corpus | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 9/23 (39.1%) | 3/23 (13.0%) | 0/23 (0.0%) | 15/23 (65.2%) |
| era | M15–ONE | 5/12 (41.7%) | 1/12 (8.3%) | 0/12 (0.0%) | 8/12 (66.7%) |
| era | MOM+ | 3/9 (33.3%) | 1/9 (11.1%) | 0/9 (0.0%) | 7/9 (77.8%) |
| era | pre-M15 | 1/2 (50.0%) | 1/2 (50.0%) | 0/2 (0.0%) | 0/2 (0.0%) |
| foil | foil | 2/5 (40.0%) | 1/5 (20.0%) | 0/5 (0.0%) | 3/5 (60.0%) |
| foil | non-foil | 7/18 (38.9%) | 2/18 (11.1%) | 0/18 (0.0%) | 12/18 (66.7%) |
| frame treatment | borderless/showcase | 2/6 (33.3%) | 2/6 (33.3%) | 0/6 (0.0%) | 4/6 (66.7%) |
| frame treatment | regular | 7/17 (41.2%) | 1/17 (5.9%) | 0/17 (0.0%) | 11/17 (64.7%) |

| Top 3, name only, new corpus | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 11/23 (47.8%) | 4/23 (17.4%) | 0/23 (0.0%) | 15/23 (65.2%) |
| era | M15–ONE | 5/12 (41.7%) | 2/12 (16.7%) | 0/12 (0.0%) | 8/12 (66.7%) |
| era | MOM+ | 4/9 (44.4%) | 1/9 (11.1%) | 0/9 (0.0%) | 7/9 (77.8%) |
| era | pre-M15 | 2/2 (100.0%) | 1/2 (50.0%) | 0/2 (0.0%) | 0/2 (0.0%) |
| foil | foil | 3/5 (60.0%) | 2/5 (40.0%) | 0/5 (0.0%) | 3/5 (60.0%) |
| foil | non-foil | 8/18 (44.4%) | 2/18 (11.1%) | 0/18 (0.0%) | 12/18 (66.7%) |
| frame treatment | borderless/showcase | 2/6 (33.3%) | 3/6 (50.0%) | 0/6 (0.0%) | 4/6 (66.7%) |
| frame treatment | regular | 9/17 (52.9%) | 1/17 (5.9%) | 0/17 (0.0%) | 11/17 (64.7%) |

| Exact printing (M15–ONE, MOM+), new corpus | Group | Hand (held out) | OpenCV (held out) | Baseline: shipped photo path | Live capture, same cards (spec 007) |
|---|---|---|---|---|---|
| overall | all | 2/21 (9.5%) | 3/21 (14.3%) | 1/21 (4.8%) | 17/21 (81.0%) |
| era | M15–ONE | 2/12 (16.7%) | 2/12 (16.7%) | 1/12 (8.3%) | 10/12 (83.3%) |
| era | MOM+ | 0/9 (0.0%) | 1/9 (11.1%) | 0/9 (0.0%) | 7/9 (77.8%) |
| foil | foil | 1/4 (25.0%) | 1/4 (25.0%) | 0/4 (0.0%) | 2/4 (50.0%) |
| foil | non-foil | 1/17 (5.9%) | 2/17 (11.8%) | 1/17 (5.9%) | 15/17 (88.2%) |
| frame treatment | borderless/showcase | 1/6 (16.7%) | 2/6 (33.3%) | 0/6 (0.0%) | 4/6 (66.7%) |
| frame treatment | regular | 1/15 (6.7%) | 1/15 (6.7%) | 1/15 (6.7%) | 13/15 (86.7%) |
</details>

**Development, biased** (52 photos; the runs that chose the settings: `dev-hand-3`, `dev-opencv-5`):

| Development, biased | Corpus | Hand | OpenCV | Baseline | Live, same cards |
|---|---|---|---|---|---|
| Top 1, final ranking | both | 40/52 (76.9%) | 14/52 (26.9%) | 15/52 (28.8%) | 24/26 (92.3%) |
| Top 3, final ranking | both | 43/52 (82.7%) | 14/52 (26.9%) | 16/52 (30.8%) | 26/26 (100.0%) |
| Top 1, name only | both | 35/52 (67.3%) | 13/52 (25.0%) | 9/52 (17.3%) | 24/26 (92.3%) |
| Top 3, name only | both | 35/52 (67.3%) | 13/52 (25.0%) | 9/52 (17.3%) | 24/26 (92.3%) |
| Exact printing | both | 20/45 (44.4%) | 5/45 (11.1%) | 11/45 (24.4%) | 17/23 (73.9%) |
| Top 1, final ranking | Phase 0 | 21/26 (80.8%) | 5/26 (19.2%) | 14/26 (53.8%) | — |
| Top 3, final ranking | Phase 0 | 22/26 (84.6%) | 5/26 (19.2%) | 15/26 (57.7%) | — |
| Exact printing | Phase 0 | 17/22 (77.3%) | 1/22 (4.5%) | 10/22 (45.5%) | — |
| Top 1, final ranking | new | 19/26 (73.1%) | 9/26 (34.6%) | 1/26 (3.8%) | 24/26 (92.3%) |
| Top 3, final ranking | new | 21/26 (80.8%) | 9/26 (34.6%) | 1/26 (3.8%) | 26/26 (100.0%) |
| Exact printing | new | 3/23 (13.0%) | 4/23 (17.4%) | 1/23 (4.3%) | 17/23 (73.9%) |

The held-out top 3 for the hand detector (32/47) is 14.6 points below its development figure (43/52); on the new corpus the drop is from 21/26 to 13/23. That gap is the bias the split exists to expose.

## 4. Detection classes and misses (AC-2.4, AC-2.11)

**Classes**, judged by eye from contact sheets of the straightened cards: **found** (the whole card and nothing else fills the image), **not found** (the detector reported no card) or **wrong outline** (the detector straightened something that isn't the whole card).

| Run | Detector | Half | Corpus | Found | Not found | Wrong outline |
|---|---|---|---|---|---|---|
| held-hand | hand | held out | Phase 0 (24) | 20 | 2 | 2 |
| held-hand | hand | held out | new (23) | 4 | 2 | 17 |
| held-opencv | OpenCV | held out | Phase 0 (24) | 0 | 5 | 19 |
| held-opencv | OpenCV | held out | new (23) | 2 | 7 | 14 |
| dev-hand-3 | hand | development, biased | Phase 0 (26) | 23 | 0 | 3 |
| dev-hand-3 | hand | development, biased | new (26) | 12 | 0 | 14 |
| dev-opencv-5 | OpenCV | development, biased | Phase 0 (26) | 6 | 7 | 13 |
| dev-opencv-5 | OpenCV | development, biased | new (26) | 16 | 5 | 5 |
| held-hand-scaled | hand | held out | Phase 0 at 1080×1440 (24) | 20 | 1 | 3 |
| held-opencv-scaled | OpenCV | held out | Phase 0 at 1080×1440 (24) | 0 | 6 | 18 |
| dev-hand-scaled | hand | development, biased | Phase 0 at 1080×1440 (26) | 23 | 0 | 3 |
| dev-opencv-scaled | OpenCV | development, biased | Phase 0 at 1080×1440 (26) | 4 | 7 | 15 |

OpenCV's found count on the new corpus fell from 16/26 (development) to 2/23 (held out). Its settings were tuned on the development photos' contours, and they didn't carry over.

**Contact sheets**, kept outside the repository with the by-eye classes beside them (`classes.json`), in `~/card-scanner-corpus/runs/phase2/<run>/contact-<n>.png`, 20 cards per sheet: `held-hand` 3 sheets, `held-opencv` 3, `held-hand-scaled` 2, `held-opencv-scaled` 2, `dev-hand-3` 3, `dev-opencv-5` 3, `dev-hand-scaled` 2, `dev-opencv-scaled` 2, and the replays `dev-hand-r1`, `dev-hand-r2`, `dev-opencv-r1`, `dev-opencv-r2` 3 each.

**What the sheets show.**

- **The bottom edge.** On the new corpus the card fills the frame and its bottom border lies against a shadowed hand. The hand detector's bottom line then often lands on the text box's lower rule or inside the text box, so the outline stops above the card's bottom edge and the collector line is lost. This is why 17 of 23 new-corpus outlines are wrong and why exact printing there is 2/21.
- **The name strip.** The shipped name strip covers y 0.055–0.165 of the guide. On a card that exactly fills the guide, the name bar sits higher than that, near the strip's top edge. An outline a little too low or too tight then drops the name (`IMG_6720`, `IMG_6805`, `IMG_6770`, `IMG_6793`).
- **Fingers.** OpenCV's contours break where fingers cross the card's edge, so it closes no four-corner outline (not found) or closes an inner frame (wrong outline).
- **Battle cards.** A battle card is printed sideways, so the upright outline and the fixed art box don't fit it (`IMG_6723`, development; `IMG_6757`, held out).

**Held-out misses for the chosen detector (hand), right card not in the final top 3 (AC-2.11), 15 of 47.** "Read" is what the shipped strips read, shortened.

| File | Expected | Class | Name read | Collector read | Likely cause |
|---|---|---|---|---|---|
| IMG_6690.jpeg | Sally Pride, Lioness Leader | not found | — | — | The card is tilted further than the detector's ±6° line search (`thetaRangeDeg` 6) |
| IMG_6705.jpeg | Cloudsteel Kirin | wrong outline | `2 ~ . Lae 20% B i AF re` | `— ! Artifact — Equipmen …` | The top edge landed on the art box and the bottom ran onto a second card below, so the name bar is outside the outline |
| IMG_6720.jpeg | Fanged Flames | found | `[] 5 \/ col 28 CL — ou pe …` | `cong MHZ « EN ¥% CAMPBELL WIITE` | The name bar sits at the strip's top edge, so the strip read the art; the set code was misread (`MHZ` for `MH3`) |
| IMG_6727.jpeg | Desert Were-Worm | not found | — | — | The card fills the photo's width; its left edge lies at the photo's edge against the hand |
| IMG_6732.jpeg | Balefire Dragon | found | `x nm om — T- ’ 5 . § 3 3 FE...` | `Eadie (x JUSS) fro as MOG97 CMM*EN …` | Foil glare washes out the name and the collector line |
| IMG_6757.jpeg | Invasion of Muraganda // Primordial Plasm | wrong outline | `/ o - I “A : - Espa, po …` | `I ih py i408 5 …` | A battle card, printed sideways: the name runs up the left side |
| IMG_6770.jpeg | Ajani Unrelenting | wrong outline | `Sag ja n / J) n rel e nt » v …` | `= Ajani deals 4 damage …` | Left and bottom edges inside the card; the name bar at the strip's top edge was read in fragments |
| IMG_6777.jpeg | Ritual Guardian | wrong outline | `I J ESE Ad` | `“By ancient magics, b will survive this night.` | The outline stops above the bottom edge, so the picture is stretched and the name bar sits above the strip |
| IMG_6782.jpeg | Sunblade Samurai | not found | — | — | The card fills the frame; black border against a shadowed hand |
| IMG_6785.jpeg | Dunland Crebain | not found | — | — | The card fills the frame; black border against a shadowed hand |
| IMG_6793.jpeg | Coronation of Chaos | wrong outline | `NUL VVIIQLIVIL VL viiaV) 1 / 2s Ww = Pe` | `When Sarevok’s deception 1` | The outline stops above the bottom edge; the name bar was cut at the strip's top edge |
| IMG_6797.jpeg | Vengeant Earth | wrong outline | (empty) | `When Zendikar’s defender: rose up …` | The outline stops above the bottom edge; nothing read in the name strip |
| IMG_6799.jpeg | +2 Mace | wrong outline | `EE $2200 fa THR` | `A 7Tev Weis TEL J revo rr as ! heavy on the wicked.` | The outline stops above the bottom edge; a short name read as noise |
| IMG_6803.jpeg | Thriving Rats | wrong outline | `\ a N tds YY p y b n > i “a 4` | `In Ghirapur, even the lowh in lavish surroundings.` | Top and bottom edges both inside the card: the name bar and the collector line are outside the outline |
| IMG_6805.jpeg | Treason of Isengard | found | `rd` | `nid — - 3 I D074 * 7 + EN % PAVEL KOLOMEYETS` | The name bar sits at the strip's top edge; the set code was lost in the dark bottom border |

Of the 15: 4 not found, 8 wrong outlines (6 of them edges inside the card on the new corpus, 1 battle card, 1 outline running onto a second card), 3 found but misread (the name strip's position twice, foil glare once).

## 5. The live-frame stand-in (AC-2.6)

**A stand-in for a live frame, not a measure of live capture.** Phase 0's photos, in which the card fills about as much of the frame as the guide asks for, were scaled down so the whole photo is 1080×1440 before detection; the straightened card was made by the same rule as at full size. The held-out 24 are the headline; the development 26 are beside them, labelled biased.

Lookup outcomes over the 22 held-out set-line cards: hand one 12, none 10; OpenCV one 6, none 16; baseline one 7, none 15. Development, biased (22): hand one 18, none 4; OpenCV one 1, none 21; baseline one 11, none 11.

| Top 1, final ranking, Phase 0 at 1080×1440 | Group | Hand (held out, n=24) | OpenCV (held out) | Baseline (held out) | Hand (development, biased) | OpenCV (development, biased) | Baseline (development) |
|---|---|---|---|---|---|---|---|
| overall | all | 16/24 (66.7%) | 7/24 (29.2%) | 9/24 (37.5%) | 23/26 (88.5%) | 5/26 (19.2%) | 14/26 (53.8%) |
| era | M15–ONE | 7/10 (70.0%) | 3/10 (30.0%) | 5/10 (50.0%) | 9/10 (90.0%) | 2/10 (20.0%) | 7/10 (70.0%) |
| era | MOM+ | 7/12 (58.3%) | 2/12 (16.7%) | 4/12 (33.3%) | 10/12 (83.3%) | 2/12 (16.7%) | 7/12 (58.3%) |
| era | pre-M15 | 2/2 (100.0%) | 2/2 (100.0%) | 0/2 (0.0%) | 4/4 (100.0%) | 1/4 (25.0%) | 0/4 (0.0%) |
| foil | foil | 2/4 (50.0%) | 1/4 (25.0%) | 2/4 (50.0%) | 4/5 (80.0%) | 1/5 (20.0%) | 1/5 (20.0%) |
| foil | non-foil | 14/20 (70.0%) | 6/20 (30.0%) | 7/20 (35.0%) | 19/21 (90.5%) | 4/21 (19.0%) | 13/21 (61.9%) |
| frame treatment | borderless/showcase | 3/7 (42.9%) | 1/7 (14.3%) | 1/7 (14.3%) | 8/9 (88.9%) | 0/9 (0.0%) | 5/9 (55.6%) |
| frame treatment | regular | 13/17 (76.5%) | 6/17 (35.3%) | 8/17 (47.1%) | 15/17 (88.2%) | 5/17 (29.4%) | 9/17 (52.9%) |

| Top 3, final ranking, Phase 0 at 1080×1440 | Group | Hand (held out, n=24) | OpenCV (held out) | Baseline (held out) | Hand (development, biased) | OpenCV (development, biased) | Baseline (development) |
|---|---|---|---|---|---|---|---|
| overall | all | 19/24 (79.2%) | 9/24 (37.5%) | 9/24 (37.5%) | 24/26 (92.3%) | 5/26 (19.2%) | 15/26 (57.7%) |
| era | M15–ONE | 9/10 (90.0%) | 4/10 (40.0%) | 5/10 (50.0%) | 9/10 (90.0%) | 2/10 (20.0%) | 8/10 (80.0%) |
| era | MOM+ | 8/12 (66.7%) | 3/12 (25.0%) | 4/12 (33.3%) | 11/12 (91.7%) | 2/12 (16.7%) | 7/12 (58.3%) |
| era | pre-M15 | 2/2 (100.0%) | 2/2 (100.0%) | 0/2 (0.0%) | 4/4 (100.0%) | 1/4 (25.0%) | 0/4 (0.0%) |
| foil | foil | 3/4 (75.0%) | 1/4 (25.0%) | 2/4 (50.0%) | 4/5 (80.0%) | 1/5 (20.0%) | 2/5 (40.0%) |
| foil | non-foil | 16/20 (80.0%) | 8/20 (40.0%) | 7/20 (35.0%) | 20/21 (95.2%) | 4/21 (19.0%) | 13/21 (61.9%) |
| frame treatment | borderless/showcase | 4/7 (57.1%) | 2/7 (28.6%) | 1/7 (14.3%) | 8/9 (88.9%) | 0/9 (0.0%) | 6/9 (66.7%) |
| frame treatment | regular | 15/17 (88.2%) | 7/17 (41.2%) | 8/17 (47.1%) | 16/17 (94.1%) | 5/17 (29.4%) | 9/17 (52.9%) |

| Top 1, name only, Phase 0 at 1080×1440 | Group | Hand (held out, n=24) | OpenCV (held out) | Baseline (held out) | Hand (development, biased) | OpenCV (development, biased) | Baseline (development) |
|---|---|---|---|---|---|---|---|
| overall | all | 16/24 (66.7%) | 8/24 (33.3%) | 5/24 (20.8%) | 17/26 (65.4%) | 5/26 (19.2%) | 9/26 (34.6%) |
| era | M15–ONE | 6/10 (60.0%) | 3/10 (30.0%) | 3/10 (30.0%) | 6/10 (60.0%) | 2/10 (20.0%) | 6/10 (60.0%) |
| era | MOM+ | 8/12 (66.7%) | 3/12 (25.0%) | 2/12 (16.7%) | 7/12 (58.3%) | 2/12 (16.7%) | 3/12 (25.0%) |
| era | pre-M15 | 2/2 (100.0%) | 2/2 (100.0%) | 0/2 (0.0%) | 4/4 (100.0%) | 1/4 (25.0%) | 0/4 (0.0%) |
| foil | foil | 3/4 (75.0%) | 1/4 (25.0%) | 1/4 (25.0%) | 2/5 (40.0%) | 1/5 (20.0%) | 2/5 (40.0%) |
| foil | non-foil | 13/20 (65.0%) | 7/20 (35.0%) | 4/20 (20.0%) | 15/21 (71.4%) | 4/21 (19.0%) | 7/21 (33.3%) |
| frame treatment | borderless/showcase | 3/7 (42.9%) | 2/7 (28.6%) | 1/7 (14.3%) | 5/9 (55.6%) | 0/9 (0.0%) | 6/9 (66.7%) |
| frame treatment | regular | 13/17 (76.5%) | 6/17 (35.3%) | 4/17 (23.5%) | 12/17 (70.6%) | 5/17 (29.4%) | 3/17 (17.6%) |

| Top 3, name only, Phase 0 at 1080×1440 | Group | Hand (held out, n=24) | OpenCV (held out) | Baseline (held out) | Hand (development, biased) | OpenCV (development, biased) | Baseline (development) |
|---|---|---|---|---|---|---|---|
| overall | all | 16/24 (66.7%) | 8/24 (33.3%) | 5/24 (20.8%) | 17/26 (65.4%) | 5/26 (19.2%) | 9/26 (34.6%) |
| era | M15–ONE | 6/10 (60.0%) | 3/10 (30.0%) | 3/10 (30.0%) | 6/10 (60.0%) | 2/10 (20.0%) | 6/10 (60.0%) |
| era | MOM+ | 8/12 (66.7%) | 3/12 (25.0%) | 2/12 (16.7%) | 7/12 (58.3%) | 2/12 (16.7%) | 3/12 (25.0%) |
| era | pre-M15 | 2/2 (100.0%) | 2/2 (100.0%) | 0/2 (0.0%) | 4/4 (100.0%) | 1/4 (25.0%) | 0/4 (0.0%) |
| foil | foil | 3/4 (75.0%) | 1/4 (25.0%) | 1/4 (25.0%) | 2/5 (40.0%) | 1/5 (20.0%) | 2/5 (40.0%) |
| foil | non-foil | 13/20 (65.0%) | 7/20 (35.0%) | 4/20 (20.0%) | 15/21 (71.4%) | 4/21 (19.0%) | 7/21 (33.3%) |
| frame treatment | borderless/showcase | 3/7 (42.9%) | 2/7 (28.6%) | 1/7 (14.3%) | 5/9 (55.6%) | 0/9 (0.0%) | 6/9 (66.7%) |
| frame treatment | regular | 13/17 (76.5%) | 6/17 (35.3%) | 4/17 (23.5%) | 12/17 (70.6%) | 5/17 (29.4%) | 3/17 (17.6%) |

| Exact printing (M15–ONE, MOM+), Phase 0 at 1080×1440 | Group | Hand (held out, n=24) | OpenCV (held out) | Baseline (held out) | Hand (development, biased) | OpenCV (development, biased) | Baseline (development) |
|---|---|---|---|---|---|---|---|
| overall | all | 9/22 (40.9%) | 4/22 (18.2%) | 6/22 (27.3%) | 17/22 (77.3%) | 1/22 (4.5%) | 10/22 (45.5%) |
| era | M15–ONE | 6/10 (60.0%) | 3/10 (30.0%) | 4/10 (40.0%) | 8/10 (80.0%) | 1/10 (10.0%) | 4/10 (40.0%) |
| era | MOM+ | 3/12 (25.0%) | 1/12 (8.3%) | 2/12 (16.7%) | 9/12 (75.0%) | 0/12 (0.0%) | 6/12 (50.0%) |
| foil | foil | 1/4 (25.0%) | 1/4 (25.0%) | 1/4 (25.0%) | 3/5 (60.0%) | 0/5 (0.0%) | 0/5 (0.0%) |
| foil | non-foil | 8/18 (44.4%) | 3/18 (16.7%) | 5/18 (27.8%) | 14/17 (82.4%) | 1/17 (5.9%) | 10/17 (58.8%) |
| frame treatment | borderless/showcase | 2/7 (28.6%) | 1/7 (14.3%) | 1/7 (14.3%) | 7/8 (87.5%) | 0/8 (0.0%) | 4/8 (50.0%) |
| frame treatment | regular | 7/15 (46.7%) | 3/15 (20.0%) | 5/15 (33.3%) | 10/14 (71.4%) | 1/14 (7.1%) | 6/14 (42.9%) |

The hand detector gives the same top 3 on the scaled photos as at full size (held out 19/24 both), with a lower exact printing (9/22 against 11/22).

## 6. Costs

**Files and licences (AC-2.7)**, from `sizes.rb` (`tmp/card_scanner_phase2/sizes.json`). Gzip is Ruby's Zlib at best compression, which stands in for the app's production proxy.

| Detector | Files | Stored | Gzip | Third-party component and licence |
|---|---|---|---|---|
| Hand-written | 5 (`canvas.js` 1,162; `warp.js` 3,327; `output.js` 339; `detect.js` 1,934; `hand_detector.js` 6,081) | 12,843 B | 5,062 B | None |
| OpenCV.js | 7 (the 5 above, `opencv_detector.js` 3,407, `opencv.js` 10,964,323) | 10,980,573 B | 3,570,593 B | OpenCV 4.13.0, Apache-2.0: compatible with AGPL-3.0 (Apache-2.0 code may be included in a GPL-3.0-family work) |

`opencv.js` alone compresses to 3,564,035 bytes with this Ruby (it links zlib-ng 1.3.1) and to 3,543,358 bytes with GNU `gzip -9`. The OpenCV files are fetched by `fetch_opencv.rb` into the ignored `tmp/card_scanner_phase2/opencv/4.13.0/`, pinned by version and SHA-256, and never committed. The 5 shared files include the spike page's own driver code, so the hand detector's figure is an upper bound for what the app would add.

**Detection and straightening (AC-2.9), desktop, headless Firefox 156, milliseconds.** Detection runs on a downscaled working copy; straightening warps the full photo.

| Run | Detect: n, median, slowest | Straighten: n, median, slowest |
|---|---|---|
| held-hand (full size) | 47, 104, 138 | 43, 111, 169 |
| held-opencv (full size) | 47, 8, 982 | 35, 113, 167 |
| held-hand-scaled (1080×1440) | 24, 103, 148 | 23, 72, 85 |
| held-opencv-scaled (1080×1440) | 24, 7, 1,031 | 18, 73.5, 84 |
| dev-hand-3, development | 52, 103, 134 | 52, 111.5, 135 |
| dev-opencv-5, development | 52, 8, 915 | 40, 113, 179 |

OpenCV's slowest detection in each run is the run's first photo (`IMG_6690` held out, 982 ms), which also waits for OpenCV.js to finish starting; later photos take a median of 7–8 ms. Straightening is only timed for photos where a card was reported.

**Text recognition, for comparison (desktop):** the shipped OCR of both strips took a median of 449 ms, slowest 781 ms, on the hand detector's held-out pictures (n=43); 479 ms and 836 ms on OpenCV's (n=35). Spec 007 measured 168 ms median on the iPhone. The desktop figures here come from a different browser and machine, so the two don't compare directly.

## 7. The art index (AC-4.1–AC-4.5, AC-4.7–AC-4.10)

### Fetch estimate and the maintainer's decision

The art index needs one image per artwork. This section estimated the cost of fetching all of them from Scryfall's image host, before any full fetch (AC-4.2). It was committed in `bc8c2a0` while the full fetch waited for the maintainer's approval.

**Bulk file.** `default-cards-20261002210553`, the file the app's catalog refresh downloaded.

**Artworks (AC-4.1).** `artworks.rb` keeps the entries the catalog imports: `lang` en, not digital, `"paper"` in `games`.

| Count | Value |
|---|---|
| Entries | 106,697 |
| Entries with an artwork id (front face) | 105,934 |
| Entries without an artwork id | 763 |
| Distinct artworks | 50,959 |

The first printing in the bulk file's order stands for each artwork, and its front-face image is the one fetched. 36 of the 50,959 artworks have no image URL in the bulk file (art-series printings). The fetcher lists them as failed and makes no request for them.

**Corpus artworks, fetched first (AC-4.3).** The 99 corpus photos show 98 distinct printings with 98 distinct artworks. These are needed whether or not the full fetch is approved, so they were fetched first, in both sizes. This also means the 500-artwork sample below is drawn from the artworks not yet cached, so it is a random sample of the remainder.

| Size | Fetched | Bytes | Seconds | Failed |
|---|---|---|---|---|
| `small` (146×204) | 98 | 1,304,453 | 18.3 | 0 of 98 |
| `normal` (488×680) | 98 | 9,393,700 | 24.3 | 0 of 98 |

**Estimate (AC-4.2).** `fetch_art.rb --size small --mode estimate`: a random sample of 500 uncached artworks, seed `20261003`, fetched at the throttled rate (at least 100 ms between requests, 2026-10-03).

| Figure | Value |
|---|---|
| Sample | 500 artworks, `small` size |
| Fetched | 500 of 500 |
| Failed | 0 of 500 |
| Bytes fetched | 6,965,982 |
| Time | 90.0 s |
| Per image | 13,932 bytes and 0.180 s (mean of 500) |
| Remaining images (not yet cached) | 50,361 |
| Remaining bytes (extrapolated from 500) | 701,627,639 (about 702 MB) |
| Remaining time (extrapolated from 500) | 2.52 hours |

The 50,361 remaining images include the 36 artworks without an image URL, which will fail without a request. The full fetch would take about 50,361 requests to `cards.scryfall.io`. A background task stops after 2 hours, so it would run in chunks of 90 minutes' worth: `floor(5400 / 0.180)` = 30,006 images per chunk, so two chunks. The cache makes it resumable; nothing is fetched twice.

Decision (maintainer, 2026-10-03): the full fetch was declined. The index covers a subset containing the artwork of all 99 corpus cards: the 98 corpus artworks plus the 500 sampled, 598 in all (AC-4.3). The first art-matching measurement (the subset columns in §9 and §10) is against that subset of 598 artworks.

Decision revised (maintainer, 2026-10-03): the full fetch is approved, to measure art matching against the full index (spec v1.2.0).

### The full fetch (AC-4.9)

`fetch_art.rb --size small --mode full`, run in chunks until one reported `fetched: 0`. The chunks' reports (`tmp/card_scanner_phase2/fetch_small_full_*.json`) were written between 2026-10-03T03:53:49Z and 06:21:35Z.

| Figure | Measured (full fetch) | Estimated beforehand (500-image sample) |
|---|---|---|
| Images fetched | 50,325 | 50,361 remaining (including the 36 without an image URL) |
| Bytes | 699,685,259 (about 700 MB) | 701,627,639 (about 702 MB) |
| Time | 9,340.5 s of fetching (2.59 hours) | 2.52 hours |
| Per image (mean) | 13,903 bytes and 0.186 s | 13,932 bytes and 0.180 s |
| Failed | 36 of 50,361: exactly the 36 artworks without an image URL, for which no request was made | — |
| Chunks | 19: 3 of 3,000 images, 14 of 2,800, one of 2,125, and a last one that fetched 0 | 2 of up to 30,006 (planned) |

With the 598 images already cached for the subset, every artwork with an image URL is cached: 50,325 + 598 = 50,923.

**A deviation from the plan.** The plan had the fetch run as background tasks of `--limit 30006` each (90 minutes' worth), within the 2-hour limit on a background task. It was run instead as foreground commands of at most 3,000 images each (393–556 s per fetching chunk), so that each finished inside the 10-minute limit on a foreground command. No chunk was killed or cut short; the cache resumed each chunk where the last had stopped, and nothing was fetched twice. The chunking changes the number of runs, not what was fetched or the rate: the throttle and the fetcher are the same.

### Fetch manners (AC-4.7)

`ArtFetcher` sends a descriptive `User-Agent` and `Accept: image/jpeg`, waits at least 100 ms between requests, sets 10 s open and 60 s read timeouts, and backs off on 429 and 5xx (`Retry-After`, else 2 s then 4 s, three attempts). Fetched images are kept in the ignored `tmp/card_scanner_phase2/artwork/<size>/` and a re-run doesn't fetch them again. No 429 was received during the corpus and estimate fetches. In the full fetch no request failed after its retries; the fetcher doesn't record a 429 that a retry recovered from, so whether any was received during the full fetch isn't known. Only the scripts contacted Scryfall; the spike page never did.

### The full index (AC-4.10)

| Figure | Value |
|---|---|
| Label in the index metadata | `full` (no `subset` field) |
| Artworks | 50,923: every one of the catalog's 50,959 artworks that has an image (AC-4.1) |
| Left out | 36 (`missing_artworks` 36, `missing_without_image` 36): the artworks without an image URL |
| Corpus artworks left out (AC-4.8) | none |
| Image per artwork | the first printing in bulk-file order, front face, `small` (146×204), as for the subset |
| Fingerprinting time | 1,066.6 s for 50,923 (about 17.8 minutes, desktop; about 21 ms each, as for the subset) |
| Index as stored | 7,332,912 bytes (50,923 × 144) and a 388-byte metadata file |
| Index compressed (zlib deflate, best) | 6,007,929 bytes (82% of stored, as for the subset) |
| Built | 2026-10-03T06:39:31Z, fingerprint settings commit `39cdc6e`, ImageMagick 7.1.2-31 (P6 decode) and pure Ruby |
| Bulk file | `default-cards-20261002210553` |

The subset index is kept beside it in the ignored `tmp/card_scanner_phase2/index-subset/`.

### The subset index (AC-4.3, AC-4.4, AC-4.8)

| Figure | Value |
|---|---|
| Subset | 598 artworks: the 98 corpus artworks and the 500-artwork random sample (seed `20261003`) |
| Image per artwork | the first printing in bulk-file order, front face, `small` (146×204) |
| Images fetched for it | 598 (`small`): 8,270,435 bytes in 108.3 s (corpus 98 in 18.3 s, sample 500 in 90.0 s) |
| Also fetched, for §8 only | 98 `normal` (488×680): 9,393,700 bytes in 24.3 s |
| Failed fetches | 0 of 598 |
| Corpus artworks left out (AC-4.8) | none |
| Fingerprinting time | 12.8 s for 598 (desktop) |
| Index as stored | 86,112 bytes (598 × 144: a 16-byte artwork id and a 128-byte fingerprint each) |
| Index compressed (zlib deflate, best) | 70,750 bytes |
| Built | 2026-10-03T01:45:53Z, settings commit `8152021` |

**What a full index costs an instance.** The fingerprints are close to random bits, so compression saves little: both indexes compress to 82% of their size. Every instance that builds its own index would make 50,923 requests to `cards.scryfall.io`: the spike's 598 for the subset and 50,325 in the full fetch came to 707,955,694 bytes and 9,448.8 s (2.62 hours) at the throttled rate (arithmetic, from the two measurements). It would then spend about 18 minutes fingerprinting on a machine like the desktop, and afterwards fetch only new artworks as sets are added.

### The tool and what the production build would add (AC-4.5)

The index is built by `build_index.rb`, outside the browser: ImageMagick 7.1.2-31 decodes each image to 8-bit P6, and pure Ruby crops, resamples and fingerprints it (`Ppm`, `Fingerprint`, `ArtIndex`). ImageMagick is on the development machine but not in `Gemfile.lock` or the app's `Dockerfile`. What it, or the alternative, would add, measured in `docker.io/library/ruby:4.0.7-slim` (the `Dockerfile`'s base, Debian 13.7) with Podman by apt resolution only, summing `Installed-Size` and `Size` over the packages apt would install with `--no-install-recommends`:

| Dependency | On the app's runtime image | On the bare base image |
|---|---|---|
| `imagemagick` (7.1.1.43) | 4 packages (`imagemagick`, `imagemagick-7.q16`, `libmagickwand-7.q16-10`, `hicolor-icon-theme`): 3,177 KiB installed, 1,132,596 B download. libvips already pulls in `libmagickcore` | 44 packages, 43,364 KiB installed, 15,078,240 B download |
| `libvips` (8.16.1) | 0: the `Dockerfile` already installs it | 122 packages, 130,647 KiB installed, 40,693,768 B download |
| `ruby-vips` gem 2.3.0 (alternative to ImageMagick) | 74,240 B gem, plus `ffi` 1.17.4 (531,456 B for x86_64-linux-gnu; 894,464 B source gem), which isn't in `Gemfile.lock`. Its other dependency, `logger`, is already in the bundle | — |

On a development machine the same packages apply: ImageMagick (or libvips with the `ruby-vips` and `ffi` gems). The spike didn't build an index with `ruby-vips`; its agreement with the browser would need checking as §8 did for ImageMagick.

## 8. Agreement (AC-4.6)

The index build (Ruby, ImageMagick decode) and the browser (canvas) compute the fingerprint with different code. `agreement.rb` fingerprinted the same source images both ways at `8152021`, before the freeze:

| Sample | n | Corpus artworks in it | Distance between the two fingerprints: median | Largest |
|---|---|---|---|---|
| `small` (146×204), the index's size | 198 (98 corpus + 100 others) | 98 of 98 | 0 bits | 0 bits |
| `normal` (488×680) | 98 | 98 of 98 | 0 bits | 0 bits |

Beside them (§9): the right artwork's median distance from a held-out photo is 203 bits and the nearest wrong artwork's 346 against the full index (211 and 385.5 against the subset). Between unrelated artworks in the subset index, distances run from 296 to 695 bits, median 510 (all 178,503 pairs of the 598 indexed fingerprints, computed from the index file for these findings). The same figure was not computed for the full index's 1.3 billion pairs. **The two computations agree exactly, so a fingerprint made in the browser can be matched against an index built in Ruby.** The disagreement the roadmap expected between resamplers doesn't arise here, because both sides implement the same area resampling rather than calling a library's.

## 9. Art matching (AC-3.1–AC-3.6, AC-3.8, AC-3.9)

The fingerprint was computed in the browser from the hand-written detector's straightened card, tried at the six offsets against every fingerprint in the index, keeping each artwork's smallest distance (AC-3.1). A photo where the detector found no card counts as a miss; a wrong outline is fingerprinted and scored like any other (AC-3.3).

Art matching was measured against two indexes. **The full index (50,923 artworks, §7) is the headline**: `held-hand-art-full`, held out, run once at `5ce0238`, and `dev-hand-3-art-full`, development, biased. **The 598-artwork subset**, measured first (`held-hand-art` at `39cdc6e`, `dev-hand-3-art`), sits beside it. No fingerprint setting changed between them, and each photo's six fingerprints are bit-identical in the two runs (§2), so every difference between the columns comes from the index.

**Held out, both corpora (n=47):**

| Right artwork first | Group | All photos, full index | Classed found, full index | All photos, subset | Classed found, subset |
|---|---|---|---|---|---|
| overall | all | 33/47 (70.2%) | 20/24 (83.3%) | 34/47 (72.3%) | 21/24 (87.5%) |
| era | M15–ONE | 13/22 (59.1%) | 7/10 (70.0%) | 14/22 (63.6%) | 8/10 (80.0%) |
| era | MOM+ | 16/21 (76.2%) | 10/11 (90.9%) | 16/21 (76.2%) | 10/11 (90.9%) |
| era | pre-M15 | 4/4 (100.0%) | 3/3 (100.0%) | 4/4 (100.0%) | 3/3 (100.0%) |
| foil | foil | 7/9 (77.8%) | 5/6 (83.3%) | 7/9 (77.8%) | 5/6 (83.3%) |
| foil | non-foil | 26/38 (68.4%) | 15/18 (83.3%) | 27/38 (71.1%) | 16/18 (88.9%) |
| frame treatment | borderless/showcase | 8/13 (61.5%) | 5/5 (100.0%) | 8/13 (61.5%) | 5/5 (100.0%) |
| frame treatment | regular | 25/34 (73.5%) | 15/19 (78.9%) | 26/34 (76.5%) | 16/19 (84.2%) |

| Right artwork in top 3 | Group | All photos, full index | Classed found, full index | All photos, subset | Classed found, subset |
|---|---|---|---|---|---|
| overall | all | 33/47 (70.2%) | 20/24 (83.3%) | 35/47 (74.5%) | 21/24 (87.5%) |
| era | M15–ONE | 13/22 (59.1%) | 7/10 (70.0%) | 14/22 (63.6%) | 8/10 (80.0%) |
| era | MOM+ | 16/21 (76.2%) | 10/11 (90.9%) | 17/21 (81.0%) | 10/11 (90.9%) |
| era | pre-M15 | 4/4 (100.0%) | 3/3 (100.0%) | 4/4 (100.0%) | 3/3 (100.0%) |
| foil | foil | 7/9 (77.8%) | 5/6 (83.3%) | 7/9 (77.8%) | 5/6 (83.3%) |
| foil | non-foil | 26/38 (68.4%) | 15/18 (83.3%) | 28/38 (73.7%) | 16/18 (88.9%) |
| frame treatment | borderless/showcase | 8/13 (61.5%) | 5/5 (100.0%) | 8/13 (61.5%) | 5/5 (100.0%) |
| frame treatment | regular | 25/34 (73.5%) | 15/19 (78.9%) | 27/34 (79.4%) | 16/19 (84.2%) |

**By corpus, against the full index**, with the development half beside it (biased: `dev-hand-3-art-full`, on the development detector run):

| Corpus | Right artwork first, held out | Top 3, held out | First, classed found, held out | Right artwork first, development, biased | Top 3, development, biased |
|---|---|---|---|---|---|
| Phase 0 | 17/24 (70.8%) | 17/24 (70.8%) | 17/20 (85.0%) | 23/26 (88.5%) | 23/26 (88.5%) |
| New corpus | 16/23 (69.6%) | 16/23 (69.6%) | 3/4 (75.0%) | 23/26 (88.5%) | 23/26 (88.5%) |
| Both | 33/47 (70.2%) | 33/47 (70.2%) | 20/24 (83.3%) | 46/52 (88.5%) | 46/52 (88.5%) |

**By corpus, against the 598-artwork subset** (`dev-hand-3-art` for the development columns):

| Corpus | Right artwork first, held out | Top 3, held out | First, classed found, held out | Right artwork first, development, biased | Top 3, development, biased |
|---|---|---|---|---|---|
| Phase 0 | 18/24 (75.0%) | 18/24 (75.0%) | 18/20 (90.0%) | 23/26 (88.5%) | 24/26 (92.3%) |
| New corpus | 16/23 (69.6%) | 17/23 (73.9%) | 3/4 (75.0%) | 26/26 (100.0%) | 26/26 (100.0%) |
| Both | 34/47 (72.3%) | 35/47 (74.5%) | 21/24 (87.5%) | 49/52 (94.2%) | 50/52 (96.2%) |

<details>
<summary>By era, foil and frame treatment for each corpus, held out, against the full index</summary>

| Right artwork first | Group | Phase 0, all (24) | Phase 0, found (20) | New, all (23) | New, found (4) |
|---|---|---|---|---|---|
| era | M15–ONE | 5/10 (50.0%) | 5/8 (62.5%) | 8/12 (66.7%) | 2/2 (100.0%) |
| era | MOM+ | 10/12 (83.3%) | 10/10 (100.0%) | 6/9 (66.7%) | 0/1 (0.0%) |
| era | pre-M15 | 2/2 (100.0%) | 2/2 (100.0%) | 2/2 (100.0%) | 1/1 (100.0%) |
| foil | foil | 3/4 (75.0%) | 3/4 (75.0%) | 4/5 (80.0%) | 2/2 (100.0%) |
| foil | non-foil | 14/20 (70.0%) | 14/16 (87.5%) | 12/18 (66.7%) | 1/2 (50.0%) |
| frame treatment | borderless/showcase | 4/7 (57.1%) | 4/4 (100.0%) | 4/6 (66.7%) | 1/1 (100.0%) |
| frame treatment | regular | 13/17 (76.5%) | 13/16 (81.2%) | 12/17 (70.6%) | 2/3 (66.7%) |

| Right artwork in top 3 | Group | Phase 0, all (24) | Phase 0, found (20) | New, all (23) | New, found (4) |
|---|---|---|---|---|---|
| era | M15–ONE | 5/10 (50.0%) | 5/8 (62.5%) | 8/12 (66.7%) | 2/2 (100.0%) |
| era | MOM+ | 10/12 (83.3%) | 10/10 (100.0%) | 6/9 (66.7%) | 0/1 (0.0%) |
| era | pre-M15 | 2/2 (100.0%) | 2/2 (100.0%) | 2/2 (100.0%) | 1/1 (100.0%) |
| foil | foil | 3/4 (75.0%) | 3/4 (75.0%) | 4/5 (80.0%) | 2/2 (100.0%) |
| foil | non-foil | 14/20 (70.0%) | 14/16 (87.5%) | 12/18 (66.7%) | 1/2 (50.0%) |
| frame treatment | borderless/showcase | 4/7 (57.1%) | 4/4 (100.0%) | 4/6 (66.7%) | 1/1 (100.0%) |
| frame treatment | regular | 13/17 (76.5%) | 13/16 (81.2%) | 12/17 (70.6%) | 2/3 (66.7%) |

</details>

<details>
<summary>By era, foil and frame treatment for each corpus, held out, against the 598-artwork subset</summary>

| Right artwork first | Group | Phase 0, all (24) | Phase 0, found (20) | New, all (23) | New, found (4) |
|---|---|---|---|---|---|
| era | M15–ONE | 6/10 (60.0%) | 6/8 (75.0%) | 8/12 (66.7%) | 2/2 (100.0%) |
| era | MOM+ | 10/12 (83.3%) | 10/10 (100.0%) | 6/9 (66.7%) | 0/1 (0.0%) |
| era | pre-M15 | 2/2 (100.0%) | 2/2 (100.0%) | 2/2 (100.0%) | 1/1 (100.0%) |
| foil | foil | 3/4 (75.0%) | 3/4 (75.0%) | 4/5 (80.0%) | 2/2 (100.0%) |
| foil | non-foil | 15/20 (75.0%) | 15/16 (93.8%) | 12/18 (66.7%) | 1/2 (50.0%) |
| frame treatment | borderless/showcase | 4/7 (57.1%) | 4/4 (100.0%) | 4/6 (66.7%) | 1/1 (100.0%) |
| frame treatment | regular | 14/17 (82.4%) | 14/16 (87.5%) | 12/17 (70.6%) | 2/3 (66.7%) |

| Right artwork in top 3 | Group | Phase 0, all (24) | Phase 0, found (20) | New, all (23) | New, found (4) |
|---|---|---|---|---|---|
| era | M15–ONE | 6/10 (60.0%) | 6/8 (75.0%) | 8/12 (66.7%) | 2/2 (100.0%) |
| era | MOM+ | 10/12 (83.3%) | 10/10 (100.0%) | 7/9 (77.8%) | 0/1 (0.0%) |
| era | pre-M15 | 2/2 (100.0%) | 2/2 (100.0%) | 2/2 (100.0%) | 1/1 (100.0%) |
| foil | foil | 3/4 (75.0%) | 3/4 (75.0%) | 4/5 (80.0%) | 2/2 (100.0%) |
| foil | non-foil | 15/20 (75.0%) | 15/16 (93.8%) | 13/18 (72.2%) | 1/2 (50.0%) |
| frame treatment | borderless/showcase | 4/7 (57.1%) | 4/4 (100.0%) | 4/6 (66.7%) | 1/1 (100.0%) |
| frame treatment | regular | 14/17 (82.4%) | 14/16 (87.5%) | 13/17 (76.5%) | 2/3 (66.7%) |

</details>

<details>
<summary>Development, biased (52), both corpora, by era, foil and frame treatment: full index and subset</summary>

| Right artwork first | Group | All photos, full index | Classed found, full index | All photos, subset | Classed found, subset |
|---|---|---|---|---|---|
| overall | all | 46/52 (88.5%) | 32/35 (91.4%) | 49/52 (94.2%) | 34/35 (97.1%) |
| era | M15–ONE | 23/26 (88.5%) | 14/15 (93.3%) | 25/26 (96.2%) | 15/15 (100.0%) |
| era | MOM+ | 16/19 (84.2%) | 11/13 (84.6%) | 17/19 (89.5%) | 12/13 (92.3%) |
| era | pre-M15 | 7/7 (100.0%) | 7/7 (100.0%) | 7/7 (100.0%) | 7/7 (100.0%) |
| foil | foil | 10/11 (90.9%) | 8/8 (100.0%) | 10/11 (90.9%) | 8/8 (100.0%) |
| foil | non-foil | 36/41 (87.8%) | 24/27 (88.9%) | 39/41 (95.1%) | 26/27 (96.3%) |
| frame treatment | borderless/showcase | 13/15 (86.7%) | 10/11 (90.9%) | 14/15 (93.3%) | 11/11 (100.0%) |
| frame treatment | regular | 33/37 (89.2%) | 22/24 (91.7%) | 35/37 (94.6%) | 23/24 (95.8%) |

| Right artwork in top 3 | Group | All photos, full index | Classed found, full index | All photos, subset | Classed found, subset |
|---|---|---|---|---|---|
| overall | all | 46/52 (88.5%) | 32/35 (91.4%) | 50/52 (96.2%) | 35/35 (100.0%) |
| era | M15–ONE | 23/26 (88.5%) | 14/15 (93.3%) | 25/26 (96.2%) | 15/15 (100.0%) |
| era | MOM+ | 16/19 (84.2%) | 11/13 (84.6%) | 18/19 (94.7%) | 13/13 (100.0%) |
| era | pre-M15 | 7/7 (100.0%) | 7/7 (100.0%) | 7/7 (100.0%) | 7/7 (100.0%) |
| foil | foil | 10/11 (90.9%) | 8/8 (100.0%) | 10/11 (90.9%) | 8/8 (100.0%) |
| foil | non-foil | 36/41 (87.8%) | 24/27 (88.9%) | 40/41 (97.6%) | 27/27 (100.0%) |
| frame treatment | borderless/showcase | 13/15 (86.7%) | 10/11 (90.9%) | 14/15 (93.3%) | 11/11 (100.0%) |
| frame treatment | regular | 33/37 (89.2%) | 22/24 (91.7%) | 36/37 (97.3%) | 24/24 (100.0%) |

</details>

On the new corpus, art matching held up where reading didn't: right artwork first for 16/23 against the full index, as against the subset, although only 4 of the 23 outlines were classed found. The art box (y 0.16–0.50) sits in the middle of the card, so an outline that stops above the bottom edge still covers most of it.

### What the full index loses (AC-3.9)

Comparing each photo's results against the two indexes: held out, the full index lost 1 of the subset's 34 right-artwork-first results (34 → 33) and 2 of its 35 top-3 results (35 → 33). Development, biased, it lost 3 of 49 first results (49 → 46) and 4 of 50 top-3 results (50 → 46). It gained none in either half.

| File | Half | Expected | Class (hand) | Lost | Subset: rank, right artwork's distance | Full index: rank, right artwork's distance | Ranked first by the full index (its printing's name), distance |
|---|---|---|---|---|---|---|---|
| IMG_6709.jpeg | held out | Sword of the Animist | found | first and top 3 | 1, 377 (nearest wrong 381) | not in the 10 returned | `a9526ac2…` (Icy Manipulator), 324 |
| IMG_6759.jpeg | held out | Repurposed Enforcer | wrong outline | top 3 | 2, 360 (first `5ebb66f2…`, Lightning Greaves, 357) | not in the 10 returned | `7a61214d…` (Heirloom Mirror // Inherited Fiend), 325 |
| IMG_6723.jpeg | development, biased | Invasion of Tarkir // Defiant Thundermaw | found | top 3 | 2, 360 | not in the 10 returned | `c9183023…` (Invasion of Kaladesh // Aetherwing, Golden-Scale Flagship), 272 |
| IMG_6758.jpeg | development, biased | Minsc, Beloved Ranger | found | first and top 3 | 1, 347 | 10, 347 | `21ad95e1…` (Spirit), 318 |
| IMG_6767.jpeg | development, biased | Trigger Happy | wrong outline | first and top 3 | 1, 394 | not in the 10 returned | `83d0fbcd…` (Trickery Charm), 371 |
| IMG_6774.jpeg | development, biased | Merry, Esquire of Rohan | found | first and top 3 | 1, 330 | 4, 330 | `d9f19630…` (Clattering Skeletons), 323 |

**Why.** Each loss was a weak match that ranked high on the subset only because the subset had few rivals. The right artwork's distance was 330–394 bits, against medians of 203 (held out) and 213 (development) for the right artwork against the full index, and at or above 296 bits, the smallest distance between two artworks in the subset index (§8). The right artwork's distance itself doesn't change between the indexes (the same fingerprint is compared with the same record, as `IMG_6758` and `IMG_6774` show); what changes is that among 85 times as many wrong artworks, one now lies nearer (272–371 bits). No match nearer than 296 bits was lost in either half. Of the 7 held-out first choices on the subset at 296 bits or more, which the subset findings named as the ones at risk, 1 was lost (`IMG_6709`) and 6 kept; of the 9 such development first choices, 3 were lost. `IMG_6723` is a battle card, printed sideways (§4), and the artwork now ranked first is another battle's.

The text path had the right card in its top 3 for both held-out losses, so "text top 3 or art first" is unchanged at 40/47. In the development half it had it for 3 of the 4 (not `IMG_6767`), so that figure falls from 52/52 to 51/52.

**Other printings' artworks.** The full index also holds the artworks of other printings of the same card, which the bulk file gives their own artwork ids. For `IMG_6777` (Ritual Guardian, wrong outline) the artwork ranked first, at 163 bits, is another Ritual Guardian printing's (`9c0535c5…`), not the ground truth's (`bb22efe0…`, not in the 10 returned). It is scored as a miss, but it names the right card. For 6 more photos (`IMG_6788` held out; `IMG_6725`, `IMG_6784`, `IMG_6794`, `IMG_6800`, `IMG_6802` development) the right artwork came first and the nearest wrong one belonged to a printing of the same card, 2–57 bits behind.

**Distances (AC-3.4), held out.** The search returns the 10 nearest artworks; the right artwork's distance is known when it is among them (33 of 47 photos against the full index, 36 against the subset).

| Summary, held out | Full index (50,923) | 598-artwork subset |
|---|---|---|
| Photos with the right artwork among the 10 returned | 33 of 47 | 36 of 47 |
| Median distance to the right artwork | 203 bits | 211 bits |
| Median distance to the nearest wrong artwork | 346 bits | 385.5 bits |
| Right artwork nearer than every wrong one | 33 of 33 | 34 of 36 |
| Phase 0: medians, right nearer | 203 / 357; 17 of 17 | 211 / 390; 18 of 18 |
| New corpus: medians, right nearer | 202.5 / 338; 16 of 16 | 225 / 379; 16 of 18 |
| Development, biased: medians, right nearer | 213 / 342.5; 46 of 48 | 215 / 381; 49 of 50 |

The right artwork's median falls from 211 to 203 bits only because the three photos that left the 10 returned had large distances (360, 377 and 421); no right-artwork distance changed. The nearest wrong artwork is nearer for all 43 searched photos, by 4 to 185 bits (`IMG_6777`'s from 348 to 163).

The margins vary. Of the 33 photos where the right artwork came first against the full index, the smallest gap to the nearest wrong artwork was 15 bits (`IMG_6788`: 308 against 323, another Ascendant Packleader printing's artwork), and 6 had a right-artwork distance of 296 bits or more. Against the subset the smallest gap was 4 bits (`IMG_6709`: 377 against 381), the photo the full index lost.

<details>
<summary>Per photo, held out (47), against the full index and the 598-artwork subset</summary>

| File | Corpus | Class (hand) | Full index: right artwork's distance | Full index: nearest wrong | Full index: rank | Subset: right artwork's distance | Subset: nearest wrong | Subset: rank |
|---|---|---|---|---|---|---|---|---|
| IMG_6690.jpeg | Phase 0 | not found | not searched | — | — | not searched | — | — |
| IMG_6692.jpeg | Phase 0 | found | 302 | 339 | 1 | 302 | 387 | 1 |
| IMG_6702.jpeg | Phase 0 | found | 319 | 360 | 1 | 319 | 397 | 1 |
| IMG_6705.jpeg | Phase 0 | wrong outline | not in the 10 returned | 350 | — | not in the 10 returned | 391 | — |
| IMG_6707.jpeg | Phase 0 | found | 159 | 334 | 1 | 159 | 371 | 1 |
| IMG_6709.jpeg | Phase 0 | found | not in the 10 returned | 324 | — | 377 | 381 | 1 |
| IMG_6711.jpeg | Phase 0 | found | not in the 10 returned | 338 | — | not in the 10 returned | 405 | — |
| IMG_6713.jpeg | Phase 0 | found | 239 | 348 | 1 | 239 | 397 | 1 |
| IMG_6715.jpeg | Phase 0 | found | 168 | 359 | 1 | 168 | 390 | 1 |
| IMG_6717.jpeg | Phase 0 | found | 116 | 346 | 1 | 116 | 398 | 1 |
| IMG_6719.jpeg | Phase 0 | found | not in the 10 returned | 349 | — | not in the 10 returned | 405 | — |
| IMG_6720.jpeg | Phase 0 | found | 198 | 356 | 1 | 198 | 373 | 1 |
| IMG_6722.jpeg | Phase 0 | found | 354 | 371 | 1 | 354 | 408 | 1 |
| IMG_6724.jpeg | Phase 0 | found | 264 | 371 | 1 | 264 | 409 | 1 |
| IMG_6727.jpeg | Phase 0 | not found | not searched | — | — | not searched | — | — |
| IMG_6729.jpeg | Phase 0 | found | 224 | 385 | 1 | 224 | 416 | 1 |
| IMG_6731.jpeg | Phase 0 | found | 141 | 357 | 1 | 141 | 379 | 1 |
| IMG_6732.jpeg | Phase 0 | found | 176 | 335 | 1 | 176 | 388 | 1 |
| IMG_6734.jpeg | Phase 0 | found | 134 | 363 | 1 | 134 | 373 | 1 |
| IMG_6737.jpeg | Phase 0 | found | 203 | 349 | 1 | 203 | 415 | 1 |
| IMG_6738.jpeg | Phase 0 | found | 122 | 332 | 1 | 122 | 386 | 1 |
| IMG_6740.jpeg | Phase 0 | found | 236 | 361 | 1 | 236 | 390 | 1 |
| IMG_6742.jpeg | Phase 0 | wrong outline | not in the 10 returned | 362 | — | not in the 10 returned | 366 | — |
| IMG_6745.jpeg | Phase 0 | found | 219 | 357 | 1 | 219 | 405 | 1 |
| IMG_6757.jpeg | new | wrong outline | 275 | 294 | 1 | 275 | 351 | 1 |
| IMG_6759.jpeg | new | wrong outline | not in the 10 returned | 325 | — | 360 | 357 | 2 |
| IMG_6761.jpeg | new | wrong outline | 255 | 292 | 1 | 255 | 356 | 1 |
| IMG_6764.jpeg | new | found | 259 | 341 | 1 | 259 | 349 | 1 |
| IMG_6766.jpeg | new | wrong outline | not in the 10 returned | 366 | — | not in the 10 returned | 410 | — |
| IMG_6769.jpeg | new | found | 142 | 335 | 1 | 142 | 383 | 1 |
| IMG_6770.jpeg | new | wrong outline | 170 | 341 | 1 | 170 | 390 | 1 |
| IMG_6773.jpeg | new | found | 194 | 343 | 1 | 194 | 384 | 1 |
| IMG_6776.jpeg | new | wrong outline | 203 | 344 | 1 | 203 | 366 | 1 |
| IMG_6777.jpeg | new | wrong outline | not in the 10 returned | 163 | — | not in the 10 returned | 348 | — |
| IMG_6780.jpeg | new | wrong outline | 170 | 352 | 1 | 170 | 385 | 1 |
| IMG_6782.jpeg | new | not found | not searched | — | — | not searched | — | — |
| IMG_6785.jpeg | new | not found | not searched | — | — | not searched | — | — |
| IMG_6786.jpeg | new | wrong outline | 170 | 312 | 1 | 170 | 371 | 1 |
| IMG_6788.jpeg | new | wrong outline | 308 | 323 | 1 | 308 | 387 | 1 |
| IMG_6791.jpeg | new | wrong outline | 202 | 363 | 1 | 202 | 385 | 1 |
| IMG_6793.jpeg | new | wrong outline | 158 | 333 | 1 | 158 | 386 | 1 |
| IMG_6795.jpeg | new | wrong outline | 247 | 353 | 1 | 247 | 369 | 1 |
| IMG_6797.jpeg | new | wrong outline | 163 | 291 | 1 | 163 | 354 | 1 |
| IMG_6799.jpeg | new | wrong outline | 314 | 377 | 1 | 314 | 393 | 1 |
| IMG_6801.jpeg | new | wrong outline | not in the 10 returned | 361 | — | not in the 10 returned | 380 | — |
| IMG_6803.jpeg | new | wrong outline | 296 | 328 | 1 | 296 | 375 | 1 |
| IMG_6805.jpeg | new | found | not in the 10 returned | 366 | — | 421 | 396 | 9 |
</details>

**What art adds to text (AC-3.5)**, on the same straightened cards, held out:

| Held out | Phase 0 (24) | New corpus (23) | Both (47) | Development, biased (52) |
|---|---|---|---|---|
| Right card not in the text path's final top 3 | 5 | 10 | 15 | 9 |
| Of those, right artwork first: full index | 2 | 6 | 8 | 8 |
| Of those, right artwork first: subset | 2 | 6 | 8 | 9 |
| Right card in the text top 3 or right artwork first: full index | 21/24 (87.5%) | 19/23 (82.6%) | 40/47 (85.1%) | 51/52 (98.1%) |
| Right card in the text top 3 or right artwork first: subset | 21/24 (87.5%) | 19/23 (82.6%) | 40/47 (85.1%) | 52/52 (100.0%) |
| Text top 3 alone, for comparison | 19/24 (79.2%) | 13/23 (56.5%) | 32/47 (68.1%) | 43/52 (82.7%) |

**Narrowing the printing (AC-3.6).** The 34 held-out cards whose collector line didn't give the exact printing, including every card whose frame prints no set code. For each: the printings among the entries the index covers (the catalog's English paper entries) that share the card's name, and those that share its artwork.

| Held out | Value |
|---|---|
| Cards | 34 |
| Median printings sharing the name | 3 |
| Median printings sharing the artwork | 2 |
| Cards whose artwork belongs to exactly one printing | 14 of 34 (41.2%) |
| Phase 0 (13 cards): medians; exactly one | 5 / 2; 4 of 13 |
| New corpus (21 cards): medians; exactly one | 2 / 2; 10 of 21 |
| Development, biased (32 cards): medians; exactly one | 3 / 1.5; 16 of 32 |

<details>
<summary>Per card, held out (34)</summary>

| File | Card | Printings sharing the name | Printings sharing the artwork |
|---|---|---|---|
| IMG_6690.jpeg | Sally Pride, Lioness Leader | 2 | 1 |
| IMG_6705.jpeg | Cloudsteel Kirin | 5 | 4 |
| IMG_6709.jpeg | Sword of the Animist | 17 | 9 |
| IMG_6719.jpeg | Folk Hero | 4 | 2 |
| IMG_6720.jpeg | Fanged Flames | 1 | 1 |
| IMG_6722.jpeg | Shared Animosity | 6 | 1 |
| IMG_6727.jpeg | Desert Were-Worm | 3 | 2 |
| IMG_6729.jpeg | Herd Heirloom | 4 | 3 |
| IMG_6732.jpeg | Balefire Dragon | 8 | 2 |
| IMG_6734.jpeg | Elixir of Immortality | 9 | 7 |
| IMG_6737.jpeg | Leyline of the Guildpact | 4 | 4 |
| IMG_6740.jpeg | Stormcarved Coast | 13 | 1 |
| IMG_6745.jpeg | Kazandu Refuge | 12 | 12 |
| IMG_6757.jpeg | Invasion of Muraganda // Primordial Plasm | 1 | 1 |
| IMG_6759.jpeg | Repurposed Enforcer | 2 | 1 |
| IMG_6761.jpeg | Orzhova, the Church of Deals | 2 | 2 |
| IMG_6764.jpeg | Tormod's Crypt | 12 | 8 |
| IMG_6766.jpeg | Gray Merchant of Alphabet | 2 | 2 |
| IMG_6770.jpeg | Ajani Unrelenting | 2 | 1 |
| IMG_6773.jpeg | Flameskull | 5 | 6 |
| IMG_6776.jpeg | Shock | 31 | 1 |
| IMG_6777.jpeg | Ritual Guardian | 2 | 2 |
| IMG_6780.jpeg | Ghalta and Mavren | 6 | 4 |
| IMG_6782.jpeg | Sunblade Samurai | 3 | 1 |
| IMG_6785.jpeg | Dunland Crebain | 3 | 1 |
| IMG_6786.jpeg | Great Ugly-Looking Goblin // Clap! Snap! | 3 | 2 |
| IMG_6788.jpeg | Ascendant Packleader | 5 | 4 |
| IMG_6791.jpeg | Way of the Deathbringer | 1 | 1 |
| IMG_6793.jpeg | Coronation of Chaos | 2 | 2 |
| IMG_6795.jpeg | Daring Demolition | 2 | 2 |
| IMG_6797.jpeg | Vengeant Earth | 1 | 1 |
| IMG_6799.jpeg | +2 Mace | 1 | 1 |
| IMG_6803.jpeg | Thriving Rats | 1 | 1 |
| IMG_6805.jpeg | Treason of Isengard | 2 | 2 |

Flameskull's artwork is shared by 6 entries but its name by only 5: one printing with that artwork carries another name.
</details>

The counts above don't depend on the index: they count the catalog's entries, so they are the same for both indexes. Of the 14 held-out cards whose artwork belongs to exactly one printing, the right artwork was first for 10 against the full index (10 against the subset); of all 34, for 23 (24 against the subset). Development, biased: 15 of 16 against the full index (16 of 16 against the subset).

**Art-matching misses, held out (AC-3.8)**, right artwork not first against the full index, 14 of 47:

| File | Expected | Artwork ranked first (its printing's name) | Right artwork's distance | Nearest wrong | Class | Likely cause |
|---|---|---|---|---|---|---|
| IMG_6690.jpeg | Sally Pride, Lioness Leader | — | — | — | not found | No card, so no fingerprint (tilt, §4) |
| IMG_6705.jpeg | Cloudsteel Kirin | `4f8d740f…` (Noble's Purse) | not in the 10 returned | 350 | wrong outline | The outline's top is on the art box, so the art box is shifted down |
| IMG_6709.jpeg | Sword of the Animist | `a9526ac2…` (Icy Manipulator) | not in the 10 returned | 324 | found | A weak match: first on the subset at 377 bits, by 4; among 50,923 artworks a wrong one lies nearer |
| IMG_6711.jpeg | Kodama's Reach | `dfa04573…` (Arcane Bombardment) | not in the 10 returned | 338 | found | Not established: the card was found; the art in the photo is dark and low in contrast |
| IMG_6719.jpeg | Folk Hero | `db8aac19…` (Cursed Firebreathing Yogurt) | not in the 10 returned | 349 | found | Foil sheen over the art |
| IMG_6727.jpeg | Desert Were-Worm | — | — | — | not found | No card, so no fingerprint (§4) |
| IMG_6742.jpeg | Abundant Harvest | `9789bc68…` (Lightkeeper of Emeria) | not in the 10 returned | 362 | wrong outline | The outline's top is inside the art, so the art box is shifted |
| IMG_6759.jpeg | Repurposed Enforcer | `7a61214d…` (Heirloom Mirror // Inherited Fiend) | not in the 10 returned | 325 | wrong outline | The outline stops above the bottom edge, stretching the art box; second on the subset at 360 bits, it falls out of the 10 returned |
| IMG_6766.jpeg | Gray Merchant of Alphabet | `b2d07fea…` (Vivid Creek) | not in the 10 returned | 366 | wrong outline | The outline stops above the bottom edge, stretching the art box |
| IMG_6777.jpeg | Ritual Guardian | `9c0535c5…` (Ritual Guardian) | not in the 10 returned | 163 | wrong outline | The outline stops above the bottom edge, stretching the art box; the artwork ranked first is another Ritual Guardian printing's, so it names the right card |
| IMG_6782.jpeg | Sunblade Samurai | — | — | — | not found | No card, so no fingerprint (§4) |
| IMG_6785.jpeg | Dunland Crebain | — | — | — | not found | No card, so no fingerprint (§4) |
| IMG_6801.jpeg | Renegade's Getaway | `10cc921b…` (Ashnod's Altar) | not in the 10 returned | 361 | wrong outline | The outline's top is below the name bar, so the art box is shifted down |
| IMG_6805.jpeg | Treason of Isengard | `cb164a55…` (As Foretold) | not in the 10 returned | 366 | found | Not established: the card was found; the photo is dim and blue-cast (ninth on the subset at 421 bits) |

Of the 14: 4 had no card, 6 a wrong outline, 4 a found card (one foil). The text path had the right card in its top 3 for 7 of these 14 (`IMG_6709`, `IMG_6711`, `IMG_6719`, `IMG_6742`, `IMG_6759`, `IMG_6766`, `IMG_6801`), so text and art fail on largely different photos. Both failed on 7: the 4 not found, and `IMG_6705`, `IMG_6777` and `IMG_6805`.

<details>
<summary>Art-matching misses, held out, against the 598-artwork subset (13 of 47)</summary>

| File | Expected | Artwork ranked first (its printing's name) | Right artwork's distance | Nearest wrong | Class | Likely cause |
|---|---|---|---|---|---|---|
| IMG_6690.jpeg | Sally Pride, Lioness Leader | — | — | — | not found | No card, so no fingerprint (tilt, §4) |
| IMG_6705.jpeg | Cloudsteel Kirin | `a9758017…` (Reclusive Taxidermist) | not in the 10 returned | 391 | wrong outline | The outline's top is on the art box, so the art box is shifted down |
| IMG_6711.jpeg | Kodama's Reach | `fcc59ddb…` (Aerie Bowmasters) | not in the 10 returned | 405 | found | Not established: the card was found; the art in the photo is dark and low in contrast |
| IMG_6719.jpeg | Folk Hero | `418c3e0d…` (Winterthorn Blessing) | not in the 10 returned | 405 | found | Foil sheen over the art |
| IMG_6727.jpeg | Desert Were-Worm | — | — | — | not found | No card, so no fingerprint (§4) |
| IMG_6742.jpeg | Abundant Harvest | `c8ccd634…` (Second Sunrise) | not in the 10 returned | 366 | wrong outline | The outline's top is inside the art, so the art box is shifted |
| IMG_6759.jpeg | Repurposed Enforcer | `5ebb66f2…` (Lightning Greaves) | 360 (rank 2) | 357 | wrong outline | The outline stops above the bottom edge, stretching the art box; the right artwork lost by 3 bits |
| IMG_6766.jpeg | Gray Merchant of Alphabet | `f8a488cf…` (Electrostatic Pummeler) | not in the 10 returned | 410 | wrong outline | The outline stops above the bottom edge, stretching the art box |
| IMG_6777.jpeg | Ritual Guardian | `2391d548…` (Zombie) | not in the 10 returned | 348 | wrong outline | The outline stops above the bottom edge, stretching the art box |
| IMG_6782.jpeg | Sunblade Samurai | — | — | — | not found | No card, so no fingerprint (§4) |
| IMG_6785.jpeg | Dunland Crebain | — | — | — | not found | No card, so no fingerprint (§4) |
| IMG_6801.jpeg | Renegade's Getaway | `a60a824f…` (Moonsilver Spear) | not in the 10 returned | 380 | wrong outline | The outline's top is below the name bar, so the art box is shifted down |
| IMG_6805.jpeg | Treason of Isengard | `a9758017…` (Reclusive Taxidermist) | 421 (rank 9) | 396 | found | Not established: the card was found; the photo is dim and blue-cast |

Of the 13: 4 had no card, 6 a wrong outline, 3 a found card (one foil). The text path had the right card in its top 3 for 6 of these 13 (`IMG_6711`, `IMG_6719`, `IMG_6742`, `IMG_6759`, `IMG_6766`, `IMG_6801`), so text and art fail on largely different photos. Both failed on 7: the 4 not found, and `IMG_6705`, `IMG_6777` and `IMG_6805`.
</details>

## 10. Search costs (AC-3.7, AC-3.10)

Desktop figures, held out (n=43 photos with a fingerprint), against the full index (50,923 artworks):

| Step | Where | Timed span | Median | Slowest |
|---|---|---|---|---|
| Fingerprint one photo | browser (headless Firefox 156) | crop, resample and hash the six offset boxes of the straightened card | 76 ms | 100 ms |
| Search the index | browser | six Hamming distances per artwork over the loaded index and the top-10 sort | 77 ms | 93 ms |
| Search the index | server: Ruby on the maintainer's machine, nothing outside the app's bundle (`search_server.rb`) | `ArtIndex#search` over the loaded index for the fingerprint the browser made: six Hamming distances per artwork and the top-10 sort; excludes loading the index | 2,667.4 ms | 3,314.7 ms |

The Ruby search ranked the same first artwork as the browser for 43 of 43 photos. Development, biased (n=52): fingerprint 77 ms median, 99 ms slowest; browser search 76 / 109 ms; Ruby search 2,622.8 / 2,690.6 ms, same first artwork 52 of 52.

Against the 598-artwork subset, for comparison (same photos, same timed spans):

| Step | Where | Median | Slowest |
|---|---|---|---|
| Fingerprint one photo | browser | 81 ms | 129 ms |
| Search the index | browser | 1 ms | 3 ms |
| Search the index | server, Ruby | 30.9 ms | 41.4 ms |

Development, biased (n=52), against the subset: fingerprint 81 / 113 ms; browser search 1 / 3 ms; Ruby search 30.9 / 47.8 ms, same first artwork 52 of 52. The fingerprint is the same computation in both runs; its 76 ms against 81 ms is the variation between two runs on the same desktop. The search does one pass over every artwork, so its time grows with the index: scaled by 50,923/598, the subset's medians had suggested about 85 ms in the browser and about 2.6 s in Ruby, and the full index measured 77 ms and 2.67 s.

**The index as a download (AC-3.10).** The full index is 7,332,912 bytes as stored and 6,007,929 bytes compressed (zlib deflate, best; §7), with a 388-byte metadata file. The 598-artwork index is 86,112 bytes, 70,750 compressed. The time to download the full index to a phone, and to search it there, was not measured (§12).

## 11. Replays (AC-2.10)

Each detector was replayed twice over the 52 development photos at the frozen settings (`39cdc6e`). An outcome is the detection class and whether the right card is in the final top 3.

| Detector | Runs | Photos whose outcome differs | Top 3, final ranking, each run (development, biased) |
|---|---|---|---|
| Hand | `dev-hand-r1`, `dev-hand-r2` | 0 of 52 | 43/52 both |
| OpenCV | `dev-opencv-r1`, `dev-opencv-r2` | 0 of 52 | 14/52 both |

The straightened images are pixel-identical between the two replays, and identical to the earlier `dev-hand-3` (52 of 52) and `dev-opencv-5` (40 of 40; 12 not found in both). Their raw PNG bytes differ only because Firefox writes a private `deBG` chunk of 16 random hex characters into every canvas PNG. The replay classes were judged from their contact sheets; where an edge case was marginal, it was given the class already recorded for the same, pixel-identical image.

## 12. Not measured (AC-5.3)

- **Every phone figure.** Download time of either detector or of the full index (6,007,929 bytes compressed), detection, straightening, fingerprint or search time on a phone, and memory use on a phone, including holding the 7.3 MB index in a phone's browser. Every timing above is from the desktop.
- **Real live capture.** No live frame was stored or replayed (none exists: spec 007 kept only the strips). The effect of detection or art matching on live capture is unknown. §5's scaled photos are a stand-in, not a measure of it.
- **The full index, beyond the desktop.** Its fetch, build, size, accuracy and desktop search times are measured (§7, §9, §10). Not measured: the smallest distance between two of its artworks (§8 gives the subset's), any server search other than pure Ruby (a native extension or a search in SQL), and whether a 429 was received and recovered from during the full fetch (§7).
- **Building the index during the catalog refresh**, in the app's container, with `ruby-vips` or ImageMagick (§7 lists what each would add; neither was installed in the image), and updating it when new sets arrive. The spike built its index on the desktop, from a cache it filled once.
- **Detection on new photos or other conditions:** other phones, lighting, backgrounds, sleeves, or cards not held in a hand.
- **The reading refinements** spec 009 will make (strip placement, name-strip height, foil handling): the shipped chain ran unchanged.
- **A published art-hash index** (neotoxicfr's): not consumed or compared; the spike built its own.
- **Back faces, Japanese and other languages:** out of scope.

## 13. Fixtures (AC-5.5, AC-5.7)

Text and numbers only, in `spec/fixtures/card_scanner/`, beside specs 005 and 007's fixtures. No photo, straightened card, strip, fetched artwork or index is committed.

**`phase2_split.json`** (AC-1.1): `format_version` (1); `rule` (the split rule in words); `halves.<corpus>.development` and `halves.<corpus>.held_out` (manifest file names), for corpora `phase0` and `new`.

**`phase2_results.json`**: `format_version` (1), `spec` (`"008"`), `settings_commit` (the latest settings commit, `5ce0238…`: the freeze `39cdc6e` plus the `art_index` metadata, §2), and `records`, one per photo (99: 52 development, 47 held out), sorted and keyed by manifest `file`:

| Field | Meaning |
|---|---|
| `file` | The manifest file name (`IMG_nnnn.jpeg`) |
| `corpus` | `phase0` or `new` |
| `half` | `development` or `held_out` |
| `name`, `external_key` | The ground-truth card name and Scryfall printing id |
| `era`, `foil`, `borderless_or_showcase` | The groups the rates are broken down by (era from the spike's ground-truth copy, §2) |
| `detectors.<hand\|opencv>.full` | The full-size run: held out from `held-hand`/`held-opencv`, development from `dev-hand-3`/`dev-opencv-5` |
| `detectors.<hand\|opencv>.scaled` | The 1080×1440 stand-in run (Phase 0 photos only; absent for the new corpus): `held-*-scaled` or `dev-*-scaled` |
| `detectors.<hand\|opencv>.replays` | Development photos only (`null` for held out): one entry per replay, `{run, class, top3}` |

Each `full` and `scaled` entry holds:

| Field | Meaning |
|---|---|
| `run`, `half` | The run directory's name and its half |
| `class` | `found`, `not_found` or `wrong_outline` (by eye, AC-2.4) |
| `found` | Whether the detector reported a card |
| `name_text`, `collector_text` | What the shipped strips read (empty when not found) |
| `parsed` | The collector-line parser's result: `set_code`, `number`, `language`, `foil`, `format` |
| `lookup` | The printing lookup: `status` (`one`, `none`, `ambiguous`) and `external_keys` |
| `lookup_ms` | The matcher's time, ms |
| `name_candidates` | The name-only ranking (card names, best first) |
| `final_candidates` | The page's final ranking (a collector-line match first) |
| `ms` | Text recognition of both strips, ms (0 when not found) |
| `msDetect`, `msWarp` | Detection and straightening, ms, desktop (`msWarp` absent when not found) |
| `recorded_at` | When the record was made (UTC) |
| `code_commit`, `settings_commit`, `tree_clean` | Provenance (AC-1.2): the commit the code was at, the settings commit given to the run (`null` for development runs before the freeze), and whether the tree was clean |

`art` (from `held-hand-art`, or `dev-hand-3-art` for development photos):

| Field | Meaning |
|---|---|
| `hashes` | The six offset fingerprints made in the browser, 256 hex characters (1,024 bits) each; `null` when no card was found |
| `art` | The 10 nearest artworks, `{id, distance}`, nearest first; `null` when no card was found |
| `right_artwork` | The ground-truth printing's artwork id |
| `art_rank` | The right artwork's rank among the 10, or `null` |
| `right_distance`, `nearest_wrong_distance` | Distances in bits, or `null` |
| `share_name`, `share_artwork` | Printings among the catalog's entries sharing the card's name, and its artwork (AC-3.6) |
| `msFingerprint`, `msSearch` | Browser fingerprint and search times, ms, desktop |
| `run`, `half`, `detector` | The art run, its half and the detect run it straightened from |
| `recorded_at`, `code_commit`, `settings_commit`, `tree_clean` | Provenance, as above. `dev-hand-3-art` ran at `e0b34b2` with an uncommitted tree and no settings commit, which development runs allow |

`art_full` (from `held-hand-art-full`, or `dev-hand-3-art-full` for development photos): art matching against the full index (AC-3.9). The same fields as `art`, plus `index_count` (the index's artwork count, 50923, from the run's index metadata). `detector` names the detect run (`held-hand` or `dev-hand-3`). `art` keeps the subset results unchanged. Every held-out `art_full` record has `half` `held_out`, `code_commit` and `settings_commit` `5ce0238…` and `tree_clean` true; the development records ran at code `1d51648` with a clean tree and no settings commit.

**Which settings commit each record names.** The top-level `settings_commit` now names `5ce0238`, the last commit to the settings file. The held-out records name the commit their run was given: the detector records (`detectors.*`) and `art` name `39cdc6e`, and `art_full` names `5ce0238`. So a provenance check of the held-out records compares each slot with its own run's commit, not every slot with the top-level value. `fixtures.rb` was not changed to write a settings commit per slot, because the phase's ordering rule allows no code change after the index-metadata settings commit; the fixtures commit (`fb79cd1`) records this ruling.

**`phase2_agreement.json`** (AC-4.6): `format_version` (1); `size` (`small`); `n` (198); `corpus_cards` (98); `median` and `max` (the distances in bits, 0 and 0); `settings_commit` (`8152021…`); `results`, one per artwork, `{id, corpus_card, distance}`.

**Straightened cards and strips (AC-5.7)**, outside the repository, in `~/card-scanner-corpus/runs/phase2/<run>/`:

- `run.json`: the run's provenance (detector run name, half, code commit, settings commit, clean tree, start time). Each `<stem>/detect.json` names the detector and repeats the provenance.
- `<stem>/card.png`: the straightened card (1008×1408); `<stem>/picture.png`: the 1320×1760 picture the photo path read.
- `measurement/<stem>.png/capture-001-name.png` and `capture-001-collector.png`: the two strips; `capture-001.json`: what was read.
- `corpus/`: the derived manifest and ground truth the reading run used; `classes.json`, `contact-<n>.png`, `score.md`, `score.json`.

| Run | Detector | Half | Settings / code commit |
|---|---|---|---|
| `held-hand`, `held-hand-scaled` | hand | held out | `39cdc6e` |
| `held-opencv`, `held-opencv-scaled` | OpenCV | held out | `39cdc6e` |
| `held-hand-art` | hand (fingerprint and search), 598-artwork subset | held out | `39cdc6e` |
| `held-hand-art-full` | hand (fingerprint and search), full index | held out | `5ce0238` |
| `dev-hand-3` | hand | development | code `59a4474` (hand settings identical to the frozen ones) |
| `dev-opencv-5`, `dev-hand-scaled`, `dev-opencv-scaled` | as named | development | code `8152021` (identical to the frozen settings) |
| `dev-hand-3-art` | hand (fingerprint and search), 598-artwork subset | development | code `e0b34b2` |
| `dev-hand-3-art-full` | hand (fingerprint and search), full index | development | code `1d51648` |
| `dev-hand-r1`, `dev-hand-r2`, `dev-opencv-r1`, `dev-opencv-r2` | as named | development | `39cdc6e` |

## 14. Recommendation and options (AC-5.2)

This is a recommendation. The maintainer rules on spec 009's scope; no pass threshold is set. Recognition stays in the browser (ADR 0004).

### Card detection: the OpenCV.js detector — recommended: drop

- *For:* a mature library; fast once started (8 ms median detection, desktop).
- *Against:*
  - It barely beats the photo path it would replace: held-out top 3 13/47 against the baseline's 10/47, exact printing 6/43 against 7/43. On Phase 0's photos it is worse than the baseline (top 3 8/24 against 9/24).
  - Its tuning didn't carry over: found 16/26 on the development new-corpus photos, 2/23 on the held-out ones.
  - It needs `'unsafe-eval'` in the scanner page's `script-src`, which loosens the policy spec 007 built for the scanner.
  - 3,570,593 bytes compressed (10,980,573 stored), about 700 times the hand-written detector.
- No ADR (AC-5.4).

### Card detection: the hand-written detector — recommended: build with the confirm flow, for the photo-picker path

- *For:*
  - Held out, it raises the photo path's top 3 from 10/47 to 32/47, and the right card first from 10/47 to 27/47. On Phase 0's photos: top 3 19/24 against 9/24, exact printing 11/22 against 6/22.
  - 5,062 bytes compressed, no dependency, and it runs under the scanner page's policy unchanged.
  - About 0.2 s per photo on the desktop (detection 104 ms and straightening 111 ms, medians).
  - It is deterministic: two replays gave identical images and outcomes for 52 of 52.
  - The photo picker is the fallback without HTTPS or a camera (spec 007 ruling), and is unusable on unguided photos today (2/49 in the top 3 for the new corpus's photos in spec 007).
- *Against:*
  - Live capture is still far better on the same cards: new corpus top 3 19/23 live against 13/23, exact printing 17/21 against 2/21. Live capture stays the primary path.
  - When the card fills the frame, the outline often stops above the bottom edge, losing the collector line (17 of 23 held-out new-corpus outlines wrong). The shipped name strip sits low for a card that exactly fills the guide, so a slightly-off outline loses the name.
  - Battle cards (sideways) and steep tilts (more than ±6°) defeat it.
  - Nothing is known about it on a phone or on live frames.
- *What spec 009 would need:* the bottom-edge weakness and the name strip's position for a detected card (both are reading refinements spec 009 already owns); a phone timing in spec 009's live sitting; and a decision on whether detection also runs on live frames (not measured here).
- [ADR 0005: Detect and straighten the card with a hand-written detector on the photo path](../../adr/0005-hand-written-card-detector-for-the-photo-path.md) (Proposed).

### Art matching — recommended: build with the confirm flow, searched in the browser

- *For:*
  - Held out, against the full index (50,923 artworks), the right artwork was first for 33/47, and for 20/24 where the outline was right. Against the 598-artwork subset it had been 34/47 and 21/24, so the full index cost one held-out first choice.
  - What the full index lost was weak matches only: 1 held-out first choice and 1 more top 3, and 3 development first choices (biased), each with a right-artwork distance of 330 bits or more. No match nearer than 296 bits was lost in either half (§9).
  - It fails on largely different photos from text: it put the right artwork first for 8 of the 15 photos the text path missed, lifting "text top 3 or art first" from 32/47 to 40/47, the same as against the subset.
  - It survives the hand detector's main weakness: on the new corpus, 16/23 first with only 4 outlines classed found.
  - For 14 of the 34 cards without an exact printing from the text, the artwork belongs to one printing, and the full index put it first for 10 of them. It would identify the printing where the collector line can't (older frames, faint foil lines).
  - The browser and a Ruby build agree to 0 bits (n=198), so the index can be built server-side from the catalog's images with the fingerprint made on the device (ADR 0004).
  - Searching the full index in the browser takes 77 ms median, 93 ms slowest (desktop), after a 76 ms fingerprint.
- *Against:*
  - Every instance would fetch the catalog's artwork images to build its index: 50,923 requests to Scryfall's image host, about 708 MB and about 2.6 hours at the throttled rate (measured in two parts, §7), and then the new artworks as sets are added.
  - The browser downloads the index: 6,007,929 bytes compressed (7,332,912 stored), refreshed when the catalog changes. Its download and search time on a phone are not measured.
  - The build needs ImageMagick (4 packages, 3,177 KiB on the app's image) or `ruby-vips` with `ffi` (not in the lockfile), and about 18 minutes of fingerprinting on the desktop.
  - The catalog would need an artwork id (a schema change).
  - A card's other printings have their own artworks, and one of them can rank first: for `IMG_6777` the artwork ranked first, at 163 bits, is another Ritual Guardian printing's, scored here as a miss though it names the right card (§9).
- **Where the search runs: in the browser.** The same search took 77 ms median in the browser and 2,667.4 ms in pure Ruby on the server (desktop, n=43). In Ruby each scan would hold a Puma thread for about 2.7 seconds, on an instance every tenant shares. A native or SQL search on the server wasn't measured. Searching in the browser costs the 6 MB download instead, once per catalog change.
- **Spec 007 FR-3.** ADR 0004 says FR-3's "Send only recognised text to the app in normal use" has to be amended if the browser sends a fingerprint. With the search in the browser the fingerprint never leaves the device, so that amendment isn't needed. What the page would send is the search's result, the artwork ids it ranked first, so that the app can name their printings. That result is derived from the picture but isn't recognised text, and ADR 0004 doesn't address it. Spec 009 should decide whether FR-3's "only recognised text" covers it or needs a word changed. Either way, no frame, strip, photo or fingerprint leaves the device.
- *What spec 009 would need:* the catalog's artwork id and the index build in the catalog refresh, with ImageMagick or `ruby-vips` (ADR 0006); the index served to the scanner page, cached and refreshed with the catalog (ADR 0007); as its first step, the index's download and search time on a phone; a ranking that combines the art result with the text result; and grouping by card, because another printing's artwork of the same card can rank first.
- [ADR 0006: Fingerprint the artwork and build the art index from the catalog's images](../../adr/0006-art-fingerprint-and-index.md) (Proposed).
- [ADR 0007: Search the art index in the browser](../../adr/0007-art-search-in-the-browser.md) (Proposed).
- **Why build rather than defer.** The subset findings offered two options: defer art matching until a full-index measurement existed (Option A), or build it with that measurement as spec 009's first step and a stop rule if accuracy fell too far (Option B). The measurement now exists. Accuracy at full size is close to the subset's (33/47 against 34/47 first; 40/47 text or art, unchanged), so Option A's precondition is met and Option B's stop rule is answered. The costs that remain are the fetch on every instance (measured) and the index download (its size measured; its time on a phone not).

### Roadmap assumptions the evidence contradicted

| The scanner roadmap assumed | The evidence |
|---|---|
| Rectification is needed only for art-hash matching (and continuous scanning) | Detection alone lifts the photo path's held-out top 3 from 10/47 to 32/47 (hand-written detector) |
| Client-side rectification means OpenCV.js (lazy-loaded) or a Python accessory | A dependency-free hand-written detector beat OpenCV.js on every held-out rate (top 3 32/47 against 13/47) |
| OpenCV.js's WebAssembly is about 8 MB | `opencv.js` 4.13.0 is 10,964,323 bytes stored and 3,564,035 gzip (WebAssembly embedded as base64) |
| OpenCV.js can be gated on `onRuntimeInitialized` | 4.13.0 never fires it; `cv` is a thenable that resolves with itself |
| A strict policy works for the scanner's libraries | OpenCV.js 4.13.0 needs `'unsafe-eval'` in `script-src` (embind's `new Function`) |
| libvips or canvas resizes will differ from OpenCV's `INTER_AREA`, eroding the margin between right and wrong artworks | For the project's own index, a Ruby build and the browser implement the same area resampling and agree to 0 bits (n=198 small, n=98 normal). Agreement with a published index wasn't tested |
| A 50,000-artwork index is about 6.4 MB (128 bytes each) | Each record also carries its 16-byte artwork id: 144 bytes. The full index of 50,923 artworks is 7,332,912 bytes stored and 6,007,929 compressed (measured) |
| A pure-Ruby search of about 50,000 artworks is likely sub-second | 2,667.4 ms median over the 50,923-artwork index (desktop, held out, n=43); the browser searched the same index in 77 ms |
