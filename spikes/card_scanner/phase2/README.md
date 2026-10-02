# Card scanner spike, Phase 2 (feature 008)

Throwaway desktop apparatus for `docs/specs/008-card-scanner-phase-2-spike/`: card detection (a hand-written
detector and OpenCV.js) and art matching, measured on the stored photos. It is not part of the app: nothing here is
autoloaded, served by Rails or run by `bin/rspec`/`bin/ci`, and nothing under `app/` changes.

## Layout

- `lib/card_scanner_phase2.rb` and `lib/card_scanner_phase2/`: the Ruby side (`Settings`, `Split`, `Runs`, `Server`,
  `OpencvAsset`, and later phases' units).
- `settings.json`: every tuned knob (detectors, warp, fingerprint). The page fetches it as `/settings.json`; the Ruby
  side reads it. The settings commit is the last commit that changes it.
- `public/`: the detect page (`detect.html`, `detect.js`) and its modules (`canvas.js`, `hand_detector.js`, `warp.js`,
  `output.js`).
- `script/`: the fetcher, the run driver and the contact-sheet builder (later phases add reading, index and findings).
- `spec/`: the spike specs.
- `config.ru`, `puma.rb`: the spike server.

## Running

1. Fetch the pinned OpenCV.js build (4.13.0, SHA-256 checked) into `tmp/card_scanner_phase2/opencv/4.13.0/`:
   `bundle exec ruby spikes/card_scanner/phase2/script/fetch_opencv.rb`. It prints the raw and gzip sizes. Never
   commit it.
2. Start the spike server: `bundle exec puma -C spikes/card_scanner/phase2/puma.rb`. It listens on `127.0.0.1:4200`
   (`SPIKE_PORT` overrides) and serves `public/`, `/settings.json`, OpenCV.js under `/opencv/`, and, to this machine
   only, the photos under `/corpus/` and the working files under `/work/`. Pages store their outputs with
   `POST /outputs/<run>/<stem>/<name>.png|json`. Every response carries the scanner page's Content Security Policy
   with a nonce and `report-uri /csp-report`; reports go to `tmp/card_scanner_phase2/logs/csp-reports.jsonl`.
   `SPIKE_UNSAFE_EVAL=1` adds `'unsafe-eval'` to `script-src` (for the AC-2.8 diagnosis only).
3. Detect run (server running):
   `SE_AVOID_STATS=true bundle exec ruby spikes/card_scanner/phase2/script/detect_run.rb --run <name> --half development --detector hand [--scale 1440] [--corpus phase0,new] [--files IMG_6688.jpeg,...]`.
   Drives the detect page in headless Firefox, one photo at a time, and writes `run.json` (provenance) and per photo
   `<stem>/detect.json`, `card.png` (the straightened card) and `picture.png` (the 3:4 picture with the card filling
   the guide's box). `SPIKE_URL` overrides `http://127.0.0.1:4200`. Run names are used once.
4. Contact sheets: `bundle exec ruby spikes/card_scanner/phase2/script/contact_sheet.rb <run>` writes
   `contact-<n>.png` (20 cards each) into the run directory, for the by-eye classes (`classes.json` beside them).
5. Spike specs: `bundle exec rspec spikes/card_scanner/phase2/spec`.

Reading, art-index and findings commands are added here as later phases build them.

## Environment

- `CARD_SCANNER_CORPUS`: the photo corpus (default `~/card-scanner-corpus/`; Phase 0's photos at the top, the new
  corpus in `phase1-live/`). Read-only.
- `SPIKE_PORT`, `SPIKE_URL`, `SPIKE_UNSAFE_EVAL`: the server's port, the driver's server address, the policy diagnosis.
- `SETTINGS_COMMIT`: required for held-out runs (below).

## Outputs

- `tmp/card_scanner_phase2/` (ignored): OpenCV.js, logs, artwork and the index.
- `~/card-scanner-corpus/runs/phase2/<run>/`: run outputs (outside the repo).

No photo, straightened card, picture, artwork or index is ever committed.

## Held-out runs

The split is in `spec/fixtures/card_scanner/phase2_split.json`. A `--half held_out` run is refused unless
`SETTINGS_COMMIT` is set to the settings commit, the code is at that commit, and the working tree is clean
(`CardScannerPhase2::Runs.guard!`). Development runs are biased and are labelled so in every table.
