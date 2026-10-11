---
date: 2026-10-11
spec: "015"
tags: [specs, time, flaky-tests, pre-push]
---

# Lesson: A fixed date and a relative time in one example

## Context

A docs-only branch (the north star and roadmap, PR #33) was blocked at the pre-push gate by a failing request spec from spec 015: `spec/requests/admin/catalogs_spec.rb:64`, "lists the 5 most recent runs".

## What happened

The example created six runs at `(n + 2).days.ago` and one at a fixed time, `Time.utc(2026, 10, 9, 3, 15)`, then asserted that the fixed one came first. That was true on 9 October, when it was written, and stayed true for two days. From 11 October 03:15 UTC the newest relative run was newer than the fixed one, and the example failed on every branch, `main` included.

Nothing caught it earlier, because it passed on the day it was written, in the plan review that ran the code, in the Mode B review and in CI.

The fix was one line: `travel_to Time.utc(2026, 10, 9, 3, 25)` at the start of the example, as `spec/requests/admin/jobs_spec.rb` already does around its own fixed times.

## What to do next time

An example that uses a literal date must not also use a time relative to now, unless it pins the clock first. Either make every time relative, or `travel_to` a fixed moment and state every time against it. Running the code can't find this on the day it's written, so a plan or code review has to read for it.

## Signals to watch for

- `Time.utc(…)` or a date string in the same example as `.ago`, `.from_now` or `Time.current`.
- An assertion on a formatted date ("9 Oct 2026 03:15 UTC") that the example gets by fixing one record's time.
- A failure on an untouched spec whose expected and actual rows are simply in the other order.
- A suite that was green yesterday and fails today with no code change.
