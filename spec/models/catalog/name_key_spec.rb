require "rails_helper"

RSpec.describe Catalog::NameKey do
  it "folds ligatures, diacritics, case and punctuation", :aggregate_failures do
    expect(described_class.call("Æther Vial")).to eq("aether vial")
    expect(described_class.call("Lim-Dûl's Vault")).to eq("lim duls vault")
    expect(described_class.call("  Jötun   Grunt\n")).to eq("jotun grunt")
    expect(described_class.call("Fire // Ice")).to eq("fire ice")
  end

  it "folds full-width characters" do
    expect(described_class.call("Ｌｉｇｈｔｎｉｎｇ Bolt")).to eq("lightning bolt")
  end

  it "returns an empty string for nil and for text with no letters or digits", :aggregate_failures do
    expect(described_class.call(nil)).to eq("")
    expect(described_class.call("_____")).to eq("")
  end
end
