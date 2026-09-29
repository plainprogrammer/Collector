# SQLite in Production & Migrations

- ✓ Keep Rails 8's SQLite defaults (WAL, busy timeout, IMMEDIATE transactions) — don't override them in `database.yml` without a benchmark.
- ✓ Keep separate SQLite files for primary, `queue`, `cache`, and `cable`; only the primary DB needs backing up (e.g. Litestream or `.backup`).
- ✓ Keep write transactions short; do network I/O and heavy computation outside `transaction do … end`.
- ✓ Write reversible migrations, safe to run unattended on a self-hoster's upgrade (`bin/rails db:prepare` on boot).
- ✓ Separate schema migrations from data backfills; backfill in batches and make backfills idempotent.
- ✓ Index every foreign key and every tenant-scoped lookup column (e.g. `[:account_id, :created_at]`).
- ✗ Never edit or delete a released migration — self-hosters may be on any prior version; add a new one.
- ✗ Don't reference application models in migrations; use an inline `Class.new(ActiveRecord::Base)` or SQL.
- ✗ Don't use Postgres-only features (`jsonb` operators, arrays, `DISTINCT ON`, advisory locks).
- ✗ Don't put the SQLite files on network filesystems or share them across hosts; one host, local persistent volume.
