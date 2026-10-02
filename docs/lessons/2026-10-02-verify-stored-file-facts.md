---
date: 2026-10-02
spec: "008"
tags: [card-scanner, findings, data, verification]
---

# Lesson: Verify stored-file facts with a tool before writing them into findings

## Context

Spec 007's findings described the two photo corpora: Phase 0's as "4032×3024, EXIF orientation 6" and the new corpus's as "3024×4032". Spec 008's PRD repeated those figures from the findings.

## What happened

- The PRD reviewer ran `magick identify` on the files: **the two were the other way round.** Phase 0's 50 files are stored 3024×4032 with orientation 1 (the rotation was applied when they were copied from the phone; their EXIF pixel-dimension tags still say 4032×3024); the new corpus's 51 files are stored 4032×3024 with orientation 6. Both display as portrait, and the only practical difference is which corpus relies on EXIF rotation, which matters for every tool the spike adds.
- The figure in spec 007's findings had been carried from spec 005's description of how the photos were *shot*, not checked against the files on disk. No rate or conclusion depended on it, but a spike tool that trusted it would have mishandled one corpus.
- Spec 007's `research.md` was corrected with a dated note; spec 005's wording ("shot as…") was left, since it may be true of the originals.

## What to do next time

- Any fact about stored files (size, orientation, format, count) goes into findings only after a tool has read every file: `magick identify`, `stat`, `ls | wc -l`. It takes seconds.
- When a fact is copied from an earlier document, re-check it rather than re-cite it, and say which was done.
- Count files and manifest rows separately when they can differ (the new corpus directory holds 51 files for 49 rows).

## Signals to watch for

- A dimension or orientation stated without saying how it was measured.
- Two corpora described with mirror-image figures.
- "Shot as" or "captured as" used where "stored as" is what the code will see.
