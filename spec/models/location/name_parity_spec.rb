# spec/models/location/name_parity_spec.rb
require "rails_helper"

# Spec 029 AC-7.8, decision 9: the model, v2.schema.json and the format document agree on what a well-formed name is,
# tried on every Unicode scalar value in four forms. The model's verdict is Location::Name (what Location validates
# besides uniqueness and the limit); the schema's is its name definition (type, minLength, maxLength, pattern).
RSpec.describe Location::Name, "parity with v2.schema.json", type: :model do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod -- the file is named for what it proves; the description names the schema
  let(:scalars) { (0..0xD7FF).to_a + (0xE000..0x10FFFF).to_a }
  let(:definition) { ExportFormat::Rules.schema(2).dig("$defs", "location_name") }
  let(:pattern) { Regexp.new(JSONSchemer::EcmaRegexp.ruby_equivalent(definition["pattern"])) }

  def well_formed?(string) = string.length.between?(definition["minLength"], definition["maxLength"]) && pattern.match?(string)

  def accepted(text)
    normalised = described_class.normalise(text)
    normalised if described_class.fault(normalised).nil?
  end

  def forms(char) = [ char, "a#{char}b", "a#{char}#{char}b", "#{char}#{char}" ]

  it "agrees on every scalar value: what the model stores is well-formed, and what is well-formed the model accepts (AC-7.8 a, b)" do
    disagreements = []
    scalars.each do |scalar|
      forms([ scalar ].pack("U")).each do |text|
        stored = accepted(text)
        disagreements << [ :stored_but_not_well_formed, text ] if stored && !well_formed?(stored)
        next unless well_formed?(text)

        normalised = described_class.normalise(text)
        disagreements << [ :well_formed_but_refused, text ] if stored.nil? && normalised.length <= described_class::MAX_LENGTH
      end
    end

    expect(disagreements.first(5).map { |kind, text| [ kind, text.codepoints.map { |cp| format("U+%04X", cp) } ] }).to eq([])
  end

  it "exports what the model stores as a well-formed file (AC-7.8 c), for a sample of every 997th scalar", :aggregate_failures do
    scalars.each_slice(997).map(&:first).each do |scalar|
      stored = accepted("a#{[ scalar ].pack("U")}b")
      next unless stored

      file = JSON.parse(Rails.root.join("docs/export-format/examples/valid/empty-v2.json").read).merge("locations" => [ { "name" => stored } ])

      expect(ExportFormat::Rules.problems_in(file)).to eq([]), format("U+%04X", scalar)
    end
  end

  it "reads the pattern the way json_schemer does, on a sample (the regular expression stands for the validator)" do
    schemer = JSONSchemer.schema(definition, regexp_resolver: "ecma")
    sample = scalars.each_slice(233).map { |slice| "a#{[ slice.first ].pack("U")}b" }

    expect(sample.reject { |text| schemer.valid?(text) == well_formed?(text) }).to eq([])
  end
end
