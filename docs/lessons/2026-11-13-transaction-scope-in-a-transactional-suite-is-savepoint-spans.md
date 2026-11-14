---
date: 2026-11-13
spec: 089 (#365)
tags: [testing, transactions, sqlite]
---

# Lesson: in a transactional suite, measure savepoint spans, not transaction depth

## Context

Spec 089 AC-4.4 first said that every write to the price tables is at transaction depth 1 and every write to the run row at depth 0, "counted through the connection's open transactions".

## What happened

The suite wraps each example in a non-joinable fixture transaction, so every `update!` or `create!` outside an explicit transaction opens a savepoint of its own: a run-row write and a batch's write both read depth 1, and depth could not tell them apart (a plan review found it by reading Active Record). The proof that holds cuts the connection's `sql.active_record` statements into spans from `SAVEPOINT` to its `RELEASE` or `ROLLBACK TO`, and asserts what each span contains. Rails opens the savepoint lazily, at the transaction's first statement on that connection, so "no read of the other database inside a transaction" has to compare that connection's open transactions to a baseline taken before the run: a read made before the first statement is in no span, and a first version of the check passed on a deliberately wrong implementation.

## What to do next time

- Specify and write a transaction-scope proof as spans of statements, and prove each assertion can fail by breaking the property in a throwaway way (a write outside the transaction; a read of the other database inside it) before trusting it.
- Never assert a depth in a spec that runs under transactional fixtures.

## Signals to watch for

- An acceptance criterion that says "at depth N", or a check that counts `open_transactions` without a baseline.
