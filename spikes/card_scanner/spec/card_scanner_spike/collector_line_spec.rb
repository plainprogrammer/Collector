require_relative "../spike_helper"

RSpec.describe CardScannerSpike::CollectorLine do
  def parse(text) = described_class.parse(text, known_set_codes: %w[neo dmu mom pmom])

  it "takes the number before the slash, not the set size (AC-1.4)", :aggregate_failures do
    result = parse("051/302 NEO")
    expect(result.set_code).to eq("NEO")
    expect(result.number).to eq("51")
    expect(result.format).to eq(:slash)
  end

  it "reads the M15–ONE two-line format", :aggregate_failures do
    result = parse("051/302 R\nNEO • EN")
    expect(result.to_h).to eq(set_code: "NEO", number: "51", language: "en", foil: false, format: :slash)
  end

  it "reads the foil star between set and language" do
    expect(parse("0123/0281 M\nDMU ★ EN").foil).to be(true)
  end

  it "accepts a bullet misread as a guillemet", :aggregate_failures do
    result = parse("051/302 R\nNEO « EN")
    expect(result.language).to eq("en")
    expect(result.foil).to be(false)
  end

  it "reads the MOM and later rarity-first format", :aggregate_failures do
    result = parse("R 0123\nMOM • EN")
    expect(result.to_h).to eq(set_code: "MOM", number: "123", language: "en", foil: false, format: :rarity_first)
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

  it "rejects an unknown set code but keeps the number", :aggregate_failures do
    result = parse("051/302 R\nXYZ • EN")
    expect(result.set_code).to be_nil
    expect(result.number).to eq("51")
  end

  it "reads a pre-M15 number with no set code", :aggregate_failures do
    result = parse("123/350")
    expect(result.set_code).to be_nil
    expect(result.number).to eq("123")
  end

  it "returns empty fields for empty text" do
    expect(parse("").to_h.values).to all(be_nil)
  end
end
