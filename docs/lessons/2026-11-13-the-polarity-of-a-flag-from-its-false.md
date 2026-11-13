---
date: 2026-11-13
spec: "085"
tags: [prices, flags, rulings]
---

# Lesson: take a boolean's polarity from what its `false` switches off

## Context

Spec 085, the price source contract. The source states `hosted_paid_allowed?`: whether a hosted instance with paid plans may show its prices. The design says an instance refuses a source its kind of instance may not show.

## What happened

The draft set Scryfall's flag to `false`, reasoning from the rulings that prices are never put behind payment. The spec review read it the other way: the flag means "may be shown on a hosted instance with paid plans", rulings 27, 37 and 38 allow that while prices stay public, and `false` would make the later refusal switch Scryfall's prices off on the hosted service. The maintainer ruled `true`.

## What to do next time

Before setting a flag from a ruling, write the sentence "when this is false, the instance does X" using the consumer's behaviour, and check X against the rulings. A rule about a display (never a paywall) is not the same rule as a rule about a source (may be shown at all). Keep the value in one place with its own example, so a ruling that changes it is a one-line change.

## Signals to watch for

A flag named for an ability ("allowed", "enabled") whose value was reasoned from a prohibition; a flag with no consumer yet, so nothing exercises its meaning; a ruling that says "while X" (a condition) that the flag's name doesn't carry.
