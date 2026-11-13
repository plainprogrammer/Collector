# Implementation Plan: A Prices Database That the Backup Holds (spec 081, issue #363)

**Spec:** `docs/specs/081-prices-database-in-backup/spec.md` (Approved 1.2.2) · **ADR:** 0029 (Proposed) · **Issue:** #363 · **Branch:** `081-prices-database-in-backup` · **Created:** 2026-11-13
Plan review: Opus, read-only, round 1 2026-11-13: REVISE (one blocking, seven major, ten minor), all applied in this revision. Gate B: the coordinator (pending). Retired by `distill-feature` after the merge (spec 027).

## Context

Spec 081 adds a fifth SQLite database, `prices`, with five tables that #364 to #370 build on, and makes the backup hold it: backup format version 2 archives `primary.sqlite3` and `prices.sqlite3`, and a restore places both or neither. Version 1 backups still restore. The upgrade proof, the container smoke and the suite cover the new file. Nothing reads or writes a price yet.

## Global Constraints

- **Repo rules:** `CLAUDE.md`, `.claude/rules/*.md`. Spec types are tagged (`type: :model` and so on). `RSpec/ExampleLength` max 15 lines; a longer scenario uses the existing `# rubocop:disable RSpec/ExampleLength -- <reason>` style, as in `restore_spec.rb:25`. `RSpec/MultipleMemoizedHelpers` max 5. Multi-expectation examples use `:aggregate_failures`.
- **One commit per task, test first:** red, implement, green, RuboCop. Conventional Commits ending `(#363)` with the trailer of the model that wrote the commit (`Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` for an implementer). One git operation per shell call; `git add` and `git commit` in separate calls. Every `git grep` ends with `':!.kamal/secrets'`.
- **Off limits:** never read `.kamal/secrets`, `config/master.key`, `.env*`, `storage/` or any `*.sqlite3`. Running `bin/rails db:migrate` (which writes under `storage/`) is fine. Never run the `sqlite3` command yourself, `bin/rails console`/`dbconsole`, `db:rollback`, `db:migrate:down`, `db:seed`, anything with `RAILS_ENV=production`, `bundle add`/`update`, or `bin/jobs`.
- **One test run at a time** in this worktree: it has one shared `storage/test*.sqlite3`. Run targeted files with `bin/rspec <file>`; never two at once. No full `bin/ci` without a slot from the coordinator.
- **Comments** (`.claude/rules/code-documentation.md`): every public class, module and method added or changed gets a summary, plus `@param`/`@return`/`@raise` where it is reusable. No `{…}` outside YARD links. Point at area docs with `@see file:release-and-deploy.md` or `@see file:prices.md` (the latter only once T5.1 has created `docs/architecture/prices.md`; until then cite "spec 081 decision N"). A changed behaviour updates its comment in the same commit.
- **Core names no collectible.** `lib/collector/backup/`, `lib/tasks/backup.rake`, `db/prices_migrate/`, `db/prices_structure.sql` and `app/models/prices_record.rb` never contain `MTG`, `Scryfall` or `Magic`, comments included (`spec/backup_guards_spec.rb:43`, `spec/prices_core_spec.rb`, new).
- **Schema noise** (`.claude/memory/migrate-schema-noise.md`): after any `bin/rails db:migrate` in development, run `git status`. If `db/schema.rb`, `db/cache_schema.rb`, `db/queue_schema.rb` or `db/cable_schema.rb` changed, restore them with `git checkout -- <file>`; only `db/prices_structure.sql` may change.
- **No deployment file changes:** `Dockerfile`, `config/deploy*.yml`, `compose.yaml` and `.github/workflows/**` stay as they are (spec FR-1). If a task seems to need one, stop and report.
- **Existing examples and callers this feature changes**, named again in their tasks. A commit is green only once its task's list is done:
  - **T1.1:**
    - `spec/backup_guards_spec.rb:37`: four databases become five. The file count at `:84` stays 10.
    - `spec/lib/collector/backup/databases_spec.rb:8`: production names, now five.
    - `databases_spec.rb:16`: the test environment is no longer single-database; its names are `primary` and `prices`.
  - **T2.1:**
    - `spec/backup_upgrade_spec.rb:27`: `db:migrate VERSION=` becomes `db:migrate:primary VERSION=`.
    - `spec/backup_boot_spec.rb:7`.
    - `spec/support/backup_helpers.rb` (decision 12).
  - **T3.1:**
    - `manifest_spec.rb:9`; `archive_spec.rb:14`.
    - `archive_spec.rb:152`, `:160` and `restore_spec.rb:197`: their "unknown version" fixture uses 2, which is now known. Use 99, and expect "restores versions 1, 2".
    - Restore's `extract` (`restore.rb:99`) writes only the primary's chunks.
  - **T3.3:**
    - `create_spec.rb:18`: report.
    - `create_spec.rb:21` and `:37`: three files.
    - `create_spec.rb:129`: the child process has no Rails.
    - `create_spec.rb:184`: "twice the two databases' sizes".
    - `script/backup/measure.rb:71`.
  - **T3.4:**
    - `restore_spec.rb:25`, `:42` and `:60`: the volume's children and the report.
    - `restore_spec.rb:97`: a primary clash.
    - `restore_spec.rb:110`: the child process has no Rails.
    - `databases_spec.rb:36`: also `collector-restore-prices.partial`.
    - `script/backup/measure.rb:78`.
  - **T4.2:** `spec/support/upgrade_fakes.rb` (`copy_database`).
  - **T4.4:** `bin/backup-smoke:122` and `:185`.

## Goal

After this branch: `bin/rails db:prepare` creates `storage/<env>_prices.sqlite3` with five tables, two of them `WITHOUT ROWID`. `backup:create` writes a version 2 file holding both databases. `backup:restore` restores version 1 and version 2 files. The upgrade proof and `bin/backup-smoke` check the prices file. The documents say so.

## Pre-implementation gates

- **Simplicity (≤3 components): pass.** (1) The prices database: configuration, migrations, structure file and `PricesRecord`. (2) The backup library's version 2 (`lib/collector/backup/`). (3) The proofs (`script/upgrade/`, `bin/backup-smoke`, specs). No gem, model per table, job or page.
- **Anti-abstraction: pass.** No wrapper class for "a database in a backup". The manifest gets one `prices` member, and `Archive` gets one more entry name. The two snapshots are handled by the same `Snapshot` class, called twice.
- **Integration-first: pass.** Phase 1 makes the database exist and decides the backup's contents (the guard). Phase 3 defines the version 2 manifest and archive (the file contract) before `Create` and `Restore` use them.
- **Complexity note:** `Restore#call` gains a second temporary file and a second placing. It stays one method with a helper per step, as today.

## Files

| File | Change | Responsibility |
|---|---|---|
| `config/database.yml` | edit | `prices` in development, test (now nested) and production; `schema_format: sql` for prices |
| `db/prices_migrate/20261113100001_create_price_tables.rb` | create | the five tables (decision 2), the `alter_table` warning (AC-7.3) |
| `db/prices_structure.sql` | create (generated by `db:migrate`) | the prices database's schema, with `WITHOUT ROWID` |
| `app/models/prices_record.rb` | create | the abstract connection class (decision 5) |
| `lib/collector/backup.rb` | edit | `FORMAT_VERSIONS = [1, 2]`, `HELD`, `release_schema_versions(root, directory)`, the counts phrases |
| `lib/collector/backup/databases.rb` | edit | `#prices` |
| `lib/collector/backup/manifest.rb` | edit | version 2's `prices` member |
| `lib/collector/backup/archive.rb` | edit | `prices.sqlite3`; the entries a version has; the sink gets each entry's name |
| `lib/collector/backup/snapshot.rb` | edit | `counts(names)`; the orphan count for `WITHOUT ROWID` tables |
| `lib/collector/backup/create.rb` | edit | two snapshots; the missing-prices refusal; free space; the report |
| `lib/collector/backup/restore.rb` | edit | versions 1 and 2; two temporary files; prices placed first and removed on failure; the not-fresh advice; the report |
| `lib/tasks/backup.rake` | edit | the task description ("the primary and prices databases") |
| `script/upgrade/release.rb`, `guard.rb`, `rules.rb`, `engine.rb`, `harness.rb` | edit | the prices migrations directory; copying out the prices file; checking and comparing it |
| `script/upgrade/seeds/next.rb` | edit | a row in each prices table |
| `bin/backup-smoke` | edit | five files; a price row that survives the restore; the counts line |
| `spec/support/backup_helpers.rb` | edit | decision 12 (two databases in child processes and helpers) |
| `spec/support/upgrade_fakes.rb` | edit | `copy_database` hands out a prices file too |
| `spec/backup_guards_spec.rb` | edit | five databases, `HELD` against the guard's lists (AC-6.1), the file count |
| `spec/config/prices_database_spec.rb` | create | AC-1.1, AC-2.4 |
| `spec/models/prices_record_spec.rb` | create | AC-1.4, AC-1.5, AC-3.1, AC-3.3, AC-3.4 |
| `spec/prices_schema_spec.rb` | create | AC-2.1 to AC-2.3 (both build paths, negative control) |
| `spec/prices_core_spec.rb` | create | AC-3.5 |
| `spec/backup_prices_spec.rb` | create | AC-1.2, AC-1.3, AC-6.2, AC-6.9 (child processes and the round trip) |
| `spec/lib/collector/backup/*_spec.rb`, `spec/backup_upgrade_spec.rb`, `spec/backup_boot_spec.rb` | edit | Story 4 and 5 criteria; the changed examples above |
| `spec/script/upgrade/{release,guard,expected_changes,engine,harness,seeds}_spec.rb` | edit | AC-6.4 to AC-6.8 |
| Documents (Phase 5) | edit, create | Story 7 |

## Phase 1: The prices database, and the backup's contents decided

**Implements:** FR-1, FR-2; decisions 1 to 5 and 9 · **Satisfies:** AC-1.1, AC-1.4, AC-1.5, AC-2.1 to AC-2.4, AC-3.1, AC-3.3 to AC-3.5, AC-6.1
**Files:** `config/database.yml`, `db/prices_migrate/…`, `db/prices_structure.sql`, `app/models/prices_record.rb`, `lib/collector/backup.rb` (`HELD` only), the specs named per task

- [ ] **T1.1 The fifth database fails the backup guard (the first failing test), and the backup's contents are decided.**
  1. Edit `config/database.yml`. In `development` and `production`, add after `cable`:
     ```yaml
       prices:
         <<: *default
         database: storage/development_prices.sqlite3   # production: storage/production_prices.sqlite3
         migrations_paths: db/prices_migrate
         schema_format: sql
     ```
     Make `test` nested:
     ```yaml
     test:
       primary:
         <<: *default
         database: storage/test.sqlite3
       prices:
         <<: *default
         database: storage/test_prices.sqlite3
         migrations_paths: db/prices_migrate
         schema_format: sql
     ```
     Keep the "Warning: The database defined as "test" will be erased…" comment above `test:`.
  2. Run `bin/rspec spec/backup_guards_spec.rb`. **Expected red:** "knows exactly the four production databases" fails, with the guard's advice text. Copy the failure's first lines into the commit body (verification.md cites them as the first failing test).
  3. Decide the contents. In `lib/collector/backup.rb`, define `HELD` in a `module Collector; module Backup; … end; end` block **above** the `require_relative` lines (`backup.rb:10-17`), so that `archive.rb` can derive its entry names from it (T3.1). Keep the main module's comment where it is:
     ```ruby
     module Collector
       module Backup
         # The databases a backup holds, by configuration name, and the archive entry each is stored as, in archive order
         # (spec 081 decision 6). Archive's entry names and Restore's placing read it; spec/backup_guards_spec.rb compares it
         # with its own lists. The queue, cache and cable databases are left out.
         HELD = { "primary" => "primary.sqlite3", "prices" => "prices.sqlite3" }.freeze
       end
     end
     ```
     `spec/lib/collector/backup/databases_spec.rb`:
     - `:8`: `contain_exactly("primary", "cache", "queue", "cable", "prices")`.
     - `:14-18`: becomes "reads the test environment's two databases", expecting `names` to be `%w[primary prices]` and `primary.basename` to be `test.sqlite3`.
  4. Rewrite the guard's database example (`spec/backup_guards_spec.rb:46-51`):
     ```ruby
     # Spec 081 decision 6 (supersedes spec 030 AC-5.5's four): what the backup holds, and why the rest stay out.
     HELD_DATABASES = %w[primary prices].freeze
     LEFT_OUT = { "queue" => "jobs in flight are lost; db:prepare creates it empty", "cache" => "it refills",
       "cable" => "it is ephemeral" }.freeze

     it "knows exactly the five production databases, and holds the primary and prices ones (spec 081 AC-6.1)", :aggregate_failures do
       names = ActiveRecord::DatabaseConfigurations.new(Rails.application.config.database_configuration)
         .configs_for(env_name: "production").map(&:name)

       expect(names).to match_array(HELD_DATABASES + LEFT_OUT.keys), advice
       expect(Collector::Backup::HELD.keys).to eq(HELD_DATABASES), advice
     end
     ```
     Change `advice` to: `"Spec 081 decision 6 (spec 030 decision 2): decide what a backup does with it, then update that decision, docs/backup-restore.md and the README's Backup and restore section, and list it here"`. Keep the constants inside the `describe` block, as `RSpec/LeakyConstantDeclaration` requires (if RuboCop flags them, use `let`s instead).
  5. `bin/rspec spec/backup_guards_spec.rb` is green. Commit: `test(backup): a fifth database, prices, and what the backup holds (#363)`.

  > The database file appears with its first migration in T1.2. Between T1.1 and T1.2 the test database `prices` has no schema; run only `spec/backup_guards_spec.rb` here.

- [ ] **T1.2 The tables, the structure file and `PricesRecord` (AC-1.1, AC-1.4, AC-1.5, AC-2.4, AC-3.1, AC-3.3, AC-3.4).**
  1. Red: create `spec/config/prices_database_spec.rb`:
     ```ruby
     require "rails_helper"

     RSpec.describe "the prices database's configuration (spec 081 AC-1.1, AC-2.4)", type: :model do
       def configs(env) = ActiveRecord::DatabaseConfigurations.new(Rails.application.config.database_configuration).configs_for(env_name: env)

       it "names a prices database in every environment, with its own migrations and an SQL schema", :aggregate_failures do
         %w[development test production].each do |env|
           prices = configs(env).find { it.name == "prices" }
           expect(prices&.database).to eq("storage/#{env}_prices.sqlite3"), env
           expect(prices.migrations_paths).to eq("db/prices_migrate"), env
           expect(prices.schema_format).to eq(:sql), env
         end
       end

       it "keeps the other databases' Ruby schema files" do
         others = %w[development test production].flat_map { configs(it) }.reject { it.name == "prices" }
         expect(others.map(&:schema_format).uniq).to eq([ :ruby ])
       end
     end
     ```
     And `spec/models/prices_record_spec.rb`:
     ```ruby
     require "rails_helper"

     RSpec.describe PricesRecord, type: :model do
       def connection = described_class.lease_connection
       def insert(sql, binds = []) = connection.exec_insert(sql, "spec", binds)

       def source! = insert("INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('a-source', 'A', 'Prices from A', 0, '2026-11-13', '2026-11-13')") && connection.select_value("SELECT max(id) FROM price_sources")
       def series!(finish = "plain") = insert("INSERT INTO price_series (finish, currency, kind, created_at, updated_at) VALUES ('#{finish}', 'USD', 'market', '2026-11-13', '2026-11-13')") && connection.select_value("SELECT max(id) FROM price_series")

       it "is abstract and connects to storage/test_prices.sqlite3, which the primary test database is not (AC-1.5)", :aggregate_failures do
         expect(described_class).to be_abstract_class
         expect(connection.pool.db_config.database).to eq("storage/test_prices.sqlite3")
         expect(ActiveRecord::Base.lease_connection.table_exists?("current_prices")).to be(false)
         expect(connection.tables).to include("price_sources", "price_series", "current_prices", "price_changes", "price_refresh_runs")
       end

       it "runs each example inside a transaction on the prices database too, so its rows roll back (AC-1.5)", :aggregate_failures do
         source!
         expect(connection.transaction_open?).to be(true)
         expect(connection.select_value("SELECT count(*) FROM price_sources")).to eq(1)
       end

       it "has no account or user column in any table (AC-3.1)" do
         columns = connection.tables.flat_map { |table| connection.columns(table).map { "#{table}.#{it.name}" } }
         expect(columns.grep(/\.(account_id|user_id)\z/)).to be_empty
       end

       it "keeps every foreign key inside the prices file, restricting deletes, and none on catalog_entry_id (AC-3.3)", :aggregate_failures do
         keys = connection.tables.flat_map { |table| connection.foreign_keys(table) }
         expect(keys.map(&:to_table).uniq).to match_array(%w[price_sources price_series])
         expect(keys.map(&:on_delete).uniq).to eq([ :restrict ])
         expect(keys.map(&:column)).not_to include("catalog_entry_id")
       end

       it "can't reach the primary database's tables (AC-3.4)" do
         expect { connection.select_value("SELECT count(*) FROM catalog_entries") }.to raise_error(ActiveRecord::StatementInvalid, /no such table/)
       end

       it "refuses rows that break the schema's rules (AC-1.4)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one row per rule
         source = source!
         series = series!
         bad = [
           "INSERT INTO current_prices (catalog_entry_id, price_source_id, price_series_id, cents, reported_on, changed_on) VALUES (1, #{source}, #{series}, -1, '2026-11-13', '2026-11-13')",
           "INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('', 'B', 'x', 0, '2026-11-13', '2026-11-13')",
           "INSERT INTO price_series (finish, currency, kind, created_at, updated_at) VALUES ('plain', 'USD', 'market', '2026-11-13', '2026-11-13')",
           "INSERT INTO price_series (finish, currency, kind, created_at, updated_at) VALUES ('shiny', 'usd', 'market', '2026-11-13', '2026-11-13')",
           "INSERT INTO current_prices (catalog_entry_id, price_source_id, price_series_id, cents, reported_on, changed_on) VALUES (1, #{source}, 999, 5, '2026-11-13', '2026-11-13')",
           "INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) VALUES (1, #{source}, #{series}, '2026-11-13', -5)",
           "INSERT INTO price_refresh_runs (price_source_id, run_on, status, started_at, created_at, updated_at) VALUES (#{source}, '2026-11-13', 'lost', '2026-11-13', '2026-11-13', '2026-11-13')"
         ]
         bad.each { |sql| expect { connection.execute(sql) }.to raise_error(ActiveRecord::StatementInvalid), sql }
       end

       it "takes a price change with no cents: the price went away that day (decision 2)" do
         source = source!
         series = series!
         insert("INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) VALUES (7, #{source}, #{series}, '2026-11-13', NULL)")
         expect(connection.select_value("SELECT count(*) FROM price_changes WHERE cents IS NULL")).to eq(1)
       end
     end
     ```
     If `RSpec/MultipleMemoizedHelpers` or line length objects, split the helpers into private methods; keep the cases. The `:committed` half of AC-1.5 is proven in T2.1.
  2. Green: create `app/models/prices_record.rb`:
     ```ruby
     # The connection to the prices database, the instance's fifth SQLite file (spec 081 decisions 1 and 5; ADR 0029).
     # Every model of a price table inherits from it. Prices are global, like the catalog: no account scopes them, and no
     # query joins this file with the primary one. A printing is named by its catalog entry's id, with no foreign key
     # (spec 081 decision 4). This class has no models yet: #364 to #366 add them.
     class PricesRecord < ActiveRecord::Base
       self.abstract_class = true

       connects_to database: { writing: :prices }
     end
     ```
     Writing role only: nothing reads from a replica, and a reading pool that `with_restored_instance` doesn't re-point would be a trap.
  3. Create `db/prices_migrate/20261113100001_create_price_tables.rb`:
     ```ruby
     # The prices database's tables (spec 081 decision 2; ADR 0029). current_prices and price_changes are WITHOUT ROWID: their
     # primary key is the table, stored once (decision 3, ruled 2026-11-13).
     #
     # WARNING for the next migration of current_prices or price_changes: on SQLite, Rails changes a column
     # (change_column, remove_column, rename_column, change_column_null, add_check_constraint and the like) by copying the
     # table into a new one built WITHOUT its options, so WITHOUT ROWID is silently lost. Write a new migration that creates
     # the new table with options: "WITHOUT ROWID", copies the rows and swaps the names. spec/prices_schema_spec.rb fails
     # on either table without the option. Adding a nullable column with add_column is safe (SQLite's ALTER TABLE ADD COLUMN).
     #
     # No index beyond the primary key on those two tables: an index on price_source_id or price_series_id would store most
     # of the key again (decision 2, an exception to "index every foreign key" the maintainer accepted on 2026-11-13).
     class CreatePriceTables < ActiveRecord::Migration[8.1]
       def change
         create_table :price_sources do |t|
           t.string :key, null: false
           t.string :name, null: false
           t.string :attribution, null: false
           t.string :attribution_url
           t.boolean :hosted_paid_allowed, null: false, default: false
           t.timestamps
           t.index :key, unique: true
           t.check_constraint "length(key) >= 1", name: "price_sources_key_present"
           t.check_constraint "length(name) >= 1", name: "price_sources_name_present"
           t.check_constraint "length(attribution) >= 1", name: "price_sources_attribution_present"
         end

         create_table :price_series do |t|
           t.string :finish, null: false
           t.string :currency, null: false
           t.string :kind, null: false
           t.timestamps
           t.index %i[finish currency kind], unique: true
           t.check_constraint "currency GLOB '[A-Z][A-Z][A-Z]'", name: "price_series_currency_code"
         end

         create_table :current_prices, primary_key: %i[catalog_entry_id price_source_id price_series_id], options: "WITHOUT ROWID" do |t|
           t.integer :catalog_entry_id, null: false
           t.references :price_source, null: false, index: false, foreign_key: { on_delete: :restrict }
           t.references :price_series, null: false, index: false, foreign_key: { to_table: :price_series, on_delete: :restrict }
           t.integer :cents, null: false
           t.date :reported_on, null: false
           t.date :changed_on, null: false
           t.check_constraint "cents >= 0", name: "current_prices_cents_non_negative"
         end

         create_table :price_changes, primary_key: %i[catalog_entry_id price_source_id price_series_id recorded_on], options: "WITHOUT ROWID" do |t|
           t.integer :catalog_entry_id, null: false
           t.references :price_source, null: false, index: false, foreign_key: { on_delete: :restrict }
           t.references :price_series, null: false, index: false, foreign_key: { to_table: :price_series, on_delete: :restrict }
           t.date :recorded_on, null: false
           t.integer :cents
           t.check_constraint "cents IS NULL OR cents >= 0", name: "price_changes_cents_non_negative"
         end

         create_table :price_refresh_runs do |t|
           t.references :price_source, null: false, index: false, foreign_key: { on_delete: :restrict }
           t.date :run_on, null: false
           t.string :source_version
           t.string :status, null: false
           t.text :error
           t.datetime :started_at, null: false
           t.datetime :finished_at
           t.timestamps
           t.index %i[price_source_id run_on]
           t.check_constraint "status IN ('running', 'finished', 'skipped', 'failed')", name: "price_refresh_runs_status_known"
         end
       end
     end
     ```
     `t.references :price_series` infers the table `price_series` (the plural of "series" is "series"), but `to_table:` is given explicitly anyway. The foreign key's column is `price_series_id`. If `create_table` with a composite `primary_key` objects to `t.references` adding a bigint column, declare `t.integer :price_source_id, null: false` and `t.integer :price_series_id, null: false` and add the foreign keys with `t.foreign_key :price_sources, on_delete: :restrict` and `t.foreign_key :price_series, column: :price_series_id, on_delete: :restrict`. Then check AC-3.3's example.
  4. Run `bin/rails db:migrate` (development). It creates `storage/development_prices.sqlite3` and writes `db/prices_structure.sql`. Apply the "Schema noise" rule. Check by reading `db/prices_structure.sql` that `current_prices` and `price_changes` end in `WITHOUT ROWID` and that the file ends with the `INSERT INTO "schema_migrations"` line for `20261113100001`.
  5. Run `bin/rails db:test:prepare`, then `bin/rspec spec/config/prices_database_spec.rb spec/models/prices_record_spec.rb spec/backup_guards_spec.rb`: green.
  6. Commit: `feat(prices): a prices database with its five tables (#363)`. Stage `config/database.yml`, the migration, `db/prices_structure.sql`, `app/models/prices_record.rb` and the two specs.

- [ ] **T1.3 `WITHOUT ROWID` on both build paths, and the guard's negative control (AC-2.1 to AC-2.3).** Create `spec/prices_schema_spec.rb`:
  ```ruby
  require "rails_helper"
  require "open3"

  # Spec 081 decision 3 (ruled 2026-11-13): current_prices and price_changes are WITHOUT ROWID on a database loaded from
  # db/prices_structure.sql (a new instance, the test database) and on one built by the migrations (an upgraded instance).
  RSpec.describe "the prices schema keeps WITHOUT ROWID (spec 081 AC-2.1 to AC-2.3)", type: :model do
    LARGE = %w[current_prices price_changes].freeze
    INTERNAL = %w[schema_migrations ar_internal_metadata].freeze
    ADVICE = "a column change on SQLite (change_column, remove_column and the like) rebuilds the table without WITHOUT ROWID; " \
      "write a new migration that recreates it with options: \"WITHOUT ROWID\" (db/prices_migrate's first migration says how)".freeze

    # The tables a database's sqlite_master defines, name => sql.
    def definitions(rows) = rows.reject { |name, _| INTERNAL.include?(name) || name.start_with?("sqlite_") }.to_h

    # Each table that should be WITHOUT ROWID and isn't, or isn't and should be: [] when the schema is right.
    def rowid_problems(definitions)
      definitions.filter_map do |name, sql|
        without = sql.to_s.rstrip.end_with?("WITHOUT ROWID")
        "#{name}: #{without ? "is WITHOUT ROWID and shouldn't be" : "isn't WITHOUT ROWID; #{ADVICE}"}" if without != LARGE.include?(name)
      end
    end

    # A database built only by running db/prices_migrate's migrations, in a child Ruby process with Active Record alone.
    def migrated_database
      path = Pathname(Dir.mktmpdir("prices-migrated")).join("prices.sqlite3")
      script = <<~RUBY
        require "bundler/setup"
        require "active_record"
        ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ARGV[0])
        ActiveRecord::Migration.verbose = false
        ActiveRecord::MigrationContext.new(ARGV[1]).migrate
      RUBY
      _out, err, status = Open3.capture3(RbConfig.ruby, "-e", script, path.to_s, Rails.root.join("db/prices_migrate").to_s, chdir: Rails.root.to_s)
      raise "migrating failed: #{err}" unless status.success?

      path
    end

    def master_of(path)
      database = SQLite3::Database.new(path.to_s, readonly: true)
      database.execute("SELECT name, sql FROM sqlite_master WHERE type IN ('table', 'index') ORDER BY name")
    ensure
      database&.close
    end

    it "holds on the structure-loaded test database (AC-2.1)" do
      rows = PricesRecord.lease_connection.select_rows("SELECT name, sql FROM sqlite_master WHERE type = 'table' ORDER BY name")
      expect(rowid_problems(definitions(rows))).to be_empty
    end

    it "holds on a database built by the migrations, whose tables and indexes are the structure-loaded one's (AC-2.2)", :aggregate_failures do
      migrated = definitions(master_of(migrated_database))
      loaded = definitions(PricesRecord.lease_connection.select_rows("SELECT name, sql FROM sqlite_master WHERE type IN ('table', 'index') ORDER BY name"))

      expect(rowid_problems(migrated.select { |name, _| loaded.key?(name) && !name.start_with?("index_") })).to be_empty
      expect(migrated).to eq(loaded)
    end

    it "would notice either table without the option, naming it and the fix (AC-2.3, a negative control)" do
      rows = { "current_prices" => 'CREATE TABLE "current_prices" ("catalog_entry_id" integer, PRIMARY KEY ("catalog_entry_id"))',
               "price_changes" => 'CREATE TABLE "price_changes" ("a" integer, PRIMARY KEY ("a")) WITHOUT ROWID' }
      expect(rowid_problems(rows)).to eq([ "current_prices: isn't WITHOUT ROWID; #{ADVICE}" ])
    end
  end
  ```
  `rowid_problems` is given tables only (an index's `sql` has no `WITHOUT ROWID`): in AC-2.2's first expectation, filter `migrated` to tables, using `type` from `sqlite_master` rather than the name prefix if that reads more clearly. Constants inside `describe` may trip `RSpec/LeakyConstantDeclaration`; if so, make them `let`s or methods. **Red first:** before writing the spec, temporarily remove `options: "WITHOUT ROWID"` from `current_prices` in the migration and in `db/prices_structure.sql`, then rebuild the test database (`bin/rails db:test:prepare`). AC-2.1's and AC-2.2's examples must fail, naming `current_prices`. Put the option back, rebuild, and confirm green. Record the red run in the commit body. Commit: `test(prices): WITHOUT ROWID on the structure-loaded and the migrated database (#363)`.

- [ ] **T1.4 The prices schema names no collectible (AC-3.5), and the export is unchanged (AC-3.2).** Create `spec/prices_core_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "the prices schema is core (spec 081 decision 9, AC-3.5)", type: :model do
    it "names no collectible or source in its migrations, structure file or connection class, comments included", :aggregate_failures do
      files = Dir[Rails.root.join("db/prices_migrate/*.rb").to_s] + [ Rails.root.join("db/prices_structure.sql").to_s, Rails.root.join("app/models/prices_record.rb").to_s ]

      expect(files.size).to eq(3) # one migration so far, the structure file and the class; a new migration raises this
      expect(files.select { File.read(it).match?(/\b(mtg|scryfall|magic)\b/i) }).to be_empty
    end
  end
  ```
  For AC-3.2, add one example to the export's request spec that already downloads an export (find it with `git grep -n "collection/export" spec/requests ':!.kamal/secrets'`). After creating a source, a series and one current price through `PricesRecord.lease_connection` (the foreign keys need the first two) with the lot's `catalog_entry_id`, the downloaded document's `format_version` is 4 and its JSON has no key matching `/price(?!_paid)/` at any depth. Write a small recursive key collector in the example. Commit: `test(prices): the prices schema names no collectible, and the export holds no price (#363)`.

## Phase 2: The suite runs with two test databases (decision 12)

**Implements:** decision 12 · **Satisfies:** AC-1.2, AC-1.3, AC-6.9, and keeps every existing backup example green
**Files:** `spec/support/backup_helpers.rb`, `spec/backup_upgrade_spec.rb`, `spec/backup_boot_spec.rb`, `spec/backup_prices_spec.rb` (new)

- [ ] **T2.1 Child processes and helpers reach both databases.**
  1. Red: create `spec/backup_prices_spec.rb` with AC-1.2, AC-1.3 and AC-6.9:
     ```ruby
     require "rails_helper"

     RSpec.describe "the prices database in a prepared volume (spec 081 AC-1.2, AC-1.3, AC-6.9)", :backup, type: :model do
       def schema_files = %w[db/schema.rb db/prices_structure.sql].to_h { [ it, Digest::SHA256.file(Rails.root.join(it)).hexdigest ] }
       def prices_versions = Collector::Backup.release_schema_versions(Rails.root, "db/prices_migrate")

       def tables(path) = sqlite(path, readonly: true) { |db| db.execute("SELECT name FROM sqlite_master WHERE type = 'table'").flatten }

       it "creates and migrates the prices file on an empty volume, without touching the repository's schema files", :aggregate_failures do
         before = schema_files
         volume = scratch("volume")
         _out, err, status = app_command(volume.join("production.sqlite3"), "db:prepare")

         expect(status).to be_success, err
         prices = volume.join("production_prices.sqlite3")
         expect(Collector::Backup::Snapshot.new(prices).schema_versions).to match_array(prices_versions)
         expect(tables(prices)).to include("price_sources", "price_series", "current_prices", "price_changes", "price_refresh_runs")
         expect(schema_files).to eq(before)
       end

       it "creates the prices file beside a primary that has no prices file, and keeps the primary's rows (AC-1.3)", :aggregate_failures, :committed do
         seed_instance(lots: 2)
         volume = scratch("volume")
         primary = volume.join("production.sqlite3")
         FileUtils.cp(copy_of_instance, primary)
         rows = table_rows(primary)
         _out, err, status = app_command(primary, "db:prepare")

         expect(status).to be_success, err
         expect(volume.join("production_prices.sqlite3")).to exist
         expect(table_rows(primary).except("schema_migrations", "ar_internal_metadata")).to eq(rows.except("schema_migrations", "ar_internal_metadata"))
       end

       it "empties the prices database after a committed example (AC-1.5, decision 12)", :committed do
         PricesRecord.lease_connection.execute("INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('kept', 'Kept', 'x', 0, '2026-11-13', '2026-11-13')")
         clear_instance!
         expect(PricesRecord.lease_connection.select_value("SELECT count(*) FROM price_sources")).to eq(0)
       end

       it "gives each child command a SCHEMA path that doesn't exist yet (AC-6.9, the second half)" do
         paths = []
         allow(Open3).to receive(:capture3).and_wrap_original { |original, env, *rest, **kw| paths << File.exist?(env["SCHEMA"]); original.call(env, *rest, **kw) }
         2.times { app_command(scratch("volume").join("production.sqlite3"), "db:prepare") }
         expect(paths).to eq([ false, false ])
       end
     end
     ```
     The `clear_instance!` example is `:committed`, so its own `before` clears too. What it proves is that `clear_instance!` reaches the prices database. Simplify the `allow(...).and_wrap_original` example if RuboCop objects to its line length; keep the assertion. It fails: `app_command` sets only `DATABASE_URL`, so the child prepares the suite's own `storage/test_prices.sqlite3` and the volume gets no prices file.
  2. Green: edit `spec/support/backup_helpers.rb`:
     - `PRODUCTION_NAMES` gains `"prices" => "production_prices.sqlite3"`.
     - `app_command`:
       ```ruby
       # A child Rails process on a database file and its prices file beside it (spec 081 decision 12): an instance as a booted
       # one would be. DATABASE_URL reaches the primary only, so the prices database gets PRICES_DATABASE_URL: without it the
       # child would open the suite's own test prices file. Each command gets its own SCHEMA path, absent when it starts: Rails
       # returns SCHEMA as every database's schema file, so both databases are built by their migrations, any dump lands in the
       # scratch directory, and neither db/schema.rb nor db/prices_structure.sql is written (AC-6.9).
       def app_command(database, *command, prices: prices_beside(database), environment: {})
         env = { "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{database}", "PRICES_DATABASE_URL" => "sqlite3:#{prices}",
           "SCHEMA" => scratch_path("schema-#{SecureRandom.hex(4)}.dump").to_s }.merge(environment)
         Open3.capture3(env, Rails.root.join("bin/rails").to_s, *command, chdir: Rails.root.to_s)
       end

       # The prices file a volume holds beside +database+: production_prices.sqlite3 beside production.sqlite3, or
       # <name>_prices.sqlite3 beside any other name.
       def prices_beside(database)
         path = Pathname(database)
         path.dirname.join(path.basename.to_s == "production.sqlite3" ? "production_prices.sqlite3" : "#{path.basename(".sqlite3")}_prices.sqlite3")
       end
       ```
     - `clear_instance!` empties both databases. Run the same loop on `PricesRecord.lease_connection` (no FTS tables there).
     - `instance_prices_database = Collector::Backup::Databases.configured.prices` (it needs T3.1's `Databases#prices`; until then, `Rails.root.join(ActiveRecord::Base.configurations.configs_for(env_name: "test", name: "prices").database)`). Switch to `Databases.configured.prices` in T3.1.
     - `with_restored_instance(path, prices: prices_beside(path))` reconnects `PricesRecord` the same way as `ActiveRecord::Base`, and restores both in `ensure`. Each new config keeps its name, because `HealthController#check_database` (`health_controller.rb:18`) finds pools by name, and a bare hash would be named "primary":
       ```ruby
       def with_restored_instance(path, prices: prices_beside(path))
         pairs = [ [ ActiveRecord::Base, path ], [ PricesRecord, prices ] ].map { |klass, file| [ klass, klass.connection_db_config, file ] }
         pairs.each do |klass, config, file|
           klass.connection_pool.disconnect!
           klass.establish_connection(ActiveRecord::DatabaseConfigurations::HashConfig.new(config.env_name, config.name, config.configuration_hash.merge(database: file.to_s)))
         end
         yield
       ensure
         pairs&.each do |klass, config, _file|
           klass.connection_pool.disconnect!
           klass.establish_connection(config)
         end
       end
       ```
       `PricesRecord.establish_connection(config)` with the original `DatabaseConfig` is how `connects_to` registered it; check with the restored-instance specs that the role is still `:writing`. If `establish_connection` on an abstract class with `connects_to` misbehaves, use `PricesRecord.connection_handler.establish_connection(config, owner_name: PricesRecord, role: :writing)`.
  3. `spec/backup_upgrade_spec.rb:27`: `db:migrate VERSION=` becomes `db:migrate:primary VERSION=`. With two databases, Rails' unnamed `db:migrate` runs only pending versions (`database_tasks.rb:241-257`), so the rollback would silently do nothing. Add to its last expectations that `db/prices_structure.sql` is unchanged too, and that `volume.join("production_prices.sqlite3")` exists after its `db:prepare`. That is a version 1 restore's first start creating the prices database (AC-5.2).
  4. `spec/backup_boot_spec.rb:7`: add `"PRICES_DATABASE_URL" => "sqlite3:#{scratch_path("boot_prices.sqlite3")}"` to `production`'s environment.
  5. Run, one at a time: `bin/rspec spec/backup_prices_spec.rb`, then `bin/rspec spec/backup_*_spec.rb spec/lib/collector/backup`. All are green, except examples that only T3.x makes pass; there should be none yet, because the backup code is unchanged. Commit: `test(backup): child processes and helpers reach both test databases (#363)`.

## Phase 3: Backup format version 2 (the file contract first)

**Implements:** FR-3, FR-4; decisions 6 to 8 · **Satisfies:** AC-4.1 to AC-4.8, AC-5.1 to AC-5.9, AC-6.2
**Files:** `lib/collector/backup.rb`, `lib/collector/backup/{databases,manifest,archive,snapshot,create,restore}.rb`, `lib/tasks/backup.rake`, their specs

- [ ] **T3.1 The version 2 manifest and archive, and the pieces both commands share.**
  1. Red, `spec/lib/collector/backup/manifest_spec.rb`. Keep the version 1 examples, with `fields` still version 1, and add:
     ```ruby
     let(:prices) { { "schema_version" => "20261113100001", "snapshot_bytes" => 2048, "snapshot_sha256" => "b" * 64, "counts" => { "current_prices" => 3, "price_changes" => 5 } } }

     it "writes version 2 with the prices member and reads it back (spec 081 AC-4.2)", :aggregate_failures do
       manifest = described_class.new(**fields, backup_format_version: 2, prices:)

       expect(JSON.parse(manifest.to_json).keys).to match_array(%w[backup_format_version taken_at schema_version snapshot_bytes snapshot_sha256 counts prices])
       expect(described_class.parse(manifest.to_json)).to eq(manifest)
       expect(manifest.entries).to eq([ [ "primary.sqlite3", 4096, "a" * 64 ], [ "prices.sqlite3", 2048, "b" * 64 ] ])
     end

     it "keeps version 1 as it was: no prices member, one entry" do
       expect(described_class.new(**fields).entries).to eq([ [ "primary.sqlite3", 4096, "a" * 64 ] ])
     end

     it "refuses a version 2 manifest without prices, a version 1 with them, and malformed prices", :aggregate_failures do
       [ JSON.generate(fields.merge(backup_format_version: 2)), JSON.generate(fields.merge(prices:)),
         JSON.generate(fields.merge(backup_format_version: 2, prices: prices.merge("counts" => { "current_prices" => 1 }))),
         JSON.generate(fields.merge(backup_format_version: 2, prices: prices.merge("snapshot_sha256" => "x"))) ].each do |text|
         expect { described_class.parse(text) }.to raise_error(described_class::Invalid), text
       end
     end
     ```
     `archive_spec.rb`: the version 1 examples stay, and `fields` stays version 1. Add:
     - Version 2 lists `manifest.json primary.sqlite3 prices.sqlite3` with `tar -tzf`.
     - `.read` yields `[chunk, name]` pairs that rebuild both payloads.
     - Reading a version 2 archive whose prices entry is missing, cut short or changed refuses as not a backup, incomplete or changed (AC-5.5). Build those with `raw_archive` and a hand-written manifest.
  2. Green:
     - `lib/collector/backup.rb`: `FORMAT_VERSIONS = [ 1, 2 ].freeze`. `release_schema_versions(root = Rails.root, directory = "db/migrate")` reads `root.join(directory, "**/[0-9]*_*.rb")`; update its comment: "the primary's migrations by default; `db/prices_migrate` for the prices database (spec 081 decision 8)". Also `self.prices_phrase(counts)` returns `"#{n} current #{n == 1 ? "price" : "prices"} and #{m} price #{m == 1 ? "change" : "changes"}"`.
     - `lib/collector/backup/databases.rb`: `def prices = @paths["prices"]`, documented as "the prices database's path, nil when the configuration has none (a version 1 world in a spec)". Update the class comment and `occupied`'s comment: "the five databases".
     - `lib/collector/backup/manifest.rb`:
       ```ruby
       Manifest = Data.define(:backup_format_version, :taken_at, :schema_version, :snapshot_bytes, :snapshot_sha256, :counts, :prices)

       class Manifest
         PRICES_MEMBERS = %w[schema_version snapshot_bytes snapshot_sha256 counts].freeze
         PRICES_COUNT_NAMES = %w[current_prices price_changes].freeze

         # Version 1 has no prices member (spec 081 decision 6).
         def initialize(prices: nil, **members) = super

         def self.for(snapshot, taken_at:, prices: nil)
           new(backup_format_version: FORMAT_VERSION, taken_at: taken_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
             schema_version: snapshot.schema_versions.max_by(&:to_i), snapshot_bytes: snapshot.path.size,
             snapshot_sha256: Digest::SHA256.file(snapshot.path).hexdigest, counts: snapshot.counts,
             prices: prices && { "schema_version" => prices.schema_versions.max_by(&:to_i), "snapshot_bytes" => prices.path.size,
               "snapshot_sha256" => Digest::SHA256.file(prices.path).hexdigest, "counts" => prices.counts(PRICES_COUNT_NAMES) })
         end

         # The archive's snapshot entries this manifest describes, in archive order: [name, bytes, sha256].
         def entries
           [ [ Archive::SNAPSHOT, snapshot_bytes, snapshot_sha256 ] ] +
             (prices ? [ [ Archive::PRICES, prices["snapshot_bytes"], prices["snapshot_sha256"] ] ] : [])
         end

         def to_json(*) = JSON.pretty_generate(to_h.then { prices ? it : it.except(:prices) })
       end
       ```
       In `parse`, the expected keys depend on the version: `members.map(&:to_s) - (version == 1 ? [ "prices" ] : [])`. In `valid?`, add the prices rule: for version 1, `prices.nil?`. For version 2, `prices` is a Hash whose keys are `PRICES_MEMBERS`, with `schema_version` a String, `snapshot_bytes` a non-negative Integer, `snapshot_sha256` 64 hex, and `counts` a Hash whose keys are `PRICES_COUNT_NAMES` with Integer values. Update the class comment (versions 1 and 2) and `COUNT_NAMES`' neighbours.
     - `lib/collector/backup/archive.rb`:
       - `SNAPSHOT = HELD.fetch("primary")` and `PRICES = HELD.fetch("prices")`, replacing the literal `SNAPSHOT` (M6: the guard's `HELD` is what the archive uses).
       - `write(path, manifest:, snapshot:, prices: nil)` adds the prices entry after the primary when `prices` is given. It raises `ArgumentError` unless `manifest.entries.size` matches the files given.
       - `read_entries` replaces the single-snapshot block with a loop over `manifest.entries`. A manifest of an unknown version has no entries, so keep today's behaviour of reading the next entry's size and refusing at the end: read entries while `entry_size` finds another ustar file, with `[ SNAPSHOT, PRICES ]` as the only acceptable names in that order, and check the count and names against `manifest.entries` at the end. Each entry's bytes are digested, and `sink.call(chunk, name)` is called for each chunk.
       - At the end, check that every entry's digest and size equal the manifest's. Any mismatch raises `changed(name)`. A missing entry, where the gzip ends with an end block where an entry was expected, raises `not_a_backup(nil, name)`.
       - `Result` stays `Data.define(:manifest, :sha256, :bytes)`, for the primary.
       - Update the class comment: "manifest.json, primary.sqlite3 and, from version 2, prices.sqlite3 (spec 081 decision 6)".
     - `snapshot.rb` `counts(names = Manifest::COUNT_NAMES)` (moved here from T3.2, because `Manifest.for` and `manifest_for(prices:)` call it):
       ```ruby
       # Counts only, never a name or an address (hosted-door rule 2, AC-1.7): the primary's three tables unless +names+ says
       # otherwise (the prices database's, spec 081 decision 6). Cross-tenant by nature: it counts the instance.
       def counts(names = Manifest::COUNT_NAMES)
         with(readonly: true) { |database| names.to_h { |table| [ table, database.get_first_value("SELECT COUNT(*) FROM #{table}") ] } }
       end
       ```
     - `restore.rb` `extract` (`:99`) writes only the primary's chunks, until T3.4 gives prices its own file. Without this, T3.3's version 2 files would put the prices bytes into the primary's temporary file:
       ```ruby
       Archive.read(@file) { |chunk, name| file.write(chunk) if name == Archive::SNAPSHOT }
       ```
     - `spec/support/backup_helpers.rb`: `unpack_snapshot(archive, name = "unpacked.sqlite3", entry: "primary.sqlite3")` writes only the chunks of `entry`, as in `{ |chunk, entry_name| file.write(chunk) if entry_name == entry }`. `manifest_for` and `archive_of` take `prices:` (a path) and build a version 2 manifest when it is given, and version 1 otherwise.
     - The "unknown version" fixtures at `archive_spec.rb:152`, `:160` and `restore_spec.rb:197` use version 2, which is now known. Change them to 99, and the expected text to "this release restores versions 1, 2." (`Archive.unknown_version` joins with ", "). `:160` expects "incomplete" for a cut-short unknown-version file; with 99, check that it still reads "incomplete".
  3. `bin/rspec spec/lib/collector/backup/manifest_spec.rb spec/lib/collector/backup/archive_spec.rb` is green, then the rest of `spec/lib/collector/backup` (Create still writes version 1 until T3.3: `FORMAT_VERSION` is 2 now, so `Manifest.for` writes version 2 without `prices`. That is invalid, so T3.1 keeps Create working by having `Manifest.for` write `backup_format_version: prices ? 2 : 1`. T3.3 always passes `prices`, after which version 1 is never written). Commit: `feat(backup): backup format version 2, with a prices.sqlite3 entry (#363)`.

- [ ] **T3.2 `Snapshot`'s counts and the orphan count of `WITHOUT ROWID` tables (AC-4.5, decision 3).**
  1. Red, `spec/lib/collector/backup/snapshot_spec.rb`:
     - `counts(%w[current_prices price_changes])` on a copy of the test prices database (`Snapshot.take(source: Databases.configured.prices, into: …)`) returns 2 and 3, after inserting a source, a series, 2 current prices and 3 changes **into the copy** through `sqlite(copy)`. The example isn't `:committed`, so rows written through Active Record would not be in the source the copy is taken from.
     - A prices copy where three `price_changes` rows name a missing series (insert them with `PRAGMA foreign_keys = OFF` on the copy through `sqlite`) raises `OrphanRows` with `count == 3`.
     - A primary copy with one row having two broken keys still counts 1, as today.
  2. Green, `snapshot.rb` (`counts(names)` already exists from T3.1). In `verify!`, count rows of rowid tables once each, and each violation of a `WITHOUT ROWID` table (whose rowid SQLite reports as null) on its own (spec 081 decision 3):
     ```ruby
     results = database.execute("PRAGMA foreign_key_check")
     count = results.select { it[1] }.map { it.first(2) }.uniq.size + results.count { it[1].nil? }
     raise OrphanRows.new(count) if count.positive?
     ```
     Update the comment above it.
  3. Switch `instance_prices_database` in the helpers to `Collector::Backup::Databases.configured.prices`. Commit: `feat(backup): count the orphans of WITHOUT ROWID tables (#363)`.

- [ ] **T3.3 `backup:create` holds both databases (AC-4.1 to AC-4.8).**
  1. Red, `spec/lib/collector/backup/create_spec.rb`:
     - Change the existing examples:
       - `:18`, the report's lines: the schema line becomes `Schema version: <v>; prices <pv>`, and the counts line gains the prices phrase.
       - `:184`: the refusal says "(twice the two databases' sizes)".
       - `:129`, the killed run, runs in a child process with no Rails, so pass `prices_source:` as an argument, as `source:` is passed. Add the prices temporary file to what it expects to find: the prices `.partial` exists only after `:snapshot_written` (it is created after the primary is taken). At the existing kill point the leftovers are still the one primary `.partial`, so `leftovers.size == 1` holds.
     - Change `:21` ("holds the manifest and a rollback-journal snapshot…") to expect `backup_format_version` 2 and a `prices` member that agrees with `prices.sqlite3`. Change `:37` ("nothing but the two files") to the three files `manifest.json primary.sqlite3 prices.sqlite3` (AC-4.1).
     - Add these examples:
       - Seeding two price rows through `PricesRecord.lease_connection` (in a `:committed` example) makes `prices.sqlite3` hold them, in rollback-journal mode, passing `verify!` (AC-4.1, AC-4.3).
       - The report reads `Schema version: <v>; prices <pv>` and `Holds: 1 account, 1 user and 3 lots; 2 current prices and 0 price changes` (AC-4.7; the counts follow the seed).
       - `prices_source:` pointing at a missing file refuses with `There is no prices database at <path>.` / `Start Collector once on this release, which creates it, then run this again.` and leaves the directory empty (AC-4.4).
       - A damaged prices source (`damage_table!` on a copy, passed as `prices_source:`) refuses with spec 030's damage message, `The prices database reports damage, so no backup was made.`, and leaves nothing (AC-4.5).
       - A prices source whose `price_changes` holds three rows naming a missing series refuses with `The prices database fails its foreign-key check (3 rows), so no backup was made.` (AC-4.5).
       - With `free_space:` returning one byte less than `2 * (primary.size + prices.size)`, it refuses, naming that need (AC-4.6).
       - AC-4.8 reuses the writers of `create_spec.rb:89`, with a new checkpoint `:prices_starting`, fired just before the prices `VACUUM INTO`, so the prices writer's commits are measured while the prices snapshot is taken. Add a third writer kind, `prices`, to `BackupHelpers::WRITER`, which inserts `price_changes` rows through its own `SQLite3::Database` on the prices file, and assert its commits keep going under 5 s while the backup runs, as the existing example asserts for `pairs` and `lots`. The writer needs a source and a series row. Seed them first in the example.
  2. Green, `create.rb`:
     - `initialize(directory:, source: Databases.configured.primary, prices_source: Databases.configured.prices, …)` sets `@prices_source = Pathname(prices_source)`.
     - `check_destination`: after `raise no_source unless @source.file?`, add `raise no_prices unless @prices_source.file?`. The need becomes `2 * (@source.size + @prices_source.size)`, and the refusal says "(twice the two databases' sizes)".
     - `make`: a second temporary `prices_file = @directory.join("#{final.basename(".tar.gz")}.prices.sqlite3.#{token}.partial")`, created private after `:snapshot_written`. Take, journal-switch and verify it right after the primary, with `@checkpoint.call(:prices_starting)` before taking it and `@checkpoint.call(:prices_written)` after. The manifest is `Manifest.for(snapshot, taken_at:, prices: Snapshot.new(prices_file))`, and the archive is `Archive.write(archive_file, manifest:, snapshot: snapshot_file, prices: prices_file)`. The `ensure` also removes `prices_file`. `PARTIAL` must match the new name: `/\Acollector-backup-\d{8}T\d{6}Z\.(?:tar\.gz|sqlite3|prices\.sqlite3)\.\h{16}\.partial(?:-journal|-wal|-shm)?\z/`. Update the comment on `PARTIAL`.
     - `translating`: a `Snapshot::Damaged` or `OrphanRows` raised while the prices file is handled must name the prices database. Wrap the prices steps in `rescue Snapshot::Damaged => e; raise PricesDamaged …`, or keep a `@stage` (`:primary` or `:prices`) that `translating` reads to choose "The database" or "The prices database". Use the `@stage` instance variable: it is one line in `make` before each stage.
     - `Result` gains `prices_schema_version` and `prices_counts`. `report` gives `Schema version: #{schema_version}; prices #{prices_schema_version}` and `Holds: #{Backup.counts_phrase(counts)}; #{Backup.prices_phrase(prices_counts)}`.
     - `no_prices` returns `Refusal.new("There is no prices database at #{@prices_source}.", "Start Collector once on this release, which creates it, then run this again.")`.
     - The class comment says "of the primary and prices databases (spec 081 decision 7); the two snapshots are taken one after the other, not at one moment".
  3. `script/backup/measure.rb:71` passes nothing new: its process has Rails, so `prices_source:` defaults to the configured file. Check that the development prices database exists there (`bin/rails db:prepare`), and otherwise leave the call as it is. `lib/tasks/backup.rake`: the create task's `desc` reads `Back up the primary and prices databases into DIRECTORY, …`. Update the file's comment.
  4. `bin/rspec spec/lib/collector/backup/create_spec.rb`, then `spec/lib/collector/backup spec/backup_*_spec.rb`, one at a time. Commit: `feat(backup): backup:create holds the prices database (#363)`.

- [ ] **T3.4 `backup:restore` restores versions 1 and 2, both databases or neither (AC-5.1 to AC-5.8).**
  1. Red, `spec/lib/collector/backup/restore_spec.rb`:
     - `:25`: the volume's children become `%w[production.sqlite3 production_prices.sqlite3]`. The prices file's rows equal the source's (`table_rows`), and it is in rollback-journal mode (AC-5.1).
     - The report includes `(prices <pv>)` and `; 0 current prices and 0 price changes` (or the seeded counts).
     - A version 1 archive (`archive_of(copy_of_instance)`, with no `prices:`) places only `production.sqlite3`. Its report ends the counts sentence and adds `The backup holds no prices; Collector's first start creates an empty prices database.` (AC-5.2).
     - A volume holding only `production_prices.sqlite3`, or only `production_prices.sqlite3-wal`, is refused as not empty, naming the file. When there is a prices file and no primary, the advice is the AC-5.9 text below (AC-5.3).
     - Version 2 archives built by `archive_of(primary_copy, prices: prices_copy)` around a damaged prices copy, around one with a foreign-key orphan, and around one with an extra `schema_migrations` version `29991231000000`. Each is refused with the matching message, and the volume holds no database and no temporary file (AC-5.4). The newer-release message is `<file> was taken by a newer release of Collector (prices schema version 29991231000000; this release has <pv>).` / `Restore it onto that release or a newer one.`
     - A version 2 archive whose prices counts in the manifest differ (`prices: { counts: … }` override) is refused as `The restored database doesn't match the backup's counts.` (AC-5.4).
     - AC-5.6: run with a `checkpoint:` that, at `:prices_placed`, creates `production.sqlite3` in the volume (as `restore_spec.rb:91` does for the primary). The restore refuses as not fresh, and the volume then holds only that planted file: the prices file it placed was removed.
     - AC-5.7: `stub_const("Collector::Backup::FORMAT_VERSIONS", [ 1 ])` plus `stub_const("Collector::Backup::FORMAT_VERSION", 1)`, then restoring a version 2 file is refused with `… uses backup format version 2; this release restores version 1.`.
     - AC-5.8: extend the existing "never creates the primary's path" example (`:104`) to the prices path too.
     - Change the existing examples:
       - `:42`: the report sentence "3 lots." is now "3 lots; 0 current prices and 0 price changes.".
       - `:60`: the `contain_exactly` list gains `production_prices.sqlite3`.
       - `:97`: on a primary clash, the refusal still names only `production.sqlite3`, because the clash block removes the placed prices file first (below).
       - `:110`: the killed child passes `release_prices_versions:` as JSON beside `release_versions:`, and builds its `Databases` with `"prices" => volume.join("production_prices.sqlite3")`. At `:snapshot_ready` the volume holds the two temporary files, and nothing is placed yet.
     - `databases_spec.rb:36`: add `collector-restore-prices.partial` and its `-journal` to the files `occupied` ignores.
  2. Green, `restore.rb`:
     - `TEMPORARY_PRICES = "collector-restore-prices.partial".freeze`.
     - `initialize(…, release_versions: Backup.release_schema_versions, release_prices_versions: Backup.release_schema_versions(Rails.root, "db/prices_migrate"), …)`.
     - `refuse_without_room`: `need = manifest.entries.sum { it[1] } + MARGIN`.
     - `call`: after reading, remove both temporary files (with `RESTORE_SUFFIXES`). `extract` writes each entry to its temporary file (`{ |chunk, name| (name == Archive::PRICES ? prices_io : primary_io).write(chunk) }`) and checks each size against the manifest's entry. `prepare` checks the primary as today. When `manifest.prices`, it then checks the prices temporary file: `Snapshot#verify!`, the schema check against `@release_prices_versions` (its own message), `rollback_journal!`, and `counts(Manifest::PRICES_COUNT_NAMES) == manifest.prices["counts"]`. It does not run `end_sessions!`.
     - Placing:
       - `:snapshot_ready` fires once both temporary files are prepared, before anything is placed, as today.
       - `Backup.fsync_file` both temporary files.
       - When `manifest.prices`, publish the prices temporary file to `@databases.prices` (on a clash, `raise not_fresh`), set `prices_placed = true` and call `@checkpoint.call(:prices_placed)`.
       - Then publish the primary. Its clash block first removes the placed prices file and its sidecars, then raises `not_fresh`. The refusal then lists only what was there before the run, and "Nothing was changed" stays true.
       - On any other exception after `prices_placed` and before the primary is placed, the `ensure` removes `@databases.prices` and its sidecars. That file is the run's own, because the volume was fresh and `publish` never replaces a file.
       - The archive's entries map to the volume's paths through `HELD`: `HELD.key(Archive::PRICES)` is `"prices"`, read with a `Databases#path(name)` (`@paths.fetch(name)`). Add `path(name)` in this task, documented.
       - When `manifest.prices` is set and `@databases` has no `prices` path, raise `ArgumentError`: a configuration without a prices database is a programming error, not an operator's.
     - `not_fresh`: when `occupied` includes the prices file or any of its sidecars, and neither the primary nor any of its sidecars, the advice is `It may be the prices database of a restore that stopped: remove <name> and its -wal, -shm and -journal files, then restore again. Never start Collector on this volume as it is (#375).` Otherwise the advice is unchanged.
     - `Result#report`: with `manifest.prices`, the second line reads `Taken … at schema version X (prices Y); it holds #{counts}; #{Backup.prices_phrase(…)}. Compare …`. Without it, the second line is as today, plus the sentence `The backup holds no prices; Collector's first start creates an empty prices database.`
     - Update the class comment: two temporary files, prices placed first and removed on failure, the killed case, and `@see file:release-and-deploy.md`.
  3. `script/backup/measure.rb:78`: `Databases.new("primary" => volume.join("production.sqlite3"), "prices" => volume.join("production_prices.sqlite3"))`.
  4. `bin/rspec spec/lib/collector/backup/restore_spec.rb`, then `spec/lib/collector/backup spec/backup_*_spec.rb`, one at a time. Commit: `feat(backup): backup:restore brings the prices database back, or neither (#363)`.

- [ ] **T3.5 A killed restore, and the round trip with price rows (AC-5.9, AC-6.2).**
  1. `restore_spec.rb`, AC-5.9:
     - Use `run_killed_at(:prices_placed, <code>, archive, volume)`, modelled on `restore_spec.rb:110`, where the code builds `Collector::Backup::Restore` with `checkpoint: STOP_HERE` and the volume's `Databases`. The child prelude has no Rails, so pass `release_versions:` and `release_prices_versions:` as JSON arguments, the way `:110` passes them today.
     - Afterwards, the volume holds `production_prices.sqlite3` and no `production.sqlite3`.
     - A second restore is refused, and its advice names the file and `#375`.
     - After the file and its sidecars are deleted, a third restore succeeds as in AC-5.1.
  2. `spec/backup_prices_spec.rb`, AC-6.2, `:committed`:
     - Seed with `seed_instance` and `seed_session`, plus, through `PricesRecord.lease_connection`, one source, two series, three current prices and four price changes, one with null `cents`.
     - Run `create_backup`, then `restore_backup` onto a fresh `scratch("volume")`.
     - `table_rows` of the restored prices file equals `table_rows(Databases.configured.prices)` table by table, and the restored primary equals the source except the four cleared tables (copy the comparison of `restore_spec.rb:25`).
  3. Commit: `test(backup): a killed restore, and a round trip that carries price rows (#363)`.

## Phase 4: The upgrade proof and the container smoke cover the prices file

**Implements:** FR-5; decision 10 · **Satisfies:** AC-6.3 to AC-6.8, AC-1.2 and AC-1.3 in production
**Files:** `script/upgrade/{release,guard,rules,engine,harness}.rb`, `script/upgrade/seeds/next.rb`, `spec/support/upgrade_fakes.rb`, `bin/backup-smoke`, `spec/script/upgrade/*_spec.rb`

- [ ] **T4.1 The migration guard and the expected changes read `db/prices_migrate/` (AC-6.7, AC-6.8).**
  1. Red:
     - `spec/script/upgrade/release_spec.rb`: `migration_files(ref, "db/prices_migrate")` lists a sandbox tag's prices migrations, and the default argument still lists `db/migrate`.
     - `guard_spec.rb`: in the git sandbox, a tag with `db/prices_migrate/20261113100001_x.rb` that the work tree edits fails, naming the file. Deleting it fails, naming it too.
     - `expected_changes_spec.rb`: an entry whose `migration` is a version from `db/prices_migrate/` loads as live. One naming a version in neither directory errors with `… is not a file in db/migrate/ or db/prices_migrate/`.
  2. Green:
     - `release.rb`: `MIGRATION_DIRECTORIES = %w[db/migrate db/prices_migrate].freeze` (with a comment citing spec 081 decision 10). Add `def migration_files(ref, directory = "db/migrate")` and `def migration_versions(ref, directory = "db/migrate")`, and `def all_migration_versions(ref) = MIGRATION_DIRECTORIES.flat_map { migration_versions(ref, it) }`. A ref without `db/prices_migrate/` gives `[]`: `git ls-tree` prints nothing for a missing path.
     - `guard.rb`: `released_files(tag) = Release::MIGRATION_DIRECTORIES.flat_map { @release.migration_files(tag, it) }`. Update the header comment.
     - `rules.rb`: the "not a file in db/migrate/" message names both directories.
     - `harness.rb`: **`working_versions` stays `db/migrate` only**, because `compare` (`harness.rb:303`) checks the primary's `schema_migrations` against it, and a prices version there would fail every upgrade. Add `working_prices_versions` for `db/prices_migrate`. Only `ExpectedChanges.load` gets the union: `current_versions: working_versions + working_prices_versions` and `previous_versions: @release.all_migration_versions(@plan[:ref])`. `verify_old` and `compare` keep using `migration_versions(ref)` (the default directory) for the primary.
  3. Commit: `feat(upgrade): the migration guard and expected changes cover db/prices_migrate (#363)`.

- [ ] **T4.2 The harness copies, checks and compares the prices file (AC-6.4, AC-6.5).**
  1. Red:
     - `spec/support/upgrade_fakes.rb`: a `databases:` entry may be a Hash `{ primary:, prices: }`. `copy_database` copies `primary` to `production.sqlite3` and, when given, `prices` to `production_prices.sqlite3`, and returns the names it copied.
     - `spec/script/upgrade/harness_spec.rb`:
       - (a) The default scenario (a previous release with no `db/prices_migrate/` at its tag) needs "upgraded" and "next" entries carrying a prices file built by `seeded_prices(name, versions)`. That helper is a new SQLite file with the five tables (reuse the `CREATE TABLE` statements read from `db/prices_structure.sql`) and its `schema_migrations`. The "work" commit of `build_history` adds `db/prices_migrate/20261113100001_create_price_tables.rb`.
       - Expect `OK`, and expect the output to name `prices: … tables, WITHOUT ROWID` (or the exact line T4.2 prints).
       - (b) An upgraded entry with no prices file fails with `the upgraded volume holds no production_prices.sqlite3`.
       - (c) An upgraded prices file missing the working tree's prices version fails, naming it.
       - (d) An upgraded prices file where `current_prices` isn't `WITHOUT ROWID` fails, naming the table.
       - (e) A previous tag that has `db/prices_migrate/`, with old and upgraded prices files whose `price_changes` differ by one row, fails with the comparison's `FAIL price_changes` line (AC-6.5).
       - (f) The same tag where both prices files are equal passes and prints the prices comparison table.
       - (g) The backup leg: a restored entry without a prices file fails as in (b), and with an equal one passes.
       - (h) When the previous tag has `db/prices_migrate/` but the old entry has no prices file, it fails with `the previous release should have made production_prices.sqlite3`.
       - (i) An `expected_changes.yml` entry for a prices table: with a previous release that has prices, and the difference it names in `price_changes`, the run passes and the primary's report shows no unmatched entry (M1).
       - (j) A `seed_exceptions.yml` `next:` entry for a primary table doesn't fail the prices coverage.
       - In each scenario, the "next" database has a prices file whose tables all hold a row, or the coverage rule names the empty one.
     - `spec/script/upgrade/engine_spec.rb`: `copy_database`'s `ls`/`cp` commands now take `production_prices.sqlite3` and its sidecars when listed. The allowlist example (AC-8.3) still passes.
  2. Green:
     - `engine.rb` `copy_database`: `files = listing.grep(/\Aproduction(?:_prices)?\.sqlite3(?:-wal|-shm)?\z/)`. It still requires `production.sqlite3`. Update its comment: "the primary and the prices database files".
     - `harness.rb`:
       - Add `PRICES_FILE = "production_prices.sqlite3".freeze` and `PRICES_WITHOUT_ROWID = %w[current_prices price_changes].freeze`, each with a comment citing spec 081 decisions 3 and 10.
       - `stop_and_snapshot` also consolidates the prices file when the copy holds it: `@prices[label] = Snapshot.open(Snapshot.consolidate(copies, PRICES_FILE, File.join(@scratch, "#{label}_prices.sqlite3")))`, or `nil` when it is absent. It still returns the primary.
       - `prices_at_previous? = @release.migration_versions(@plan[:ref], "db/prices_migrate").any?`, computed once after `fetch_previous`, because for an explicit image without a version, `settle_version` sets `@plan[:ref]` only during the fetch. When `@plan[:ref]` is still nil, it is false.
       - In `verify_old`, if `prices_at_previous?`, `@prices["old"]` must exist (else fail with (h)'s message), and its `schema_migrations` must equal the tag's prices versions (`AC-2.1` wording, naming the prices database).
       - Add `check_prices(label, old_label)`. It fails unless:
         - `@prices[label]` exists (message (b), with the label's volume role);
         - its `schema_migrations` covers the working tree's prices versions and the old prices database's;
         - `Compare.integrity` is empty;
         - each `PRICES_WITHOUT_ROWID` table's `sql` ends in `WITHOUT ROWID`.
         It prints `prices: <n> tables, schema <latest>, WITHOUT ROWID on current_prices and price_changes`. When `@prices[old_label]` exists, it runs `Compare.new(@prices[old_label], @prices[label], expected: @changes.live).call`, prints its lines, and fails on `!ok?` naming "the prices database".
       - Call `check_prices("upgraded", "old")` from `upgrade` after `compare`, and `check_prices("restored", "old")` from `backup_leg` after its `compare`.
       - **Each comparison gets the expected changes of its own database.** `Compare#call` resets `matched` on every entry it is given (`compare.rb:82`) and reports the unmatched ones (`:177`), so one list shared by both comparisons fails whichever database lacks the entry's table. Add `def changes_for(db) = @changes.live.select { Compare.tables(db).include?(it.table) }`, written against the old database (whose tables a dropped-table entry names). Pass `expected: changes_for(old)` to the primary's `Compare.new` in `compare` and `expected: changes_for(@prices[old_label])` to the prices one. An entry whose table is in neither old database matches nothing, and the primary's report flags it as unmatched, as today.
       - **Seed exceptions likewise.** `SeedExceptions.coverage` flags a listed table that its database doesn't have (`rules.rb:88`). Give each call `entries.select { Compare.tables(db).include?(it.table) }`, and fail once, in `next_release`, for a listed table that is in neither database, with the existing message. Apply this to `verify_old` and `next_release` for the primary and for prices.
       - In `next_release`, run the coverage on `@prices["next"]` too, and fail when `@prices["next"]` is missing.
       - In `verify_old`, when `prices_at_previous?`, also run the coverage on `@prices["old"]` (decision 10: the old prices database is checked as the primary is).
       - Update the header comment, `backup_leg`'s comment (no longer "the backup holds the primary only"; a version 1 backup's restored instance gets its prices file from its first start) and `stop_and_snapshot`'s.
  3. `bin/rspec spec/script/upgrade`. Commit: `feat(upgrade): the upgrade proof checks and compares the prices database (#363)`.

- [ ] **T4.3 The next release's seed fills the prices tables (AC-6.6).**
  1. Red, `spec/script/upgrade/seeds_spec.rb`, a new example:
     ```ruby
     it "fills every table of the prices database, except those listed under next (spec 081 AC-6.6)" do
       run_seed("next.rb")
       tables = Rails.root.join("db/prices_structure.sql").read.scan(/^CREATE TABLE (?:IF NOT EXISTS )?"([^"]+)"/).flatten - %w[schema_migrations ar_internal_metadata]
       listed = Upgrade::SeedExceptions.load(seeds.join("../seed_exceptions.yml"), "next").entries
       prices = PricesRecord.lease_connection.raw_connection
       prices.results_as_hash = false
       problems, = Upgrade::SeedExceptions.coverage(prices, listed, label: "next", seed: "script/upgrade/seeds/next.rb", only: tables)
       expect(problems).to be_empty
     ensure
       prices&.results_as_hash = true
     end
     ```
     Check the regex against `db/prices_structure.sql`'s actual `CREATE TABLE` lines and adjust it if Rails writes them differently.
  2. Green: append to `script/upgrade/seeds/next.rb`, before the completion line:
     ```ruby
     # The prices database (spec 081 decision 10): a row in each of its five tables, through its connection, with SQL because no
     # price model exists yet. Each printing is named by its catalog entry's id, with no foreign key across the two files.
     prices = PricesRecord.lease_connection
     prices.execute("INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('upgrade-source', 'Upgrade Source', 'Prices from the upgrade seed', 0, #{prices.quote(now)}, #{prices.quote(now)})")
     source_id = prices.select_value("SELECT id FROM price_sources WHERE key = 'upgrade-source'")
     prices.execute("INSERT INTO price_series (finish, currency, kind, created_at, updated_at) VALUES ('plain', 'USD', 'market', #{prices.quote(now)}, #{prices.quote(now)})")
     series_id = prices.select_value("SELECT id FROM price_series WHERE finish = 'plain' AND currency = 'USD'")
     entries.first(3).each_with_index do |entry, index|
       prices.execute("INSERT INTO current_prices (catalog_entry_id, price_source_id, price_series_id, cents, reported_on, changed_on) VALUES (#{entry.id}, #{source_id}, #{series_id}, #{100 + index}, '2026-11-12', '2026-11-12')")
       prices.execute("INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) VALUES (#{entry.id}, #{source_id}, #{series_id}, '2026-11-12', #{100 + index})")
     end
     prices.execute("INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) VALUES (#{entries.last.id}, #{source_id}, #{series_id}, '2026-11-12', NULL)")
     prices.execute("INSERT INTO price_refresh_runs (price_source_id, run_on, source_version, status, started_at, finished_at, created_at, updated_at) VALUES (#{source_id}, '2026-11-12', 'upgrade-seed', 'finished', #{prices.quote(now)}, #{prices.quote(now)}, #{prices.quote(now)}, #{prices.quote(now)})")
     ```
     `seeds_spec.rb:58`'s "names no constant" rule forbids assignments to constants, not references, so `PricesRecord` is fine. Use the variable names `entries` and `now` as `next.rb` defines them. Its `0.2.1.rb`/`0.3.0.rb` seeds are untouched.
  3. Commit: `feat(upgrade): the next release's seed fills the prices tables (#363)`.

- [ ] **T4.4 `bin/backup-smoke` carries a price row (AC-6.3).**
  1. In `seed_ruby`, after the lot, insert a source, a series and one `current_prices` row for `entry.id` through `PricesRecord.lease_connection`, as in T4.3 but with `smoke` names.
  2. Change `state_ruby` as follows:
     - `files` checks the five names, adding `production_prices`.
     - It appends `PricesRecord.lease_connection.select_value("SELECT count(*) FROM current_prices")` to the printed line.
     - `verify_restored`'s expected string becomes `true,0,nil,true,1,1,1`, in both places.
     - Update the comment above `state_ruby` ("The five databases exist … and the price row came back").
  3. The counts check at `:185` greps for `it holds 1 account, 1 user and 1 lot\.`, but the report now continues after "1 lot" with "; …". Replace it with `grep -q "it holds 1 account, 1 user and 1 lot; 1 current price and 0 price changes\." <<<"$restored" || fail "backup:restore's counts are not the seeded instance's:"$'\n'"$restored"`. Match the exact report text T3.4 prints.
  4. `spec/smoke_scripts_spec.rb` may pin parts of the script. Run it: `bin/rspec spec/smoke_scripts_spec.rb`.
  5. Commit: `test(backup): bin/backup-smoke carries a price row through the restore (#363)`.
  6. **The container runs are not this task's.** They need colima and a slot; see T5.3.

## Phase 5: Documents, the container runs, verification

**Implements:** decision 11 · **Satisfies:** AC-7.1 to AC-7.3, the container halves of AC-1.2, AC-1.3, AC-6.3 and AC-6.4, and the NFR timing

- [ ] **T5.1 The documents (Story 7).** One commit per document group; each statement cites its source (spec 081 decision N, ADR 0029, #375):
  - `docs/architecture/prices.md` (new) uses the shape in `docs/architecture/README.md`. It covers:
    - the database and its file names;
    - the five tables;
    - the rules of decision 4 (global, keyed by `catalog_entry_id`, no cross-file key or join; an unmatched printing is no entry);
    - `WITHOUT ROWID` and the `alter_table` trap (AC-7.3) with the guard;
    - the index exception;
    - `PricesRecord`;
    - a Named constants table (none yet, or the run status values);
    - its Sources.

    Add it to `docs/architecture/README.md`'s list and area map.
  - `docs/architecture/release-and-deploy.md`:
    - the five databases and the fresh volume;
    - backup format version 2 and the two snapshots;
    - restore's two placings and the killed case (#375);
    - the upgrade proof's prices coverage;
    - `bin/backup-smoke`;
    - Named constants: `FORMAT_VERSIONS` `[1, 2]`, `HELD`, `TEMPORARY_PRICES`, and the free space as twice both databases;
    - Sources: spec 081, ADR 0029, #363, #375.
  - `docs/backup-restore.md`: version 2's three files and manifest (with the `prices` member's table), version 1, what a restore checks for both, and the killed case. Manual recovery gets the prices line: copy `prices.sqlite3` to `<volume>/production_prices.sqlite3`, owner 1000, and never start with a prices file and no primary (AC-7.1).
  - `README.md` "Backup and restore": what a backup holds (both databases) and the restore steps' warning (#375).
  - `docs/releasing.md`: the next release's upgrade note (a fifth file on the same volume; backups become format version 2, which the release before can't restore). The real-backup step restores a version 2 file.
  - `CLAUDE.md`:
    - Project Status gets one clause for spec 081.
    - "Dev mirrors prod" names `storage/development_prices.sqlite3`.
    - The test env sentence says "primary and prices databases".
    - The backup bullet says "the primary and prices databases" and that a sixth database fails the guard.
    - Keep the area's rules out (`.claude/rules/documentation.md`).
  - `.claude/rules/sqlite-and-migrations.md`: the primary and prices databases need backing up, and the large tables' index exception (pointing to `prices.md`).
  - `.claude/memory/steering/tech-stack.md`, `.claude/memory/worktree-shared-test-db.md` and `.claude/memory/push-in-background.md`: the test environment's two files.
  - ADR 0016's status line: "Extended by 0029 (a fifth file, prices)". ADR 0024's status line: "Superseded in part by 0029 (decisions 2, 3 and 4)". ADR 0029 stays Proposed until the maintainer accepts it with the PR.
  - Code comments that now cite spec 081 decision N can switch to `@see file:prices.md` where they state a prices rule. Run `bin/yard doc` once: no warnings.

  Verify by reading, against AC-7.2's list. Search for leftovers with `git grep -n -i -E "four databases|primary database only|holds the primary only|one database" -- docs README.md CLAUDE.md .claude ':!.kamal/secrets'` and fix every hit that isn't a frozen spec, a frozen contract or an ADR body.

- [ ] **T5.2 `bin/ci checks`, and the suite in parts.** Run `bin/ci checks` (RuboCop, YARD, the comment ratchet, Brakeman, audits, the migration guard), which needs no slot. Then the backup, prices and upgrade specs in one targeted run: `bin/rspec spec/backup_*_spec.rb spec/prices_*_spec.rb spec/models/prices_record_spec.rb spec/config/prices_database_spec.rb spec/lib/collector/backup spec/script/upgrade`. Fix what fails, one commit per fix.

- [ ] **T5.3 The container runs (ask first).** Ask the coordinator for a slot and say the container engine (colima) is needed. Per `.claude/memory/container-engine-colima-macos.md`, build the image locally and run with `TMPDIR` under the worktree and its `mktemp` shim:
  - `bin/backup-smoke <local-image>` (AC-6.3, and AC-1.2 in production);
  - `bin/upgrade-smoke auto <local-image>` against 0.3.0 (AC-1.3, AC-6.4).

  Record the outputs' key lines and timings in `verification.md`. The timings are backup:create's and restore's seconds against the NFR's "under a second more". Report "slot released" with the SHA.

- [ ] **T5.4 `verification.md`.** Write `docs/specs/081-prices-database-in-backup/verification.md` with:
  - each AC and its proof (example or reading);
  - the first failing test (T1.1's red guard), the WITHOUT ROWID red run (T1.3) and the decision 3 evidence;
  - the container runs (T5.3);
  - the Story 7 reading;
  - deviations, and the commits' model trailers.

  The implementation review (Mode B, read-only, Opus) is recorded under `## Implementation review` with the verdict on its first line.

## Spec coverage

| Spec item | Tasks |
|---|---|
| FR-1, decisions 1 to 5 | T1.1 to T1.3 |
| FR-2, decisions 4 and 9 | T1.2, T1.4 |
| FR-3, decisions 6 and 7 | T3.1 to T3.3 |
| FR-4, decision 8 | T3.1, T3.2, T3.4, T3.5 |
| FR-5, decision 10 | T4.1 to T4.4, T5.3 |
| Decision 11 | T5.1 |
| Decision 12 | T2.1 |
| AC-1.1 to AC-1.5 | T1.1, T1.2, T2.1, T5.3 |
| AC-2.1 to AC-2.4 | T1.2, T1.3 |
| AC-3.1 to AC-3.5 | T1.2, T1.4 |
| AC-4.1 to AC-4.8 | T3.1 to T3.3 |
| AC-5.1 to AC-5.9 | T3.1, T3.4, T3.5 |
| AC-6.1 to AC-6.9 | T1.1, T2.1, T3.5, T4.1 to T4.4, T5.3 |
| AC-7.1 to AC-7.3 | T1.2 (the migration's comment), T5.1 |
| NFR timing | T5.3 |

## Implementer batches (sdd-execute)

Sonnet 5.5 implementers, two to four consecutive tasks each, reading this plan by line range; the supervisor checks each batch's diff and trailers:

- **A:** T1.1 to T1.4.
- **B:** T2.1, T3.1, T3.2.
- **C:** T3.3 to T3.5.
- **D:** T4.1 to T4.4.
- **The supervisor:** T5.1 to T5.4.
