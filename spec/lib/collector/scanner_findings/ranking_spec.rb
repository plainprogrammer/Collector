require "rails_helper"

RSpec.describe Collector::ScannerFindings::Ranking do
  let(:fixtures) { Pathname(Dir.mktmpdir) }
  let(:ranking) { described_class.new(fixtures:, runs: { "Live" => %w[results.json truth.json] }, misreads: { "Live" => %w[a.jpeg] }) }

  before do
    mom = create(:catalog_set, code: "mom")
    [ "Lightning Bolt", "Lightning Helix" ].each_with_index do |name, index|
      identity = create(:catalog_identity, name:)
      create(:mtg_printing, entry: create(:catalog_entry, identity:, name:, set: mom, number: (123 + index).to_s))
    end
    Catalog::NameIndex.new("mtg").rebuild
    fixtures.join("truth.json").write(JSON.generate("photos" => [ { "file" => "a.jpeg", "name" => "Lightning Bolt" },
      { "file" => "b.jpeg", "name" => "Lightning Helix" } ]))
    fixtures.join("results.json").write(JSON.generate("results" => [
      { "file" => "a.jpeg", "name_text" => "Lightning Bolt", "collector_text" => "" },
      { "file" => "b.jpeg", "name_text" => "Lightning Helix", "collector_text" => "" },
      { "file" => "c.jpeg", "name_text" => "Untracked", "collector_text" => "" } ]))
  end

  after { FileUtils.rm_rf(fixtures) }

  it "ranks every reading that has ground truth, with its final and name-only top 3", :aggregate_failures do
    rows = ranking.rankings.fetch("Live")
    expect(rows.map { it["file"] }).to eq(%w[a.jpeg b.jpeg])
    expect(rows.first).to include("expected" => "Lightning Bolt", "name" => include("Lightning Bolt"))
    expect(rows.first["final"].first).to eq("Lightning Bolt")
  end

  it "writes a baseline that loses nothing against itself", :aggregate_failures do
    ranking.write_baseline!
    expect(JSON.parse(fixtures.join(described_class::BASELINE).read)).to include("format_version" => 1, "ranking" => "spec 007")
    now = ranking.rankings
    expect(ranking.losses(now)).to be_empty
    expect(ranking.name_losses(now)).to be_empty
    expect(ranking.misreads_fixed?(now)).to be(true)
  end

  it "reports a lost first place and the changed first candidate", :aggregate_failures do
    ranking.write_baseline!
    worse = ranking.rankings.transform_values do |rows|
      rows.map { it["file"] == "a.jpeg" ? it.merge("final" => [ "Lightning Helix", "Lightning Bolt" ]) : it }
    end
    expect(ranking.losses(worse)).to eq([ [ "Live", "a.jpeg" ] ])
    expect(ranking.misreads_fixed?(worse)).to be(false)
    expect(ranking.comparison(worse)).to include("| Live | a.jpeg | Lightning Bolt |", "Right first places lost: Live a.jpeg")
  end
end
