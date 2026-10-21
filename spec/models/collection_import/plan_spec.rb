require "rails_helper"

# Spec 028: what applying a file would do, and the fingerprint that ties an apply to its preview (decision 2).
RSpec.describe CollectionImport::Plan, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:a) { import_printing }
  let(:b) { import_printing }

  def import(lots, **fields) = CollectionImport.new(account:, file: import_io(import_file(user, lots, **fields)))

  it "lists what applying does (FR-1)", :aggregate_failures do
    kept = held_lot(account, a, quantity: 3)
    edited = held_lot(account, b, quantity: 2)
    gone = held_lot(account, import_printing, quantity: 7)
    plan = import([ import_row(a, quantity: 3), import_row(b, quantity: 5, changed_at: "2026-10-02T10:00:00Z"), import_row(import_printing, quantity: 6) ]).plan

    expect(plan.added_rows.map(&:number)).to eq([ 3 ])
    expect(plan.changed_rows.map(&:number)).to eq([ 2 ])
    expect(plan.held_for(plan.changed_rows.first).id).to eq(edited.id)
    expect(plan.removed_lots.map(&:id)).to eq([ gone.id ])
    expect(plan.counts).to eq(added: 1, changed: 1, removed: 1)
    expect([ plan.nothing_to_change?, plan.removes? ]).to eq([ false, true ])
    expect(kept).to be_persisted
  end

  it "has nothing to change for a file the collection already holds (AC-1.5)", :aggregate_failures do
    held_lot(account, a, quantity: 3)
    plan = import([ import_row(a, quantity: 3) ]).plan

    expect(plan.nothing_to_change?).to be(true)
    expect(import([], profile: { "name" => "x", "email_address" => "x@example.test", "collection_view" => "table" }).plan.nothing_to_change?).to be(false) # a view change alone is something
  end

  it "treats a lot with fractional times as unchanged against a row without them (AC-1.7)" do
    lot = held_lot(account, a, quantity: 3)
    lot.update_columns(created_at: Time.iso8601("2026-10-01T10:00:00Z") + 0.25, updated_at: Time.iso8601("2026-10-01T10:00:00Z") + 0.75)

    expect(import([ import_row(a, quantity: 3) ]).plan.nothing_to_change?).to be(true)
  end

  describe "#fingerprint (AC-3.7)" do
    def view_profile(view) = { "name" => user.name, "email_address" => user.email_address, "collection_view" => view }

    def fingerprint(checksum = "sum") = import([ import_row(a, quantity: 5), import_row(b, quantity: 1) ]).plan.fingerprint(checksum)

    it "is equal for two previews of the same file and collection", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      first = fingerprint
      expect(fingerprint).to eq(first)
      expect(lot).to be_persisted
    end

    it "differs for any change to a lot's quantity, either time or existence, to the file, or to the view", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      baseline = fingerprint

      lot.update_columns(quantity: 3)
      expect(fingerprint).not_to eq(baseline)
      lot.update_columns(quantity: 2)
      expect(fingerprint).to eq(baseline)
      lot.update_columns(updated_at: lot.updated_at + 0.001)
      expect(fingerprint).not_to eq(baseline) # full precision, not truncated to the second
      lot.update_columns(updated_at: lot.updated_at - 0.001, created_at: lot.created_at + 1.hour)
      expect(fingerprint).not_to eq(baseline)
      lot.update_columns(created_at: lot.created_at - 1.hour)
      expect(fingerprint("other")).not_to eq(baseline) # the stored file
      extra = held_lot(account, import_printing, quantity: 1)
      expect(fingerprint).not_to eq(baseline) # a removed lot appears
      extra.destroy!
      lot.destroy!
      expect(fingerprint).not_to eq(baseline)
      same = import([ import_row(a, quantity: 5) ], profile: view_profile("grid")).plan.fingerprint("sum")
      changing = import([ import_row(a, quantity: 5) ], profile: view_profile("table")).plan.fingerprint("sum")
      expect(changing).not_to eq(same) # the view change
    end
  end

  it "re-reads the collection on replan without parsing again, and becomes the import's plan", :aggregate_failures do
    held_lot(account, a, quantity: 3)
    parsed = import([ import_row(a, quantity: 3) ])
    expect(parsed.plan.nothing_to_change?).to be(true) # as the preview saw it

    account.lots.update_all(quantity: 4)
    expect(parsed.plan.nothing_to_change?).to be(true) # memoized

    expect(parsed.replan.changed_rows.size).to eq(1)
    expect(parsed.plan.changed_rows.size).to eq(1)
    expect(parsed.changed.lots).to eq(1) # the page's counts follow the new plan
  end

  it "knows the catalog entry each row resolved to" do
    parsed = import([ import_row(a) ])

    expect(parsed.entry_id(parsed.rows.first)).to eq(a.id)
  end

  describe "locations (spec 029)" do
    def import_v2(lots, locations: [], **fields) = CollectionImport.new(account:, file: import_io(import_file_v2(user, lots, locations:, **fields)))

    it "has something to change for a file whose only change is a location, and nothing for one that matches (AC-9.4)", :aggregate_failures do
      held_lot(account, a, quantity: 3)
      create(:location, account:, name: "Box")

      expect(import_v2([ import_row(a, quantity: 3) ], locations: [ "Box" ]).plan.nothing_to_change?).to be(true)
      plan = import_v2([ import_row(a, quantity: 3) ], locations: [ "Box", "Crate" ]).plan
      expect([ plan.nothing_to_change?, plan.writes_lots?, plan.removes? ]).to eq([ false, false, false ])
      expect(import_v2([ import_row(a, quantity: 3) ], locations: [ "BOX" ]).plan.nothing_to_change?).to be(false) # a change of case alone
    end

    it "removes when it removes lots or locations, and writes lots only when a lot changes (AC-9.10, AC-9.17)", :aggregate_failures do
      held_lot(account, a, quantity: 3)
      create(:location, account:, name: "Old crate")
      only_locations = import_v2([ import_row(a, quantity: 3) ], locations: [])
      only_view = import_v2([ import_row(a, quantity: 3) ], locations: [ "Old crate" ], profile: { "name" => user.name, "email_address" => user.email_address, "collection_view" => "table" })
      lots = import_v2([ import_row(a, quantity: 4) ], locations: [ "Old crate" ])

      expect([ only_locations.plan.removes?, only_locations.plan.writes_lots? ]).to eq([ true, false ])
      expect([ only_view.plan.nothing_to_change?, only_view.plan.writes_lots? ]).to eq([ false, false ])
      expect([ lots.plan.removes?, lots.plan.writes_lots? ]).to eq([ false, true ])
    end

    it "leaves a version 1 file's plan and fingerprint to the lots (AC-9.3)", :aggregate_failures do
      create(:location, account:, name: "Box")
      plan = import([ import_row(a) ]).plan

      expect(plan.locations.counted?).to be(false)
      expect(plan.fingerprint("sum")).to eq(import([ import_row(a) ]).plan.fingerprint("sum"))
    end

    describe "#fingerprint (AC-9.9)" do
      def fingerprint(*names, lots: [ import_row(a) ]) = import_v2(lots, locations: names).plan.fingerprint("sum")

      it "is equal for two previews of one file and account, and differs for a location added, removed or respelled", :aggregate_failures do
        box = create(:location, account:, name: "box")
        baseline = fingerprint("Box", "New")

        expect(fingerprint("Box", "New")).to eq(baseline)
        create(:location, account:, name: "New") # added by another tab
        expect(fingerprint("Box", "New")).not_to eq(baseline)
        Location.where(name: "New").destroy_all
        box.update!(name: "Box") # respelled, so the rename became unchanged
        expect(fingerprint("Box", "New")).not_to eq(baseline)
        box.update!(name: "box")
        expect(fingerprint("Box", "New")).to eq(baseline)
        box.destroy!
        expect(fingerprint("Box", "New")).not_to eq(baseline)
      end

      it "differs for another file, and holds no id: a renamed, a removed and an unchanged location deleted and added again with the same spelling change nothing (AC-9.9, ruled 2026-10-21)", :aggregate_failures do
        [ "box", "Old crate", "Same" ].each { |name| create(:location, account:, name:) } # "box" is renamed to Box, "Old crate" is removed
        baseline = fingerprint("Box", "Same", "Other")

        expect(fingerprint("Box", "Same", "Another")).not_to eq(baseline)
        account.locations.each do |location|
          name = location.name
          location.destroy!
          create(:location, account:, name:) # a new id each, the same plan
        end
        expect(fingerprint("Box", "Same", "Other")).to eq(baseline)
      end
    end
  end
end
