---
name: worktree-isolation-command-guard
description: A worktree-isolated agent's Bash calls are refused when a compound command mentions git (or is too complex to verify); split git into plain separate calls and edit files with Edit
metadata:
  type: reference
---

An agent dispatched with worktree isolation (the Agent tool's `isolation: "worktree"`, seen in issue #84 on 2026-10-14) has a guard on its Bash calls. It refuses, before running, any command it "can't verify stays inside the worktree". It said: "this command names git in a form too complex to verify" or "this command is too complex to verify".

Refused in #84:
- `cd <worktree> && bin/setup … && cat … && git diff --stat` style chains with git anywhere in them.
- `cp … && git diff … > file && python3 - <<'EOF' … EOF` (git inside a chain with a heredoc).
- A `python3 - <<'EOF'` heredoc that edited two app files, followed by `bin/rspec …` in the same call. It had no git in it at all, so length or heredoc complexity alone can trip it.
- A `cat $(ls …glob…) ; ls .claude/memory | grep -i "worktree|git"` chain, probably because of the literal word "git" in a grep pattern.

Accepted: `cd <worktree> && git add <files>`, `cd <worktree> && git commit -q -F - <<'EOF' … EOF`, `cd <worktree> && git show HEAD:<path> > <scratchpad file>`, and a python heredoc on its own followed by `git diff --stat`.

**How to apply:**
- One git operation per Bash call, prefixed only by `cd <worktree> &&`. Keep `git add` and `git commit` in separate calls anyway (see [[precommit-hook-staging]]).
- Make code edits with the Edit tool, not python heredocs chained to other commands. If a script edit is needed, run it alone.
- To commit part of a file's changes (no `git add -p` here): copy the full file to the scratchpad, `git show HEAD:<path>` the original to the scratchpad in its own call, rewrite the hunks for the later commit back to the original, commit, then copy the full file back.
- Avoid the bare word "git" in grep patterns or other arguments of a chained command.

Related: [[precommit-hook-staging]], [[small-incremental-commits]].
