require "rails_helper"

RSpec.describe Collector::Backup::Refusal, :backup do
  it "keeps what is wrong and what to do as two sentences, and reads as both (FR-4, AC-3.8)", :aggregate_failures do
    refusal = described_class.new("The volume isn't empty.", "Restore onto a new volume.")

    expect(refusal).to have_attributes(problem: "The volume isn't empty.", advice: "Restore onto a new volume.",
      message: "The volume isn't empty. Restore onto a new volume.")
  end
end
