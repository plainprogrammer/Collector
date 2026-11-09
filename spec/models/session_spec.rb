require "rails_helper"

RSpec.describe Session, type: :model do
  let(:user) { create(:user) }
  let(:now) { Time.utc(2026, 11, 9, 12, 0, 0) }

  def session_stamped(ago) = user.sessions.create!(last_used_at: now - ago)

  describe "#expired? and .expired (spec 049 decisions 1 and 2)" do
    it "is expired at 30 days or more and not before, by the stamp", :aggregate_failures do
      fresh = session_stamped(30.days - 1.second)
      edge = session_stamped(30.days)
      old = session_stamped(31.days)

      expect([ fresh, edge, old ].map { it.expired?(now) }).to eq([ false, true, true ])
      expect(described_class.expired(now)).to contain_exactly(edge, old)
    end
  end

  describe "#stale?" do
    it "is stale at 24 hours or more, and when the stamp is in the future (the clock was set back)", :aggregate_failures do
      expect(session_stamped(23.hours).stale?(now)).to be(false)
      expect(session_stamped(24.hours).stale?(now)).to be(true)
      expect(session_stamped(-1.hour).stale?(now)).to be(true)
    end
  end

  it "stamps a new session with its creation time (AC-2.1)" do
    travel_to(now) { expect(user.sessions.create!.last_used_at).to eq(now) }
  end

  it "keeps no address and no user agent (AC-4.1)" do
    expect(described_class.column_names).not_to include("ip_address", "user_agent")
  end

  describe ".sweep! (spec 049 Story 3)" do
    def fill(session)
      selection = BulkSelection.for(session)
      selection.marks.create!(account: user.account, lot: create(:lot, account: user.account))
      BulkRemoval.create!(session:, account: user.account, copies: 1)
    end

    it "deletes expired sessions with their selection, marks and Undo, and nothing else (AC-3.1, AC-3.4, AC-1.8)", :aggregate_failures do
      other = create(:user)
      gone = session_stamped(31.days).tap { fill(it) }
      kept = session_stamped(1.day).tap { fill(it) }
      theirs = other.sessions.create!(last_used_at: now)
      before = [ User.count, Account.count, Lot.count ]

      expect(described_class.sweep!(now:)).to eq(1)

      expect(described_class.all).to contain_exactly(kept, theirs)
      expect(BulkSelection.pluck(:session_id)).to eq([ kept.id ])
      expect(BulkRemoval.pluck(:session_id)).to eq([ kept.id ])
      expect(BulkSelection::Mark.count).to eq(1)
      expect([ User.count, Account.count, Lot.count ]).to eq(before)
      expect(described_class.exists?(gone.id)).to be(false)
    end

    it "changes nothing when none is expired, and the second run deletes nothing (AC-3.2)", :aggregate_failures do
      session_stamped(31.days)
      expect(described_class.sweep!(now:)).to eq(1)
      expect(described_class.sweep!(now:)).to eq(0)
      user.sessions.create!(last_used_at: now)
      expect(described_class.sweep!(now:)).to eq(0)
    end

    it "deletes every expired session across batches, one delete statement each (AC-3.3)", :aggregate_failures do
      5.times { session_stamped(40.days) }
      statements = write_statements_to("sessions") { expect(described_class.sweep!(now:, batch: 2)).to eq(5) }
      expect(statements.size).to eq(3)
      expect(described_class.count).to eq(0)
    end
  end
end
