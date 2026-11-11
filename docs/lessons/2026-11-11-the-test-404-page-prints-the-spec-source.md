---
date: 2026-11-11
spec: 066 (#253)
tags: [testing, request-specs, tenancy]
---

# Lesson: the test environment's 404 page prints the spec's source lines

## Context

Spec 066 AC-1.2 needs "another account's deck is a 404 and nothing of it is shown". The request example created a second account's deck named "Theirs", requested its page and asserted the 404 body did not include "Theirs".

## What happened

- In the test environment a 404 from `find_by!` renders Rails' debug exception page, which prints the source lines around the failing code, and a request spec's own lines are in that trace. The literal `"Theirs"` in the example's source therefore appeared in the body on every iteration, and the `not_to include("Theirs")` failed for a reason that had nothing to do with leaking the other account's deck.
- The reverse is the dangerous case: a name that is absent from the page for the wrong reason makes an isolation check pass without proving anything.
- The implementer built the other deck's name at run time (`"Rival #{SecureRandom.hex(4)}"`) and asserted on that, so the name occurs in no source line.

## What to do next time

When a request example asserts that a body does not contain a name, build the name at run time (a sequence or a random suffix) rather than writing it as a literal in the spec, and keep a positive control in the same example (the same request for the owner's own deck shows the name). A tenancy 404 is better asserted on the status, with the body check as a second line.

## Signals to watch for

- A `not_to include("<literal>")` after a 404 in a request spec, where the literal also appears in the example's source.
- An isolation example that never shows the same data to its owner.
