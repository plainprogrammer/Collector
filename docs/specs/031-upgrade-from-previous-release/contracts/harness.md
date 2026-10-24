# Contract: `bin/upgrade-smoke` and the helpers under `script/upgrade/`

**Spec requirements:** decisions 1 to 5, 7, 8; FR-1 to FR-8; AC-1.x, AC-2.x, AC-3.x, AC-5.x, AC-6.x, AC-7.3 to AC-7.5, AC-8.3.

## The command

```
bin/upgrade-smoke <previous> <current> [options] [-- extra `run` flags, e.g. --platform linux/arm64]
```

| Argument | Meaning |
|---|---|
| `<previous>` | `auto`: the previous release of the checkout, resolved by `Upgrade::Release#previous` (decision 2), pulled as `ghcr.io/plainprogrammer/collector:X.Y.Z` for the runner's platform (what the image job passes). Or an image reference, used as it is when the engine already has it, pulled otherwise (the hand run, AC-7.3) |
| `<current>` | The image built from the code under test (`collector:smoke` in the image job) |

| Option | Meaning |
|---|---|
| `--previous-version X.Y.Z` | Names the release when `<previous>` is an image whose `org.opencontainers.image.version` label is absent or not a stable `X.Y.Z`. Wins over the label; a disagreement is printed (decision 2) |
| `--previous-ref REF` | `<previous>` is no release (the image of a commit, AC-6.5). The migration tree is read from `REF`, the seed is `seeds/next.rb` with the `next` exceptions, every expected change whose migration is in `REF`'s tree is retired, and the run prints that it is not a release proof |
| `--timeout SECONDS` | The step's own limit; default 600 (AC-7.4) |

| Environment | Meaning |
|---|---|
| `CONTAINER_CLI` | `docker` when present, else `podman`, as `bin/backup-smoke` |
| `SMOKE_BOOT_ATTEMPTS` | `/up` polls of 2 s each; default 60 (as `bin/backup-smoke`) |
| `GITHUB_REF_TYPE`, `GITHUB_REF_NAME`, `GITHUB_ACTIONS` | Read by the one resolver of the tag being built (decision 2, AC-1.7) |
| `UPGRADE_IMAGE_REPOSITORY` | The repository `auto` pulls from; default `ghcr.io/plainprogrammer/collector` |

It needs Ruby with the bundle's `sqlite3` and `json_schemer` (it requires `bundler/setup`), `git`, and a container engine. It reads `script/upgrade/` from the checkout it is run in.

## Exit status and output

| Status | Meaning |
|---|---|
| 0 | Every check passed, or `no previous release` (printed, no container started), or the backup leg alone was skipped (printed) |
| 1 | A check failed. The last lines are `FAIL: <step>: <what>`, `read: <what to read>` and `reproduce: <command>` |

Steps print `== <step>` lines, in this order (AC-7.3, AC-2.9): `resolve`, `seed and rules` (before any container, AC-2.7), `pull`, `boot the previous release`, `seed`, `before the stop`, `stop and snapshot the old database`, `upgrade`, `snapshot and compare`, `behaviour`, `backup leg` (or its skip line), `seed of the next release`, then `OK: ...`. For an explicit image whose release is read from its label, `seed and rules` follows `pull`. A failure prints the previous release's tag and image digest, the code under test's commit (`git rev-parse HEAD`), the step and its evidence (AC-7.5). Every container, volume and the temporary directory are removed on every exit path (AC-7.3, FR-6).

The comparison prints one line per table of the old database: `<table>  old <n>  new <n>  same|differs`, then one line per difference (`FAIL <table>[.<column>]: <kind>, first key <key>`), per expected change (`expected: ... (<reason>)`), per retired entry (`retired: ...`) and per seed exception (`seed exception: <table> (<reason>)`).

## Time

The step fails after `--timeout` seconds (default 600) with the elapsed time printed; the workflow adds `timeout-minutes: 12` as its own backstop (AC-7.4).

## The commands it may run (AC-3.4, AC-8.3)

Every command goes through `Upgrade::Engine`, whose builders are the only code that makes an argument list. `Engine#run` refuses a list that no category accepts, and any list holding one of `db:schema:load`, `db:reset`, `db:drop`, `db:setup` (the constant `Engine::FORBIDDEN`).

| Category | Command (after the engine) |
|---|---|
| `pull` | `pull [--platform P] IMAGE` |
| `inspect` | `image inspect IMAGE`, `inspect --format '{{.State.Running}} {{.State.ExitCode}}' NAME` |
| `start` | `run -d --name NAME [flags] -p 127.0.0.1::8080 -v VOLUME:/rails/storage [-v DIR:/backups] -e SECRET_KEY_BASE=S -e HTTP_PORT=8080 -e SOLID_QUEUE_IN_PUMA=true IMAGE` (the image's own entrypoint boots it: `db:prepare`, then the server) |
| `observe` | `port NAME 8080`, `logs NAME` |
| `stop` | `stop -t 30 NAME`, `rm -f NAME` |
| `runner` | `exec -i NAME bin/rails runner -` (the seed or a check on stdin) |
| `tasks` | `exec NAME bin/rails -T backup`, `exec NAME bin/rails backup:create[/backups]` |
| `restore` | `run --rm -u 1000 [flags] -v VOLUME:/rails/storage -v DIR:/backups:ro -e SECRET_KEY_BASE_DUMMY=1 IMAGE bin/rails backup:restore[/backups/FILE]` |
| `files` | `run --rm -u 0 -v ... IMAGE <ls | cp | chown | chmod | rm -rf> ...` on the volume or the temporary directory only |
| `volume` | `volume create NAME`, `volume rm -f NAME` |

The only `db:*` task that runs is the one in the image's entrypoint (`db:prepare`), caused by starting the image, never named by the harness.

## The helpers

| File | Constant | Public interface |
|---|---|---|
| `release.rb` | `Upgrade::Release` | `new(dir = Dir.pwd, env: ENV)`; `#versions`, `#building`, `#previous` (a `Version` or nil; raises `TagsNotFetched`), `#migration_files(ref)`, `#migration_versions(ref)`, `#show(ref, path)`, `#ancestor?(ref)`, `#head`; `Release::Version` (`parse`, `<=>`, `stable?`, `number`) |
| `guard.rb` | `Upgrade::Guard` | `new(release, root:)`, `#call` → `Result(ok?, lines)`; run as a script it prints the lines and exits 0 or 1 (the `bin/ci` step) |
| `snapshot.rb` | `Upgrade::Snapshot` | `.consolidate(source_dir, basename, target)` (copies the main file and any `-wal`, `-shm`, `VACUUM INTO target`), `.open(path)` (read-only `SQLite3::Database`) |
| `compare.rb` | `Upgrade::Compare` | `new(old_db, new_db, expected: [], optional: [], emptied: [])#call` → `Report`; `.tables(db)`, `.count(db, table)`, `.integrity(db)`, `.seed_problems(db)` |
| `rules.rb` | `Upgrade::ExpectedChanges`, `Upgrade::SeedExceptions` | `ExpectedChanges.load(path, previous_versions:, current_versions:)` → `Loaded(live, retired, errors)`; `ExpectedChanges.restore_effects` and `RESTORE_ENDS_SESSIONS` (the backup leg's allowance); `SeedExceptions.load(path, key)` → `Result(entries, errors)`; `SeedExceptions.coverage(db, entries, label:, seed:, only: nil)` → `[ problems, notes ]` |
| `engine.rb` | `Upgrade::Engine` | `new(cli:, run_flags:, executor:)`; the builders `pull`, `image_info`, `create_volume`, `remove_volume`, `start`, `port`, `state`, `logs`, `stop`, `remove`, `runner`, `tasks`, `task`, `restore`, `copy_database`, `list_directory`, `own`, `remove_directory`; `run` and `run!` are private |
| `web.rb` | `Upgrade::Web` | `new(port)`, `#get(path)`, `#status(path)`, `#sign_in(email, password)`, `.signup_form?(body)` |
| `harness.rb` | `Upgrade::Harness` | `.parse(argv, env:)` → `[ previous, current, options ]`; `new(previous:, current:, release:, engine:, options:, web: Web.method(:new), out: $stdout, root: Dir.pwd, sleeper:)#call` → exit status 0 or 1 |

## The seed's output

A seed prints, as its last line, `UPGRADE-SEED-COMPLETE <json>` where the JSON is `{"release", "password", "users": [{"email", "lots", "names"}], "locations": [names], "marker"}`. The harness reads it as the truth of what was seeded (the credentials, the card names each collector must see, the lot count the export must hold, the locations the page must list, the marker argument of the scheduled job); nothing is duplicated in the harness. A seed that does not print the line, or exits non-zero, fails the run with its output (AC-2.8).
