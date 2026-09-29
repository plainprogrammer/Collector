---
date: 2026-09-29
spec: "001"
tags: [rails, rspec, solid-queue, tooling]
---

# Lesson: Rails 8.1.4 generator defaults that surprised the plan

## Context

Feature 001: `rails new . --database=sqlite3 --skip-test --force` on Ruby 4.0.7, then RSpec, rubocop-rspec, bin/ci.

## What happened

- `config/ci.rb` from `--skip-test` has no test step — a failing spec passed `bin/ci` until `step "Tests: RSpec", "bin/rspec"` was added.
- `rspec:install` leaves `infer_spec_type_from_file_location!` commented, so `spec/requests` files lack request helpers unless tagged `type: :request`.
- Production `assume_ssl`/`force_ssl` are commented out in 8.1.4 (plain HTTP works; no /up SSL exemption needed).
- Solid Queue stores the supervisor kind as `"Supervisor(fork)"`, so `where(kind: "Supervisor")` returns 0.
- rubocop-rspec's department-level `Enabled: true` doesn't enable pending cops; they must be listed.
- Dev defaults are async jobs + memory cache; mirroring prod needs database.yml, development.rb, cache.yml, cable.yml, and the puma Solid Queue plugin.

## What to do next time

Before planning against a generator, run it in a scratch dir and read the generated ci.rb, rails_helper, production.rb, and puma.rb. Tag spec types explicitly in this project. Query Solid Queue processes with `where("kind LIKE 'Supervisor%'")`.

## Signals to watch for

Planning code that assumes Rails defaults; CI that passes suspiciously; NameErrors for route helpers in request specs.
