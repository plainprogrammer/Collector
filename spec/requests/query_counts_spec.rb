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

  it "keeps the card page's queries independent of the number of placed lots (spec 032 NFR)" do
    entry = printing
    own(entry, location: create(:location, account: user.account))
    few = queries_for(catalog_entry_path(entry))
    19.times { |n| own(entry, location: create(:location, account: user.account), price_paid_cents: n) }

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
  it "keeps the grid's, the table's, the bulk table's and the card page's queries to a place's plus one for lots in zones", :aggregate_failures do
    user.update!(collection_view: "table")
    entry = printing
    lot = own(entry, location: create(:location, account: user.account))
    post collection_selection_path
    paths = { grid: collection_path(view: "grid"), table: collection_path, bulk: collection_path(bulk: 1), card: catalog_entry_path(entry) }
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
end
