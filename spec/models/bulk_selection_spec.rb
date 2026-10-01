require "rails_helper"

RSpec.describe BulkSelection, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:default_sort) { CollectionTable::Sort.parse(nil, nil) }
  let(:selection) { described_class.for(user.sessions.create!) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)

  def tick(shown, ticked, header_rendered: false, header_ticked: false)
    selection.record!(shown_ids: shown.map(&:id), ticked_ids: ticked.map(&:id), header_rendered:, header_ticked:)
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
    tick([ a ], [], header_rendered: true, header_ticked: true)
    expect([ selection.lots.to_a, selection.copies, selection.everything? ]).to eq([ [ b ], 3, false ])
    tick([ a, b ], [ a, b ], header_rendered: true, header_ticked: false)
    expect(selection.lots).to be_empty
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
    tick([ a ], [], header_ticked: true)
    tick([ a, b ], [], header_rendered: true, header_ticked: true)
    selection.include!([ b.id ])
    expect(selection.lots).to eq([ b ])
  end

  it "uses the vocabulary of its lots' collectible" do
    own
    selection.include!(Lot.ids)
    expect(selection.vocabulary).to eq(MTG::Collecting)
  end
end
