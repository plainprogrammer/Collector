# Card scanner spike (feature 005, Phase 0)

Throwaway feasibility apparatus for `docs/specs/005-card-scanner-phase-0/`. It is not part of the app: nothing here
is autoloaded, served by Rails or run by `bin/rspec`/`bin/ci`. Outputs go to the ignored `tmp/card_scanner_spike/`.

## Running

1. Fetch the pinned OCR engine (Tesseract.js 7.0.0, core builds, `eng` data) into `tmp/card_scanner_spike/ocr/v7.0.0/`:
   `spikes/card_scanner/script/fetch_ocr_assets`. It prints the tarballs' sha256 and the file sizes. Never commit them.
2. Start the spike server: `bundle exec puma -C spikes/card_scanner/puma.rb`. It listens on port 4100
   (`SPIKE_PORT` overrides) on all interfaces so the iPhone can reach it on the LAN. It serves `public/`, the OCR engine
   under `/ocr/` and, to this machine only, the photo corpus under `/corpus/`, all under a self-only CSP. Logs go to
   `tmp/card_scanner_spike/logs/` (`requests.jsonl`, `csp-reports.jsonl`, `timings-*.json`).
3. OCR page: `http://<host>:4100/ocr.html` (device mode: pick photos, timings are posted to `/timings`) or
   `?mode=replay` (runs every corpus photo).
4. Desktop replay (server running): `bundle exec ruby spikes/card_scanner/script/replay.rb <label>`. Drives the page in
   headless Firefox and writes `tmp/card_scanner_spike/replays/<label>/ocr.json` and `crops/*.png`. `SPIKE_URL`
   overrides the server address.
5. Spike specs: `bundle exec rspec spikes/card_scanner/spec`.

## Photo protocol

- Set the iPhone camera to JPEG (Settings → Camera → Formats → Most Compatible).
- Shoot in portrait with the card upright and centred (its centre about halfway across and just above halfway down),
  filling about 74% of the frame height, on a plain background, in normal room light.
- Shoot foils as they naturally catch the light.
- Use unique file names.
- Copy the photos to `$CARD_SCANNER_CORPUS` (default `~/card-scanner-corpus/`) and keep them in the iPhone's Photos
  library for Phase 6.
- Write `manifest.csv` there, with the columns `file,set,number,foil[,era]`: `set` is the Scryfall set code, `number`
  the collector number, `foil` is `yes` or `no`, and `era` (optional) is `pre-M15`, `M15–ONE` or `MOM+`. Values must
  not contain commas (the manifest is split on commas, since `csv` isn't in the bundle).
- Quotas: at least 50 usable photos, at least 5 per era, at least 5 foil, and some borderless or showcase cards.

## Notes

- The iPhone photo picker usually names every picked file `image.jpeg`, so device timing rows can't be matched to
  corpus files (they don't need to be).
- Run `camera_spec.rb` on its own, never in the same process as a `rails_helper` spec (rspec-rails would replace
  `Capybara.app`).

## How the Phase 0 runs were made (2026-09-30)

Commands in the order they were run, from the repository root. Everything they write goes to the ignored
`tmp/card_scanner_spike/`, except the fixtures under `spec/fixtures/card_scanner/`.

| Step | Command | Output |
|---|---|---|
| OCR assets | `spikes/card_scanner/script/fetch_ocr_assets` | `tmp/card_scanner_spike/ocr/v7.0.0/`; sha256 and sizes printed |
| Spike server (background) | `bundle exec puma -C spikes/card_scanner/puma.rb` | port 4100; logs in `tmp/card_scanner_spike/logs/` |
| Pilot replays (5 photos; 2 framing + 3 psm rounds) | `bundle exec ruby spikes/card_scanner/script/replay.rb pilot-1` … `pilot-5` | `tmp/card_scanner_spike/replays/pilot-*/` |
| Catalog (with `bin/dev` running) | `bin/rails "catalog:refresh[mtg]"`, then `bin/rails "catalog:status[mtg]"` until applied | worktree development database |
| Ground truth | `bin/rails runner spikes/card_scanner/script/build_ground_truth.rb` | `spec/fixtures/card_scanner/ground_truth.json` |
| Schema round trip (AC-3.1) | `bundle exec ruby spikes/card_scanner/script/schema_round_trip.rb` | printed |
| Name index, 3 times (AC-3.2, AC-3.5) | `bin/rails runner spikes/card_scanner/script/build_name_index.rb` | `tmp/card_scanner_spike/names.sqlite3`; timings printed |
| Name edge cases (AC-3.4) | `bundle exec ruby spikes/card_scanner/script/name_edge_cases.rb` | Markdown table printed |
| Desktop replays, twice (AC-1.5) | `bundle exec ruby spikes/card_scanner/script/replay.rb run-a`, then `… replay.rb run-b` | `tmp/card_scanner_spike/replays/run-{a,b}/ocr.json` and `crops/` |
| Matching | `bin/rails runner spikes/card_scanner/script/match.rb run-a`, then `… match.rb run-b` | `replays/run-{a,b}/ocr_results.json` and `name_matches.json` |
| Reports | `bundle exec ruby spikes/card_scanner/script/report.rb run-a run-b > tmp/card_scanner_spike/report.md` and `bundle exec ruby spikes/card_scanner/script/report.rb run-b > tmp/card_scanner_spike/report-b.md` | the two reports |
| Device run setup | stop the server, `mv tmp/card_scanner_spike/logs tmp/card_scanner_spike/logs-desktop`, restart it, then `curl -s -D - -o /dev/null http://<lan-ip>:4100/ocr.html \| grep -i content-security-policy` | the header quoted in `research.md` |
| iPhone (AC-1.6) | open `http://<lan-ip>:4100/ocr.html` after clearing site data (cold), pick photos, reload the same tab (warm), pick photos | `tmp/card_scanner_spike/logs/` |
| Device summary | `bundle exec ruby spikes/card_scanner/script/timing_summary.rb <iphone-ip>` | printed |
| Camera `.y4m` | `ffmpeg -y -loop 1 -i "$CARD_SCANNER_CORPUS/IMG_6692.jpeg" -t 2 -r 10 -vf "scale=720:-2,format=yuv420p" tmp/card_scanner_spike/camera.y4m` | `tmp/card_scanner_spike/camera.y4m` |
| Camera, first run | `CAMERA_SOURCE=IMG_6692.jpeg bundle exec rspec spikes/card_scanner/spec/camera_spec.rb --format documentation` | `tmp/card_scanner_spike/camera-results.jsonl` |
| Camera, 10 runs (AC-2.3, AC-2.4) | `for i in $(seq 10); do SE_AVOID_STATS=true CAMERA_SOURCE=IMG_6692.jpeg bundle exec rspec spikes/card_scanner/spec/camera_spec.rb; done` | appended to `camera-results.jsonl` |
| Fixtures | `cp tmp/card_scanner_spike/replays/run-a/{ocr_results,name_matches}.json spec/fixtures/card_scanner/` | `spec/fixtures/card_scanner/` |

Notes on the runs:

- The Fedora Workstation firewall zone already allows ports 1025–65535/tcp, so no `firewall-cmd` step was needed for the
  iPhone.
- The on-device run used Brave on iOS (WebKit), not Safari, and pooled the photos over the cold and warm loads; the
  maintainer accepted both.
- Set `SE_AVOID_STATS=true` for anything that uses Selenium Manager: without it, Selenium Manager tries to send usage
  statistics to `plausible.io`.

## Results

- Findings, with every table and the Phase 1 recommendation: `docs/specs/005-card-scanner-phase-0/research.md`.
- Proposed decisions: `docs/adr/0001-browser-ocr-engine-and-asset-hosting.md`, `docs/adr/0002-camera-path-testing.md`,
  `docs/adr/0003-card-name-index.md`.
- Fixtures (text only, one record per photo keyed by `file`; fields documented in `research.md` Section 7):
  `spec/fixtures/card_scanner/ground_truth.json`, and from replay run-a `ocr_results.json` and `name_matches.json`.
- Not committed: photos (in `$CARD_SCANNER_CORPUS`), crops, the OCR engine, the name index, logs and the raw reports,
  all under `tmp/card_scanner_spike/`.
