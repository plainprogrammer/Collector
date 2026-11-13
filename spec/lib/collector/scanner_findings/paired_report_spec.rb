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

  # Records each named card's first capture, reading the name given, or the name and collector line when given a pair.
  def measure(framing, reads, user_agent: "iPhone", extra: {})
    strip = -> { StringIO.new("\x89PNG\r\n\x1A\n".b) }
    run = run_for(framing)
    reads.each do |file, (name, collector)|
      run.record!(run.row(file), name_text: name, collector_text: collector.to_s, ms: 300, user_agent:, name_strip: strip.call, collector_strip: strip.call,
        extra: { "video_width" => 1280, "video_height" => 720, "stage_width" => 390, "stage_height" => 700, "framing" => framing }.merge(extra))
    end
    run
  end

  # Reads every card's name right, and its collector line right only for the files listed (a blank line identifies no printing).
  def reads(lines_for: [])
    { "S001" => [ "Lightning Bolt", "R 0123\nMOM • EN" ], "S002" => [ "Counterspell", "R 0007\nMOM • EN" ], "S003" => [ "Lightning Bolt", "R 0123\nMOM • EN" ] }
      .to_h { |file, (name, line)| [ file, [ name, lines_for.include?(file) ? line : "" ] ] }
  end

  def report(full:, shipped:) = described_class.new(runs: { "full" => measure("full", full), "shipped" => measure("shipped", shipped) }, truth:)

  def report_of(full_run, shipped_run) = described_class.new(runs: { "full" => full_run, "shipped" => shipped_run }, truth:)

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

  describe "bar A's slack (spec 082 AC-7.4)" do
    def bar_for(full_right:, shipped_right: %w[S001 S002 S003], full_exact: %w[S001 S002 S003], shipped_exact: %w[S001 S002 S003])
      FileUtils.rm_rf(dir.join("runs")) # a second call in one example would otherwise add retakes the first call's captures outrank
      names = ->(files, exact) { reads(lines_for: exact).to_h { |file, (name, line)| [ file, files.include?(file) ? [ name, line ] : [ "zzz", "" ] ] } }
      report_of(measure("full", names.(full_right, full_exact)), measure("shipped", names.(shipped_right, shipped_exact))).bar
    end

    it "passes with the right card first exactly one card below the shipped framing's, and fails two below", :aggregate_failures do
      expect(bar_for(full_right: %w[S001 S002])).to eq(:passes)
      expect(bar_for(full_right: %w[S001])).to eq(:fails)
    end

    it "passes with the exact printing exactly two below the shipped framing's, and fails three below", :aggregate_failures do
      expect(bar_for(full_right: %w[S001 S002 S003], full_exact: %w[S001])).to eq(:passes)
      expect(bar_for(full_right: %w[S001 S002 S003], full_exact: [])).to eq(:fails)
    end
  end

  describe "#to_markdown's run conditions (spec 082 AC-7.4)" do
    it "says per framing whether art matching was on, from a capture's art time or a recorded reading's art status", :aggregate_failures do
      full = measure("full", reads, extra: { "art_ms" => 80 })
      shipped = measure("shipped", reads)
      expect(report_of(full, shipped).to_markdown).to include("Art matching: full on; shipped off.")
      shipped.record_reading!("k" * 32, instance_double(MTG::Reading, art_usable: [], artworks: [], tier: nil, overruled: nil, overruled_scope: nil, art_status: :matched, candidates: []))
      expect(report_of(full, shipped).art_matching).to eq("full" => true, "shipped" => true)
    end

    it "lists the user agents seen in each framing" do
      markdown = report_of(measure("full", reads, user_agent: "iPhone"), measure("shipped", reads, user_agent: "Pixel")).to_markdown
      expect(markdown).to include("User agents: full iPhone; shipped Pixel.")
    end
  end
end
