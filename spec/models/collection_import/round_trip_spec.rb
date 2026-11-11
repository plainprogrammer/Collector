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

  describe "decks and zones (spec 062 AC-8.5)" do
    # One deck in every format the specs register, a copy in its Main and in Considering and the rest of its zones empty, two
    # places holding a copy each, and the unplaced lots the outer `before` made.
    def seed_decks_and_places(user)
      entry = import_printing
      blue, box = locations(user, "Blue binder", "Long box")
      create(:lot, account: user.account, entry:, finish: "foil", location: blue, quantity: 2)
      create(:lot, account: user.account, entry:, finish: "nonfoil", location: box, quantity: 3)
      Catalog::Formats.options.map do |option|
        create(:deck, account: user.account, name: "Deck #{option.format.name}", pair: option.value).tap do |deck|
          create_lot_in_zone(deck, "main", entry:, quantity: 4)
          create_lot_in_zone(deck, Catalog::Formats::CONSIDERING, entry:, quantity: 1, finish: "foil")
        end
      end
    end

    def collection_rows(account)
      [ account.locations.order(:id).pluck(:id, :name, :kind, :parent_id, :zone), account.decks.order(:id).pluck(:id, :location_id, :collectible_type, :format),
        account.lots.order(:id).pluck(:id, :quantity, :location_id, :lot_key, :created_at, :updated_at) ]
    end

    it "restores places, decks of every format with their zones, zone lots, a place's lot and an unplaced lot into a fresh account", :aggregate_failures do
      seed_decks_and_places(source)
      original = export(source)

      expect(apply!(target, original).outcome).to eq(:applied)
      restored = export(target)

      expect(same_collection?(original, restored)).to be(true)
      expect(restored.except("exported_at", "profile")).to eq(original.except("exported_at", "profile"))
      expect(restored["decks"].size).to eq(Catalog::Formats.options.size)
      expect(ExportFormatRules.problems(JSON.generate(restored))).to be_empty
      expect(target.account.lots.where(location_id: nil)).to exist
      target.account.decks.includes(:location).each do |deck|
        expect(deck.zones.pluck(:zone)).to eq(Catalog::Formats.zones_for(deck.collectible_type, deck.format).map(&:key))
      end
      expect(target.account.lots.joins(:location).where(locations: { kind: "deck_zone" }).count).to eq(2 * Catalog::Formats.options.size)
      expect(target.account.locations.zones_of_decks.where.not(id: target.account.lots.where.not(location_id: nil).select(:location_id)).count).to be > 0 # empty zones came across
    end

    it "refuses the same file the second time as nothing to change, writing and clearing nothing", :aggregate_failures do
      seed_decks_and_places(source)
      original = export(source)
      apply!(target, original)
      rows = collection_rows(target.account)
      working_state = NumberEntry.create!(account: target.account)
      again = store_import!(account: target.account, data: original, forced: true)

      expect(CollectionImport.new(account: target.account.reload, file: StringIO.new(JSON.generate(original))).plan.nothing_to_change?).to be(true)
      result = CollectionImport::Apply.new(account: target.account.reload, fingerprint: again.fingerprint, confirmed: true).call

      expect(result.outcome).to eq(:nothing_to_change)
      expect(collection_rows(target.account)).to eq(rows)
      expect(NumberEntry.exists?(working_state.id)).to be(true)
    end
  end

  # An export of this instance is version 4. An older example is compared as the version 4 file it becomes: a version 1
  # example with no locations, every lot of an older example in no location (a restore reads such a lot as unplaced,
  # spec 032 decision 7), and no decks (an older file says nothing of them, spec 062); each location name as the export writes it, in NFC (decision 5), which a valid example in NFD isn't
  # (ruled 2026-10-21: AC-9.15 holds for the example once its names are normalised). A lot's zone names its deck by any spelling
  # of its comparison key ("IZZET TEMPO", AC-6.12), and an export writes the deck's own: the example is compared with that.
  def spelled(data, deck) = data["decks"].map { |entry| entry["name"] }.find { |name| Location::Name.key(name) == Location::Name.key(deck) }

  def as_current_version(data)
    data = data.merge("lots" => data["lots"].map { |lot| lot["location"].is_a?(Hash) ? lot.merge("location" => lot["location"].merge("deck" => spelled(data, lot["location"]["deck"]))) : lot }) if data["format_version"] == 4
    data = data.merge("locations" => []) if data["format_version"] == 1
    data = data.merge("lots" => data["lots"].map { |lot| lot.merge("location" => nil) }) if data["format_version"] < 3
    data = data.merge("format_version" => 4, "decks" => data.fetch("decks", []))
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

      it "applies #{name} to an empty account at the default currency and exports the same collection, currency included, or has nothing to change (spec 038 AC-6.10, AC-6.11)", :aggregate_failures do
        data = JSON.parse(ExportFormatRules.examples("valid").fetch(name))
        build_catalog(data)
        user = create(:user, name: data.dig("profile", "name"), email_address: data.dig("profile", "email_address"))

        if data["lots"].empty? && data.fetch("locations", []).empty? && data["currency"] == user.account.currency
          import = CollectionImport.new(account: user.account, file: StringIO.new(JSON.generate(data)))
          expect([ import.refused?, import.plan.nothing_to_change? ]).to eq([ false, true ])
        else
          expect(apply!(user, data).outcome).to eq(:applied)
          expect(same_collection?(as_current_version(data), export(user))).to be(true)
          expect(export(user)["currency"]).to eq(data["currency"])
          expect(user.account.lots.count).to eq(data["lots"].size)
          expect(user.account.locations.places.count).to eq(data.fetch("locations", []).size)
          expect(user.account.decks.count).to eq(data.fetch("decks", []).size) # a deck is a location of its own kind, with its zones beside it
          expect(user.account.locations.zones_of_decks.count).to eq(data.fetch("decks", []).sum { |deck| Catalog::Formats.zones_for(deck["collectible_type"], deck["format"]).size })
          # Once applied, the same file has nothing to change, a currency-only file among them.
          expect(CollectionImport.new(account: user.account.reload, file: StringIO.new(JSON.generate(data))).plan.nothing_to_change?).to be(true)
        end
      end
    end
  end
end
