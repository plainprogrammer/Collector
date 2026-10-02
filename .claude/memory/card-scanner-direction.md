---
name: card-scanner-direction
description: Card scanner status — Phase 0 (PR #6), Phase 1 (spec 007, PR #8, merged); Phase 2 = spec 008 (desktop spike of card detection + art matching, browser only, ADR 0004; spec v1.1.1 and plan approved and reviewed, ready for sdd-execute on Opus) then spec 009 (confirm flow + refinements; answers in the 008 PRD); pending: artwork-fetch approval, 009 ruling
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
- **Ruling (2026-10-02) on research.md §12:** re-measure live first, on a **new corpus the maintainer owns (49 cards)**, at the frozen settings (`c68ffbd`). It goes **in PR #8 before merge**, as a MINOR spec 007 update with the results added to research.md. Capture each card live **and** take one unguided photo of it, so there is a photo-path baseline. **No pass threshold:** the maintainer rules on confirm flow vs card detection after reading the rates. Don't write the next spec before that second ruling.
- **Re-measure result (2026-10-02, research.md §5):** live, right card first 42/49, top 3 45/49, exact printing 34/44, median 168 ms. Same cards' photos 2/49 (cards fill the frame beyond the guide). 3/49 misread collector numbers matched another card's real printing and outranked the right name; foils 4/10 exact printing. New corpus in `~/card-scanner-corpus/phase1-live/`.
- **Phase 2 reshaped (2026-10-02, later the same day, spec 008 brainstorm) — this replaces the ordering in the next bullet.** The maintainer's Phase 2 is the confirm flow **plus** the roadmap's precision work. It is two specs:
  - **Spec 008** (`docs/specs/008-card-scanner-phase-2-spike/prd.md`): a desktop-only spike of **card detection and art matching** on the 99 stored photos. Stored photos only: no device run, no new captures. In the browser only (ADR 0004; the roadmap's server sidecar is ruled out). Each corpus is halved, balanced on foil (foils and non-foils alternated separately by manifest order; `mat 71` is in both corpora, so its new-corpus photo goes to development: 52 development, 47 held out); held-out rates are the headline. No pass threshold. The full Scryfall artwork fetch needs the maintainer's approval after a 500-artwork estimate.
  - **Spec 009:** the scan → confirm → add flow with the reading refinements, plus whichever of detection and art matching the spike supports. The maintainer's confirm-flow answers are already recorded in the 008 PRD ("Decisions carried to spec 009"): stack sitting with optional details, one add button per finish, picking the printing inside the scanner, a stored list of the sitting's adds with undo (not what was read), re-score then a live sitting on unseen cards. Don't ask these again.
  - Detection is now **inside** Phase 2. Japanese and other languages stay out.
  - **Spec 008 status (2026-10-02, end of the brainstorm/plan session):** `spec.md` v1.1.1 Approved (reviewed twice, READY TO PLAN); `plan.md` approved and revised after a Fable plan review that ran the plan's code blocks (READY TO EXECUTE after fixes). ADR 0004 Accepted. **Next:** `sdd-execute` on Opus; create the branch `008-card-scanner-phase-2-spike` from `plainprogrammer/008-card-scanner-phase-2` first (the docs commits are on the worktree branch). Phase 0 of the plan refreshes this worktree's empty catalog and makes a `phase2@localhost` user. **Maintainer decisions still pending:** approve or decline the full artwork fetch from the committed estimate (plan Phase 5), and the spec 009 ruling on the findings. Nothing may be committed between the freeze commit and the last held-out run (the guard compares `HEAD` with the settings commit).
  - Spec 007's `research.md` §2 and §7 were corrected on 2026-10-02: Phase 0's photos are stored 3024×4032 (EXIF 1), the new corpus's 4032×3024 (EXIF 6); spec 005's research still says the Phase 0 photos were "shot as 4032×3024 with orientation 6" (left as is: true of the originals on the phone).
- **Ruling (2026-10-02) on research.md §13 (ordering superseded above; the ranking and photo-picker rulings below still stand, for spec 009):** the next spec was to be the **scan → confirm → add flow on live capture**, with card detection a later phase for the photo path.
  - **Collector line against name:** when they point to different cards, a strong name match outranks the collector-line match, which is shown second. This changes spec 007's AC-3.2 ("collector match first"); spec 008 must define "strong" from the evidence (the 3 misread-number cases in research.md §5).
  - **Photo picker:** kept as the fallback when there's no HTTPS or no camera, with copy telling the collector to frame the card like the guide. Detection improves it later.
  - Still open for sdd-specify: where confirmed cards land (the roadmap's "Loose bucket" vs an existing lot), choosing the finish (foil exact printing 4/10), correcting the printing, and whether scan attempts are logged.
- **Carry into the next spec** (research.md §11): a misread collector line can match a real, different printing and outrank the right name match (AC-3.2); faint foil collector lines; query cleaning can prefer a long noise line.

Related: [[phone-lan-dev-access]], [[sdd-review-model-choice]], [[check-corpus-availability]].
