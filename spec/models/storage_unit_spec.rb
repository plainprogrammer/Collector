# frozen_string_literal: true

require "rails_helper"

RSpec.describe StorageUnit, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:parent).class_name("StorageUnit").optional }
    it { is_expected.to have_many(:children).class_name("StorageUnit").with_foreign_key(:parent_id) }
  end

  describe "validations" do
    it "requires name to be present" do
      unit = described_class.new(unit_type: "box")
      expect(unit).not_to be_valid
      expect(unit.errors[:name]).to include("can't be blank")
    end

    it "requires unit_type to be present" do
      unit = described_class.new(name: "Test Unit")
      expect(unit).not_to be_valid
      expect(unit.errors[:unit_type]).to include("can't be blank")
    end
  end

  describe "UUID primary key" do
    it "generates a UUID for id before validation" do
      unit = described_class.new(name: "Test Unit", unit_type: "box")
      unit.valid?
      expect(unit.id).to be_present
      expect(unit.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "does not override an existing id" do
      existing_id = SecureRandom.uuid
      unit = described_class.new(
        id: existing_id,
        name: "Test Unit",
        unit_type: "box"
      )
      unit.valid?
      expect(unit.id).to eq(existing_id)
    end
  end

  describe "self-referential nesting" do
    it "can have a parent storage unit" do
      parent = create(:storage_unit, name: "Shelf")
      child = create(:storage_unit, name: "Box", parent: parent)

      expect(child.parent).to eq(parent)
    end

    it "can have multiple children" do
      parent = create(:storage_unit, name: "Shelf")
      child1 = create(:storage_unit, name: "Box 1", parent: parent)
      child2 = create(:storage_unit, name: "Box 2", parent: parent)

      expect(parent.children).to include(child1, child2)
      expect(parent.children.count).to eq(2)
    end

    it "can be a root unit (no parent)" do
      root = create(:storage_unit, name: "Main Shelf", parent: nil)

      expect(root.parent).to be_nil
    end
  end

  describe "unit_type values" do
    it "accepts shelf type" do
      unit = build(:storage_unit, unit_type: "shelf")
      expect(unit).to be_valid
    end

    it "accepts box type" do
      unit = build(:storage_unit, unit_type: "box")
      expect(unit).to be_valid
    end

    it "accepts binder type" do
      unit = build(:storage_unit, unit_type: "binder")
      expect(unit).to be_valid
    end

    it "accepts deck type" do
      unit = build(:storage_unit, unit_type: "deck")
      expect(unit).to be_valid
    end
  end
end
