---
scope: conventions
loaded-by: sdd-specify, sdd-plan, sdd-execute, sdd-review
---

# Conventions

## File Naming
Rails/Zeitwerk: `snake_case` files mirroring `CamelCase` constants; singular models, plural controllers/tables; specs end in `_spec.rb` and mirror `app/`.

## Directory Structure
Standard Rails 8 layout. Core, collectible-agnostic domain in `app/models/` (e.g. `Collection`, `Item`, `Catalog::`); collectible-specific code in namespaces such as `MTG::` (`app/models/mtg/`). External source adapters implement `Catalog::Sources` and live in their collectible's namespace (`MTG::Scryfall`). Detailed rules: `.claude/rules/`.

## Code Style
`rubocop-rails-omakase` + `rubocop-rspec`, auto-corrected on edit; minimal, commented local overrides. RESTful thin controllers, HTML over the wire.

## Architectural Patterns
- Rich models + concerns; POROs for multi-model workflows — no sprawling services layer
- Row-level multi-tenancy via `account_id` and `Current.account`
- Collectible-agnostic core with per-collectible extension namespaces
- Adapter pattern for external data sources; local caching, upserts keyed by provider IDs
- Idempotent background jobs on Solid Queue
