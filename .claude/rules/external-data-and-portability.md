# External Data Sources, Import/Export & Upgrades

- ✓ Wrap each external source in an adapter behind a source-agnostic interface (e.g. `MTG::Scryfall::Source` implementing `Catalog::Sources`).
- ✓ Prefer Scryfall bulk-data downloads over per-card API calls; cache locally and refresh at most daily.
- ✓ When calling Scryfall directly, send a descriptive `User-Agent` and `Accept` header, throttle (~50–100ms between requests), and back off on 429. (Verify against scryfall.com/docs/api.)
- ✓ Key external records by the provider's stable IDs (Scryfall `id`, `oracle_id`) with a unique index; upsert in batches.
- ✓ Set explicit open/read timeouts on every HTTP call; stub HTTP in tests (WebMock/VCR) — no real network in the suite.
- ✓ Export user data in a documented, versioned format (JSON/CSV with `format_version`) referencing external IDs, not internal primary keys.
- ✓ Make imports idempotent and validating: preview/dry-run, per-row errors, all-or-nothing per batch, scoped to `Current.account`.
- ✓ Ship upgrade notes; round-trip test export → import.
- ✗ Don't hit external APIs during page render; the app must work fully from its local cache.
- ✗ Don't store API secrets in code; use Rails credentials or documented ENV vars.
