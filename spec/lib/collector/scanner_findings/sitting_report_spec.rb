require "rails_helper"

RSpec.describe Collector::ScannerFindings::SittingReport do
  let(:dir) { Pathname(Dir.mktmpdir("sitting")) }
  let(:run) { Scanner::MeasurementRun.new(manifest: dir.join("manifest.csv"), dir: dir.join("run")) }
  let(:account) { create(:user).account }
  let(:bolt) { create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, name: "Lightning Bolt", set: mom, number: "123")).entry }
  let(:opt) { create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, name: "Opt", set: mom, number: "7")).entry }

  def mom = Catalog::Set.find_by(collectible_type: "mtg", code: "mom") || create(:catalog_set, code: "mom")
  def report = described_class.new(run:, account:, ground_truth: dir.join("truth.json"))

  before do
    dir.join("manifest.csv").write("file,set,number,foil\nS001,mom,123,no\nS002,mom,7,yes\nS003,mom,123,no\n")
    dir.join("truth.json").write(JSON.generate("photos" => [
      { "file" => "S001", "name" => "Lightning Bolt", "set_code" => "mom", "collector_number" => "123", "external_key" => bolt.external_key, "finish" => "nonfoil", "foil" => false },
      { "file" => "S002", "name" => "Opt", "set_code" => "mom", "collector_number" => "7", "external_key" => opt.external_key, "finish" => "foil", "foil" => true },
      { "file" => "S003", "name" => "Lightning Bolt", "set_code" => "mom", "collector_number" => "123", "external_key" => bolt.external_key, "finish" => "nonfoil", "foil" => false } ]))
    scan("S001", "a", bolt, "nonfoil", rank: "1")
    scan("S002", "b", opt, "nonfoil", rank: "2")
    Scanner::SittingEntry.find_by!(reading_key: "b" * 32).undo!
    run.record_event!(run.row("S002"), kind: "undo", rank: nil, reading_key: "b" * 32)
    scan("S002", "c", opt, "foil", rank: "other")
  end

  after { FileUtils.remove_entry(dir) }

  def scan(file, key, printing, finish, rank:)
    strip = -> { StringIO.new("\x89PNG\r\n\x1A\n".b) }
    run.record!(run.row(file), name_text: printing.name, collector_text: "", ms: 200, user_agent: "iPhone", name_strip: strip.call,
      collector_strip: strip.call, extra: { "reading_key" => key * 32, "outline" => "live" })
    Scanner::Sitting.add!(account:, printing:, finish:, reading_key: key * 32)
    run.record_event!(run.row(file), kind: "add", rank:, reading_key: key * 32)
  end

  it "scores each card by what it ended as, with the corrections on the way (AC-9.1)", :aggregate_failures do
    outcomes = report.outcomes.index_by(&:file)
    expect(outcomes["S001"].kind).to eq("right first time")
    expect(outcomes["S002"]).to have_attributes(kind: "right after a correction", corrections: [ "a candidate other than the first", "Other printings", "Undo and re-add" ], scans: 2)
    expect(outcomes["S003"].kind).to eq("not added")
  end

  it "reads the finish from the lot after an edit" do
    Scanner::SittingEntry.find_by!(reading_key: "a" * 32).lot.revise!(finish: "foil")
    expect(report.outcomes.find { it.file == "S001" }.kind).to eq("wrong")
  end

  it "summarises the outcomes by finish, the corrections and the time per card", :aggregate_failures do
    markdown = report.to_markdown
    expect(markdown).to include("| all | 1/3 | 1/3 | 0/3 | 1/3 |", "| foil | 0/1 | 1/1 | 0/1 | 0/1 |", "Other printings: 1")
    expect(markdown).to match(/Time per card, .*\(n=2\)/)
    expect(markdown).to include("| S003 | Lightning Bolt (MOM · 123, nonfoil) | — | not added |")
  end
end
