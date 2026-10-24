require "rails_helper"

# Spec 017: the export format's document (docs/export-format/README.md), checked against its schema, its examples
# and the application, so that a change to one that isn't made to the others fails here.
RSpec.describe "The export format's document" do
  def tables_owned_by_a_collector
    connection = ActiveRecord::Base.connection
    [ "accounts" ] + connection.tables.select { |table| connection.columns(table).map(&:name).intersect?(%w[account_id user_id]) }
  end

  def columns_of(tables)
    tables.flat_map { |table| ActiveRecord::Base.connection.columns(table).map { |column| "#{table}.#{column.name}" } }
  end

  let(:document) { ExportFormatRules.document }
  let(:fields) do
    ExportFormatRules.examples("valid").values.flat_map { |bytes| ExportFormatRules.field_names(JSON.parse(bytes)) }.uniq
  end
  let(:coverage) { ExportFormatRules.section("Coverage") }
  let(:covered_tables) { ExportFormatRules.table(coverage, "Table") }
  let(:covered_columns) { ExportFormatRules.table(coverage, "Column") }

  it "names every field that appears in the valid examples (AC-1.1)" do
    expect(fields.reject { |field| document.include?("`#{field}`") }).to be_empty
  end

  it "states the newest version, which its schema and a valid example carry, and every version has its schema and a row (AC-4.1, AC-7.1)", :aggregate_failures do
    version = ExportFormatRules.version
    carried = ExportFormatRules.examples("valid").values.map { |bytes| JSON.parse(bytes)["format_version"] }

    expect(version).to eq(ExportFormat::Rules::VERSION)
    expect(ExportFormatRules.schema_file.basename.to_s).to eq("v#{version}.schema.json")
    (1..version).each { |each| expect(ExportFormatRules.schema(each).dig("properties", "format_version", "const")).to eq(each) }
    expect(carried).to include(version)
    expect(carried.uniq - (1..version).to_a).to be_empty
    expect(ExportFormatRules.table(ExportFormatRules.section("Versions"), "Version").map { |row| row["Version"] }).to eq((1..version).map(&:to_s))
  end

  it "lists each collectible type's conditions as the application registers them (AC-4.2)", :aggregate_failures do
    types = ExportFormatRules.section("Collectible types")

    expect(Catalog.collecting.keys).not_to be_empty
    Catalog.collecting.each_key do |type|
      section = types[/^### [^\n]*\(`#{Regexp.escape(type)}`\)\n(.*?)(?=^### |\z)/m, 1].to_s
      listed = ExportFormatRules.table(section, "Condition").map { |row| row["Condition"] }
      expect(listed).to eq(Catalog.collecting_for(type).conditions.keys), type
    end
  end

  it "lists the currencies the application supports (AC-4.3)" do
    expect(ExportFormatRules.section("Currency").scan(/`([A-Z]{3})`/).flatten).to eq(Collector::Currency::SYMBOLS.keys)
  end

  it "names no collectible outside its section for collectible types (FR-6)", :aggregate_failures do
    core = document.sub(/^## Collectible types\n.*?(?=^## )/m, "")
    names = /\b(mtg|magic|scryfall)\b/i

    expect(core).not_to eq(document)
    expect(core).not_to match(names)
    expect(ExportFormatRules.schema_file.read).not_to match(names)
  end

  describe "coverage" do
    it "accounts for every table that belongs to an account or a user (AC-3.4)" do
      expect(covered_tables.map { |row| row["Table"] }).to match_array(tables_owned_by_a_collector)
    end

    it "accounts for every column of a table that isn't left out whole (AC-3.4)" do
      kept = covered_tables.reject { |row| row["In the export"] == "Left out" }.map { |row| row["Table"] }

      expect(covered_columns.map { |row| row["Column"] }).to match_array(columns_of(kept))
    end

    it "marks each table as the spec rules (AC-3.5)", :aggregate_failures do
      status = covered_tables.to_h { |row| [ row["Table"], row["In the export"] ] }

      expect(status).to include("lots" => "Exported", "users" => "Exported", "locations" => "Exported", "accounts" => "Nothing to export")
      expect(status.select { |_table, mark| mark == "Left out" }.keys)
        .to match_array(%w[bulk_removals bulk_selection_marks bulk_selections import_uploads number_entries number_entry_lines scanner_sitting_entries scanner_sittings sessions])
      expect(covered_tables.map { |row| row["Why"] }).to all(match(/\S/))
    end

    it "maps each column to a field of the format or says why it is left out (AC-3.5)", :aggregate_failures do
      left_out, mapped = covered_columns.partition { |row| row["In the file"] == "Left out" }

      expect(left_out.map { |row| row["Why left out"] }).to all(match(/\S/))
      expect(mapped.map { |row| row["In the file"] } - fields).to be_empty
      expect(left_out.map { |row| row["Column"] }).to match_array(%w[
        accounts.id accounts.created_at accounts.updated_at
        locations.id locations.account_id locations.name_key locations.created_at locations.updated_at
        lots.id lots.account_id lots.lot_key lots.location_id
        users.id users.account_id users.password_digest users.admin users.created_at users.updated_at
      ])
    end
  end
end
