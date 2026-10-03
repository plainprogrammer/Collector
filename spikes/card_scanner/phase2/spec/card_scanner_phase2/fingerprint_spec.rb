require_relative "../phase2_helper"
require "card_scanner_phase2/settings"
require "card_scanner_phase2/ppm"
require "card_scanner_phase2/fingerprint"

RSpec.describe CardScannerPhase2::Fingerprint do
  let(:settings) { CardScannerPhase2::Settings.load.fetch("fingerprint") }

  # A 100x140 image whose red channel rises left to right, green top to bottom, blue constant.
  let(:image) do
    data = +"".b
    140.times { |y| 100.times { |x| data << [ (x * 255) / 99, (y * 255) / 139, 128 ].pack("C*") } }
    CardScannerPhase2::Ppm::Image.new(100, 140, data)
  end

  it "resamples a box by area into the grid, keeping the gradient", :aggregate_failures do
    r, g, b = described_class.area_resample(image, 14.0, 22.4, 86.0, 70.0, 17, 16)
    expect(r.size).to eq(17 * 16)
    expect(r[0]).to be < r[16]
    expect(g[0]).to be < g[15 * 17]
    expect(b.uniq.map(&:round)).to eq([ 128 ])
  end

  it "hashes four planes into 128 bytes with neighbour comparisons", :aggregate_failures do
    hash = described_class.hash(image, settings, settings["offsets"].first)
    expect(hash.bytesize).to eq(128)
    red_plane = hash.byteslice(96, 32)
    expect(red_plane.unpack1("B*")).to eq("1" * 256) # red rises to the right, so every neighbour comparison is true
    blue_plane = hash.byteslice(32, 32)
    expect(blue_plane.unpack1("B*")).to eq("0" * 256) # blue is flat, so none is
  end

  it "computes six offset hashes, all distinct boxes", :aggregate_failures do
    boxes = settings["offsets"].map { described_class.box(100, 140, settings["box"], it) }
    expect(boxes.uniq.size).to eq(6)
    expect(described_class.hashes(image, settings).size).to eq(6)
  end

  it "measures Hamming distance", :aggregate_failures do
    a = ([ 0xFF ] * 128).pack("C*")
    b = ([ 0xFF ] * 127 + [ 0x0F ]).pack("C*")
    expect(described_class.hamming(a, a)).to eq(0)
    expect(described_class.hamming(a, b)).to eq(4)
  end
end
