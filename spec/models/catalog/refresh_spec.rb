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
    create(:catalog_refresh_run, :running, collectible_type: "fake")

    expect(refresh).to be_skipped
    expect(Catalog::Entry.count).to eq(0)
  end

  describe "the job running it (spec 015 FR-1)" do
    it "records the job running it, and closes that job's own running run when it starts again (AC-3.3)", :aggregate_failures do
      left = create(:catalog_refresh_run, :running, collectible_type: "fake", job_id: "job-1")

      run = described_class.new("fake", trigger: "manual", source:, job_id: "job-1").call

      expect(run).to have_attributes(status: "applied", job_id: "job-1")
      expect(left.reload).to have_attributes(status: "failed", message: "interrupted")
    end

    it "gives the same catalog when a job runs again after being interrupted partway (AC-3.8)", :aggregate_failures do
      source.entries = [ entry_record("a"), entry_record("b"), entry_record("c") ]
      source.fail_at = 2
      expect { described_class.new("fake", trigger: "manual", source:, job_id: "job-1").call }.to raise_error(RuntimeError)
      Catalog::RefreshRun.recent.first.update!(status: "running", finished_at: nil) # as a killed worker leaves it
      source.fail_at = nil

      run = described_class.new("fake", trigger: "manual", source:, job_id: "job-1").call

      expect(run).to have_attributes(status: "applied", seen_count: 3)
      expect(Catalog::Entry.active.pluck(:external_key)).to contain_exactly("a", "b", "c")
      expect(Catalog::RefreshRun.where(status: "running")).to be_empty
    end
  end

  describe "stage and progress (spec 015 FR-1)" do
    # Every write of the run's progress, in order, as [stage, done, total, seen so far], or as what the block makes
    # of it at the moment of the write.
    def progress_writes(&observe)
      observe ||= ->(progress) { [ progress[:stage], progress[:done], progress[:total], progress[:counts][:seen] ] }
      writes = []
      allow_any_instance_of(Catalog::RefreshRun).to receive(:progress!).and_wrap_original do |original, **progress| # rubocop:disable RSpec/AnyInstance -- the run is created inside the refresh
        writes << observe.call(progress)
        original.call(**progress)
      end
      writes
    end

    it "passes through the four stages in order and keeps the last one (AC-2.4)", :aggregate_failures do
      writes = progress_writes

      run = refresh

      expect(writes.map(&:first)).to eq(%w[download sync retire index])
      expect(run).to have_attributes(status: "applied", stage: "index")
    end

    it "keeps the stage reached when the run fails (AC-3.1)", :aggregate_failures do
      source.fail_at = 1

      expect { refresh }.to raise_error(RuntimeError)
      expect(Catalog::RefreshRun.recent.first).to have_attributes(status: "failed", stage: "sync", seen_count: 1)
    end

    context "with a source that reports how far it is" do
      let(:source) { ReportingCatalogSource.new(sets: [ set_record("lea") ], entries: [ entry_record("a"), entry_record("b") ]) }
      let(:now) { [ 0.0 ] }
      let(:clock) { -> { now[0] += 3 } } # every look at the clock is 3 seconds later, so every report is due

      it "records bytes of the download and of the file, with the counts so far (AC-2.5, AC-2.6)", :aggregate_failures do
        writes = progress_writes

        described_class.new("fake", trigger: "manual", source:, clock:).call

        expect(writes).to include([ "download", 50, 100, 0 ], [ "download", 100, 100, 0 ], [ "sync", 1, 2, 0 ], [ "sync", 2, 2, 1 ])
        expect(writes.last).to eq([ "index", nil, nil, 2 ])
      end

      it "never writes progress inside a batch's write transaction (spec 015 FR-1 must not)", :aggregate_failures do
        stub_const("Catalog::Refresh::BATCH_SIZE", 2) # a batch is written every two records, between writes of progress
        source.entries = %w[a b c d e].map { |key| entry_record(key) }
        connection = ActiveRecord::Base.connection
        outside = connection.open_transactions # the example's own transaction, and nothing else
        writes = progress_writes { |progress| [ progress[:stage], progress[:counts][:inserted], connection.open_transactions ] }

        described_class.new("fake", trigger: "manual", source:, clock:).call

        expect(writes.map(&:last).uniq).to eq([ outside ])
        # Progress was written before, between and after the batches, so a write inside one would have been seen.
        expect(writes.filter_map { |stage, inserted, _open| inserted if stage == "sync" }.uniq).to eq([ 0, 2, 4 ])
      end
    end

    it "works with a source that reports nothing: stages and counts only (AC-2.8)" do
      writes = progress_writes

      refresh

      expect(writes.map { |_stage, done, total, _seen| [ done, total ] }.uniq).to eq([ [ nil, nil ] ])
    end
  end

  describe "the name index (spec 007 AC-3.9)" do
    def names(text) = Catalog::NameIndex.new("fake", source_class: FakeCatalogSource).search(text).map(&:name)

    it "indexes the cards of an applied refresh, including one added later", :aggregate_failures do
      refresh
      expect(names("Lightning Bolt")).to eq([ "Lightning Bolt" ])
      source.entries += [ entry_record("c", identity: identity_record("helix", name: "Lightning Helix")) ]
      refresh
      expect(names("Lightning Helix")).to include("Lightning Helix")
    end

    it "rebuilds an empty index when a scheduled run is skipped", :aggregate_failures do
      refresh(trigger: "scheduled")
      Catalog::Name.delete_all
      expect(refresh(trigger: "scheduled")).to have_attributes(status: "skipped", message: "v1 already applied; name index rebuilt with 1 name")
      expect(names("Lightning Bolt")).to eq([ "Lightning Bolt" ])
    end

    it "leaves a populated index alone when a scheduled run is skipped" do
      refresh(trigger: "scheduled")
      expect { refresh(trigger: "scheduled") }.not_to(change { Catalog::Name.pluck(:id) })
    end
  end

  context "with a source's refresh hooks (spec 011 AC-2.3, AC-2.4)" do
    it "applies an already-applied version again when the source asks before the skip decision", :aggregate_failures do
      refresh(trigger: "scheduled")
      source.reapply = true

      run = refresh(trigger: "scheduled")

      expect(run).to have_attributes(status: "applied", source_version: "v1")
      expect(source.downloads).to eq(%w[v1 v1])
    end

    it "skips an already-applied scheduled version when the source doesn't ask" do
      refresh(trigger: "scheduled")

      expect(refresh(trigger: "scheduled")).to have_attributes(status: "skipped")
    end

    it "tells the source after an applied run and after an already-applied skip" do
      refresh(trigger: "scheduled")
      refresh(trigger: "scheduled")

      expect(source.refreshed).to eq([ %w[applied v1], %w[skipped v1] ])
    end

    it "doesn't tell the source when the refresh was skipped because another one is running", :aggregate_failures do
      create(:catalog_refresh_run, collectible_type: "fake", status: "running", finished_at: nil, started_at: 1.minute.ago)

      expect(refresh).to have_attributes(status: "skipped", message: "already running")
      expect(source.refreshed).to be_empty
    end

    it "works with a source that implements neither hook" do
      plain = Class.new(FakeCatalogSource) { undef_method :reapply?, :after_refresh }.new(sets: [ set_record("lea") ], entries: [ entry_record("a") ])

      expect(described_class.new("fake", trigger: "manual", source: plain).call).to have_attributes(status: "applied")
    end
  end
end
