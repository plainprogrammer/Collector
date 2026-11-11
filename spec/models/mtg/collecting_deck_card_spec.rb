require "rails_helper"

# Spec 066 decisions 6, 8 and 11, AC-3.1 to AC-3.4, AC-6.3 to AC-6.6: Magic's answer to the deck page's seam.
RSpec.describe MTG::Collecting, type: :model do
  def entry_with(type_line: "Instant", cost: "{R}", legalities: {}, faces: nil)
    entry = create(:catalog_entry)
    faces ||= [ { "name" => entry.name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ]
    create(:mtg_printing, entry:, legalities:, faces:)
    Catalog::Entry.preload_extensions([ entry ]).first
  end

  describe ".deck_card" do
    it "groups by the first face's type line and says the cost is drawn", :aggregate_failures do
      answer = described_class.deck_card(entry_with(type_line: "Artifact Creature — Golem"), "modern")

      expect(answer.group).to eq("Creatures")
      expect(answer.position).to eq(0)
      expect(answer.costed).to be(true)
    end

    it "places a multi-face card by its first face (a Sorcery // Land is a Sorcery)" do
      faces = [ { "name" => "A", "type_line" => "Sorcery", "mana_cost" => "{1}{U}" }, { "name" => "B", "type_line" => "Land", "mana_cost" => "" } ]

      expect(described_class.deck_card(entry_with(faces:), "modern").group).to eq("Sorceries")
    end

    it "puts a printing with no face data in Other with no marker", :aggregate_failures do
      answer = described_class.deck_card(entry_with(faces: [], legalities: { "modern" => "banned" }), "modern")

      expect([ answer.group, answer.legality ]).to eq([ "Other", nil ])
    end

    it "puts an entry with no extension record in Other, not costed, with no marker", :aggregate_failures do
      bare = create(:catalog_entry)
      Catalog::Entry.preload_extensions([ bare ])

      answer = described_class.deck_card(bare, "modern")

      expect([ answer.group, answer.costed, answer.legality ]).to eq([ "Other", false, nil ])
    end

    {
      "banned" => "Banned", "restricted" => "Restricted", "not_legal" => "Not legal"
    }.each do |status, word|
      it "reads #{status.inspect} in the deck's own format as #{word.inspect}" do
        expect(described_class.deck_card(entry_with(legalities: { "vintage" => status }), "vintage").legality).to eq(word)
      end
    end

    it "shows no marker for a legal card", :aggregate_failures do
      expect(described_class.deck_card(entry_with(legalities: { "modern" => "legal" }), "modern").legality).to be_nil
    end

    it "reads a card with no entry for the format as Not legal (AC-3.2)" do
      expect(described_class.deck_card(entry_with(legalities: {}), "modern").legality).to eq("Not legal")
    end

    it "reads the legality of each format it registers under the format's own key (AC-6.5)", :aggregate_failures do
      legalities = described_class::LEGALITY_FORMATS.index_with { "banned" }
      entry = entry_with(legalities:)

      described_class::LEGALITY_FORMATS.each do |key|
        expect(described_class.deck_card(entry, key).legality).to eq("Banned"), "#{key} read no legality"
      end
      expect(described_class::LEGALITY_FORMATS).to eq(%w[standard pioneer modern legacy vintage pauper commander])
    end

    it "shows no marker in a format with no rules, whatever the card's legalities (AC-3.3)" do
      expect(described_class.deck_card(entry_with(legalities: { "modern" => "banned" }), "casual").legality).to be_nil
    end

    it "shows no marker for a format the instance no longer registers (AC-3.4)" do
      expect(described_class.deck_card(entry_with(legalities: { "modern" => "banned" }), "retired").legality).to be_nil
    end

    it "registers every deck format Casual aside as one with stored legality (AC-6.5)" do
      keys = described_class.formats.map(&:key) - [ "casual" ]

      expect(keys).to match_array(described_class::LEGALITY_FORMATS)
    end
  end
end
