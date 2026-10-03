---
name: shipped-percentile-upper-middle
description: Collector::ScannerFindings.percentile(values, 50) returns the upper-middle value for even counts; the 008 spike uses its own conventional CardScannerPhase2.median
metadata:
  type: project
---

`Collector::ScannerFindings.percentile(values, 50)` (`lib/collector/scanner_findings.rb:37`, shipped in spec 007) returns the upper-middle value for even-sized samples (`sorted[(0.5 * (n - 1)).round]`), not the mean of the two middle values. The spec 008 spike now uses its own conventional `CardScannerPhase2.median` (`07cc753`). Before that, the upper-middle rule put 14 even-count figures in research.md a few units high, and the Mode B review caught it.

**Why:** Mixing the two rules gives medians that disagree with any hand recomputation. In the 008 session a subagent brief said 211 where the score file said 219.

**How to apply:** When spec 009 or later scoring reports medians, use one conventional median helper and state the convention in the findings' method section. Don't change `lib/` from a spike branch whose scope rule (like 008's AC-5.6) forbids it. Related: [[card-scanner-direction]], [[verify-corpus-manifests]].
