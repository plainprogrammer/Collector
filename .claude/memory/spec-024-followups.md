---
name: spec-024-followups
description: Spec 024 (issue #78, skip while another job's retry waits) — merged (PR #96, 2026-10-15); #77 must discard or run the waiting job first; accepted limits
metadata:
  type: project
---

Spec 024 merged on 2026-10-15 (PR #96, after #95; it was stacked on #95 and retargeted to `main`). Delete this memory once #77 is specified.

- **For #77 ("start fresh while a retry waits"):** a refresh or art build that starts while any other job of its operation waits in the queue to run again is now skipped as `waiting for another job's retry`, whoever started it (the maintainer's ruling: manual behaves like scheduled; an override belongs to #77). So #77's "start fresh" is skipped too unless it first discards the waiting job or runs it now. Its spec has to say which.
- **Accepted limits, in spec 024:** any job held for a later time counts, not only a rate-limit retry (the queue row can't tell them apart). With two waiting retries, the one due first is skipped. The art build has no concurrency lock, so a build that starts in the milliseconds between a failing build closing its record and its retry being queued still goes ahead, as it did before.

**Why:** the #77 constraint lives only in spec 024's "Interactions" section, which a session starting #77 won't read by default.

**How to apply:** when specifying #77, start from the first bullet. The stacking procedure itself is in [[pr-exists-and-conflicts-check]].
