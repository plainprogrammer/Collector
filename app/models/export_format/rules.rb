require "json_schemer"

# The export format's rules for a well-formed file, version 1 (docs/export-format/README.md, spec 017), as the app
# applies them when it reads a file (spec 025, ADR 0021). v1.schema.json beside this file is a byte-identical copy of
# docs/export-format/v1.schema.json, which the published image leaves out; spec/models/export_format/rules_spec.rb
# keeps the two equal.
module ExportFormat
  module Rules
    Problem = Data.define(:rule, :at)

    FORMAT = "collector-export".freeze
    VERSION = 1
    # The rules a schema can't state, and the two that apply before a schema can.
    RULES = %w[not_utf8 not_json not_a_time changed_before_added duplicate_lot].freeze
    SCHEMA_FILE = Pathname(__dir__).join("v1.schema.json")
    TIME = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\z/
    JSON_TYPES = %w[array boolean integer null number object string].freeze
    # The fields under a lot that make its identity (ADR 0019).
    IDENTITY_FIELDS = %w[entry entry/collectible_type entry/source_id finish condition price_paid].freeze

    def self.schema = @schema ||= JSON.parse(SCHEMA_FILE.read)

    def self.schemer = @schemer ||= JSONSchemer.schema(schema, regexp_resolver: "ecma")

    # The file as data, or the problem that stops it being read: [data, nil] or [nil, problem]. JSON's error message
    # quotes the file, so it is dropped (spec 025 FR-6). A number too large for a float reads as Infinity, which no
    # JSON text can mean and json_schemer's integer check can't take (FloatDomainError), so it isn't readable JSON.
    def self.parse(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      return [ nil, Problem.new("not_utf8", "") ] unless text.valid_encoding?

      data = JSON.parse(text, allow_duplicate_key: false)
      non_finite?(data) ? [ nil, Problem.new("not_json", "") ] : [ data, nil ]
    rescue JSON::ParserError
      [ nil, Problem.new("not_json", "") ]
    end

    # Why a file isn't well-formed: an empty list when it is.
    def self.problems(bytes)
      data, problem = parse(bytes)
      problem ? [ problem ] : problems_in(data)
    end

    # Why parsed data isn't well-formed. Schema problems carry the keyword that failed. The time rules then apply to
    # each time the schema accepted, and duplicate_lot to the lots whose identity can be read (spec 025 FR-2).
    def self.problems_in(data)
      found = schema_problems(data)
      found + rule_problems(data, found.to_set(&:at))
    end

    # What identifies a lot (ADR 0019): its entry's type and source id, finish, condition and price paid.
    def self.identity(lot)
      lot.fetch("entry").values_at("collectible_type", "source_id") + lot.values_at("finish", "condition", "price_paid")
    end

    # Whether the lot at +at+ has an identity to compare: it is an object, and none of its identity fields is among
    # the +failed+ pointers (spec 025 decision 1).
    def self.identity_readable?(lot, at, failed)
      lot.is_a?(Hash) && !failed.include?(at) && IDENTITY_FIELDS.none? { |field| failed.include?("#{at}/#{field}") }
    end

    def self.schema_problems(data)
      schemer.validate(data).flat_map do |error|
        missing = error.dig("details", "missing_keys")
        next missing.map { |key| Problem.new("required", "#{error["data_pointer"]}/#{key}") } if missing

        [ Problem.new(JSON_TYPES.include?(error["type"]) ? "type" : error["type"], error["data_pointer"]) ]
      end
    end

    def self.rule_problems(data, failed)
      return [] unless data.is_a?(Hash)

      lots = data["lots"].is_a?(Array) ? data["lots"].each_with_index.select { |lot, _index| lot.is_a?(Hash) } : []
      times = [ [ "/exported_at", data["exported_at"] ] ] +
        lots.flat_map { |lot, index| %w[added_at changed_at].map { |name| [ "/lots/#{index}/#{name}", lot[name] ] } }
      checked = times.reject { |at, _value| failed.include?(at) }
      real = checked.select { |_at, value| moment?(value) }.to_set { |at, _value| at }
      not_times = checked.reject { |at, _value| real.include?(at) }.map { |at, _value| Problem.new("not_a_time", at) }
      backwards = lots.select { |lot, index| changed_before_added?(lot, "/lots/#{index}", real) }
        .map { |_lot, index| Problem.new("changed_before_added", "/lots/#{index}/changed_at") }
      repeats = lots.select { |lot, index| identity_readable?(lot, "/lots/#{index}", failed) }.group_by { |lot, _index| identity(lot) }.values
        .flat_map { |group| group.drop(1).map { |_lot, index| Problem.new("duplicate_lot", "/lots/#{index}") } }
      not_times + backwards + repeats
    end

    def self.non_finite?(value)
      case value
      when Float then !value.finite?
      when Hash then value.each_value.any? { |item| non_finite?(item) }
      when Array then value.any? { |item| non_finite?(item) }
      else false
      end
    end

    def self.changed_before_added?(lot, at, real)
      real.include?("#{at}/added_at") && real.include?("#{at}/changed_at") && lot["changed_at"] < lot["added_at"]
    end

    def self.moment?(value)
      year, month, day, hour, minute, second = value.match(TIME).captures.map(&:to_i)
      Date.valid_date?(year, month, day) && hour < 24 && minute < 60 && second < 60
    end

    private_class_method :non_finite?, :schema_problems, :rule_problems, :changed_before_added?, :moment?
  end
end
