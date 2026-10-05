require "rails_helper"

RSpec.describe MTG::Reading, type: :model do
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine", released_on: Date.new(2023, 4, 21)) }
  let(:stx) { create(:catalog_set, code: "stx", name: "Strixhaven", released_on: Date.new(2021, 4, 23)) }
  let!(:bolt) { printing("Lightning Bolt", set: mom, number: "123") }

  before do
    printing("Lightning Helix", set: mom, number: "200")
    Catalog::NameIndex.new("mtg").rebuild
  end

  def printing(name, set:, number:, language: "en", finishes: %w[nonfoil foil])
    identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
    create(:mtg_printing, finishes:, entry: create(:catalog_entry, identity:, name:, set:, number:, language:)).entry
  end

  def read(name_text: "", collector_text: "") = described_class.new(name_text:, collector_text:).resolve

  it "puts the printing the collector line identifies first, once, matched by both (AC-3.2, AC-5.1)", :aggregate_failures do
    reading = read(name_text: "Lightning Bolt", collector_text: "R 0123\nMOM • EN")
    expect(reading.collector_status).to eq(:one)
    expect(reading.candidates.first).to have_attributes(entry: bolt, evidence: %i[collector_line name], strong_name: true)
    expect(reading.candidates.count { it.entry.catalog_identity_id == bolt.catalog_identity_id }).to eq(1)
  end

  it "uses English when the collector line names no language" do
    expect(read(collector_text: "M0123\nMOM").collector_status).to eq(:one)
  end

  it "reports several printings and falls back to the name (AC-3.3)", :aggregate_failures do
    printing("Lightning Bolt", set: mom, number: "123")
    reading = read(name_text: "Lightning Bolt", collector_text: "R 0123\nMOM • EN")
    expect(reading.collector_status).to eq(:several)
    expect(reading.candidates.map(&:evidence)).to all(eq(%i[name]))
  end

  it "reports no printing, or a line it couldn't read", :aggregate_failures do
    expect(read(collector_text: "R 0999\nMOM • EN").collector_status).to eq(:none)
    expect(read(collector_text: "").collector_status).to eq(:unread)
  end

  it "shows a name candidate's printing in the parsed set, else its newest English printing", :aggregate_failures do
    newer = printing("Lightning Bolt", set: create(:catalog_set, code: "m25", released_on: Date.new(2025, 1, 1)), number: "1")
    expect(read(name_text: "Lightning Bolt", collector_text: "R 0999\nMOM • EN").candidates.first.entry).to eq(bolt)
    expect(read(name_text: "Lightning Bolt").candidates.first.entry).to eq(newer)
  end

  it "lists at most three candidates" do
    %w[Lightning\ Axe Lightning\ Storm Lightning\ Strike].each_with_index { |name, i| printing(name, set: mom, number: (300 + i).to_s) }
    Catalog::NameIndex.new("mtg").rebuild
    expect(read(name_text: "Lightning").candidates.size).to eq(3)
  end

  it "knows when nothing was read, when the catalog isn't ready, and when text is too long", :aggregate_failures do
    expect(read).to be_nothing_read
    Catalog::Name.delete_all
    expect(read(name_text: "Lightning Bolt")).not_to be_catalog_ready
    expect(described_class.new(name_text: "a" * 2_001)).not_to be_valid
  end

  context "when the name and the collector line point to different cards (spec 009 Story 5)" do
    let!(:tome) { printing("Tome Shredder", set: stx, number: "117") }
    let!(:spellbinder) { printing("Elite Spellbinder", set: stx, number: "17") }

    before { Catalog::NameIndex.new("mtg").rebuild }

    it "ranks a strong name match first, corrected by one digit, and the collector-line printing second (AC-5.1, AC-5.3)", :aggregate_failures do
      candidates = read(name_text: "Tome Shredder", collector_text: "R 0017\nSTX • EN").candidates
      expect(candidates.first).to have_attributes(entry: tome, evidence: %i[name collector_line_corrected], strong_name: true)
      expect(candidates.second).to have_attributes(entry: spellbinder, evidence: include(:collector_line))
    end

    it "keeps the collector-line printing first when the name match isn't strong, without a correction (AC-5.2)", :aggregate_failures do
      candidates = read(name_text: "Tome Shredder", collector_text: "R 0017\nSTX • EN").ranked(1.01)
      expect(candidates.first).to have_attributes(entry: spellbinder, evidence: include(:collector_line))
      expect(candidates.second).to have_attributes(entry: tome, evidence: %i[name])
    end

    it "corrects a number that matched no printing to the named card's one printing a digit away (AC-5.3)" do
      expect(read(name_text: "Tome Shredder", collector_text: "R 0118\nSTX • EN").candidates.first)
        .to have_attributes(entry: tome, evidence: %i[name collector_line_corrected])
    end

    it "doesn't correct when two printings are a digit away, or the letters differ (AC-5.3)", :aggregate_failures do
      printing("Tome Shredder", set: stx, number: "119")
      expect(read(name_text: "Tome Shredder", collector_text: "R 0118\nSTX • EN").candidates.first).not_to be_corrected
      tome.update!(number: "117a")
      expect(read(name_text: "Tome Shredder", collector_text: "R 0017\nSTX • EN").candidates.first).not_to be_corrected
    end
  end

  describe "#finish_hint (spec 009 AC-6.5)" do
    it "suggests foil only when the separator reads as the foil marker", :aggregate_failures do
      expect(read(collector_text: "R 0123\nMOM ★ EN").finish_hint).to eq("foil")
      expect(read(collector_text: "R 0123\nMOM • EN").finish_hint).to be_nil
      expect(read(collector_text: "").finish_hint).to be_nil
    end
  end

  describe "the ranking rule (AC-5.5)" do
    it "orders by a strong name, then collector-line evidence, then name rank" do
      kinds = [ [ %i[name], 1, false ], [ %i[collector_line], nil, false ], [ %i[name], 0, true ], [ %i[name collector_line_corrected], 2, false ] ]
      candidates = kinds.map { |evidence, name_rank, strong_name| described_class::Candidate.new(entry: bolt, evidence:, name_rank:, strong_name:) }
      expect(candidates.sort_by(&:rank_key).map { [ it.evidence, it.name_rank ] })
        .to eq([ [ %i[name], 0 ], [ %i[name collector_line_corrected], 2 ], [ %i[collector_line], nil ], [ %i[name], 1 ] ])
    end
  end
end
