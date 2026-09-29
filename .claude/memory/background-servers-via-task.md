---
name: background-servers-via-task
description: Start temporary dev servers with run_in_background and stop them with TaskStop, not shell & / kill / pkill
metadata:
  type: feedback
---

Start temporary servers, such as a dev server for verification or screenshots, with the Bash tool's `run_in_background`, and stop them with `TaskStop`. Don't use shell backgrounding (`&`, `setsid`) plus `kill`/`pkill`.

**Why:** on 2026-09-29, a combined command that started a server with `setsid … &` and then ran `rm -rf` and `kill` was denied by permissions. Earlier, `pkill -f "puma.*3055"` matched its own shell and exited with 144.

**How to apply:** start the server as its own background Bash call, poll `/up` with curl in a separate call, do the work, then `TaskStop` the task. Keep destructive commands out of compound one-liners. Related: [[pr-screenshots-workflow]].
