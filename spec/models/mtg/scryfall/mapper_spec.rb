require "rails_helper"

RSpec.describe MTG::Scryfall::Mapper, type: :model do
  describe ".entry_record" do
    it "maps core entry attributes", :aggregate_failures do
      card = scryfall_card("id" => "bolt-m10")
      record = described_class.entry_record(card)

      expect(record).to have_attributes(external_key: "bolt-m10", set_code: "m10", set_name: "Magic 2010",
        number: "146", language: "en", name: "Lightning Bolt", localized_name: nil, kind: "card",
        released_on: Date.new(2009, 7, 17), image_url: card.dig("image_uris", "normal"))
      expect(record.identity).to have_attributes(external_key: "oracle-bolt", name: "Lightning Bolt")
    end

    it "keeps MTG attributes in the extensions and drops prices", :aggregate_failures do
      record = described_class.entry_record(scryfall_card)

      expect(record.extension).to include(rarity: "common", finishes: %w[foil nonfoil], layout: "normal",
        legalities: { "modern" => "legal" }, external_ids: { "tcgplayer_id" => 33_517 })
      expect(record.extension[:faces].first).to include("name" => "Lightning Bolt", "artist" => "Christopher Moeller")
      expect(record.identity.extension).to include(mana_cost: "{R}", colors: [ "R" ], type_line: "Instant")
      expect(record.to_h.to_s).not_to include("1.00")
    end

    it "joins face localized names and takes images from faces for multi-face printings", :aggregate_failures do
      card = JSON.parse(file_fixture("scryfall/azusa_ja_transform.json").read)
      record = described_class.entry_record(card)

      expect(record.localized_name).to eq("梓の幾多の旅 // 探求者の肖像")
      expect(record.image_url).to include("/front/")
      expect(record.identity.external_key).to eq("oracle-azusa")
      expect(record.extension[:faces].map { |face| face["artist"] }).to eq([ "Lindsey Look", "Lindsey Look" ])
    end

    it "classifies tokens, emblems, art cards and other non-card kinds", :aggregate_failures do
      kinds = %w[token double_faced_token emblem art_series planar normal].map do |layout|
        described_class.entry_record(scryfall_card("layout" => layout)).kind
      end

      expect(kinds).to eq(%w[token token emblem art_card other card])
    end

    it "produces the same digest for the same data and a different one when stored data changes", :aggregate_failures do
      card = scryfall_card("id" => "x")

      expect(described_class.entry_record(card).digest).to eq(described_class.entry_record(card.merge("prices" => {})).digest)
      expect(described_class.entry_record(card.merge("rarity" => "rare")).digest).not_to eq(described_class.entry_record(card).digest)
    end

    it "raises KeyError when a required field is missing" do
      expect { described_class.entry_record(scryfall_card.except("set")) }.to raise_error(KeyError)
    end
  end

  describe ".paper?" do
    it "is false for digital-only printings", :aggregate_failures do
      expect(described_class.paper?(scryfall_card)).to be(true)
      expect(described_class.paper?(scryfall_card("digital" => true, "games" => [ "arena" ]))).to be(false)
    end
  end

  describe ".set_record" do
    it "allows a missing release date" do
      expect(described_class.set_record(scryfall_set("released_at" => nil)).released_on).to be_nil
    end
  end
end
