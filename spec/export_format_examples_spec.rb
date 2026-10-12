require "rails_helper"

# Spec 017: the export format's example files, checked against its schema and the rules a schema can't state
# (docs/export-format/README.md). The rules themselves are in spec/support/export_format_rules.rb.
RSpec.describe "The export format's examples" do
  def parsed(examples) = examples.transform_values { |bytes| JSON.parse(bytes) }

  def problems_of(bytes) = ExportFormatRules.problems(bytes).map { |problem| problem.to_h.stringify_keys }

  # What examples/problems.json says is wrong with each invalid example.
  def named = JSON.parse(ExportFormatRules.directory.join("examples/problems.json").read)

  def base = comparison.fetch("comparison/base.json")

  def lots = parsed(valid).values.flat_map { |file| file["lots"] }

  # Spec 017's Error Scenarios list several ways to break one rule. Each pair here is one of them: where the base
  # file is changed and to what, then the rule that must fail and where.
  def malformed_variants
    {
      [ %w[exported_at], :absent ] => %w[required /exported_at],
      [ %w[profile], :absent ] => %w[required /profile],
      [ %w[currency], :absent ] => %w[required /currency],
      [ %w[format_version], 0 ] => %w[const /format_version],
      [ %w[profile email_address], :absent ] => %w[required /profile/email_address],
      [ %w[profile email_address], "" ] => %w[pattern /profile/email_address],
      [ %w[currency], "US" ] => %w[pattern /currency],
      [ %w[currency], "USDX" ] => %w[pattern /currency],
      [ [ "lots", 0, "entry", "collectible_type" ], :absent ] => %w[required /lots/0/entry/collectible_type],
      [ [ "lots", 0, "entry", "language" ], "" ] => %w[pattern /lots/0/entry/language],
      [ [ "lots", 0, "quantity" ], -1 ] => %w[minimum /lots/0/quantity],
      [ [ "lots", 0, "quantity" ], 10_000 ] => %w[maximum /lots/0/quantity],
      [ [ "lots", 0, "quantity" ], 2.5 ] => %w[type /lots/0/quantity],
      [ [ "lots", 0, "quantity" ], "4" ] => %w[type /lots/0/quantity],
      [ [ "lots", 0, "finish" ], " " ] => %w[pattern /lots/0/finish],
      [ [ "lots", 0, "condition" ], :absent ] => %w[required /lots/0/condition],
      [ [ "lots", 0, "price_paid" ], :absent ] => %w[required /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], 12.5 ] => %w[type /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "012.50" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "-1.00" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "$3.00" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "1,200.00" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "price_paid" ], "12.50\n" ] => %w[pattern /lots/0/price_paid],
      [ [ "lots", 0, "added_at" ], :absent ] => %w[required /lots/0/added_at],
      [ [ "lots", 0, "added_at" ], "2026-09-30T18:02:11.250Z" ] => %w[pattern /lots/0/added_at],
      [ [ "lots", 0, "added_at" ], "2026-09-30" ] => %w[pattern /lots/0/added_at],
      [ [ "lots", 0, "added_at" ], "2026-09-30T24:00:00Z" ] => %w[not_a_time /lots/0/added_at],
      [ %w[exported_at], "2026-13-01T00:00:00Z" ] => %w[not_a_time /exported_at]
    }
  end

  # The base file with one value replaced, or removed when the value is :absent, as bytes.
  def changed(path, value)
    data = JSON.parse(base)
    *parents, last = path
    target = parents.empty? ? data : data.dig(*parents)
    value == :absent ? target.delete(last) : target[last] = value
    JSON.generate(data)
  end

  let(:valid) { ExportFormatRules.examples("valid") }
  let(:invalid) { ExportFormatRules.examples("invalid") }
  let(:comparison) { ExportFormatRules.examples("comparison") }

  it "is defined by a schema that is itself valid" do
    expect(JSONSchemer.valid_schema?(ExportFormatRules.schema)).to be(true)
  end

  it "has valid, invalid and comparison examples", :aggregate_failures do
    expect(valid.keys).to eq(%w[valid/collection.json valid/empty.json])
    expect(invalid.size).to eq(21)
    expect(comparison.size).to eq(8)
  end

  it "finds nothing wrong with any valid or comparison example (AC-2.1)" do
    found = valid.merge(comparison).transform_values { |bytes| problems_of(bytes) }

    expect(found.reject { |_name, problems| problems.empty? }).to be_empty
  end

  it "finds each invalid example wrong for the one reason it names (AC-2.2)" do
    found = invalid.transform_values { |bytes| problems_of(bytes) }

    expect(found).to eq(named.transform_values { |entry| [ entry.slice("rule", "at") ] })
  end

  it "says in words why each invalid example is wrong (AC-2.2)" do
    expect(named.values.map { |entry| entry["why"].to_s.strip }).to all(match(/\A[A-Z].+\.\z/))
  end

  it "has an invalid example for every rule a schema can't state (AC-2.2)" do
    expect(named.values.map { |entry| entry["rule"] }).to include(*ExportFormatRules::RULES)
  end

  it "finds every listed variant of a malformed value (AC-2.2)", :aggregate_failures do
    malformed_variants.each do |(path, value), (rule, at)|
      expect(problems_of(changed(path, value))).to eq([ { "rule" => rule, "at" => at } ]), "#{path.join('/')} = #{value.inspect}"
    end
  end

  it "fails version 1's schema for a file of another version, which a reader refuses before it checks (FR-8)" do
    expect(problems_of(changed(%w[format_version], 2))).to eq([ { "rule" => "const", "at" => "/format_version" } ])
  end

  it "accepts the values at the edges of each rule", :aggregate_failures do
    {
      %w[generator] => :absent, %w[profile collection_view] => "gallery", [ "lots", 0, "price_paid" ] => nil, %w[currency] => "XTS",
      [ "lots", 0, "quantity" ] => 9_999, [ "lots", 0, "price_paid" ] => "0.00", [ "lots", 0, "finish" ] => "glossy",
      [ "lots", 0, "changed_at" ] => "2026-09-30T18:02:11Z", [ "lots", 0, "entry", "collectible_type" ] => "comics",
      %w[lots] => []
    }.each do |path, value|
      expect(problems_of(changed(path, value))).to be_empty, "#{path.join('/')} = #{value.inspect}"
    end
  end

  it "covers every shape a lot can take between the valid examples (AC-2.3)", :aggregate_failures do
    identities = lots.map { |lot| ExportFormatRules.identity(lot) }
    differing = identities.combination(2).map { |one, other| one.each_index.reject { |index| one[index] == other[index] } }

    expect(lots).to include(a_hash_including("finish" => String, "condition" => String, "price_paid" => String))
    expect(lots).to include(a_hash_including("finish" => nil, "condition" => nil, "price_paid" => nil))
    expect(lots.map { |lot| lot["price_paid"] }).to include("0.00")
    expect(lots.map { |lot| lot["quantity"] }).to include(1, 9_999)
    expect(differing).to include([ 2 ], [ 3 ], [ 4 ])
    expect(parsed(valid).values.map { |file| file["lots"].size }).to include(0)
  end

  it "describes every lot's entry for a reader with no catalog (AC-1.3)" do
    described = lots.map { |lot| lot["entry"].values_at("collectible_type", "source_id", "name", "set_code", "collector_number", "language") }

    expect(described.flatten).to all(match(/\S/))
  end

  it "carries no credential, role or internal id (AC-1.4)", :aggregate_failures do
    names = parsed(valid).values.flat_map { |file| ExportFormatRules.field_names(file) }.uniq

    expect(names).not_to include("admin", "password", "session")
    expect(names.grep(/_digest\z/)).to be_empty
    expect(names.grep(/(\A|_)(id|key)\z/)).to eq(%w[source_id])
  end

  describe "the same collection (FR-7)" do
    def different = parsed(comparison).select { |name, _file| name.start_with?("comparison/different-") }

    let(:original) { JSON.parse(base) }
    let(:same) { JSON.parse(comparison.fetch("comparison/same.json")) }

    it "holds for a file that differs only in what the rule ignores (AC-2.5)" do
      expect(ExportFormatRules.same_collection?(original, same)).to be(true)
    end

    it "is tested by a pair that differs in everything the rule ignores (AC-2.5)", :aggregate_failures do
      expect(same["lots"].map { |lot| ExportFormatRules.identity(lot) }).to eq(original["lots"].map { |lot| ExportFormatRules.identity(lot) }.reverse)
      expect(same.values_at("exported_at", "generator")).not_to include(*original.values_at("exported_at", "generator"))
      expect(same["lots"].last["entry"].values_at("name", "set_code")).not_to include(*original["lots"].first["entry"].values_at("name", "set_code"))
      expect(ExportFormatRules.field_names(same) - ExportFormatRules.field_names(original)).to match_array(%w[note shelf])
    end

    it "fails for each file that differs in one thing the rule compares (AC-2.5)", :aggregate_failures do
      expect(different.keys.map { |name| name[/different-(.+)\.json/, 1] })
        .to eq(%w[changed-at currency email-address finish missing-lot quantity])
      different.each { |name, file| expect(ExportFormatRules.same_collection?(original, file)).to be(false), name }
    end

    it "is only defined for files of one version" do
      expect { ExportFormatRules.same_collection?(original, original.merge("format_version" => 2)) }.to raise_error(ArgumentError)
    end
  end
end
