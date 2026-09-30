---
date: 2026-09-30
spec: "005"
tags: [spike, planning, ocr, measurement]
---

# Lesson: Pilot the spike apparatus on real inputs before freezing its constants

## Context

Spec 005 (card scanner Phase 0), Phase 2. The plan fixed the OCR guide at "the card fills 90% of the image height, centred", with name and collector strips as fixed fractions of that card. It then tuned them on a 5-photo pilot before the measured runs.

## What happened

The maintainer's real, hand-held iPhone photos had the card at 69–77% of the frame height, centred at 0.50–0.58 across and 0.45–0.51 down. On the first pilot round every strip missed the card entirely.

Two framing rounds fixed that: a guide of 0.74 height centred at (0.51, 0.485). But the strips had to be tall, about 0.16–0.18 of the card, to absorb the ±4% drift. Single-line segmentation (psm 7) on those tall strips read no names at all. Three more rounds on the page-segmentation mode only reached 2 of 5, with psm 6.

That tall-strip cost then dominated the measured results: 19 of the 24 top-3 misses trace to strip framing. The finding was real, but the plan's 90% assumption would have measured nothing if there had been no pilot.

## What to do next time

- When a spike measures a technique that depends on input geometry (framing, cropping, thresholds), the spec should require a pilot on real inputs, and the findings should report the tuning rounds and the frozen values.
- Plans should treat the constants as starting guesses, not as values.
- Keep the tuning knobs few and named in the plan. Here that was the guide height, the guide centre, and the strip box and segmentation mode. That way each tuning round stays within the approved plan.
- Say explicitly whether the pilot photos are part of the measured set.

## Signals to watch for

- A plan that hard-codes proportions, thresholds or crop boxes for data nobody has looked at yet.
- A first run whose output is all noise.
- "Frozen" values that were never checked against a real sample.
