require "rails_helper"

RSpec.describe MTG::Art::Fingerprint, type: :model do
  # A picture whose every channel rises (or falls) from left to right: each horizontal neighbour pair differs one way.
  def gradient(width, height, rising:)
    data = (0...height).flat_map { (0...width).flat_map { |x| [ rising ? x : 255 - x ] * 3 } }.pack("C*")
    MTG::Art::Decoder::Image.new(width, height, data)
  end

  it "sets every bit when brightness rises left to right, and none when it falls (ADR 0006)", :aggregate_failures do
    expect(described_class.of(gradient(200, 280, rising: true))).to eq("\xFF".b * 128)
    expect(described_class.of(gradient(200, 280, rising: false))).to eq("\x00".b * 128)
  end

  it "makes 128 bytes for every one of the six offsets" do
    image = gradient(146, 204, rising: true)
    expect(MTG::Art::Settings.fingerprint.fetch("offsets").map { described_class.of(image, it).bytesize }).to all(eq(128))
  end

  it "crops the art box of the card: x 14–86%, y 16–50%" do
    expect(described_class.box(1000, 1000, MTG::Art::Settings.fingerprint.fetch("box"), described_class::ZERO))
      .to eq([ 140.0, 160.0, 860.0, 500.0 ])
  end
end
