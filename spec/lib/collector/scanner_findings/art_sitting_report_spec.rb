require "rails_helper"

RSpec.describe Collector::ScannerFindings::ArtSittingReport, type: :model do
  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:entry) { create(:mtg_printing, entry: create(:catalog_entry, external_key: "right")).entry }

  after { FileUtils.rm_rf(dir) }

  def write_run(tier:, first:, ms: 30, captures: {}, second_capture: nil)
    dir.join("manifest.csv").write("file,set,number\nIMG_1.jpeg,#{entry.set.code},#{entry.number}\n")
    dir.join("truth.json").write(JSON.generate("photos" => [ { "file" => "IMG_1.jpeg", "external_key" => "right", "finish" => "nonfoil", "foil" => false,
      "name" => entry.name, "set_code" => entry.set.code, "collector_number" => entry.number } ]))
    run = Scanner::MeasurementRun.new(manifest: dir.join("manifest.csv"), dir: dir.join("run"))
    dir.join("run/IMG_1.jpeg").mkpath
    dir.join("run/IMG_1.jpeg/capture-001.json").write(JSON.generate("file" => "IMG_1.jpeg", "reading_key" => "k" * 32, "name_text" => entry.name,
      "collector_text" => "", "art_ms" => ms, "art_download_ms" => 244, "art_ready_ms" => 79, "ready_ms" => 900))
    dir.join("run/readings.jsonl").write(JSON.generate("reading_key" => "k" * 32, "tier" => tier, "candidates" => [ first ], "nearest" => 189,
      "second" => 341, "second_other_card" => true, "overruled" => nil, "overruled_scope" => nil, "art_status" => "matched") + "\n")
    if second_capture
      dir.join("run/IMG_1.jpeg/capture-002.json").write(JSON.generate("file" => "IMG_1.jpeg", "reading_key" => "m" * 32,
        "name_text" => entry.name, "collector_text" => "", "art_ms" => 41))
      dir.join("run/readings.jsonl").open("a") { it.write(JSON.generate("reading_key" => "m" * 32, "tier" => "art",
        "candidates" => [ second_capture ], "nearest" => 120, "second" => 400, "second_other_card" => true) + "\n") }
    end
    described_class.new(run:, account: create(:account), ground_truth: dir.join("truth.json"), captures:)
  end

  it "joins each card's reading to its capture and says whether the right card came first (AC-9.2, AC-9.3)", :aggregate_failures do
    report = write_run(tier: "art", first: "right")

    expect(report.rows.sole).to have_attributes(file: "IMG_1.jpeg", tier: "art", right_card_first: true, confident_wrong: false, nearest: 189)
    expect(report.to_markdown).to include("| IMG_1.jpeg |", "189", "341", "Art search per capture")
    expect(report.fixture).to include("format_version" => 1, "spec" => "011", "rows" => [ hash_including("file" => "IMG_1.jpeg", "tier" => "art") ])
  end

  it "names a confident art match on the wrong card (AC-9.4)" do
    other = create(:catalog_entry, external_key: "wrong")

    expect(write_run(tier: "art", first: other.external_key).rows.sole.confident_wrong).to be(true)
  end

  context "when a row is scored on another capture" do
    it "uses that capture's reading and says so in the table, the summary and the fixture", :aggregate_failures do
      other = create(:catalog_entry, external_key: "previous")
      report = write_run(tier: "art", first: other.external_key, second_capture: "right", captures: { "IMG_1.jpeg" => 2 })

      expect(report.rows.sole).to have_attributes(capture: 2, right_card_first: true, nearest: 120, art_ms: 41)
      expect(report.to_markdown).to include("| IMG_1.jpeg (capture 2) |", "Scored on another capture: IMG_1.jpeg (capture 2).")
      expect(report.fixture["rows"].sole).to include("capture" => 2)
    end

    it "keeps the first capture and no override line without overrides", :aggregate_failures do
      report = write_run(tier: "art", first: "right", second_capture: "right")

      expect(report.rows.sole).to have_attributes(capture: 1, nearest: 189)
      expect(report.to_markdown).not_to include("Scored on another capture")
    end

    it "refuses a file that isn't in the manifest" do
      expect { write_run(tier: "art", first: "right", captures: { "IMG_9.jpeg" => 2 }) }
        .to raise_error(ArgumentError, "Capture override for IMG_9.jpeg: no such file in the manifest.")
    end

    it "refuses a capture the row doesn't have" do
      expect { write_run(tier: "art", first: "right", captures: { "IMG_1.jpeg" => 2 }) }
        .to raise_error(ArgumentError, "Capture override for IMG_1.jpeg: no capture 2 (it has 1).")
    end
  end

  describe ".parse_captures" do
    it "reads file=number pairs", :aggregate_failures do
      expect(described_class.parse_captures("IMG_6835.jpeg=2, IMG_6836.jpeg=2")).to eq("IMG_6835.jpeg" => 2, "IMG_6836.jpeg" => 2)
      expect(described_class.parse_captures(nil)).to eq({})
    end

    it "refuses a pair without a capture number" do
      expect { described_class.parse_captures("IMG_6835.jpeg") }
        .to raise_error(ArgumentError, 'CAPTURES needs file=number pairs separated by commas, not "IMG_6835.jpeg".')
    end
  end
end
