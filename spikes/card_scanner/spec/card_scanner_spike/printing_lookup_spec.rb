require "rails_helper"
require_relative "../spike_helper"
require "card_scanner_spike/printing_lookup"

RSpec.describe CardScannerSpike::PrintingLookup, type: :model do
  subject(:lookup) { described_class.new }

  let(:neo) { create(:catalog_set, code: "neo") }

  it "resolves a set, number and language to one printing", :aggregate_failures do
    entry = create(:catalog_entry, set: neo, number: "51")
    outcome = lookup.call(set_code: "NEO", number: "51", language: "en")
    expect(outcome.status).to eq(:one)
    expect(outcome.entries).to eq([ entry ])
  end

  it "defaults a missing language to English" do
    create(:catalog_entry, set: neo, number: "51")
    expect(lookup.call(set_code: "NEO", number: "51", language: nil).status).to eq(:one)
  end

  it "reports none for an unknown number" do
    create(:catalog_entry, set: neo, number: "51")
    expect(lookup.call(set_code: "NEO", number: "52").status).to eq(:none)
  end

  it "reports none when the set or number was not parsed" do
    expect(lookup.call(set_code: nil, number: "51").status).to eq(:none)
  end

  it "ignores retired printings" do
    create(:catalog_entry, :retired, set: neo, number: "51")
    expect(lookup.call(set_code: "NEO", number: "51").status).to eq(:none)
  end

  it "reports ambiguous when more than one printing matches" do
    create_list(:catalog_entry, 2, set: neo, number: "51")
    expect(lookup.call(set_code: "NEO", number: "51").status).to eq(:ambiguous)
  end

  describe ".known_set_codes" do
    it "lists the catalog's set codes" do
      neo
      expect(described_class.known_set_codes).to include("neo")
    end
  end
end
