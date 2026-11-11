require "rails_helper"

# Spec 025: an export file read against one account's collection and this instance's catalog. Nothing is written.
RSpec.describe CollectionImport, type: :model do
  let(:user) { create(:user, name: "Grace Example", email_address: "grace@example.test") }
  let(:account) { user.account }

  def printing(**entry) = create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, **entry)).entry

  def row(entry, quantity: 1, finish: nil, condition: nil, price_paid: nil, added_at: "2026-10-01T10:00:00Z", changed_at: added_at)
    { "entry" => { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name,
                   "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language },
      "quantity" => quantity, "finish" => finish, "condition" => condition, "price_paid" => price_paid,
      "added_at" => added_at, "changed_at" => changed_at }
  end

  # A row naming an entry no catalog has.
  def stranger(source_id = "not-#{SecureRandom.hex(4)}", type: "mtg", **options)
    row(build(:catalog_entry, collectible_type: type, external_key: source_id), **options)
  end

  def file(lots, **fields)
    { "format" => "collector-export", "format_version" => 1, "exported_at" => "2026-10-15T09:00:00Z",
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => user.collection_view },
      "currency" => "USD", "lots" => lots }.merge(fields.stringify_keys)
  end

  def import(data) = described_class.new(account:, file: StringIO.new(data.is_a?(String) ? data : JSON.generate(data)))

  def held(entry, quantity:, added_at: "2026-10-01T10:00:00Z", changed_at: added_at, **attributes)
    create(:lot, account:, entry:, quantity:, created_at: Time.iso8601(added_at), updated_at: Time.iso8601(changed_at), **attributes)
  end

  def refusal_of(data) = import(data).refusal.then { |refusal| [ refusal.rule, refusal.at, refusal.reason ] }

  def reasons(preview) = preview.problem_rows.to_h { |row| [ row.number, row.problems.map(&:reason) ] }

  describe "a file refused as a whole (decision 10)" do
    it "asks for a file when there is none, it is empty, or the field isn't an upload", :aggregate_failures do
      reason = "Choose an export file to preview."
      expect(described_class.new(account:, file: nil).refusal).to eq(described_class::Refusal.new("no_file", "", reason))
      expect(described_class.new(account:, file: StringIO.new("")).refusal.rule).to eq("no_file")
      expect(described_class.new(account:, file: "export.json").refusal.rule).to eq("no_file")
    end

    it "refuses a file over 32 MB without reading it (AC-3.3)", :aggregate_failures do
      big = StringIO.new("{}")
      allow(big).to receive(:size).and_return(described_class::MAX_BYTES + 1)
      allow(big).to receive(:read).and_call_original

      expect(described_class.new(account:, file: big).refusal)
        .to eq(described_class::Refusal.new("too_large", "", "This file is larger than 32 MB, so it can't be an export Collector reads."))
      expect(big).not_to have_received(:read)
    end

    it "refuses a file it can't read as JSON", :aggregate_failures do
      reason = "This file isn't a Collector export: it isn't readable JSON."
      expect(refusal_of("{\"a\":\"\xE9\"}".b)).to eq([ "not_utf8", "", reason ])
      expect(refusal_of("{")).to eq([ "not_json", "", reason ])
      expect(refusal_of('{"a":1,"a":2}')).to eq([ "not_json", "", reason ])
      expect(refusal_of("\xEF\xBB\xBF{}".b)).to eq([ "not_json", "", reason ])
    end

    it "refuses JSON that isn't an export", :aggregate_failures do
      reason = "This file isn't a Collector export."
      expect(refusal_of([])).to eq([ "type", "", reason ])
      expect(refusal_of(file([]).except("format"))).to eq([ "required", "/format", reason ])
      expect(refusal_of(file([], format: "other-export"))).to eq([ "const", "/format", reason ])
    end

    it "refuses a file that doesn't say its version", :aggregate_failures do
      reason = "This file doesn't say which version of the export format it follows."
      expect(refusal_of(file([]).except("format_version"))).to eq([ "required", "/format_version", reason ])
      [ "1", 0, -1, 1.5, nil ].each do |version|
        expect(refusal_of(file([], format_version: version))).to eq([ "const", "/format_version", reason ]), version.inspect
      end
    end

    it "refuses a newer version as newer, before the schema (AC-3.2)", :aggregate_failures do
      expect(refusal_of(file([], format_version: 5).except("lots", "profile"))).to eq(
        [ "newer_version", "/format_version", "This file was written by a newer version of Collector (format version 5). This instance reads version 4." ])
      expect(refusal_of(file([], format_version: 5.0)).first).to eq("newer_version")
      expect(import(file([], format_version: 1.0))).not_to be_refused
    end

    it "names the first field outside the lots that isn't well-formed, in the file's order", :aggregate_failures do
      expect(refusal_of(file([], profile: { "name" => " ", "email_address" => "a@b.test", "collection_view" => "grid" }, currency: "usd")))
        .to eq([ "pattern", "/profile/name", "This file isn't a well-formed export: profile.name isn't valid." ])
      expect(refusal_of(file([], exported_at: "2026-02-30T00:00:00Z")))
        .to eq([ "not_a_time", "/exported_at", "This file isn't a well-formed export: exported_at isn't a real moment." ])
      expect(refusal_of(file([]).except("lots"))).to eq([ "required", "/lots", "This file isn't a well-formed export: lots is missing." ])
      expect(refusal_of(file({}))).to eq([ "type", "/lots", "This file isn't a well-formed export: lots isn't valid." ])
    end

    it "reads a file in another supported currency, even with no lots (spec 038 decision 7, AC-6.2)", :aggregate_failures do
      parsed = import(file([], currency: "EUR"))
      expect(parsed).not_to be_refused
      expect(parsed.plan.currency_change).to eq(CollectionImport::CurrencyChange.new(from: "USD", to: "EUR"))
    end

    it "has no currency change for a file in the account's own currency (spec 038 AC-6.1)", :aggregate_failures do
      account.update!(currency: "EUR")
      parsed = import(file([], currency: "EUR"))
      expect([ parsed.refused?, parsed.plan.currency_change ]).to eq([ false, nil ])
    end

    it "refuses a well-formed currency this instance can't show (spec 038 AC-6.6)", :aggregate_failures do
      expect(refusal_of(file([], currency: "XYZ"))).to eq([ "unsupported_currency", "/currency", "Collector can't show prices in XYZ." ])
      expect(refusal_of(file([], currency: "EURO")).first(2)).to eq([ "pattern", "/currency" ])
      expect(refusal_of(file([], currency: "xyz")).first(2)).to eq([ "pattern", "/currency" ])
    end

    it "reports the rule and place problems.json names for each example refused as a whole (AC-2.7)" do
      named = JSON.parse(Rails.root.join("docs/export-format/examples/problems.json").read).reject { |_name, entry| entry["at"].start_with?("/lots/") }
      found = named.to_h do |name, _entry|
        refusal = import(Rails.root.join("docs/export-format/examples", name).binread).refusal
        [ name, refusal && { "rule" => refusal.rule, "at" => refusal.at } ]
      end

      expect(found).to eq(named.transform_values { |entry| entry.slice("rule", "at") })
    end
  end

  describe "what applying would do (decision 1)" do
    it "counts lots added, changed, unchanged and removed, with their copies (AC-1.2)", :aggregate_failures do
      a, b, c, d, e = Array.new(5) { printing }
      held(a, quantity: 3)
      held(b, quantity: 2)
      held(c, quantity: 4)
      held(d, quantity: 7)
      preview = import(file([ row(a, quantity: 3), row(b, quantity: 5), row(c, quantity: 4, changed_at: "2026-10-02T10:00:00Z"), row(e, quantity: 6) ]))

      expect(preview).to be_applicable
      expect(preview.added).to eq(described_class::Tally.new(lots: 1, copies: 6))
      expect(preview.changed).to eq(described_class::Tally.new(lots: 2, copies: 6, copies_after: 9))
      expect(preview.unchanged).to eq(described_class::Tally.new(lots: 1, copies: 3))
      expect(preview.removed).to eq(described_class::Tally.new(lots: 1, copies: 7))
      expect(preview.held).to eq(described_class::Tally.new(lots: 0, copies: 0))
      expect(preview.removed_lots.map(&:name)).to eq([ d.name ])
    end

    it "says what applying would do with each row and which lot it matches (FR-1)", :aggregate_failures do
      a, b, e = Array.new(3) { printing }
      lot_a = held(a, quantity: 3)
      lot_b = held(b, quantity: 2)
      preview = import(file([ row(a, quantity: 3), row(b, quantity: 5), row(e, quantity: 6), stranger ]))

      expect(preview.rows.map { |each_row| preview.row_outcome(each_row) }).to eq([ :unchanged, :changed, :added, nil ])
      expect(preview.rows.first(3).map { |each_row| preview.held_lot_for(each_row)&.id }).to eq([ lot_a.id, lot_b.id, nil ])
      expect([ preview.all_removed_lots, preview.lots_held_by_problem_rows ]).to eq([ [], [] ])
    end

    it "previews a collection's own export as unchanged (AC-1.3)", :aggregate_failures do
      held(printing, quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 1250)
      held(printing, quantity: 1)
      preview = import(CollectionExport.new(account:, at: Time.current).to_json)

      expect(preview).to be_applicable
      expect([ preview.added.lots, preview.changed.lots, preview.unchanged.lots, preview.removed.lots ]).to eq([ 0, 0, 2, 0 ])
    end

    it "adds every row to an empty collection (AC-1.4)" do
      expect(import(file(Array.new(3) { row(printing) })).added).to eq(described_class::Tally.new(lots: 3, copies: 3))
    end

    it "removes every lot for a file with none (AC-1.5)", :aggregate_failures do
      held(printing(name: "Opt"), quantity: 1)
      held(printing(name: "Brainstorm"), quantity: 2)
      preview = import(file([]))

      expect(preview.removed).to eq(described_class::Tally.new(lots: 2, copies: 3))
      expect(preview.removed_lots.map(&:name)).to eq(%w[Brainstorm Opt])
    end

    it "compares times to the second and whole numbers by value (AC-1.6)", :aggregate_failures do
      entry = printing
      create(:lot, account:, entry:, quantity: 4, created_at: Time.utc(2026, 10, 1, 10, 0, 0.75r), updated_at: Time.utc(2026, 10, 2, 11, 0, 0.5r))
      preview = import(file([ row(entry, quantity: 4.0, added_at: "2026-10-01T10:00:00Z", changed_at: "2026-10-02T11:00:00Z") ]))

      expect(preview.unchanged.lots).to eq(1)
      expect(preview.changed.lots).to eq(0)
    end

    it "matches a lot by its finish, condition and price paid as well as its entry" do
      entry = printing
      held(entry, quantity: 1, finish: "foil", price_paid_cents: 1250)
      preview = import(file([ row(entry, finish: "foil", price_paid: "12.50"), row(entry, finish: "nonfoil", price_paid: "12.50") ]))

      expect([ preview.unchanged.lots, preview.added.lots, preview.removed.lots ]).to eq([ 1, 1, 0 ])
    end

    it "holds a lot that a problem row names, rather than removing it (AC-1.11)", :aggregate_failures do
      entry = printing
      held(entry, quantity: 2)
      held(printing, quantity: 5)
      preview = import(file([ row(entry, quantity: 2, added_at: "2026-02-30T00:00:00Z", changed_at: "2026-10-01T10:00:00Z"),
        row(printing).except("entry") ]))

      expect(preview.held).to eq(described_class::Tally.new(lots: 1, copies: 2))
      expect(preview.removed).to eq(described_class::Tally.new(lots: 1, copies: 5))
    end

    it "counts a held lot once when a duplicate row names it too" do
      entry = printing
      held(entry, quantity: 1)
      preview = import(file([ row(entry), row(entry, quantity: 2) ]))

      expect([ preview.unchanged.lots, preview.held.lots, preview.removed.lots ]).to eq([ 1, 0, 0 ])
    end

    it "compares the file with this account's lots only (AC-4.1)", :aggregate_failures do
      entry = printing
      create(:lot, account: create(:user).account, entry:, quantity: 8_888)
      preview = import(file([ row(entry) ]))

      expect(preview.added.lots).to eq(1)
      expect(preview.removed.lots).to eq(0)
    end

    it "lists the first 100 removed lots by name and counts them all (AC-2.8)", :aggregate_failures do
      entry = printing(name: "Opt")
      150.times { |index| create(:lot, account:, entry:, price_paid_cents: index) }
      preview = import(file([]))

      expect(preview.removed.lots).to eq(150)
      expect(preview.removed_lots.size).to eq(100)
      expect(preview.more_removed_lots).to eq(50)
    end
  end

  describe "rows that can't be applied (decision 9)" do
    it "says why a well-formed row doesn't resolve (AC-2.1)", :aggregate_failures do
      known = printing
      preview = import(file([ stranger, stranger(type: "comics"), row(known, finish: "etched"), row(known, condition: "mint"), row(printing) ]))

      expect(preview).not_to be_applicable
      expect(reasons(preview)).to eq(
        1 => [ "Not in this instance's catalog" ], 2 => [ "This instance doesn't collect comics" ],
        3 => [ "This printing doesn't come in etched" ], 4 => [ "mint isn't a condition this instance knows" ])
      expect(preview.problem_rows.flat_map { |row| row.problems.map { |problem| [ problem.rule, problem.at ] } }).to eq([
        %w[not_in_catalog /lots/0/entry/source_id], %w[unknown_type /lots/1/entry/collectible_type],
        %w[finish_not_listed /lots/2/finish], %w[condition_unknown /lots/3/condition] ])
      expect(preview.problem_counts.values).to eq([ 1, 1, 1, 1 ])
      expect(preview.added.lots).to eq(1)
    end

    it "refuses a price that doesn't fit the cents column, as a problem row naming the field (spec 028 1.3.4)", :aggregate_failures do
      fits = row(printing, price_paid: "92233720368547758.07")
      too_big = row(printing, price_paid: "92233720368547758.08")
      preview = import(file([ fits, too_big, row(printing, price_paid: "999999999999999999999999.99") ]))

      expect(preview).not_to be_applicable
      expect(reasons(preview)).to eq(2 => [ "price_paid is too large to record" ], 3 => [ "price_paid is too large to record" ])
      expect(preview.problem_rows.first.problems.first).to have_attributes(rule: "price_too_large", at: "/lots/1/price_paid")
      expect(preview.added.lots).to eq(1)
    end

    it "checks the catalog in order: the type, then the entry, then finish and condition", :aggregate_failures do
      known = printing
      preview = import(file([ stranger(type: "comics", condition: "mint"), stranger(finish: "etched", condition: "mint"),
        row(known, finish: "etched", condition: "mint") ]))

      expect(reasons(preview)).to eq(
        1 => [ "This instance doesn't collect comics" ],
        2 => [ "Not in this instance's catalog", "mint isn't a condition this instance knows" ],
        3 => [ "This printing doesn't come in etched", "mint isn't a condition this instance knows" ])
    end

    it "treats a registered type without a collecting vocabulary as one it doesn't collect", :other_catalog do
      expect(reasons(import(file([ stranger(type: "other") ])))).to eq(1 => [ "This instance doesn't collect other" ])
    end

    it "resolves a retired entry and ignores descriptive fields that disagree (AC-2.2, AC-2.3)" do
      retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
      renamed = row(printing).deep_merge("entry" => { "name" => "Something Else", "set_code" => "zzz", "language" => "ja" })

      expect(import(file([ row(retired), renamed ]))).to be_applicable
    end

    it "says why a row isn't well-formed, and doesn't check it against the catalog (AC-2.4)", :aggregate_failures do
      entry = printing
      preview = import(file([
        row(entry).except("quantity"), row(printing, quantity: 0), row(printing, price_paid: "12.5"),
        row(printing, added_at: "2026-02-30T00:00:00Z", changed_at: "2026-10-01T10:00:00Z"), row(printing, added_at: "2026-10-02T00:00:00Z", changed_at: "2026-10-01T00:00:00Z"),
        row(entry, quantity: 2), 7, stranger(quantity: 0), row(printing)
      ]))

      expect(reasons(preview)).to eq(
        1 => [ "quantity is missing" ], 2 => [ "quantity isn't valid" ], 3 => [ "price_paid isn't valid" ],
        4 => [ "added_at isn't a real moment" ], 5 => [ "changed_at is earlier than added_at" ],
        6 => [ "Same card, finish, condition and price as row 1" ], 7 => [ "This row isn't a lot" ], 8 => [ "quantity isn't valid" ])
      expect(preview.added.lots).to eq(1)
    end

    it "names nested fields with a point" do
      expect(reasons(import(file([ row(printing).tap { |lot| lot["entry"].delete("source_id") } ])))).to eq(1 => [ "entry.source_id is missing" ])
    end

    it "shows every reason a row has (AC-2.5)" do
      expect(reasons(import(file([ row(printing, quantity: 0, price_paid: "1") ])))).to eq(1 => [ "quantity isn't valid", "price_paid isn't valid" ])
    end

    it "lists the first 100 problem rows and counts them all, by reason (AC-2.8)", :aggregate_failures do
      preview = import(file(Array.new(150) { stranger }))

      expect(preview.listed_problem_rows.map(&:number)).to eq((1..100).to_a)
      expect(preview.more_problem_rows).to eq(50)
      expect(preview.problem_counts).to eq("Not in this instance's catalog" => 150)
    end

    it "counts duplicates under one reason" do
      entry = printing
      preview = import(file([ row(entry), row(entry, quantity: 2), row(entry, quantity: 3) ]))

      expect(preview.problem_counts).to eq("Same card, finish, condition and price as an earlier row" => 2)
    end

    it "describes a row by the strings the file gives", :aggregate_failures do
      described = import(file([ stranger("x", finish: "foil", price_paid: 3) ])).problem_rows.first

      expect(described.name).to be_a(String)
      expect(described.described.values_at(:finish, :price_paid)).to eq([ "foil", nil ])
    end
  end

  describe "the profile (decision 4, AC-1.7)" do
    it "says nothing when the file's profile agrees", :aggregate_failures do
      preview = import(file([]))

      expect([ preview.view_change, preview.other_name, preview.other_email_address ]).to eq([ nil, nil, nil ])
    end

    it "gives the view a file would change to, and the file's own name and email address when they differ", :aggregate_failures do
      preview = import(file([], profile: { "name" => "Ada Example", "email_address" => "ada@example.test", "collection_view" => "table" }))

      expect([ preview.view_change, preview.other_name, preview.other_email_address ]).to eq([ "table", "Ada Example", "ada@example.test" ])
    end

    it "ignores a view the instance doesn't know" do
      expect(import(file([], profile: { "name" => user.name, "email_address" => user.email_address, "collection_view" => "gallery" })).view_change).to be_nil
    end
  end

  describe "#unloaded_catalog_titles (AC-2.6)" do
    it "names the unloaded catalogs of the types the file names", :aggregate_failures do
      preview = import(file([ row(printing), stranger(type: "comics") ]))
      expect(preview.unloaded_catalog_titles).to eq([ Catalog.title_for("mtg") ])

      create(:catalog_refresh_run, collectible_type: "mtg", status: "applied")
      expect(preview.unloaded_catalog_titles).to eq([])
    end
  end

  it "writes nothing (FR-6)" do
    entry = printing
    held(entry, quantity: 1)
    data = file([ row(entry, quantity: 3), stranger ])

    expect { import(data).then { |preview| [ preview.added, preview.removed_lots, preview.problem_counts ] } }
      .not_to(change { [ Lot.count, Lot.maximum(:updated_at), Catalog::Entry.count, User.maximum(:updated_at) ] })
  end

  # A version 2 file: the same, with its locations by name (spec 029).
  def file_v2(lots, locations: [], **fields) = file(lots, format_version: 2, locations: locations.map { |name| { "name" => name } }, **fields)

  def location_names(preview) = [ preview.locations.added, preview.locations.renamed.map(&:name), preview.locations.removed.map(&:name) ]

  describe "version 2 (spec 029 decision 10)" do
    it "reads version 1 and version 2, each against its own schema (AC-8.1)", :aggregate_failures do
      expect(import(file([]))).not_to be_refused
      expect(import(file_v2([]))).not_to be_refused
      expect(import(file_v2([], format_version: 2.0))).not_to be_refused
      expect(refusal_of(file([]).merge("format_version" => 2))).to eq([ "required", "/locations", "This file isn't a well-formed export: locations is missing." ])
    end

    it "refuses a bad locations list whole, naming the field and the reason (AC-8.5, P6)", :aggregate_failures do
      expect(refusal_of(file_v2([]).except("locations"))).to eq([ "required", "/locations", "This file isn't a well-formed export: locations is missing." ])
      expect(refusal_of(file_v2([]).merge("locations" => "Box")).last).to eq("This file isn't a well-formed export: locations isn't valid.")
      expect(refusal_of(file_v2([], locations: [ "Box", "a  b" ]))).to eq([ "pattern", "/locations/1/name", "This file isn't a well-formed export: locations.1.name isn't valid." ])
      expect(refusal_of(file_v2([], locations: [ "Box", "box" ]))).to eq(
        [ "duplicate_location", "/locations/1", "This file isn't a well-formed export: locations.1 has the same name as an earlier location, ignoring case." ])
      expect(refusal_of(file_v2([], locations: [ "Café", "Cafe\u0301" ])).first).to eq("duplicate_location")
      expect(refusal_of(file_v2([], locations: Array.new(501) { |index| "Binder #{index}" })).first(2)).to eq([ "maxItems", "/locations" ])
    end

    it "refuses a name whose normal form is over 60 code points, as a whole (AC-8.5)", :aggregate_failures do
      name = "#{"本" * 59}\u0344" # well-formed as written (60 code points); NFC is 61 (a CJK character composes with nothing)
      expect(ExportFormat::Rules.problems(JSON.generate(file_v2([], locations: [ name ])))).to eq([])

      expect(refusal_of(file_v2([], locations: [ name ]))).to eq(
        [ "maxLength", "/locations/0/name", "This file isn't a well-formed export: locations.0.name isn't valid." ])
    end

    it "reads a name in NFD as its NFC spelling, matching a held location of that name (AC-9.18)", :aggregate_failures do
      create(:location, account:, name: "Café")
      create(:location, account:, name: "Old crate")
      preview = import(file_v2([], locations: [ "Cafe\u0301", "Straße" ]))

      expect(preview.locations.unchanged).to eq(1)
      expect(location_names(preview)).to eq([ [ "Straße" ], [], [ "Old crate" ] ])
    end

    it "judges the lots of a version 2 file as it does a version 1 file's (AC-8.7)", :aggregate_failures do
      a = printing
      held(a, quantity: 3)
      one = import(file([ row(a, quantity: 5), stranger ]))
      two = import(file_v2([ row(a, quantity: 5), stranger ], locations: [ "Box" ]))

      expect(two.problem_rows.map(&:number)).to eq(one.problem_rows.map(&:number))
      expect([ two.added, two.changed, two.unchanged, two.removed, two.held ]).to eq([ one.added, one.changed, one.unchanged, one.removed, one.held ])
    end

    it "has no outcomes for locations in a version 1 file, whatever the account holds (AC-8.4, AC-9.3)", :aggregate_failures do
      create(:location, account:, name: "Box")
      preview = import(file([]))

      expect(preview.locations.counted?).to be(false)
      expect(preview.plan.nothing_to_change?).to be(true)
    end

    it "reads the locations from the account only (AC-9.13)", :aggregate_failures do
      create(:location, name: "Elsewhere")
      create(:location, account:, name: "Mine")

      expect(location_names(import(file_v2([], locations: [ "Mine" ])))).to eq([ [], [], [] ])
      expect(location_names(import(file_v2([], locations: [])))).to eq([ [], [], [ "Mine" ] ])
    end
  end

  # A version 3 file (spec 032): its lots say where they are.
  def row_in(entry, location, **options) = row(entry, **options).merge("location" => location)

  def file_v3(lots, locations: [], **fields) = file(lots, format_version: 3, locations: locations.map { |name| { "name" => name } }, **fields)

  def removed_lines(preview) = preview.removed_lots.map { |lot| [ lot.location, lot.quantity ] }

  describe "version 3 (spec 032 decision 7)" do
    it "reads versions 1, 2 and 3, each against its own schema (AC-10.1)", :aggregate_failures do
      expect(import(file_v3([]))).not_to be_refused
      expect(import(file_v3([], format_version: 3.0))).not_to be_refused
      expect(reasons(import(file_v2([ row(printing) ]).merge("format_version" => 3)))).to eq(1 => [ "location is missing" ])
    end

    it "matches a held lot on printing, finish, condition, price paid and location, 'box' being 'Box' (AC-10.2)", :aggregate_failures do
      a = printing
      create(:location, account:, name: "Box")
      held(a, quantity: 2, location: account.locations.first)
      same = import(file_v3([ row_in(a, "box", quantity: 2) ], locations: [ "box" ]))
      elsewhere = import(file_v3([ row_in(a, nil, quantity: 2) ], locations: [ "box" ]))

      expect([ same.unchanged.lots, same.added.lots, same.removed.lots ]).to eq([ 1, 0, 0 ])
      expect([ elsewhere.unchanged.lots, elsewhere.added.lots, elsewhere.removed.lots ]).to eq([ 0, 1, 1 ])
    end

    it "makes a problem row of a lot whose location the file doesn't list, holding back the lot it matches (AC-10.3)", :aggregate_failures do
      a = printing
      create(:location, account:, name: "Box")
      lot = held(a, quantity: 2, location: account.locations.first)
      preview = import(file_v3([ row_in(a, "Box", quantity: 2) ], locations: [ "Crate" ]))

      expect(preview).not_to be_applicable
      expect(reasons(preview)).to eq(1 => [ "Its location “Box” isn't one of the file's locations." ])
      expect(preview.removed.lots).to eq(0)
      expect(preview.held.lots).to eq(1)
      expect(preview.lots_held_by_problem_rows.map(&:id)).to eq([ lot.id ])
    end

    it "reads a version 1 or 2 file's lots as unplaced: they match unplaced held lots only (AC-10.4, AC-10.5)", :aggregate_failures do
      a = printing
      b = printing
      create(:location, account:, name: "Box")
      held(a, quantity: 2, location: account.locations.first)
      held(b, quantity: 3)
      held(b, quantity: 1, finish: "foil", location: account.locations.first)
      [ import(file([ row(a, quantity: 2), row(b, quantity: 4), row(b, quantity: 1, finish: "foil") ])),
        import(file_v2([ row(a, quantity: 2), row(b, quantity: 4), row(b, quantity: 1, finish: "foil") ], locations: [ "Box" ])) ].each do |preview|
        expect([ preview.added.lots, preview.changed.lots, preview.unchanged.lots, preview.removed.lots ]).to eq([ 2, 1, 0, 2 ])
        expect(removed_lines(preview)).to contain_exactly([ "Box", 2 ], [ "Box", 1 ])
      end
    end

    it "has nothing to change for the account's own version 3 file (AC-10.6)", :aggregate_failures do
      a = printing
      create(:location, account:, name: "Box")
      held(a, quantity: 2, location: account.locations.first)
      held(a, quantity: 5)
      preview = import(file_v3([ row_in(a, "Box", quantity: 2), row_in(a, nil, quantity: 5) ], locations: [ "Box" ]))

      expect(preview.plan.nothing_to_change?).to be(true)
    end

    it "adds one lot and removes one for a file that moves a lot between places, naming the place it leaves (AC-10.7)", :aggregate_failures do
      a = printing
      create(:location, account:, name: "Long box")
      create(:location, account:, name: "Blue binder")
      held(a, quantity: 2, location: account.locations.find_by!(name: "Long box"))
      preview = import(file_v3([ row_in(a, "Blue binder", quantity: 2) ], locations: [ "Long box", "Blue binder" ]))

      expect(preview).to be_applicable
      expect([ preview.added.lots, preview.removed.lots, preview.changed.lots ]).to eq([ 1, 1, 0 ])
      expect(removed_lines(preview)).to eq([ [ "Long box", 2 ] ])
    end

    it "lists a rename and changes no lot (AC-10.8)", :aggregate_failures do
      a = printing
      location = create(:location, account:, name: "box")
      held(a, quantity: 2, location:)
      preview = import(file_v3([ row_in(a, "Box", quantity: 2) ], locations: [ "Box" ]))

      expect(location_names(preview)).to eq([ [], [ "Box" ], [] ])
      expect([ preview.added.lots, preview.removed.lots, preview.changed.lots, preview.unchanged.lots ]).to eq([ 0, 0, 0, 1 ])
    end

    it "carries the file's location on a problem row (AC-10.9)", :aggregate_failures do
      a = printing
      preview = import(file_v3([ row_in(a, "Box", quantity: 2, finish: "etched") ], locations: [ "Box" ]))

      expect(preview.problem_rows.sole.described).to include(location: "Box")
    end

    it "words a duplicate row of a version 3 file with the location, and keeps the older wording (AC-9.5)", :aggregate_failures do
      a = printing
      three = import(file_v3([ row_in(a, "Box"), row_in(a, "box") ], locations: [ "Box" ]))
      one = import(file([ row(a), row(a) ]))

      expect(reasons(three)).to eq(2 => [ "Same card, finish, condition, price and location as row 1" ])
      expect(reasons(one)).to eq(2 => [ "Same card, finish, condition and price as row 1" ])
    end

    it "lists every lot of a location the file drops as removed, with the location (AC-10.10)", :aggregate_failures do
      a = printing
      create(:location, account:, name: "Box")
      held(a, quantity: 2, location: account.locations.first)
      preview = import(file_v3([], locations: []))

      expect(removed_lines(preview)).to eq([ [ "Box", 2 ] ])
      expect(location_names(preview)).to eq([ [], [], [ "Box" ] ])
    end

    it "reads only its own account's lots and locations (AC-10.11)", :aggregate_failures do
      a = printing
      other = create(:user).account
      theirs = create(:location, account: other, name: "Box")
      create(:lot, account: other, entry: a, quantity: 9, location: theirs)
      preview = import(file_v3([ row_in(a, "Box", quantity: 9) ], locations: [ "Box" ]))

      expect([ preview.added.lots, preview.removed.lots, preview.unchanged.lots ]).to eq([ 1, 0, 0 ])
    end
  end

  # A version 4 file (spec 062): its decks beside its places, and a lot's location may be a deck's zone.
  def file_v4(lots, locations: [], decks: [], **fields)
    file(lots, format_version: 4, locations: locations.map { |name| { "name" => name } }, decks: decks.map { |deck| deck_in_file(deck) }, **fields)
  end

  # A deck of a file: a name alone is a Casual deck of the one collectible this suite registers; a hash is taken as written.
  def deck_in_file(deck) = deck.is_a?(Hash) ? deck.stringify_keys : { "name" => deck, "collectible_type" => "mtg", "format" => "modern" }

  def zone(deck, key) = { "deck" => deck, "zone" => key }

  def refusal_rules(data) = refusal_of(data).first

  describe "version 4 (spec 062 Story 6 and Story 7)" do
    it "reads version 4 against its own schema, decks and all (AC-6.7a)", :aggregate_failures do
      expect(import(file_v4([], decks: [ "Izzet Tempo" ]))).not_to be_refused
      expect(import(file_v4([], decks: [ "Izzet Tempo" ], format_version: 4.0))).not_to be_refused
      expect(refusal_of(file_v4([]).except("decks"))).to eq([ "required", "/decks", "This file isn't a well-formed export: decks is missing." ])
    end

    it "refuses a schema problem in the decks as a whole, at its pointer, and reads no row (AC-7.8)", :aggregate_failures do
      a = printing
      broken = file_v4([ row(a) ], decks: [ { "name" => "Izzet Tempo", "collectible_type" => "mtg" } ])
      preview = import(broken)

      expect([ preview.refusal.rule, preview.refusal.at ]).to eq([ "required", "/decks/0/format" ])
      expect(preview.rows).to eq([])
      expect(refusal_of(file_v4([], decks: [ "a" * 61 ])).first(2)).to eq([ "maxLength", "/decks/0/name" ])
    end

    it "refuses places and decks over 500 together as too_many_locations at /decks, and no row (AC-7.8)", :aggregate_failures do
      preview = import(file_v4([ row(printing) ], locations: Array.new(300) { |n| "Binder #{n}" }, decks: Array.new(201) { |n| "Deck #{n}" }))

      expect([ preview.refusal.rule, preview.refusal.at, preview.rows ]).to eq([ "too_many_locations", "/decks", [] ])
    end

    it "refuses a deck name over 60 code points once normalised, before the currency (AC-6.7b)", :aggregate_failures do
      name = "#{"本" * 59}\u0344" # 60 code points as written; NFC is 61
      expect(ExportFormat::Rules.problems(JSON.generate(file_v4([], decks: [ name ])))).to eq([ ExportFormat::Rules::Problem.new("maxLength", "/decks/0/name") ])

      expect(refusal_of(file_v4([], decks: [ name ], currency: "XYZ"))).to eq(
        [ "maxLength", "/decks/0/name", "This file isn't a well-formed export: decks.0.name isn't valid." ])
    end

    it "refuses a deck whose format or collectible type this instance doesn't register, as a whole (AC-6.11)", :aggregate_failures do
      a = printing
      expect(refusal_of(file_v4([ row(a) ], decks: [ "Izzet Tempo", { "name" => "Odd", "collectible_type" => "mtg", "format" => "nope" } ]))).to eq(
        [ "unknown_format", "/decks/1/format", "This instance doesn't know the format “nope” of mtg." ])
      expect(refusal_of(file_v4([], decks: [ { "name" => "Odd", "collectible_type" => "comics", "format" => "modern" } ]))).to eq(
        [ "unknown_format", "/decks/0/format", "This instance doesn't know the format “modern” of comics." ])
      expect(import(file_v4([ row(a) ], decks: [ { "name" => "Odd", "collectible_type" => "comics", "format" => "modern" } ])).rows).to eq([])
    end

    it "judges unsupported_currency before unknown_format (AC-7.4e)" do
      data = file_v4([], decks: [ { "name" => "Odd", "collectible_type" => "mtg", "format" => "nope" } ], currency: "XYZ")

      expect(refusal_rules(data)).to eq("unsupported_currency")
    end

    it "makes a problem row of a lot in a zone its deck's format lacks, naming the deck and the key as the lot spells them (AC-6.10, AC-6.7a)", :aggregate_failures do
      a = printing
      preview = import(file_v4([ row_in(a, zone("IZZET TEMPO", "commander")), row_in(a, zone("Izzet Tempo", "main"), finish: "foil") ], decks: [ "Izzet Tempo" ]))
      problem = preview.problem_rows.sole.problems.sole

      expect(preview).not_to be_refused
      expect(preview.problem_rows.map(&:number)).to eq([ 1 ])
      expect([ problem.rule, problem.at, problem.reason ]).to eq(
        [ "unknown_zone", "/lots/0/location/zone", "The deck “IZZET TEMPO” has no zone “commander” in its format." ])
    end

    it "makes a problem row of a lot naming a deck the file doesn't list, with the reason of a deck (AC-6.10, AC-6.7a)", :aggregate_failures do
      a = printing
      preview = import(file_v4([ row_in(a, zone("Nope", "main")) ], decks: [ "Izzet Tempo" ]))
      problem = preview.problem_rows.sole.problems.sole

      expect(preview).not_to be_refused
      expect([ problem.rule, problem.at, problem.reason ]).to eq([ "unknown_location", "/lots/0/location", "Its deck “Nope” isn't one of the file's decks." ])
    end

    it "reads a place's reason as before, in a version 4 file (AC-6.10)" do
      preview = import(file_v4([ row_in(printing, "Box") ], locations: [ "Crate" ]))

      expect(reasons(preview)).to eq(1 => [ "Its location “Box” isn't one of the file's locations." ])
    end

    it "never prints a raw object in a reason (AC-6.7a)", :aggregate_failures do
      a = printing
      preview = import(file_v4([ row_in(a, zone("Nope", "main")), row_in(a, zone("Izzet Tempo", "commander"), finish: "foil"),
                                 row_in(a, { "deck" => "Izzet Tempo", "zone" => 5 }, finish: "nonfoil") ], decks: [ "Izzet Tempo" ]))
      text = preview.problem_rows.flat_map { |row| row.problems.flat_map { |problem| [ problem.reason, problem.summary ] } + [ row.place.to_s ] }.join

      expect(preview.problem_rows.size).to eq(3)
      expect(text).not_to match(/[{}]|=>|"deck"/)
    end

    it "gives a row in a zone the label of its deck, with the zone's name as the format registers it, else its key (AC-7.5)", :aggregate_failures do
      a = printing
      preview = import(file_v4([ row_in(a, zone("izzet tempo", "main")), row_in(a, zone("Izzet Tempo", "considering"), finish: "foil"),
                                 row_in(a, zone("Izzet Tempo", "commander"), finish: "nonfoil"), row_in(a, "Box", condition: "damaged") ],
        locations: [ "Box" ], decks: [ "Izzet Tempo" ]))

      expect(preview.rows.map(&:place)).to eq([ "izzet tempo › Main", "Izzet Tempo › Considering", "Izzet Tempo › commander", "Box" ])
      expect(preview.rows.first.described[:location]).to eq("izzet tempo › Main")
    end

    it "keeps a lot's place out of the row of a version 1 to 3 file, and of a lot that has none (AC-7.4)", :aggregate_failures do
      a = printing
      expect(import(file([ row(a) ])).rows.map(&:place)).to eq([ nil ])
      expect(import(file_v4([ row_in(a, nil) ])).rows.map(&:place)).to eq([ nil ])
    end

    it "identifies a lot in a zone by its deck's comparison key and the zone's key, so the same printing in two decks' Main is two lots (AC-7.4c)", :aggregate_failures do
      a = printing
      izzet = create(:deck, account:, name: "Izzet Tempo")
      elves = create(:deck, account:, name: "Elves", format: "commander")
      held_izzet = create_lot_in_zone(izzet, "main", entry: a, quantity: 2)
      held_elves = create_lot_in_zone(elves, "main", entry: a, quantity: 3)
      [ held_izzet, held_elves ].each { |lot| lot.update_columns(created_at: Time.utc(2026, 10, 1, 10), updated_at: Time.utc(2026, 10, 1, 10)) } # the rows' times
      both = import(file_v4([ row_in(a, zone("Izzet Tempo", "main"), quantity: 2), row_in(a, zone("elves", "main"), quantity: 3) ], decks: [ "Izzet Tempo", { "name" => "Elves", "collectible_type" => "mtg", "format" => "commander" } ]))
      one = import(file_v4([ row_in(a, zone("Izzet Tempo", "main"), quantity: 2) ], decks: [ "Izzet Tempo", { "name" => "Elves", "collectible_type" => "mtg", "format" => "commander" } ]))

      expect(both.rows.map { |row| row.identity.last }).to eq([ [ "izzet tempo", "main" ], [ "elves", "main" ] ])
      expect([ both.unchanged.lots, both.added.lots, both.removed.lots ]).to eq([ 2, 0, 0 ])
      expect(both.rows.map { |row| both.held_lot_for(row).id }).to eq([ held_izzet.id, held_elves.id ])
      expect([ one.unchanged.lots, one.removed.lots ]).to eq([ 1, 1 ])
      expect(one.all_removed_lots.map(&:id)).to eq([ held_elves.id ])
    end

    it "keeps a place called like a zone's key apart from the zone (AC-6.12)", :aggregate_failures do
      a = printing
      place = create(:location, account:, name: "Main")
      create_lot_in_zone(create(:deck, account:, name: "Izzet Tempo"), "main", entry: a)
      held(a, quantity: 2, location: place)
      preview = import(file_v4([ row_in(a, "Main", quantity: 2) ], locations: [ "Main" ], decks: [ "Izzet Tempo" ]))

      expect([ preview.unchanged.lots, preview.added.lots, preview.removed.lots ]).to eq([ 1, 0, 1 ])
      expect(preview.removed_lots.map(&:location)).to eq([ "Izzet Tempo › Main" ])
    end

    it "has the account's own export as lots with nothing to change, decks counted (AC-7.4c)", :aggregate_failures do
      a = printing
      izzet = create(:deck, account:, name: "Izzet Tempo")
      create_lot_in_zone(izzet, "main", entry: a, quantity: 2)
      create_lot_in_zone(izzet, "sideboard", entry: a, quantity: 1)
      data = JSON.parse(CollectionExport.new(account:, at: Time.utc(2026, 11, 10)).to_json)
      preview = import(data)

      expect([ preview.unchanged.lots, preview.added.lots, preview.removed.lots, preview.changed.lots ]).to eq([ 2, 0, 0, 0 ])
      expect([ preview.decks.counted?, preview.decks.unchanged, preview.decks.nothing_to_change? ]).to eq([ true, 1, true ])
    end

    it "reads the decks of the account only (AC-7.2)" do
      create(:deck, name: "Elsewhere")
      create(:deck, account:, name: "Mine")

      expect(import(file_v4([], decks: [ "Mine" ])).decks.counts).to eq(added: 0, renamed: 0, format_changed: 0, unchanged: 1, removed: 0)
    end

    it "says the file lists places and decks (AC-7.4)", :aggregate_failures do
      expect([ import(file([])).places?, import(file_v3([])).places?, import(file_v4([])).places? ]).to eq([ false, true, true ])
      expect([ import(file([])).decks_counted?, import(file_v3([])).decks_counted?, import(file_v4([])).decks_counted? ]).to eq([ false, false, true ])
    end

    it "writes nothing and enqueues nothing for a file with decks and zone lots (AC-7.9)", :aggregate_failures do
      a = printing
      create(:deck, account:, name: "Held deck")
      data = file_v4([ row_in(a, zone("Izzet Tempo", "main")), row_in(a, zone("Nope", "main"), finish: "foil") ], decks: [ "Izzet Tempo" ])
      writes = []
      counter = ->(*, payload) { writes << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)/i) }

      expect do
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          preview = import(data)
          [ preview.plan, preview.decks.counts, preview.removed_lots, preview.problem_counts ]
        end
      end.not_to have_enqueued_job
      expect(writes).to eq([])
    end
  end

  describe "a version 1 to 3 file and the decks held (spec 062 AC-7.4)" do
    let!(:izzet) { create(:deck, account:, name: "Izzet Tempo") }

    it "says nothing of decks: they aren't counted, the lots of the file are in places or none (AC-7.4)", :aggregate_failures do
      a = printing
      [ file([ row(a) ]), file_v2([ row(a) ]), file_v3([ row_in(a, nil) ]) ].each do |data|
        preview = import(data)
        expect(preview).not_to be_refused
        expect(preview.decks.counted?).to be(false)
        expect(preview.rows.map(&:place)).to eq([ nil ])
      end
    end

    it "lists a held lot in a zone as removed, with its label, since no row of such a file matches it (AC-7.4)", :aggregate_failures do
      a = printing
      create_lot_in_zone(izzet, "main", entry: a, quantity: 3)
      held(a, quantity: 1)
      [ import(file([ row(a) ])), import(file_v3([ row_in(a, nil) ])) ].each do |preview|
        expect(removed_lines(preview)).to eq([ [ "Izzet Tempo › Main", 3 ] ])
        expect([ preview.unchanged.lots, preview.removed.lots ]).to eq([ 1, 1 ])
      end
    end

    it "refuses a version 2 or 3 file with a place that has a held deck's comparison key, at the place (AC-7.4a)", :aggregate_failures do
      reason = "A deck you have is called “Izzet Tempo”, like a place in this file. Rename one of them and preview again."
      expect(refusal_of(file_v2([], locations: [ "Box", "IZZET tempo" ]))).to eq([ "deck_name_taken", "/locations/1", reason ])
      expect(refusal_of(file_v3([], locations: [ "izzet tempo" ]))).to eq([ "deck_name_taken", "/locations/0", reason ])
      expect(refusal_of(file_v3([], locations: [ "Izzet Tempo" ]))).to eq([ "deck_name_taken", "/locations/0", reason ])
    end

    it "never refuses a version 1 file for a deck, which has no places (AC-7.4a)" do
      expect(import(file([]))).not_to be_refused
    end

    it "reads the name of a place in NFD as its stored spelling when it meets a deck (AC-7.4a)" do
      create(:deck, account:, name: "Café")

      expect(refusal_of(file_v3([], locations: [ "Cafe\u0301" ])).first(2)).to eq([ "deck_name_taken", "/locations/0" ])
    end

    it "refuses a version 2 or 3 file whose places and the held decks would pass 500, as a whole (AC-7.4b)", :aggregate_failures do
      create(:deck, account:, name: "Elves")
      reason = "This file and your decks together would have more than 500 locations."
      names = Array.new(499) { |n| "Binder #{n}" }

      expect(refusal_of(file_v2([], locations: names))).to eq([ "too_many_with_decks", "/locations", reason ])
      expect(refusal_of(file_v3([ row_in(printing, nil) ], locations: names)).first).to eq("too_many_with_decks")
      expect(import(file_v3([], locations: names.first(498)))).not_to be_refused
    end

    it "does not refuse the same file for an account without decks, and never a version 1 file (AC-7.4b)", :aggregate_failures do
      create(:deck, account:, name: "Elves")
      other = create(:user).account
      big = file_v3([], locations: Array.new(500) { |n| "Binder #{n}" })

      expect(described_class.new(account: other, file: StringIO.new(JSON.generate(big)))).not_to be_refused
      expect(import(file([]))).not_to be_refused
    end

    it "judges the file's own places, not the places held (AC-7.4b)" do
      create(:deck, account:, name: "Elves")
      30.times { |n| create(:location, account:, name: "Held #{n}") }

      expect(import(file_v3([], locations: [ "Only one" ]))).not_to be_refused
    end

    it "decides deck_name_taken before too_many_with_decks, and unsupported_currency before either (AC-7.4e)", :aggregate_failures do
      create(:deck, account:, name: "Elves")
      names = Array.new(499) { |n| "Binder #{n}" } + [ "izzet tempo" ]
      data = file_v3([], locations: names)

      expect(refusal_rules(data)).to eq("deck_name_taken")
      expect(refusal_rules(data.merge("currency" => "XYZ"))).to eq("unsupported_currency")
    end

    it "reads nothing of another account's decks (AC-7.4a)" do
      other = create(:user).account
      create(:deck, account: other, name: "Elsewhere")

      expect(described_class.new(account: other, file: StringIO.new(JSON.generate(file_v3([], locations: [ "Izzet Tempo" ]))))).not_to be_refused
    end

    it "writes nothing when it refuses (AC-7.4a)" do
      data = file_v3([ row_in(printing, nil) ], locations: [ "Izzet Tempo" ])

      expect { import(data) }.not_to(change { [ Location.count, Deck.count, Lot.count, Location.maximum(:updated_at) ] })
    end
  end
end
