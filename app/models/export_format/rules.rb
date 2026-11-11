require "json_schemer"

# The export format's rules for a well-formed file, versions 1 to 4 (docs/export-format/README.md, specs 017, 029, 032 and 062),
# as the app applies them when it reads a file (spec 025, ADR 0021). The v<N>.schema.json files beside this file are
# byte-identical copies of those in docs/export-format/, which the published image leaves out;
# spec/models/export_format/rules_spec.rb keeps them equal.
module ExportFormat
  module Rules
    Problem = Data.define(:rule, :at)

    FORMAT = "collector-export".freeze
    # The versions this instance reads, each against its own schema. VERSION is the newest: the one the export writes and
    # the highest a reader accepts (spec 029 decision 10).
    VERSIONS = [ 1, 2, 3, 4 ].freeze
    VERSION = VERSIONS.max
    # The most places and decks together a file holds from version 4 (spec 062 decision 3), and the most places of a version 2
    # or 3 file. Keep in step with the schemas' maxItems for locations and decks (a spec checks it).
    MAX_LOCATIONS = Location::MAX_PER_ACCOUNT
    # The rules a schema can't state, and the two that apply before a schema can. too_many_locations is version 4's count of
    # places and decks together, which no maxItems of one list can state.
    RULES = %w[not_utf8 not_json not_a_time changed_before_added duplicate_lot duplicate_location unknown_location too_many_locations].freeze
    SCHEMA_DIRECTORY = Pathname(__dir__)
    TIME = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\z/
    JSON_TYPES = %w[array boolean integer null number object string].freeze
    # The fields under a lot that make its identity (ADR 0019, ADR 0025, ADR 0028): a deck's zone has two more under its location.
    IDENTITY_FIELDS = %w[entry entry/collectible_type entry/source_id finish condition price_paid location location/deck location/zone].freeze

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
    # duplicate_location to the locations (from version 4 the decks too) whose name can be read.
    def self.problems_in(data)
      found = schema_problems(data, schema_version(data))
      found + rule_problems(data, found.to_set(&:at))
    end

    # What identifies a lot (ADR 0019, ADR 0025, ADR 0028): its entry's type and source id, finish, condition, price paid and,
    # from version 3, where it is. Six values for every version; the sixth is nil for versions 1 and 2, which say nothing
    # about a place (spec 032 decision 7), and for a lot in no location; otherwise it is `Location::Placement.file_key`: a
    # place's comparison key or, from version 4, the pair of a deck's comparison key and a zone key (spec 062 AC-6.12).
    def self.identity(lot, version = VERSION)
      lot.fetch("entry").values_at("collectible_type", "source_id") + lot.values_at("finish", "condition", "price_paid") +
        [ place_key(lot["location"], version) ]
    end

    # The sixth identity value, or nil where the version has none or the location is none of a name and (from version 4) a
    # deck and zone object. Never raises for a value the schema would have refused: those aren't compared (identity_readable?).
    def self.place_key(location, version)
      Location::Placement.file_key(location) if version >= 3 && (location.is_a?(String) || (version >= 4 && location.is_a?(Hash)))
    end

    # Whether the lot at +at+ has an identity to compare: it is an object, and none of its identity fields is among
    # the +failed+ pointers (spec 025 decision 1).
    def self.identity_readable?(lot, at, failed)
      lot.is_a?(Hash) && !failed.include?(at) && IDENTITY_FIELDS.none? { |field| failed.include?("#{at}/#{field}") }
    end

    # The schema's problems, in the order a whole-file pass gives them. The lots are checked one at a time against
    # $defs/lot, each lot's errors mapped before the next lot's (spec 025 decision 13: json_schemer holds a result tree
    # for everything it validates in one call). The rest of the file, locations and decks included, is checked with no lots; its
    # errors at the root (a missing key) follow the lots', as json_schemer reports what "properties" finds before the
    # root's own "required". Data that isn't an object, or whose lots aren't an array, is checked whole: no lot is
    # checked then, so its tree is small.
    def self.schema_problems(data, version)
      return problems_from(schemer(version).validate(data)) unless data.is_a?(Hash) && data["lots"].is_a?(Array)

      over = names_over_limit?(data, version)
      data = cut_names(data) if over
      root, header = schemer(version).validate(data.merge("lots" => [])).partition { |error| error["data_pointer"].empty? }
      lots = data["lots"].each_with_index.flat_map { |lot, index| problems_from(lot_schemer(version).validate(lot), "/lots/#{index}") }
      problems_from(header) + (over ? [ over_limit_problem(version) ] : []) + lots + problems_from(root)
    end

    # Whether the file lists more names than it may, so that only the first MAX_LOCATIONS of each list are checked and what
    # a hostile file costs doesn't grow with the lists (spec 029 review M1; the validator holds a result tree, and every
    # name would be case-folded). A version 2 or 3 file is over when its locations are; a version 4 file when its locations
    # and decks together are, places and decks sharing one set of names (spec 062 decision 3, AC-6.9).
    def self.names_over_limit?(data, version)
      return false if version < 2

      count = ->(key) { data[key].is_a?(Array) ? data[key].size : 0 }
      version >= 4 ? count.("locations") + count.("decks") > MAX_LOCATIONS : count.("locations") > MAX_LOCATIONS
    end

    # The file with each list of names cut to its first MAX_LOCATIONS items.
    def self.cut_names(data)
      %w[locations decks].select { |key| data[key].is_a?(Array) }.reduce(data) { |cut, key| cut.merge(key => data[key].first(MAX_LOCATIONS)) }
    end

    # The problem of a file over the limit: the schema's own keyword for a list of locations (versions 2 and 3), and the
    # rule too_many_locations at the decks for the places and decks together (version 4), which maxItems can't state.
    def self.over_limit_problem(version) = version >= 4 ? Problem.new("too_many_locations", "/decks") : Problem.new("maxItems", "/locations")

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
      long = version >= 4 ? long_deck_names(data, failed) : []
      failed = failed | long.to_set(&:at)
      repeats = lots.select { |lot, index| identity_readable?(lot, "/lots/#{index}", failed) }.group_by { |lot, _index| identity(lot, version) }.values
        .flat_map { |group| group.drop(1).map { |_lot, index| Problem.new("duplicate_lot", "/lots/#{index}") } }
      long + not_times + backwards + repeats + unlisted_places(data, lots, failed, version) + (version >= 2 ? repeated_locations(data, failed, version) : [])
    end

    # The decks whose well-formed name is over MAX_LENGTH code points once normalised (NFC): U+0344 and others decompose to
    # more than they were, so the schema's maxLength, which counts the name as written, lets them through, and no bulk write
    # may reach a name the database's length check refuses (spec 062 AC-6.7b). A rule of the format, not the reader's as a
    # place's is, because the examples spec asks every invalid example for exactly its problem here. Only the first
    # MAX_LOCATIONS decks are read, and none when the list failed (too long, or not a list).
    def self.long_deck_names(data, failed)
      return [] unless data["decks"].is_a?(Array) && !failed.include?("/decks")

      data["decks"].first(MAX_LOCATIONS).each_with_index.filter_map do |deck, index|
        at = "/decks/#{index}/name"
        next unless deck.is_a?(Hash) && deck["name"].is_a?(String) && !failed.include?("/decks/#{index}") && !failed.include?(at)

        Problem.new("maxLength", at) if Location::Name.normalise(deck["name"]).length > Location::Name::MAX_LENGTH
      end
    end

    # The lots whose location names a place or a deck the file doesn't list, compared by comparison key: a string against the
    # file's locations (version 3), an object's deck against the file's decks (version 4, spec 062 AC-6.10). Whether the zone
    # key is one of the deck's format is the reader's (it depends on this instance's registrations). A lot whose location
    # failed the schema has nothing to compare, as a lot whose identity can't be read isn't compared, and neither has any
    # lot against a list that failed (an over-long list is refused at the header; none of it is folded here, spec 029 review M1).
    def self.unlisted_places(data, lots, failed, version)
      return [] unless version >= 3

      listed = { String => listed_keys(data, "locations", failed, version), Hash => version >= 4 ? listed_keys(data, "decks", failed, version) : nil }
      lots.filter_map do |lot, index|
        location = lot["location"]
        at = "/lots/#{index}/location"
        keys = listed[location.class]
        next unless keys && !location_failed?(location, at, failed)

        name = location.is_a?(Hash) ? location["deck"] : location
        Problem.new("unknown_location", at) unless keys.include?(Location::Name.key(Location::Name.normalise(name)))
      end
    end

    # The comparison keys of the names in the file's list +list+ ("locations" or "decks"), or nil when the list failed.
    def self.listed_keys(data, list, failed, version)
      return unless data[list].is_a?(Array) && !failed.include?("/#{list}")

      data[list].filter_map { |item| place_key(item["name"], version) if item.is_a?(Hash) }.to_set
    end

    # Whether the location at +at+ is one of the failed pointers, or (an object) has a failed deck, zone or other key.
    def self.location_failed?(location, at, failed)
      failed.include?(at) || (location.is_a?(Hash) && (location.keys | %w[deck zone]).any? { |key| failed.include?("#{at}/#{key}") })
    end

    # The locations, then (from version 4) the decks, whose comparison key an earlier one already has (spec 029 decision 9,
    # spec 062 AC-6.8): the key of the name after normalisation and case folding, places being judged first so that a place
    # is never the later entry. A name that fails the schema has no key to compare, as a lot whose identity can't be read
    # isn't compared, and a list that failed isn't walked.
    def self.repeated_locations(data, failed, version)
      seen = Set.new
      (version >= 4 ? %w[locations decks] : %w[locations]).flat_map do |list|
        next [] unless data[list].is_a?(Array) && !failed.include?("/#{list}")

        data[list].each_with_index.filter_map do |item, index|
          at = "/#{list}/#{index}"
          next unless item.is_a?(Hash) && item["name"].is_a?(String) && !failed.include?(at) && !failed.include?("#{at}/name")

          Problem.new("duplicate_location", at) unless seen.add?(Location::Name.key(Location::Name.normalise(item["name"])))
        end
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

    private_class_method :non_finite?, :schema_problems, :names_over_limit?, :cut_names, :over_limit_problem, :problems_from, :rule_problems, :long_deck_names, :unlisted_places,
                         :listed_keys, :location_failed?, :place_key, :repeated_locations, :changed_before_added?, :moment?
  end
end
