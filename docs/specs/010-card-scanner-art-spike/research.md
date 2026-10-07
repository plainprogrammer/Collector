# Feature 010: Card Scanner Art Spike — Findings

**Spec:** [spec.md](spec.md) (v1.1.2) | **Plan:** [plan.md](plan.md)
**Measured:** 2026-10-05 (index rebuild; the iPhone timing session 23:05 UTC) and 2026-10-07 00:05–00:14 UTC (the live captures, the evening of 2026-10-06 local time) | **Branch:** `010-card-scanner-art-spike` | **Fingerprint settings:** frozen at `39cdc6e` (index metadata commit `5ce0238`)

Every figure carries its sample size. Desktop and phone figures are labelled as such. Every rate is against the full index (50,924 artworks); no subset index was used. This spike sets no pass threshold: the figures are for the maintainer's ruling on spec 011 and on ADRs 0006 and 0007.

---

## 1. Environment

- **Catalog:** bulk file `default-cards-20261003210542` (106,698 English paper printings), named with `CARD_SCANNER_BULK_FILE`. The catalog wasn't refreshed during the spike.
- **Settings commit:** `5ce0238589f61d40541f2addc8610d921fe77453`. Against the frozen `39cdc6e` it only adds the descriptive `art_index` key to `settings.json`; every fingerprint value is identical (FR-1). Nothing was tuned on the 35 cards (FR-4).
- **Index:** label `full`, 50,924 artworks, built 2026-10-05 22:19 UTC (§2).
- **Desktop:** the development machine (Linux). Browser replays and the desktop reference in headless Firefox 156 (`Mozilla/5.0 (X11; Linux x86_64; rv:156.0) Gecko/20100101 Firefox/156.0`); index build and scoring in Ruby (ImageMagick 7.1.2-31 decodes, pure Ruby fingerprints).
- **Phone:** the maintainer's iPhone, iOS 26.6.1, Brave (WebKit): `Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.6.1 Mobile/15E148 Safari/604.1 Brave`. The user agent's "iPhone OS 18_7" is the value iOS freezes; the `Version/26.6.1` token is the release. Every download was over the LAN, from the dev machine over HTTPS (spec 007's certificate).
- **Spec 008's tools** gained three settings and nothing else (FR-1): `CARD_SCANNER_WORK_DIR` (here `~/card-scanner-corpus/art-cache`), `CARD_SCANNER_TRUTH_CORPORA` (`sitting`) and `CARD_SCANNER_BULK_FILE`. The diff touches `card_scanner_phase2.rb` (the working folder and `truth_corpora`), `bulk_artworks.rb` (the named bulk file), the three scripts' corpus lists (`fetch_art.rb`, `build_index.rb`, `agreement.rb`, one line each) and `search.js`, whose parsing moved unchanged into an exported `parseIndex` (plus a `DataView` offset so it can parse a slice). The fingerprint, resampling and index writer are untouched.
- **Fixtures (AC-5.4):** `spec/fixtures/card_scanner/phase3_fetch_estimate.json`, `phase3_index_build.json`, `phase3_phone_timings.json` and `phase3_art_results.json` (keyed by manifest `file`; no image, frame, index or cached artwork).

## 2. The index rebuild (AC-1.1–AC-1.6)

**Artworks (AC-1.1).** The bulk file lists 50,960 distinct front-face artworks across 106,698 printings; 105,935 printings carry an artwork id and 763 don't.

**Estimate (AC-1.2),** committed before anything beyond the 35 cards' artworks was fetched, from spec 008's measured cost per image (707,955,694 bytes and 9,448.8 s for 50,923 images, [research.md](../008-card-scanner-phase-2-spike/research.md) §7: 13,902.5 bytes and 0.1856 s per image):

| Estimate | Value |
|---|---|
| Artworks with a small image URL | 50,924 |
| Already cached (the 35 cards' artworks) | 34 |
| To fetch | 50,890 |
| Bytes | 707,496,912 |
| Time at the throttled rate | 2.623 h |

**Ruling:** the maintainer approved the full fetch on 2026-10-05.

**Fetch (AC-1.3, AC-1.4),** `small` images, cached in `~/card-scanner-corpus/art-cache/`, at least 100 ms between requests, resumable:

| Run | Images fetched | Bytes | Seconds | Skipped (cached) |
|---|---|---|---|---|
| Corpus (the 35 cards) | 34 | 464,157 | 6.6 | 0 |
| Full, part 1 | 30,000 | 415,493,478 | 5,613.9 | 19 |
| Full, part 2 | 20,890 | 292,013,221 | 3,847.0 | 30,034 |
| **Total** | **50,924** | **707,970,856** | **9,467.4** | |

36 artworks have no small image URL in the bulk file, so they were never fetched and are left out of the index; no fetch failed after its retries. One of the 36 is IMG_6812's: Extus, Oriq Overlord (STX 149) has artwork `d4a80d40-02ec-4d4e-bbe5-2fb58bbb4a88`, whose representative printing (the first in bulk-file order, spec 008's rule) is named "Extus, Oriq Overlord // Extus, Oriq Overlord" and has no image: by all appearances an art-series printing. The artwork has five printings in the bulk file.

**Build (AC-1.5):**

| The full index | Value |
|---|---|
| Records | 50,924 (144 bytes each: a 16-byte artwork id and a 128-byte fingerprint) |
| Size | 7,333,056 bytes stored, 6,008,050 bytes gzip |
| Fingerprinting | 2,901.1 s for 50,924 images (desktop) |
| Metadata | bulk `default-cards-20261003210542`, settings commit `5ce0238`, built 2026-10-05T22:19:03Z |

Against spec 008's index (50,923 artworks, 7,332,912 bytes stored, 6,007,929 gzip, 9,448.8 s fetch) this is one artwork more and almost the same cost. Fingerprinting took 2,901.1 s against spec 008's 1,066.6 s on the same machine and code; the cause wasn't investigated.

**Agreement (AC-1.6):** the build's fingerprints and the browser's, on n=134 cached `small` images (34 of the 35 cards' artworks, all that have an image, plus 100 others sampled with seed 20261003): median 0 bits, largest 0 bits. The index was used.

## 3. The index on the iPhone (AC-2.1–AC-2.7)

The spike's timing page (served by `CardScannerPhase3::Server` on the LAN, policy `connect-src 'self'`, no inline script, no third-party host) loaded the full index once with an empty cache and once with it cached. Searches used spec 008's 43 held-out query fingerprints; fingerprinting used 12 of the 43 straightened held-out cards.

| Load | Encoded bytes | Decoded bytes | Download | Ready | Search median / slowest (n=43) | Fingerprint median / slowest (n=12) | Fingerprint largest difference | Longest gap, 100 searches |
|---|---|---|---|---|---|---|---|---|
| Phone, cold | 6,008,050 | 7,333,056 | 244 ms | 79 ms | 19 / 29 ms | 14.5 / 29 ms | 0 bits | 36 ms |
| Phone, warm | 0 (browser cache) | 7,333,056 | 11 ms | 59 ms | 18 / 21 ms | 14.5 / 19 ms | 0 bits | 25 ms |
| Desktop reference, cold | 6,008,050 | 7,333,056 | 51 ms | 77 ms | 71 / 110 ms | 54 / 70 ms | 0 bits | 101 ms |

- **Download (AC-2.1):** served with `Content-Encoding: gzip`; the encoded body (6,008,050 bytes) equals the server's file size (`Content-Length` 6,008,050). The warm load's encoded size of 0 means the index came from the browser's cache. "Ready" (AC-2.2) runs from the end of the download to the index held in the search's arrays (`parseIndex`); the browser did the decompression.
- **Search (AC-2.3):** the iPhone searched the full index about 3.7 times faster than headless Firefox on the desktop (median 19 ms against 71 ms). Its first artwork matched the desktop's for 43 of 43 queries; no top differed.
- **Fingerprint (AC-2.4):** the iPhone's fingerprints of the 12 straightened cards equal the committed `art_full.hashes` on all six offsets (largest difference 0 bits). Median 14.5 ms against 54 ms on the desktop.
- **Memory (AC-2.5):** WebKit gives no heap figure, so this is what the page holds: the decoded index 7,333,056 bytes, the fingerprint words 6,518,272 bytes (50,924 × 128), and 50,924 artwork ids as strings in at most 3,666,528 bytes; about 17.5 MB in all. Through 100 consecutive searches the page stayed responsive on both loads: no reload, no crash, longest gap between progress updates 36 ms (cold) and 25 ms (warm), against the 1 s limit.
- **Slower links (AC-2.6, arithmetic from 6,008,050 bytes, not measured):** 1.0 s at 50 Mbit/s, 4.8 s at 10 Mbit/s, 24.0 s at 2 Mbit/s.
- **Policy:** no CSP report was recorded on either load.

## 4. The live session (AC-3.5)

The maintainer captured spec 009's 35 cards live on the iPhone once each, in development measurement mode with frame keeping on (`COLLECTOR_SCANNER_KEEP_FRAMES=1`), 2026-10-07 00:05–00:14 UTC, into `~/card-scanner-corpus/runs/spec010/sitting/`. Captures only: nothing was added, so the signed-in account plays no part.

| Live session | Value |
|---|---|
| Captures stored | 35/35 (one per card); skipped rows 0 |
| Retakes | 0 |
| Frames stored | 35, PNG, all 1080×1920 (portrait), 99,624,815 bytes in all (about 2.8 MB each; limit 32 MB) |
| Outline | `live` for all 35 |
| Guide rect | the same on all 35: about 819 × 1144 at (131, 388) in frame pixels; cropped as 820 × 1144 at (130, 388) after rounding outward |
| Recognition on the phone | median 155 ms, slowest 413 ms (n=35) |
| Device and browser | the iPhone and Brave of §1 |

The guide, and so a framed card, spans 0.596 of the frame's height. This matters for detection (§5).

## 5. Art on the three paths (AC-4.1–AC-4.5, AC-4.7)

All three paths ran on the desktop in headless Firefox with spec 008's `fingerprint.js` and `search.js` and, for the detected and photo paths, the app's shipped detector (ADR 0005, including spec 009's outline completion and `8a6c712`'s flat-pixel fix). Search on the desktop replay: median 75 ms (guide, n=35), 75 ms (detected, n=25), 74 ms (photo, n=34).

- **Live, guide box:** the guide rect cropped from the stored frame at native resolution, taken as the card (AC-4.1).
- **Live, detected:** the shipped detector on the whole stored frame, then straightened (AC-4.2).
- **Unguided photo, detected:** spec 009's 35 unguided photos through the shipped detector (AC-4.3).

**Rates (AC-4.4),** 35 cards (8 foils, 27 non-foils). For IMG_6808 (Plains), "right card first by art" is nearly automatic: every Plains artwork names Plains, so any Plains first counts. No card was left out for want of an artwork id.

| Path | Group | Right artwork first | Right card first by art | Right artwork in top 3 |
|---|---|---|---|---|
| Live, guide box | all | 33/35 (94.3%) | 33/35 (94.3%) | 33/35 (94.3%) |
| | foil | 8/8 | 8/8 | 8/8 |
| | non-foil | 25/27 | 25/27 | 25/27 |
| Live, detected | all | 5/35 (14.3%) | 5/35 (14.3%) | 5/35 (14.3%) |
| | foil | 1/8 | 1/8 | 1/8 |
| | non-foil | 4/27 | 4/27 | 4/27 |
| Unguided photo, detected | all | 20/35 (57.1%) | 20/35 (57.1%) | 22/35 (62.9%) |
| | foil | 7/8 | 7/8 | 7/8 |
| | non-foil | 13/27 | 13/27 | 15/27 |

On every path, whenever the right card came first by art its own artwork came first too: no other printing's artwork of the same card outranked it.

**Against spec 009's text (AC-4.5).** Spec 009's committed text results for the same cards (`phase2_sitting_*`): the right card in the text top 3 for 31/35, and the exact printing missed for 14/35 (IMG_6806, 6807, 6808, 6813, 6814, 6818, 6819, 6820, 6821, 6823, 6829, 6830, 6831, 6836).

| Path | Text top 3 alone | Text top 3 or right card first by art | Printings the text missed | Of which art names the printing |
|---|---|---|---|---|
| Live, guide box | 31/35 (88.6%) | **35/35 (100.0%)** | 14 | 4 (IMG_6813, 6819, 6820, 6823) |
| Live, detected | 31/35 (88.6%) | 31/35 (88.6%) | 14 | 1 (IMG_6820) |
| Unguided photo, detected | 31/35 (88.6%) | 34/35 (97.1%) | 14 | 3 (IMG_6813, 6819, 6823) |

Art names the printing only when the right artwork is first and belongs to exactly one printing. Of the 14 missed printings, only those four cards' artworks are unique to their printing; the other ten share their artwork with reprints (or, for the basic lands, are one of many), so art confirms the card but can't choose the printing.

**Secondary: the text read in the same new capture** (rescored with the shipped matcher at spec 009's frozen settings, n=35). Text top 3 31/35 on every path; text or art 35/35 (guide), 31/35 (detected), 34/35 (photo). This time the collector line itself read the exact printing for five of spec 009's misses (IMG_6813, 6818, 6819, 6820, 6823), including all four whose artwork is unique, and missed two it had read before (IMG_6815, 6824). So the text missed 11 printings (IMG_6806, 6807, 6808, 6814, 6815, 6821, 6824, 6829, 6830, 6831, 6836), and art names none of them: every one has an artwork shared with another printing. Collector-line reads vary between captures of the same card; on these 35 cards, art's printing evidence and a good collector-line read covered the same cards.

**Distances (AC-4.7),** in bits of 1,024; medians are conventional:

| Path | Right artwork, median | Nearest wrong artwork, median |
|---|---|---|
| Live, guide box | 189 (n=34) | 341 (n=35) |
| Live, detected | 433.5 (n=24) | 357 (n=25) |
| Unguided photo, detected | 340 (n=33) | 350.5 (n=34) |

The right artwork's distance is missing for IMG_6812 on every path (no image in the index) and, on the detected paths, for the frames and photo with no outline.

### Misses and their likely causes

Causes were judged by viewing each frame (with the guide rect) and each photo (with the detected outline drawn on it).

**Live, guide box (2 of 35):**

| File | Card | Right / nearest wrong | Likely cause |
|---|---|---|---|
| IMG_6806 | Raven Familiar (PLST C13-55, old frame) | 337 / 323 | Framing: the card was held larger than the guide and off to the right (its right edge about 50 px outside the guide, its top about 20 px above), so the crop cuts the card's right border and shifts the art box. The artwork is also dark and low in contrast. |
| IMG_6812 | Extus, Oriq Overlord (STX 149) | — / 320 | Missing image: the artwork isn't in the index (§2). |

**Live, detected (30 of 35): structural.** On this phone's frames the card spans 0.596 of the frame height (§4), but the shipped detector, tuned on photos where the card fills the picture, requires its two horizontal edges to be at least `minSeparation` 0.65 of the height apart. It can't select both of the card's horizontal edges, so:
- 10 frames gave no outline: IMG_6808, 6815, 6816, 6817, 6818, 6821, 6822, 6823, 6827, 6840.
- 19 found an outline that pairs one card edge with another line in the frame (corners above the card, from y ≈ 15 to ≈ 330, or below it, y ≈ 1,700–1,955, where the card spans about y 365–1,545). The straightened "card" is then the wrong region and the right artwork is far (median 433.5 bits): IMG_6806, 6807, 6809, 6810, 6813, 6819, 6824, 6825, 6826, 6828, 6829, 6830, 6831, 6833, 6834, 6836, 6837, 6838, 6839.
- IMG_6812: missing image, as above.

The 5 right first (IMG_6811, 6814, 6820, 6832, 6835) came from outlines that happened to land near the card's edges. The detector was not tuned for live frames here (FR-4).

**Unguided photo, detected (15 of 35):**

| File | Card | Right / nearest wrong | Likely cause |
|---|---|---|---|
| IMG_6807 | Treacherous Werewolf (PLST JUD-76, old frame) | 391 / 366 | Framing: the outline stops at the text box, above the card's bottom edge, so the art box is placed too low on the card. |
| IMG_6808 | Plains (M10 233) | 438 / 322 | Framing: the outline starts above the card and stops short of its bottom, shifting the art box; warm, dim light. (The guide path got this card at 175.) |
| IMG_6812 | Extus, Oriq Overlord (STX 149) | — / 319 | Missing image. |
| IMG_6816 | Invasion of Kylem (MOM 235, battle) | 533 / 362 | Framing: the outline covers only the left part of the sideways battle card. |
| IMG_6818 | Orim's Chant (MH3 265) | 396 / 350 | Framing: the outline stops a little short of the card's bottom; a pale, low-contrast artwork. |
| IMG_6820 | Demon's Due (SNC 75, foil) | 436 / 385 | Framing and foil: the outline starts at the art's top edge, cutting off the name bar, and the foil sheen is strong. |
| IMG_6822 | Young Blue Dragon (CLB 106) | 383 / 323 | Framing: the outline extends well above the card's top edge. |
| IMG_6824 | Moss Diamond (CMR 327) | 424 / 343 | Framing: the outline extends above the card's top edge. |
| IMG_6826 | Éowyn, Lady of Rohan (LTR) | — / — | No outline: the card's dark border against the dark background and the fingers. |
| IMG_6827 | Imperial Subduer (NEO 310) | 464 / 359 | Framing: the outline starts at the art's top edge, cutting off the name bar. |
| IMG_6831 | Lightning Bolt (A25 141) | 492 / 377 | Framing: the outline extends well above the card's top edge. |
| IMG_6833 | Dueling Coach (STX 15) | 443 / 364 | Framing: the outline extends above the card's top edge. |
| IMG_6835 | Green Dragon (AFR 295) | 340 / 316 | Framing: the outline extends above the card's top edge; the right artwork is third. |
| IMG_6838 | Trickster's Talisman (AFR 79) | 360 / 343 | Framing: the outline is slightly loose at the top; a narrow margin. |
| IMG_6840 | Bolg's Company (HOB 149) | 361 / 348 | Framing: the outline stops short of the card's bottom edge (at the power box); a narrow margin, the right artwork third. Not a foil, though the gold frame shines. |

No photo miss was a shared artwork: where the right artwork wasn't first, no other printing of the same card was first either. Most photo misses are the detector's outline extending above the card or stopping short of it (spec 008 §4 saw the same on the new corpus), which moves the art box.

## 6. Spec 009's misses and corrections (AC-4.6)

The five cards whose printing spec 009's text got wrong or that needed a correction ([research.md](../009-card-scanner-confirm-flow/research.md) §11). Distances in bits: right artwork / nearest wrong.

| File | Card | Live, guide box | Live, detected | Unguided photo | Artwork unique to the printing |
|---|---|---|---|---|---|
| IMG_6808 | Plains (M10 233) | artwork first, 175 / 347 | no outline | miss, 438 / 322 | no |
| IMG_6829 | Mana Geyser (CNS 147) | artwork first, 164 / 368 | miss, 440 / 376 | artwork first, 228 / 367 | no |
| IMG_6821 | Pegasus Guardian (CLB 36, foil) | artwork first, 350 / 363 | no outline | artwork first, 380 / 382 | no |
| IMG_6814 | Obsidian Fireheart (ZEN 140) | artwork first, 215 / 353 | artwork first, 325 / 349 | artwork first, 300 / 332 | no |
| IMG_6823 | Past in Flames (WHO 565, foil) | artwork first, 180 / 361 | no outline | artwork first, 279 / 361 | yes |

- The guide path put the right artwork first for all five.
- Only Past in Flames (WHO 565) has an artwork unique to its printing, so art alone would have named the printing that spec 009 needed Other printings for.
- For Plains (M10), Mana Geyser (CNS), Pegasus Guardian (CLB) and Obsidian Fireheart (ZEN) the artwork is shared with reprints, so art confirms the card but not the printing; the choice among the printings sharing that artwork still needs the collector line, the frame's era or Other printings. Spec 009 §12's "an art match would have named M10 233" holds only in that the M10 artwork comes first; it doesn't single out the M10 printing.
- Pegasus Guardian's margin is thin on both paths that found it (350 / 363 guide, 380 / 382 photo).

## 7. Determinism (AC-4.8)

The replay ran twice on the desktop (`replay-1` and `replay-2`, 105 jobs each: 35 cards × 3 paths) from the stored frames and photos. **Every job gave identical fingerprints on both runs.** Each search also measured the right artwork's distance directly against its own index record, so the distances in §5–§6 don't depend on the right artwork being in the top 10.

## 8. Recommendations for spec 011 (AC-5.2)

The maintainer rules on these; none is a decision, and there is no pass threshold.

1. **Art on the live path, from the guide crop, with no detection.** It is the strongest result here: right artwork first 33/35 on the desktop replay of the iPhone's frames, with the right card in the text top 3 or first by art for 35/35. The crop needs nothing beyond the guide rect the page already has.
2. **Don't run the shipped detector on whole live frames.** It gets 5/35 right first because its `minSeparation` (0.65 of the height) is larger than the card's share of a live frame (0.596). If detection is wanted on live frames, detect within a region around the guide, or re-tune `minSeparation` for live framing, and measure either first.
3. **The photo path benefits, with care.** Text or art 34/35 against text alone 31/35, but the margins are thin (median right 340 bits against nearest wrong 350.5) and most misses come from the outline. Use art there as evidence with a distance margin, not on its own.
4. **Search in the browser (ADR 0007).** On the iPhone the full index is a 6,008,050-byte gzip download (244 ms over the LAN; 4.8 s at 10 Mbit/s by arithmetic), cacheable as an immutable file named by its catalog version, ready in 79 ms, about 17.5 MB held, and searched in 19 ms median, faster than the desktop's headless Firefox.
5. **Ranking: group art evidence by artwork, then by card.** Art names the printing only when the artwork belongs to one printing (4 of the 14 printings spec 009's text missed). Otherwise it confirms the card and narrows it to the printings sharing the artwork, and the collector line, the frame's era or Other printings decide among them. On these cards the four unique artworks were exactly the ones a better collector-line read also got (§5), so art's main gain is the right card, not the printing.
6. **The opt-in build's cost on this catalog:** about 708 MB of `small` images and about 2.6 h of fetching at Scryfall etiquette (9,467.4 s measured), about 48 min of fingerprinting on the desktop (2,901.1 s; spec 008 measured 1,066.6 s), and a 7.3 MB index (6.0 MB gzip). The build must choose, for each artwork, a printing that has an image: under spec 008's choice (the first printing in bulk-file order) 36 artworks have none, IMG_6812's among them, so the build should fall back to another printing of the same artwork where one has an image.
7. **A confidence margin can be set from the guide-path distances** (right artwork median 189 bits, n=34; nearest wrong median 341, n=35, with the closest wrong first at 320–323 bits), measured on more cards before it is fixed.
