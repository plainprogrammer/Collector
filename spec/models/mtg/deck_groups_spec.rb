require "rails_helper"

# Spec 066 decision 6, AC-6.3: Magic's top-level types of a printing's first face, as the deck page groups rows.
RSpec.describe MTG::DeckGroups, type: :model do
  describe ".position" do
    {
      "Legendary Creature — Elf Druid" => "Creatures",
      "Artifact Creature — Golem" => "Creatures",
      "Basic Land — Forest" => "Lands",
      "Artifact Land" => "Lands",
      "Land Creature — Forest Dryad" => "Creatures",
      "Kindred Instant — Elf" => "Instants",
      "Instant" => "Instants",
      "Sorcery" => "Sorceries",
      "Legendary Planeswalker — Jace" => "Planeswalkers",
      "Battle — Siege" => "Battles",
      "Legendary Artifact — Equipment" => "Artifacts",
      "Enchantment — Aura" => "Enchantments",
      "Conspiracy" => "Other",
      "" => "Other"
    }.each do |type_line, group|
      it "puts #{type_line.inspect} in #{group}" do
        expect(described_class.group_name(described_class.position(type_line))).to eq(group)
      end
    end

    it "puts a card with no type data in Other" do
      expect(described_class.group_name(described_class.position(nil))).to eq("Other")
    end

    it "does not read a type after the dash", :aggregate_failures do
      expect(described_class.group_name(described_class.position("Creature — Land"))).to eq("Creatures")
      expect(described_class.group_name(described_class.position("Instant — Land"))).to eq("Instants")
    end
  end

  describe "NAMES" do
    it "lists the groups in the order the page shows them (decision 6)" do
      expect(described_class::NAMES).to eq(%w[Creatures Planeswalkers Battles Instants Sorceries Artifacts Enchantments Lands Other])
    end
  end
end
