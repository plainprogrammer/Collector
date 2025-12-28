# frozen_string_literal: true

require "rails_helper"

RSpec.describe Item, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:collection) }
    it { is_expected.to belong_to(:storage_unit).optional }
    it { is_expected.to belong_to(:catalog_entry) }
  end

  describe "validations" do
    it "requires collection to be present" do
      set = create(:mtg_set)
      card = create(:mtg_card, mtg_set: set)
      item = described_class.new(catalog_entry: card)
      expect(item).not_to be_valid
      expect(item.errors[:collection]).to include("must exist")
    end

    it "requires catalog_entry to be present" do
      collection = create(:collection)
      item = described_class.new(collection: collection)
      expect(item).not_to be_valid
      expect(item.errors[:catalog_entry]).to include("must exist")
    end

    it "requires quantity to be greater than 0" do
      collection = create(:collection)
      set = create(:mtg_set)
      card = create(:mtg_card, mtg_set: set)
      item = build(:item, collection: collection, catalog_entry: card, quantity: 0)
      expect(item).not_to be_valid
      expect(item.errors[:quantity]).to include("must be greater than 0")
    end
  end

  describe "UUID primary key" do
    it "generates a UUID for id before validation" do
      collection = create(:collection)
      set = create(:mtg_set)
      card = create(:mtg_card, mtg_set: set)
      item = build(:item, collection: collection, catalog_entry: card)
      item.valid?
      expect(item.id).to be_present
      expect(item.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe "quantity default" do
    it "defaults to 1" do
      item = build(:item)
      expect(item.quantity).to eq(1)
    end
  end

  describe "polymorphic catalog_entry" do
    it "can reference an MTGCard" do
      collection = create(:collection)
      set = create(:mtg_set)
      card = create(:mtg_card, name: "Lightning Bolt", mtg_set: set)
      item = create(:item, collection: collection, catalog_entry: card)

      expect(item.catalog_entry).to eq(card)
      expect(item.catalog_entry_type).to eq("MTGCard")
    end
  end

  describe "delegated type detail" do
    it "creates an MTGCardItemDetail when detail_type is MTGCardItemDetail" do
      collection = create(:collection)
      set = create(:mtg_set)
      card = create(:mtg_card, mtg_set: set)
      detail = create(:mtg_card_item_detail)
      item = build(:item, collection: collection, catalog_entry: card, detail: detail)

      expect(item.detail).to eq(detail)
      expect(item.detail_type).to eq("MTGCardItemDetail")
    end
  end
end
