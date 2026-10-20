require "rails_helper"

RSpec.describe Collector::LibvipsCheck do
  describe "#hint" do
    it "is nil when the probe succeeds (AC-3.1)" do
      expect(described_class.new(probe: -> { true }).hint).to be_nil
    end

    it "names libvips and both packages when the probe fails, exits non-zero or can't run (AC-3.2)", :aggregate_failures do
      [ -> { false }, -> { nil }, -> { raise Errno::ENOENT, "bundle" } ].each do |probe|
        expect(described_class.new(probe: probe).hint).to include("libvips", "sudo dnf install vips", "sudo apt install libvips")
      end
    end

    it "finds libvips with the default probe where it's installed, as in development and CI (AC-3.4)" do
      expect(described_class.new.hint).to be_nil
    end
  end

  it "probes by loading ruby-vips in the bundle, not with a vips command (AC-3.4)" do
    expect(described_class::PROBE).to eq([ "bundle", "exec", "ruby", "-e", 'require "ruby-vips"' ])
  end

  it "is what bin/setup runs, beside the ImageMagick check (AC-3.5)", :aggregate_failures do
    setup = Rails.root.join("bin/setup").read
    expect(setup).to include('require_relative "../lib/collector/libvips_check"', "Collector::LibvipsCheck.new.hint")
    expect(setup.index("Checking libvips")).to be > setup.index("Checking ImageMagick")
  end
end
