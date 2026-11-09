# Verification: spec 049

Spec [v1.0.0](spec.md), plan [plan.md](plan.md); issue [#228](https://github.com/plainprogrammer/Collector/issues/228). Suite size at the pushed head: 2,873 examples (`bin/rspec --dry-run`). The full `bin/ci` ran as the pre-push hook on the pushed head; its SHA and result are in the pull request.

## Evidence by criterion

| Criteria | Evidence |
|---|---|
| AC-1.1–AC-1.7, AC-2.1–AC-2.8 | `spec/requests/session_expiry_spec.rb` (16 examples, including the busy-database ruling below), `spec/models/session_spec.rb` (boundaries of `expired?`, `expired`, `stale?`, the creation stamp) |
| AC-1.8, AC-3.1–AC-3.4, AC-3.8 | `spec/models/session_spec.rb` (`.sweep!`: cascade to selection, marks and Undo; no other table; batches of 2 over 5 rows give 3 `DELETE`s), `spec/jobs/session/sweep_job_spec.rb` |
| AC-3.5, AC-3.7 | `spec/jobs/session/sweep_job_spec.rb` (a busy database and a statement timeout are retried, another error fails; `limits_concurrency` declared and a second job blocked through Solid Queue) |
| AC-3.6 | `spec/config/recurring_spec.rb` (both environments, `10 4 * * *`, queue `default`) |
| AC-4.1–AC-4.4 | `spec/migrations/drop_session_client_columns_spec.rb` (6 examples: sessions, selection, mark and Undo survive down and up; the stamp is the migration's time, `updated_at` untouched; the backfill is idempotent; down restores the two columns empty) and `bin/rails db:migrate:redo:primary VERSION=20261109100003` run by the implementer |
| AC-4.5 | `script/upgrade/expected_changes.yml` lists the two `dropped` columns; `seeds/next.rb` creates sessions without them; `seeds/0.2.1.rb` is unchanged; `spec/script/upgrade` (133 examples) passes. The proof compares only the columns both databases have (`script/upgrade/compare.rb`), so the added `last_used_at` and its backfill are not reported and no `rewritten` entry is needed. **Owed:** `bin/upgrade-smoke` needs a container engine and is not a `bin/ci` step; the proof runs in CI's image job |
| AC-4.6 | `spec/backup_guards_spec.rb` and `spec/export_format_document_spec.rb` pass with no change to the format or its version |
| AC-4.7 | **Owed:** the harness's backup leg (`script/upgrade/harness.rb`, which restores the previous release's backup and migrates it) runs in CI's image job; the restore's `DELETE FROM sessions` names no column |
| AC-5.1 | Verified by reading `docs/architecture/tenancy-and-accounts.md`: Glossary (Session: stamp, expiry, the sweep), Invariants (the jobs list, the cross-account reads), States ("A session": Created, Resumed, Used, Ended, the sweep, the upgrade), Named constants (the cookie, `IDLE_LIMIT`, `STAMP_INTERVAL`, `SWEEP_BATCH`), Decisions (the "behaviours with no spec source" bullet: four of the six decided, two left, with #228's clauses removed and #229's, #230's and #231's kept), Accepted limits (the two session entries replaced by one on the 30-day window), Sources |
| AC-5.2 | Verified by reading `docs/specs/README.md`: row 049 |
| AC-5.3 | Verified by reading `README.md` and `docs/backup-restore.md`: neither says a session lasts until ended |

## Rulings made during execution

- **A stamp write that meets a busy database doesn't fail the request** (implementation review, major 1). `Authentication#record_use_of` rescues `ActiveRecord::StatementTimeout` and `SQLite3::BusyException`, logs one line, skips the new cookie, and the request goes on. The spec says a missed write is harmless (the stamp lags by under 24 hours more). Cost if wrong: none for correctness; a session whose stamp could not be written keeps the old stamp until the next request. Two examples in `session_expiry_spec.rb` (written first, red with the exception propagating).
- **Plan examples fixed where red for wiring** (the first batch's AC-4.3 assertion on `Session.expired` moved to Task 2's commit, where the scope exists; RuboCop's metadata order).

## Implementation review

SPEC-ALIGNED (Mode B, Opus, read-only, on head `3255e08` before the follow-ups; nothing blocking)

Coverage matrix: every acceptance criterion and requirement of the spec is covered by code and by an example judged able to fail without the behaviour, except the three that this environment cannot produce (AC-4.5's and AC-4.7's proof runs, AC-4.6's suite run), which are owed to CI (above). No drift from decisions 1–11.

Findings and what was done:

| Finding | Disposition |
|---|---|
| Major 1: a busy database can turn the daily stamp write on a GET into a 500 | Fixed (above), commit `5363e15a` |
| Major 2: no `verification.md` | This file |
| Minor 1: migration 3 re-runs `remove_columns` with an empty list after a partial run | Not changed: harmless (one extra table copy on a run that was interrupted between two steps), and the migration spec passes |
| Minor 2: no example for `ActiveRecord::StatementTimeout` in AC-3.5 | Fixed, `92b2ade4` (shown red by removing it from `retry_on`) |
| Minor 3: AC-1.4 doesn't assert the absence of collection signals | Fixed, `92b2ade4` ("Sign out" absent for the expired session, present after a fresh sign-in; shown red with the expiry check disabled) |
| Minor 4: the Glossary entry doesn't name the sweep | Fixed, `01893ba` |
| Minor 5: two concurrent stale requests both write | Documented in the area doc's "Used" bullet, `01893ba` |
| Minor 6: sign-out of a stale session stamps first | Accepted (one write; the plan notes it) |
| Minor 7: `last_used_at` has no index, so a sweep batch scans | Accepted at the spec's scale (a row per sign-in: tens to a few thousand); revisit if sessions grow |

Not verified by the review, owed to CI: the full `bin/ci` and `bin/upgrade-smoke` / the harness's backup leg.
