require "json_schemer"

# The export format's rules for a well-formed file, versions 1 to 3 (docs/export-format/README.md, specs 017, 029 and 032),
# as the app applies them when it reads a file (spec 025, ADR 0021). The v<N>.schema.json files beside this file are
# byte-identical copies of those in docs/export-format/, which the published image leaves out;
# spec/models/export_format/rules_spec.rb keeps them equal.
module ExportFormat
  module Rules
    Problem = Data.define(:rule, :at)

    FORMAT = "collector-export".freeze
    # The versions this instance reads, each against its own schema. VERSION is the newest: the one the export writes and
    # the highest a reader accepts (spec 029 decision 10).
    VERSIONS = [ 1, 2, 3 ].freeze
    VERSION = VERSIONS.max
    # Keep in step with v2.schema.json's and v3.schema.json's maxItems for locations (a spec checks it).
    MAX_LOCATIONS = Location::MAX_PER_ACCOUNT
    # The rules a schema can't state, and the two that apply before a schema can.
    RULES = %w[not_utf8 not_json not_a_time changed_before_added duplicate_lot duplicate_location unknown_location].freeze
    SCHEMA_DIRECTORY = Pathname(__dir__)
    TIME = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\z/
    JSON_TYPES = %w[array boolean integer null number object string].freeze
    # The fields under a lot that make its identity (ADR 0019, ADR 0025).
    IDENTITY_FIELDS = %w[entry entry/collectible_type entry/source_id finish condition price_paid location].freeze

    def self.schema_file(version = VERSION) = SCHEMA_DIRECTORY.join("v#{version}.schema.json")

    def self.schema(version = VERSION) = (@schemas ||= {})[version] ||= JSON.parse(schema_file(version).read)

    def self.schemer(version = VERSION) = (@schemers ||= {})[version] ||= JSONSchemer.schema(schema(version), regexp_resolver: "ecma")

    # The schema of one lot, $defs/lot, whose own $refs resolve against the whole schema of its version.
    def self.lot_schemer(version = VERSION) = (@lot_schemers ||= {})[version] ||= schemer(version).ref("#/$defs/lot")

    # The version whose schema judges +data+: its own when this instance reads it, else the oldest. A file with a missing,
    # unreadable or unknown version is then judged as it always was: by version 1's schema, which names the version
    # (required or const at /format_version) and has no locations to miss (plan review M1; spec 029 AC-7.4: every
    # version 1 invalid example keeps exactly its one problem).
    def self.schema_version(data)
      version = data.is_a?(Hash) ? whole_number(data["format_version"]) : nil
      VERSIONS.include?(version) ? version : VERSIONS.min
    end

    # A whole number (a zero fraction is allowed, spec 017), or nil.
    def self.whole_number(value)
      case value
      when Integer then value
      when Float then value.to_i if value.finite? && value == value.floor
      end
    end

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

    # Why parsed data isn't well-formed. Schema problems carry the keyword that failed. The time rules then apply to each
    # time the schema accepted, duplicate_lot to the lots whose identity can be read (spec 025 FR-2), and from version 2
    # duplicate_location to the locations whose name can be read.
    def self.problems_in(data)
      found = schema_problems(data, schema_version(data))
      found + rule_problems(data, found.to_set(&:at))
    end

    # What identifies a lot (ADR 0019, ADR 0025): its entry's type and source id, finish, condition, price paid and, from
    # version 3, the comparison key of its location. Six values for every version; the sixth is nil for versions 1 and 2,
    # which say nothing about a place (spec 032 decision 7), and for a lot in no location.
    def self.identity(lot, version = VERSION)
      lot.fetch("entry").values_at("collectible_type", "source_id") + lot.values_at("finish", "condition", "price_paid") +
        [ place_key(lot["location"], version) ]
    end

    def self.place_key(location, version)
      Location::Name.key(Location::Name.normalise(location)) if version >= 3 && location.is_a?(String)
    end

    # Whether the lot at +at+ has an identity to compare: it is an object, and none of its identity fields is among
    # the +failed+ pointers (spec 025 decision 1).
    def self.identity_readable?(lot, at, failed)
      lot.is_a?(Hash) && !failed.include?(at) && IDENTITY_FIELDS.none? { |field| failed.include?("#{at}/#{field}") }
    end

    # The schema's problems, in the order a whole-file pass gives them. The lots are checked one at a time against
    # $defs/lot, each lot's errors mapped before the next lot's (spec 025 decision 13: json_schemer holds a result tree
    # for everything it validates in one call). The rest of the file, locations included, is checked with no lots; its
    # errors at the root (a missing key) follow the lots', as json_schemer reports what "properties" finds before the
    # root's own "required". Data that isn't an object, or whose lots aren't an array, is checked whole: no lot is
    # checked then, so its tree is small.
    def self.schema_problems(data, version)
      return problems_from(schemer(version).validate(data)) unless data.is_a?(Hash) && data["lots"].is_a?(Array)

      over = locations_over_limit?(data, version)
      data = data.merge("locations" => data["locations"].first(MAX_LOCATIONS)) if over
      root, header = schemer(version).validate(data.merge("lots" => [])).partition { |error| error["data_pointer"].empty? }
      lots = data["lots"].each_with_index.flat_map { |lot, index| problems_from(lot_schemer(version).validate(lot), "/lots/#{index}") }
      problems_from(header) + (over ? [ Problem.new("maxItems", "/locations") ] : []) + lots + problems_from(root)
    end

    # A version 2 list longer than the schema's maxItems is reported at once and only its first MAX_LOCATIONS items are
    # checked, so what a hostile file costs doesn't grow with the list (spec 029 review M1; the validator holds a result
    # tree, and every name would be case-folded).
    def self.locations_over_limit?(data, version)
      version >= 2 && data["locations"].is_a?(Array) && data["locations"].size > MAX_LOCATIONS
    end

    # Schema errors as problems, their pointers under +at+. A missing key is a problem at the key.
    def self.problems_from(errors, at = "")
      errors.flat_map do |error|
        pointer = "#{at}#{error["data_pointer"]}"
        missing = error.dig("details", "missing_keys")
        next missing.map { |key| Problem.new("required", "#{pointer}/#{key}") } if missing

        [ Problem.new(JSON_TYPES.include?(error["type"]) ? "type" : error["type"], pointer) ]
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
      version = schema_version(data)
      repeats = lots.select { |lot, index| identity_readable?(lot, "/lots/#{index}", failed) }.group_by { |lot, _index| identity(lot, version) }.values
        .flat_map { |group| group.drop(1).map { |_lot, index| Problem.new("duplicate_lot", "/lots/#{index}") } }
      not_times + backwards + repeats + unlisted_places(data, lots, failed, version) + (version >= 2 ? repeated_locations(data, failed) : [])
    end

    # The lots whose location is a name the file's locations don't list, compared by comparison key (version 3). A lot whose
    # location failed the schema has nothing to compare, as a lot whose identity can't be read isn't compared.
    def self.unlisted_places(data, lots, failed, version)
      return [] unless version >= 3 && data["locations"].is_a?(Array) && !failed.include?("/locations") # an over-long list is refused at the header; none of it is folded here (spec 029 review M1)

      listed = data["locations"].filter_map { |location| place_key(location["name"], version) if location.is_a?(Hash) }.to_set
      lots.filter_map do |lot, index|
        next unless lot["location"].is_a?(String) && !failed.include?("/lots/#{index}/location")

        Problem.new("unknown_location", "/lots/#{index}/location") unless listed.include?(place_key(lot["location"], version))
      end
    end

    # The locations whose comparison key an earlier location already has (spec 029 decision 9): the key of the name after
    # normalisation and case folding. A name that fails the schema has no key to compare, as a lot whose identity can't
    # be read isn't compared.
    def self.repeated_locations(data, failed)
      return [] unless data["locations"].is_a?(Array) && !failed.include?("/locations")

      seen = Set.new
      data["locations"].each_with_index.filter_map do |location, index|
        at = "/locations/#{index}"
        next unless location.is_a?(Hash) && location["name"].is_a?(String) && !failed.include?(at) && !failed.include?("#{at}/name")

        Problem.new("duplicate_location", at) unless seen.add?(Location::Name.key(Location::Name.normalise(location["name"])))
      end
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

    private_class_method :non_finite?, :schema_problems, :locations_over_limit?, :problems_from, :rule_problems, :unlisted_places, :place_key, :repeated_locations, :changed_before_added?, :moment?
  end
end
