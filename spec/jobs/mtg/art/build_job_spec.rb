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

  # The build has stopped and recorded why (MTG::Art::Build). Its job runs again when the host asked, under the same job
  # id, and the new run carries on from the images already cached (issue #74, Catalog::RateLimitRetry).
  context "when the image host rate limits the build (issue #74)" do
    def rate_limited(retry_after) = Catalog::Sources::RateLimitedError.new("rate limited", retry_after:)

    before { freeze_time }

    it "comes back when the host asked, under the same job id", :aggregate_failures do
      job = described_class.new
      allow(MTG::Art::Build).to receive(:new).and_raise(rate_limited(120))

      expect { job.perform_now }.to have_enqueued_job(described_class).at(120.seconds.from_now)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.last["job_id"]).to eq(job.job_id)
    end

    it "waits 45 seconds when the host never said how long" do
      allow(MTG::Art::Build).to receive(:new).and_raise(rate_limited(nil))

      expect { described_class.perform_now }.to have_enqueued_job(described_class).at(45.seconds.from_now)
    end

    it "fails instead of waiting when asked for more than an hour", :aggregate_failures do
      allow(MTG::Art::Build).to receive(:new).and_raise(rate_limited(3601))

      expect { expect { described_class.perform_now }.to raise_error(Catalog::Sources::RateLimitedError) }
        .not_to have_enqueued_job(described_class)
    end

    it "fails the fourth time it is rate limited, counting its 3 retries in the queued job", :aggregate_failures do
      allow(MTG::Art::Build).to receive(:new).and_raise(rate_limited(60))
      queued = -> { ActiveJob::Base.queue_adapter.enqueued_jobs }
      described_class.perform_now

      expect { 2.times { ActiveJob::Base.execute(queued.call.last) } }.to change { queued.call.size }.by(2)
      expect { expect { ActiveJob::Base.execute(queued.call.last) }.to raise_error(Catalog::Sources::RateLimitedError) }
        .not_to change { queued.call.size }
    end

    # Artworks in an applied catalog, oldest first, and a client that doesn't really sleep. Returns the image URLs.
    def artworks(names = %w[a b])
      create(:catalog_refresh_run, collectible_type: "mtg", source_version: "default-cards-1")
      allow(MTG::Scryfall::Client).to receive(:new).and_return(MTG::Scryfall::Client.new(sleeper: ->(_) { }, clock: -> { 0.0 }))
      names.map.with_index(1) do |name, year|
        url = "https://cards.scryfall.io/small/front/a/b/#{name}.jpg"
        create(:mtg_printing, illustration_id: "#{name * 8}-0000-4000-8000-000000000001", faces: [ { "image_uris" => { "small" => url } } ],
          entry: create(:catalog_entry, released_on: Date.new(2000 + year, 1, 1), set: create(:catalog_set)))
        url
      end
    end

    # One 429 that names no wait stops the build: the host isn't asked again inside the 30 seconds Scryfall limits
    # access for, and the job's retry, 45 seconds later, is the next request (issue #81).
    it "stops at one 429 with no Retry-After, and its retry 45 seconds later finishes the build without fetching an image twice",
      :aggregate_failures, :art_matching do
      images = artworks
      first = stub_request(:get, images.first).to_return(body: noisy_png)
      second = stub_request(:get, images.last).to_return({ status: 429 }, { body: noisy_png })
      job = described_class.new

      expect { job.perform_now }.to have_enqueued_job(described_class).at(45.seconds.from_now)
      expect(MTG::ArtBuild.sole).to have_attributes(status: "failed", job_id: job.job_id, fetched_count: 1, failed_count: 0,
        message: include("returned 429 with no usable Retry-After"))
      expect(second).to have_been_requested.once

      ActiveJob::Base.execute(ActiveJob::Base.queue_adapter.enqueued_jobs.last) # the queued retry, as a worker runs it

      expect(MTG::ArtBuild.recent.first).to have_attributes(status: "finished", job_id: job.job_id, fetched_count: 1, failed_count: 0, indexed_count: 2)
      expect(first).to have_been_requested.once
      expect(second).to have_been_requested.twice
    end

    # The issue's scenario (#86): every attempt but the last fetched images before it was turned away. Attempt 1 fetches a
    # and meets a 429 on b; 2 fetches b and meets one on c; 3 fetches c and meets one on d; 4 has nothing new to fetch.
    it "retries a fourth rate limit when the first three attempts fetched images and the fourth fetched none (AC-2.5)",
      :aggregate_failures, :art_matching do
      a, b, c, d = artworks(%w[a b c d])
      stub_request(:get, a).to_return(body: noisy_png)
      stub_request(:get, b).to_return({ status: 429 }, { body: noisy_png })
      stub_request(:get, c).to_return({ status: 429 }, { body: noisy_png })
      stub_request(:get, d).to_return(status: 429)
      queued = -> { ActiveJob::Base.queue_adapter.enqueued_jobs }
      counted = -> { queued.call.last.dig("exception_executions", Catalog::RateLimitRetry::COUNTED_AS) }

      described_class.perform_now
      counts = [ counted.call ]
      3.times { ActiveJob::Base.execute(queued.call.last).then { counts << counted.call } }

      expect(counts).to eq([ 1, 1, 1, 2 ])
      expect(MTG::ArtBuild.recent.pluck(:status)).to all(eq("failed"))
    end

    it "leaves its count alone when the build is skipped at start (AC-2.4)", :aggregate_failures, :art_matching do
      artworks
      create(:mtg_art_build, status: "running", finished_at: nil, started_at: 1.minute.ago, heartbeat_at: 10.seconds.ago,
        job_id: "job-other")
      job = described_class.new
      job.exception_executions[Catalog::RateLimitRetry::COUNTED_AS] = 2

      expect { job.perform_now }.not_to have_enqueued_job(described_class)
      expect(job.exception_executions[Catalog::RateLimitRetry::COUNTED_AS]).to eq(2)
      expect(MTG::ArtBuild.recent.first).to have_attributes(status: "skipped", message: "already running")
    end

    # Decision 4, note 2: one job instance, two attempts. The second can't build its build, so it has made no progress,
    # whatever the first did.
    it "doesn't carry one attempt's progress into the next on the same job instance", :aggregate_failures, :art_matching do
      first_image, second_image = artworks
      stub_request(:get, first_image).to_return(body: noisy_png)
      stub_request(:get, second_image).to_return(status: 429)
      job = described_class.new

      job.perform_now
      expect(job.exception_executions[Catalog::RateLimitRetry::COUNTED_AS]).to eq(1) # fetched the first image: progress
      allow(MTG::Art::Build).to receive(:new).and_raise(rate_limited(60))
      job.perform_now
      expect(job.exception_executions[Catalog::RateLimitRetry::COUNTED_AS]).to eq(2) # not 1
    end
  end

  context "when Retry now has moved its waiting retry (spec 055 AC-2.4)", :solid_queue do
    it "carries on counting from the job's retry record", :aggregate_failures do
      allow(MTG::Art::Build).to receive(:new).and_raise(Catalog::Sources::RateLimitedError.new("rate limited", retry_after: 600))
      described_class.perform_now
      waiting = SolidQueue::Job.sole
      counted = Catalog::RateLimitRetry::COUNTED_AS
      expect(waiting.arguments["exception_executions"]).to eq(counted => 1)

      expect(Catalog::Operation::Queue.new(described_class).run_now(waiting.active_job_id)).to be(true)
      expect(waiting.reload).to be_ready
      expect(waiting.arguments["exception_executions"]).to eq(counted => 1)

      ActiveJob::Base.execute(waiting.arguments)
      retry_row = SolidQueue::Job.where(active_job_id: waiting.active_job_id).find(&:scheduled?)
      expect(retry_row.arguments["exception_executions"]).to eq(counted => 2)
    end
  end
end
