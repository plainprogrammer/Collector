# Feature 007: Card Scanner Phase 1 — Findings

**Spec:** [spec.md](spec.md) (v2.0.0) | **Plan:** [plan.md](plan.md)
**Measured:** 2026-10-01 and 2026-10-02 | **Branch:** `007-card-scanner-live-capture` | **Settings:** commit `c68ffbd` (frozen)

Every rate carries its sample size. Anything not measured is labelled as such. Phase 1 sets no pass threshold: the numbers inform the maintainer's decision on the scan → confirm flow, they don't make it.

---

## 1. Summary

**What was and wasn't measured.** The question Phase 1 exists to answer is whether lining a card up with a live guide fixes Phase 0's accuracy problem. That question was answered only on **12 tuning cards**. Those cards also chose the settings, so their rates are biased upwards (§4). The 50 Phase 0 cards were borrowed and returned, so they couldn't be re-captured live. Instead, their **Phase 0 photos were replayed** through the shipped photo-picker path (§3). Those photos were framed without a guide, so that replay mostly measures the fallback path, not live alignment (spec v2.0.0).

**Live capture, on the tuning cards (iPhone, Brave).** On the final two rounds of fresh captures, the right card was in the name-only top 3 for 11/12 and 10/12. It was first in the final ranking for 10/12 and 9/12. The exact printing came from the collector line for 6/9 in both rounds. Phase 0's comparable rates, on the different 50 cards, were 26/50 (top 3) and 7/45 (exact printing). Recognition on the phone took a median of about 185 ms per capture, slowest 539 ms (n=44), against Phase 0's 626 ms.

**The matcher on Phase 0's own cards.** Phase 0's recorded OCR text, read through Phase 1's parser and matcher, identified the exact printing for 15/45 instead of 7/45. The final ranking had the right card first for 33/50. That is the gain from the code alone (§3).

**The photo replay.** The right card was first for 23/50, and the exact printing was found for 16/45. Names suffer because the guide's framing doesn't match where cards sit in these unguided photos: 21 of the 26 misses are misalignment (§5). The collector-line path holds up (16/45).

**The engine and the page work as designed.**
- A cold load of the scanner page downloads 7,050,153 bytes, including one core build. A warm load re-downloads nothing.
- The policy, the camera lifecycle, the torch, the photo fallback and the plain-HTTP explanation all passed on the iPhone (§6, §7).
- Desktop replays reproduce the device's text exactly (§8).

## 2. Method and apparatus

- **App:** branch `007-card-scanner-live-capture`. The settings were frozen at `c68ffbd` after 4 tuning rounds (AC-6.1):
  - Guide: 80% of the 3:4 stage's height, at most 90% of its width.
  - Name strip: x 0.05, y 0.055, w 0.75, h 0.11, page segmentation 6.
  - Collector strip: x 0.03, y 0.89, w 0.55, h 0.11, page segmentation 6.
  - Both strips drawn at 2× with a grayscale min–max contrast stretch. The collector strip's dark pixel rows are inverted before OCR.
  - Engine: Tesseract.js 7.0.0, core 7.0.0, `eng` `4.0.0_best_int`, served by the app from `/ocr/v7.0.0/`.
- **Catalog:** Scryfall `default-cards-20260930210545` (106,677 English entries), with 35,946 names indexed.
- **Device:** the maintainer's iPhone, iOS 18.7, Brave (WebKit; `… Version/26.6.1 Mobile/15E148 Safari/604.1 Brave`). It reached the dev server over HTTPS on the local network, using a self-signed certificate it trusts (`bin/dev-certificate`). The maintainer's Cloudflare tunnel returned 502 and was abandoned.
- **Tuning cards:** 12 English cards outside the 50-card corpus (`~/card-scanner-corpus/tuning/manifest.csv`): 3 pre-M15, 7 M15–ONE, 2 MOM+, 3 foil. Rounds 1–2 had the first 10 cards; T011–T012 (MOM+) were added for rounds 3–4. Ground truth was built from the catalog (`scanner:ground_truth`): 12 of 12 resolved.
- **Capture protocol (AC-5.4):** one deliberate shot per card with the card filling the guide. A card's first capture is the measured one. Retakes are stored but not counted.
- **Photo replay (AC-6.2):** the 50 Phase 0 photos (4032×3024, EXIF orientation 6). `script/scanner/photo_run.rb` fed each one to the real photo picker in headless Firefox 156 on the desktop. The shipped code placed the guide as on a live frame, cut and read the strips, matched them, and stored the capture through measurement mode. The cards in these photos fill 69–77% of the frame height and drift by about ±4% (spec 005), against the guide's fixed 80%. That mismatch is why misalignment dominates its misses.
- **Scoring:** `bin/rails scanner:findings` (`Collector::ScannerFindings`), using spec 005's definitions. It reproduces Phase 0's committed rates exactly from its fixtures (top 3 26/50, exact printing 7/45). Top 1 and top 3 are reported twice: over the name candidates alone, which is Phase 0's definition, and over the page's final ranking, where a collector-line match comes first.

## 3. Rates: Phase 0, Phase 0's text with Phase 1's matcher, and the photo replay (AC-6.2, AC-6.3)

The middle column changes only the code, since it uses Phase 0's own OCR text. The right column also changes the strips: the guide-relative strips are cut from Phase 0's unguided photos. The final ranking has no Phase 0 column, because Phase 0 had no collector-first ranking.

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

**These are the only live-alignment evidence in Phase 1, and they are biased upwards.** The same 12 cards were used to choose the settings round by round. Rounds 3 and 4 are fresh captures at the settings each round tested, but those settings were picked partly on earlier captures of the same cards.

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


## 5. Misses (AC-6.4)

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

## 6. Timings and downloads (AC-6.5, NFR Performance)

| Measure | Value | n | Phase 0 reference |
|---|---|---|---|
| On-device recognition of both strips, per capture (iPhone, all tuning rounds) | median ≈185 ms, slowest 539 ms | 44 | median 626 ms, slowest 1,911 ms (n=11) |
| — per round (median / slowest) | 131/179, 167/271, 221/271, 288/539 ms | 10, 10, 12, 12 | |
| App-side candidate lookup (desktop, photo replay) | median 44.4 ms, p95 70.1 ms | 50 | name query p95 114 ms (n=50) |
| Cold load of `/scanner` after sign-in | 7,050,153 bytes, 6 requests (engine 7,026,613 bytes in 4: library, worker, `core/tesseract-core-simd-lstm.wasm.js`, `lang/eng.traineddata.gz`) | 1 | 7,031,507 bytes |
| Cold session including the sign-in page and app assets | 7,353,346 bytes, 37 requests | 1 | |
| Warm reload of `/scanner` | 11,770 bytes, 1 request (the page; no engine file requested, not even revalidated) | 1 | about 1 KB |

The recognition time per round rises as the strips grew (2× drawing, taller strips, row inversion). It is still well under Phase 0's. The desktop photo replay's recognition times (median 1,057 ms on 4032×3024 photos) are a desktop measure and aren't comparable.

## 7. Device checks (AC-6.5)

All on the iPhone in Brave, during Phase 10:

| Check | Result |
|---|---|
| Rear camera opens (AC-1.1) | ✓ |
| Camera indicator goes off after leaving the page (AC-1.4) | ✓ |
| Torch toggles the light (AC-1.5) | ✓ |
| A portrait photo picked with **Use a photo** is read upright (AC-4.2) | ✓ |
| Over plain HTTP: no camera request, Capture disabled, **Use a photo** offered (AC-1.6) | ✓ |

## 8. Replays (AC-5.6)

- **Tuning round 4,** replayed twice on the desktop at the frozen settings (`desktop-a`, `desktop-b`): 0 of 12 captures differ from the device's text in either strip, and the two replays are identical. Byte for byte, all 12 differ only in line endings: multipart form posts turn the device's `\n` into `\r\n`.
- **Round 2,** replayed at its own settings: 0 of 10 differ.

The OCR is deterministic across the iPhone (WebKit) and desktop Firefox, which is what made the desktop tuning experiments in §4 trustworthy.

## 9. Coverage (AC-5.4, AC-5.5)

| Run | Captured | Skipped | Retakes |
|---|---|---|---|
| Tuning rounds 1–2 | 10 of 10 (T011–T012 added later) | none | 0 |
| Tuning round 3 | 12 of 12 | none | 0 |
| Tuning round 4 | 12 of 12 | none | 1 (not counted) |
| Photo replay | 50 of 50 | none | 0 |

## 10. Findings for the next spec

- **A misread collector line can outrank the right name.** In tuning round 3, T003's `178/184 C` lost its `178/` and parsed as AER 184. That is a real, different printing, so as the collector-line match it was ranked first (AC-3.2), ahead of the correct name candidate. The confirm step should make the disagreement between the two visible, or rank the collector match below a strong name match. That needs a spec change.
- **Faint collector lines,** especially on foils, are the weakest strip: grey on black, at about 15 px in the frame.
- **Query cleaning picks the longest mostly-alphabetic line.** A long noise line can beat the real name (photo replay, IMG_6720).
- **Framing matters more than anything else measured.** Live alignment with the guide put names in the strip. Unguided photos didn't. Card detection (Phase 2 in the roadmap) would address the photo path and hand-held drift.
- **Flavour names** (IMG_6691) still need a catalog field.

## 11. Fixtures (AC-6.6)

Text only, format_version 2, keyed by manifest `file`, beside spec 005's fixtures in `spec/fixtures/card_scanner/`:

- `phase1_photos_ocr_results.json` and `phase1_photos_name_matches.json`: the photo replay (50).
- `phase1_tuning4_ocr_results.json` and `phase1_tuning4_name_matches.json`: tuning round 4's live iPhone captures (12). The `T0nn` files are keyed by the tuning manifest, not the corpus.

`*_ocr_results.json` carries spec 005's fields (`file`, `name_text`, `collector_text`, `parsed`, `lookup`) plus `ms`, `user_agent` and `captured_at`. `*_name_matches.json` carries `file`, `query`, `lookup_ms`, `name_candidates` (name-only ranking) and `final_candidates` (the page's ranking). No image, crop or photo is committed. The strips stay in `~/card-scanner-corpus/runs/`.

## 12. Options for the maintainer (AC-6.7)

No pass threshold is set. The next spec waits for your ruling.

- **Build the confirm flow on live capture.**
  - *For:* aligned live captures put the right card in the top 3 for 10–11 of 12, and first for 9–10 of 12, at about 0.2 s of recognition. A confirm step catches the remainder, including collector-line disagreements.
  - *Against:* live alignment was measured only on 12 cards that also tuned the settings. Collector lines on faint foils remain unreliable.
- **Bring card detection forward (Phase 2).**
  - *For:* the photo replay shows framing is the dominant failure without a guide. Detection would make both the photo picker and careless live framing robust.
  - *Against:* a larger download (OpenCV.js, about 8 MB per the roadmap, not measured) and more work before any collector benefit.
- **Re-measure live first.**
  - *For:* capturing 50 new cards outside tuning, with the frozen settings, would give an unbiased live number.
  - *Against:* it needs a new corpus, and delays the decision.
- **Stop.**
  - *For / against:* the name index, the parser and the printing lookup would still serve a typed quick-add.
