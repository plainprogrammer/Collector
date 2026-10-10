---
name: spec-015-followups
description: Spec 015 (admin catalog and jobs) — PR #32 state, what its manual checks left unchecked, and two behaviours noted for a later spec
metadata:
  type: project
---

Spec 015 was executed on 2026-10-10. PR #32 is a draft, mergeable, with GitHub CI green on `2d6b1c2` (after merging `main` with spec 014). The Mode B review was SPEC-ALIGNED; it wasn't re-run after the one guard test (`b115cd2`) and the docs commits. Results are in `docs/specs/015-admin-catalog-and-jobs/research.md`.

**Unchecked by the manual run:**
- A graceful restart mid-refresh, where the queue re-queues the job by itself (the crash path was checked; see [[background-servers-via-task]]).
- The art index section with `COLLECTOR_MTG_ART_MATCHING=true` (its first build is about 2.6 hours).
- Focus rings on the new pages.

**For a later spec:**
- After a crash, the catalog page reads "Running." with "Refresh now" disabled while the job already sits under Failed, until it is retried or 15 minutes pass.
- A job's page shows "Attempts 0" for a job the queue failed and an admin retried: the count is Active Job's executions, which rise only on its own retries.

**How to apply:** check PR #32's state before relying on this; once it merges, the two "later spec" points are the part that lasts. This worktree's development database has a loaded MTG catalog (106,846 cards) and a throwaway admin, `admin@example.test`.
