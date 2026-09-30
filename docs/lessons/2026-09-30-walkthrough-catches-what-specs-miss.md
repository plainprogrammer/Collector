---
date: 2026-09-30
spec: "004"
tags: [verification, ui, design-system, walkthrough]
---

# Lesson: A real-data walkthrough found bugs that 316 specs and three reviews missed

## Context

Feature 004 (design system, accounts, card page, collection grid) was implemented with TDD. It had 316 passing specs, a clean `bin/ci`, and three SDD Mode B reviews ending SPEC-ALIGNED. Screenshots for the PR were then captured from a dev server loaded with the full Scryfall English catalog, and every screenshot was actually looked at.

## What happened

The walkthrough found four real issues, all fixed test-first before the PR:

- **Duplicate image:** multi-face cards whose faces share one image (e.g. "Emeritus of Conflict // Lightning Bolt") showed that image twice. The specs used factory faces with distinct or empty images.
- **Stylized names:** English Secret Lair printings carry a stylized `printed_name` ("SERRA ANGEL"), which the "printed name when present" rule put on tiles. That rule came from a review-time ruling aimed at Japanese names, and the fixtures never had English printed names.
- **Wrapping codes:** `SET · number` wrapped mid-code in phone Printings rows. That needs real long set names and codes, which the fixtures didn't have.
- **Missing spacing:** forms sat directly under the page head. Nothing asserted spacing.

Also, the first refresh for the walkthrough filled the disk. The 80 GB host had a 15 GB root LV, the Fedora Server default, and that was only discovered here.

## What to do next time

- Treat "walk through the real app with real data and look at every screen" as a required step before the PR, not an optional part of the verification phase.
- Seed a realistic collection: several printings of one card, foils, multi-face cards and non-English printings.
- When a ruling changes displayed data (names, images), check it against real upstream records, not only factories.
- Check free disk space before a bulk catalog refresh.

## Signals to watch for

- Every check is green but no one has looked at the UI with production-like data.
- Rules about display names or images were written only against factories.
- A bulk download on a machine whose storage layout hasn't been checked.
