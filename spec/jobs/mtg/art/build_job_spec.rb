require "rails_helper"

RSpec.describe MTG::Art::BuildJob, type: :job do
  it "runs on the catalog's queue" do
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue("sync")
  end

  it "runs a build under its own job id, so a re-run after a restart carries on (AC-3.2)" do
    job = described_class.new
    allow(MTG::Art::Build).to receive(:new).and_call_original

    job.perform_now

    expect(MTG::Art::Build).to have_received(:new).with(job_id: job.job_id)
  end

  # The build marks its run failed and re-raises; the retry keeps the job id, so MTG::ArtBuild.start! carries on (AC-3.2).
  [ SQLite3::BusyException, ActiveRecord::StatementTimeout ].each do |error|
    it "retries under the same job id when the database is busy (#{error})", :aggregate_failures do
      job = described_class.new
      allow(MTG::Art::Build).to receive(:new).and_raise(error, "database is locked")

      expect { job.perform_now }.to have_enqueued_job(described_class).exactly(:once)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.last["job_id"]).to eq(job.job_id)
    end
  end
end
