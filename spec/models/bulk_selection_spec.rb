require "rails_helper"

RSpec.describe BulkSelection, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:default_sort) { CollectionTable::Sort.parse(nil, nil) }
  let(:selection) { described_class.for(user.sessions.create!) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)

  def tick(shown, ticked, header_rendered: false, header_ticked: false, baseline: [], header_toggled: false)
    selection.record!(shown_ids: shown.map(&:id), ticked_ids: ticked.map(&:id), header_rendered:, header_ticked:,
      baseline_ids: baseline.map(&:id), header_toggled:)
  end

  it "starts empty under the default filter and sort", :aggregate_failures do
    own
    expect([ selection.lots.to_a, selection.copies, selection.context?("", default_sort) ]).to eq([ [], 0, true ])
  end

  it "selects shown-and-ticked lots and unselects shown-and-unticked ones, across pages" do
    a, b, c = [ "Card A", "Card B", "Card C" ].map { |name| own(name) }
    tick([ a, b ], [ a, b ])
    tick([ b, c ], [ c ])
    expect(selection.lots).to contain_exactly(a, c)
  end

  it "selects every matching lot from the header, keeps unticks as exceptions and clears from the header", :aggregate_failures do
    a = own("Bolt A", quantity: 2)
    b = own("Bolt B", quantity: 3)
    own("Opt")
    selection.restart!(query: "bolt", sort: default_sort)
    tick([ a ], [], header_ticked: true)
    expect(selection.lots).to contain_exactly(a, b)
    expect([ selection.copies, selection.everything? ]).to eq([ 5, true ])
    tick([ a ], [], header_rendered: true, header_ticked: true, baseline: [ a ])
    expect([ selection.lots.to_a, selection.copies, selection.everything? ]).to eq([ [ b ], 3, false ])
    tick([ a, b ], [ b ], header_rendered: true, header_ticked: false, baseline: [ b ])
    expect(selection.lots).to be_empty
  end

  context "when the header was toggled (spec v5.0.0 FR-4)" do
    let(:lots) { [ "Card A", "Card B", "Card C" ].map { |name| own(name) } }

    it "keeps a row unticked against its ticked baseline as an exception after Select all" do
      a, b, c = lots
      tick([ a, b, c ], [ a, c ], header_ticked: true, baseline: [ a, b, c ], header_toggled: true)
      expect(selection.lots).to contain_exactly(a, c)
    end

    it "selects a row ticked against its unticked baseline after clearing the header" do
      a, b, c = lots
      tick([ a, b, c ], [], header_ticked: true)
      tick([ a, b, c ], [ b ], header_rendered: true, header_ticked: false, baseline: [], header_toggled: true)
      expect(selection.lots).to contain_exactly(b)
    end

    it "lets rows equal to their baseline follow the header", :aggregate_failures do
      a, b, c = lots
      tick([ a ], [ a ])
      tick([ a, b ], [ a ], header_ticked: true, baseline: [ a ])
      expect(selection.lots).to contain_exactly(a, b, c)
      tick([ a, b ], [ a, b ], header_rendered: true, header_ticked: false, baseline: [ a, b ])
      expect(selection.lots).to be_empty
    end

    it "resets when scripting reports a toggle, even with the header submitted as rendered" do
      a, b, c = lots
      tick([ a ], [ a ])
      tick([ b, c ], [ b ], baseline: [], header_toggled: true)
      expect(selection.lots).to contain_exactly(b)
    end
  end

  it "ignores ids that aren't the account's matching lots" do
    mine = own
    theirs = owned_printing(account: create(:user).account)
    tick([ mine, theirs ], [ mine, theirs ])
    expect(selection.marks.pluck(:lot_id)).to eq([ mine.id ])
  end

  it "starts over under a new filter and sort", :aggregate_failures do
    lot = own
    tick([ lot ], [ lot ])
    by_price = CollectionTable::Sort.parse("price", "desc")
    selection.restart!(query: "bolt", sort: by_price)
    expect([ selection.lots.to_a, selection.context?("bolt", by_price), selection.context?("", default_sort) ]).to eq([ [], true, false ])
    expect(selection.sort.to_params).to eq(sort: "price", dir: "desc")
  end

  it "drops a mark when its lot is removed" do
    lot = own
    tick([ lot ], [ lot ])
    lot.destroy!
    expect(selection.marks).to be_empty
  end

  it "goes with its session however the session ends", :aggregate_failures do
    lot = own
    tick([ lot ], [ lot ])
    user.end_sessions!
    expect([ described_class.count, BulkSelection::Mark.count ]).to eq([ 0, 0 ])
  end

  it "keeps an indexed account key on its tables and cascades from sessions", :aggregate_failures do
    connection = described_class.connection
    %w[bulk_selections bulk_selection_marks].each do |table|
      expect(connection.columns(table).find { |column| column.name == "account_id" }.null).to be(false)
      expect(connection.foreign_keys(table).map(&:to_table)).to include("accounts")
      expect(connection.indexes(table).map(&:columns)).to include(a_collection_starting_with("account_id"))
    end
    expect(connection.foreign_keys("bulk_selections").find { |key| key.to_table == "sessions" }.on_delete).to eq(:cascade)
    expect(connection.foreign_keys("bulk_selection_marks").find { |key| key.to_table == "lots" }.on_delete).to eq(:cascade)
  end

  it "selects lots added later, in either mode", :aggregate_failures do
    a = own("Card A")
    b = own("Card B")
    selection.include!([ a.id ])
    expect(selection.lots).to eq([ a ])
    tick([ a ], [ a ], header_ticked: true, baseline: [ a ])
    tick([ a, b ], [], header_rendered: true, header_ticked: true, baseline: [ a, b ])
    selection.include!([ b.id ])
    expect(selection.lots).to eq([ b ])
  end

  describe "under a location filter (spec 037 decision 5)" do
    let(:blue) { create(:location, account:) }

    it "reads a row stored before the column as all locations", :aggregate_failures do
      session = user.sessions.create!
      now = Time.current
      described_class.insert_all([ { session_id: session.id, account_id: account.id, created_at: now, updated_at: now } ])
      old = described_class.find_by!(session:)
      expect([ old.location_filter, old.context?("", default_sort), old.context?("", default_sort, location: "") ]).to eq([ "", true, true ])
    end

    it "compares the location in its context and restarts under it", :aggregate_failures do
      lot = own(location: blue)
      tick([ lot ], [ lot ])
      selection.restart!(query: "", sort: default_sort, location: blue.id.to_s)
      expect([ selection.marks.count, selection.location_filter ]).to eq([ 0, blue.id.to_s ])
      expect([ selection.context?("", default_sort, location: blue.id.to_s), selection.context?("", default_sort) ]).to eq([ true, false ])
    end

    it "selects and records only the place's lots", :aggregate_failures do
      inside = own("Card A", location: blue)
      outside = own("Card B")
      selection.restart!(query: "", sort: default_sort, location: blue.id.to_s)
      tick([ inside, outside ], [ inside, outside ])
      expect(selection.marks.pluck(:lot_id)).to eq([ inside.id ])
      tick([], [], header_ticked: true)
      expect(selection.lots).to eq([ inside ])
    end

    it "selects only unplaced lots for none" do
      own("Card A", location: blue)
      unplaced = own("Card B")
      selection.restart!(query: "", sort: default_sort, location: "none")
      tick([], [], header_ticked: true)
      expect(selection.lots).to eq([ unplaced ])
    end

    it "fails closed for a removed, foreign or unknown location, also with every matching lot", :aggregate_failures do
      own("Card A")
      own("Card B", location: blue)
      gone = create(:location, account:)
      foreign = create(:location).tap { create(:lot, account: it.account, location: it) }
      [ gone.id.to_s, foreign.id.to_s, "999999999" ].each do |place|
        selection.restart!(query: "", sort: default_sort, location: place)
        gone.destroy! if gone.persisted?
        tick([], [], header_ticked: true)
        expect([ selection.lots.to_a, selection.copies ]).to eq([ [], 0 ])
      end
    end
  end

  it "uses the vocabulary of its lots' collectible" do
    own
    selection.include!(Lot.ids)
    expect(selection.vocabulary).to eq(MTG::Collecting)
  end

  describe "#after_move! (spec 041)" do
    let(:blue) { create(:location, account:) }

    it "selects the lots that now hold the moved copies under all locations, an excepted one too (AC-3.9)", :aggregate_failures do
      a = own("Card A")
      excepted = own("Card B")
      selection.restart!(query: "", sort: default_sort)
      tick([ a, excepted ], [ a ], header_ticked: true, baseline: [ a, excepted ], header_toggled: true)
      expect(selection.lots).to contain_exactly(a)
      selection.after_move!([ excepted.id ])
      expect(selection.lots).to contain_exactly(a, excepted)
    end

    it "marks the surviving lots of a ticked-set selection (AC-3.9)" do
      a = own("Card A")
      b = own("Card B")
      tick([ a, b ], [ a ])
      selection.after_move!([ b.id ])
      expect(selection.lots).to contain_exactly(a, b)
    end

    it "restarts empty under the same filters and sort when a location filter is set (AC-3.13)", :aggregate_failures do
      a = own("Card A", location: blue)
      selection.restart!(query: "card", sort: CollectionTable::Sort.parse("name", "desc"), location: blue.id.to_s)
      tick([ a ], [ a ])
      selection.after_move!([ a.id ])
      expect(selection.lots).to be_empty
      expect(selection.context?("card", CollectionTable::Sort.parse("name", "desc"), location: blue.id.to_s)).to be(true)
      expect(selection.all_matching?).to be(false)
    end

    it "restarts under none the same way (AC-3.13)" do
      a = own("Card A")
      selection.restart!(query: "", sort: default_sort, location: CollectionFilter::Place::NONE)
      tick([ a ], [ a ])
      selection.after_move!([ a.id ])
      expect(selection.lots).to be_empty
    end
  end
end
