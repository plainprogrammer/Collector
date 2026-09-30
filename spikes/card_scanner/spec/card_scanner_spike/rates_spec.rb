require_relative "../spike_helper"

RSpec.describe CardScannerSpike::Rates do
  let(:records) do
    [ { "era" => "MOM+", "foil" => true, "borderless_or_showcase" => false, "hit" => true },
      { "era" => "MOM+", "foil" => false, "borderless_or_showcase" => true, "hit" => false },
      { "era" => "pre-M15", "foil" => false, "borderless_or_showcase" => false, "hit" => true } ]
  end
  let(:breakdown) { described_class.breakdown(records) { it["hit"] } }

  describe ".breakdown" do
    it "rates every grouping with its sample size", :aggregate_failures do
      expect(breakdown["overall"]["all"].to_s).to eq("2/3 (66.7%)")
      expect(breakdown["era"].transform_values(&:to_s)).to eq("MOM+" => "1/2 (50.0%)", "pre-M15" => "1/1 (100.0%)")
      expect(breakdown["foil"]["foil"].to_s).to eq("1/1 (100.0%)")
      expect(breakdown["frame treatment"]["borderless/showcase"].to_s).to eq("0/1 (0.0%)")
    end
  end

  describe ".markdown" do
    it "renders a header and one row per group" do
      expect(described_class.markdown("Hit", breakdown).lines.size).to eq(2 + 7)
    end
  end
end
