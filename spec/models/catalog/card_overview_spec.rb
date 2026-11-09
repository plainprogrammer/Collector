require "rails_helper"

RSpec.describe Catalog::CardOverview, type: :model do
  let(:account) { create(:user).account }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  def printing(released_on, **attributes)
    create(:mtg_printing, entry: create(:catalog_entry, identity:, released_on:, **attributes)).entry
  end

  it "counts copies and printings owned across the whole card", :aggregate_failures do
    a, b = printing(Date.new(2020, 1, 1)), printing(Date.new(2021, 1, 1))
    create(:lot, account:, entry: a, quantity: 3)
    create(:lot, account:, entry: b, quantity: 4, finish: "foil")
    create(:lot, entry: a, quantity: 9) # another account
    overview = described_class.new(account:, entry: a)
    expect([ overview.owned_count, overview.printings_owned, overview.lots.size ]).to eq([ 7, 2, 2 ])
  end

  it "lists the shown printing, then owned ones, then the 10 newest others", :aggregate_failures do
    old = printing(Date.new(1993, 1, 1))
    owned_retired = printing(Date.new(1994, 1, 1), retired_at: 1.day.ago)
    create(:lot, account:, entry: owned_retired)
    newest = (1..12).map { |i| printing(Date.new(2000 + i, 1, 1)) }

    rows = described_class.new(account:, entry: old).rows
    expect(rows.first).to have_attributes(entry: old, shown: true)
    expect(rows.second).to have_attributes(entry: owned_retired, owned: 1)
    expect(rows.drop(2).map(&:entry)).to eq(newest.reverse.first(10))
    expect(described_class.new(account:, entry: old).total_printings).to eq(13)
  end

  context "with printings of the card in one set (#204)" do
    let(:set) { create(:catalog_set, code: "znr") }
    let(:shown) { printing(set.released_on, set:, number: "1") }

    it "lists the owned and the newest printings by collector number, numerically", :aggregate_failures do
      owned = %w[100 12a 2].map { |number| printing(set.released_on, set:, number:) }
      %w[12 10 ★].each { |number| printing(set.released_on, set:, number:) }
      owned.each { |entry| create(:lot, account:, entry:) }

      overview = described_class.new(account:, entry: shown)
      expect(overview.rows.drop(1).map { |row| row.entry.number }).to eq(%w[2 12a 100 10 12 ★])
      expect(overview.lots.map { |lot| lot.entry.number }).to eq(%w[2 12a 100])
    end
  end
end
