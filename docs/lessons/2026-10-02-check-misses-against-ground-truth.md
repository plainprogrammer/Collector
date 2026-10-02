---
date: 2026-10-02
spec: "007"
tags: [card-scanner, measurement, ground-truth]
---

# Lesson: A miss that reads perfectly may be a ground-truth error

## Context

Spec 007's live re-measure on a new corpus of 49 cards (`research.md` §5). The maintainer wrote the manifest by hand, and ground truth was built from it against the catalog.

## What happened

- The first scoring run showed 5 live misses. In one of them, IMG_6763, the name strip read "Leyline Immersion" cleanly, but the expected card was "Sram, Senior Edificer".
- The photo showed Leyline Immersion, `mat 71`. The manifest said `mul 71`, a one-letter slip in the set code. The scanner had been right.
- Before capture, the ground-truth build had already flagged three rows: List reprints entered as `list 132` instead of `plst PCY-132`. A pair check against earlier corpora found two printings already in Phase 0's corpus.
- In all, 5 of 51 rows needed fixing and 2 were dropped. None of these was a scanner problem.

## What to do next time

- Before a measured run: resolve the manifest, check it for overlap with earlier corpora, and confirm each photo file exists (memory: verify-corpus-manifests).
- When writing up misses, view each miss's strips first. If the strip shows a different card read cleanly, check the manifest against the photo before blaming the scanner.
- Record any manifest correction as a `Ruling:` and in the findings' method section, so the numbers can be traced.

## Signals to watch for

- A miss with a clean, confident read of a real card name that isn't the expected one.
- Ground-truth errors (`none` or `ambiguous`) on sets with unusual numbering: The List, Secret Lair, promos.
