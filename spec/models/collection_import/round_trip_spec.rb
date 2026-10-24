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

  it "restores lots in two locations, a printing in both, an unplaced lot and an empty location (AC-11.2)", :aggregate_failures do
    blue, box = locations(source, "Blue binder", "Long box")
    locations(source, "Empty one")
    entry = source.account.lots.first.entry
    create(:lot, account: source.account, entry:, finish: "foil", condition: "near_mint", price_paid_cents: 1250, location: blue, quantity: 3)
    create(:lot, account: source.account, entry:, finish: "foil", condition: "near_mint", price_paid_cents: 1250, location: box, quantity: 2)
    original = export(source)

    expect(apply!(target, original).outcome).to eq(:applied)
    restored = export(target)

    expect(restored.except("exported_at", "profile")).to eq(original.except("exported_at", "profile"))
    expect(restored["locations"].map { |location| location["name"] }).to include("Empty one")
    expect(target.account.lots.map(&:location_id).compact.size).to eq(2)
  end

  def locations(user, *names) = names.map { |name| create(:location, account: user.account, name:) }

  def names(user) = user.account.locations.order(:id).pluck(:name)

  it "restores an export's locations by name, exactly spelled, into an empty account (AC-9.5)", :aggregate_failures do
    locations(source, "Blue binder", "Trade binder", "box")
    original = export(source)

    expect(apply!(target, original).outcome).to eq(:applied)

    expect(names(target)).to contain_exactly("Blue binder", "Trade binder", "box")
    expect(same_collection?(original, export(target))).to be(true)
    expect(export(target)["locations"]).to eq(original["locations"])
    expect(ExportFormatRules.problems(JSON.generate(export(target)))).to be_empty
  end

  it "restores a changed set of locations from the file, and then has nothing to change (AC-9.6)", :aggregate_failures do
    blue, = locations(source, "Blue binder", "Trade binder", "Old crate")
    original = export(source)
    source.account.locations.find_by!(name: "Blue binder").update!(name: "Green binder")
    source.account.locations.find_by!(name: "Old crate").destroy!
    create(:location, account: source.account, name: "New box")

    expect(apply!(source, original).outcome).to eq(:applied)

    expect(names(source)).to contain_exactly("Blue binder", "Trade binder", "Old crate")
    expect(same_collection?(original, export(source))).to be(true)
    expect(CollectionImport.new(account: source.account, file: StringIO.new(JSON.generate(original))).plan.nothing_to_change?).to be(true)
    expect(Location.exists?(blue.id)).to be(false) # the respelled "Green binder" went
    expect(source.account.locations.find_by!(name: "Blue binder").id).not_to eq(blue.id) # and "Blue binder" came back as a new row
  end

  it "previews the exported collection, locations and all, as nothing to change (AC-6.1 of spec 028, with locations)", :aggregate_failures do
    locations(source, "Blue binder", "box")
    import = CollectionImport.new(account: source.account, file: StringIO.new(JSON.generate(export(source))))

    expect(import.locations.unchanged).to eq(2)
    expect(import.plan.nothing_to_change?).to be(true)
    expect(ImportUpload.count).to eq(0)
  end

  # An export of this instance is version 3. An older example is compared as the version 3 file it becomes: a version 1
  # example with no locations, and every lot of an older example in no location (a restore reads such a lot as unplaced,
  # spec 032 decision 7); each location name as the export writes it, in NFC (decision 5), which a valid example in NFD isn't
  # (ruled 2026-10-21: AC-9.15 holds for the example once its names are normalised).
  def as_current_version(data)
    data = data.merge("locations" => []) if data["format_version"] == 1
    data = data.merge("lots" => data["lots"].map { |lot| lot.merge("location" => nil) }) if data["format_version"] < 3
    data = data.merge("format_version" => 3)
    data.merge("locations" => data["locations"].map { |location| { "name" => Location::Name.normalise(location["name"]) } })
  end

  describe "every valid example of the format (AC-6.4, AC-9.15)" do
    # One entry and printing per source id (the examples repeat ids across lots), with the finishes of its lots.
    def build_catalog(data)
      data["lots"].group_by { |lot| lot.dig("entry", "source_id") }.each_value do |lots|
        entry = lots.first["entry"]
        set = Catalog::Set.find_by(collectible_type: entry["collectible_type"], code: entry["set_code"]) || create(:catalog_set, code: entry["set_code"])
        created = create(:catalog_entry, external_key: entry["source_id"], set:, number: entry["collector_number"], language: entry["language"], name: entry["name"])
        create(:mtg_printing, entry: created, finishes: (%w[nonfoil foil etched] + lots.filter_map { |lot| lot["finish"] }).uniq)
      end
    end

    ExportFormatRules.examples("valid").each_key do |name|
      next if name.end_with?("lot-location-nfd.json") # outside the round trip: it re-exports with the stored spelling (AC-9.4)

      it "applies #{name} to an empty account and exports the same collection, or has nothing to change", :aggregate_failures do
        data = JSON.parse(ExportFormatRules.examples("valid").fetch(name))
        allow(Rails.configuration.x).to receive(:currency).and_return(Collector::Currency.fetch!(data["currency"]))
        build_catalog(data)
        user = create(:user, name: data.dig("profile", "name"), email_address: data.dig("profile", "email_address"))

        if data["lots"].empty? && data.fetch("locations", []).empty?
          import = CollectionImport.new(account: user.account, file: StringIO.new(JSON.generate(data)))
          expect([ import.refused?, import.plan.nothing_to_change? ]).to eq([ false, true ])
        else
          expect(apply!(user, data).outcome).to eq(:applied)
          expect(same_collection?(as_current_version(data), export(user))).to be(true)
          expect(user.account.lots.count).to eq(data["lots"].size)
          expect(user.account.locations.count).to eq(data.fetch("locations", []).size)
        end
      end
    end
  end
end
