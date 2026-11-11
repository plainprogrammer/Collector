require "rails_helper"

# Spec 025 decision 5 (ADR 0021): the export format's well-formedness rules as the app applies them.
RSpec.describe ExportFormat::Rules, type: :model do
  def examples(kind)
    Rails.root.glob("docs/export-format/examples/#{kind}/*.json").sort.to_h { |file| [ "#{kind}/#{file.basename}", file.binread ] }
  end

  def base = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/base.json").read)

  def problems_of(data) = described_class.problems(JSON.generate(data)).map { |problem| [ problem.rule, problem.at ] }

  it "keeps a byte-identical copy of every documented schema (ADR 0021)", :aggregate_failures do
    documented = Rails.root.glob("docs/export-format/v*.schema.json")
    copies = documented.map { |file| described_class::SCHEMA_DIRECTORY.join(file.basename) }

    expect(documented.map(&:basename).map(&:to_s)).to include("v1.schema.json", "v2.schema.json", "v3.schema.json", "v4.schema.json")
    expect(copies.map { |copy| copy.exist? && copy.binread }).to eq(documented.map(&:binread))
  end

  it "reports exactly what examples/problems.json names for each invalid example (AC-2.7)" do
    named = JSON.parse(Rails.root.join("docs/export-format/examples/problems.json").read)
    found = examples("invalid").transform_values { |bytes| described_class.problems(bytes).map { |problem| problem.to_h.stringify_keys } }

    expect(found).to eq(named.transform_values { |entry| [ entry.slice("rule", "at") ] })
  end

  it "finds nothing wrong with the valid and comparison examples (AC-2.7)" do
    found = examples("valid").merge(examples("comparison")).transform_values { |bytes| described_class.problems(bytes) }

    expect(found.reject { |_name, problems| problems.empty? }).to be_empty
  end

  it "reads a whole number written with a zero fraction" do
    data = base
    data["format_version"] = 1.0
    data["lots"][0]["quantity"] = 4.0

    expect(problems_of(data)).to eq([])
  end

  it "checks the times of a lot whose other fields fail the schema" do
    data = base
    data["lots"][0]["quantity"] = 0
    data["lots"][0]["added_at"] = "2026-02-30T00:00:00Z"

    expect(problems_of(data)).to eq([ %w[minimum /lots/0/quantity], %w[not_a_time /lots/0/added_at] ])
  end

  it "leaves a time that fails the schema to the schema" do
    data = base
    data["lots"][0]["added_at"] = "2026-02-30"

    expect(problems_of(data)).to eq([ %w[pattern /lots/0/added_at] ])
  end

  it "compares only real moments when it looks for a lot changed before it was added" do
    data = base
    data["lots"][0]["added_at"] = "2026-02-30T00:00:00Z"
    data["lots"][0]["changed_at"] = "2026-01-01T00:00:00Z"

    expect(problems_of(data)).to eq([ %w[not_a_time /lots/0/added_at] ])
  end

  it "finds the duplicate of a lot whose quantity fails the schema" do
    data = base
    data["lots"] << data["lots"][0].merge("quantity" => 0)

    expect(problems_of(data)).to eq([ %w[minimum /lots/2/quantity], %w[duplicate_lot /lots/2] ])
  end

  it "compares no lot whose identity can't be read" do
    data = base
    data["lots"][0]["price_paid"] = "12.5"
    data["lots"] << data["lots"][0].dup

    expect(problems_of(data)).to eq([ %w[pattern /lots/0/price_paid], %w[pattern /lots/2/price_paid] ])
  end

  it "reports a lot that isn't an object and checks the others" do
    data = base
    data["lots"].unshift(5)
    data["lots"][1]["added_at"] = "2026-02-30T00:00:00Z"

    expect(problems_of(data)).to eq([ %w[type /lots/0], %w[not_a_time /lots/1/added_at] ])
  end

  # The maintainer's ruling of 2026-10-15 (spec 025 decision 13): the whole-file pass held a result tree for every lot
  # at once, so the lots are checked one at a time against $defs/lot. These pin that it finds what the whole-file pass
  # found, in the same order, without the root schema ever seeing a lot.
  describe "checking each lot on its own" do
    # The whole-file pass the rules made before the ruling: the whole schema over the whole file, mapped the same way,
    # then the rules a schema can't state (rule_problems is private; called here as the reference, not stubbed).
    def whole_file_problems(bytes)
      data, problem = described_class.parse(bytes)
      return [ problem ] if problem

      found = JSONSchemer.schema(described_class.schema(described_class.schema_version(data)), regexp_resolver: "ecma").validate(data).flat_map do |error|
        missing = error.dig("details", "missing_keys")
        next missing.map { |key| described_class::Problem.new("required", "#{error["data_pointer"]}/#{key}") } if missing

        [ described_class::Problem.new(described_class::JSON_TYPES.include?(error["type"]) ? "type" : error["type"], error["data_pointer"]) ]
      end
      found + described_class.send(:rule_problems, data, found.to_set(&:at))
    end

    def bad_lots
      data = base
      lots = data["lots"]
      lots[0]["entry"] = 5
      lots[1]["shine"] = "glossy"
      lots << lots[1].except("quantity", "shine").merge("entry" => lots[1]["entry"].merge("source_id" => 7))
      lots << "a lot"
      lots << lots[0].merge("entry" => base["lots"][0]["entry"].except("name"), "price_paid" => "1.5", "added_at" => "2026-02-30T00:00:00Z")
      lots << base["lots"][1]
      data
    end

    def variants
      header = bad_lots.except("currency").merge("profile" => { "name" => 3 }, "exported_at" => "2026-10-11")
      {
        "bad lots" => bad_lots,
        "bad lots and header" => header,
        "no lots and a bad header" => header.merge("lots" => []),
        "lots not an array" => base.merge("lots" => { "0" => base["lots"][0] }),
        "lots missing" => base.except("lots"),
        "lots missing and a bad header" => header.except("lots"),
        "data an array" => [ base ],
        "data a string" => "collector-export",
        "data null" => nil
      }.transform_values { |data| JSON.generate(data) }
    end

    it "finds the same problems, in the same order, as the whole-file pass on every example and variant", :aggregate_failures do
      # The reference pass is a schema alone, so it can't state version 4's count of places and decks together
      # (too_many_locations, spec 062 AC-6.9); those two examples are checked by problems.json and "6.9" below.
      files = examples("valid").merge(examples("invalid"), examples("comparison"), variants).except("invalid/decks-501.json", "invalid/locations-and-decks-501.json")

      files.each do |name, bytes|
        expect(described_class.problems(bytes)).to eq(whole_file_problems(bytes)), name
      end
      expect(described_class.problems(variants["bad lots and header"]).map(&:at)).to include("/lots/3", "/lots/2/entry/source_id", "/currency")
    end

    it "checks a lot against $defs/lot, whose errors prefixed with the lot's place are the whole schema's" do
      data = bad_lots
      whole = described_class.schemer(1).validate(data).map { |error| [ error["type"], error["data_pointer"] ] }
      alone = data["lots"].each_with_index.flat_map do |lot, index|
        described_class.lot_schemer(1).validate(lot).map { |error| [ error["type"], "/lots/#{index}#{error["data_pointer"]}" ] }
      end

      expect(alone).to eq(whole)
    end

    it "never gives the root schema a lot" do
      allow(described_class.schemer(1)).to receive(:validate).and_call_original

      described_class.problems_in(bad_lots)

      expect(described_class.schemer(1)).to have_received(:validate).once.with(bad_lots.merge("lots" => []))
    end
  end

  describe "version 2 (spec 029)" do
    def v2 = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/v2-base.json").read)

    def locations(*names) = v2.merge("locations" => names.map { |name| { "name" => name } })

    it "judges a file against the schema of its own version", :aggregate_failures do
      expect(described_class.schema_version(base)).to eq(1)
      expect(described_class.schema_version(v2)).to eq(2)
      expect(described_class.schema_version(v2.merge("format_version" => 2.0))).to eq(2)
      expect(described_class.schema_version(v2.merge("format_version" => 5))).to eq(1) # a version it doesn't read: the oldest names the version
      expect(described_class.schema_version(base.except("format_version"))).to eq(1)
      expect(described_class.schema_version(base.merge("format_version" => "1"))).to eq(1)
      expect(described_class.schema_version([ v2 ])).to eq(1) # not an object: the oldest judges it, as it always did
      expect(problems_of(v2)).to eq([])
      expect(problems_of(base.merge("format_version" => 2))).to eq([ %w[required /locations] ])
      expect(problems_of(base.except("format_version"))).to eq([ %w[required /format_version] ]) # the version 1 invalid examples keep their one problem
      expect(problems_of(base.merge("format_version" => "1"))).to eq([ %w[const /format_version] ])
      expect(problems_of(v2.merge("format_version" => 5))).to eq([ %w[const /format_version] ])
      expect(problems_of(v2.merge("format_version" => 1))).to eq([]) # an unknown field is ignored by version 1
    end

    it "finds a location problem under its pointer and checks the lots too", :aggregate_failures do
      data = locations("Blue binder", "a  b", "")
      data["lots"][0]["quantity"] = 0

      expect(problems_of(data)).to eq([ %w[pattern /locations/1/name], %w[minLength /locations/2/name], %w[minimum /lots/0/quantity] ])
    end

    it "finds a repeated key at the later location, by case, case folding and normalisation form (AC-7.3)", :aggregate_failures do
      expect(problems_of(locations("box", "Box"))).to eq([ %w[duplicate_location /locations/1] ])
      expect(problems_of(locations("Straße", "STRASSE"))).to eq([ %w[duplicate_location /locations/1] ])
      expect(problems_of(locations("Café", "Cafe\u0301", "CAFE\u0301"))).to eq([ %w[duplicate_location /locations/1], %w[duplicate_location /locations/2] ])
      expect(problems_of(locations("Cafe\u0301"))).to eq([]) # a name in NFD is well-formed
    end

    describe "a list over the limit (spec 029 review M1)" do
      let(:limit) { JSON.parse(Rails.root.join("docs/export-format/v2.schema.json").read).dig("properties", "locations", "maxItems") }

      it "keeps the limit in step with the schema's maxItems and the account's cap" do
        expect(limit).to eq(Location::MAX_PER_ACCOUNT)
      end

      it "reports maxItems without validating or case-folding the items past the limit", :aggregate_failures do
        long = locations(*Array.new(limit + 1_500) { |index| "Binder #{index}" })
        long["locations"][limit + 10] = { "name" => "a  b" } # fails the schema, but lies past the limit

        allow(Location::Name).to receive(:key).and_call_original
        expect(problems_of(long)).to eq([ %w[maxItems /locations] ])
        expect(Location::Name).not_to have_received(:key)
      end

      it "still lists the problems of the first items in a list over the limit" do
        long = locations("a  b", *Array.new(limit) { |index| "Binder #{index}" })

        expect(problems_of(long)).to eq([ %w[pattern /locations/0/name], %w[maxItems /locations] ])
      end

      it "keeps the problems of a list at the limit as they were, and lists no duplicate once the list is refused", :aggregate_failures do
        names = Array.new(limit) { |index| "Binder #{index}" }

        expect(problems_of(locations(*names))).to eq([])
        expect(problems_of(locations(*names, "binder 0"))).to eq([ %w[maxItems /locations] ]) # a refused list needs no duplicate listing
        expect(problems_of(locations(*names.first(limit - 1), "binder 0"))).to eq([ [ "duplicate_location", "/locations/#{limit - 1}" ] ])
      end
    end

    it "compares no location whose name fails the schema, as it compares no lot with an unreadable identity" do
      expect(problems_of(locations("a  b", "a  b"))).to eq([ %w[pattern /locations/0/name], %w[pattern /locations/1/name] ])
    end

    it "reports a location that isn't an object and checks the others" do
      data = v2.merge("locations" => [ 5, { "name" => "Box" }, { "name" => "box" } ])

      expect(problems_of(data)).to eq([ %w[type /locations/0], %w[duplicate_location /locations/2] ])
    end
  end

  describe "version 3 (spec 032)" do
    def v3 = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/v3-base.json").read)

    def placed(*locations, listed: %w[Blue\ binder Trade\ binder])
      data = v3.merge("locations" => listed.map { |name| { "name" => name } })
      data["lots"] = locations.each_with_index.map { |location, index| data["lots"][0].merge("location" => location, "finish" => index.to_s.then { |n| n == "0" ? "foil" : "f#{n}" }) }
      data
    end

    it "reads versions 1 to 4, the newest being the one written", :aggregate_failures do
      expect(described_class::VERSIONS).to eq([ 1, 2, 3, 4 ])
      expect(described_class::VERSION).to eq(4)
      expect(described_class.schema_version(v3)).to eq(3)
      expect(problems_of(v3)).to eq([])
    end

    it "gives a lot six identity values, the sixth the location's comparison key (AC-9.5)", :aggregate_failures do
      lot = v3["lots"][0].merge("location" => "Blue Binder")
      expect(described_class.identity(lot, 3).size).to eq(6)
      expect(described_class.identity(lot, 3).last).to eq("blue binder")
      expect(described_class.identity(lot.merge("location" => nil), 3).last).to be_nil
      expect(described_class.identity(lot, 2)).to eq(described_class.identity(lot.except("location"), 2) + [])
      expect(described_class.identity(lot, 2).last).to be_nil # versions 1 and 2 say nothing about a place
    end

    it "finds a missing, mistyped or ill-formed lot location where the schema says (AC-9.5)", :aggregate_failures do
      one = ->(value) { problems_of(placed("Blue binder").tap { |data| data["lots"][0]["location"] = value }) }
      missing = placed("Blue binder").tap { |data| data["lots"][0].delete("location") }
      expect(problems_of(missing)).to eq([ %w[required /lots/0/location] ])
      expect(one.call(5)).to eq([ %w[type /lots/0/location] ])
      expect(one.call("")).to eq([ %w[minLength /lots/0/location] ])
      expect(one.call("本" * 61)).to eq([ %w[maxLength /lots/0/location] ])
      [ " Blue binder", "Blue  binder", "Blue\tbinder", "Blue\u0007binder" ].each { |bad| expect(one.call(bad)).to eq([ %w[pattern /lots/0/location] ]), bad.inspect }
      expect(one.call(nil)).to eq([])
    end

    it "ignores a location on a lot of a version 1 or 2 file (AC-9.8)", :aggregate_failures do
      v2 = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/v2-base.json").read)
      v2["lots"][0]["location"] = "Anywhere at all"
      expect(problems_of(v2)).to eq([])
      expect(problems_of(base.tap { |data| data["lots"][0]["location"] = 5 })).to eq([])
    end

    it "finds a lot whose location the file's locations don't list, but not one listed in another case or form (AC-9.4)", :aggregate_failures do
      expect(problems_of(placed("Long box"))).to eq([ %w[unknown_location /lots/0/location] ])
      expect(problems_of(placed("BLUE BINDER", "Cafe\u0301", listed: [ "Blue binder", "Café" ]))).to eq([])
    end

    it "finds the repeat of a lot whose location differs only in case, and not one that differs in location (AC-9.5)", :aggregate_failures do
      data = placed("Blue binder", "blue binder")
      data["lots"][1]["finish"] = data["lots"][0]["finish"]
      expect(problems_of(data)).to eq([ %w[duplicate_lot /lots/1] ])
      data["lots"][1]["location"] = "Trade binder"
      expect(problems_of(data)).to eq([])
    end

    it "does not walk a list over the limit again for unknown locations (spec 029 review M1)", :aggregate_failures do
      names = Array.new(501) { |index| "Binder #{index}" }
      data = placed("Binder 500", listed: names)
      allow(Location::Name).to receive(:key).and_call_original
      expect(problems_of(data)).to eq([ %w[maxItems /locations] ])
      expect(Location::Name).not_to have_received(:key).with("binder 500")
    end

    it "judges a version 5 file by version 1's schema, which names the version" do
      expect(problems_of(v3.merge("format_version" => 5))).to eq([ %w[const /format_version] ])
    end

    it "keeps unknown_location among the rules" do
      expect(described_class::RULES).to include("unknown_location")
    end
  end

  describe "version 4 (spec 062)" do
    def v4 = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/v4-base.json").read)

    def deck(name, format: "modern", type: "mtg") = { "name" => name, "collectible_type" => type, "format" => format }

    def places(*names) = names.map { |name| { "name" => name } }

    # A version 4 file with these places and decks and no lots, unless lots are given.
    def filed(places: [], decks: [], lots: []) = v4.merge("locations" => places(*places), "decks" => decks, "lots" => lots)

    def lot_in(location) = v4["lots"][0].merge("location" => location)

    it "reads versions 1 to 4 and checks a version 4 file by its own schema", :aggregate_failures do
      expect(described_class.schema_version(v4)).to eq(4)
      expect(described_class.schema_version(v4.merge("format_version" => 4.0))).to eq(4)
      expect(problems_of(v4)).to eq([])
    end

    it "keeps a byte-identical copy of the schema of version 4 beside the rules (ADR 0021)" do
      document = Rails.root.join("docs/export-format/v4.schema.json")

      expect(described_class.schema_file(4).binread).to eq(document.binread)
    end

    it "6.7 finds a missing, mistyped or ill-formed list of decks where the schema says", :aggregate_failures do
      expect(problems_of(v4.except("decks"))).to eq([ %w[required /decks] ])
      expect(problems_of(v4.merge("decks" => {}))).to eq([ %w[type /decks] ])
      expect(problems_of(v4.merge("decks" => "Izzet Tempo"))).to eq([ %w[type /decks] ])
      expect(problems_of(v4.merge("decks" => [ 5 ], "lots" => []))).to eq([ %w[type /decks/0] ])
    end

    it "6.7 finds a deck whose fields are missing, blank or ill-formed", :aggregate_failures do
      one = ->(changes) { problems_of(filed(places: [], decks: [ deck("Izzet Tempo").merge(changes) ])) }
      %w[name collectible_type format].each { |field| expect(one.call(field => nil)).to eq([ [ "type", "/decks/0/#{field}" ] ]), field }
      expect(problems_of(filed(decks: [ deck("Izzet Tempo").except("name") ]))).to eq([ %w[required /decks/0/name] ])
      expect(problems_of(filed(decks: [ deck("Izzet Tempo").except("collectible_type") ]))).to eq([ %w[required /decks/0/collectible_type] ])
      expect(problems_of(filed(decks: [ deck("Izzet Tempo").except("format") ]))).to eq([ %w[required /decks/0/format] ])
      expect(one.call("collectible_type" => "")).to eq([ %w[pattern /decks/0/collectible_type] ])
      expect(one.call("collectible_type" => " \t")).to eq([ %w[pattern /decks/0/collectible_type] ])
      expect(one.call("format" => "")).to eq([ %w[pattern /decks/0/format] ])
      expect(one.call("format" => "  ")).to eq([ %w[pattern /decks/0/format] ])
    end

    it "6.7 judges a deck's name as a place's: control, padding, spacing and length", :aggregate_failures do
      one = ->(name) { problems_of(filed(decks: [ deck(name) ])) }
      expect(one.call("")).to eq([ %w[minLength /decks/0/name] ])
      expect(one.call("Izzet\u0007Tempo")).to eq([ %w[pattern /decks/0/name] ])
      expect(one.call(" Izzet Tempo")).to eq([ %w[pattern /decks/0/name] ])
      expect(one.call("Izzet Tempo ")).to eq([ %w[pattern /decks/0/name] ])
      expect(one.call("Izzet  Tempo")).to eq([ %w[pattern /decks/0/name] ])
      expect(one.call("本" * 61)).to eq([ %w[maxLength /decks/0/name] ])
      expect(one.call("本" * 60)).to eq([])
    end

    describe "a lot's location" do
      def one(location, decks: [ deck("Izzet Tempo") ]) = problems_of(filed(places: [ "Blue binder" ], decks:, lots: [ lot_in(location) ]))

      it "6.7 is accepted as null, a listed place's name or a listed deck's zone", :aggregate_failures do
        expect(one(nil)).to eq([])
        expect(one("Blue binder")).to eq([])
        expect(one({ "deck" => "Izzet Tempo", "zone" => "main" })).to eq([])
      end

      it "6.7 is refused as a number, a list or a missing field where the schema says", :aggregate_failures do
        missing = filed(places: [ "Blue binder" ], decks: [ deck("Izzet Tempo") ], lots: [ v4["lots"][0].except("location") ])
        expect(problems_of(missing)).to eq([ %w[required /lots/0/location] ])
        expect(one(5)).to eq([ %w[type /lots/0/location] ])
        expect(one([])).to eq([ %w[type /lots/0/location] ])
        expect(one(true)).to eq([ %w[type /lots/0/location] ])
      end

      it "6.7 is refused as an object without a deck or a zone, naming the missing key", :aggregate_failures do
        expect(one({})).to eq([ %w[required /lots/0/location/deck], %w[required /lots/0/location/zone] ])
        expect(one({ "zone" => "main" })).to eq([ %w[required /lots/0/location/deck] ])
        expect(one({ "deck" => "Izzet Tempo" })).to eq([ %w[required /lots/0/location/zone] ])
      end

      it "6.7 is refused as an object with another key, at that key" do
        expect(one({ "deck" => "Izzet Tempo", "zone" => "main", "slot" => 1 })).to eq([ %w[schema /lots/0/location/slot] ])
      end

      it "6.7 is refused with a deck that isn't a well-formed name or a blank zone", :aggregate_failures do
        expect(one({ "deck" => "Izzet  Tempo", "zone" => "main" })).to eq([ %w[pattern /lots/0/location/deck] ])
        expect(one({ "deck" => "", "zone" => "main" })).to eq([ %w[minLength /lots/0/location/deck] ])
        expect(one({ "deck" => 5, "zone" => "main" })).to eq([ %w[type /lots/0/location/deck] ])
        expect(one({ "deck" => "Izzet Tempo", "zone" => "" })).to eq([ %w[pattern /lots/0/location/zone] ])
        expect(one({ "deck" => "Izzet Tempo", "zone" => " " })).to eq([ %w[pattern /lots/0/location/zone] ])
        expect(one({ "deck" => "Izzet Tempo", "zone" => 5 })).to eq([ %w[type /lots/0/location/zone] ])
      end

      it "6.7 holds a string to the rules of a name, as in version 3", :aggregate_failures do
        expect(one("")).to eq([ %w[minLength /lots/0/location] ])
        expect(one("本" * 61)).to eq([ %w[maxLength /lots/0/location] ])
        expect(one("Blue  binder")).to eq([ %w[pattern /lots/0/location] ])
      end

      it "6.10 is unknown_location at the location when the deck isn't listed, compared by comparison key, and not when the zone key is unknown", :aggregate_failures do
        expect(one({ "deck" => "Nope", "zone" => "main" })).to eq([ %w[unknown_location /lots/0/location] ])
        expect(one({ "deck" => "IZZET TEMPO", "zone" => "main" })).to eq([])
        expect(one({ "deck" => "Cafe\u0301", "zone" => "main" }, decks: [ deck("Café") ])).to eq([])
        expect(one({ "deck" => "Izzet Tempo", "zone" => "no-such-zone" })).to eq([]) # the format's zone keys are the reader's to check
        expect(one({ "deck" => "Blue binder", "zone" => "main" })).to eq([ %w[unknown_location /lots/0/location] ]) # a place isn't a deck
      end

      it "6.10 is unknown_location for a place's name that is only a deck's name", :aggregate_failures do
        expect(one("Izzet Tempo")).to eq([ %w[unknown_location /lots/0/location] ])
      end

      it "6.10 compares no location that failed the schema, nor any when the decks failed", :aggregate_failures do
        expect(one({ "deck" => "Nope  x", "zone" => "main" })).to eq([ %w[pattern /lots/0/location/deck] ])
        expect(problems_of(filed(decks: { "name" => "x" }, lots: [ lot_in({ "deck" => "Nope", "zone" => "main" }) ]))).to eq([ %w[type /decks] ])
      end
    end

    describe "6.8 a name two entries share" do
      it "is duplicate_location at the later entry, a deck after a place being /decks/0", :aggregate_failures do
        expect(problems_of(filed(places: [ "Box" ], decks: [ deck("box") ]))).to eq([ %w[duplicate_location /decks/0] ])
        expect(problems_of(filed(places: [ "Box", "box" ], decks: [ deck("BOX") ]))).to eq([ %w[duplicate_location /locations/1], %w[duplicate_location /decks/0] ])
        expect(problems_of(filed(decks: [ deck("Straße"), deck("STRASSE") ]))).to eq([ %w[duplicate_location /decks/1] ])
        expect(problems_of(filed(decks: [ deck("Café"), deck("Cafe\u0301") ]))).to eq([ %w[duplicate_location /decks/1] ])
      end

      it "is judged with the places before the decks, so a place is never the later entry" do
        expect(problems_of(filed(places: [ "binder" ], decks: [ deck("Binder") ]))).to eq([ %w[duplicate_location /decks/0] ])
      end

      it "compares no deck whose name fails the schema, as it compares no place", :aggregate_failures do
        expect(problems_of(filed(decks: [ deck("a  b"), deck("a  b") ]))).to eq([ %w[pattern /decks/0/name], %w[pattern /decks/1/name] ])
        expect(problems_of(filed(places: [ "Box" ], decks: [ deck("box ") ]))).to eq([ %w[pattern /decks/0/name] ])
      end

      it "judges a name alone, whatever the deck's collectible type and format" do
        expect(problems_of(filed(decks: [ deck("Izzet"), deck("izzet", format: "legacy", type: "cards") ]))).to eq([ %w[duplicate_location /decks/1] ])
      end
    end

    describe "6.7b a deck name over 60 code points after normalisation" do
      let(:long) { "\u0344" * 31 } # 31 code points as written; each decomposes to two

      it "is maxLength at the name, and the 60-character name stays valid", :aggregate_failures do
        expect(problems_of(filed(decks: [ deck(long) ]))).to eq([ %w[maxLength /decks/0/name] ])
        expect(problems_of(filed(decks: [ deck("\u0344" * 30) ]))).to eq([])
        expect(problems_of(filed(decks: [ deck("本" * 60) ]))).to eq([])
      end

      it "is not compared for a duplicate", :aggregate_failures do
        expect(problems_of(filed(decks: [ deck(long), deck(long) ]))).to eq([ %w[maxLength /decks/0/name], %w[maxLength /decks/1/name] ])
      end

      it "leaves a lot that names the deck unjudged against it" do
        data = filed(decks: [ deck(long) ], lots: [ lot_in({ "deck" => long, "zone" => "main" }) ])

        expect(problems_of(data)).to eq([ %w[maxLength /decks/0/name] ])
      end

      it "checks the first 500 decks only", :aggregate_failures do
        decks = Array.new(500) { |index| deck("Deck #{index}") } + [ deck(long) ]
        allow(Location::Name).to receive(:normalise).and_call_original

        expect(problems_of(filed(decks:))).to eq([ %w[too_many_locations /decks] ])
        expect(Location::Name).not_to have_received(:normalise).with(long)
      end
    end

    describe "6.9 places and decks together over 500" do
      let(:limit) { described_class::MAX_LOCATIONS }

      it "keeps the limit in step with the account's cap and the schema's maxItems", :aggregate_failures do
        expect(limit).to eq(Location::MAX_PER_ACCOUNT)
        expect(JSON.parse(Rails.root.join("docs/export-format/v4.schema.json").read).dig("properties", "decks", "maxItems")).to eq(limit)
      end

      it "is too_many_locations at /decks, whichever list is long, and not when the total is 500", :aggregate_failures do
        names = ->(count, prefix) { Array.new(count) { |index| "#{prefix} #{index}" } }
        decks = ->(count) { names.call(count, "Deck").map { |name| deck(name) } }

        expect(problems_of(filed(places: names.call(300, "Binder"), decks: decks.call(200)))).to eq([])
        expect(problems_of(filed(places: names.call(300, "Binder"), decks: decks.call(201)))).to eq([ %w[too_many_locations /decks] ])
        expect(problems_of(filed(decks: decks.call(501)))).to eq([ %w[too_many_locations /decks] ])
        expect(problems_of(filed(places: names.call(501, "Binder")))).to eq([ %w[too_many_locations /decks] ])
        expect(problems_of(filed(decks: decks.call(500)))).to eq([])
      end

      it "still lists the problems of the first items of a list over the limit", :aggregate_failures do
        decks = [ deck("a  b") ] + Array.new(limit) { |index| deck("Deck #{index}") }

        expect(problems_of(filed(decks:))).to eq([ %w[pattern /decks/0/name], %w[too_many_locations /decks] ])
      end

      it "validates and case-folds no name past the limit, and judges no lot against or repeats no name in a refused list", :aggregate_failures do
        decks = Array.new(100_000) { |index| deck("Deck #{index}") }
        decks[limit + 10] = deck("a  b") # fails the schema, but lies past the limit
        allow(Location::Name).to receive(:key).and_call_original

        expect(problems_of(filed(decks:, lots: [ lot_in({ "deck" => "Deck 600", "zone" => "main" }) ]))).to eq([ %w[too_many_locations /decks] ])
        expect(Location::Name).to have_received(:key).once.with("Deck 600") # the lot's identity, and no name of the list
      end

      it "keeps a version 2 and 3 list of locations over the limit as maxItems at /locations", :aggregate_failures do
        long = Array.new(limit + 1) { |index| { "name" => "Binder #{index}" } }
        v2 = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/v2-base.json").read)
        v3 = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/v3-base.json").read)

        expect(problems_of(v2.merge("locations" => long))).to eq([ %w[maxItems /locations] ])
        expect(problems_of(v3.merge("locations" => long, "lots" => []))).to eq([ %w[maxItems /locations] ])
      end
    end

    describe "6.12 lot identity" do
      let(:lot) { v4["lots"][0] }

      it "gives six values, the sixth nil, a place's key or the pair of a deck's key and a zone key", :aggregate_failures do
        expect(described_class.identity(lot.merge("location" => nil), 4)).to eq(described_class.identity(lot, 4).first(5) + [ nil ])
        expect(described_class.identity(lot.merge("location" => "Blue Binder"), 4).last).to eq("blue binder")
        expect(described_class.identity(lot.merge("location" => { "deck" => "Izzet Tempo", "zone" => "main" }), 4).last).to eq([ "izzet tempo", "main" ])
        expect(described_class.identity(lot.merge("location" => { "deck" => "Izzet Tempo", "zone" => "main" }), 4).size).to eq(6)
      end

      it "tells a place from a deck's zone of the same name, and a zone from another zone of one deck", :aggregate_failures do
        place = described_class.identity(lot.merge("location" => "Box"), 4)
        zone = described_class.identity(lot.merge("location" => { "deck" => "Box", "zone" => "main" }), 4)

        expect(place).not_to eq(zone)
        expect(zone).not_to eq(described_class.identity(lot.merge("location" => { "deck" => "Box", "zone" => "sideboard" }), 4))
      end

      it "finds two lots in one zone of a deck written in two cases a duplicate, and not lots in two zones or a place and a zone", :aggregate_failures do
        twice = ->(one, other) { problems_of(filed(places: [ "Box" ], decks: [ deck("Izzet") ], lots: [ lot_in(one), lot_in(other) ])) }

        expect(twice.call({ "deck" => "Izzet", "zone" => "main" }, { "deck" => "izzet", "zone" => "main" })).to eq([ %w[duplicate_lot /lots/1] ])
        expect(twice.call({ "deck" => "Izzet", "zone" => "main" }, { "deck" => "izzet", "zone" => "sideboard" })).to eq([])
        expect(twice.call({ "deck" => "Izzet", "zone" => "main" }, "Box")).to eq([])
        expect(twice.call({ "deck" => "Izzet", "zone" => "Main" }, { "deck" => "Izzet", "zone" => "main" })).to eq([]) # a zone key is compared as written
      end

      it "reads no identity from a lot whose zone object failed the schema" do
        data = filed(decks: [ deck("Izzet") ], lots: [ lot_in({ "deck" => "Izzet", "zone" => "" }), lot_in({ "deck" => "Izzet", "zone" => "" }) ])

        expect(problems_of(data)).to eq([ %w[pattern /lots/0/location/zone], %w[pattern /lots/1/location/zone] ])
      end
    end

    it "keeps too_many_locations among the rules, and identity fields for a deck and a zone", :aggregate_failures do
      expect(described_class::RULES).to include("too_many_locations")
      expect(described_class::IDENTITY_FIELDS).to include("location/deck", "location/zone")
    end

    it "leaves a version 3 file to its own schema: its decks are ignored and a zone object is a type problem", :aggregate_failures do
      v3 = JSON.parse(Rails.root.join("docs/export-format/examples/comparison/v3-base.json").read)

      expect(problems_of(v3.merge("decks" => 5))).to eq([])
      expect(problems_of(v3.tap { |data| data["lots"][0]["location"] = { "deck" => "X", "zone" => "main" } })).to eq([ %w[type /lots/0/location] ])
    end
  end

  describe ".identity_readable?" do
    let(:lot) { base["lots"][0] }

    it "is true when no identity field fails the schema" do
      expect(described_class.identity_readable?(lot, "/lots/0", Set["/lots/0/quantity", "/lots/0/added_at"])).to be(true)
    end

    it "is false when an identity field fails, or the entry, or the lot isn't an object", :aggregate_failures do
      %w[entry entry/collectible_type entry/source_id finish condition price_paid].each do |field|
        expect(described_class.identity_readable?(lot, "/lots/0", Set["/lots/0/#{field}"])).to be(false), field
      end
      expect(described_class.identity_readable?(5, "/lots/0", Set["/lots/0"])).to be(false)
    end
  end

  describe ".parse" do
    it "reads UTF-8 JSON and refuses anything else", :aggregate_failures do
      expect(described_class.parse('{"a":1}')).to eq([ { "a" => 1 }, nil ])
      expect(described_class.parse("{\"a\":\"\xE9\"}".b)).to eq([ nil, described_class::Problem.new("not_utf8", "") ])
      expect(described_class.parse('{"a":1,"a":2}')).to eq([ nil, described_class::Problem.new("not_json", "") ])
      expect(described_class.parse("\xEF\xBB\xBF{}".b)).to eq([ nil, described_class::Problem.new("not_json", "") ])
    end

    it "refuses a number too large to read, which JSON reads as infinite" do
      expect(described_class.parse('{"lots":[{"quantity":1e400}]}')).to eq([ nil, described_class::Problem.new("not_json", "") ])
    end
  end
end
