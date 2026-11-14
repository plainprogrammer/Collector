---
name: harness-changes-the-model-mid-run
description: a worker's main session can change model mid-run without being asked; state the model per commit at gates
metadata:
  type: feedback
---

During spec 089's run the harness moved a worker's main session from Sonnet 5.5 to Opus 5.5 and back (the commit attribution reminder changed with it), without the worker or the coordinator asking; a sibling worker saw the same.

**Why:** the maintainer chose the model split for the run and wants it visible while it goes, not at the end (coordinator's brief, 2026-11-13).

**How to apply:** at every gate and in `worker_done`, say which model wrote what, by commit range; when asked which model the session is on, answer from what the harness reports now and whether it changed, and change nothing.
