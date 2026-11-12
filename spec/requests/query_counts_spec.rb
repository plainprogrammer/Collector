require "rails_helper"

# NFR: a page's database work is bounded by the page, not by how much the collector owns or how
# many results it shows. Each page is loaded with little and with a lot of data and must run the
# same number of queries (an N+1 would add one per row).
RSpec.describe "Page query counts", type: :request do
  let(:user) { create(:user) }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  before { sign_in_as(user) }

  def queries_for(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    expect(response).to have_http_status(:ok)
    count
  end

  def printing(identity: create(:catalog_identity, name: "Lightning Bolt"), **attributes)
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: identity.name, **attributes)).entry
  end

  def own(entry, **attributes) = create(:lot, account: user.account, entry:, **attributes)

  it "keeps the collection page's queries independent of the number of lots" do
    own(printing, finish: "foil")
    few = queries_for(collection_path)
    29.times { |n| own(printing, finish: n.even? ? "foil" : "nonfoil") }
    expect(queries_for(collection_path)).to eq(few)
  end

  it "keeps the locations page's queries independent of the number of locations (spec 029 NFR)" do
    create(:location, account: user.account)
    few = queries_for(locations_path)
    29.times { create(:location, account: user.account) }

    expect(queries_for(locations_path)).to eq(few)
  end

  it "keeps the locations page's queries independent of the lots in its locations (spec 032 NFR)" do
    create(:lot, account: user.account, location: create(:location, account: user.account))
    few = queries_for(locations_path)
    29.times { create(:lot, account: user.account, location: create(:location, account: user.account), entry: printing) }

    expect(queries_for(locations_path)).to eq(few)
  end

  it "keeps the refusal page's queries independent of the number of lots in the location (spec 032 NFR)" do
    location = create(:location, account: user.account)
    5.times { |n| own(printing, location:, price_paid_cents: n) }
    few = queries_for(new_location_removal_path(location))
    35.times { |n| own(printing, location:, price_paid_cents: 100 + n) }

    expect(queries_for(new_location_removal_path(location))).to eq(few)
  end

  # Since spec 073 the card page preloads the lots' places twice (`Catalog::CardOverview#lots` and `Lot::FreeCopies#lots`). With a
  # single placed lot, or with lots whose two lists agree, both preloads issue the same statement and the second is a query-cache
  # hit that the counter skips, which says nothing about scaling. So the baseline has two lots listed in different orders: the
  # overview sorts the unpriced lot first, while `Lot::FreeCopies` reads in the order of the `lot_key` index, which puts it
  # last, so the two statements differ and neither is a cache hit (spec 070's statement-count lesson,
  # docs/lessons/2026-11-11-a-statement-count-example-needs-different-printings-for-its-two-runs.md).
  it "keeps the card page's queries independent of the number of placed lots (spec 032 NFR)" do
    entry = printing
    [ nil, 100 ].each { |cents| own(entry, location: create(:location, account: user.account), price_paid_cents: cents) }
    few = queries_for(catalog_entry_path(entry))
    18.times { |n| own(entry, location: create(:location, account: user.account), price_paid_cents: 200 + n) }

    expect(queries_for(catalog_entry_path(entry))).to eq(few)
  end

  it "keeps the add form's queries independent of the number of locations (spec 032 NFR)" do
    entry = printing
    create(:location, account: user.account)
    few = queries_for(new_catalog_entry_lot_path(entry))
    29.times { create(:location, account: user.account) }

    expect(queries_for(new_catalog_entry_lot_path(entry))).to eq(few)
  end

  it "keeps the Move copies page's queries independent of the number of locations (spec 032 NFR)" do
    lot = own(printing)
    create(:location, account: user.account)
    few = queries_for(new_lot_move_path(lot))
    29.times { create(:location, account: user.account) }

    expect(queries_for(new_lot_move_path(lot))).to eq(few)
  end

  it "keeps search's queries independent of the number of result groups" do
    own(printing)
    printing(identity: Catalog::Identity.sole)
    few = queries_for(catalog_entries_path(q: "bolt"))
    11.times do
      entry = printing
      own(entry)
      printing(identity: entry.identity, language: "ja", localized_name: "稲妻")
    end
    expect(queries_for(catalog_entries_path(q: "bolt"))).to eq(few)
  end

  it "keeps the card page's queries independent of the number of lots" do
    entry = printing(identity:)
    # The first lot is of another printing: a lone lot of the page's own printing lets Rails reuse the
    # already-loaded set, which saves one query without saying anything about scaling.
    own(printing(identity:))
    few = queries_for(catalog_entry_path(entry))
    7.times { |n| own(entry, price_paid_cents: 100 * (n + 1)) }
    7.times { own(printing(identity:), finish: "foil", condition: "near_mint") }
    expect(queries_for(catalog_entry_path(entry))).to eq(few)
  end

  # Spec 062 AC-5.4: a zone's label names its deck, so every lot list preloads the parent. A zone lot costs at most the one
  # query that loads the parents (a place has none to load), and no query more however many lots or decks there are.
  # The card page reads the card's decks too (spec 073) and is judged by its own example below.
  it "keeps the grid's, the table's and the bulk table's queries to a place's plus one for lots in zones", :aggregate_failures do
    user.update!(collection_view: "table")
    entry = printing
    lot = own(entry, location: create(:location, account: user.account))
    post collection_selection_path
    paths = { grid: collection_path(view: "grid"), table: collection_path, bulk: collection_path(bulk: 1) }
    in_a_place = paths.transform_values { |path| queries_for(path) }

    lot.update!(location: create(:deck, account: user.account, name: "Deck 0").zone("main"))
    in_a_zone = paths.transform_values { |path| queries_for(path) }
    expect(in_a_zone.merge(in_a_place) { |_, zone, place| zone - place }.values).to all(be <= 1)

    5.times { |n| own(entry, location: create(:deck, account: user.account, name: "Deck #{n + 1}").zone("sideboard"), price_paid_cents: n) }
    expect(paths.transform_values { |path| queries_for(path) }).to eq(in_a_zone)
  end

  # Spec 065 AC-8.2. A regression proof, not a red-first example: the filter already read the account's locations in one
  # statement, and now one `Location::Choices` read carries the places, the decks and their zones, so decks cost nothing more.
  it "keeps the collection page's queries the same with three decks as with none (spec 065 AC-8.2)", :aggregate_failures do
    own(printing, location: create(:location, account: user.account))
    paths = { grid: collection_path(view: "grid"), table: collection_path(view: "table"), bulk: collection_path(bulk: 1) }
    post collection_selection_path
    paths.each_value { |path| queries_for(path) } # a view param saves the collector's view, one write that the first pass makes
    without_decks = paths.transform_values { |path| queries_for(path) }

    3.times { |n| create(:deck, account: user.account, name: "Deck #{n}") }
    expect(paths.transform_values { |path| queries_for(path) }).to eq(without_decks)
  end

  # Spec 065 AC-8.2: an account whose only location is a deck takes the select, the column and the place line as one with a
  # place does, from the same read, so the "has any place" test costs it no statement of its own. The lot is unplaced in both
  # states, so only the account's locations differ.
  it "keeps the collection page's queries the same for an account with a deck and no place as with a place (spec 065 AC-8.2)", :aggregate_failures do
    own(printing)
    place = create(:location, account: user.account)
    paths = { grid: collection_path(view: "grid"), table: collection_path(view: "table"), bulk: collection_path(bulk: 1) }
    post collection_selection_path
    paths.each_value { |path| queries_for(path) } # the first pass saves the view param
    with_a_place = paths.transform_values { |path| queries_for(path) }

    create(:deck, account: user.account, name: "Only deck")
    place.destroy!
    expect(paths.transform_values { |path| queries_for(path) }).to eq(with_a_place)
  end

  it "keeps the table's queries independent of the number of lots, in and out of bulk mode", :aggregate_failures do
    user.update!(collection_view: "table")
    own(printing, finish: "foil")
    post collection_selection_path
    few = queries_for(collection_path)
    few_bulk = queries_for(collection_path(bulk: 1))
    29.times { |n| own(printing, condition: n.even? ? "near_mint" : nil) }
    expect(queries_for(collection_path)).to eq(few)
    expect(queries_for(collection_path(bulk: 1))).to eq(few_bulk)
  end

  it "keeps the deck page's queries independent of the zones, printings and lots a deck holds (spec 066 AC-2.10)" do
    deck = create(:deck, account: user.account, name: "Izzet Tempo")
    create_lot_in_zone(deck, "main", entry: printing(identity: create(:catalog_identity, name: "One")))
    few = queries_for(deck_path(deck))
    24.times do |n|
      entry = printing(identity: create(:catalog_identity, name: "Card #{n}"), number: (n + 2).to_s)
      create_lot_in_zone(deck, %w[main sideboard considering][n % 3], entry:, finish: n.even? ? "foil" : "nonfoil")
    end

    expect(queries_for(deck_path(deck))).to eq(few)
  end

  it "keeps the deck page's and the Decks page's queries the same with six proxies as with one (spec 068 AC-2.10, AC-5.3)", :aggregate_failures do
    deck = create(:deck, account: user.account, name: "Izzet Tempo")
    create(:deck_proxy, zone: deck.zone("main"), account: user.account)
    paths = [ deck_path(deck), decks_path ]
    with_one = paths.map { |path| queries_for(path) }

    5.times { |n| create(:deck_proxy, zone: deck.zone(%w[main sideboard considering][n % 3]), account: user.account) }

    expect(paths.map { |path| queries_for(path) }).to eq(with_one)
  end

  it "keeps the deck page's queries the same with 40 printings, owned and proxied, as with one printing, panel included (spec 069 AC-6.1)" do
    deck = create(:deck, account: user.account, name: "Izzet Tempo")
    card = lambda do
      entry = printing
      create(:mtg_card, identity: entry.identity, mana_value: 2.0)
      entry
    end
    create_lot_in_zone(deck, "main", entry: card.call, quantity: 1)
    few = queries_for(deck_path(deck))

    entries = Array.new(39) { card.call }
    entries.each { |entry| create_lot_in_zone(deck, "main", entry:, quantity: 1) }
    entries.first(20).each { |entry| create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry:, quantity: 2) } # 40 printings, lots and proxies

    expect(queries_for(deck_path(deck))).to eq(few)
  end

  it "adds one statement for the panel, and none when Commander and Main hold no card (spec 069 AC-6.1, AC-6.3)" do
    entry = printing
    create(:mtg_card, identity: entry.identity, mana_value: 2.0)
    outside = create(:deck, account: user.account, name: "Sideboard only")
    inside = create(:deck, account: user.account, name: "In Main")
    create_lot_in_zone(outside, "sideboard", entry:)
    create_lot_in_zone(inside, "main", entry:)

    expect(queries_for(deck_path(inside))).to eq(queries_for(deck_path(outside)) + 1) # the mana values, read once for the curve, average and note
  end
end
