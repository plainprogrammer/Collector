require "rails_helper"

RSpec.describe CollectionTable, type: :model do
  include QueryCounting

  let(:account) { create(:user).account }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)

  def table(sort: nil, dir: nil, query: nil, page: nil)
    described_class.new(account:, query:, page:, sort: CollectionTable::Sort.parse(sort, dir))
  end

  it "pages at 120 rows" do
    expect(described_class::PER_PAGE).to eq(120)
  end

  it "lists one row per lot in the grid's order, then finish, condition and price paid" do
    first = own("Lightning Bolt")
    lot = ->(**attributes) { create(:lot, account:, entry: first.entry, **attributes) }
    foil = lot.call(finish: "foil")
    played = lot.call(finish: "nonfoil", condition: "lightly_played")
    nm_dear = lot.call(finish: "nonfoil", condition: "near_mint", price_paid_cents: 200)
    nm_unpriced = lot.call(finish: "nonfoil", condition: "near_mint")
    nm_cheap = lot.call(finish: "nonfoil", condition: "near_mint", price_paid_cents: 100)
    opt = own("Opt")
    expect(table.lots).to eq([ nm_cheap, nm_dear, nm_unpriced, played, foil, first, opt ])
  end

  it "puts the newest printing of a card first" do
    old = own("Lightning Bolt", released_on: Date.new(1993, 8, 5))
    new = own("Lightning Bolt", released_on: Date.new(2021, 1, 1))
    expect(table.lots).to eq([ new, old ])
  end

  it "sorts by card name, not the printed name", :aggregate_failures do
    bolt = own("Lightning Bolt", language: "ja", localized_name: "稲妻")
    opt = own("Opt")
    expect(table(sort: "name", dir: "asc").lots).to eq([ bolt, opt ])
    expect(table(sort: "name", dir: "desc").lots).to eq([ opt, bolt ])
  end

  it "sorts by set and collector number, reversing both when descending", :aggregate_failures do
    aaa = create(:catalog_set, code: "aaa")
    bbb = create(:catalog_set, code: "bbb")
    a1 = own("Opt", set: aaa, number: "1")
    a2 = own("Bolt", set: aaa, number: "2")
    b1 = own("Shock", set: bbb, number: "1")
    expect(table(sort: "set", dir: "asc").lots).to eq([ a1, a2, b1 ])
    expect(table(sort: "set", dir: "desc").lots).to eq([ b1, a2, a1 ])
  end

  it "sorts condition by the collectible's scale with unspecified last both ways", :aggregate_failures do
    damaged = own("Card A", condition: "damaged")
    near_mint = own("Card B", condition: "near_mint")
    none = own("Card C")
    expect(table(sort: "condition", dir: "asc").lots).to eq([ near_mint, damaged, none ])
    expect(table(sort: "condition", dir: "desc").lots).to eq([ damaged, near_mint, none ])
  end

  it "sorts quantity and price paid numerically, unspecified price last both ways", :aggregate_failures do
    nine = own("Card A", quantity: 9, price_paid_cents: 900)
    ten = own("Card B", quantity: 10, price_paid_cents: 10_000)
    unpriced = own("Card C", quantity: 1)
    expect(table(sort: "quantity", dir: "asc").lots).to eq([ unpriced, nine, ten ])
    expect(table(sort: "price", dir: "asc").lots).to eq([ nine, ten, unpriced ])
    expect(table(sort: "price", dir: "desc").lots).to eq([ ten, nine, unpriced ])
  end

  it "breaks ties with the default order" do
    opt = own("Opt", quantity: 2)
    bolt = own("Lightning Bolt", quantity: 2)
    expect(table(sort: "quantity", dir: "desc").lots).to eq([ bolt, opt ])
  end

  it "filters by name, counts like the grid and pages", :aggregate_failures do
    stub_const("CollectionTable::PER_PAGE", 1)
    own("Lightning Bolt", quantity: 3)
    own("Bolt of Lightning", quantity: 1)
    own("Opt", quantity: 2)
    bolts = table(query: " bolt ", page: "99")
    expect([ bolts.query, bolts.matching_quantity, bolts.total_quantity, bolts.unique_cards ]).to eq([ "bolt", 4, 6, 3 ])
    expect([ bolts.pagination.page, bolts.pagination.total_pages, bolts.lots.size ]).to eq([ 2, 2, 1 ])
  end

  it "keeps rows of retired printings" do
    lot = own
    lot.entry.update!(retired_at: 1.day.ago)
    expect(table.lots).to eq([ lot ])
  end

  it "lists only the account's lots" do
    owned_printing(account: create(:user).account)
    expect(table.lots).to be_empty
  end

  it "preloads the lots' locations in a bounded number of statements" do
    blue = create(:location, account:)
    create(:lot, account:, entry: own("Opt").entry, location: blue)
    few = count_queries { table.lots.each { it.location&.name } }
    8.times { |i| create(:lot, account:, entry: own("Card #{i}").entry, location: create(:location, account:)) }
    expect(count_queries { table.lots.each { it.location&.name } }).to eq(few)
  end

  it "knows whether the account has anything to choose a location from", :aggregate_failures do
    expect(table.choices?).to be(false)
    create(:location, account:)
    expect(table.choices?).to be(true)
  end

  it "counts a deck's zones as choices and shows the place column for them (spec 065 decision 3)", :aggregate_failures do
    deck = create(:deck, account:)
    expect([ table.choices?, table.place_column? ]).to eq([ true, true ])
    expect(table.choices.decks.map { it.location }).to eq([ deck.location ])
  end

  describe "under a location filter (spec 037)" do
    let(:blue) { create(:location, account:, name: "Blue binder") }

    def placed(location) = described_class.new(account:, query: nil, location:, page: nil, sort: CollectionTable::Sort.parse(nil, nil))

    it "lists the place's lots and counts their copies", :aggregate_failures do
      bolt = own("Lightning Bolt", quantity: 2, location: blue)
      own("Lightning Bolt", quantity: 5, finish: "foil")
      opt = own("Opt", quantity: 1)
      expect([ placed(blue.id.to_s).lots, placed(blue.id.to_s).matching_quantity, placed(blue.id.to_s).filtered? ]).to eq([ [ bolt ], 2, true ])
      expect(placed("none").lots.map(&:quantity)).to eq([ 5, opt.quantity ])
      expect([ placed(blue.id.to_s).location, placed(blue.id.to_s).chosen_location ]).to eq([ blue.id.to_s, blue ])
    end

    it "joins the name filter" do
      own("Lightning Bolt", location: blue)
      opt = own("Opt", location: blue)
      filtered = described_class.new(account:, query: "opt", location: blue.id.to_s, page: nil, sort: CollectionTable::Sort.parse(nil, nil))
      expect(filtered.lots).to eq([ opt ])
    end

    it "reads the account's locations once", :aggregate_failures do
      own("Opt", location: blue)
      filter = placed(blue.id.to_s)
      expect(count_queries { [ filter.choices?, filter.location, filter.chosen_location, filter.choices.places ] }).to eq(1)
    end
  end
end
