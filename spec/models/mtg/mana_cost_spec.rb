require "rails_helper"

RSpec.describe MTG::ManaCost, type: :model do
  it "reads each symbol aloud in printed order", :aggregate_failures do
    expect(described_class.new("{1}{R}{R}").label).to eq("Mana cost: 1 generic, 1 red, 1 red")
    expect(described_class.new("{X}{C}{W}{U}{B}{G}").label).to eq("Mana cost: X, 1 colourless, 1 white, 1 blue, 1 black, 1 green")
  end

  it "shows undesigned symbols as text tags", :aggregate_failures do
    cost = described_class.new("{W/U}{G/P}{S}")
    expect(cost.pips.map(&:pip?)).to eq([ false, false, false ])
    expect(cost.label).to eq("Mana cost: white or blue, Phyrexian green, snow")
  end

  it "is empty for a blank cost" do
    expect(described_class.new(nil).pips).to eq([])
  end
end
