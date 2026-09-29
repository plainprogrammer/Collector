require "rails_helper"

RSpec.describe Catalog::Entry, type: :model do
  describe ".named_like" do
    it "matches part of the name, ignoring ASCII case", :aggregate_failures do
      bolt = create(:catalog_entry, name: "Lightning Bolt")
      create(:catalog_entry, name: "Lightning Helix")

      expect(described_class.named_like("LIGHTNING bo")).to contain_exactly(bolt)
    end

    it "matches the localized name" do
      ja = create(:catalog_entry, name: "Lightning Bolt", localized_name: "稲妻", language: "ja")

      expect(described_class.named_like("稲妻")).to contain_exactly(ja)
    end

    it "treats % and _ literally" do
      create(:catalog_entry, name: "Fires of Yavimaya")

      expect(described_class.named_like("Fire_")).to be_empty
    end
  end

  describe ".searchable" do
    it "excludes retired entries and non-card kinds" do
      card = create(:catalog_entry)
      create(:catalog_entry, :retired)
      create(:catalog_entry, kind: "token")

      expect(described_class.searchable).to contain_exactly(card)
    end
  end

  describe ".in_set" do
    it "restricts to one set code and ignores a blank code", :aggregate_failures do
      a = create(:catalog_entry, set: create(:catalog_set, code: "aaa"))
      b = create(:catalog_entry, set: create(:catalog_set, code: "bbb"))

      expect(described_class.in_set("aaa")).to contain_exactly(a)
      expect(described_class.in_set("")).to contain_exactly(a, b)
    end
  end

  describe ".newest_first" do
    it "orders by release date, then set code, number and language" do
      old = create(:catalog_entry, released_on: Date.new(2001, 1, 1))
      new_b = create(:catalog_entry, released_on: Date.new(2020, 1, 1), set: create(:catalog_set, code: "bbb"))
      new_a = create(:catalog_entry, released_on: Date.new(2020, 1, 1), set: create(:catalog_set, code: "aaa"))

      expect(described_class.newest_first.to_a).to eq([ new_a, new_b, old ])
    end
  end

  it "is addressed by its external key" do
    expect(build(:catalog_entry, external_key: "abc-123").to_param).to eq("abc-123")
  end
end
