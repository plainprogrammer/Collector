---
date: 2026-11-06
issue: "#213"
tags: [testing, flaky, tenancy]
---

# Lesson: A leak check looks for what the leak would show, not for bare digits

## Context

Spec 032's AC-5.7 example (`spec/requests/locations_spec.rb`) proves another account's lot doesn't leak onto a collector's refused-removal page. It gave the other lot a quantity of 777 and checked `expect(response.body).not_to include("777")`.

## What happened

The example passed for weeks, then failed in RSpec shard 4/4 on two unrelated PRs (#211, docs only, and #212), with different seeds, while passing alone. The page also lists the collector's own lot, and its set code (`s<n>`), collector number (`<n>`) and catalog link (an id) come from factory sequences and the database. As the suite grew, shard 4 began creating several hundred records before this example, so the collector's own lot could print "777". One worker traced it to an id in a link, the coordinator to the collector number: both were right.

Fixed in #214: the example now pins its own lot's number to `777` (red before the change, every time) and checks for the forms a leak would take: the held quantities are exactly `×4`, the sentence says "holds 4 copies in 1 lot.", and the body has neither `×777` nor `777 cop`. A mutation (the own lot given 777 copies) fails all five checks.

## What to do next time

- A sentinel value in a whole-body `include` check collides with anything else on the page that can print it: sequences, ids, digests, tokens. Search for the rendered form (`×777`, `777 copies`), or scope the check to the elements that would hold the leak.
- When an example's correctness depends on a value not appearing by chance, pin that chance on purpose in the example so it can't pass for the wrong reason.

## Signals to watch for

- `not_to include("<number>")` or `not_to have_content("<number>")` against a whole page.
- One example failing in the same shard on several unrelated PRs, with different seeds, and passing alone: suspect a value that grows with the suite (sequences, ids) before suspecting the branches.
