---
name: hooks-need-repo-project-dir
description: Repository hooks load only when the session's project directory is the repo; after a cloud worker restart it can become /home/user and every hook silently stops
metadata:
  type: reference
---

The hooks in `.claude/settings.json` load only when the session's **project directory** is the repository: the pre-commit RuboCop and Brakeman, the pre-push `bin/ci`, and the RuboCop run after editing a Ruby file. A session whose project directory is a parent such as `/home/user` loads none of them. Nothing says so. Commits and pushes just go through ungated.

**Seen on 2026-10-31 (spike #145, spec 035).**
- **The restart.** A cloud session's worker restarted mid-session. Afterwards its project directory was `/home/user`, not `/home/user/Collector`: its transcript moved from `~/.claude/projects/-home-user-Collector/` to `~/.claude/projects/-home-user/`.
- **What it hid.** Every later push went out about 2 seconds after its tool call, with no `bin/ci`. That was true even after #148 gave the hook `"onFailure": "block"`. Replaying the hook command by hand, with a simulated `git push` tool call on stdin and `CLAUDE_PROJECT_DIR` set, ran `bin/ci` correctly. So the hook itself was fine; it was never loaded.
- **The wrong turn first.** I timed pushes inside the Bash command (`s=$(date +%s); git push …`). A `PreToolUse` hook runs before the command starts, so that timing can never include it. Measure from the tool call instead: the transcript entry's `timestamp`, against the background task's output-file birth time (`stat -c %w`).

**How to apply:**
- **Check after a restart.** After a "worker process was restarted" notice, or whenever pushes look suspiciously fast, check which `~/.claude/projects/<dir>/` holds the current transcript (`ls -t ~/.claude/projects/*/*.jsonl | head -1`).
- **If it isn't the repo:**
  - say so;
  - run the gates by hand: `bin/rubocop` on staged Ruby files and `bin/brakeman` before a commit, `bin/ci` before a push;
  - or hand over to a new session started in the repository, which the maintainer chose for spec 035's execution.
- **Don't report "the hook ran" from a push's speed alone.**

Related: [[push-in-background]], [[secret-files-user-verified]].
