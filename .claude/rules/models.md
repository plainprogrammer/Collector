# Models & Active Record

- ✓ Put domain behavior in models and concerns ("rich model" style); use plain Ruby objects under `app/models/` for multi-model workflows rather than a sprawling services layer.
- ✓ Enforce integrity in the database too: `null: false`, foreign keys, unique indexes backing every `validates :uniqueness`.
- ✓ Use `includes`/`preload` for associations rendered in lists; enable `strict_loading` in development to catch N+1s.
- ✓ Use `enum` with explicit mappings (`enum :condition, { near_mint: "nm", ... }`) — never implicit ordinal order.
- ✓ Keep scopes and query class methods chainable (return relations).
- ✓ Store collectible-specific attributes in game-specific tables (or a validated JSON column with `store_accessor`), not nullable columns on core tables.
- ✗ Avoid callbacks that touch other aggregates, send email, or call external APIs; use explicit methods or `after_commit` + a job.
- ✗ Don't use `update_column`/`update_all`/`delete_all` in normal flows — they skip validations and tenant checks.
- ✗ Don't use `default_scope` for anything except tenant scoping (see multi-tenancy.md).
