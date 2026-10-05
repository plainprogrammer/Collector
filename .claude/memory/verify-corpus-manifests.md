---
name: verify-corpus-manifests
description: Before a scanner measured run, check a maintainer-made corpus manifest against the catalog, earlier corpora and the photos; List/retro cards need plst numbers and an era override
metadata:
  type: reference
---

A corpus manifest the maintainer writes by hand (`file,set,number,foil[,era]`) can be wrong in ways that look like scanner misses. Checks that caught real errors on 2026-10-02 (spec 007's new 49-card corpus, `~/card-scanner-corpus/phase1-live/`):

- **Resolve it:** `bin/rails "scanner:ground_truth[<manifest>]"`. Every row must resolve to exactly one printing.
- **The List reprints** (a planeswalker symbol at the bottom left) are Scryfall set `plst`, with numbers like `PCY-132` (original set code, a hyphen, then the original number), not `list 132`. `printed_as` handles the hyphenated numbers.
- **Frames that print no set code** (List reprints of old cards, retro frames such as `mat`) get `era` set to `pre-M15` in the manifest, so they're left out of the exact-printing rate. `MTG::Printing#frame` tells you which (`1997` or `2003` against `2015`).
- **Overlap with earlier corpora:** compare `(set, number)` pairs with `~/card-scanner-corpus/manifest.csv` and `tuning/manifest.csv`. Repeated printings were dropped (maintainer ruling).
- **Photo names:** `file` must be the photo's real file name. The photo replay looks it up in the manifest's folder.
- **Foil column vs the photo:** on M15+ cards a ★ between set code and language (`MID ★ EN`) means foil. Check every `foil` value against its photo. IMG_6828 (spec 009's sitting) was marked `no` but is foil, and it would have counted as a wrong finish.
- **A miss whose strip reads cleanly** may be a ground-truth error. IMG_6763's strip said "Leyline Immersion" (`mat 71`), but the manifest said `mul 71`. View the strip, then the photo, before counting a miss.

**Why:** 5 of 51 rows needed fixing, plus 2 overlaps. Uncaught, they would have counted as scanner misses in the findings.

**How to apply:** run these checks before starting any server for a measured run, and again on every miss when writing up the findings. Related: [[card-scanner-direction]], [[check-corpus-availability]].
