---
name: orca-setup-through-mise
description: Orca runs worktree setup with the global mise Ruby, so orca.yaml and the post-checkout hook run `mise exec -- bin/setup` (#225); it needs mise's idiomatic_version_file_enable_tools to include ruby on each machine
metadata:
  type: project
---

Since PR #226 (2026-11-08, closes #225), `orca.yaml` runs `mise exec -- bin/setup --skip-server`, and `.githooks/post-checkout` does the same when `mise` is on the PATH (plain `bin/setup` otherwise, as on GitHub's runners).

**Why:** Orca starts setup from its own environment, which carries the global mise Ruby (`~/.config/mise/config.toml`: 4.0.4), not the 4.0.7 in `.ruby-version`. On 4.0.4, `bin/setup` ran `bundle install` and `db:prepare` on the wrong Ruby. Even a satisfied `bundle check` rewrote `Gemfile.lock`: 4.0.4's gem-installed Bundler 4.0.20 has its `.gem` cached, so it adds `bundler (4.0.20) sha256=7978a8ac…` to `CHECKSUMS`. That is why every Orca worktree of the 2026-11-06 run started with `Gemfile.lock` modified.

**How to apply:**
- `mise exec` honours `.ruby-version` only when mise's `idiomatic_version_file_enable_tools` includes `ruby`. It does on this machine, but recent mise versions default it off. Set it on any new dev machine.
- If a fresh Orca worktree shows `Gemfile.lock` modified again, check that setting and `mise exec -- ruby -v` in the worktree before touching the lockfile. Never commit the stray checksum line.
- Quick check from Orca's kind of environment: `PATH=~/.local/share/mise/installs/ruby/4.0.4/bin:$PATH sh -c 'mise exec -- ruby -v'` must print the `.ruby-version` Ruby.

Related: [[parallel-sdd-orchestration]], [[ruby-precompiled-mise]] (auto-memory).
