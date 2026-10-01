require "rails_helper"

RSpec.describe MTG::Collecting, type: :model do
  it "is registered for mtg" do
    expect(Catalog.collecting_for("mtg")).to eq(described_class)
  end

  it "offers the printing's finishes, nonfoil first", :aggregate_failures do
    printing = create(:mtg_printing, finishes: %w[etched foil nonfoil])
    expect(described_class.finishes_for(printing.entry)).to eq(%w[nonfoil foil etched])
    expect(described_class.finishes_for(create(:catalog_entry))).to eq([])
  end

  it "defines the category name, condition scale and special finishes", :aggregate_failures do
    expect(described_class.category_name).to eq("Magic: The Gathering")
    expect(described_class.conditions.values.map(&:last)).to eq(%w[NM LP MP HP DMG])
    expect(described_class.special_finishes).to eq(%w[foil etched])
    expect(described_class.finish_label("glossy")).to eq("Glossy")
  end

  it "orders finishes nonfoil, foil, etched" do
    expect(described_class.finish_order).to eq(%w[nonfoil foil etched])
  end
end
