# Implementation Plan: Back Up and Restore an Instance

**Spec:** docs/specs/030-backup-restore/spec.md (v1.2.1, Approved by the maintainer on 2026-10-21)
**Status:** Approved by the maintainer on 2026-10-21, after two independent read-only reviews (Opus: NEEDS REVISION, 1 critical, 3 major, 13 minor; Sonnet: APPROVE WITH NITS, 4 minor) with the second review's nits folded in. The maintainer accepted ADR 0024 (its Status changes in Phase 8, step 8.5) and chose Sonnet for execution. Written without running anything: it was traced against the files it edits and the gem sources (`research.md`). Every finding, its fix and the rulings are in [plan-review.md](plan-review.md).
**Decisions:** docs/adr/0024-backup-with-vacuum-into.md (Proposed, written with this plan; accepted by the maintainer 2026-10-21, status changed in Phase 8); ADRs 0016, 0017, 0019, 0020, 0022 apply
**Created:** 2026-10-21 (on `d67554b`, spec 1.2.0, then the approval commit; `origin/main` at `acb6e3c`)
**Supporting:** [data-model.md](data-model.md), [contracts/tasks.md](contracts/tasks.md), [contracts/archive.md](contracts/archive.md), [research.md](research.md), [plan-review.md](plan-review.md), [issue-art-index-ready.md](issue-art-index-ready.md)

## Global Constraints

Copied from the spec; each applies to every phase.

- One pull request: the library and the two tasks, the suite, `bin/backup-smoke` and its CI step, the documents and the ADR (decision 15). No migration, no table, no column, no setting, no route, no controller, no view (spec NFRs, AC-6.2).
- The commands: `bin/rails "backup:create[DIRECTORY]"` and `bin/rails "backup:restore[FILE]"`; the directory and the file are required arguments; no default under `storage/` (decision 4). Neither runs a job, a request or a process; neither calls the network (FR-3).
- A backup is `collector-backup-YYYYMMDDTHHMMSSZ.tar.gz` (UTC, no colon): a gzip'd tar of `manifest.json` then `primary.sqlite3`, mode 0600, written under a `.partial` name created 0600, fsynced, read back, then hard-linked to its final name, never replacing a file (decisions 5 and 7). It holds the primary database only; no secret, no Active Storage file (decisions 2 and 3).
- A restore needs a fresh volume (none of the four databases, no `-wal`, `-shm` or `-journal`), places the snapshot through a temporary file it links into place after every check, never opens a connection to the primary's path, ends every session with foreign keys on (cascading to the bulk removals, selections and marks), and migrates nothing (decisions 6, 7, 10; FR-2, FR-3, FR-8).
- Snapshots are opened with `SQLite3::Database` only, never Active Record (decision 6).
- A refusal is two plain sentences (what is wrong, what to do), no exception class, no backtrace, exit status 1; it leaves the volume as it was (FR-4, AC-3.8). That includes the slips decision 4's ownership rules invite: a file or a volume the container's user can't read or write is a named refusal, and a system or SQLite error nothing else names ends in the same two lines (`Backup.run`'s last rescue).
- Core code names no collectible: the new files contain neither `MTG` nor `Scryfall` (FR-5).
- No secret is written into a backup, printed or logged; the output holds file names, paths, sizes, counts of accounts, users and lots, the schema version and times, never a name or an address (FR-10, AC-1.7).
- The tasks don't depend on `:environment` (research.md 1, 2): they initialize nothing, read no `secret_key_base` and open no Active Record connection. The library is in `lib/collector/backup/`, required by path and not autoloaded (`config/application.rb`, Phase 0). `SECRET_KEY_BASE_DUMMY=1` stays in the documented Kamal one-off and in `bin/backup-smoke` as the maintainer ruled.
- Every phase ends green: its last step is the whole `bin/rspec` passing, with RuboCop and Brakeman clean; each phase adds files and edits no expectation of an existing spec except where its own step says so (`.claude/rules/testing.md`).
- TDD is the hard gate: every implementation step has a failing test before it. Prose documents are verified by reading and recorded in `verification.md`, never by RSpec (`.claude/rules/testing.md`).
- Plans here are not executed before approval: this plan was traced, not run (research.md 8 lists what each phase's first failing test confirms).
- Commits: Conventional Commits, one per step or change, ending with the executing model's attribution line (the one the session's system reminder gives; execution is by the maintainer's choice of agent); stage by name; one git operation per call (the project's hooks read the command text).

---

## Goal

An operator backs up a running instance with one command into one verified file, and restores that file onto a new, empty volume with one command; a damaged, partial or wrong-release file is refused before anything changes; and the procedure is documented for Compose, Podman and Kamal, proven in the suite, proven in CI against a built image, and proven once by the maintainer on their own collection.

---

## Scope Check and Gates

One outcome (decision 15), six stories, no split. One pull request, nine phases (0 to 8).

- **Simplicity (≤3 components):** (1) the file: `Manifest` and `Archive`; (2) the database operations: `Snapshot`, `Databases`, `FreeSpace`; (3) the two commands: `Create` and `Restore`, with `Refusal`. Each is a few small files in `lib/collector/backup/`; the two tasks are a dozen lines. No gem is added: `Zlib`, `Gem::Package::TarWriter` (already used by `lib/collector/ocr_engine.rb`), `Digest`, `FileUtils`, `Open3` and the `sqlite3` gem that is already in the bundle.
- **Anti-abstraction:** `VACUUM INTO`, `PRAGMA integrity_check`, `PRAGMA foreign_key_check`, `df`, `File.link` and `fsync` are used directly. `Snapshot` is one class because every SQLite call of both commands must agree on how a file is opened (never through Active Record, never creating a file); it wraps no SQLite API beyond that.
- **Integration-first:** [contracts/tasks.md](contracts/tasks.md) and [contracts/archive.md](contracts/archive.md) precede code; Phase 0 starts with the failing specs of the three smallest pieces; Phase 1 with the archive's, before any command exists.

## Areas and supersessions

- **Area docs to change:** none exists for this area. The release-and-deploy area doc is not written (spec 027 slice C, #109) and stays listed as not written in `docs/architecture/README.md`; `CLAUDE.md` gains the pointers (Phase 7) and `distill-feature` writes the area doc at the end if the slice has landed.
- **Supersedes:** nothing in a shipped spec. ADR 0016's consequence "the mechanism, and whether a backup includes those files, is undecided" is closed by ADR 0024 (the ADR isn't edited); `docs/adr/README.md`'s "Expected" line loses the backup mechanism; `.claude/rules/sqlite-and-migrations.md` points to the ADR (Phase 7).
- **ADR number:** 0024. `origin/main` holds ADRs up to 0022 and the in-flight branch `029-manage-locations` takes 0023 (and `docs/adr/README.md` names 0023 for spec 027 slice B's YARD ADR, which takes the next free number if it merges first). An unmerged ADR takes the next free number on rebase: whoever merges second renumbers its file, its H1, its index line and the references to it (this plan's `plan.md`, `research.md`, the spec's "Documents that change", `docs/backup-restore.md`, `CLAUDE.md`, `docs/roadmap.md`, the rules file), and says so in its Status line, as ADRs 0012, 0014 and 0015 do.
- **Files both this plan and spec 029's plan edit** (`README.md`, `CLAUDE.md`, `docs/releasing.md`, `docs/roadmap.md`, `docs/specs/README.md`, `docs/adr/README.md`): the table with the rebase notes is in research.md 9. Nothing here depends on a file that exists only on the 029 branch; the one shared support helper, `ExportFormatRules.same_collection?`, is used through its current signature.

## File Structure

| File | Responsibility |
|---|---|
| `lib/collector/backup.rb` | The namespace: constants, `Backup.run`, `.argument`, the file helpers (`create_private`, `remove`, `fsync_*`, `publish`), the phrase helpers; requires the rest |
| `lib/collector/backup/refusal.rb` | `Refusal`: problem and advice |
| `lib/collector/backup/databases.rb` | The environment's databases, from `config/database.yml`, and a fresh volume's definition |
| `lib/collector/backup/free_space.rb` | Bytes available, from `df` |
| `lib/collector/backup/manifest.rb` | `manifest.json`: build, parse, validate |
| `lib/collector/backup/archive.rb` | The gzip'd tar: write, read, classify |
| `lib/collector/backup/snapshot.rb` | Every SQLite operation: `VACUUM INTO`, verify, counts, versions, end sessions, rollback-journal mode |
| `lib/collector/backup/create.rb`, `restore.rb` | The two commands |
| `lib/tasks/backup.rake` | `backup:create`, `backup:restore`: argument, print, exit |
| `config/application.rb` (edit) | `autoload_lib` ignores `collector/backup` |
| `spec/support/backup_helpers.rb` | The suite's support layer (scratch directories, committed instances, the killed child, the app child, the restored instance) |
| `spec/lib/collector/backup/*_spec.rb`, `spec/tasks/backup_*_rake_spec.rb` | The library and the tasks |
| `spec/backup_guards_spec.rb`, `spec/backup_restored_*_spec.rb`, `spec/backup_upgrade_spec.rb`, `spec/backup_boot_spec.rb` | The guards, the restored instance, the upgrade path, the boot |
| `bin/backup-smoke` | The image-level proof |
| `.github/workflows/ci.yml`, `config/deploy.yml`, `.dockerignore`, `bin/image-smoke`, `spec/image_publishing_spec.rb` (edit) | The CI step, the Kamal alias, keeping the script out of the image |
| `README.md`, `docs/backup-restore.md`, `docs/releasing.md`, `CLAUDE.md`, `docs/roadmap.md`, `.claude/rules/sqlite-and-migrations.md` | The documents |
| `script/backup/measure.rb` | The measurement of decision 13, outside the suite and the image |
| `docs/specs/030-backup-restore/verification.md` | Evidence, measurements, the maintainer's NAS restore, the implementation review |

---

## The `secret_key_base` finding (D4)

The maintainer's ruling asks the plan to confirm that a production boot of the restore task doesn't read `secret_key_base` eagerly, and if it does, that the dummy is enough. The trace is in [research.md section 1](research.md#1-does-a-production-boot-of-the-rake-task-read-secret_key_base-decision-4s-d4-ruling); in short:

- **A booted application does read it eagerly.** `active_storage.verifier` (`activestorage-8.1.4/lib/active_storage/engine.rb:175`) calls `app.message_verifier` in `after_initialize`, and `RotationCoordinator#[]` builds the verifier at once, calling the generator that reads `config.secret_key_base` (`railties-8.1.4/lib/rails/application.rb:208`); Active Record's `generated_token_verifier` does the same. Without `SECRET_KEY_BASE`, `SECRET_KEY_BASE_DUMMY` or readable credentials, production raises `Missing secret_key_base`. **`SECRET_KEY_BASE_DUMMY=1` is enough**: the configuration then returns a locally generated secret (`configuration.rb:525`), the way `RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile` already boots the image's build.
- **The tasks don't boot the application.** Rake initializes only inside its `:environment` task (`application.rb:562`); `RakeCommand` loads the Rakefile and runs the requested task. `backup:create` and `backup:restore` don't depend on `:environment`, so they read no secret and need no dummy; they also can't open an Active Record connection (FR-8's guarantee becomes structural). The library is therefore required by path and not autoloaded.
- **How the plan tests it** (Phase 5, `spec/backup_boot_spec.rb`): a child production process with no secret, no dummy and a wrong master key runs `backup:restore` and `backup:create` and gets only the tasks' own refusal (the wrong key is safe there: the tasks read no credentials); an in-process example shows the two tasks' prerequisites exclude `environment` (the structural guarantee). The control and the dummy example run `bin/rails runner` **without any master key**, and are skipped, with the reason, when a `config/master.key` file exists (CI has none): with a wrong key every production boot raises `InvalidMessage` before `secret_key_base` is read, because `config/storage.yml`'s commented-out ERB reads credentials when Active Storage's blob loads, so the control would pass for the wrong reason and the dummy example could not pass (plan-review M1, research.md 1). The control's regex is `/secret_key_base/` only. Every child is given a scratch `DATABASE_URL` and the examples assert no file appeared in `storage/`. `bin/backup-smoke` restores once with the dummy (the maintainer's command) and once with neither variable set. **The confirmation therefore rests on the tasks' structure plus the dummy example run where no key exists (CI and the image), not on a boot with a wrong key**; `verification.md` records it that way.
- **What stays as ruled:** the documented Kamal one-off and the smoke script's first restore keep `-e SECRET_KEY_BASE_DUMMY=1`. It costs nothing and keeps the command working if a later change adds `:environment`; the README says it stands for a secret the restore doesn't read.

## Decision 12's separate issue

The art index shown as "ready" when its index file is missing is not fixed here. The text to file is in [issue-art-index-ready.md](issue-art-index-ready.md) for the coordinator to file; this plan does not file it. The workaround is documented (README: press **Build art index**) and AC-2.8 tests that the build then needs no request.

---

## Requirement Map

Every criterion, requirement and decision → its phase → its first failing test (file, example). Phase 0 to 5 examples live under `spec/`; "reading" means a document criterion verified by reading and recorded in `verification.md`; "script" means `bin/backup-smoke`, proven by CI.

| Requirement | Phase | First failing test |
|---|---|---|
| AC-1.1 | 3 | `create_spec` "writes one file named by the UTC second and returns its facts"; `backup_create_rake_spec` "prints the file's path, size, schema version…" |
| AC-1.2 | 3 | `create_spec` "holds both rows of every pair or neither, passes its checks…" |
| AC-1.3 | 3 | same example (no error, no wait over the busy timeout, writes landed during a backup) |
| AC-1.4 | 1, 2, 3 | `archive_spec` ".write makes a private gzip'd tar…"; `snapshot_spec` "#rollback_journal!"; `create_spec` "holds the manifest and a rollback-journal snapshot…" |
| AC-1.5 | 2, 3 | `snapshot_spec` ".take calls a source with a page it can't read damaged"; `create_spec` "refuses a damaged database…" |
| AC-1.6 | 3 | `create_spec` "leaves at worst a private .partial file when it is killed…", "removes a .partial file more than a day old…" |
| AC-1.7 | 3, 4 | `backup_create_rake_spec` and `backup_restore_rake_spec` "prints no recognisable name, address or card, and logs none" |
| AC-1.8 | 3 | `create_spec` "is private and holds no secret or setting…" |
| AC-1.9 | 3 | `create_spec` "never replaces a file…", "gives two runs started together one file…" |
| AC-1.10 | 8 | `script/backup/measure.rb`, recorded in `verification.md` (outside the suite) |
| AC-1.11 | 0, 3 | `free_space_spec`; `create_spec` "refuses a directory that doesn't exist, can't be written or has too little room…" |
| AC-1.12 | 2, 3 | `snapshot_spec` "counts the rows that fail the foreign-key check"; `create_spec` "refuses a database that fails its foreign-key check…" |
| AC-2.1 | 2, 4 | `snapshot_spec` "#end_sessions!"; `restore_spec` "places the snapshot with the sessions ended and every other row as it was" |
| AC-2.2 | 5 | `backup_restored_instance_spec` "signs the collector in… exports the same collection" |
| AC-2.3 | 6 | script (`verify_restored`), first CI run |
| AC-2.4 | 5 | `backup_restored_instance_spec` "ends every session…" |
| AC-2.5 | 4 | `restore_spec` "a volume that isn't fresh" (three cases) |
| AC-2.6 | 4 | `restore_spec` "a restore that is refused or stopped" |
| AC-2.7 | 4, 5 | `restore_spec` "reads no secret…"; `backup_boot_spec` |
| AC-2.8 | 5 | `backup_restored_art_spec` |
| AC-2.9 | 5 | `backup_restored_catalog_spec` "reads a refresh recorded as running as interrupted…" |
| AC-2.10 | 5 | `backup_restored_catalog_spec` "answers 'Preview the file again.'…" |
| AC-2.11 | 4 | `restore_spec` "restores an instance with no users…" |
| AC-3.1 to AC-3.4 | 1, 4 | `archive_spec` (each case); `restore_spec` "a wrong or damaged file" (each case with the volume unchanged) |
| AC-3.5 | 4 | `restore_spec` "refuses a newer release's backup…" |
| AC-3.6 | 5 | `backup_upgrade_spec` |
| AC-3.7 | 2, 4 | `snapshot_spec` "#verify!"; `restore_spec` "refuses a snapshot with an unreadable page, and one with an orphan row…" |
| AC-3.8 | 0, 4 | `restore_spec` `expect_refused` (plain-sentence check on every refusal, including an unreadable file and an unwritable volume); `backup_restore_rake_spec` "prints each refusal as two lines…"; `run_spec` (an unnamed system or SQLite error ends in two plain lines) |
| AC-4.1 | 3 | `create_spec` "is private and holds no secret or setting…" |
| AC-4.2 | 6 | script (`verify_restored`, different `SECRET_KEY_BASE`), first CI run |
| AC-4.3 | 0 | `backup_guards_spec` "uses no Active Record encryption…" (no model `encrypts`; no key in `config.active_record.encryption`) |
| AC-4.4 | 7 | reading (README "What to keep outside the backup") |
| AC-5.1 | 7 | reading |
| AC-5.2 | 6 | script, first CI run |
| AC-5.3 | 6 | `image_publishing_spec` "runs bin/backup-smoke after bin/image-smoke…", and the first run |
| AC-5.4 | 0 to 5 | the support layer (Phase 0) and every non-container example; `bin/ci` |
| AC-5.5 | 0 | `backup_guards_spec` "knows every collector-owned attachment…" with a negative control, and "knows exactly the four production databases" (an exact match, no control) |
| AC-5.6 | 8 | the maintainer's NAS restore, recorded in `verification.md` |
| AC-5.7 | 7 | reading (`docs/releasing.md` step 5) |
| AC-6.1 | 7 | reading (both links resolve) |
| AC-6.2 | 5 | `backup_guards_spec` "has no route, controller or view named for a backup…" |
| FR-1 | 3 | `create_spec` (all) |
| FR-2 | 1, 4 | `archive_spec` (including the `on_manifest` callback); `restore_spec` (the order is the order of the examples' refusals: volume, kind, incomplete, version, **room, then checksum** (maintainer's ruling m3: the room is checked as soon as the manifest is parsed, inside `Archive.read`'s first pass), checks, schema; a file damaged after its manifest, on a volume without room, is refused for the room: ruling m3) |
| FR-3 | 4 | `restore_spec` "places the snapshot…" compares every other table; Phase 4 step 4.5 |
| FR-4 | 0, 3, 4 | `refusal_spec`; `run_spec` "prints a system error as two plain lines…"; every refusal example |
| FR-5 | 5 | `backup_guards_spec` "keeps core code free of any collectible…" |
| FR-6 | 3, 4 | `create_spec` "removes a .partial file more than a day old…"; `restore_spec` "…the next restore succeeds and cleans up"; Phase 4 step 4.5 (grep) |
| FR-7 | 1, 7 | `archive_spec` (system `tar` reads it); reading of `docs/backup-restore.md` |
| FR-8 | 4, 5 | `restore_spec` (no primary path after any refusal); Phase 4 step 4.5 (grep); `backup_boot_spec` |
| FR-9 | 6, 7 | `image_publishing_spec`; reading (CLAUDE.md lists the script) |
| FR-10 | 3, 4 | the AC-1.7 and AC-1.8 examples |
| Decision 1 | 3, 8 | `create_spec`; ADR 0024 accepted in Phase 8 |
| Decision 2 | 0, 3, 7 | `backup_guards_spec`; `create_spec` (only the two files); README "What a backup doesn't hold" |
| Decision 3 | 3, 4, 7 | secrets example; sessions examples; README "What to keep outside the backup" |
| Decision 4 | 5, 6, 7 | `backup_boot_spec`; script (both copy-in ways, the Kamal container command); README (ownership, Podman, Kamal sequence) |
| Decision 5 | 1, 3, 7 | `archive_spec`; `create_spec` (file name); `docs/backup-restore.md` |
| Decision 6 | 0, 4 | `databases_spec` "#occupied"; `restore_spec` (fresh volume, temporary file, no sidecar) |
| Decision 7 | 3, 4 | `create_spec` (verification, `.partial`, fsync order by reading), `restore_spec` |
| Decision 8 | 7 | reading (cron line, no scheduler); `config/recurring.yml` is untouched (its existing spec stays green) |
| Decision 9 | 0, 5, 6, 8 | the support layer; the restored-instance specs; the script; the maintainer's restore |
| Decision 10 | 4, 5 | `restore_spec` (newer refused); `backup_upgrade_spec` (older migrates) |
| Decision 11 | 7 | reading (README table, both links) |
| Decision 12 | 5, 7 | `backup_restored_art_spec`; README; `issue-art-index-ready.md` |
| Decision 13 | 3, 8 | `create_spec` (free-space refusal); `script/backup/measure.rb` |
| Decision 14 | 7, 8 | `docs/releasing.md` step 5; the maintainer's NAS restore |
| Decision 15 | all | one spec, one pull request |
---

## Phase 0: The namespace, the volume, the refusal, the suite's support layer and the guards

**Implements:** FR-4 (Refusal), FR-6 (what the code may touch), decision 6 (a fresh volume's definition), decision 2 (guards), decision 9 layer 1 (support) | **Satisfies:** AC-5.5, AC-4.3, AC-5.4 (the support it rests on)

**Goal:** the three pieces everything else stands on exist and are tested, the application knows `lib/collector/backup*` is required by path (never autoloaded), and the two guards that stop a later change from silently making a backup incomplete are in the suite.

**Files:**
- Create: `lib/collector/backup.rb`, `lib/collector/backup/refusal.rb`, `lib/collector/backup/databases.rb`, `lib/collector/backup/free_space.rb`
- Edit: `config/application.rb` (one line: `autoload_lib` ignores the backup library)
- Create: `spec/support/backup_helpers.rb`, `spec/lib/collector/backup/refusal_spec.rb`, `spec/lib/collector/backup/run_spec.rb`, `spec/lib/collector/backup/databases_spec.rb`, `spec/lib/collector/backup/free_space_spec.rb`, `spec/backup_guards_spec.rb`

**Interfaces:**
- `Collector::Backup::Refusal.new(problem, advice)` → `#problem`, `#advice`, `#message` ("problem advice")
- `Collector::Backup::Databases.configured(env: Rails.env)` → `Databases`; `Databases.new({ "primary" => path, … })`; `#primary` → `Pathname`, `#directory` → `Pathname`, `#names` → `Array<String>`, `#occupied` → `Array<Pathname>` (every file of the four databases and their `-wal`, `-shm`, `-journal` that exists)
- `Collector::Backup::FreeSpace.bytes(path)` → `Integer` or `nil`
- `Collector::Backup` module functions (this phase): `.argument(args, name, usage)`, `.run { }` (a `Refusal` prints its two sentences; a `SystemCallError` or `SQLite3::Exception` that nothing named ends in two plain lines too; both exit 1), `.size_phrase(bytes)`, `.counts_phrase(counts)`, `.create_private(path)`, `.remove(path)`, `.fsync_file(path)`, `.fsync_directory(path)`, `.publish(from, to) { on_clash }`, `.release_schema_versions(root = Rails.root)`; constants `FORMAT_VERSIONS`, `FORMAT_VERSION`, `BUSY_TIMEOUT_MS`, `STALE_PARTIAL_SECONDS`
- Spec support: `BackupHelpers` (below)

**Complexity Tracking:** the library lives in `lib/collector/backup/` and is not autoloaded, which departs from "plain Ruby objects under `app/models/`" (`.claude/rules/models.md`). The two tasks must not initialize the application (research.md 1 and 2; ADR 0024 decision 5), and autoloading exists only after initialization. The simplicity gate holds: three components (the file, the database operations, the two commands), each of a few small files, no gem.

- [ ] **Step 0.1: Write the failing specs for `Refusal`, `Databases` and `FreeSpace`.**

`spec/lib/collector/backup/refusal_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::Backup::Refusal, :backup do
  it "keeps what is wrong and what to do as two sentences, and reads as both (FR-4, AC-3.8)", :aggregate_failures do
    refusal = described_class.new("The volume isn't empty.", "Restore onto a new volume.")

    expect(refusal).to have_attributes(problem: "The volume isn't empty.", advice: "Restore onto a new volume.",
      message: "The volume isn't empty. Restore onto a new volume.")
  end
end
```

`spec/lib/collector/backup/run_spec.rb` (plan-review M3: the slips decision 4's ownership rules invite must not end in a backtrace):

```ruby
require "rails_helper"

RSpec.describe Collector::Backup, ".run", :backup do
  it "prints a refusal as its two sentences and exits 1", :aggregate_failures do
    out, err, status = captured_streams { described_class.run { raise Collector::Backup::Refusal.new("It is wrong.", "Do this.") } }

    expect([ out, err, status ]).to eq([ "", "It is wrong.\nDo this.\n", 1 ])
  end

  it "prints a system error nothing else names as two plain lines without its class or its frames, and exits 1", :aggregate_failures do
    out, err, status = captured_streams { described_class.run { raise Errno::EACCES, "/rails/storage/production.sqlite3" } }

    expect([ out, status ]).to eq([ "", 1 ])
    expect(err.lines.size).to eq(2)
    expect(err.lines.first).to eq("The command stopped: Permission denied.\n")
    expect(err.lines.last).to start_with("It left nothing half-made; check that")
    expect(err).not_to match(/Errno|EACCES|Exception|Error|\.rb:\d+/)
  end

  it "does the same for a SQLite error", :aggregate_failures do
    _out, err, status = captured_streams { described_class.run { raise SQLite3::IOException, "disk I/O error" } }

    expect([ status, err.lines.first, err.lines.size ]).to eq([ 1, "The command stopped: Disk I/O error.\n", 2 ])
  end
end
```

`spec/lib/collector/backup/databases_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::Backup::Databases, :backup do
  describe ".configured" do
    it "reads the production databases from config/database.yml without connecting (FR-8)", :aggregate_failures do
      databases = described_class.configured(env: "production")

      expect(databases.names).to contain_exactly("primary", "cache", "queue", "cable")
      expect(databases.primary).to eq(Rails.root.join("storage/production.sqlite3"))
      expect(databases.directory).to eq(Rails.root.join("storage"))
    end

    it "reads a single-database environment as its primary", :aggregate_failures do
      databases = described_class.configured(env: "test")

      expect(databases.names).to eq([ "primary" ])
      expect(databases.primary.basename.to_s).to eq("test.sqlite3")
    end
  end

  describe "#occupied" do
    let(:directory) { scratch("volume") }
    let(:databases) { databases_for(directory) }

    it "is empty for an empty volume" do
      expect(databases.occupied).to be_empty
    end

    it "names each of the four databases and each -wal, -shm and -journal file that is there (decision 6)", :aggregate_failures do
      names = %w[production.sqlite3 production_cache.sqlite3-wal production_queue.sqlite3-shm production_cable.sqlite3-journal]
      names.each { |name| directory.join(name).write("x") }

      expect(databases.occupied.map { it.basename.to_s }).to match_array(names)
    end

    it "ignores the restore's own temporary file and its journal, and other files of the volume", :aggregate_failures do
      %w[collector-restore.partial collector-restore.partial-journal catalog.txt].each { |name| directory.join(name).write("x") }

      expect(databases.occupied).to be_empty
    end
  end
end
```

`spec/lib/collector/backup/free_space_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::Backup::FreeSpace, :backup do
  it "reads the bytes available on the filesystem that holds a path" do
    expect(described_class.bytes(Dir.tmpdir)).to be_a(Integer).and be_positive
  end

  it "answers nil when it can't read the figure, so the check is skipped rather than guessed" do
    expect(described_class.bytes("/no/such/place/for/collector")).to be_nil
  end
end
```

- [ ] **Step 0.2: Write the support module** (it is what makes the specs above runnable; the failing run in step 0.3 is for the missing library). Every later phase uses it.

`spec/support/backup_helpers.rb`:

```ruby
require Rails.root.join("lib/collector/backup").to_s
require "open3"
require "rbconfig"
require "tmpdir"

# Support for spec 030's examples (decision 9 layer 1, AC-5.4). Tag a group :backup for the helpers and a scratch
# directory removed after each example; add :committed when the example commits rows (VACUUM INTO can't run inside a
# transaction and the writers of AC-1.2 and AC-1.3 use their own connections), which empties the test database
# before and after it.
module BackupHelpers
  PRODUCTION_NAMES = { "primary" => "production.sqlite3", "cache" => "production_cache.sqlite3",
    "queue" => "production_queue.sqlite3", "cable" => "production_cable.sqlite3" }.freeze
  SECRETS = { "SECRET_KEY_BASE" => "sk-recognisable-secret-key-base-value-30303",
    "RAILS_MASTER_KEY" => "mk-recognisable-master-key-value-40404",
    "COLLECTOR_TRUSTED_PROXIES" => "198.51.100.77" }.freeze
  Seed = Data.define(:user, :entries, :lots, :values)

  def scratch_root = (@scratch_root ||= Pathname(Dir.mktmpdir("collector-backup-spec")))

  # A directory under the example's scratch root, created. Several names make several directories.
  def scratch(name) = scratch_root.join(name).tap(&:mkpath)

  # A path under the scratch root that isn't created.
  def scratch_path(name) = scratch_root.join(name)

  def remove_scratch!
    return unless @scratch_root

    @scratch_root.glob("**/*").select(&:directory?).each { it.chmod(0o755) }
    FileUtils.remove_entry(@scratch_root, true)
    @scratch_root = nil
  end

  def production_paths(directory) = PRODUCTION_NAMES.transform_values { directory.join(it) }
  def databases_for(directory) = Collector::Backup::Databases.new(production_paths(directory))
  def instance_database = Collector::Backup::Databases.configured.primary
  def release_versions = Collector::Backup.release_schema_versions

  # The examples' clock: the second a backup is taken (decision 5's file name).
  def clock_at(time = Time.utc(2026, 10, 21, 14, 21, 0)) = Struct.new(:now).new(time)

  # Recognisable values, so that AC-1.7 and AC-1.8 can search for them.
  def seed_instance(lots: 3)
    user = create(:user, name: "Zebra Quartz", email_address: "zebra.quartz@example.test")
    entries = Array.new(lots) { |index| create(:mtg_printing, entry: create(:catalog_entry, name: "Zebra Quartz Dragon #{index}")).entry }
    made = entries.map { |entry| create(:lot, account: user.account, entry:, quantity: 2) }
    Seed.new(user:, entries:, lots: made, values: [ "Zebra Quartz", "zebra.quartz@example.test", "Zebra Quartz Dragon" ])
  end

  # A session with a pending bulk selection (a mark) and a bulk removal, the working state a restore clears (decision 3).
  def seed_session(user, lot)
    session = user.sessions.create!(ip_address: "203.0.113.9", user_agent: "RSpec")
    BulkSelection.for(session).marks.create!(account: user.account, lot:)
    BulkRemoval.create!(session:, account: user.account, copies: 1)
    session
  end

  def create_backup(into: scratch("backups"), source: instance_database, clock: clock_at, **options)
    Collector::Backup::Create.new(directory: into, source:, clock:, **options).call.path
  end

  def restore_backup(file, volume: scratch("volume"), **options)
    Collector::Backup::Restore.new(file:, databases: databases_for(volume), release_versions:, **options).call
  end

  # The manifest of a snapshot file built by hand (a damaged or altered one), not made by backup:create.
  def manifest_for(snapshot_path, **changes)
    snapshot = Collector::Backup::Snapshot.new(snapshot_path)
    fields = { backup_format_version: 1, taken_at: "2026-10-21T14:21:00Z", schema_version: release_versions.max_by(&:to_i),
      snapshot_bytes: snapshot_path.size, snapshot_sha256: Digest::SHA256.file(snapshot_path).hexdigest,
      counts: { "accounts" => 0, "users" => 0, "lots" => 0 } }
    fields[:counts] = snapshot.counts unless changes.key?(:counts)
    Collector::Backup::Manifest.new(**fields.merge(changes))
  end

  # An archive built by hand around a snapshot file, with a correct manifest unless changes say otherwise.
  def archive_of(snapshot_path, into: scratch("archives"), name: "collector-backup-20261021T142100Z.tar.gz", **changes)
    into.join(name).tap { Collector::Backup::Archive.write(it, manifest: manifest_for(snapshot_path, **changes), snapshot: snapshot_path) }
  end

  # A copy of the test database (schema, and the rows committed so far), made with VACUUM INTO as a backup does.
  def copy_of_instance(name = "copy.sqlite3")
    scratch_path(name).tap { |path| Collector::Backup::Snapshot.take(source: instance_database, into: path) }
  end

  def sqlite(path, readonly: false)
    SQLite3::Database.new(path.to_s, readonly:).tap { it.busy_timeout = 5_000 }.then do |db|
      yield db
    ensure
      db.close
    end
  end

  # Overwrites the root page of a table, so that the b-tree can't be read (AC-1.5, AC-3.7).
  def damage_table!(path, table)
    root, size = sqlite(path) { |db| [ db.get_first_value("SELECT rootpage FROM sqlite_master WHERE name = ?", [ table ]), db.get_first_value("PRAGMA page_size") ] }
    File.open(path, "r+b") { |file| file.seek((root - 1) * size) && file.write("\xFF".b * size) }
  end

  # Runs +code+ in a plain Ruby child that has loaded the backup library and is stopped (SIGKILL) when the command
  # reaches +step+ (its checkpoint). A real kill, not a rescued exception: no ensure block runs (AC-1.6, AC-2.6).
  def run_killed_at(step, code, *arguments)
    prelude = <<~RUBY
      require "bundler/setup"
      require "json"
      require "collector/backup"
      STEP = ARGV.shift.to_sym
      STOP_HERE = ->(reached) { Process.kill("KILL", Process.pid) if reached == STEP }
    RUBY
    pid = Process.spawn(RbConfig.ruby, "-I", Rails.root.join("lib").to_s, "-e", prelude + code, step.to_s, *arguments.map(&:to_s),
      chdir: Rails.root.to_s, out: File::NULL, err: File::NULL)
    status = Process.wait2(pid).last
    expect(status.signaled? && status.termsig == 9).to be(true), "the run wasn't stopped at #{step}: #{status.inspect}"
  end

  # A child Rails process on a database file: the application as a booted instance would be (AC-2.2, AC-3.6). DATABASE_URL
  # is Rails' own setting, so the application gets no setting of its own. SCHEMA keeps a migration from rewriting db/schema.rb.
  def app_command(database, *command, environment: {})
    env = { "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{database}", "SCHEMA" => scratch_path("schema-dump.rb").to_s }.merge(environment)
    Open3.capture3(env, Rails.root.join("bin/rails").to_s, *command, chdir: Rails.root.to_s)
  end

  # Empties every table the application knows (not the FTS5 index's shadow tables, which a DELETE would corrupt; no spec
  # of this feature creates catalog names), leaving the schema and its versions.
  def clear_instance!
    connection = ActiveRecord::Base.connection
    keep = %w[schema_migrations ar_internal_metadata]
    connection.disable_referential_integrity do
      (connection.tables - keep).grep_v(/\Acatalog_names_fts/).each { |table| connection.execute("DELETE FROM #{connection.quote_table_name(table)}") }
    end
  end

  # The Refusal a block raises, or nil when it doesn't raise one.
  def refusal_of
    yield
    nil
  rescue Collector::Backup::Refusal => refusal
    refusal
  end

  def with_env(values)
    saved = values.keys.to_h { [ it, ENV[it] ] }
    values.each { |name, value| ENV[name] = value }
    yield
  ensure
    saved.each { |name, value| ENV[name] = value }
  end

  # Every file of a directory by name and SHA-256: "every file is as it was" (AC-2.5, AC-3.x).
  def checksums(directory)
    directory.children.select(&:file?).to_h { [ it.basename.to_s, Digest::SHA256.file(it).hexdigest ] }
  end

  # Every table's rows as sorted strings, for comparing two databases table by table (AC-2.1, AC-2.7).
  def table_rows(path)
    sqlite(path, readonly: true) do |database|
      database.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name").flatten
        .to_h { |table| [ table, database.execute("SELECT * FROM #{table}").map(&:inspect).sort ] }
    end
  end

  # The snapshot inside an archive, written out to a scratch file.
  def unpack_snapshot(archive, name = "unpacked.sqlite3")
    scratch_path(name).tap { |path| File.open(path, "wb") { |file| Collector::Backup::Archive.read(archive) { file.write(it) } } }
  end

  def captured_streams
    out, err = StringIO.new, StringIO.new
    original = [ $stdout, $stderr ]
    $stdout, $stderr = out, err
    status = 0
    begin
      yield
    rescue SystemExit => stopped
      status = stopped.status
    end
    [ out.string, err.string, status ]
  ensure
    $stdout, $stderr = original
  end

  # What Rails logged while the block ran (the commands log nothing, AC-1.7).
  def captured_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    Rails.logger.broadcast_to(logger)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end
end

RSpec.shared_context "committed instance" do
  self.use_transactional_tests = false

  before { clear_instance! }
  after { clear_instance! }
end

RSpec.configure do |config|
  config.include BackupHelpers, :backup
  config.include_context "committed instance", :committed
  config.after(:each, :backup) { remove_scratch! }
end
```

- [ ] **Step 0.3: Run the specs and see them fail.** Run `bin/rspec spec/lib/collector/backup` — expect: it fails to load with `cannot load such file -- …/lib/collector/backup`, because the support file requires the library, which doesn't exist yet. (The support file is loaded by every spec, so the whole suite is red from step 0.2 until step 0.4; do the two steps in one sitting.)

- [ ] **Step 0.4: Write the library's first four files.**

`lib/collector/backup.rb`:

```ruby
require "digest"
require "fileutils"
require "json"
require "pathname"
require "securerandom"
require "sqlite3"
require "zlib"
require "rubygems/package"

require_relative "backup/refusal"
require_relative "backup/databases"
require_relative "backup/free_space"

module Collector
  # Back up and restore an instance (spec 030, ADR 0024, docs/backup-restore.md). The operator's two commands,
  # lib/tasks/backup.rake, run before the application is initialized and don't depend on Rake's :environment: no
  # initializers, no Solid* connection, no secret_key_base (research.md 1 and 2), and no Active Record connection that
  # could create the primary's file (FR-8). So this library needs only the standard library, the sqlite3 gem and, for the
  # database paths, Rails.root and config/database.yml; it is required by path and isn't autoloaded (config/application.rb).
  module Backup
    FORMAT_VERSIONS = [ 1 ].freeze # the backup format versions this release restores (decision 5, AC-3.4)
    FORMAT_VERSION = FORMAT_VERSIONS.last # the one backup:create writes
    BUSY_TIMEOUT_MS = 5_000 # the database's own busy timeout (config/database.yml), for the commands' direct connections
    STALE_PARTIAL_SECONDS = 24 * 60 * 60 # a .partial file older than this is a dead run's (decision 7, AC-1.6)
    TEMPORARY_MODE = 0o600

    # The one argument of a task, or the refusal that says how to give it (a comma makes Rake read a second argument).
    def self.argument(args, name, usage)
      value = args[name].to_s
      raise Refusal.new("No #{name} was given.", "Run: #{usage}.") if value.empty?
      raise Refusal.new("The #{name} argument contains a comma, which Rake reads as a second argument.", "Use a path without a comma.") if args.extras.any?

      value
    end

    # A task's body: a refusal prints its two sentences on stderr and exits 1, the only failure status (AC-3.8, FR-4). A
    # system or SQLite error that no command named (an unreadable file or an unwritable volume the commands didn't check,
    # a failing disk) ends the same way: what stopped it, and that it left nothing half-made (each command removes its own
    # temporary files and places nothing until every check has passed; an error after the database was placed, such as
    # the directory fsync, must not claim "nothing was changed"), never the exception class or its frames.
    def self.run
      yield
    rescue Refusal => refusal
      warn refusal.problem, refusal.advice
      exit 1
    rescue SystemCallError, SQLite3::Exception => error
      warn "The command stopped: #{stopped_text(error)}.",
        "It left nothing half-made; check that the directories and files involved are readable and writable by the user Collector runs as (uid #{Process.uid}) and have room, then run it again."
      exit 1
    end

    # An error's own words without Ruby's "@ rb_sysopen - /path" tail, capitalised: "Permission denied".
    def self.stopped_text(error)
      error.message.split(/ [@-] /).first.to_s.strip.sub(/\A./, &:upcase)
    end

    def self.size_phrase(bytes)
      units = %w[bytes KB MB GB TB]
      value = bytes.to_f
      index = 0
      while value >= 1024 && index < units.size - 1
        value /= 1024
        index += 1
      end
      index.zero? ? "#{bytes} #{bytes == 1 ? "byte" : "bytes"}" : format("%.1f %s", value, units[index])
    end

    def self.counts_phrase(counts)
      parts = %w[accounts users lots].map { |name| "#{counts.fetch(name)} #{counts.fetch(name) == 1 ? name.chomp("s") : name}" }
      "#{parts[0..-2].join(", ")} and #{parts.last}"
    end

    # The release's migrations as the framework finds them: the digits that start each file's name. Read from the files,
    # never through a connection (FR-8); primary's migrations_paths is the default, db/migrate.
    def self.release_schema_versions(root = Rails.root)
      Dir[root.join("db/migrate/**/[0-9]*_*.rb").to_s].filter_map { File.basename(it)[/\A(\d+)_/, 1] }.sort_by(&:to_i)
    end

    # A new, empty file readable by its owner only from the moment it exists (decision 7). Returns it open for writing.
    def self.create_private(path)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL | File::BINARY, TEMPORARY_MODE)
    end

    # Removes one of the commands' own temporary files and the sidecars SQLite may have made beside it (FR-6).
    def self.remove(path)
      [ "", "-journal", "-wal", "-shm" ].each { |suffix| FileUtils.rm_f("#{path}#{suffix}") }
    end

    def self.fsync_file(path)
      File.open(path, "r") { it.fsync }
    end

    # Where the platform or the share allows it (decision 7); a failure here never fails the run.
    def self.fsync_directory(path)
      File.open(path, "r") { it.fsync }
    rescue Errno::EINVAL, Errno::ENOTSUP, Errno::EISDIR, Errno::EACCES, Errno::EPERM
      nil
    end

    # Puts +from+ at +to+ and never replaces a file that is already there: a hard link fails on a clash where a rename
    # would overwrite. Some shares can't link; there the existence check and the rename are all there is. The block runs
    # when +to+ is taken.
    def self.publish(from, to, &on_clash)
      File.link(from, to)
      File.unlink(from)
    rescue Errno::EEXIST
      on_clash.call
    rescue Errno::EPERM, Errno::ENOTSUP, Errno::EOPNOTSUPP, Errno::EMLINK, Errno::EXDEV
      return on_clash.call if File.exist?(to)

      File.rename(from, to)
    end
  end
end
```

`lib/collector/backup/refusal.rb`:

```ruby
module Collector
  module Backup
    # A command that stops before it changes anything, with what is wrong and what to do about it: two plain sentences
    # an operator can act on, never an exception class or a backtrace (FR-4, AC-3.8).
    class Refusal < StandardError
      attr_reader :problem, :advice

      def initialize(problem, advice)
        @problem = problem
        @advice = advice
        super("#{problem} #{advice}")
      end
    end
  end
end
```

`lib/collector/backup/databases.rb`:

```ruby
module Collector
  module Backup
    # Where this environment's databases live: the files that make a volume "not fresh" (decision 6) and the path of the
    # primary. Read from config/database.yml without a connection pool, so it works before the application is initialized.
    class Databases
      SIDECARS = [ "", "-wal", "-shm", "-journal" ].freeze

      def self.configured(env: Rails.env)
        configs = ActiveRecord::DatabaseConfigurations.new(Rails.application.config.database_configuration).configs_for(env_name: env.to_s)
        new(configs.to_h { |config| [ config.name, Rails.root.join(config.database) ] })
      end

      def initialize(paths)
        @paths = paths.transform_values { Pathname(it) }
      end

      def names = @paths.keys
      def primary = @paths.fetch("primary")
      def directory = primary.dirname

      # Every file of the four databases that exists, a stale -wal or -journal included: a -wal beside a restored
      # database would be replayed into it, and an old queue database would run old jobs against it (decision 6).
      def occupied
        @paths.values.flat_map { |path| SIDECARS.map { Pathname("#{path}#{it}") } }.select { it.exist? || it.symlink? }
      end
    end
  end
end
```

`lib/collector/backup/free_space.rb`:

```ruby
require "open3"

module Collector
  module Backup
    # The bytes available to the user on the filesystem that holds a path, from `df` (POSIX output, 1024-byte blocks).
    # nil when it can't be read: the free-space checks (AC-1.11, decision 13) are then skipped rather than guessed.
    module FreeSpace
      def self.bytes(path)
        output, status = Open3.capture2e("df", "-Pk", path.to_s)
        return unless status.success?

        available = output.lines.last.to_s.split[3]
        available && Integer(available, 10) * 1024
      rescue Errno::ENOENT, ArgumentError
        nil
      end
    end
  end
end
```

`backup.rb` requires only the files that exist. Each later phase adds its own `require_relative` line (`manifest` and `archive` in Phase 1, `snapshot` in Phase 2, `create` in Phase 3, `restore` in Phase 4) in the same commit as the file.

- [ ] **Step 0.5: Tell the application not to autoload the library.** In `config/application.rb`, replace

```ruby
    config.autoload_lib(ignore: %w[assets tasks])
```

with

```ruby
    config.autoload_lib(ignore: %w[assets tasks collector/backup.rb collector/backup])
```

and add above it the comment line `# collector/backup is the operator's backup and restore (spec 030): required by path before the app boots, never autoloaded.` (the existing comment above the call stays).

- [ ] **Step 0.6: Write the guards.** `spec/backup_guards_spec.rb` (the two checks of decision 2 and the encryption check of decision 3; the file grows in Phase 5 with FR-5 and AC-6.2):

```ruby
require "rails_helper"

RSpec.describe "what a backup holds (spec 030 decisions 2 and 3)", :backup, type: :model do
  let(:transient) { { "ImportUpload" => %i[file] } } # spec 028's stored import file: one hour, restored without its file (ADR 0022)
  let(:advice) do
    "Spec 030 decision 2: decide what a backup does with it, then update that decision's table, docs/backup-restore.md " \
      "and the README's Backup and restore section, and list it here"
  end

  def attachments_of(models)
    models.to_h { [ it.name, it.reflect_on_all_attachments.map(&:name) ] }.reject { |_name, names| names.empty? }
  end

  def unlisted(models)
    attachments_of(models).filter_map { |name, names| [ name, names - transient.fetch(name, []) ] if (names - transient.fetch(name, [])).any? }.to_h
  end

  def application_models
    Rails.application.eager_load!
    ApplicationRecord.descendants.select { it.name && !it.abstract_class? && Object.const_defined?(it.name) }
  end

  it "knows every collector-owned attachment: only ImportUpload's, listed as transient (AC-5.5)" do
    expect(unlisted(application_models)).to be_empty, advice
  end

  it "would notice a new attachment (a negative control for the guard above)" do
    cover = Class.new(ApplicationRecord) do
      self.table_name = "accounts"
      def self.name = "CoverPhotoOwner"
      has_one_attached :photo
    end

    expect(unlisted([ cover ])).to eq("CoverPhotoOwner" => [ :photo ])
  end

  it "knows exactly the four production databases (AC-5.5)" do
    names = ActiveRecord::DatabaseConfigurations.new(Rails.application.config.database_configuration)
      .configs_for(env_name: "production").map(&:name)

    expect(names).to match_array(%w[primary queue cache cable]), advice
  end

  it "uses no Active Record encryption, so no secret protects any data in the database (AC-4.3)", :aggregate_failures do
    encrypting = application_models.select { it.respond_to?(:encrypted_attributes) && it.encrypted_attributes.present? }
    # config.active_record.encryption is not blank under load_defaults 8.1 (the 7.1 defaults set hash_digest_class and
    # support_sha1_for_non_deterministic_encryption), so check what AC-4.3 names: the keys. Credentials are never read here.
    keys = Rails.application.config.active_record.encryption.to_h.slice(:primary_key, :deterministic_key, :key_derivation_salt)
    declaring = Dir[Rails.root.join("app/**/*.rb").to_s].select { File.read(it).match?(/^\s*encrypts\s/) }

    expect(encrypting.map(&:name)).to be_empty,
      "Spec 030 decision 3: a model that encrypts needs the procedure's secrets section and decision 3 to say what the secret then protects"
    expect(declaring).to be_empty
    expect(keys).to be_empty
  end
end
```

- [ ] **Step 0.7: Run, then the whole suite and the linters.** Run `bin/rails zeitwerk:check` — expect `All is good!` (the library is in `autoload_lib`'s ignore list, so Zeitwerk doesn't manage it; the check passes because of the ignore, and the files are loaded by path everywhere). Run `bin/rspec spec/lib/collector/backup spec/backup_guards_spec.rb` — expect all examples pass (the guards are meant to pass today; the negative control proves the attachment guard would fail). Run `bin/rspec` — expect 0 failures. Run `bin/rubocop` — expect no offenses. Run `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` — expect no warnings.

- [ ] **Step 0.8: Commit** `feat(backup): add the backup namespace, the volume's definition and the suite's guards` (stage `lib/collector/backup.rb`, `lib/collector/backup/`, `config/application.rb`, `spec/support/backup_helpers.rb`, `spec/lib/collector/backup/`, `spec/backup_guards_spec.rb`; one `git add` call, then the commit, as the pre-commit hook reads the command text).

**Phase 0 verification:** `bin/rspec` green; `bin/rails zeitwerk:check` green; AC-5.5 and AC-4.3 pass with a negative control.

---

## Phase 1: The file (`Manifest` and `Archive`)

**Implements:** decision 5, FR-7 (the layout the document will state), part of FR-1 and FR-2 | **Satisfies:** AC-1.4 (the archive holds exactly `manifest.json` then `primary.sqlite3`, 0600), AC-3.1, AC-3.2, AC-3.3, AC-3.4 (at the file level; Phase 4 repeats them through the task)

**Goal:** a backup file can be written and read by `Collector::Backup::Archive` alone, around any bytes, with the classification of [contracts/archive.md](contracts/archive.md): not a backup, incomplete, unknown version, changed. Nothing here knows SQLite.

**Files:**
- Create: `lib/collector/backup/manifest.rb`, `lib/collector/backup/archive.rb`
- Edit: `lib/collector/backup.rb` (two `require_relative` lines), `spec/support/backup_helpers.rb` (`raw_archive`)
- Create: `spec/lib/collector/backup/manifest_spec.rb`, `spec/lib/collector/backup/archive_spec.rb`

**Interfaces:**
- `Manifest = Data.define(:backup_format_version, :taken_at, :schema_version, :snapshot_bytes, :snapshot_sha256, :counts)`; `Manifest.for(snapshot, taken_at:)` (Phase 2 supplies `Snapshot`); `Manifest.parse(text)` → `Manifest`, raising `Manifest::UnknownVersion` (`#version`) or `Manifest::Invalid`; `#to_json` → pretty JSON
- `Archive.write(path, manifest:, snapshot:)` → creates `path` (0600, `EXCL`), writes, fsyncs, closes
- `Archive.read(path, allow_partial: false, on_manifest: nil) { |chunk| }` → `Archive::Result(manifest, sha256, bytes)`; reads the whole file once, yields each chunk of the snapshot, writes nothing; raises `Refusal` for each case of the classification. A name ending in `.partial` is refused as incomplete unless `allow_partial: true` (only `Create`'s own read-back of the archive it just wrote, under its `.partial` name, passes it: plan-review C1). `on_manifest` is called with the parsed `Manifest` of a version this release restores, as soon as it is parsed and before the snapshot is read or its checksum computed (FR-2 lists the room before the checksum: `Restore` checks the room there, maintainer's ruling m3); anything it raises (a `Refusal`) propagates

- [ ] **Step 1.1: Write the failing specs.**

Add to `BackupHelpers` in `spec/support/backup_helpers.rb`:

```ruby
  # A .tar.gz built by hand from [name, bytes] pairs, for the files AC-3.3 and AC-3.4 refuse.
  def raw_archive(*entries, into: scratch("archives"), name: "collector-backup-20261021T142100Z.tar.gz")
    into.join(name).tap do |path|
      File.open(path, "wb") do |file|
        gzip = Zlib::GzipWriter.new(file)
        tar = Gem::Package::TarWriter.new(gzip)
        entries.each { |entry_name, bytes| tar.add_file_simple(entry_name, 0o600, bytes.bytesize) { it.write(bytes) } }
        tar.close
        gzip.finish
      end
    end
  end
```

`spec/lib/collector/backup/manifest_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::Backup::Manifest, :backup do
  let(:fields) do
    { backup_format_version: 1, taken_at: "2026-10-21T14:21:00Z", schema_version: "20261020100002", snapshot_bytes: 4096,
      snapshot_sha256: "a" * 64, counts: { "accounts" => 1, "users" => 1, "lots" => 7 } }
  end

  it "writes exactly the six members of AC-1.4 and reads them back", :aggregate_failures do
    manifest = described_class.new(**fields)

    expect(JSON.parse(manifest.to_json).keys).to match_array(%w[backup_format_version taken_at schema_version snapshot_bytes snapshot_sha256 counts])
    expect(described_class.parse(manifest.to_json)).to eq(manifest)
  end

  it "refuses a version this release doesn't restore, before it looks at any other member (AC-3.4)" do
    text = JSON.generate("backup_format_version" => 99, "future" => "members")

    expect { described_class.parse(text) }.to raise_error(described_class::UnknownVersion) { |error| expect(error.version).to eq(99) }
  end

  it "refuses what isn't a manifest of a known version", :aggregate_failures do
    [ "not json", "[]", JSON.generate(fields.merge(extra: 1)), JSON.generate(fields.except(:counts)),
      JSON.generate(fields.merge(snapshot_sha256: "xyz")), JSON.generate(fields.merge(snapshot_bytes: "4096")),
      JSON.generate(fields.merge(counts: { "accounts" => 1 })) ].each do |text|
      expect { described_class.parse(text) }.to raise_error(described_class::Invalid)
    end
  end
end
```

`spec/lib/collector/backup/archive_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::Backup::Archive, :backup do
  let(:payload) { Random.bytes(3 * 1024 * 1024 + 17) } # not a multiple of 512, several chunks, and nothing SQLite
  let(:snapshot) { scratch_path("primary.sqlite3").tap { it.binwrite(payload) } }
  let(:fields) do
    { backup_format_version: 1, taken_at: "2026-10-21T14:21:00Z", schema_version: "20261020100002", snapshot_bytes: payload.bytesize,
      snapshot_sha256: Digest::SHA256.hexdigest(payload), counts: { "accounts" => 1, "users" => 1, "lots" => 2 } }
  end
  let(:manifest) { Collector::Backup::Manifest.new(**fields) }
  let(:archive) { scratch("archives").join("collector-backup-20261021T142100Z.tar.gz").tap { described_class.write(it, manifest:, snapshot:) } }

  describe ".write" do
    it "makes a private gzip'd tar of manifest.json then primary.sqlite3 and nothing else that the system tar reads (AC-1.4)", :aggregate_failures do
      listing, status = Open3.capture2("tar", "-tzf", archive.to_s)
      expect(status).to be_success
      expect(listing.lines(chomp: true)).to eq(%w[manifest.json primary.sqlite3])
      expect(archive.stat.mode & 0o777).to eq(0o600)

      Open3.capture2("tar", "-xzf", archive.to_s, "-C", scratch("unpacked").to_s)
      expect(scratch("unpacked").join("primary.sqlite3").binread).to eq(payload)
      expect(Collector::Backup::Manifest.parse(scratch("unpacked").join("manifest.json").read)).to eq(manifest)
    end

    it "never replaces a file that is there" do
      archive
      expect { described_class.write(archive, manifest:, snapshot:) }.to raise_error(Errno::EEXIST)
    end
  end

  describe ".read" do
    it "reads the whole archive once, yielding the snapshot's bytes, and reports what it saw", :aggregate_failures do
      chunks = []
      result = described_class.read(archive) { chunks << it }

      expect(chunks.join.b).to eq(payload.b)
      expect(result).to have_attributes(manifest:, sha256: fields[:snapshot_sha256], bytes: payload.bytesize)
    end

    it "writes nothing", :aggregate_failures do
      before = archive.dirname.children.map { [ it.basename.to_s, it.size ] }
      described_class.read(archive)
      expect(archive.dirname.children.map { [ it.basename.to_s, it.size ] }).to eq(before)
    end

    it "calls a file cut short incomplete (AC-3.1)", :aggregate_failures do
      cut = scratch("cut").join(archive.basename).tap { it.binwrite(archive.binread[0...-100]) }
      refusal = refusal_of { described_class.read(cut) }

      expect(refusal.problem).to eq("#{cut.basename} is incomplete; it was cut short or is still being written.")
      expect(refusal.advice).to eq("Take the backup again, or copy it again.")
    end

    it "calls a file whose gzip checksum fails incomplete (AC-3.1)" do
      damaged = archive.binread
      damaged.setbyte(-8, damaged.getbyte(-8) ^ 0xFF) # the gzip footer's CRC
      broken = scratch("crc").join(archive.basename).tap { it.binwrite(damaged) }

      expect(refusal_of { described_class.read(broken) }.problem).to include("is incomplete")
    end

    it "calls an intact file named *.partial incomplete, because the run that made it didn't finish (AC-3.1)" do
      partial = scratch("partial").join("#{archive.basename}.0123456789abcdef.partial").tap { it.binwrite(archive.binread) }

      expect(refusal_of { described_class.read(partial) }.problem).to include("is incomplete")
    end

    it "reads an intact *.partial file when it is told the file is its own (Create's read-back, plan-review C1)", :aggregate_failures do
      partial = scratch("partial").join("#{archive.basename}.0123456789abcdef.partial").tap { it.binwrite(archive.binread) }
      chunks = []
      result = described_class.read(partial, allow_partial: true) { chunks << it }

      expect(chunks.join.b).to eq(payload.b)
      expect(result.sha256).to eq(fields[:snapshot_sha256])
    end

    it "still calls a cut-short *.partial file incomplete when it is told the file is its own" do
      partial = scratch("partial").join("#{archive.basename}.0123456789abcdef.partial").tap { it.binwrite(archive.binread[0...-100]) }

      expect(refusal_of { described_class.read(partial, allow_partial: true) }.problem).to include("is incomplete")
    end

    it "hands the manifest to on_manifest before it reads the snapshot or checks the checksum (FR-2: the room before the checksum)", :aggregate_failures do
      altered = scratch("altered").join("collector-backup-20261021T142100Z.tar.gz").tap do
        described_class.write(it, manifest:, snapshot: scratch_path("changed.sqlite3").tap { |file| file.binwrite(payload.dup.tap { |bytes| bytes.setbyte(1000, bytes.getbyte(1000) ^ 1) }) })
      end
      seen = nil
      chunks = []
      no_room = lambda do |read|
        seen = read
        raise Collector::Backup::Refusal.new("No room.", "Make some.")
      end
      refusal = refusal_of { described_class.read(altered, on_manifest: no_room) { chunks << it } }

      expect(refusal.problem).to eq("No room.") # not the checksum refusal the same file gets without the callback
      expect(seen).to eq(manifest)
      expect(chunks).to be_empty
    end

    it "does not call on_manifest for a file that isn't a backup or names an unknown version", :aggregate_failures do
      future = raw_archive([ "manifest.json", JSON.generate("backup_format_version" => 2) ], [ "primary.sqlite3", "x" ], name: "v2.tar.gz")
      text = scratch_path("note.txt").tap { it.write("hello") }
      calls = []
      [ future, text ].each { |file| refusal_of { described_class.read(file, on_manifest: ->(read) { calls << read }) } }

      expect(calls).to be_empty
    end

    it "calls a changed snapshot a checksum failure, not an incomplete file (AC-3.2)", :aggregate_failures do
      changed = scratch_path("changed.sqlite3").tap { it.binwrite(payload.dup.tap { |bytes| bytes.setbyte(1000, bytes.getbyte(1000) ^ 1) }) }
      altered = scratch("altered").join("collector-backup-20261021T142100Z.tar.gz").tap { described_class.write(it, manifest:, snapshot: changed) }
      refusal = refusal_of { described_class.read(altered) }

      expect(refusal.problem).to eq("#{altered.basename} doesn't match its checksum; it was changed or damaged after it was made.")
      expect(refusal.advice).to eq("Use another copy of the backup.")
    end

    it "refuses what isn't a backup, saying so and never 'incomplete' (AC-3.3)", :aggregate_failures do
      other = Collector::Backup::Manifest.new(**fields).to_json
      files = {
        "a text file" => scratch_path("note.txt").tap { it.write("hello") },
        "an empty file" => scratch_path("empty").tap { it.write("") },
        "a gzip file of something else" => scratch_path("other.gz").tap { it.binwrite(Zlib.gzip("hello, this is not a tar")) },
        "a tar.gz whose first entry isn't manifest.json" => raw_archive([ "other.txt", "x" ], [ "manifest.json", other ], name: "first.tar.gz"),
        "a tar.gz with a manifest that doesn't parse" => raw_archive([ "manifest.json", "not json" ], [ "primary.sqlite3", "x" ], name: "garbled.tar.gz"),
        "a tar.gz whose second entry isn't primary.sqlite3" => raw_archive([ "manifest.json", other ], [ "other.bin", "x" ], name: "second.tar.gz")
      }

      files.each do |label, path|
        refusal = refusal_of { described_class.read(path) }
        expect(refusal&.problem).to eq("#{path.basename} isn't a Collector backup."), label
        expect(refusal.advice).to eq("Give a collector-backup-….tar.gz file made by backup:create."), label
      end
    end

    it "tells a Collector export file where it belongs (AC-3.3)", :aggregate_failures do
      export = scratch_path("collector-export-2026-10-21.json").tap { it.write(JSON.generate("format" => "collector-export", "format_version" => 1, "lots" => [])) }
      refusal = refusal_of { described_class.read(export) }

      expect(refusal.problem).to eq("#{export.basename} is a Collector export file, not a backup.")
      expect(refusal.advice).to include("Import collection")
    end

    it "refuses a backup format version this release doesn't restore, naming the ones it does (AC-3.4)", :aggregate_failures do
      future = raw_archive([ "manifest.json", JSON.generate("backup_format_version" => 2, "newer" => true) ], [ "primary.sqlite3", "x" ], name: "v2.tar.gz")
      refusal = refusal_of { described_class.read(future) }

      expect(refusal.problem).to eq("#{future.basename} uses backup format version 2; this release restores version 1.")
      expect(refusal.advice).to eq("Restore it with a release that knows that version.")
    end

    it "calls a cut-short file of an unknown version incomplete first (FR-2's order)" do
      future = raw_archive([ "manifest.json", JSON.generate("backup_format_version" => 2) ], [ "primary.sqlite3", Random.bytes(100_000) ], name: "v2.tar.gz")
      cut = scratch("cut").join("v2.tar.gz").tap { it.binwrite(future.binread[0...-200]) }

      expect(refusal_of { described_class.read(cut) }.problem).to include("is incomplete")
    end
  end
end
```

- [ ] **Step 1.2: Run and see them fail.** Run `bin/rspec spec/lib/collector/backup/manifest_spec.rb spec/lib/collector/backup/archive_spec.rb` — expect: failures `uninitialized constant Collector::Backup::Manifest` / `Archive`.

- [ ] **Step 1.3: Write `Manifest`.** `lib/collector/backup/manifest.rb`:

```ruby
module Collector
  module Backup
    # manifest.json: what the backup holds and how to check it (decision 5, contracts/archive.md). Counts only, never a
    # name or an email address (hosted-door rule 2, AC-1.7).
    Manifest = Data.define(:backup_format_version, :taken_at, :schema_version, :snapshot_bytes, :snapshot_sha256, :counts)

    class Manifest
      Invalid = Class.new(StandardError)

      class UnknownVersion < StandardError
        attr_reader :version

        def initialize(version)
          @version = version
          super("backup format version #{version}")
        end
      end

      COUNT_NAMES = %w[accounts users lots].freeze

      def self.for(snapshot, taken_at:)
        new(backup_format_version: FORMAT_VERSION, taken_at: taken_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          schema_version: snapshot.schema_versions.max_by(&:to_i), snapshot_bytes: snapshot.path.size,
          snapshot_sha256: Digest::SHA256.file(snapshot.path).hexdigest, counts: snapshot.counts)
      end

      # The version is read first: a manifest of a version this release doesn't know may have other members (AC-3.4).
      def self.parse(text)
        data = JSON.parse(text)
        raise Invalid, "not an object" unless data.is_a?(Hash) && data["backup_format_version"].is_a?(Integer)
        raise UnknownVersion.new(data["backup_format_version"]) unless FORMAT_VERSIONS.include?(data["backup_format_version"])
        raise Invalid, "the members differ from the format's" unless data.keys.sort == members.map(&:to_s).sort

        new(**data.transform_keys(&:to_sym)).tap { raise Invalid, "a member has the wrong type" unless it.valid? }
      rescue JSON::ParserError => error
        raise Invalid, error.message
      end

      def valid?
        taken_at.is_a?(String) && schema_version.is_a?(String) && snapshot_bytes.is_a?(Integer) && snapshot_bytes >= 0 &&
          /\A\h{64}\z/.match?(snapshot_sha256.to_s) && counts.is_a?(Hash) && counts.keys.sort == COUNT_NAMES.sort &&
          counts.values.all?(Integer)
      end

      def to_json(*) = JSON.pretty_generate(to_h)
    end
  end
end
```

- [ ] **Step 1.4: Write `Archive`.** `lib/collector/backup/archive.rb`:

```ruby
module Collector
  module Backup
    # The backup file: a gzip'd ustar tar of manifest.json then primary.sqlite3 (decision 5, contracts/archive.md).
    # Written with Gem::Package::TarWriter, as bin/fetch-ocr-engine's library reads a tarball with TarReader. The reader is
    # this module's own, because what counts as "not a backup" and what as "incomplete" (FR-2, AC-3.1, AC-3.3) must be
    # exact, and is tested (research.md 6). Compression is the fastest level: the bar of decision 13 is for a NAS's CPU.
    module Archive
      MANIFEST = "manifest.json".freeze
      SNAPSHOT = "primary.sqlite3".freeze
      GZIP_MAGIC = "\x1F\x8B".b.freeze
      BLOCK = 512
      CHUNK = 1024 * 1024
      MANIFEST_LIMIT = 64 * 1024

      Result = Data.define(:manifest, :sha256, :bytes)

      def self.write(path, manifest:, snapshot:)
        snapshot = Pathname(snapshot)
        file = Backup.create_private(path)
        gzip = Zlib::GzipWriter.new(file, Zlib::BEST_SPEED)
        tar = Gem::Package::TarWriter.new(gzip)
        text = manifest.to_json
        tar.add_file_simple(MANIFEST, 0o600, text.bytesize) { it.write(text) }
        tar.add_file_simple(SNAPSHOT, 0o600, snapshot.size) { |entry| File.open(snapshot, "rb") { |source| IO.copy_stream(source, entry) } }
        tar.close
        gzip.finish
        file.flush
        file.fsync
      ensure
        file&.close
      end

      # Reads the whole archive once and writes nothing, so a refusal is decided before the volume is touched (FR-2). The
      # block, when given, gets each chunk of the snapshot (Restore's second pass writes them to its temporary file).
      # +allow_partial+ lets Create read back the archive it wrote under its own .partial name; for anyone else a .partial
      # name means the run that made the file didn't finish. +on_manifest+ is called with the manifest of a known version
      # as soon as it is parsed, before the snapshot is read (Restore checks the room there, as FR-2 orders).
      def self.read(path, allow_partial: false, on_manifest: nil, &sink)
        name = File.basename(path.to_s)
        File.open(path, "rb") do |file|
          raise not_a_backup(file, name) unless file.read(2) == GZIP_MAGIC

          file.rewind
          gzip = begin
            Zlib::GzipReader.new(file)
          rescue Zlib::Error
            raise not_a_backup(file, name)
          end
          read_entries(gzip, name, allow_partial:, on_manifest:, &sink)
        end
      rescue Zlib::Error
        raise incomplete(name)
      end

      def self.read_entries(gzip, name, allow_partial:, on_manifest:, &sink)
        manifest_size = entry_size(gzip, MANIFEST, name)
        raise incomplete(name) if !allow_partial && File.extname(name) == ".partial" # it starts as a backup; the run that made it didn't finish
        raise not_a_backup(nil, name) if manifest_size > MANIFEST_LIMIT

        manifest_text = read_exactly(gzip, manifest_size, name)
        skip_padding(gzip, manifest_size, name)
        manifest, unknown = parse_manifest(manifest_text, name)
        on_manifest&.call(manifest) if manifest
        snapshot_size = entry_size(gzip, SNAPSHOT, name)
        digest = Digest::SHA256.new
        remaining = snapshot_size
        while remaining.positive?
          chunk = gzip.read([ CHUNK, remaining ].min) or raise incomplete(name)
          digest << chunk
          sink&.call(chunk)
          remaining -= chunk.bytesize
        end
        skip_padding(gzip, snapshot_size, name)
        gzip.read # the end blocks: reading to the end is what checks the stream's CRC and length
        raise unknown_version(unknown, name) if unknown
        raise changed(name) unless digest.hexdigest == manifest.snapshot_sha256 && snapshot_size == manifest.snapshot_bytes

        Result.new(manifest:, sha256: digest.hexdigest, bytes: snapshot_size)
      end

      def self.parse_manifest(text, name)
        [ Manifest.parse(text), nil ]
      rescue Manifest::UnknownVersion => unknown
        [ nil, unknown ]
      rescue Manifest::Invalid
        raise not_a_backup(nil, name)
      end

      # The size of the next entry, which must be the regular file +expected+ in a ustar block with a good checksum.
      def self.entry_size(gzip, expected, name)
        block = gzip.read(BLOCK)
        valid = block && block.bytesize == BLOCK && block.byteslice(257, 5) == "ustar" && checksum_ok?(block) &&
          block.byteslice(0, 100).unpack1("Z*") == expected && [ "0", "\0" ].include?(block.byteslice(156, 1))
        raise not_a_backup(nil, name) unless valid

        block.byteslice(124, 12).unpack1("Z*").strip.to_i(8)
      end

      def self.checksum_ok?(block)
        stored = block.byteslice(148, 8).unpack1("Z*").strip.to_i(8)
        stored == block.bytes.sum - block.byteslice(148, 8).bytes.sum + (" ".ord * 8)
      end

      def self.read_exactly(gzip, size, name)
        data = gzip.read(size)
        raise incomplete(name) unless data && data.bytesize == size

        data
      end

      def self.skip_padding(gzip, size, name)
        padding = (BLOCK - size % BLOCK) % BLOCK
        read_exactly(gzip, padding, name) if padding.positive?
      end

      # An export file is the likeliest wrong file (a collector's, not the instance's), so it gets its own sentence.
      def self.not_a_backup(file, name)
        head = file ? file.tap(&:rewind).read(4096).to_s.b : "".b
        if head.lstrip.start_with?("{") && head.include?('"format_version"')
          Refusal.new("#{name} is a Collector export file, not a backup.", "Import it in the app with Import collection (More, then Import collection).")
        else
          Refusal.new("#{name} isn't a Collector backup.", "Give a collector-backup-….tar.gz file made by backup:create.")
        end
      end

      def self.incomplete(name) = Refusal.new("#{name} is incomplete; it was cut short or is still being written.", "Take the backup again, or copy it again.")

      def self.changed(name) = Refusal.new("#{name} doesn't match its checksum; it was changed or damaged after it was made.", "Use another copy of the backup.")

      def self.unknown_version(unknown, name)
        known = FORMAT_VERSIONS.join(", ")
        Refusal.new("#{name} uses backup format version #{unknown.version}; this release restores #{FORMAT_VERSIONS.one? ? "version" : "versions"} #{known}.",
          "Restore it with a release that knows that version.")
      end

      private_class_method :read_entries, :parse_manifest, :entry_size, :checksum_ok?, :read_exactly, :skip_padding, :not_a_backup, :incomplete, :changed, :unknown_version
    end
  end
end
```

Two details the first run settles (research.md 8): that `Zlib::GzipReader#read(n)` raises a `Zlib::Error` subclass on a truncated stream and `Zlib::GzipFile::CRCError` at the end; and that `TarWriter` entries extract with the system `tar`. If `raise not_a_backup(nil, name)` is reached for the export case the `file` is nil and the export sentence is lost; the export is a non-gzip file, so it takes the first `raise` (with the file), which is the only place the export sentence is needed.

In `lib/collector/backup.rb` add, after the `free_space` line: `require_relative "backup/manifest"` and `require_relative "backup/archive"`.

- [ ] **Step 1.5: Run the new specs, then everything.** `bin/rspec spec/lib/collector/backup` — expect all pass. `bin/rspec` — expect 0 failures. `bin/rubocop` — no offenses.

- [ ] **Step 1.6: Commit** `feat(backup): add the backup file's manifest and archive` (stage `lib/collector/backup.rb`, `lib/collector/backup/manifest.rb`, `lib/collector/backup/archive.rb`, `spec/support/backup_helpers.rb`, `spec/lib/collector/backup/`).

**Phase 1 verification:** the archive example lists `manifest.json` then `primary.sqlite3` with the system `tar` and extracts to the same bytes (the manual recovery path of FR-7 is therefore real); each case of AC-3.1 to AC-3.4 has its refusal sentence at the file level.

---

## Phase 2: The snapshot (`Snapshot`)

**Implements:** decision 6 (snapshots through `SQLite3::Database`, never Active Record), decision 7 (verification), decision 10 (the schema rule's input), decision 3 (ending sessions) | **Satisfies:** AC-1.4 (rollback-journal header), AC-1.12 and AC-3.7 (detection), the database half of AC-1.2, AC-2.1 and AC-3.5

**Goal:** one class owns every SQLite operation the commands perform: `VACUUM INTO`, the integrity and foreign-key checks, the counts, the schema versions, ending sessions with the cascade, and closing in rollback-journal mode. It opens only the files it is given and never creates a missing one.

**Files:**
- Create: `lib/collector/backup/snapshot.rb`, `spec/lib/collector/backup/snapshot_spec.rb`
- Edit: `lib/collector/backup.rb` (one `require_relative`)

**Interfaces:** `Snapshot.take(source:, into:)` (raises `Snapshot::Damaged`, `SQLite3::CantOpenException`, `SQLite3::BusyException`, `SQLite3::FullException`); `Snapshot.new(path)` → `#path`, `#verify!` (raises `Damaged` or `OrphanRows#count`), `#counts` → `{ "accounts" => n, "users" => n, "lots" => n }`, `#schema_versions` → `Array<String>`, `#end_sessions!`, `#rollback_journal!` (raises `Damaged` if the header isn't `[1, 1]` afterwards), `#rollback_journal?`

- [ ] **Step 2.1: Write the failing spec.** `spec/lib/collector/backup/snapshot_spec.rb` (transactional: the examples copy the test database's schema and write rows directly into their copies):

```ruby
require "rails_helper"

RSpec.describe Collector::Backup::Snapshot, :backup do
  let(:copy) { copy_of_instance }
  let(:snapshot) { described_class.new(copy) }
  let(:now) { "2026-10-21 14:21:00" }

  def insert_account_and_user(database, email: "a@example.test")
    database.execute("INSERT INTO accounts (created_at, updated_at) VALUES (?, ?)", [ now, now ])
    account_id = database.last_insert_row_id
    database.execute("INSERT INTO users (account_id, name, email_address, password_digest, created_at, updated_at) VALUES (?, 'N', ?, 'd', ?, ?)",
      [ account_id, email, now, now ])
    [ account_id, database.last_insert_row_id ]
  end

  describe ".take" do
    it "copies a database into an empty private file with VACUUM INTO, and the copy checks out", :aggregate_failures do
      target = scratch_path("snapshot.sqlite3")
      Collector::Backup.create_private(target).close

      described_class.take(source: instance_database, into: target)

      expect(target.stat.mode & 0o777).to eq(0o600)
      expect { described_class.new(target).verify! }.not_to raise_error
      expect(described_class.new(target).schema_versions).to match_array(release_versions)
    end

    it "never creates a source that isn't there" do
      missing = scratch_path("none.sqlite3")

      expect { described_class.take(source: missing, into: scratch_path("out.sqlite3")) }.to raise_error(SQLite3::CantOpenException)
      expect(missing).not_to exist
    end

    it "calls a source with a page it can't read damaged (AC-1.5)" do
      damage_table!(copy, "lots")

      expect { described_class.take(source: copy, into: scratch_path("out.sqlite3")) }.to raise_error(described_class::Damaged)
    end
  end

  describe "#rollback_journal!" do
    it "turns a WAL file into a rollback-journal file with no sidecar, whatever its header said first (AC-1.4)", :aggregate_failures do
      sqlite(copy) { |database| database.execute("PRAGMA journal_mode = WAL") }
      expect(File.binread(copy, 2, 18).bytes).to eq([ 2, 2 ])

      snapshot.rollback_journal!

      expect(File.binread(copy, 2, 18).bytes).to eq([ 1, 1 ])
      expect(snapshot).to be_rollback_journal
      expect(Dir["#{copy}-*"]).to be_empty
    end

    it "leaves a rollback-journal file as it is" do
      snapshot.rollback_journal!
      snapshot.rollback_journal!

      expect(snapshot).to be_rollback_journal
    end
  end

  describe "#verify!" do
    it "passes a sound database" do
      expect { snapshot.verify! }.not_to raise_error
    end

    it "calls a database with an unreadable page damaged (AC-3.7)" do
      damage_table!(copy, "lots")

      expect { snapshot.verify! }.to raise_error(described_class::Damaged)
    end

    it "counts the rows that fail the foreign-key check (AC-1.12, AC-3.7)" do
      sqlite(copy) do |database|
        database.execute("PRAGMA foreign_keys = OFF")
        database.execute("INSERT INTO lots (account_id, catalog_entry_id, quantity, lot_key, created_at, updated_at) VALUES (999, 999, 1, 'k', ?, ?)", [ now, now ])
      end

      expect { snapshot.verify! }.to raise_error(described_class::OrphanRows) { |error| expect(error.count).to eq(1) }
    end

    it "calls a file that is not a database damaged" do
      garbage = scratch_path("garbage.sqlite3").tap { it.binwrite("this is not a database" * 100) }

      expect { described_class.new(garbage).verify! }.to raise_error(described_class::Damaged)
    end
  end

  describe "#counts and #schema_versions" do
    it "counts accounts, users and lots, and lists the migrations the database has run", :aggregate_failures do
      sqlite(copy) { |database| insert_account_and_user(database) }

      expect(snapshot.counts).to eq("accounts" => 1, "users" => 1, "lots" => 0)
      expect(snapshot.schema_versions).to match_array(release_versions)
    end
  end

  describe "#end_sessions!" do
    it "deletes every session with foreign keys on, which takes the bulk removals, selections and marks with them (decision 3, AC-2.1)", :aggregate_failures do
      sqlite(copy) do |database|
        database.execute("PRAGMA foreign_keys = OFF")
        account_id, user_id = insert_account_and_user(database)
        database.execute("INSERT INTO sessions (user_id, created_at, updated_at) VALUES (?, ?, ?)", [ user_id, now, now ])
        session_id = database.last_insert_row_id
        database.execute("INSERT INTO bulk_selections (session_id, account_id, created_at, updated_at) VALUES (?, ?, ?, ?)", [ session_id, account_id, now, now ])
        selection_id = database.last_insert_row_id
        database.execute("INSERT INTO bulk_selection_marks (bulk_selection_id, account_id, lot_id) VALUES (?, ?, 1)", [ selection_id, account_id ])
        database.execute("INSERT INTO bulk_removals (session_id, account_id, copies, created_at, updated_at) VALUES (?, ?, 1, ?, ?)", [ session_id, account_id, now, now ])
      end

      snapshot.end_sessions!

      tables = %w[sessions bulk_selections bulk_selection_marks bulk_removals]
      expect(sqlite(copy, readonly: true) { |database| tables.map { database.get_first_value("SELECT COUNT(*) FROM #{it}") } }).to eq([ 0, 0, 0, 0 ])
      expect(snapshot.counts).to include("users" => 1)
    end
  end
end
```

- [ ] **Step 2.2: Run and see it fail.** `bin/rspec spec/lib/collector/backup/snapshot_spec.rb` — expect `uninitialized constant Collector::Backup::Snapshot`.

- [ ] **Step 2.3: Write `Snapshot`.** `lib/collector/backup/snapshot.rb`:

```ruby
module Collector
  module Backup
    # One SQLite file that is the commands' own (a snapshot being written, or the restore's temporary file). Always opened
    # with SQLite3::Database and never Active Record: the Rails adapter sets journal_mode WAL on every connection, which
    # would convert the file and leave -wal and -shm beside it (decision 6, research.md 4). No open creates a missing file.
    class Snapshot
      Damaged = Class.new(StandardError) # the file can't be read as a sound Collector database

      class OrphanRows < StandardError
        attr_reader :count

        def initialize(count)
          @count = count
          super("#{count} rows fail the foreign-key check")
        end
      end

      attr_reader :path

      # One read transaction, so a WAL database's writers keep going (decision 1). +into+ must be absent or an empty file.
      def self.take(source:, into:)
        database = SQLite3::Database.new(source.to_s, readwrite: true)
        database.busy_timeout = BUSY_TIMEOUT_MS
        database.execute("VACUUM INTO ?", [ into.to_s ])
      rescue SQLite3::CorruptException, SQLite3::NotADatabaseException => error
        raise Damaged, error.message
      ensure
        database&.close
      end

      def initialize(path)
        @path = Pathname(path)
      end

      # SQLite's integrity check, then its foreign-key check (decision 7). Proves this file sound, not the file it was
      # copied from: VACUUM INTO rebuilds indexes (decision 7). foreign_keys is set explicitly because SQLite's default is
      # off (decision 6), though foreign_key_check reports violations either way.
      def verify!
        with(readonly: true) do |database|
          database.execute("PRAGMA foreign_keys = ON")
          problems = database.execute("PRAGMA integrity_check").flatten
          raise Damaged, problems.first(3).join("; ") unless problems == [ "ok" ]

          violations = database.execute("PRAGMA foreign_key_check")
          raise OrphanRows.new(violations.size) if violations.any?
        end
      end

      # Counts only, never a name or an address (hosted-door rule 2, AC-1.7). Cross-tenant by nature: it counts the instance.
      def counts
        with(readonly: true) do |database|
          %w[accounts users lots].to_h { |table| [ table, database.get_first_value("SELECT COUNT(*) FROM #{table}") ] }
        end
      end

      def schema_versions
        with(readonly: true) { |database| database.execute("SELECT version FROM schema_migrations").flatten }
      end

      # Ends every session with foreign keys on, so the database cascades to bulk_removals, bulk_selections and, through
      # them, bulk_selection_marks (decision 3, FR-3). journal_mode is set first so the delete can't make a WAL file.
      def end_sessions!
        with do |database|
          database.execute("PRAGMA journal_mode = DELETE")
          database.execute("PRAGMA foreign_keys = ON")
          database.execute("DELETE FROM sessions")
        end
      end

      def rollback_journal!
        with { |database| database.execute("PRAGMA journal_mode = DELETE") }
        [ "-wal", "-shm", "-journal" ].each { FileUtils.rm_f("#{path}#{it}") }
        raise Damaged, "the file is not in rollback-journal mode" unless rollback_journal?
      end

      # Header bytes 18 and 19 are 1 for rollback-journal mode and 2 for WAL.
      def rollback_journal? = File.binread(path, 2, 18).bytes == [ 1, 1 ]

      private
        def with(readonly: false)
          database = SQLite3::Database.new(path.to_s, readonly ? { readonly: true } : { readwrite: true })
          database.busy_timeout = BUSY_TIMEOUT_MS
          yield database
        rescue SQLite3::CorruptException, SQLite3::NotADatabaseException, SQLite3::SQLException => error
          raise Damaged, error.message
        ensure
          database&.close
        end
    end
  end
end
```

Add `require_relative "backup/snapshot"` to `lib/collector/backup.rb`. The first run confirms three assumptions (research.md 8): `VACUUM INTO ?` takes a bound path and an existing empty file on a `readwrite: true` connection; a `SQLite3::Database` on a non-database file raises `NotADatabaseException` on its first statement (caught by `with`); and `PRAGMA journal_mode = DELETE` leaves bytes 18 and 19 at 1.

- [ ] **Step 2.4: Run the spec, then everything.** `bin/rspec spec/lib/collector/backup/snapshot_spec.rb` — expect pass. `bin/rspec` — 0 failures. `bin/rubocop` — clean.

- [ ] **Step 2.5: Commit** `feat(backup): add the snapshot's SQLite operations` (stage the three files).

**Phase 2 verification:** every SQLite call in the library is in `snapshot.rb` (a `git grep -n "SQLite3::Database" lib ':!.kamal/secrets'` shows only `snapshot.rb`); none opens Active Record.

---

## Phase 3: `backup:create`

**Implements:** FR-1, FR-6 (what `Create` deletes), FR-10, decisions 7, 8 and 13 (the free-space rule) | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-1.7 (for this command), AC-1.8, AC-1.9, AC-1.11, AC-1.12, AC-4.1

**Goal:** an operator backs up a running instance with `bin/rails "backup:create[DIRECTORY]"`: one verified, private, atomically named file, or a plain refusal and nothing left behind, with writers unaffected.

**Files:**
- Create: `lib/collector/backup/create.rb`, `lib/tasks/backup.rake`
- Edit: `lib/collector/backup.rb` (one `require_relative`)
- Create: `spec/lib/collector/backup/create_spec.rb`, `spec/tasks/backup_create_rake_spec.rb`

**Interfaces:** `Create.new(directory:, source: Databases.configured.primary, clock: Time, free_space: FreeSpace.method(:bytes), checkpoint: ->(_step) {})` → `#call` → `Create::Result(path, bytes, schema_version, counts, seconds)` with `#report`; raises `Refusal`. Checkpoints: `:snapshot_written`, `:archive_written`. The constant `Create::PARTIAL` is the temporary names' pattern. `clock` is anything with `#now` (the seam for the file name); `free_space` and `checkpoint` are the seams of AC-1.11 and AC-1.6.

- [ ] **Step 3.1: Write the failing specs.**

`spec/lib/collector/backup/create_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::Backup::Create, :backup, :committed do
  let(:directory) { scratch("out") }
  let!(:seed) { seed_instance }

  def run(into: directory, source: instance_database, clock: clock_at, **options)
    described_class.new(directory: into, source:, clock:, **options).call
  end

  it "writes one file named by the UTC second and returns its facts (AC-1.1)", :aggregate_failures do
    result = run

    expect(directory.children.map { it.basename.to_s }).to eq([ "collector-backup-20261021T142100Z.tar.gz" ])
    expect(result).to have_attributes(path: directory.join("collector-backup-20261021T142100Z.tar.gz"),
      schema_version: release_versions.max_by(&:to_i), counts: { "accounts" => 1, "users" => 1, "lots" => 3 })
    expect(result.bytes).to eq(result.path.size)
    expect(result.report).to match(/\ABackup written: .*\nSize: .*\nSchema version: \d+\nHolds: 1 account, 1 user and 3 lots\nTook: \d+\.\d s\z/)
  end

  it "holds the manifest and a rollback-journal snapshot that agrees with it, and no sidecar (AC-1.4)", :aggregate_failures do
    path = run.path
    unpacked = scratch("unpacked")
    _output, status = Open3.capture2("tar", "-xzf", path.to_s, "-C", unpacked.to_s)
    snapshot = unpacked.join("primary.sqlite3")
    manifest = Collector::Backup::Manifest.parse(unpacked.join("manifest.json").read)

    expect(status).to be_success
    expect(unpacked.children.map { it.basename.to_s }).to match_array(%w[manifest.json primary.sqlite3])
    expect(manifest).to have_attributes(backup_format_version: 1, taken_at: "2026-10-21T14:21:00Z", snapshot_bytes: snapshot.size,
      snapshot_sha256: Digest::SHA256.file(snapshot).hexdigest, counts: { "accounts" => 1, "users" => 1, "lots" => 3 })
    expect(File.binread(snapshot, 2, 18).bytes).to eq([ 1, 1 ])
    expect(Dir["#{snapshot}-*"]).to be_empty
    expect { Collector::Backup::Snapshot.new(snapshot).verify! }.not_to raise_error
  end

  it "is private and holds no secret or setting, and nothing but the two files (AC-1.8, AC-4.1)", :aggregate_failures do
    with_env(BackupHelpers::SECRETS) { run }
    path = directory.children.sole
    unpacked = scratch("unpacked")
    listing, = Open3.capture2("tar", "-tzf", path.to_s)
    Open3.capture2("tar", "-xzf", path.to_s, "-C", unpacked.to_s)
    bytes = unpacked.children.sum("".b) { it.binread }

    expect(path.stat.mode & 0o777).to eq(0o600)
    expect(listing.lines(chomp: true)).to eq(%w[manifest.json primary.sqlite3])
    BackupHelpers::SECRETS.each_value { |value| expect(bytes).not_to include(value) }
  end

  describe "while the app writes (AC-1.2, AC-1.3)" do
    let(:entries) { Array.new(300) { create(:mtg_printing, entry: create(:catalog_entry)).entry } }
    let(:stats) { { pairs: Queue.new, waits: Queue.new, commits: Queue.new, errors: Queue.new } }

    def timed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stats[:waits] << finished - started
      stats[:commits] << finished
    rescue StandardError => error
      stats[:errors] << error
    end

    # Two writers on their own connections: a pair of related rows in one transaction (an account and its user, as a
    # sign-up writes them), and the app's own lot add (Lot.add!, an IMMEDIATE transaction, app/models/lot.rb).
    def start_writers(stop)
      pairs = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          index = 0
          until stop.true?
            timed do
              user = User.create!(name: "Pair #{index}", email_address: "pair#{index}@example.test", password: "correct horse battery")
              stats[:pairs] << user.account_id
            end
            index += 1
          end
        end
      end
      lots = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          entries.each do |entry|
            break if stop.true?

            timed { Lot.add!(account: seed.user.account, entry:) }
          end
        end
      end
      [ pairs, lots ]
    end

    def drain(queue) = Array.new(queue.size) { queue.pop }

    # Accounts without a user, and users without an account: a half-written pair would show here, which totals could hide.
    def unpaired(path)
      sqlite(path, readonly: true) do |database|
        [ database.get_first_value("SELECT COUNT(*) FROM accounts a LEFT JOIN users u ON u.account_id = a.id WHERE u.id IS NULL"),
          database.get_first_value("SELECT COUNT(*) FROM users u LEFT JOIN accounts a ON a.id = u.account_id WHERE a.id IS NULL") ]
      end
    end

    before do
      entries
      # A database big enough for a backup to take a moment.
      Catalog::Identity.insert_all(Array.new(50_000) { |index| { collectible_type: "mtg", external_key: "filler-#{index}", name: "Filler #{index}", content_digest: "d" } })
    end

    it "holds both rows of every pair or neither, passes its checks, and makes every write complete within the busy timeout", :aggregate_failures do
      stop = Concurrent::AtomicBoolean.new(false)
      writers = start_writers(stop)
      Timeout.timeout(30) { sleep 0.01 until stats[:commits].size >= 20 || stats[:errors].size.positive? }
      committed_before = drain(stats[:pairs])
      windows = []
      results = Array.new(4) do |index|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        described_class.new(directory: scratch("out#{index}"), source: instance_database, clock: clock_at(Time.utc(2026, 10, 21, 14, 21, index))).call.tap do
          windows << (started..Process.clock_gettime(Process::CLOCK_MONOTONIC))
        end
      end
      stop.make_true
      writers.each(&:join)

      expect(drain(stats[:errors])).to be_empty
      expect(drain(stats[:waits]).max).to be < Collector::Backup::BUSY_TIMEOUT_MS / 1000.0
      expect(drain(stats[:commits]).count { |time| windows.any? { it.cover?(time) } }).to be_positive # writes landed while a backup ran
      results.each_with_index do |result, index|
        snapshot = Collector::Backup::Snapshot.new(unpack_snapshot(result.path, "snapshot-#{index}.sqlite3"))
        counts = snapshot.counts

        expect { snapshot.verify! }.not_to raise_error
        expect(unpaired(snapshot.path)).to eq([ 0, 0 ]) # a pair is both rows or neither, in every snapshot
        expect(counts.fetch("users")).to be_positive
      end
      first = sqlite(unpack_snapshot(results.first.path, "first.sqlite3"), readonly: true) { |database| database.execute("SELECT id FROM accounts").flatten }
      expect(first).to include(*committed_before)
    end
  end

  it "refuses a damaged database with a plain message and leaves nothing behind (AC-1.5)", :aggregate_failures do
    damaged = copy_of_instance("damaged.sqlite3").tap { damage_table!(it, "lots") }
    refusal = refusal_of { run(source: damaged) }

    expect(refusal.problem).to eq("The database reports damage, so no backup was made.")
    expect(refusal.message).not_to match(/SQLite|Collector::|Exception|\.rb/)
    expect(directory.children).to be_empty
  end

  it "leaves at worst a private .partial file when it is killed with the snapshot written (AC-1.6)", :aggregate_failures do
    run_killed_at(:snapshot_written, <<~RUBY, directory, instance_database)
      Collector::Backup::Create.new(directory: ARGV[0], source: ARGV[1], checkpoint: STOP_HERE).call
    RUBY

    leftovers = directory.children
    expect(leftovers.map { it.basename.to_s }).to all(match(described_class::PARTIAL))
    expect(leftovers.size).to eq(1)
    expect(leftovers.first.stat.mode & 0o777).to eq(0o600)
  end

  it "removes a .partial file more than a day old on the next run and leaves a younger one (AC-1.6)", :aggregate_failures do
    old = directory.join("collector-backup-20260101T000000Z.tar.gz.0123456789abcdef.partial").tap { it.write("x") }
    old_sidecars = %w[-journal -wal -shm].map { |suffix| directory.join("collector-backup-20260101T000000Z.sqlite3.0123456789abcdef.partial#{suffix}").tap { it.write("s") } }
    young = directory.join("collector-backup-20260102T000000Z.sqlite3.fedcba9876543210.partial").tap { it.write("y") }
    young_sidecar = directory.join("collector-backup-20260102T000000Z.sqlite3.fedcba9876543210.partial-shm").tap { it.write("t") }
    other = directory.join("notes.partial").tap { it.write("z") }
    [ old, *old_sidecars ].each { File.utime(26.hours.ago, 26.hours.ago, it) }

    run

    expect([ old, *old_sidecars ]).to all(satisfy { !it.exist? }) # a killed run's sidecars go with it
    expect([ young, young_sidecar, other ]).to all(exist)
  end

  it "never replaces a file with the name it would use, and leaves no .partial (AC-1.9)", :aggregate_failures do
    taken = directory.join("collector-backup-20261021T142100Z.tar.gz").tap { it.write("someone else's file") }
    refusal = refusal_of { run }

    expect(refusal.problem).to eq("A file named collector-backup-20261021T142100Z.tar.gz already exists in #{directory}; it was left as it is.")
    expect(refusal.advice).to eq("Run it again in a second, or give another directory.")
    expect(taken.read).to eq("someone else's file")
    expect(directory.children).to eq([ taken ])
  end

  it "gives two runs started together one file between them and the clash message for the other (AC-1.9)", :aggregate_failures do
    outcomes = Array.new(2) { Thread.new { refusal_of { run } } }.map(&:value)

    expect(outcomes.count(nil)).to eq(1)
    expect(outcomes.compact.sole.problem).to include("already exists")
    expect(directory.children.size).to eq(1)
    expect { Collector::Backup::Archive.read(directory.children.first) }.not_to raise_error
  end

  it "refuses a directory that doesn't exist, can't be written or has too little room, writing nothing (AC-1.11)", :aggregate_failures do
    missing = scratch_path("not-there")
    expect(refusal_of { run(into: missing) }.problem).to eq("#{missing} doesn't exist or isn't a directory.")

    unless Process.uid.zero?
      locked = scratch("locked").tap { it.chmod(0o500) }
      expect(refusal_of { run(into: locked) }.problem).to eq("#{locked} isn't writable by the user Collector runs as (uid #{Process.uid}).")
      expect(locked.children).to be_empty
    end

    refusal = refusal_of { run(free_space: ->(_path) { 1 }) }
    expect(refusal.problem).to match(/\A#{Regexp.escape(directory.to_s)} has 1 byte free; a backup needs about .* \(twice the database's size\)\.\z/)
    expect(directory.children).to be_empty
  end

  it "refuses a source that isn't there without creating it", :aggregate_failures do
    missing = scratch_path("no-primary.sqlite3")

    expect(refusal_of { run(source: missing) }.problem).to eq("There is no primary database at #{missing}.")
    expect(missing).not_to exist
  end

  it "refuses a database that fails its foreign-key check and points to the exports (AC-1.12)", :aggregate_failures do
    orphaned = copy_of_instance("orphaned.sqlite3")
    sqlite(orphaned) do |database|
      database.execute("PRAGMA foreign_keys = OFF")
      database.execute("INSERT INTO lots (account_id, catalog_entry_id, quantity, lot_key, created_at, updated_at) VALUES (999, 999, 1, 'k', '2026-10-21 14:21:00', '2026-10-21 14:21:00')")
    end
    refusal = refusal_of { run(source: orphaned) }

    expect(refusal.problem).to eq("The database fails its foreign-key check (1 row), so no backup was made.")
    expect(refusal.advice).to include("Export collection")
    expect(directory.children).to be_empty
  end
end
```

`spec/tasks/backup_create_rake_spec.rb`:

```ruby
require "rails_helper"
require "rake"

RSpec.describe "backup:create", :backup, :committed, type: :task do
  let(:directory) { scratch("out") }
  let!(:seed) { seed_instance }

  before { Rails.application.load_tasks unless Rake::Task.task_defined?("backup:create") }

  def run_task(*arguments)
    Rake::Task["backup:create"].reenable
    captured_streams { Rake::Task["backup:create"].invoke(*arguments) }
  end

  it "prints the file's path, size, schema version, counts and time, and exits 0 (AC-1.1)", :aggregate_failures do
    out, err, status = run_task(directory.to_s)

    expect(status).to eq(0)
    expect(err).to be_empty
    expect(out).to include("Backup written: #{directory}/collector-backup-", "Size: ", "Schema version: #{release_versions.max_by(&:to_i)}",
      "Holds: 1 account, 1 user and 3 lots", "Took: ")
  end

  it "prints no recognisable name, address or card, and logs none (AC-1.7)", :aggregate_failures do
    out = err = nil
    log = captured_log { out, err, = run_task(directory.to_s) }

    seed.values.each do |value|
      expect(out).not_to include(value)
      expect(err).not_to include(value)
      expect(log).not_to include(value)
    end
  end

  it "says what to do, in two lines and with status 1, when no directory is given", :aggregate_failures do
    out, err, status = run_task

    expect(status).to eq(1)
    expect(out).to be_empty
    expect(err.lines(chomp: true)).to eq([ "No directory was given.", %(Run: bin/rails "backup:create[/path/to/directory]".) ])
  end

  it "refuses an argument with a comma, which Rake reads as two" do
    _out, err, status = run_task("/tmp/a", "b")

    expect([ status, err.lines.first ]).to eq([ 1, "The directory argument contains a comma, which Rake reads as a second argument.\n" ])
  end

  it "prints a refusal as two sentences without an exception class or a backtrace, and exits 1", :aggregate_failures do
    _out, err, status = run_task(scratch_path("not-there").to_s)

    expect(status).to eq(1)
    expect(err.lines.size).to eq(2)
    expect(err).not_to match(/Refusal|Collector::|\.rb:\d+/)
  end
end
```

- [ ] **Step 3.2: Run and see them fail.** `bin/rspec spec/lib/collector/backup/create_spec.rb spec/tasks/backup_create_rake_spec.rb` — expect `uninitialized constant Collector::Backup::Create` and `Don't know how to build task 'backup:create'`.

- [ ] **Step 3.3: Write `Create`.** `lib/collector/backup/create.rb`:

```ruby
module Collector
  module Backup
    # backup:create (spec 030 FR-1, decisions 1, 5, 7, 13): a verified, private, atomically named backup of the primary
    # database, taken while the app runs. Everything it writes is in +directory+, under a .partial name created 0600, until
    # the finished archive is hard-linked to its final name, which it never replaces.
    class Create
      Result = Data.define(:path, :bytes, :schema_version, :counts, :seconds) do
        def report
          [ "Backup written: #{path}", "Size: #{Backup.size_phrase(bytes)}", "Schema version: #{schema_version}",
            "Holds: #{Backup.counts_phrase(counts)}", format("Took: %.1f s", seconds) ].join("\n")
        end
      end

      # Both temporary names, and the sidecars SQLite may leave beside one a killed run was using:
      # collector-backup-<time>.(tar.gz|sqlite3).<16 hex>.partial[-journal|-wal|-shm] (contracts/archive.md).
      PARTIAL = /\Acollector-backup-\d{8}T\d{6}Z\.(?:tar\.gz|sqlite3)\.\h{16}\.partial(?:-journal|-wal|-shm)?\z/

      def initialize(directory:, source: Databases.configured.primary, clock: Time, free_space: FreeSpace.method(:bytes),
        checkpoint: ->(_step) {})
        @directory = Pathname(directory.to_s)
        @source = Pathname(source)
        @clock = clock
        @free_space = free_space
        @checkpoint = checkpoint
      end

      def call
        translating do
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          check_destination
          taken_at = Time.at(@clock.now.to_i).utc
          final = @directory.join("collector-backup-#{taken_at.strftime("%Y%m%dT%H%M%SZ")}.tar.gz")
          raise name_taken(final) if final.exist?

          sweep_stale_partials
          manifest = make(final, taken_at)
          Result.new(path: final, bytes: final.size, schema_version: manifest.schema_version, counts: manifest.counts,
            seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
        end
      end

      private
        def check_destination
          raise Refusal.new("#{@directory} doesn't exist or isn't a directory.", "Create it, or give another directory.") unless @directory.directory?
          unless @directory.writable? && @directory.executable?
            raise Refusal.new("#{@directory} isn't writable by the user Collector runs as (uid #{Process.uid}).",
              "Make it writable by that user (for example with chown 1000:1000), or give another directory.")
          end
          raise no_source unless @source.file?

          need = 2 * @source.size
          free = @free_space.call(@directory)
          return unless free && free < need

          raise Refusal.new("#{@directory} has #{Backup.size_phrase(free)} free; a backup needs about #{Backup.size_phrase(need)} (twice the database's size).",
            "Free some space, or give a directory on a larger disk.")
        end

        # A killed run leaves a .partial file; a younger one may belong to a run in progress (decision 7).
        def sweep_stale_partials
          cutoff = Time.now - STALE_PARTIAL_SECONDS
          @directory.children.each do |child|
            FileUtils.rm_f(child) if PARTIAL.match?(child.basename.to_s) && child.file? && child.mtime < cutoff
          end
        end

        def make(final, taken_at)
          token = SecureRandom.hex(8)
          snapshot_file = @directory.join("#{final.basename(".tar.gz")}.sqlite3.#{token}.partial")
          archive_file = @directory.join("#{final.basename}.#{token}.partial")
          published = false
          Backup.create_private(snapshot_file).close
          Snapshot.take(source: @source, into: snapshot_file)
          @checkpoint.call(:snapshot_written)
          snapshot = Snapshot.new(snapshot_file)
          snapshot.rollback_journal! # before verify!: a WAL header would make verify!'s open leave -shm and -wal beside the file
          snapshot.verify!
          manifest = Manifest.for(snapshot, taken_at:)
          Archive.write(archive_file, manifest:, snapshot: snapshot_file)
          read_back(archive_file)
          @checkpoint.call(:archive_written)
          Backup.publish(archive_file, final) { raise name_taken(final) }
          published = true
          Backup.fsync_directory(@directory)
          manifest
        ensure
          Backup.remove(snapshot_file) if snapshot_file
          Backup.remove(archive_file) if archive_file && !published
        end

        # The archive is read back whole before it counts as a backup: one that can't be restored is never reported as made.
        # It is still under its .partial name, which Archive.read refuses for anyone else (plan-review C1).
        def read_back(archive_file)
          Archive.read(archive_file, allow_partial: true)
        rescue Refusal
          raise Refusal.new("The backup file just written doesn't read back, so no backup was made.", "Run it again; if it keeps failing, check the disk.")
        end

        def translating
          yield
        rescue Snapshot::Damaged
          raise Refusal.new("The database reports damage, so no backup was made.",
            "Restore the last good backup, and ask each collector to download their export (Export collection) while the instance still answers.")
        rescue Snapshot::OrphanRows => error
          raise Refusal.new("The database fails its foreign-key check (#{error.count} #{error.count == 1 ? "row" : "rows"}), so no backup was made.",
            "Each collector's export (Export collection) is still available; a backup of an instance in this state would be refused when restored.")
        rescue SQLite3::BusyException
          raise Refusal.new("The database stayed busy for more than #{BUSY_TIMEOUT_MS / 1000} seconds.", "Run it again in a quieter moment.")
        rescue SQLite3::FullException, Errno::ENOSPC
          raise Refusal.new("The disk filled up while the backup was written.", "Free some space and run it again.")
        rescue SQLite3::CantOpenException
          raise Refusal.new("The database couldn't be opened or the backup couldn't be written.",
            "Check that #{@source} and #{@directory} are readable by the user Collector runs as.")
        end

        def name_taken(final)
          Refusal.new("A file named #{final.basename} already exists in #{@directory}; it was left as it is.", "Run it again in a second, or give another directory.")
        end

        def no_source
          Refusal.new("There is no primary database at #{@source}.", "Run this inside the running Collector container, with its storage volume mounted.")
        end
    end
  end
end
```

`lib/tasks/backup.rake`:

```ruby
require Rails.root.join("lib/collector/backup").to_s

# The operator's backup and restore (spec 030, ADR 0024, docs/backup-restore.md). Neither task depends on :environment, so
# neither initializes the application: no initializers, no queue or cache connection, no secret_key_base, and no Active
# Record connection that could create the primary's file (research.md 1 and 2). The logic is in lib/collector/backup/.
namespace :backup do
  desc %(Back up the primary database into DIRECTORY, an existing directory the container's user can write: bin/rails "backup:create[/backups]")
  task :create, [ :directory ] do |_task, args|
    Collector::Backup.run do
      directory = Collector::Backup.argument(args, :directory, 'bin/rails "backup:create[/path/to/directory]"')
      puts Collector::Backup::Create.new(directory:).call.report
    end
  end
end
```

Add `require_relative "backup/create"` to `lib/collector/backup.rb`. The `restore` line comes with Phase 4.

- [ ] **Step 3.4: Run the specs.** `bin/rspec spec/lib/collector/backup/create_spec.rb spec/tasks/backup_create_rake_spec.rb` — expect pass. If the concurrent example fails on the `be_positive` overlap expectation, the backups finished between two commits: raise the filler to 150,000 rows (the example's job is to prove overlap, so it must overlap). Then `bin/rspec` (0 failures), `bin/rubocop`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.

- [ ] **Step 3.5: Commit** `feat(backup): add backup:create` (stage the library file, the task, the two specs, `lib/collector/backup.rb`).

**Phase 3 verification:** AC-1.1 to AC-1.9, AC-1.11, AC-1.12 and AC-4.1 have an example each; the concurrency example reads every snapshot back through the checks.

---

## Phase 4: `backup:restore`

**Implements:** FR-2, FR-3, FR-4, FR-6 (what `Restore` deletes), FR-8, FR-10, decisions 3, 6, 7 and 10 | **Satisfies:** AC-2.1, AC-2.5, AC-2.6, AC-2.7, AC-2.11, AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.5, AC-3.7, AC-3.8, AC-1.7 (for this command)

**Goal:** `bin/rails "backup:restore[FILE]"` places a verified snapshot as the primary database of a fresh volume, with every session ended, or refuses with two plain sentences and leaves the volume exactly as it was; a restore killed at any point leaves no primary database.

**Files:**
- Create: `lib/collector/backup/restore.rb`, `spec/lib/collector/backup/restore_spec.rb`, `spec/tasks/backup_restore_rake_spec.rb`
- Edit: `lib/collector/backup.rb` (one `require_relative`), `lib/tasks/backup.rake` (the second task)

**Interfaces:** `Restore.new(file:, databases: Databases.configured, release_versions: Backup.release_schema_versions, free_space: FreeSpace.method(:bytes), checkpoint: ->(_step) {})` → `#call` → `Restore::Result(file, volume, manifest)` with `#report`; raises `Refusal`. Checkpoint: `:snapshot_ready` (the snapshot is closed, checked and fsynced; linking it into place is next). `Restore::TEMPORARY = "collector-restore.partial"`.

- [ ] **Step 4.1: Write the failing specs.**

`spec/lib/collector/backup/restore_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::Backup::Restore, :backup, :committed do
  let(:volume) { scratch("volume") }
  let!(:seed) { seed_instance }

  # A refusal that changes nothing in the volume and reads as two plain sentences (AC-3.8): each starts with a capital, a path
  # or the file's name (collector-backup-….tar.gz, note.txt) and ends with a full stop.
  def expect_refused(path, problem, advice = nil)
    before = checksums(volume)
    refusal = refusal_of { restore_backup(path, volume:) }

    expect(refusal&.problem).to eq(problem)
    expect(refusal.advice).to eq(advice) if advice
    [ refusal.problem, refusal.advice ].each do |sentence|
      expect(sentence).to match(/\A(?:[A-Z]|\/|collector-backup-|[\w.-]+\.(?:gz|txt|json) ).*\.\z/)
      expect(sentence).not_to match(/Exception|Error|Collector::|SQLite3|\.rb\b/)
    end
    expect(checksums(volume)).to eq(before)
    expect(volume.children.map { it.basename.to_s }).to match_array(before.keys)
    refusal
  end

  describe "a fresh volume (AC-2.1, AC-2.11)" do
    it "places the snapshot with the sessions ended and every other row as it was", :aggregate_failures do
      seed_session(seed.user, seed.lots.first)
      path = create_backup
      result = restore_backup(path, volume:)
      primary = volume.join("production.sqlite3")
      cleared = %w[sessions bulk_removals bulk_selections bulk_selection_marks]
      live = table_rows(instance_database)
      restored = table_rows(primary)

      expect(volume.children.map { it.basename.to_s }).to eq([ "production.sqlite3" ])
      expect(File.binread(primary, 2, 18).bytes).to eq([ 1, 1 ])
      expect(restored.keys).to eq(live.keys)
      (live.keys - cleared).each { |table| expect(restored.fetch(table)).to eq(live.fetch(table)), table }
      cleared.each { |table| expect(restored.fetch(table)).to be_empty, table }
      expect(live.fetch("sessions")).not_to be_empty # the source had them
      expect { Collector::Backup::Snapshot.new(primary).verify! }.not_to raise_error
      expect(result.report.lines(chomp: true)).to include("Restored #{path.basename} into #{volume}.")
      expect(result.report).to include("it holds 1 account, 1 user and 3 lots.", "Everyone signs in again",
        "pending bulk-removal Undos and selections are gone", "Start Collector now", "Build art index")
    end

    it "restores an instance with no users and says who becomes its admin (AC-2.11)" do
      clear_instance!
      result = restore_backup(create_backup, volume:)

      expect(result.report).to include("The backup holds no users: the first person to reach the restored instance becomes its admin.")
    end

    it "restores from a file that lives in the volume, and leaves it as it was", :aggregate_failures do
      path = create_backup
      inside = volume.join(path.basename).tap { FileUtils.cp(path, it) }
      before = Digest::SHA256.file(inside).hexdigest

      restore_backup(inside, volume:)

      expect(volume.children.map { it.basename.to_s }).to match_array([ inside.basename.to_s, "production.sqlite3" ])
      expect(Digest::SHA256.file(inside).hexdigest).to eq(before)
    end

    it "reads no secret: one backup restored under two secrets holds the same rows (AC-2.7)" do
      path = create_backup
      first = scratch("first")
      second = scratch("second")
      with_env("SECRET_KEY_BASE" => "one" * 20) { restore_backup(path, volume: first) }
      with_env("SECRET_KEY_BASE" => "two" * 20) { restore_backup(path, volume: second) }

      expect(table_rows(first.join("production.sqlite3"))).to eq(table_rows(second.join("production.sqlite3")))
    end
  end

  describe "a volume that isn't fresh (AC-2.5)" do
    {
      "a primary database" => "production.sqlite3",
      "only a -wal file of a database that is gone" => "production.sqlite3-wal",
      "only a queue database" => "production_queue.sqlite3"
    }.each do |label, name|
      it "refuses a volume that holds #{label} and changes nothing", :aggregate_failures do
        volume.join(name).write("whatever was there")
        volume.join("catalog.txt").write("another file")
        path = create_backup

        expect_refused(path, "The volume at #{volume} isn't empty: it holds #{name}.",
          "Restore onto a new, empty volume and start Collector on that. Nothing was changed.")
      end
    end

    it "refuses a primary that appears while the restore runs, and removes its temporary file (never overwrites)", :aggregate_failures do
      path = create_backup
      appear = ->(step) { volume.join("production.sqlite3").write("appeared") if step == :snapshot_ready }

      refusal = refusal_of { restore_backup(path, volume:, checkpoint: appear) }

      expect(refusal.problem).to eq("The volume at #{volume} isn't empty: it holds production.sqlite3.")
      expect(volume.children.map { it.basename.to_s }).to eq([ "production.sqlite3" ])
      expect(volume.join("production.sqlite3").read).to eq("appeared")
    end
  end

  describe "a restore that is refused or stopped (AC-2.6)" do
    it "never creates the primary's path for a file that doesn't exist" do
      missing = scratch_path("nope.tar.gz")

      expect_refused(missing, "There is no file at #{missing}.", "Check the path as the container sees it; copy the backup in first.")
    end

    it "leaves no primary database when it is killed with the snapshot written, and the next restore succeeds and cleans up", :aggregate_failures do
      path = create_backup
      run_killed_at(:snapshot_ready, <<~RUBY, path, volume, release_versions.to_json)
        files = { "primary" => "production.sqlite3", "cache" => "production_cache.sqlite3", "queue" => "production_queue.sqlite3", "cable" => "production_cable.sqlite3" }
        databases = Collector::Backup::Databases.new(files.transform_values { |name| Pathname(ARGV[1]).join(name) })
        Collector::Backup::Restore.new(file: ARGV[0], databases: databases, release_versions: JSON.parse(ARGV[2]), checkpoint: STOP_HERE).call
      RUBY
      expect(volume.children.map { it.basename.to_s }).to eq([ "collector-restore.partial" ])
      volume.join("collector-restore.partial-journal").write("a stopped run's journal")

      restore_backup(path, volume:)

      expect(volume.children.map { it.basename.to_s }).to eq([ "production.sqlite3" ])
    end

    it "refuses a storage directory that isn't there", :aggregate_failures do
      gone = scratch_path("gone")

      refusal = refusal_of { restore_backup(create_backup, volume: gone) }

      expect(refusal.problem).to eq("The storage directory #{gone} doesn't exist.")
      expect(gone).not_to exist
    end

    it "refuses when the volume has too little room, before it writes anything", :aggregate_failures do
      path = create_backup
      refusal = refusal_of { restore_backup(path, volume:, free_space: ->(_path) { 1 }) }

      expect(refusal.problem).to match(/\AThe volume at #{Regexp.escape(volume.to_s)} has 1 byte free; the snapshot needs .*\.\z/)
      expect(volume.children).to be_empty
    end

    it "checks the room before the checksum, as FR-2 lists them (maintainer's ruling m3)", :aggregate_failures do
      original = unpack_snapshot(create_backup)
      changed = scratch_path("changed.sqlite3").tap { it.binwrite(original.binread.tap { |bytes| bytes.setbyte(bytes.bytesize - 1, bytes.getbyte(bytes.bytesize - 1) ^ 1) }) }
      altered = scratch("altered").join("collector-backup-20261021T142100Z.tar.gz").tap { Collector::Backup::Archive.write(it, manifest: manifest_for(original), snapshot: changed) }

      expect(refusal_of { restore_backup(altered, volume:, free_space: ->(_path) { 1 }) }.problem).to start_with("The volume at #{volume} has 1 byte free")
      expect_refused(altered, "#{altered.basename} doesn't match its checksum; it was changed or damaged after it was made.", "Use another copy of the backup.")
    end

    it "refuses a file the user can't read and a volume it can't write, naming the fix and changing nothing (plan-review M3)", :aggregate_failures do
      skip "root reads and writes anything" if Process.uid.zero?
      path = create_backup
      path.chmod(0o000)

      expect_refused(path, "#{path} can't be read by the user Collector runs as (uid #{Process.uid}).",
        "Give it to that user (chown 1000:1000), as the README's restore steps do, then run this again. Nothing was changed.")

      path.chmod(0o600)
      volume.chmod(0o500)

      expect_refused(path, "The volume at #{volume} isn't writable by the user Collector runs as (uid #{Process.uid}).",
        "Give the volume to that user (chown 1000:1000), then run this again. Nothing was changed.")
    end
  end

  describe "a wrong or damaged file (AC-3.1 to AC-3.7)" do
    let(:path) { create_backup }

    it "refuses a file cut short, and a .partial file, as incomplete (AC-3.1)", :aggregate_failures do
      cut = scratch("cut").join(path.basename).tap { it.binwrite(path.binread[0...-100]) }
      partial = scratch("partial").join("#{path.basename}.0123456789abcdef.partial").tap { FileUtils.cp(path, it) }

      [ cut, partial ].each do |file|
        expect_refused(file, "#{file.basename} is incomplete; it was cut short or is still being written.", "Take the backup again, or copy it again.")
      end
    end

    it "refuses a changed snapshot on its checksum (AC-3.2)" do
      original = unpack_snapshot(path)
      manifest = manifest_for(original)
      changed = scratch_path("changed.sqlite3").tap { it.binwrite(original.binread.tap { |bytes| bytes.setbyte(bytes.bytesize - 1, bytes.getbyte(bytes.bytesize - 1) ^ 1) }) }
      altered = scratch("altered").join("collector-backup-20261021T142100Z.tar.gz").tap { Collector::Backup::Archive.write(it, manifest:, snapshot: changed) }

      expect_refused(altered, "#{altered.basename} doesn't match its checksum; it was changed or damaged after it was made.", "Use another copy of the backup.")
    end

    it "refuses what isn't a backup, and a Collector export, saying so (AC-3.3)", :aggregate_failures do
      text = scratch_path("note.txt").tap { it.write("hello") }
      export = scratch_path("collector-export-2026-10-21.json").tap { it.write(CollectionExport.new(account: seed.user.account, at: Time.utc(2026, 10, 21)).to_json) }

      expect_refused(text, "#{text.basename} isn't a Collector backup.", "Give a collector-backup-….tar.gz file made by backup:create.")
      expect(expect_refused(export, "#{export.basename} is a Collector export file, not a backup.").advice).to include("Import collection")
    end

    it "refuses an unknown backup format version, naming the ones it restores (AC-3.4)" do
      future = raw_archive([ "manifest.json", JSON.generate("backup_format_version" => 2) ], [ "primary.sqlite3", "x" ], name: "v2.tar.gz")

      expect_refused(future, "v2.tar.gz uses backup format version 2; this release restores version 1.", "Restore it with a release that knows that version.")
    end

    it "refuses a newer release's backup, naming both schema versions (AC-3.5)" do
      newer = copy_of_instance("newer.sqlite3").tap { |copy| sqlite(copy) { |database| database.execute("INSERT INTO schema_migrations (version) VALUES ('29991231235959')") } }
      archive = archive_of(newer)

      expect_refused(archive, "#{archive.basename} was taken by a newer release of Collector (schema version 29991231235959; this release has #{release_versions.max_by(&:to_i)}).",
        "Restore it onto that release or a newer one.")
    end

    it "refuses a snapshot with an unreadable page, and one with an orphan row, as damaged (AC-3.7)", :aggregate_failures do
      damaged = copy_of_instance("damaged.sqlite3").tap { damage_table!(it, "lots") }
      orphaned = copy_of_instance("orphaned.sqlite3")
      sqlite(orphaned) do |database|
        database.execute("PRAGMA foreign_keys = OFF")
        database.execute("INSERT INTO lots (account_id, catalog_entry_id, quantity, lot_key, created_at, updated_at) VALUES (999, 999, 1, 'k', '2026-10-21 14:21:00', '2026-10-21 14:21:00')")
      end
      zero = { "accounts" => 0, "users" => 0, "lots" => 0 }

      [ archive_of(damaged, into: scratch("a"), counts: zero), archive_of(orphaned, into: scratch("b")) ].each do |archive|
        expect_refused(archive, "The database inside #{archive.basename} is damaged.", "Use another copy of the backup.")
      end
    end

    it "refuses a snapshot whose counts differ from its manifest's" do
      archive = archive_of(copy_of_instance("counts.sqlite3"), counts: { "accounts" => 5, "users" => 5, "lots" => 5 })

      expect_refused(archive, "The restored database doesn't match the backup's counts.", "Use another copy of the backup.")
    end
  end
end
```

`spec/tasks/backup_restore_rake_spec.rb`:

```ruby
require "rails_helper"
require "rake"

RSpec.describe "backup:restore", :backup, :committed, type: :task do
  let(:volume) { scratch("volume") }
  let!(:seed) { seed_instance }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("backup:restore")
    allow(Collector::Backup::Databases).to receive(:configured).and_return(databases_for(volume))
  end

  def run_task(*arguments)
    Rake::Task["backup:restore"].reenable
    captured_streams { Rake::Task["backup:restore"].invoke(*arguments) }
  end

  it "restores onto the configured volume, prints the facts and exits 0 (AC-2.1)", :aggregate_failures do
    path = create_backup
    out, err, status = run_task(path.to_s)

    expect([ status, err ]).to eq([ 0, "" ])
    expect(out).to include("Restored #{path.basename} into #{volume}.", "it holds 1 account, 1 user and 3 lots.", "Start Collector now")
    expect(volume.join("production.sqlite3")).to exist
  end

  it "prints no recognisable name, address or card, and logs none (AC-1.7)", :aggregate_failures do
    path = create_backup
    out = err = nil
    log = captured_log { out, err, = run_task(path.to_s) }

    seed.values.each do |value|
      expect(out).not_to include(value)
      expect(err).not_to include(value)
      expect(log).not_to include(value)
    end
  end

  it "prints each refusal as two lines, exits 1 and prints nothing else (AC-3.8)", :aggregate_failures do
    path = create_backup
    volume.join("production.sqlite3").write("in the way")
    out, err, status = run_task(path.to_s)

    expect([ out, status ]).to eq([ "", 1 ])
    expect(err.lines(chomp: true).first).to eq("The volume at #{volume} isn't empty: it holds production.sqlite3.")
    expect(err.lines.size).to eq(2)
    volume.join("production.sqlite3").delete

    text = scratch_path("note.txt").tap { it.write("hello") }
    out, err, status = run_task(text.to_s)
    expect([ out, status, err.lines.size ]).to eq([ "", 1, 2 ])
    expect(err).not_to match(/Refusal|Collector::|\.rb:\d+/)
  end

  it "says what to do when no file is given, and refuses an argument with a comma", :aggregate_failures do
    _out, err, status = run_task
    expect([ status, err.lines(chomp: true) ]).to eq([ 1, [ "No file was given.", %(Run: bin/rails "backup:restore[/path/to/collector-backup.tar.gz]".) ] ])
    expect(run_task("/a", "b")[2]).to eq(1)
  end
end
```

- [ ] **Step 4.2: Run and see them fail.** `bin/rspec spec/lib/collector/backup/restore_spec.rb spec/tasks/backup_restore_rake_spec.rb` — expect `uninitialized constant Collector::Backup::Restore` and an unknown task.

- [ ] **Step 4.3: Write `Restore`.** `lib/collector/backup/restore.rb`:

```ruby
module Collector
  module Backup
    # backup:restore (spec 030 FR-2, FR-3, FR-8, decisions 3, 6, 7, 10): places a verified snapshot as the primary database
    # of a fresh volume. Everything before the final rename is read-only on the volume except one temporary file and its
    # journal; the primary's path is never opened, because opening it would create the empty database that the next
    # db:prepare takes for a blank instance (research.md 2). Nothing is migrated here: the first boot's db:prepare does it.
    class Restore
      TEMPORARY = "collector-restore.partial".freeze
      MARGIN = 16 * 1024 * 1024 # room for the delete's journal and the rename, beyond the snapshot's own size

      Result = Data.define(:file, :volume, :manifest) do
        def report
          counts = manifest.counts
          lines = [ "Restored #{File.basename(file)} into #{volume}.",
            "Taken #{manifest.taken_at} at schema version #{manifest.schema_version}; it holds #{Backup.counts_phrase(counts)}. " \
              "Compare these with what you expect before you start Collector." ]
          lines << "The backup holds no users: the first person to reach the restored instance becomes its admin." if counts.fetch("users").zero?
          lines << "Everyone signs in again, and pending bulk-removal Undos and selections are gone; no collection is lost."
          lines << "Start Collector now. With art matching on, press Build art index on the admin catalog page to rebuild the scanner's art index."
          lines.join("\n")
        end
      end

      def initialize(file:, databases: Databases.configured, release_versions: Backup.release_schema_versions,
        free_space: FreeSpace.method(:bytes), checkpoint: ->(_step) {})
        @file = Pathname(file.to_s)
        @databases = databases
        @release_versions = release_versions
        @free_space = free_space
        @checkpoint = checkpoint
      end

      def call
        volume = @databases.directory
        raise Refusal.new("The storage directory #{volume} doesn't exist.", "Mount the volume where Collector expects it, then run this again.") unless volume.directory?

        refuse_unless_fresh
        raise Refusal.new("There is no file at #{@file}.", "Check the path as the container sees it; copy the backup in first.") unless @file.file?

        # docker cp makes root-owned files and the backup is 0600 (decision 4): a file or a volume the user can't use is the
        # slip to expect, so it is named here and not left to an Errno::EACCES (plan-review M3).
        raise unreadable unless @file.readable?
        raise unwritable(volume) unless volume.writable? && volume.executable?

        # The kind, completeness and version, then the room as soon as the manifest is read (FR-2 lists it before the
        # checksum, which the same pass computes), then the checksum: all decided before anything is written.
        read = Archive.read(@file, on_manifest: ->(manifest) { refuse_without_room(volume, manifest) })
        temporary = volume.join(TEMPORARY)
        Backup.remove(temporary) # a stopped run's leftover and its journal (FR-6)
        placed = false
        begin
          extract(temporary, read.manifest)
          prepare(temporary, read.manifest)
          @checkpoint.call(:snapshot_ready)
          Backup.publish(temporary, @databases.primary) { raise not_fresh }
          placed = true
          Backup.fsync_directory(volume)
          Result.new(file: @file, volume:, manifest: read.manifest)
        ensure
          Backup.remove(temporary) unless placed
        end
      rescue SQLite3::FullException, Errno::ENOSPC
        raise Refusal.new("The volume filled up while the backup was restored.", "Free some space or use a larger volume, then run this again. Nothing was changed.")
      end

      private
        def refuse_unless_fresh
          raise not_fresh if @databases.occupied.any?
        end

        def unreadable
          Refusal.new("#{@file} can't be read by the user Collector runs as (uid #{Process.uid}).",
            "Give it to that user (chown 1000:1000), as the README's restore steps do, then run this again. Nothing was changed.")
        end

        def unwritable(volume)
          Refusal.new("The volume at #{volume} isn't writable by the user Collector runs as (uid #{Process.uid}).",
            "Give the volume to that user (chown 1000:1000), then run this again. Nothing was changed.")
        end

        def not_fresh
          Refusal.new("The volume at #{@databases.directory} isn't empty: it holds #{@databases.occupied.map { it.basename.to_s }.join(", ")}.",
            "Restore onto a new, empty volume and start Collector on that. Nothing was changed.")
        end

        def refuse_without_room(volume, manifest)
          need = manifest.snapshot_bytes + MARGIN
          free = @free_space.call(volume)
          return unless free && free < need

          raise Refusal.new("The volume at #{volume} has #{Backup.size_phrase(free)} free; the snapshot needs #{Backup.size_phrase(need)}.",
            "Free some space or use a larger volume.")
        end

        # The second pass over the archive: the snapshot's bytes go to the temporary file, created private (decision 7).
        def extract(temporary, manifest)
          file = Backup.create_private(temporary)
          Archive.read(@file) { file.write(it) }
          file.flush
          file.fsync
          raise damaged_inside unless temporary.size == manifest.snapshot_bytes
        ensure
          file&.close
        end

        # FR-2's checks in order, then ending sessions, rollback-journal mode, and agreement with the manifest.
        def prepare(temporary, manifest)
          snapshot = Snapshot.new(temporary)
          snapshot.verify!
          check_schema(snapshot)
          snapshot.end_sessions!
          snapshot.rollback_journal!
          snapshot.verify! # the clearing leaves no foreign-key violation (AC-2.1)
          raise Refusal.new("The restored database doesn't match the backup's counts.", "Use another copy of the backup.") unless snapshot.counts == manifest.counts

          Backup.fsync_file(temporary)
        rescue Snapshot::Damaged, Snapshot::OrphanRows
          raise damaged_inside
        end

        def check_schema(snapshot)
          versions = snapshot.schema_versions
          raise Snapshot::Damaged, "no migrations" if versions.empty?
          return if (versions - @release_versions).empty?

          raise Refusal.new("#{@file.basename} was taken by a newer release of Collector (schema version #{versions.max_by(&:to_i)}; this release has #{@release_versions.max_by(&:to_i)}).",
            "Restore it onto that release or a newer one.")
        end

        def damaged_inside
          Refusal.new("The database inside #{@file.basename} is damaged.", "Use another copy of the backup.")
        end
    end
  end
end
```

Add `require_relative "backup/restore"` to `lib/collector/backup.rb`. Add to `lib/tasks/backup.rake`, inside `namespace :backup`:

```ruby
  desc %(Restore a backup onto a fresh volume, before Collector's first start: bin/rails "backup:restore[/backups/collector-backup-20261021T142100Z.tar.gz]")
  task :restore, [ :file ] do |_task, args|
    Collector::Backup.run do
      file = Collector::Backup.argument(args, :file, 'bin/rails "backup:restore[/path/to/collector-backup.tar.gz]"')
      puts Collector::Backup::Restore.new(file:).call.report
    end
  end
```

- [ ] **Step 4.4: Run.** `bin/rspec spec/lib/collector/backup spec/tasks/backup_create_rake_spec.rb spec/tasks/backup_restore_rake_spec.rb` — expect pass. Then `bin/rspec`, `bin/rubocop`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` — clean.

- [ ] **Step 4.5: Trace FR-8 by reading** and record it in `verification.md`: `git grep -n "Database.new\|establish_connection\|ActiveRecord::Base" lib/collector/backup lib/tasks/backup.rake ':!.kamal/secrets'` shows `SQLite3::Database.new` only in `snapshot.rb` (two calls, each given a snapshot's or a source's path, never `@databases.primary`) and no `ActiveRecord::Base` or `establish_connection` in the library (`ActiveRecord::DatabaseConfigurations` in `databases.rb` only builds configuration objects).

- [ ] **Step 4.6: Commit** `feat(backup): add backup:restore` (the library file, the task, the specs, `lib/collector/backup.rb`).

**Phase 4 verification:** `bin/rspec` green; every refusal of [contracts/tasks.md](contracts/tasks.md) has an example whose volume checksums are unchanged and whose two sentences pass the plain-message check.

---

## Phase 5: The app on a restored file, the upgrade path, the boot, and the last guards

**Implements:** decision 10 (the first boot migrates), decision 12 (art index after a restore), decision 4's D4 ruling (no secret), FR-5, AC-6.2 | **Satisfies:** AC-2.2, AC-2.4, AC-2.8, AC-2.9, AC-2.10, AC-3.6, AC-6.2, and the D4 boot test (research.md 1)

**Goal:** what a collector or an admin meets on an instance started from a restored file is proven in the suite: the sign-in, the lots, the export, the old cookie, the interrupted refresh, the missing import file, the art index; an older backup migrates on first start with every row kept; the tasks need no secret; no page, route or controller is named for a backup.

**Files:**
- Edit: `spec/support/backup_helpers.rb` (`with_restored_instance`), `spec/backup_guards_spec.rb`
- Create: `spec/backup_restored_instance_spec.rb`, `spec/backup_restored_catalog_spec.rb`, `spec/backup_restored_art_spec.rb`, `spec/backup_upgrade_spec.rb`, `spec/backup_boot_spec.rb`
- No application code changes: this phase proves behaviour the earlier phases and the existing app already have. If an example fails, the failure is a finding about the app or the restore (read `.claude/rules` and fix in the owning file with its own test), not a reason to bend the example.

**Interfaces:** `with_restored_instance(path) { }` (spec helper): Active Record points at the file for the block, then back at the test database. `app_command(database, *command, environment: {})` (Phase 0): a child `bin/rails` on a database file.

- [ ] **Step 5.1: Add the helper** to `BackupHelpers`:

```ruby
  # Points Active Record at a restored file for the block, as an instance started on that volume would be, then back at the
  # test database. Requests made in the block meet that file's rows only (AC-2.2, AC-2.4, AC-2.8 to AC-2.10).
  def with_restored_instance(path)
    original = ActiveRecord::Base.connection_db_config
    ActiveRecord::Base.connection_pool.disconnect!
    ActiveRecord::Base.establish_connection(original.configuration_hash.merge(database: path.to_s))
    yield
  ensure
    ActiveRecord::Base.connection_pool.disconnect!
    ActiveRecord::Base.establish_connection(original)
  end
```

- [ ] **Step 5.2: Write the failing specs.**

`spec/backup_restored_instance_spec.rb` (AC-2.2, AC-2.4):

```ruby
require "rails_helper"

RSpec.describe "an instance started from a restored backup", :backup, :committed, type: :request do
  let!(:seed) { seed_instance }
  let(:user) { seed.user }
  let(:volume) { scratch("volume") }
  let(:restored) { volume.join("production.sqlite3") }

  it "signs the collector in with their password, shows their lots and exports the same collection (AC-2.2)", :aggregate_failures do
    before_export = JSON.parse(CollectionExport.new(account: user.account, at: Time.utc(2026, 10, 21, 12)).to_json)
    restore_backup(create_backup, volume:)
    _output, error, status = app_command(restored, "db:prepare") # the entrypoint's command, on the restored file
    expect(status).to be_success, error

    with_restored_instance(restored) do
      sign_in_as(user)
      get "/collection"
      expect(response).to have_http_status(:ok)
      seed.entries.each { |entry| expect(response.body).to include(entry.name) }
      get "/collection/export"
      expect(ExportFormatRules.same_collection?(before_export, JSON.parse(response.body))).to be(true)
    end
  end

  it "ends every session: the old cookie is sent to sign in, and the password works (AC-2.4)", :aggregate_failures do
    sign_in_as(user) # a session row, and its cookie in this integration session
    expect(table_rows(instance_database).fetch("sessions")).not_to be_empty
    restore_backup(create_backup, volume:)

    expect(table_rows(restored).fetch("sessions")).to be_empty
    with_restored_instance(restored) do
      expect(Session.count).to eq(0)
      get "/collection"
      expect(response).to redirect_to(new_session_path)
      post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }
      get "/collection"
      expect(response).to have_http_status(:ok)
    end
  end
end
```

`spec/backup_restored_catalog_spec.rb` (AC-2.9, AC-2.10):

```ruby
require "rails_helper"

RSpec.describe "a restored instance's catalog page and stored import", :backup, :committed, :solid_queue, type: :request do
  let!(:admin) { create(:admin) }
  let(:volume) { scratch("volume") }
  let(:restored) { volume.join("production.sqlite3") }

  def page = Nokogiri::HTML5(response.body)

  it "reads a refresh recorded as running as interrupted, and lets a refresh start (AC-2.9)", :aggregate_failures do
    create(:catalog_refresh_run, :running, stage: "sync", started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago, job_id: "job-1")
    restore_backup(create_backup, volume:)

    with_restored_instance(restored) do
      SolidQueueHelpers.load_tables # the queue's tables are part of the test database, and a fresh instance has its own
      sign_in_as(admin)
      get admin_catalog_path
      expect(page.at_css("#mtg_refresh .c-operation__summary").text.squish).to eq("Interrupted while syncing cards.")
      expect(page.at_css("#mtg_refresh button")["disabled"]).to be_nil
      post admin_catalog_operation_starts_path, params: { collectible_type: "mtg", operation: "refresh" }
      expect(response).to redirect_to(admin_catalog_path)
      expect(SolidQueue::Job.where(class_name: "Catalog::RefreshJob").count).to eq(1)
    end
  end

  it "answers 'Preview the file again.' for an upload whose file isn't there, and the sweep removes its row (AC-2.10)", :aggregate_failures do
    entry = import_printing
    upload = store_import!(account: admin.account, data: import_file(admin, [ import_row(entry) ]))
    path = create_backup
    ActiveStorage::Blob.service.delete(upload.file.blob.key) # the backup holds the database only
    restore_backup(path, volume:)

    with_restored_instance(restored) do
      sign_in_as(admin)
      post collection_import_path, params: { fingerprint: ImportUpload.sole.fingerprint, confirm_removal: "1" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Preview the file again.")
      expect(Lot.count).to eq(0)
      travel_to(2.hours.from_now) { ImportUpload.sweep! }
      expect(ImportUpload.count).to eq(0)
    end
  end
end
```

`spec/backup_restored_art_spec.rb` (AC-2.8; modelled on `spec/models/mtg/art/build_spec.rb`, which needs ImageMagick as the art specs already do):

```ruby
require "rails_helper"

RSpec.describe "art matching after a restore", :backup, :committed, :art_matching, type: :model do
  let(:art) { "aaaaaaaa-0000-4000-8000-000000000001" }
  let(:image) { "https://cards.scryfall.io/small/front/a/b/#{art}.jpg" }
  let(:client) { MTG::Scryfall::Client.new(sleeper: ->(_seconds) {}, clock: -> { 0.0 }) }
  let(:volume) { scratch("volume") }

  before do
    create(:catalog_refresh_run, collectible_type: "mtg", source_version: "default-cards-1")
    create(:mtg_printing, illustration_id: art, faces: [ { "name" => "Lightning Bolt", "image_uris" => { "small" => image } } ],
      entry: create(:catalog_entry, released_on: Date.new(2005, 1, 1)))
    stub_request(:get, image).to_return(body: noisy_png)
  end

  it "offers text recognition only until Build art index is pressed, which then needs no request (AC-2.8)", :aggregate_failures do
    MTG::Art::Build.new(job_id: "before", client:).call # fingerprints the artwork and writes the index
    expect(MTG::Art.page_config).to be_present
    path = create_backup
    FileUtils.rm_rf(MTG::Art.root) # the volume it is restored onto has no index file and no image
    restore_backup(path, volume:)

    with_restored_instance(volume.join("production.sqlite3")) do
      expect(MTG::Art.page_config).to be_nil
      WebMock.reset! # no stub is left: a request would raise, and would be counted
      run = MTG::Art::Build.new(job_id: "after", client:).call

      expect(run).to have_attributes(status: "finished", fetched_count: 0, indexed_count: 1)
      expect(a_request(:any, /.*/)).not_to have_been_made
      expect(MTG::Art.page_config).to include(name: a_string_starting_with("art-index-"))
    end
  end
end
```

`spec/backup_upgrade_spec.rb` (AC-3.6). The older snapshot is the seeded instance's, with the release's newest migration rolled back in a child process (every migration is reversible by rule); `SCHEMA` keeps the child from rewriting `db/schema.rb`, and the example checks it didn't:

```ruby
require "rails_helper"

RSpec.describe "restoring a backup from an older release (AC-3.6)", :backup, :committed do
  let!(:seed) { seed_instance }
  let(:volume) { scratch("volume") }

  it "restores it as it is, and the first start migrates it with every row kept", :aggregate_failures do
    schema_before = Digest::SHA256.file(Rails.root.join("db/schema.rb")).hexdigest
    older = unpack_snapshot(create_backup, "older.sqlite3")
    _output, error, status = app_command(older, "db:rollback", "STEP=1")
    expect(status).to be_success, "the newest migration must be reversible (.claude/rules/sqlite-and-migrations.md): #{error}"
    older_versions = Collector::Backup::Snapshot.new(older).schema_versions
    expect(older_versions.size).to eq(release_versions.size - 1)

    restore_backup(archive_of(older, schema_version: older_versions.max_by(&:to_i)), volume:)
    restored = volume.join("production.sqlite3")
    expect(Collector::Backup::Snapshot.new(restored).schema_versions).to match_array(older_versions) # the restore ran no migration

    _output, error, status = app_command(restored, "db:prepare")
    expect(status).to be_success, error
    snapshot = Collector::Backup::Snapshot.new(restored)
    expect(snapshot.schema_versions).to match_array(release_versions)
    expect(snapshot.counts).to eq("accounts" => 1, "users" => 1, "lots" => 3) # nothing was lost, and schema:load would have emptied it
    expect(Digest::SHA256.file(Rails.root.join("db/schema.rb")).hexdigest).to eq(schema_before)
  end
end
```

`spec/backup_boot_spec.rb` (the D4 ruling; research.md 1). The children are production processes: `DATABASE_URL` points any connection at a scratch file, and the examples assert that no file appeared in `storage/`. Two kinds of child, because a wrong `RAILS_MASTER_KEY` is safe for the tasks (they read no credentials) but breaks every production *boot*: `config/storage.yml` holds ERB inside YAML comments (lines 12-13, `Rails.application.credentials.dig(:aws, …)`), `ActiveSupport::ConfigurationFile#parse` renders any file that contains `<%` (`configuration_file.rb:21`) when Active Storage's blob loads at eager load, and `EncryptedConfiguration#read` rescues only `MissingContentError`, so a wrong key raises `InvalidMessage` before `secret_key_base` is ever read (plan-review M1). The boot examples therefore run with **no** key and are skipped where a developer's `config/master.key` exists (testing that the file exists reads nothing); CI and the image have none:

```ruby
require "rails_helper"
require "rake"

RSpec.describe "the tasks need no secret (spec 030 decision 4, research.md 1)", :backup, type: :task do
  # No SECRET_KEY_BASE, no dummy. The tasks read no credentials, so a wrong master key is harmless to them and keeps a
  # developer's real config/master.key from supplying a secret_key_base. A boot is different: see boot below.
  def production(*command, environment: {})
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE" => nil, "SECRET_KEY_BASE_DUMMY" => nil, "RAILS_MASTER_KEY" => "0" * 32,
      "DATABASE_URL" => "sqlite3:#{scratch_path("boot.sqlite3")}" }.merge(environment)
    Open3.capture3(env, Rails.root.join("bin/rails").to_s, *command, chdir: Rails.root.to_s)
  end

  # A production boot with no master key at all: credentials come back empty (EncryptedFile#read raises
  # MissingContentError, which EncryptedConfiguration rescues), as in the image, which has no key file.
  def boot(*command, environment: {})
    skip "config/master.key exists on this machine; the boot examples need an environment without a key (CI has none)" if Rails.root.join("config/master.key").exist?

    production(*command, environment: { "RAILS_MASTER_KEY" => nil }.merge(environment))
  end

  def storage_files = Dir[Rails.root.join("storage/production*").to_s].sort

  it "gives neither task a dependency on :environment, so neither initializes the application (the structural guarantee)", :aggregate_failures do
    Rails.application.load_tasks unless Rake::Task.task_defined?("backup:create")

    %w[backup:create backup:restore].each do |name|
      expect(Rake::Task[name].all_prerequisite_tasks.map(&:name)).not_to include("environment"), name
    end
  end

  it "runs backup:restore in production and answers its own refusal, without a secret", :aggregate_failures do
    before = storage_files
    out, err, status = production("backup:restore")

    expect(status.exitstatus).to eq(1)
    expect(out).to be_empty
    expect(err.lines(chomp: true)).to eq([ "No file was given.", %(Run: bin/rails "backup:restore[/path/to/collector-backup.tar.gz]".) ])
    expect(storage_files).to eq(before)
  end

  it "runs backup:create in production the same way", :aggregate_failures do
    out, err, status = production("backup:create")

    expect([ status.exitstatus, out ]).to eq([ 1, "" ])
    expect(err.lines.first).to eq("No directory was given.\n")
  end

  it "would fail if they booted the application, which reads secret_key_base eagerly (the control)", :aggregate_failures do
    before = storage_files
    _out, err, status = boot("runner", "puts :booted")

    expect(status.exitstatus).not_to eq(0)
    expect(err).to match(/secret_key_base/) # not a credentials error: that would prove nothing about the secret
    expect(storage_files).to eq(before)
  end

  it "boots with the dummy, which is enough, as the documented one-off passes it", :aggregate_failures do
    before = storage_files
    out, err, status = boot("runner", "puts :booted", environment: { "SECRET_KEY_BASE_DUMMY" => "1" })

    expect(status).to be_success, err
    expect(out).to include("booted")
    expect(storage_files).to eq(before)
  end
end
```

Add to `spec/backup_guards_spec.rb` (AC-6.2 and FR-5):

```ruby
  it "has no route, controller or view named for a backup, and no route runs the tasks (AC-6.2)", :aggregate_failures do
    routes = Rails.application.routes.routes.map { |route| [ route.path.spec.to_s, route.defaults[:controller], route.defaults[:action], route.name ].join(" ") }

    expect(routes.grep(/backup/i)).to be_empty
    expect(Dir[Rails.root.join("app/{controllers,views}/**/*backup*").to_s]).to be_empty
  end

  it "keeps core code free of any collectible: the backup's files name neither MTG nor Scryfall (FR-5)", :aggregate_failures do
    files = Dir[Rails.root.join("lib/collector/backup.rb").to_s, Rails.root.join("lib/collector/backup/*.rb").to_s, Rails.root.join("lib/tasks/backup.rake").to_s]

    expect(files.size).to eq(10)
    expect(files.select { File.read(it).match?(/MTG|Scryfall/) }).to be_empty
  end
```

- [ ] **Step 5.3: Run.** `bin/rspec spec/backup_restored_instance_spec.rb spec/backup_restored_catalog_spec.rb spec/backup_restored_art_spec.rb spec/backup_upgrade_spec.rb spec/backup_boot_spec.rb spec/backup_guards_spec.rb` — the first run is the first run of these examples; the ones that fail show something about the app that the plan couldn't read without running (for example the exact text on the collection page, or a model validation in `seed_session`). Fix the example only where the plan's wording of an existing behaviour is wrong; fix the restore only where it is. Expect after that: all pass, the boot examples taking a few seconds each.

- [ ] **Step 5.4: Run everything.** `bin/rspec` — 0 failures, in random order, twice with different seeds (the examples commit rows and switch connections, so this is the order-dependence check); `bin/rubocop`; `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.

- [ ] **Step 5.5: Commit** `test(backup): prove the restored instance, the upgrade, the boot and the guards` (stage the six spec files and the helper).

**Phase 5 verification:** AC-2.2, AC-2.4, AC-2.8, AC-2.9, AC-2.10, AC-3.6 and AC-6.2 each have a passing example; the boot examples answer D4: with `SECRET_KEY_BASE_DUMMY` the application boots, without a secret it doesn't, and the tasks run in production with neither and depend on no `:environment`. On a machine with a `config/master.key` the two boot examples are skipped; `verification.md` records the CI run where they ran (or the run in an environment without a key). Those two examples first run in the first CI run, after Phase 6; an unexpected result there (the control not failing on `secret_key_base`, the dummy not booting) is a reason to reopen research.md 8's row for the control boot, not to loosen the example.

---

## Phase 6: `bin/backup-smoke`, the CI step and the Kamal alias

**Implements:** decision 9 layer 2, decision 4 (the two copy-in ways, the Kamal one-off's container command), FR-9 | **Satisfies:** AC-5.2, AC-5.3, AC-2.3, AC-4.2 (by the script, first proved by CI), FR-9

**Goal:** the two tasks, run the way the documents tell an operator to run them, are proven against the image CI built, on both architectures: a backup of a running container, restored into a second container with another secret, then started.

**Files:**
- Create: `bin/backup-smoke` (mode 0755)
- Edit: `.github/workflows/ci.yml`, `config/deploy.yml`, `.dockerignore`, `bin/image-smoke`, `spec/image_publishing_spec.rb`

**Interfaces:** `bin/backup-smoke <image> [<restore-image>] [-- extra run flags]`; env `CONTAINER_CLI`, `SMOKE_BOOT_ATTEMPTS` as `bin/image-smoke`. With a second image the backup is taken from the first and restored into the second (issue #42 reuses it with the previous release as the first).

- [ ] **Step 6.1: Write the failing examples** in `spec/image_publishing_spec.rb`. In `describe ".dockerignore"` add:

```ruby
    it "keeps the backup smoke script out of the image, and the image smoke test checks it (spec 030 FR-9)", :aggregate_failures do
      expect(rules).to include("/bin/backup-smoke")
      expect(Rails.root.join("bin/image-smoke").read).to include("bin/backup-smoke")
    end
```

In `describe "config/deploy.yml"` add:

```ruby
    it "has a backup alias and offers the backup directory as a commented-out volume (spec 030 decision 4)", :aggregate_failures do
      expect(deploy.dig("aliases", "backup")).to eq(%(app exec --reuse "bin/rails 'backup:create[/backups]'"))
      expect(deploy["volumes"]).to eq([ "collector_storage:/rails/storage" ])
      expect(Rails.root.join("config/deploy.yml").read).to include('# - "/srv/collector-backups:/backups"')
    end
```

In `describe ".github/workflows/ci.yml"` add:

```ruby
    it "runs bin/backup-smoke after bin/image-smoke and before the push, on each architecture (spec 030 AC-5.3)", :aggregate_failures do
      names = steps.map { |candidate| candidate["id"] || candidate["name"] }
      backup = steps.find { |candidate| candidate["run"] == "bin/backup-smoke collector:smoke" }

      expect(backup).to be_present
      expect(names.index(backup["name"])).to be_between(names.index("Smoke test"), names.index("push")).exclusive
      expect(image_job.dig("strategy", "matrix", "include").size).to eq(2)
    end
```

Run `bin/rspec spec/image_publishing_spec.rb` — expect the three new examples to fail.

- [ ] **Step 6.2: Write `bin/backup-smoke`.**

```bash
#!/usr/bin/env bash
# Smoke-tests backup and restore against a built Collector image (spec 030, AC-5.2): boots a container with a volume,
# seeds a catalog entry, an admin and a lot, backs it up while polling /up, throws the container and its volume away,
# restores the file into a new volume the two documented ways (README, "Backup and restore"), and starts a second
# container with a different SECRET_KEY_BASE: the databases are as a fresh instance's but the collection, the admin's
# password works, a session cookie from the first instance doesn't (AC-2.3, AC-4.2).
#
#   bin/backup-smoke <image> [<restore-image>] [-- extra `run` flags, e.g. --platform linux/arm64]
#
# With a <restore-image> the backup is taken from <image> and restored into <restore-image> (issue #42 reuses this with the
# previous release as <image>). Uses docker when present, else podman (override with CONTAINER_CLI). Exit status 0 means
# every check passed; a failure names its step.
set -euo pipefail

image="${1:?usage: bin/backup-smoke <image> [<restore-image>] [-- run flags]}"
shift
restore_image="$image"
if [ $# -gt 0 ] && [ "$1" != "--" ]; then restore_image="$1"; shift; fi
if [ "${1:-}" = "--" ]; then shift; fi
run_flags=("$@")
cli="${CONTAINER_CLI:-$(command -v docker >/dev/null 2>&1 && echo docker || echo podman)}"
attempts="${SMOKE_BOOT_ATTEMPTS:-60}" # 2 s each; raise it for emulated runs
work="$(mktemp -d)"
tag="$$"
password="smoke-password-1234"
containers=()
volumes=()

cleanup() {
  for container in ${containers[@]+"${containers[@]}"}; do "$cli" rm -f "$container" >/dev/null 2>&1 || true; done
  for volume in ${volumes[@]+"${volumes[@]}"}; do "$cli" volume rm -f "$volume" >/dev/null 2>&1 || true; done
  # What the container's user (uid 1000) made can't be removed by the invoking user: remove it as root, in a one-off.
  "$cli" run --rm -u 0 -v "$work:/work" "$image" rm -rf /work/backups /work/restore >/dev/null 2>&1 || true
  rm -rf "$work" 2>/dev/null || true
}
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
status() { curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$1$2"; }

# Makes a host directory belong to the container's user, as the documents' `chown 1000:1000` does; where the engine can't
# (rootless podman maps ids differently) it is made world-writable instead, which is all the smoke test needs.
own() { "$cli" run --rm -u 0 -v "$1:/dir" "$image" chown 1000:1000 /dir >/dev/null 2>&1 || chmod 0777 "$1"; }

# start <name> <volume> <secret> <image> [extra run args]: runs a container, sets PORT once /up answers 200.
start() {
  local name="$1" volume="$2" secret="$3" img="$4"
  shift 4
  containers+=("$name")
  "$cli" run -d --name "$name" ${run_flags[@]+"${run_flags[@]}"} -p 127.0.0.1::8080 -v "$volume:/rails/storage" "$@" \
    -e SECRET_KEY_BASE="$secret" -e HTTP_PORT=8080 -e SOLID_QUEUE_IN_PUMA=true "$img" >/dev/null
  PORT="$("$cli" port "$name" 8080 | head -n 1 | sed 's/.*://')"
  for _ in $(seq 1 "$attempts"); do
    [ "$(status "$PORT" /up)" = "200" ] && return 0
    sleep 2
  done
  "$cli" logs "$name" >&2
  fail "$name: /up did not answer 200 within $((attempts * 2)) s"
}

# sign_in <port> <cookie jar>: the sign-in form as a browser submits it, with its CSRF token.
sign_in() {
  local token code
  token="$(curl -s -c "$2" -b "$2" "http://127.0.0.1:$1/session/new" | sed -n 's/.*name="csrf-token" content="\([^"]*\)".*/\1/p' | head -n 1)"
  [ -n "$token" ] || return 1
  code="$(curl -s -o /dev/null -w '%{http_code}' -c "$2" -b "$2" --data-urlencode "authenticity_token=$token" \
    --data-urlencode "email_address=smoke@example.com" --data-urlencode "password=$password" "http://127.0.0.1:$1/session")"
  [ "$code" = "302" ] || [ "$code" = "303" ]
}

seed_ruby='
set = Catalog::Set.create!(collectible_type: "mtg", code: "smk", name: "Smoke Set", released_on: Date.new(2020, 1, 1), content_digest: "smoke")
identity = Catalog::Identity.create!(collectible_type: "mtg", external_key: "smoke-identity", name: "Smoke Dragon", content_digest: "smoke")
entry = Catalog::Entry.create!(collectible_type: "mtg", external_key: "smoke-entry", set: set, identity: identity, number: "1", language: "en", name: "Smoke Dragon", kind: "card", released_on: set.released_on, content_digest: "smoke")
MTG::Printing.create!(entry: entry, rarity: "common", finishes: %w[nonfoil foil], layout: "normal", scryfall_uri: "https://scryfall.com/card/smk/1", faces: [ { "name" => "Smoke Dragon", "mana_cost" => "{R}", "type_line" => "Creature", "oracle_text" => "Smoke.", "artist" => "Nobody", "image_uris" => {} } ])
user, = User::Command.call(email: "smoke@example.com", password: "smoke-password-1234")
Lot.create!(account: user.account, entry: entry, quantity: 2)
Catalog::RefreshJob.set(wait: 1.year).perform_later("mtg", "smoke-marker")
Rails.cache.write("smoke-marker", "1")
puts "seeded"
'

# What the queue and cache held before the backup must not be there after it (AC-2.3): a scheduled job with a marker
# argument, and a cache entry.
marker_ruby='puts [ SolidQueue::Job.where("arguments LIKE ?", "%smoke-marker%").count, Rails.cache.read("smoke-marker").inspect ].join(",")'

# The four databases exist, the marker job and cache entry are gone, the recurring tasks of config/recurring.yml are
# registered, and the collection came back (AC-2.3).
state_ruby='
require "yaml"
storage = Rails.root.join("storage")
files = %w[production production_cache production_queue production_cable].all? { |name| storage.join("#{name}.sqlite3").exist? }
expected = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production").keys.sort
puts [ files, SolidQueue::Job.where("arguments LIKE ?", "%smoke-marker%").count, Rails.cache.read("smoke-marker").inspect,
  SolidQueue::RecurringTask.pluck(:key).sort == expected, Lot.count, User.count ].join(",")
'

# verify_restored <container> <port> <label>: AC-2.3 and AC-4.2 on a started, restored instance.
verify_restored() {
  local name="$1" port="$2" label="$3" state=""
  for _ in $(seq 1 30); do # the scheduler registers the recurring tasks a few seconds after /up
    state="$("$cli" exec "$name" bin/rails runner "$state_ruby" 2>&1 | tail -n 1)" || true
    [ "$state" = "true,0,nil,true,1,1" ] && break
    sleep 2
  done
  [ "$state" = "true,0,nil,true,1,1" ] || fail "$label: the restored instance's databases weren't a fresh instance's with the collection (AC-2.3); got: $state"
  sign_in "$port" "$work/jar-$label" || fail "$label: the admin couldn't sign in with their password under a different SECRET_KEY_BASE (AC-4.2)"
  curl -s -b "$work/jar-$label" "http://127.0.0.1:$port/collection" | grep -q "Smoke Dragon" || fail "$label: the lot isn't on the collection page"
  [ "$(curl -s -o /dev/null -w '%{http_code}' -b "$work/jar-a" "http://127.0.0.1:$port/collection")" = "302" ] \
    || fail "$label: a session cookie from the first instance was accepted (AC-4.2)"
}

echo "== boot the first instance and seed it"
mkdir -p "$work/backups" "$work/out" "$work/restore"
own "$work/backups"
volume_a="collector-backup-smoke-a-$tag"
volumes+=("$volume_a")
start "backup-smoke-a-$tag" "$volume_a" "secret-of-the-first-instance-0001" "$image" -v "$work/backups:/backups"
a="backup-smoke-a-$tag"
port_a="$PORT"
seeded="$("$cli" exec "$a" bin/rails runner "$seed_ruby" 2>&1)" || fail "seeding exited $?:"$'\n'"$seeded"
grep -qx "seeded" <<<"$seeded" || fail "seeding didn't finish; it printed:"$'\n'"$seeded"
[ "$("$cli" exec "$a" bin/rails runner "$marker_ruby" 2>&1 | tail -n 1)" = '1,"1"' ] || fail "the marker job and cache entry weren't seeded"
sign_in "$port_a" "$work/jar-a" || fail "the admin couldn't sign in on the first instance"

echo "== back up while /up is polled (AC-5.2)"
( "$cli" exec "$a" bin/rails "backup:create[/backups]" >"$work/backup.out" 2>&1; echo $? >"$work/backup.status" ) &
background=$!
samples=0
while kill -0 "$background" 2>/dev/null; do
  [ "$(status "$port_a" /up)" = "200" ] || fail "/up stopped answering while the backup ran"
  samples=$((samples + 1))
  sleep 0.2
done
wait "$background" || true
[ "$(cat "$work/backup.status")" = "0" ] || fail "backup:create failed:"$'\n'"$(cat "$work/backup.out")"
[ "$samples" -ge 1 ] || fail "the backup finished before /up could be polled"
grep -q "^Backup written: /backups/collector-backup-" "$work/backup.out" || fail "backup:create didn't print its file:"$'\n'"$(cat "$work/backup.out")"
file="$("$cli" exec "$a" sh -c 'ls /backups')"
[ "$(wc -l <<<"$file" | tr -d ' ')" = "1" ] || fail "the backup directory should hold exactly one file; it holds: $file"
"$cli" cp "$a:/backups/$file" "$work/out/$file"
"$cli" rm -f "$a" >/dev/null
"$cli" volume rm -f "$volume_a" >/dev/null

echo "== restore from a host directory owned by uid 1000, mounted read-only, with SECRET_KEY_BASE_DUMMY (decision 4)"
own "$work/restore"
"$cli" run --rm -u 0 -v "$work/out:/in:ro" -v "$work/restore:/dest" "$image" \
  sh -c "cp /in/$file /dest/$file && chown 1000:1000 /dest/$file && chmod 0600 /dest/$file" >/dev/null || fail "placing the file in the host directory failed"
volume_b="collector-backup-smoke-b-$tag"
volumes+=("$volume_b")
"$cli" volume create "$volume_b" >/dev/null
restored="$("$cli" run --rm -u 1000 ${run_flags[@]+"${run_flags[@]}"} -v "$volume_b:/rails/storage" -v "$work/restore:/backups:ro" -e SECRET_KEY_BASE_DUMMY=1 \
  "$restore_image" bin/rails "backup:restore[/backups/$file]" 2>&1)" || fail "backup:restore (host directory) exited $?:"$'\n'"$restored"
grep -q "^Restored $file into /rails/storage\." <<<"$restored" || fail "backup:restore didn't say it restored; it printed:"$'\n'"$restored"
grep -q "it holds 1 account, 1 user and 1 lot\." <<<"$restored" || fail "backup:restore's counts are not the seeded instance's:"$'\n'"$restored"

echo "== start the second instance under a different SECRET_KEY_BASE (AC-2.3, AC-4.2)"
b="backup-smoke-b-$tag"
start "$b" "$volume_b" "a-different-secret-of-the-second-instance-0002" "$restore_image"
verify_restored "$b" "$PORT" b

echo "== restore the copied-in way: create, cp, a root chown one-off, and no secret at all (decision 4)"
volume_c="collector-backup-smoke-c-$tag"
volumes+=("$volume_c")
holder="backup-smoke-holder-$tag"
containers+=("$holder")
"$cli" create --name "$holder" -v "$volume_c:/rails/storage" "$restore_image" >/dev/null
"$cli" cp "$work/out/$file" "$holder:/rails/storage/$file"
"$cli" rm -f "$holder" >/dev/null
"$cli" run --rm -u 0 -v "$volume_c:/rails/storage" "$restore_image" chown 1000:1000 "/rails/storage/$file" >/dev/null || fail "the root chown one-off failed"
restored="$("$cli" run --rm -u 1000 ${run_flags[@]+"${run_flags[@]}"} -v "$volume_c:/rails/storage" "$restore_image" bin/rails "backup:restore[/rails/storage/$file]" 2>&1)" \
  || fail "backup:restore (copied in) exited $?:"$'\n'"$restored"
grep -q "^Restored $file into /rails/storage\." <<<"$restored" || fail "backup:restore (copied in) didn't say it restored:"$'\n'"$restored"
c="backup-smoke-c-$tag"
start "$c" "$volume_c" "a-third-secret-of-the-third-instance-000003" "$restore_image"
verify_restored "$c" "$PORT" c

echo "OK: ${image} was backed up and restored into ${restore_image} the documented ways"
```

The seed's lot count is 1 (one `Lot.create!`), so the restore's line reads "1 account, 1 user and 1 lot." as grepped.

- [ ] **Step 6.3: Make it executable and keep it out of the image.** `chmod +x bin/backup-smoke`. In `.dockerignore`, after `/bin/ghcr-cleanup`, add `/bin/backup-smoke`. In `bin/image-smoke`, the `for path in …` list gains `bin/backup-smoke` after `bin/ghcr-cleanup`.

- [ ] **Step 6.4: Add the CI step.** In `.github/workflows/ci.yml`, in the `image` job, after the `Smoke test` step and before `Push by digest`:

```yaml
      # Backs up a running container and restores the file into a second one under another secret, the ways the README
      # documents (spec 030, AC-5.2, AC-5.3).
      - name: Backup smoke test
        run: bin/backup-smoke collector:smoke
```

- [ ] **Step 6.5: Add the Kamal alias and the commented volume.** In `config/deploy.yml`, under `aliases:` after `catalog-status`: `  backup: app exec --reuse "bin/rails 'backup:create[/backups]'"`. Under `volumes:` after the named volume:

```yaml
  # Backups (spec 030, README "Backup and restore"): create the directory on the server first, owned by uid 1000
  # (sudo install -d -o 1000 -g 1000 /srv/collector-backups), then uncomment this line and deploy. It stays commented
  # because Docker creates a missing bind-mount source owned by root, which the container's user could not write to:
  # - "/srv/collector-backups:/backups"
```

- [ ] **Step 6.6: Run what can run here.** `bin/rspec spec/image_publishing_spec.rb` — the three new examples pass. `bash -n bin/backup-smoke` — expect no output (syntax). `bin/rspec`, `bin/rubocop` — clean. The script itself needs a container engine and a built image: it is proven by the first CI run on both architectures (AC-5.3's "first run") and, when an engine is at hand, by `bin/backup-smoke collector:local`. The plan's author did not run it. The assumptions its first run settles are in research.md 8 (`docker cp` out of a bind mount, `docker create` + `cp` + `chown`, the sign-in markup). Where a step fails for a reason of the engine, fix the script's step, never loosen a check.

- [ ] **Step 6.7: Commit** `test(backup): add bin/backup-smoke and run it in CI after the image smoke test` (stage the script, the workflow, `config/deploy.yml`, `.dockerignore`, `bin/image-smoke`, the spec). The pre-push hook runs `bin/ci`, which doesn't run the script: that is the first CI run's job.

**Phase 6 verification:** the workflow, `.dockerignore`, `config/deploy.yml` and the script's syntax are checked by `bin/rspec` and `bash -n`; the script's behaviour is checked by the first CI run (both architectures), recorded in `verification.md` with the run's URL.

---

## Phase 7: The documents

**Implements:** FR-7, FR-9 (the CLAUDE.md line), decisions 4, 8, 10, 11 | **Satisfies:** AC-5.1, AC-5.7, AC-6.1, AC-4.4

**Goal:** an operator who has never seen the spec can back up and restore Compose, Podman and Kamal instances from the README, can open a backup with `tar` and `sqlite3` from `docs/backup-restore.md`, and is told when to use the export instead; the maintainer's release check is a step in `docs/releasing.md`.

**Files:** `README.md`, `docs/backup-restore.md` (new), `docs/releasing.md`, `CLAUDE.md`, `docs/roadmap.md`, `.claude/rules/sqlite-and-migrations.md`. Prose documents are verified by reading, never by RSpec (`.claude/rules/testing.md`); `verification.md` records the reading, criterion by criterion. `docs/architecture/` gets no change: the release-and-deploy area doc is not written (spec 027 slice C, #109) and stays listed as such; `distill-feature` writes it at the end.

**Interfaces:** the README's anchor `#backup-and-restore` and `docs/backup-restore.md`'s anchor `#manual-recovery-with-tar-and-sqlite3`, each linked from the other document.

- [ ] **Step 7.1: The README's Compose and Kamal bullets and "Your data".**

In "Docker Compose", replace the Data bullet with:

```markdown
- **Data:** all four production SQLite databases live in the named volume
  `collector_storage`, mounted at `/rails/storage`. Back it up with Collector's own command, not by copying
  the files of a running instance: see [Backup and restore](#backup-and-restore).
```

In "Kamal", after "Data is stored in the `collector_storage` volume …" append: ` How to back it up and restore it is in [Backup and restore](#backup-and-restore).`

At the end of "Your data" (before "## License" and before the new section) append:

```markdown
A collector's export is not a backup of the instance, and a backup is not a collector's export: [Backup and restore](#backup-and-restore) says which to use for what and how to restore an instance.
```

- [ ] **Step 7.2: The README's new section**, after "Your data" and before "## License". Write it with these headings and exactly these commands (the container command lines are the ones `bin/backup-smoke` runs):

````markdown
## Backup and restore

Everything a collector owns, and the card catalog, is in one SQLite file on your instance's `storage/` volume. A **backup** is one file, made while Collector keeps running, that holds that file as it was at one moment: every account, user, lot and setting, and the catalog. A **restore** puts it onto a new, empty volume before Collector's first start. The backup is yours to keep wherever you like. Collector doesn't schedule, rotate or upload it.

### Export or backup?

| | Export (a collector, in the app) | Backup (you, the operator) |
|---|---|---|
| Whose | One collector's collection | The whole instance: every account, user and setting, and the catalog |
| Made by | The collector, from the account menu or More | The operator, with a command on the host |
| Holds | Profile, currency and lots, keyed by the card source's ids | The primary database as it is |
| Restores into | Any instance of any release, even one with another catalog build; replaces that collector's lots | A new, empty instance of the same release or a newer one |
| Doesn't hold | Passwords, other users, settings, the catalog | Secrets, `COLLECTOR_*` settings, queued jobs, the art index file, downloads |
| Use it for | Moving a collection between instances, a collector's own safety copy, a file they can read ([Your data](#your-data)) | Recovering the instance after a failed disk, moving it to new hardware, a copy before an upgrade |

### What to keep outside the backup

The backup holds no secret, so keep these yourself, apart from the backup file: `SECRET_KEY_BASE` (and, under Kamal, `RAILS_MASTER_KEY`), your `COLLECTOR_*` settings (a restored instance run with another `COLLECTOR_CURRENCY` shows the same prices with another symbol), and your `compose.yaml` or `config/deploy.yml`. Nothing in the database is encrypted with the secrets, so **a lost or changed secret costs only the signed-in sessions**: everyone signs in again with their password.

The file is **sensitive**: it holds every user's password hash and every collection. Collector writes it readable by its owner only; store it privately.

### Back up

Run the command in the running container, with a directory the container's user (uid 1000) can write. Quote the argument for your shell (it can't contain a comma). It prints the file, its size, the schema version, the counts of accounts, users and lots, and how long it took; it stops with a plain message when the directory is missing, isn't writable, has less than twice the database's size free, or the database fails its checks.

**Docker Compose** (the stock `compose.yaml`; `/tmp` is writable in the container):

```sh
docker compose exec web bin/rails "backup:create[/tmp]"
docker compose cp web:/tmp/collector-backup-20261021T142100Z.tar.gz .     # use the name the command printed
docker compose exec web rm /tmp/collector-backup-20261021T142100Z.tar.gz
```

**Podman** (`podman compose` has no `cp`; the container's name differs by tool, so look it up):

```sh
podman compose exec web bin/rails "backup:create[/tmp]"
podman ps --format '{{.Names}}'                    # for example collector_web_1 under podman-compose, collector-web-1 under Compose v2
podman cp collector_web_1:/tmp/collector-backup-20261021T142100Z.tar.gz .
podman compose exec web rm /tmp/collector-backup-20261021T142100Z.tar.gz
```

**With a host directory instead** (Compose; no copy out): make the directory belong to uid 1000 once, then mount it for a one-off run. Rootless Podman shows a bind mount to the container as root-owned unless the mount has `:U` (`-v "$PWD/backups:/backups:U"`) or the container has `--userns=keep-id`.

```sh
mkdir backups && sudo chown 1000:1000 backups
docker compose run --rm -v "$PWD/backups:/backups" web bin/rails "backup:create[/backups]"
```

**Kamal:** the `backup` alias is already in `config/deploy.yml`; the directory it writes to is a volume you add once. First create the directory on the server, owned by uid 1000; only then uncomment the `/srv/collector-backups:/backups` line under `volumes:` and deploy. The line is commented out in the stock file because Docker creates a missing bind-mount directory owned by root, which the container's user (uid 1000) could not write to, and the alias would then refuse.

```sh
ssh root@192.168.0.1 'install -d -o 1000 -g 1000 /srv/collector-backups'
# now uncomment the /srv/collector-backups:/backups line in config/deploy.yml, then:
bin/kamal deploy --skip-push --version 0.1.0     # mounts the directory
bin/kamal backup                                 # backup:create[/backups] in the running container
scp root@192.168.0.1:/srv/collector-backups/collector-backup-20261021T142100Z.tar.gz .
```

The file is mode 0600 and owned by uid 1000 on the server; Kamal logs in as root by default (`ssh:` in `config/deploy.yml`), which can read it. Any other login needs `sudo`.

**When to back up:** before every upgrade, and at least daily for a collection that changes daily. From a host's cron, for example (02:17 every day, clear of Monday 03:00 to 05:00 in the container's time zone, UTC unless you set one, when the weekly catalog refresh writes the most and a backup would hold the database's write-ahead log back):

```cron
17 2 * * * cd /srv/collector && docker compose run --rm -T -v /srv/collector-backups:/backups web bin/rails "backup:create[/backups]" >> /var/log/collector-backup.log 2>&1
```

Keep several, and delete old ones yourself.

### Restore

A restore needs a **new, empty volume** and runs **before the instance's first start**, as a one-off command in a container of the image you will run. It refuses a volume that already holds a Collector database (or the `-wal`, `-shm` or `-journal` file of one, or the queue, cache or cable database) and changes nothing: to restore over a running instance, restore onto a new volume and switch to it. It restores a backup taken by the same release or an older one, which the first start then migrates as any upgrade does; a backup from a newer release is refused. Use the image tag you run (`COLLECTOR_IMAGE`), and a release that has `backup:restore`.

A restore ends every session (everyone signs in again) and drops pending bulk-removal Undos and selections; no collection is lost. It leaves the art index file behind: with art matching on, press **Build art index** on the admin catalog page afterwards, which needs no downloads.

**Docker Compose.** Create the volume without starting Collector, and find its real name (Compose prefixes the project's name; a different project name is a different, empty volume):

```sh
docker compose up --no-start
docker volume ls | grep collector_storage          # for example collector_collector_storage
```

Then get the file in readable by uid 1000, the preferred way (a host directory that belongs to uid 1000, mounted read-only):

```sh
sudo install -d -o 1000 -g 1000 backups-in
sudo cp collector-backup-20261021T142100Z.tar.gz backups-in/ && sudo chown 1000:1000 backups-in/collector-backup-20261021T142100Z.tar.gz
docker run --rm -u 1000 -v collector_collector_storage:/rails/storage -v "$PWD/backups-in:/backups:ro" \
  -e SECRET_KEY_BASE_DUMMY=1 ghcr.io/plainprogrammer/collector:0.1.0 \
  bin/rails "backup:restore[/backups/collector-backup-20261021T142100Z.tar.gz]"
```

or, without a host directory (`docker cp` makes root-owned files, and uid 1000 can't give a file to itself, so one root one-off fixes the owner):

```sh
docker create --name collector-restore -v collector_collector_storage:/rails/storage ghcr.io/plainprogrammer/collector:0.1.0
docker cp collector-backup-20261021T142100Z.tar.gz collector-restore:/rails/storage/
docker rm collector-restore
docker run --rm -u 0 -v collector_collector_storage:/rails/storage ghcr.io/plainprogrammer/collector:0.1.0 \
  chown 1000:1000 /rails/storage/collector-backup-20261021T142100Z.tar.gz
docker run --rm -u 1000 -v collector_collector_storage:/rails/storage ghcr.io/plainprogrammer/collector:0.1.0 \
  bin/rails "backup:restore[/rails/storage/collector-backup-20261021T142100Z.tar.gz]"
```

(The restore never moves or deletes the file you give it; delete it from the volume yourself afterwards.) Then `docker compose up -d`. `SECRET_KEY_BASE_DUMMY=1` stands in for a secret: the restore reads none.

**Podman** is the same with `podman` for `docker` and `podman compose up --no-start`, the root `chown` one-off included. Under rootless Podman give the host directory `:U` (or run with `--userns=keep-id`) as above.

**Kamal.** A restore can't use `kamal app exec` before the first boot: its one-off container needs the role's env file, which only an app boot writes, and the `kamal` network, which only the proxy boot creates. So restore with a plain `docker run` of the exact release over SSH, then deploy that same release:

```sh
bin/kamal server bootstrap
ssh root@192.168.0.1 'install -d -o 1000 -g 1000 /srv/collector-backups'    # a freshly bootstrapped server doesn't have it
scp collector-backup-20261021T142100Z.tar.gz root@192.168.0.1:/srv/collector-backups/
ssh root@192.168.0.1 'chown 1000:1000 /srv/collector-backups/collector-backup-20261021T142100Z.tar.gz && docker run --rm -u 1000 \
  -v collector_storage:/rails/storage -v /srv/collector-backups:/backups:ro -e SECRET_KEY_BASE_DUMMY=1 \
  ghcr.io/plainprogrammer/collector:0.1.0 bin/rails "backup:restore[/backups/collector-backup-20261021T142100Z.tar.gz]"'
bin/kamal setup --skip-push --version 0.1.0
```

Give the exact release as the tag: releases deploy by version, so no `latest` tag is on the server. This path is documented and its container command is tested in CI, but it hasn't been run through Kamal itself.

**After a restore**, before you hand the instance back: compare the counts the command printed (accounts, users, lots) with what you expect; start it; sign in; with art matching on press **Build art index**; check your settings (`COLLECTOR_*`) and your secret.

**A damaged, cut-short or wrong file is refused** with a plain message and the volume is left as it was: a file still being copied, a file from another tool, a collector's export (use **Import collection** for that), a backup of a newer release, a snapshot that fails SQLite's integrity or foreign-key check.

### What Collector doesn't do

It doesn't back up for you (no schedule, no retention, no upload), encrypt the file, restore one account out of a backup, merge a backup into an instance, or restore onto an older release. Other ways to protect the volume exist and Collector doesn't test them: stopping the app and copying the volume, Litestream, and ZFS, LVM or btrfs snapshots. The file's layout, and how to open it with `tar` and `sqlite3` without Collector, are in [docs/backup-restore.md](docs/backup-restore.md).
````

- [ ] **Step 7.3: `docs/backup-restore.md`**:

````markdown
# Backup file and manual recovery

How the backup file made by `bin/rails "backup:create[DIRECTORY]"` is laid out, and how to get a database out of it without Collector. The procedure (how to back up and restore, for Compose, Podman and Kamal) is in the [README](../README.md#backup-and-restore); the decisions are in [ADR 0024](adr/0024-backup-with-vacuum-into.md) and [spec 030](specs/030-backup-restore/spec.md).

## The file

`collector-backup-YYYYMMDDTHHMMSSZ.tar.gz`: the UTC time the backup started, to the second, with no colon (a colon breaks `docker cp`, `scp` and Windows shares). While it is being made it has a `.partial` name ending in a random part; only a finished, verified backup is linked to the final name, and a final name is never replaced.

It is a gzip-compressed tar of two files, in this order, each mode 0600:

| File | What it is |
|---|---|
| `manifest.json` | What the backup holds and how to check it (below) |
| `primary.sqlite3` | A SQLite database: the instance's primary database at one moment, in rollback-journal mode (no `-wal` or `-shm`) |

Nothing else is in it: no secret, no setting, no queue, cache or cable database, no catalog download, no art image or index, no Active Storage file.

## The manifest

| Member | Meaning |
|---|---|
| `backup_format_version` | `1`. The backup format's own whole number, apart from the export format's `format_version`. A released version never changes meaning; a release restores every version it has shipped and refuses one it doesn't know |
| `taken_at` | When the backup started, UTC, RFC 3339 |
| `schema_version` | The newest migration the snapshot has run (`schema_migrations.version`) |
| `snapshot_bytes` | The size of `primary.sqlite3` |
| `snapshot_sha256` | The SHA-256 of `primary.sqlite3` |
| `counts` | `{ "accounts": n, "users": n, "lots": n }`, counted in the snapshot |

## What a restore checks

In this order, before it changes the volume: the volume is empty (none of the four databases and no `-wal`, `-shm` or `-journal` file); the file is a Collector backup and isn't named `*.partial`; its format version is known; the volume has room (checked as soon as the manifest is read); then the file is read to its end, which finds a cut-short file and checks the checksum. Then, on a temporary file in the volume: SQLite's integrity check and foreign-key check, that no migration is newer than the release's, then every session is ended (which cascades to the bulk removals and selections), the counts agree with the manifest, and the file is linked to its final name, never replacing a file. A restore that stops anywhere leaves no primary database.

## Manual recovery with `tar` and `sqlite3`

You don't need Collector to open a backup:

```sh
tar -xzf collector-backup-20261021T142100Z.tar.gz        # manifest.json and primary.sqlite3
cat manifest.json
sha256sum primary.sqlite3                                # the manifest's snapshot_sha256
sqlite3 primary.sqlite3 "PRAGMA integrity_check;"        # ok
sqlite3 primary.sqlite3 "SELECT COUNT(*) FROM lots;"
```

To put it on a new instance by hand, instead of `backup:restore`: stop Collector; the volume must hold no Collector database or `-wal`, `-shm` or `-journal` file; copy `primary.sqlite3` to `<volume>/production.sqlite3` with owner uid 1000 (`chown 1000:1000`); and, to end the sessions as `backup:restore` does, `sqlite3 <volume>/production.sqlite3 "PRAGMA foreign_keys = ON; DELETE FROM sessions;"`. Then start Collector: its first start creates the other three databases and migrates this one if the backup is from an older release. The export of each collector is the other way to get a collection out ([export format](export-format/README.md)).
````

- [ ] **Step 7.4: `docs/releasing.md`.** In "Cutting a release", add as step 5 and renumber the old step 5 to 6:

```markdown
5. Before announcing a release that changes the schema, the backup or the restore, restore the maintainer's own real backup onto the new image (spec 030 AC-5.7): take a backup of the NAS instance on the previous release, restore it onto a fresh Compose project of the new image (`docs/backup-restore.md` and the README's "Backup and restore"), start it, sign in, and compare the printed counts and an export of each with the source's. Record the steps, counts and timings in the feature's `verification.md`.
```

In "Upgrade notes", add at the top (newest first):

```markdown
- **Backup and restore (spec 030).** No migration. Two new commands, `bin/rails "backup:create[DIRECTORY]"` and `bin/rails "backup:restore[FILE]"`, back up a running instance into one file and restore it onto a new, empty volume; see the README's "Backup and restore". `config/deploy.yml` gains a `backup` alias and a commented backup-directory volume; `compose.yaml` is unchanged. Nothing is required of the operator, but take a backup before this upgrade and keep your `SECRET_KEY_BASE` and `COLLECTOR_*` settings somewhere apart from it.
```

- [ ] **Step 7.5: `CLAUDE.md`.** Three edits, each a sentence or a line (the rules of the area go in its area doc when `distill-feature` writes one):
  - Project Status paragraph: after the sentence about number entry add: "An operator backs up a running instance and restores it onto a fresh volume with two rake tasks, `backup:create[DIRECTORY]` and `backup:restore[FILE]` (`Collector::Backup`, `lib/collector/backup/`, spec 030, ADR 0024)."
  - Commands: after the `Local CI` bullet add: "- Backup smoke: `bin/backup-smoke <image> [restore-image]` (spec 030): backs up a running container and restores it into a second one under another secret, the documented ways; CI runs it after `bin/image-smoke` on both architectures; it needs a container engine, so it is not a `bin/ci` step."
  - Non-obvious Facts: add **Backup and restore (spec 030, ADR 0024):** `docs/backup-restore.md` has the file's layout; `README.md` the procedure. A backup holds the primary database only (`VACUUM INTO`, verified, archived as `collector-backup-<UTC>.tar.gz`, 0600, never overwriting), no secret and no Active Storage file; the restore needs a fresh volume (none of the four databases or their `-wal`, `-shm`, `-journal`), never opens the primary's path, ends every session (cascading to bulk removals and selections), and migrates nothing (the first boot's `db:prepare` does). The two tasks don't depend on `:environment`, so they boot nothing and need no secret; their code is in `lib/collector/backup/`, required by path and not autoloaded (`config/application.rb`), and opens snapshots with `SQLite3::Database`, never Active Record. The suite's backup examples commit rows (`:committed`, `spec/support/backup_helpers.rb`); a model with a new attachment, or a fifth production database, fails `spec/backup_guards_spec.rb` until the backup's contents are decided.

- [ ] **Step 7.6: `docs/roadmap.md`** item 6: replace `**Expected ADR:** the backup mechanism.` with `**Done:** [spec 030](specs/030-backup-restore/spec.md), [ADR 0024](adr/0024-backup-with-vacuum-into.md).` (add the pull request link when it exists). **`.claude/rules/sqlite-and-migrations.md`:** replace "only the primary DB needs backing up (e.g. Litestream or `.backup`)" with "only the primary DB needs backing up, with `backup:create` ([ADR 0024](../../docs/adr/0024-backup-with-vacuum-into.md)); Litestream and volume snapshots are alternatives the app doesn't test".

- [ ] **Step 7.7: Read each document against the criteria**, and record the reading in `verification.md` (one row per criterion, with what was read): AC-5.1 (every item of its long sentence is in the README section: Compose, Podman and `podman cp`'s container name, Kamal, the two copy-in ways per engine with ownership, the Kamal sequence with the exact version and the not-run-through-Kamal sentence, the comma and quoting, what to keep outside, a schedule and cron line avoiding Monday 03:00 to 05:00, the checklist, which release to restore onto, what a backup doesn't hold, sensitivity, alternatives B to D untested, the link to the layout); AC-4.4; AC-6.1 (both directions of the links resolve: `#backup-and-restore`, `#your-data`, `docs/backup-restore.md`); AC-5.7; FR-7 (layout, manifest, format-version rule, manual recovery); FR-9 (CLAUDE.md lists the script). Check each anchor and each command by reading; every container command line in the README is the one `bin/backup-smoke` runs or differs from it only in the names of the volume, the image tag and the mounts.

- [ ] **Step 7.8: Run** `bin/rspec` (0 failures; no document is checked by RSpec) and `bin/rubocop`. **Commit** `docs(backup): document backup and restore, the file layout and the release check` (stage `README.md`, `docs/backup-restore.md`, `docs/releasing.md`, `CLAUDE.md`, `docs/roadmap.md`, `.claude/rules/sqlite-and-migrations.md`).

**Phase 7 verification:** the reading of step 7.7, recorded.

---

## Phase 8: Measurements, verification, review and the maintainer's check

**Implements:** decision 13, decision 14, decision 9 layer 3, ADR 0024's acceptance | **Satisfies:** AC-1.10, AC-5.6 (the maintainer's step), the spec's verification

**Goal:** the bars of decision 13 are measured outside the suite and recorded; `verification.md` maps every criterion to its evidence; an independent implementation review is recorded; the maintainer's own restore is done and recorded; the ADR is accepted.

**Files:** `script/backup/measure.rb` (new; `script/` is outside the image, `.dockerignore`), `docs/specs/030-backup-restore/verification.md` (new), `docs/adr/0024-backup-with-vacuum-into.md` (Status), `docs/specs/README.md` (the 030 row at the end).

- [ ] **Step 8.1: Write `script/backup/measure.rb`:**

```ruby
# AC-1.10, decision 13 (spec 030): times a backup and a restore of a SEEDED instance (a catalog of English-catalog size and
# 50,000 lots) and the longest wait of a write made while the backup runs. It builds its own database under tmp/ and never
# reads or writes storage/ or the maintainer's instance, so it needs nobody's database and no agent reads one. Run it in the
# test environment, whose only database is the primary, pointed at a scratch file:
#
#   mkdir -p tmp/measure && rm -f tmp/measure/primary.sqlite3*
#   export RAILS_ENV=test DATABASE_URL=sqlite3:$PWD/tmp/measure/primary.sqlite3
#   bin/rails db:schema:load
#   bin/rails runner script/backup/measure.rb
#
# The numbers are a seeded database's, not a real instance's: its rows are synthetic and their size is an estimate (the
# catalog is MEASURE_ENTRIES printings, default 100,000; the real Scryfall count isn't known to the plan). Record the
# printed counts and sizes beside the result. AC-5.6 (the maintainer's own restore) is the real-data check.
require Rails.root.join("lib/collector/backup").to_s
require "tmpdir"

abort "Run it against a scratch database under tmp/measure (see the header)." unless Rails.env.test? && ENV["DATABASE_URL"].to_s.include?("/tmp/measure/")

LOTS = 50_000
entries = Integer(ENV.fetch("MEASURE_ENTRIES", 100_000))
now = Time.current
digest = "d" * 64
legalities = %w[standard pioneer modern legacy vintage commander pauper brawl historic explorer].index_with { "legal" }

Catalog::Set.insert_all(Array.new(400) { |index| { id: index + 1, collectible_type: "mtg", code: "s#{index}", name: "Seeded set #{index}", content_digest: digest, created_at: now, updated_at: now } })
(1..entries).each_slice(5_000) do |ids|
  Catalog::Identity.insert_all(ids.map { |id| { id:, collectible_type: "mtg", external_key: "seed-identity-#{id}", name: "Seeded Card #{id}", content_digest: digest, created_at: now, updated_at: now } })
  Catalog::Entry.insert_all(ids.map do |id|
    { id:, collectible_type: "mtg", external_key: "seed-entry-#{id}", catalog_set_id: id % 400 + 1, catalog_identity_id: id, number: (id % 400).to_s, language: "en",
      name: "Seeded Card #{id}", kind: "card", content_digest: digest, created_at: now, updated_at: now }
  end)
  MTG::Printing.insert_all(ids.map do |id|
    { catalog_entry_id: id, rarity: "common", finishes: %w[nonfoil foil], layout: "normal", legalities:, external_ids: { "scryfall" => "seed-#{id}" },
      faces: [ { "name" => "Seeded Card #{id}", "mana_cost" => "{1}{R}", "type_line" => "Instant", "oracle_text" => "Deals 3 damage to any target. " * 6, "artist" => "A. Painter", "image_uris" => {} } ],
      scryfall_uri: "https://scryfall.com/card/s#{id % 400}/#{id}", created_at: now, updated_at: now }
  end)
end

unretired = Catalog::Entry.where(retired_at: nil).count
abort "The catalog holds #{unretired} unretired entries; the gate is 50,000." if unretired < LOTS

# The account is made before the clock starts: User.create! hashes a password with bcrypt, which the timed writes must not include.
account = User.create!(name: "Measure", email_address: "measure@example.test", password: "correct horse battery").account
ids = Catalog::Entry.where(retired_at: nil).order(:id).pluck(:id)
Lot.insert_all(ids.first(LOTS).map { |id| { account_id: account.id, catalog_entry_id: id, quantity: 1, lot_key: Lot.key_for(nil, nil, nil), created_at: now, updated_at: now } })
writer_ids = ids.drop(LOTS).first(2_000).presence || ids.first(2_000)

clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
primary = Collector::Backup::Databases.configured.primary
database_bytes = primary.size
waits = Queue.new
stop = false

Dir.mktmpdir("collector-measure") do |dir|
  directory = Pathname(dir).join("out").tap(&:mkpath)
  writer = Thread.new do
    ActiveRecord::Base.connection_pool.with_connection do
      index = 0
      until stop
        entry = Catalog::Entry.find(writer_ids[index % writer_ids.size])
        began = clock.call
        Lot.add!(account:, entry:) # the app's own write path, with no password hash in the timing
        waits << clock.call - began
        index += 1
        sleep 0.05
      end
    end
  end

  began = clock.call
  result = Collector::Backup::Create.new(directory:, source: primary).call
  backup_seconds = clock.call - began
  stop = true
  writer.join
  waited = Array.new(waits.size) { waits.pop }

  volume = Pathname(dir).join("volume").tap(&:mkpath)
  databases = Collector::Backup::Databases.new("primary" => volume.join("production.sqlite3"))
  began = clock.call
  Collector::Backup::Restore.new(file: result.path, databases:).call
  restore_seconds = clock.call - began

  manifest = Collector::Backup::Archive.read(result.path).manifest
  puts "| Measure | Value | Bar |", "|---|---|---|"
  puts "| Seeded database | #{Collector::Backup.size_phrase(database_bytes)} (#{Catalog::Entry.count} entries, #{unretired} unretired, #{Lot.count} lots) | gate: 50,000 unretired |"
  puts "| Backup file / snapshot | #{Collector::Backup.size_phrase(result.bytes)} / #{Collector::Backup.size_phrase(manifest.snapshot_bytes)} | |"
  puts "| Backup, verification included | #{format("%.1f", backup_seconds)} s | under 300 s: #{backup_seconds < 300 ? "met" : "MISSED"} |"
  puts "| Writes during the backup (Lot.add!, no password hash) | #{waited.size}, longest wait #{format("%.3f", waited.max.to_f)} s | under 5 s: #{waited.max.to_f < 5 ? "met" : "MISSED"} |"
  puts "| Restore | #{format("%.1f", restore_seconds)} s | under 300 s: #{restore_seconds < 300 ? "met" : "MISSED"} |"
  puts "| Write-ahead log after the run | #{Collector::Backup.size_phrase(File.size("#{primary}-wal"))} | recorded |" if File.exist?("#{primary}-wal")
end
```

- [ ] **Step 8.2: Take the measurement** on the development machine with the three commands of the script's header (no catalog refresh, no copy of any instance, nothing from `storage/`: the executor needs no one's help). Paste the table into `verification.md` under `## Measurements (AC-1.10)` with the machine, the date, the real entry, unretired-entry and lot counts the table prints, the file sizes, and the sentence **"These numbers come from a seeded database (synthetic rows, `MEASURE_ENTRIES` printings), not from the maintainer's instance."** If a bar is missed: the plan's fallback order is (1) `quick_check` instead of `integrity_check` in `Snapshot#verify!`, then (2) the default compression level (`Zlib::DEFAULT_COMPRESSION` is slower, so this only if the size matters more than the time); the maintainer rules which, and a change is a spec 030 amendment (decision 13), not a silent edit.

- [ ] **Step 8.3: Write `verification.md`** with: a table of every AC and FR with its evidence (the example's file and name, the document and the line read, or the CI run), the Phase 7 reading, the Phase 4 FR-8 trace, the measurements (with the seeded-database sentence of step 8.2), the first CI run's link (AC-5.2, AC-5.3, AC-2.3, AC-4.2), and the `bin/ci` result with the seed, run twice. Keep it factual: what was run and what it printed. Also record these notes, each with its reason:
  - **AC-3.6's construction** (maintainer's ruling m6, 2026-10-21, no spec change): the criterion says the older snapshot is "built in the spec by migrating a scratch database to that version"; `spec/backup_upgrade_spec.rb` instead seeds an instance, backs it up and rolls the newest migration back on the copy, because that keeps the seeded rows, which the criterion's "no row is lost" needs, and an empty scratch database proves nothing about rows. It relies on the newest migration being reversible (a rule: `.claude/rules/sqlite-and-migrations.md`); the example fails with that message otherwise.
  - **The D4 confirmation** (plan-review M1): which examples ran and where; the two boot examples are skipped on a machine with a `config/master.key`, so cite the CI run (or an environment without a key) where they ran.
  - **FR-2's order** (ruling m3): the room is checked as soon as the manifest is read, inside `Archive.read`'s first pass, so a file damaged after its manifest (cut short, a wrong gzip CRC, trailing damage, a snapshot that doesn't match its checksum) on a volume without room is refused for the room (such a file is told apart only by reading it to its end); every other pair of FR-2's checks is in FR-2's order.
  - **Kamal's volume** (ruling m5): decision 4's "stated addition" is read as the `backup` alias live plus the documents' `install -d -o 1000 -g 1000` step and the volume line to uncomment, which stays commented in the stock file.

- [ ] **Step 8.4: The maintainer's step (AC-5.6, decision 14)**, done by the maintainer, not an agent, on their NAS, once, before the spec ships: build the image from this branch (`docker build -t collector:local .`; a released image has no `backup:create`), run the NAS instance (Compose) on it with `COLLECTOR_IMAGE=collector:local`, back it up, restore that file onto a fresh Compose project of the same image the README's way, start it, sign in, and compare the printed counts and an export of each (the same collection, `docs/export-format/README.md`). The steps, counts, timings and result go into `verification.md` under `## NAS restore (AC-5.6)`.

- [ ] **Step 8.5: Implementation review and wrap-up.** Run `sdd-superpowers:sdd-review` (Mode B, independent, read-only), record its verdict under `## Implementation review` in `verification.md` with the verdict on its first line; run `distill-feature` (the release-and-deploy area doc, if slice C has landed, else it stays listed as not written); on the maintainer's acceptance of the plan, change ADR 0024's Status line to `Accepted (<date>)` (and its row in `docs/adr/README.md` loses "(Proposed)"); renumber the ADR to the next free number if another ADR merged first (below); set the 030 row in `docs/specs/README.md` to Approved with the plan and, after the merge, to Shipped. The coordinator files the separate issue of [issue-art-index-ready.md](issue-art-index-ready.md).

- [ ] **Step 8.6: Commit** `docs(backup): record the measurements and verification of spec 030` and `feat(backup): add the backup measurement script` (two commits: the script, then the records).

**Phase 8 verification:** `verification.md` complete; `bin/ci` green; CI green on both architectures including `Backup smoke test`.

---

## Integration verification

1. `bin/ci` — setup, RuboCop, Brakeman, bundler-audit, importmap audit, RSpec: green, from a clean checkout of the branch.
2. `bin/rspec --seed <the CI seed>` and one more seed — the backup examples commit rows and switch connections, so order matters (`.claude/rules/testing.md`: `rspec --bisect` if one fails).
3. The image job on both architectures: `bin/image-smoke collector:smoke` then `bin/backup-smoke collector:smoke`.
4. By hand, locally if an engine is at hand: `docker build -t collector:local . && bin/backup-smoke collector:local`.
5. The measurements and the maintainer's NAS restore (Phase 8).

## Quickstart validation

A new operator reads only the README's "Backup and restore" section and, on a scratch Compose project: starts Collector, creates an admin, adds a lot, runs the Compose backup commands, runs `docker compose down -v`, restores the file the host-directory way, starts it, signs in with the admin's password under a different `SECRET_KEY_BASE`, and sees the lot. That is `bin/backup-smoke`'s second pass by hand; the first time anyone does it (the maintainer's NAS restore) is a step of Phase 8.

---

## Self-review (sdd-plan, Step 5)

- **Spec coverage:** every FR (1 to 10), every acceptance criterion (AC-1.1 to AC-6.2) and every decision (1 to 15) is in the Requirement Map with a phase and a first failing test. The criteria with no suite test say how they are proven: AC-1.10 (the measurement script, Phase 8), AC-2.3 and AC-4.2 (the smoke script, Phase 6, first CI run), AC-4.4, AC-5.1, AC-5.7 and AC-6.1 (reading, Phase 7), AC-5.6 (the maintainer, Phase 8). No gaps.
- **Placeholder scan:** no "TBD", "TODO", "implement later" or "similar to Phase N"; every code step shows its code. Two places name a thing the first run settles, and say what: research.md 8 lists the assumptions each phase's first failing test confirms (`VACUUM INTO ?` with a bound path, the header bytes after `journal_mode = DELETE`, `GzipReader`'s errors, `df`'s columns, `docker cp` ownership, the control boot failing on `secret_key_base`); Phase 5's step 5.3 says the restored-instance examples are the first run of text and models the plan could only read.
- **Type consistency:** `Refusal#problem/#advice`, `Databases#primary/#directory/#names/#occupied`, `Snapshot#verify!/#counts/#schema_versions/#end_sessions!/#rollback_journal!`, `Archive.write/.read(path, allow_partial:, on_manifest:)` and `Archive::Result`, `Manifest.for/.parse/#to_json`, `Create#call → Result#report`, `Restore#call → Result#report`, the checkpoints (`:snapshot_written`, `:archive_written`, `:snapshot_ready`) and the helpers (`create_backup`, `restore_backup`, `archive_of`, `manifest_for`, `copy_of_instance`, `unpack_snapshot`, `run_killed_at`, `app_command`, `with_restored_instance`) are spelled the same in every phase that uses them.
- **Traceability:** every decision in a phase traces to a spec requirement; the three choices the spec leaves to the plan are below.

## Choices the plan makes that the spec leaves open (no spec change needed)

1. **The tasks don't depend on `:environment`** (and so the library lives in `lib/collector/backup/`, required by path). The spec asks the plan to confirm the secret question (D4) and says "a rake task"; this answers it by not booting. It also makes FR-8 structural. The ruled `SECRET_KEY_BASE_DUMMY=1` stays in the documented one-off and the smoke script.
2. **The release's migrations are read as file names** (`db/migrate/**/[0-9]*_*.rb`), not through `ActiveRecord::MigrationContext`, whose `#migrations` is `:nodoc:` and whose constructor evaluates a connection pool. FR-8 says "from the migration files without connecting"; this is that.
3. **The restore reads the archive twice**: once to classify, check the room and check the checksum (writing nothing, so a refusal changes nothing), once to extract. FR-2 says the checks come before any write and lists the temporary file after them; two passes are the cost of that order. The room is checked from `Archive.read`'s `on_manifest` callback, as soon as the manifest is parsed, because FR-2 lists it before the checksum and the checksum is only known at the end of the first pass (maintainer's ruling m3). The residue: a file damaged after its manifest (cut short, a wrong gzip CRC, trailing damage, or a snapshot whose checksum doesn't match) on a volume without room is refused for the room, because it is told apart only by reading it to its end, which comes after the room check; "incomplete" therefore follows the room for that case, a departure from FR-2's order that the ruling accepted.
4. **`compose.yaml` is unchanged.** The Compose documents use `/tmp` plus `cp`, or a `run -v` one-off with a host directory; adding a bind mount would need a path or a variable, and the spec adds no setting (hosted-door rule 3). `config/deploy.yml` gets the `backup` alias live and the volume line commented out: the alias works once the directory is mounted, and a live placeholder mount that docker would create root-owned would break the deploy's backups for everyone who doesn't read the README. **Reading of decision 4's "stated addition"** (maintainer's ruling m5, 2026-10-21): the addition is the alias plus the documents' steps (`install -d -o 1000 -g 1000 /srv/collector-backups` on the server, then uncomment the volume line and deploy); the line itself stays commented in the stock file.
5. **The older snapshot of AC-3.6 is made by rolling back the newest migration** on a copy of a seeded backup, in a child process with `SCHEMA` pointing away from `db/schema.rb`, instead of migrating an empty scratch database up to N-1: it keeps rows, which "no row is lost" needs. It relies on every migration being reversible, which `.claude/rules/sqlite-and-migrations.md` requires; an irreversible newest migration fails the example with that message. The maintainer accepted this construction for AC-3.6 on 2026-10-21 (ruling m6, no spec change); `verification.md` records the departure and its reason (step 8.3).

## Open items awaiting the maintainer

- **Approval of this plan** (the gate). Execution is by the maintainer's choice of agent after it, in one pull request.
- **Acceptance of ADR 0024** (Proposed), with the plan; it records the `lib/collector/backup` placement and the no-`:environment` decision (decision 5 of the ADR) beside the spec's rulings.
- **AC-5.6, the NAS restore** (Phase 8, step 8.4): the maintainer's, with the image built from the branch.
- **The separate issue of decision 12** is drafted in [issue-art-index-ready.md](issue-art-index-ready.md) for the coordinator to file; it is not filed.
- **Revised after the review, not reviewed again.** The independent read-only Opus review (NEEDS REVISION: 1 critical, 3 major, 13 minor) and its resolution are in [plan-review.md](plan-review.md), with the maintainer's four rulings of 2026-10-21 (m3, m5, m6, m7). A second review of the revised plan is the maintainer's call.
