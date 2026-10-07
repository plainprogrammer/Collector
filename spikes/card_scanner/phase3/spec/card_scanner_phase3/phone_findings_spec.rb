require_relative "../phase3_helper"
require "card_scanner_phase3/phone_findings"

RSpec.describe CardScannerPhase3::PhoneFindings do
  let(:phone) do
    { "mode" => "cold", "userAgent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) … Brave", "downloadMs" => 900.0, "readyMs" => 120.0,
      "index" => { "count" => 50_000, "decodedBytes" => 7_200_000, "encodedBodySize" => 5_900_000, "contentLength" => 5_900_000 },
      "search" => { "n" => 2, "medianMs" => 150.0, "slowestMs" => 210.0, "tops" => [ { "file" => "A", "top" => { "id" => "x" } }, { "file" => "B", "top" => { "id" => "y" } } ] },
      "responsive" => { "searches" => 100, "maxGapMs" => 400.0, "completed" => true },
      "fingerprint" => { "n" => 12, "medianMs" => 90.0, "slowestMs" => 130.0, "maxBits" => 0 },
      "memory" => { "decodedBytes" => 7_200_000, "wordsBytes" => 6_400_000, "ids" => 50_000, "idsBytes" => 3_600_000 } }
  end
  let(:desktop) { phone.merge("userAgent" => "Firefox", "search" => phone["search"].merge("tops" => [ { "file" => "A", "top" => { "id" => "x" } }, { "file" => "B", "top" => { "id" => "z" } } ])) }

  it "reports the phone's figures with slower-link arithmetic, and lists tops that differ from the desktop's (AC-2.3, AC-2.6)", :aggregate_failures do
    markdown = described_class.new(results: [ phone ], desktop:).to_markdown
    expect(markdown).to include("| cold | 5,900,000 | 7,200,000 | 900 | 120 | 150 | 210 | 90 | 130 | 0 | 400 | yes |")
    expect(markdown).to include("50 Mbit/s: 0.9 s", "10 Mbit/s: 4.7 s", "2 Mbit/s: 23.6 s", "arithmetic, not measured")
    expect(markdown).to include("Tops that differ from the desktop's: B (phone y, desktop z)")
    expect(markdown).to include("iPhone OS 18_7", "measured over the LAN")
    expect(markdown).to include("Memory held (cold): index 7,200,000 bytes, words 6,400,000 bytes, 50,000 ids in at most 3,600,000 bytes")
  end
end
