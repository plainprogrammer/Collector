---
date: 2026-11-09
spec: 054 (#103)
tags: [plans, review, process]
---

# Lesson: have the plan review trace the plan's code against the library's source, not only the repo's files

## Context

Spec 054's plan held about 300 lines of new Ruby (a YARD extension, its specs and a fixture) written against YARD's internals. The first plan review (Fable, read-only, "trace, don't run") was pointed at the repository's files and also at a copy of the YARD source in a scratch directory.

## What happened

The review traced the plan to a blocking bug and six major ones before any code existed: a fixture file that YARD's own glob turned into a page, so the expected GitHub URL could never appear; the extension loading twice (YARD parses its options again for its statistics) and printing constant-redefinition warnings on every run; a `grep` expectation that missed the `../` YARD puts in links from a namespaced class page; and rubocop cops (`RSpec/SpecFilePathFormat`, `RSpec/MultipleExpectations`) that the new spec files would have tripped. A second round, scoped to "verify the fixes and what they introduced", found one more missed `:aggregate_failures`. The implementers then ran every task green on the first pass with no code corrections.

## What to do next time

When a plan's code depends on a library's internals, give the plan reviewer the library's source (a read-only copy, with its path in the brief) and ask for hand traces of the real call paths and of each expected string; ask for the repository's lint cops by name. Keep the second round narrow: the fixes and what they introduced.

## Signals to watch for

- A plan whose test expectations quote strings a library generates, with no one having read the generator.
- A review brief that lists only repository files.
- Implementers reporting "plan code needed a correction" more than once per phase.
