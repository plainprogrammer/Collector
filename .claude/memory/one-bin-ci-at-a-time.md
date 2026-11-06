---
name: one-bin-ci-at-a-time
description: With parallel worktrees, the coordinator hands out one slot for any full bin/ci (direct or a push's pre-push hook); "stopped without reporting" alerts while a worker waits on the coordinator are not stalls
metadata:
  type: project
---

When several worktrees work at once (spec 041–044 run, 2026-11-06), only one full `bin/ci` runs at a time. That covers a direct run and the pre-push hook of any push that isn't documentation-only. Workers ask the coordinator for a "ci slot" or "push slot" and report "slot released" with the result.

**Why:** parallel full runs race on the shared temporary directory (#178, [[parallel-bin-ci-tmpdir-race]]) and slow every run past the hook's timeout. A documentation-only push (only `docs/` or `.md` files, such as a memory or plan-retirement commit) runs `bin/ci checks` only and needs no slot.

**How to apply:**
- **Slot order:** a branch about to merge comes before one still building.
- **The maintainer can override:** a push they ask for directly in a worker's terminal can overlap; watch it for the #178 flake.
- **Expected alerts:** Orca's "Worker stopped without reporting" and "waiting on a prompt" alerts often only mean the worker ended its turn to wait on `ask`, or a hook was running. Check `worker-read` before reporting a stall to the maintainer.

Related: [[parallel-sdd-orchestration]], and the lesson `2026-11-06-each-merge-reconflicts-open-branches-on-the-specs-index`.
