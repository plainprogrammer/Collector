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

  describe ".truth_corpora (spec 010)" do
    around do |example|
      saved = ENV.delete("CARD_SCANNER_TRUTH_CORPORA")
      example.run
    ensure
      saved ? ENV["CARD_SCANNER_TRUTH_CORPORA"] = saved : ENV.delete("CARD_SCANNER_TRUTH_CORPORA")
    end

    it "defaults to spec 008's two corpora, and takes a list from the environment", :aggregate_failures do
      expect(described_class.truth_corpora).to eq(%w[phase0 new])
      ENV["CARD_SCANNER_TRUTH_CORPORA"] = "sitting"
      expect(described_class.truth_corpora).to eq(%w[sitting])
    end
  end

  it "takes the bulk file from CARD_SCANNER_BULK_FILE (spec 010)" do
    script = "require 'card_scanner_phase2'; require 'card_scanner_phase2/bulk_artworks'; puts CardScannerPhase2::BulkArtworks.latest_bulk_file"
    output = IO.popen({ "CARD_SCANNER_BULK_FILE" => "/tmp/bulk.jsonl.gz" }, [ "ruby", "-I", File.expand_path("../lib", __dir__), "-e", script ], &:read)
    expect(output.strip).to eq("/tmp/bulk.jsonl.gz")
  end

  it "takes its working folder from CARD_SCANNER_WORK_DIR (spec 010)" do
    script = "require 'card_scanner_phase2'; puts CardScannerPhase2::WORK_DIR"
    output = IO.popen({ "CARD_SCANNER_WORK_DIR" => "/tmp/art-cache" }, [ "ruby", "-I", File.expand_path("../lib", __dir__), "-e", script ], &:read)
    expect(output.strip).to eq("/tmp/art-cache")
  end
end
