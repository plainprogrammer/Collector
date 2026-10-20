require "rails_helper"

RSpec.describe NumberEntry::SetChoice do
  let(:mh3) { create(:catalog_set, code: "mh3", name: "Modern Horizons 3", released_on: Date.new(2024, 6, 14)) }

  def entry(set:, language: "en", **attributes) = create(:catalog_entry, set:, language:, **attributes)

  describe ".offered" do
    it "offers sets with an active entry of any kind, newest first, undated last (AC-1.3)", :aggregate_failures do
      tokens = create(:catalog_set, code: "tmh3", name: "Modern Horizons 3 Tokens", released_on: Date.new(2023, 1, 1))
      retired = create(:catalog_set, code: "old", released_on: Date.new(2025, 1, 1))
      undated = create(:catalog_set, code: "nod", released_on: nil)
      entry(set: mh3)
      entry(set: tokens, kind: "token")
      entry(set: retired, retired_at: 1.day.ago)
      entry(set: undated)
      expect(described_class.offered.to_a).to eq([ mh3, tokens, undated ])
    end
  end

  describe "resolving the typed set (AC-1.4)" do
    before { entry(set: mh3) }

    it "takes the code in any case, the name in any case, or the offered label", :aggregate_failures do
      [ "MH3", "mh3", " mh3 ", "modern horizons 3", "Modern Horizons 3", "Modern Horizons 3 (MH3)" ].each do |text|
        expect(described_class.new(text:).set).to eq(mh3), text
      end
    end

    it "finds nothing for text that names no offered set", :aggregate_failures do
      choice = described_class.new(text: "zzz")
      expect(choice).to have_attributes(set: nil, asked?: true, chosen?: false)
      expect(choice.unmatched_message).to eq("No set matches “zzz”. Type a set code or choose a set from the list.")
    end

    it "asks nothing for empty text" do
      expect(described_class.new(text: "")).to have_attributes(set: nil, asked?: false, chosen?: false)
    end

    it "ignores a type or text that isn't a string (a forged parameter)" do
      expect(described_class.new(text: "mh3", type: { "a" => "b" }).set).to eq(mh3)
    end

    it "narrows to the type when one is given" do
      expect(described_class.new(text: "mh3", type: "other").set).to be_nil
    end

    it "finds the page's own link without loading the offered sets", :aggregate_failures do
      choice = described_class.new(text: "mh3", type: "mtg", language: "en")
      expect(choice.set).to eq(mh3)
      expect(choice.instance_variable_get(:@sets)).to be_nil
    end

    it "leaves a linked set whose entries are all retired unchosen" do
      retired = create(:catalog_set, code: "old")
      entry(set: retired, retired_at: 1.day.ago)
      expect(described_class.new(text: "old", type: "mtg")).to have_attributes(chosen?: false)
    end
  end

  describe "the language" do
    it "defaults to EN when the set has English entries (AC-1.5)", :aggregate_failures do
      entry(set: mh3)
      entry(set: mh3, language: "ja")
      choice = described_class.new(text: "mh3")
      expect(choice.languages.keys).to contain_exactly("en", "ja")
      expect(choice.language).to eq("en")
      expect(choice.to_params).to eq(type: "mtg", set: "mh3", language: "en")
    end

    it "defaults to the most common language without English, ties to the first code (AC-1.6)", :aggregate_failures do
      3.times { entry(set: mh3, language: "ja") }
      entry(set: mh3, language: "de")
      expect(described_class.new(text: "mh3").language).to eq("ja")
      entry(set: mh3, language: "de")
      entry(set: mh3, language: "de")
      expect(described_class.new(text: "mh3").language).to eq("de")
    end

    it "keeps a language the set has, and chooses nothing for one it lacks (AC-1.11)", :aggregate_failures do
      entry(set: mh3)
      entry(set: mh3, language: "ja")
      expect(described_class.new(text: "mh3", language: "ja")).to have_attributes(language: "ja", chosen?: true)
      lacking = described_class.new(text: "mh3", language: "fr")
      expect(lacking).to have_attributes(chosen?: false, asked?: true)
      expect(lacking.unmatched_message).to eq("No set matches “mh3”. Type a set code or choose a set from the list.")
    end
  end

  describe "#canonical?" do
    before { entry(set: mh3) }

    it "holds only for the type, the code and the language as the page links them", :aggregate_failures do
      choice = described_class.new(text: "mh3", type: "mtg", language: "en")
      expect(choice.canonical?(ActionController::Parameters.new(type: "mtg", set: "mh3", language: "en"))).to be(true)
      expect(choice.canonical?(ActionController::Parameters.new(set: "MH3"))).to be(false)
    end
  end

  it "labels a set as its name and code" do
    expect(described_class.new(text: "").label(mh3)).to eq("Modern Horizons 3 (MH3)")
  end
end
