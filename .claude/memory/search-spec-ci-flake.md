---
name: search-spec-ci-flake
description: Open follow-up - spec/system/catalog_search_spec.rb:4 intermittently times out on GitHub CI opening a card page; cause unknown
metadata:
  type: project
---

`spec/system/catalog_search_spec.rb:4` ("Card search finds a card and opens a printing") fails intermittently on GitHub Actions only. It never fails locally, not even pinned to one core with a CPU hog.

- **Seen:**
  - On `main` after the PR #6 merge (run 36793202581, seed 14482).
  - On PR #7 (run 36882235200, seed 4155). Re-running only the failed job passed.
- **Symptom:** after `click_link "Lightning Bolt"`, the check `have_css("h1", text: "Lightning Bolt")` times out at Capybara's default 2 s wait. The CI screenshot shows the search page with Turbo's progress bar still running, so the card-page visit was in flight and slow, not wrong.
- **Ruled out (2026-10-01):**
  - Cold template compilation: the first card-page render takes about 55 ms locally with `CI=1`, which eager-loads.
  - The frame-advance Back race: this spec never goes back, and that race is fixed separately (see [[turbo-back-navigation-quirks]]).
- **Not yet checked:**
  - Whether a hover prefetch of the same link, or of other tile links, delays the click's visit.
  - SQLite or shared-connection contention in the Capybara server.
  - CI test-log timings: upload `log/test.log` as an artifact on failure.

**Why:** it is the remaining CI flake after PR #7, and it can block merges on unrelated branches.

**How to apply:**
- When it recurs, start from the failed run's seed and screenshot ([[reproduce-ci-with-seed]]), and add log or timing evidence before changing the test.
- Don't just raise `default_max_wait_time` without a root cause.
- Remove this memory once it's resolved.

Related: [[pr5-open-followups]].
