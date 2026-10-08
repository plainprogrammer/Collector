require "rails_helper"

# Spec 011 Story 6: art evidence in MTG::Reading's ranking. Text-only rankings are spec 009's (reading_spec.rb, AC-6.8).
RSpec.describe MTG::Reading, type: :model do
  def art_id(key)
    { plains: "aaaaaaaa-0000-4000-8000-000000000001", shared: "bbbbbbbb-0000-4000-8000-000000000002",
      bolt: "cccccccc-0000-4000-8000-000000000003", helix: "dddddddd-0000-4000-8000-000000000004",
      unknown: "eeeeeeee-0000-4000-8000-000000000005" }.fetch(key)
  end

  # Plains M10 233 has an artwork of its own; Plains FDN 272 shares one (with MOM 277 in one context); Bolt MOM 123.
  let!(:cards) do
    sets = { m10: [ 2009, 7, 17 ], fdn: [ 2024, 11, 15 ], mom: [ 2023, 4, 21 ] }
      .to_h { |code, date| [ code, create(:catalog_set, code: code.to_s, released_on: Date.new(*date)) ] }
    { sets:, plains_m10: printing("Plains", sets[:m10], "233", :plains), plains_fdn: printing("Plains", sets[:fdn], "272", :shared),
      bolt: printing("Lightning Bolt", sets[:mom], "123", :bolt) }
  end

  before { Catalog::NameIndex.new("mtg").rebuild }

  def printing(name, set, number, art)
    identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
    entry = create(:catalog_entry, identity:, name:, set:, number:, released_on: set.released_on)
    create(:mtg_printing, entry:, illustration_id: art_id(art))
    MTG::Artwork.find_by(illustration_id: art_id(art)) || create(:mtg_artwork, illustration_id: art_id(art), entry:)
    entry
  end

  def read(name_text: "", collector_text: "", art: nil)
    artworks = art&.map { |key, distance| MTG::Art::Sent::Artwork.new(id: art_id(key), distance:) }
    described_class.new(name_text:, collector_text:, artworks:).resolve
  end

  it "ranks the confident artwork's card first, its only printing, overruling the name's printing (AC-6.3, AC-6.4, AC-6.7)", :aggregate_failures do
    reading = read(name_text: "Plains", art: { plains: 175 })

    expect(reading.candidates.first).to have_attributes(entry: cards[:plains_m10], evidence: %i[art name], art_unique: true, artwork_id: art_id(:plains))
    expect(reading).to have_attributes(tier: :art, overruled: :name, overruled_scope: :printing, art_status: :matched)
  end

  it "ranks confident art above a strong name for another card, which comes second (AC-6.3)", :aggregate_failures do
    reading = read(name_text: "Lightning Bolt", art: { plains: 120 })

    expect(reading.candidates.map(&:entry)).to eq([ cards[:plains_m10], cards[:bolt] ])
    expect(reading.candidates.second).to have_attributes(strong_name: true, evidence: %i[name])
    expect(reading).to have_attributes(overruled: :name, overruled_scope: :card)
  end

  it "ranks confident art above a collector-line match, and says the collector line was overruled (AC-6.3, AC-6.7)", :aggregate_failures do
    reading = read(collector_text: "R 0123\nMOM • EN", art: { plains: 120 })

    expect(reading.candidates.map(&:entry)).to eq([ cards[:plains_m10], cards[:bolt] ])
    expect(reading).to have_attributes(overruled: :collector_line, overruled_scope: :card)
  end

  it "adds the confident card even when no text was read (AC-6.3)", :aggregate_failures do
    reading = read(art: { plains: 120 })

    expect(reading).to be_nothing_read
    expect(reading.candidates.map(&:entry)).to eq([ cards[:plains_m10] ])
    expect(reading).to have_attributes(overruled: nil, art_status: :matched)
  end

  context "when several printings share the confident artwork (AC-6.4)" do
    let!(:plains_mom) { printing("Plains", cards[:sets][:mom], "277", :shared) }

    it "keeps the collector line's printing when it's one of them, with both kinds of evidence", :aggregate_failures do
      reading = read(name_text: "Plains", collector_text: "C 0272\nFDN • EN", art: { shared: 150 })

      expect(reading.candidates.first).to have_attributes(entry: cards[:plains_fdn], evidence: %i[collector_line name art], art_unique: false)
      expect(reading.candidates.first).to be_printing_confirmed
      expect(reading.overruled).to be_nil
    end

    it "takes the newest in the read set, else the newest, unconfirmed", :aggregate_failures do
      expect(read(name_text: "Plains", collector_text: "C 0999\nMOM • EN", art: { shared: 150 }).candidates.first.entry).to eq(plains_mom)
      newest = read(name_text: "Plains", art: { shared: 150 }).candidates.first
      expect(newest).to have_attributes(entry: cards[:plains_fdn], evidence: %i[art name])
      expect(newest).not_to be_printing_confirmed
    end

    it "doesn't keep a collector-line printing of the same card with another artwork (AC-6.4)", :aggregate_failures do
      reading = read(name_text: "Plains", collector_text: "C 0233\nM10 • EN", art: { shared: 150 })

      expect(reading.candidates.first).to have_attributes(entry: cards[:plains_fdn], evidence: %i[art name])
      expect(reading).to have_attributes(overruled: :collector_line, overruled_scope: :printing)
    end
  end

  it "uses weak art only to break a tie between name-only candidates, never changing a printing (AC-6.5)", :aggregate_failures do
    helix = printing("Lightning Helix", cards[:sets][:mom], "200", :helix)
    Catalog::NameIndex.new("mtg").rebuild
    text = read(name_text: "Lightning").candidates.map(&:entry)
    reading = read(name_text: "Lightning", art: { helix: 410 })

    expect(reading.candidates.map(&:entry)).to eq([ helix, *(text - [ helix ]) ])
    expect(reading.candidates.first).to have_attributes(evidence: %i[name art_weak], art_distance: 410)
    expect(reading).to have_attributes(tier: :art_weak, art_status: :similar, overruled: nil)
  end

  it "never lets weak art outrank a strong name or add a card (AC-6.5)", :aggregate_failures do
    reading = read(name_text: "Lightning Bolt", art: { plains: 400 })

    expect(reading.candidates.map(&:entry)).to eq([ cards[:bolt] ])
    expect(reading).to have_attributes(tier: :strong_name, art_status: :no_match)
  end

  it "gives weak art to another candidate's card even when one card is confident (glossary)" do
    reading = read(name_text: "Lightning Bolt", art: { plains: 120, bolt: 290 })

    expect(reading.candidates.map { [ it.entry, it.evidence ] }).to eq([ [ cards[:plains_m10], %i[art] ], [ cards[:bolt], %i[name art_weak] ] ])
  end

  it "ignores an artwork id it doesn't know, and ranks as spec 009 without artworks (AC-6.1, AC-6.8)", :aggregate_failures do
    unknown = read(name_text: "Lightning Bolt", art: { unknown: 10 })
    expect(unknown.candidates.map(&:entry)).to eq([ cards[:bolt] ])
    expect(unknown.art_status).to eq(:no_match)
    expect(read(name_text: "Lightning Bolt")).to have_attributes(art_status: nil, tier: :strong_name, overruled: nil)
  end

  it "keeps the margin beside the strong-name threshold" do
    expect(described_class::ART_MARGIN).to eq(300)
  end
end
