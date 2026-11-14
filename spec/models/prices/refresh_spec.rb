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

      expect { refresh.call }.not_to raise_error # Phase 6 makes a file with no quote a GuardError; T6.3 updates this example

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
end
