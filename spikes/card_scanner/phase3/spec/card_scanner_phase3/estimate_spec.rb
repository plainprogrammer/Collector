require_relative "../phase3_helper"
require "card_scanner_phase3/estimate"

RSpec.describe CardScannerPhase3::Estimate do
  let(:artworks) do
    { "a" => { "small" => "u1" }, "b" => { "small" => "u2" }, "c" => { "small" => nil }, "d" => { "small" => "u4" } }
  end

  it "estimates the uncached fetchable artworks from spec 008's measured cost per image (AC-1.2)", :aggregate_failures do
    estimate = described_class.call(artworks, cached: ->(id) { id == "a" }, measured: { "images" => 10, "bytes" => 1_000, "seconds" => 36.0 })
    expect(estimate).to include("artworks" => 4, "with_image_url" => 3, "cached" => 1, "to_fetch" => 2, "bytes" => 200, "hours" => 0.002)
    expect(estimate["per_image"]).to eq("bytes" => 100.0, "seconds" => 3.6)
    expect(estimate["basis"]).to include("10 images")
  end
end
