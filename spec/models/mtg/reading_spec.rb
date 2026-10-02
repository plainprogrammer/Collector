require "rails_helper"

RSpec.describe MTG::Reading, type: :model do
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine", released_on: Date.new(2023, 4, 21)) }
  let!(:bolt) { printing("Lightning Bolt", set: mom, number: "123") }

  before do
    printing("Lightning Helix", set: mom, number: "200")
    Catalog::NameIndex.new("mtg").rebuild
  end

  def printing(name, set:, number:, language: "en")
    identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name:, set:, number:, language:)).entry
  end

  def read(name_text: "", collector_text: "") = described_class.new(name_text:, collector_text:).resolve

  it "puts the printing the collector line identifies first, once (AC-3.2)", :aggregate_failures do
    reading = read(name_text: "Lightning Bolt", collector_text: "R 0123\nMOM • EN")
    expect(reading.collector_status).to eq(:one)
    expect(reading.candidates.first).to have_attributes(entry: bolt, source: :collector_line)
    expect(reading.candidates.count { it.entry.catalog_identity_id == bolt.catalog_identity_id }).to eq(1)
  end

  it "uses English when the collector line names no language" do
    expect(read(collector_text: "M0123\nMOM").collector_status).to eq(:one)
  end

  it "reports several printings and falls back to the name (AC-3.3)", :aggregate_failures do
    printing("Lightning Bolt", set: mom, number: "123")
    reading = read(name_text: "Lightning Bolt", collector_text: "R 0123\nMOM • EN")
    expect(reading.collector_status).to eq(:several)
    expect(reading.candidates.map(&:source)).to all(eq(:name))
  end

  it "reports no printing, or a line it couldn't read", :aggregate_failures do
    expect(read(collector_text: "R 0999\nMOM • EN").collector_status).to eq(:none)
    expect(read(collector_text: "").collector_status).to eq(:unread)
  end

  it "shows a name candidate's printing in the parsed set, else its newest English printing", :aggregate_failures do
    newer = printing("Lightning Bolt", set: create(:catalog_set, code: "m25", released_on: Date.new(2025, 1, 1)), number: "1")
    expect(read(name_text: "Lightning Bolt", collector_text: "R 0999\nMOM • EN").candidates.first.entry).to eq(bolt)
    expect(read(name_text: "Lightning Bolt").candidates.first.entry).to eq(newer)
  end

  it "keeps the name candidates independent of the collector line (AC-6.2)", :aggregate_failures do
    reading = read(name_text: "Lightning Helix", collector_text: "R 0123\nMOM • EN")
    expect(Catalog::Identity.find(reading.name_candidates.first.identity_id).name).to eq("Lightning Helix")
    expect(reading.candidates.first.entry).to eq(bolt)
  end

  it "lists at most three candidates" do
    %w[Lightning\ Axe Lightning\ Storm Lightning\ Strike].each_with_index { |name, i| printing(name, set: mom, number: (300 + i).to_s) }
    Catalog::NameIndex.new("mtg").rebuild
    expect(read(name_text: "Lightning").candidates.size).to eq(3)
  end

  it "knows when nothing was read, when the catalog isn't ready, and when text is too long", :aggregate_failures do
    expect(read).to be_nothing_read
    Catalog::Name.delete_all
    expect(read(name_text: "Lightning Bolt")).not_to be_catalog_ready
    expect(described_class.new(name_text: "a" * 2_001)).not_to be_valid
  end
end
