# Card scanner spike, Phase 2 (feature 008)

Throwaway desktop apparatus for `docs/specs/008-card-scanner-phase-2-spike/`: card detection (a hand-written
detector and OpenCV.js) and art matching, measured on the stored photos. It is not part of the app: nothing here is
autoloaded, served by Rails or run by `bin/rspec`/`bin/ci`, and nothing under `app/` changes.

## Layout

- `lib/card_scanner_phase2.rb` and `lib/card_scanner_phase2/`: the Ruby side (`Settings`, `Split`, `Runs`, `Server`,
  `OpencvAsset`, `DerivedCorpus`, `Scoring`, `BulkArtworks`, `ArtFetcher`, `Ppm`, `Fingerprint`, `ArtIndex`,
  `ArtScoring`).
- `settings.json`: every tuned knob (detectors, warp, fingerprint). The page fetches it as `/settings.json`; the Ruby
  side reads it. The settings commit is the last commit that changes it: the freeze, `39cdc6e`, then `5ce0238`, which
  adds only the full index's description (`art_index`) for the held-out full-index art run.
- `public/`: the detect page (`detect.html`, `detect.js`) and its modules (`canvas.js`, `hand_detector.js`,
  `opencv_detector.js`, `warp.js`, `output.js`, and for art matching `fingerprint.js` and `search.js`).
- `script/`: every step below, from fetching OpenCV.js to assembling the fixtures.
- `spec/`: the spike specs.
- `config.ru`, `puma.rb`: the spike server.

## Commands, in order

The findings are in `docs/specs/008-card-scanner-phase-2-spike/research.md`. `S` below stands for
`spikes/card_scanner/phase2/script`. Steps 4–8 repeat per detector run; steps 14–16 per art run.

| # | Step | Command | Writes |
|---|---|---|---|
| 1 | Fetch OpenCV.js 4.13.0 | `bundle exec ruby S/fetch_opencv.rb` | `tmp/card_scanner_phase2/opencv/4.13.0/` (prints `already intact` or `fetched`, 10,964,323 bytes) |
| 2 | Spike server | `bundle exec puma -C spikes/card_scanner/phase2/puma.rb`; with `SPIKE_UNSAFE_EVAL=1` for any OpenCV run | `tmp/card_scanner_phase2/logs/csp-reports.jsonl` |
| 3 | Ground-truth copies (once) | `bundle exec ruby S/truth_copies.rb` | `tmp/card_scanner_phase2/truth/<corpus>/` |
| 4 | Detect run | `SE_AVOID_STATS=true bundle exec ruby S/detect_run.rb --run <name> --half development\|held_out --detector hand\|opencv [--scale 1440] [--corpus phase0,new] [--files …]` | `<run>/run.json`, `<run>/<stem>/{detect.json,card.png,picture.png}` |
| 5 | Contact sheets and classes | `bundle exec ruby S/contact_sheet.rb <run>`, then write `<run>/classes.json` by eye (`found`, `not_found`, `wrong_outline`) | `<run>/contact-<n>.png` |
| 6 | Derived corpus | `bundle exec ruby S/derive.rb <run>`; prints the reading run's environment | `<run>/corpus/` |
| 7 | Reading run | the dev server with the printed `COLLECTOR_SCANNER_MANIFEST` and `COLLECTOR_SCANNER_RUN_DIR` (`bin/rails server -b 127.0.0.1 -p <worktree port>`), then `SE_AVOID_STATS=true SCANNER_EMAIL=… SCANNER_PASSWORD=… bundle exec ruby script/scanner/photo_run.rb`; stop the dev server afterwards | `<run>/measurement/<stem>.png/capture-001{.json,-name.png,-collector.png}` |
| 8 | Score | `bin/rails runner S/score.rb <run> [<label>]` | `<run>/score.md`, `<run>/score.json` |
| 9 | Sizes (AC-2.7) | `bundle exec ruby S/sizes.rb` | `tmp/card_scanner_phase2/sizes.json` |
| 10 | Artworks (AC-4.1) | `bundle exec ruby S/artworks.rb` (reads the bulk file under `storage/catalog/mtg/`) | `tmp/card_scanner_phase2/{artworks,entries,names}.json` |
| 11 | Fetch artwork | `bundle exec ruby S/fetch_art.rb --size small\|normal --mode corpus\|estimate\|full [--limit N] [--seed N]` | `tmp/card_scanner_phase2/artwork/<size>/`, `fetch_*.json`, `fetch_estimate.json` |
| 12 | Build the index | `bundle exec ruby S/build_index.rb [--size small] [--label TEXT]` | `tmp/card_scanner_phase2/index/art_index.bin`, `art_index_meta.json` (copy a previous index aside first: the full index's run kept the subset in `index-subset/`) |
| 13 | Agreement (AC-4.6), before the freeze | `SE_AVOID_STATS=true bundle exec ruby S/agreement.rb [--size small] [--extra 100]` (server running) | `tmp/card_scanner_phase2/agreement_<size>.json` |
| 14 | Art run | `SE_AVOID_STATS=true bundle exec ruby S/art_run.rb --from <detect run> --detector hand [--name <run>]` (server running) | `<detect run>-art/`, or `<run>/` with `--name` (`art.json`, `card.png`, `picture.png` per photo) |
| 15 | Art score | `bundle exec ruby S/art_score.rb <art run> <detect run>` | `<art run>/art_score.{md,json}` |
| 16 | Server-side search timing (AC-3.7) | `bundle exec ruby S/search_server.rb <art run>` | `<art run>/search_server.json` |
| 17 | Replay difference (AC-2.10) | `bundle exec ruby S/replay_diff.rb <run a> <run b>` | prints the count |
| 18 | Fixtures (AC-5.5) | `bundle exec ruby S/fixtures.rb --held hand=held-hand,opencv=held-opencv --scaled hand=held-hand-scaled,opencv=held-opencv-scaled --dev hand=dev-hand-3,opencv=dev-opencv-5 --dev-scaled hand=dev-hand-scaled,opencv=dev-opencv-scaled --replays hand=dev-hand-r1+dev-hand-r2,opencv=dev-opencv-r1+dev-opencv-r2 --art held-hand-art --dev-art dev-hand-3-art --full-art held-hand-art-full --dev-full-art dev-hand-3-art-full --agreement small` | `spec/fixtures/card_scanner/phase2_{results,agreement}.json` |
| — | Spike specs | `bundle exec rspec spikes/card_scanner/phase2/spec` (not run by `bin/ci`; no real HTTP) | — |

`<run>` is `~/card-scanner-corpus/runs/phase2/<run>/`. Run names are used once: `Runs.start!` refuses an existing
directory.

**The artwork fetch needs the maintainer's approval.** `--mode corpus` (the 98 corpus artworks) and `--mode estimate`
(500 random uncached artworks, seed `20261003`) may run at any time. `--mode full` (about 50,361 requests) runs only
after the maintainer has approved the committed estimate, and the approval is recorded in `research.md` with its date.
For this spike the maintainer first declined it (2026-10-03), so the first index covered 598 artworks, then approved
it the same day (spec v1.2.0). It ran as 19 chunks with `--limit` (at most 3,000 images each, so each finished inside
a 10-minute command), until a chunk reported `fetched: 0`; the cache resumes each chunk where the last stopped. Every
request carries a descriptive `User-Agent` and `Accept`, at least 100 ms apart, with timeouts and back-off on 429;
cached images are never fetched again.

### Notes on the steps

- **Step 1.** Fetch the pinned OpenCV.js build (4.13.0, SHA-256 checked) into `tmp/card_scanner_phase2/opencv/4.13.0/`:
   `bundle exec ruby spikes/card_scanner/phase2/script/fetch_opencv.rb`. It prints the raw and gzip sizes. Never
   commit it.
- **Step 2.** Start the spike server: `bundle exec puma -C spikes/card_scanner/phase2/puma.rb`. It listens on `127.0.0.1:4200`
   (`SPIKE_PORT` overrides) and serves `public/`, `/settings.json`, OpenCV.js under `/opencv/`, and, to this machine
   only, the photos under `/corpus/` and the working files under `/work/`. Pages store their outputs with
   `POST /outputs/<run>/<stem>/<name>.png|json`. Every response carries the scanner page's Content Security Policy
   with a nonce and `report-uri /csp-report`; reports go to `tmp/card_scanner_phase2/logs/csp-reports.jsonl`.
   `SPIKE_UNSAFE_EVAL=1` adds `'unsafe-eval'` to `script-src` (for the AC-2.8 diagnosis only).
- **Step 4.** Detect run (server running):
   `SE_AVOID_STATS=true bundle exec ruby spikes/card_scanner/phase2/script/detect_run.rb --run <name> --half development --detector hand|opencv [--scale 1440] [--corpus phase0,new] [--files IMG_6688.jpeg,...]`.
   Drives the detect page in headless Firefox, one photo at a time, and writes `run.json` (provenance) and per photo
   `<stem>/detect.json`, `card.png` (the straightened card) and `picture.png` (the 3:4 picture with the card filling
   the guide's box). `SPIKE_URL` overrides `http://127.0.0.1:4200`. Run names are used once. The OpenCV detector
   doesn't load under the scanner page's policy (its `new Function` calls are blocked by `script-src`); run it with the
   server started as `SPIKE_UNSAFE_EVAL=1`.
- **Step 5.** Contact sheets: `bundle exec ruby spikes/card_scanner/phase2/script/contact_sheet.rb <run>` writes
   `contact-<n>.png` (20 cards each) into the run directory, for the by-eye classes (`classes.json` beside them).
- **Step 9.** Sizes (AC-2.7): `bundle exec ruby spikes/card_scanner/phase2/script/sizes.rb` prints each detector's file count,
   raw and gzip sizes and writes `tmp/card_scanner_phase2/sizes.json`.
- **Steps 6–8.** `derive.rb` copies each found photo's `picture.png` into `<run>/corpus/` with a manifest and ground
  truth from the spike's copies (step 3), and lists the photos not found (they count as misses). The reading run needs
  a local user (`COLLECTOR_PASSWORD=… bin/rails "collector:user[phase2@localhost]"`); `photo_run.rb` resumes from
  pending rows, so an interrupted reading run is re-run on the same directory. `score.rb` reads `classes.json` if
  present, so run it again after classing.
- **Step 12.** `build_index.rb` labels the index in `art_index_meta.json`: `full` when every artwork with an image URL
  is cached (the artworks without one are counted in `missing_artworks` and `missing_without_image`), otherwise a
  subset, described by `--label TEXT` (default `cached artworks only`) in a `subset` field. `art_score.rb` names the
  index in every heading ("against a N-artwork subset" or "against N artworks") and copies its metadata into
  `art_score.json`. The full index's metadata is also recorded in `settings.json`'s `art_index` key by its own
  settings commit (`5ce0238`), so the held-out art run against it can run at that commit.
- **Steps 13–16.** The agreement check runs before the freeze (it ran at `8152021`). `art_run.rb` takes its half from
  the detect run, so a development detect run can only make a development art run. `--name <run>` gives a second art
  run from the same detect run its own directory (the full-index runs are `dev-hand-3-art-full` and
  `held-hand-art-full`).
- **Step 18.** `--art`/`--dev-art` fill each record's `art` slot (the subset runs); `--full-art`/`--dev-full-art` fill
  a separate `art_full` slot with the same fields plus `index_count` (the full-index runs). Field meanings are in
  `research.md` §13.

## Environment

| Variable | Used by | Meaning |
|---|---|---|
| `CARD_SCANNER_CORPUS` | every script | The photo corpus (default `~/card-scanner-corpus/`; Phase 0's photos at the top, the new corpus in `phase1-live/`). Read-only. Run outputs go under its `runs/phase2/` |
| `SPIKE_PORT` | the spike server | Its port (default 4200, on `127.0.0.1`) |
| `SPIKE_URL` | `detect_run.rb`, `agreement.rb`, `art_run.rb` | The spike server's address (default `http://127.0.0.1:4200`) |
| `SPIKE_UNSAFE_EVAL` | the spike server | `1` adds `'unsafe-eval'` to `script-src`; needed for any OpenCV run (AC-2.8) |
| `SETTINGS_COMMIT` | `detect_run.rb`, `art_run.rb` | The settings commit (`39cdc6e`, or `5ce0238` for the full-index art run); required for `--half held_out` (below) |
| `SE_AVOID_STATS` | the Selenium drivers | `true` stops Selenium Manager sending usage statistics |
| `COLLECTOR_SCANNER_MANIFEST`, `COLLECTOR_SCANNER_RUN_DIR` | the dev server (step 7) | The derived corpus and the run's `measurement/` directory, as `derive.rb` prints them |
| `SCANNER_EMAIL`, `SCANNER_PASSWORD`, `SCANNER_URL` | `script/scanner/photo_run.rb` | The local user, and the dev server's address (default: the worktree's port) |

## Outputs

- `tmp/card_scanner_phase2/` (ignored): OpenCV.js, the ground-truth copies, `artworks.json` and its siblings, the
  fetched artwork and fetch reports, the index (`index/`, the full index; `index-subset/`, the 598-artwork subset), `sizes.json`, `agreement_<size>.json` and the policy reports.
- `~/card-scanner-corpus/runs/phase2/<run>/` (outside the repo): `run.json` (provenance); per photo
  `<stem>/detect.json`, `card.png`, `picture.png` (and `art.json` for an art run); the derived `corpus/`; the reading
  run's `measurement/` (both strips per photo); `classes.json`, `contact-<n>.png`, `score.md` and `score.json`; for an
  art run, `art_score.md`, `art_score.json` and `search_server.json`.
- `spec/fixtures/card_scanner/phase2_*.json`: the only committed outputs, text and numbers (fields documented in
  `research.md` §13).

No photo, straightened card, picture, strip, artwork or index is ever committed.

## Held-out runs

The split is in `spec/fixtures/card_scanner/phase2_split.json`. A `--half held_out` detect or art run is refused
unless all of these hold (`CardScannerPhase2::Runs.guard!`):

- `SETTINGS_COMMIT` is set to the settings commit (the freeze, `39cdc6e`; for the full-index art run, `5ce0238`, which adds only the index's description to `settings.json`);
- the code is at that commit (`HEAD` equals it);
- the working tree is clean.

So nothing may be committed between a settings commit and the last held-out run that uses it, and a failed held-out
run is repeated only at the same commit (AC-1.5). Every record carries its time, the code commit, the settings commit and whether the tree
was clean. Development runs need none of this; they are biased and labelled so in every table.

## Tuning log (development half only, biased)

Rounds on the 52 development photos (26 Phase 0, 26 new corpus). Classes are by eye from the contact sheets
(found = the straightened image shows the whole card and nothing else fills it). Top 1 / top 3 are the final
ranking through the shipped photo path; exact printing is over the 45 M15–ONE and MOM+ photos. Run outputs and
`score.md` files are under `~/card-scanner-corpus/runs/phase2/<run>/`. The baseline (the shipped photo path on the
same photos) is top 1 15/52, top 3 16/52, exact 11/45.

| Round | Settings changed | Hand run | found / not_found / wrong_outline | top 1 | top 3 | exact | OpenCV run | found / not_found / wrong_outline | top 1 | top 3 | exact |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | pilot-tuned hand; plan's OpenCV | dev-hand-1 | 17 / 5 / 30 | 28 | 28 | 12 | dev-opencv-1 | 1 / 42 / 9 | 1 | 1 | 0 |
| 1 | hand.edgePercentile 0.85→0.7; opencv.canny 50/150→30/90 | dev-hand-2 | 24 / 1 / 27 | 37 | 39 | 16 | dev-opencv-2 | 5 / 34 / 13 | 4 | 4 | 1 |
| 2 | hand.edgePercentile 0.7→0.55; opencv.canny →20/60 | dev-hand-3 | 35 / 0 / 17 | 40 | 43 | 20 | dev-opencv-3 | 8 / 28 / 16 | 6 | 6 | 3 |
| 3 | opencv.blur 5→3, opencv.approxEpsilon 0.02→0.04 (hand unchanged) | — | — | — | (43) | — | dev-opencv-4 | 18 / 21 / 13 | 12 | 13 | 6 |
| 4 | opencv.workWidth 480→320 (hand unchanged) | — | — | — | (43) | — | dev-opencv-5 | 22 / 12 / 18 | 14 | 14 | 5 |

Stopped after round 4: the hand detector unchanged (0) and OpenCV +1. The hand detector stopped changing after
round 2 because detect-only probes of its other knobs (blur 1/3, work width 360/640, theta range 3, edge percentile
0.5) each moved at most two outlines with gains offset by losses. Final development full-size runs: `dev-hand-3`
(hand) and `dev-opencv-5` (OpenCV). Stand-ins (Phase 0 development photos at 1080×1440, current settings):
`dev-hand-scaled` 23 / 0 / 3, top 3 24/26; `dev-opencv-scaled` 4 / 7 / 15, top 3 5/26 (baseline 15/26).

Freeze: `39cdc6e` (2026-10-03), chosen detector hand (development top 3 43/52 against 14/52). The held-out runs
(`held-hand`, `held-opencv`, `held-hand-scaled`, `held-opencv-scaled`, `held-hand-art`) and the replays
(`dev-*-r1`, `dev-*-r2`) ran at that commit. Art matching against the full index (50,923 artworks): `dev-hand-3-art-full`
(development, biased) at code `1d51648`, then the index-metadata settings commit `5ce0238`, then `held-hand-art-full`
once at that commit, with no fingerprint setting changed. All their results are in `research.md`.
