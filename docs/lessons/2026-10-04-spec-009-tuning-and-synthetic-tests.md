---
date: 2026-10-04
spec: "009"
tags: [card-scanner, tuning, detection, testing]
---

# Lesson: Tune against a reference variant, and give synthetic detector images noise

## Context

Feature 009 (card scanner confirm flow and photo-path detection) planned three strip refinements: inverting light names on dark bars, binarizing and enlarging faint foil collector lines, and a wider name strip. It also planned two detector tweaks: outline completion and the name strip's position on a straightened card. All five were tuned on stored runs before a freeze.

## What happened

- **None of the strip refinements helped.** On the new corpus's stored live strips, no collector variant raised foil exact printing above the variant with every refinement off (4/10), and binarizing lowered it. No name inversion read IMG_6785. The gains came instead from the detected path's own strip layout (name strip at y 0.04) and from outline completion. On the 47 held-out photos the pipeline went from the spike's 27/47 right first to 33/47. Because every refinement was built off, each one had to beat the all-off variant to ship, so nothing that cost accuracy was frozen in.
- **Flat synthetic images break the detector's tests.** On a perfectly flat synthetic picture, more than 55% of edge strengths are exactly 0, so the frozen percentile threshold becomes 0 and flat pixels swamp the card's edges. The spike behaves identically, so the fix belonged in the tests: seeded noise of ±2 levels. With noise, a photo with no card can also yield a phantom outline. The real-photo fallback ("no card edge found") may therefore rarely trigger.
- **The spike's committed run records were enough for parity.** Its detector code was identical between the development run and the freeze commit, so the recorded corners served as the reference. The ported detector matched all 99 photos with 0.000 px drift, without running the spike again.

## What to do next time

- Give every planned refinement an "off" reference variant and a written decision rule, and plan for it staying off. Expect some refinements not to ship, and say so in the spec.
- Draw synthetic test images for image-processing code with fixed-seed noise, and cover the flat and no-card cases deliberately.
- When porting spike code, check whether its committed run records can serve as the parity reference before planning a re-run.

## Signals to watch for

A refinement list written before any measurement. Percentile thresholds over images with large uniform areas. A spike whose code and settings are unchanged since its recorded runs.
