# frozen_string_literal: true

require "rails_helper"

RSpec.describe MTGCardItemDetail, type: :model do
  describe "UUID primary key" do
    it "generates a UUID for id before validation" do
      detail = described_class.new
      detail.valid?
      expect(detail.id).to be_present
      expect(detail.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end

  describe "defaults" do
    it "defaults condition to NM" do
      detail = described_class.new
      expect(detail.condition).to eq("NM")
    end

    it "defaults finish to nonfoil" do
      detail = described_class.new
      expect(detail.finish).to eq("nonfoil")
    end

    it "defaults language to EN" do
      detail = described_class.new
      expect(detail.language).to eq("EN")
    end

    it "defaults signed to false" do
      detail = described_class.new
      expect(detail.signed).to eq(false)
    end

    it "defaults altered to false" do
      detail = described_class.new
      expect(detail.altered).to eq(false)
    end

    it "defaults graded to false" do
      detail = described_class.new
      expect(detail.graded).to eq(false)
    end
  end

  describe "condition values" do
    it "accepts NM (Near Mint)" do
      detail = build(:mtg_card_item_detail, condition: "NM")
      expect(detail).to be_valid
    end

    it "accepts LP (Lightly Played)" do
      detail = build(:mtg_card_item_detail, condition: "LP")
      expect(detail).to be_valid
    end

    it "accepts MP (Moderately Played)" do
      detail = build(:mtg_card_item_detail, condition: "MP")
      expect(detail).to be_valid
    end

    it "accepts HP (Heavily Played)" do
      detail = build(:mtg_card_item_detail, condition: "HP")
      expect(detail).to be_valid
    end

    it "accepts DMG (Damaged)" do
      detail = build(:mtg_card_item_detail, condition: "DMG")
      expect(detail).to be_valid
    end
  end

  describe "finish values" do
    it "accepts nonfoil" do
      detail = build(:mtg_card_item_detail, finish: "nonfoil")
      expect(detail).to be_valid
    end

    it "accepts foil" do
      detail = build(:mtg_card_item_detail, finish: "foil")
      expect(detail).to be_valid
    end

    it "accepts etched" do
      detail = build(:mtg_card_item_detail, finish: "etched")
      expect(detail).to be_valid
    end
  end

  describe "grading fields" do
    it "allows grading_service when graded is true" do
      detail = build(:mtg_card_item_detail, graded: true, grading_service: "PSA", grade: "9")
      expect(detail).to be_valid
    end

    it "allows nil grading_service when graded is false" do
      detail = build(:mtg_card_item_detail, graded: false, grading_service: nil, grade: nil)
      expect(detail).to be_valid
    end
  end
end
