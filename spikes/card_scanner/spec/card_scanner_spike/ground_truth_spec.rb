require "rails_helper"
require_relative "../spike_helper"
require "card_scanner_spike/printing_lookup"
require "card_scanner_spike/ground_truth"

RSpec.describe CardScannerSpike::GroundTruth, type: :model do
  subject(:ground_truth) { described_class.new }

  let(:manifest) { "file,set,number,foil\nbolt.jpg,NEO,51,yes\nghost.jpg,NEO,999,no\n" }

  before do
    neo = create(:catalog_set, code: "neo", released_on: Date.new(2022, 2, 18))
    create(:mtg_printing, entry: create(:catalog_entry, set: neo, number: "51", released_on: neo.released_on), border_color: "borderless")
  end

  it "records each resolvable photo with its derived fields" do
    photos = ground_truth.build(manifest, corpus_files: %w[bolt.jpg ghost.jpg]).fetch("photos")
    expect(photos).to contain_exactly(include("file" => "bolt.jpg", "name" => "Lightning Bolt", "name_bar" => "Lightning Bolt",
      "set_code" => "neo", "collector_number" => "51", "era" => "M15–ONE", "foil" => true, "borderless_or_showcase" => true))
  end

  it "lists rows that match no printing as ground-truth errors" do
    errors = ground_truth.build(manifest, corpus_files: %w[bolt.jpg ghost.jpg]).fetch("errors")
    expect(errors).to contain_exactly(include("file" => "ghost.jpg", "problem" => "none"))
  end

  it "lists rows whose photo is missing as ground-truth errors" do
    errors = ground_truth.build(manifest, corpus_files: %w[bolt.jpg]).fetch("errors")
    expect(errors).to contain_exactly(include("file" => "ghost.jpg", "problem" => "missing photo"))
  end

  it "lets the manifest override the era" do
    photos = ground_truth.build("file,set,number,foil,era\nbolt.jpg,NEO,51,no,MOM+\n", corpus_files: %w[bolt.jpg]).fetch("photos")
    expect(photos.first["era"]).to eq("MOM+")
  end

  it "counts photos per era and foil" do
    counts = ground_truth.build(manifest, corpus_files: %w[bolt.jpg ghost.jpg]).fetch("counts")
    expect(counts).to eq("total" => 1, "foil" => 1, "by_era" => { "pre-M15" => 0, "M15–ONE" => 1, "MOM+" => 0 })
  end

  describe ".era_for" do
    it "splits eras at the M15 and MOM releases", :aggregate_failures do
      expect(described_class.era_for(Date.new(2014, 7, 17))).to eq("pre-M15")
      expect(described_class.era_for(Date.new(2014, 7, 18))).to eq("M15–ONE")
      expect(described_class.era_for(Date.new(2023, 4, 21))).to eq("MOM+")
    end
  end
end
