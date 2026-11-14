require "rails_helper"

RSpec.describe Prices::Refresh, type: :model do
  def refresh(job_id: "job-1") = described_class.new("fake_source", job_id:)
  def last_run = PriceRefreshRun.order(:id).last

  describe "before it applies anything" do
    it "skips with a reason and no date when the catalog has no printing of the type, asking the catalog's source nothing (AC-1.5)", :aggregate_failures do
      use_widget_sources(records: [ widget_quote("w-1", 100) ])
      allow(Catalog).to receive(:source_for).and_call_original

      run = refresh.call

      expect(Catalog).not_to have_received(:source_for)
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

      expect { refresh.call }.to raise_error(Prices::Refresh::GuardError, /no valid quotes/) # a file with no quote is a GuardError (AC-3.5)

      expect(PriceSource.pluck(:key)).to eq([ "fake_source" ])
      expect(PriceSeries.count).to eq(1)
      expect(last_run.price_source.key).to eq("fake_source")
    end

    it "skips a file already applied for the same version and languages, copying its date (AC-1.2; the end-to-end example proves nothing is downloaded again)", :aggregate_failures do
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

    it "skips a file older than the latest finished or failed run (AC-1.4)", :aggregate_failures do
      use_widget_sources(reported_on: Date.new(2026, 11, 12), records: [ widget_quote("w-1", 100) ])
      widget_entry("w-1")
      PriceRefreshRun.create!(price_source: price_source_row, status: "failed", source_version: "other", languages: "en",
        run_on: Date.new(2026, 11, 13), started_at: 2.hours.ago)

      older = refresh.call

      expect(older).to have_attributes(status: "skipped", run_on: Date.new(2026, 11, 12))
      expect(older.error).to include("2026-11-13")
      expect([ CurrentPrice.count, PriceChange.count ]).to eq([ 0, 0 ])
    end

    it "skips a file older than a finished run, and applies another version of the finished run's own day (AC-1.4)", :aggregate_failures do
      widget_entry("w-1")
      PriceRefreshRun.create!(price_source: price_source_row, status: "finished", source_version: "v1", languages: "en",
        run_on: Date.new(2026, 11, 13), started_at: 2.hours.ago)
      use_widget_sources(reported_on: Date.new(2026, 11, 12), records: [ widget_quote("w-1", 100) ], version: "old")
      older = refresh.call
      use_widget_sources(reported_on: Date.new(2026, 11, 13), records: [ widget_quote("w-1", 100) ], version: "v2")

      same_day = refresh.call

      expect(older.status).to eq("skipped")
      expect(same_day).to have_attributes(status: "finished", run_on: Date.new(2026, 11, 13))
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
      touches = []
      during = nil
      stub_const("WidgetCatalog", Class.new(ReportingCatalogSource) do
        define_method(:initialize) { |*| super(version: "v1", languages: [ "en" ]) }
        define_method(:download) { |version, dir:| before = touches.size; super(version, dir:).tap { during = touches.size - before } }
      end)
      callback = ->(*, payload) { touches << payload[:sql] if payload[:sql].to_s.match?(/UPDATE "price_refresh_runs" SET "updated_at" = [^,]+ WHERE/) }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { refresh.call }

      expect(during).to eq(1) # ReportingCatalogSource reports twice within one instant while downloading: one touch, which sets only updated_at
    end
  end

  describe "judging quotes" do
    def rows = CurrentPrice.pluck(:catalog_entry_id, :cents, :reported_on, :changed_on)
    def history = PriceChange.order(:catalog_entry_id, :recorded_on).pluck(:catalog_entry_id, :recorded_on, :cents)

    it "adds a price no one has, with a history row for the run's date, and finishes the run (AC-1.1, AC-2.1)", :aggregate_failures do
      use_widget_sources(records: [ widget_quote("w-1", 142) ], reported_on: Date.new(2026, 11, 13))
      entry = widget_entry("w-1")

      run = refresh.call

      expect(run).to have_attributes(status: "finished", run_on: Date.new(2026, 11, 13), source_version: "v1", languages: "en",
        job_id: "job-1", added: 1, quotes_seen: 1, unchanged: 0, repriced: 0)
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

      expect(run).to have_attributes(unchanged: 1, repriced: 0, added: 0, quotes_seen: 1)
      expect(rows).to eq([ [ entry.id, 100, Date.new(2026, 11, 12), Date.new(2026, 11, 12) ] ])
      expect(history.size).to eq(1)
    end

    it "updates a changed price and adds one history row, leaving the earlier ones (AC-2.3)", :aggregate_failures do
      use_widget_sources(records: [ widget_quote("w-1", 150) ])
      entry = widget_entry("w-1")
      seed_price(entry, 100, on: Date.new(2026, 11, 12))

      run = refresh.call

      expect(run).to have_attributes(repriced: 1, added: 0, unchanged: 0)
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

      expect(run).to have_attributes(quotes_seen: 3, unchanged: 1, repriced: 1, added: 1)
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

    it "touches the run after every batch, even one that writes nothing (AC-4.7)", :aggregate_failures do
      stub_const("Prices::Refresh::BATCH_SIZE", 2)
      entries = Array.new(5) { |index| widget_entry("w-#{index}") }
      entries.each { |entry| seed_price(entry, 100) }
      use_widget_sources(records: entries.map { widget_quote(it.external_key, 100) }) # all unchanged: no batch writes a price
      progress = []
      callback = ->(*, payload) { progress << payload[:sql] if payload[:sql].to_s.start_with?('UPDATE "price_refresh_runs" SET') && payload[:sql].include?('"quotes_seen"') }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { refresh.call }

      expect(CurrentPrice.pluck(:cents).uniq).to eq([ 100 ]) # nothing was written
      expect(progress.size).to eq(3) # a progress write per batch (2, 2 and 1 printings): only they put quotes_seen in an UPDATE's SET
    end
  end

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
      CurrentPrice.insert_all!([ { catalog_entry_id: 9_999_999, price_source_id: price_source_row.id, price_series_id: series_row.id, cents: 5, reported_on: Date.new(2026, 11, 12), changed_on: Date.new(2026, 11, 12) } ])
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

    it "fails the run, with the reader's error, when the file is cut short; earlier batches stand, nothing is removed, and a whole file of the day finishes without a duplicate row (AC-3.4)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- two runs of one scenario
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

    it "touches the run for each slice of the removal walk (AC-4.7)" do
      stub_const("Prices::Refresh::BATCH_SIZE", 2)
      seed_candidates(10)
      widget_entry("gone").tap { seed_price(it, 100) }
      use_widget_sources(records: keep_quotes(10))
      progress = []
      callback = ->(*, payload) { progress << payload[:sql] if payload[:sql].to_s.start_with?('UPDATE "price_refresh_runs" SET') && payload[:sql].include?('"updated_at"') }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { refresh.call }

      expect(progress.size).to be >= 12 # eleven candidates in slices of two: six slices in each of the two walks
    end

    it "leaves both or neither of a removal batch's current price and blank history row when the batch fails (AC-3.9)", :aggregate_failures do
      seed_candidates(10)
      gone = widget_entry("gone").tap { seed_price(it, 100) }
      use_widget_sources(records: keep_quotes(10))
      PricesRecord.lease_connection.execute("CREATE TRIGGER no_blank_history BEFORE INSERT ON price_changes WHEN NEW.cents IS NULL BEGIN SELECT RAISE(ABORT, 'injected'); END")

      expect { refresh.call }.to raise_error(ActiveRecord::StatementInvalid, /injected/)

      expect(CurrentPrice.where(catalog_entry_id: gone.id).count).to eq(1)
      expect(blank_history(gone)).to be_empty

      PricesRecord.lease_connection.execute("DROP TRIGGER no_blank_history")
      run = refresh.call

      expect(run).to have_attributes(status: "finished", removed: 1)
      expect(CurrentPrice.where(catalog_entry_id: gone.id)).to be_empty
      expect(blank_history(gone)).to eq([ Date.new(2026, 11, 13) ])
    end
  end
end
