require "rails_helper"

RSpec.describe Collector::ScannerFindings::ArtSittingReport, type: :model do
  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:entry) { create(:mtg_printing, entry: create(:catalog_entry, external_key: "right")).entry }

  after { FileUtils.rm_rf(dir) }

  def write_run(tier:, first:, ms: 30)
    dir.join("manifest.csv").write("file,set,number\nIMG_1.jpeg,#{entry.set.code},#{entry.number}\n")
    dir.join("truth.json").write(JSON.generate("photos" => [ { "file" => "IMG_1.jpeg", "external_key" => "right", "finish" => "nonfoil", "foil" => false,
      "name" => entry.name, "set_code" => entry.set.code, "collector_number" => entry.number } ]))
    run = Scanner::MeasurementRun.new(manifest: dir.join("manifest.csv"), dir: dir.join("run"))
    dir.join("run/IMG_1.jpeg").mkpath
    dir.join("run/IMG_1.jpeg/capture-001.json").write(JSON.generate("file" => "IMG_1.jpeg", "reading_key" => "k" * 32, "name_text" => entry.name,
      "collector_text" => "", "art_ms" => ms, "art_download_ms" => 244, "art_ready_ms" => 79, "ready_ms" => 900))
    dir.join("run/readings.jsonl").write(JSON.generate("reading_key" => "k" * 32, "tier" => tier, "candidates" => [ first ], "nearest" => 189,
      "second" => 341, "second_other_card" => true, "overruled" => nil, "overruled_scope" => nil, "art_status" => "matched") + "\n")
    described_class.new(run:, account: create(:account), ground_truth: dir.join("truth.json"))
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
end
