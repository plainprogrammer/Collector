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
- Shoot in portrait with the card upright and centred, filling about 90% of the frame height, on a plain background,
  in normal room light.
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
