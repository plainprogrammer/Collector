require "rails_helper"

RSpec.describe MTG::Art::Settings, type: :model do
  it "is the fingerprint frozen at 39cdc6e (spec 011 AC-8.1)" do
    frozen = JSON.parse(Rails.root.join("spikes/card_scanner/phase2/settings.json").read).fetch("fingerprint")
    expect(described_class.fingerprint).to eq(frozen)
  end

  it "has a stable 16-character digest, which the page gets with the settings", :aggregate_failures do
    expect(described_class.digest).to match(/\A[0-9a-f]{16}\z/)
    expect(described_class.digest).to eq(Digest::SHA256.hexdigest(JSON.generate(described_class.fingerprint))[0, 16])
    expect(described_class.for_page).to eq("digest" => described_class.digest, "fingerprint" => described_class.fingerprint)
  end
end
