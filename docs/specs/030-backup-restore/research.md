# Research: Back up and restore an instance

Read-only traces made while planning (spec 030 1.2.1), against `acb6e3c`'s files and the gems in the bundle (`bundle show`: rails 8.1.4, sqlite3 2.10.0, kamal 2.12.0). Nothing was run: plans here aren't executed before approval. Section 8 lists what the first failing test of each phase will confirm.

## 1. Does a production boot of the rake task read `secret_key_base`? (decision 4's D4 ruling)

**Yes, if the task boots the application; and the dummy is enough. The tasks don't boot it, so they read nothing.**

Trace, `railties-8.1.4`, `activestorage-8.1.4`, `activesupport-8.1.4`:

1. `Rails::Application::Configuration#secret_key_base` (`configuration.rb:523`) returns `generate_local_secret` when `ENV["SECRET_KEY_BASE_DUMMY"]` is set; else `ENV["SECRET_KEY_BASE"] || credentials.secret_key_base || (Rails.env.local? && generate_local_secret)`; a nil result in production raises `ArgumentError: Missing 'secret_key_base' for 'production' environment` (`:535-544`). `generate_local_secret` writes `tmp/local_secret.txt` under `Rails.root` when absent (`:653`); the image's build already runs `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile`, so the file exists there and `/rails` is owned by uid 1000.
2. `ActiveStorage::Engine`'s initializer `"active_storage.verifier"` (`engine.rb:175`) does `config.after_initialize { |app| ActiveStorage.verifier = app.message_verifier("ActiveStorage") }`, and the app requires `active_storage/engine` (`config/application.rb:8`). `Rails::Application#message_verifier` is `message_verifiers[name]`; `RotationCoordinator#[]` (`rotation_coordinator.rb:18`) calls `build_with_rotations` at once, and `MessageVerifiers#build` calls the generator block, whose default is `self.secret_key_base` (`application.rb:208`). Active Record does the same in `active_record.generated_token_verifier` (`railtie.rb:354`). Both run in `after_initialize`, which `initialize!` runs.
3. Rake runs `initialize!` only inside the `:environment` task (`application.rb:562`: `require_environment!`). `Rails::Command::RakeCommand#perform` (`rake_command.rb:19`) only loads the Rakefile (`config/application` and `load_tasks`) and runs the requested task; `config/application.rb` reads no secret (`ENV["COLLECTOR_TRUSTED_PROXIES"]` only).

So a task with `=> :environment` needs `SECRET_KEY_BASE` or `SECRET_KEY_BASE_DUMMY=1` in production (the dummy is enough: step 1), and a task without it needs neither. The plan builds the tasks without `:environment` (research section 2) and keeps `SECRET_KEY_BASE_DUMMY=1` in the documented Kamal one-off and in `bin/backup-smoke` as the maintainer ruled, because it costs nothing and keeps the command working if a later change adds `:environment`.

**A wrong master key breaks every production boot, before `secret_key_base` is read** (found in the plan review, M1). `config/storage.yml` holds ERB inside YAML comments (lines 12-13: `#   access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>`), and `ActiveSupport::ConfigurationFile#parse` renders ERB whenever the file contains `<%` (`configuration_file.rb:21`), knowing nothing of YAML comments. The file is parsed in `on_load(:active_storage_blob)` (`active_storage/engine.rb:180-188`), which production's eager load triggers; and the `active_record_encryption.configuration` initializer reads `app.credentials.dig(:active_record_encryption, …)` as soon as `ActiveRecord::Encryption` loads (`active_record/railtie.rb:361-366`). `EncryptedConfiguration#read` rescues only `MissingContentError` (`encrypted_configuration.rb:62-66`), so a wrong key raises `ActiveSupport::MessageEncryptor::InvalidMessage` with or without `SECRET_KEY_BASE_DUMMY`. With **no** key, `EncryptedFile#read` raises `MissingContentError`, which is rescued, and credentials come back empty: that is the image's case (it has no key file), so this doesn't affect operators. It does affect how the plan tests the question.

**How the plan tests it** (Phase 5): two kinds of child, `RAILS_ENV=production`, `SECRET_KEY_BASE` and `SECRET_KEY_BASE_DUMMY` removed. (a) The tasks, with `RAILS_MASTER_KEY` a 32-digit wrong key (so a dev machine's real `config/master.key` can't supply a secret; the tasks read no credentials, so the wrong key is harmless): `backup:restore` and `backup:create` must answer their own refusals ("No file was given."), exit 1, and print no `secret_key_base` or `ArgumentError`; and an in-process example shows neither task has `environment` among its prerequisites (the structural guarantee). (b) The control and the dummy example run `bin/rails runner` with **no** master key and are skipped, with the reason, when `config/master.key` exists (testing that it exists reads nothing; CI has no key): the control must fail with `/secret_key_base/` in its stderr (a credentials error would prove nothing about the secret), and the dummy example must boot. If someone adds `:environment` to a task, the prerequisite example fails at once. `bin/backup-smoke` runs the restore pass of its second leg with neither variable set, in the image.

## 2. What the tasks may use before the application is initialized

- `Rails.root`, `Rails.env` and `Rails.application.config.database_configuration` work before `initialize!`: the last parses `config/database.yml` (`configuration.rb:453`). `ActiveRecord::DatabaseConfigurations.new(hash).configs_for(env_name:)` turns it into `HashConfig`s with `name` and `database`, merging `DATABASE_URL` as Rails does everywhere. No connection pool is created.
- Autoloading is not set up before `initialize!` (the autoloaders start in the finisher's initializers). `lib/` is autoloaded in the booted app (`config.autoload_lib`), so code in `lib/collector/backup/` is found there; the rake file `require`s it by path for the un-booted case. There is precedent: `bin/fetch-ocr-engine` requires `lib/collector/ocr_engine.rb` before the app exists, and that file already reads a `.tar.gz` with `Gem::Package::TarReader` over `Zlib::GzipReader` (`ocr_engine.rb:73`, specified in `spec/lib/collector/ocr_engine_spec.rb`).
- `ActiveRecord::MigrationContext.new` evaluates `connection_pool` (`migration.rb:1225`) and its `#migrations` is `:nodoc:`, so the release's migrations are read as the framework does: `Dir["db/migrate/**/[0-9]*_*.rb"]` and the leading digits of each file name (`migration.rb:1377`). Primary's `migrations_paths` is the default `db/migrate`.
- `DatabaseTasks.initialize_database` (`database_tasks.rb:651`) calls `schema_migration.table_exists?` and, when it is false and `db/schema.rb` exists, `load_schema`. A restored primary has `schema_migrations`, so the first boot only migrates; an empty file at the primary's path would be loaded with the schema as a blank instance. This confirms FR-8's reason.

## 3. SQLite facts the plan relies on

- `SQLite3::Database.new(path)` opens `READWRITE | CREATE` (`sqlite3-2.10.0/lib/sqlite3/database.rb:143`); `readonly: true` and `readwrite: true` (no create) are the other modes. The restore never passes the primary's path; the backup opens its source `readwrite: true` so that a missing source raises `SQLite3::CantOpenException` instead of creating an empty file. Errors are `SQLite3::CorruptException`, `NotADatabaseException`, `BusyException`, `FullException`, `CantOpenException`, `SQLException` (`errors.rb`).
- `VACUUM INTO ?` takes a bound string; the target must not exist or must be empty, so the backup creates the 0600 file first (decision 7). The statement runs in one read transaction (WAL writers keep going), and a corrupt b-tree makes it raise `SQLITE_CORRUPT` after possibly writing part of the target.
- A snapshot's header bytes 18 and 19 are 1 (rollback journal) or 2 (WAL). The plan doesn't rely on what `VACUUM INTO` writes there: it sets `PRAGMA journal_mode = DELETE` on the verified snapshot, closes it and asserts the two bytes are 1 (a spec asserts them too).
- The primary holds an FTS5 table, `catalog_names_fts` with `content='catalog_names'` (`db/migrate/20260930170000_create_catalog_names.rb`) and its shadow tables. `VACUUM INTO` copies it. The spec helper that empties the test database must not `DELETE` from the shadow tables (it would corrupt the index): it skips every `catalog_names_fts*` table and the specs of this feature create no `catalog_names` rows.
- `PRAGMA foreign_key_check` reports violations whatever `foreign_keys` is set to; decision 6 says the checks set `PRAGMA foreign_keys = ON` explicitly anyway (SQLite's default is off), so `Snapshot#verify!` sets it (allowed on a read-only connection) and `end_sessions!` sets it before the cascading delete.
- The backup converts the snapshot to rollback-journal mode before it verifies it: the plan doesn't rely on the journal mode `VACUUM INTO` writes, and a read-only open of a file with a WAL header may create `-shm` and `-wal` beside it, which a killed run would leave (the sweep's pattern covers those sidecars).

## 4. Active Record can't open the snapshot

The Rails SQLite adapter sets `journal_mode: :wal` on every connection (`activerecord-8.1.4` SQLite3 adapter's default pragmas), which would turn the snapshot into a WAL database and leave `-wal` and `-shm` beside it. Every snapshot (the backup's `.partial`, the restore's temporary file) is therefore opened with `SQLite3::Database` (decision 6). `config/database.yml` is not touched (`.claude/rules/sqlite-and-migrations.md`).

## 5. Kamal 2.12.0

- `kamal app exec` without `--reuse` runs `docker run --rm --name … --network kamal` with `role&.env_args(host)` (the role's `--env-file .kamal/apps/<service>/env/roles/web.env`, written by the app boot), the `--env` values, then the image tag (`commands/app/execution.rb:10`); it uses `latest` unless `--version` is given. With `--reuse` it `docker exec`s in the running container and so shares its mounts. The spec's sequence (decision 4) therefore stands: restore with a plain `docker run` over `ssh` (or `kamal server exec`), then `kamal setup`/`deploy`.
- `config/deploy.yml`'s `volumes:` takes `host:container[:options]` strings, so a host directory is `- "/srv/collector-backups:/backups"` next to the existing named volume. Aliases are `name: command` strings (`config/deploy.yml` has six).
- `kamal server bootstrap` installs Docker on the host (`cli/server.rb:38`).
- Nothing here is exercised through Kamal: the maintainer has no host (decision 4). `bin/backup-smoke` runs the same container command.

## 6. The archive's reader and writer

`Gem::Package::TarWriter#add_file_simple(name, mode, size)` writes a ustar header and yields a stream limited to `size`; `#close` writes the end blocks and leaves the underlying IO open, so the plan calls `GzipWriter#finish`, then `fsync` and `close` on the file. Reading is the plan's own 40 lines, not `TarReader`: classification (FR-2, AC-3.1, AC-3.3) depends on exactly which first bytes, which first entry and which zlib error means "not a backup" versus "incomplete", and the plan wants that visible and tested rather than inferred from `TarReader`'s errors on garbage. The writer's output is checked against the system `tar` (a spec lists and extracts it), which is also the manual recovery path.

## 7. Test-suite facts

- `config.use_transactional_fixtures = true` globally (`spec/rails_helper.rb:46`); a group sets `self.use_transactional_tests = false` to commit. The test database is the file `storage/test.sqlite3` (`config/database.yml`), WAL, with Solid Queue's tables loaded on demand by `spec/support/solid_queue.rb`.
- `VACUUM INTO` can't run inside a transaction, and the writers of AC-1.2 and AC-1.3 need their own connections (`ActiveRecord::Base.connection_pool.with_connection` in threads), so these examples commit and clean up after themselves (Phase 0's helper).
- `DATABASE_URL` is read by `DatabaseConfigurations` for the current environment, so the specs that boot the application against a restored file (AC-2.2, AC-3.6) start a child `RAILS_ENV=test DATABASE_URL=sqlite3:<abs path> bin/rails …`: no setting is added to the application.
- `ExportFormatRules.same_collection?(one, other)` (`spec/support/export_format_rules.rb:36`) is the helper for "the same collection" (AC-2.2). Spec 029 changes that file for format version 2; this plan calls it only through its current signature.

## 8. What the first failing test of each phase confirms (not run in the plan)

| Where | Assumption to confirm | If it fails |
|---|---|---|
| Phase 2 | `VACUUM INTO ?` accepts a bound parameter and an existing empty 0600 file, on `readwrite: true` | use string interpolation of a `SQLite3::Database.quote`d path; the file rules stay |
| Phase 2 | the snapshot's header bytes are 1 after `PRAGMA journal_mode = DELETE` | the spec asserts them; if the bytes still read 2, set `PRAGMA journal_mode = DELETE` on a second connection after the first is closed and assert again |
| Phase 1 | `Zlib::GzipReader#read(n)` raises a `Zlib::Error` subclass on a truncated stream and a CRC or length error at the end | map the class the spec shows |
| Phase 1 | `Gem::Package::TarWriter` entries extract with the system `tar` | adjust the mode or name arguments |
| Phase 3 | `df -Pk <dir>` prints `Available` in column 4 on macOS and the image | `FreeSpace` returns nil (check skipped) when it can't parse |
| Phase 6 | `docker cp` out of a bind mount into a host directory creates files owned by the caller; `docker create` + `cp` + `-u 0 chown` works on the CI runner | the script's fallbacks (see its comments) |
| Phase 0, 5 | `Collector::Backup` is required by path everywhere (the rake file, the spec support file, the child processes) and is in `autoload_lib`'s ignore list, so Zeitwerk doesn't manage it | `bin/rails zeitwerk:check` passes because of the ignore; if it still complains, list the files it names |
| Phase 5 | the control boot (production runner, no master key, no secret) fails with `secret_key_base` in its stderr, and the dummy boot succeeds | if another initializer fails first (a database or asset), read the message, make the child's environment supply what it needs, and keep the regex on `secret_key_base`; if the dummy boot touches `storage/`, limit the file assertion to `production.sqlite3*` |
| Phase 3 | the sweep removes a killed run's `-journal`, `-wal` and `-shm` sidecars by the widened pattern | adjust the pattern, not the age rule |

## 9. Files both this plan and spec 029's plan edit (rebase notes)

Spec 029 is executed on its own branch (`029-manage-locations`) in parallel. This plan does not depend on any file that exists only there. Files both touch, so that the later merge rebases cleanly:

| File | 029's change | This plan's change |
|---|---|---|
| `README.md` | the "Your data" paragraph (locations, version 2 exports) | a pointer and the comparison in the same part, and a new "Backup and restore" section after "Self-hosting"; keep both paragraphs |
| `CLAUDE.md` | the status paragraph and three Non-obvious Facts | the status paragraph (a sentence), a "Backup and restore" fact, `bin/backup-smoke` in Commands |
| `docs/releasing.md` | an upgrade note | an upgrade note and release-check step 5 |
| `docs/roadmap.md` | item 9 done, item 10's wording | item 6 done |
| `docs/specs/README.md` | the 029 row | the 030 row |
| `docs/adr/README.md` | index line 0023 and the "Expected" paragraph (drops nothing of the backup) | index line 0024 and the "Expected" paragraph (drops "the backup mechanism (item 6)") |
| `spec/support/export_format_rules.rb`, `app/models/export_format/**`, `app/models/collection_*` | version 2 | none (read only) |

Both plans touch the "Expected" paragraph of `docs/adr/README.md`: on rebase, keep 029's added text and drop the backup mechanism from the list. An unmerged ADR takes the next free number on rebase: this one is 0024 only while 0023 is 029's.
