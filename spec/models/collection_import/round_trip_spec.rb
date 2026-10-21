require "rails_helper"

# Spec 028 Story 6: export → import restores the collection (the 1.0 test's second check).
RSpec.describe "Export and import round trip", type: :model do
  let(:source) { create(:user, name: "Source", email_address: "source@example.test") }
  let(:target) { create(:user, name: "Target", email_address: "target@example.test") }

  def export(user, at: Time.utc(2026, 10, 20, 12)) = JSON.parse(CollectionExport.new(account: user.account, at:).to_json)

  # The same collection under the format's rule, the profile's name and email address apart (apply never changes them).
  def same_collection?(one, other)
    ExportFormatRules.same_collection?(one.merge("profile" => one["profile"].except("name", "email_address")),
      other.merge("profile" => other["profile"].except("name", "email_address")))
  end

  def apply!(user, data)
    upload = store_import!(account: user.account, data:)
    CollectionImport::Apply.new(account: user.account.reload, fingerprint: upload&.fingerprint, confirmed: true).call
  end

  before do
    a = import_printing
    b = import_printing
    c = import_printing
    held_lot(source.account, a, quantity: 4, finish: "foil", condition: "near_mint", price_paid_cents: 1250, added_at: "2026-01-02T03:04:05Z", changed_at: "2026-02-03T04:05:06Z")
    held_lot(source.account, a, quantity: 1, finish: "nonfoil", added_at: "2026-03-01T00:00:00Z")
    held_lot(source.account, b, quantity: 9_999, condition: "damaged", price_paid_cents: 5, added_at: "2026-04-01T00:00:00Z")
    held_lot(source.account, c, quantity: 2)
  end

  it "has nothing to change for the collection that was exported, and stores nothing (AC-6.1)", :aggregate_failures do
    import = CollectionImport.new(account: source.account, file: StringIO.new(JSON.generate(export(source))))

    expect(import.unchanged.lots).to eq(4)
    expect(import.plan.nothing_to_change?).to be(true)
    expect(ImportUpload.count).to eq(0)
  end

  it "restores an export into an empty account of the same catalog (AC-6.2)", :aggregate_failures do
    original = export(source)

    expect(apply!(target, original).outcome).to eq(:applied)
    restored = export(target)

    expect(same_collection?(original, restored)).to be(true)
    expect(ExportFormatRules.problems(JSON.generate(restored))).to be_empty
  end

  it "restores a changed collection from the file (AC-6.3)", :aggregate_failures do
    original = export(source)
    source.account.lots.order(:id).first.update!(quantity: 1)
    source.account.lots.order(:id).last.destroy!
    held_lot(source.account, import_printing, quantity: 3)

    expect(apply!(source, original).outcome).to eq(:applied)

    expect(same_collection?(original, export(source))).to be(true)
    expect(CollectionImport.new(account: source.account, file: StringIO.new(JSON.generate(original))).plan.nothing_to_change?).to be(true)
  end

  describe "the format's valid example with lots (AC-6.4)" do
    # One entry and printing per source id (collection.json repeats ids across lots), with the finishes of its lots.
    def build_catalog(data)
      data["lots"].group_by { |lot| lot.dig("entry", "source_id") }.each_value do |lots|
        entry = lots.first["entry"]
        set = Catalog::Set.find_by(collectible_type: entry["collectible_type"], code: entry["set_code"]) || create(:catalog_set, code: entry["set_code"])
        created = create(:catalog_entry, external_key: entry["source_id"], set:, number: entry["collector_number"], language: entry["language"], name: entry["name"])
        create(:mtg_printing, entry: created, finishes: (%w[nonfoil foil etched] + lots.filter_map { |lot| lot["finish"] }).uniq)
      end
    end

    it "applies collection.json to an empty account and exports the same collection", :aggregate_failures do
      bytes = ExportFormatRules.examples("valid").fetch("valid/collection.json")
      data = JSON.parse(bytes)
      build_catalog(data)
      user = create(:user, name: data.dig("profile", "name"), email_address: data.dig("profile", "email_address"))

      expect(apply!(user, data).outcome).to eq(:applied)
      expect(same_collection?(data, export(user))).to be(true)
      expect(user.account.lots.count).to eq(data["lots"].size)
    end
  end
end
