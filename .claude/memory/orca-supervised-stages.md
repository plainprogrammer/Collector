---
name: orca-supervised-stages
description: Working as an Orca worker under a coordinator — questions go through `orca orchestration ask`, heartbeats from a background loop, one SDD stage per Task
metadata:
  type: reference
---

When a brief says "You are a dispatched worker" with a coordinator handle, the maintainer isn't watching the terminal. The coordinator relays to them.

- **Questions:** never `AskUserQuestion` or `ExitPlanMode`. Use `orca orchestration ask` with one question, its options and a recommendation, and wait for the reply. A reversal of something the maintainer already ruled on is worth an `ask`; points that can wait go into `worker_done` as "for the maintainer to rule on".
- **One stage per Task:** spec, plan, execution, push and PR, and session wrap each came as their own Task in spec 017 (2026-10-11). Each ends with one `worker_done`, then stop. Don't start the next stage; the approval arrives as the next Task's brief.
- **Heartbeats while waiting:** a background review or a `bin/ci` run outlasts the five-minute heartbeat. Start a background Bash loop (`for i in $(seq 1 30); do orca orchestration send … --type heartbeat …; sleep 240; done`, `run_in_background`), and stop it with `TaskStop` before sending `worker_done`, or it keeps reporting a settled Task as alive.
- **Before `worker_done`:** run `orca orchestration check` once more, and confirm `git status` is clean.
- **`worker_done` body:** the brief says three sentences, but the acceptance line lists what it must carry (commit range, counts, deviations, what is owed). Carry all of it.

This is my reading of one session's briefs; the maintainer didn't comment on the method. Related: [[sdd-review-model-choice]], [[exitplanmode-for-sdd-plans]], [[background-servers-via-task]].
