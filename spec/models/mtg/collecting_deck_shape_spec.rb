require "rails_helper"

# Spec 069 decision 1: Magic's answer to the deck page's panel seam.
RSpec.describe MTG::Collecting, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def zones_of(in_deck) = Deck::Page.new(Deck.includes(:location).find_by!(location_id: in_deck.location_id)).zones

  describe ".deck_shape" do
    it "answers the parts' partial with the figures, the scope line and the fold's facts", :aggregate_failures do
      entry = create(:catalog_entry)
      create(:mtg_printing, entry:)
      create(:mtg_card, identity: entry.identity, mana_value: 1.0)
      create_lot_in_zone(deck, "main", entry:, quantity: 2)

      answer = described_class.deck_shape(zones_of(deck))

      expect(answer.partial).to eq("mtg/deck_shapes/parts")
      expect(answer.figures).to be_a(MTG::DeckShape)
      expect([ answer.scope, answer.facts ]).to eq([ "Main · 2 cards", "Main · 2 cards · average mana value 1.0" ])
    end

    it "answers nil when no zone is Commander or Main" do
      deck.zone("main").destroy!

      expect(described_class.deck_shape(zones_of(deck))).to be_nil
    end

    it "is what the core seam returns for a Magic deck" do
      expect(Catalog::DeckShape.answer("mtg", zones_of(deck))).to be_a(Catalog::DeckShape::Answer)
    end
  end
end
