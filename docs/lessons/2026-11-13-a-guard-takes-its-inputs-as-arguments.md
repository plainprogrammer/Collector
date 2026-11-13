---
date: 2026-11-13
spec: 087 (#376)
tags: [guards, testing, ci]
---

# Lesson: a guard that takes its inputs as arguments can be shown to fail

## Context

Spec 087 keeps a list of third-party components from going stale with a guard spec: a manifest, the gems, the importmap pins, the font and icon files and the pinned engine digests must agree.

## What happened

`Collector::ThirdPartyLicences::Audit` takes every input as an argument and returns the problems it finds. Each rule has a fixture that fails naming the offender and a baseline that passes (AC-5.7), and the repository's own spec only asserts that `problems` is empty on the real files, so a guard that stopped checking would fail its own spec. The implementation review still found two holes: an emptiness check written as `entry[field].to_s.strip.empty?` passed `spdx: []`, because `[].to_s` is `"[]"`, and `if entry["texts"]` is truthy for `[]`.

## What to do next time

- Build the next guard as an object that takes its inputs, with a failing fixture per rule.
- Write a presence check for a list as a check on the list (`Array(value).any?`), and give every rule a fixture with an empty value as well as a missing one.

## Signals to watch for

- A guard spec that only runs against the real repository.
- `to_s.strip.empty?` or a bare truthiness test on a field that can be an array.
