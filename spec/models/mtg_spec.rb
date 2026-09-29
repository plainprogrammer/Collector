require "rails_helper"

RSpec.describe MTG, type: :model do
  it "is the constant for the mtg namespace" do
    expect("mtg/printing".camelize).to eq("MTG::Printing")
  end

  it "prefixes extension tables with mtg_" do
    expect(described_class.table_name_prefix).to eq("mtg_")
  end
end
