---
scope: tech-stack
loaded-by: sdd-brainstorm, sdd-specify, sdd-plan, sdd-execute, sdd-review
---

# Tech Stack

## Languages
Ruby 4.0.7, pinned via `.ruby-version`. Minimal JavaScript via Stimulus.

## Frameworks
- Ruby on Rails 8.1.4
- Hotwire: Turbo (Drive/Frames/Streams, morphing) + Stimulus
- Asset pipeline: Propshaft + importmap (no Node toolchain)
- Solid Queue (jobs), Solid Cache (cache), Solid Cable (Action Cable) — chosen to keep moving parts to a minimum

## Data
- SQLite for all environments, including production; separate DB files for primary, queue, cache, cable under `storage/`
- External catalog data: Scryfall (bulk data, cached locally) for Magic: The Gathering

## Infrastructure
Self-hostable; both paths build the Rails-generated `Dockerfile` (Thruster in front of Puma, non-root uid 1000, `db:prepare` on boot) and run Solid Queue inside Puma (`SOLID_QUEUE_IN_PUMA=true`):
- **Docker Compose** (`compose.yaml`, service `web`): requires `SECRET_KEY_BASE`; optional `COLLECTOR_PORT` (host port, default 3000 → container 8080); named volume `collector_storage` at `/rails/storage` holds all four production SQLite DBs; healthcheck on `/up`; no TLS (reverse proxy in front). Works with `docker compose` and `podman compose`.
- **Kamal 2.12.0** (`config/deploy.yml`, placeholder server/registry): secrets via `.kamal/secrets` (`RAILS_MASTER_KEY` from `config/master.key`, `KAMAL_REGISTRY_PASSWORD` from env); same `collector_storage:/rails/storage` volume.
- Local containers: Podman (no Docker on the dev machine); files stay Docker-compatible.
- CI: GitHub Actions runs `bin/ci`; Dependabot for bundler and github-actions.

## Package Manager
Bundler (`Gemfile` / `Gemfile.lock` checked in); importmap for JS pins.

## Tooling
RSpec, FactoryBot, WebMock/VCR, RuboCop (`rubocop-rails-omakase` + `rubocop-rspec`), Brakeman, bundler-audit, `bin/ci` as the local CI entrypoint.
