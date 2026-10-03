require_relative "../phase2_helper"
require "card_scanner_phase2/art_index"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::ArtIndex do
  let(:ids) { %w[00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000002] }
  let(:hashes) { [ ("\x00" * 128).b, ("\xFF" * 128).b ] }
  let(:dir) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(dir) }

  it "writes and reads back fixed-size records of uuid plus hash", :aggregate_failures do
    described_class.write!(dir, ids, hashes, meta: { "image_size" => "small" })
    index = described_class.read(dir)
    expect(dir.join("art_index.bin").size).to eq(2 * 144)
    expect(index.size).to eq(2)
    expect(index.ids).to eq(ids)
    expect(index.meta).to include("image_size" => "small", "count" => 2)
  end

  it "ranks by the smallest distance over the query's offsets" do
    described_class.write!(dir, ids, hashes, meta: {})
    index = described_class.read(dir)
    query = [ ("\xFF" * 127 + "\x0F").b, ("\x00" * 127 + "\x0F").b ]
    ranked = index.search(query, limit: 2)
    expect(ranked).to eq([ { "id" => ids[0], "distance" => 4 }, { "id" => ids[1], "distance" => 4 } ])
  end
end
