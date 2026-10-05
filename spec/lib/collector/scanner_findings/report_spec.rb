require "rails_helper"

RSpec.describe Collector::ScannerFindings::Report do
  let(:dir) { Pathname(Dir.mktmpdir("findings")) }
  let(:run) { Scanner::MeasurementRun.new(manifest: dir.join("manifest.csv"), dir: dir.join("run")) }
  let(:report) { described_class.new(run:, output: dir) }
  let(:name_text) { "Nothing useful" }

  before do
    dir.join("manifest.csv").write("file,set,number,foil\nIMG_6688.jpeg,fra,391,no\nIMG_6689.jpeg,afc,1,yes\n")
    strip = -> { StringIO.new("\x89PNG\r\n\x1A\n".b) }
    run.record!(run.row("IMG_6688.jpeg"), name_text:, collector_text: "", ms: 640, user_agent: "iPhone", name_strip: strip.call, collector_strip: strip.call)
    run.skip!(run.row("IMG_6689.jpeg"))
  end

  after { FileUtils.remove_entry(dir) }

  it "reports every rate for Phase 0, Phase 0's text with Phase 1's matcher, and the live run (AC-6.2, AC-6.3)", :aggregate_failures do
    markdown = report.to_markdown
    expect(markdown).to include("| Top 3, name only | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 live |")
    expect(markdown).to include("| Top 3, final ranking | Group | Phase 0 text, Phase 1 matcher | Phase 1 live |")
    expect(markdown).to include("| overall | all | 26/50 (52.0%) |", "Exact printing (M15–ONE, MOM+)")
  end

  it "lists misses, timings, skipped rows and retakes (AC-6.4, AC-6.5)", :aggregate_failures do
    expect(report.to_markdown).to include("| IMG_6688.jpeg |", "median 640 ms", "skipped: IMG_6689.jpeg", "retakes: 0")
  end

  it "writes the live run as text-only fixtures (AC-6.6)", :aggregate_failures do
    report.write_fixtures!
    results = JSON.parse(dir.join("phase1_ocr_results.json").read)
    expect(results).to include("format_version" => 2, "run" => "Phase 1 live")
    expect(results["results"].sole.keys).to contain_exactly("file", "name_text", "collector_text", "ms", "user_agent", "captured_at", "parsed", "lookup")
    expect(JSON.parse(dir.join("phase1_name_matches.json").read)["matches"].sole.keys).to include("name_candidates", "final_candidates")
  end

  context "when the OCR text arrives with CRLF line endings (multipart form posts)" do
    let(:name_text) { "Nothing\r\nuseful" }

    it "keeps each miss on a single table row", :aggregate_failures do
      markdown = report.to_markdown
      expect(markdown.lines).to include(a_string_starting_with("| IMG_6688.jpeg |").and(including("Nothing useful")))
      expect(markdown).not_to include("\r")
    end

    it "ignores replays that differ from the device's text only in line endings" do
      run.record_replay!("desktop-a", [ { "file" => "IMG_6688.jpeg", "name_text" => "Nothing\nuseful", "collector_text" => "" } ])
      expect(report.to_markdown).to include("Replay desktop-a: 0 of 1 captures differ")
    end

    it "still reports a replay whose text differs, with normalised line endings", :aggregate_failures do
      run.record_replay!("desktop-a", [ { "file" => "IMG_6688.jpeg", "name_text" => "Nothing\nelse", "collector_text" => "" } ])
      markdown = report.to_markdown
      expect(markdown).to include("Replay desktop-a: 1 of 1 captures differ")
      expect(markdown).to include(%(- IMG_6688.jpeg name_text: "Nothing\\nuseful" on the device, "Nothing\\nelse" replayed))
    end
  end

  context "when the run is named (the photo replay, a tuning round)" do
    let(:report) { described_class.new(run:, output: dir, label: "Phase 1 photo replay", prefix: "phase1_photos") }

    it "names the run's column and its misses after the label", :aggregate_failures do
      markdown = report.to_markdown
      expect(markdown).to include("| Top 3, name only | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 photo replay |")
      expect(markdown).to include("Not in the top 3 (Phase 1 photo replay, final ranking)")
      expect(markdown).not_to include("Phase 1 live")
    end

    it "writes its fixtures under the prefix, with the label as the run", :aggregate_failures do
      report.write_fixtures!
      expect(JSON.parse(dir.join("phase1_photos_ocr_results.json").read)).to include("run" => "Phase 1 photo replay")
      expect(JSON.parse(dir.join("phase1_photos_name_matches.json").read)).to include("run" => "Phase 1 photo replay")
      expect(dir.join("phase1_ocr_results.json")).not_to exist
    end
  end

  it "writes format version 3 with the outline and the detector's timings (spec 009 AC-9.4)" do
    described_class.new(run:, output: dir, format_version: 3).write_fixtures!
    expect(JSON.parse(dir.join("phase1_ocr_results.json").read)).to include("format_version" => 3)
  end
end
