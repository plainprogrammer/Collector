require "rails_helper"

RSpec.describe Scanner::MeasurementRun, type: :model do
  let(:dir) { Pathname(Dir.mktmpdir("corpus")) }
  let(:run) { described_class.new(manifest: dir.join("manifest.csv"), dir: dir.join("runs/live")) }

  after { FileUtils.remove_entry(dir) }

  it "reads the Phase 0 manifest format" do
    dir.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\n")
    expect(run.rows).to eq([ described_class::Row.new(file: "IMG_1.jpeg", set: "mom", number: "123") ])
  end

  it "says what is wrong with a missing or malformed manifest", :aggregate_failures do
    expect { run.rows }.to raise_error(described_class::ManifestError, /No manifest at/)
    dir.join("manifest.csv").write("file,set\nIMG_1.jpeg,mom\n")
    expect { described_class.new(manifest: dir.join("manifest.csv"), dir:).rows }.to raise_error(described_class::ManifestError, /needs file, set and number/)
    dir.join("manifest.csv").write("file,set,number\n../x,mom,1\n")
    expect { described_class.new(manifest: dir.join("manifest.csv"), dir:).rows }.to raise_error(described_class::ManifestError, /Bad file name/)
  end

  it "is enabled only when configured", :aggregate_failures do
    expect(described_class).not_to be_enabled
    expect(described_class.current).to be_nil
  end

  it "finds a row's photo beside the manifest, or nil when it's missing (spec 007 photo replay)", :aggregate_failures do
    dir.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\nIMG_2.jpeg,neo,51,no\n")
    dir.join("IMG_1.jpeg").binwrite("\xFF\xD8\xFF".b)
    expect(run.photo_path(run.row("IMG_1.jpeg"))).to eq(dir.join("IMG_1.jpeg"))
    expect(run.photo_path(run.row("IMG_2.jpeg"))).to be_nil
  end

  describe "spec 009's capture fields and events (AC-9.2)" do
    let(:png) { -> { StringIO.new("\x89PNG\r\n\x1A\n".b) } }

    before { dir.join("manifest.csv").write("file,set,number,foil\nS001,mom,123,no\nS002,neo,51,yes\n") }

    def capture(file, key)
      run.record!(run.row(file), name_text: "Bolt", collector_text: "", ms: 200, user_agent: "iPhone", name_strip: png.call, collector_strip: png.call,
        extra: { "reading_key" => key, "outline" => "found", "detect_ms" => 180, "warp_ms" => 120, "art_ms" => 31,
          "art_download_ms" => 244, "art_ready_ms" => 79, "ready_ms" => 900, "other" => "dropped" })
    end

    it "stores the reading key, the outline, the detector's timings and the art timings (spec 011 AC-9.5) with a capture", :aggregate_failures do
      capture("S001", "a" * 32)
      expect(run.captures(run.row("S001")).sole).to include("reading_key" => "a" * 32, "outline" => "found", "detect_ms" => 180, "warp_ms" => 120,
        "art_ms" => 31, "art_download_ms" => 244, "art_ready_ms" => 79, "ready_ms" => 900)
      expect(run.captures(run.row("S001")).sole).not_to have_key("other")
    end

    it "finds a row by a capture's reading key and keeps its events in order", :aggregate_failures do
      capture("S002", "b" * 32)
      row = run.row_for_key("b" * 32)
      expect(row.file).to eq("S002")
      expect(run.row_for_key("c" * 32)).to be_nil
      run.record_event!(row, kind: "add", rank: "2", reading_key: "b" * 32)
      run.record_event!(row, kind: "undo", rank: nil, reading_key: "b" * 32)
      expect(run.events(row).map { it.slice("kind", "rank") }).to eq([ { "kind" => "add", "rank" => "2" }, { "kind" => "undo", "rank" => nil } ])
      expect(run.events(row).first["at"]).to match(/\A\d{4}-\d\d-\d\dT[\d:.]+Z\z/)
    end
  end

  describe "frames (spec 010 Story 3)" do
    let(:png) { ->(width = 4, height = 3) { StringIO.new("\x89PNG\r\n\x1A\n".b + [ 13 ].pack("N") + "IHDR" + [ width, height ].pack("NN") + "\x08\x06\x00\x00\x00".b) } }
    let(:guide) { { "x" => 1.5, "y" => 2.25, "width" => 10.0, "height" => 14.0 } }

    before { dir.join("manifest.csv").write("file,set,number,foil\nS001,mom,123,no\n") }

    def capture(frame:, guide: self.guide)
      run.record!(run.row("S001"), name_text: "Bolt", collector_text: "", ms: 200, user_agent: "iPhone", name_strip: png.call, collector_strip: png.call,
        frame:, guide:)
    end

    it "stores the frame beside the strips, with the guide rect and the frame's size (AC-3.1)", :aggregate_failures do
      capture(frame: png.call(1080, 1920))
      expect(dir.join("runs/live/S001/capture-001-frame.png")).to exist
      expect(run.captures(run.row("S001")).sole).to include("guide" => guide, "frame_width" => 1080, "frame_height" => 1920)
    end

    it "refuses the whole capture for a frame that isn't a PNG or is over the limit (AC-3.2)", :aggregate_failures do
      expect { capture(frame: StringIO.new("not a png")) }.to raise_error(described_class::InvalidCapture, /frame wasn't a PNG of at most 32 MB/)
      stub_const("Scanner::MeasurementRun::MAX_FRAME_BYTES", 20)
      expect { capture(frame: png.call) }.to raise_error(described_class::InvalidCapture)
      expect(dir.join("runs/live/S001")).not_to exist
    end

    it "refuses a frame without a whole guide rect" do
      expect { capture(frame: png.call, guide: { "x" => 1 }) }.to raise_error(described_class::InvalidCapture, /guide rect/)
    end

    it "stores no frame keys when no frame comes" do
      capture(frame: nil, guide: nil)
      expect(run.captures(run.row("S001")).sole.keys).not_to include("guide", "frame_width")
    end
  end

  it "keeps frames only when the measurement config says so (AC-3.1)", :aggregate_failures do
    expect(described_class).not_to be_keep_frames
    Rails.configuration.x.scanner_measurement = { manifest: "m", dir: "d", keep_frames: true }
    expect(described_class).to be_keep_frames
  ensure
    Rails.configuration.x.scanner_measurement = nil
  end

  describe "#record_reading! (spec 011 AC-9.3)" do
    it "appends what the ranking decided to a file for the whole run, keyed by the reading key", :aggregate_failures do
      reading = instance_double(MTG::Reading, artworks: [ MTG::Art::Sent::Artwork.new(id: "a" * 8 + "-0000-4000-8000-000000000001", distance: 189) ],
        tier: :art, overruled: :name, overruled_scope: :printing, art_status: :matched,
        candidates: [ MTG::Reading::Candidate.new(entry: build_stubbed(:catalog_entry, external_key: "p1"), evidence: %i[art], name_rank: nil, strong_name: false) ],
        art_usable: [ MTG::Art::Evidence::Usable.new(id: "x", distance: 189, identity_id: 1, printings: []),
                      MTG::Art::Evidence::Usable.new(id: "y", distance: 341, identity_id: 2, printings: []) ])

      run.record_reading!("f" * 32, reading)

      expect(run.readings).to match([ hash_including("reading_key" => "f" * 32, "tier" => "art", "overruled" => "name",
        "overruled_scope" => "printing", "art_status" => "matched", "candidates" => [ "p1" ], "nearest" => 189, "second" => 341,
        "second_other_card" => true, "artworks" => [ { "id" => "a" * 8 + "-0000-4000-8000-000000000001", "distance" => 189 } ]) ])
      expect(run.dir.join("readings.jsonl")).to exist
    end
  end
end
