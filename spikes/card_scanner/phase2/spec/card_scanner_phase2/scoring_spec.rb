require "rails_helper"
require_relative "../phase2_helper"
require "card_scanner_phase2/scoring"

RSpec.describe CardScannerPhase2::Scoring, type: :model do
  def record(file, corpus, era: "MOM+", foil: false, final: [], names: [], status: "none", keys: [], key: "k", found: true, klass: nil)
    { "file" => file, "corpus" => corpus, "name" => "Right", "era" => era, "foil" => foil, "borderless_or_showcase" => false,
      "external_key" => key, "final_candidates" => final, "name_candidates" => names, "lookup" => { "status" => status, "external_keys" => keys },
      "found" => found, "class" => klass || (found ? "found" : "not_found") }
  end

  let(:run) do
    [ record("A.jpeg", "phase0", final: %w[Right], names: %w[Right], status: "one", keys: %w[k]),
      record("B.jpeg", "phase0", final: %w[Other Right], names: %w[Other]),
      record("C.jpeg", "new", found: false),
      record("D.jpeg", "new", era: "pre-M15", final: %w[Right], names: %w[Right]) ]
  end
  let(:baseline) { run.map { it.except("found", "class").merge("final_candidates" => [], "name_candidates" => [], "lookup" => { "status" => "none", "external_keys" => [] }) } }

  it "lays out the spec's rates per source, for both corpora together and each on its own", :aggregate_failures do
    tables = described_class.tables("Hand (dev, biased)" => run, "Baseline" => baseline)
    expect(tables.keys).to eq([ "both", "phase0", "new" ])
    both = tables["both"]
    expect(both).to include("| Top 1, final ranking | Group | Hand (dev, biased) | Baseline |", "| overall | all | 2/4 (50.0%) | 0/4 (0.0%) |")
    expect(both).to include("| Top 3, final ranking | Group | Hand (dev, biased) | Baseline |", "| overall | all | 3/4 (75.0%) | 0/4 (0.0%) |")
    expect(both).to include("| Exact printing (M15–ONE, MOM+) | Group | Hand (dev, biased) | Baseline |", "| overall | all | 1/3 (33.3%) | 0/3 (0.0%) |")
    expect(both).to include("| Top 3, name only | Group | Hand (dev, biased) | Baseline |", "| overall | all | 2/4 (50.0%) | 0/4 (0.0%) |")
    expect(both).to include("Lookup outcomes", "Detection: Hand (dev, biased) found 3, not_found 1")
    expect(both).not_to include("Detection: Baseline")
    expect(tables["new"]).to include("| overall | all | 1/2 (50.0%) | 0/2 (0.0%) |")
  end

  it "lists the misses with their class", :aggregate_failures do
    misses = described_class.misses(run)
    expect(misses.map { it["file"] }).to eq(%w[C.jpeg])
    expect(misses.first["class"]).to eq("not_found")
  end
end
