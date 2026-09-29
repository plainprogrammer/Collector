require "rails_helper"

RSpec.describe Catalog::Search, type: :model do
  def printing(name, identity: create(:catalog_identity, name:), **attributes)
    create(:catalog_entry, identity:, name:, **attributes)
  end

  it "is inactive for a blank or whitespace query without a set", :aggregate_failures do
    expect(described_class.new(query: "   ")).not_to be_active
    expect(described_class.new(query: "   ").groups).to eq([])
  end

  it "groups every searchable printing of each matching card, newest first", :aggregate_failures do
    bolt = create(:catalog_identity, name: "Lightning Bolt")
    en = printing("Lightning Bolt", identity: bolt, released_on: Date.new(2009, 7, 17))
    ja = printing("Lightning Bolt", identity: bolt, language: "ja", localized_name: "稲妻", released_on: Date.new(2022, 1, 1))

    groups = described_class.new(query: "稲妻").groups

    expect(groups.map(&:identity)).to eq([ bolt ])
    expect(groups.first.entries).to eq([ ja, en ])
  end

  it "caps a group at 10 printings and reports the total", :aggregate_failures do
    forest = create(:catalog_identity, name: "Forest")
    11.times { printing("Forest", identity: forest) }

    group = described_class.new(query: "forest").groups.first

    expect(group.entries.size).to eq(10)
    expect(group.total_entries).to eq(11)
  end

  it "sorts cards by name and pages 12 at a time", :aggregate_failures do
    13.times { |i| printing(format("Card %02d", i)) }

    expect(described_class.new(query: "card").groups.map { |group| group.identity.name }.first).to eq("Card 00")
    expect(described_class.new(query: "card", page: "2").groups.map { |group| group.identity.name }).to eq([ "Card 12" ])
  end

  it "clamps invalid pages to the first or last page", :aggregate_failures do
    13.times { |i| printing("Card #{i}") }

    expect(described_class.new(query: "card", page: "0").pagination.page).to eq(1)
    expect(described_class.new(query: "card", page: "abc").pagination.page).to eq(1)
    expect(described_class.new(query: "card", page: "99").pagination.page).to eq(2)
  end
end
