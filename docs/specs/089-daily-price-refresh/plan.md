# Implementation Plan: Prices Refresh Once a Day, and Each Change Is Recorded Once

**Spec:** docs/specs/089-daily-price-refresh/spec.md (v0.4.1, approved at Gate A, 2026-11-13)
**Decisions:** none in an ADR (the decisions are the spec's; the area doc carries the rules)
**Created:** 2026-11-13

## Global Constraints

- Prices are global: no `account_id`, no `Current.account`, nothing in the export (spec NFR Security).
- A printing is keyed by `catalog_entries.id` with no foreign key; **no join or attach across the two database files** (the suite has both, so one fails).
- `current_prices` and `price_changes` stay `WITHOUT ROWID` with **no index beyond the primary key**; the migration of this plan touches only `price_refresh_runs`, a rowid table (`prices.md`, `sqlite-and-migrations.md`).
- A released migration is never edited: this plan adds `db/prices_migrate/20261113190001_prepare_price_refresh_runs.rb` and leaves `20261113100001` alone.
- A `Malformed` quote is unreadable, not absent: the refresh never deletes or blanks a price it failed to parse (spec 085; spec decision 4).
- No network call, and no read of the primary database, inside a transaction on the prices database; the run row's progress write is outside the batch transaction (spec decision 7).
- Core files name no collectible, source or marketplace, comments included: `mtg`, `magic`, `scryfall`, `tcgplayer`, `cardmarket` as substrings, so not even "magical" (`spec/price_source_core_spec.rb`; spec decision 8). The only place the source's key is written is `config/recurring.yml`.
- No real network in the suite (WebMock/VCR). No agent runs the `sqlite3` command, `bin/rails console`, `db:rollback`, `db:migrate:down`, `db:seed`, or anything with `RAILS_ENV=production`; never `bin/jobs`.
- Public code gets a YARD comment (summary, `@param`/`@return`/`@raise`, side effects, idempotency); constants say why they have their value; `{…}` stays out of comments; the core never names a collectible (`.claude/rules/code-documentation.md`).
- Array and hash literals use RuboCop omakase spacing (`[ a, b ]`). Tag spec types explicitly (`type: :model`, `type: :job`); multi-expectation examples use `:aggregate_failures`.
- Targeted runs only while implementing (`bin/rspec <file>`); one example at a time on the shared test database; no full `bin/ci` until the coordinator gives the slot.
- Every implementer's prompt says: never run the `sqlite3` command or anything else on the permission-ask list.
- The area docs (`prices.md`, `catalog-operations.md`) are written by `distill-feature` after the implementation review (the run's finish order); Phase 9 lists what they must say, and the other documents are written in Phase 9.

---

## Goal

A Solid Queue job, scheduled daily, reads the catalog source's bulk file, judges each price against the current price, writes a history row only where a price changed (or went away, when the file can be trusted to say so), and records the run, in the prices database, without ever overlapping itself.

## File map

| File | Responsibility |
|---|---|
| `db/prices_migrate/20261113190001_prepare_price_refresh_runs.rb`, `db/prices_structure.sql` | the run table's nullable `run_on`, `job_id`, `languages` and counts (decision 2) |
| `app/models/current_price.rb`, `app/models/price_change.rb` | composite-key models of the two large tables; bulk writes by key |
| `app/models/price_refresh_run.rb` | the run record and its guard: `start!`, `skip!`, `finish!`, `fail!`, `progress!`, `heartbeat`, the lookups for "applied" and "older" |
| `app/models/prices/refresh.rb` | the decisions: skip rules, reading, the four cases, absence and its guards |
| `app/jobs/prices/refresh_job.rb` | the queue's face: lock, retries, rate-limit module |
| `app/models/mtg/scryfall/source.rb`, `app/models/catalog/sources.rb` | unique partial download name, stale partial pruning, the contract's comment (one change, one commit) |
| `config/recurring.yml` | the schedule |
| `spec/support/price_refresh_helpers.rb`, `spec/support/fake_price_source.rb` | the specs' fakes and builders |

Three components (the run record, the refresh, the job) plus two thin models: within the Simplicity Gate. No wrapper types: Active Record's `upsert_all` and `delete_all` are used directly (Anti-Abstraction Gate).

---

## Phase 0: Specs' fakes and the failing contract of the job

**Implements:** FR-1, FR-2 (the shape only) | **Satisfies:** none yet (it makes the later phases' tests writable)
**Files:** `spec/support/price_refresh_helpers.rb`, `spec/support/fake_price_source.rb`
**Interfaces:** Consumes: `FakePriceSource`, `FakeCatalogSource`, the `:catalog_entry` factory. Produces: `use_widget_sources(records:, reported_on:, series:, version:, languages:)` (registers a price source `fake_source` and a catalog source `widgets`; undone after the example), `widget_quote(key, cents, series: PLAIN)`, `widget_malformed(key = nil, series: nil)`, `widget_entry(key, **attributes)`, `price_source_row`, `series_row(series = PLAIN)`, `seed_price(entry, cents, series: PLAIN, on:)`, the constant `PriceRefreshHelpers::PLAIN`.

- [ ] **T0.1** Edit `spec/support/fake_price_source.rb`: a record that responds to `call` is called instead of yielded (so an example can raise after N quotes). Replace `@records.each(&block)` in `#each_quote` with:

  ```ruby
      @records.each { |record| record.respond_to?(:call) ? record.call : block.call(record) }
  ```

  Update its header comment: "A record that responds to `call` is called, not yielded, so an example can raise partway."

- [ ] **T0.2** Create `spec/support/price_refresh_helpers.rb`:

  ```ruby
  # Builders and fakes for the daily price refresh's specs (spec 089): a fake price source and a fake catalog source for
  # a made-up collectible, "widgets", registered for one example with `use_widget_sources`.
  #
  # @api private
  module PriceRefreshHelpers
    PLAIN = Prices::Sources::Series.new(finish: "plain", currency: "USD", kind: "market")
    DAY = Date.new(2026, 11, 13)

    # Registers `fake_source` (prices) and `widgets` (catalog) for this example; both are undone after it.
    #
    # @param records [Array] what the price source yields from `each_quote` (a record that responds to `call` is called)
    # @param reported_on [Date, Exception] what `#reported_on` answers
    # @param series [Array<Prices::Sources::Series>, nil] the series it declares, or the one plain series
    # @param version [String] the catalog source's current version
    # @param languages [Array<String>] the catalog source's languages
    def use_widget_sources(records: [], reported_on: DAY, series: nil, version: "v1", languages: [ "en" ])
      price_class = Class.new(FakePriceSource) do
        define_singleton_method(:series) { series } if series
        define_method(:initialize) { |*| super(records:, reported_on:) }
      end
      catalog_class = Class.new(FakeCatalogSource) do
        define_method(:initialize) { |*| super(version:, languages:) }
      end
      stub_const("WidgetPrices", price_class)
      stub_const("WidgetCatalog", catalog_class)
      Prices.sources["fake_source"] = "WidgetPrices"
      Catalog.sources["widgets"] = "WidgetCatalog"
      @widget_sources = true
      price_class
    end

    def widget_quote(key, cents, series: PLAIN, on: DAY)
      Prices::Sources::Quote.new(external_key: key, finish: series.finish, currency: series.currency, kind: series.kind, cents:, reported_on: on)
    end

    def widget_malformed(key = nil, series: nil) = Prices::Sources::Malformed.new(external_key: key, error: "unreadable", series:)

    def widget_entry(key, **attributes) = create(:catalog_entry, collectible_type: "widgets", external_key: key, **attributes)

    def price_source_row = PriceSource.sync!(Prices.source_class("fake_source"))

    def series_row(series = PLAIN) = PriceSeries.ensure!([ series ]).fetch(series)

    # A current price and its history row, as an earlier run would have left them.
    def seed_price(entry, cents, series: PLAIN, on: Date.new(2026, 11, 12))
      keys = { catalog_entry_id: entry.id, price_source_id: price_source_row.id, price_series_id: series_row(series).id }
      CurrentPrice.insert_all!([ keys.merge(cents:, reported_on: on, changed_on: on) ])
      PriceChange.insert_all!([ keys.merge(recorded_on: on, cents:) ])
    end
  end

  RSpec.configure do |config|
    config.include PriceRefreshHelpers
    config.after do
      next unless @widget_sources

      Prices.sources.delete("fake_source")
      Catalog.sources.delete("widgets")
    end
  end
  ```

- [ ] **T0.3** Run `bin/rspec spec/models/prices_spec.rb spec/models/prices/sources_spec.rb` — expect PASS (the fake's change breaks nothing). Commit: `test: add the daily price refresh's fakes and builders (spec 089)`.

---

## Phase 1: The run table fits the refresh

**Implements:** Decision 2, FR-3 | **Satisfies:** AC-5.2, AC-1.9 (the table accepts a nil `run_on`)
**Files:** `db/prices_migrate/20261113190001_prepare_price_refresh_runs.rb`, `db/prices_structure.sql`, `spec/prices_schema_spec.rb`
**Interfaces:** Consumes: the table of `20261113100001_create_price_tables.rb`. Produces: `price_refresh_runs` with `run_on` nullable, `job_id` and `languages` (nullable strings) and the integer counts `quotes_seen`, `unchanged`, `changed`, `added`, `removed`, `removals_withheld`, `unknown_printings`, `malformed` (`null: false, default: 0`).

The rebuild touches a rowid table (`price_refresh_runs`), so the `WITHOUT ROWID` trap of the two large tables doesn't apply; the schema spec proves they are untouched.

- [ ] **T1.1** Failing test. In `spec/prices_schema_spec.rb`, give `migrated_database` an optional target and an existing path (the child script reads `ARGV[2]` as the version to migrate to), and add the examples. Replace the helper with:

  ```ruby
    # A database built only by running db/prices_migrate's migrations, in a child Ruby process with Active Record alone.
    # `through` stops at a version (nil: all); `path` continues a database already begun.
    def migrated_database(through: nil, path: nil)
      path ||= Pathname(Dir.mktmpdir("prices-migrated")).join("prices.sqlite3")
      script = <<~RUBY
        require "bundler/setup"
        require "active_record"
        ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ARGV[0])
        ActiveRecord::Migration.verbose = false
        target = ARGV[2].to_s.empty? ? nil : ARGV[2].to_i
        ActiveRecord::MigrationContext.new(ARGV[1]).migrate(target)
      RUBY
      _out, err, status = Open3.capture3(RbConfig.ruby, "-e", script, path.to_s, Rails.root.join("db/prices_migrate").to_s, through.to_s, chdir: Rails.root.to_s)
      raise "migrating failed: #{err}" unless status.success?

      path
    end

    def execute_in(path, sql, *binds)
      database = SQLite3::Database.new(path.to_s)
      database.execute(sql, *binds)
    ensure
      database&.close
    end
  ```

  Add inside the describe:

  ```ruby
    context "with spec 089's migration (AC-5.2, AC-1.9)" do
      let(:released) { "20261113100001" }
      let(:count_columns) { %w[quotes_seen unchanged changed added removed removals_withheld unknown_printings malformed] }

      def columns_of(path)
        execute_in(path, "PRAGMA table_info(price_refresh_runs)").to_h { |_cid, name, type, notnull, default, _pk| [ name, { type:, notnull:, default: } ] }
      end

      it "keeps a run row of a database migrated as main has it, and its table's check, key and index", :aggregate_failures do
        path = migrated_database(through: released)
        execute_in(path, "INSERT INTO price_sources (key, name, attribution, created_at, updated_at) VALUES ('s', 'S', 'a', '2026-11-13', '2026-11-13')")
        execute_in(path, "INSERT INTO price_refresh_runs (price_source_id, run_on, status, started_at, created_at, updated_at) VALUES (1, '2026-11-12', 'finished', '2026-11-12 10:00:00', '2026-11-12', '2026-11-12')")

        migrated_database(path:)
        columns = columns_of(path)
        master = execute_in(path, "SELECT name, sql FROM sqlite_master").to_h

        expect(execute_in(path, "SELECT run_on, quotes_seen, job_id FROM price_refresh_runs")).to eq([ [ "2026-11-12", 0, nil ] ])
        expect(columns["run_on"][:notnull]).to eq(0)
        expect(columns.keys).to include("job_id", "languages", *count_columns)
        expect(count_columns.map { |name| columns[name].values_at(:notnull, :default) }.uniq).to eq([ [ 1, "0" ] ])
        expect(master["price_refresh_runs"]).to include("price_refresh_runs_status_known", "REFERENCES \"price_sources\"")
        expect(master).to have_key("index_price_refresh_runs_on_price_source_id_and_run_on")
        expect(rowid_problems(definitions(master_of(path)))).to be_empty
      end

      it "accepts a run with no date and refuses an unknown status" do
        path = migrated_database
        execute_in(path, "INSERT INTO price_sources (key, name, attribution, created_at, updated_at) VALUES ('s', 'S', 'a', '2026-11-13', '2026-11-13')")

        expect { execute_in(path, "INSERT INTO price_refresh_runs (price_source_id, status, started_at, created_at, updated_at) VALUES (1, 'skipped', '2026-11-13', '2026-11-13', '2026-11-13')") }.not_to raise_error
        expect { execute_in(path, "INSERT INTO price_refresh_runs (price_source_id, status, started_at, created_at, updated_at) VALUES (1, 'bogus', '2026-11-13', '2026-11-13', '2026-11-13')") }.to raise_error(SQLite3::ConstraintException)
      end

      it "goes down without losing a row: a nil run_on takes the date of started_at" do
        path = migrated_database
        execute_in(path, "INSERT INTO price_sources (key, name, attribution, created_at, updated_at) VALUES ('s', 'S', 'a', '2026-11-13', '2026-11-13')")
        execute_in(path, "INSERT INTO price_refresh_runs (price_source_id, status, started_at, created_at, updated_at) VALUES (1, 'skipped', '2026-11-13 09:00:00', '2026-11-13', '2026-11-13')")

        migrated_database(through: released, path:)

        expect(execute_in(path, "SELECT run_on FROM price_refresh_runs")).to eq([ [ "2026-11-13" ] ])
        expect(columns_of(path)["run_on"][:notnull]).to eq(1)
        expect(columns_of(path).keys).not_to include("job_id", "quotes_seen")
      end
    end
  ```

- [ ] **T1.2** Run `bin/rspec spec/prices_schema_spec.rb` — expect FAIL (the new examples: no such columns).

- [ ] **T1.3** Create `db/prices_migrate/20261113190001_prepare_price_refresh_runs.rb`:

  ```ruby
  # What the daily refresh needs of price_refresh_runs (spec 089 decision 2; supersedes the run_on column of spec 081).
  #
  # run_on becomes nullable: a run opens before its file's date is known, and some end before it is (already running, an
  # empty catalog, a transient error). job_id is for the stall rule; languages and the counts say what the run did.
  #
  # price_refresh_runs is a rowid table, so Rails' table rebuild for change_column_null is safe here, unlike for
  # current_prices and price_changes (see the first prices migration's warning). The columns are added first and the
  # rebuild comes last, so the stored table SQL is the canonical one. `down` gives a nil run_on the date of started_at,
  # so it never loses a row.
  class PreparePriceRefreshRuns < ActiveRecord::Migration[8.1]
    COUNTS = %i[quotes_seen unchanged changed added removed removals_withheld unknown_printings malformed].freeze

    def up
      add_column :price_refresh_runs, :job_id, :string
      add_column :price_refresh_runs, :languages, :string
      COUNTS.each { |name| add_column :price_refresh_runs, name, :integer, null: false, default: 0 }
      change_column_null :price_refresh_runs, :run_on, true
    end

    def down
      execute "UPDATE price_refresh_runs SET run_on = date(started_at) WHERE run_on IS NULL"
      change_column_null :price_refresh_runs, :run_on, false
      COUNTS.reverse_each { |name| remove_column :price_refresh_runs, name }
      remove_column :price_refresh_runs, :languages
      remove_column :price_refresh_runs, :job_id
    end
  end
  ```

- [ ] **T1.4** Run `bin/rails db:migrate` (development; it re-dumps `db/prices_structure.sql`; the `sqlite3` command is run by Rails, not by you), then `bin/rails db:prepare`. Check `git diff db/prices_structure.sql`: `price_refresh_runs` has the new columns, `run_on` without `NOT NULL`, the status check, the foreign key and the index, a new `schema_migrations` row, and **the two `WITHOUT ROWID` tables unchanged**. If the test database is stale, `bin/rails db:test:prepare`.

- [ ] **T1.5** Run `bin/rspec spec/prices_schema_spec.rb spec/backup_guards_spec.rb` and `ruby script/upgrade/guard.rb` — expect PASS. Commit (stage the migration, the structure file and the spec; the structure file is generated, never hand-edited): `feat(prices): make price_refresh_runs fit the daily refresh (spec 089 decision 2)`.

---

## Phase 2: The models of the three tables, and the run's guard

**Implements:** Decisions 2, 3, 6 (the keys), 7 (the guard), FR-2 | **Satisfies:** AC-4.1, AC-4.2, AC-1.9, AC-2.8 (keys)
**Files:** `app/models/current_price.rb`, `app/models/price_change.rb`, `app/models/price_refresh_run.rb`, `spec/models/current_price_spec.rb`, `spec/models/price_change_spec.rb`, `spec/models/price_refresh_run_spec.rb`, `spec/price_source_core_spec.rb`
**Interfaces:** Consumes: `PricesRecord`, `PriceSource`, Phase 1's columns. Produces:
`CurrentPrice` and `PriceChange` (composite primary keys; `upsert_all(rows, unique_by: Model.primary_key)` works on them),
`PriceRefreshRun::STATUSES`, `COUNTS`, `STALL_AFTER` (15 minutes), `HEARTBEAT_EVERY` (30 seconds), scopes `running`, `finished`,
`PriceRefreshRun.start!(source, job_id:, now: Time.current)` → a `running` run, or a `skipped` one with `error: "already running"` (after closing runs left behind as `failed`/`interrupted`),
`#left_behind?(job_id:, now:)`, `#record_file!(version:, languages:)`, `#skip!(reason, run_on: nil)`, `#finish!(counts)`, `#fail!(error, counts)`, `#progress!(counts)`, `#heartbeat(*)`,
`PriceRefreshRun.applied(source, version, languages)` (finished runs), `PriceRefreshRun.latest_run_on(source)` (the latest `run_on` of finished or failed runs).

- [ ] **T2.1** Failing tests. `spec/models/current_price_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe CurrentPrice, type: :model do
    it "is keyed by printing, source and series, and an upsert on that key replaces the row", :aggregate_failures do
      source = PriceSource.sync!(FakePriceSource)
      series = PriceSeries.ensure!(FakePriceSource.series).values.first
      keys = { catalog_entry_id: 7, price_source_id: source.id, price_series_id: series.id }

      described_class.upsert_all([ keys.merge(cents: 100, reported_on: Date.new(2026, 11, 12), changed_on: Date.new(2026, 11, 12)) ], unique_by: described_class.primary_key)
      described_class.upsert_all([ keys.merge(cents: 150, reported_on: Date.new(2026, 11, 13), changed_on: Date.new(2026, 11, 13)) ], unique_by: described_class.primary_key)

      expect(described_class.primary_key).to eq(%w[catalog_entry_id price_source_id price_series_id])
      expect(described_class.pluck(:cents, :changed_on)).to eq([ [ 150, Date.new(2026, 11, 13) ] ])
    end

    it "lives in the prices database and has no account" do
      expect([ described_class.connection_db_config.name, described_class.column_names & %w[account_id user_id] ]).to eq([ "prices", [] ])
    end
  end
  ```

  `spec/models/price_change_spec.rb` is the same shape: key `catalog_entry_id price_source_id price_series_id recorded_on`; upsert twice with cents `100` then `nil` (a blank row) and expect `pluck(:cents)` to eq `[ nil ]`.

  `spec/models/price_refresh_run_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe PriceRefreshRun, type: :model do
    let(:source) { PriceSource.sync!(FakePriceSource) }
    let(:now) { Time.utc(2026, 11, 13, 12, 0, 0) }

    def run!(status: "running", job_id: "job-1", updated_at: now, **attributes)
      described_class.create!(price_source: source, status:, job_id:, started_at: updated_at, updated_at:, **attributes)
    end

    describe ".start!" do
      it "opens a running run with its job id and the time", :aggregate_failures do
        run = described_class.start!(source, job_id: "job-2", now:)

        expect(run).to have_attributes(status: "running", job_id: "job-2", started_at: now, run_on: nil, finished_at: nil)
      end

      it "records a skipped run, 'already running', while another run has recent progress (AC-4.1)", :aggregate_failures do
        busy = run!(updated_at: now - 5.minutes)

        skipped = described_class.start!(source, job_id: "job-2", now:)

        expect(skipped).to have_attributes(status: "skipped", error: "already running", finished_at: now)
        expect(busy.reload.status).to eq("running")
      end

      it "closes a run with no progress for STALL_AFTER as interrupted and goes ahead (AC-4.2)", :aggregate_failures do
        left = run!(updated_at: now - described_class::STALL_AFTER - 1.minute)

        run = described_class.start!(source, job_id: "job-2", now:)

        expect(left.reload).to have_attributes(status: "failed", error: "interrupted", finished_at: now)
        expect(run.status).to eq("running")
      end

      it "closes a running run that carries the starting job's own id (the queue re-ran it) (AC-4.2)", :aggregate_failures do
        left = run!(job_id: "job-1", updated_at: now - 1.minute)

        run = described_class.start!(source, job_id: "job-1", now:)

        expect(left.reload).to have_attributes(status: "failed", error: "interrupted")
        expect(run.status).to eq("running")
      end

      it "leaves another source's runs alone" do
        other = PriceSource.create!(key: "other", name: "Other", attribution: "text")
        elsewhere = described_class.create!(price_source: other, status: "running", started_at: now, updated_at: now - 1.hour)

        described_class.start!(source, job_id: "job-2", now:)

        expect(elsewhere.reload.status).to eq("running")
      end
    end

    describe "#skip!, #finish!, #fail!" do
      it "ends a run with its reason or counts", :aggregate_failures do
        a = run!.tap { it.skip!("v1 already applied", run_on: Date.new(2026, 11, 13)) }
        b = run!(job_id: "x").tap { it.finish!(unchanged: 3, changed: 1, bogus: 9) }
        c = run!(job_id: "y").tap { it.fail!(RuntimeError.new("boom"), added: 2) }

        expect(a).to have_attributes(status: "skipped", error: "v1 already applied", run_on: Date.new(2026, 11, 13))
        expect(b).to have_attributes(status: "finished", unchanged: 3, changed: 1)
        expect(c).to have_attributes(status: "failed", error: "RuntimeError: boom", added: 2)
        expect([ a, b, c ].map(&:finished_at)).to all(be_present)
      end
    end

    describe ".applied and .latest_run_on" do
      it "finds a finished run of the same version and languages only", :aggregate_failures do
        finished = run!(status: "finished", source_version: "v1", languages: "en", run_on: Date.new(2026, 11, 13))
        run!(status: "failed", job_id: "a", source_version: "v1", languages: "en")
        run!(status: "finished", job_id: "b", source_version: "v1", languages: "en,ja")

        expect(described_class.applied(source, "v1", "en")).to eq([ finished ])
        expect(described_class.applied(source, "v2", "en")).to be_empty
      end

      it "takes the latest run_on of finished and failed runs, never of skipped or running ones" do
        run!(status: "finished", job_id: "a", run_on: Date.new(2026, 11, 10))
        run!(status: "failed", job_id: "b", run_on: Date.new(2026, 11, 12))
        run!(status: "skipped", job_id: "c", run_on: Date.new(2026, 11, 14))
        run!(status: "running", job_id: "d", run_on: Date.new(2026, 11, 15))

        expect(described_class.latest_run_on(source)).to eq(Date.new(2026, 11, 12))
      end
    end

    describe "#progress! and #heartbeat" do
      it "stores the counts, and a heartbeat touches the run at most once per HEARTBEAT_EVERY", :aggregate_failures do
        run = run!(updated_at: now - 1.hour)

        travel_to(now) { run.heartbeat(1, 10) }
        first = run.reload.updated_at
        travel_to(now + 10.seconds) { run.heartbeat }
        second = run.reload.updated_at
        travel_to(now + 31.seconds) { run.heartbeat }
        run.progress!(unchanged: 4, malformed: 1)

        expect([ first, second ]).to eq([ now, now ])
        expect(run.reload.updated_at).to be >= now + 31.seconds
        expect(run).to have_attributes(unchanged: 4, malformed: 1)
      end
    end
  end
  ```

  In `spec/price_source_core_spec.rb` extend the file list: `%w[app/models/prices.rb app/models/prices/**/*.rb app/models/price_source.rb app/models/price_series.rb app/models/current_price.rb app/models/price_change.rb app/models/price_refresh_run.rb app/jobs/prices/**/*.rb]` (spec 089 decision 8).

- [ ] **T2.2** Run `bin/rspec spec/models/current_price_spec.rb spec/models/price_change_spec.rb spec/models/price_refresh_run_spec.rb` — expect FAIL (`uninitialized constant`).

- [ ] **T2.3** Implement. `app/models/current_price.rb`:

  ```ruby
  # The latest known price of one printing in one series from one source, in the prices database (spec 081; spec 089).
  # Keyed by printing (a catalog entry's id, with no foreign key: `prices.md`), source and series; the table is
  # WITHOUT ROWID with no other index, so every lookup goes by printing, the key's first column.
  #
  # The daily refresh writes it with `upsert_all` and `delete_all` by key, which skip validations on purpose: each row comes
  # from a validated `Prices::Sources::Quote`, and the table's own checks refuse the rest.
  #
  # @see file:prices.md
  class CurrentPrice < PricesRecord
    self.primary_key = %i[catalog_entry_id price_source_id price_series_id]
  end
  ```

  `app/models/price_change.rb`:

  ```ruby
  # One row of price history, in the prices database: the price of a printing in a series from a source on the day it
  # differed from the last one recorded; a row with no cents records that the price went away that day (spec 081; spec
  # 089). WITHOUT ROWID, keyed by printing, source, series and day, with no other index. Written by the daily refresh with
  # `upsert_all` on that key, so a second write for the same day replaces the first (validations are skipped on purpose,
  # as for `CurrentPrice`).
  #
  # @see file:prices.md
  class PriceChange < PricesRecord
    self.primary_key = %i[catalog_entry_id price_source_id price_series_id recorded_on]
  end
  ```

  `app/models/price_refresh_run.rb`:

  ```ruby
  # One run of the daily price refresh, in the prices database (spec 089 decision 2): its identity (source, the file's
  # day, version and languages), its times, its status and the counts of what it did to rows. The run is also the guard
  # against overlap and against a run left behind (decision 7). Measurements of cost are #366's.
  #
  # `run_on` is nil until the file's date is known; `error` holds why a run failed or was skipped.
  #
  # @see file:prices.md
  class PriceRefreshRun < PricesRecord
    STATUSES = %w[running finished skipped failed].freeze
    # What a run counts (spec 089 decision 2); the columns have these names and default to 0.
    COUNTS = %i[quotes_seen unchanged changed added removed removals_withheld unknown_printings malformed].freeze
    # A running run with no progress for this long is left behind. The catalog refresh's own threshold (spec 089 decision 7).
    STALL_AFTER = 15.minutes
    # The most often the run row is touched while a download reports progress, so a long download never reads as stalled.
    HEARTBEAT_EVERY = 30.seconds

    belongs_to :price_source

    scope :running, -> { where(status: "running") }
    scope :finished, -> { where(status: "finished") }

    # Opens a run for the source, or records that none could be opened. In one transaction it closes each running run that
    # was left behind (`#left_behind?`) as `failed` with `interrupted`; then, if a run still runs, it records the new run
    # as `skipped` with `already running` (nothing else is touched), otherwise as `running`.
    #
    # @param source [PriceSource]
    # @param job_id [String, nil] the starting job's Active Job id
    # @param now [Time]
    # @return [PriceRefreshRun] `running`, or `skipped` when another run is working
    def self.start!(source, job_id:, now: Time.current)
      transaction do
        running.where(price_source: source).select { it.left_behind?(job_id:, now:) }
          .each { it.update!(status: "failed", error: "interrupted", finished_at: now) }
        if running.exists?(price_source_id: source.id)
          create!(price_source: source, status: "skipped", error: "already running", job_id:, started_at: now, finished_at: now)
        else
          create!(price_source: source, status: "running", job_id:, started_at: now)
        end
      end
    end

    # The finished runs of a source for one file and language set: what "applied" means (spec 089 decision 5).
    #
    # @return [ActiveRecord::Relation<PriceRefreshRun>]
    def self.applied(source, version, languages) = finished.where(price_source: source, source_version: version, languages:)

    # The latest day a finished or failed run of the source read a file for (a failed run may have written rows); skipped
    # and running runs don't count (spec 089 decision 3).
    #
    # @return [Date, nil]
    def self.latest_run_on(source) = where(price_source: source, status: %w[finished failed]).maximum(:run_on)

    # Whether nothing works on this running run any more: its last progress is older than STALL_AFTER, or it carries the
    # starting job's own id (the queue re-ran it after a restart).
    #
    # @return [Boolean]
    def left_behind?(job_id:, now: Time.current) = updated_at < now - STALL_AFTER || (job_id.present? && self.job_id == job_id)

    # Records the file this run is for.
    def record_file!(version:, languages:) = update!(source_version: version, languages:)

    # Ends the run as skipped, with the reason in `error`; `run_on` when it is known.
    def skip!(reason, run_on: nil) = update!(status: "skipped", error: reason, run_on: run_on || self.run_on, finished_at: Time.current)

    # Ends the run as finished with its counts (keys outside COUNTS are ignored).
    def finish!(counts) = update!(status: "finished", finished_at: Time.current, **counted(counts))

    # Ends the run as failed with `"<class>: <message>"` and the counts so far.
    def fail!(error, counts) = update!(status: "failed", error: "#{error.class}: #{error.message}", finished_at: Time.current, **counted(counts))

    # Stores the counts so far and counts as progress (the stall rule reads `updated_at`). Written outside any batch's
    # transaction.
    def progress!(counts) = update!(**counted(counts), updated_at: Time.current)

    # A progress callback for a download (called with bytes done and total): touches the run at most once per
    # HEARTBEAT_EVERY.
    def heartbeat(*)
      now = Time.current
      return if @last_beat && now - @last_beat < HEARTBEAT_EVERY

      @last_beat = now
      touch
    end

    private
      def counted(counts) = counts.slice(*COUNTS)
  end
  ```

  `validates :status, inclusion: { in: STATUSES }` is not added: the table's check is the guard (as the other prices models).

- [ ] **T2.4** Run the three model specs and `bin/rspec spec/price_source_core_spec.rb` — expect PASS. Run `bin/rubocop -a` on the files. Commit: `feat(prices): add the models of current prices, price changes and refresh runs (spec 089)`.

---

## Phase 3: A download two jobs can make at once

**Implements:** Decision 1's shared directory | **Satisfies:** AC-4.8
**Files:** `app/models/mtg/scryfall/source.rb`, `app/models/catalog/sources.rb`, `spec/models/mtg/scryfall/source_spec.rb`
**Interfaces:** Consumes: the existing `#fetch`, `#prune`. Produces: `MTG::Scryfall::Source::STALE_PARTIAL_AFTER` (1 day); a partial file named `<file>.<hex>.part` per download; `prune` deletes `*.part` files older than that by mtime; the `Catalog::Sources` contract's comment says `#download` must tolerate concurrent calls for one version.

This is a contract change (`#download` now has two callers that can run together) and a behaviour change of the catalog's source, so the comment and the behaviour go in **one commit** (`code-documentation.md`, "Extension contracts"). It supersedes spec 002 FR-3's "a partial file".

- [ ] **T3.1** Failing tests, in `spec/models/mtg/scryfall/source_spec.rb`, inside `describe "#current_version and #download"` (the file's `dir`, `source`, `stub_scryfall` helpers are used by its neighbours):

  ```ruby
    it "deletes a partial file left by a killed download once it is a day old, and keeps a fresh one (spec 089 AC-4.8)", :aggregate_failures do
      old = dir.join("default-cards-1.jsonl.gz.dead.part")
      fresh = dir.join("default-cards-1.jsonl.gz.live.part")
      fixed = dir.join("default-cards-0.jsonl.gz.part") # a fixed-name partial file from an earlier build
      [ old, fresh, fixed ].each { |path| path.write("x") }
      FileUtils.touch(old, mtime: Time.now - 2.days)
      FileUtils.touch(fixed, mtime: Time.now - 2.days)
      stub_scryfall(cards: [ scryfall_card ])
      version = source.current_version(languages: [ "en" ])

      source.download(version, dir:)

      expect(dir.children.map { |path| path.basename.to_s }).to contain_exactly("#{version}.jsonl.gz", fresh.basename.to_s)
    end

    it "writes each download to a partial file of its own, so a second download of the version, started inside the first, is harmless (spec 089 AC-4.8)", :aggregate_failures do
      cards = [ scryfall_card ]
      stub_scryfall(cards:)
      version = source.current_version(languages: [ "en" ])
      body = gzip_jsonl(cards)
      url = "https://data.scryfall.io/default-cards/#{version}.jsonl.gz"
      other = described_class.new(client: MTG::Scryfall::Client.new, env: {})
      other.current_version(languages: [ "en" ])
      calls = 0
      partials_while_nested = nil
      stub_request(:get, url).to_return do |_request|
        calls += 1
        if calls == 1
          partials_while_nested = dir.glob("*.part").size # the first download's own partial file is open
          other.download(version, dir:)
        end
        { body:, headers: { "Content-Type" => "application/gzip" } }
      end

      path = source.download(version, dir:)

      expect(partials_while_nested).to eq(1)
      expect(path.size).to eq(body.bytesize)
      expect(dir.glob("*.part")).to be_empty
    end
  ```

- [ ] **T3.2** Run `bin/rspec spec/models/mtg/scryfall/source_spec.rb -e "partial file"` — expect FAIL (the old partial is not pruned; the nested download renames the first's partial file away: `Errno::ENOENT` or a wrong size).

- [ ] **T3.3** Implement in `app/models/mtg/scryfall/source.rb`. Add the constant under `KEEP_DOWNLOADS`:

  ```ruby
    # A partial file this old belongs to a killed download: a live one is far younger (a job that never reports ends at its
    # 6-hour lock). Each download writes its own partial file, so a killed one leaves an orphan for `prune` to remove
    # (spec 089 decision 1, which supersedes spec 002 FR-3's "a partial file").
    STALE_PARTIAL_AFTER = 1.day
  ```

  Change `fetch`'s first line, and `prune`:

  ```ruby
      def fetch(url, path, expected)
        partial = Pathname("#{path}.#{SecureRandom.hex(4)}.part")
        # (rest unchanged)
  ```

  ```ruby
      def prune(dir)
        dir.glob("*.jsonl.gz").sort_by(&:mtime).reverse.drop(KEEP_DOWNLOADS).each(&:delete)
        dir.glob("*.part").select { it.mtime < STALE_PARTIAL_AFTER.ago }.each(&:delete)
      end
  ```

  In `app/models/catalog/sources.rb`, change the `#download` line of the contract's comment to:

  ```
  #   #download(version, dir:)            Pathname of the verified local copy (IntegrityError, TransientError). Two callers
  #                                       (the catalog refresh and a price refresh) may call it for one version at once, so it
  #                                       must tolerate concurrent calls: a partial download is never shared between calls
  ```

- [ ] **T3.4** Run `bin/rspec spec/models/mtg/scryfall/source_spec.rb spec/jobs/catalog/refresh_job_spec.rb spec/models/catalog/refresh_spec.rb` — expect PASS (the existing size-mismatch example still leaves `dir.children` empty). Commit: `feat(catalog): a download writes a partial file of its own and stale ones are pruned (spec 089 decision 1)`.

---

## Phase 4: The refresh's lifecycle: skips, the date, failure

**Implements:** Decisions 1 (file), 5, 7 (guard, errors), FR-1, FR-2 | **Satisfies:** AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.8, AC-1.9 (a run that ends early), AC-4.1 (through the refresh), AC-4.2 (through the refresh), AC-4.7 (the download's heartbeat)
**Files:** `app/models/prices/refresh.rb`, `spec/models/prices/refresh_spec.rb`
**Interfaces:** Consumes: Phase 2's `PriceRefreshRun`, `PriceSource.sync!`, `PriceSeries.ensure!`, `Catalog.source_for`, `Prices.source_class`, `Rails.configuration.x.catalog_download_dir`. Produces: `Prices::Refresh.new(source_key, job_id: nil).call` → the `PriceRefreshRun`; `Prices::Refresh::BATCH_SIZE` (1,000), `MAX_REMOVED_SHARE` (`Rational(1, 10)`), `Prices::Refresh::GuardError`. Phase 4 builds `#call`, `#perform` and a stub `#apply` that reads nothing; Phases 5 and 6 fill `#apply`.

- [ ] **T4.1** Failing tests, `spec/models/prices/refresh_spec.rb` (the first half; later phases add describes to this file):

  ```ruby
  require "rails_helper"

  RSpec.describe Prices::Refresh, type: :model do
    def refresh(job_id: "job-1") = described_class.new("fake_source", job_id:)
    def last_run = PriceRefreshRun.order(:id).last

    context "before it applies anything" do
      it "skips with a reason and no date when the catalog has no printing of the type, asking the catalog's source nothing (AC-1.5)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 100) ])

        run = refresh.call

        expect(run).to have_attributes(status: "skipped", run_on: nil)
        expect(run.error).to include("no printing")
        expect([ CurrentPrice.count, PriceChange.count ]).to eq([ 0, 0 ])
      end

      it "syncs the source before a run exists, so a source that fails verification fails the job with no run (AC-1.8)", :aggregate_failures do
        use_widget_sources
        Prices.sources["fake_source"] = "WidgetPrices"
        broken = Class.new(FakePriceSource) { def self.key = "BAD KEY" }
        stub_const("WidgetPrices", broken)

        expect { refresh.call }.to raise_error(Prices::Sources::ConfigurationError, /key/)
        expect(PriceRefreshRun.count).to eq(0)
        expect { described_class.new("nobody").call }.to raise_error(ArgumentError, /unknown price source/)
        expect(PriceRefreshRun.count).to eq(0)
      end

      it "syncs the source and its series first, so their rows exist when the run opens (AC-1.8)", :aggregate_failures do
        use_widget_sources
        widget_entry("w-1")

        expect { refresh.call }.not_to raise_error # Phase 6 makes a file with no quote a GuardError; T6.3 updates this example

        expect(PriceSource.pluck(:key)).to eq([ "fake_source" ])
        expect(PriceSeries.count).to eq(1)
        expect(last_run.price_source.key).to eq("fake_source")
      end

      it "skips a file already applied for the same version and languages, copying its date and asking for no download (AC-1.2)", :aggregate_failures do
        use_widget_sources(version: "v1")
        widget_entry("w-1")
        PriceRefreshRun.create!(price_source: price_source_row, status: "finished", source_version: "v1", languages: "en",
          run_on: Date.new(2026, 11, 13), started_at: 1.hour.ago)

        run = refresh.call

        expect(run).to have_attributes(status: "skipped", error: "v1 already applied", run_on: Date.new(2026, 11, 13),
          source_version: "v1", languages: "en")
      end

      it "applies a file of the same version when the language set differs (AC-1.3)", :aggregate_failures do
        use_widget_sources(version: "all-1", languages: %w[de en], records: [ widget_quote("w-1", 100) ])
        widget_entry("w-1")
        PriceRefreshRun.create!(price_source: price_source_row, status: "finished", source_version: "all-1", languages: "en,ja",
          run_on: Date.new(2026, 11, 13), started_at: 1.hour.ago)

        run = refresh.call

        expect(run).to have_attributes(status: "finished", languages: "de,en")
      end

      it "skips a file older than the latest finished or failed run, and applies one of the same day (AC-1.4)", :aggregate_failures do
        use_widget_sources(reported_on: Date.new(2026, 11, 12), records: [ widget_quote("w-1", 100) ])
        widget_entry("w-1")
        PriceRefreshRun.create!(price_source: price_source_row, status: "failed", source_version: "other", languages: "en",
          run_on: Date.new(2026, 11, 13), started_at: 2.hours.ago)

        older = refresh.call

        expect(older).to have_attributes(status: "skipped", run_on: Date.new(2026, 11, 12))
        expect(older.error).to include("2026-11-13")
        expect([ CurrentPrice.count, PriceChange.count ]).to eq([ 0, 0 ])
      end

      it "ends the run failed, with its error, when the source's file has no date, and nothing is written (AC-1.9)", :aggregate_failures do
        use_widget_sources(reported_on: Prices::Sources::IntegrityError.new("no date"))
        widget_entry("w-1")

        expect { refresh.call }.to raise_error(Prices::Sources::IntegrityError)
        expect(last_run).to have_attributes(status: "failed", run_on: nil)
        expect(last_run.error).to eq("Prices::Sources::IntegrityError: no date")
      end

      it "records a skipped run, 'already running', for a run with recent progress, and writes nothing (AC-4.1)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 100) ])
        widget_entry("w-1")
        PriceRefreshRun.create!(price_source: price_source_row, status: "running", job_id: "other-job", started_at: 1.minute.ago)

        run = refresh(job_id: "job-2").call

        expect(run).to have_attributes(status: "skipped", error: "already running")
        expect([ CurrentPrice.count, PriceChange.count ]).to eq([ 0, 0 ])
      end

      it "closes a run left behind as interrupted and goes ahead (AC-4.2)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 100) ])
        widget_entry("w-1")
        left = PriceRefreshRun.create!(price_source: price_source_row, status: "running", job_id: "dead-job",
          started_at: 1.hour.ago, updated_at: 1.hour.ago)

        run = refresh(job_id: "job-2").call

        expect(left.reload).to have_attributes(status: "failed", error: "interrupted")
        expect(run.status).to eq("finished")
      end

      it "touches the run while the download reports progress, at most once per HEARTBEAT_EVERY (AC-4.7)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 100) ])
        widget_entry("w-1")
        stub_const("WidgetCatalog", Class.new(ReportingCatalogSource) { define_method(:initialize) { |*| super(version: "v1", languages: [ "en" ]) } })
        touches = []
        callback = ->(*, payload) { touches << payload[:sql] if payload[:sql].to_s.match?(/UPDATE "price_refresh_runs" SET "updated_at" = [^,]+ WHERE/) }

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { refresh.call }

        expect(touches.size).to eq(1) # ReportingCatalogSource reports twice within one instant: one touch (a touch sets only updated_at)
      end
    end
  end
  ```

- [ ] **T4.2** Run `bin/rspec spec/models/prices/refresh_spec.rb` — expect FAIL (`uninitialized constant Prices::Refresh`).

- [ ] **T4.3** Implement `app/models/prices/refresh.rb` (Phases 5 and 6 add to the private section; the skeleton below is complete for this phase):

  ```ruby
  # One run of the daily price refresh for one price source (spec 089): asks the collectible's catalog source for the bulk
  # file it already downloads, judges each quote against the current price and writes only what changed, and records the
  # run (`PriceRefreshRun`). It makes no request outside that catalog source, never joins the prices database with the
  # primary, and holds no network call or primary read inside a transaction on the prices database.
  #
  # Side effects: rows of `current_prices`, `price_changes`, `price_sources`, `price_series` and `price_refresh_runs`;
  # the catalog source's download directory. It needs no `Current.account` (prices are global). Safe to run twice on one
  # file: the second run is skipped as already applied, and a rerun of a failed run changes nothing it already wrote.
  #
  # @see file:prices.md
  class Prices::Refresh
    # Printings per write transaction, and current prices per removal transaction: a few thousand rows, so the database
    # is held briefly (spec 089 decision 7).
    BATCH_SIZE = 1_000

    # The largest share of the source's candidate current prices a run may remove in one day (spec 089 decision 4, ruled
    # by the maintainer on 2026-11-13). A GUESS until #366's run records measure the real daily share of prices that
    # disappear: a file that loses a tenth of the market in a day is far more likely truncated or damaged than a market
    # event. A real drop above it is refused, every day, until this constant moves.
    MAX_REMOVED_SHARE = Rational(1, 10)

    # The file can't be trusted to say prices are gone (decision 4, items 2 and 5); the run fails and nothing is removed.
    class GuardError < StandardError; end

    # @param source_key [String] a key of `Prices.sources`
    # @param job_id [String, nil] the Active Job id, so a re-run after a restart closes its own left-behind run
    def initialize(source_key, job_id: nil)
      @source_key = source_key
      @job_id = job_id
      @counts = Hash.new(0)
    end

    # Runs the refresh. The source is looked up and synced before any run exists (a run's source row is required), so an
    # unregistered key or a source that fails verification raises with no run recorded; every later failure ends the run
    # `failed` with its error and re-raises it for the job's retry rules.
    #
    # @return [PriceRefreshRun] finished, skipped or (when another run works) skipped as already running
    # @raise [ArgumentError, Prices::Sources::ConfigurationError] before a run exists
    # @raise [GuardError, Prices::Sources::IntegrityError, Zlib::Error, Catalog::Sources::Error, StandardError] after the run is recorded failed
    def call
      @source_class = Prices.source_class(@source_key)
      @source = PriceSource.sync!(@source_class)
      @series = PriceSeries.ensure!(@source_class.series)
      @run = PriceRefreshRun.start!(@source, job_id: @job_id)
      return @run unless @run.running?

      perform
      @run
    rescue StandardError => error
      @run.fail!(error, @counts) if @run&.running?
      raise
    end

    private
      def collectible_type = @source_class.collectible_type

      def perform
        return @run.skip!("the catalog has no #{collectible_type} printings yet") unless Catalog::Entry.exists?(collectible_type:)

        catalog = Catalog.source_for(collectible_type)
        @languages = catalog.languages
        version = catalog.current_version(languages: @languages)
        @run.record_file!(version:, languages: @languages.join(","))
        applied = PriceRefreshRun.applied(@source, version, @run.languages).first
        return @run.skip!("#{version} already applied", run_on: applied.run_on) if applied

        catalog.progress = @run.method(:heartbeat) if catalog.respond_to?(:progress=)
        path = catalog.download(version, dir: Rails.configuration.x.catalog_download_dir.join(collectible_type))
        reader = @source_class.new
        @run_on = reader.reported_on(path)
        @run.update!(run_on: @run_on)
        latest = PriceRefreshRun.latest_run_on(@source)
        return @run.skip!("a later file (#{latest}) was already read; this one is dated #{@run_on}") if latest && @run_on < latest

        apply(reader, path)
        @run.finish!(@counts)
      end

      # Filled in by the next phases.
      def apply(_reader, _path); end
  end
  ```

  Why the order holds: `latest_run_on` runs after the new run's `run_on` was written; the run is `running`, so it is not among the statuses counted.

- [ ] **T4.4** Run `bin/rspec spec/models/prices/refresh_spec.rb` — expect PASS. `bin/rubocop -a app/models/prices/refresh.rb spec/models/prices/refresh_spec.rb`. Commit: `feat(prices): the daily refresh's lifecycle, skips and run guard (spec 089)`.

---

## Phase 5: Each quote is judged and written

**Implements:** Decisions 2 (counts), 3, 6, FR-1 | **Satisfies:** AC-1.1, AC-1.6, AC-1.7, AC-2.1, AC-2.2, AC-2.3, AC-2.5, AC-2.6, AC-2.7, AC-2.8, AC-2.10, AC-2.11, AC-2.12, AC-5.3
**Files:** `app/models/prices/refresh.rb`, `spec/models/prices/refresh_spec.rb`
**Interfaces:** Consumes: Phase 4's `Prices::Refresh`, `CurrentPrice`, `PriceChange`, `Catalog::Entry`. Produces: `#apply` reads `reader.each_quote(path, languages: @languages)`, batches by distinct printing (`BATCH_SIZE`), looks up entry ids on the primary by `external_key` (outside any transaction), judges against current prices inside one prices transaction, writes `upsert_all`, tallies `@counts` after the commit, calls `@run.progress!(@counts)` after each batch. It records, for Phase 6: `@seen` (a `Set` of `[entry_id, series_id]`), `@held_entries`, `@held_series`, `@untrusted`, `@quotes_yielded`, `@unknown`.

- [ ] **T5.1** Failing tests: add to `spec/models/prices/refresh_spec.rb` (a `describe "applying a file"`, with `before { use_widget_sources(records:) }`-style setup per example; helper `refresh`, `last_run` from Phase 4):

  ```ruby
    describe "judging quotes" do
      def rows = CurrentPrice.pluck(:catalog_entry_id, :cents, :reported_on, :changed_on)
      def history = PriceChange.order(:catalog_entry_id, :recorded_on).pluck(:catalog_entry_id, :recorded_on, :cents)

      it "adds a price no one has, with a history row for the run's date, and finishes the run (AC-1.1, AC-2.1)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 142) ], reported_on: Date.new(2026, 11, 13))
        entry = widget_entry("w-1")

        run = refresh.call

        expect(run).to have_attributes(status: "finished", run_on: Date.new(2026, 11, 13), source_version: "v1", languages: "en",
          job_id: "job-1", added: 1, quotes_seen: 1, unchanged: 0, changed: 0)
        expect(run.started_at).to be_present
        expect(run.finished_at).to be_present
        expect(rows).to eq([ [ entry.id, 142, Date.new(2026, 11, 13), Date.new(2026, 11, 13) ] ])
        expect(history).to eq([ [ entry.id, Date.new(2026, 11, 13), 142 ] ])
      end

      it "writes nothing for an unchanged price, and the current price's dates stay (AC-2.2)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 100) ])
        entry = widget_entry("w-1")
        seed_price(entry, 100, on: Date.new(2026, 11, 12))

        run = refresh.call

        expect(run).to have_attributes(unchanged: 1, changed: 0, added: 0, quotes_seen: 1)
        expect(rows).to eq([ [ entry.id, 100, Date.new(2026, 11, 12), Date.new(2026, 11, 12) ] ])
        expect(history.size).to eq(1)
      end

      it "updates a changed price and adds one history row, leaving the earlier ones (AC-2.3)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 150) ])
        entry = widget_entry("w-1")
        seed_price(entry, 100, on: Date.new(2026, 11, 12))

        run = refresh.call

        expect(run).to have_attributes(changed: 1, added: 0, unchanged: 0)
        expect(rows).to eq([ [ entry.id, 150, Date.new(2026, 11, 13), Date.new(2026, 11, 13) ] ])
        expect(history).to eq([ [ entry.id, Date.new(2026, 11, 12), 100 ], [ entry.id, Date.new(2026, 11, 13), 150 ] ])
      end

      it "judges each series of a printing on its own (AC-2.6)", :aggregate_failures do
        series = [ PriceRefreshHelpers::PLAIN,
                   Prices::Sources::Series.new(finish: "foil", currency: "USD", kind: "market"),
                   Prices::Sources::Series.new(finish: "etched", currency: "USD", kind: "market") ]
        use_widget_sources(series:, records: [ widget_quote("w-1", 100, series: series[0]), widget_quote("w-1", 300, series: series[1]), widget_quote("w-1", 500, series: series[2]) ])
        entry = widget_entry("w-1")
        seed_price(entry, 100, series: series[0]) # unchanged
        seed_price(entry, 250, series: series[1]) # changed

        run = refresh.call

        expect(run).to have_attributes(quotes_seen: 3, unchanged: 1, changed: 1, added: 1)
        expect(CurrentPrice.count).to eq(3)
      end

      it "skips a printing the catalog doesn't have, counting it once however many series it has (AC-2.5)", :aggregate_failures do
        series = [ PriceRefreshHelpers::PLAIN, Prices::Sources::Series.new(finish: "foil", currency: "USD", kind: "market") ]
        use_widget_sources(series:, records: [ widget_quote("ghost", 1, series: series[0]), widget_quote("ghost", 2, series: series[1]), widget_quote("w-1", 100) ])
        widget_entry("w-1")

        run = refresh.call

        expect(run).to have_attributes(unknown_printings: 1, quotes_seen: 1, added: 1)
        expect(CurrentPrice.count).to eq(1)
      end

      it "judges the first of two quotes for one printing and series, ignoring the second (AC-2.10)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 100), widget_quote("w-2", 5), widget_quote("w-1", 999) ])
        entry = widget_entry("w-1")
        widget_entry("w-2")

        run = refresh.call

        expect(run).to have_attributes(quotes_seen: 2, added: 2)
        expect(CurrentPrice.find_by(catalog_entry_id: entry.id).cents).to eq(100)
      end

      it "replaces a history row of the same day when a second file of that day differs (AC-2.7)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 150) ], version: "v2")
        entry = widget_entry("w-1")
        seed_price(entry, 100, on: Date.new(2026, 11, 13))
        PriceChange.where(catalog_entry_id: entry.id).update_all(recorded_on: Date.new(2026, 11, 13)) # rubocop:disable Rails/SkipsModelValidations -- fixture setup

        refresh.call

        expect(history).to eq([ [ entry.id, Date.new(2026, 11, 13), 150 ] ])
      end

      it "gives every written row the file's date, whatever the clock says (AC-1.6)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 100) ], reported_on: Date.new(2026, 11, 13))
        widget_entry("w-1")

        travel_to(Time.utc(2026, 12, 25, 12)) { refresh.call }

        expect(CurrentPrice.pluck(:reported_on, :changed_on)).to eq([ [ Date.new(2026, 11, 13), Date.new(2026, 11, 13) ] ])
        expect(PriceChange.pluck(:recorded_on)).to eq([ Date.new(2026, 11, 13) ])
      end

      it "writes the same rows when the job is performed twice on one file (AC-1.7)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 100), widget_quote("w-2", 200) ])
        widget_entry("w-1")
        widget_entry("w-2")

        refresh.call
        first = [ CurrentPrice.pluck(:catalog_entry_id, :cents, :changed_on).sort, PriceChange.pluck(:catalog_entry_id, :cents, :recorded_on).sort ]
        second = refresh.call

        expect(second).to have_attributes(status: "skipped", error: "v1 already applied")
        expect([ CurrentPrice.pluck(:catalog_entry_id, :cents, :changed_on).sort, PriceChange.pluck(:catalog_entry_id, :cents, :recorded_on).sort ]).to eq(first)
        expect(PriceRefreshRun.count).to eq(2)
      end

      it "keeps rows keyed by the entry's id, in the prices database (AC-2.8)", :aggregate_failures do
        use_widget_sources(records: [ widget_quote("w-1", 100) ])
        entry = widget_entry("w-1")

        refresh.call

        expect(CurrentPrice.first.catalog_entry_id).to eq(entry.id)
        expect([ CurrentPrice, PriceChange, PriceRefreshRun ].map { it.connection_db_config.name }.uniq).to eq([ "prices" ])
      end

      it "raises, fails the run and keeps earlier batches when a quote's series was not declared (AC-2.11)", :aggregate_failures do
        undeclared = Prices::Sources::Series.new(finish: "gold", currency: "USD", kind: "market")
        stub_const("Prices::Refresh::BATCH_SIZE", 1)
        use_widget_sources(records: [ widget_quote("w-1", 100), widget_quote("w-2", 5, series: undeclared) ])
        widget_entry("w-1")
        widget_entry("w-2")

        expect { refresh.call }.to raise_error(Prices::Sources::ConfigurationError, /gold/)

        expect(last_run).to have_attributes(status: "failed", added: 1)
        expect(CurrentPrice.count).to eq(1)
      end

      it "logs a malformed record's key and error, and counts it (AC-2.12)", :aggregate_failures do
        use_widget_sources(records: [ widget_malformed("w-1", series: PriceRefreshHelpers::PLAIN), widget_quote("w-2", 5) ])
        widget_entry("w-1")
        widget_entry("w-2")
        allow(Rails.logger).to receive(:warn)

        run = refresh.call

        expect(run.malformed).to eq(1)
        expect(Rails.logger).to have_received(:warn).with(/prices\.refresh skipped malformed .*w-1.*unreadable/)
      end
    end
  ```

- [ ] **T5.2** Run `bin/rspec spec/models/prices/refresh_spec.rb -e "judging quotes"` — expect FAIL (no rows are written; `#apply` is empty).

- [ ] **T5.3** Implement. In `app/models/prices/refresh.rb` replace the empty `apply` with the following (inside `private`):

  ```ruby
      # Reads the file once, flushing a batch of printings at a time (decision 6), then handles absences (Phase 6).
      def apply(reader, path)
        @seen = Set.new # [entry id, series id] judged this run: a duplicate quote is ignored, an unseen candidate is absent
        @unknown = Set.new
        @held_entries = Set.new
        @held_series = Set.new
        @untrusted = false
        @quotes_yielded = 0
        @pending = {}
        @pending_malformed = []

        reader.each_quote(path, languages: @languages) do |record|
          case record
          when Prices::Sources::Quote then queue_quote(record)
          when Prices::Sources::Malformed then queue_malformed(record)
          end
        end
        flush
        @counts[:unknown_printings] = @unknown.size
      end

      def queue_quote(quote)
        @quotes_yielded += 1
        @series.fetch(quote.series) do
          raise Prices::Sources::ConfigurationError, "#{@source_class} yielded a quote of #{quote.series.inspect}, which it did not declare"
        end
        flush if !@pending.key?(quote.external_key) && @pending.size >= BATCH_SIZE
        (@pending[quote.external_key] ||= []) << quote
      end

      def queue_malformed(record)
        @counts[:malformed] += 1
        Rails.logger.warn("prices.refresh skipped malformed #{record.external_key.inspect}: #{record.error}")
        @pending_malformed << record
      end

      # Judges and writes the pending printings. The primary is read here, outside any transaction; the prices database
      # is read and written in one short transaction; the counts are tallied after it commits.
      def flush
        return if @pending.empty? && @pending_malformed.empty?

        keys = (@pending.keys + @pending_malformed.filter_map(&:external_key)).uniq
        ids = Catalog::Entry.where(collectible_type:, external_key: keys).pluck(:external_key, :id).to_h
        hold_malformed(ids)
        judged = []
        @pending.each do |key, quotes|
          id = ids[key]
          next @unknown << key unless id

          quotes.each do |quote|
            series_id = @series.fetch(quote.series).id
            judged << [ id, series_id, quote.cents ] if @seen.add?([ id, series_id ])
          end
        end
        write_judged(judged)
        @pending = {}
        @pending_malformed = []
        @run.progress!(@counts)
      end

      # What a Malformed holds back from removal (decision 4, items 3 and 4): no key, the whole run; a key and no series (or
      # a series the source didn't declare), every series of the printing; a key and a series, that series.
      def hold_malformed(ids)
        @pending_malformed.each do |record|
          entry_id = ids[record.external_key]
          if record.external_key.nil? then @untrusted = true
          elsif entry_id.nil? then next
          elsif record.series.nil? || @series[record.series].nil? then @held_entries << entry_id
          else @held_series << [ entry_id, @series[record.series].id ]
          end
        end
      end

      def write_judged(judged)
        return if judged.empty?

        tally = Hash.new(0)
        PricesRecord.transaction do
          existing = CurrentPrice.where(price_source_id: @source.id, catalog_entry_id: judged.map(&:first).uniq)
            .pluck(:catalog_entry_id, :price_series_id, :cents).to_h { |entry_id, series_id, cents| [ [ entry_id, series_id ], cents ] }
          currents = []
          changes = []
          judged.each do |entry_id, series_id, cents|
            had = existing[[ entry_id, series_id ]]
            next tally[:unchanged] += 1 if had == cents

            tally[had ? :changed : :added] += 1
            keys = { catalog_entry_id: entry_id, price_source_id: @source.id, price_series_id: series_id }
            currents << keys.merge(cents:, reported_on: @run_on, changed_on: @run_on)
            changes << keys.merge(recorded_on: @run_on, cents:)
          end
          CurrentPrice.upsert_all(currents, unique_by: CurrentPrice.primary_key) if currents.any?
          PriceChange.upsert_all(changes, unique_by: PriceChange.primary_key) if changes.any?
        end
        tally.each { |name, count| @counts[name] += count }
        @counts[:quotes_seen] += judged.size
      end
  ```

  If `upsert_all(..., unique_by: Model.primary_key)` is refused for a composite key on this Rails (8.1.4), use `unique_by: %i[catalog_entry_id price_source_id price_series_id]` (and the four columns for `PriceChange`): the `WITHOUT ROWID` primary key is the conflict target. T2.1's model specs prove which form works; use that form here.

- [ ] **T5.4** Run `bin/rspec spec/models/prices/refresh_spec.rb` — expect PASS. `bin/rubocop -a`. Commit: `feat(prices): judge each quote and record a change once (spec 089)`.

---

## Phase 6: Gone is not bad: absences and their guards

**Implements:** Decision 4, decision 6 (removal), FR-1 must-nots | **Satisfies:** AC-2.4, AC-2.9, AC-3.1 to AC-3.9, AC-5.3 (withheld)
**Files:** `app/models/prices/refresh.rb`, `spec/models/prices/refresh_spec.rb`
**Interfaces:** Consumes: Phase 5's `@seen`, `@held_entries`, `@held_series`, `@untrusted`, `@quotes_yielded`, `@languages`, `@run_on`, `@counts`. Produces: after the whole file is read, `#remove_absent` raises `GuardError` when the file yielded no `Quote`; walks the source's current prices twice by printing id in slices of `BATCH_SIZE` (the first walk counts candidates and absences, the second removes, only if the ceiling holds); a removal slice deletes the current prices and upserts blank history rows in one transaction; `@counts[:removed]` and `[:removals_withheld]`.

- [ ] **T6.1** Failing tests: add to `spec/models/prices/refresh_spec.rb`. Each example that removes a price seeds **at least ten candidate rows** (the ceiling is a share): a helper makes them.

  ```ruby
    describe "absences" do
      def seed_candidates(count, prefix: "keep") = Array.new(count) { |index| widget_entry("#{prefix}-#{index}").tap { seed_price(it, 100) } }
      def keep_quotes(count, prefix: "keep") = Array.new(count) { |index| widget_quote("#{prefix}-#{index}", 100) }
      def blank_history(entry) = PriceChange.where(catalog_entry_id: entry.id, cents: nil).pluck(:recorded_on)

      it "removes a price the file leaves out and writes a blank history row for the run's date (AC-2.4)", :aggregate_failures do
        kept = seed_candidates(10)
        gone = widget_entry("gone").tap { seed_price(it, 100) }
        use_widget_sources(records: keep_quotes(10))

        run = refresh.call

        expect(run).to have_attributes(status: "finished", removed: 1, removals_withheld: 0, unchanged: 10)
        expect(CurrentPrice.where(catalog_entry_id: gone.id)).to be_empty
        expect(blank_history(gone)).to eq([ Date.new(2026, 11, 13) ])
        expect(CurrentPrice.where(catalog_entry_id: kept.map(&:id)).count).to eq(10)
      end

      it "treats a price that comes back as an added quote with its own history row (AC-2.4)", :aggregate_failures do
        seed_candidates(10)
        gone = widget_entry("gone").tap { seed_price(it, 100) }
        use_widget_sources(records: keep_quotes(10), version: "v1")
        refresh.call
        use_widget_sources(records: keep_quotes(10) + [ widget_quote("gone", 120) ], version: "v2", reported_on: Date.new(2026, 11, 14))

        run = refresh.call

        expect(run).to have_attributes(added: 1, unchanged: 10)
        expect(CurrentPrice.find_by(catalog_entry_id: gone.id).cents).to eq(120)
        expect(PriceChange.where(catalog_entry_id: gone.id).order(:recorded_on).pluck(:recorded_on, :cents)).to eq([ [ Date.new(2026, 11, 12), 100 ], [ Date.new(2026, 11, 13), nil ], [ Date.new(2026, 11, 14), 120 ] ])
      end

      it "removes a price of a printing absent from the file altogether, and of a retired entry (AC-2.9)", :aggregate_failures do
        seed_candidates(20)
        absent = widget_entry("absent").tap { seed_price(it, 100) }
        retired = widget_entry("retired", retired_at: 1.day.ago).tap { seed_price(it, 100) }
        use_widget_sources(records: keep_quotes(20))

        run = refresh.call

        expect(run).to have_attributes(removed: 2)
        expect(CurrentPrice.where(catalog_entry_id: [ absent.id, retired.id ])).to be_empty
      end

      it "leaves a price whose printing is in a language the run did not read, or the primary lacks, and does not count it (AC-3.7)", :aggregate_failures do
        seed_candidates(10)
        japanese = widget_entry("ja-1", language: "ja").tap { seed_price(it, 100) }
        unknown = CurrentPrice.insert_all!([ { catalog_entry_id: 9_999_999, price_source_id: price_source_row.id, price_series_id: series_row.id, cents: 5, reported_on: Date.new(2026, 11, 12), changed_on: Date.new(2026, 11, 12) } ])
        use_widget_sources(records: keep_quotes(10))

        run = refresh.call

        expect(run).to have_attributes(removed: 0, removals_withheld: 0)
        expect(CurrentPrice.where(catalog_entry_id: [ japanese.id, 9_999_999 ]).count).to eq(2)
      end

      it "does not remove a price whose quote was unreadable, and the printing's other series are judged as usual (AC-3.1)", :aggregate_failures do
        other = Prices::Sources::Series.new(finish: "foil", currency: "USD", kind: "market")
        seed_candidates(10)
        entry = widget_entry("w-x")
        seed_price(entry, 100)
        seed_price(entry, 100, series: other)
        use_widget_sources(series: [ PriceRefreshHelpers::PLAIN, other ], records: keep_quotes(10) + [ widget_malformed("w-x", series: PriceRefreshHelpers::PLAIN) ])

        run = refresh.call

        expect(run).to have_attributes(malformed: 1, removals_withheld: 1, removed: 1)
        expect(CurrentPrice.where(catalog_entry_id: entry.id, price_series_id: series_row.id).count).to eq(1) # kept
        expect(CurrentPrice.where(catalog_entry_id: entry.id, price_series_id: series_row(other).id)).to be_empty # absent and trusted
        expect(blank_history(entry)).to eq([ Date.new(2026, 11, 13) ])
      end

      it "removes none of a printing's prices when its line could be read only as far as its key (AC-3.2)", :aggregate_failures do
        other = Prices::Sources::Series.new(finish: "foil", currency: "USD", kind: "market")
        seed_candidates(10)
        entry = widget_entry("w-x")
        seed_price(entry, 100)
        seed_price(entry, 100, series: other)
        use_widget_sources(series: [ PriceRefreshHelpers::PLAIN, other ], records: keep_quotes(10) + [ widget_malformed("w-x") ])

        run = refresh.call

        expect(run).to have_attributes(removed: 0, removals_withheld: 2)
        expect(CurrentPrice.where(catalog_entry_id: entry.id).count).to eq(2)
      end

      it "removes nothing at all when a line names no printing, applying the quotes around it (AC-3.3)", :aggregate_failures do
        seed_candidates(10)
        gone = widget_entry("gone").tap { seed_price(it, 100) }
        new_entry = widget_entry("fresh")
        use_widget_sources(records: keep_quotes(10).first(5) + [ widget_malformed ] + keep_quotes(10).last(5) + [ widget_quote("fresh", 77) ])

        run = refresh.call

        expect(run).to have_attributes(status: "finished", removed: 0, removals_withheld: 1, added: 1)
        expect(CurrentPrice.where(catalog_entry_id: gone.id).count).to eq(1)
        expect(CurrentPrice.where(catalog_entry_id: new_entry.id).count).to eq(1)
      end

      it "fails the run, with the reader's error, when the file is cut short; earlier batches stand, nothing is removed, and a whole file of the day finishes without a duplicate row (AC-3.4)", :aggregate_failures do
        stub_const("Prices::Refresh::BATCH_SIZE", 2)
        seed_candidates(10)
        gone = widget_entry("gone").tap { seed_price(it, 100) }
        fresh = Array.new(4) { |index| widget_entry("new-#{index}") }
        use_widget_sources(records: keep_quotes(10) + fresh.map { widget_quote(it.external_key, 7) } + [ -> { raise Zlib::GzipFile::Error, "unexpected end of file" } ])

        expect { refresh.call }.to raise_error(Zlib::GzipFile::Error)

        expect(last_run).to have_attributes(status: "failed", removed: 0)
        expect(last_run.error).to include("unexpected end of file")
        expect(CurrentPrice.where(catalog_entry_id: gone.id).count).to eq(1)
        written = CurrentPrice.where(catalog_entry_id: fresh.map(&:id)).count
        expect(written).to be_between(2, 4)

        use_widget_sources(records: keep_quotes(10) + fresh.map { widget_quote(it.external_key, 7) }, version: "v1")
        second = refresh.call

        expect(second.status).to eq("finished")
        expect(CurrentPrice.where(catalog_entry_id: fresh.map(&:id)).count).to eq(4)
        expect(PriceChange.where(catalog_entry_id: fresh.map(&:id)).count).to eq(4)
      end

      it "fails the run, 'no valid quotes', and writes nothing when the file yields no quote (AC-3.5)", :aggregate_failures do
        seed_candidates(10)
        use_widget_sources(records: [ widget_malformed ])

        expect { refresh.call }.to raise_error(Prices::Refresh::GuardError, /no valid quotes/)

        expect(last_run).to have_attributes(status: "failed", removed: 0)
        expect(CurrentPrice.count).to eq(10)
        expect(PriceChange.count).to eq(10)
      end

      it "finishes a file whose quotes are all for printings the catalog lacks, counting them and writing or removing nothing (AC-3.5)", :aggregate_failures do
        widget_entry("w-1") # the catalog has a printing of the type, so the run isn't skipped
        use_widget_sources(records: [ widget_quote("ghost-1", 1), widget_quote("ghost-2", 1) ])

        run = refresh.call

        expect(run).to have_attributes(status: "finished", unknown_printings: 2, quotes_seen: 0, removed: 0)
        expect([ CurrentPrice.count, PriceChange.count ]).to eq([ 0, 0 ])
      end

      it "refuses every removal and fails the run when absences exceed the share, counting them as withheld (AC-3.6)", :aggregate_failures do
        seed_candidates(10)
        gone = Array.new(2) { |index| widget_entry("gone-#{index}").tap { seed_price(it, 100) } }
        use_widget_sources(records: keep_quotes(10)) # 2 of 12 candidates absent: over 1/10

        expect { refresh.call }.to raise_error(Prices::Refresh::GuardError, /2 of 12/)

        expect(last_run).to have_attributes(status: "failed", removed: 0, removals_withheld: 2)
        expect(CurrentPrice.where(catalog_entry_id: gone.map(&:id)).count).to eq(2)
      end

      it "removes absences exactly at the share (AC-3.6)", :aggregate_failures do
        seed_candidates(9)
        gone = widget_entry("gone").tap { seed_price(it, 100) } # 1 of 10 candidates: exactly 1/10
        use_widget_sources(records: keep_quotes(9))

        run = refresh.call

        expect(run).to have_attributes(status: "finished", removed: 1)
        expect(CurrentPrice.where(catalog_entry_id: gone.id)).to be_empty
      end

      it "reads a failed file again on the next run (AC-3.8)", :aggregate_failures do
        seed_candidates(10)
        widget_entry("gone").tap { seed_price(it, 100) }
        widget_entry("gone-2").tap { seed_price(it, 100) }
        use_widget_sources(records: keep_quotes(10))
        expect { refresh.call }.to raise_error(Prices::Refresh::GuardError)

        expect { refresh.call }.to raise_error(Prices::Refresh::GuardError) # read again, not skipped as applied

        expect(PriceRefreshRun.where(status: "failed").count).to eq(2)
        expect(PriceRefreshRun.where(status: "skipped")).to be_empty
      end

      it "leaves both or neither of a removal batch's current price and blank history row when the batch fails (AC-3.9)", :aggregate_failures do
        seed_candidates(10)
        gone = widget_entry("gone").tap { seed_price(it, 100) }
        use_widget_sources(records: keep_quotes(10))
        PricesRecord.connection.execute("CREATE TRIGGER no_blank_history BEFORE INSERT ON price_changes WHEN NEW.cents IS NULL BEGIN SELECT RAISE(ABORT, 'injected'); END")

        expect { refresh.call }.to raise_error(ActiveRecord::StatementInvalid, /injected/)

        expect(CurrentPrice.where(catalog_entry_id: gone.id).count).to eq(1)
        expect(blank_history(gone)).to be_empty

        PricesRecord.connection.execute("DROP TRIGGER no_blank_history")
        run = refresh.call

        expect(run).to have_attributes(status: "finished", removed: 1)
        expect(CurrentPrice.where(catalog_entry_id: gone.id)).to be_empty
        expect(blank_history(gone)).to eq([ Date.new(2026, 11, 13) ])
      end
    end
  ```

- [ ] **T6.2** Run `bin/rspec spec/models/prices/refresh_spec.rb -e "absences"` — expect FAIL.

- [ ] **T6.3** Implement. In `#apply`, after `@counts[:unknown_printings] = @unknown.size`, add `remove_absent`; add to the `private` section:

  ```ruby
      # Absence is trusted only as far as the file is (spec 089 decision 4). The file has been read to the end here (a
      # reader's error would have left `#apply` already). Two walks over the source's candidate current prices by printing
      # id: the first counts the candidates and the absences, so the ceiling is judged on the whole; the second removes.
      def remove_absent
        raise GuardError, "the file yielded no valid quotes (#{@counts[:malformed]} malformed), so nothing was written or removed" if @quotes_yielded.zero?

        candidates = absent_clear = absent_held = 0
        each_candidate_slice do |rows|
          rows.each do |entry_id, series_id|
            candidates += 1
            next if @seen.include?([ entry_id, series_id ])

            held?(entry_id, series_id) ? absent_held += 1 : absent_clear += 1
          end
        end
        @counts[:removals_withheld] = absent_held
        return if absent_clear.zero?

        if absent_clear > candidates * MAX_REMOVED_SHARE
          @counts[:removals_withheld] += absent_clear
          raise GuardError, "#{absent_clear} of #{candidates} current prices are missing from the file, more than the #{(MAX_REMOVED_SHARE * 100).to_i} percent " \
                            "a day may lose, so nothing was removed. A file that loses that much in a day is usually truncated or damaged; a real, " \
                            "lasting drop is refused until Prices::Refresh::MAX_REMOVED_SHARE is raised."
        end

        each_candidate_slice { |rows| remove(rows.reject { |entry_id, series_id| @seen.include?([ entry_id, series_id ]) || held?(entry_id, series_id) }) }
      end

      def held?(entry_id, series_id) = @untrusted || @held_entries.include?(entry_id) || @held_series.include?([ entry_id, series_id ])

      # Yields the source's candidate current prices as [entry id, series id], a slice of BATCH_SIZE printings at a time,
      # by keyset on the printing id. A candidate's printing is a catalog entry of this type in a language of the run,
      # retired or not; one the primary lacks, or in a language not read, isn't asked about and is left out. The primary is
      # read outside any transaction, and each slice touches the run as progress.
      def each_candidate_slice
        last = 0
        loop do
          ids = CurrentPrice.where(price_source_id: @source.id).where("catalog_entry_id > ?", last).distinct.order(:catalog_entry_id).limit(BATCH_SIZE).pluck(:catalog_entry_id)
          break if ids.empty?

          last = ids.last
          languages = Catalog::Entry.where(collectible_type:, id: ids).pluck(:id, :language).to_h
          rows = CurrentPrice.where(price_source_id: @source.id, catalog_entry_id: ids).pluck(:catalog_entry_id, :price_series_id)
          yield rows.select { |entry_id, _series_id| @languages.include?(languages[entry_id]) }
          @run.progress!(@counts)
        end
      end

      # Deletes the current prices and records their blank history rows in ONE transaction: a price deleted without its row
      # would no longer be a candidate, and the removal would be lost for good. `delete_all` is bulk maintenance of
      # global rows by key; no callbacks or validations apply.
      def remove(rows)
        return if rows.empty?

        PricesRecord.transaction do
          rows.group_by(&:first).each do |entry_id, pairs|
            CurrentPrice.where(price_source_id: @source.id, catalog_entry_id: entry_id, price_series_id: pairs.map(&:last)).delete_all
          end
          PriceChange.upsert_all(rows.map { |entry_id, series_id| { catalog_entry_id: entry_id, price_source_id: @source.id, price_series_id: series_id, recorded_on: @run_on, cents: nil } },
            unique_by: PriceChange.primary_key)
        end
        @counts[:removed] += rows.size
      end
  ```

  A `GuardError` from `remove_absent` happens inside `#apply`, so `#call`'s rescue marks the run failed with the counts so far (`removals_withheld` included) — `@counts` is the same hash. `@run.progress!(@counts)` runs per slice; `@counts[:removals_withheld]` set before the second walk is persisted by it.

  Phase 4's example `syncs the source and its series first` has no quote in its file, which is now a `GuardError` (`no valid quotes`): in `spec/models/prices/refresh_spec.rb` change its expectation to `raise_error(Prices::Refresh::GuardError, /no valid quotes/)`.

- [ ] **T6.4** Run `bin/rspec spec/models/prices/refresh_spec.rb` — expect PASS. `bin/rubocop -a`. Commit: `feat(prices): remove a gone price only when the file can be trusted (spec 089)`.

---

## Phase 7: The job and the schedule

**Implements:** Decisions 7 (lock, retries, errors), 8 (schedule) | **Satisfies:** AC-4.3, AC-4.6, AC-5.1
**Files:** `app/jobs/prices/refresh_job.rb`, `config/recurring.yml`, `spec/jobs/prices/refresh_job_spec.rb`, `spec/config/recurring_spec.rb`
**Interfaces:** Consumes: `Prices::Refresh.new(key, job_id:).call`, `Catalog::RateLimitRetry`. Produces: `Prices::RefreshJob.perform_later("scryfall")`-shaped jobs on queue `sync`; `Prices::RefreshJob::LOCK_FOR` (6 hours); `refresh_prices` in `config/recurring.yml`.

- [ ] **T7.1** Failing tests. `spec/jobs/prices/refresh_job_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe Prices::RefreshJob, type: :job do
    it "allows one refresh per source key at a time, on the sync queue (AC-4.3)", :aggregate_failures do
      expect(described_class.queue_name).to eq("sync")
      expect(described_class.concurrency_limit).to eq(1)
      expect(described_class.concurrency_on_conflict).to eq(:block)
      expect(described_class.concurrency_duration).to eq(6.hours)
      expect(described_class.new("fake_source").concurrency_key).to eq("Prices::RefreshJob/fake_source")
    end

    it "runs the refresh for the source key, under its own job id" do
      refresh = instance_double(Prices::Refresh, call: nil)
      allow(Prices::Refresh).to receive(:new).and_return(refresh)
      job = described_class.new("fake_source")

      job.perform_now

      expect(Prices::Refresh).to have_received(:new).with("fake_source", job_id: job.job_id)
    end

    # decision 7's table (AC-4.6): the job's fate for each error; no error is discarded
    {
      "Catalog::Sources::TransientError" => [ Catalog::Sources::TransientError, "timeout", :retried ],
      "ActiveRecord::StatementTimeout" => [ ActiveRecord::StatementTimeout, "busy", :retried ],
      "Catalog::Sources::IntegrityError" => [ Catalog::Sources::IntegrityError, "downloaded 1 bytes", :retried ],
      "Catalog::Sources::RateLimitedError" => [ Catalog::Sources::RateLimitedError, "slow down", :retried ],
      "Prices::Sources::IntegrityError" => [ Prices::Sources::IntegrityError, "no date", :failed ],
      "Catalog::Sources::ConfigurationError" => [ Catalog::Sources::ConfigurationError, "bad language", :failed ],
      "Zlib::Error" => [ Zlib::Error, "cut short", :failed ],
      "Prices::Refresh::GuardError" => [ Prices::Refresh::GuardError, "over the ceiling", :failed ],
      "RuntimeError" => [ RuntimeError, "anything else", :failed ]
    }.each do |name, (error, message, fate)|
      it "#{fate == :retried ? "retries" : "fails, without a retry or a discard,"} on #{name} (AC-4.6)" do
        allow(Prices::Refresh).to receive(:new).and_raise(error, message)

        if fate == :retried
          expect { described_class.perform_now("fake_source") }.to have_enqueued_job(described_class).with("fake_source")
        else
          expect { described_class.perform_now("fake_source") }.to raise_error(error, message)
        end
      end
    end
  end
  ```

  Add to `spec/config/recurring_spec.rb`:

  ```ruby
    it "refreshes prices daily in production, at another time than the catalog's refresh, and not in development (spec 089 AC-5.1)", :aggregate_failures do
      config = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
      task = config.dig("production", "refresh_prices")

      expect(task).to include("class" => "Prices::RefreshJob", "args" => [ "scryfall" ], "queue" => "sync")
      expect(Fugit.parse_cronish(task["schedule"]).to_cron_s).to eq("30 11 * * *")
      expect(config.dig("development", "refresh_prices")).to be_nil
    end
  ```

- [ ] **T7.2** Run `bin/rspec spec/jobs/prices/refresh_job_spec.rb spec/config/recurring_spec.rb` — expect FAIL.

- [ ] **T7.3** Implement `app/jobs/prices/refresh_job.rb`:

  ```ruby
  # Runs the daily price refresh for a price source, in the background (spec 089). Queued daily by config/recurring.yml,
  # or by hand from `bin/rails runner`; there is no button or task until the admin page (#367).
  #
  # No error is discarded: a failed job shows under Failed on `/admin/jobs`, which is how an operator learns of a guard that
  # fired before #367 shows the runs. A departure from `background-jobs.md`'s `discard_on` advice, whose example is a
  # `DeserializationError`: the argument is a string, and a discarded job would hide a guard that fired (spec 089 decision 7).
  #
  # @see file:prices.md
  class Prices::RefreshJob < ApplicationJob
    # How long the queue holds a second refresh of the source back when the first never reports its end: a waiting refresh
    # must never start while another's job may still be working (the catalog refresh's value, spec 089 decision 7). The
    # run's own stall rule is `PriceRefreshRun::STALL_AFTER`, in minutes.
    LOCK_FOR = 6.hours

    queue_as :sync

    limits_concurrency to: 1, key: ->(source_key, *) { source_key }, duration: LOCK_FOR

    # The download's size error is retried too: a file republished mid-download gives exactly it, and the retry asks the
    # index again (spec 089 decision 7).
    retry_on Catalog::Sources::TransientError, Catalog::Sources::IntegrityError, ActiveRecord::StatementTimeout,
      wait: :polynomially_longer, attempts: 3
    # After retry_on, so that it is tried first: a rate-limited source is a TransientError too, but the job comes back when
    # the source asked. It reports no progress: a rate limit ends a refresh before any row is written.
    include Catalog::RateLimitRetry

    # @param source_key [String] a key of `Prices.sources`
    def perform(source_key) = Prices::Refresh.new(source_key, job_id:).call
  end
  ```

  In `config/recurring.yml`, add to the `production:` block after `refresh_mtg_catalog`:

  ```yaml
    refresh_prices:
      class: Prices::RefreshJob
      args: [ "scryfall" ]
      queue: sync
      schedule: at 11:30am every day
  ```

- [ ] **T7.4** Run `bin/rspec spec/jobs/prices/refresh_job_spec.rb spec/config/recurring_spec.rb spec/price_source_core_spec.rb` — expect PASS (the core guard now covers `app/jobs/prices/**`; the schedule's `scryfall` is in YAML, outside it). If `retry_on … IntegrityError` and the rate-limit module don't compose as the example for `RateLimitedError` expects, put `Catalog::Sources::RateLimitedError`'s example under `have_enqueued_job` with `retry_job`'s wait (the module reschedules it itself). Commit: `feat(prices): the daily refresh job, its errors' fates and its schedule (spec 089)`.

---

## Phase 8: Proofs: transactions, the network, the real source, the timing

**Implements:** Decisions 6, 7, NFR | **Satisfies:** AC-4.4, AC-4.5, AC-5.6, AC-1.1 and AC-1.7 end to end
**Files:** `spec/models/prices/refresh_spec.rb`, `spec/models/prices/refresh_end_to_end_spec.rb`, `spec/models/prices/refresh_timing_spec.rb`
**Interfaces:** Consumes: everything above, `stub_scryfall`, `scryfall_card`, `gzip_jsonl`. Produces: evidence only (specs); the timing numbers go in `verification.md`.

- [ ] **T8.1** AC-4.4, in `spec/models/prices/refresh_spec.rb`:

  ```ruby
    describe "transactions (AC-4.4)" do
      it "writes in batches of BATCH_SIZE printings at transaction depth 1, the run row at depth 0, and reads the primary outside them", :aggregate_failures do
        stub_const("Prices::Refresh::BATCH_SIZE", 2)
        entries = Array.new(5) { |index| widget_entry("w-#{index}") }
        use_widget_sources(records: entries.map { widget_quote(it.external_key, 100) })
        entries.each { |entry| seed_price(entry, 90) } # five changes, so every batch writes both tables
        prices = PricesRecord.connection
        baseline = prices.open_transactions # the example's own transaction; a batch's transaction is a savepoint inside it
        data_writes = []
        run_writes = []
        primary_inside = []
        callback = lambda do |_name, _start, _finish, _id, payload|
          depth = prices.open_transactions - baseline
          sql = payload[:sql].to_s
          if payload[:connection].equal?(prices)
            table = sql[/\A\s*(?:INSERT(?: OR \w+)? INTO|UPDATE|DELETE FROM)\s+"?(\w+)"?/i, 1]
            data_writes << [ table, depth, sql ] if %w[current_prices price_changes].include?(table)
            run_writes << depth if table == "price_refresh_runs"
          elsif depth == 1
            primary_inside << sql
          end
        end

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { refresh.call }

        current_inserts = data_writes.select { |table, _depth, _sql| table == "current_prices" }
        expect(data_writes).not_to be_empty
        expect(data_writes.map { |_table, depth, _sql| depth }.uniq).to eq([ 1 ])
        expect(run_writes).not_to be_empty
        expect(run_writes.uniq).to eq([ 0 ])
        expect(primary_inside).to be_empty
        expect(current_inserts.size).to eq(3) # five printings in batches of two: 2, 2 and 1
        expect(current_inserts.map { |_table, _depth, sql| sql.scan(/\),\s*\(/).size + 1 }).to eq([ 2, 2, 1 ]) # tuples of each insert
        expect(CurrentPrice.count).to eq(5)
      end
    end
  ```

- [ ] **T8.2** AC-4.5 and the real source end to end. `spec/models/prices/refresh_end_to_end_spec.rb`:

  ```ruby
  require "rails_helper"

  # The refresh through the real catalog source and the real price source, over a stubbed Scryfall (spec 089 AC-4.5, AC-1.1,
  # AC-1.7): the file's quotes become rows, and no request happens inside a transaction.
  RSpec.describe "the daily price refresh over the real sources", type: :model do
    let(:stamp) { "20261113100623" }

    def cards(prices_by_id) = prices_by_id.map { |id, prices| scryfall_card("id" => id, "prices" => prices) }

    around do |example|
      example.run
    ensure
      FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir)
    end

    it "downloads once, applies the file's quotes dated by its name, and makes no request inside a transaction (AC-4.5)", :aggregate_failures do
      one = create(:catalog_entry, collectible_type: "mtg", external_key: "card-1")
      two = create(:catalog_entry, collectible_type: "mtg", external_key: "card-2")
      stub_scryfall(cards: cards("card-1" => { "usd" => "1.42", "usd_foil" => "3.10", "eur" => nil }, "card-2" => { "usd" => "0.05" }), stamp:)
      connections = [ ApplicationRecord.connection, PricesRecord.connection ]
      baselines = connections.map(&:open_transactions)
      inside = []
      seen = 0
      WebMock.after_request do |request, _response|
        seen += 1
        inside << request.uri.to_s if connections.zip(baselines).any? { |connection, baseline| connection.open_transactions > baseline }
      end

      run = Prices::Refresh.new("scryfall").call

      expect(seen).to be >= 2 # the bulk-data index and the file
      expect(inside).to be_empty
      expect(run).to have_attributes(status: "finished", run_on: Date.new(2026, 11, 13), source_version: "default-cards-#{stamp}", added: 3, quotes_seen: 3)
      expect(CurrentPrice.where(catalog_entry_id: one.id).order(:price_series_id).pluck(:cents)).to contain_exactly(142, 310)
      expect(CurrentPrice.where(catalog_entry_id: two.id).pluck(:cents)).to eq([ 5 ])
      expect(PriceChange.pluck(:recorded_on).uniq).to eq([ Date.new(2026, 11, 13) ])
    ensure
      WebMock.reset_callbacks
    end

    it "changes nothing when the same file is read again (AC-1.7)", :aggregate_failures do
      create(:catalog_entry, collectible_type: "mtg", external_key: "card-1")
      stub_scryfall(cards: cards("card-1" => { "usd" => "1.42" }), stamp:)
      Prices::Refresh.new("scryfall").call
      before = [ CurrentPrice.pluck(:cents, :changed_on), PriceChange.pluck(:cents, :recorded_on) ]

      run = Prices::Refresh.new("scryfall").call

      expect(run).to have_attributes(status: "skipped", error: "default-cards-#{stamp} already applied")
      expect([ CurrentPrice.pluck(:cents, :changed_on), PriceChange.pluck(:cents, :recorded_on) ]).to eq(before)
    end
  end
  ```

  The suite's WebMock setup may already use `after_request` callbacks (check `spec/support/http_stubbing.rb`); if `WebMock.reset_callbacks` would remove the suite's own, remove only this example's callback (`WebMock::CallbackRegistry`'s list is mutable; keep a reference and delete it). The `PriceSource.sync!` of `"scryfall"` writes the real source row; the example needs no registration.

- [ ] **T8.3** AC-5.6, `spec/models/prices/refresh_timing_spec.rb` (excluded unless `SCANNER_TIMING` is set; run by hand: `SCANNER_TIMING=1 bin/rspec spec/models/prices/refresh_timing_spec.rb`):

  ```ruby
  require "rails_helper"

  # A day's file at realistic size (spec 089 AC-5.6): 110,000 cards, about 300,000 quotes, entries in the test database.
  # A measurement, not a gate; the numbers are recorded in verification.md (#366 replaces them with the run's own).
  RSpec.describe "the daily price refresh's time", :timing, type: :model do
    let(:count) { 110_000 }
    let(:stamp) { "20261113100623" }

    def card_lines(shift)
      Array.new(count) do |index|
        scryfall_card("id" => "card-#{index}", "prices" => { "usd" => format("%.2f", 1 + index / 100.0 + shift(index)), "usd_foil" => (index.even? ? format("%.2f", 2 + index / 100.0) : nil), "eur" => format("%.2f", 1 + index / 120.0) })
      end
    end

    it "applies a first run and then a typical day", :aggregate_failures do
      set = create(:catalog_set, collectible_type: "mtg")
      identity = create(:catalog_identity, collectible_type: "mtg")
      now = Time.current
      Catalog::Entry.insert_all(Array.new(count) do |index|
        { collectible_type: "mtg", external_key: "card-#{index}", catalog_set_id: set.id, catalog_identity_id: identity.id, number: index.to_s, language: "en",
          name: "Card #{index}", kind: "card", content_digest: "d", created_at: now, updated_at: now }
      end)
      timings = {}

      stub_scryfall(cards: card_lines(->(_) { 0 }), stamp: stamp)
      timings[:first_run] = Benchmark.realtime { Prices::Refresh.new("scryfall").call }
      first = PriceRefreshRun.order(:id).last

      next_stamp = "20261114100623"
      stub_scryfall(cards: card_lines(->(index) { (index % 6).zero? ? 0.5 : 0 }), stamp: next_stamp) # about 17 percent change
      timings[:typical_day] = Benchmark.realtime { Prices::Refresh.new("scryfall").call }
      second = PriceRefreshRun.order(:id).last

      puts "price refresh timing: #{timings.transform_values { it.round(1) }.inspect}, first #{first.attributes.slice(*PriceRefreshRun::COUNTS.map(&:to_s)).inspect}, second #{second.attributes.slice(*PriceRefreshRun::COUNTS.map(&:to_s)).inspect}"
      expect(first.status).to eq("finished")
      expect(second).to have_attributes(status: "finished")
      expect(second.changed).to be > 0
    ensure
      FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir)
    end
  end
  ```

  The cards' `prices` carry `usd`, `usd_foil` and `eur`; the file is built in memory by `stub_scryfall` (110,000 lines, a few tens of MB). If building it in memory is too slow or too large, write it under `tmp/` with `gzip_jsonl` and stub the download to return that file. Do not add the example to the default suite (it is excluded without `SCANNER_TIMING`).

- [ ] **T8.4** Run `bin/rspec spec/models/prices/` — expect PASS; run `SCANNER_TIMING=1 bin/rspec spec/models/prices/refresh_timing_spec.rb` once, **alone**, and keep its printed line for `verification.md`. Commit: `test(prices): prove the refresh's transactions, its requests and its time (spec 089)`.

---

## Phase 9: Guards, documents and the index

**Implements:** FR-1 to FR-3's documentation, Decision 8, NFR | **Satisfies:** AC-5.4, AC-5.5, AC-5.7
**Files:** `README.md` (the backup advice only), `docs/roadmap.md`, `CLAUDE.md` (the status paragraph), `docs/specs/README.md`, `docs/specs/089-daily-price-refresh/verification.md`; `docs/architecture/prices.md` and `docs/architecture/catalog-operations.md` by `distill-feature`
**Interfaces:** Consumes: the finished code. Produces: documents that say what the job does, each statement with its source.

- [ ] **T9.1** Run the checks: `bin/rubocop`, `bin/yard doc` (no warning), `ruby script/yard/comment_ratchet.rb` (the step `bin/ci checks` runs; read `config/ci.rb` for its exact command), `bin/brakeman -q`, `bin/rspec spec/price_source_core_spec.rb spec/prices_core_spec.rb spec/prices_schema_spec.rb spec/backup_guards_spec.rb spec/config/recurring_spec.rb`, `ruby script/upgrade/guard.rb`. Fix what they say (a missing comment, a `{…}` in a comment, a collectible name in a core comment). Commit any fixes: `chore(prices): satisfy the comment ratchet and the core guard (spec 089)`.

- [ ] **T9.2** `README.md`, "Back up": the advice reads "before every upgrade and daily, never Monday 03:00–05:00". Add the daily window: the price refresh runs daily at 11:30 server time and writes the prices database, which a backup's read transaction holds back (ADR 0029, Cost): "never Monday 03:00–05:00, and not around 11:30 (the daily price refresh)". Keep the table row in `release-and-deploy.md` in step (`Backup schedule advice`) — that area doc is `distill-feature`'s, so only `README.md` here. Source: spec 089 decision 8; ADR 0029.

- [ ] **T9.3** `docs/roadmap.md`: the prices lane's #365 row becomes "Done: [spec 089](specs/089-daily-price-refresh/spec.md)" in the form #364's row uses. `CLAUDE.md`'s status paragraph: where it says the prices database "whose five tables exist, with a price source contract and Scryfall's prices through it … and no refresh or reader yet", say the daily refresh exists (`Prices::Refresh`, `Prices::RefreshJob`, `PriceRefreshRun`, spec 089, #365), leaving "no reader yet" and #366 to #369 as they are. Do not restate the area doc's rules (`documentation.md`).

- [ ] **T9.4** `docs/specs/README.md`: the spec's row already exists (status "Approved", plan "present"); leave its status for `distill-feature`.

- [ ] **T9.5** Create `docs/specs/089-daily-price-refresh/verification.md`: one row per AC with the evidence (the spec file and example, or the command and its output), the timing line of T8.4, the document criteria verified by reading (AC-5.7), and an empty `## Implementation review` heading for the review's verdict.

- [ ] **T9.6** What `distill-feature` must write into the area docs (it runs after the implementation review; this list is the plan's commitment, spec AC-5.7 and the coordinator's Gate A note):
  - **`prices.md`:** the daily refresh's rules (decisions 3 to 7): the run's date, "unchanged writes nothing" and what freshness means (the latest finished `run_on`, with the lag known limit); the four cases and the blank row; the absence rules and the five conditions, the candidate rule and what a withheld removal is; the guards and the errors table; the models and their keys; the run record's columns, with where #366 starts; `MAX_REMOVED_SHARE` in Named constants **as a guess until #366 measures the daily share of disappearing prices, and that a real drop above it is refused until the constant moves**; `BATCH_SIZE`, `STALL_AFTER`, `HEARTBEAT_EVERY`, `LOCK_FOR` rows; the "Only `PriceSource` and `PriceSeries` are models" invariant and the "Two models exist" decision replaced; spec 081's `run_on` supersession; **what an operator sees and does when a guard or a bad file fails the job every day, since there is no prices page until #367**: one Failed job a day under `/admin/jobs` (`Prices::RefreshJob`), whose exception says what happened (`Prices::Refresh::GuardError` with how many of how many prices, `Zlib::Error` for a cut-short file, `Catalog::Sources::ConfigurationError` naming a bad language code); the failed run row in `price_refresh_runs`; a standing ceiling breach is refused until `MAX_REMOVED_SHARE` is raised; Solid Queue's hourly clearing removes only finished jobs, so an admin discards a failed job by hand; and the as-of label lags while runs fail.
  - **`catalog-operations.md`:** the shared download (the price refresh asks the catalog source for the same file; a file one job downloaded is reused by the other; an instance with more languages downloads the large file daily), the unique partial file name and `STALE_PARTIAL_AFTER`, the contract's concurrent-call line, the supersession of spec 002 FR-3's "a partial file", and that the price refresh does not use `Catalog::Operation` (a pointer to `prices.md`).
  - Both: the spec's sources inline, and the distillation log rows.

- [ ] **T9.7** Commit the documents (stage and commit separately): `docs: the daily price refresh in the roadmap, the status paragraph and the backup advice (spec 089)`.

---

## Phase 10: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run `bin/ci checks` — expect all steps pass (RuboCop, YARD, the comment ratchet, Brakeman, bundler-audit, importmap audit, the migration guard).
- [ ] Run, one at a time on the shared test database: `bin/rspec spec/models/prices spec/models/price_refresh_run_spec.rb spec/models/current_price_spec.rb spec/models/price_change_spec.rb spec/jobs/prices spec/config spec/models/mtg/scryfall spec/jobs/catalog spec/models/catalog spec/prices_schema_spec.rb spec/prices_core_spec.rb spec/price_source_core_spec.rb spec/backup_guards_spec.rb` — expect PASS.
- [ ] Do **not** run a separate full `bin/ci`: the one full run is the push's, with the coordinator's slot, after the implementation review and the wrap.
- [ ] Verify each AC against `verification.md`; commit: `docs(specs): verification of spec 089`.

---

## Quickstart Validation

On a development database with the catalog loaded and Scryfall reachable (the maintainer's machine, not the suite):

1. `bin/rails runner 'Prices::RefreshJob.perform_later("scryfall")'` (the dev server runs Solid Queue inside Puma; never `bin/jobs`).
2. Watch `/admin/jobs`: the job runs on `sync`.
3. `bin/rails runner 'p PriceRefreshRun.order(:id).last.attributes'` — a `finished` run with `run_on` the file's UTC date and counts; `p CurrentPrice.count, PriceChange.count`.
4. Queue it again: the new run is `skipped` with `<version> already applied` and no row changes.
