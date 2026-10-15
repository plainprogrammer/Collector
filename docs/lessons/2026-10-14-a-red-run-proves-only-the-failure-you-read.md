---
date: 2026-10-14
spec: "024"
tags: [testing, tdd, plans, verification, review]
---

# Lesson: A red run proves only the failure you read

## Context

Spec 024 (issue #78): a refresh or art build that starts while another job's retry waits in the queue is skipped. The plan was made by applying the whole change uncommitted, running the new examples without the code (red) and with it (green), then replaying that phase by phase.

## What happened

- **The issue's probe was red for the wrong reason at first.** The probe queues a refresh job to run later, then runs two more refreshes and expects no request to Scryfall's `/bulk-data`. Its first draft stubbed `/bulk-data` with no response, so WebMock answered 200 with an empty body. The run failed with `JSON::ParserError: unexpected end of input` inside `MTG::Scryfall::Client#get_json`. That isn't the issue: the issue is that the source gets asked at all inside a rate-limit window. Only after the stub answered as the issue describes (`429`, `Retry-After: 600`) did the failure read "GET https://api.scryfall.com/bulk-data was not expected to execute but it executed 2 times".
- **A red was almost recorded without being seen.** The art build's probe was counted among the failures, but its message hadn't been read when `verification.md` was being written. On a check, it failed as expected (the build `finished` instead of `skipped`, and the image was requested). Before that check the record would have been an assumption.
- **The Red lists mixed guards with red tests.** Four of the plan's "Red" examples (another type's job waiting, the starting job's own job waiting, two "already running" cases) pass before the change. They guard behaviour the change must keep. The plan reviewer flagged that someone replaying the plan would expect them red. The plan's failure count (10, later 11) was right; the lists didn't say which examples it excluded.

## What to do next time

1. Give a probe's stubs the response the issue describes (status, headers, body), not the default empty 200. Otherwise the run can fail on parsing before it reaches the behaviour under test.
2. For every example counted as red, read its failure message and check it names the issue's symptom. Quote that message in the plan or `verification.md`. Don't record a red you only inferred from the failure count.
3. In a plan's Red list, label each example that passes before the change "(guard, passes before)". State the expected failure count, and say which examples it covers.

## Signals to watch for

- A red failure inside a parser, a factory or a stub helper, rather than in the expectation the example was written for.
- `stub_request(...)` with no `.to_return` in a probe that is about how the app reacts to an answer.
- A Red list whose length differs from the failure count the plan states.
- Writing "failed as expected" in `verification.md` for an example whose output you never printed.
