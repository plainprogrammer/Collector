---
date: 2026-10-12
spec: "020"
tags: [verification, records, subagents, counting]
---

# Lesson: List one row per claim when a sweep's counts must match its lists

## Context

Spec 020's record had to list every README claim that couldn't be checked, and its per-section table had to add up: claims = checked + not checkable + off-limits.

## What happened

Each checker returned a summary table of counts and separate lists. One checker counted seven not-checkable claims in the Kamal section and listed six, because it had put two claims from one line ("Kamal needs registry credentials even to pull a public image" and "use a GitHub token with `read:packages`") into a single row. The implementer writing the record noticed that 31 listed against 32 counted, refused to guess which claim was missing and stopped. Both of my guesses at the seventh claim were wrong; only the checker knew, and resuming it took one message.

## What to do next time

In a sweep brief, say that every list has exactly one row per counted claim and that a sentence holding two claims gets two rows, and ask each checker to verify its own counts against its row counts before replying. Have the unit that assembles the record check counts against lists first, and send a mismatch back to the checker that made it.

## Signals to watch for

- A count column with no rule tying it to a list.
- A list row whose quoted text contains "and" or a colon joining two statements.
- An assembler asked to merge findings it can't re-derive.
