---
date: 2026-11-06
spec: "027"
tags: [documentation, area-docs, freezing]
---

# Lesson: before freezing a spec whole, sweep its NFRs, not only its stories

## Context

Spec 027 slice C for tenancy and accounts (#106) was the last area doc to cover spec 004, so its index row went from "Frozen in part" to "Frozen".

## What happened

The frozen line and the index named stories, FRs and AC ranges. The implementation review found one bullet in no area doc: NFR Performance's "search stays under 500 ms with owned quantities added, for 5,000 lots". Collection and lots held the collection page's bar and catalog core held no bar at all.

## What to do next time

- Before the row says Frozen, list every Story, FR, NFR bullet, Error Scenarios row and Open Questions bullet of the spec and name the doc that holds each.
- Where a bullet crosses two areas, add it to the doc that holds the measured bars and name the other.
- Name NFRs in the frozen line's parts, not only stories and FRs.
