---
date: 2026-10-02
spec: "007"
tags: [card-scanner, ocr, tuning, measurement, testing]
---

# Lesson: Tune OCR on stored strips, and keep synthetic test text independent of the tuned geometry

## Context

Spec 007, Phase 10, 2026-10-01: tuning the scanner's strip geometry and OCR settings on 12 cards outside the corpus, captured live on the maintainer's iPhone (Brave), 4 rounds.

## What happened

- **Desktop replays are trustworthy.** Measurement mode stores each capture's strips. Replaying them on the desktop through the same recognition code (`script/scanner/replay.rb`, headless Firefox) reproduced the iPhone's OCR text exactly. The only difference was line endings, `\n` vs `\r\n` from multipart posts.
- **That made settings cheap to choose,** with no capture round from the maintainer:
  - Name-strip page segmentation: psm 6 put 10/10 names in the top 3, against 4/10 for psm 7.
  - Collector strip: inverting its dark rows turned light-on-black lines into dark-on-light, lifting exact printing 6/9 → 8/9 on stored strips. Otsu binarizing made it worse, and so did inverting the name strip.
- **Geometry still needed live rounds.** Replays can't re-cut strips, so the first round's misframed name strip (names clipped at its bottom edge, 0/10 read) needed a fresh capture after the fix.
- **Fresh rounds show where tuning stops.** Rounds 3 and 4 differed only by photo-to-photo OCR variance. A sharp name read as `el Tae.`, and `257` read as `287`. More tuning on 12 cards would have chased noise.
- **A test fixture can couple to the thing being tuned.** The synthetic test card sized its text from the strip boxes. When the collector strip got taller, the drawn text grew and OCR misread it (`R0O123`), failing a spec. Sizing the text from the card fixed it, and is closer to a real card.

## What to do next time

- Store what OCR actually read (the strips after preprocessing) for every measured capture.
- Tune recognition-stage settings on desktop replays, and spend capture rounds only on geometry changes and on confirming the chosen settings on fresh photos.
- Stop tuning when fresh rounds stop differing beyond capture variance, and say so in the freeze commit.
- Size synthetic test images from the physical object, never from the parameters under tuning.
- Normalise line endings before comparing texts that crossed a form post.

## Signals to watch for

- A desktop replay that doesn't match the device's text (beyond line endings): the replay is no longer a valid proxy.
- A spec that breaks when only a tuning constant changed: check whether the fixture depends on that constant.
