# Research: Worktree Environment Setup (003)

Collected 2026-09-29. This file separates verified facts from inferences; re-verify versions before relying on details.

## Claude Code (`claude --worktree`, v2.1.x)

Sources: https://code.claude.com/docs/en/worktrees, https://code.claude.com/docs/en/hooks, https://code.claude.com/docs/en/settings

- Default location is `.claude/worktrees/<name>/`, on branch `worktree-<name>`, based on `origin/HEAD` (or `worktree.baseRef: "head"`). Only tracked files are checked out. The docs recommend git-ignoring `.claude/worktrees/`.
- `.worktreeinclude` sits at the repo root and uses `.gitignore` syntax. Only paths that match a pattern **and** are gitignored get copied. Name files explicitly (`tmp/local_secret.txt`), not with `**/` patterns inside wholly-ignored directories.
- A `WorktreeCreate` hook **replaces** git worktree creation entirely, and `.worktreeinclude` is then not processed. Avoid it: we rely on the default mechanism, which runs `git worktree add`, so git's `post-checkout` hook fires.
- `CLAUDE_PROJECT_DIR` stays at the launch root when a session enters a worktree mid-session. When launched from a worktree dir, it is that worktree.

## Plain git (2.55)

Sources: https://git-scm.com/docs/githooks, https://git-scm.com/docs/git-worktree, plus a local experiment

- `post-checkout` fires on `git worktree add` (unless `--no-checkout`) with `$1 = 0000…0` (null SHA), `$2 = new HEAD`, `$3 = 1`, cwd = the new worktree. `git clone` has the same signature. A `git switch` passes a real previous SHA.
- Hooks live in `$GIT_COMMON_DIR/hooks` and are unversioned. `core.hooksPath` (per clone) is the only way to use versioned hooks.
- The main checkout is the first entry of `git worktree list --porcelain`, or `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`. A worktree of a worktree still resolves to the original main checkout. In a bare repo the first entry carries a `bare` line and has no working tree.
- A checkout is a linked worktree when `git rev-parse --git-common-dir` ≠ `--git-dir`.

## Orca (1.4.215, stablyai, https://www.onorca.dev/docs)

Sources: `orca` CLI help, `orca skills get orca-per-workspace-env`, onorca.dev docs (model/worktrees, agents/hooks-memory, remote-servers, ssh, settings), https://github.com/stablyai/orca/issues/9206, app bundle inspection

- Local worktrees are created with plain `git worktree add` at `<workspaceDir>/<repo>/<name>`, branch `<gitUsername>/<name>`, base `refs/remotes/origin/main`.
- The repo-root `orca.yaml` (checked in) supports `scripts.setup`, `scripts.archive`, `setupAgentStartupPolicy` (`start-immediately` | `wait-for-setup`), and `worktree.sharedDirectories`. App-level settings can also define scripts (`commandSourcePolicy`). The first run of an `orca.yaml` script asks for trust (keyed by a content hash).
- The setup script runs in a visible terminal under `bash -lc` with `set -e`, cwd = the worktree. Environment: `ORCA_ROOT_PATH` (primary checkout), `ORCA_WORKTREE_PATH`, `ORCA_WORKSPACE_NAME`. No port or branch variables are set.
- Orca honours `.worktreeinclude` with **literal paths only** (globs and negation are skipped with a warning). Listed paths must be gitignored, and they are copied, not symlinked.
- `worktree.sharedDirectories` symlinks gitignored directories on Linux. This is unsuitable for `storage/`.
- Remote runtimes (`orca serve`, paired with `orca environment add`) keep their repos, worktrees and hooks on the server, which has no access to the client's files. Inference: `orca.yaml` and `.worktreeinclude` apply relative to the remote primary checkout.
- `scripts.archive` runs on removal (120 s timeout). `orca worktree rm` skips it unless `--run-hooks` is passed.
- Ordinary Orca terminals set `ORCA_WORKTREE_ID` and `TERM_PROGRAM=Orca`, but **not** `ORCA_ROOT_PATH`. Git-based detection is the robust contract.
- Orca does no port allocation for local worktrees.

## Rails inventory (this repo)

- Gems install to a shared user gem path (no `vendor/bundle` or `.bundle/config`), so every worktree shares one gem set.
- `config.require_master_key` is false in development and test. Without the key, credentials are empty, and `secret_key_base` falls back to `tmp/local_secret.txt` (generated on demand).
- SQLite runs in WAL mode, so a raw `cp` of a live database is unsafe. That is moot, since the databases are regenerated (spec FR-2).
- Puma binds `ENV.fetch("PORT", 3000)`. The pid file is per checkout (`tmp/pids/server.pid`). Each worktree has its own queue database, so one embedded Solid Queue supervisor per worktree stays within the "one supervisor per queue DB" rule.
- A fresh Orca worktree was observed to contain zero ignored files. The main checkout holds `config/master.key`, `tmp/local_secret.txt`, `storage/*.sqlite3`, `log/*`, and `tmp/cache`.
