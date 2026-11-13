---
date: 2026-11-13
spec: "085"
tags: [prices, contracts, failure-channel]
---

# Lesson: a failure channel must tell the consumer "absent" from "unreadable"

## Context

Spec 085, the price source contract. A source yields quotes and `Malformed` records; the daily refresh (#365) will read a price that has no quote as "gone", remove the current price and write an empty history row.

## What happened

The first draft's `Malformed` carried only a key and a message, so a price the source could not parse looked, to the refresh, the same as a price the file left empty. A refresh that deletes on absence would have deleted a price it failed to read, and written that deletion into history that can't be fetched again. The spec review found it in two steps: round 1 saw that a malformed price was indistinguishable from an absent one (so `Malformed` gained a `series`), and round 2 saw the same hole for a line unreadable as a whole (so a `Malformed` with no series, or no key, also got a stated meaning).

## What to do next time

When a contract has a reader that acts on absence (deletes, closes, marks gone), design the failure channel from that action backwards: a record for something that exists but couldn't be read must name what it was (here the series), and the contract's comment must say what each kind of failure means for absence. Put the reason in the contract's comment, because the next issue is built from it.

## Signals to watch for

A consumer that treats "no record" as "nothing there" while the producer also has a way to skip what it can't read; a `Malformed`, `Error` or `Skipped` value with no field saying which thing was skipped; a deletion that is recorded somewhere that can't be rebuilt.
