# Feature 086: A Start Refuses a Volume That Holds a Prices Database and No Primary

**Status:** Draft
**Version:** 0.1.0
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Depends on:** [spec 081](../081-prices-database-in-backup/spec.md) (the prices database and the order in which a restore places two files; frozen, by [prices](../../architecture/prices.md) and [release and deploy](../../architecture/release-and-deploy.md)), [spec 030](../030-backup-restore/spec.md) (the restore and its refusal of a volume that isn't empty; frozen, by [release and deploy](../../architecture/release-and-deploy.md))
**Branch:** `086-start-refuses-orphan-prices`
**Issue:** [#375](https://github.com/plainprogrammer/Collector/issues/375) (the 1.0 milestone, prices lane, after #363)
**ADR:** none. The start check is not costly to reverse and decides nothing that [ADR 0029](../../adr/0029-prices-database-held-by-the-backup.md) leaves open: that ADR names this start as its follow-up.

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-13 | First draft from issue #375 and the task brief. Decisions 1, 2 and 3 (where the check lives, what "holds a prices database" means, whether development gets it) are my recommendations, put to the coordinator as scope questions and marked *(pending)* until they are answered |

## Problem Statement

`backup:restore` places a version 2 backup's prices database first and the primary last, so that a primary never stands without its prices (spec 081 decision 8). If the restore is killed between the two placings (a SIGKILL, a power loss), the prices file is left alone on the volume. A second restore already refuses that volume and says what to do. A *start* doesn't: `bin/docker-entrypoint` runs `db:prepare`, which creates a new, blank primary (whose first visitor becomes its admin) and leaves the restored prices database alone, because it already has its `schema_migrations`. The new primary's first catalog refresh then gives printings new `catalog_entry_id` values, and the old price history attaches to the wrong printings: prices are keyed by that id with no foreign key across the two files (spec 081 decision 4). That is worse than a blank instance, because nothing about the result looks wrong.

Today the documents tell the operator never to start Collector on such a volume. An instruction in a document is all that stands between a half-restored volume and a wrong price on every card, and an operator who restarts a container (Compose's `restart: unless-stopped` does it unasked) never reads it.

> **Terms.** *Storage directory*: the directory that holds the instance's database files (`storage/`, the volume in the image). *Primary*: the primary database's file, `production.sqlite3` in the image. *Prices file*: the prices database's file, `production_prices.sqlite3` in the image. *Sidecars*: a database file's `-wal`, `-shm` and `-journal` files. *Server start*: a container started with the image's default command, or any command that ends in `./bin/rails server`: the starts that run `db:prepare` today (release and deploy). *One-off command*: any other command run in the image, such as `bin/rails "backup:restore[…]"`. *Orphan prices*: the state this spec refuses: a prices file or one of its sidecars in the storage directory, and no primary.

## Goals

- A server start on a storage directory that holds orphan prices stops before `db:prepare` and before anything is created, exits non-zero, and logs why and what to do.
- A storage directory that holds neither the primary nor the prices file is a new instance, and a storage directory that holds the primary starts as it does today, with or without a prices file.
- The restore's own advice, `docs/backup-restore.md`, the README's restore steps and the area docs say that the start refuses this state, and no longer tell the operator only never to start on it.
- A container run on a built image proves the refusal and the message, and the way out the message gives.

## Non-Goals

- **No automatic repair.** The check never removes, renames or moves a file, and never starts with the prices file set aside. The operator chooses between restoring again and starting blank, and deleting history is theirs to decide.
- **No check of the queue, cache and cable databases.** They hold no price and no id that outlives them; a volume with only those files is a volume whose primary was removed on purpose, and starts as it does today.
- **No check of a primary with no prices file.** That is an instance upgraded from a release before the prices database, or a version 1 backup's restore; its first start creates an empty prices database (spec 081 AC-1.2, AC-5.2).
- **No check of the databases' contents or health.** The check reads directory entries only. It opens no database, so it can't tell a damaged file from a sound one, and it doesn't try (decision 2).
- **No change to how a restore places its files.** The order, the cleanup and the refusal's conditions stay as spec 081 decision 8 made them; only the refusal's advice changes (FR-4).
- **No check in development, in the suite, or in a one-off command** (decisions 1 and 3).

## Users and Context

**Primary users:** an operator who restores a backup onto a new volume and starts Collector on it, with Compose, Kamal or `docker run`.
**Secondary users:** an operator who removes a primary by hand and starts again, expecting a blank instance.
**Usage context:** the container's start, before anyone can sign in. The operator reads the container's log (`docker logs`, `docker compose logs`, `kamal app logs`), and a deploy's health check reports the container as failing.
**User mental model:** "The restore stopped; I started again." They expect either a working instance or a plain statement of what is wrong with the volume, never a working-looking instance with another catalog's prices.

## User Stories

### Story 1: A start refuses orphan prices

**As an** operator whose restore was interrupted
**I want** Collector to refuse to start on the volume and tell me what is wrong
**So that** I don't run an instance whose price history belongs to different printings

**Acceptance criteria:**

- [ ] **AC-1.1** Given a storage directory that holds the prices file and no primary When a server start runs Then the process exits with a non-zero status, `db:prepare` and the server are not run, and the directory holds exactly the files it held before, with their bytes unchanged
- [ ] **AC-1.2** Given the state of AC-1.1 When a server start refuses it Then standard error carries a message that names the storage directory and the prices file, says that the volume holds a prices database and no primary, says that a restore stopped between placing the two files leaves this state and that starting here would keep prices that don't belong to the new catalog's printings, says to remove the prices file and its `-wal`, `-shm` and `-journal` files, and says to then restore again or start blank
- [ ] **AC-1.3** Given a storage directory that holds only one sidecar of the prices file (`-wal`, `-shm` or `-journal`, each in turn) and no primary When a server start runs Then it refuses as in AC-1.1, and the message names the sidecar it found
- [ ] **AC-1.4** Given a prices file with no row in it, or an empty file, and no primary When a server start runs Then it refuses as in AC-1.1 (decision 2)
- [ ] **AC-1.5** Given a restore killed by SIGKILL after it placed the prices file and before it placed the primary (`Collector::Backup::Restore`'s checkpoint `prices_placed`) When a server start runs on that volume Then it refuses as in AC-1.1, and the prices file is the one the restore placed
- [ ] **AC-1.6** Given the state of AC-1.1 and no `SECRET_KEY_BASE` in the environment When a server start refuses it Then the message is the same, not an error about a missing secret (the check initializes nothing)

### Story 2: Every other start is as it was

**As an** operator who doesn't have this state
**I want** my start to be as it was
**So that** nothing about the check can stop a healthy instance

**Acceptance criteria:**

- [ ] **AC-2.1** Given a storage directory that holds none of the five databases When a server start runs Then the check passes, `db:prepare` creates the five databases and the server starts, as before this spec
- [ ] **AC-2.2** Given a storage directory that holds the primary and the prices file When a server start runs Then the check passes and the start proceeds
- [ ] **AC-2.3** Given a storage directory that holds the primary and no prices file (an instance from before the prices database, or a version 1 backup's restore) When a server start runs Then the check passes and `db:prepare` creates the prices database, as in spec 081 AC-1.2
- [ ] **AC-2.4** Given a storage directory that holds only the queue, cache and cable databases, or any of their sidecars, and no prices file When a server start runs Then the check passes (Non-Goals)
- [ ] **AC-2.5** Given the state of AC-1.1 When a one-off command runs (a `backup:restore`, a `runner`, a `db:prepare` by hand) Then the check does not run and the command behaves as it did before this spec; in particular a second `backup:restore` refuses the volume itself (spec 081 AC-5.9)
- [ ] **AC-2.6** Given the state of AC-1.1 When the application is booted by anything that isn't a server start (a development server, the suite, a console, a rake task) Then it boots as before; the check is no initializer and no part of booting (decisions 1 and 3)
- [ ] **AC-2.7** Given the operator followed the message and removed the prices file and its sidecars When a server start runs Then it starts as a new instance (AC-2.1); and Given they then restored a backup onto that volume and removed nothing When a server start runs Then it starts with the restored databases (AC-2.2)

### Story 3: The advice agrees with the start

**As an** operator reading the restore's refusal or the documents
**I want** to be told what the start does
**So that** I know a start on this volume will stop, and why

**Acceptance criteria:**

- [ ] **AC-3.1** Given the state of AC-1.1 When a second `backup:restore` refuses the volume Then its advice says to remove the prices file and its `-wal`, `-shm` and `-journal` files and restore again, and says that a start of Collector refuses this volume as it is; it no longer says only "never start Collector on this volume", and every other refusal's text is unchanged
- [ ] **AC-3.2** Given `docs/backup-restore.md`, `README.md`'s restore steps, and the release and deploy and prices area docs When they describe a volume with a prices file and no primary Then each says that a start refuses it, with the message's cause and way out, and none says that issue #375 will make it refuse (verified by reading, recorded in `verification.md`)

### Story 4: Shown on a built image

**As a** maintainer
**I want** CI to start the real image on this volume
**So that** the wiring (entrypoint, rake task, message, exit status) is proven where operators run it

**Acceptance criteria:**

- [ ] **AC-4.1** Given a built image and a volume that holds a restored instance's prices file and no primary (a restore made, the primary removed) When the container is started with the image's default command Then it exits with a non-zero status within the smoke test's boot allowance, its log holds the message of AC-1.2, and the volume holds no primary
- [ ] **AC-4.2** Given that volume after the prices file and its sidecars were removed When a container is started with the default command Then `/up` answers 200 and the instance is new, as the message promised ("start blank")
- [ ] **AC-4.3** Given a build whose start doesn't refuse the state of AC-4.1 When `bin/backup-smoke` runs Then it fails at that step, naming this spec; and `bin/backup-smoke` is the script CI already runs (`.github/workflows/ci.yml`, step "bin/backup-smoke collector:smoke"), so no workflow changes

## Functional Requirements

### FR-1: The check

On a server start, before `db:prepare`, Collector looks at the storage directory for the primary and for the prices file and its sidecars, and refuses the start when a prices file or one of its sidecars is there and the primary is not.

**Must:**
- Decide by whether files exist: the primary's file (a dangling symlink counts as there, as it does for the restore's own check), and each of the prices file and its sidecars.
- Take the files' names and directory from the application's database configuration, so that `DATABASE_URL` and `PRICES_DATABASE_URL` move the check as they move the databases (decision 5).
- Run in every server start, whatever the environment of the container.

**Must not:**
- Open, read, create, lock, rename, remove or write any database file or sidecar, or create any file of its own.
- Depend on a secret, a credential, a database connection, the queue or the cache.
- Refuse a start for any state other than orphan prices.

### FR-2: Where it runs

The check belongs to the container's start and to nothing else. It runs in the same place and under the same condition as `db:prepare` (server starts only), before it, and when it refuses, the start stops there.

**Must:**
- Run before `db:prepare` and before the server, so that nothing is created.
- Run for the image's default command and for every command that ends in `./bin/rails server`.

**Must not:**
- Run for a one-off command, for the application's initializers, for the suite or for a development server (decisions 1 and 3).

### FR-3: The message and the exit

**Must:**
- Write to standard error, so that it is in the container's log and in a terminal.
- Say, in plain words and in this order: what Collector found (the storage directory, the prices file or sidecars present, no primary); why it stops (a restore stopped between its two placings leaves this, and a start would create a blank primary and keep prices that the new catalog's printings don't own); what to do (remove the prices file and its `-wal`, `-shm` and `-journal` files, then restore again, or start blank); and that nothing was changed.
- Exit with a non-zero status, so that Compose's restart policy, Kamal's health check and a shell all see a failed start.

**Must not:**
- Print a stack trace, a Ruby backtrace or a framework message around it.
- Name any other file than the ones it found and the ones the advice tells the operator to remove.

### FR-4: The restore's advice and the documents

**Must:**
- Change the restore's refusal for this state (`Collector::Backup::Restore#not_fresh`) so that it ends "Collector refuses to start on this volume as it is" in place of "Never start Collector on this volume as it is" (AC-3.1). Its conditions, its other refusals and the order of its placings are unchanged.
- Update every document that says to never start on such a volume (AC-3.2): `docs/backup-restore.md`, `README.md`, `docs/architecture/release-and-deploy.md`, `docs/architecture/prices.md`, the roadmap's #375 row, and `CLAUDE.md`'s status paragraph. ADR 0029 is accepted and keeps its text, which records what was true when it was decided and names this start as its follow-up; the area docs carry the current rule.

**Must not:**
- Edit spec 081, which is shipped: this spec records that it supersedes spec 081 decision 8's "Collector must never be started on such a volume" and the advice of AC-5.9 in part, in the specs index, both directions.

## Non-Functional Requirements

### Performance

- The check reads directory entries only: no database connection, no migration, no network. The start's cost grows by one application load of the kind `backup:restore` already pays (its timing isn't a requirement of this spec).

### Security

- The message names paths inside the storage directory and nothing else of the instance: no secret, no environment variable's value, no user data.

### Reliability

- A start that refuses leaves the volume as it found it (AC-1.1), so the operator can read the message again on the next start and the way out stays open.
- The check has no state: it decides from the directory each time, and a restart loop (Compose's `restart: unless-stopped`) prints the same message each time and changes nothing.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Server start, prices file present, no primary | Refused before `db:prepare`; message of FR-3; exit non-zero; volume untouched (AC-1.1, AC-1.2) |
| Server start, only a prices sidecar present, no primary | Refused the same, naming the sidecar (AC-1.3) |
| Server start, the prices file holds no row or no byte, no primary | Refused the same (AC-1.4, decision 2) |
| Server start under Compose with `restart: unless-stopped` | The container restarts and refuses again, each time with the message, until the operator acts |
| Server start, no database file at all | A new instance; starts as today (AC-2.1) |
| Server start, primary present, prices file absent | Starts; `db:prepare` creates the prices database (AC-2.3) |
| Server start, primary present, prices file present | Starts (AC-2.2) |
| The operator removed the primary on purpose, leaving the prices file, and starts to get a blank instance | Refused with the same message; "start blank" in it means removing the prices file too (decision 2) |
| A one-off command on the refused volume | Not checked; `backup:restore` refuses the volume itself (AC-2.5) |
| The storage directory doesn't exist or can't be read | Not this check's case: it finds no file and passes, and the start meets the same error `db:prepare` gives today |

## Decisions

1. **The check lives in `bin/docker-entrypoint` *(pending: scope question, recommendation)*.** It runs in the `if` that already runs `db:prepare`, before it, by calling a task of the application. The alternative is a Rails initializer that runs before `db:prepare`. An initializer would run on every boot: a console, `runner`, `assets:precompile` at the image's build, the suite, `backup:restore` (which exists to run on this volume), and a development server; each would need an exception, and one that forgot it would stop a restore on the volume it is meant to repair. The entrypoint is the container's start, which is the case the issue names, and `db:prepare` is already there. The `Dockerfile` and the workflows are untouched.
2. **"Holds a prices database" means a prices file or one of its sidecars exists *(pending: scope question, recommendation)*.** The issue's outcome says "with rows" and its bullet says "a prices file present". The bullet wins. Telling a file with rows from one without means opening it, which the check must not do (FR-1): opening it with SQLite creates a sidecar and can replay a stale `-wal`, and for a file that is damaged it fails in a way that is a second thing to explain. A prices file with no rows, a killed restore's own file, and the restore's own refusal (`Databases#occupied`) all say the same: this directory is not a new instance and has no primary. The cost is that an operator who removed a primary on purpose gets the refusal and removes the prices file too; the message says so. A prices file that is empty of rows costs the operator nothing to remove.
3. **Development doesn't get the check *(pending: scope question, recommendation)*.** A development server is `bin/rails server`, which never runs the entrypoint, and its databases are disposable (`db:reset`, `bin/setup`). A developer who removes `development.sqlite3` and keeps the prices file loses a test file's history and gets an empty database that `db:prepare` fills, which is what they asked for. What is refused is the production-shaped start, in the image, whose prices are an operator's. The check doesn't read `Rails.env` to skip itself: it is simply not on the development path (FR-2).
4. **The message names the files it found, not a guess about the cause.** It says what this state is *usually* (a stopped restore), because a restore is how a volume gets a prices file with no primary, and it gives the way out for the other case too (start blank). Exit status 1, as the backup tasks use for a refusal.
5. **The check reads the same configuration as the databases do.** Its code lives outside `lib/collector/backup/` (it is a start check, not a backup command, and `lib/collector/backup/` boots nothing and stays the backup's), and it is a task that doesn't depend on `:environment`, so it initializes nothing, as the backup tasks don't (AC-1.6). It reuses `Collector::Backup::Databases`' reading of `config/database.yml` and the environment's database URLs for the names and the directory, so that the places a start and a restore look at can't differ (one definition of where the files are); the plan decides whether that class is moved or required as it is, and its comment records the second user.
6. **Proof on the image is a leg of `bin/backup-smoke`.** It already restores a backup onto a volume and starts the image on it, so the volume for AC-4.1 is the one it restores, with the primary removed afterwards (the state a killed restore leaves, made without killing anything). CI already runs the script on both architectures, so no workflow changes (AC-4.3). The suite proves the entrypoint's wiring on a scratch directory (AC-1.x and AC-2.x), and a real SIGKILL for AC-1.5, with the helpers of spec 030 (`:backup`, `:committed`, `run_killed_at`).

## Open Questions

- Decisions 1, 2 and 3 are put to the coordinator *(pending)*; nothing else is open.

## Out of Scope (Future Considerations)

- Making a restore atomic (one placing instead of two). Spec 081 decision 8 chose the order that a kill can leave behind, and this spec is the check for what it leaves.
- Checking the same state at `kamal deploy` or in `bin/upgrade-smoke`. The start refuses it wherever it runs.
- A `backup:repair` task that removes the stopped restore's file for the operator.
- A check that a prices file belongs to a primary (a stamp of identity across the two files). Spec 081 decision 4 chose two files with no link between them; this spec only refuses the state in which one is missing.
