require "rails_helper"

# Spec 088 decision 2: the one new reading of the evidence, "sure of the card". It changes nothing the ranking does.
RSpec.describe MTG::Reading::Candidate, type: :model do
  def candidate(evidence, strong_name: false)
    described_class.new(entry: nil, evidence:, name_rank: 0, strong_name:)
  end

  describe "#card_sure?" do
    it "trusts the card on collector-line evidence, plain or corrected", :aggregate_failures do
      expect(candidate(%i[collector_line])).to be_card_sure
      expect(candidate(%i[name collector_line_corrected])).to be_card_sure
    end

    it "trusts the card on confident art or a strong name match", :aggregate_failures do
      expect(candidate(%i[art])).to be_card_sure
      expect(candidate(%i[name], strong_name: true)).to be_card_sure
    end

    it "does not trust a name-only or weak-art candidate", :aggregate_failures do
      expect(candidate(%i[name])).not_to be_card_sure
      expect(candidate(%i[name art_weak])).not_to be_card_sure
    end
  end
end
