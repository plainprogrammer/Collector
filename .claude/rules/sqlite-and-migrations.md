# SQLite in Production & Migrations

- ✓ Keep Rails 8's SQLite defaults (WAL, busy timeout, IMMEDIATE transactions) — don't override them in `database.yml` without a benchmark.
- ✓ Keep separate SQLite files for primary, `prices`, `queue`, `cache`, and `cable`; the primary and prices databases need backing up, both held by `backup:create` ([ADR 0024](../../docs/adr/0024-backup-with-vacuum-into.md), [ADR 0029](../../docs/adr/0029-prices-database-held-by-the-backup.md)); Litestream and volume snapshots are alternatives the app doesn't test.
- ✓ The prices database's `current_prices` and `price_changes` are `WITHOUT ROWID` with no index beyond their primary key, an accepted exception to indexing every foreign key; a change to either is a new migration that recreates the table (`docs/architecture/prices.md`).
- ✓ Keep write transactions short; do network I/O and heavy computation outside `transaction do … end`.
- ✓ Write reversible migrations, safe to run unattended on a self-hoster's upgrade (`bin/rails db:prepare` on boot).
- ✓ Separate schema migrations from data backfills; backfill in batches and make backfills idempotent.
- ✓ Index every foreign key and every tenant-scoped lookup column (e.g. `[:account_id, :created_at]`).
- ✗ Never edit or delete a released migration — self-hosters may be on any prior version; add a new one. `ruby script/upgrade/guard.rb` (a `bin/ci` step) fails on it, and the upgrade proof (`bin/upgrade-smoke`, spec 031) fails on a migration that loses data.
- ✗ Don't reference application models in migrations; use an inline `Class.new(ActiveRecord::Base)` or SQL.
- ✗ Don't use Postgres-only features (`jsonb` operators, arrays, `DISTINCT ON`, advisory locks).
- ✗ Don't put the SQLite files on network filesystems or share them across hosts; one host, local persistent volume.
