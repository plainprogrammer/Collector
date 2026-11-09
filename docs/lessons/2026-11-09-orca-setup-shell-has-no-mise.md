---
date: 2026-11-09
spec: none (#268)
tags: [tooling, ruby, worktrees, orca, mise]
---

# Lesson: Orca's setup shell has no mise, so `mise exec` alone was not enough

## Context

#226 (for #225) made `orca.yaml` run `mise exec -- bin/setup --skip-server` and the post-checkout hook do the same when `mise` is on the `PATH`. On 2026-11-09 a worker's new worktree still failed setup with `Could not find 'bundler' (4.0.20)` from `/System/Library/Frameworks/Ruby.framework/Versions/2.6/…/bin/bundle`, and the worker never started (`wait-for-setup`).

## What happened

The fix of #225 had been checked from a shell where mise was already active, so it passed. Orca's app process has `PATH=/usr/bin:/bin:/usr/sbin:/sbin`. Its setup runs `bash -lc 'eval "${ORCA_SEQUENCED_SETUP_SCRIPT}"'`, and a login `bash` here reads only `~/.bash_profile` and `~/.profile`, which don't activate mise (the Homebrew binary is `/opt/homebrew/bin/mise`, off that `PATH`). Reproduced with `env -i HOME=… PATH=/usr/bin:/bin:/usr/sbin:/sbin bash -lc …`:

- `mise exec -- bin/setup`: `mise: command not found`, exit 127.
- the hook's fallback, plain `bin/setup`: system Ruby 2.6, the #268 error.
- `/opt/homebrew/bin/mise exec -- bin/setup`: setup finishes on Ruby 4.0.7.

The hook's "no mise, run as is" fallback, made for CI runners, turned a missing `mise` into a silent run on the wrong Ruby.

## What to do next time

Check a fix for a tool started by a GUI app or an agent in that tool's real environment (`env -i` with the app's `PATH`, a login shell without the interactive profile), not in your own terminal. A fallback that runs the work on another tool version should be opt-in (`--optional`), so the default fails loudly.

## Signals to watch for

- "Works in my shell" for anything Orca, an IDE or a hook starts.
- A `command not found` (127) or a system-Ruby path (`/usr/bin`, `/System/Library`) in a worktree's setup output.
