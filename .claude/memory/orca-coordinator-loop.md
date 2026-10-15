---
name: orca-coordinator-loop
description: Coordinating Orca workers — they block silently at Claude Code permission prompts (git push, rails runner), so read their terminals after each empty inbox wait; inbox batches can be heartbeats only; resume a released worker with `claude --continue` in its setup shell
metadata:
  type: reference
---

Seen while coordinating issues #38, #59 and #78 as supervised Orca workers on 2026-10-14.

- **Workers stall at permission prompts.** Rules such as `Bash(git push *)` and `Bash(bin/rails runner *)` ask for confirmation even with bypass permissions on. Nothing reaches the orchestration inbox while a worker waits, and `worker-list` shows it `stale` / `unverifiable`. Three workers sat for about an hour before I looked.
- **So:** keep inbox waits to 5–10 minutes (`check --wait --timeout-ms 600000`, `run_in_background`). After each wait that brings no question, read each worker's screen: `orca terminal read --terminal <agent handle> --json`, text in `result.terminal.tail`, and look for "Do you want to proceed?". Accept only an action the maintainer has approved, or when they've said I may answer prompts: `orca terminal send --terminal <handle> --text "1"` (option 1 is "Yes", not "always allow"). A push first runs the pre-push `bin/ci` hook (about 5 minutes), so its prompt appears late.
- **Inbox batches can hold only heartbeats and setup notices.** Acknowledge them (`check --ack <deliveryId>`) and wait again. Parse with `json.JSONDecoder().raw_decode`, since the output file holds keepalive lines and the result.
- **Approvals with findings:** send long findings with `orchestration send --to dispatch:<id> --body "$(cat <file>)"` and reply to the `ask` pointing at that message.
- **After `worker_done`:** `worker-release` closes the agent terminal (the worktree stays). A worker whose resource is user-owned reports `retained` instead.
- **A later task for a released worker** (a session wrap): its setup shell terminal is still open in the worktree. `orca terminal send --text "claude --continue --model claude-opus-5-5" --enter` resumes its session with full context, then paste the task.

Related: [[orca-supervised-stages]], [[background-servers-via-task]].
