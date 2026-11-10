require "rails_helper"

# Spec 062 FR-2, AC-1.2, AC-1.8, AC-9.11: the seam through which a collectible extension registers deck formats and zones, and
# the checks that fail the boot for a bad registration.
RSpec.describe Catalog::Formats, type: :model do
  def zone(key, name = key.to_s.capitalize) = described_class::Zone.new(key: key.to_s, name:)

  def build_format(key, zones: [ zone("main"), zone("considering") ], default: false) = described_class::Format.new(key: key.to_s, name: key.to_s.capitalize, zones:, default:)

  # A vocabulary registered as the type "fake" for one example, answering the formats it is given.
  def register(*formats)
    vocabulary = Module.new { define_singleton_method(:formats) { formats } }
    stub_const("FakeFormatVocabulary", vocabulary)
    Catalog.collecting["fake"] = "FakeFormatVocabulary"
  end

  after { Catalog.collecting.delete("fake") }

  it "knows one zone key, the one for cards under consideration" do
    expect(described_class::CONSIDERING).to eq("considering")
  end

  describe "the registered formats of mtg" do
    it "are Casual (default), the constructed formats and Commander, in order", :aggregate_failures do
      formats = described_class.options.map(&:format)

      expect(formats.map(&:key)).to eq(%w[casual standard pioneer modern legacy vintage pauper commander])
      expect(described_class.default_option.format.key).to eq("casual")
      expect(described_class.options.map(&:type).uniq).to eq([ "mtg" ])
      expect(described_class.options.map(&:value).first(2)).to eq(%w[mtg/casual mtg/standard])
    end

    it "give a deck's zones in order for a format and nothing for another" do
      expect(described_class.zones_for("mtg", "commander")).to eq([ zone("commander"), zone("main"), zone("considering") ])
    end

    it "give a name for a key, or the key itself when none is registered", :aggregate_failures do
      expect(described_class.name_for("mtg", "modern")).to eq("Modern")
      expect(described_class.name_for("mtg", "gone")).to eq("gone")
    end

    it "give the type's category name" do
      expect(described_class.category_name("mtg")).to eq("Magic: The Gathering")
    end
  end

  describe ".find and .find_pair (AC-1.8)" do
    it "finds a format by type and key, and nothing for an unknown one", :aggregate_failures do
      expect(described_class.find("mtg", "modern").name).to eq("Modern")
      expect(described_class.find("mtg", :modern).name).to eq("Modern")
      expect(described_class.find("mtg", "x")).to be_nil
      expect(described_class.find("nope", "modern")).to be_nil
      expect(described_class.zones_for("nope", "modern")).to be_nil
      expect(described_class.zones_for("mtg", "x")).to be_nil
    end

    it "splits a pair on the first slash into an option", :aggregate_failures do
      option = described_class.find_pair("mtg/modern")

      expect(option).to be_a(described_class::Option)
      expect([ option.type, option.format.key, option.value ]).to eq(%w[mtg modern mtg/modern])
    end

    it "answers nil for blank, no slash, an unknown type or a key of another type", :aggregate_failures do
      [ nil, "", "mtg", "modern", "nope/modern", "mtg/", "mtg/nope", "/modern", "mtg/modern/x" ].each do |value|
        expect(described_class.find_pair(value)).to be_nil, value.inspect
      end
    end
  end

  describe "with a second collectible that registers a key of the first's", :other_collecting do
    it "finds each by its type, so a key is unique within its type only", :aggregate_failures do
      expect(described_class.find("mtg", "standard").zones.map(&:key)).to eq(%w[main sideboard considering])
      expect(described_class.find("other", "standard").zones.map(&:key)).to eq(%w[deck considering])
      expect(described_class.find_pair("other/standard").type).to eq("other")
    end

    it "offers the options of both and groups them by each type's category name (AC-1.2)", :aggregate_failures do
      groups = described_class.options.group_by { described_class.category_name(it.type) }

      expect(described_class.grouped?).to be(true)
      expect(groups.keys).to eq([ "Magic: The Gathering", "Other cards" ])
      expect(groups["Other cards"].map(&:value)).to eq([ "other/standard" ])
    end

    it "keeps the default of the first type that registers one" do
      expect(described_class.default_option.value).to eq("mtg/casual")
    end
  end

  it "is flat with one type (AC-1.2)" do
    expect(described_class.grouped?).to be(false)
  end

  describe "a vocabulary that registers no formats" do
    it "offers none and doesn't raise", :aggregate_failures do
      Catalog.collecting["fake"] = "Object"

      expect(described_class.options.map(&:type).uniq).to eq([ "mtg" ])
      expect(described_class.find("fake", "x")).to be_nil
      expect(described_class.verify!).to be(true)
    end
  end

  describe ".verify!" do
    it "passes the registrations of the application and of a well-made vocabulary" do
      register(build_format("a", default: true), build_format("b"))

      expect(described_class.verify!).to be(true)
    end

    it "refuses a default that is not among the formats" do
      register(build_format("a"), build_format("b"))

      expect { described_class.verify! }.to raise_error(ArgumentError, /fake.*default/i)
    end

    it "refuses two defaults" do
      register(build_format("a", default: true), build_format("b", default: true))

      expect { described_class.verify! }.to raise_error(ArgumentError, /fake.*default/i)
    end

    it "refuses two formats with one key" do
      register(build_format("a", default: true), build_format("a"))

      expect { described_class.verify! }.to raise_error(ArgumentError, /fake.*"a".*more than once/)
    end

    it "refuses a repeated zone key" do
      register(build_format("a", default: true, zones: [ zone("main"), zone("main", "Other"), zone("considering") ]))

      expect { described_class.verify! }.to raise_error(ArgumentError, /fake.*"main".*zone key/)
    end

    it "refuses two zone names with one comparison key" do
      register(build_format("a", default: true, zones: [ zone("main", "Main"), zone("two", "  MAIN "), zone("considering") ]))

      expect { described_class.verify! }.to raise_error(ArgumentError, /fake.*zone names/)
    end

    it "refuses a zone name that is not a well-formed location name", :aggregate_failures do
      [ "", "a" * 61, "Ma\u0007in" ].each do |name|
        register(build_format("a", default: true, zones: [ zone("main", name), zone("considering") ]))

        expect { described_class.verify! }.to raise_error(ArgumentError, /fake.*zone name/), name.inspect
      end
    end

    it "refuses a format with no considering zone" do
      register(build_format("a", default: true, zones: [ zone("main") ]))

      expect { described_class.verify! }.to raise_error(ArgumentError, /fake.*"considering"/)
    end

    it "is run when the application boots", :aggregate_failures do
      source = Rails.root.join("config/initializers/catalog.rb").read

      expect(source).to include("Catalog::Formats.verify!")
    end
  end
end
