---
date: 2026-09-29
spec: "002"
tags: [rspec, rails, ruby-4, sqlite, multi-database, tooling]
---

# Lesson: Rails 8.1 / Ruby 4 test-harness gotchas

## Context

Feature 002 (Scryfall catalog), plan review and execution across Phases 2–8.

## What happened

- rspec-rails does not include `ActiveSupport::Testing::TimeHelpers`, so `travel`/`freeze_time` raised `NoMethodError` until `spec/support/time_helpers.rb` included them.
- In this multi-database app, `bin/rails db:migrate:redo STEP=2` is refused; `db:migrate:redo:primary STEP=2` works.
- `bin/rails db:migrate` rewrites `db/cable_schema.rb`, `db/cache_schema.rb` and `db/queue_schema.rb` (header comment and version only).
- `benchmark` is no longer a default gem in Ruby 4, so `require "benchmark"` in `bin/rails runner` fails. Use `Process.clock_gettime(Process::CLOCK_MONOTONIC)`.
- `Fugit` is loaded by the Solid Queue supervisor, not in the test env; specs that parse schedules need `require "fugit"`.
- With `RSpec: Enabled: true`, `RSpec/ExampleLength` (max 5) failed 22 integration-style examples; the project now sets max 15 with a comment.

## What to do next time

Include TimeHelpers in spec support before writing time-dependent specs; use `:primary`-suffixed db tasks; restore the three secondary schema files with `git checkout --` rather than committing header churn; time things with the monotonic clock; require `fugit` explicitly in specs; keep examples ≤ 15 lines.

## Signals to watch for

`NoMethodError: travel`; "redo is not supported for multiple databases"; unexpected diffs in `db/*_schema.rb`; `cannot load such file -- benchmark`; `uninitialized constant Fugit`; RuboCop `RSpec/ExampleLength` offenses.
