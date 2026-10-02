---
name: card-scanner-direction
description: Card scanner status — Phase 0 (PR #6) led to Phase 1 (spec 007, PR #8, ready for review); re-measure on a new 50-card corpus ruled in (2026-10-02), then confirm-flow vs detection ruling; corpus cards returned, only photos remain
metadata:
  type: project
---

On 2026-09-30 the maintainer decided to **move forward with the card scanner**, judging from the Phase 0 findings (spec 005, PR #6) that "there is enough potential here to justify that".

Phase 0 found:
- **What works:** self-hosted Tesseract.js 7 is fast on the iPhone (cold 7.03 MB, ready in about 0.5 s, 626 ms per photo), and the FTS5 trigram name index works, including in `schema.rb`.
- **The weakness:** accuracy with a fixed guide on hand-held photos. Top 3 was 26/50, and the exact printing from the collector line was 7/45. 19 of the 24 misses came from strip framing.

**Why:** the go/no-go was left to the maintainer on purpose (spec 005 Non-Goal). This records the decision, which isn't in the code.

**How to apply:**
- Specify Phase 1 from `docs/specs/005-card-scanner-phase-0/research.md` §8 (the recommended scope) and §9 (the roadmap assumptions it contradicted), not from the original roadmap.
- That scope is: a live camera preview with the guide overlay (iOS needs HTTPS for the camera), tight strips, query cleaning, and parser fixes (a rarity letter glued to the number, a dropped slash, and "ONE" being picked up as a set code). Card detection is the fallback.
- ADRs 0001–0003 are still `Proposed`, so accept or revise them during Phase 1 planning.
- The photo corpus (50 JPEGs plus `manifest.csv`, with the original in `manifest.csv.orig`) is in `~/card-scanner-corpus/`, outside the repo on purpose (FR-1). Reuse it for Phase 1 measurements; `spec/fixtures/card_scanner/` holds the text-only fixtures.

**Phase 1 status (2026-10-02):** spec 007 was implemented and is in PR #8, ready for review. The findings are in `docs/specs/007-card-scanner-live-capture/research.md`.
- **Spec v2.0.0:** the 50 corpus cards were **borrowed and returned**. Only their photos and `manifest.csv` remain in `~/card-scanner-corpus/`, so the measured run replayed the photos through the photo-picker path.
- **Tuning cards:** the 12 cards in `~/card-scanner-corpus/tuning/` (manifest and ground truth) were captured live in 4 tuning rounds. They also chose the frozen settings (`c68ffbd`), so their rates are biased upwards. They can't serve as an unbiased live measurement.
- **Ruling (2026-10-02) on research.md §12:** re-measure live first, on a **new 50-card corpus the maintainer owns**, at the frozen settings (`c68ffbd`). It goes **in PR #8 before merge**, as a MINOR spec 007 update with the results added to research.md. Capture each card live **and** take one unguided photo of it, so there is a photo-path baseline. **No pass threshold:** the maintainer rules on confirm flow vs card detection after reading the rates. Don't write the next spec before that second ruling.
- **Carry into the next spec** (research.md §10): a misread collector line can match a real, different printing and outrank the right name match (AC-3.2); faint foil collector lines; query cleaning can prefer a long noise line.

Related: [[phone-lan-dev-access]], [[sdd-review-model-choice]], [[check-corpus-availability]].
