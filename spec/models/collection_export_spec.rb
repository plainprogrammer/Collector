require "rails_helper"

# Spec 022: the collection export writes one account's collection as a format-v3 file (docs/export-format/README.md).
RSpec.describe CollectionExport, type: :model do
  let(:user) { create(:user, name: "Grace Example", email_address: "grace@example.test") }
  let(:account) { user.account }
  let(:at) { Time.utc(2026, 10, 14, 12, 34, 56.789r) }
  let(:export) { described_class.new(account:, at:) }

  def printing(**attributes) = create(:mtg_printing, entry: create(:catalog_entry, **attributes)).entry

  def parsed = JSON.parse(export.to_json)

  # Every shape a lot can take (AC-1.2).
  def fixture_collection
    serra = printing(name: "Serra Angel", external_key: "00000000-0000-4000-8000-000000000001", number: "27",
      set: create(:catalog_set, code: "dmr"))
    bolt_ja = printing(name: "Lightning Bolt", localized_name: "稲妻", language: "ja")
    retired = create(:catalog_entry, :retired)
    comic = create(:catalog_entry, collectible_type: "comics") # unregistered: its lot can carry no finish or condition
    token = create(:catalog_entry, kind: "token")
    [
      create(:lot, account:, entry: serra, quantity: 4, finish: "foil", condition: "near_mint", price_paid_cents: 1250),
      create(:lot, account:, entry: serra, finish: nil, condition: nil, price_paid_cents: nil),
      create(:lot, account:, entry: serra, finish: "nonfoil", condition: "damaged", price_paid_cents: 0),
      create(:lot, account:, entry: bolt_ja, quantity: Lot::MAX_QUANTITY, price_paid_cents: 100_005),
      create(:lot, account:, entry: retired),
      create(:lot, account:, entry: comic),
      create(:lot, account:, entry: token)
    ]
  end

  it "writes a well-formed file of every shape a lot can take" do
    fixture_collection

    expect(ExportFormatRules.problems(export.to_json)).to eq([])
  end

  it "writes the header, the profile and the currency", :aggregate_failures do
    file = parsed
    expect(file.except("lots", "locations")).to eq(
      "format" => "collector-export", "format_version" => 3, "exported_at" => "2026-10-14T12:34:56Z",
      "profile" => { "name" => "Grace Example", "email_address" => "grace@example.test", "collection_view" => "grid" },
      "currency" => Rails.configuration.x.currency.code)
    expect(file).not_to have_key("generator")
  end

  it "writes an empty collection as an empty list of lots", :aggregate_failures do
    expect(parsed["lots"]).to eq([])
    expect(ExportFormatRules.problems(export.to_json)).to eq([])
  end

  it "writes each lot's eight fields from the lot, its entry and its set" do
    travel_to(Time.utc(2026, 9, 30, 18, 2, 11.999r), with_usec: true) { fixture_collection }
    lot = account.lots.find_by!(price_paid_cents: 1250)
    lot.update!(quantity: 5, updated_at: Time.utc(2026, 10, 2, 9, 15, 0.5r))

    expect(parsed["lots"]).to include(
      "entry" => { "collectible_type" => "mtg", "source_id" => "00000000-0000-4000-8000-000000000001", "name" => "Serra Angel",
                   "set_code" => "dmr", "collector_number" => "27", "language" => "en" },
      "quantity" => 5, "finish" => "foil", "condition" => "near_mint", "price_paid" => "12.50", "location" => nil,
      "added_at" => "2026-09-30T18:02:11Z", "changed_at" => "2026-10-02T09:15:00Z")
  end

  it "writes one lot per lot row, with nulls, free copies, exact prices and the catalog's name", :aggregate_failures do
    lots = fixture_collection
    written = parsed["lots"]

    expect(written.size).to eq(lots.size)
    expect(written.map { |lot| lot.values_at("finish", "condition", "price_paid") }).to include(
      [ nil, nil, nil ], [ "nonfoil", "damaged", "0.00" ], [ nil, nil, "1000.05" ])
    expect(written.find { |lot| lot["entry"]["language"] == "ja" }).to include(
      "quantity" => Lot::MAX_QUANTITY, "entry" => a_hash_including("name" => "Lightning Bolt"))
    expect(written.map { |lot| lot["entry"]["collectible_type"] }).to include("comics")
  end

  it "writes the same file twice for an unchanged collection, apart from exported_at", :aggregate_failures do
    fixture_collection
    later = described_class.new(account:, at: at + 1.hour)

    expect(JSON.parse(later.to_json).except("exported_at")).to eq(parsed.except("exported_at"))
    expect(ExportFormatRules.same_collection?(parsed, JSON.parse(later.to_json))).to be(true)
  end

  it "writes only this account's profile and lots", :aggregate_failures do
    shared = printing
    mine = create(:lot, account:, entry: shared, quantity: 2)
    other = create(:user, name: "Zebulon Otherperson", email_address: "zebulon.otherperson@example.test")
    create(:lot, account: other.account, entry: shared, quantity: 8_888, price_paid_cents: 77_777)

    expect(parsed["lots"].map { |lot| [ lot["entry"]["source_id"], lot["quantity"] ] }).to eq([ [ mine.entry.external_key, 2 ] ])
    expect(parsed["lots"].map { |lot| lot.values_at("quantity", "price_paid") }.flatten).not_to include(8_888, "777.77")
    expect(export.to_json).not_to include("Zebulon Otherperson", "zebulon.otherperson@example.test")
  end

  it "writes the lots a scanner sitting added, and nothing of the sitting", :aggregate_failures do
    entry = printing
    added = Scanner::Sitting.add!(account:, printing: entry, finish: "foil", reading_key: "a" * 32)

    expect(parsed["lots"].map { |lot| [ lot["entry"]["source_id"], lot["finish"] ] }).to eq([ [ entry.external_key, "foil" ] ])
    expect(export.to_json).not_to include("a" * 32, "sitting")
    expect(added.replayed).to be(false)
  end

  it "writes exactly the fields the format defines" do
    fixture_collection

    reference = JSON.parse(ExportFormatRules.directory.join("examples/valid/collection-v3.json").read)

    expect(ExportFormatRules.field_names(parsed)).to match_array(ExportFormatRules.field_names(reference) - [ "generator" ])
  end

  it "reads the lots in one statement, whatever their number", :aggregate_failures do
    statements = lambda do
      sql = []
      counter = ->(*, payload) { sql << payload[:sql] unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      fresh = account.reload
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.new(account: fresh, at:).to_json }
      sql
    end
    2.times { create(:lot, account:, entry: printing) }
    few = statements.call
    28.times { create(:lot, account:, entry: printing) }
    many = statements.call

    expect(many.size).to eq(few.size)
    expect(many.grep(/FROM "lots"/).size).to eq(1)
  end

  it "writes nothing and enqueues nothing", :aggregate_failures do
    fixture_collection
    writes = []
    counter = ->(*, payload) { writes << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)/i) }

    expect { ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { export.to_json } }.not_to have_enqueued_job
    expect(writes).to eq([])
  end

  it "leaves the caller's time in its own zone", :aggregate_failures do
    local = Time.new(2026, 10, 14, 23, 30, 0, "-05:00")
    written = described_class.new(account:, at: local)

    expect([ written.filename, JSON.parse(written.to_json)["exported_at"] ]).to eq([ "collector-export-2026-10-15.json", "2026-10-15T04:30:00Z" ])
    expect(local.utc_offset).to eq(-5 * 3600)
  end

  it "names the file by the export's UTC date" do
    expect(described_class.new(account:, at: Time.new(2026, 10, 14, 23, 30, 0, "-05:00")).filename).to eq("collector-export-2026-10-15.json")
  end

  describe "locations (spec 029)" do
    def locations(*names) = names.each { |name| create(:location, account:, name:) }

    it "writes version 3 with the names only, in order, and a well-formed file (AC-6.1, AC-6.4, AC-6.5)", :aggregate_failures do
      locations("Trade binder", "Blue binder")
      fixture_collection
      file = parsed

      expect(file["format_version"]).to eq(3)
      expect(file["locations"]).to eq([ { "name" => "Blue binder" }, { "name" => "Trade binder" } ])
      expect(file["locations"].flat_map(&:keys).uniq).to eq([ "name" ])
      expect(file["lots"].size).to eq(7)
      expect(ExportFormatRules.problems(export.to_json)).to eq([])
    end

    it "writes an empty list for an account with none (AC-6.2)", :aggregate_failures do
      expect(parsed["format_version"]).to eq(3)
      expect(parsed["locations"]).to eq([])
      expect(ExportFormatRules.problems(export.to_json)).to eq([])
    end

    it "orders by comparison key then name, in code-point order (AC-6.3)" do
      locations("box", "Binder 2", "Binder 10", "Éclair", "eclair")

      expect(parsed["locations"].map { |location| location["name"] }).to eq([ "Binder 10", "Binder 2", "box", "eclair", "Éclair" ])
    end

    it "writes none of another account's (AC-6.7)", :aggregate_failures do
      locations("Blue binder")
      create(:location, name: "Zebulon's crate")

      expect(parsed["locations"]).to eq([ { "name" => "Blue binder" } ])
      expect(export.to_json).not_to include("Zebulon")
    end

    it "writes the same file twice for an unchanged collection, apart from exported_at (AC-6.6)", :aggregate_failures do
      locations("Blue binder", "Trade binder")
      later = described_class.new(account:, at: at + 1.hour)

      expect(JSON.parse(later.to_json).except("exported_at")).to eq(parsed.except("exported_at"))
      expect(ExportFormatRules.same_collection?(parsed, JSON.parse(later.to_json))).to be(true)
    end

    it "holds a different collection when a name differs in case, and the same one when the order does (AC-6.8)", :aggregate_failures do
      box = create(:location, account:, name: "box")
      create(:location, account:, name: "Binder")
      first = parsed
      box.update!(name: "Box")

      expect(ExportFormatRules.same_collection?(first, parsed)).to be(false)
      swapped = parsed.merge("locations" => parsed["locations"].reverse)
      expect(ExportFormatRules.same_collection?(parsed, swapped)).to be(true)
    end
  end

  describe "a lot's location (spec 032 Story 8)" do
    def blue = @blue ||= create(:location, account:, name: "Blue binder")
    def box = @box ||= create(:location, account:, name: "Long box")

    def lots_reads(&)
      reads = []
      counter = ->(*, payload) { reads << payload[:sql] if payload[:sql].include?('FROM "lots"') }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
      reads.size
    end

    it "writes the stored name or null for every lot, never an empty string (AC-8.1)", :aggregate_failures do
      a = printing
      create(:lot, account:, entry: a, location: blue, quantity: 2)
      create(:lot, account:, entry: a, quantity: 1)

      expect(parsed["lots"].map { |lot| lot["location"] }).to eq([ "Blue binder", nil ])
    end

    it "writes a printing in two places as two lots (AC-8.2)", :aggregate_failures do
      a = printing
      create(:lot, account:, entry: a, location: blue)
      create(:lot, account:, entry: a, location: box)

      expect(parsed["lots"].map { |lot| lot["location"] }).to eq([ "Blue binder", "Long box" ])
    end

    it "lists an empty location and every lot's location among the names (AC-8.3)", :aggregate_failures do
      create(:lot, account:, entry: printing, location: blue)
      box
      file = parsed

      expect(file["locations"].map { |location| location["name"] }).to eq([ "Blue binder", "Long box" ])
      expect(ExportFormatRules.problems(export.to_json)).to eq([])
    end

    it "writes nothing of another account's places (AC-8.4)", :aggregate_failures do
      other = create(:user).account
      theirs = create(:location, account: other, name: "Zebulon's crate")
      create(:lot, account: other, entry: printing, location: theirs)
      create(:lot, account:, entry: printing)

      expect(export.to_json).not_to include("Zebulon")
      expect(parsed["lots"].map { |lot| lot["location"] }).to eq([ nil ])
    end

    it "writes the same file twice, apart from exported_at (AC-8.5)" do
      create(:lot, account:, entry: printing, location: blue)
      later = described_class.new(account:, at: at + 1.hour)

      expect(JSON.parse(later.to_json).except("exported_at")).to eq(parsed.except("exported_at"))
    end

    it "writes null everywhere and no locations for an account with none (AC-8.6)", :aggregate_failures do
      create(:lot, account:, entry: printing)

      expect(parsed["locations"]).to eq([])
      expect(parsed["lots"].map { |lot| lot["location"] }).to eq([ nil ])
    end

    it "reads the lots and their places in one statement and the same statements whatever their number (NFR)", :aggregate_failures do
      3.times { |n| create(:lot, account:, entry: printing, location: create(:location, account:, name: "Place #{n}")) }
      few = lots_reads { described_class.new(account: account.reload, at:).to_json }
      20.times { |n| create(:lot, account:, entry: printing, location: create(:location, account:, name: "More #{n}")) }

      expect(few).to eq(1)
      expect(lots_reads { described_class.new(account: account.reload, at:).to_json }).to eq(1)
    end

    describe "a location changed between the export's two reads (plan review M5)" do
      before do
        create(:lot, account:, entry: printing, location: box)
        @written = []
      end

      # Runs +change+ right after the SELECT that reads the lots, +times+ times at most; counts the lot reads, leaving out the
      # subscriber's own statements (they are UPDATE and DELETE, not a SELECT from lots).
      def export_while(times:, &change)
        done = 0
        reads = 0
        subscriber = lambda do |*, payload|
          sql = payload[:sql]
          next unless sql.start_with?("SELECT") && sql.include?('FROM "lots"')

          reads += 1
          next unless done < times

          done += 1
          change.call
        end
        file = nil
        ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { file = described_class.new(account:, at:).to_json }
        [ file, reads ]
      end

      it "reads again after a rename and writes the new name on the list and the lot", :aggregate_failures do
        file, reads = export_while(times: 1) { Location.where(id: box.id).update_all(name: "Crate", name_key: "crate") }
        data = JSON.parse(file)

        expect(reads).to eq(2)
        expect(ExportFormatRules.problems(file)).to eq([])
        expect([ data["locations"], data["lots"].map { |lot| lot["location"] } ]).to eq([ [ { "name" => "Crate" } ], [ "Crate" ] ])
      end

      it "reads again after the lot moved out and its location was removed", :aggregate_failures do
        file, reads = export_while(times: 1) do
          Lot.where(account_id: account.id).update_all(location_id: nil, lot_key: Lot.key_for(nil, nil, nil))
          Location.where(id: box.id).delete_all
        end
        data = JSON.parse(file)

        expect(reads).to eq(2)
        expect(ExportFormatRules.problems(file)).to eq([])
        expect([ data["locations"], data["lots"].map { |lot| lot["location"] } ]).to eq([ [], [ nil ] ])
      end

      it "gives up after three reads when the locations keep changing", :aggregate_failures do
        count = 0
        expect { export_while(times: 5) { Location.where(id: box.id).update_all(name: "Name #{count += 1}", name_key: "name #{count}") } }
          .to raise_error(described_class::Unsettled)
        expect(count).to eq(3)
      end
    end
  end
end
