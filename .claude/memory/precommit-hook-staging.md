---
name: precommit-hook-staging
description: The Claude pre-commit RuboCop hook lints only already-staged files; run git add as its own command before git commit
metadata:
  type: reference
---

The PreToolUse hook in `.claude/settings.json` runs RuboCop on `git diff --cached` *before* the Bash command executes. A one-liner `git add X && git commit …` therefore reaches the hook with nothing staged: RuboCop checks nothing and offenses get committed. In spec 004 this let two `RSpec/ExampleLength` offenses through, and they later failed `bin/ci`.

**How to apply:** always stage in a separate Bash call, then commit in the next one. Tell implementer subagents the same. Fixing the hook itself (lint the files a same-command `git add` names, or all changed Ruby files) is an open offer to the user, not done yet. Related: [[small-incremental-commits]].
