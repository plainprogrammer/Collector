---
name: card-scanner-direction
description: Maintainer chose to go ahead with the card scanner after Phase 0 (PR #6); Phase 1 should follow research.md §8's changed scope; corpus lives outside the repo
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

Related: [[phone-lan-dev-access]], [[sdd-review-model-choice]].
