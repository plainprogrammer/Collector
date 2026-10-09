require "rails_helper"

RSpec.describe MTG::Art::Decoder, type: :model do
  it "decodes a PNG to its exact pixels with ImageMagick (ADR 0012)", :aggregate_failures do
    path = Rails.root.join("tmp/decoder-spec.png")
    path.binwrite(png_bytes(3, 2) { |x, y| [ x * 10, y * 20, 255 - x ] })

    image = described_class.decode(path)

    expect([ image.width, image.height ]).to eq([ 3, 2 ])
    expect(image.rgb(2, 1)).to eq([ 20, 20, 253 ])
  ensure
    path&.delete if path&.exist?
  end

  it "parses binary 8-bit P6 and refuses anything else", :aggregate_failures do
    expect(described_class.parse("P6\n1 1\n255\n\x01\x02\x03".b).rgb(0, 0)).to eq([ 1, 2, 3 ])
    expect { described_class.parse("P3\n1 1\n255\n1 2 3") }.to raise_error(described_class::Error)
  end

  it "raises its own error for a file ImageMagick can't read" do
    path = Rails.root.join("tmp/decoder-spec.jpg")
    path.binwrite("not an image")
    expect { described_class.decode(path) }.to raise_error(described_class::Error)
  ensure
    path&.delete if path&.exist?
  end
end
