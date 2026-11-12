require "rails_helper"

# Spec 073 decision 5 and AC-2.6: the count beside the card page's "In decks".
RSpec.describe DecksHelper, type: :helper do
  describe "#card_decks_count_line" do
    def line(owned:, decks:, proxy:) = helper.card_decks_count_line(instance_double(Deck::CardUses, owned:, deck_count: decks, proxy:))

    it "reads the copies, the decks and the proxies", :aggregate_failures do
      expect(line(owned: 4, decks: 2, proxy: 2)).to eq("4 copies in 2 decks · 2 proxy")
      expect(line(owned: 1, decks: 1, proxy: 0)).to eq("1 copy in 1 deck")
      expect(line(owned: 0, decks: 0, proxy: 2)).to eq("2 proxy")
      expect(line(owned: 1, decks: 1, proxy: 1)).to eq("1 copy in 1 deck · 1 proxy")
      expect(line(owned: 0, decks: 0, proxy: 0)).to eq("")
    end

    it "delimits thousands" do
      expect(line(owned: 12_345, decks: 1_000, proxy: 1_234)).to eq("12,345 copies in 1,000 decks · 1,234 proxy")
    end
  end
end
