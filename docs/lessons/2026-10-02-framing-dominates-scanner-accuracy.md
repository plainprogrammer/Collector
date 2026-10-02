---
date: 2026-10-02
spec: "007"
tags: [card-scanner, ocr, matching, product]
---

# Lesson: Framing dominates card-scanner accuracy, and a confident collector line can be wrong

## Context

Spec 007 findings (`docs/specs/007-card-scanner-live-capture/research.md`), 2026-10-01/02: live tuning captures on 12 cards, a photo replay of Phase 0's 50 unguided photos, and Phase 0's OCR text re-scored with the new matcher.

## What happened

- **Framing explained most of the result.**
  - Once the name strip framed the name bar on live, guided captures, names went from 0/10 to 11/12 in the name-only top 3.
  - On Phase 0's unguided photos, the same guide-relative strips missed mostly through misalignment: 21 of 26 misses, with 14/50 in the name-only top 3.
- **The parser and matcher fixes alone** doubled the exact printing on the same OCR text, from 7/45 to 15/45.
- **A misread collector line can be confidently wrong.** `178/184 C` lost its `178/` and parsed as AER 184, a real but different printing. Because a unique collector-line match ranks first (AC-3.2), it pushed the correct name match down.
- **The unbiased re-measure held up (added 2026-10-02).** On 49 new cards that played no part in tuning, live capture had the right card first for 42/49 and the exact printing for 34/44. The biased tuning rounds had suggested 9–10 of 12. Misread collector numbers produced the wrong card first 3 times in 49.
- **The photo path fails in both directions.** Phase 0's photos had the card too small for the guide (69–77% of the frame), giving 24/50 in the top 3. The new corpus's photos had it too large (about 95%), giving 2/49. A fixed guide on an unguided photo only works by luck.

## What to do next time

- For the confirm-flow spec, show the collector-line match and the top name match side by side when they disagree, or rank a strong name match above a collector-line match. Don't assume a unique collector-line match is right.
- For any photo path without live alignment (the photo picker, careless framing), plan card detection or rectification (Phase 2), rather than expecting fixed strips to work.
- Measure framing first, by looking at the stored strips, before tuning OCR settings.
- Get an unbiased number before deciding: a fresh corpus that played no part in tuning, captured at frozen settings. It took about an hour and settled the direction (the confirm flow, ruled 2026-10-02).

## Signals to watch for

- A scanned card whose collector-line match names a different card from the name strip.
- Misses whose strips show art or rules text instead of the name bar or collector line.
