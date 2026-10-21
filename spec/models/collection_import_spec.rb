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
      expect(refusal_of(file([], format_version: 3).except("lots", "profile"))).to eq(
        [ "newer_version", "/format_version", "This file was written by a newer version of Collector (format version 3). This instance reads version 2." ])
      expect(refusal_of(file([], format_version: 3.0)).first).to eq("newer_version")
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

    it "refuses a file in another currency, even with no lots (decision 3)" do
      expect(refusal_of(file([], currency: "EUR"))).to eq([ "other_currency", "/currency", "This file's prices are in EUR. This instance uses USD." ])
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
end
