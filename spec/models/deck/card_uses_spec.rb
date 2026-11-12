require "rails_helper"

# Spec 073 decisions 4 and 6: the zones that hold a copy or a proxy of one card, summed across its printings.
RSpec.describe Deck::CardUses, type: :model do
  let(:account) { create(:user).account }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:entry) { printing }

  def printing(**attributes) = create(:mtg_printing, entry: create(:catalog_entry, identity:, **attributes)).entry

  # The lots the caller passes are the card's lots in deck zones; here every lot the account has is one.
  def uses(for_entry: entry) = described_class.new(account:, entry: for_entry, lots: account.lots.to_a)

  def shown(rows) = rows.map { [ it.deck.name, it.zone.name, it.owned, it.proxy ] }

  it "makes one row per zone, summing copies across printings, finishes and conditions and proxies across printings", :aggregate_failures do
    deck = create(:deck, account:, name: "Izzet Tempo")
    other = printing
    create_lot_in_zone(deck, "main", entry:, quantity: 2, finish: "foil")
    create_lot_in_zone(deck, "main", entry: other, quantity: 3, condition: "near_mint")
    create(:deck_proxy, zone: deck.zone("main"), entry:, finish: "nonfoil", quantity: 1)
    create(:deck_proxy, zone: deck.zone("main"), entry: other, finish: "foil", quantity: 2)

    expect(shown(uses.rows)).to eq([ [ "Izzet Tempo", "Main", 5, 3 ] ])
    expect(uses).to have_attributes(owned: 5, proxy: 3, deck_count: 1)
  end

  it "orders decks by comparison key then name and a deck's zones by id", :aggregate_failures do
    banana = create(:deck, account:, name: "Banana")
    apple = create(:deck, account:, name: "apple")
    create_lot_in_zone(banana, "main", entry:)
    create_lot_in_zone(apple, "sideboard", entry:)
    create_lot_in_zone(apple, "main", entry:)

    expect(shown(uses.rows).map { it.first(2) }).to eq([ %w[apple Main], %w[apple Sideboard], %w[Banana Main] ]) # "apple" sorts before "Banana" by key
  end

  it "makes a row for a zone that has only a proxy, with 0 owned, and leaves it out of the deck count", :aggregate_failures do
    deck = create(:deck, account:, name: "Proxy only")
    create(:deck_proxy, zone: deck.zone("considering"), entry:, finish: "nonfoil", quantity: 2)

    expect(shown(uses.rows)).to eq([ [ "Proxy only", "Considering", 0, 2 ] ])
    expect(uses).to have_attributes(owned: 0, proxy: 2, deck_count: 0)
  end

  it "counts a deck once however many of its zones hold copies" do
    deck = create(:deck, account:)
    create_lot_in_zone(deck, "main", entry:)
    create_lot_in_zone(deck, "considering", entry:)

    expect(uses.deck_count).to eq(1)
  end

  it "reads only this account's proxies, and only of this card's printings", :aggregate_failures do
    deck = create(:deck, account:, name: "Mine")
    create(:deck_proxy, zone: deck.zone("main"), entry:, quantity: 1)
    create(:deck_proxy, zone: deck.zone("main"), entry: create(:mtg_printing).entry, quantity: 4) # another card
    other = create(:user).account # another account: every record is its own
    theirs = create(:deck, account: other, name: "Theirs")
    create(:deck_proxy, zone: theirs.zone("main"), entry:, account: other, quantity: 8)
    create_lot_in_zone(theirs, "main", entry:, quantity: 6)

    expect(shown(uses.rows)).to eq([ [ "Mine", "Main", 0, 1 ] ]) # the control: the owner's own proxy is there
    expect(described_class.new(account: other, entry:, lots: other.lots.to_a).rows.map { it.deck.name }).to eq([ "Theirs" ])
  end

  # The zones query would drop another account's zones anyway, so the rows can't show whether the proxies' own account filter
  # is there: the statement that sums the proxies is read directly.
  it "sums only this account's proxies by zone, never another account's proxy of the card in its own zone", :aggregate_failures do
    deck = create(:deck, account:, name: "Mine")
    create(:deck_proxy, zone: deck.zone("main"), entry:, quantity: 1)
    other = create(:user).account
    theirs = create(:deck, account: other, name: "Theirs")
    create(:deck_proxy, zone: theirs.zone("main"), entry:, account: other, quantity: 8)

    expect(uses.send(:proxies_by_zone)).to eq(deck.zone("main").id => 1)
    expect(described_class.new(account: other, entry:, lots: []).send(:proxies_by_zone)).to eq(theirs.zone("main").id => 8)
  end

  it "has no rows and runs no statement for a visitor (no account)", :aggregate_failures do
    entry.identity # loaded beforehand: only the object's own reads are counted
    visitor = described_class.new(account: nil, entry:, lots: [])
    statements = count_queries { visitor.rows }

    expect(statements).to eq(0)
    expect([ visitor.rows, visitor.owned, visitor.proxy, visitor.deck_count ]).to eq([ [], 0, 0, 0 ])
  end
end
