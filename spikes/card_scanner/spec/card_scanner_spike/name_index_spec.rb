require_relative "../spike_helper"
require "card_scanner_spike/name_index"
require "tmpdir"

RSpec.describe CardScannerSpike::NameIndex do
  subject(:index) { described_class.new(File.join(dir, "names.sqlite3")) }

  let(:dir) { Dir.mktmpdir("name-index") }
  let(:rows) do
    [ [ "Lightning Bolt", "Lightning Bolt" ], [ "Lightning Helix", "Lightning Helix" ], [ "Aether Vial", "Aether Vial" ],
      [ "Fire // Ice", "Fire // Ice" ], [ "Fire // Ice", "Fire" ], [ "Fire // Ice", "Ice" ], [ "Ox", "Ox" ] ]
  end

  before { index.rebuild(rows) }
  after { FileUtils.remove_entry(dir) }

  def top(text) = index.search(text).first&.card_name

  it "indexes each distinct card and name pair, idempotently" do
    expect(index.rebuild(rows)).to eq(7)
  end

  it "finds a card by its exact name" do
    expect(top("Lightning Bolt")).to eq("Lightning Bolt")
  end

  it "finds a card from a misread name" do
    expect(top("Lightnlng Bo1t")).to eq("Lightning Bolt")
  end

  it "finds a card whose name has a ligature" do
    expect(top("Æther Vial")).to eq("Aether Vial")
  end

  it "maps a face name to its card, once per card", :aggregate_failures do
    expect(top("Fire")).to eq("Fire // Ice")
    expect(index.search("Fire").map(&:card_name)).to eq(index.search("Fire").map(&:card_name).uniq)
  end

  it "falls back to exact and prefix matching below three characters" do
    expect(top("Ox")).to eq("Ox")
  end

  it "returns at most the limit, best first" do
    expect(index.search("Lightning", limit: 1).map(&:card_name)).to eq([ "Lightning Bolt" ])
  end

  it "returns nothing for text that normalises to nothing" do
    expect(index.search(" -- ")).to eq([])
  end

  it "lists names shorter than three characters" do
    expect(index.short_names).to eq([ [ "Ox", "Ox" ] ])
  end

  it "looks up the cards an exact name belongs to" do
    expect(index.card_names_for("fire")).to eq([ "Fire // Ice" ])
  end
end
