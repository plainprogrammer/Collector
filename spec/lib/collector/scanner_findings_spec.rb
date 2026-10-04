require "rails_helper"

RSpec.describe Collector::ScannerFindings do
  let(:records) do
    [ { "era" => "MOM+", "foil" => true, "borderless_or_showcase" => false, "hit" => true },
      { "era" => "MOM+", "foil" => false, "borderless_or_showcase" => true, "hit" => false },
      { "era" => "pre-M15", "foil" => false, "borderless_or_showcase" => false, "hit" => true } ]
  end

  it "rates every grouping with its sample size", :aggregate_failures do
    rates = described_class.breakdown(records) { it["hit"] }
    expect(rates["overall"]["all"].to_s).to eq("2/3 (66.7%)")
    expect(rates["era"].transform_values(&:to_s)).to eq("MOM+" => "1/2 (50.0%)", "pre-M15" => "1/1 (100.0%)")
    expect(rates["frame treatment"]["borderless/showcase"].to_s).to eq("0/1 (0.0%)")
  end

  it "compares sources column by column, with a dash where a source has no such group", :aggregate_failures do
    table = described_class.comparison("Hit", "A" => records, "B" => records.first(1)) { it["hit"] }
    expect(table.lines.first.strip).to eq("| Hit | Group | A | B |")
    expect(table).to include("| era | pre-M15 | 1/1 (100.0%) | — |")
  end

  it "scores reads, printings and rankings the way spec 005 did", :aggregate_failures do
    record = { "name_text" => "FIRE\n", "name_bar" => "Fire", "name" => "Fire // Ice", "external_key" => "abc",
               "lookup" => { "status" => "one", "external_keys" => [ "abc" ] }, "name_candidates" => [ "Fireball", "Fire // Ice" ] }
    expect(described_class.name_read?(record)).to be(true)
    expect(described_class.name_read?(record, against: "name")).to be(false)
    expect(described_class.printing_identified?(record)).to be(true)
    expect([ described_class.in_top?(record, "name_candidates", 1), described_class.in_top?(record, "name_candidates", 3) ]).to eq([ false, true ])
    expect(described_class.percentile([ 5, 1, 3, 2, 4 ], 95)).to eq(5)
  end

  describe "with a catalog" do
    let(:entry) do
      identity = create(:catalog_identity, name: "Lightning Bolt")
      create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123")).entry
    end

    before { entry && Catalog::NameIndex.new("mtg").rebuild }

    it "re-reads any run's text through Phase 1's matcher, keeping both rankings (AC-6.3)" do
      record = described_class.rescore({ "IMG_1.jpeg" => { "name" => "Lightning Bolt" } },
        [ { "file" => "IMG_1.jpeg", "name_text" => "Lightnlng Bolt", "collector_text" => "R 0123\nMOM • EN", "ms" => 640 } ]).sole
      expect(record).to include("ms" => 640, "lookup" => { "status" => "one", "external_keys" => [ entry.external_key ] },
        "name_candidates" => [ "Lightning Bolt" ], "final_candidates" => [ "Lightning Bolt" ])
    end

    it "builds ground truth for a tuning manifest (AC-6.1)", :aggregate_failures do
      truth = described_class.ground_truth("file,set,number,foil\nIMG_1.jpeg,mom,123,yes\nIMG_2.jpeg,mom,999,no\n")
      expect(truth["photos"].sole).to include("file" => "IMG_1.jpeg", "name" => "Lightning Bolt", "name_bar" => "Lightning Bolt", "foil" => true, "era" => "M15–ONE")
      expect(truth["errors"].sole).to include("file" => "IMG_2.jpeg", "problem" => "none")
    end

    it "records each card's finish in ground truth, from a finish column or the foil column (spec 009 AC-9.1)" do
      truth = described_class.ground_truth("file,set,number,foil,era,finish\nIMG_1.jpeg,mom,123,yes,,\nIMG_3.jpeg,mom,123,no,,etched\n")
      expect(truth["photos"].map { it["finish"] }).to eq(%w[foil etched])
    end

    it "lists cards already used by earlier corpora (spec 009 AC-9.1)" do
      fresh = [ { "file" => "S001", "name" => "Lightning Bolt", "external_key" => "x" }, { "file" => "S002", "name" => "Opt", "external_key" => "y" } ]
      earlier = { "Phase 0" => [ { "file" => "IMG_1.jpeg", "name" => "Lightning Bolt", "external_key" => "z" } ] }
      expect(described_class.overlaps(fresh, earlier)).to eq([ "S001 Lightning Bolt is Phase 0 IMG_1.jpeg (another printing)" ])
    end
  end

  describe ".headline (spec 009 tuning)" do
    it "gives right first, top 3, exact printing by foil, name read and outlines found, each with its sample size" do
      records = [
        { "name" => "A", "name_bar" => "A", "name_text" => "A", "final_candidates" => %w[A], "era" => "MOM+", "foil" => true, "external_key" => "k1",
          "lookup" => { "status" => "one", "external_keys" => [ "k1" ] }, "outline" => "found" },
        { "name" => "B", "name_bar" => "B", "name_text" => "x", "final_candidates" => %w[C B], "era" => "pre-M15", "foil" => false, "external_key" => "k2",
          "lookup" => { "status" => "none", "external_keys" => [] }, "outline" => "not_found" }
      ]
      expect(described_class.headline(records)).to eq("right card first 1/2 (50.0%); top 3 2/2 (100.0%); exact printing 1/1 (100.0%) " \
        "(foils 1/1 (100.0%), non-foils 0/0 (n/a)); name read 1/2 (50.0%); outline found 1/2 (50.0%)")
    end
  end
end
