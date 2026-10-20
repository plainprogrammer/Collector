---
date: 2026-10-08
spec: "011"
tags: [measurement, performance, benchmarking]
---

# Lesson: Timing two code paths back to back favours the second

## Context

Spec 011's NFR asks how much the art evidence adds to the reading request's ranking time on the server (target ≤ 50 ms). `script/scanner/art_reading_time.rb` ranks each measured reading with text only and then with art, and compares medians.

## What happened

The first version timed text only, then art, once each per reading. It reported 71.4 ms text only and 17.3 ms with art: art looked 54 ms *faster*. The text-only run paid for cold caches (name index queries, catalog rows) that the art run then reused. With two warm-up rounds of both paths, and then interleaved timing in both orders (art, text, art, text), the figures were 8.7 and 13.0 ms (+4.3 ms), stable across runs.

## What to do next time

When comparing two paths over the same inputs, warm both first, then interleave and alternate the order, and report the spread across repeated runs. Treat a result where the path doing more work is faster as a measurement bug until shown otherwise.

## Signals to watch for

- A "with X" path that comes out faster than "without X".
- Timing loops that always run variant A before variant B.
- The first run of a script being much slower than later ones.
