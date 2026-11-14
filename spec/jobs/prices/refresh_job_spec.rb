require "rails_helper"

RSpec.describe Prices::RefreshJob, type: :job do
  it "allows one refresh per source key at a time, on the sync queue (AC-4.3)", :aggregate_failures do
    expect(described_class.queue_name).to eq("sync")
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.concurrency_on_conflict).to eq(:block)
    expect(described_class.concurrency_duration).to eq(6.hours)
    expect(described_class.new("fake_source").concurrency_key).to eq("Prices::RefreshJob/fake_source")
  end

  it "runs the refresh for the source key, under its own job id" do
    refresh = instance_double(Prices::Refresh, call: nil)
    allow(Prices::Refresh).to receive(:new).and_return(refresh)
    job = described_class.new("fake_source")

    job.perform_now

    expect(Prices::Refresh).to have_received(:new).with("fake_source", job_id: job.job_id)
  end

  # decision 7's table (AC-4.6): the job's fate for each error; no error is discarded
  {
    "Catalog::Sources::TransientError" => [ Catalog::Sources::TransientError, "timeout", :retried ],
    "ActiveRecord::StatementTimeout" => [ ActiveRecord::StatementTimeout, "busy", :retried ],
    "Catalog::Sources::IntegrityError" => [ Catalog::Sources::IntegrityError, "downloaded 1 bytes", :retried ],
    "Catalog::Sources::RateLimitedError" => [ Catalog::Sources::RateLimitedError, "slow down", :retried ],
    "Prices::Sources::IntegrityError" => [ Prices::Sources::IntegrityError, "no date", :failed ],
    "Catalog::Sources::ConfigurationError" => [ Catalog::Sources::ConfigurationError, "bad language", :failed ],
    "Zlib::Error" => [ Zlib::Error, "cut short", :failed ],
    "Prices::Refresh::GuardError" => [ Prices::Refresh::GuardError, "over the ceiling", :failed ],
    "RuntimeError" => [ RuntimeError, "anything else", :failed ]
  }.each do |name, (error, message, fate)|
    it "#{fate == :retried ? "retries" : "fails, without a retry or a discard,"} on #{name} (AC-4.6)", :aggregate_failures do
      allow(Prices::Refresh).to receive(:new).and_raise(error, message)

      if fate == :retried
        expect { described_class.perform_now("fake_source") }.to have_enqueued_job(described_class).with("fake_source")
      else
        expect { described_class.perform_now("fake_source") }.to raise_error(error, message)
      end
    end
  end

  it "fails on the third attempt of a transient error, not retried again (AC-4.6)" do
    allow(Prices::Refresh).to receive(:new).and_raise(Catalog::Sources::TransientError, "timeout")
    job = described_class.new("fake_source")
    2.times { job.perform_now } # two retries are queued (retry_on counts per exception class, in the job's exception_executions)

    expect { job.perform_now }.to raise_error(Catalog::Sources::TransientError, "timeout")
  end
end
