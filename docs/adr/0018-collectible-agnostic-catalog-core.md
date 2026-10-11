# 0018: A collectible-agnostic catalog core with per-type extensions

## Status

Accepted (recorded 2026-10-11, after the fact; decided in spec 002)

**Date:** 2026-10-11
**Feature:** 002-scryfall-catalog-search

## Context

Foundation principle 3 asks for a core that is independent of any single collectible type, and principle 4 treats external sources as unreliable. [Spec 002](../specs/002-scryfall-catalog-search/spec.md) built the catalog on both, with Magic: The Gathering as the only type. The boundary was recorded in `CLAUDE.md` and `.claude/rules/`, with no ADR. This one records it as the [north star](../north-star.md) is written, because comics are the second type and their source research is starting.

## Decision

`Catalog::` holds entries, sets, names and refresh runs for any collectible type. A type registers a source adapter that implements the `Catalog::Sources` contract, and its collecting vocabulary (finishes, conditions), in `config/initializers/catalog.rb`. A type keeps its own tables and code under its namespace (`MTG::`). Core code never names a collectible.

Catalog data is global. It changes only through a refresh that runs in a background job from the source's bulk data, and it is never fetched during a page render.

## Consequences

- A new type is added by writing an adapter, a vocabulary and its own tables, without changing the core.
- Pages work fully from the local copy when a source is down.
- The boundary has been exercised by one type only. Comics, whenever built, is its first real test, and the core may need to change when it meets a source shaped unlike Scryfall.
- `spec/admin_catalog_core_spec.rb` is the only automated guard that the core names no collectible, and it covers the admin catalog code only.
- A source must also pass the north star's "source terms allow hosting" rule before it is adopted.
