require "rails_helper"

# Spec 065 decision 1: the one object that says what a picker and the collection filter offer.
RSpec.describe Location::Choices, type: :model do
  let(:account) { create(:user).account }

  it "lists the places in comparison-key order and the decks with their zones in zone order", :aggregate_failures do
    create(:location, account:, name: "Zed box")
    create(:location, account:, name: "Alpha binder")
    beta = create(:deck, account:, name: "Beta deck")
    alpha = create(:deck, account:, name: "Alpha deck", format: "commander")
    choices = described_class.new(account)
    expect(choices.places.map(&:name)).to eq([ "Alpha binder", "Zed box" ])
    expect(choices.decks.map { it.location.name }).to eq([ "Alpha deck", "Beta deck" ])
    expect(choices.decks.first.zones.map(&:zone)).to eq(alpha.zones.map(&:zone))
    expect(choices.decks.last.zones.map(&:label)).to eq(beta.zones.map { "Beta deck › #{it.name}" })
  end

  it "reads the account's locations in one statement and sets each zone's parent from it", :aggregate_failures do
    create(:location, account:)
    create(:deck, account:)
    other = create(:user).account
    create(:deck, account: other)
    choices = described_class.new(account)
    queries = count_queries { choices.places; choices.decks; choices.any?; choices.decks.flat_map(&:zones).map(&:label) }
    expect(queries).to eq(1)
  end

  it "has nothing for an account with no location and for no account", :aggregate_failures do
    expect(described_class.new(account).any?).to be(false)
    expect(described_class.new(nil).any?).to be(false)
  end

  it "has something for a place alone and for a deck alone", :aggregate_failures do
    create(:location, account:)
    expect(described_class.new(account)).to be_any
    expect(described_class.new(account)).not_to be_decks
    other = create(:user).account
    create(:deck, account: other)
    expect(described_class.new(other)).to be_any
    expect(described_class.new(other)).to be_decks
  end

  it "finds a place or a zone by id, and never a deck's row, another account's location or a malformed id", :aggregate_failures do
    place = create(:location, account:)
    deck = create(:deck, account:)
    foreign = create(:deck, account: create(:user).account)
    choices = described_class.new(account)
    expect(choices.find(place.id)).to eq(place)
    expect(choices.find(deck.zone("main").id.to_s)).to eq(deck.zone("main"))
    expect([ deck.location_id, foreign.zone("main").id, "12abc", "012", "", nil ].map { choices.find(it) }).to all(be_nil)
  end

  it "finds a deck's group by its location's id only", :aggregate_failures do
    deck = create(:deck, account:)
    choices = described_class.new(account)
    expect(choices.deck(deck.location_id.to_s).location).to eq(deck.location)
    expect(choices.deck(deck.zone("main").id)).to be_nil
  end

  it "leaves out a place or a zone with except, for any?", :aggregate_failures do
    place = create(:location, account:)
    expect(described_class.new(account).any?(except: place.id)).to be(false)
    create(:deck, account:)
    expect(described_class.new(account).any?(except: place.id)).to be(true)
  end

  describe "#decks_of" do
    it "offers only the decks of the collectible type, with their zones", :aggregate_failures, :other_collecting do
      mine = create(:deck, account:, name: "Izzet Tempo")
      create(:deck, account:, name: "Elsewhere", pair: "other/standard")
      create(:deck, name: "Theirs") # another account's

      groups = described_class.new(account).decks_of("mtg")

      expect(groups.map { |group| group.location.name }).to eq([ "Izzet Tempo" ])
      expect(groups.first.zones.map(&:id)).to eq(mine.zones.map(&:id))
      expect(described_class.new(account).decks_of("other").map { |group| group.location.name }).to eq([ "Elsewhere" ])
    end

    it "is empty for an account with no deck of the type, one more statement than the choices' own", :aggregate_failures do
      choices = described_class.new(account)
      choices.decks

      expect(count_queries { choices.decks_of("mtg") }).to eq(1)
      expect(choices.decks_of("mtg")).to be_empty
    end
  end
end
