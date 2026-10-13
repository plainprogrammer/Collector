require "rails_helper"

RSpec.describe Catalog::RefreshJob, type: :job do
  it "allows one refresh per collectible type at a time, queuing the rest", :aggregate_failures do
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.concurrency_on_conflict).to eq(:block)
    expect(described_class.concurrency_duration).to eq(6.hours) # not the run's 15-minute stall threshold (spec 015 FR-1)
    expect(described_class.new("mtg").concurrency_key).to eq("Catalog::RefreshJob/mtg")
  end

  it "runs a refresh for the collectible type and trigger, under its own job id (spec 015 FR-1)" do
    refresh = instance_double(Catalog::Refresh, call: nil)
    allow(Catalog::Refresh).to receive(:new).and_return(refresh)
    job = described_class.new("mtg", "scheduled")

    job.perform_now

    expect(Catalog::Refresh).to have_received(:new).with("mtg", trigger: "scheduled", job_id: job.job_id)
  end

  it "is followed by the art build when it applies with art matching on, as a scheduled refresh is (spec 015 AC-4.9)", :art_matching do
    stub_scryfall(cards: [ scryfall_card ])

    expect { described_class.perform_now("mtg", "manual") }.to have_enqueued_job(MTG::Art::BuildJob).once
  ensure
    FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir)
  end

  it "retries transient source errors" do
    allow(Catalog::Refresh).to receive(:new).and_raise(Catalog::Sources::TransientError, "timeout")

    expect { described_class.perform_now("mtg") }.to have_enqueued_job(described_class).with("mtg")
  end

  # The source's client no longer sleeps through a long Retry-After: it raises, and the queue holds the retry instead
  # of a worker (issue #74).
  it "retries a rate-limited source as a transient error, instead of a worker waiting it out" do
    allow(Catalog::Refresh).to receive(:new).and_raise(Catalog::Sources::RateLimitedError, "asked for 600 seconds")

    expect { described_class.perform_now("mtg") }.to have_enqueued_job(described_class).with("mtg")
  end
end
