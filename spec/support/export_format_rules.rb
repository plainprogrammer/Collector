require "json_schemer"

# The export format's rules as the suite applies them (spec 017, docs/export-format/README.md): what makes a file
# well-formed, what identifies a lot, and when two files hold the same collection. Test support only: the app writes
# the format (CollectionExport, spec 022) but has no import yet, and json_schemer is never loaded outside the suite.
module ExportFormatRules
  Problem = Data.define(:rule, :at)

  # The rules a schema can't state, and the two that apply before a schema can.
  RULES = %w[not_utf8 not_json not_a_time changed_before_added duplicate_lot].freeze
  TIME = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z\z/
  JSON_TYPES = %w[array boolean integer null number object string].freeze

  def self.directory = Rails.root.join("docs/export-format")

  def self.document = directory.join("README.md").read

  # The version the document says it defines.
  def self.version = document[/^\*\*Format version:\*\* (\d+)$/, 1].to_i

  # The schema of the newest version: v<N>.schema.json.
  def self.schema_file = directory.glob("v*.schema.json").max_by { |file| file.basename.to_s[/\d+/].to_i }

  def self.schema = JSON.parse(schema_file.read)

  # The examples of one kind ("valid", "invalid", "comparison"), as bytes keyed by their path under examples/.
  def self.examples(kind)
    directory.glob("examples/#{kind}/*.json").sort.to_h { |file| [ "#{kind}/#{file.basename}", file.binread ] }
  end

  # Why a file isn't well-formed: an empty list when it is. Schema problems carry the schema keyword that failed.
  def self.problems(bytes)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    return [ Problem.new("not_utf8", "") ] unless text.valid_encoding?

    data = JSON.parse(text, allow_duplicate_key: false)
    found = schema_problems(data)
    found.empty? ? rule_problems(data) : found
  rescue JSON::ParserError
    [ Problem.new("not_json", "") ]
  end

  # What identifies a lot (ADR 0019): its entry's type and source id, finish, condition and price paid.
  def self.identity(lot)
    lot.fetch("entry").values_at("collectible_type", "source_id") + lot.values_at("finish", "condition", "price_paid")
  end

  # Whether two well-formed files of one version hold the same collection (spec 017 FR-7). Callers check
  # .problems first: a file that isn't well-formed may raise here.
  def self.same_collection?(one, other)
    raise ArgumentError, "the files have different format versions" unless one["format_version"] == other["format_version"]

    compared(one) == compared(other)
  end

  # Every field name in a parsed file, at any depth.
  def self.field_names(data)
    case data
    when Hash then data.keys | data.values.flat_map { |value| field_names(value) }
    when Array then data.flat_map { |value| field_names(value) }.uniq
    else []
    end
  end

  # A "## " section of the format document, without its heading.
  def self.section(title)
    document[/^## #{Regexp.escape(title)}\n(.*?)(?=^## |\z)/m, 1] or raise KeyError, "no section #{title}"
  end

  # The rows of the table in +text+ whose first column is headed +heading+, as hashes keyed by column heading.
  # Backticks are dropped from the cells.
  def self.table(text, heading)
    lines = text.lines.map(&:strip)
    start = lines.index { |line| line.start_with?("| #{heading} |") } or raise KeyError, "no table headed #{heading}"
    header = cells(lines[start])
    lines.drop(start + 2).take_while { |line| line.start_with?("|") }.map { |line| header.zip(cells(line)).to_h }
  end

  def self.cells(line) = line.delete_prefix("|").delete_suffix("|").split("|", -1).map { |cell| cell.strip.delete("`") }

  def self.schema_problems(data)
    JSONSchemer.schema(schema, regexp_resolver: "ecma").validate(data).flat_map do |error|
      missing = error.dig("details", "missing_keys")
      next missing.map { |key| Problem.new("required", "#{error["data_pointer"]}/#{key}") } if missing

      [ Problem.new(JSON_TYPES.include?(error["type"]) ? "type" : error["type"], error["data_pointer"]) ]
    end
  end

  def self.rule_problems(data)
    lots = data["lots"].each_with_index.to_a
    times = [ [ "/exported_at", data["exported_at"] ] ] +
      lots.flat_map { |lot, index| %w[added_at changed_at].map { |name| [ "/lots/#{index}/#{name}", lot[name] ] } }
    not_times = times.reject { |_at, value| moment?(value) }.map { |at, _value| Problem.new("not_a_time", at) }
    backwards = lots.select { |lot, _index| lot["changed_at"] < lot["added_at"] }
      .map { |_lot, index| Problem.new("changed_before_added", "/lots/#{index}/changed_at") }
    repeats = lots.group_by { |lot, _index| identity(lot) }.values
      .flat_map { |group| group.drop(1).map { |_lot, index| Problem.new("duplicate_lot", "/lots/#{index}") } }
    not_times + backwards + repeats
  end

  def self.moment?(value)
    year, month, day, hour, minute, second = value.match(TIME).captures.map(&:to_i)
    Date.valid_date?(year, month, day) && hour < 24 && minute < 60 && second < 60
  end

  def self.compared(file)
    [ file.fetch("profile").slice("name", "email_address", "collection_view"), file["currency"],
      file.fetch("lots").to_h { |lot| [ identity(lot), lot.values_at("quantity", "added_at", "changed_at") ] } ]
  end

  private_class_method :schema_problems, :rule_problems, :moment?, :compared, :cells
end
