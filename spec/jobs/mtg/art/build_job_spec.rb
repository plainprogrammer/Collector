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
end
