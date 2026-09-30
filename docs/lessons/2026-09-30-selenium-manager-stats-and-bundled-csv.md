---
date: 2026-09-30
spec: "005"
tags: [selenium, privacy, ruby-4, bundler, gems]
---

# Lesson: Selenium Manager phones home, and `csv` isn't loadable without the Gemfile on Ruby 4

## Context

Spec 005 (card scanner Phase 0). The camera spike used Selenium with Chrome and Firefox, and the ground-truth builder was planned around Ruby's `csv`. The spike wasn't allowed to change the `Gemfile` (AC-4.5).

## What happened

- **Selenium Manager's telemetry.** When Selenium Manager resolved drivers and downloaded Chrome for Testing, it tried to POST usage stats to `plausible.io` ("Error sending stats to Plausible"). It failed here, but it is an outbound call from a test run in a project with a privacy rule of "no other hosts" and a no-real-network test policy. Setting `SE_AVOID_STATS=true` turns it off.
- **`csv` is a bundled gem.** Since Ruby 3.4, `csv` is a bundled gem rather than a default gem. Under Bundler, `require "csv"` raises `LoadError` unless `csv` is in the `Gemfile`. The plan review caught this before execution, and the manifest parser became a comma split, since the manifest has no quoted values.

## What to do next time

- For any Selenium or Capybara run, set `SE_AVOID_STATS=true`, locally and in CI if Selenium Manager is ever used there. The app's existing system specs use the preinstalled geckodriver path, but a new browser (Chrome for Testing) goes through Selenium Manager.
- Before a plan relies on a stdlib library, check it loads under the bundle: `bundle exec ruby -e 'require "x"'`. On Ruby 4, `csv`, `base64`, `bigdecimal`, `mutex_m` and others are bundled gems. Either add the gem (if the Gemfile may change) or avoid the library.

## Signals to watch for

- "Error sending stats to Plausible" in a test log.
- A plan step that says `require "csv"` (or another former default gem) in code that runs under Bundler.
- Any new browser driver introduced into specs.
