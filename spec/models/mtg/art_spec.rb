require "rails_helper"

RSpec.describe MTG::Art, type: :model do
  describe ".enabled_in?" do
    it "is on for 1, true, yes and on, in any case and with surrounding spaces (AC-1.2)" do
      values = [ "1", "true", "yes", "on", "TRUE", " On " ]
      expect(values.map { described_class.enabled_in?(described_class::ENV_NAME => it) }).to all(be(true))
    end

    it "is off when unset, empty or anything else (AC-1.1, AC-1.2)" do
      envs = [ {}, { described_class::ENV_NAME => "" }, { described_class::ENV_NAME => "0" }, { described_class::ENV_NAME => "enabled" } ]
      expect(envs.map { described_class.enabled_in?(it) }).to all(be(false))
    end
  end

  describe ".enabled?" do
    it "is off in tests unless an example turns it on" do
      expect(described_class).not_to be_enabled
    end

    it "reads the app's configuration", :art_matching do
      expect(described_class).to be_enabled
    end
  end

  it "keeps its files under the catalog download directory" do
    expect(described_class.root).to eq(Rails.root.join("tmp/catalog/mtg/art"))
  end
end
