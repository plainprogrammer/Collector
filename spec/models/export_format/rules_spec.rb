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
    copies = documented.map { |file| described_class::SCHEMA_FILE.dirname.join(file.basename) }

    expect(documented.map(&:basename).map(&:to_s)).to include("v1.schema.json")
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
