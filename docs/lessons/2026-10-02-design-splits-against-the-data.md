---
date: 2026-10-02
spec: "008"
tags: [card-scanner, measurement, spec-review, held-out]
---

# Lesson: Design a held-out split against the data, not the rule

## Context

Spec 008 (the Phase 2 spike) splits the 99 stored photos into a development half for tuning and a held-out half for the headline rates, because spec 007 had shown that cards used for tuning give inflated numbers. The brainstorm chose a plain rule, "odd manifest rows develop, even rows held out", and the maintainer approved it.

## What happened

- The PRD review computed the split from the manifests: **15 of the 20 foils landed in the held-out half**, and foils are the scanner's weakest group. Tuning would have seen 5 foils and the headline would have been measured mostly on them. The rule was replaced by one that alternates foils and non-foils separately (11 development, 9 held out).
- The spec review then found that **one card, Leyline Immersion `mat 71`, is in both corpora**, with one photo on each side of the new split, and recorded with two different eras (by release date in Phase 0's ground truth, by frame in the new manifest). The spec now forces that photo into development and scores the Phase 0 photo with the frame-based era.
- The plan review confirmed the final counts (52/47) and found that two same-name pairs in Phase 0 straddle the split with different artworks, which is harmless for art matching and mild for name matching; it is now disclosed rather than discovered later.

Each problem was invisible in the rule's wording and obvious the moment someone computed the split from the real manifests.

## What to do next time

- Before approving a split, compute it from the actual data and tabulate every group the findings will report by (era, foil, frame treatment, corpus). Stratify on the weak group.
- Check for the same item on both sides: the same printing, the same artwork, and the same name, each at the level the measurement works at.
- Write the rule so two people produce the same lists ("each group starts with development", "data rows not counting the header") and commit the resulting lists before tuning starts.
- Make reviewers recompute the split; it is cheap and it has caught something every time.

## Signals to watch for

- A split rule stated in words with no counts beside it.
- A corpus assembled in two sessions (cards can repeat across them).
- A ground truth whose "era" or other grouping field is derived differently in two places.
