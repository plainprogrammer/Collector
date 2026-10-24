require "rails_helper"

# Spec 032 P1, P2: what a location holds, for the locations page and the page that refuses a removal.
RSpec.describe Location::Holdings, type: :model do
  let(:account) { create(:user).account }
  let(:blue) { create(:location, account:) }
  let(:box) { create(:location, account:) }

  def queries_during
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  describe ".counts" do
    it "counts lots and copies per placed location and nothing for any other", :aggregate_failures do
      create(:lot, account:, location: blue, quantity: 4)
      create(:lot, account:, location: blue, quantity: 2, finish: "foil")
      create(:lot, account:, location: box, quantity: 1)
      create(:lot, account:, quantity: 9)
      counts = described_class.counts(account)
      expect(counts[blue.id]).to eq(described_class::Count.new(lots: 2, copies: 6))
      expect(counts[box.id]).to eq(described_class::Count.new(lots: 1, copies: 1))
      expect(counts[0]).to eq(described_class::Count.new(lots: 0, copies: 0))
    end

    it "counts only the account's own lots" do
      other = create(:user).account
      create(:lot, account: other, location: create(:location, account: other), quantity: 3)
      expect(described_class.counts(account)).to be_empty
    end

    it "runs two statements whatever the number of locations or lots" do
      2.times { create(:lot, account:, location: create(:location, account:)) }
      few = queries_during { described_class.counts(account) }
      20.times { create(:lot, account:, location: create(:location, account:)) }
      expect([ few, queries_during { described_class.counts(account) } ]).to eq([ 2, 2 ])
    end
  end

  describe "#total, #any?, #listed, #more" do
    it "reports an empty location", :aggregate_failures do
      holdings = blue.holdings
      expect([ holdings.any?, holdings.total, holdings.listed, holdings.more ]).to eq([ false, described_class::EMPTY, [], 0 ])
    end

    it "lists at most 100 lots, ordered by entry name, set code, number, language, finish, condition and price paid", :aggregate_failures do
      entry = create(:mtg_printing, finishes: %w[nonfoil foil]).entry
      prices = (1..105).to_a.shuffle
      prices.each { |cents| create(:lot, account:, entry:, location: blue, price_paid_cents: cents, quantity: 2) }
      holdings = blue.holdings
      expect(holdings.lots_count).to eq(105)
      expect(holdings.copies).to eq(210)
      expect(holdings.listed.map(&:price_paid_cents)).to eq((1..100).to_a)
      expect(holdings.more).to eq(5)
    end

    it "orders by name before anything else" do
      zebra = create(:lot, account:, location: blue, entry: create(:catalog_entry, name: "Zebra"))
      ant = create(:lot, account:, location: blue, entry: create(:catalog_entry, name: "Ant"))
      expect(blue.holdings.listed).to eq([ ant, zebra ])
    end
  end
end
