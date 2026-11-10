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

    it "keeps the front face's artwork id and each face's small image (spec 011 AC-2.1)", :aggregate_failures do
      card = scryfall_card("illustration_id" => "art-1",
        "image_uris" => { "small" => "https://cards.scryfall.io/small/front/a/b/x.jpg", "normal" => "n", "large" => "l" })
      record = described_class.entry_record(card)

      expect(record.extension[:illustration_id]).to eq("art-1")
      expect(record.extension[:faces].first["image_uris"]).to eq("small" => "https://cards.scryfall.io/small/front/a/b/x.jpg", "normal" => "n", "large" => "l")
    end

    it "takes a multi-face printing's artwork id from its front face, and stores none when there is none", :aggregate_failures do
      faces = [ { "name" => "Front", "illustration_id" => "front-art" }, { "name" => "Back", "illustration_id" => "back-art" } ]
      expect(described_class.entry_record(scryfall_card("card_faces" => faces, "illustration_id" => nil)).extension[:illustration_id]).to eq("front-art")
      expect(described_class.entry_record(scryfall_card).extension[:illustration_id]).to be_nil
    end
  end

  describe "mana value (spec 058)" do
    def scryfall_fixture(name) = JSON.parse(file_fixture("scryfall/#{name}.json").read)
    def identity_extension(card) = described_class.entry_record(card).identity.extension

    it "reads a whole mana value, a half and a very large one from recorded cards", :aggregate_failures do
      expect(identity_extension(scryfall_fixture("lightning_bolt_m10"))[:mana_value]).to eq(1.0)
      expect(identity_extension(scryfall_fixture("little_girl_unh"))[:mana_value]).to eq(0.5)
      expect(identity_extension(scryfall_fixture("gleemax_unh"))[:mana_value]).to eq(1_000_000.0)
    end

    it "keeps a token's zero as zero, not nil", :aggregate_failures do
      record = described_class.entry_record(scryfall_fixture("avatar_token_tm10"))

      expect(record.kind).to eq("token")
      expect(record.identity.extension[:mana_value]).to eq(0.0)
    end

    it "reads a reversible card's front face when the card has no cmc of its own, and does not drop it", :aggregate_failures do
      card = scryfall_fixture("ajani_reversible_sld")

      expect(card).not_to have_key("cmc")
      expect(card["card_faces"].map { |face| face["cmc"] }).to eq([ 4.0, 4.0 ])
      expect { described_class.entry_record(card) }.not_to raise_error
      expect(identity_extension(card)[:mana_value]).to eq(4.0)
    end

    it "gives nil, still mapped and with the key present, when no usable cmc exists", :aggregate_failures do
      no_cmc = scryfall_card.except("cmc")
      no_faces_at_all = scryfall_fixture("lightning_bolt_m10").except("cmc", "card_faces")
      reversible = scryfall_fixture("ajani_reversible_sld")
      front_without = reversible.merge("card_faces" => [ reversible["card_faces"][0].except("cmc"), reversible["card_faces"][1] ])

      [ no_cmc, no_faces_at_all, front_without,
        scryfall_card("cmc" => "x"), scryfall_card("cmc" => "3"), scryfall_card("cmc" => true), scryfall_card("cmc" => nil) ].each do |card|
        extension = identity_extension(card)

        expect(extension).to have_key(:mana_value)
        expect(extension[:mana_value]).to be_nil
      end
    end

    it "makes an integer 3 and a float 3.0 one value with one digest", :aggregate_failures do
      integer = described_class.entry_record(scryfall_card("cmc" => 3)).identity
      float = described_class.entry_record(scryfall_card("cmc" => 3.0)).identity

      expect(integer.extension[:mana_value]).to be(3.0)
      expect(integer.digest).to eq(float.digest)
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
