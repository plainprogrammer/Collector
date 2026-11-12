---
date: 2026-11-11
spec: 070 (#257)
tags: [testing, query-counts, request-specs, n-plus-one]
---

# Lesson: a statement-count example that compares 1 row with many must not share a record between the two runs

## Context

Spec 070 AC-2.7 says Use my copy's page runs the same number of statements for 1 lot and for 200 lots. The request example fetched the page with one lot, added more lots and fetched it again with `count_queries`.

## What happened

- The first run read 13 statements against 15, which looked like an N+1.
- It wasn't: the one lot shared the proxy's printing, so the request's query cache served that printing's entry and set reads in the first run (the cache ignores them, `count_queries` skips cached statements). The second run, with other printings, paid for them. The code was fine; the fixture hid the statements.
- The fix was in the example: the one-lot run uses a different printing from the proxy's, so both runs read the same kinds of rows. Mutating `preload(:location)` away then made the example fail (14 against 35), which showed it can.

## What to do next time

Build the one-row run of a statement-count example so it touches the same kinds of records as the many-row run (a printing other than the one the page already loads, a place of its own), warm the page once before counting, and prove the example can fail by removing one preload or `includes` from the code. A pair of counts that differs by 2 may be the cache, not the code.

## Signals to watch for

- A count example whose few-row case reuses a record the page itself loads (the proxy's printing, the account's one place).
- A difference of one or two statements between the two runs, with no loop in the code.
