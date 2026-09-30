require "rails_helper"

RSpec.describe Collector::Currency do
  it "knows USD and EUR", :aggregate_failures do
    expect(described_class.fetch!("usd").symbol).to eq("$")
    expect(described_class.fetch!("EUR").symbol).to eq("€")
  end

  it "rejects an unknown code, naming it" do
    expect { described_class.fetch!("XYZ") }.to raise_error(ArgumentError, /COLLECTOR_CURRENCY.*"XYZ"/)
  end

  it "is configured at boot from the environment, defaulting to USD" do
    expect(Rails.configuration.x.currency).to eq(described_class::Unit.new(code: "USD", symbol: "$"))
  end
end
