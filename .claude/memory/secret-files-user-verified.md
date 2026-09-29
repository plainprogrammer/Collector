---
name: secret-files-user-verified
description: Agents cannot read .kamal/secrets, config/master.key, .env*, storage/ — ask the user to verify contents
metadata:
  type: project
---

`.claude/settings.json` deny rules block reads of `.kamal/secrets*`, `config/master.key`, `.env*`, and `storage/**` for Claude and all subagents.

**Why:** Protects credentials and SQLite data; approved at project init (2026-09-29). In feature 001 the AC "Kamal secrets contain no literal values" had to be verified by the user.

**How to apply:** When a check needs those files' contents, ask the user to run `! cat <file>` — never work around the rule (no alternate commands, git show, or copies). Listing file names with `ls` is fine; reading contents is not.
