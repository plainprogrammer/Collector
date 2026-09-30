---
name: work-ahead-of-human-checkpoints
description: During sdd-execute, build every unit that doesn't need the maintainer's input before waiting at a human checkpoint; record rulings in commit bodies
metadata:
  type: feedback
---

When a plan has human checkpoints (photos, device runs, credentials), first run every work unit that doesn't depend on them: code, specs, and measurements against local data. Ask for all the maintainer's inputs early and in one go, so they can gather them in parallel. Keep going, and record each judgment call as `Ruling: <what> — <why> — <cost if wrong>` in the commit body. Examples from spec 005 are the manifest fixes confirmed from photos, the extra tuning rounds, and the Brave evidence.

**Why:** in spec 005 (2026-09-30) this let all the spike code, the catalog refresh, the name-index benchmark and the edge-case tables finish while the maintainer shot photos. The maintainer accepted the rulings without rework, and the implementation review confirmed they were all recorded.

**How to apply:** at the start of `sdd-execute`, split each phase into its steps that need the maintainer and those that don't, and dispatch the second group first. Stop to ask only about the four things `sdd-execute` lists (irreversible, security-sensitive, external side effect, or a plan broken beyond repair) and for evidence only the maintainer can provide. When evidence deviates from an AC (for example, the wrong browser), give the options and a recommendation rather than silently accepting it. Related: [[small-incremental-commits]], [[card-scanner-direction]].
