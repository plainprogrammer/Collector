# Verification: spec 087, the third-party licences readable from the app (#376)

**Spec:** [spec.md](spec.md) v0.3.1 · **Plan:** [plan.md](plan.md) · **Branch:** `087-third-party-licences` · **Date:** 2026-11-13

Prose documents are verified by reading (`.claude/rules/testing.md`); code criteria by the specs named below. Evidence for the pull request (screenshots, GIF) is in [screenshots/](screenshots/).

## Acceptance criteria

| AC | How it is proved |
|---|---|
| 1.1, 1.2, 1.3 | `spec/requests/licences_spec.rb`: a collector (application header, tab bar, footer), a visitor with the open catalog on and off (brand-only header, no redirect), and an instance with no users (200). |
| 1.4, 1.5 | The same file: the intro and the five `h2`s in order with counts; a row's heading, a closed `<details>` with home link, copyright line and each text in a `<pre>`; the stand-in components. |
| 1.6 | `spec/lib/collector/third_party_licences_spec.rb`: a stand-in bundle with `BSDL`, `MIT-LICENSE` and `LEGAL.rdoc` shows each under its file name and not a `README` or `lib/LICENSE`. |
| 1.7 | `licences_spec.rb`: a `<script>` in a text is shown as text. No `html_safe`, `raw` or `<%==` in the new views. |
| 1.8 | The reader builds once and returns the same object, and a failed build isn't kept (reader spec); a visitor's request runs 0 queries and a collector's no more than `GET /more` (`count_queries`). No outbound call: WebMock blocks the suite's HTTP. |
| 1.9 | The real page is 556,691 bytes (542 KiB), under the 1 MiB ceiling (`licences_spec.rb`). |
| 1.10 | `spec/system/licences_spec.rb`: at a 360px viewport, light and dark, the open Apache text scrolls in its own box and neither the box nor the page scrolls sideways. Screenshots at 390px in [screenshots/](screenshots/). |
| 2.1, 2.2, 2.3, 2.5 | `spec/requests/licence_line_spec.rb` (every reading ends with the new sentence; three links), `spec/requests/licences_link_spec.rb` (`LICENCES_PATH` equals `licences_path`; versions named `third-party-licences`, `AGPL-3.0`, `source-code` keep three links), `licences_spec.rb` (one licence line on the page). |
| 2.4 | The partial rendered alone holds the link (`licences_link_spec.rb`); the scanner page's footer holds it under the scanner's Content-Security-Policy, unchanged (`spec/requests/footer_spec.rb:217`, `spec/system/footer_spec.rb`). No scanner file is touched, and spec 082's sheets render the same partial once it merges (T7.1). |
| 2.6 | `spec/licences_core_spec.rb`: no forbidden word in the controller, views, reader, audit, manifest or texts. |
| 3.1–3.5 | `licences_spec.rb` on the real list: `tesseract.js` 7.0.0 and `tesseract.js-core` 7.0.0 under Apache-2.0 with their texts and the bundled-library notices; Turbo "8.0.23 (turbo-rails 2.0.23)" with its copyright line and the gem's `MIT-LICENSE`; Stimulus "1.3.4 (stimulus-rails)"; Fraunces, IBM Plex Sans and IBM Plex Mono "5.3.0 (Fontsource)" with their copyright lines; one Lucide row with its text, the Feather section and "Cole Bemis". |
| 4.1–4.4 | Reader and page specs: a gem with identifiers and no file reads "Licence text not found" with no `<details>`; `@tesseract.js-data/eng` reads "MIT (as the package declares)" and "Licence text not found"; an unreadable file, an empty file, one over 1 MiB, invalid UTF-8; a `javascript:`, empty or relative homepage gives no link. |
| 5.1–5.7 | `spec/lib/collector/third_party_licences/audit_spec.rb` (each rule fails on a fixture and passes on a baseline; found by review and fixed: an empty `spdx` or `texts` list now fails) and `spec/third_party_licences_manifest_spec.rb` (the repository's real inputs have no problems). |
| 5.8 | `config/ci.rb`, the workflows and the `Dockerfile` are unchanged (`git diff --stat cb10f5b6..HEAD`). |
| 6.1, 6.2 | The script and its shape spec (`spec/image_publishing_spec.rb`); the run in a built image is under "The image proof" below. AC-6.1 names "Permission is hereby granted, free of charge" as the string only a gem's text supplies; the plan swapped it for `c-licences__file">MIT-LICENSE<`, because the Lucide text in the manifest also holds that sentence (the Feather section's MIT text), so it would pass on an image whose gems' files were not read. The swap is deliberate. |
| 7.1, 7.2, 7.3 | Read: catalog core, release and deploy, tenancy and accounts, `Footer.md`, `Licences.md`, the design-system README, `README.md`, `CLAUDE.md`, the roadmap row (in progress now, done at the merge), the specs index in both directions. The area docs' distillation logs and the Named constants table (`MAX_TEXT_BYTES`, the 1 MiB ceiling) are written by `distill-feature` with the pull request's number. |
| 7.4 | [screenshots/](screenshots/): desktop at 1280 and phone at 390, both themes, the page's top, an open row and the footer's licence line, a visitor's view, and `open-a-row-and-follow-the-link.gif`. |

## Numbers

- **The page:** 556,691 bytes with the suite's bundle; 20 requests after one warm-up render in a median of 10.2 ms (maximum 30.9 ms), `SCANNER_TIMING=1 bin/rspec spec/requests/licences_timing_spec.rb`.
- **Components in the suite** (it holds every group): JavaScript 2, OCR engine 3, Fonts 3, Icons 1, Ruby gems 142. The spec's 139 was measured on the image's bundle (all but `development`); the suite's 142 includes the development group. The image's own count is in "The image proof".
- **Eight gems have no licence file** in the bundle here: `brakeman`, `bundler`, `hana`, `minitest`, `rubocop-rails-omakase`, `vcr`, `websocket`, `xpath`; each reads "Licence text not found" with its identifiers.

## Findings that changed the work

- The screenshots found a defect the specs missed: the intro's AGPL-3.0 link showed in the browser's default blue, and the intro sat flush under the heading. Fixed in `6fad73b9`.
- Plan bug: a bare `Collector` in a controller resolves to `ActionController::MimeResponds::Collector`; the controller uses `::Collector`.
- Plan bug: `RSpec/DescribeClass` flagged the core guard; `spec/licences_core_spec.rb` is in `.rubocop.yml`'s exclusions beside `footer_core_spec.rb`.

## Owed to the maintainer

- **Open question 2:** `@tesseract.js-data/eng` 1.0.0 declares MIT in its `package.json` and ships no licence text or copyright line; its row reads "Licence text not found". Whether the traineddata is under the licence the package declares is for the maintainer to confirm.
- **The icons:** Lucide is listed for all 13 inline icons on the maintainer's word (spec decision 7); only `_check` and `_back` match `lucide-static` 1.72.0's paths.
- **#408:** the test group's gems are in the image and so on the page.
- The homes of the OCR packages and the Fontsource fonts are the packages' own `package.json` homepages (decision 5 covers copyright lines and texts; the addresses were read from the same tarballs).

## The image proof (T5.2)

Pending: the local image build and `bin/image-smoke` need the coordinator's slot.

## Implementation review

SPEC-ALIGNED WITH FINDINGS (Opus 5.5, read-only, 2026-11-13, `git diff cb10f5b6..HEAD` at `6fad73b9`). No blocking finding. Every AC met, or pending with its owner (AC-6.1's run in an image, AC-7.4's pull request evidence, the roadmap's "done" at the merge).

- **Major 1 and 2** (the guard let `spdx: []` and `texts: []` through, so AC-5.6 was partly met): fixed test-first in `a2e4896a`.
- **Minor, all addressed in `b4a1e211`:** the specs index rows now list every supersession of spec 084, in both rows; wrong AC citations in the reader spec, the system spec and the `safe_home` comment; the tenancy doc's Sources names spec 087; IBM Plex Sans and Mono copyright lines are asserted; a useless example replaced by one that checks the real pins are Collector's own.
- **Minor, recorded here:** the AC-6.1 string swap (above); the Named constants and distillation logs are `distill-feature`'s; the homes' provenance is recorded under "Owed to the maintainer".
