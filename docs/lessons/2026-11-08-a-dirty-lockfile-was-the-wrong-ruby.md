---
date: 2026-11-08
spec: none (#225)
tags: [tooling, bundler, ruby, worktrees, orca]
---

# Lesson: A dirty lockfile in every new worktree was setup running on the wrong Ruby

## Context

During the 2026-11-06 parallel run, every Orca worktree started with `Gemfile.lock` modified. The only change was one line in `CHECKSUMS`: `bundler (4.0.20) sha256=7978a8ac…`. The workers left it uncommitted as setup noise. The coordinator first proposed committing the line on `main` so new worktrees would stop showing it.

## What happened

The maintainer asked for the cause before committing the line. Isolating it took four probes:

- A worktree made with hooks off, then `bin/setup` and each `bin/ci checks` step run on the pinned Ruby (4.0.7): the lockfile stayed clean. So no project step writes the line on the right Ruby.
- Bundler records its own checksum only when it can find its `.gem` file. Ruby 4.0.7's Bundler 4.0.20 is the bundled default, with no `.gem`. The global mise Ruby (4.0.4) has 4.0.20 gem-installed, `.gem` cached.
- `bundle lock` on 4.0.4 wrote the identical line, hash included.
- The project's newest gems (`rails-8.1.4.1`, locked the day before) were installed into 4.0.4's gem directory. Only this project's `bundle install` puts them there.

So Orca had been running worktree setup (`orca.yaml` and the post-checkout hook) in its own environment, on the global Ruby: `bundle install` and `db:prepare` on a Ruby the project doesn't use. Committing the line would have hidden that. The fix (PR #226) runs setup through `mise exec`. An end-to-end check from a 4.0.4 `PATH` stayed clean, and a control with plain `bin/setup` on 4.0.4 dirtied the lockfile even though `bundle check` reported the dependencies satisfied.

## What to do next time

Before committing or ignoring an unexplained change to a generated file (lockfile, schema, snapshot), find the process and the tool version that writes it: reproduce the change from scratch, then compare runs that differ by one thing (Ruby, environment, step). An environment-dependent line is a symptom of the environment, not something to normalise in the repo.

## Signals to watch for

- A generated file that changes in fresh checkouts but not in the main one.
- A change workers call "setup noise" and leave out of every commit.
- A version manager's global setting that differs from the project's pinned version, combined with tools that start shells outside an interactive prompt (GUI apps, hooks, agents).
