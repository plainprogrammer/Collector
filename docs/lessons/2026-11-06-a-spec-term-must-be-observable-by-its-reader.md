---
date: 2026-11-06
spec: "043"
tags: [specification, catalog, source-contract]
---

# Lesson: A term the core must judge has to be observable from the core's own inputs

## Context

Spec 043 lets a rate-limited job's count start again when its attempt made progress, and each operation answers whether it did. The first draft listed "a downloaded file written into place" as part of a catalog refresh's progress, beside catalog rows written.

## What happened

The first spec review found the refresh (core code) can't tell a fresh download from a reused one. `Catalog::Sources#download` returns the verified file's path either way, and `MTG::Scryfall::Source` reports `(expected, expected)` through `#progress=` when it reuses the file, the same call a finished download makes. Telling them apart needed either a new optional hook in the source contract (and an area doc change) or a guess from file times.

Dropping the download was cheaper and lost nothing: the file is kept and the retry uses it again, so counting it would only have bought one extra fresh start. Refresh progress became "a catalog row written".

## What to do next time

- When a spec defines a term that core code evaluates ("progress", "changed", "fresh"), check, while writing it, that each case in the definition is visible in what the core receives: return values, recorded counts, its own writes. A case only the adapter can see is either a contract change, which is a spec decision, or it doesn't belong in the definition.
- Ask whether the case is worth a contract change at all: what does counting it buy?

## Signals to watch for

- A definition in a spec that names something an adapter does internally (a download, a cache hit, a retry inside a client).
