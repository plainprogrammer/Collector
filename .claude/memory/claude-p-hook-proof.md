---
name: claude-p-hook-proof
description: How to prove a SessionStart or other hook change in a fresh local Claude Code session with claude -p, without an Orca worker, and what it showed in #289
metadata:
  type: reference
---

A hook change only takes effect in a new session, so prove it in one (done for #289, 2026-11-10):

- A throwaway worktree at `HEAD` under the scratchpad, with the post-checkout hook off so no setup runs: `git -c core.hooksPath=/dev/null worktree add -b throwaway-NNN <scratchpad>/throwaway-NNN HEAD`.
- `claude` is a native binary at `~/.local/bin/claude`: call it by its absolute path to run with a trimmed `PATH` (`PATH=/usr/bin:/bin:/usr/sbin:/sbin`). From inside the worktree: `claude -p --model haiku --allowedTools 'Bash(ruby -v)' … -- '<prompt>' < /dev/null` (without `< /dev/null` it waits 3 s for stdin).
- To see what a hook gets, add a probe with `--settings <file>`: a second `SessionStart` hook that appends `${CLAUDE_ENV_FILE:+set}` to a log. A local `claude -p` session receives `CLAUDE_ENV_FILE` (`CLAUDE_CODE_REMOTE` unset), and the PATH line written to it applies to the session's Bash commands.
- Clean up: `git worktree remove --force <path>`, then `git branch -D throwaway-NNN`; confirm with `git worktree list` and `git branch --list`.

`script/worktree/with_mise` looks in `/opt/homebrew/bin` and `~/.local/bin` even when the `PATH` has no mise, so a trimmed `PATH` alone does not show the no-mise path: add `COLLECTOR_MISE_SEARCH=/nonexistent`.

**Why:** an Orca worker is the real case, but starting one needs the coordinator's go-ahead; this shows the same thing for one haiku call.
**How to apply:** ask the coordinator before the session when you are an Orca worker; related to [[worker-permission-prompts]].
