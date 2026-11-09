---
date: 2026-11-09
spec: none (#268)
tags: [tooling, ruby, worktrees, orca, mise]
---

# Lesson: Orca's setup shell had no mise, and where it had mise, `mise exec` still ran the system Ruby

## Context

#226 (for #225) made `orca.yaml` run `mise exec -- bin/setup --skip-server` and the post-checkout hook do the same when `mise` is on the `PATH`. On 2026-11-09 a worker's new worktree still failed setup with `Could not find 'bundler' (4.0.20)` from `/System/Library/Frameworks/Ruby.framework/Versions/2.6/…/bin/bundle`, and the worker never started (`wait-for-setup`).

## What happened

The fix of #225 had been checked from a shell where mise was already active, so it passed. Orca's app process has `PATH=/usr/bin:/bin:/usr/sbin:/sbin`. Its setup runs `bash -lc 'eval "${ORCA_SEQUENCED_SETUP_SCRIPT}"'`, and a login `bash` here reads only `~/.bash_profile` and `~/.profile`, which don't activate mise (the Homebrew binary is `/opt/homebrew/bin/mise`, off that `PATH`). Reproduced with `env -i HOME=… PATH=/usr/bin:/bin:/usr/sbin:/sbin bash -lc …`:

- `mise exec -- bin/setup`: `mise: command not found`, exit 127.
- the hook's fallback, plain `bin/setup`: system Ruby 2.6, the #268 error.
- `/opt/homebrew/bin/mise exec -- bin/setup`: setup finishes on Ruby 4.0.7.

The hook's "no mise, run as is" fallback, made for CI runners, turned a missing `mise` into a silent run on the wrong Ruby.

That was the first cause, and finding mise (`script/worktree/with_mise`) was not enough: the first fix still failed on a worker's real worktree. The setup terminal there is a zsh with mise active, and the `bash -lc` in it found mise at `/opt/homebrew/bin`. But `mise exec -- sh -c 'command -v ruby'` printed `/usr/bin/ruby`, while `mise exec -- ruby -v` printed 4.0.7 (mise resolves the command itself, but its child gets the PATH). The login `bash` keeps the PATH the zsh built, with mise's `installs/ruby/4.0.7/bin` and `shims`, but macOS's `path_helper` puts `/usr/bin` ahead of them, and `mise exec` doesn't move a directory that is already in the PATH. So `bin/setup`'s `#!/usr/bin/env ruby` and its `bundle` found Ruby 2.6 first. Unsetting `__MISE_DIFF`, `__MISE_ORIG_PATH`, `__MISE_SESSION` and `MISE_SHELL` changed nothing; only the PATH order mattered. `with_mise` now drops mise's own `installs/*` and `shims` directories from the PATH before `mise exec`, so mise puts them first.

## What to do next time

`env -i` can't show the second cause: it needs the PATH a real Orca terminal passes on. Check a fix for a tool started by a GUI app or an agent in that tool's real environment (`env -i` with the app's `PATH`, a login shell without the interactive profile), not in your own terminal. A fallback that runs the work on another tool version should be opt-in (`--optional`), so the default fails loudly.

## Signals to watch for

- `mise exec -- ruby -v` right but `mise exec -- which ruby` wrong: the PATH, not mise's resolution, is off.
- "Works in my shell" for anything Orca, an IDE or a hook starts.
- A `command not found` (127) or a system-Ruby path (`/usr/bin`, `/System/Library`) in a worktree's setup output.
