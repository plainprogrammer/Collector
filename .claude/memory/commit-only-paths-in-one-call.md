---
name: commit-only-paths-in-one-call
description: "git commit -o <paths> -m" commits named tracked files, a deletion after a plain rm included, in one Bash call; docs only, because the RuboCop hook doesn't see them
metadata:
  type: feedback
---

In an isolated worktree, where each Bash call may hold one git operation, `git commit -o <path>… -m "…"` commits exactly those paths from the working tree, so an edit, or a deletion made with a plain `rm`, is one call instead of a stage call and a commit call. Spec 027 slice C (#104) made 19 documentation commits that way, each of one to three files.

**Why:** it keeps unrelated working-tree changes (a modified `Gemfile.lock` here) out of each commit without a separate `git add`, and a retirement commit is provably the plan's deletion and nothing else (`git show --stat`).

**How to apply:**
- Only for tracked paths. Verified here for edits and for a deleted file. A new file is not tracked, so it needs `git add <path>` first (git's pathspec rule; not tested here, the coordinator asked for the caveat).
- Only for non-Ruby files. The pre-commit hook lints staged Ruby files and the files of a `git add` in the same command, and `-o` stages nothing first, so a Ruby file committed this way skips RuboCop; see [[precommit-hook-staging]]. Documentation slices (`docs/`, `.md`) are the safe use.
- Related: [[small-incremental-commits]], [[worktree-isolation-command-guard]].
