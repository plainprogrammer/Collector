require "rails_helper"

RSpec.describe Collector::TrustedProxies do
  it "adds the configured proxies to Rails' private and loopback defaults", :aggregate_failures do
    proxies = described_class.parse(" 203.0.113.0/24, ,198.51.100.4 ")
    expect(proxies).to include(IPAddr.new("203.0.113.0/24"), IPAddr.new("198.51.100.4"))
    expect(proxies).to include(*ActionDispatch::RemoteIp::TRUSTED_PROXIES)
  end

  it "keeps the defaults when nothing is configured" do
    expect(described_class.parse(nil)).to eq(ActionDispatch::RemoteIp::TRUSTED_PROXIES)
  end
end
