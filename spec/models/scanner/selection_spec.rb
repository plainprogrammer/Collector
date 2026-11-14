require "rails_helper"

# Spec 088 decisions 2 to 4, 15: what the pane's row holds, in which band state, and how many printings load at once.
RSpec.describe Scanner::Selection, type: :model do
  let(:key) { "f" * 32 }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  def printing(code, number, identity: self.identity)
    set = Catalog::Set.find_by(code:) || create(:catalog_set, code:, name: code.upcase)
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: identity.name, set:, number:)).entry
  end

  def candidate(entry, evidence, strong_name: false, name_rank: 0, **rest)
    MTG::Reading::Candidate.new(entry:, evidence:, name_rank:, strong_name:, **rest)
  end

  def reading(*candidates, finish_hint: nil)
    instance_double(MTG::Reading, candidates:, finish_hint:, collector_line: Struct.new(:set_code, :number).new("mom", "123"))
  end

  describe ".state_of" do
    let(:entry) { printing("mom", "123") }

    it "names the band state of a candidate", :aggregate_failures do
      expect(described_class.state_of(candidate(entry, %i[collector_line]))).to eq(:collector_line)
      expect(described_class.state_of(candidate(entry, %i[name collector_line_corrected]))).to eq(:collector_line_corrected)
      expect(described_class.state_of(candidate(entry, %i[art], artwork_id: "a", art_unique: true))).to eq(:art)
      expect(described_class.state_of(candidate(entry, %i[art], artwork_id: "a", art_unique: false))).to eq(:guess)
      expect(described_class.state_of(candidate(entry, %i[name], strong_name: true))).to eq(:guess)
      expect(described_class.state_of(candidate(entry, %i[name]))).to eq(:unsure)
    end
  end

  describe ".for_reading when sure of the card" do
    subject(:selection) { described_class.for_reading(reading(candidate(matched, %i[collector_line])), key:) }

    let!(:matched) { printing("mom", "123") }
    let!(:others) { [ printing("m10", "146"), printing("2x2", "117") ] }


    it "holds the matched printing first, then the card's other printings, and counts them all", :aggregate_failures do
      expect(selection.kind).to eq(:printings)
      expect(selection.items.map(&:entry).first).to eq(matched)
      expect(selection.items.map(&:entry)).to contain_exactly(matched, *others)
      expect(selection.total).to eq(3)
      expect(selection.current).to eq(0)
      expect(selection.more).to eq(0)
    end

    it "gives the first item the evidence's band and rank 1, the others 'Not the printing that was read'", :aggregate_failures do
      expect(selection.items.first.band).to have_attributes(form: :success, icon: :check, sentence: "Matched by its collector line")
      expect(selection.items.first.rank).to eq(1)
      expect(selection.items.drop(1).map { it.band.sentence }.uniq).to eq([ "Not the printing that was read" ])
      expect(selection.items.drop(1).map(&:rank)).to all(be_nil)
    end

    it "does not hold the other candidate cards", :aggregate_failures do
      other_card = printing("m21", "1", identity: create(:catalog_identity, name: "Lightning Blast"))
      selection = described_class.for_reading(reading(candidate(matched, %i[name], strong_name: true), candidate(other_card, %i[name], name_rank: 1)), key:)
      expect(selection.items.map(&:entry)).not_to include(other_card)
      expect(selection.items.first.band.sentence).to eq("Printing not confirmed. Swipe to check.")
    end

    it "puts the read set first among the others (the Other printings order)" do
      selection = described_class.for_card(identity:, match: matched, state: "guess", key:, set: "2x2")
      expect(selection.items.map { it.entry.set.code }.first(2)).to eq(%w[mom 2x2])
    end
  end

  describe ".for_reading when not sure of the card" do
    it "holds the candidate cards, ranked, each with its own printing's state for 'All printings'", :aggregate_failures do
      first = printing("mom", "123")
      second = printing("m21", "1", identity: create(:catalog_identity, name: "Lightning Blast"))
      selection = described_class.for_reading(reading(candidate(first, %i[name]), candidate(second, %i[name], name_rank: 1)), key:)
      expect(selection.kind).to eq(:cards)
      expect(selection.items.map(&:entry)).to eq([ first, second ])
      expect(selection.items.map(&:rank)).to eq([ 1, 2 ])
      expect(selection.items.map { it.band.sentence }.uniq).to eq([ "Not sure of this card. Check it against your capture." ])
      expect(selection.items.map { it.band.icon }.uniq).to eq([ :question ])
      expect(selection.items.map(&:state)).to eq(%i[guess guess])
      expect(selection.total).to eq(2)
    end
  end

  describe ".for_card" do
    let!(:matched) { printing("mom", "123") }

    before { 24.times { |i| printing("s#{i}", i.to_s) } }

    it "shows 20 printings and a count of the rest, keeping the position's total", :aggregate_failures do
      selection = described_class.for_card(identity:, match: matched, state: "collector_line", key:)
      expect(selection.items.size).to eq(20)
      expect(selection.total).to eq(25)
      expect(selection.more).to eq(5)
      expect(selection.limit).to eq(20)
    end

    it "shows more at a raised limit, centred on the named printing, clamped to 20..200", :aggregate_failures do
      named = described_class.for_card(identity:, match: matched, state: "guess", key:).items.last.entry
      selection = described_class.for_card(identity:, match: matched, state: "guess", key:, limit: 40, current: named.external_key)
      expect(selection.items.size).to eq(25)
      expect(selection.more).to eq(0)
      expect(selection.current).to eq(19)
      expect(described_class.for_card(identity:, match: matched, state: "guess", key:, limit: 5).limit).to eq(20)
      expect(described_class.for_card(identity:, match: matched, state: "guess", key:, limit: 21).limit).to eq(40)
      expect(described_class.for_card(identity:, match: matched, state: "guess", key:, limit: [ "x" ]).limit).to eq(20)
      expect(described_class.for_card(identity:, match: matched, state: "guess", key:, limit: 9_999).limit).to eq(200)
    end

    it "ends the row at the cap with no more item, the position still counting every printing (decision 4)", :aggregate_failures do
      stub_const("Scanner::Selection::MAX", 20)
      selection = described_class.for_card(identity:, match: matched, state: "guess", key:, limit: 20)
      expect(selection.items.size).to eq(20)
      expect(selection.total).to eq(25)
      expect(selection.more).to eq(0)
      expect(selection.more?).to be(false)
      expect(selection.count).to eq(20)
    end

    it "treats a band state outside the closed list as a guess" do
      selection = described_class.for_card(identity:, match: matched, state: "<script>", key:)
      expect(selection.items.first.band.sentence).to eq("Printing not confirmed. Swipe to check.")
    end
  end
end
