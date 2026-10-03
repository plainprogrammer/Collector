require_relative "phase2_helper"

RSpec.describe CardScannerPhase2 do
  describe ".median" do
    it "takes the middle value of an odd count" do
      expect(described_class.median([ 9, 1, 5 ])).to eq(5)
    end

    it "takes the mean of the two middle values of an even count", :aggregate_failures do
      expect(described_class.median([ 386, 1, 385, 400 ])).to eq(385.5)
      expect(described_class.median([ 4, 1, 2, 6 ])).to be(3) # an Integer, not 3.0
    end

    it "keeps a float sample's precision" do
      expect(described_class.median([ 1.2, 3.4 ])).to be_within(1e-9).of(2.3)
    end

    it "returns the only value of a single-value sample" do
      expect(described_class.median([ 7 ])).to eq(7)
    end

    it "returns nil for an empty sample" do
      expect(described_class.median([])).to be_nil
    end
  end
end
