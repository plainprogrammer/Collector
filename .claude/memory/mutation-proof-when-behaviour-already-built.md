---
name: mutation-proof-when-behaviour-already-built
description: a task whose tests check behaviour an earlier task already built is proved by mutation, in the commit body, in place of failing-first
metadata:
  type: feedback
---

Where a plan task's tests check behaviour that an earlier task already implemented, failing-first can't be shown. The coordinator accepted a **mutation proof** in its place: the implementer breaks the code in a named way, runs only the named example, notes the failure, restores the code (`git diff` clean), and records each mutation and its failure in the commit body.

**Why:** spec 085's plan (T2.3) had four examples (the file's day, streaming, the catalog's file, the twin's EUR) that T2.2's code already satisfied. The coordinator ruled at Gate B (2026-11-13): "The T2.3 mutation proof is accepted in place of failing-first: keep the four mutations and their failures in the commit body."

**How to apply:** only where an earlier task already built the behaviour; every other task is still test first. State the exception in the plan, name each mutation and the one example it must fail (run it with `-e` alone, since a mutation can fail other examples too), and put the results in the commit body. Ask the coordinator at Gate B, not after. See [[batch-plan-tasks-per-implementer]].
