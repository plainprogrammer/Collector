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

  # The waiting retry holds no concurrency lock, so the schedule or `catalog:refresh` can queue another refresh meanwhile
  # (issue #78). The issue's probe: that refresh must not ask the source inside the window it asked us to stay out of.
  context "when another refresh for the type waits to run again (issue #78)", :solid_queue do
    it "asks the source nothing, whoever started it, and leaves the work to the waiting job", :aggregate_failures do
      queue_job(described_class, "mtg", "manual", wait: 10.minutes)
      bulk_data = stub_request(:get, "https://api.scryfall.com/bulk-data").to_return(status: 429, headers: { "Retry-After" => "600" })

      %w[scheduled manual].each { |trigger| described_class.perform_now("mtg", trigger) }

      expect(bulk_data).not_to have_been_requested
      expect(Catalog::RefreshRun.pluck(:trigger, :status, :message)).to contain_exactly(
        [ "scheduled", "skipped", "waiting for another job's retry" ], [ "manual", "skipped", "waiting for another job's retry" ])
      expect(SolidQueue::Job.where(class_name: described_class.name, finished_at: nil).count).to eq(1) # one retry chain
    end
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

    def with_count(job, count) = job.tap { |queued| queued.exception_executions[Catalog::RateLimitRetry::COUNTED_AS] = count }

    def count_of(job) = job.exception_executions[Catalog::RateLimitRetry::COUNTED_AS]

    # Spec 043: only a refresh that wrote catalog rows before the rate limit starts the count again.
    describe "and its count is kept only without progress (spec 043)" do
      it "counts a rate limit on /bulk-data as no progress (AC-3.1)", :aggregate_failures do
        stub_request(:get, "https://api.scryfall.com/bulk-data").to_return(status: 429)
        job = with_count(described_class.new("mtg"), 2)

        expect { job.perform_now }.to have_enqueued_job(described_class).at(45.seconds.from_now)
        expect(count_of(job)).to eq(3)
      end

      it "counts a rate limit on /sets after a fresh download as no progress (AC-3.2)", :aggregate_failures do
        file = stub_scryfall(cards: [ scryfall_card ])
        stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429)
        job = with_count(described_class.new("mtg"), 2)

        expect { job.perform_now }.to have_enqueued_job(described_class)
        expect(file).to have_been_requested
        expect(count_of(job)).to eq(3)
      ensure
        FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir)
      end

      it "starts the count again after an attempt that wrote rows, then fails on the third rate limit with none (AC-3.3, AC-3.4)",
        :aggregate_failures do
        stub_const("Catalog::Refresh::BATCH_SIZE", 1)
        allow(Catalog).to receive(:source_for).with("fake").and_return(RateLimitedCatalogSource.new(entries: [ entry_record("a") ]))
        job = with_count(described_class.new("fake"), 3)

        expect { job.perform_now }.to have_enqueued_job(described_class) # wrote "a", then was turned away
        expect(count_of(job)).to eq(1)
        counts = []
        2.times do # nothing new to write
          job.perform_now
          counts << count_of(job)
        end
        expect(counts).to eq([ 2, 3 ])
        expect { job.perform_now }.to raise_error(Catalog::Sources::RateLimitedError)
      end

      # Decision 4, note 2: one job instance, two attempts. The second can't build its refresh, so it has made no
      # progress, whatever the first did.
      it "doesn't carry one attempt's progress into the next on the same job instance", :aggregate_failures do
        stub_const("Catalog::Refresh::BATCH_SIZE", 1)
        allow(Catalog).to receive(:source_for).with("fake").and_return(RateLimitedCatalogSource.new(entries: [ entry_record("a") ]))
        job = with_count(described_class.new("fake"), 0)

        job.perform_now
        expect(count_of(job)).to eq(1) # wrote "a", then was turned away: progress
        allow(Catalog::Refresh).to receive(:new).and_raise(rate_limited(60))
        job.perform_now
        expect(count_of(job)).to eq(2) # not 1: the first attempt's answer is gone
      end
    end

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

  # Spec 055 AC-2.4, AC-2.5: Retry now moves the waiting row; the job that runs is that row, with its retry record.
  context "when Retry now has moved its waiting retry (spec 055)", :solid_queue do
    def scheduled_row(active_job_id) = SolidQueue::Job.where(active_job_id:, finished_at: nil).find(&:scheduled?)

    it "carries on counting from the job's retry record, and opens a run under the same job id as any retry does", :aggregate_failures do
      stub_request(:get, "https://api.scryfall.com/bulk-data").to_return(status: 429, headers: { "Retry-After" => "600" })
      described_class.perform_now("mtg", "manual")
      waiting = scheduled_row(Catalog::RefreshRun.sole.job_id)
      counted = Catalog::RateLimitRetry::COUNTED_AS
      expect(waiting.arguments["exception_executions"]).to eq(counted => 1)

      expect(Catalog::RefreshOperation.new("mtg").retry_now).to be(true)
      expect(waiting.reload).to be_ready
      expect(waiting.arguments["exception_executions"]).to eq(counted => 1) # the press left the retry record alone

      ActiveJob::Base.execute(waiting.arguments) # a worker runs the row; the source still turns it away, with no progress
      expect(scheduled_row(waiting.active_job_id).arguments["exception_executions"]).to eq(counted => 2) # 2, not 1 again
      expect(Catalog::RefreshRun.where(job_id: waiting.active_job_id).pluck(:status)).to eq(%w[failed failed])
    end
  end
end
