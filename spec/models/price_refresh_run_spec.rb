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
      b = run!(job_id: "x").tap { it.finish!(unchanged: 3, repriced: 1, bogus: 9) }
      c = run!(job_id: "y").tap { it.fail!(RuntimeError.new("boom"), added: 2) }

      expect(a).to have_attributes(status: "skipped", error: "v1 already applied", run_on: Date.new(2026, 11, 13))
      expect(b).to have_attributes(status: "finished", unchanged: 3, repriced: 1)
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
      travel_to(now + 31.seconds) do
        run.heartbeat
        run.progress!(unchanged: 4, malformed: 1)
      end

      expect([ first, second ]).to eq([ now, now ])
      expect(run.reload.updated_at).to be >= now + 31.seconds
      expect(run).to have_attributes(unchanged: 4, malformed: 1)
    end
  end
end
