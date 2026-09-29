require "rails_helper"

RSpec.describe Catalog::Refresh, type: :model do
  let(:source) { FakeCatalogSource.new(sets: [ set_record("lea") ], entries: [ entry_record("a"), entry_record("b") ]) }

  def refresh(trigger: "manual") = described_class.new("fake", trigger:, source:).call

  it "inserts entries with their sets and identities and records the run", :aggregate_failures do
    run = refresh

    expect(run).to have_attributes(status: "applied", source_version: "v1", languages: "en", seen_count: 2, inserted_count: 2)
    expect(Catalog::Entry.pluck(:external_key)).to contain_exactly("a", "b")
    expect(Catalog::Identity.pluck(:external_key)).to eq([ "bolt" ])
    expect(Catalog::Set.pluck(:code)).to eq([ "lea" ])
  end

  it "writes nothing when the same data is applied again", :aggregate_failures do
    refresh
    stamps = Catalog::Entry.pluck(:updated_at)

    travel 1.hour do
      run = refresh
      expect(run).to have_attributes(inserted_count: 0, updated_count: 0, retired_count: 0)
    end
    expect(Catalog::Entry.count).to eq(2)
    expect(Catalog::Entry.pluck(:updated_at)).to eq(stamps)
  end

  it "updates only the entry whose stored data changed", :aggregate_failures do
    refresh
    source.entries = [ entry_record("a"), entry_record("b", number: "2") ]

    run = refresh

    expect(run.updated_count).to eq(1)
    expect(Catalog::Entry.find_by(external_key: "b").number).to eq("2")
  end

  it "updates an identity whose data changed even when no entry changed" do
    refresh
    source.entries = [ entry_record("a", identity: identity_record(extension: { errata: true })), entry_record("b") ]

    expect { refresh }.to change { Catalog::Identity.find_by(external_key: "bolt").content_digest }
  end

  it "retires entries missing from the source without deleting them", :aggregate_failures do
    refresh
    source.entries = [ entry_record("a") ]

    freeze_time do
      run = refresh
      expect(run.retired_count).to eq(1)
      expect(Catalog::Entry.find_by(external_key: "b").retired_at).to eq(Time.current)
    end
  end

  it "restores a retired entry that reappears, keeping its id", :aggregate_failures do
    refresh
    id = Catalog::Entry.find_by(external_key: "b").id
    source.entries = [ entry_record("a") ]
    refresh
    source.entries = [ entry_record("a"), entry_record("b") ]

    run = refresh

    expect(run.restored_count).to eq(1)
    expect(Catalog::Entry.find_by(external_key: "b")).to have_attributes(id:, retired_at: nil)
  end

  it "creates a set the listing lacks from the entry's own set code and name" do
    source.entries = [ entry_record("a", set_code: "xyz") ]

    refresh

    expect(Catalog::Set.find_by(code: "xyz").name).to eq("XYZ")
  end

  it "skips and counts malformed records", :aggregate_failures do
    source.entries = [ entry_record("a"), Catalog::Sources::Malformed.new(external_key: "bad", error: "KeyError") ]

    run = refresh

    expect(run).to have_attributes(status: "applied", seen_count: 1, malformed_count: 1)
  end

  it "does not retire an existing entry whose record is malformed this run", :aggregate_failures do
    refresh
    source.entries = [ entry_record("a"), Catalog::Sources::Malformed.new(external_key: "b", error: "KeyError") ]

    run = refresh

    expect(run.retired_count).to eq(0)
    expect(Catalog::Entry.find_by(external_key: "b")).not_to be_retired
  end

  it "fails without retiring anything when the source yields no valid records", :aggregate_failures do
    refresh
    source.entries = [ Catalog::Sources::Malformed.new(external_key: nil, error: "JSON::ParserError") ]

    expect { refresh }.to raise_error(Catalog::Sources::Error, /no valid records/)
    expect(Catalog::RefreshRun.recent.first).to be_failed
    expect(Catalog::Entry.active.count).to eq(2)
  end

  it "retires entries of a language that is no longer configured" do
    source.entries = [ entry_record("en-1"), entry_record("ja-1", language: "ja") ]
    source.languages_result = %w[en ja]
    refresh
    source.languages_result = [ "en" ]

    refresh(trigger: "scheduled")

    expect(Catalog::Entry.find_by(external_key: "ja-1")).to be_retired
  end

  context "when the run fails partway" do
    before do
      refresh
      source.entries = [ entry_record("a", number: "9"), entry_record("c"), entry_record("d") ]
      source.fail_at = 2
    end

    it "records the failure and retires nothing", :aggregate_failures do
      expect { refresh }.to raise_error(RuntimeError, "source exploded")

      run = Catalog::RefreshRun.recent.first
      expect(run).to have_attributes(status: "failed", message: "RuntimeError: source exploded", retired_count: 0)
      expect(Catalog::Entry.where.not(retired_at: nil)).to be_empty
      expect(Catalog::Entry.find_by(external_key: "b")).to be_present
    end

    it "is completed by the next run as if it never happened", :aggregate_failures do
      expect { refresh }.to raise_error(RuntimeError)
      source.fail_at = nil
      refresh

      expect(Catalog::Entry.active.pluck(:external_key)).to contain_exactly("a", "c", "d")
    end
  end

  describe "skipping" do
    before { refresh }

    it "skips a scheduled run when the version and languages were already applied", :aggregate_failures do
      run = refresh(trigger: "scheduled")

      expect(run).to have_attributes(status: "skipped", message: "v1 already applied")
      expect(source.downloads).to eq([ "v1" ])
    end

    it "applies a scheduled run when the source publishes a new version", :aggregate_failures do
      source.version = "v2"

      run = refresh(trigger: "scheduled")

      expect(run).to have_attributes(status: "applied", trigger: "scheduled", source_version: "v2")
      expect(source.downloads).to eq(%w[v1 v2])
    end

    it "applies a scheduled run when the language set changed" do
      source.languages_result = %w[en ja]

      expect(refresh(trigger: "scheduled")).to be_applied
    end

    it "never skips a manual run" do
      expect(refresh(trigger: "manual")).to be_applied
    end
  end

  it "fails before downloading when the language setting is invalid", :aggregate_failures do
    source.languages_result = Catalog::Sources::ConfigurationError.new("unsupported language code(s): xx")

    expect { refresh }.to raise_error(Catalog::Sources::ConfigurationError)
    expect(Catalog::RefreshRun.recent.first).to have_attributes(status: "failed", message: a_string_including("xx"))
    expect(source.downloads).to be_empty
  end

  it "records a skip without touching the catalog while another run is in progress", :aggregate_failures do
    create(:catalog_refresh_run, collectible_type: "fake", status: "running", started_at: 1.hour.ago, finished_at: nil)

    expect(refresh).to be_skipped
    expect(Catalog::Entry.count).to eq(0)
  end
end
