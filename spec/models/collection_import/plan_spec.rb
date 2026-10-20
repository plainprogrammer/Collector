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
end
