# Feature 007: Card Scanner Phase 1 — Findings

**Spec:** [spec.md](spec.md) (v2.1.1) | **Plan:** [plan.md](plan.md)
**Measured:** 2026-10-01 and 2026-10-02 | **Branch:** `007-card-scanner-live-capture` | **Settings:** commit `c68ffbd` (frozen)

**Corrected 2026-10-02:** §2 and §7 had the stored size and EXIF orientation of the two photo corpora the wrong way round. Every file in both corpora was checked with `magick identify`. No rate or conclusion changes.

Every rate carries its sample size. Anything not measured is labelled as such. Phase 1 sets no pass threshold: the numbers inform the maintainer's decision on the scan → confirm flow, they don't make it.

---

## 1. Summary

**What was and wasn't measured.** The question Phase 1 exists to answer is whether lining a card up with a live guide fixes Phase 0's accuracy problem. It was answered on a **new corpus of 49 cards** the maintainer owns, none of them in Phase 0's corpus or among the tuning cards, captured live on the iPhone at the frozen settings (§5). The 12 tuning cards' live captures are reported too, but those cards also chose the settings, so their rates are biased upwards (§4). Phase 0's 50 cards were borrowed and returned, so only their Phase 0 photos could be replayed (§3).

**Live capture on the new corpus (iPhone, Brave, n=49).** The right card was first in the final ranking for 42/49 (85.7%) and in the top 3 for 45/49 (91.8%). The collector line identified the exact printing for 34 of the 44 set-line cards (77.3%). Phase 0's comparable rates, on different cards, were 26/50 in the name-only top 3 and 7/45 for the exact printing. Recognition took a median of 168 ms per capture, slowest 322 ms. The weak spots are foils (exact printing 4/10, first 7/11) and older frames (top 3 for 3/5). In 3 captures a misread collector number pointed at a real printing of another card, which then outranked the right name (§5).

**Photos of the same 49 cards, without the guide.** The right card was in the top 3 for 2/49. In these photos the card fills about 95% of the frame height (estimated from the photos, not measured), against the guide's 80%, so every name strip landed on the art. Phase 0's photos, where cards filled 69–77% of the frame, had the right card in the top 3 for 24/50 through the same path (§3). The photo path works only when the framing happens to match the guide.

**Live capture on the tuning cards (iPhone, Brave; biased).** On the final two rounds of fresh captures, the right card was in the name-only top 3 for 11/12 and 10/12. It was first in the final ranking for 10/12 and 9/12. The exact printing came from the collector line for 6/9 in both rounds. Phase 0's comparable rates, on the different 50 cards, were 26/50 (top 3) and 7/45 (exact printing). Recognition on the phone took a median of about 185 ms per capture, slowest 539 ms (n=44), against Phase 0's 626 ms.

**The matcher on Phase 0's own cards.** Phase 0's recorded OCR text, read through Phase 1's parser and matcher, identified the exact printing for 15/45 instead of 7/45. The final ranking had the right card first for 33/50. That is the gain from the code alone (§3).

**The photo replay of Phase 0's cards.** The right card was first for 23/50, and the exact printing was found for 16/45. Names suffer because the guide's framing doesn't match where cards sit in these unguided photos: 21 of the 26 misses are misalignment (§6). The collector-line path holds up (16/45).

**The engine and the page work as designed.**
- A cold load of the scanner page downloads 7,050,153 bytes, including one core build. A warm load re-downloads nothing.
- The policy, the camera lifecycle, the torch, the photo fallback and the plain-HTTP explanation all passed on the iPhone (§7, §8).
- Desktop replays reproduce the device's text exactly (§9).

## 2. Method and apparatus

- **App:** branch `007-card-scanner-live-capture`. The settings were frozen at `c68ffbd` after 4 tuning rounds (AC-6.1):
  - Guide: 80% of the 3:4 stage's height, at most 90% of its width.
  - Name strip: x 0.05, y 0.055, w 0.75, h 0.11, page segmentation 6.
  - Collector strip: x 0.03, y 0.89, w 0.55, h 0.11, page segmentation 6.
  - Both strips drawn at 2× with a grayscale min–max contrast stretch. The collector strip's dark pixel rows are inverted before OCR.
  - Engine: Tesseract.js 7.0.0, core 7.0.0, `eng` `4.0.0_best_int`, served by the app from `/ocr/v7.0.0/`.
- **Camera resolution (FR-2):** the page asks for `width: ideal 1920, height: ideal 1080`, rear camera. The delivered resolution wasn't logged. Round 1's strips, drawn at 1× before 2× scaling was added, were 590×97 px for the name. That puts the guide about 1,141 px tall in the frame, and the stage's visible area about 1,070×1,426 px, which matches a 1080×1920 portrait frame: the requested size, rotated. This is inferred from the strip sizes, not measured directly.
- **Catalog:** Scryfall `default-cards-20260930210545` (106,677 English entries), with 35,946 names indexed.
- **Device:** the maintainer's iPhone, iOS 18.7, Brave (WebKit; `… Version/26.6.1 Mobile/15E148 Safari/604.1 Brave`). It reached the dev server over HTTPS on the local network, using a self-signed certificate it trusts (`bin/dev-certificate`). The maintainer's Cloudflare tunnel returned 502 and was abandoned.
- **Tuning cards:** 12 English cards outside the 50-card corpus (`~/card-scanner-corpus/tuning/manifest.csv`): 3 pre-M15, 7 M15–ONE, 2 MOM+, 3 foil. Rounds 1–2 had the first 10 cards; T011–T012 (MOM+) were added for rounds 3–4. Ground truth was built from the catalog (`scanner:ground_truth`): 12 of 12 resolved.
- **New corpus (AC-6.9):** 49 English cards the maintainer owns, in `~/card-scanner-corpus/phase1-live/` (manifest, ground truth and one photo per card, outside the repository). The photos are stored as 4032×3024 with EXIF orientation 6, so they display as 3024×4032 portrait.
  - None is among Phase 0's 50 cards or the 12 tuning cards. Two rows repeated Phase 0 printings (`hob 225`, `wot 49`) and were dropped before capture, so the corpus is 49 cards, not 50 (maintainer ruling).
  - 16 MOM+, 28 M15–ONE and 5 pre-M15; 11 foil; 12 borderless or showcase.
  - Era follows the printed frame. Three List reprints (`plst`, 1997 and 2003 frames) and one retro-frame `mat` card print no set code, so the manifest gives them `era` pre-M15. The rest take their era from the release date, as before.
  - Manifest corrections, all to ground truth only: the List rows' set and numbers (`plst`, `PCY-132`, `GPT-162`, `EVE-143`) before capture, and IMG_6763 after capture, whose card is Leyline Immersion `mat 71`, not `mul 71`. Its name strip showed the mistake.
  - Settings: unchanged since `c68ffbd`. Nothing under `app/javascript/scanner`, `app/models/catalog` or `app/models/mtg` changed.
  - Live run: 2026-10-02 on the same iPhone and browser, in manifest order, one deliberate shot per card. Afterwards the strips were replayed once on the desktop.
  - Photos: replayed through the photo picker with `script/scanner/photo_run.rb` in headless Firefox 156, as in §3.
- **Capture protocol (AC-5.4):** one deliberate shot per card with the card filling the guide. A card's first capture is the measured one. Retakes are stored but not counted.
- **Photo replay (AC-6.2):** the 50 Phase 0 photos (stored as 3024×4032 portrait with EXIF orientation 1, so this replay applied no rotation; the new corpus's photos are the ones that rely on it). `script/scanner/photo_run.rb` fed each one to the real photo picker in headless Firefox 156 on the desktop. The shipped code placed the guide as on a live frame, cut and read the strips, matched them, and stored the capture through measurement mode. The cards in these photos fill 69–77% of the frame height and drift by about ±4% (spec 005), against the guide's fixed 80%. That mismatch is why misalignment dominates its misses.
- **Scoring:** `bin/rails scanner:findings` (`Collector::ScannerFindings`), using spec 005's definitions. It reproduces Phase 0's committed rates exactly from its fixtures (top 3 26/50, exact printing 7/45). Top 1 and top 3 are reported twice: over the name candidates alone, which is Phase 0's definition, and over the page's final ranking, where a collector-line match comes first.

## 3. Rates: Phase 0, Phase 0's text with Phase 1's matcher, and the photo replay (AC-6.2, AC-6.3)

The middle column changes only the code, since it uses Phase 0's own OCR text. The right column also changes the strips: the guide-relative strips are cut from Phase 0's unguided photos. The final ranking has no Phase 0 column, because Phase 0 had no collector-first ranking. Lookup outcomes over the 45 set-line cards: Phase 0 one 8, none 37; Phase 0 text with Phase 1's matcher one 17, none 28; photo replay one 18, none 27. No lookup in any run was ambiguous (0).

| Name read (front face) | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 photo replay |
|---|---|---|---|---|
| overall | all | 5/50 (10.0%) | 5/50 (10.0%) | 3/50 (6.0%) |
| era | M15–ONE | 3/20 (15.0%) | 3/20 (15.0%) | 3/20 (15.0%) |
| era | MOM+ | 1/25 (4.0%) | 1/25 (4.0%) | 0/25 (0.0%) |
| era | pre-M15 | 1/5 (20.0%) | 1/5 (20.0%) | 0/5 (0.0%) |
| foil | foil | 2/9 (22.2%) | 2/9 (22.2%) | 1/9 (11.1%) |
| foil | non-foil | 3/41 (7.3%) | 3/41 (7.3%) | 2/41 (4.9%) |
| frame treatment | borderless/showcase | 2/16 (12.5%) | 2/16 (12.5%) | 1/16 (6.3%) |
| frame treatment | regular | 3/34 (8.8%) | 3/34 (8.8%) | 2/34 (5.9%) |

| Name read (catalog name) | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 photo replay |
|---|---|---|---|---|
| overall | all | 5/50 (10.0%) | 5/50 (10.0%) | 3/50 (6.0%) |
| era | M15–ONE | 3/20 (15.0%) | 3/20 (15.0%) | 3/20 (15.0%) |
| era | MOM+ | 1/25 (4.0%) | 1/25 (4.0%) | 0/25 (0.0%) |
| era | pre-M15 | 1/5 (20.0%) | 1/5 (20.0%) | 0/5 (0.0%) |
| foil | foil | 2/9 (22.2%) | 2/9 (22.2%) | 1/9 (11.1%) |
| foil | non-foil | 3/41 (7.3%) | 3/41 (7.3%) | 2/41 (4.9%) |
| frame treatment | borderless/showcase | 2/16 (12.5%) | 2/16 (12.5%) | 1/16 (6.3%) |
| frame treatment | regular | 3/34 (8.8%) | 3/34 (8.8%) | 2/34 (5.9%) |

| Top 1, name only | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 photo replay |
|---|---|---|---|---|
| overall | all | 20/50 (40.0%) | 27/50 (54.0%) | 14/50 (28.0%) |
| era | M15–ONE | 8/20 (40.0%) | 11/20 (55.0%) | 9/20 (45.0%) |
| era | MOM+ | 8/25 (32.0%) | 12/25 (48.0%) | 5/25 (20.0%) |
| era | pre-M15 | 4/5 (80.0%) | 4/5 (80.0%) | 0/5 (0.0%) |
| foil | foil | 4/9 (44.4%) | 5/9 (55.6%) | 3/9 (33.3%) |
| foil | non-foil | 16/41 (39.0%) | 22/41 (53.7%) | 11/41 (26.8%) |
| frame treatment | borderless/showcase | 7/16 (43.8%) | 9/16 (56.3%) | 7/16 (43.8%) |
| frame treatment | regular | 13/34 (38.2%) | 18/34 (52.9%) | 7/34 (20.6%) |

| Top 3, name only | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 photo replay |
|---|---|---|---|---|
| overall | all | 26/50 (52.0%) | 27/50 (54.0%) | 14/50 (28.0%) |
| era | M15–ONE | 12/20 (60.0%) | 11/20 (55.0%) | 9/20 (45.0%) |
| era | MOM+ | 10/25 (40.0%) | 12/25 (48.0%) | 5/25 (20.0%) |
| era | pre-M15 | 4/5 (80.0%) | 4/5 (80.0%) | 0/5 (0.0%) |
| foil | foil | 5/9 (55.6%) | 5/9 (55.6%) | 3/9 (33.3%) |
| foil | non-foil | 21/41 (51.2%) | 22/41 (53.7%) | 11/41 (26.8%) |
| frame treatment | borderless/showcase | 9/16 (56.3%) | 9/16 (56.3%) | 7/16 (43.8%) |
| frame treatment | regular | 17/34 (50.0%) | 18/34 (52.9%) | 7/34 (20.6%) |

| Top 1, final ranking | Group | Phase 0 text, Phase 1 matcher | Phase 1 photo replay |
|---|---|---|---|
| overall | all | 33/50 (66.0%) | 23/50 (46.0%) |
| era | M15–ONE | 12/20 (60.0%) | 12/20 (60.0%) |
| era | MOM+ | 17/25 (68.0%) | 11/25 (44.0%) |
| era | pre-M15 | 4/5 (80.0%) | 0/5 (0.0%) |
| foil | foil | 6/9 (66.7%) | 3/9 (33.3%) |
| foil | non-foil | 27/41 (65.9%) | 20/41 (48.8%) |
| frame treatment | borderless/showcase | 12/16 (75.0%) | 6/16 (37.5%) |
| frame treatment | regular | 21/34 (61.8%) | 17/34 (50.0%) |

| Top 3, final ranking | Group | Phase 0 text, Phase 1 matcher | Phase 1 photo replay |
|---|---|---|---|
| overall | all | 33/50 (66.0%) | 24/50 (48.0%) |
| era | M15–ONE | 12/20 (60.0%) | 13/20 (65.0%) |
| era | MOM+ | 17/25 (68.0%) | 11/25 (44.0%) |
| era | pre-M15 | 4/5 (80.0%) | 0/5 (0.0%) |
| foil | foil | 6/9 (66.7%) | 4/9 (44.4%) |
| foil | non-foil | 27/41 (65.9%) | 20/41 (48.8%) |
| frame treatment | borderless/showcase | 12/16 (75.0%) | 7/16 (43.8%) |
| frame treatment | regular | 21/34 (61.8%) | 17/34 (50.0%) |

| Exact printing (M15–ONE, MOM+) | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 photo replay |
|---|---|---|---|---|
| overall | all | 7/45 (15.6%) | 15/45 (33.3%) | 16/45 (35.6%) |
| era | M15–ONE | 2/20 (10.0%) | 5/20 (25.0%) | 8/20 (40.0%) |
| era | MOM+ | 5/25 (20.0%) | 10/25 (40.0%) | 8/25 (32.0%) |
| foil | foil | 0/9 (0.0%) | 3/9 (33.3%) | 1/9 (11.1%) |
| foil | non-foil | 7/36 (19.4%) | 12/36 (33.3%) | 15/36 (41.7%) |
| frame treatment | borderless/showcase | 3/16 (18.8%) | 7/16 (43.8%) | 5/16 (31.3%) |
| frame treatment | regular | 4/29 (13.8%) | 8/29 (27.6%) | 11/29 (37.9%) |

Lookup outcomes (M15–ONE, MOM+): Phase 0 {"none" => 37, "one" => 8}; Phase 0 text, Phase 1 matcher {"none" => 28, "one" => 17}; Phase 1 photo replay {"none" => 27, "one" => 18}

## 4. Live captures on the tuning cards (AC-6.8)

**These were the only live-alignment evidence until the re-measure on a new corpus (§5), and they are biased upwards.** The same 12 cards were used to choose the settings round by round. Rounds 3 and 4 are fresh captures at the settings each round tested, but those settings were picked partly on earlier captures of the same cards.

| Round | Settings commit | Cards | Name read | Top 1 / top 3, name only | Top 1 / top 3, final | Exact printing | Lookups (set-line cards) |
|---|---|---|---|---|---|---|---|
| 1 | initial (`fa4e4eb`) | 10 | 0/10 | 1/10 / 1/10 | 6/10 / 6/10 | 5/7 | one 5, none 2 |
| 2 | `ca27148` | 10 | 0/10 | 4/10 / 4/10 | 8/10 / 8/10 | 6/7 | one 6, none 1 |
| 3 | `7d4f09d` | 12 | 0/12 | 11/12 / 11/12 | 10/12 / 11/12 | 6/9 | one 7, none 2 |
| 4 | `ec71cd9` (= frozen `c68ffbd`) | 12 | 5/12 | 10/12 / 10/12 | 9/12 / 10/12 | 6/9 | one 7, none 2 |

What changed between rounds:
- **Round 1 → 2:** the name strip was cut too high, so on every card the name sat at its bottom edge and was usually clipped (name read 0/10). The name strip moved down and got taller (y 0.03→0.055, h 0.085→0.11). Strips are now drawn at 2× and contrast-stretched.
- **Round 2 → 3:** with the names inside the strip, page segmentation 7 (a single line) garbled them amid frame lines. Desktop replays of round 2's stored strips compared modes for the name strip: psm 7 put 4/10 names in the top 3, psm 6 put 10/10, psm 11 4/10 and psm 13 1/10. The collector strip was also extended to the card's bottom edge after a card held slightly large lost its set line.
- **Round 3 → 4:** collector lines are small light text on the black border. Replays of the 22 stored captures from rounds 2 and 3 compared preparations:
  - Inverting the strip's dark rows lifted round 3's exact printing from 6/9 to 8/9, with no change in round 2.
  - Otsu binarising made it worse (5/9; 4/7 in round 2).
  - Page segmentation 4 or 11 was no better.
  - Inverting the name strip too hurt names (9/10 and 9/12).
- **Round 4, on fresh captures, didn't beat round 3:** 6/9 exact printing in both. What remained was photo-to-photo OCR variation. A sharp name read as `el Tae.`; `257` read as `287`; `328` read as `528`.
- **Tried and rejected:**
  - A one-substitution set-code correction: `ERA` is one letter from both `EMA` and `FRA`, and about a quarter of random misreads sit one letter from exactly one real code, so a correction would invent matches.
  - A "leading words" name query: no gain in tuning, and 3 fewer first places on Phase 0's text.

Round 4 in full, at the frozen settings:

| Name read (front face) | Group | Tuning round 4 (live) |
|---|---|---|
| overall | all | 5/12 (41.7%) |
| era | M15–ONE | 4/7 (57.1%) |
| era | MOM+ | 1/2 (50.0%) |
| era | pre-M15 | 0/3 (0.0%) |
| foil | foil | 1/3 (33.3%) |
| foil | non-foil | 4/9 (44.4%) |
| frame treatment | regular | 5/12 (41.7%) |

| Name read (catalog name) | Group | Tuning round 4 (live) |
|---|---|---|
| overall | all | 5/12 (41.7%) |
| era | M15–ONE | 4/7 (57.1%) |
| era | MOM+ | 1/2 (50.0%) |
| era | pre-M15 | 0/3 (0.0%) |
| foil | foil | 1/3 (33.3%) |
| foil | non-foil | 4/9 (44.4%) |
| frame treatment | regular | 5/12 (41.7%) |

| Top 1, name only | Group | Tuning round 4 (live) |
|---|---|---|
| overall | all | 10/12 (83.3%) |
| era | M15–ONE | 7/7 (100.0%) |
| era | MOM+ | 1/2 (50.0%) |
| era | pre-M15 | 2/3 (66.7%) |
| foil | foil | 2/3 (66.7%) |
| foil | non-foil | 8/9 (88.9%) |
| frame treatment | regular | 10/12 (83.3%) |

| Top 3, name only | Group | Tuning round 4 (live) |
|---|---|---|
| overall | all | 10/12 (83.3%) |
| era | M15–ONE | 7/7 (100.0%) |
| era | MOM+ | 1/2 (50.0%) |
| era | pre-M15 | 2/3 (66.7%) |
| foil | foil | 2/3 (66.7%) |
| foil | non-foil | 8/9 (88.9%) |
| frame treatment | regular | 10/12 (83.3%) |

| Top 1, final ranking | Group | Tuning round 4 (live) |
|---|---|---|
| overall | all | 9/12 (75.0%) |
| era | M15–ONE | 6/7 (85.7%) |
| era | MOM+ | 1/2 (50.0%) |
| era | pre-M15 | 2/3 (66.7%) |
| foil | foil | 2/3 (66.7%) |
| foil | non-foil | 7/9 (77.8%) |
| frame treatment | regular | 9/12 (75.0%) |

| Top 3, final ranking | Group | Tuning round 4 (live) |
|---|---|---|
| overall | all | 10/12 (83.3%) |
| era | M15–ONE | 7/7 (100.0%) |
| era | MOM+ | 1/2 (50.0%) |
| era | pre-M15 | 2/3 (66.7%) |
| foil | foil | 2/3 (66.7%) |
| foil | non-foil | 8/9 (88.9%) |
| frame treatment | regular | 10/12 (83.3%) |

| Exact printing (M15–ONE, MOM+) | Group | Tuning round 4 (live) |
|---|---|---|
| overall | all | 6/9 (66.7%) |
| era | M15–ONE | 5/7 (71.4%) |
| era | MOM+ | 1/2 (50.0%) |
| foil | foil | 1/2 (50.0%) |
| foil | non-foil | 5/7 (71.4%) |
| frame treatment | regular | 6/9 (66.7%) |


## 5. Live re-measure on a new corpus (AC-6.9)

**This is Phase 1's unbiased live measure.** The cards weren't used for tuning, the settings were frozen before the run (`c68ffbd`), and each card's first capture counts. The live and photo columns are the same 49 cards. Phase 0 and the tuning rounds used different cards, so comparisons with them are across corpora.

Lookup outcomes over the 44 set-line cards: live, one 37 and none 7; photos, one 2 and none 42. No lookup was ambiguous (0).

Name read against the catalog name gives the same counts as against the front-face name, group by group, in both runs (live 5/49, photos 0/49), so only the front-face table is shown (last below).

| Top 1, name only | Group | Live (iPhone) | Photos (no guide) |
|---|---|---|---|
| overall | all | 39/49 (79.6%) | 0/49 (0.0%) |
| era | M15–ONE | 22/28 (78.6%) | 0/28 (0.0%) |
| era | MOM+ | 14/16 (87.5%) | 0/16 (0.0%) |
| era | pre-M15 | 3/5 (60.0%) | 0/5 (0.0%) |
| foil | foil | 9/11 (81.8%) | 0/11 (0.0%) |
| foil | non-foil | 30/38 (78.9%) | 0/38 (0.0%) |
| frame treatment | borderless/showcase | 10/12 (83.3%) | 0/12 (0.0%) |
| frame treatment | regular | 29/37 (78.4%) | 0/37 (0.0%) |

| Top 3, name only | Group | Live (iPhone) | Photos (no guide) |
|---|---|---|---|
| overall | all | 39/49 (79.6%) | 0/49 (0.0%) |
| era | M15–ONE | 22/28 (78.6%) | 0/28 (0.0%) |
| era | MOM+ | 14/16 (87.5%) | 0/16 (0.0%) |
| era | pre-M15 | 3/5 (60.0%) | 0/5 (0.0%) |
| foil | foil | 9/11 (81.8%) | 0/11 (0.0%) |
| foil | non-foil | 30/38 (78.9%) | 0/38 (0.0%) |
| frame treatment | borderless/showcase | 10/12 (83.3%) | 0/12 (0.0%) |
| frame treatment | regular | 29/37 (78.4%) | 0/37 (0.0%) |

| Top 1, final ranking | Group | Live (iPhone) | Photos (no guide) |
|---|---|---|---|
| overall | all | 42/49 (85.7%) | 2/49 (4.1%) |
| era | M15–ONE | 25/28 (89.3%) | 1/28 (3.6%) |
| era | MOM+ | 14/16 (87.5%) | 1/16 (6.3%) |
| era | pre-M15 | 3/5 (60.0%) | 0/5 (0.0%) |
| foil | foil | 7/11 (63.6%) | 1/11 (9.1%) |
| foil | non-foil | 35/38 (92.1%) | 1/38 (2.6%) |
| frame treatment | borderless/showcase | 10/12 (83.3%) | 1/12 (8.3%) |
| frame treatment | regular | 32/37 (86.5%) | 1/37 (2.7%) |

| Top 3, final ranking | Group | Live (iPhone) | Photos (no guide) |
|---|---|---|---|
| overall | all | 45/49 (91.8%) | 2/49 (4.1%) |
| era | M15–ONE | 27/28 (96.4%) | 1/28 (3.6%) |
| era | MOM+ | 15/16 (93.8%) | 1/16 (6.3%) |
| era | pre-M15 | 3/5 (60.0%) | 0/5 (0.0%) |
| foil | foil | 9/11 (81.8%) | 1/11 (9.1%) |
| foil | non-foil | 36/38 (94.7%) | 1/38 (2.6%) |
| frame treatment | borderless/showcase | 11/12 (91.7%) | 1/12 (8.3%) |
| frame treatment | regular | 34/37 (91.9%) | 1/37 (2.7%) |

| Exact printing (M15–ONE, MOM+) | Group | Live (iPhone) | Photos (no guide) |
|---|---|---|---|
| overall | all | 34/44 (77.3%) | 2/44 (4.5%) |
| era | M15–ONE | 22/28 (78.6%) | 1/28 (3.6%) |
| era | MOM+ | 12/16 (75.0%) | 1/16 (6.3%) |
| foil | foil | 4/10 (40.0%) | 1/10 (10.0%) |
| foil | non-foil | 30/34 (88.2%) | 1/34 (2.9%) |
| frame treatment | borderless/showcase | 8/11 (72.7%) | 1/11 (9.1%) |
| frame treatment | regular | 26/33 (78.8%) | 1/33 (3.0%) |

| Name read (front face) | Group | Live (iPhone) | Photos (no guide) |
|---|---|---|---|
| overall | all | 5/49 (10.2%) | 0/49 (0.0%) |
| era | M15–ONE | 2/28 (7.1%) | 0/28 (0.0%) |
| era | MOM+ | 2/16 (12.5%) | 0/16 (0.0%) |
| era | pre-M15 | 1/5 (20.0%) | 0/5 (0.0%) |
| foil | foil | 0/11 (0.0%) | 0/11 (0.0%) |
| foil | non-foil | 5/38 (13.2%) | 0/38 (0.0%) |
| frame treatment | borderless/showcase | 0/12 (0.0%) | 0/12 (0.0%) |
| frame treatment | regular | 5/37 (13.5%) | 0/37 (0.0%) |

**Beside the earlier evidence** (different cards in each column):

| Measure | Phase 0, photos (50 cards) | Tuning round 4, live (12 cards, biased) | New corpus, live (49 cards) |
|---|---|---|---|
| Top 3, name only | 26/50 | 10/12 | 39/49 |
| Top 1, final ranking | — | 9/12 | 42/49 |
| Top 3, final ranking | — | 10/12 | 45/49 |
| Exact printing (set-line cards) | 7/45 | 6/9 | 34/44 |
| Recognition per capture, median / slowest | 626 / 1,911 ms (n=11) | 288 / 539 ms (round 4) | 168 / 322 ms |

**A misread collector number can outrank the right name: 3 of 49.** Each misread named a real printing of another card. It was ranked first as the collector-line match (AC-3.2), and the right card came second from the name.

| File | Card | Printed | Read as | Ranked first |
|---|---|---|---|---|
| IMG_6765.jpeg | Tome Shredder | STX 117 | STX 17 | Elite Spellbinder |
| IMG_6769.jpeg | Grand Master of Flowers | AFR 282 (foil) | AFR 202 | Ranger Class |
| IMG_6792.jpeg | Cast Away Doubt | FRA 51 (foil) | FRA 5 | Enlightened Confidant |

**Collector lines that found no printing: 7 of 44.** Four are foils whose number was lost or garbled (IMG_6768, IMG_6772, IMG_6777, IMG_6790). IMG_6756's set code was cut at the strip's left edge (`KO` for `IKO`). IMG_6759's number came out as `D019` and wasn't parsed. IMG_6785's `0411` was read as `04am`.

**Misses, live, not in the final top 3: 4 of 49.** Causes come from viewing both stored strips (`~/card-scanner-corpus/runs/phase1-live/<file>/capture-001-*.png`, not committed).

| File | Expected | Name strip | Collector strip | Top 3 | Likely cause |
|---|---|---|---|---|---|
| IMG_6761.jpeg | Orzhova, the Church of Deals | loon the Church of Dea | \| Rts xv Mi | Join the Dead; Poison the Cup; Anowon, the Ruin Thief | Misalignment and matcher miss: the long name ran past the strip's right edge and its first word was read as `loon`; the List reprint's collector line prints no set code |
| IMG_6764.jpeg | Tormod's Crypt | Cr RAD \| A SR— : #1 - | Pe” W BG Eo (gee LLL ITH | Rad Rascal; Radstorm; Bad Ass | Misalignment: the card sat high, so the name was cut at the strip's top; the pre-M15 collector strip is a blurred copyright line |
| IMG_6777.jpeg | Ritual Guardian | I ' 44 TY8 | wT dat C MID*EN w Dinmany Roowur |  | Misalignment: name cut at the strip's top; the faint foil collector line (`030/277 C / MID★EN`) lost its number |
| IMG_6785.jpeg | Dunland Crebain | BE 0 | —————a— Ba i C 04am ¥ LTR « EN % DaviD RAPOZA | Bribe Taker; Lobe Lobber; Robe of Stars | Unusual frame: a sharp, well-framed white name on a dark bar read as `BE 0`; collector number `0411` read as `04am` |

**Misses, photos, not in the final top 3: 47 of 49.** All 47 have the same cause. The maintainer photographed each card filling about 95% of the frame height (estimated, not measured), so the guide's 80% box put the name strip on the art and the collector strip on the rules or flavour text. A contact sheet of all 49 name strips shows art on every one, and two show an Adventure banner. The 2 hits came from collector lines.

| File | Expected | Name strip | Collector strip | Top 3 | Likely cause |
|---|---|---|---|---|---|
| IMG_6756.jpeg | Indatha Crystal | /Z A Z> \| 7 } 4 NE LA Ae il. \| a cw rE ' Oe b a os <7 a" LE 4 Aap” (2 - | reLca trees as iy berry embrace. aimee oi. aR | Zap | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6757.jpeg | Invasion of Muraganda // Primordial Plasm | fe" be “% a 7 A -y ’ Y Yi o 4 § 7 2 Q epg ay “A L \ ; 51% DUT VD ® \| é Ai LF = ; Rong R ; £ N pT a ¥ 77 AR TY \| i C & fe. > he 7 z : ®, Oh, . u es A Ge Fes 4 ™ By 9 de 0 | ve s — EY VY 4 \| \| oy A "\| - ‘ + ol $ er > ‘0 ~~ & a f 0199 | Moonshae Pixie // Pixie Dust; Vow of Duty; Vassal's Duty | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6758.jpeg | Minsc, Beloved Ranger | Be ee T—— \. A&P \ | arid DCCOI1IICO 4a \Jliallt iil types. Activate only as a | Hyena Pack; Mana Prism; Affa Protector | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6759.jpeg | Repurposed Enforcer | a - - . % ‘ t ' Ty be y LY } ll " Ee [¥ 3 - a \ ly < \ Ta : 4, etd : \ a. on - Syd - A — ) ¥- R ‘y J A : a - v 2s g pd Bs » * = rl . ’ y ro. Fo _— LY | A face half remembered, a f 42 |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6760.jpeg | Vintara Snapper | 3 : + ¢ J ’ ; - PF i "4 g . ‘ o d - \| - rr 4 — Sa o > TR 4 : 4d *s “ | IMlus. Joel E 1993-2000 Wizards of the C | Sea of Clouds; Nyssa of Traken; Nissa, Worldwaker | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6761.jpeg | Orzhova, the Church of Deals | "Re 7 | DESL LU DTaY UEUTE VU RR, 5. Fr ee . Ty |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6762.jpeg | Moonhold | fa fn te » AT " k ¥ 4 pos. ox ah. 1 sf pt i Ld Cy A wo i it RY; =. a po > ”> z 3 : EY. s " 3 5 ja \| / 2% ad al Se ny dal » Re a BT IER > . »* EN Zp ir - 3 4 Ee. a A 2 a By ™ Ll - : " 3 i cs ve Pa x, , . » ’ hey Mh [3 ry 2 ig > ’ . : pr -— r A | play it. (Do ooth 1] & | Possessed Aven; Proposal; Ormos, Archive Keeper | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6763.jpeg | Leyline Immersion | RK \| < bo \! . at | Tie Marl |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6764.jpeg | Tormod's Crypt | \| 8 AN, ATEN ra ver 0: ~ 4 mmm \| ¥ | ZICVIVIELENN VIOLIN (IVI EFF | Animal Attendant; Shambling Attendants; Krosan Avenger | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6765.jpeg | Tome Shredder | oo” EY » ‘ >, J $ Fa a v TR a | rey BEA EV SoA yy NNT Vr ie OY ~Augusta, Lorehold dear ‘278 £& | Ow | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6767.jpeg | Trigger Happy | NEL r 4 (J RL . % 4 y, ot —— ’“ u / pa \| DL RRS 4 wl 2 TP Ra \| 4 if “ 3 ’ : ” 4 - > ‘NR [ AA : 4 TR — ARDY oo. F <! aN ha i [/ a eS | ou may ao a Lite aan eres /7%44 (1 | Lady Orca; Hardy Outlander; Body Dropper | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6768.jpeg | Den of the Bugbear | IDNR UT CL ADVENTURE FOR CHARACTER LEV : RP] rome WON g i | gm Ne gm Sp a mt i 4 SONSOONIN CYOALIND Toon Lr 1 \| . »" It’ al ' | Adventure Awaits; Adventurous Eater // Have a Bite; Adventurer Beguiler | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6769.jpeg | Grand Master of Flowers | xX Cc : - = Kd . re . ly pe “ 3 1 - 3 > a \| a oS - a " & . . “3 rs , 4 * ¥ Yy ., & Sal" " ’ h Tagg NES \| he : Do a \| v ’ \ a L - - . : N 'y ~ : 8 v vi \| | +] BR d Monk of the Op — POUIL 30 100 VOUT Nani, 11 this way, shuffle. | Tarmogoyf Nest; Staggering Size; Staggershock | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6770.jpeg | Ajani Unrelenting | LW NETH» ARe@lART NTR NAA RS Te Naw. a . j NG Bri, yer SOS SRR PG © < _ ~~ - . rg 19 2 { 4 723" ) \| \| R 2 i > ba dg - Lo : = - 7 »* J \| ir i re : sl , eR. , P ’ v L v - >. nN o - a Sy 4 ; = 3 | 1 Ajani aeals 4 qamage —* CXCCDL TOT TOKENS VO Pv Tey | Nether Horror; Colfenor, the Last Yew; Nether Spirit | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6771.jpeg | Flourishing Grapple | 3 ‘a ro “a 9° 9 kz Ee 7 2 X\ : \ ~/ 1 o> — \ 3 = 4) gr AES “1H RN ~~ . 2 AN Gry Wo = NN hs . vs - ANN CW]. V es SANE 2 Pe | allldgC CuUal LO 1S PI crmanent. | Annex; Annul; Arlinn, the Pack's Hope // Arlinn, the Moon's Fury | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6772.jpeg | Kasla, the Broken Halo | \| rd <7 W) py 4 YB = \| - = #h fe TE Eo i | YY IiINAAVY LL YUM VAROL REV E convoke, scry 2, then dr | Fire Tempest; Raze the Effigy; Hope Tender | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6773.jpeg | Flameskull | [] K of » : 4 J ' L - » i 1 4 . rd i V/ ’ @ y- - (1 ro 4 x ’ . $ Lo t i i ' ~ £Y y 4 / 4 . Nf \ (7 . [ ne 5 “ : - . >» [s - “by A . KE) > y i 5 RY J Ey 3 o ° » . . | EE EE TEE, EEF ad ne TL ET Tap ee cast Flameskull this way, y awther card, and ance versa. EE” ZW 0202 |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6774.jpeg | Merry, Esquire of Rohan | - . aha - ee. B d = i v9, a } EL \| f f h 4 i Ww - ~ > \| : \| \| \| \| J \| 4 i Ne - = " FE a - y ¥ % 5 5 4 gs , hl I. \ B . ow Bu : ; \| \| \| \| i ] Re AW A “ \ he A . ‘ - } of a he 14 ‘ > iL 4 Lo 4 ph p oy : . y a ~ a ; : y rs ot . - J Li 3s h or, N Br 5 "i o EE ; 3 . om SER NE \| oo Ry % 4; \| \| [5 eg, ie 5 2 . - rig RY, > sa 4 | ard. | Atarka Efreet; Mana Echoes; Maha, Its Feathers Night | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6776.jpeg | Shock | \ \a a a \7 A -~ . CR os P 4 rai gl A \ ’ h . / / or vO {rw _ y a - & 4g od . 4 » —— - ERNE TN ” - aN 2) = \. . 4 .* < | -Ral Zarek, research n | Learned Learner; Returned; Wilderness Elemental | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6777.jpeg | Ritual Guardian | 4 v hyo ats if 5 / ’ vo » y g “EE an t / ’ i 0. v o 3 5 % N° pr 4 3 4 Sy al | YY ANClent mages, Vy ill survive this night.” 0 —eeeee ee —— | Ichthyomorphosis | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6778.jpeg | Evolving Wilds | N ADVENTURE FOR CHARACTER LE orgie oR 2 | fac ns BT, Ao, FEARED hs HE Fey wt i ai ei 2 ¢ ’ Bd . AY & a a . Te iA sa Toh + For rh A TPC TT HRI A, wT Lo LR Cy LEAN . g CR A TE A ADE an ay J F 3 \| BEES CARP Sond 7 Ps, 2 a nye hy RE "ah iL 2% <4 re A DBRT GG 3 JT ELLEN $< K pe 3 WF lab aye ¥ 3A h, 1 Sod eR BY > "ne (NE: 1 5 Wy M5 $0 4 MCA Cry Tat Ee A \| 5 Ch ERG RR pe SRL Tae Si g a hs, go Fe Hy VWF AN px Fi + Mig; 2 - 3 row GT 7 A o 1A Tw Ag iy wh p nT ~ v 5 b# * ras ‘5 iw : L 1 En " * a Lap ve jo A SARE \| A a Re RIN Sr Ee CN IR Ty - Va a¥ PLY Tas OF a - ~ vy & Si Re =, ATH % £2" 5 Eu 3 Fey BLT. . Frade , ert ad e hy ra Sg Fy 3 LE PE sed al Fo AE - y Sa TLL od oe E 3 Cw SEE es cole sd ar y Tg dt 15h fe EAL A pd EF Eh Et a 14 $2 hr A Cama "7 5“ J a wy a 3 ; lh wl Yc ; & LR TT Aa RANT REN ob MRR LES0 aed eB 5 > IMEI. BH int hes Lot RE XE CAs RT wid » ” 51 FE oe FT = . gh Lr Thy 3 p Hs MRA Ch 3 fa vr} » 4 v { Ly Yi BNE ER Sse dR oe Latha Sip EVE C1 0, Spt Ls wi £5 Aas x4) A eed Ge SRR SH NEE i, SRR © A . he Lo res Ne 7 Fy ’ 4} wi 4 ‘ ay ¥ ow 5 A. - I ¥ B . a i or i TF In ok ; PAE = ay a hy uf, rx - (be NS. ¥ 4 fe: » * 4 ron Se A REET EE JE se a PEE FR AF 5 bo . ht wi “tS Vf nl SET CW ad by 35 ' - # au - Lh p— : ~ BTR Sa Re . - fic A SV we YE g Pe - ¥ | Adventure Awaits; Adventurous Eater // Have a Bite; Adventurer's Airship | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6780.jpeg | Ghalta and Mavren | 3 Cf ~3, aod A \| A » _ 3 y i - % ~ SY ot 7, \ . . : p; “& | with lifelink, where X is tl attacking crearures. |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6781.jpeg | Mountain | a] | i " \| | X; _____; ______ | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6782.jpeg | Sunblade Samurai | \ N hs & X) Cd 5 : f J RS \ \) \ ry A \| 7 4 4 \| EL a / 4 \ \ ’ o (1s \| hn \| » p " it ” 4 ( 2 N | i a ilk 'y olf ws adi | Rags // Riches; Relic's Roar; Arms Race | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6783.jpeg | Lucky Offering | rf Vaan Yy¢ ~~. = > —. x EL) : « * F 2 A - s . /\ ~ a ) EX ’ ONT AB TI Sn \| Ey NA V4 rs ORD gd 7 { . 2 Pa BB JF "yb -_s . pr { | JOULLIVY Ul TW v LWivrvwuv evo musing trinkets. | Aang; Karplusan Yeti; Sylvan Yeti | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6784.jpeg | Sungold Sentinel | ¥ a ¥ ON ~ y - tu N ’ 8 9 p » a” ’ 9 4 re b aad ~ ol a « - - ve " p & ’ - a R ~ bs as, e - , pr 5 \ 3'7 a ats [8 - - pe “Way | of that color this turn. Act powers. 3 | Nature's Way; Harm's Way; Curator's Ward | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6785.jpeg | Dunland Crebain | \ J : ) ( 4 : \| ~ A PN | Ld | Urza, Planeswalker; Urza, Prince of Kroog; Mana Prism | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6786.jpeg | Great Ugly-Looking Goblin // Clap! Snap! | h I — A : - y - \| & 0 | T11ASS UT “ud, | Bosh, Iron Golem; Death in Heaven; Sautekh Immortal | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6787.jpeg | Terramorphic Expanse | . be rh TA COT SEE - - oF 2 £ § ar = X \| ; ‘a 277 5 oF: F IV: a pr # + «BE ’ ; 1 bY FY . & ap 2 of head 2 Chr i a Y N BN a 3 pve » = « h a % : : g -. A - oo > . 3 i J - 1 -. A Fs : v MN ~ ga - KW ~ » 3 FS A Py RE Mr 3 “yr z, : ¢ . ) ” / ho oe PR Era rs é Kl _ . i . ‘ LT. p Fo A o wd v n » o = » : a ." - # £ 4 ha ATBE wie 04 als i R NE » - Pa » ya > Py hb 2 J sak 3 4 y 2 op ~ . . -4 - * Og i — - | / revive vs SVS AVVEY WV vv wT Tvs morrows, so will thewr ru -Koth | Raise the Alarm; Make a Wish; Tangle Wire | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6788.jpeg | Ascendant Packleader | 4 ZF ’ \| o \| Vv" { ve ' A] Fs /i 7/4 7.5 Ll) AR) / ge wr wy 44 4» : \| J / 2 # a , Ae - : . J i J&A / 4 LJ Lf ‘ | valusn I Vi slilvaivis pve on Ascendant Packleac |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6789.jpeg | Illithid Harvester // Plant Tadpoles | — 44 \ WY 4 SE 9RY 4 A 4 fH Fa 2 4 \ | BEE on ey wm © id : J0Ke HETS 11€X1 fT om EE \| » . & AE Tan 51 KY LD a oy | Fry | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6790.jpeg | Storvald, Frost Giant Jarl | i? pa 4 Bb A Sa ~ Ch ' a | irget creature has base ughness 1/1 until end «¢ | Ori, Plate Stacker; Lutri, Pauper Otter; Wild Pair | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6791.jpeg | Way of the Deathbringer | 3 “1 “rr » or v3 (os CL IASI yoy. ry ns : i XR of B . 7, . Par Ly AF rr Pp od WS oy. . ? oS ey v #5 7, ALLA p77 by £ I ’ PM or “a y's / ITI < he , ) 7, rr i LoS SYA CL ¥ Linas yah ress WRIT os At en OF a ea L 3 i SHIA . . - /8 Ad sor 47 APR 7 ns a i 4 » ( he p yy Ar -» A . - AA A ay ‘e pe 7 4 ’ f eal AY Hp , "i 7 ’ 4 rt oz 4 ) ar 38 4 77 7 7 7 < /4 i oN fol AA 7 4 ’ 4 AY Paley 4 Pere Lous ; J a at \ . oF y ys ry Vp i 65.7 0 ar p i 2 Ye % +H a Me \| o ’ : rr Aw 2 C, vo yb wi A y7 Gai 4 “a L r . er, J ATL rh 0 4A wal Pole’ 4 | atiTe TH or green Beast creature toke: | Liliana's Caress; Olivia's Wrath; Nature's Wrath | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6792.jpeg | Cast Away Doubt | ¥o 2 a OURR ge Y eh SOAR & Goes \| ctheld : JA . ee J : p> Nn NINE «Qt A \ NY > » vs . > 4 A RI J P00 oN X LN + ET) ’ Ww, ( -h 4 . py J LY . Ss \ ot : ’ » = WE EG NSE TREE, GE eh," A Re Sanasty ‘on : Pa SE Sa init d are “77 > BA R20 RR CRIREEN CT. $30 he BRET i Fd % ) RA TA R LR Co Ta LOU RIC ARS 44 XE “3 o gon = Ye dd . L2 SUNN, se Bh, 4 INRA RTI EL vw. A vo - PRR \| 20 (A AE ER an Sa SRL a, dE CS o£ ' vee, REE Naty a 3 AAAI, - 4 ) L ; ¥ ra kd ‘, h Nd b 5 aan oY h3 a he Rp So . RYE: 5 ry v4 AN y . FD BW - " a - r ’ a, ¥ AY, S ' < PNY BYNe”? AN RN. 49 “vt aa 3 Ne Y v % AFZRIE VY Dh 3% PARR eo HL NC 3 7 \ ‘e \| » y : : bo XW ad Vet) va v Ye ol ANd Ve \| A N\ al bh of A ’ \ " EAN) WG STH AX \ > SORES \| “3 « le 21s AN » hy 1 No YC AS Se : 3 MN "a ' No , a A, > N od 5 . . : a Se oS > VOIR Re +4 ; ~ Wi IN , Ro oN SEY: EBRA GR BCAY a Ya L ~ Ye AS oe = J : A ’ Ny C Re AN : pre { $ Ad RO R-A ESE: RETNA NT BR SL | Fev) wit smite AA Jy Vv wv wy NR 3 - Vv Vv Ww heorist was all that ren | Reenact the Crime; Three Tree Scribe; Campus Crier | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6793.jpeg | Coronation of Chaos | pd 4 T Y 2 \| Ne a k a Er Cp é | ‘NEN OAre VOOR § decepLior. heerimg crowd erupted int | S.N.E.A.K. Dispatcher; T.A.P.P.E.R.; Stone of Erech | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6794.jpeg | Devious Cover-Up | ge. | Vidow Weber's new scare y1tract more crows than |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6795.jpeg | Daring Demolition | Es “ SERN, | A _, | Serenity; Protect // Serve; Seraph | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6796.jpeg | Die Young | >) 3 . | Wren rie Linnie Contes, \| sts forever.” |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6797.jpeg | Vengeant Earth | § 4 ; Jo - : n - Ld - - - pe ‘ \| « ~ i > ™N K 4 « | hen Zendikar’s defender: )se up to shake the invad |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6798.jpeg | Vanquish the Weak | < \| pr . \ ’ CRS Heh . ; ® % - % J “ Te _ Ny i a - i” J ev , y " 4 Lind a Wy he | (C71 A rari rig. 4 1it 2A. | Curious Herd; Victory's Herald; Aurochs Herd | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6799.jpeg | +2 Mace | x, Eo AR” Sal ; a Eo Fa Bo a. \|S i 9 &" I « To owe ge I ® > samt IN oe : i & 3 po of 1] MN Ed § S es EE J A v ’ : A - . a b 5 y # \| ’ . : v, h- oe a Os Ry RW - TCT a \ k . Py: "- kn . ~ ~~ A aby or ps pf ¢ a3 ¢ p { , pL —, N he am io a 2 " ar | EE WD CT Aon RAF Wd eavy on the wicked. | Auriok Salvagers; Dakmor Salvage; Dark Salvation | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6800.jpeg | Secrets of the Key | 4 PAY CPs ry — WA TT Ad RNY | § digarda ana Sorin battled covered the key from the M: | Canopy Claws; Dairy Cow; Ivory Cup | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6801.jpeg | Renegade's Getaway | A | You can’t fight what you c | X; _____; ______ | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6802.jpeg | Stuffed Bear | rd 4 N° | CLECLILIAT NLIALT CLVLCL FVLLYIANY. SEUET THE ILS PTTL, Pret | Ward of Bones; Herd Gnarr; Lord Magnus | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6803.jpeg | Thriving Rats | 3 -_ N > id yd - ™ i Ny fF oV PA AS" ig” 4 \| : Sa Q 7 ~~ | Ghirapur, even the lowlie lavish surroundings. |  | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6804.jpeg | Now for Wrath, Now for Ruin! | — Wr NB, ed . TUNES J Le “. ™ . 3 i \| ge ; SI Be L-y . ~ . . \ “ EN. ho ’ \| \| L - 7 { 4 . ; rd SUR 5 EON Vi. A Wa . ‘ - ~ » -.¥ Tt Y a gee JC SE ¥ : dN h. | EE ET RS FY Wy Pw VY WN challenge the Black Ga of Mordor. | Surge to Victory; Broken Visage; Start Your Engines | Misalignment: the card fills the frame, so the name strip is on the art |
| IMG_6805.jpeg | Treason of Isengard | 179 $3 = . : - : 5 : A +4 \| i pe Zs WL fmm RE Sh a a i ~ 2 sh nT. Bb *a 44 oa A hog a vo pF Ji i> SE 9 TR ogi ay . we 4 pL fa J. a - ye = 27 po 4 ' ’ » a 4 x » "oe 1 i it Bl | 0 an Orc. If you dont cc ate a 0/0 black Orc Arn Pr ) | Finest Hour; Warthog; Sunlit Hoplite | Misalignment: the card fills the frame, so the name strip is on the art |

**Desktop replay (AC-5.6):** `desktop-a` reproduced the device's text for all 49 captures, line endings aside.

**Coverage (AC-5.4, AC-5.5):** live, 49 of 49 captured, none skipped, no retakes; photos, 49 of 49.

## 6. Misses (AC-6.4)

The new corpus's misses, live and photo, are in §5.

**Photo replay**, not in the final top 3. Each likely cause comes from viewing both stored strips (`~/card-scanner-corpus/runs/photos/<file>/capture-001-*.png`, not committed). 21 of 26 are misalignment: the photos weren't framed to the guide. The other 5 are 2 unusual frames, 1 catalog gap, 1 matcher miss, and the pre-M15 Plains, a misalignment that was read as noise.

| File | Expected | Name strip | Collector strip | Top 3 | Likely cause |
|---|---|---|---|---|---|
| IMG_6688.jpeg | Mountain | Aa eS Jy Ya 5 i AN FUT BN & Sh  L A OL A [\| > \ : ATR aA) A a1 y “a  x Ke, ATVI ANA A V4 0 RR Ny NPI NEA EN Sart LR ryr" J  ST ob Adie 4 Lich ) AINE NUTSIPATS UE) SH REF Tt PY Ms As 7 2 5 Vor vl vce” i NT  RC rk PEA we DCPS Sa s—y—  vy A Bra (a3 A) has \ P. 9 Aisa Rud ap “ yr v hy -  ae un \| WHEN SRO \| Ae A LE LAR NA FAA VAI AV : : ; )  FE 0) RUSSERT SINT Ly (PET AS AL Ng Ogae o) it LA a re ; 4 ,  3 BR TRE RE Sl So Re ah HL \| . 7 Gl 7  R SEY \| \ 4 B MA o aL 1) 8 3 ut, a : Ci :5' 2 i ps p < pt «5  hd / B® LPR { 2 Ng / RI [A fr Ae i a - a  AR, LN WD OWN @ <I QU Wes AN )  [ Nor LIN ARRAS a ef Ee 5 ON WC 4 ¥ BUATARY ite aha g  RR. PUT SE Ee [1 gt VI WE) COTA 0) he el bh NM i M JA “ bay wer 3  ARR 3 TOA DRL OA YM WL Ne ANE 1 he MAN eds to p  yo MOREA RM 2 AN A) A Lh fy wed J ee Fb Ho SNR (Ri te o ’ 2 ’ >  Rhriinsptdtamatan ARRAN A SRA SOR he Ther  We AY Tv AR Yi AE ANG AINA NARA BARI 1 A ’ ps HE os :  Ls RENNIN SVE dd 20 © ik  v ANT SS TRE NAD © 9 GERI) M0 $a \ BSR IN 4 - :  ’ Sl eT y pigs 10 MJ Tr Re 2, ——  a py OT  ‘ 7 mi 55179 jo 7 ee, RE MPAIIP 2 2 ii eal 4  \| we ae i SH i  . "Rv fh 77 4 457; 7) it is 1a] lr. » ) 17 / id por  ie) j gh 2. vi Ga 71 a ; Li dia / i p  Tr 3 2 tw Aro i (AA gre Hsu! fof of a  J FHS YI 214 - di! 77) Ws 5 IE ied (4 f (BS ire  Aids AT i Hl i a hile 14) Or  Awd PS A AW pt | i hs  hey >  ._ » : CR  : Mel  Ri. ETE  151 wR ES  of SORA  RO", 1 rE Sr  iL EP cy TN 8/8  i ERA Re * o  2 BR Te oe >  ~ A  : J, (ove  B. DEIR  be. Re  ’ BR owt EA  z el hy  M Eg fl ire  a : | Anticipate; Celestine, the Living Saint; Hewed Stone Retainers || Unusual frame: full-art basic with a textured name bar; name visible but read as noise; collector strip on the hand (photo framing) |
| IMG_6690.jpeg | Sally Pride, Lioness Leader | 7  A ; V/ y 727 7 3  i fii, dh mw 7, HH 0% 7 7%, /  RORSIRRNN WW) a  hy ’ / bY Hey 7 7 7 8 nY V/ & iy % 7, 7) 77 / ie 17/5 i A 7 7 7% YT) 7 HH 7% 7 7% 7 % 7 7, / / 7  7 3 7 NING i ak IR IS A ie Ti /  4 y / 0) For Nr IN STA 77 he dr 7 f  \| \| 4  \| I ten i  RY Sal ALANIS TT PIAS CRESTS EA HOI RATA SANA IIIS a" / ps ” wor  - NAAN AA us BARA ASE) We ps - Wadia Ht 1 Ui i 7) ih // 7 Y  f gr A $l Re AIA ff ? Hf ni i j oe A 7d a // J) iH { ’  <r A) Wy WR Gay  LFA) / Yio bo] [7208 4 INATAY J i ii Hi 1] ft) J 7 7 ’ 7  he de Va NA em  ADIN ix 0 Lory, D1 i. 7% le f / if f J WH 4 i i Z 7 7  a Ge i RR i inn i iy y 7 \| 7 / )  A 7 an  Jw Jd 7 AA Hn mi fin I # 7 7 ih > LJ y, ] Ve | K ay La lids 4 2 Che AS  Vv Bs ales TNR  : oH ‘ pi, ies  Jas lo  a . 4 Ey het  v y Tt  - ; Be RS  8 ey Ta Ba  y “ Tr y ' oy  £ os 2 Q ne  3 pry ) BE " BL  . : 4 ag. ¢  { 0. be . BL » as Ey  & Fr. fae 3 &  « 49 da WR :  Se a {5 Ji  Y a - < Th, Tv  [4 A ” Bd a ~ -£. v  N prey * STAMP hres . fA g Sie OH  tf ad 3 ' %  Sut Es ia “a,  B. py NN % .  - ' o oh 4 By © ey Td Wg » thd Ty | Liliana's Caress; Titania's Chosen; Illusionist's Stratagem || Unusual frame: stylised lettering (licensed art); collector strip on the hand (photo framing) |
| IMG_6691.jpeg | Wedding Ring | . Cm ples A PVT TE a 4 of oh Co TAY TREE ’ ye YE el pe  Ys 3 5 By BAL v : > ft ’ 7; ‘so ¥. i A 5S Pe x: [4 a de. ra Ne .  aS. : ad pd PRR SrA fn Ye 1 2 3 \|  ) v F # - opty *  bv Yn, 44 gh SF ig 5 A pepe So 2% rs . . ) Pec  wo” 2 ' . ) pi . - oh 2 2 - } 2  » A woe EN Na PT, RT I Pe ai aii i Soni  \ “« [ :  \ . a”  \ . \|  va 3 ¢ » J  \ b: Q 1g!  Fr Lm  3 \ ii  - - 5  3 “oo OL A — unt os  ; 2 pt, ES & PRL DIYEE RET SRNL FRE op Ee z LE Ap ——— AER PRI SPSS = SHEERS A endian pro.  " vs of 5 he , - o - he )  ¥ = T a ddi Ri ¢ a ~ - > i Cm py: 2  3 4 :  Baia Wedding Ring \| ies \| fo th a  . r LJ bo i —— - ’ | —ah CA, HAMIL LNINE UAE  : J ——— RN a  gs  ot i  iia  3 SF | Joined Researchers // Secret Rendezvous; Peer Pressure; Grim Reaper's Sprint || Catalog gap: prints the flavour name *Mermaid's Pendant*; collector strip off the card (photo framing) |
| IMG_6705.jpeg | Cloudsteel Kirin | ee  - CL e—————— Ee  p- —  ’ -  ”  Vr AAR. a  Fy FO) ny a =) - | » —  p TENS TTgegT pees | Aardvark Sloth; Aarakocra Sneak; Aardwolf's Advantage || Misalignment: name clipped at the strip's bottom edge; collector strip on the rules text |
| IMG_6711.jpeg | Kodama's Reach | gr 5 yah  - - "e e's  2 o  =a -  4 py» 7 a S-  : \| ’ LL ;  — N\  . A r* \| | ¥vy | Yahenni's Expertise; Yahenni, Undying Partisan; Fa'adiyah Seer || Misalignment: name strip on the art; collector line legible (`120 C / NEC • EN`) but read as noise |
| IMG_6716.jpeg | Blessed Ghoul | ” or / Fp We a L ELISA : - ~ —— p—  - — 3 Ao - <n A § FJ  ’ y > f EC.  - % 5" AOS, 3 . wd ; TB : ‘  4 ’; J . r ‘  a \| Lop Y s \| /  BE IEW  & Lil Ps A \V de | mare up tne wore.  012%  2A + EN Ke IGOR GRECHANY) | Belisarius Cawl; Obelisk of Alara; Felisa, Fang of Silverquill || Misalignment: name strip on the art; collector line cut at the left (`0123 / RA • EN`) |
| IMG_6717.jpeg | Campus Crier | i. - - TE 3 ~ Fim fr  PF ee ag WE 4 ig Vo AW hy “gi i  "4 * v&f NY 7 Jey ™ - \ Re BR a ~~ Rig  ~ : y TG Site SECs g ‘. ' Ca 5 TN v £4  : bs . ore i] gr gr WM  7 pak N(R TT 1  AN Te AR aE \| N= \| Vs \‘, oF IS  — % : A \| \ oH N y pe \| 4, « P .  Ba % en gs \ 4 \|\$ por I  AL w Tal 2 a & bh Sad Hee ' fp ty  v : : aN h Z / 4 4% i \  PENG © = 7 \| AE \| \|  APN ald J PO ho ; | D004  A +» EN 5% JOUAN GRENIER ™ & | Might Makes Right; Gavel of the Righteous; The Mana Rig || Misalignment: name strip on the art; collector line cut at the left |
| IMG_6718.jpeg | Leyline Immersion | Bo ; Sa  ‘~ :  \| “« -  “y b \| ’ bs a 4 -  \| oy = . \ 1 | AlLN v 4 Ad AN £K  ¢  msie ay  —— Fe | Lay Bare; Toy Boat; My Deck is About a Seven || Misalignment: name strip on the art; collector strip on the copyright line |
| IMG_6720.jpeg | Fanged Flames | Lp cog Sw pan soon pa B= SR be prea ZN oo Ld  Fanged Flames 1  ~  _______ \3 | ETRE ==  C 0118 NM §  MHZ « EN ¥% CAMPBELL WHITE | Monsoon; Harpoon Sniper; Horned Loch-Whale // Lagoon Breach || Matcher miss: name read (`… Fanged Flames 1`) but a longer noise line won query cleaning; `MH3` read as `MHZ` |
| IMG_6721.jpeg | Hammer of Purphoros |  | f Ad A VV VI VN VV UT Vvew Vy A Saad Ea  4 J nla 25 ANE x THERE LL  ek NEONE-TIA0 Nan  Th PT fo NNT FC  VORTAC & 0201 3 Wizards of the £oase 124/249  h_4 ab. 0 - a samp } Aw ll 7 Dad |  || Misalignment: name clipped at the strip's top; collector strip on the artist and copyright lines |
| IMG_6722.jpeg | Shared Animosity | - \| !  4 Fr > ( i  EY Al  \| wy Ea A y: 4 | long-ago aispute over «¢ spur  Assault on Delverhaugh  . fon    mS "AN A0 < py | C.A.M.P.; Spy Eye; V.A.T.S. || Misalignment: name strip on the art; collector line cut at the bottom |
| IMG_6726.jpeg | Desert Were-Worm | 7 \| PDOCSCIL YYCIC~YWOILIL  # : ON) RY . \| > EN | " | Acidic Soil; Oil-Gorger Troll; Toil // Trouble || Misalignment: name clipped at the top; collector strip on the hand |
| IMG_6727.jpeg | Desert Were-Worm | - dd hs” vv  - - AE ) he  -s o is - »    = g ; a : (3    - i et    PJ eX - aN i ” PP, 4  y 3    : maa SO ge Sn | i, . 25% hh ® i \| \| oy  aaaitonal comoat \|  sees. Tw |  || Misalignment: name clipped at the top; collector line cut at the bottom |
| IMG_6729.jpeg | Herd Heirloom | -s9Y  =. XN | Tak Liilavv a vail.  R 0144  TOM +» EN % ALLEN MORRIS | Thawing Glaciers || Misalignment: name strip on the art; collector misread (`TDM` as `TOM`) |
| IMG_6732.jpeg | Balefire Dragon | ; k, g -~ . 4  by i, El  -— og |  | Bury in Books; By Force; Guy in the Chair || Misalignment: name strip on the art; collector strip on the hand |
| IMG_6733.jpeg | Primevals' Glorious Rebirth | “4 / | 1 to rule the hung.  165 R  OMC » EN » YIGIT KOROGLU |  || Misalignment: name strip on the art; collector misread (`DMC` as `OMC`) |
| IMG_6734.jpeg | Elixir of Immortality | messy 9  ¢ N :  AR    5 Avi A | re EE  JEST oltan Boros & Gabor Sziksz  ETNC& #201 3 Wizard of the Coast Avr | Missy; Mesa Lynx; Messenger Hawk || Misalignment: name strip on the art; collector strip on the artist and copyright lines (pre-M15) |
| IMG_6735.jpeg | Fracture | NT | Jssi Foil Bay cuales. RL GB acd SE “3  188/275 U  CTA EN we MIBANDA MLEKS . |  || Misalignment: name strip on the art; collector line cut at the left (`188/275 U / STX`) |
| IMG_6737.jpeg | Leyline of the Guildpact | 4 Be, § 3 x = i  AE | RB 02%7  said EN Fr DAARKEN |  || Misalignment: name clipped at the top; collector misread (`R 0217` as `RB 02%7`) |
| IMG_6738.jpeg | Darksteel Citadel | -~N »  har  " . g  v . ~ ~ af  am——T— »    we ~ | n JE LLT LCT MOI WEWEFE TVRAT WEA  ec ——  292R/249 C | Akoum Warrior // Akoum Teeth; Jalum Tome; Dream Strix || Misalignment: name strip on the art; collector line cut at the bottom |
| IMG_6739.jpeg | Plains | gsams = «000 EEE  : OND 5 Alt Co te 4 5 me 0 0 ME  "  . )  ve | ad . — -r -™    ==> Adam Paquette J. UA    Ba 0 1003-2011 Wizards of the Coast LLG 250.  ’ | Sram's Expertise; Sam's Desperate Rescue; Samite Elder || Misalignment: name at the strip's top edge, read as noise; pre-M15 collector line has no set code |
| IMG_6740.jpeg | Stormcarved Coast |  | -—r Vv LE —_——— — S—— TN re  ————————T SEEN  a aan A =n |  || Misalignment: name clipped; collector line cut at the bottom |
| IMG_6741.jpeg | Kodama's Reach | > .  “ Ea cB oo | "Heather Hudson Oe  =P, ie 40. 200 3 Wigrds of the Couse (917229 \| | Sea of Clouds; Plea for Power; Sea God's Scorn || Misalignment: name strip on the art; collector strip on the artist and copyright lines (pre-M15) |
| IMG_6742.jpeg | Abundant Harvest | 4  _—  yo- pL -— N\ | EE SAR pare Wee mT TT  library in a random or |  || Misalignment: name strip on the art; collector strip on the rules text |
| IMG_6744.jpeg | Gluttonous Hellkite | ger. EE PE = Lg: - ol ph -  — — -  23 \| \|  kh =~ Asan :  ar,  _  x F > . L apm— ra a | ? 00753 ;  wre *EN Wee losin "107 CAMERON  —— | Geyser Leaper; Tiger Claws; Tiger-Dillo || Misalignment: name strip on the art; collector misread (`M3C` as `wre`) |
| IMG_6745.jpeg | Kazandu Refuge | :  y - | din \| a, Ly  weir Franz Vohwinkel Rw  ™& 0 201) Wizards of the Coast 71/8) £ | X; _____; ______ || Misalignment: name clipped at the top; collector strip on the artist and copyright lines (pre-M15) |

**Tuning round 4 (live)**, not in the final top 3:

| File | Expected | Name strip | Collector strip | Top 3 | Likely cause |
|---|---|---|---|---|---|
| T001 | Exploration | Exploration PE  CC EEEEEEEERRAY Lv | AL WANY BFE 34588 Sa  \| C1O0 8 199% Wigands of the 4 | Terra, Magical Adept // Esper Terra; Ogre Errant; Serra Redeemer || Matcher miss: name read (`Exploration PE CC EEEEEEEERRAY Lv`), but the noise token stayed in the cleaned query and pulled in other names; pre-M15 collector line has no set code |
| T011 | Way of the Mentor | el Tae. | > \| I  — NEY SCHWARTT | Give // Take; Taeko, the Patient Avalanche; Touch of Vitae || OCR miss on clean strips: a sharp, well-framed name read as `el Tae.`; the faint foil collector line (`U 0208 / FRA★EN`) read as noise |

## 7. Timings and downloads (AC-6.5, NFR Performance)

| Measure | Value | n | Phase 0 reference |
|---|---|---|---|
| On-device recognition of both strips, per capture (iPhone, all tuning rounds) | median ≈185 ms (185–186, n even), slowest 539 ms | 44 | median 626 ms, slowest 1,911 ms (n=11) |
| — per round (upper median / slowest) | 131/179, 167/271, 221/271, 288/539 ms | 10, 10, 12, 12 | |
| On-device recognition, per capture (iPhone, new corpus live run, §5) | median 168 ms, slowest 322 ms | 49 | median 626 ms, slowest 1,911 ms (n=11) |
| App-side candidate lookup (desktop, new corpus live run; machine timing) | median 64.9 ms, p95 90.0 ms | 49 | name query p95 114 ms (n=50) |
| App-side candidate lookup (desktop, new corpus photos; machine timing) | median 37.1 ms, p95 59.6 ms | 49 | |
| App-side candidate lookup (desktop, photo replay; machine timing, varies by about ±2 ms between runs) | median 44.4 ms, p95 70.1 ms | 50 | name query p95 114 ms (n=50) |
| Cold load of `/scanner` after sign-in | 7,050,153 bytes, 6 requests (engine 7,026,613 bytes in 4: library, worker, `core/tesseract-core-simd-lstm.wasm.js`, `lang/eng.traineddata.gz`) | 1 | 7,031,507 bytes |
| Cold session including the sign-in page and app assets | 7,353,346 bytes, 37 requests | 1 | |
| Warm reload of `/scanner` | 11,770 bytes, 1 request (the page; no engine file requested, not even revalidated) | 1 | about 1 KB |

The recognition time per round rises as the strips grew (2× drawing, taller strips, row inversion). It is still well under Phase 0's. The desktop photo replay's recognition times (median 1,057 ms on 3024×4032 photos) are a desktop measure and aren't comparable.

## 8. Device checks (AC-6.5)

All on the iPhone in Brave, during Phase 10:

| Check | Result |
|---|---|
| Rear camera opens (AC-1.1) | ✓ |
| Camera indicator goes off after leaving the page (AC-1.4) | ✓ |
| Torch toggles the light (AC-1.5) | ✓ |
| A portrait photo picked with **Use a photo** is read upright (AC-4.2) | ✓ |
| Over plain HTTP: no camera request, Capture disabled, **Use a photo** offered (AC-1.6) | ✓ |

## 9. Replays (AC-5.6)

- **Tuning round 4,** replayed twice on the desktop at the frozen settings (`desktop-a`, `desktop-b`): 0 of 12 captures differ from the device's text in either strip, and the two replays are identical. Byte for byte, all 12 differ only in line endings: multipart form posts turn the device's `\n` into `\r\n`.
- **Round 2,** replayed at its own settings: 0 of 10 differ.
- **New corpus live run,** replayed once on the desktop (`desktop-a`): 0 of 49 differ from the device's text, line endings aside.

The OCR is deterministic across the iPhone (WebKit) and desktop Firefox, which is what made the desktop tuning experiments in §4 trustworthy.

## 10. Coverage (AC-5.4, AC-5.5)

| Run | Captured | Skipped | Retakes |
|---|---|---|---|
| Tuning rounds 1–2 | 10 of 10 (T011–T012 added later) | none | 0 |
| Tuning round 3 | 12 of 12 | none | 0 |
| Tuning round 4 | 12 of 12 | none | 1 (not counted) |
| Photo replay | 50 of 50 | none | 0 |
| New corpus, live | 49 of 49 | none | 0 |
| New corpus, photos | 49 of 49 | none | 0 |

## 11. Findings for the next spec

- **A misread collector line can outrank the right name.** In tuning round 3, T003's `178/184 C` lost its `178/` and parsed as AER 184. That is a real, different printing, so as the collector-line match it was ranked first (AC-3.2), ahead of the correct name candidate. The new corpus showed it 3 times in 49 (§5): a digit dropped or misread gave a real printing of another card, and the right card came second. The confirm step should make the disagreement between the two visible, or rank the collector match below a strong name match. That needs a spec change.
- **Faint collector lines,** especially on foils, are the weakest strip: grey on black, at about 15 px in the frame. On the new corpus, the exact printing was found for 4 of 10 foils against 30 of 34 non-foils.
- **Light names on dark name bars** can fail even when sharp and well framed (IMG_6785, §5). Only the collector strip's dark rows are inverted before OCR.
- **Long names can run past the name strip's right edge** (IMG_6761, §5).
- **Query cleaning picks the longest mostly-alphabetic line.** A long noise line can beat the real name (photo replay, IMG_6720).
- **Framing matters more than anything else measured.** Live alignment with the guide put names in the strip. Unguided photos didn't, whether the card filled too little of the frame (Phase 0's photos, 23/50 first) or too much (the new corpus's photos, 2/49 in the top 3). Card detection (Phase 2 in the roadmap) would address the photo path and hand-held drift.
- **Flavour names** (IMG_6691) still need a catalog field.

## 12. Fixtures (AC-6.6)

Text only, format_version 2, keyed by manifest `file`, beside spec 005's fixtures in `spec/fixtures/card_scanner/`:

- `phase1_photos_ocr_results.json` and `phase1_photos_name_matches.json`: the photo replay (50).
- `phase1_tuning4_ocr_results.json` and `phase1_tuning4_name_matches.json`: tuning round 4's live iPhone captures (12). The `T0nn` files are keyed by the tuning manifest, not the corpus.
- `phase1_live_ocr_results.json` and `phase1_live_name_matches.json`: the new corpus's live iPhone captures (49), keyed by the new corpus's manifest (`~/card-scanner-corpus/phase1-live/`).
- `phase1_live_photos_ocr_results.json` and `phase1_live_photos_name_matches.json`: the new corpus's photos through the photo picker (49).

`*_ocr_results.json` carries spec 005's fields (`file`, `name_text`, `collector_text`, `parsed`, `lookup`) plus `ms`, `user_agent` and `captured_at`. `*_name_matches.json` carries `file`, `query`, `lookup_ms`, `name_candidates` (name-only ranking) and `final_candidates` (the page's ranking). No image, crop or photo is committed. The strips stay in `~/card-scanner-corpus/runs/`.

## 13. Options for the maintainer (AC-6.7)

No pass threshold is set. The next spec waits for your ruling. You ruled on 2026-10-02 to re-measure live first; that re-measure is §5, so the options are now these.

- **Build the confirm flow on live capture.**
  - *For:* on 49 cards that played no part in tuning, live capture put the right card first for 42 and in the top 3 for 45, and identified the exact printing for 34 of 44 set-line cards, at a median of 0.17 s of recognition. A confirm step catches the remainder.
  - *Against:* the final ranking puts any collector-line match first, and in 3 of 49 a misread number made that match the wrong card. The confirm step must show the disagreement between name and collector line, or rank differently (a spec change to AC-3.2). Foils are weak: the exact printing was found for 4 of 10. The photo picker isn't usable as it stands.
- **Bring card detection forward (Phase 2).**
  - *For:* the photo path fails whenever framing doesn't match the guide, in either direction: in the top 3 for 24/50 of Phase 0's photos and 2/49 of the new ones. 3 of the 4 live misses were framing (a name cut at the strip's top or right edge). Detection would make the photo picker and careless live framing robust.
  - *Against:* live capture already reaches 45/49 in the top 3. Most of the remaining live errors are collector-line misreads, which detection doesn't fix. It costs a larger download (OpenCV.js, about 8 MB per the roadmap, not measured) and more work before any benefit to collectors.
- **Stop.**
  - *For / against:* the evidence doesn't point this way. Even so, the name index, the parser and the printing lookup would still serve a typed quick-add.
