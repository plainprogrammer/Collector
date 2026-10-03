require_relative "../phase2_helper"
require "card_scanner_phase2/settings"

RSpec.describe CardScannerPhase2::Settings do
  it "loads the committed settings with every section", :aggregate_failures do
    settings = described_class.load
    expect(settings.keys).to include("hand", "opencv", "warp", "fingerprint") # the freeze adds "frozen" and "chosen_detector"
    expect(settings.dig("fingerprint", "offsets").size).to eq(6)
    expect(settings.dig("warp", "width").to_f / settings.dig("warp", "height")).to be_within(0.002).of(63.0 / 88)
  end

  it "reports the commit that last changed the file" do
    expect(described_class.commit).to match(/\A\h{40}\z/)
  end
end
