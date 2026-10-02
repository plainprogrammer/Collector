---
name: background-servers-via-task
description: Start temporary dev servers with run_in_background and stop them with TaskStop, not shell & / kill / pkill; they die at the 2-hour task limit
metadata:
  type: feedback
---

Start temporary servers, such as a dev server for verification or screenshots, with the Bash tool's `run_in_background`, and stop them with `TaskStop`. Don't use shell backgrounding (`&`, `setsid`) plus `kill`/`pkill`.

**Why:** on 2026-09-29, a combined command that started a server with `setsid … &` and then ran `rm -rf` and `kill` was denied by permissions. Earlier, `pkill -f "puma.*3055"` matched its own shell and exited with 144.

**How to apply:** start the server as its own background Bash call, poll `/up` with curl in a separate call, do the work, then `TaskStop` the task. Keep destructive commands out of compound one-liners.

**Time limit:** a background task stops at its timeout, and the maximum is 2 hours (7,200,000 ms). In spec 007 (2026-10-01/02), the HTTPS dev server died twice while the maintainer was away, once just before a device load test. Start or restart the server right before a step that needs the maintainer on a device, check `/up` before saying it's ready, and tell them it lasts up to 2 hours. Related: [[pr-screenshots-workflow]].
