# frozen_string_literal: true

require "rails_helper"

RSpec.describe CollectionStorageUnit, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:collection) }
    it { is_expected.to belong_to(:storage_unit) }
  end

  describe "validations" do
    it "requires collection to be present" do
      storage_unit = create(:storage_unit)
      csu = described_class.new(storage_unit: storage_unit)
      expect(csu).not_to be_valid
      expect(csu.errors[:collection]).to include("must exist")
    end

    it "requires storage_unit to be present" do
      collection = create(:collection)
      csu = described_class.new(collection: collection)
      expect(csu).not_to be_valid
      expect(csu.errors[:storage_unit]).to include("must exist")
    end
  end

  describe "UUID primary key" do
    it "generates a UUID for id before validation" do
      collection = create(:collection)
      storage_unit = create(:storage_unit)
      csu = described_class.new(collection: collection, storage_unit: storage_unit)
      csu.valid?
      expect(csu.id).to be_present
      expect(csu.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe "uniqueness constraint" do
    it "prevents duplicate collection-storage_unit pairs" do
      collection = create(:collection)
      storage_unit = create(:storage_unit)
      create(:collection_storage_unit, collection: collection, storage_unit: storage_unit)

      duplicate = build(:collection_storage_unit, collection: collection, storage_unit: storage_unit)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:storage_unit_id]).to include("has already been taken")
    end

    it "allows same storage unit for different collections" do
      collection1 = create(:collection)
      collection2 = create(:collection)
      storage_unit = create(:storage_unit)

      csu1 = create(:collection_storage_unit, collection: collection1, storage_unit: storage_unit)
      csu2 = build(:collection_storage_unit, collection: collection2, storage_unit: storage_unit)

      expect(csu2).to be_valid
    end

    it "allows same collection with different storage units" do
      collection = create(:collection)
      storage_unit1 = create(:storage_unit, name: "Unit 1")
      storage_unit2 = create(:storage_unit, name: "Unit 2")

      csu1 = create(:collection_storage_unit, collection: collection, storage_unit: storage_unit1)
      csu2 = build(:collection_storage_unit, collection: collection, storage_unit: storage_unit2)

      expect(csu2).to be_valid
    end
  end
end
