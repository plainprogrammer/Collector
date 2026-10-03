---
date: 2026-10-02
spec: "008"
tags: [card-scanner, spike, planning, measurement, tooling]
---

# Lesson: A derived input that matches the shipped geometry lets a spike reuse the app unchanged

## Context

Spec 008 measures whether card detection improves the scanner's photo path. To isolate what detection adds, everything after straightening must be the shipped reading chain (strips, OCR, parser, matcher) at its frozen settings, and the spec forbids changes under `app/`, `lib/` and `script/`.

## What happened

- The obvious design, feeding a straightened card to the reading code directly, would have meant new entry points in the app. Instead the plan pads the straightened card into a **3:4 picture at 80% of the height**, which is exactly where the shipped photo path's guide lands (`geometry.js`: `STAGE_ASPECT = 3/4`, `GUIDE.height = 0.8`, 63:88). The shipped picker, strips, measurement mode, `photo_run.rb` and `scanner:findings` then run on it as they stand, through the environment seams they already have (`COLLECTOR_SCANNER_MANIFEST`, `COLLECTOR_SCANNER_RUN_DIR`, `GROUND_TRUTH`).
- Three explorers traced the path before planning and found the only constraints: file names must match `/\A[\w-][\w.-]*\z/`, photos must sit beside the manifest, the file's type is sniffed from bytes (so `.png` works), and a run directory is keyed by file name (so each run needs a fresh one). The plan review then confirmed the geometry: a 1008×1408 card in a 1320×1760 picture lands at (156, 176).
- Not-found photos can't go through the picker, so they're scored as empty readings by calling the shipped `rescore` with blank text, which keeps the denominators honest without special cases in the app.

## What to do next time

- When a spike must use shipped code "as it stands", look first for its environment seams and its input geometry, and design the spike's output to match them exactly. Prove the match with numbers (where the guide lands) before writing the spike.
- Reuse the shipped scoring functions from spike code rather than their report wrapper, which is shaped for its own fixtures.
- Keep the spike's own naming honest (`IMG_6688.png` holding a PNG) and map back to the original keys in the fixtures.

## Signals to watch for

- A plan that adds a flag or an entry point to the app "just for the spike".
- A derived picture whose size or framing isn't checked against the consumer's geometry constants.
- Shipped tooling that hard-codes a corpus path, a run name or a fixture prefix (ask whether the environment can override it before changing it).
