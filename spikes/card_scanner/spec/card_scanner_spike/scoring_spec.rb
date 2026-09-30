require_relative "../spike_helper"

RSpec.describe CardScannerSpike::Scoring do
  let(:truth) { { "name" => "Fire // Ice", "name_bar" => "Fire", "external_key" => "abc" } }

  describe ".name_read?" do
    it "compares normalised text", :aggregate_failures do
      expect(described_class.name_read?({ "name_text" => "FIRE\n" }, truth)).to be(true)
      expect(described_class.name_read?({ "name_text" => "Firc" }, truth)).to be(false)
    end
  end

  describe ".printing_identified?" do
    it "needs exactly the expected printing", :aggregate_failures do
      expect(described_class.printing_identified?({ "lookup" => { "status" => "one", "external_keys" => [ "abc" ] } }, truth)).to be(true)
      expect(described_class.printing_identified?({ "lookup" => { "status" => "ambiguous", "external_keys" => %w[abc def] } }, truth)).to be(false)
    end
  end

  describe ".in_top?" do
    it "looks only at the first candidates", :aggregate_failures do
      match = { "candidates" => [ { "card_name" => "Fireball" }, { "card_name" => "Fire // Ice" } ] }
      expect(described_class.in_top?(match, truth, 1)).to be(false)
      expect(described_class.in_top?(match, truth, 3)).to be(true)
    end
  end

  describe ".percentile" do
    it "picks the nearest rank", :aggregate_failures do
      expect(described_class.percentile([ 5, 1, 3, 2, 4 ], 50)).to eq(3)
      expect(described_class.percentile([ 5, 1, 3, 2, 4 ], 95)).to eq(5)
      expect(described_class.percentile([], 50)).to be_nil
    end
  end

  describe ".differences" do
    it "lists strips whose text changed between runs" do
      a = [ { "file" => "x.jpg", "name_text" => "Fire", "collector_text" => "1/2" } ]
      b = [ { "file" => "x.jpg", "name_text" => "Firc", "collector_text" => "1/2" } ]
      expect(described_class.differences(a, b)).to eq([ { "file" => "x.jpg", "field" => "name_text", "a" => "Fire", "b" => "Firc" } ])
    end
  end

  describe ".misread" do
    it "swaps the middle character for a lookalike, or x", :aggregate_failures do
      expect(described_class.misread("Bolt")).to eq("Bo1t")
      expect(described_class.misread("Ice")).to eq("Ixe")
    end
  end
end
