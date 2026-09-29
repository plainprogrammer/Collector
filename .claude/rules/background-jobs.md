# Background Jobs (Solid Queue)

- ✓ Make every job idempotent — Solid Queue is at-least-once; use unique keys/upserts so retries don't duplicate work.
- ✓ Pass IDs/GlobalID records as arguments, never large payloads; re-fetch state inside `perform`.
- ✓ Enqueue after the transaction commits so the worker sees the data.
- ✓ `retry_on` transient errors (network, `SQLite3::BusyException`) with backoff; `discard_on` permanent ones (`ActiveJob::DeserializationError`).
- ✓ Define scheduled work (e.g. nightly Scryfall bulk sync) in `config/recurring.yml`, with named queues (`default`, `imports`, `sync`).
- ✓ Use `limits_concurrency` for jobs that must not overlap (per-account import, global catalog sync).
- ✓ Split big work into batches/child jobs so each does few SQLite writes per transaction.
- ✗ Don't run two Solid Queue supervisors against the same SQLite queue DB (e.g. Puma plugin and `bin/jobs`).
- ✗ Don't set very low polling intervals; it adds pressure on SQLite.
- ✗ Don't call external APIs or send mail inline in requests — enqueue a job.
