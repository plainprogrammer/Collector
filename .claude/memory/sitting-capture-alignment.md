---
name: sitting-capture-alignment
description: Measurement-mode sittings drift from the manifest when a card is re-scanned; check first-capture name text per row before scoring, and say "scan and add" explicitly
metadata:
  type: project
---

In spec 011's sitting (2026-10-08) two things went wrong:
- **The manifest drifted from the cards.** Rows IMG_6835–6837 got a first capture of the previous card: the manifest advanced while the previous card was scanned again. The raw report said 31/35 right card first; scored on each row's own card it was 34/35. `ArtSittingReport` now takes `CAPTURES="IMG_6835.jpeg=2,…"` to score a row on another capture.
- **The cards were scanned but not added.** That left AC-9.2's add-based outcomes (right first time, corrections, time per card) unmeasurable, so the maintainer ruled to score as-is.

**Why:** both cost measured figures. The first nearly reported three false "confident wrong" matches.

**How to apply:**
- Before scoring any sitting, list each row's first-capture name text beside the expected card and look for runs where it matches the previous row.
- When briefing a device sitting, give "add each card" its own step, and say what is lost without it.

Related: [[device-sitting-account-check]], [[verify-corpus-manifests]].
