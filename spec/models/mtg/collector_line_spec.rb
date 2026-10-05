require "rails_helper"

RSpec.describe MTG::CollectorLine do
  # AC-3.6: the known set codes are exactly these, so xyz and ffv are unknown.
  let(:known) { %w[neo dmu mom pmom cmm nec fin one sta] }
  let(:phase0) do
    JSON.parse(Rails.root.join("spec/fixtures/card_scanner/ocr_results.json").read)
      .fetch("results").to_h { [ it["file"], it["collector_text"] ] }
  end

  def parse(text) = described_class.parse(text, known_set_codes: known)

  describe "Phase 0's misses (AC-3.6)" do
    { "IMG_6723.jpeg" => %w[MOM 149], "IMG_6732.jpeg" => %w[CMM 697],
      "IMG_6711.jpeg" => %w[NEC 120], "IMG_6714.jpeg" => %w[FIN 258] }.each do |file, (set_code, number)|
      it "reads #{file}'s recorded text as #{set_code} #{number}" do
        expect(parse(phase0.fetch(file))).to have_attributes(set_code:, number:)
      end
    end

    it "uses the strings the spec quotes" do
      expect(phase0.fetch("IMG_6711.jpeg")).to eq("Vig 204\n—Shigeki, Jukar v1\n120 Ke\nNEC » EN do SAM BURLEY\n— eww")
    end

    it "doesn't read 'one' in flavour or rules text as the ONE set", :aggregate_failures do
      expect(parse(phase0.fetch("IMG_6728.jpeg")).set_code).to be_nil
      expect(parse(phase0.fetch("IMG_6736.jpeg")).set_code).to be_nil
    end

    it "reads the real ONE set in the SET • LANG shape" do
      expect(parse("R 0123\nONE • EN")).to have_attributes(set_code: "ONE", number: "123", language: "en")
    end
  end

  describe "WORD_SET_CODES (AC-3.7)" do
    it "lists one" do
      expect(described_class::WORD_SET_CODES).to include("one")
    end

    it "applies to the loose fallback only", :aggregate_failures do
      expect(parse("Add one mana of any color.").set_code).to be_nil
      expect(parse("0042 ONE • EN").set_code).to eq("ONE")
    end
  end

  describe "Phase 0's parser inputs (research.md §3)" do
    it "takes the number before the slash, not the set size", :aggregate_failures do
      expect(parse("051/302 NEO")).to have_attributes(set_code: "NEO", number: "51", format: :slash)
    end

    it "reads the M15–ONE two-line format" do
      expect(parse("051/302 R\nNEO • EN").to_h).to eq(set_code: "NEO", number: "51", language: "en", foil: false, format: :slash)
    end

    it "reads the foil star between set and language" do
      expect(parse("0123/0281 M\nDMU ★ EN").foil).to be(true)
    end

    it "reads the foil marker the stored foil captures show and no non-foil does (AC-6.5)" do
      expect(described_class.parse("R 0123\nMOM ® EN", known_set_codes: %w[mom]).foil).to be(true)
    end

    it "doesn't read an asterisk as a foil marker, which stored non-foil captures show too (AC-6.5)" do
      expect(described_class.parse("R 0123\nMOM * EN", known_set_codes: %w[mom]).foil).to be(false)
    end

    it "accepts a bullet misread as a guillemet" do
      expect(parse("051/302 R\nNEO « EN")).to have_attributes(language: "en", foil: false)
    end

    it "reads the MOM and later rarity-first format" do
      expect(parse("R 0123\nMOM • EN").to_h).to eq(set_code: "MOM", number: "123", language: "en", foil: false, format: :rarity_first)
    end

    it "keeps a promo suffix letter" do
      expect(parse("R 0045P\nPMOM • EN").number).to eq("45p")
    end

    it "repairs digit lookalikes in the number" do
      expect(parse("O5I/3O2 R\nNEO • EN").number).to eq("51")
    end

    it "repairs a zero read for the letter O in the set code" do
      expect(parse("051/302 R\nNE0 • EN").set_code).to eq("NEO")
    end

    it "rejects an unknown set code but keeps the number" do
      expect(parse("051/302 R\nXYZ • EN")).to have_attributes(set_code: nil, number: "51")
    end

    it "reads a pre-M15 number with no set code" do
      expect(parse("123/350")).to have_attributes(set_code: nil, number: "123")
    end

    it "returns empty fields for empty text" do
      expect(parse("").to_h.values).to all(be_nil)
    end
  end
end
