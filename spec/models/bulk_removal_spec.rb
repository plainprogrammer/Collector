require "rails_helper"

RSpec.describe BulkRemoval, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:session) { user.sessions.create! }
  let(:selection) { BulkSelection.for(session) }
  let(:sort) { CollectionTable::Sort.parse(nil, nil) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
  def select_all = selection.record!(shown_ids: [], ticked_ids: [], header_rendered: false, header_ticked: true)

  it "removes the selected lots, keeping them for one undo, and empties the selection", :aggregate_failures do
    lot = own(quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 150)
    select_all
    removal = described_class.remove!(selection)
    expect([ Lot.count, removal.copies, removal.undoable?, selection.reload.lots.to_a ]).to eq([ 0, 2, true, [] ])
    expect(removal.reload.lots_data).to eq([
      { "catalog_entry_id" => lot.catalog_entry_id, "finish" => "foil", "condition" => "near_mint", "price_paid_cents" => 150, "quantity" => 2 }
    ])
  end

  it "removes only the lots matching the filter at the time" do
    bolt = own("Lightning Bolt")
    opt = own("Opt")
    selection.restart!(query: "bolt", sort:)
    select_all
    described_class.remove!(selection)
    expect([ Lot.exists?(bolt.id), Lot.exists?(opt.id) ]).to eq([ false, true ])
  end

  it "restores exactly the removed lots once", :aggregate_failures do
    own(quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 150)
    select_all
    before = Lot.pluck(:catalog_entry_id, :finish, :condition, :price_paid_cents, :quantity)
    removal = described_class.remove!(selection).reload
    removal.undo!(sort:)
    expect([ Lot.pluck(:catalog_entry_id, :finish, :condition, :price_paid_cents, :quantity), removal.undoable? ]).to eq([ before, false ])
    expect { removal.undo!(sort:) }.to raise_error(BulkRemoval::NotUndoable)
  end

  it "merges restored lots into lots added since" do
    lot = own(quantity: 2)
    select_all
    removal = described_class.remove!(selection).reload
    Lot.add!(account:, entry: lot.entry, quantity: 3)
    removal.undo!(sort:)
    expect(Lot.pluck(:quantity)).to eq([ 5 ])
  end

  it "restores nothing when a merge would pass 9,999 copies", :aggregate_failures do
    lot = own(quantity: 2)
    select_all
    removal = described_class.remove!(selection).reload
    full = Lot.add!(account:, entry: lot.entry, quantity: 9_999)
    expect { removal.undo!(sort:) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(full) }
    expect([ Lot.pluck(:quantity), removal.reload.undoable? ]).to eq([ [ 9_999 ], true ])
  end

  it "restores lots of retired printings" do
    own.entry.update!(retired_at: 1.day.ago)
    select_all
    described_class.remove!(selection).reload.undo!(sort:)
    expect(Lot.count).to eq(1)
  end

  it "keeps one undoable removal per session, leaving superseded ones as stubs", :aggregate_failures do
    own("Card A")
    select_all
    first = described_class.remove!(selection)
    own("Card B")
    select_all
    second = described_class.remove!(selection)
    expect([ first.reload.undoable?, first.lots_data, second.undoable? ]).to eq([ false, nil, true ])
    described_class.supersede!(session)
    expect(second.reload.undoable?).to be(false)
  end

  it "goes with its session" do
    own
    select_all
    described_class.remove!(selection)
    user.end_sessions!
    expect(described_class.count).to eq(0)
  end

  it "keeps an indexed account key and cascades from sessions", :aggregate_failures do
    connection = described_class.connection
    expect(connection.columns("bulk_removals").find { |column| column.name == "account_id" }.null).to be(false)
    expect(connection.indexes("bulk_removals").map(&:columns)).to include(a_collection_starting_with("account_id"))
    expect(connection.foreign_keys("bulk_removals").find { |key| key.to_table == "sessions" }.on_delete).to eq(:cascade)
  end
end
