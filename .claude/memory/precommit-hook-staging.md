---
name: precommit-hook-staging
description: How the Claude pre-commit RuboCop hook decides which files to lint, and the same-command staging gap it once had
metadata:
  type: reference
---

The PreToolUse hook in `.claude/settings.json` runs *before* the Bash command executes, so on its own `git diff --cached` misses files staged by a `git add` in that same command. Until 2026-09-30 that meant `git add X && git commit …` linted nothing. That's how two `RSpec/ExampleLength` offenses reached spec 004's branch and later failed `bin/ci`.

The fix (2026-09-30) makes the hook lint:
- always: the staged Ruby files
- if the command also runs `git add`: changed tracked files and untracked files in the working tree
- if the commit uses `-a`/`--all`: changed tracked files only

It still reads the command text, so staging done by a different mechanism (a script, or an alias not spelled `git add`) isn't seen. Staging in a separate Bash call before committing remains the most reliable habit. Related: [[small-incremental-commits]].
