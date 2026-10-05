# 0005: Detect and straighten the card with a hand-written detector on the photo path

## Status

Accepted (2026-10-03, maintainer ruling on spec 009's scope from the spec 008 findings: build into spec 009 for the photo-picker path only)

**Date:** 2026-10-03
**Feature:** 008-card-scanner-phase-2-spike

## Context

The scanner's photo picker is the fallback when there is no HTTPS or no camera (spec 007 ruling). It cuts the name and collector strips at fixed positions, so it only works when the photo happens to be framed like the live guide. On the new corpus's unguided photos it put the right card in the top 3 for 2 of 49 (spec 007 [research.md](../specs/007-card-scanner-live-capture/research.md) §5).

The Phase 2 spike ([research.md](../specs/008-card-scanner-phase-2-spike/research.md)) tested two in-browser detectors that find the card in a photo and straighten it before the shipped reading chain reads it. Settings were tuned on 52 development photos and frozen (`39cdc6e`); the figures below are from the 47 held-out photos, on the desktop. ADR 0004 keeps recognition in the browser.

| Held out (47) | Hand-written | OpenCV.js 4.13.0 | Shipped photo path |
|---|---|---|---|
| Right card in the top 3, final ranking | 32/47 (68.1%) | 13/47 (27.7%) | 10/47 (21.3%) |
| Right card first | 27/47 (57.4%) | 12/47 (25.5%) | 10/47 (21.3%) |
| Exact printing (set-line cards) | 13/43 (30.2%) | 6/43 (14.0%) | 7/43 (16.3%) |
| Files, gzip | 5,062 B | 3,570,593 B | — |
| Runs under the scanner page's policy | Yes | Needs `'unsafe-eval'` in `script-src` | — |
| Detect + straighten, medians (desktop) | 104 + 111 ms | 8 + 113 ms | — |

Live capture remains far better on the same cards: on the new corpus's 23 held-out cards, top 3 19/23 live against 13/23 with the hand-written detector, exact printing 17/21 against 2/21. When the card fills the frame, the hand-written detector's outline often stops above the card's bottom edge (17 of those 23 outlines were wrong), losing the collector line. Nothing was measured on a phone or on live frames.

## Options considered

### Option A: The hand-written detector on the photo path

**Pros:**
- Triples the photo path's held-out top 3 (10/47 to 32/47).
- About 5 KB compressed, no third-party code, and it runs under the scanner page's existing Content Security Policy.
- Deterministic: two replays gave identical images and outcomes for 52 of 52 photos.

**Cons:**
- Misses the bottom edge of a card that fills the frame, losing the collector line; battle cards and tilts beyond ±6° defeat it.
- Its settings were tuned on 52 photos from two corpora; other phones, backgrounds and lighting are unmeasured.
- Phone timings are unmeasured.

### Option B: The OpenCV.js detector on the photo path

**Pros:**
- A maintained library with general contour tools.

**Cons:**
- Held-out top 3 13/47, barely above the shipped photo path's 10/47, and below it on Phase 0's photos (8/24 against 9/24).
- 3.57 MB compressed (10.98 MB stored), about 700 times Option A.
- Needs `'unsafe-eval'` in the scanner page's `script-src`.

### Option C: No detection; keep the photo picker as it is

**Pros:**
- No new code. Live capture already serves collectors with HTTPS and a camera.

**Cons:**
- The fallback stays close to unusable on unguided photos (10/47 held out; 2/49 on the new corpus in spec 007).

## Decision

**Proposed: Option A.** Spec 009 builds the hand-written detector into the photo-picker path: detect the card, straighten it to the frozen size (1008×1408) and place it exactly in the guide's box before the shipped strips are cut. Live capture stays the primary path and is unchanged unless spec 009 measures detection on live frames.

The frozen settings carry over as the starting point: work width 480, blur 2, edge percentile 0.55, theta range 6°, minimum separation 0.65, minimum area 0.15, aspect range 0.5–0.9 (`spikes/card_scanner/phase2/settings.json` at `39cdc6e`). The detector is treated as upright-only, as in the spike.

Option B is rejected on the evidence: it is less accurate, larger by three orders of magnitude, and needs the policy loosened. Option C leaves the fallback path failing for most unguided photos.

## Consequences

- The scanner gains about 5 KB of first-party JavaScript and no dependency. The Content Security Policy is unchanged.
- The photo picker becomes useful without the guide, but stays well below live capture; the confirm step remains the safety net.
- Spec 009 owns the weaknesses the spike found: the outline stopping above the bottom edge of a card that fills the frame, and the name strip sitting below the name bar of a card that exactly fills the guide. Both are reading refinements spec 009 already plans; neither is solved by this ADR.
- Battle cards (sideways) and steep tilts are not handled; the confirm step or a typed search covers them.
- Phone timing and accuracy on the phone must be measured in spec 009's live sitting before this ADR is accepted as more than a desktop result. **Measured in spec 009** ([research.md](../specs/009-card-scanner-confirm-flow/research.md) §7, §9, settings `7afed14`):
  - On the iPhone (Brave, WebKit), on 10 unguided photos of the sitting's cards: detection median 103 ms (slowest 126 ms), straightening median 30.5 ms (slowest 35 ms), well under the 1 s target. Outline found 10/10, right card first 5/10, top 3 6/10, exact printing 1/6, name read 1/10. A small sample, below the desktop held-out result and well below live capture of the same cards.
  - Desktop, held out once at the freeze (n=47), with spec 009's two refinements: right card first 33/47, top 3 33/47, exact printing 15/43 (foils 3/8, non-foils 12/35), outline found 43/47, against the spike's frozen 27/47, 32/47 and 13/43.
  - The outline completion (`completeTolerance` 0.08, extending an outline that stops above the card's bottom edge) raised development exact printings from 20/46 to 22/46 (non-foils 17/35 to 20/35, foils 3/11 to 2/11; development, biased). Moving the detected name strip up (y 0.04) raised development right-first from 42/52 to 43/52 alone, and 44/52 with the completion.
  - The shipped detector matches the spike's on all 99 photos at the spike's settings (0.000 px drift).
- Whether detection also runs on live frames (to correct careless framing) is not decided here; the spike didn't measure it.
- The OpenCV.js build is not added to the app, and `vendor/` gains nothing.
