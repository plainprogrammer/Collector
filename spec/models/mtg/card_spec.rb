require "rails_helper"

RSpec.describe MTG::Card, type: :model do
  describe "#mana_value (spec 058)" do
    it "is a nullable float with no default, and a card made without one has none", :aggregate_failures do
      column = described_class.columns_hash.fetch("mana_value")

      expect(column).to have_attributes(type: :float, null: true, default: nil)
      expect(create(:mtg_card).reload.mana_value).to be_nil
    end

    it "keeps zero, a half and a very large value exactly, zero staying zero and not nil" do
      [ 0.0, 0.5, 1_000_000.0 ].each { |value| create(:mtg_card, mana_value: value) }

      expect(described_class.order(:mana_value).pluck(:mana_value)).to eq([ 0.0, 0.5, 1_000_000.0 ])
    end
  end
end
