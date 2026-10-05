# Feature 009: Card Scanner Confirm Flow — Findings

**Spec:** [spec.md](spec.md) (v1.1.2) | **Plan:** [plan.md](plan.md)
**Measured:** 2026-10-04 (the sitting 00:34–00:53 UTC and the phone photos 01:09–01:13 UTC on 2026-10-05, the evening of 2026-10-04 local time) | **Branch:** `009-card-scanner-confirm-flow` | **Settings:** commit `7afed14` (frozen, AC-6.7)

Every rate carries its sample size. Rates on readings or photos that chose a setting are labelled "development, biased"; the held-out photos and the live sitting are the unbiased checks. Desktop and phone figures are labelled as such. This feature sets no pass threshold: the figures are for the maintainer and the art-matching spec.

---

## 1. Environment

- **Catalog:** `source_version` `default-cards-20261003210542` (106,698 printings).
- **Settings commit:** `7afed14d2948970c7f7c3c0c549de7e303f2573b` ("chore(scanner): freeze the spec 009 settings"). Every tuning step ran before it; the held-out photo run, the live sitting and the phone photo run ran after it, with no setting changed (the only later commit before the sitting, `0731e5c`, adds a timing spec and a size script).
- **Phone:** the maintainer's iPhone, Brave (WebKit): `Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.6.1 Mobile/15E148 Safari/604.1 Brave` (on all 35 sitting captures and all 10 phone photos).
- **Desktop:** the development machine; stored-text re-scores in Ruby, strip and photo replays in headless Firefox (`script/scanner/replay.rb`, `script/scanner/detector_parity.rb`).
- **Runs (outside the repository):** sitting `~/card-scanner-corpus/runs/spec009/sitting`; phone photos `~/card-scanner-corpus/runs/spec009/sitting-photos`; both against `~/card-scanner-corpus/phase2-sitting/manifest.csv` and its ground truth.
- **Fixtures (AC-9.4):** the stored text, in spec 007's format at `format_version` 3, keyed by manifest `file`, with no image or strip: `spec/fixtures/card_scanner/phase2_sitting_{ocr_results,name_matches}.json` (35 rows, run "Spec 009 sitting") and `phase2_sitting_photos_{ocr_results,name_matches}.json` (10 rows, run "Spec 009 phone photos", with the outline and the detection and straightening times).

## 2. Ranking (AC-5.1, AC-5.4)

**Rule.** The top name candidate is "strong" when its Jaro-Winkler similarity to the cleaned query is at or above `MTG::Reading::STRONG_NAME_SCORE`. A strong name candidate ranks first; then collector-line evidence (exact, or one digit corrected, AC-5.3); then the name order. The rule is `Candidate#rank_key` (AC-5.5).

**Threshold sweep** (`bin/rails scanner:strong_sweep`, all 210 stored readings: Phase 0 50, Phase 1 photo replay 50, tuning round 4 12, new corpus live 49, new corpus photos 49; development, biased):

| Threshold | Right first (of 210) | Right first places lost | The three misread cases right first |
|---|---|---|---|
| 0.80 | 112 | 3 | yes |
| 0.81–0.82 | 113 | 2 | yes |
| 0.83–0.92 | 114 | 1 | yes |
| **0.93–0.96** | **115** | **0** | **yes** |
| 0.97–1.00 | 114 | 0 | no |

**Chosen: 0.96**, the highest threshold with the most right-first readings and no loss. There is no margin above it: from 0.97 the misread cases lose their right first place. `Catalog::NameIndex::LONG_TOKEN_SHARE` stayed at 0.5 (§3).

**Against spec 007's ranking** (`spec009_ranking_baseline.json`, both with this feature's query cleaning against the baseline's spec 007 cleaning and ranking):

| Run | Right first, spec 007 | Right first, spec 009 | Top 3, spec 007 | Top 3, spec 009 |
|---|---|---|---|---|
| Phase 0 | 33/50 | 33/50 | 33/50 | 33/50 |
| Phase 1 photo replay | 23/50 | 25/50 | 24/50 | 25/50 |
| Tuning round 4 | 9/12 | 10/12 | 10/12 | 10/12 |
| New corpus live | 42/49 | 45/49 | 45/49 | 45/49 |
| New corpus photos | 2/49 | 2/49 | 2/49 | 2/49 |

- The first candidate changed for 12 of 210 readings. Six became right: IMG_6704 (Enlightened Tutor), IMG_6720 (Fanged Flames), T007 (Honored Heirloom), and the three misread cases IMG_6765 (Tome Shredder), IMG_6769 (Grand Master of Flowers) and IMG_6792 (Cast Away Doubt). The other six were wrong before and after: IMG_6737, IMG_6716, IMG_6717, IMG_6744 and IMG_6787 changed one wrong first candidate for another, and IMG_6762 (Moonhold, a new-corpus photo) now gets no candidate at all, where it had three wrong ones.
- No right first place was lost, and no right card left the name-only top 3.

Every reading whose first candidate changed (`bin/rails scanner:ranking`, AC-5.4):

| Run | File | Expected | Spec 007 top 3 | Spec 009 top 3 |
|---|---|---|---|---|
| Phase 0 | IMG_6737.jpeg | Leyline of the Guildpact | Keiga, the Tide Star; See the Truth; Picklock Prankster // Free the Fae | Metastatic Evangel; Overt Operative; Rhys, the Evermore |
| Phase 1 photo replay | IMG_6704.jpeg | Enlightened Tutor | Divine Sacrament; Enlightened Tutor; Enlightened Ascetic | Enlightened Tutor; Divine Sacrament; Enlightened Ascetic |
| Phase 1 photo replay | IMG_6716.jpeg | Blessed Ghoul | Belisarius Cawl; Obelisk of Alara; Felisa, Fang of Silverquill | View from Above; Viewpoint Synchronization; Towering Viewpoint |
| Phase 1 photo replay | IMG_6717.jpeg | Campus Crier | Might Makes Right; Gavel of the Righteous; The Mana Rig | Pako, Arcane Retriever; Peak Eruption; Most Decrepit Old Bird // Speak Secrets |
| Phase 1 photo replay | IMG_6720.jpeg | Fanged Flames | Monsoon; Harpoon Sniper; Horned Loch-Whale // Lagoon Breach | Fanged Flames; Fanning the Flames; Spreading Flames |
| Phase 1 photo replay | IMG_6744.jpeg | Gluttonous Hellkite | Geyser Leaper; Tiger Claws; Tiger-Dillo | Far // Away |
| Tuning round 4 | T007 | Honored Heirloom | Welcoming Vampire; Honored Heirloom; Hero's Heirloom | Honored Heirloom; Welcoming Vampire; Hero's Heirloom |
| New corpus live | IMG_6765.jpeg | Tome Shredder | Elite Spellbinder; Tome Shredder; Bone Shredder | Tome Shredder; Elite Spellbinder; Bone Shredder |
| New corpus live | IMG_6769.jpeg | Grand Master of Flowers | Ranger Class; Grand Master of Flowers; Grand Melee | Grand Master of Flowers; Ranger Class; Grand Melee |
| New corpus live | IMG_6792.jpeg | Cast Away Doubt | Enlightened Confidant; Cast Away Doubt; Cast Out | Cast Away Doubt; Enlightened Confidant; Cast Out |
| New corpus photos | IMG_6762.jpeg | Moonhold | Possessed Aven; Proposal; Ormos, Archive Keeper | (none) |
| New corpus photos | IMG_6787.jpeg | Terramorphic Expanse | Raise the Alarm; Make a Wish; Tangle Wire | Headstone; Heal; Head Games |

- **Bias.** The threshold and the cleaning were chosen on these same 210 readings, so their results here are biased upwards. The live sitting (§8) is the unbiased check.

## 3. Query cleaning (AC-6.1)

A line now counts as a name query only if at least half its characters (`LONG_TOKEN_SHARE` 0.5) sit in tokens of 3 or more characters; otherwise cleaning falls back to spec 007's rule. On IMG_6720's stored Phase 1 photo-replay text, the short-token noise line no longer beats the name: Fanged Flames is now the first name candidate (it was outside the top 3 under spec 007's cleaning). Every stored reading whose right card was in the name-only top 3 under spec 007 stays there (210 readings, §2; development, biased).

## 4. The foil marker (AC-6.5)

The separator between set code and language, as read on the new corpus's 49 stored live captures (11 foils, 38 non-foils by ground truth; development, biased):

| Read as | Foils | Non-foils |
|---|---|---|
| `*` | 4 | 3 |
| `®` | 1 | 0 |
| `«` | 2 | 10 |
| `=` | 1 | 2 |
| `+`, `+»`, `»` | 0 | 17 |
| no separator, or no set line | 3 | 6 |

- **Shipped:** `MTG::CollectorLine::FOIL_MARKERS = %w[★ ®]`. `*` was dropped because 3 of 38 non-foils read it.
- **Marked as foil:** foils 1/11, non-foils 0/38 (before, with `★ *`: foils 4/11, non-foils 3/38). The marker is a hint on the Foil button only; it never reorders or adds (AC-6.5). With so few foils marked, the collector's tap chooses the finish in practice (§8).

## 5. Strip refinements on the stored live strips (AC-6.2, AC-6.3)

The new corpus's 49 stored live strips (10 foils with a set line), replayed on the desktop (development, biased):

| Variant | Right first | Top 3 | Exact printing | Foils | Non-foils | Name read | IMG_6785 name read |
|---|---|---|---|---|---|---|---|
| All off (shipped) | 45/49 | 45/49 | 34/44 | 4/10 | 30/34 | 5/49 | no |
| Collector binarized | 44/49 | 44/49 | 28/44 | 1/10 | 27/34 | 5/49 | no |
| Collector scaled 1.5× | 45/49 | 45/49 | 34/44 | 3/10 | 31/34 | 5/49 | no |
| Binarized and 1.5× | 44/49 | 44/49 | 31/44 | 3/10 | 28/34 | 5/49 | no |
| Name inverted below 100 | 45/49 | 45/49 | 34/44 | 4/10 | 30/34 | 5/49 | no |
| Name inverted below 128 | 45/49 | 45/49 | 34/44 | 4/10 | 30/34 | 4/49 | no |

- Spec 007's figures were foils 4/10, non-foils 30/34. No collector variant raised the foil exact-printing rate, and binarizing lowered the non-foil rate, so every refinement ships off (`REFINE` in `scanner/geometry`, all off at `7afed14`).
- IMG_6785's light name on a dark bar was never read; inverting below 128 lost one other name (5/49 to 4/49).
- The faint foil collector line is still unsolved by strip processing (§12).

## 6. The detector against the spike (AC-7.3)

`script/scanner/detector_parity.rb` ran the shipped detector at the spike's frozen settings (`39cdc6e`, before AC-6.6's refinements) and the spike's detector re-run at `39cdc6e` on the spike's 99 photos (desktop): **99 of 99 match**, with the same outcome (95 found, 4 not found, all held out) and corner drift 0.000 px at work width 480.

Caveat from the synthetic specs: on a perfectly flat picture the frozen edge threshold is 0. The spike then counted every flat pixel as an edge, and the shipped detector did too until the fix below. A noisy picture with no card can still yield a phantom outline, so the no-outline fallback (guide placement) may rarely trigger on real photos.

Flat-picture fix (after the caveat above): CI on PR #11 failed on the two picked-photo system specs (`scanner_spec.rb:78`, `scanner_adding_spec.rb:51`), whose flat synthetic card found no candidate on Ubuntu 24.04. Root cause: with the edge threshold at 0, `hough` counted every zero-gradient pixel as an edge, and with gx = gy = 0 as a horizontal one, so the card's top and bottom were misplaced (about 6° of slant); local runs read the misframed picture by luck. `hough` now skips pixels with no gradient, the one change from the spike's arithmetic, and two detection specs cover flat pictures. Parity re-run after the fix: **99 of 99 match** (95 found, 4 not found, drift 0.000 px), so real photos are unaffected.

## 7. Detected photos (AC-6.4, AC-6.6)

**Development, biased** (the spike's 52 development photos, desktop):

| Variant | Right first | Top 3 | Exact printing | Foils | Non-foils | Name read |
|---|---|---|---|---|---|---|
| v0: spike settings | 42/52 | 43/52 | 20/46 | 3/11 | 17/35 | 6/52 |
| v1: outline completion 0.08 | 42/52 | 43/52 | 22/46 | 2/11 | 20/35 | 5/52 |
| v2: name strip wider (w 0.82) | 42/52 | 43/52 | 20/46 | 3/11 | 17/35 | 4/52 |
| v3: name strip higher (y 0.04) | 43/52 | 45/52 | 20/46 | 3/11 | 17/35 | 8/52 |
| **v4: v1 + v3 (chosen)** | **44/52** | **46/52** | **22/46** | **2/11** | **20/35** | **8/52** |

- Outline completion (`completeTolerance` 0.08) extends an outline that stops above the card's bottom edge; it raised non-foil exact printings (17/35 to 20/35) and cost one foil (3/11 to 2/11).
- The long-name refinement as a wider strip (v2) held one more name in full (IMG_6714) but lost three, so it was not shipped. Moving the detected name strip up (`DETECTED_STRIPS` name y 0.04) read six names in full that were cut before (IMG_6706, IMG_6710, IMG_6739, IMG_6741, IMG_6755, IMG_6798) and lost four (IMG_6716, IMG_6771, IMG_6783, IMG_6802).
- So AC-6.4's long-name refinement was evaluated (v2) and not shipped, as it gained nothing: long names such as IMG_6761's can still be cut off at the name strip's right edge on live capture.

**Held out, once, at `7afed14`** (the spike's 47 held-out photos, desktop):

| Held out (47) | Spec 009 (v4) | Spike, frozen |
|---|---|---|
| Right card first | 33/47 (70.2%) | 27/47 (57.4%) |
| Top 3 | 33/47 (70.2%) | 32/47 (68.1%) |
| Exact printing (set-line cards) | 15/43 (34.9%): foils 3/8, non-foils 12/35 | 13/43 (30.2%) |
| Outline found | 43/47 | — |
| Name read | 7/47 | — |

## 8. The live sitting (AC-9.1, AC-9.2)

35 English cards from the maintainer's own pile, none in an earlier corpus (`scanner:overlap`), 8 foils and 27 non-foils, scanned live on the iPhone at `7afed14` and added through the scanner. Eras by ground truth: M15–ONE 21, MOM+ 8, pre-M15 6. Unbiased: none of these cards fed tuning.

| Cards | Right first time | Right after a correction | Wrong | Not added |
|---|---|---|---|---|
| All | 30/35 | 2/35 | 3/35 | 0/35 |
| Foil | 6/8 | 1/8 | 1/8 | 0/8 |
| Non-foil | 24/27 | 1/27 | 2/27 | 0/27 |

- **Corrections** (a card can have several): a candidate other than the first 0; Other printings 2 (IMG_6814, IMG_6823); Undo and re-add 0; details edited 2 (IMG_6808, IMG_6823).
- **Time per card,** from the previous add to the add (conventional median): median 23.0 s, slowest 124.0 s (n=34). It includes picking up the card, framing it, choosing and any correction.
- **Retakes:** 4 (39 captures for 35 cards: IMG_6813, IMG_6818, IMG_6819, IMG_6830). The first captures of those four read no usable name; each retake ended right.
- **First captures, scored like spec 007's runs** (`phase2_sitting_*` fixtures, n=35): right card first 31/35, top 3 31/35, exact printing 21/29 (foils 2/8, non-foils 19/21), name read 9/35. Recognition on the phone: median 151 ms, slowest 401 ms (n=35).
- The collector's tap set the finish: foils ended right 7/8 despite a foil exact-printing rate of 2/8 from the collector line.

**Ground truth and rulings.** `scanner:ground_truth` resolved 35/35. IMG_6808 (Plains, M10 233) shares its name with Phase 0's IMG_6739 (another printing); kept by the maintainer's ruling (a different physical card; only basic-land names repeat). The era `pre-M15` was added to the three List reprints with old frames (IMG_6806 C13-55, IMG_6807 JUD-76, IMG_6830 SOK-89; the original is kept as `manifest.csv.orig`). IMG_6828 (Clarion Cathars) was corrected to foil: its photo shows `MID ★ EN` and a foil shine, and the maintainer confirmed it; it ended right first time.

**First attempt.** A first sitting attempt was reset at the maintainer's request. Its 6 captures of 5 cards are kept in `runs/spec009/sitting-attempt-1`; its adds remain in the `findings@localhost` collection and its sitting, but they aren't scored, because the report matches entries by this run's reading keys. The sitting's entries belong to `findings@localhost` (the phone was signed in to that account, not `sitting@localhost` as the plan named).

## 9. The phone photo path (AC-9.3)

10 of the sitting's cards (IMG_6806–IMG_6815), photographed without a guide and picked through "Use a photo" on the iPhone, at `7afed14`. By the controller's ruling, the run used the sitting's manifest and ground truth with its own run directory (`runs/spec009/sitting-photos`) rather than a separate `phase2-sitting-photos` manifest; only those 10 rows were captured.

| Phone photos (10) | Result |
|---|---|
| Outline found | 10/10 |
| Right card first | 5/10 |
| Top 3 | 6/10 |
| Exact printing (set-line cards) | 1/6: foils 0/2, non-foils 1/4 |
| Name read | 1/10 |
| Detection on the phone | median 103 ms (conventional median), slowest 126 ms (n=10) |
| Straightening on the phone | median 30.5 ms (conventional median), slowest 35 ms (n=10) |

Right first: IMG_6806 Raven Familiar, IMG_6808 Plains, IMG_6809 Teleportation Circle, IMG_6810 Tranquil Cove, IMG_6812 Extus (the exact printing, STX 149). IMG_6814 Obsidian Fireheart was second. The other four (IMG_6807, IMG_6811, IMG_6813, IMG_6815) had the right card nowhere in the top 3. With n=10 these rates are rough; they sit below the held-out desktop result (§7) and well below live capture of the same cards (§8).

## 10. Timings and sizes against the targets (NFR Performance)

| Target | Measured | Where, n |
|---|---|---|
| Add, tap to "Added" announcement: median ≤ 500 ms | median 52 ms, slowest 111 ms | desktop, n=10 |
| Other printings with 100 printings: p95 < 300 ms | p95 208 ms | desktop, n=20 (at n=20 the p95 is the slowest) |
| Detection and straightening on the iPhone: median ≤ 1 s per photo | detection median 103 ms, straightening median 30.5 ms | phone, n=10 |
| Cold-load growth ≤ 20 KB compressed (20,480 B) | +8,013 B gzip -9 | `script/scanner/asset_growth.rb`; nothing fetched from another host |

The add round trip wasn't measured separately on the phone; the sitting's time per card (§8) includes handling. Growth by file: detector.js +4,321, scanner_reading_controller.js +1,163, geometry.js +1,073, card_reader_controller.js +689, measurement_controller.js +490, additions.css +207, replay_controller.js +70.

**Reliability (NFR Reliability).** The four scanner system spec files (`scanner_spec`, `scanner_adding_spec`, `scanner_sitting_spec`, `scanner_detection_spec`; 27 examples) passed 10 runs in a row at `0731e5c` (seeds 59809, 33083, 40164, 54421, 31352, 15882, 40965, 51026, 62022, 21996).

**Touch targets.** The spec's 44×44 px minimum names only the add, Undo and Done buttons. The "Other printings" ghost link and "Show N more" have no 44 px minimum; a later spec may want one on the phone.

## 11. Cards that didn't end right (AC-9.5)

Three sitting cards ended as the wrong printing or finish; two more ended right after a correction.

| File | Expected | Ended as | Collector strip read | Likely cause |
|---|---|---|---|---|
| IMG_6821 | Pegasus Guardian // Rescue the Foal, CLB 36, foil | PLST CLB-36, nonfoil | `6/361 C CL» EN » LEANNA CROSSAN` | The set code read as `CL»`, so the collector line matched nothing and the name alone ranked the newest printing (a List reprint). Added without a correction, so both printing and finish were wrong. |
| IMG_6808 | Plains, M10 233, nonfoil | WOE 262, nonfoil | `J ea, woe FO p— …` (noise) | An M10 frame prints no set code or number; the name alone guessed the newest Plains. Details were opened, but the printing wasn't changed. |
| IMG_6829 | Mana Geyser, CNS 147, nonfoil | FDC 165, nonfoil | `… Martina Fucerova … 2014 Wizards of the Goast 3472 …` | An old-frame card with no set code in its collector line; the name alone guessed the newest printing. |
| IMG_6814 | Obsidian Fireheart, ZEN 140, nonfoil | right, after Other printings | `Obsidian Fireheart has le a … JBN RAYONG …` | Pre-M15 frame, no collector line; the name guessed another printing; fixed in Other printings. |
| IMG_6823 | Past in Flames, WHO 565, foil | right, after Other printings and details | `P 0565 - NHO*EN we BBC STUDIOS` | The set code read as `NHO`; fixed in Other printings. |

The four first captures that read no usable name (IMG_6813, IMG_6818, IMG_6819, IMG_6830) were retaken and ended right first time.

## 12. Recommendations for the art-matching spec (AC-9.5)

- **Name-only guesses are the main source of wrong printings.** All three wrong cards and one of the two corrections had no usable collector line, so the name chose the newest printing. Art evidence is what would identify the printing for these cards; per card:
  - **IMG_6808 (Plains, M10 233):** the old frame prints no set code or number, and a basic land has many printings with different artworks. An art match would have named M10 233 instead of WOE 262.
  - **IMG_6829 (Mana Geyser, CNS 147):** an old frame (2003) with no set code; the name guessed FDC 165 (2015 frame). An art match would have named the printing, provided CNS 147's artwork differs from the other printings' (the catalog holds no artwork id yet to check this).
  - **IMG_6814 (Obsidian Fireheart, ZEN 140):** corrected through Other printings; an art match would have ranked the right printing first, under the same proviso against E01 55.
  - **IMG_6821 (Pegasus Guardian, CLB 36 foil):** the set code was lost (`CL»`), so the name guessed the PLST reprint. Art would confirm the card and narrow it to the printings sharing its artwork, but a List reprint shows the same artwork, so the set symbol or a better collector-line read is needed to choose CLB over PLST; the foil finish is a tap either way.
  - **IMG_6823 (Past in Flames, WHO 565 foil):** the set code read as `NHO`; corrected through Other printings. An art match would help if WHO 565's artwork is its own.
- **Join the ranking as a new kind of evidence** in `Candidate#rank_key` (AC-5.5). Group art results by card, since another printing's artwork of the same card can rank first (spec 008 §9).
- **The photo path** finds the outline on the phone (10/10) but reads few names (1/10); art matching on the straightened card (spec 008: right artwork first 33/47 held out against the full index) would help it most.
- **Measure first** the index download and search time on the phone, as the maintainer ruled (spec 008 §14). Detection and straightening already take about 0.13 s per photo on the iPhone (§9).
- **Foil finish** remains a tap: the foil marker marked 1/11 foils (§4), and no strip refinement raised the foil exact-printing rate (§5).
