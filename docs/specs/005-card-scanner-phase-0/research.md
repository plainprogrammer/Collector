# Feature 005: Card Scanner Phase 0 — Findings

**Spec:** [spec.md](spec.md) (v1.1.1) | **Plan:** [plan.md](plan.md)
**Measured:** 2026-09-30 | **Branch:** `005-card-scanner-phase-0`

Every rate below carries its sample size. Anything that was not measured is labelled "estimate" or "not measured". Phase 0 sets no pass threshold: the numbers inform the maintainer's go / no-go / pivot decision, they don't make it.

---

## 1. Summary

**Spike 1, OCR strip accuracy.** Tesseract.js 7.0.0, served from the spike page's own origin, read the name-bar and collector-line strips of 50 hand-held iPhone photos cut at fixed positions relative to a fixed card guide. The engine loads and runs on the maintainer's iPhone: 7,031,507 bytes on a cold load, about 1 KB on a warm one, ready in 528 ms cold and 313 ms warm, and a median of 626 ms per photo (n=11). Accuracy is the problem. The name strip read exactly on 5 of 50 photos, and the collector line identified the exact printing on 7 of 45. Two desktop replays gave identical OCR text on all 50 photos. Of the 24 photos whose card was not in the top 3 candidates, 19 trace to the fixed guide: hand-held photos drift by about ±4% of the image, so the strips had to be tall, and they either clipped the name or took in so much art that the OCR text was mostly noise.

**Spike 2, headless camera testing.** Firefox's built-in fake camera, the project's current system-test driver, shows a synthetic pattern and can't be given a chosen card image. Two alternatives worked 10 times out of 10 with a card-specific assertion (a 256-bit average hash of the captured frame against the source photo): replacing `getUserMedia` inside the page with a stream drawn from the photo (in the existing headless Firefox, hash distance 0), and Chrome's file-backed fake camera fed a `.y4m` made from the photo (hash distance 27, threshold 32).

**Spike 3, fuzzy name index.** An FTS5 trigram table with `tokenize='trigram remove_diacritics 1'` survives Rails 8.1.4's `schema.rb` dump and load unchanged. Over the full English catalog it indexes 35,986 names in a median 3.04 s (n=3), including the catalog read. With a 50-row `bm25` shortlist re-ranked by Jaro-Winkler, queries take a median 10.14 ms and a 95th percentile of 114.46 ms (n=50). Clean names are found, but short names lose to a single misread character, and long noisy OCR text dilutes the ranking.

**Headline numbers (run-a; run-b identical):**

| Measure | Result | n |
|---|---|---|
| Name strip read exactly (front-face name) | 5/50 (10.0%) | 50 photos |
| Exact printing from the collector line (M15–ONE and MOM+) | 7/45 (15.6%) | 45 photos |
| Correct card is the top candidate | 20/50 (40.0%) | 50 photos |
| Correct card in the top 3 | 26/50 (52.0%) | 50 photos |
| OCR text differing between run-a and run-b | 0/50 photos | 50 photos |
| iPhone per-photo recognition, median / slowest | 626 ms / 1,911 ms | 11 photos (cold and warm pooled) |
| iPhone bytes before the first scan, cold / warm | 7,031,507 / 1,055 | 1 load each |
| Name query time, median / p95 (desktop) | 10.14 ms / 114.46 ms | 50 queries |
| Name index full rebuild, median (desktop) | 3.04 s | 3 builds |
| Recommended camera-test approach, passes in 10 runs | 10/10 | 10 runs |

## 2. Method and apparatus

**Spike server.** A static Rack app (`CardScannerSpike::Server`, `spikes/card_scanner/lib/card_scanner_spike/server.rb`) under its own Puma config (`spikes/card_scanner/puma.rb`), listening on port 4100 on all interfaces so the iPhone can reach it on the local network. The Rails app is not involved. It serves:

- the spike pages from `spikes/card_scanner/public/`;
- the OCR engine under `/ocr/` with `cache-control: public, max-age=31536000, immutable`, answering any revalidation (`If-Modified-Since` or `If-None-Match`) with `304` and no body, since the files are pinned by version in their path;
- the photo corpus under `/corpus/`, to loopback addresses only. A request from the LAN address got `403`.

Every response carries this header, quoted as sent (checked with `curl` against the LAN address):

```
content-security-policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self' blob:; connect-src 'self'; report-uri /csp-report
```

The server logs every response's size to `tmp/card_scanner_spike/logs/requests.jsonl`, CSP violation reports to `csp-reports.jsonl`, and device timing posts to `timings-*.json`.

**OCR assets.** Downloaded with `curl` straight from `registry.npmjs.org` by `spikes/card_scanner/script/fetch_ocr_assets` into `tmp/card_scanner_spike/ocr/v7.0.0/` (ignored, never committed). No Node toolchain was used.

| Package | Version | Tarball sha256 |
|---|---|---|
| `tesseract.js` | 7.0.0 | `9a93bf51c3387f945d10a24bf8b3a4bf2e45c7c7161b8242aafbaf9d3c4b606a` |
| `tesseract.js-core` | 7.0.0 | `ba584355515eaff877552022853c0e71f2cb70466e759d1d6940484929718ee0` |
| `@tesseract.js-data/eng` | 1.0.0 (`4.0.0_best_int`) | `c9bddf2e2f0a214ac7918f3f4a3caf45e09ce8674fe26662ae7787ac8927f7bb` |

| File | Bytes |
|---|---|
| `tesseract.min.js` | 62,961 |
| `worker.min.js` | 111,307 |
| `core/tesseract-core.wasm.js` | 4,687,944 |
| `core/tesseract-core-lstm.wasm.js` | 3,896,484 |
| `core/tesseract-core-simd.wasm.js` | 4,690,932 |
| `core/tesseract-core-simd-lstm.wasm.js` | 3,899,472 |
| `core/tesseract-core-relaxedsimd.wasm.js` | 4,697,227 |
| `core/tesseract-core-relaxedsimd-lstm.wasm.js` | 3,905,767 |
| `lang/eng.traineddata.gz` | 2,952,873 |

The engine picks one core per device and downloads only that one: desktop Firefox 156 chose `relaxedsimd-lstm`, the iPhone chose `simd-lstm`.

**OCR page.** `spikes/card_scanner/public/ocr.html` and `ocr.js`. It decodes a photo with `createImageBitmap` (which applies the EXIF orientation), places a fixed 63:88 card guide on it, crops two strips relative to the guide, and runs one Tesseract worker over each strip with its own page segmentation mode (psm). There is no card detection and no perspective correction (FR-2). The page runs in two modes: device mode (the photo picker; timings are posted back to the server) and replay mode (every corpus photo, driven by `script/replay.rb` in headless Firefox through Selenium).

**Guide and strip values (frozen before the measured runs).** Values are fractions of the image (guide) or of the guide rectangle (strips).

| Setting | Value |
|---|---|
| `GUIDE_HEIGHT` | 0.74 of the image height |
| `GUIDE_CENTRE` | x 0.51, y 0.485 of the image |
| Name strip | x 0.0, y 0.0, w 0.76, h 0.16, psm 6 |
| Collector strip | x 0.0, y 0.86, w 0.45, h 0.18, psm 6 |

**Pilot tuning: 2 framing rounds and 3 psm rounds, on 5 pilot photos** (IMG_6688 to IMG_6692; none pre-M15):

1. Round 1: a centred guide at 0.9 of the image height put every strip off the card. On the pilot photos the card measured 0.69 to 0.77 of the image height, with its centre at x 0.50 to 0.58 and y 0.45 to 0.51, a scatter of about ±0.04.
2. Round 2 (commit `b3b3b38`): the guide above, with the name strip at psm 7. All 10 crops were framed. Collector OCR was good on 4 of 5; name OCR was noise on all 5.
3. Rounds 3 to 5 (commit `f88760b`): name-strip psm 6 read 2 of 5 names (IMG_6692 exactly, IMG_6691 as "Mermaoid’s Pendant"), psm 11 read 1 of 5 and psm 3 read 0 of 5, against 0 of 5 for psm 7. psm 6 was chosen.

Caveat: the 5 pilot photos are part of the 50-photo corpus, so the strip values were tuned on 10% of the measured set. That can only flatter the results.

**Corpus.** 50 photos of the maintainer's own English cards (IMG_6688 to IMG_6692 and IMG_6702 to IMG_6746), shot hand-held on an iPhone as 4032×3024 JPEGs with EXIF orientation 6, following the photo protocol in `spikes/card_scanner/README.md`. By convention the photos live in `$CARD_SCANNER_CORPUS` (default `~/card-scanner-corpus/`), outside the repository, with the maintainer's `manifest.csv` (`file,set,number,foil[,era]`). No photo, crop or derived image is committed (FR-1).

**Ground truth (AC-1.1).** `script/build_ground_truth.rb` resolved every manifest row against the local catalog: 50 of 50 resolved, 0 ground-truth errors. Era counts: pre-M15 5, M15–ONE 20, MOM+ 25; foil 9; borderless or showcase 16. Three manifest rulings, each checked against the photo:

1. The manifest had no header row; one was added.
2. IMG_6707: set `lc1` corrected to `lci` (the photo prints `R 0264 LCI`).
3. IMG_6736: `dmu 146` corrected to `dmu 246` (the photo shows Crystal Grotto, `246/281 C`).

The original manifest is kept as `manifest.csv.orig` in the corpus directory, outside the repository.

**Catalog.** A real refresh applied `default-cards-20260930090541` to this worktree's development database: 106,636 records seen, 106,636 inserted, 0 malformed, in 61 s (n=1).

**Machines.** The desktop is the maintainer's Fedora development machine (Firefox 156, SQLite 3.53.2, Rails 8.1.4, Ruby 4.0.7). The phone is the maintainer's iPhone on iOS 18.7 (see AC-1.6 for the browser).

## 3. Spike 1: OCR strip accuracy

### Question and method

Can in-browser OCR on the name bar and collector line identify real cards from hand-held phone photos?

Each replay (AC-1.2) ran all 50 corpus photos through the OCR page in headless Firefox on the desktop (`script/replay.rb`; about 80 s wall-clock per replay, not timed precisely). `script/match.rb` then parsed each collector strip (`CardScannerSpike::CollectorLine`), looked the parsed set, number and language up in the catalog (`CardScannerSpike::PrintingLookup`: one printing, none, or ambiguous), and queried the name index with the raw name-strip text (Spike 3). `script/report.rb` scored the results against `ground_truth.json`.

**Name read (AC-1.3).** The name-read rate compares the normalised name-strip text with the normalised front-face name (`name_bar` in the ground truth), because that is what the name bar prints. For a double-faced card the catalog name is `Front // Back`, which no name bar prints. The strict comparison with the catalog name (`name`) is reported alongside. Normalisation (`CardScannerSpike::Normaliser`) applies NFKC, folds ligatures ("Æ" to "ae"), strips diacritics, downcases, drops apostrophes and turns every other run of punctuation or whitespace into one space. It is applied identically to OCR text, ground truth and catalog names (FR-2). On this corpus both rates are 5/50: no double-faced card was read exactly.

One photo can never match on the catalog name. IMG_6691 is a Secret Lair card that prints the flavour name "Mermaid's Pendant" (with "Wedding Ring" as a subtitle); the catalog stores "Wedding Ring" and has no flavour-name field.

**Exact printing (AC-1.3).** Counted over the 45 M15–ONE and MOM+ photos only, since pre-M15 collector lines print no set code. A hit is a lookup that returns exactly one printing, and that printing is the ground-truth one.

### Collector-line parser inputs (AC-1.4)

The parser's spec (`spikes/card_scanner/spec/card_scanner_spike/collector_line_spec.rb`) uses the known set codes `neo dmu mom pmom` and these inputs, verbatim:

| Input | Expected |
|---|---|
| `051/302 NEO` | set `NEO`, number `51`, format `:slash` (AC-1.4: the number before the slash, not the set size 302) |
| `051/302 R\nNEO • EN` | set `NEO`, number `51`, language `en`, foil `false`, format `:slash` |
| `0123/0281 M\nDMU ★ EN` | foil `true` |
| `051/302 R\nNEO « EN` | language `en`, foil `false` (bullet misread as a guillemet) |
| `R 0123\nMOM • EN` | set `MOM`, number `123`, language `en`, foil `false`, format `:rarity_first` |
| `R 0045P\nPMOM • EN` | number `45p` (promo suffix kept) |
| `O5I/3O2 R\nNEO • EN` | number `51` (digit lookalikes repaired) |
| `051/302 R\nNE0 • EN` | set `NEO` (zero read for the letter O) |
| `051/302 R\nXYZ • EN` | set `nil`, number `51` (unknown set code rejected, number kept) |
| `123/350` | set `nil`, number `123` (pre-M15, no set code) |
| `""` (empty) | every field `nil` |

All pass. The parser accepts a set code only if it is a known catalog set code (FR-3). It first looks for a `SET • LANG` shape, then falls back to any 3-to-5-character token that is a known set code (the "loose" fallback).

### Rates, run-a (AC-1.3)

Name strip against the front-face name (`name_bar`):

| Name read | Group | Hits / n (rate) |
|---|---|---|
| overall | all | 5/50 (10.0%) |
| era | M15–ONE | 3/20 (15.0%) |
| era | MOM+ | 1/25 (4.0%) |
| era | pre-M15 | 1/5 (20.0%) |
| foil | foil | 2/9 (22.2%) |
| foil | non-foil | 3/41 (7.3%) |
| frame treatment | borderless/showcase | 2/16 (12.5%) |
| frame treatment | regular | 3/34 (8.8%) |

Name strip against the catalog name (strict):

| Catalog name | Group | Hits / n (rate) |
|---|---|---|
| overall | all | 5/50 (10.0%) |
| era | M15–ONE | 3/20 (15.0%) |
| era | MOM+ | 1/25 (4.0%) |
| era | pre-M15 | 1/5 (20.0%) |
| foil | foil | 2/9 (22.2%) |
| foil | non-foil | 3/41 (7.3%) |
| frame treatment | borderless/showcase | 2/16 (12.5%) |
| frame treatment | regular | 3/34 (8.8%) |

Exact printing from the collector line, M15–ONE and MOM+ photos only:

| Printing | Group | Hits / n (rate) |
|---|---|---|
| overall | all | 7/45 (15.6%) |
| era | M15–ONE | 2/20 (10.0%) |
| era | MOM+ | 5/25 (20.0%) |
| foil | foil | 0/9 (0.0%) |
| foil | non-foil | 7/36 (19.4%) |
| frame treatment | borderless/showcase | 3/16 (18.8%) |
| frame treatment | regular | 4/29 (13.8%) |

Lookup outcomes over the 45 photos: one printing 8, none 37, ambiguous 0. One of the 8 single-printing lookups was the wrong printing: IMG_6689 (Galea, AFC 001) was read as `301/062 M AFC`, and AFC 301 exists.

Collector-line outcomes over the same 45 photos:

| Outcome | Photos |
|---|---|
| Exact printing identified | 7 |
| Wrong printing identified | 1 |
| Neither set nor number parsed (the strip missed the collector line, often catching flavour or rules text above it, or the line was cut at the crop's bottom edge) | 21 |
| Set only | 11 |
| Number only | 4 |
| Both parsed, no catalog match (PIP read `10g` for 289) | 1 |
| **Total** | **45** |

Parser gaps seen in the OCR text (not fixed, since this is a spike):

- A rarity letter glued to the number (`M0149 MOM`, `M0697 CMM`) fails the rarity-first pattern, which expects whitespace after the rarity.
- A slash lost by OCR (`120 Ke NEC`) fails the slash pattern.
- No rarity letter read at all (`0258 FFV FIN`) fails both.

**Loose set-code fallback.** 20 photos had a set code parsed; 18 were the right set. The 2 false set codes are both `ONE`, the English word "one" in rules text ("Add one"), on IMG_6728 (truth `sta`) and IMG_6736 (truth `dmu`). The fallback should require the `SET • LANG` shape, or exclude dictionary words.

**Foil marker.** A foil marker was read on 8 photos and agreed with the ground truth on 5 (62.5%, n=8). Tesseract reads the printed `•` as `*`, `«` or `+`, and `*` counts as the foil star, so the non-foil TMT card IMG_6690 (`R 0225 TMT * EN`) reads as foil. The foil marker from OCR is not reliable.

### Both runs (AC-1.5)

The accuracy run was replayed twice on the desktop (run-a, run-b). **0 of 50 photos differ** in either strip's OCR text, so there are no differing strings to list. Every rate is the same in both runs:

| Measure | run-a | run-b |
|---|---|---|
| Name read (front-face name) | 5/50 (10.0%) | 5/50 (10.0%) |
| Name read (catalog name) | 5/50 (10.0%) | 5/50 (10.0%) |
| Exact printing (M15–ONE and MOM+) | 7/45 (15.6%) | 7/45 (15.6%) |
| Lookup outcomes | one 8, none 37 | one 8, none 37 |
| Top 1 | 20/50 (40.0%) | 20/50 (40.0%) |
| Top 3 | 26/50 (52.0%) | 26/50 (52.0%) |
| Query time, median / p95 | 10.14 / 114.46 ms | 9.81 / 113.87 ms |

Every per-era, foil and frame-treatment row is also identical between the two runs (compared line by line). Only the query times, which are wall-clock measurements, differ. The committed fixtures come from run-a (Section 7).

### iPhone timings (AC-1.6)

Measured 2026-09-30 20:35–20:42 UTC on the maintainer's iPhone (iOS 18.7), loading `http://<dev machine LAN address>:4100/ocr.html` over the local network and picking corpus photos with the photo picker.

Two deviations from AC-1.6, both accepted by the maintainer:

- **Browser.** The run used Brave, not Safari. Brave on iOS uses WebKit, and its user agent was `Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.6.1 Mobile/15E148 Safari/604.1 Brave`. Whether Brave's own caching or privacy features change the numbers relative to Safari was not assessed.
- **Photo count.** The 11 photos are pooled over both loads (2 cold, 9 warm), rather than at least 10 per load.

| Load | Requests | Bytes before the first scan | Page load to ready | Per-photo recognition |
|---|---|---|---|---|
| Cold (site data cleared) | 8 | 7,031,507 | 528 ms | 556, 462 ms (n=2) |
| Warm (same tab, reload) | page and script only | 1,055 | 313 ms | median 852 ms, slowest 1,911 ms (n=9) |
| Both, pooled | | | | **median 626 ms, slowest 1,911 ms (n=11)** |

- Cold bytes: `ocr.html` 632 + `tesseract.min.js` 62,961 + `ocr.js` 4,168 + `worker.min.js` 111,307 + `core/tesseract-core-simd-lstm.wasm.js` 3,899,472 + `lang/eng.traineddata.gz` 2,952,873, plus the small timing-post responses the server log counts in the same session.
- Warm bytes: `ocr.html` (632 bytes) and `ocr.js` (answered `304`, no body), plus the timing posts. The engine, core and language data were not requested at all (HTTP cache and the engine's IndexedDB copy of the language data).
- Warm per-photo times in the order picked: 418, 1,911, 402, 626, 296, 1,169, 1,114, 852, 1,344 ms. The median and slowest use the nearest-rank method.
- Per-photo time covers both strips (two `recognize` calls), from after the photo is decoded to the end of the second call.

Live-camera timing was not measured: the on-device run used the photo picker, as the spec's error scenario allows. Camera access over plain HTTP on the LAN was not attempted.

### Not in the top 3 (AC-1.7)

24 of 50 photos did not have the correct card among Story 3's top 3 candidates. The OCR text cells are cut to their first 60 characters ("…"); the full text is in `spec/fixtures/card_scanner/ocr_results.json`. Causes come from reviewing each photo's two crops (`tmp/card_scanner_spike/replays/run-a/crops/`, not committed).

| File | Expected | Name strip (first 60 chars) | Collector strip (first 60 chars) | Top 3 | Likely cause |
|---|---|---|---|---|---|
| IMG_6688.jpeg | Mountain | ARSENATE SO YI TE pI Sa SIT ER% wa BOR CTA i RANA AA AAA A A… | \\ } I DQOILU Lali \ 4 \| LEON TUKKER | Reshape the Earth; Arsenal Thresher; Sea Gate Restoration // Sea Gate, Reborn | Strip clutter: name legible, but the tall fixed strip takes in borderless art and its OCR noise swamps the name |
| IMG_6689.jpeg | Galea, Kindler of Hope | ow A k " — - edd os BTR BN Ps a . 1 TN Fo io - ~ : ¢ Q 4 — a… | 1L LO talgcClL CiCatu 301/062 M AFC #\*# EN db JOHANNES YOSS | Plea for Power; Aatchik, Emerald Radian; S.N.E.A.K. Dispatcher | Glare (foil) |
| IMG_6690.jpeg | Sally Pride, Lioness Leader | ra—————T aaa ae : Ld Vs TE 1, J if mw y/ PVE 1 A I" i a o fi… | R 0225 TMT \* EN % GREGG SCHIGIEL | Ria Ivor, Bane of Bladehold; V.A.T.S.; Rafi, Retro Racer | Strip clutter: name legible, but the tall fixed strip takes in showcase art and its OCR noise swamps the name |
| IMG_6691.jpeg | Wedding Ring | — a a = . = Sere TRS eee Re a ough Lo SR KT 4 (ek ; i] A Se… | § TEE R— TL SATE. ARR M 2802 SLD + EN ¥%s CONCERNED | Borough Backup; Ba Sing Se; Maralen, Fae Ascendant | Unusual frame: flavour name printed ("Mermaid's Pendant"), catalog name is "Wedding Ring" |
| IMG_6705.jpeg | Cloudsteel Kirin | (empty) | CYR SUL NED » EN MW JONATHAN KUO BE \| Art BE rr | (none) | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6708.jpeg | Reyav, Master Smith | v \d cote E (a s de ed "N | PIV LL 7 WIN FO TYAIVRLIN WIR | S.H.I.E.L.D. Deployment Drone; Quake, Agent of S.H.I.E.L.D.; Nick Fury, Agent of S.H.I.E.L.D. | Blur (sleeved) |
| IMG_6711.jpeg | Kodama's Reach | - / AN 3 ~~ A a y/ \ > by -—. > Ee » \ | Vig 204 —Shigeki, Jukar v1 120 Ke NEC » EN do SAM BURLEY — e… | Lead by Example; Teach by Example; Eaten by Spiders | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6714.jpeg | Genji Glove | HS pay - mcr wos + VE OEIC coma ~omot enji Glove a  a — pA - | Equip 3 “I must say, I quite en \ 0258 FFV FIN oo EN Wo ELIZ… | The Cave of Two Lovers; Opera Love Song; You See a Pair of Goblins | Misalignment: name left-clipped ("enji Glove" read) |
| IMG_6715.jpeg | Mjölnir, Hammer of Thor | =X . REPENS 4 IE a. _ VTENE. | Equip worthy 1 (A4 ci legendary non-Villain t 2 @, Discard t… | Decadent Dragon // Expensive Taste; Repel; Regenerations Restored | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6716.jpeg | Blessed Ghoul | Oy 1 jessed (nou Er af 4 a, Po \| >, gi Lo rd wo Ng AOR A ©… | 1¢ naa failed nis fu rofessor had kindly nake up the work. | Blessed Wine; You See a Pair of Goblins; Blessed Wind | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6717.jpeg | Campus Crier | Ag ) T \| £ ®m \| _« EE —————————————————————————————— EE —… | ¢ speaks what the futu ritten. 004 | A.I.M. Synthoids; A.I.M. Bot; Kree Sentinel | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6718.jpeg | Leyline Immersion | AW \ 5 ¥ 1 Ry - A | Illus. \| ™ & 2023 W | Saw in Half; Ripjaw Raptor; Guan Yu's 1,000-Li March | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6722.jpeg | Shared Animosity | N A ‘ £4 \| N Vy f \| vo Ig ) VN Al V | raged for so long that 1 it started. Few would long-ago disp… | B-I-N-G-O; Heavy Fog; Rending Volley | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6723.jpeg | Invasion of Tarkir // Defiant Thundermaw | gm N a i 2: io WS yo | \| F \ ; 3 4 © Gg M0149 MOM + EN dw DARREN TAN | B-I-N-G-O; Man-o'-War; A.I.M. Synthoids | Unusual frame (battle, landscape layout) |
| IMG_6729.jpeg | Herd Heirloom | - 2 wr t  3 \| \ J  af -  PRR, ai AY \ ’ . | HAlllo tialllpiv ali creature deals cor player, draw a car | Aettir and Priwen; March of Progress; Stir the Pride | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6730.jpeg | Cosmic Hunger | A) ae ea i Rd TE NC DORA AA Sa pr Cosmic Hunger | The Copper Host sc strongest converts. 1 perfection. | Ghalta, Primal Hunger // Ghalta, Primal Hunger; Silver Surfer, Cosmic Voyager; Moira and Teshar | Matcher miss: name read correctly, but surrounding noise dilutes the trigram and Jaro-Winkler ranking |
| IMG_6732.jpeg | Balefire Dragon | . Dace Uragon = ER - ho” oo. | M0697 CMM\*EN > Scori b | Dragon Arch; Topaz Dragon // Entropic Cloud; Crystal Dragon // Rob the Hoard | Misalignment: name clipped by the strip edge or strip off the name (foil) |
| IMG_6733.jpeg | Primevals' Glorious Rebirth | (empty) | AA NJAALL RA Se CD Tr Fon oh Centuries ago, five . to rule t… | (none) | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6734.jpeg | Elixir of Immortality | BE - -b A Lo \! : s. A - | rather stale, but it —Baron Sengir  >Zglgan Boros & Gab  Wa… | Phoebe, Head of S.N.E.A.K.; Goblin S.W.A.T. Team; Bello, Bard of the Brambles | Misalignment: name clipped by the strip edge or strip off the name |
| IMG_6735.jpeg | Fracture | BT | really are.” . —FExtus Narr 27% U | (none) | Misalignment: name clipped by the strip edge or strip off the name (foil) |
| IMG_6736.jpeg | Crystal Grotto | - NE J : d FY PRT TE - J ’  v § | ~: Add ¢. I, ©: Add one | S.H.I.E.L.D. Flying Car; The Art of Tea; M.O.D.O.K. | Strip clutter: name legible, but the tall fixed strip takes in art and its OCR noise swamps the name |
| IMG_6737.jpeg | Leyline of the Guildpact | CE ER ERT Le SAC eve « v § “ : 3 NE f B B g \| eAN AS SRV b… | 8 Lands you contr type in addition | B-I-N-G-O; Faerie Miscreant; Bee-Bee Gun | Strip clutter: name legible, but the tall fixed strip takes in art and its OCR noise swamps the name |
| IMG_6738.jpeg | Darksteel Citadel | a > tz - S ig ; LJ p ‘ \| \| 5 - we ~— yr. ’ 4 | Structures built neither assault 1 | T.A.P.P.E.R.; Goblin S.W.A.T. Team; Waltz of Rage | Misalignment: name clipped by the strip edge or strip off the name (foil) |
| IMG_6743.jpeg | Lathliss, Dragon Queen | <ALIEIO0y AIA KRURYL ILL IY : aid : ¥ g a \| - -— 3 pry | 4. LldgVllo yUYViL & until end of turn. M19 + EN de ALEX IKO… | Unlikely Aid; Airborne Aid; Call for Aid | Misalignment: name clipped by the strip edge or strip off the name |

| Cause | Photos |
|---|---|
| Misalignment of the fixed strip: name clipped by the strip edge, or strip off the name | 15 |
| Strip clutter: name legible, but the tall fixed strip takes in art and the OCR noise swamps it | 4 |
| Glare (foil) | 1 |
| Blur | 1 |
| Unusual frame (battle layout; flavour name) | 2 |
| Matcher miss | 1 |
| Parser miss | 0 |
| **Total** | **24** |

19 of the 24 misses (the first two rows) trace to the fixed guide on hand-held photos. The strips are tall so that they still contain the name bar and collector line when the card drifts by about ±4% of the image, and that height is what either clips the name or fills the strip with art. The parser and the matcher are secondary causes. No top-3 miss is attributed to the parser, because the candidates come from the name strip only; the collector line's own failures are in the outcome table above.

### Recommendation

The engine choice and self-hosting hold up; the capture method does not. Keep Tesseract.js 7.0.0 served from the app's own origin (ADR 0001). Don't build Phase 1 on a still photo cut at fixed positions: on hand-held photos it found the card in the top 3 only 52% of the time (n=50) and the exact printing 15.6% of the time (n=45). Give the user a live camera preview with the card guide drawn over it, so they align the card before capture, and cut tight strips (just the name bar, just the collector line) once alignment can be relied on. Measure that on a corpus again before building the rest of the flow. If live alignment isn't enough, card detection and rectification is the fallback. Also fix the parser gaps above, tighten the loose set-code fallback, and ask the user for the finish rather than trusting the OCR'd foil marker.

## 4. Spike 2: headless camera testing

### Question and method

Can a system test drive a live-camera page with a chosen card image, with no person and no physical camera?

A throwaway page (`spikes/card_scanner/public/camera.html`, `camera.js`) starts the camera with `getUserMedia`, captures one frame, and computes a 16×16 average hash (256 bits) of the frame and of the source photo. `spikes/card_scanner/spec/camera_spec.rb` (Capybara with Selenium, against the spike server) clicks through the page and counts the differing bits. A distance of 32 or less (of 256) counts as "this is the card" (AC-2.2). Each example records its approach, distance and seconds to `tmp/card_scanner_spike/camera-results.jsonl`.

Source image: IMG_6692 (Minimus Containment). Chrome's `.y4m` was made with ffmpeg 8.1.2: `ffmpeg -y -loop 1 -i "$CARD_SCANNER_CORPUS/IMG_6692.jpeg" -t 2 -r 10 -vf "scale=720:-2,format=yuv420p" tmp/card_scanner_spike/camera.y4m` (720×960, 10 fps, 2 s, 20.7 MB).

Approaches:

- **(a) Firefox fake camera (the current driver, AC-2.1).** Headless Firefox with the prefs `media.navigator.streams.fake = true` and `media.navigator.permission.disabled = true`.
- **(b) Chrome file capture (AC-2.3).** Headless Chrome with `--headless=new --use-fake-ui-for-media-stream --use-fake-device-for-media-stream --use-file-for-fake-video-capture=tmp/card_scanner_spike/camera.y4m`.
- **(c) In-page substitution in Firefox (AC-2.3).** The test replaces `navigator.mediaDevices.getUserMedia` with a function that draws the photo onto a canvas and returns `canvas.captureStream(10)`. This needs no browser prefs; in the spike it happened to run under approach (a)'s driver, whose prefs it never uses.

v4l2loopback (a virtual camera device) was considered but not tried, because it needs a root-installed kernel module.

### Results

| | (a) Firefox fake camera | (b) Chrome file capture | (c) In-page substitution, Firefox |
|---|---|---|---|
| Supplies the chosen card image? | No: a synthetic pattern, distance 110 of 256 (threshold 32) | Yes: distance 27 on every run | Yes: distance 0 on every run |
| Card-specific assertion (AC-2.2) | Not possible | Average-hash match | Average-hash match |
| Dev-machine setup | None (Firefox already installed) | Chrome isn't installed; Selenium Manager downloads Chrome for Testing to `~/.cache/selenium` on the first run. ffmpeg to make the `.y4m` (installed) | None |
| CI setup (GitHub `ubuntu-24.04` image) | None: Firefox 156 and geckodriver 0.37.1 are on the image | Chrome 153 and ChromeDriver 153 are on the image; ffmpeg is not, so install it with apt or write the `.y4m` in Ruby | None |
| Run time per example, 10-run loop | median 3.42 s, max 3.54 s | median 1.41 s, max 1.52 s | median 1.61 s, max 4.41 s |
| First run | 3.67 s | 8.23 s (includes the Chrome for Testing download) | 1.73 s |
| Passes over 10 consecutive runs (AC-2.3, AC-2.4) | 10/10 (the example asserts the pattern is *not* the card) | 10/10 | 10/10 |
| Failures | None | None | None |
| What it exercises | The real `getUserMedia` path, but not a card | The real `getUserMedia` and permission path, with a card | The page's code after `getUserMedia`; bypasses the real media and permission path |

The first run of all three passed 3 of 3. The 10-run loop ran with `SE_AVOID_STATS=true`: on the first run Selenium Manager tried to POST usage statistics to `plausible.io` (the request failed), and that variable turns it off. Any use of Selenium Manager in the project's test setup should set it.

Chrome's distance of 27 is close to the threshold of 32, because the `.y4m` is scaled and converted to YUV 4:2:0. It was the same on every run, so it is deterministic, but a tighter threshold would fail.

**Fixture image.** FR-1 forbids committing corpus photos, so neither (b) nor (c) can reuse IMG_6692 in the project's suite. Phase 1 needs a synthetic or suitably licensed card image as its camera fixture, and for (b) a `.y4m` generated from it at test time.

**Suite run time (estimate).** Each camera system test would add roughly its per-example time above, 1.4 to 1.6 s for (b) or (c). This is an estimate from the spike's per-example seconds, which include page load and capture but were measured outside the project's suite. For (b), Chrome is a second browser alongside Firefox, and the `.y4m` (20.7 MB here) has to be generated or cached.

### Recommendation

Use (c), in-page `getUserMedia` substitution, for Phase 1's capture → OCR → candidates system tests: it runs in the existing headless Firefox driver, needs no CI change, and was deterministic (distance 0, 10 of 10). Its gap is that it skips the browser's real media and permission path. If the maintainer wants that path covered too, add (b), Chrome file capture, for one test, accepting a second browser and an ffmpeg (or Ruby-written `.y4m`) step in CI. Don't use (a) for anything that asserts on content: it can't show a card. See ADR 0002.

## 5. Spike 3: fuzzy name index

### Question and method

Does a trigram name index over the local catalog find the right card from misread names, quickly, within the app's schema conventions?

`CardScannerSpike::NameIndex` (`spikes/card_scanner/lib/card_scanner_spike/name_index.rb`) keeps its own SQLite file (`tmp/card_scanner_spike/names.sqlite3`), not the app's schema:

- `names (id, card_name, indexed, norm)`, unique on `(card_name, norm)`: one row for each distinct full card name, plus one row for each face name of a multi-face card, de-duplicated (AC-3.2). `norm` is the normalised `indexed` name.
- `names_fts`, an external-content FTS5 table over `norm` (`content='names'`, `content_rowid='id'`, `tokenize='trigram remove_diacritics 1'`), rebuilt with FTS5's `'rebuild'` command.

A query is normalised, split into its distinct trigrams, and the trigrams are ORed in one `MATCH`. The best 50 rows by `bm25` form a shortlist, which is re-ranked by Jaro-Winkler similarity (Ruby's stdlib `DidYouMean::JaroWinkler.distance`) between the query and each row's `norm`, keeping each card's best-scoring row. Queries shorter than 3 characters skip FTS and use an exact or prefix match on `norm`. The OCR queries are the raw name-strip text, with no cleaning.

### Schema round trip (AC-3.1)

`script/schema_round_trip.rb` creates the table with Rails 8.1.4's `create_virtual_table`, dumps the schema with `ActiveRecord::SchemaDumper`, loads the dump into a fresh database and compares the stored SQL. The dump line, verbatim:

```ruby
create_virtual_table "names_fts", "fts5", ["norm", "content='names'", "content_rowid='id'", "tokenize='trigram remove_diacritics 1'"]
```

- SQL before and after the round trip identical: **true**.
- A trigram `MATCH` after loading the dump finds the inserted row: **true**.

The index, including its tokenizer options, survives `schema.rb`. No fallback is needed. Had it failed, the fallback would have been a SQL-format schema (`structure.sql`) or building the index outside the schema.

### Build time, size and count (AC-3.2)

`script/build_name_index.rb` over the English catalog from the real refresh (Section 2), 3 runs on the desktop:

| Run | Read from catalog | Build index | Total |
|---|---|---|---|
| 1 | 1.07 s | 1.96 s | 3.03 s |
| 2 | 1.08 s | 2.11 s | 3.19 s |
| 3 | 1.09 s | 1.95 s | 3.04 s |
| **Median** | **1.08 s** | **1.96 s** | **3.04 s** |

- Names indexed: 35,986 (full names and face names, de-duplicated).
- Index file on disk: 7,086,080 bytes, of which the FTS5 tables are 2,416,640 bytes (measured with `dbstat`).

### Top-1 and top-3 rates (AC-3.3)

Queried with each photo's raw name-strip text from run-a, re-ranked by Jaro-Winkler.

Correct card is the top candidate:

| Top 1 | Group | Hits / n (rate) |
|---|---|---|
| overall | all | 20/50 (40.0%) |
| era | M15–ONE | 8/20 (40.0%) |
| era | MOM+ | 8/25 (32.0%) |
| era | pre-M15 | 4/5 (80.0%) |
| foil | foil | 4/9 (44.4%) |
| foil | non-foil | 16/41 (39.0%) |
| frame treatment | borderless/showcase | 7/16 (43.8%) |
| frame treatment | regular | 13/34 (38.2%) |

Correct card in the top 3:

| Top 3 | Group | Hits / n (rate) |
|---|---|---|
| overall | all | 26/50 (52.0%) |
| era | M15–ONE | 12/20 (60.0%) |
| era | MOM+ | 10/25 (40.0%) |
| era | pre-M15 | 4/5 (80.0%) |
| foil | foil | 5/9 (55.6%) |
| foil | non-foil | 21/41 (51.2%) |
| frame treatment | borderless/showcase | 9/16 (56.3%) |
| frame treatment | regular | 17/34 (50.0%) |

Query time: median 10.14 ms, 95th percentile 114.46 ms (n=50, run-a, desktop). Long, noisy queries are the slow ones, because they OR many trigrams. Run-b: median 9.81 ms, 95th percentile 113.87 ms (n=50).

When the name strip holds clean text, the matcher finds the card; pre-M15 photos reach 4 of 5 in the top 3. One miss (IMG_6730, Cosmic Hunger) is the matcher's own: the name was read correctly, but the noise around it diluted both the trigram shortlist and the Jaro-Winkler score.

### Edge cases (AC-3.4)

`script/name_edge_cases.rb` against the 35,986-name index. Each name is queried as printed and with one character misread (the middle character replaced by an OCR lookalike, or `x`). "Shorter than 3" lists every indexed name whose normalised form is under 3 characters, plus the two all-underscore names, which normalise to nothing.

| Category | Printed name | Expected card | Exact: top 3 | Misread | Misread: top 3 |
|---|---|---|---|---|---|
| shorter than 3 | Ow | Ow | yes | Ox | no |
| shorter than 3 | X | X | yes | x | yes |
| shorter than 3 | _____ | _____; ______ | no | __x__ | no |
| shorter than 3 | ______ | _____; ______ | no | ___x__ | no |
| diacritic or ligature | Æther Vial | Aether Vial | yes | ÆtherxVial | yes |
| diacritic or ligature | Lim-Dûl's Vault | Lim-Dûl's Vault | yes | Lim-Dûlxs Vault | yes |
| diacritic or ligature | Jötun Grunt | Jötun Grunt | yes | JötunxGrunt | yes |
| diacritic or ligature | Dandân | Dandân | yes | Danxân | yes |
| split | Fire // Ice | Fire // Ice | yes | Fire x/ Ice | yes |
| split | Fire | Fire // Ice; Start // Fire | yes | Fixe | no |
| split | Ice | Fire // Ice | yes | Ixe | no |
| adventure | Bonecrusher Giant | Bonecrusher Giant // Stomp | yes | Bonecrusxer Giant | yes |
| adventure | Stomp | Bonecrusher Giant // Stomp | yes | St0mp | no |
| double-faced | Delver of Secrets | Delver of Secrets // Insectile Aberration | yes | Delver ox Secrets | yes |
| double-faced | Insectile Aberration | Delver of Secrets // Insectile Aberration | yes | Insectile xberration | yes |

Every diacritic, ligature and long multi-face name is found, both exactly and with a misread. The failures, and a proposed fallback for each:

| Failing category | Why it fails | Proposed fallback |
|---|---|---|
| All-underscore names (`_____`, `______`) | They normalise to an empty string, so the search returns nothing | Match the raw, unnormalised text exactly against the stored names when the normalised query is empty |
| Short names and short faces with one misread (`Ox`, `Fixe`, `Ixe`, `St0mp`) | A 3-to-5-character query shares too few trigrams with its target (a 3-character query has only one), so one wrong character removes the target from the shortlist | For short queries, an edit distance of at most 1 over the names of similar length (±1 character). There are few such names, so a scan in Ruby is cheap (estimate; not measured) |
| Noisy OCR queries (the Spike 1 misses, for example IMG_6730) | Extra tokens dilute the trigram OR and the Jaro-Winkler score | Clean the query before searching: take the longest mostly-alphabetic line and drop tokens under 3 characters |

### Refresh cost (AC-3.5)

The index is derived data, so rebuild it in full after each catalog refresh that applies a new source version: clear `names`, reinsert, and run FTS5's `'rebuild'`. That adds a median 3.04 s (n=3, desktop) to a refresh, which took 61 s here (n=1). An incremental update on changed entries only is possible but was not tried; at 3 s, a full rebuild is simpler and keeps the index consistent by construction.

### Recommendation

Keep the FTS5 trigram approach: an external-content table declared in `schema.rb`, rebuilt after each refresh, with Jaro-Winkler re-ranking of a 50-row `bm25` shortlist. Add the three fallbacks above. Index flavour names too once the catalog stores them (1 of 50 photos needed one). See ADR 0003.

## 6. Privacy evidence

- **Header sent.** Every response from the spike server carries `content-security-policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self' blob:; connect-src 'self'; report-uri /csp-report` (checked with `curl` against the LAN address). Every directive allows only `'self'`, the `blob:` scheme for the worker, or `'wasm-unsafe-eval'` to compile the engine. There is no other host (NFR Security, v1.1.1).
- **Cold iPhone run succeeded.** With site data cleared, the page loaded the engine, core and language data from its own origin (8 requests, 7,031,507 bytes) and recognised 2 photos (Section 3). Under this policy any other host would have been blocked, so no other host was needed.
- **CSP violation reports: 0**, over the whole on-device session (cold and warm loads, 11 photos). A desktop smoke run in Firefox 156 during plan review also produced 0 reports.
- **Photos stayed local.** The corpus is served to loopback addresses only; a request from the LAN address got `403`. The iPhone read photos from its own library through the picker. No photo or crop was sent anywhere else, and none is committed.
- **Desktop browser network log.** Not captured. The server's own request log (`tmp/card_scanner_spike/logs/requests.jsonl`, not committed) records every request that reached the spike server, but it can't show requests to other hosts; the CSP result is the evidence for those.

Test tooling, not the page: Selenium Manager tried to send usage statistics to `plausible.io` on the first camera run (Section 4). It carries no photo data, and `SE_AVOID_STATS=true` turns it off.

## 7. Fixtures

Three JSON files in `spec/fixtures/card_scanner/`, all text, no images (AC-4.4). Each file holds one record per photo, and the record's `file` field (the photo's file name, for example `IMG_6688.jpeg`) is unique within the file and is its key. All three cover the same 50 photos. `ocr_results.json` and `name_matches.json` come from **run-a**; run-b's text was identical (Section 3). Treat them as one run's output, not canonical truth.

### `ground_truth.json`

Written by `script/build_ground_truth.rb` from the maintainer's manifest and the local catalog.

| Field | Meaning |
|---|---|
| `format_version` | `1` |
| `photos[]` | One record per photo |
| `photos[].file` | Photo file name; the key |
| `photos[].name` | Card name as the catalog stores it (for example `Aether Vial`; `Front // Back` for multi-face cards) |
| `photos[].name_bar` | Front-face name, which is what the name bar prints; used for the name-read rate |
| `photos[].set_code` | Scryfall set code, lowercase |
| `photos[].collector_number` | Collector number as the catalog stores it |
| `photos[].external_key` | The printing's Scryfall ID |
| `photos[].era` | `pre-M15`, `M15–ONE` or `MOM+` (see below) |
| `photos[].foil` | `true` if the photographed copy is foil, from the manifest |
| `photos[].borderless_or_showcase` | `true` if the printing has a borderless border or the `showcase` frame effect |
| `errors[]` | Manifest rows that failed to resolve: the row's fields plus `problem` (`missing photo`, `unknown era`, `none` or `ambiguous`). Empty here |
| `counts` | `total` (50), `foil` (9) and `by_era` (`pre-M15` 5, `M15–ONE` 20, `MOM+` 25) |

`era` is derived from the printing's release date (or its set's): before 2014-07-18 is `pre-M15`, before 2023-04-21 is `M15–ONE`, otherwise `MOM+`. The manifest's optional `era` column overrides it; no override was used. The spec defines era by what the collector line prints, and the date is an approximation of that. Reprint sets that follow their release year's frame fit it: `mm2` (2015) is `M15–ONE`, `wot` and `mul` (2023) are `MOM+`.

### `ocr_results.json`

Written by `script/match.rb` from the replay's `ocr.json`.

| Field | Meaning |
|---|---|
| `format_version` | `1` |
| `run` | `run-a` |
| `results[]` | One record per photo |
| `results[].file` | Photo file name; the key |
| `results[].run` | `run-a` |
| `results[].name_text` | Raw OCR text of the name strip (newlines kept) |
| `results[].collector_text` | Raw OCR text of the collector strip |
| `results[].name_confidence` | Tesseract's mean confidence for the name strip, 0 to 100 |
| `results[].collector_confidence` | The same for the collector strip |
| `results[].ms` | Desktop recognition time for both strips in headless Firefox, in milliseconds (not the iPhone time) |
| `results[].parsed.set_code` | Parsed set code, uppercase as printed (`NEO`), or `null` |
| `results[].parsed.number` | Parsed collector number, leading zeros removed, promo suffix lowercase (`45p`), or `null` |
| `results[].parsed.language` | Scryfall language code (`en`) from the printed code, or `null` |
| `results[].parsed.foil` | `true` or `false` from the marker between set and language, or `null` if no set line was read. Unreliable (Section 3) |
| `results[].parsed.format` | `slash` (M15–ONE and pre-M15), `rarity_first` (MOM+), or `null` |
| `results[].lookup.status` | `one`, `none` or `ambiguous` (FR-3) |
| `results[].lookup.external_keys` | Scryfall IDs of the matching printings (empty for `none`) |

### `name_matches.json`

Written by `script/match.rb` from the same replay and the Spike 3 index.

| Field | Meaning |
|---|---|
| `format_version` | `1` |
| `run` | `run-a` |
| `matches[]` | One record per photo |
| `matches[].file` | Photo file name; the key |
| `matches[].query` | The query sent: the raw name-strip text |
| `matches[].query_ms` | Query time on the desktop, in milliseconds |
| `matches[].candidates[]` | Up to 3 candidates, best first; empty when nothing matched |
| `matches[].candidates[].card_name` | Catalog card name |
| `matches[].candidates[].matched` | The normalised indexed name (full name or face name) that scored best for that card |
| `matches[].candidates[].score` | Jaro-Winkler similarity between the normalised query and `matched`, 0 to 1, rounded to 4 places |

## 8. Recommended Phase 1 scope

This is a recommendation (AC-4.2). Go / no-go is the maintainer's decision (spec Non-Goals).

What the evidence says: the OCR engine works on the iPhone, can be self-hosted under a strict policy, and is fast enough (median 626 ms per photo, n=11; about 1 KB on a warm load). The name index works and is cheap to keep current. Camera pages can be tested headlessly. The blocker is accuracy with a fixed guide on hand-held photos: 52% top 3 (n=50) and 15.6% exact printing (n=45), with 19 of 24 misses caused by strip framing. So the recommended Phase 1 fixes capture first, measures again, and only then builds the full scan → confirm flow.

**In:**

1. **Live camera preview with the card guide overlay, first, re-measured.** The user sees the camera feed with the 63:88 guide drawn over it and aligns the card before the shutter, so the strips can be tight: the name bar only, the collector line only. Re-run a corpus of at least 50 cards through it with the same scripts and fixture formats, and report the same rates, before building the rest of Phase 1. The size of the gain is not measured; Phase 0 has no live-camera data.
2. **HTTPS for the camera page.** `getUserMedia` needs a secure context, so on the iPhone the page must be served over HTTPS; plain HTTP on the LAN is not enough (a platform requirement, not tested in Phase 0). For self-hosters this means the scanner needs HTTPS in their deployment, and development on a phone needs a local certificate. Document both.
3. **OCR engine per ADR 0001.** Tesseract.js 7.0.0, core 7.0.0, `eng` `4.0.0_best_int`, served by the app from a versioned path (proposed: `public/ocr/v7.0.0/`; Phase 0 did not add anything to `public/`), cached as immutable with `304` on revalidation, loaded only on the scanner page, under a CSP that adds `'wasm-unsafe-eval'` to `script-src` and `blob:` to `worker-src` for that page.
4. **Name matching per ADR 0003.** The FTS5 trigram index in `schema.rb`, rebuilt after each refresh (about 3 s), Jaro-Winkler re-ranking, query cleaning before the search, the empty-normalisation exact match, and the short-name edit-distance fallback.
5. **Collector-line parser fixes.** Glued rarity (`M0149 MOM`), lost slash (`120 Ke NEC`), no rarity letter (`0258 FFV`), and a loose set-code fallback that requires the `SET • LANG` shape or excludes dictionary words (`ONE`).
6. **A printing lookup by set, collector number and language**, built new (there is no resolver chain), reporting one, none or ambiguous.
7. **Finish chosen by the user** at confirmation. Don't take foil from OCR.
8. **Tests.** Pure-Ruby parser and normaliser specs; matcher regression specs over the committed fixtures; system tests of the capture → OCR → candidates flow with in-page `getUserMedia` substitution in the existing headless Firefox (ADR 0002), using a synthetic or licensed card image, not a corpus photo.
9. **After the re-measure:** the scan → candidates → confirm flow the roadmap describes, if the maintainer judges the new numbers good enough.

**Out:**

- Card detection and rectification (OpenCV.js or similar). This is the fallback if live alignment isn't enough; the spec places it in Phase 2, and it would move forward only on that evidence.
- Flavour-name matching, which needs a catalog field the catalog doesn't have (a catalog schema change; 1 of 50 photos affected).
- Japanese and other languages, art hashing, bulk or continuous scanning, native apps (unchanged from the roadmap).
- Chrome file-capture tests in CI, unless the maintainer wants the real media path covered (ADR 0002).

**Changed from the roadmap:**

| The roadmap's Phase 1 | Recommended Phase 1 |
|---|---|
| Fixed card-shaped guide with ROI crops (name top ~4–10%, collector bottom ~5–8%) is sufficient | A live preview with the guide overlay, re-measured before the rest is built; tight strips only once alignment is live |
| Build the scan flow straight away | A measurement gate between the capture step and the scan → confirm flow |
| CSP `connect-src 'self'`, `worker-src 'self' blob:` | Add `'wasm-unsafe-eval'` to `script-src` |
| About 4 MB first-launch download for English | 7.03 MB measured (n=1): one core build (3.9 MB) plus the `best_int` language data (2.95 MB) |
| Feed parsed lines into the existing resolver rung 3 | Build a printing lookup; there is no resolver chain |
| Ruby re-ranking with a gem (`damerau-levenshtein` or `jaro_winkler`) | Stdlib `DidYouMean::JaroWinkler`; plus query cleaning and short-name fallbacks |
| Fake-camera system tests with Chrome flags and Cuprite | In-page `getUserMedia` substitution in the existing Selenium headless Firefox; Chrome file capture optional |
| Foil from the premium-star marker once parsed | Finish chosen by the user |
| HTTPS not stated as a Phase 1 requirement | HTTPS required for the camera on iOS; a self-hosting consideration |

**Decision for the maintainer.** The options the evidence supports:

- **Go with the changed scope:** start Phase 1 with the live guide and tight strips, re-measure, then build the flow.
- **Pivot to detection first:** bring card detection and rectification forward from Phase 2 and make it Phase 1's capture step, accepting a larger download (OpenCV.js; about 8 MB per the roadmap, not measured here) and more work.
- **No-go:** stop the OCR-based scanner; the name index and printing lookup could still serve a typed quick-add.

## 9. Roadmap assumptions contradicted

Every assumption in the scanner roadmap that the Phase 0 evidence contradicted, with that evidence (AC-4.2).

| The scanner roadmap assumed | The evidence |
|---|---|
| A fixed card-shaped guide with ROI crops is sufficient, because the user aligns the card and strip OCR tolerates small misalignment | On hand-held photos without a live overlay, the card drifted by about ±4% of the image (pilot, n=5). Strips tall enough to absorb that reached 52% top 3 (n=50) and 15.6% exact printing (n=45); 19 of 24 misses trace to the fixed strips. A live overlay was not tested, so the roadmap's own premise (the user aligns to a visible guide) is still untested |
| Roughly 4 MB first-launch download for English | 7,031,507 bytes on a cold iPhone load (n=1): the `simd-lstm` core is 3,899,472 bytes and the `eng` language data 2,952,873 |
| A strict CSP of `connect-src 'self'` and `worker-src 'self' blob:` is enough | WebAssembly compilation also needs `'wasm-unsafe-eval'` in `script-src`; with it, 0 violation reports and a working cold run (spec v1.1.1) |
| Pin v7 with a matching-major `tesseract.js-core`, as npm's latest | `tesseract.js` 7.0.0 is published, but `tesseract.js-core`'s `latest` tag still pointed to 6.1.2 at planning; core 7.0.0 is published and had to be pinned explicitly. The core directory holds six builds (adding `relaxedsimd`), not four |
| The star/bullet marker can be parsed for foil | Read on 8 photos, right on 5 (62.5%); Tesseract reads `•` as `*`, `«` or `+` |
| Feed parsed lines into the existing resolver rung 3 | There is no resolver chain; a printing lookup had to be prototyped (spec corrections) |
| Fake-camera testing with Chrome flags under Cuprite | The project uses Selenium with headless Firefox, whose fake camera shows only a synthetic pattern (distance 110 of 256). Chrome file capture works (10/10) but is a second browser; in-page substitution works in the current driver (10/10) |
| Verify the SDD plugin's `sdd-init` layout in a spike | Moot: the SDD plugin is installed and in use (`docs/specs/NNN-slug/`) |

Checked and held:

- **Versioned path with immutable caching.** The warm iPhone load fetched 1,055 bytes: the engine, core and language data were not requested at all, and only the page and its script went to the server. The spike server also answers any revalidation of an `/ocr/` file with `304` and no body, in case a browser ignores `immutable`; the iPhone never exercised that path.
- **FTS5 trigram in `schema.rb`.** The round trip holds on Rails 8.1.4 (AC-3.1).
- **`051/302 NEO`** parses as NEO 51 (AC-1.4).
- **Diacritics and ligatures.** NFKC plus "Æ" folding and `remove_diacritics` find "Æther Vial", "Lim-Dûl's Vault", "Jötun Grunt" and "Dandân", exactly and with a misread (AC-3.4).

## 10. Decisions

Each recommended decision has a Proposed ADR (AC-4.3; convention: [`docs/adr/README.md`](../../adr/README.md)):

- [ADR 0001: Self-host Tesseract.js 7 for in-browser OCR](../../adr/0001-browser-ocr-engine-and-asset-hosting.md)
- [ADR 0002: Test the camera path by substituting getUserMedia in the page](../../adr/0002-camera-path-testing.md)
- [ADR 0003: Index card names with an FTS5 trigram table](../../adr/0003-card-name-index.md)
