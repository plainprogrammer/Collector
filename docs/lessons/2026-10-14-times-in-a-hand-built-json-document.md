---
date: 2026-10-14
spec: "022"
tags: [time, json, testing, ruby]
---

# Lesson: Times in a hand-built JSON document

## Context

The export format requires every time as RFC 3339 in UTC, with `Z` and no fraction, and the fraction dropped rather than rounded. `CollectionExport` builds a Hash and calls `JSON.generate`.

## What happened

Three traps, each caught by a review or a test, not by reading the code:

1. **`JSON.generate` doesn't format a `TimeWithZone` the way you expect.** `pluck` returns `ActiveSupport::TimeWithZone` for `created_at`. Left in the Hash, it falls through to ActiveSupport's `to_json` and is written as `2026-10-14T12:00:00.000Z`, which the schema's time pattern rejects. The spec said "plain strings, integers and nil"; the second (Fable) spec review corrected it.
2. **`travel_to` drops microseconds by default.** The example meant to prove "fraction dropped, not rounded" created a lot at `11.999` inside `travel_to`, but the database stored `11.000`. So half the criterion tested nothing. The Opus plan review found it by running the code. The fix is `travel_to(time, with_usec: true)`.
3. **`Time#utc` converts the receiver in place.** `value.utc.iso8601` changed the caller's plain `Time` to UTC. It was harmless with `Time.current` (a `TimeWithZone`), but wrong for any other caller. The spec-alignment review found it, and the fix is `getutc`.

## What to do next time

- Format every time to its final string yourself before serialising. Never rely on a JSON library's fallback for a time.
- An example about sub-second behaviour uses `travel_to(…, with_usec: true)`, or sets the timestamp column directly, and asserts the stored value has the fraction.
- Use `getutc`, not `utc`, on a time you were given.

## Signals to watch for

- A `Time`, `TimeWithZone` or `DateTime` inside a Hash passed to `JSON.generate` or `to_json`.
- A criterion that says "dropped, not rounded", or names milliseconds, tested inside `travel_to`.
- `.utc` called on a method argument.
