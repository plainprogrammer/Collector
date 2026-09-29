---
scope: tech-stack
loaded-by: sdd-brainstorm, sdd-specify, sdd-plan, sdd-execute, sdd-review
---

# Tech Stack

## Languages
Ruby (latest stable supported by Rails 8.x), pinned via `.ruby-version`. Minimal JavaScript via Stimulus.

## Frameworks
- Ruby on Rails 8.x (latest)
- Hotwire: Turbo (Drive/Frames/Streams, morphing) + Stimulus
- Asset pipeline: Propshaft + importmap (no Node toolchain)
- Solid Queue (jobs), Solid Cache (cache), Solid Cable (Action Cable) — chosen to keep moving parts to a minimum

## Data
- SQLite for all environments, including production; separate DB files for primary, queue, cache, cable under `storage/`
- External catalog data: Scryfall (bulk data, cached locally) for Magic: The Gathering

## Infrastructure
Self-hostable: single-host deployment via the Rails-generated Dockerfile (Kamal optional); SQLite on a persistent volume. [Edit to match reality]

## Package Manager
Bundler (`Gemfile` / `Gemfile.lock` checked in); importmap for JS pins.

## Tooling
RSpec, FactoryBot, WebMock/VCR, RuboCop (`rubocop-rails-omakase` + `rubocop-rspec`), Brakeman, bundler-audit, `bin/ci` as the local CI entrypoint.
