require "rails_helper"

# Spec 066 decision 5, AC-6.1: the deck page's optional answer of a collectible's vocabulary, and the core's flat default.
RSpec.describe Catalog::DeckCards, type: :model do
  let(:entry) { build_stubbed(:catalog_entry) }

  describe ".answer" do
    it "gives the vocabulary's answer for an entry of the deck's own type", :aggregate_failures do
      stub_const("AnsweringCollecting", Module.new do
        def self.deck_card(entry, format_key) = Catalog::DeckCards::Answer.new(group: "Group", position: 3, legality: "Banned: #{format_key}", costed: true)
      end)
      Catalog.collecting["answering"] = "AnsweringCollecting"
      answering = build_stubbed(:catalog_entry, collectible_type: "answering")

      expect(described_class.answer("answering", answering, "k")).to eq(described_class::Answer.new(group: "Group", position: 3, legality: "Banned: k", costed: true))
    ensure
      Catalog.collecting.delete("answering")
    end

    it "gives NONE for an entry of another type than the deck's" do
      expect(described_class.answer("other", entry, "k")).to eq(described_class::NONE) # the entry is of the "mtg" type
    end

    it "gives NONE for a type no longer registered" do
      stranger = build_stubbed(:catalog_entry, collectible_type: "gone")

      expect(described_class.answer("gone", stranger, "x")).to eq(described_class::NONE)
    end

    it "gives NONE when the vocabulary does not answer", :other_collecting do
      other = build_stubbed(:catalog_entry, collectible_type: "other")

      expect(described_class.answer("other", other, "standard")).to eq(described_class::NONE)
    end

    it "gives NONE when the vocabulary answers nil" do
      stub_const("NilCollecting", Module.new { def self.deck_card(*) = nil })
      Catalog.collecting["nilish"] = "NilCollecting"
      nilish = build_stubbed(:catalog_entry, collectible_type: "nilish")

      expect(described_class.answer("nilish", nilish, "k")).to eq(described_class::NONE)
    ensure
      Catalog.collecting.delete("nilish")
    end

    it "has no group, position or legality in NONE and no cost display", :aggregate_failures do
      none = described_class::NONE

      expect([ none.group, none.position, none.legality, none.costed ]).to eq([ nil, nil, nil, false ])
    end
  end
end
