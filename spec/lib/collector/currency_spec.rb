require "rails_helper"

RSpec.describe Collector::Currency do
  it "knows USD and EUR", :aggregate_failures do
    expect(described_class.fetch!("usd").symbol).to eq("$")
    expect(described_class.fetch!("EUR").symbol).to eq("€")
  end

  it "rejects an unknown code, naming it" do
    expect { described_class.fetch!("XYZ") }.to raise_error(ArgumentError, /COLLECTOR_CURRENCY.*"XYZ"/)
  end

  it "names where an unknown code came from when it isn't the setting (spec 038)" do
    expect { described_class.fetch!("XYZ", setting: "accounts.currency") }.to raise_error(ArgumentError, /\Aaccounts\.currency "XYZ" is not supported/)
  end

  it "normalises a padded, lower-case code (spec 038 AC-3.5)" do
    expect(described_class.fetch!(" eur ")).to eq(described_class::Unit.new(code: "EUR", symbol: "€"))
  end

  it "sets the default a new account starts with at boot from the environment, defaulting to USD (spec 038 AC-3.2)" do
    expect(Rails.configuration.x.default_currency).to eq(described_class::Unit.new(code: "USD", symbol: "$"))
  end
end
