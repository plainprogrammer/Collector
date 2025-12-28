# frozen_string_literal: true

require "rails_helper"

RSpec.describe Collection, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:catalog) }
  end

  describe "validations" do
    it "requires name to be present" do
      catalog = create(:catalog)
      collection = described_class.new(catalog: catalog, item_type: "mtg_card")
      expect(collection).not_to be_valid
      expect(collection.errors[:name]).to include("can't be blank")
    end

    it "requires item_type to be present" do
      catalog = create(:catalog)
      collection = described_class.new(catalog: catalog, name: "My Collection")
      expect(collection).not_to be_valid
      expect(collection.errors[:item_type]).to include("can't be blank")
    end

    it "requires catalog to be present" do
      collection = described_class.new(name: "My Collection", item_type: "mtg_card")
      expect(collection).not_to be_valid
      expect(collection.errors[:catalog]).to include("must exist")
    end
  end

  describe "UUID primary key" do
    it "generates a UUID for id before validation" do
      catalog = create(:catalog)
      collection = described_class.new(
        name: "Test Collection",
        item_type: "mtg_card",
        catalog: catalog
      )
      collection.valid?
      expect(collection.id).to be_present
      expect(collection.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "does not override an existing id" do
      existing_id = SecureRandom.uuid
      catalog = create(:catalog)
      collection = described_class.new(
        id: existing_id,
        name: "Test Collection",
        item_type: "mtg_card",
        catalog: catalog
      )
      collection.valid?
      expect(collection.id).to eq(existing_id)
    end
  end

  describe "1:1 relationship with catalog" do
    it "enforces uniqueness of catalog_id" do
      catalog = create(:catalog)
      create(:collection, catalog: catalog)

      duplicate_collection = build(:collection, catalog: catalog)
      expect(duplicate_collection).not_to be_valid
      expect(duplicate_collection.errors[:catalog_id]).to include("has already been taken")
    end
  end
end
