require "rails_helper"

RSpec.describe Scanner::OtherPrintings, type: :model do
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let!(:earlier_core_set) { printing("m10", "146", Date.new(2009, 7, 17)) }
  let!(:later_core_set) { printing("m11", "149", Date.new(2010, 7, 16)) }
  let!(:later_core_set_same_number) { printing("m11", "146", Date.new(2010, 7, 16)) }
  let!(:masters_bolt) { printing("a25", "141", Date.new(2018, 3, 16)) }

  before do
    printing("m25", "1", Date.new(2025, 1, 1), retired: true)
    printing("m10", "146", Date.new(2009, 7, 17), language: "ja")
  end

  def printing(set_code, number, released_on, language: "en", retired: false)
    set = Catalog::Set.find_by(collectible_type: "mtg", code: set_code) || create(:catalog_set, code: set_code, released_on:)
    create(:catalog_entry, identity:, set:, number:, language:, released_on:, retired_at: (1.day.ago if retired))
  end

  def entries(set: nil, number: nil) = described_class.new(identity:, set_code: set, number:).entries

  it "puts the read set and number first, then the set, then the number, then the rest (AC-2.3)" do
    expect(entries(set: "M11", number: "0146")).to eq([ later_core_set_same_number, later_core_set, earlier_core_set, masters_bolt ])
  end

  it "lists newest first when nothing was read, leaving out retired and other-language printings (AC-2.2, AC-2.4)" do
    expect(entries).to eq([ masters_bolt, later_core_set_same_number, later_core_set, earlier_core_set ])
  end

  it "shows 20 and keeps the rest (AC-2.5)", :aggregate_failures do
    22.times { printing("x#{it}", "1", Date.new(2000, 1, 1)) }
    other = described_class.new(identity:)
    expect([ other.shown.size, other.rest.size ]).to eq([ 20, 6 ])
  end
end
