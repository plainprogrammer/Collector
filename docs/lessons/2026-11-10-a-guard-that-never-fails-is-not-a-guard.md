---
date: 2026-11-10
spec: 062
tags: [testing, guards, upgrade, seeds]
---

# Lesson: a guard that never fails is not a guard

## Context

`spec/script/upgrade/seeds_spec.rb` has an example "fills every table db/schema.rb creates": the upgrade proof's seed (`script/upgrade/seeds/next.rb`) must put a row in every table the schema creates, or the table is listed in `script/upgrade/seed_exceptions.yml` with a reason. Spec 062 added the `decks` table, so the guard should have failed until the seed created a deck.

## What happened

It did not fail. The implementer of the migration task found that the example passed whether or not the seed filled `decks`, and that a listed exception even reported "lists decks, which has no such table" while the table existed. Active Record's connection returns rows as hashes, and `Upgrade::Compare` read them as name/value pairs, so the rule saw no tables at all. The guard had passed vacuously since it was written, whatever the seed left empty.

## The fix

The example now sets `results_as_hash = false` around the call, so the comparison sees real rows. With that, it fails without the `decks` exception entry and passes with it, and T4 replaced the entry with a seeded deck and a lot in a zone.

## What to do next time

- Prove a guard can fail the day you write it: break the thing it guards once and watch it go red (several core-names-no-collectible guards already do this with a temporary identifier-shaped name).
- When a new table, column or constant is the first thing a guard has had to say anything about, run the guard against its absence before relying on its silence.
- A guard that lists exceptions should also check each exception names something that exists; here that check is what exposed the vacuity.
