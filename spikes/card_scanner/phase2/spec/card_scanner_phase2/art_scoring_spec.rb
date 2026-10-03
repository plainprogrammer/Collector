require_relative "../phase2_helper"
require "card_scanner_phase2/art_scoring"

RSpec.describe CardScannerPhase2::ArtScoring do
  let(:data) do
    { "artworks" => { "art-1" => { "name" => "Right", "entries" => 2 }, "art-2" => { "name" => "Other", "entries" => 1 }, "art-3" => { "name" => "Right", "entries" => 1 } },
      "entries" => { "k1" => "art-1", "k2" => "art-1", "k3" => "art-3" }, "names" => { "Right" => 3, "Other" => 1 } }
  end
  let(:records) do
    [ { "file" => "A.jpeg", "corpus" => "phase0", "name" => "Right", "external_key" => "k1", "era" => "MOM+", "foil" => false, "borderless_or_showcase" => false,
        "found" => true, "class" => "found", "art" => [ { "id" => "art-1", "distance" => 200 }, { "id" => "art-2", "distance" => 300 } ], "text_top3" => false, "lookup" => { "status" => "none" } },
      { "file" => "B.jpeg", "corpus" => "phase0", "name" => "Right", "external_key" => "k3", "era" => "pre-M15", "foil" => true, "borderless_or_showcase" => false,
        "found" => true, "class" => "wrong_outline", "art" => [ { "id" => "art-2", "distance" => 250 }, { "id" => "art-3", "distance" => 260 } ], "text_top3" => true, "lookup" => { "status" => "none" } },
      { "file" => "C.jpeg", "corpus" => "new", "name" => "Right", "external_key" => "k2", "era" => "MOM+", "foil" => false, "borderless_or_showcase" => true,
        "found" => false, "class" => "not_found", "art" => nil, "text_top3" => false, "lookup" => { "status" => "none" } } ]
  end

  it "scores the right artwork first and in the top 3, over all photos and over the ones classed as found", :aggregate_failures do
    scored = described_class.score(records, data)
    expect(scored.map { it["right_artwork"] }).to eq(%w[art-1 art-3 art-1])
    expect(scored.map { it["art_rank"] }).to eq([ 1, 2, nil ])
    expect(scored.map { it["right_distance"] }).to eq([ 200, 260, nil ])
    expect(scored.map { it["nearest_wrong_distance"] }).to eq([ 300, 250, nil ])
    md = described_class.markdown(scored)
    expect(md).to include("| Right artwork first | Group | All photos | Classed found |", "| overall | all | 1/3 (33.3%) | 1/1 (100.0%) |")
    expect(md).to include("| Right artwork in top 3 | Group | All photos | Classed found |", "| overall | all | 2/3 (66.7%) | 1/1 (100.0%) |")
    expect(md).to include("Text missed 2; of those art first 1; text top 3 or art first 2 of 3")
    expect(md).to include("| B.jpeg | Right | 3 | 1 |") # printings sharing the name vs sharing the artwork, for a card with no exact printing
  end

  it "reports the conventional median of the ranked distances, the mean of the two middle values for an even count" do
    md = described_class.markdown(described_class.score(records, data))
    expect(md).to include("median right 230, median nearest wrong 275, right nearer than every wrong 1 of 2")
  end
end
