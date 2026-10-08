# Feature 011: Card Scanner — Art Matching on Live Capture — Findings

**Spec:** [spec.md](spec.md) (v1.1.3) | **Plan:** [plan.md](plan.md)
**Measured:** 2026-10-08 (agreement, the development build, the iPhone sitting and the server time) | **Branch:** `011-card-scanner-art-matching` | **Fingerprint settings:** frozen at `39cdc6e`, settings digest `aa574ad30218cd69`

Every figure carries its sample size. Desktop and phone figures are labelled as such. The sitting used the same 35 cards the 300-bit margin was derived from, so its rates are biased upwards (§9). This feature sets no pass threshold: the figures are for the maintainer's ruling on the margin (§11).

---

## 1. Environment

- **Desktop:** the development machine, Fedora (Linux 7.2.7), ImageMagick 7.1.2-32 Q16-HDRI (`magick`). Agreement ran in headless Firefox through the system spec; the build and the server time ran in this worktree's development instance.
- **Production image:** ImageMagick 7.1.1-43 Q16 (`magick`), amd64, checked in Phase 15 (§2).
- **Catalog:** this worktree's development catalog, refreshed to `default-cards-20261008210545` for the build (§3).
- **Phone:** the maintainer's iPhone, Brave (WebKit), user agent `… iPhone OS 18_7 … Version/26.6.1 … Brave` (iOS freezes "18_7"; `Version/26.6.1` is the release, as in spec 010). Served from the dev machine over the LAN with the self-signed certificate (`bin/dev-certificate`), at `192.168.1.76:3693`, in development measurement mode with art matching on.
- **Account:** the maintainer's own account, which had no sittings or lots before, instead of the fresh `art011@localhost` the plan named (ruling, §4). Spec 009's open sitting in `findings@localhost` isn't mixed in.
- **Fixtures (AC-9.6):** `spec/fixtures/card_scanner/phase3_shipped_agreement.json`, `phase3_shipped_build.json` and `phase3_shipped_sitting.json` (keyed by manifest `file`; no image, frame, index or cached artwork). The run's captures and reading events are in `~/card-scanner-corpus/runs/spec011/sitting` (38 captures), outside the repository.

## 2. Agreement (AC-8.2, AC-3.10)

**Desktop (AC-8.2).** The shipped build (`MTG::Art::Decoder`, ImageMagick) and the shipped scanner page (canvas) fingerprinted spec 010's 134 agreement images (its 34 sitting artworks and 100 others): median 0 bits, largest 0 bits, n=134, decoder `magick`, settings digest `aa574ad30218cd69`. The development index was used for the sitting only after this.

**The production image against the desktop (AC-3.10, Phase 15, `0d2ad58`).** `script/scanner/art_decoder_fingerprints.rb` printed the build's fingerprint of each of the 134 images on the desktop (ImageMagick 7.1.2-32) and in the amd64 production image (ImageMagick 7.1.1-43): all 134 identical. The image installs ImageMagick 7, so the `convert` fallback ADR 0011 allows for wasn't needed. One Rails boot notice ("Generating image variants with libvips requires the ruby-vips gem", issue #18) was filtered out of the image's output before the diff; no fingerprint line differed.

**Not measured:** the arm64 image's decoder. ADR 0011 records it as a known gap.

**Serving (AC-4.1, Phase 15).** A one-record index served by the image through Thruster came back with exactly one `Content-Encoding: gzip` header and a body that gunzips once to 172 bytes (the 28-byte header and one 144-byte record).

## 3. The build (AC-9.1)

The shipped job built the development index after `bin/rails "catalog:refresh[mtg]"`. The maintainer seeded its image cache from the spike's (`~/card-scanner-corpus/art-cache/artwork/small/`), so the job fetched only the artworks the seed lacked.

| The development build | Value |
|---|---|
| Catalog | `default-cards-20261008210545` |
| Artworks indexed | 48,734 |
| Without an image | 0 |
| Images fetched by the shipped job | 51 (the rest from the seeded cache) |
| Fingerprinted | 48,734 |
| Failed | 0 |
| Time, start to finish | 1,743.9 s (about 29 min), almost all fingerprinting |
| Index | 7,017,724 bytes stored, 5,742,930 bytes gzip |
| Index file | `art-index-default-cards-20261008210545-aa574ad30218cd69-48734.bin.gz` |
| Decoder | `magick` |

- **Fetch and fingerprint times** weren't recorded separately; the run keeps one start and one finish. With 51 images fetched (about 5 s at the 100 ms throttle, arithmetic), the 1,743.9 s is fingerprinting. Spec 010's fingerprinting took 2,901.1 s for 50,924 artworks on the same machine; the plan's estimate was about 48 minutes.
- **Fewer artworks than spec 010** (48,734 against 50,924, on a newer bulk file): the difference wasn't investigated. The shipped build counts only artworks with an active, English, ordinary card printing (spec glossary), where the spike counted every front-face artwork in the bulk file, which likely accounts for most of it. Every artwork the build counted had an image under the oldest-English-printing rule (AC-3.3).
- **A first build without a seed** fetches every image: spec 010 measured about 708 MB and 2.6 h for 50,924 images. That cost wasn't re-measured here.

## 4. The sitting (AC-9.2, AC-9.3)

The maintainer scanned spec 009's 35 cards (8 foils, 27 non-foils) live on the iPhone with art on, in measurement mode, on 2026-10-08: 38 captures for 35 cards. Each reading's art event was joined to its capture by reading key (AC-9.3).

**Deviation: the cards weren't added.** The maintainer scanned each card but didn't add it, so every row reads "not added". **Ruling (maintainer, 2026-10-08):** score the sitting as it is. So AC-9.2's add-based outcomes weren't measured: the right printing and finish first time, after a correction (by kind), wrong, and the time per card from the previous add. "Right card first" stands in for them below, and is not the same thing: it says nothing about the printing or the finish.

**Ruling: IMG_6835–6837 are scored on capture 2.** Their first captures were of the previous card: the manifest advanced during a re-scan, so capture 1 of IMG_6835 shows Draconic Intervention and capture 1 of IMG_6836 and IMG_6837 shows Green Dragon. Those first captures were right for the card actually shown (art tier for Draconic Intervention at 248 bits, Green Dragon at 184 and 236), so the slip cost nothing in recognition.

**Account ruling.** The sitting used the maintainer's own account, which had no prior sittings or lots, rather than a fresh `art011@localhost`. Nothing else was mixed in.

| Cards | Right card first | First by confident art | First by strong name | First by weak art |
|---|---|---|---|---|
| All | **34/35** | 27/35 | 7/35 | 1/35 |
| Foil | 8/8 | 5/8 | 2/8 | 1/8 |
| Non-foil | 26/27 | 22/27 | 5/27 | 0/27 |

"First by" is the tier of the first candidate (spec glossary). The strong-name rows (IMG_6811, 6813, 6828, 6833, 6834, 6835, 6840) had a nearest artwork above the 300-bit margin (302–363) and a name strong enough to rank first; the weak-art row (IMG_6821, Pegasus Guardian, foil) had its nearest at 347.

- **Confident art on the wrong card:** 1/35 (IMG_6806, §5).
- **Overrule note shown:** 6/35. Name of another card overruled: IMG_6806 (wrong) and IMG_6839 (right; the name strip read "2 | ey" for Goblin-town Flunkies). Name's printing overruled: IMG_6809, 6823, 6831, 6836.
- **Art overruled a collector-line printing of the same card:** 0/35.
- **Corrections, time per card:** not measured (nothing was added).

**Against spec 009 and spec 010** (same 35 cards; different measures, so read the comparison with care):

| Run | Measure | All | Foil | Non-foil |
|---|---|---|---|---|
| Spec 011, shipped, art on | right card first | 34/35 | 8/8 | 26/27 |
| Spec 010, guide-box replay (desktop) | right artwork first | 33/35 | 8/8 | 25/27 |
| Spec 009, text only, first captures | right card first | 31/35 | — | — |
| Spec 009, text only, added | right first time / in the end | 30/35 / 32/35 | 6/8 / 7/8 | 24/27 / 25/27 |

Spec 009's added outcomes count the printing and finish; this sitting's "right card first" doesn't, so 34/35 isn't directly comparable with 30/35. The comparable line is spec 009's first captures (31/35). Spec 010's two misses were IMG_6806 (framing) and IMG_6812 (no image in the spike's index); here IMG_6812 had an image and art put the right card first at 274 bits, and IMG_6806 is again the miss.

**Distances,** in bits of 1,024 (the event records the nearest two only):

- Every correct confident art match had its nearest at or below 288 bits (n=26): 124 151 173 178 185 209 212 214 215 216 217 228 233 234 240 249 255 257 262 269 271 274 277 280 283 288. The wrong one was at 284, inside that range.
- Art rows whose second-nearest artwork, another card's, was also at or below 300: IMG_6806 (284 / 299, wrong), IMG_6812 (274 / 292), IMG_6815 (240 / 297), IMG_6816 (173 / 291).
- Smallest gaps between nearest and second: IMG_6806 15 bits (wrong), IMG_6812 18, IMG_6810 31 (the second is the same card's), IMG_6808 39.

## 5. Cards not right first, and confident wrong matches (AC-9.4)

**Not ended as the right printing and finish:** not measured, since no card was added (§4). Every card that wasn't the right card first is named here, which is one.

| File | Card | Name strip | Collector strip | Tier | Nearest / second | Ranked first |
|---|---|---|---|---|---|---|
| IMG_6806 | Raven Familiar (PLST C13-55, old frame, non-foil) | `\| Raven Familiar \|` | `Cal TR AVC ri SR T— \| se TOD = - ta xu sik \| i LL —` | confident art | 284 / 299 (another card), gap 15 | Voyage's End |

- **It is the sitting's one confident art match on the wrong artwork.** The name read cleanly and art overruled it (note "name / card").
- **Likely cause:** the List (PLST) reprint's artwork as Scryfall's `small` image looks unlike the printed old-frame card under the phone's camera, so its own artwork wasn't the nearest, and two other cards' artworks landed close together just under the margin (284 and 299). Spec 010 missed the same card on the guide path (right 337 / nearest wrong 323), where framing and a dark, low-contrast artwork were judged the cause; the art event here records only the nearest two, so this sitting's right-artwork distance isn't known.
- **Cost to the collector:** the confirm step shows the overrule note and the other candidates; by the ranking rule the name match ranks second (spec 010 ruling, 2026-10-07). Not measured, as nothing was added.

The other 34 were the right card first. Of the cards spec 009 got wrong or corrected, IMG_6808 (Plains, art 288), IMG_6814 (Obsidian Fireheart, art 233), IMG_6823 (Past in Flames, art 214) and IMG_6829 (Mana Geyser, art 216) were first by confident art, and IMG_6821 (Pegasus Guardian, foil) by weak art at 347, matching spec 010's thin margin for it (350 / 363).

## 6. Phone times (AC-9.5, AC-5.6, NFR Performance)

The page loaded once for the whole sitting, so there is one index load. The art time per capture runs from the start of the fingerprint to the end of the search (`card_reader_controller.js#matchArt`).

| iPhone, Brave | Spec 011, shipped | Spec 010, spike |
|---|---|---|
| Index download (cold) | 119 ms (5,742,930 B gzip) | 244 ms (6,008,050 B gzip) |
| Index ready (parse) | 61 ms | 79 ms |
| Art per capture, median / slowest | 65 / 92 ms (n=35 scored; 64.5 ms over all 38 captures) | search 19 / 29 ms, fingerprint 14.5 / 29 ms |
| Warm load | **not measured** | 11 ms download, 59 ms ready |

- **Against the 100 ms target (AC-5.6, NFR):** median 65 ms per capture, slowest 92 ms, within the target. The art work runs alongside text recognition.
- **Against spec 010:** the shipped art time includes the fingerprint and the search of six offsets, where spec 010's 19 ms is the search alone; its fingerprint and search together come to about 33.5 ms (medians added). The shipped figure is about twice that. The cause wasn't investigated; the shipped page also crops the guide box from the live frame first.
- **Warm load:** not measured. The sitting needed one page load and nobody reloaded it.

## 7. Readiness with art on and off (NFR Performance)

- **Art on:** text recognition was ready 585 ms after the page started (one load). The page starts loading the index after the scanner starts (ADR 0007); its download (119 ms) and parse (61 ms) are in §6. Whether loading it delayed the camera or text recognition can't be told from one load without the art-off comparison.
- **Art off: not measured.** **Ruling (maintainer, 2026-10-08):** skip the three art-off loads and record the comparison as unmeasured. So the NFR's "with and without art matching on" has only the art-on half.

## 8. Server time (NFR Performance)

`bin/rails runner script/scanner/art_reading_time.rb` over the sitting's readings (development, desktop): it ranks each reading with and without its art evidence, after two warm-up rounds each, then twice per side in alternating order (`4eb615c`).

| Ranking, median | Time |
|---|---|
| Text only | 8.7 ms |
| With art | 13.0 ms |
| Added by art | **+4.3 ms** (repeated runs +4.1 to +4.6) |

Within the target of 50 ms more. An earlier ad-hoc run gave 13.5 / 23.0 ms (+9.5). The first version of the script, without warm-up, gave 71.4 / 17.3 ms: whichever side ran first paid for the caches, so the order, not art, made the difference. `4eb615c` fixed that. This is the ranking's time, not the whole request's.

## 9. Bias and threshold

The 300-bit margin was derived from spec 010's guide-path distances on these same 35 cards (AC-6.2). The rates above are therefore biased upwards and aren't an unseen-card rate. This feature sets no pass threshold.

## 10. Recommendations

The maintainer rules on these; only the margin is ruled (§11).

1. **The margin: keep 300 bits.** One confident wrong match in 35 (IMG_6806 at 284) sits inside the range of the correct ones (124–288), so no single threshold separates it on this sample, and moving the margin on one biased card would be tuning on the test. The confirm step still shows the other candidates.
2. **An unseen-card sitting.** Scan a fresh pile, none of it in any earlier corpus, with art on, and add each card, so the add-based outcomes this sitting missed (right printing and finish first time, corrections, time per card) and an unbiased right-card-first rate are measured. Include List reprints and old frames, where the one miss fell.
3. **A gap rule worth evaluating.** The wrong match had the smallest gap between its nearest and second artworks (15 bits, both other cards' and both under 300). A rule that drops confidence when a second card is within a few bits could catch such cases, but IMG_6812 was right with an 18-bit gap, so on this sample a cut-off would sit between 15 and 18 bits: one card each side. Evaluate it on the unseen sitting before adopting it, and record the right artwork's own distance there too.
4. **The 390 px tile wrap.** At 390 px a candidate tile's set line doesn't wrap and can overflow sideways. The markup is spec 009's and the issue predates this feature; fix it in the design-system additions.
5. **List printings' artwork.** IMG_6806 (PLST C13-55) and spec 010's guide miss are the same List reprint. Look at whether the List printing's artwork, or the representative image chosen for it, matches the physical card, and whether List reprints should count their original printing's artwork too.
6. **Known, unrelated:** the production image prints a `ruby-vips` notice on boot (issue #18).

## 11. The margin ruling

**Ruling (maintainer, 2026-10-08, AC-9.4):** keep the margin at 300 bits as shipped. IMG_6806 is recorded as the known confident miss. The margin isn't tuned on one card from a small, biased sample; the confirm step still shows the other candidates. Revisit it with an unseen-card sitting (recommendation 2).
