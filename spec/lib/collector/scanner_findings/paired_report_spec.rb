require "rails_helper"

RSpec.describe Collector::ScannerFindings::PairedReport do
  let(:dir) { Pathname(Dir.mktmpdir("paired")) }
  let(:mom) { create(:catalog_set, code: "mom") }
  let(:bolt) { create(:mtg_printing, entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Lightning Bolt"), name: "Lightning Bolt", set: mom, number: "123")).entry }
  let(:opt) { create(:mtg_printing, entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Counterspell"), name: "Counterspell", set: mom, number: "7")).entry }
  let(:truth) do
    { "S001" => truth_for("S001", bolt), "S002" => truth_for("S002", opt), "S003" => truth_for("S003", bolt) }
  end

  def truth_for(file, entry)
    { "file" => file, "name" => entry.name, "name_bar" => entry.name, "set_code" => "mom", "collector_number" => entry.number,
      "external_key" => entry.external_key, "era" => "MOM+", "foil" => false, "finish" => "nonfoil" }
  end

  def run_for(framing) = Scanner::MeasurementRun.new(manifest: dir.join("manifest.csv"), dir: dir.join("runs", framing))

  # Records each named card's first capture, reading the name given ("" for a card the framing never measured).
  def measure(framing, reads)
    strip = -> { StringIO.new("\x89PNG\r\n\x1A\n".b) }
    run = run_for(framing)
    reads.each do |file, text|
      run.record!(run.row(file), name_text: text, collector_text: "", ms: 300, user_agent: "iPhone", name_strip: strip.call, collector_strip: strip.call,
        extra: { "video_width" => 1280, "video_height" => 720, "stage_width" => 390, "stage_height" => 700, "framing" => framing })
    end
    run
  end

  def report(full:, shipped:) = described_class.new(runs: { "full" => measure("full", full), "shipped" => measure("shipped", shipped) }, truth:)

  before do
    bolt && opt
    Catalog::NameIndex.new("mtg").rebuild
    dir.join("manifest.csv").write("file,set,number,foil\nS001,mom,123,no\nS002,mom,7,no\nS003,mom,123,no\n")
  end

  after { FileUtils.remove_entry(dir) }

  it "tabulates one column per framing, with the discordant cards and the sizes", :aggregate_failures do
    markdown = report(full: { "S001" => "Lightning Bolt", "S002" => "Counterspell" }, shipped: { "S001" => "Lightning Bolt", "S002" => "zzz" }).to_markdown
    expect(markdown).to include("| Rate | full | shipped |", "| right card first |", "| top 3 |", "| exact printing |", "| name read |")
    expect(markdown).to include("full 1280×720×390×700", "S002: full only", "Bar A: passes")
  end

  it "passes bar A when the full framing is within the slack, and fails it below" do
    passing = report(full: { "S001" => "Lightning Bolt", "S002" => "Counterspell" }, shipped: { "S001" => "Lightning Bolt", "S002" => "zzz" })
    expect(passing.bar).to eq(:passes)
  end

  it "fails bar A when the full framing reads none the shipped one reads", :aggregate_failures do
    failing = report(full: { "S001" => "zzz", "S002" => "zzz" }, shipped: { "S001" => "Lightning Bolt", "S002" => "Counterspell" })
    expect(failing.bar).to eq(:fails)
    expect(failing.discordant).to contain_exactly("S001: shipped only", "S002: shipped only")
  end

  it "leaves a card only one framing measured out of every rate, and lists it", :aggregate_failures do
    paired = report(full: { "S001" => "Lightning Bolt", "S002" => "Counterspell", "S003" => "Lightning Bolt" }, shipped: { "S001" => "Lightning Bolt", "S002" => "Counterspell" })
    expect(paired.unpaired).to eq([ "S003" ])
    expect(paired.records.values.map(&:size)).to eq([ 2, 2 ])
    expect(paired.to_markdown).to include("Unpaired (left out): S003.")
  end
end
