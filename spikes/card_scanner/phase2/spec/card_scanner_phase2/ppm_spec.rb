require_relative "../phase2_helper"
require "card_scanner_phase2/ppm"

RSpec.describe CardScannerPhase2::Ppm do
  it "parses a binary P6 image into width, height and RGB bytes", :aggregate_failures do
    image = described_class.parse("P6\n2 1\n255\n".b + [ 255, 0, 0, 0, 0, 255 ].pack("C*"))
    expect([ image.width, image.height ]).to eq([ 2, 1 ])
    expect(image.rgb(0, 0)).to eq([ 255, 0, 0 ])
    expect(image.rgb(1, 0)).to eq([ 0, 0, 255 ])
  end

  it "refuses anything but 8-bit P6" do
    expect { described_class.parse("P3\n1 1\n255\n0 0 0") }.to raise_error(ArgumentError, /P6/)
  end
end
