require_relative "../phase3_helper"
require "card_scanner_phase3/art_findings"

RSpec.describe CardScannerPhase3::ArtFindings do
  let(:truth) do
    { "IMG_6808.jpeg" => { "file" => "IMG_6808.jpeg", "name" => "Plains", "external_key" => "m10-233", "foil" => false, "set_code" => "m10", "collector_number" => "233" },
      "IMG_6821.jpeg" => { "file" => "IMG_6821.jpeg", "name" => "Pegasus Guardian", "external_key" => "clb-36", "foil" => true, "set_code" => "clb", "collector_number" => "36" } }
  end
  let(:entries) { { "m10-233" => "art-plains", "clb-36" => "art-pegasus" } }
  let(:owners) do
    { "art-plains" => { "names" => [ "Plains" ], "printings" => [ "m10-233" ] }, "art-other-plains" => { "names" => [ "Plains" ], "printings" => [ "woe-262" ] },
      "art-pegasus" => { "names" => [ "Pegasus Guardian" ], "printings" => [ "clb-36", "plst-clb-36" ] } }
  end
  let(:text) do
    { "IMG_6808.jpeg" => { "top3" => [ "Plains" ], "lookup" => { "status" => "none", "external_keys" => [] } },
      "IMG_6821.jpeg" => { "top3" => [ "Pegasus Guardian" ], "lookup" => { "status" => "one", "external_keys" => [ "clb-36" ] } } }
  end
  let(:results) do
    { "guide" => { "IMG_6808.jpeg" => { "top" => [ { "id" => "art-other-plains", "distance" => 210 }, { "id" => "art-plains", "distance" => 230 } ], "rightDistance" => 230 },
                   "IMG_6821.jpeg" => { "top" => [ { "id" => "art-pegasus", "distance" => 150 } ], "rightDistance" => 150 } },
      "detected" => { "IMG_6808.jpeg" => { "found" => false, "top" => [], "rightDistance" => nil },
                      "IMG_6821.jpeg" => { "found" => true, "top" => [ { "id" => "art-pegasus", "distance" => 120 } ], "rightDistance" => 120 } } }
  end

  # A method, not a let: the group already has five memoised helpers (RSpec/MultipleMemoizedHelpers).
  def findings(**changes) = described_class.new(results:, truth:, entries:, owners:, text:, **changes)

  it "scores right artwork first, right card first by art and the top 3 per path (AC-4.4)", :aggregate_failures do
    plains, pegasus = findings.scored("guide").values_at(0, 1)
    expect(plains).to include("art_first" => false, "card_first" => true, "art_top3" => true, "right_distance" => 230, "nearest_wrong" => 210)
    expect(pegasus).to include("art_first" => true, "card_first" => true, "unique_printing" => false)
    expect(findings.rates("guide")["all"]).to include("art_first" => "1/2 (50.0%)", "card_first" => "2/2 (100.0%)")
  end

  it "counts a missing outline as a miss on the detected path (AC-4.2)" do
    expect(findings.rates("detected")["all"]["art_first"]).to eq("1/2 (50.0%)")
  end

  it "compares with the text: text or art, and the printings the text missed (AC-4.5)", :aggregate_failures do
    expect(findings.comparison("guide")).to include("text_top3" => "2/2 (100.0%)", "text_or_art" => "2/2 (100.0%)", "printing_missed" => 1)
    expect(findings.comparison("guide")["art_names_printing"]).to eq(0)
  end

  it "names spec 009's misses with their distances and whether the artwork is unique to the printing (AC-4.6)" do
    expect(findings.to_markdown).to include("| IMG_6808.jpeg | Plains (M10 · 233) | guide: card first, right 230, nearest wrong 210, unique to its printing | detected: no outline |")
  end

  it "renders the named table as one table, rows separated by single newlines (AC-4.6)" do
    expect(findings.to_markdown).to include("| File | Card | guide | detected |\n|---|---|---|---|\n| IMG_6808.jpeg | Plains")
  end

  it "renders the same-capture comparison as prose (AC-4.5)" do
    same = { "IMG_6808.jpeg" => text["IMG_6808.jpeg"], "IMG_6821.jpeg" => { "top3" => [], "lookup" => { "status" => "none" } } }
    expect(findings(same_capture_text: same).to_markdown)
      .to include("Same-capture text: text top 3 1/2 (50.0%); text or art 2/2 (100.0%); printings the text missed 2, of which art names the printing 0.")
  end

  it "keeps the same-capture comparison per path in the fixture hash (AC-4.5)", :aggregate_failures do
    same = { "IMG_6808.jpeg" => text["IMG_6808.jpeg"], "IMG_6821.jpeg" => { "top3" => [], "lookup" => { "status" => "none" } } }
    expect(findings(same_capture_text: same).to_h.dig("paths", "guide", "same_capture_comparison")).to include("text_top3" => "1/2 (50.0%)", "printing_missed" => 2)
    expect(findings.to_h.dig("paths", "guide")).not_to have_key("same_capture_comparison")
  end

  it "leaves a card without an artwork id out of the rates, and lists it (Error Scenarios)", :aggregate_failures do
    lost = { "file" => "IMG_6899.jpeg", "name" => "Lost Card", "external_key" => "no-art", "foil" => false, "set_code" => "xyz", "collector_number" => "1" }
    without = findings(truth: truth.merge("IMG_6899.jpeg" => lost))
    expect(without.rates("guide")["all"]["art_first"]).to eq("1/2 (50.0%)")
    expect(without.comparison("guide")["text_top3"]).to eq("2/2 (100.0%)")
    expect(without.to_markdown).to include("Left out (no artwork id): IMG_6899.jpeg Lost Card")
  end

  it "notes a right artwork missing from the index (Error Scenarios)" do
    missing = results.merge("detected" => results["detected"].merge("IMG_6821.jpeg" => { "found" => true, "top" => [ { "id" => "art-x", "distance" => 300 } ], "rightDistance" => nil }))
    expect(findings(results: missing).to_markdown).to include("| IMG_6821.jpeg | Pegasus Guardian | art-x | — | 300 | missing image |")
  end
end
