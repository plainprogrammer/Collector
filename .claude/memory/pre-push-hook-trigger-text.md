---
name: pre-push-hook-trigger-text
description: The pre-push hook fires on any Bash command whose text holds "git" then "push" (heredocs, ruby -e, grep patterns), running the full bin/ci or blocking; write commit messages to a file and commit with -F
metadata:
  type: feedback
---

The pre-push hook (`.claude/hooks/pre_push_ci.rb`, spec 035) decides that a Bash call is a push by matching its command *text* against `Collector::PushScope::PUSH`: "git", an optional `-C <dir>`, then "push". The command doesn't have to push anything. A heredoc commit message, a `ruby -e` string or a grep pattern that contains those words is enough.

- **What happens then:** the hook runs the full `bin/ci`, about 9 minutes, before the command. If `bin/ci` fails, the command is blocked.
- **Seen on spec 035 (2026-10-31):**
  - A Phase 4 subagent's Python heredoc mentioned the words. The old shell hook ran a full suite in the worktree and blocked the heredoc.
  - A later subagent's throwaway test command was refused for the same text.
- **Before the UTF-8 fix (`db40d59`):** in a C-locale cloud session, a command holding "push" and a non-ASCII character (✅, ❌) crashed the Ruby hook, which then blocked the command (fail-closed).

**Why:** the regex is the old shell hook's, kept on purpose by spec 035's plan (4.3). A false positive costs a full `bin/ci`, never a missed check.

**How to apply:**
- Write commit messages, scripts and JSON that name a push to a scratchpad file with the Write tool, then use `git commit -F <file>` or `ruby <file>`.
- Search for the phrase with the Grep tool, not a shell `grep`.
- Put this rule in every subagent brief that commits.
- Real pushes still go in the background ([[push-in-background]]).

Related: [[hooks-need-repo-project-dir]], [[pre-push-hook-output-in-transcript]].
