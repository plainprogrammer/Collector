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

  # The source's client no longer sleeps through a long Retry-After: it raises, and the queue holds the retry for as
  # long as the source asked, instead of a worker (issue #74, Catalog::RateLimitRetry).
  context "when the source rate limits the refresh (issue #74)" do
    def rate_limited(retry_after) = Catalog::Sources::RateLimitedError.new("rate limited", retry_after:)

    before { freeze_time }

    it "comes back when the source asked, not at a transient error's few seconds" do
      allow(Catalog::Refresh).to receive(:new).and_raise(rate_limited(600))

      expect { described_class.perform_now("mtg") }.to have_enqueued_job(described_class).with("mtg").at(600.seconds.from_now)
    end

    # The 30 seconds Scryfall says a 429 limits access for, and a margin: the wait runs from when the error is handled.
    [ nil, 0, 5, 30, 44 ].each do |asked|
      it "waits 45 seconds at least, when the source asked for #{asked.inspect}" do
        allow(Catalog::Refresh).to receive(:new).and_raise(rate_limited(asked))

        expect { described_class.perform_now("mtg") }.to have_enqueued_job(described_class).at(45.seconds.from_now)
      end
    end

    it "waits what the source asked for once that is more than 45 seconds" do
      allow(Catalog::Refresh).to receive(:new).and_raise(rate_limited(46))

      expect { described_class.perform_now("mtg") }.to have_enqueued_job(described_class).at(46.seconds.from_now)
    end

    it "waits as long as an hour when asked" do
      allow(Catalog::Refresh).to receive(:new).and_raise(rate_limited(3600))

      expect { described_class.perform_now("mtg") }.to have_enqueued_job(described_class).at(1.hour.from_now)
    end

    it "fails instead of waiting when asked for more than an hour", :aggregate_failures do
      allow(Catalog::Refresh).to receive(:new).and_raise(rate_limited(3601))

      expect { expect { described_class.perform_now("mtg") }.to raise_error(Catalog::Sources::RateLimitedError) }
        .not_to have_enqueued_job(described_class)
    end

    it "fails the fourth time it is rate limited, after 3 retries", :aggregate_failures do
      allow(Catalog::Refresh).to receive(:new).and_raise(rate_limited(60))
      job = described_class.new("mtg")

      expect { 3.times { job.perform_now } }.to have_enqueued_job(described_class).exactly(3).times
      expect { expect { job.perform_now }.to raise_error(Catalog::Sources::RateLimitedError) }.not_to have_enqueued_job(described_class)
    end

    # As a worker runs them: each retry is the queued job's data, so the count has to travel with the job.
    it "keeps count of its retries in the queued job: the fourth, run from the queue, fails", :aggregate_failures do
      allow(Catalog::Refresh).to receive(:new).and_raise(rate_limited(60))
      queued = -> { ActiveJob::Base.queue_adapter.enqueued_jobs }
      described_class.perform_now("mtg")

      expect { 2.times { ActiveJob::Base.execute(queued.call.last) } }.to change { queued.call.size }.by(2)
      expect { expect { ActiveJob::Base.execute(queued.call.last) }.to raise_error(Catalog::Sources::RateLimitedError) }
        .not_to change { queued.call.size }
    end

    it "counts rate limits and other transient errors each on their own", :aggregate_failures do
      errors = [ rate_limited(60), rate_limited(60), rate_limited(60) ] + Array.new(3) { Catalog::Sources::TransientError.new("timeout") }
      allow(Catalog::Refresh).to receive(:new) { raise errors.shift }
      job = described_class.new("mtg")

      # 3 retries for the rate limits, then the transient rule's own 2 of its 3 attempts.
      expect { 5.times { job.perform_now } }.to have_enqueued_job(described_class).exactly(5).times
      expect { job.perform_now }.to raise_error(Catalog::Sources::TransientError, "timeout")
    end

    it "leaves a run that says how long Scryfall asked for, and is queued to run again then", :aggregate_failures do
      stub_request(:get, "https://api.scryfall.com/bulk-data").to_return(status: 429, headers: { "Retry-After" => "600" })

      expect { described_class.perform_now("mtg") }.to have_enqueued_job(described_class).with("mtg").at(600.seconds.from_now)
      expect(Catalog::RefreshRun.sole).to have_attributes(status: "failed",
        message: "Catalog::Sources::RateLimitedError: GET https://api.scryfall.com/bulk-data returned 429 and asked for 600 seconds " \
                 "before a retry; the client waits at most 30")
    end

    # Scryfall limits access for 30 seconds after a 429, and may not say so in a Retry-After. The refresh then asks
    # nothing more in that run, and its job is the next to ask, 45 seconds later (issue #81).
    it "asks Scryfall once when a 429 gives no Retry-After, and is queued to run again 45 seconds later", :aggregate_failures do
      limited = stub_request(:get, "https://api.scryfall.com/bulk-data").to_return({ status: 429 }, { status: 429 }, { status: 429 })
      allow(MTG::Scryfall::Client).to receive(:new).and_return(MTG::Scryfall::Client.new(sleeper: ->(_) { }, clock: -> { 0.0 }))

      expect { described_class.perform_now("mtg") }.to have_enqueued_job(described_class).with("mtg").at(45.seconds.from_now)
      expect(limited).to have_been_requested.once
      expect(Catalog::RefreshRun.sole).to have_attributes(status: "failed",
        message: "Catalog::Sources::RateLimitedError: GET https://api.scryfall.com/bulk-data returned 429 with no usable Retry-After; " \
                 "Scryfall limits access for 30 seconds after a 429, so the client doesn't ask again in this call")
    end
  end
end
