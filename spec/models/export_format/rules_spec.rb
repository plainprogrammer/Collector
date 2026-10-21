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

    expect(documented.map(&:basename).map(&:to_s)).to include("v1.schema.json", "v2.schema.json")
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
      files = examples("valid").merge(examples("invalid"), examples("comparison"), variants)

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
      expect(described_class.schema_version(v2.merge("format_version" => 3))).to eq(1) # a version it doesn't read: the oldest names the version
      expect(described_class.schema_version(base.except("format_version"))).to eq(1)
      expect(described_class.schema_version(base.merge("format_version" => "1"))).to eq(1)
      expect(described_class.schema_version([ v2 ])).to eq(1) # not an object: the oldest judges it, as it always did
      expect(problems_of(v2)).to eq([])
      expect(problems_of(base.merge("format_version" => 2))).to eq([ %w[required /locations] ])
      expect(problems_of(base.except("format_version"))).to eq([ %w[required /format_version] ]) # the version 1 invalid examples keep their one problem
      expect(problems_of(base.merge("format_version" => "1"))).to eq([ %w[const /format_version] ])
      expect(problems_of(v2.merge("format_version" => 3))).to eq([ %w[const /format_version] ])
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

    it "compares no location whose name fails the schema, as it compares no lot with an unreadable identity" do
      expect(problems_of(locations("a  b", "a  b"))).to eq([ %w[pattern /locations/0/name], %w[pattern /locations/1/name] ])
    end

    it "reports a location that isn't an object and checks the others" do
      data = v2.merge("locations" => [ 5, { "name" => "Box" }, { "name" => "box" } ])

      expect(problems_of(data)).to eq([ %w[type /locations/0], %w[duplicate_location /locations/2] ])
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
