---
name: secret-files-user-verified
description: Agents cannot read .kamal/secrets, config/master.key, .env*, storage/ — ask the user to verify contents
metadata:
  type: project
---

`.claude/settings.json` deny rules block reads of `.kamal/secrets*`, `config/master.key`, `.env*`, and `storage/**` for Claude and all subagents.

**Why:** Protects credentials and SQLite data; approved at project init (2026-09-29). In feature 001 the AC "Kamal secrets contain no literal values" had to be verified by the user.

**How to apply:** When a check needs those files' contents, ask the user to run `! cat <file>` — never work around the rule (no alternate commands, git show, or copies). Listing file names with `ls` is fine; reading contents is not.

**Subagents too, including through the shell:** say in every subagent brief that `grep`, `cat`, `head`, `zcat` and the like on these paths are off-limits, not only the Read tool. Scripts the plan runs may read the bulk file under `storage/catalog/`; the agent itself may not. In spec 010 (2026-10-06) a subagent ran `grep -c` on the bulk file under `storage/` to check one artwork. That was a slip, despite a brief that forbade "reading" `storage/`.
