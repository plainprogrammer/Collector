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
      { "catalog_entry_id" => lot.catalog_entry_id, "finish" => "foil", "condition" => "near_mint", "price_paid_cents" => 150, "quantity" => 2, "location_id" => nil }
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

  it "names the first lot in the sort order when several merges would pass 9,999 copies", :aggregate_failures do
    entries = %w[Ant Zebra].map { |name| own(name).entry }
    select_all
    removal = described_class.remove!(selection).reload
    ant, zebra = entries.map { |entry| Lot.add!(account:, entry:, quantity: 9_999) }
    by_name_desc = CollectionTable::Sort.parse("name", "desc")
    expect { removal.undo!(sort: by_name_desc) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(zebra) }
    expect([ Lot.where(id: [ ant, zebra ]).pluck(:quantity), removal.reload.undoable? ]).to eq([ [ 9_999, 9_999 ], true ])
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

  describe "with locations (spec 032 Story 7)" do
    def blue = @blue ||= create(:location, account:)

    def removal_of(*lots)
      selection.record!(shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id), header_rendered: false, header_ticked: false)
      described_class.remove!(selection).reload
    end

    it "saves each lot's place", :aggregate_failures do
      placed = own(location: blue)
      removal = removal_of(placed)
      expect(removal.lots_data.sole).to include("location_id" => blue.id)
    end

    it "restores each lot to its place and merges per place (AC-7.4)", :aggregate_failures do
      placed = own("Bolt", location: blue, quantity: 2)
      unplaced = create(:lot, account:, entry: placed.entry, quantity: 3)
      removal = removal_of(placed, unplaced)
      Lot.add!(account:, entry: placed.entry, quantity: 1, location: blue)
      removal.undo!(sort:)
      expect(account.lots.pluck(:location_id, :quantity)).to contain_exactly([ blue.id, 3 ], [ nil, 3 ])
    end

    it "restores a lot whose location was removed unplaced and says how many (AC-7.5)", :aggregate_failures do
      placed = own(location: blue)
      removal = removal_of(placed)
      blue.destroy!
      undone = removal.undo!(sort:)
      expect(account.lots.sole.location_id).to be_nil
      expect(undone.unplaced).to eq(1)
    end

    it "counts no unplaced lots when every location is still there", :aggregate_failures do
      removal = removal_of(own(location: blue), own("Opt"))
      expect(removal.undo!(sort:).unplaced).to eq(0)
    end

    it "merges restored rows that share an identity once their location is gone (AC-7.8)", :aggregate_failures do
      placed = own(location: blue, quantity: 3)
      unplaced = create(:lot, account:, entry: placed.entry, quantity: 4)
      removal = removal_of(placed, unplaced)
      blue.destroy!
      removal.undo!(sort:)
      expect(account.lots.pluck(:location_id, :quantity)).to eq([ [ nil, 7 ] ])
    end

    it "raises the cap error naming the entry when only the restored rows pass 9,999 (AC-7.8, O2)", :aggregate_failures do
      placed = own(location: blue, quantity: 9_999)
      unplaced = create(:lot, account:, entry: placed.entry, quantity: 1)
      removal = removal_of(placed, unplaced)
      blue.destroy!
      expect { removal.undo!(sort:) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot.entry).to eq(placed.entry) }
      expect([ account.lots.count, removal.reload.undoable? ]).to eq([ 0, true ])
    end

    it "names an existing lot that would overflow before a restored row (O2)", :aggregate_failures do
      placed = own(location: blue, quantity: 9_999)
      unplaced = create(:lot, account:, entry: placed.entry, quantity: 1)
      removal = removal_of(placed, unplaced)
      blue.destroy!
      full = Lot.add!(account:, entry: placed.entry, quantity: 9_999)
      expect { removal.undo!(sort:) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(full) }
    end

    it "restores saved lots with no location key unplaced (AC-7.8)" do
      lot = own
      removal = removal_of(lot)
      removal.update!(lots_data: removal.lots_data.map { |data| data.except("location_id") })
      removal.undo!(sort:)
      expect(account.lots.sole.location_id).to be_nil
    end
  end

  def queries_during
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def undo_queries_for(count)
    count.times { |n| own("Card #{n}", finish: n.even? ? "foil" : nil, price_paid_cents: n.even? ? nil : 100 * n) }
    select_all
    removal = described_class.remove!(selection).reload
    queries = queries_during { removal.undo!(sort:) }
    account.lots.destroy_all
    queries
  end

  it "runs as many queries to restore 12 lots that don't merge as for 2" do
    expect(undo_queries_for(12)).to eq(undo_queries_for(2))
  end
end
