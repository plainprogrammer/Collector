require "rails_helper"

# Spec 043: the rule's own examples, with probe jobs that are rate limited every time they run. The jobs' own answers are
# in spec/jobs/catalog/refresh_job_spec.rb and spec/jobs/mtg/art/build_job_spec.rb.
RSpec.describe Catalog::RateLimitRetry, type: :job do
  let(:counted_as) { Catalog::RateLimitRetry::COUNTED_AS }

  # First argument: the wait the source asks for. Second: whether the attempt made progress, which the job answers.
  let(:probe_class) do
    stub_const("RateLimitedProbeJob", Class.new(ApplicationJob) do
      include Catalog::RateLimitRetry

      def perform(asked, progressed)
        @progressed = progressed
        raise Catalog::Sources::RateLimitedError.new("rate limited", retry_after: asked)
      end

      private
        def rate_limit_progress? = @progressed
    end)
  end

  # Includes the rule and says nothing about progress.
  let(:silent_class) do
    stub_const("SilentProbeJob", Class.new(ApplicationJob) do
      include Catalog::RateLimitRetry

      def perform = raise(Catalog::Sources::RateLimitedError.new("rate limited", retry_after: 60))
    end)
  end

  before { freeze_time }

  def probe(count, progressed, asked: 60)
    probe_class.new(asked, progressed).tap { |job| job.exception_executions[counted_as] = count unless count.nil? }
  end

  def count_of(job) = job.exception_executions[counted_as]

  context "when the attempt made progress" do
    it "retries after the wait and starts the count again at 1, from 3 (AC-1.1)", :aggregate_failures do
      job = probe(3, true)

      expect { job.perform_now }.to have_enqueued_job(probe_class).at(60.seconds.from_now)
      expect(count_of(job)).to eq(1)
    end

    it "retries every time, however many times it is rate limited (AC-1.5)", :aggregate_failures do
      job = probe(nil, true)

      expect { 8.times { job.perform_now } }.to have_enqueued_job(probe_class).exactly(8).times
      expect(count_of(job)).to eq(1)
    end

    [ nil, 5, 44 ].each do |asked|
      it "still waits 45 seconds at least, when the source asked for #{asked.inspect} (FR-8)" do
        job = probe(0, true, asked:)

        expect { job.perform_now }.to have_enqueued_job(probe_class).at(45.seconds.from_now)
      end
    end
  end

  context "when the attempt made no progress" do
    [ 0, 1, 2 ].each do |count|
      it "retries after the wait with the count one more, from #{count} (AC-1.3)", :aggregate_failures do
        job = probe(count, false)

        expect { job.perform_now }.to have_enqueued_job(probe_class).at(60.seconds.from_now)
        expect(count_of(job)).to eq(count + 1)
      end
    end

    it "fails with the rate-limit error from 3, as before (AC-1.2)", :aggregate_failures do
      expect { expect { probe(3, false).perform_now }.to raise_error(Catalog::Sources::RateLimitedError) }
        .not_to have_enqueued_job(probe_class)
    end
  end

  [ true, false ].each do |progressed|
    it "fails at once when asked to wait more than an hour, with progress #{progressed} (AC-1.4)", :aggregate_failures do
      job = probe(0, progressed, asked: 3601)

      expect { expect { job.perform_now }.to raise_error(Catalog::Sources::RateLimitedError) }
        .not_to have_enqueued_job(probe_class)
    end
  end

  it "treats a job that says nothing about progress as having made none: it fails the fourth time (AC-1.6, FR-3)", :aggregate_failures do
    job = silent_class.new

    expect { 3.times { job.perform_now } }.to have_enqueued_job(silent_class).exactly(3).times
    expect { expect { job.perform_now }.to raise_error(Catalog::Sources::RateLimitedError) }
      .not_to have_enqueued_job(silent_class)
  end
end
