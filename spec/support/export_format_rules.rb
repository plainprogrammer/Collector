require "json_schemer"

# The export format's rules as the suite applies them (spec 017, docs/export-format/README.md): what makes a file
# well-formed, what identifies a lot, and when two files hold the same collection. Well-formedness and lot identity
# are the app's (ExportFormat::Rules, spec 025, ADR 0021); this module passes them through and adds what only the
# suite needs: the document, its examples and the comparison of two files.
module ExportFormatRules
  Problem = ExportFormat::Rules::Problem
  RULES = ExportFormat::Rules::RULES

  def self.directory = Rails.root.join("docs/export-format")

  def self.document = directory.join("README.md").read

  # The version the document says it defines.
  def self.version = document[/^\*\*Format version:\*\* (\d+)$/, 1].to_i

  # The schema of the newest version: v<N>.schema.json.
  def self.schema_file = directory.glob("v*.schema.json").max_by { |file| file.basename.to_s[/\d+/].to_i }

  # Every version this instance reads (ExportFormat::Rules), and the schema file of one.
  def self.versions = ExportFormat::Rules::VERSIONS

  def self.schema_file_for(version) = directory.join("v#{version}.schema.json")

  def self.schema(version = nil) = JSON.parse((version ? schema_file_for(version) : schema_file).read)

  # The examples of one kind ("valid", "invalid", "comparison"), as bytes keyed by their path under examples/.
  def self.examples(kind)
    directory.glob("examples/#{kind}/*.json").sort.to_h { |file| [ "#{kind}/#{file.basename}", file.binread ] }
  end

  # Why a file isn't well-formed: an empty list when it is (ExportFormat::Rules).
  def self.problems(bytes) = ExportFormat::Rules.problems(bytes)

  # What identifies a lot (ADR 0019).
  def self.identity(lot) = ExportFormat::Rules.identity(lot)

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

  def self.compared(file)
    [ file.fetch("profile").slice("name", "email_address", "collection_view"), file["currency"],
      file.fetch("lots").to_h { |lot| [ identity(lot), lot.values_at("quantity", "added_at", "changed_at") ] },
      file["locations"]&.map { |location| location["name"] }&.to_set ]
  end

  private_class_method :compared, :cells
end
