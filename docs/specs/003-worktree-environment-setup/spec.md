# Feature 003: Worktree Environment Setup

**Status:** Approved
**Created:** 2026-09-29
**Branch:** `plainprogrammer/chore-003-worktree-environment-setup`

> Numbered 003: feature 002 is being specified in parallel elsewhere.

---

## Problem Statement

Collector development increasingly happens in parallel git worktrees: created with plain `git worktree add`, by Claude Code (`claude --worktree` and isolated subagents), and by Orca, both on the developer's machine and on remote Orca runtimes. A new worktree contains only tracked files. It has no credentials key, no local development secret, and no databases, and nothing prepares it. The developer has to know which ignored files to copy from the main checkout and which commands to run, and two dev servers in different worktrees clash on the same port. That friction works against Foundation principle 1 ("easy to self-host", which starts with easy to develop) and slows every parallel agent session.

> **Integration constraints.** The setup entrypoint `bin/setup` is fixed by the request: it stays the single, universal setup command. The worktree creators are external systems with fixed contracts, and the plan must integrate with them (verified against git 2.55, Claude Code 2.1.x, Orca 1.4.215):
> - Plain git runs a `post-checkout` hook on `git worktree add`. `git clone` gives the same signature, and a failing hook makes the command exit non-zero, although the worktree is still created. Hooks are unversioned unless the clone points `core.hooksPath` at a versioned directory.
> - Claude Code's default worktree creation (under `.claude/worktrees/`, inside the main checkout) copies gitignored paths listed in a repo-root `.worktreeinclude`. It does not run setup commands itself, but it creates worktrees with git, so git's hook fires.
> - Orca runs `scripts.setup` from a checked-in repo-root `orca.yaml`, with `ORCA_ROOT_PATH` and `ORCA_WORKTREE_PATH` set. It also honours `.worktreeinclude` (literal paths only). Orca creates worktrees with git, so git's hook runs first (synchronously) and Orca's script runs afterwards. On a remote runtime both run against the remote's own primary checkout, which cannot see the developer's local files.
>
> Research sources and findings: `docs/specs/003-worktree-environment-setup/research.md`.

## Goals

- A worktree created by any supported method is ready for development and testing (dependencies checked, secrets present where available, databases prepared) without the developer running any command. The one exception is a plain-git clone that has not yet run setup once.
- `bin/setup` stays the one setup command. It works in a fresh clone, the main checkout, and any worktree, and running it again is always safe.
- The spec defines which ignored local state is copied from the main checkout and which is regenerated in each worktree.
- Dev servers in the main checkout and in several worktrees can run at the same time without port conflicts or manual configuration.

## Non-Goals

- Provisioning remote Orca runtimes, VMs, or environment recipes.
- Distributing the credentials key to remote machines. Setup reports that it is missing; it does not fetch it.
- Copying or sharing development database contents between worktrees.
- Teardown or cleanup when a worktree is removed. All per-worktree state lives inside the worktree directory.
- Changing production, container, or Kamal behaviour.
- Installing Ruby or system packages.
- Changing how the existing Claude Code project hooks pick their working directory. Those hooks `cd` to the launch project root, which can be the main checkout during a `.claude/worktrees` session; that is recorded under Out of Scope.

## Users and Context

**Primary users:** Collector developers (the maintainer) and the Claude Code agent sessions they launch.
**Secondary users:** Orca, as an automated caller of the setup script; future contributors cloning the repo; GitHub Actions, which runs `bin/setup` via `bin/ci`.
**Usage context:** A developer or agent starts a task in a fresh worktree (often several at once) and expects to run the app, the test suite, and `bin/ci` straight away.
**User mental model:** "New worktree → it just works." "`bin/setup` fixes my environment wherever I am." "Each worktree is its own sandbox: its own databases, its own server port."

**Terms.**
- *Main checkout*: the working tree that owns the repository's git directory. A fresh clone is a main checkout.
- *Linked worktree*: any additional working tree attached to that git directory, whatever tool created it.
- *Automatic setup*: setup run by a creation trigger (git hook or Orca), not typed by a person.

## User Stories

### Story 1: Plain git worktree is ready automatically

**As a** developer
**I want** `git worktree add` to produce a ready-to-use worktree
**So that** I don't have to remember any setup steps

**Acceptance criteria:**

- [ ] **AC-1.1** Given a clone where `bin/setup` has completed at least once When the developer runs `git worktree add <path> -b <branch>` Then, when the command returns, the new worktree has its development and test databases prepared, and the RSpec suite runs in it with exit 0
- [ ] **AC-1.2** Given the same situation and the main checkout contains `config/master.key` and `tmp/local_secret.txt` When the worktree is created Then both files exist in the new worktree with the same contents as in the main checkout and mode 0600
- [ ] **AC-1.3** Given a clone that has never run `bin/setup` When the developer runs `git worktree add` Then no automatic setup runs, and running `bin/setup` inside the new worktree produces the same result as AC-1.1 and AC-1.2
- [ ] **AC-1.4** Given automatic setup runs during worktree creation When it finishes Then no dev server was started and the `git worktree add` command has returned
- [ ] **AC-1.5** Given a normal branch switch (`git switch`/`git checkout <branch>`) in an existing checkout When it completes Then automatic setup does not run
- [ ] **AC-1.6** Given automatic setup fails during `git worktree add` (e.g. database preparation errors) When the command returns Then it exits 0, the worktree exists, and the output names the failure and the command `bin/setup` to re-run in that worktree

### Story 2: Claude Code worktree is ready automatically

**As a** developer launching Claude Code in isolation
**I want** `claude --worktree` (and worktree-isolated subagents) to start in a ready environment
**So that** the agent can run the app and tests without first doing setup

**Acceptance criteria:**

- [ ] **AC-2.1** Given a clone where `bin/setup` has completed at least once When Claude Code creates a worktree using its default mechanism Then the worktree contains `config/master.key` and `tmp/local_secret.txt` copied from the main checkout (when present there) and has prepared databases before the agent's first command
- [ ] **AC-2.2** Given the repository When its ignore rules and lint configuration are inspected Then Claude Code's default worktree directory (`.claude/worktrees/`) is ignored by git and excluded from the style check, so `bin/ci` in the main checkout never inspects worktree contents

### Story 3: Orca worktree is ready automatically (local)

**As a** developer using Orca on my machine
**I want** a new Orca worktree to run project setup itself
**So that** agents in that worktree start in a working environment

**Acceptance criteria:**

- [ ] **AC-3.1** Given the repository When the checked-in Orca configuration is inspected Then it declares a setup script that runs `bin/setup --skip-server`, and it does not pass `--reset`
- [ ] **AC-3.2** Given Orca creates a local worktree with setup enabled When the setup script finishes Then it has exited 0, the worktree has prepared databases, and the key and local secret were copied from the primary checkout when present there
- [ ] **AC-3.3** Given setup is already running in a worktree When a second setup invocation starts in the same worktree (e.g. Orca's script, or an agent running `bin/setup`) Then the second waits until the first finishes and then completes, both exit 0, and the end state equals a single run

### Story 4: Remote Orca worktree degrades clearly

**As a** developer running Orca against a remote runtime
**I want** setup to succeed even though my local key isn't on that machine
**So that** development and tests work remotely, and I know exactly what's missing

**Acceptance criteria:**

- [ ] **AC-4.1** Given a worktree whose main checkout has no `config/master.key` When setup runs Then it exits 0, the databases are prepared, the RSpec suite runs with exit 0, and the output includes a warning naming the missing key file and how to supply it (copy the file or set `RAILS_MASTER_KEY`)
- [ ] **AC-4.2** Given a worktree whose main checkout has no `tmp/local_secret.txt` When setup runs and the app boots Then a new local secret exists in the worktree, and setup does not warn about it

### Story 5: `bin/setup` is universal and safe to re-run

**As a** developer
**I want** one setup command that behaves correctly wherever I run it
**So that** I never have to think about which kind of checkout I'm in

**Acceptance criteria:**

- [ ] **AC-5.1** Given a fresh clone (a main checkout) When the developer runs `bin/setup --skip-server` Then it exits 0, prepares the databases, attempts no file copying, and enables automatic setup for future worktrees of this clone
- [ ] **AC-5.2** Given a worktree that already has its own `config/master.key` or `tmp/local_secret.txt` whose contents differ from the main checkout's When setup runs Then the worktree's files are left unchanged
- [ ] **AC-5.3** Given a fully set-up worktree containing development data When `bin/setup --skip-server` runs again Then it exits 0 and the development data is unchanged
- [ ] **AC-5.4** Given a developer runs `bin/setup` interactively without `--skip-server` in any checkout When setup completes Then the dev server starts on that checkout's assigned port (see Story 6)
- [ ] **AC-5.5** Given the clone already has a different custom git hooks path configured When `bin/setup` runs Then it leaves that configuration unchanged, prints a notice that automatic worktree setup was not enabled, and exits 0
- [ ] **AC-5.6** Given the clone has active (non-sample) hooks in its default hooks directory and no custom hooks path When `bin/setup` enables automatic setup Then it prints a notice listing those hooks, since they stop running once the hooks path changes
- [ ] **AC-5.7** Given `bin/setup` runs outside a git repository, or where `git` is unavailable When it runs Then it skips copying and hook enabling with a notice, completes the remaining steps, and exits 0
- [ ] **AC-5.8** Given a main checkout When automatic setup would be triggered by a checkout event there (including `git clone` into a clone whose hooks are configured) Then automatic setup does not run

### Story 6: Parallel dev servers without port clashes

**As a** developer running several worktrees
**I want** each checkout's dev server on its own stable port
**So that** I can run them side by side without configuring anything

**Acceptance criteria:**

- [ ] **AC-6.1** Given the main checkout in development with no `PORT` set When the dev server port is resolved Then it is 3000
- [ ] **AC-6.2** Given a linked worktree in development with no `PORT` set When the dev server port is resolved Then it is in the range 3001–3999, and resolving it again for the same worktree path gives the same port
- [ ] **AC-6.3** Given a fixed set of sample worktree paths When their ports are derived Then every result is in 3001–3999, and the derivation is a pure function of the absolute, symlink-resolved worktree path (distinct paths are expected, but not guaranteed, to get distinct ports)
- [ ] **AC-6.4** Given any checkout with `PORT` set When the dev server port is resolved Then it is `PORT`
- [ ] **AC-6.5** Given setup completes in a linked worktree When its output is read Then it states the URL (including port) the dev server will use, and that port equals the port the dev server binds
- [ ] **AC-6.6** Given the production or test environment, or a checkout without git metadata (such as the container image) When the server port is resolved Then it is `PORT` or 3000, with no git invocation and no error

## Functional Requirements

### FR-1: Checkout detection

**Must:**
- Distinguish a main checkout from a linked worktree using git itself, whichever tool created it. Git's answer is authoritative.
- Locate the main checkout from a linked worktree. If the Orca-provided primary path is set and disagrees with git's, print a notice and use git's.

**Must not:**
- Treat a bare repository's entry as a source of files.
- Fail when not inside a git repository (see AC-5.7).

### FR-2: Copy vs. regenerate inventory

Setup must handle ignored local state exactly as follows:

| Item | Treatment | Reason |
|---|---|---|
| `config/master.key` | **Copy** from main checkout if the worktree lacks it; warn if the main checkout lacks it | Only key for the committed encrypted credentials; cannot be regenerated. Dev/test work without it |
| `tmp/local_secret.txt` | **Copy** from main checkout if the worktree lacks it; otherwise let the app regenerate it | Development secret; sharing it keeps dev sessions/cookies valid across checkouts on localhost |
| Development databases (primary, queue, cache, cable) | **Regenerate** (create, load schema, seed) | Per-worktree isolation; queue/cache/cable hold process state and must never be shared |
| Test database | **Regenerate** | Per-worktree; maintained by the test run |
| Boot/compile caches under `tmp/` | **Regenerate** (on demand) | Keyed to file paths, which differ per worktree |
| Logs, pid files, screenshots, uploaded-file storage | **Neither**: per-worktree, start empty | Runtime artefacts |
| Environment (`.env*`) files | **Neither** | None exist; secrets come from the credentials key |

**Must:**
- Use the repo-root `.worktreeinclude` as the single list of files to copy. It contains only literal, gitignored paths (no globs or negation, since Orca rejects them). Setup copies exactly the paths it lists, so Claude Code, Orca, and `bin/setup` never diverge.
- Copy a file only when the destination is absent, and set each copied file to mode 0600 regardless of the source's mode.
- Leave `tmp/local_secret.txt` untouched by the temp-file clearing step.

**Must not:**
- Copy, symlink, or share any database file, log, or pid file between checkouts.
- Overwrite any existing file in the worktree. This is a `bin/setup` rule. Claude Code or Orca may independently copy the same `.worktreeinclude` files with identical content, which is acceptable.

### FR-3: Automatic triggering

**Must:**
- Run `bin/setup --skip-server` automatically after `git worktree add` in any clone where `bin/setup` has completed once. This covers Claude Code's default worktree creation and Orca's.
- Trigger only in a linked worktree (FR-1) on a new-checkout event (null previous commit, branch checkout).
- Enable that automatic trigger from `bin/setup` using versioned, reviewed hook files in the repository.
- Declare Orca's setup script (`bin/setup --skip-server`) in checked-in Orca configuration.
- Serialize setup per worktree: an invocation that starts while another is running in the same worktree waits for it, then runs (AC-3.3).
- When automatic setup fails, report the failure and the re-run command but exit 0, so worktree creation succeeds for git, Claude Code, and Orca (AC-1.6).

**Must not:**
- Run on ordinary branch switches, file checkouts, or in the main checkout (including right after `git clone`).
- Pass `--reset` or start a server.
- Replace a hooks path the developer has already set to something else.
- Replace Claude Code's own worktree creation mechanism.

### FR-4: `bin/setup` behavior

**Must:**
- Remain idempotent: install missing gems, prepare databases, copy missing files (FR-2), enable automatic triggering (FR-3), and clear logs and temp files as it does today.
- Keep today's interactive default (start the dev server unless `--skip-server`) and flags (`--skip-server`, `--reset`).
- Exit non-zero when any step fails and it was invoked directly (not via the automatic trigger).
- Print a short summary: checkout kind, files copied or missing, and the dev server URL.

**Must not:**
- Prompt for input.
- Delete or reset existing development data unless `--reset` is passed.

### FR-5: Per-checkout dev server port

**Must:**
- In development: use port 3000 in the main checkout. In a linked worktree, use a port in 3001–3999 derived deterministically from the absolute, symlink-resolved worktree path.
- Use a single port-derivation routine shared by the dev server and the setup summary.
- Honour an explicit `PORT` in every checkout and environment.
- Outside development, or when git metadata is unavailable, resolve to `PORT` or 3000 without invoking git (production behaviour unchanged).

**Must not:**
- Require the developer to configure anything for the default behaviour.

### FR-6: Documentation

**Must:**
- Document the worktree workflow in `README.md` and keep `CLAUDE.md`'s command and fact sections in sync. Cover: the supported creators, what is copied vs regenerated, ports and the `PORT` collision remedy, the remote key caveat, the one-time `bin/setup` for plain git, and that enabling automatic setup replaces the clone's default hooks directory.

## Verification

Every acceptance criterion is verified in one of two ways.

**Automated (RSpec, run by `bin/ci`):** 
- Checkout detection.
- Copy rules and 0600 permissions.
- `.worktreeinclude` literal-path and gitignore validity.
- Hook trigger conditions (worktree add vs switch vs main checkout/clone). These run in a throwaway git repository with a stub setup command, so the real setup isn't executed.
- Non-zero trigger failure still exiting 0.
- Setup serialization.
- Hooks-path conflict notices.
- Non-git behaviour.
- Port derivation as a pure unit, including the non-development fallback.
- Inspection of the Orca configuration, the ignore rules, and the lint exclusions.

Covers AC-1.2, 1.3, 1.5, 1.6, 2.2, 3.1, 3.3, 4.1 (the warning), 4.2, 5.2, 5.5–5.8, 6.1–6.4, and 6.6.

**Manual checklist (recorded in the PR description):**

| Check | ACs |
|---|---|
| Real `git worktree add` end-to-end, with `bin/rspec` inside the new worktree | AC-1.1, AC-1.4 |
| `claude --worktree` | AC-2.1 |
| Local Orca worktree | AC-3.2 |
| Remote Orca runtime, or a simulated main checkout without the key | AC-4.1 |
| Fresh clone | AC-5.1, AC-5.3, AC-5.4 |
| Dev server actually listening on the printed port | AC-6.5 |

## Non-Functional Requirements

### Performance

- With gems already installed, automatic setup of a new worktree finishes within 60 seconds on the developer machine.
- Re-running setup in an already set-up worktree (with `--skip-server`) finishes within 30 seconds.

### Security

- Secret files are copied only from the same user's main checkout on the same machine, never from a network source. Their contents are never printed to output or logs.
- Copied secret files are mode 0600.
- Automatic hooks run only code checked into the repository.

### Reliability

- Setup never leaves a worktree half-copied: a file is either fully present or absent.
- If automatic setup fails, the worktree still exists, the failure and the re-run command are shown, and re-running `bin/setup` completes the setup.
- Everything works identically when run from a subdirectory of the checkout.
- Setup that runs in CI (no key present) completes successfully. The missing-key warning appearing in CI output is acceptable.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Main checkout lacks `config/master.key` (e.g. remote runtime, CI) | Setup continues and exits 0. It warns, naming the file and how to supply it (copy it, or set `RAILS_MASTER_KEY`) |
| Main checkout lacks `tmp/local_secret.txt` | Setup continues silently; app generates a new one |
| Main checkout cannot be located (e.g. only a bare repository entry) | Setup skips copying with a notice and completes the remaining steps |
| Not in a git repository, or `git` missing | Setup skips copying and hook enabling with a notice, completes the rest, exits 0 |
| Gem install or database preparation fails during automatic setup | Trigger prints the failure and "run `bin/setup` in this worktree", then exits 0; the worktree is kept |
| Same failure during a direct `bin/setup` run | Setup exits non-zero naming the failed step |
| Clone has a custom hooks path already | Automatic trigger not enabled; notice printed; setup exits 0 |
| Clone has active hooks in its default hooks directory | Automatic trigger enabled; notice lists hooks that will no longer run |
| A second setup starts while one is running in the same worktree | Second waits, then completes; both exit 0; end state equals one run |
| Orca's primary path disagrees with git's main checkout | Notice printed; git's main checkout is used |
| Assigned worktree port is already in use | Server start fails with the port in the message; the developer sets `PORT` to override |

## Open Questions

None. Plain-git automation, database strategy, port handling, and the missing-key behaviour were decided during specification (versioned hook, fresh regenerate, deterministic per-worktree port, warn-and-continue). The spec review settled hook failure semantics (report, exit 0), the port range (3001–3999), and serialization.

## Out of Scope (Future Considerations)

- Opt-in snapshot of the main checkout's development database into a worktree.
- Supplying the credentials key to remote runtimes (secret manager, `RAILS_MASTER_KEY` injection, environment recipes).
- An Orca archive/teardown script.
- Automatic port-collision resolution (probing for a free port).
- Shared gem install paths or other cross-worktree caching.
- Making the Claude Code project hooks (RuboCop on edit, pre-commit, pre-push `bin/ci`) run against the active worktree rather than `$CLAUDE_PROJECT_DIR` when a session enters a `.claude/worktrees` worktree mid-session.
- Adding `bin/setup --reset` to the Claude Code permission deny list, alongside the existing `bin/rails db:reset` entry.
