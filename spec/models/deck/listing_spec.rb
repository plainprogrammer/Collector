require "rails_helper"

# Spec 062: the Decks page's rows, in a bounded number of statements.
RSpec.describe Deck::Listing, type: :model do
  let(:account) { create(:user).account }

  it "lists the account's decks by comparison key, with the copies in every zone (Considering included)", :aggregate_failures do
    zebra = create(:deck, account:, name: "zebra")
    apple = create(:deck, account:, name: "Apple")
    mid = create(:deck, account:, name: "Mid")
    create_lot_in_zone(apple, "main", quantity: 4)
    create_lot_in_zone(apple, "sideboard", quantity: 3)
    create_lot_in_zone(apple, "considering", quantity: 2)
    create_lot_in_zone(zebra, "main", quantity: 1)
    create(:lot, account:, location: create(:location, account:), quantity: 50)
    create(:lot, account:, quantity: 70)

    rows = described_class.new(account).rows

    expect(rows.map(&:deck)).to eq([ apple, mid, zebra ])
    expect(rows.map(&:cards)).to eq([ 9, 0, 1 ])
    expect(rows.first.deck.association(:location)).to be_loaded
    expect(described_class.new(account).count).to eq(3)
  end

  it "adds the proxies of every zone to a deck's cards and lists owned and proxy apart (AC-5.1)", :aggregate_failures do
    deck = create(:deck, account:, name: "Alpha")
    create_lot_in_zone(deck, "main", quantity: 3)
    create(:deck_proxy, zone: deck.zone("sideboard"), account:, quantity: 4)
    create(:deck_proxy, zone: deck.zone("considering"), account:, quantity: 2)
    create(:deck, account:, name: "Beta")

    alpha, beta = described_class.new(account).rows

    expect([ alpha.owned, alpha.proxy, alpha.cards ]).to eq([ 3, 6, 9 ])
    expect([ beta.owned, beta.proxy, beta.cards ]).to eq([ 0, 0, 0 ])
  end

  it "reads the proxies with one grouped statement, however many decks (AC-5.3)" do
    3.times { |n| create(:deck_proxy, zone: create(:deck, account:, name: "D#{n}").zone("main"), account:) }

    expect(count_queries { described_class.new(account).rows }).to eq(4) # the decks, their locations, the copies, the proxies
  end

  it "lists nothing for an account with no deck, and never another account's" do
    create(:deck, account: create(:user).account)

    expect(described_class.new(account).rows).to be_empty
  end

  it "runs the same number of statements for 1 and for 12 decks" do
    create(:deck, account:, name: "Only")
    few = count_queries { described_class.new(account).rows }
    11.times { |index| create_lot_in_zone(create(:deck, account:, name: "Deck #{index}"), "main") }

    expect(count_queries { described_class.new(account).rows }).to eq(few)
  end
end
