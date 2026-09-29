---
date: 2026-09-29
spec: "002"
tags: [catalog, scryfall, performance, sqlite, baseline]
---

# Lesson: Catalog refresh and search baseline on real Scryfall data

## Context

Feature 002, Phase 8 manual NFR checks in development (SQLite, Solid Queue in Puma, dev machine), 2026-09-29.

## What happened

- English refresh (`default_cards`): 106,636 printings inserted, 0 malformed, 69 s wall, 236 MB max RSS.
- Immediate re-run of the same file: seen 106,636, 0 inserted/updated/retired, 17 s, 328 MB — the digest-based change detection writes nothing.
- English + Japanese (`all_cards`): seen 169,317, inserted 62,681 (Japanese), 0 English rows rewritten, 74 s, 413 MB.
- Search on the full EN+JA catalog: model-level 4–40 ms per query ("forest" worst); HTTP 275–370 ms server time, dominated by ActiveRecord (the set-filter list query over all entries). Detail page 34 ms, printings page 91 ms.

## What to do next time

Treat these as the regression baseline for catalog work. If search needs to get faster, look first at the set-options query (`Catalog::Set.with_searchable_entries`), e.g. caching it per refresh. Switching `default_cards` ↔ `all_cards` rewrites no English rows because the digests match.

## Signals to watch for

Refresh time or RSS far above these numbers; a no-op re-run that reports updates; search pages drifting toward the 500 ms NFR as more languages or collectible types are added.
