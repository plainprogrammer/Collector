---
date: 2026-11-10
spec: none (#289)
tags: [tooling, ruby, hooks, orca, mise, testing]
---

# Lesson: the sandbox spec with a fake mise passed while the hook failed against the real one

## Context

#289: a local Claude Code session, an Orca worker's too, starts with macOS's Ruby 2.6 first on its `PATH`, so a bare `ruby` or `bundle` failed with `Could not find 'bundler'`. #269 fixed Orca's setup and #272 fixed the hooks, but not the model's own commands. `.claude/hooks/session-start.sh` now writes a `PATH` line for `.ruby-version`'s Ruby to `$CLAUDE_ENV_FILE` in a local session.

## What happened

The first version had a nine-example spec against a sandbox project with a fake mise, and all nine passed. A run of the hook against the real mise, with a scratch env file, then sourced to `ruby -v`, printed 2.6.

The line skipped adding the directory when it was already somewhere in `PATH` (`case ":$PATH:" in *:dir:*`). The session's `PATH` already holds mise's `installs/ruby/4.0.7/bin`, behind `/usr/bin` (#268, the macOS `path_helper` effect), so the line did nothing. The fake mise's sandbox `PATH` was `/usr/bin:/bin`, which never held the directory, so no example could fail that way. The guard now tests for the directory *first* in `PATH`, with its own example.

An Opus code review of the fix then found a second case the sandbox hid: `with_mise` strips the session's own mise directories before `mise exec`, so a mise that resolves no Ruby for the checkout leaves `/usr/bin`'s, and the hook put `/usr/bin` first (a session's Ruby 3.x would become 2.6). A fake mise that always adds a Ruby can't show that either. The hook now writes the line only when the resolved Ruby's version is `.ruby-version`'s.

## What to do next time

For a hook or script that edits `PATH`, run it once against the real tool in the real session's `PATH` order (here `bash .claude/hooks/session-start.sh` with a scratch `CLAUDE_ENV_FILE`, then `. file; ruby -v`), then pin each case it shows as an example whose `PATH` has that shape. Make the fake tool's sandbox `PATH` hold the shape that failed (the tool's directory already in it, behind the system's) and the fake's failure mode (it resolves nothing), not only the happy case.

## Signals to watch for

- A spec for a `PATH` change whose sandbox `PATH` is `/usr/bin:/bin` and nothing else.
- A fake tool that always succeeds in a spec for code that must handle the real tool resolving nothing.
- "Not already on the `PATH`" used where "first on the `PATH`" is meant.
