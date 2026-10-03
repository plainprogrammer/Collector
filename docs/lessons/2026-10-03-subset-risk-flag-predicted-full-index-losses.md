---
date: 2026-10-03
spec: "008"
tags: [card-scanner, art-matching, measurement, spikes]
---

# Lesson: A margin-based risk band on a subset predicted the full index's losses

## Context

Feature 008 (card scanner Phase 2 spike): art matching measured first against a 598-artwork subset, then (spec v1.2.0) against the full 50,923-artwork index, with the same fingerprints.

## What happened

The subset findings flagged a correct match as at risk if its right-artwork distance was at or above 296 bits, the smallest distance between two indexed artworks. Seven held-out matches were flagged. Against an index 85 times larger, held-out right-artwork-first went from 34/47 to 33/47, and development from 49/52 to 46/52. Every lost match had a right distance of 330 bits or more. No match nearer than 296 bits was lost, and 6 of the 7 flagged held-out matches held. The full fetch and build (about 2.6 hours of fetching and 18 minutes of fingerprinting) confirmed what the risk band had predicted.

## What to do next time

When a full-size measurement is costly, measure a random subset that contains every test item, and report a margin-based risk band (correct matches whose distance is at or above the smallest gap in the index). Treat the band as the expected upper bound on losses at full size when deciding whether the full measurement must come before a build decision. Still run the full measurement before committing other people's instances to its costs.

## Signals to watch for

"The subset flatters these rates" arguments. A costly full fetch or build waiting on a go/no-go decision. Nearest-neighbour matching whose index will grow by orders of magnitude.
