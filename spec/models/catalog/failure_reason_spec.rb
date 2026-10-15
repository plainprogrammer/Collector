require "rails_helper"

# Issue #84: why a refresh or an operation failed, in plain words, with the stored error text kept as the detail.
RSpec.describe Catalog::FailureReason, type: :model do
  def reason(message, reasons = {}) = described_class.new(message, reasons:)

  describe "#sentence" do
    it "words the source turning requests away" do
      expect(reason("Catalog::Sources::RateLimitedError: GET https://example.test/x still rate limited after 3 attempts").sentence)
        .to eq(described_class::REASONS.fetch("Catalog::Sources::RateLimitedError"))
    end

    it "words the known failures each in its own sentence", :aggregate_failures do
      sentences = [ "Catalog::Sources::RateLimitedError: a", "Catalog::Sources::TransientError: GET x returned 503",
                    "Catalog::Sources::IntegrityError: short file", "SQLite3::BusyException: database is locked",
                    "ActiveRecord::StatementTimeout: SQLite3::BusyException: database is locked" ].map { reason(it).sentence }

      expect(sentences.first).to include("turning requests away")
      expect(sentences[1]).to include("couldn't be reached")
      expect(sentences[2]).to include("couldn't be verified")
      expect(sentences[3]).to include("database was busy")
      expect(sentences[4]).to eq(sentences[3])
      expect(sentences.join).not_to match(/Error|Exception|Timeout|::/)
    end

    it "takes a source's own wording for its own errors" do
      expect(reason("Zeta::Decoder::Error: no decoder", "Zeta::Decoder::Error" => "The decoder is missing.").sentence)
        .to eq("The decoder is missing.")
    end

    it "gives the generic sentence for any other error" do
      expect(reason("Errno::ENOSPC: No space left on device").sentence).to eq(described_class::GENERIC)
    end

    it "gives the generic sentence when nothing was recorded", :aggregate_failures do
      expect(reason(nil).sentence).to eq(described_class::GENERIC)
      expect(reason("").sentence).to eq(described_class::GENERIC)
    end

    it "keeps a message that isn't an error's as a sentence" do
      expect(reason("interrupted").sentence).to eq("Interrupted.")
    end
  end

  describe "#detail" do
    it "is the stored error text" do
      expect(reason("SQLite3::BusyException: database is locked").detail).to eq("SQLite3::BusyException: database is locked")
    end

    it "is nil for a message that isn't an error's", :aggregate_failures do
      expect(reason("interrupted").detail).to be_nil
      expect(reason(nil).detail).to be_nil
    end
  end

  describe ".for" do
    around { |example| with_catalog_sources({}) { example.run } }

    it "asks the type's source for its wording (optional .failure_reasons hook)", :aggregate_failures do
      source = Class.new { def self.failure_reasons = { "Zeta::Error" => "Zeta broke." } }
      stub_const("ZetaFailureSource", source)
      Catalog.sources["zeta"] = "ZetaFailureSource"
      stub_const("EtaFailureSource", Class.new)
      Catalog.sources["eta"] = "EtaFailureSource"

      expect(described_class.for("Zeta::Error: boom", "zeta").sentence).to eq("Zeta broke.")
      expect(described_class.for("Zeta::Error: boom", "eta").sentence).to eq(described_class::GENERIC)
    end
  end
end
