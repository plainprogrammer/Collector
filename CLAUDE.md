# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering cards. The Rails app skeleton exists (stack, RSpec, `bin/ci`, Compose and Kamal deployment); no domain features yet. License: AGPL-3.0.

Mission and principles: `.claude/memory/foundation.md`. Detailed coding rules: `.claude/rules/`. Feature specs: `docs/specs/`.

## Stack

Ruby 4.0.7, Rails 8.1.4, SQLite in every environment (including production), Hotwire (Turbo + Stimulus), Propshaft + importmap (no Node toolchain), Solid Queue / Solid Cache / Solid Cable, RSpec + FactoryBot + Capybara, WebMock/VCR, RuboCop (`rubocop-rails-omakase` + `rubocop-rspec`), Brakeman, bundler-audit, Kamal 2.12.0.

## Commands

- Setup: `bin/setup` (idempotent; works in clones and worktrees, copies `.worktreeinclude` files from the main checkout, enables `.githooks/` auto-setup; starts the server afterwards, `--skip-server` to not)
- Run: `bin/dev` (just `bin/rails server`; port 3000, or the worktree's port printed by `bin/setup`)
- All specs: `bin/rspec`
- Single spec file / example: `bin/rspec spec/requests/home_spec.rb:5`
- Lint (autocorrect): `bin/rubocop -a`
- Security: `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`
- Local CI (single CI definition, `config/ci.rb`): `bin/ci` — setup, RuboCop, Brakeman, bundler-audit, importmap audit, RSpec. GitHub Actions runs only `bin/ci`, so change CI steps in `config/ci.rb`.
- DB: `bin/rails db:prepare` (also what containers run on boot via `bin/docker-entrypoint`)
- Containers locally: `podman compose up -d` (no Docker on the dev machine; `compose.yaml` needs `SECRET_KEY_BASE`, optional `COLLECTOR_PORT`)

## Non-obvious Facts

- **Dev mirrors prod.** Development uses separate SQLite DBs (`storage/development{,_cache,_queue,_cable}.sqlite3`) and runs Solid Queue inside Puma (`config/puma.rb` plugin), so the server already processes jobs. Never also run `bin/jobs` (two supervisors on one SQLite queue DB). The test env uses Rails defaults (primary DB only, `:test` job adapter, null cache).
- **Worktrees:** `bin/setup` sets `core.hooksPath=.githooks` (unless a custom hooks path exists), so `git worktree add`, `claude --worktree` and Orca (`orca.yaml`) worktrees set themselves up via `.githooks/post-checkout` (new linked worktrees only; failures keep the worktree). Each worktree has its own DBs; dev port is 3000 in the main checkout, 3001–3999 per worktree (`lib/collector/dev_port.rb`), `PORT` overrides. Copy list = `.worktreeinclude` (copied only if missing, mode 0600; logic in `lib/collector/worktree_setup.rb`). A missing `config/master.key` only warns; a wrong one breaks boot.
- **Specs:** tag spec types explicitly (`type: :request`, `type: :system`; no inference); multi-expectation examples use `:aggregate_failures`. System specs run in headless Firefox. WebMock + VCR block all real HTTP (cassettes in `spec/cassettes`).
- **Deploy:** Compose (`compose.yaml`) and Kamal (`config/deploy.yml`, placeholder server/registry) both mount the `collector_storage` volume at `/rails/storage` and set `SOLID_QUEUE_IN_PUMA`. Both paths are documented in `README.md`; keep it in sync.
- **Off-limits for reads (permission-denied):** `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`. Don't try to read them.

## Architecture Intent

- **Collectible-agnostic core.** Core domain models (collections, items, conditions, valuations) must not know about any specific collectible; MTG-specific code lives under an `Mtg::` namespace behind an extension boundary.
- **Row-level multi-tenancy.** Every tenant-owned table carries `account_id`; requests resolve `Current.account` and all queries scope through it. Jobs and Turbo Stream broadcasts must carry/restore the tenant. Shared catalog data (e.g. Scryfall cards) is global.
- **External data behind adapters.** Sources such as Scryfall sit behind `Catalog::Sources::*` adapters, are synced in background jobs (bulk data, cached locally), and are never called during page render.
- **Self-hosting & upgrades.** Separate SQLite DBs (primary/queue/cache/cable) live in `storage/` on a persistent volume. Released migrations are never edited; every migration must be safe to run unattended from any prior version. User data export/import uses a documented, versioned format keyed by external IDs.

## Claude Code Hooks (`.claude/settings.json`)

- After editing a Ruby file: `bin/rubocop -a` runs on that file; remaining offenses are reported back.
- Before `git commit`: RuboCop on staged Ruby files + Brakeman; failures block the commit.
- Before `git push`: `bin/ci`; failure blocks the push.
