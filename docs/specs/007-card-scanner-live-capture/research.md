# Feature 007: Card Scanner Phase 1 — Findings

Spec: [spec.md](spec.md)

> **Draft — the live run is still to come (Phase 11).**

## Phase 0's text with Phase 1's matcher

Spec 005's OCR text for the 50 corpus photos (`spec/fixtures/card_scanner/ocr_results.json`), read again through Phase 1's parser, printing lookup and name index (`MTG::Reading`), against this worktree's catalog (Scryfall `default-cards-20260930210545`, 35,946 indexed names). The "Phase 0" column is recomputed from spec 005's committed fixtures and matches research.md §3. Produced by `bin/rails scanner:findings` with an empty run directory, so the "Phase 1 live" column is empty. Every rate shows its sample size.

The OCR text is unchanged, so the name read rates are the same in both columns. With the same text, the exact printing was identified for 15 of 45 set-line cards instead of 7, because 17 collector lines now resolve to one printing instead of 8. The right card was in the top 3 of the name-only ranking for 27 of 50 photos instead of 26 (two MOM+ cards gained, one M15–ONE card lost), and the top 1 of that ranking rose from 20 to 27. The final ranking, which puts a collector-line match first, had the right card first for 33 of 50, and no photo had it at position 2 or 3.

| Name read (front face) | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 live |
|---|---|---|---|---|
| overall | all | 5/50 (10.0%) | 5/50 (10.0%) | — |
| era | M15–ONE | 3/20 (15.0%) | 3/20 (15.0%) | — |
| era | MOM+ | 1/25 (4.0%) | 1/25 (4.0%) | — |
| era | pre-M15 | 1/5 (20.0%) | 1/5 (20.0%) | — |
| foil | foil | 2/9 (22.2%) | 2/9 (22.2%) | — |
| foil | non-foil | 3/41 (7.3%) | 3/41 (7.3%) | — |
| frame treatment | borderless/showcase | 2/16 (12.5%) | 2/16 (12.5%) | — |
| frame treatment | regular | 3/34 (8.8%) | 3/34 (8.8%) | — |

| Name read (catalog name) | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 live |
|---|---|---|---|---|
| overall | all | 5/50 (10.0%) | 5/50 (10.0%) | — |
| era | M15–ONE | 3/20 (15.0%) | 3/20 (15.0%) | — |
| era | MOM+ | 1/25 (4.0%) | 1/25 (4.0%) | — |
| era | pre-M15 | 1/5 (20.0%) | 1/5 (20.0%) | — |
| foil | foil | 2/9 (22.2%) | 2/9 (22.2%) | — |
| foil | non-foil | 3/41 (7.3%) | 3/41 (7.3%) | — |
| frame treatment | borderless/showcase | 2/16 (12.5%) | 2/16 (12.5%) | — |
| frame treatment | regular | 3/34 (8.8%) | 3/34 (8.8%) | — |

| Top 1, name only | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 live |
|---|---|---|---|---|
| overall | all | 20/50 (40.0%) | 27/50 (54.0%) | — |
| era | M15–ONE | 8/20 (40.0%) | 11/20 (55.0%) | — |
| era | MOM+ | 8/25 (32.0%) | 12/25 (48.0%) | — |
| era | pre-M15 | 4/5 (80.0%) | 4/5 (80.0%) | — |
| foil | foil | 4/9 (44.4%) | 5/9 (55.6%) | — |
| foil | non-foil | 16/41 (39.0%) | 22/41 (53.7%) | — |
| frame treatment | borderless/showcase | 7/16 (43.8%) | 9/16 (56.3%) | — |
| frame treatment | regular | 13/34 (38.2%) | 18/34 (52.9%) | — |

| Top 3, name only | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 live |
|---|---|---|---|---|
| overall | all | 26/50 (52.0%) | 27/50 (54.0%) | — |
| era | M15–ONE | 12/20 (60.0%) | 11/20 (55.0%) | — |
| era | MOM+ | 10/25 (40.0%) | 12/25 (48.0%) | — |
| era | pre-M15 | 4/5 (80.0%) | 4/5 (80.0%) | — |
| foil | foil | 5/9 (55.6%) | 5/9 (55.6%) | — |
| foil | non-foil | 21/41 (51.2%) | 22/41 (53.7%) | — |
| frame treatment | borderless/showcase | 9/16 (56.3%) | 9/16 (56.3%) | — |
| frame treatment | regular | 17/34 (50.0%) | 18/34 (52.9%) | — |

| Top 1, final ranking | Group | Phase 0 text, Phase 1 matcher | Phase 1 live |
|---|---|---|---|
| overall | all | 33/50 (66.0%) | — |
| era | M15–ONE | 12/20 (60.0%) | — |
| era | MOM+ | 17/25 (68.0%) | — |
| era | pre-M15 | 4/5 (80.0%) | — |
| foil | foil | 6/9 (66.7%) | — |
| foil | non-foil | 27/41 (65.9%) | — |
| frame treatment | borderless/showcase | 12/16 (75.0%) | — |
| frame treatment | regular | 21/34 (61.8%) | — |

| Top 3, final ranking | Group | Phase 0 text, Phase 1 matcher | Phase 1 live |
|---|---|---|---|
| overall | all | 33/50 (66.0%) | — |
| era | M15–ONE | 12/20 (60.0%) | — |
| era | MOM+ | 17/25 (68.0%) | — |
| era | pre-M15 | 4/5 (80.0%) | — |
| foil | foil | 6/9 (66.7%) | — |
| foil | non-foil | 27/41 (65.9%) | — |
| frame treatment | borderless/showcase | 12/16 (75.0%) | — |
| frame treatment | regular | 21/34 (61.8%) | — |

| Exact printing (M15–ONE, MOM+) | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 live |
|---|---|---|---|---|
| overall | all | 7/45 (15.6%) | 15/45 (33.3%) | — |
| era | M15–ONE | 2/20 (10.0%) | 5/20 (25.0%) | — |
| era | MOM+ | 5/25 (20.0%) | 10/25 (40.0%) | — |
| foil | foil | 0/9 (0.0%) | 3/9 (33.3%) | — |
| foil | non-foil | 7/36 (19.4%) | 12/36 (33.3%) | — |
| frame treatment | borderless/showcase | 3/16 (18.8%) | 7/16 (43.8%) | — |
| frame treatment | regular | 4/29 (13.8%) | 8/29 (27.6%) | — |

Lookup outcomes (M15–ONE, MOM+): Phase 0 {"none" => 37, "one" => 8}; Phase 0 text, Phase 1 matcher {"none" => 28, "one" => 17}; Phase 1 live {}
