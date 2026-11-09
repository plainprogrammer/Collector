require "rails_helper"

RSpec.describe Session::SweepJob, type: :job do
  let(:user) { create(:user) }

  it "runs on the default queue and deletes the expired sessions of every account (AC-3.8)", :aggregate_failures do
    expect(described_class.new.queue_name).to eq("default")
    old = user.sessions.create!(last_used_at: 31.days.ago)
    recent = create(:user).sessions.create!

    described_class.perform_now

    expect(Session.all).to contain_exactly(recent)
    expect(Session.exists?(old.id)).to be(false)
  end

  it "declares one run at a time (AC-3.7)", :aggregate_failures do
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.concurrency_key).to eq("session_sweep")
  end

  it "queues a second sweep behind the first through Solid Queue (AC-3.7)", :aggregate_failures, :solid_queue do
    first = queue_job(described_class)
    second = queue_job(described_class)

    expect(first.ready_execution).to be_present
    expect(second.blocked_execution).to be_present
  end

  it "retries a busy database later and fails on an error that is not transient (AC-3.5)", :aggregate_failures do
    allow(Session).to receive(:sweep!).and_raise(SQLite3::BusyException)
    expect { described_class.perform_now }.to have_enqueued_job(described_class)

    allow(Session).to receive(:sweep!).and_raise(ArgumentError)
    expect { described_class.perform_now }.to raise_error(ArgumentError)
  end
end
