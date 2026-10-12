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

**Update (2026-10-08, spec 012):**
- The deny rule also blocks commands that merely name the path, e.g. `git diff --stat -- .kamal/secrets`. Leave such checks to the maintainer.
- A masked check works for user verification: `grep -n NAME file | sed -E 's/=.*/=<masked>/'`, or an anchored count `grep -c '^NAME=' file`.
- `.kamal/secrets` assigned `KAMAL_REGISTRY_PASSWORD` only in commented examples until the maintainer's fix `63596c6`; a substring `grep -c` returned 4 and hid it.
- Don't commit a file you can't read; ask the maintainer to commit it.

**Update (2026-10-12, spec 020):** `.kamal/secrets` is a tracked file, so `git grep` and `git ls-files` reach it without naming it. A draft plan's lookup (`git grep -l -w <NAME>` across the tree) made a plan reviewer's git search the file; it filtered the name out of the output and saw no content. The next reviewer's `git ls-files .kamal` printed the file's name. From then on:
- Every `git grep` in a plan, brief or command ends with the pathspec `':!.kamal/secrets'`, and no recursive `grep -r` runs from the repository root without explicit directories.
- A path check (`test -e`, `ls`) skips `.kamal/secrets`, `config/master.key`, `.env*` and `storage/…`; a README claim about one of them is recorded as off-limits, not checked.
- Say both in every subagent brief, and ask the subagent to report any accidental touch. Related: [[plan-reviews-run-the-code]].
