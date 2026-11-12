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

## Again with two preloads of one association (spec 073, #50)

The card page gained a second reader of the lots' places: `Catalog::CardOverview#lots` preloads `location: :parent` and `Lot::FreeCopies#lots` preloads `:location`. With one placed lot, or with one deck, both issue the identical statement and the second is a query-cache hit that the counter skips, so the baseline run undercounts (19 against 20, then 26 against 27) while the page's real count is constant.

- The record was not the trap this time, the order of the ids was: the two IN lists must differ to defeat the cache. With priced lots both collaborators read in price order, so prices in reverse order did not help. The baseline that worked has one unpriced lot: the overview sorts NULL first, while `Lot::FreeCopies` reads in the order of the `lot_key` index, which puts it last. That depends on SQLite's index-order scan of `lots`; the example's comment says so, and it may need a new baseline if that plan changes.
- For the decks, the small run gets a deck that holds only a proxy of the card, so the zones' parent ids of the two preloads differ there too.
- The proof that the example can fail: swap `preload(parent: :deck)` for a per-row `Deck.find_by` and it fails (30 against 50).

When a page gains a second reader of an association another reader already loads, give the baseline run the same sets in different orders, not only different records, log both statements once to see that neither is a cache hit, and write in the comment what the order depends on.

