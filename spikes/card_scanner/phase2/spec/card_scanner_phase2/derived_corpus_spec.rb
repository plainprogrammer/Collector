require_relative "../phase2_helper"
require "card_scanner_phase2/derived_corpus"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::DerivedCorpus do
  let(:phase0) { "file,set,number,foil\nIMG_6718.jpeg,mat,71,no\nIMG_6690.jpeg,aaa,2,yes\n" }
  let(:new) { "file,set,number,foil,era\nIMG_6763.jpeg,mat,71,no,pre-M15\nIMG_6756.jpeg,iko,235,no,\n" }
  let(:texts) { { "phase0" => phase0, "new" => new } }
  let(:run) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(run) }

  def detection(file, corpus, found)
    stem = File.basename(file, ".*")
    run.join(stem).mkpath
    run.join(stem, "picture.png").binwrite("\x89PNG".b) if found
    run.join(stem, "detect.json").write({ "file" => file, "corpus" => corpus, "found" => found }.to_json)
  end

  it "adds an era column that overrides only the shared card's Phase 0 photo", :aggregate_failures do
    expect(described_class.manifest_with_era("phase0", texts:)).to eq("file,set,number,foil,era\nIMG_6718.jpeg,mat,71,no,pre-M15\nIMG_6690.jpeg,aaa,2,yes,\n")
    expect(described_class.manifest_with_era("new", texts:)).to eq(new)
  end

  it "writes a derived manifest of the found photos with png names, and copies their pictures", :aggregate_failures do
    detection("IMG_6718.jpeg", "phase0", true)
    detection("IMG_6690.jpeg", "phase0", false)
    detection("IMG_6756.jpeg", "new", true)
    written = described_class.write!(run, texts:)
    expect(written.join("manifest.csv").read).to eq("file,set,number,foil,era\nIMG_6718.png,mat,71,no,pre-M15\nIMG_6756.png,iko,235,no,\n")
    expect(written.join("IMG_6718.png").binread).to eq("\x89PNG".b)
    expect(written.join("IMG_6690.png")).not_to exist
    expect(described_class.not_found(run)).to eq([ { "file" => "IMG_6690.jpeg", "corpus" => "phase0" } ])
  end
end
