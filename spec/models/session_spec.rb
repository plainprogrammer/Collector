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
end
