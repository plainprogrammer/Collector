---
date: 2026-10-03
spec: "008"
tags: [sdd, spec, findings, statistics]
---

# Lesson: Define the statistics a spec asks for

## Context

Feature 008 (card scanner Phase 2 spike): research.md reported medians of art distances, timings and narrowing counts, and the Mode B implementation review checked them.

## What happened

The spec's acceptance criteria asked for medians but never defined one. Three spike scripts used `values.sort[values.size / 2]`, and the shipped `Collector::ScannerFindings.percentile(values, 50)` rounds to the upper middle. For every even-sized sample, the published median was the upper-middle value. The review recomputed them conventionally and found the difference, for example 219 / 386 bits where the conventional medians are 211 / 385.5. Fixing it took a code change (`07cc753`), 14 corrected cells in research.md and one in an ADR. No conclusion changed, but the published figures were wrong until then.

## What to do next time

When a spec's acceptance criteria name a statistic (median, percentile, rate, mean), define it in the spec's constraints or in the plan's shared helpers: the even-count rule for medians, the percentile method, and the denominator for rates. Every script computes it through that one helper, with a spec for odd, even, single and empty samples. State the convention in the findings' method section.

## Signals to watch for

"median", "p95" or "percentile" in an acceptance criterion. More than one script computing summary figures. A hand recomputation that disagrees with a tool's output by a small amount.
