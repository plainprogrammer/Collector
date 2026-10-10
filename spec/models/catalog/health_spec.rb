require "rails_helper"

RSpec.describe Catalog::Health, type: :model do
  subject(:health) { described_class.new("mtg") }

  describe ".all and .find" do
    it "has one per registered type, in name order (spec 015 AC-5.1)", :other_catalog do
      expect(described_class.all.map(&:collectible_type)).to eq(%w[mtg other])
    end

    it "finds a registered type and raises not found for any other (AC-5.6)", :aggregate_failures do
      expect(described_class.find("mtg").collectible_type).to eq("mtg")
      expect { described_class.find("pokemon") }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  it "is titled by its source, or by its type when the source gives no title", :aggregate_failures, :other_catalog do
    expect(described_class.new("other").title).to eq("Pocket Monsters")
    Catalog.sources["plain"] = "FakeCatalogSource"
    expect(described_class.new("plain").title).to eq("Plain")
  ensure
    Catalog.sources.delete("plain")
  end

  it "counts the type's entries that aren't retired (AC-5.1)" do
    create(:catalog_entry)
    create(:catalog_entry, :retired)
    create(:catalog_entry, collectible_type: "other")

    expect(health.entries_count).to eq(1)
  end

  it "is loaded once the type has an applied refresh (glossary)", :aggregate_failures do
    create(:catalog_refresh_run, status: "failed")
    create(:catalog_refresh_run, collectible_type: "other")
    expect(health).not_to be_loaded

    applied = create(:catalog_refresh_run, source_version: "v7")
    expect(described_class.new("mtg")).to be_loaded.and have_attributes(last_applied: applied)
  end

  describe "#next_refresh_at (AC-5.5)" do
    def schedule(key, arguments)
      SolidQueue::RecurringTask.create!(key:, class_name: "Catalog::RefreshJob", arguments:, schedule: "every monday at 3:15am", static: true)
    end

    it "is nil when nothing is scheduled for the type" do
      schedule("refresh_other_catalog", %w[other scheduled])

      expect(health.next_refresh_at).to be_nil
    end

    it "is the next run of the type's recurring refresh, whatever its trigger argument" do
      schedule("refresh_mtg_catalog", %w[mtg scheduled])

      travel_to Time.utc(2026, 10, 9, 12) do
        expect(health.next_refresh_at).to eq(Time.utc(2026, 10, 12, 3, 15))
      end
    end
  end

  it "gives the configured languages, or why the setting can't be read (AC-1.4)", :aggregate_failures do
    expect(health.languages).to eq("EN")
    allow(Catalog).to receive(:source_for).and_return(FakeCatalogSource.new(languages: Catalog::Sources::ConfigurationError.new("unsupported language code(s): xx")))
    expect(health.languages).to eq("unsupported language code(s): xx")
  end

  describe "#operations" do
    it "is the refresh alone for a source that adds none (AC-5.2)" do
      Catalog.sources["plain"] = "FakeCatalogSource"
      expect(described_class.new("plain").operations.map(&:key)).to eq([ "refresh" ])
    ensure
      Catalog.sources.delete("plain")
    end

    it "is the refresh, then what the source adds (AC-5.3)", :aggregate_failures, :other_catalog do
      other = described_class.new("other")

      expect(other.operations.map(&:key)).to eq(%w[refresh price_sync])
      expect(other.refresh).to be_a(Catalog::RefreshOperation)
      expect(other.operation("price_sync").title).to eq("Price sync")
      expect(other.operation("missing")).to be_nil
    end
  end

  it "is in flight while any of its operations is", :solid_queue do
    expect { queue_job(Catalog::RefreshJob, "mtg", "scheduled") }.to change { described_class.new("mtg").in_flight? }.from(false).to(true)
  end

  it "lists the 5 most recent runs, skipped ones included (AC-5.1, AC-2.16)", :aggregate_failures do
    7.times { |n| create(:catalog_refresh_run, started_at: (n + 1).hours.ago, source_version: "v#{n}") }
    skipped = create(:catalog_refresh_run, status: "skipped", message: "already running", started_at: 1.minute.ago)

    expect(health.recent_runs.size).to eq(5)
    expect(health.recent_runs.first).to eq(skipped)
  end
end
