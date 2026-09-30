---
date: 2026-09-30
spec: "004"
tags: [ci, flaky-tests, turbo, debugging]
---

# Lesson: Debugging a CI flake that won't reproduce locally

## Context

PR #5 (spec 004) failed CI once in a system spec that exercises the browser Back button after a search (`spec/system/quick_add_spec.rb`, run 36748308952). The same code had passed CI twice, and it passed locally every time.

## What happened

- **Evidence:** the failed log (`gh run view --log-failed`) and the uploaded screenshot artifact (`gh run download -n screenshots`) showed the page fully unchanged after Back: the URL had changed, but the results and the typed "bolt" were still there.
- **Ruled out:**
  - 20 isolated local runs.
  - 10 runs at 100% CPU.
  - Only later: the full suite with CI's exact seed, all green. The user asked for the seed check to come much earlier (see memory `reproduce-ci-with-seed`).
  - Reading Turbo's source ruled out ignored `popstate` events.
- **Instrumentation:** a throwaway scratch spec logging Turbo's events showed two restore paths: an immediate Back re-fetches, and a Back after about 10 ms renders a cached snapshot. It also turned up a real bug. The snapshot keeps typed form values, so Back left "bolt" in the search box. That was fixed test-first with a `url-sync` Stimulus controller.
- **The flake itself** was never reproduced. The tests were hardened to wait for Turbo to be idle before navigating, and the commit says plainly that this rests on a hypothesis. CI went green.
- **A second surprise:** during that work an implementer saw one full-suite failure it hadn't logged, and it could never be identified.
- **A third finding:** the waits exposed a Turbo accessibility bug. The restored snapshot can keep `busy`/`aria-busy`.

## What to do next time

- For a CI-only failure, work in this order:
  1. Read the failed log and download the screenshot artifact.
  2. Rerun the full suite with CI's seed.
  3. Loop the example in isolation, and under load.
  4. Instrument the framework's events in a scratch spec outside the repo.
- When the root cause can't be proven, fix the real bugs the investigation surfaces, test-first. Harden the test, and label the hardening as based on a hypothesis in the commit and to the user. Then watch the next CI runs.
- Save every full-suite run's output to a file (`bin/rspec > log`) so a failure is never lost.

## Signals to watch for

- A failure that exists only in CI.
- A screenshot showing that "nothing happened" after a navigation.
- Framework-managed async behaviour (Turbo visits, snapshot caches, frame navigation) sitting between a test action and its assertion.
