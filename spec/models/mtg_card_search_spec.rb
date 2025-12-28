# frozen_string_literal: true

require "rails_helper"

RSpec.describe MTGCard, type: :model do
  describe ".search" do
    let!(:set) { create(:mtg_set, code: "TST") }
    let!(:lightning_bolt) { create(:mtg_card, name: "Lightning Bolt", mtg_set: set) }
    let!(:bolt_bend) { create(:mtg_card, name: "Bolt Bend", mtg_set: set) }
    let!(:shock) { create(:mtg_card, name: "Shock", mtg_set: set) }

    it "returns cards matching the search query" do
      results = MTGCard.search("bolt")

      expect(results).to include(lightning_bolt, bolt_bend)
      expect(results).not_to include(shock)
    end

    it "is case-insensitive" do
      results = MTGCard.search("BOLT")

      expect(results).to include(lightning_bolt, bolt_bend)
    end

    it "supports partial matches" do
      results = MTGCard.search("light")

      expect(results).to include(lightning_bolt)
      expect(results).not_to include(bolt_bend, shock)
    end

    it "returns empty relation for empty query" do
      results = MTGCard.search("")

      expect(results).to be_empty
    end

    it "returns empty relation for nil query" do
      results = MTGCard.search(nil)

      expect(results).to be_empty
    end

    it "returns all matching cards ordered by relevance" do
      # Exact match should rank higher
      exact = create(:mtg_card, name: "Bolt", mtg_set: set)

      results = MTGCard.search("bolt").to_a

      # Exact match should come first
      expect(results.first.name).to eq("Bolt")
    end
  end

  describe ".search_by_name" do
    let!(:set) { create(:mtg_set, code: "TST") }
    let!(:card1) { create(:mtg_card, name: "Ancient Dragon", mtg_set: set) }
    let!(:card2) { create(:mtg_card, name: "Dragon Hatchling", mtg_set: set) }

    it "finds cards containing the search term" do
      results = MTGCard.search_by_name("dragon")

      expect(results).to include(card1, card2)
    end

    it "returns exact matches first" do
      exact = create(:mtg_card, name: "Dragon", mtg_set: set)

      results = MTGCard.search_by_name("dragon").to_a

      expect(results.first.name).to eq("Dragon")
    end
  end
end
