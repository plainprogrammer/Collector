---
date: 2026-11-13
spec: 081 (#363)
tags: [documentation, yard, ci]
---

# Lesson: the comment ratchet judges a block of one-line methods together

## Context

`bin/ci checks`' step "Docs: new and changed public code has a comment" (`script/yard/comment_ratchet.rb`, spec 056) fails a branch that adds or changes a public method with no summary. Spec 081 inserted methods among one-line methods: `def names = …`, `def primary = …` and `def prices = …` in `Databases`, and the `def … =` helpers in `spec/support/backup_helpers.rb`.

## What happened

- **One-liners counted as changed.** The ratchet counted untouched one-line neighbours as "changed", because the edit shifted or touched their lines.
- **Three rounds to green.** I added a summary to each method it named, and each run named the next neighbour. The step failed three times before the block was clean.

## What to do next time

- When an edit lands inside a run of one-line methods, give every method of that run a summary in the same commit. Then run `ruby script/yard/comment_ratchet.rb` (it takes seconds) before `bin/ci checks`.
- Tell implementers the same in a batch brief that touches such a block.

## Signals to watch for

- A diff that inserts or removes lines between `def x = …` methods.
- A ratchet failure naming a method the branch didn't mean to change.
