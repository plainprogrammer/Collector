require_relative "../phase2_helper"
require "card_scanner_phase2/split"

RSpec.describe CardScannerPhase2::Split do
  # Non-foils A, C, D alternate to development, held out, development; foils B, E to development, held out.
  let(:phase0) { "file,set,number,foil\nA.jpeg,aaa,1,no\nB.jpeg,aaa,2,yes\nC.jpeg,aaa,3,no\nD.jpeg,aaa,4,no\nE.jpeg,aaa,5,yes\n" }
  let(:new) { "file,set,number,foil,era\nF.jpeg,bbb,1,no,\nG.jpeg,bbb,2,no,pre-M15\nH.jpeg,bbb,3,yes,\n" }
  let(:texts) { { "phase0" => phase0, "new" => new } }

  it "alternates foils and non-foils separately, each group starting with development", :aggregate_failures do
    halves = described_class.halves(texts, force_development: {})
    expect(halves.dig("phase0", "development")).to eq(%w[A.jpeg D.jpeg B.jpeg])
    expect(halves.dig("phase0", "held_out")).to eq(%w[C.jpeg E.jpeg])
    expect(halves.dig("new", "development")).to eq(%w[F.jpeg H.jpeg])
    expect(halves.dig("new", "held_out")).to eq(%w[G.jpeg])
  end

  it "forces the shared card's new-corpus photo into development", :aggregate_failures do
    halves = described_class.halves(texts, force_development: { "new" => %w[G.jpeg] })
    expect(halves.dig("new", "development")).to eq(%w[F.jpeg H.jpeg G.jpeg])
    expect(halves.dig("new", "held_out")).to be_empty
  end

  it "reads the real manifests into the committed counts", :aggregate_failures do
    halves = described_class.halves
    counts = halves.transform_values { |h| h.transform_values(&:size) }
    expect(counts).to eq("phase0" => { "development" => 26, "held_out" => 24 }, "new" => { "development" => 26, "held_out" => 23 })
    expect(halves.dig("new", "development")).to include("IMG_6763.jpeg")
  end
end
