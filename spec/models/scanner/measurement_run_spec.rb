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
end
