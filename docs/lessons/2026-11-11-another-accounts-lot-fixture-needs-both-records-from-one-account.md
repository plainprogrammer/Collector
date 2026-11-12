---
date: 2026-11-11
spec: 070 (#257)
tags: [testing, factories, tenancy, plans, reviews]
---

# Lesson: "another account's lot" can't be built from two factories that each make their own account

## Context

Spec 070's plan needed another account's free lot in five examples (the `Lot.free` spec, the `Lot::MoveIntoZone` spec, two in the `UseCopies` spec, the page examples and the "leaves the other account's lots as they were" example). The plan wrote each as `create(:lot, entry:, location: create(:location), …)`.

## What happened

- `spec/factories/lots.rb` gives a lot a new user's account and `spec/factories/locations.rb` gives a location another one. `Lot#location_is_the_accounts` (`app/models/lot.rb`) runs when a lot is created, so every one of these fixtures raises `RecordInvalid` before the example asserts anything.
- No existing spec used that shape. Plan review round 1 found it as the one blocking finding, by reading the validation behind the factory, not by running the plan; the two earliest tasks were the ones affected, and those commits are cherry-picked by another worker, so they had to be right before they were handed over.
- The fix is the shape the tenancy spec already used: build the account first and give both records to it.

## What to do next time

A fixture for another account's lot, deck proxy or location is `other = create(:user).account` and then every record built with `account: other`, the location and the lot alike. A reviewer finds the wrong shape by reading `Lot#location_is_the_accounts` and the two factories, so the plan should name the one helper or the one pattern in its Global Constraints and use it everywhere.

## Signals to watch for

- `create(:lot, …, location: create(:location))` or `create(:deck_proxy, …)` with a zone from another `create(:deck)`, without an `account:` on each.
- A tenancy example whose "other account" has no control example showing the same request works for its owner.
