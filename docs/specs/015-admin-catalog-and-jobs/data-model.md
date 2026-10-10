# Data Model: Admin Catalog Operations and Jobs

No new table. One existing table gains five nullable columns; everything else the pages show is read from tables that already exist (`catalog_refresh_runs`, `mtg_art_builds`, `catalog_entries`, and Solid Queue's own tables in the queue database).

## Entities

### Catalog::RefreshRun (`catalog_refresh_runs`, existing; columns added)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| stage | string | nullable; one of `download`, `sync`, `retire`, `index` (validated) | The stage the run is in, or was in when it ended. Nil for runs recorded before this feature and for a run skipped because another was running. |
| stage_done | bigint | nullable | How far through the stage the source says it is: bytes received (download) or compressed bytes read (sync). Nil when the source doesn't say, and in the retire and index stages. |
| stage_total | bigint | nullable | The stage's total in the same unit: the published file size, or the file's size on disk. Nil when unknown. |
| job_id | string | nullable | The Active Job id of the job running it. Nil for a refresh started without a job (console, a model spec) and for older runs. |
| heartbeat_at | datetime | nullable | When the run last recorded progress. Set at start and by every progress write. Nil for older runs, whose last progress is `started_at`. |

The existing `*_count` columns are now also written while the run is running (the counts so far), not only when it ends.

**Indexes:** none added. The lookups are "running runs of a type" (the existing `[collectible_type, status, started_at]` index) filtered by `job_id` or by last progress; at most a handful of rows are ever running.
**Relationships:** none. `job_id` matches `solid_queue_jobs.active_job_id` in the queue database by value only; there is no foreign key across databases.
**Spec requirement:** FR-1 (stage, progress, job id, heartbeat), AC-2.4 to AC-2.9, AC-3.1 to AC-3.8.

**Derived, not stored:**

- *Last progress* = `heartbeat_at`, or `started_at` when it is nil.
- *Stalled* = running and last progress at or before 15 minutes ago (`STALL_AFTER`).
- *Interrupted* (display) = stalled and no worker holds the run's job; *stalled, still running* (display) = stalled and a worker holds it. Only the queue knows which, so this is worked out by `Catalog::RefreshOperation`, not the model.
- *Attempted* = every run except those skipped with the message "already running".

**Migration:** `20261009100001_add_progress_to_catalog_refresh_runs.rb`, one `change_table … bulk: true` adding the five columns. Reversible, no backfill, no lock beyond SQLite's own for `ALTER TABLE ADD COLUMN`; safe for unattended `db:prepare` from any prior version.

---

### Read-only: Solid Queue's tables (queue database; primary database in tests)

Not changed. Read through Solid Queue's models (ADR 0014):

| Table | Read for |
|-------|----------|
| `solid_queue_jobs` | Every job: class, arguments, queue, priority, `active_job_id`, `scheduled_at`, `finished_at`. |
| `solid_queue_failed_executions` | The Failed list, the error and backtrace, and whether an operation's job is failed. |
| `solid_queue_claimed_executions` | The Running list, and whether a worker holds a run's job. |
| `solid_queue_ready_executions`, `solid_queue_blocked_executions` | The Queued list (blocked = "waiting"), and "in flight". |
| `solid_queue_scheduled_executions` | The Scheduled list, and a retrying operation's "retrying at". |
| `solid_queue_recurring_tasks` | A catalog type's next scheduled refresh. |

Written only through Solid Queue itself: `perform_later` (start), `FailedExecution#retry`, `FailedExecution#discard`.

**Spec requirement:** FR-3, FR-5, AC-5.5, the glossary's "In flight" and job states.
