require "rails_helper"

RSpec.describe CollectionFilter::Place, type: :model do
  describe ".parse (spec 037 decision 1)" do
    it "keeps the canonical values", :aggregate_failures do
      expect(described_class.parse("")).to eq("")
      expect(described_class.parse("none")).to eq("none")
      expect(described_class.parse("17")).to eq("17")
      expect(described_class.parse("9" * 18)).to eq("9" * 18)
    end

    it "reads anything else as all" do
      values = [ nil, "017", " 17", "17 ", "17abc", "0", "-3", "NONE", "1" * 19, [ "1" ], { "a" => "1" }, 17 ]
      expect(values.map { described_class.parse(it) }).to all(eq(""))
    end
  end

  describe ".apply" do
    let(:account) { create(:user).account }
    let(:blue) { create(:location, account:) }

    def apply(place) = described_class.apply(account.lots, place)

    it "narrows the scope to the place", :aggregate_failures do
      in_blue = create(:lot, account:, location: blue)
      in_box = create(:lot, account:, location: create(:location, account:))
      unplaced = create(:lot, account:)
      expect(apply("")).to contain_exactly(in_blue, in_box, unplaced)
      expect(apply("none")).to contain_exactly(unplaced)
      expect(apply(blue.id.to_s)).to contain_exactly(in_blue)
    end

    it "matches no lot for a foreign, removed or unknown id", :aggregate_failures do
      create(:lot, account:, location: blue)
      foreign = create(:location)
      create(:lot, account: foreign.account, location: foreign)
      gone = create(:location, account:).tap(&:destroy!)
      expect(apply(foreign.id.to_s)).to be_empty
      expect(apply(gone.id.to_s)).to be_empty
      expect(apply("999999999")).to be_empty
    end
  end
end
