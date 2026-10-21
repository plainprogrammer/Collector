require "rails_helper"

RSpec.describe ImportUpload::SweepJob, type: :job do
  it "sweeps on the default queue, taking no argument", :aggregate_failures do
    expect(described_class.new.queue_name).to eq("default")
    allow(ImportUpload).to receive(:sweep!)

    described_class.perform_now

    expect(ImportUpload).to have_received(:sweep!)
  end
end
