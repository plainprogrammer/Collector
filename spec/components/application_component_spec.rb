# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationComponent, type: :component do
  let(:component) { described_class.new }

  describe "#condition_class" do
    it "returns appropriate classes for Near Mint condition" do
      expect(component.condition_class("NM")).to include("bg-green-50", "text-green-700")
    end

    it "returns appropriate classes for Lightly Played condition" do
      expect(component.condition_class("LP")).to include("bg-blue-50", "text-blue-700")
    end

    it "returns appropriate classes for Moderately Played condition" do
      expect(component.condition_class("MP")).to include("bg-yellow-50", "text-yellow-800")
    end

    it "returns appropriate classes for Heavily Played condition" do
      expect(component.condition_class("HP")).to include("bg-orange-50", "text-orange-700")
    end

    it "returns appropriate classes for Damaged condition" do
      expect(component.condition_class("DMG")).to include("bg-red-50", "text-red-700")
    end

    it "returns default gray classes for unknown condition" do
      expect(component.condition_class("UNKNOWN")).to include("bg-gray-50", "text-gray-600")
    end

    it "includes base classes for all conditions" do
      expect(component.condition_class("NM")).to include("inline-flex", "items-center", "rounded-md")
    end
  end

  describe "#finish_class" do
    it "returns appropriate classes for nonfoil finish" do
      expect(component.finish_class("nonfoil")).to include("bg-gray-50", "text-gray-600")
    end

    it "returns appropriate classes for foil finish" do
      expect(component.finish_class("foil")).to include("bg-purple-50", "text-purple-700")
    end

    it "returns appropriate classes for etched finish" do
      expect(component.finish_class("etched")).to include("bg-indigo-50", "text-indigo-700")
    end

    it "returns default gray classes for unknown finish" do
      expect(component.finish_class("unknown")).to include("bg-gray-50", "text-gray-600")
    end

    it "includes base classes for all finishes" do
      expect(component.finish_class("foil")).to include("inline-flex", "items-center", "rounded-md")
    end
  end

  describe "#mana_symbols" do
    it "returns empty string for nil input" do
      expect(component.mana_symbols(nil)).to eq("")
    end

    it "returns empty string for blank input" do
      expect(component.mana_symbols("")).to eq("")
    end

    it "wraps mana cost in span with mana-cost class" do
      result = component.mana_symbols("{2}{W}{W}")
      expect(result).to include("mana-cost")
      expect(result).to include("{2}{W}{W}")
    end
  end
end
