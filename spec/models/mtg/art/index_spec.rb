require "rails_helper"

RSpec.describe MTG::Art::Index, :art_matching, type: :model do
  let(:a) { "aaaaaaaa-0000-4000-8000-000000000001" }
  let(:b) { "bbbbbbbb-0000-4000-8000-000000000002" }
  let(:records) { [ [ b, "\xFF".b * 128 ], [ a, "\x01".b * 128 ] ] }

  it "writes a compressed header and sorted 144-byte records, named by catalog version, digest and count (AC-3.9)", :aggregate_failures do
    path = described_class.write!("default-cards-1", records)

    expect(path.basename.to_s).to eq("art-index-default-cards-1-#{MTG::Art::Settings.digest}-2.bin.gz")
    expect(described_class.read(path)).to eq(magic: "CART", version: 1, digest: MTG::Art::Settings.digest, count: 2,
      records: [ [ a, "\x01".b * 128 ], [ b, "\xFF".b * 128 ] ])
    expect(Zlib.gunzip(path.binread).bytesize).to eq(28 + 2 * 144)
  end

  it "leaves no partial file and doesn't rewrite an index it already has", :aggregate_failures do
    path = described_class.write!("default-cards-1", records)
    written = path.mtime
    travel(1.minute) { described_class.write!("default-cards-1", records.reverse) }
    expect(path.mtime).to eq(written)
    expect(described_class.dir.glob("*.part")).to be_empty
  end

  it "keeps only the two newest, serves only those by name, and calls the newest current (AC-3.9, AC-4.2)", :aggregate_failures do
    old = described_class.write!("v1", records)
    FileUtils.touch(old, mtime: 3.minutes.ago.to_time)
    previous = described_class.write!("v2", records)
    FileUtils.touch(previous, mtime: 2.minutes.ago.to_time)
    newest = described_class.write!("v3", records)

    expect(described_class.files).to eq([ newest, previous ])
    expect(old).not_to exist
    expect(described_class.current).to eq(newest)
    expect(described_class.path_for(previous.basename.to_s)).to eq(previous)
    expect(described_class.path_for(old.basename.to_s)).to be_nil
    expect(described_class.path_for("../../config/master.key")).to be_nil
  end

  it "knows whether a catalog version has an index at the current settings" do
    described_class.write!("v1", records)
    expect([ described_class.built_for?("v1"), described_class.built_for?("v2") ]).to eq([ true, false ])
  end
end
