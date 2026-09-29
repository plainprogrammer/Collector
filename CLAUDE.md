# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering cards. **The Rails application has not been generated yet** — the repo currently holds only the project foundation (`.claude/`), `docs/`, `LICENSE` (AGPL-3.0), and a Rails-template `.gitignore`. Update this file with real commands and structure once the app exists.

Mission and principles: `.claude/memory/foundation.md`. Detailed coding rules: `.claude/rules/`. Feature specs: `docs/specs/`.

## Chosen Stack

Rails 8.x (latest), SQLite in every environment (including production), Hotwire (Turbo + Stimulus), Propshaft + importmap (no Node toolchain), Solid Queue / Solid Cache / Solid Cable, RSpec + FactoryBot, RuboCop (`rubocop-rails-omakase`), Brakeman, bundler-audit.

## Commands (once the app is generated)

- Local CI (also the pre-push gate): `bin/ci` — configured in `config/ci.rb`; must run `bundle exec rspec` rather than the default `bin/rails test`. Maintain it as the single local CI entrypoint.
- All specs: `bundle exec rspec`
- Single spec file / example: `bundle exec rspec spec/models/collection_spec.rb:42`
- Lint (autocorrect): `bin/rubocop -a`
- Security: `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`
- DB: `bin/rails db:prepare` (also what self-hosted instances run on boot)

## Architecture Intent

- **Collectible-agnostic core.** Core domain models (collections, items, conditions, valuations) must not know about any specific collectible; MTG-specific code lives under an `Mtg::` namespace behind an extension boundary.
- **Row-level multi-tenancy.** Every tenant-owned table carries `account_id`; requests resolve `Current.account` and all queries scope through it. Jobs and Turbo Stream broadcasts must carry/restore the tenant. Shared catalog data (e.g. Scryfall cards) is global.
- **External data behind adapters.** Sources such as Scryfall sit behind `Catalog::Sources::*` adapters, are synced in background jobs (bulk data, cached locally), and are never called during page render.
- **Self-hosting & upgrades.** Separate SQLite DBs (primary/queue/cache/cable) live in `storage/` on a persistent volume. Released migrations are never edited; every migration must be safe to run unattended from any prior version. User data export/import uses a documented, versioned format keyed by external IDs.

## Claude Code Hooks (`.claude/settings.json`)

- After editing a Ruby file: `bin/rubocop -a` runs on that file; remaining offenses are reported back.
- Before `git commit`: RuboCop on staged Ruby files + Brakeman; failures block the commit.
- Before `git push`: `bin/ci`; failure blocks the push.

All hooks no-op until the corresponding `bin/` scripts exist.
