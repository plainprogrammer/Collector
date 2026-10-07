---
date: 2026-10-06
spec: "010"
tags: [card-scanner, detection, measurement, art-matching]
---

# Lesson: Check a detector's limits against the new framing, and rescore a surprising zero

## Context

Spec 010 measured art matching on spec 009's 35 cards along three paths: the live guide-box crop, the shipped detector (ADR 0005) on each live frame, and the detector on unguided photos. It also compared art with the text read in the same new capture, the secondary figure in AC-4.5.

## What happened

- **The detector on live frames scored 5/35, and the cause was structural.** The guide on the iPhone's 1080×1920 frame spans 0.596 of the frame height. The shipped detector requires its two horizontal edges to be at least `minSeparation` 0.65 of the height apart, a limit tuned on photos where the card fills the picture. So it can never select both card edges. It found no outline on 10 frames and paired one card edge with another line on the rest. One line of arithmetic, the card's share of the frame against the separation limit, predicted this before any replay ran.
- **The same-capture comparison showed art naming 0 more printings, and that was real.** It looked like a keying bug. Rescoring the captures showed that the new collector lines had read the exact printing for the cards art had rescued against spec 009's text (IMG_6819, 6820, 6823), so there was nothing left for art to name.
- **The guide-box crop scored 33/35 right artwork first, with a wide margin:** the right artwork's distance had a median of 189 bits, against 341 for the nearest wrong one. Without detection, the simpler path was the stronger one.

## What to do next time

- Before measuring an image-processing step on a new kind of input, write down its geometric limits (separation, area, aspect) and check them against the input's framing. Predict the result, then measure it.
- When a secondary comparison comes out at zero or 100%, rescore one or two cases by hand before treating it as a bug, or as a finding.
- Don't assume detection improves on a fixed crop when the framing is controlled (a guide box). Measure the crop first.

## Signals to watch for

A detector or threshold carried over from a different capture path. Constants expressed as fractions of the image. A secondary figure at an extreme value.
