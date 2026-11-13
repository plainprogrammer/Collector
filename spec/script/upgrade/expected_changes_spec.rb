require "rails_helper"
require Rails.root.join("script/upgrade/rules").to_s

RSpec.describe Upgrade::ExpectedChanges, :upgrade do
  let(:dir) { upgrade_dir }
  let(:current) { %w[20261001000001 20261101100001] }

  let(:entry) do
    <<~YAML
      changes:
        - table: lots
          column: lot_key
          kind: rewritten
          migration: "20261101100001"
          reason: "Spec 033 decision 2"
    YAML
  end

  def load_yaml(body, previous: [])
    path = File.join(dir, "expected_changes.yml")
    File.write(path, body)
    described_class.load(path, previous_versions: previous, current_versions: current)
  end

  it "keeps an entry whose migration the previous release lacks as live (AC-4.4)", :aggregate_failures do
    loaded = load_yaml(entry)
    expect(loaded.errors).to be_empty
    expect(loaded.live.map { [ it.table, it.column, it.kind, it.migration ] }).to eq([ [ "lots", "lot_key", "rewritten", "20261101100001" ] ])
  end

  it "retires an entry whose migration the previous release already has, without failing (AC-4.5)", :aggregate_failures do
    loaded = load_yaml(entry, previous: %w[20261001000001 20261101100001])
    expect(loaded.live).to be_empty
    expect(loaded.retired.size).to eq(1)
    expect(loaded.errors).to be_empty
  end

  it "reads an unquoted migration number as the version it is" do
    expect(load_yaml(entry.sub('"20261101100001"', "20261101100001")).live.first.migration).to eq("20261101100001")
  end

  it "names the entry that is incomplete, has an unknown kind, or rewrites without a column (AC-4.5)", :aggregate_failures do
    expect(load_yaml("changes:\n  - table: lots\n    kind: dropped\n    migration: '20261101100001'\n").errors)
      .to eq([ "expected_changes.yml entry 1 has no reason" ])
    expect(load_yaml(entry.sub("rewritten", "mangled")).errors.first).to include("entry 1", "mangled")
    expect(load_yaml(entry.sub("    column: lot_key\n", "")).errors.first).to include("names its column")
  end

  it "names an entry whose migration is no file of the code under test (AC-4.5)" do
    expect(load_yaml(entry.sub("20261101100001", "20269999999999")).errors.first).to include("20269999999999", "not a file in db/migrate/ or db/prices_migrate/")
  end

  it "reads a version of db/prices_migrate as live, and names one in neither directory (spec 081 AC-6.8)", :aggregate_failures do
    prices = entry.sub("20261101100001", "20261113100001").sub("lots", "price_changes")
    path = File.join(dir, "expected_changes.yml")
    File.write(path, prices)
    loaded = described_class.load(path, previous_versions: [], current_versions: current + %w[20261113100001])
    expect(loaded.errors).to be_empty
    expect(loaded.live.map(&:migration)).to eq(%w[20261113100001])
    expect(load_yaml(prices).errors.first).to include("20261113100001", "is not a file in db/migrate/ or db/prices_migrate/")
  end

  it "refuses an unknown top-level key and a file that is not a mapping", :aggregate_failures do
    expect(load_yaml("changes: []\nextra: 1\n").errors.first).to include("extra")
    expect(load_yaml("- 1\n").errors.first).to include("mapping")
  end

  it "lists the tables a restore empties as rows_removed entries (P4)", :aggregate_failures do
    expect(described_class::RESTORE_ENDS_SESSIONS).to eq(%w[sessions bulk_removals bulk_selections bulk_selection_marks])
    expect(described_class.restore_effects.map(&:table)).to eq(described_class::RESTORE_ENDS_SESSIONS)
    expect(described_class.restore_effects.map(&:kind).uniq).to eq([ "rows_removed" ])
  end

  it "names every table the schema cascades from sessions, so the allowance can't go stale (P4, review m8)" do
    connection = ActiveRecord::Base.connection
    cascading = ->(parents) { connection.tables.select { |table| connection.foreign_keys(table).any? { it.on_delete == :cascade && parents.include?(it.to_table) } } }
    closure = [ "sessions" ]
    closure |= cascading.call(closure) until cascading.call(closure).all? { closure.include?(it) }
    expect(closure).to match_array(described_class::RESTORE_ENDS_SESSIONS),
      "a table now cascades from sessions: update RESTORE_ENDS_SESSIONS and spec 031's decision 7, FR-4 and AC-6.2 (a PATCH)"
  end

  it "ships valid: no error (every entry names a migration of the working tree) and no retired entry" do
    versions = Rails.root.glob("db/migrate/*.rb").map { it.basename.to_s[/\A\d+/] }
    real = described_class.load(Rails.root.join("script/upgrade/expected_changes.yml"), previous_versions: [], current_versions: versions)
    expect([ real.errors, real.retired ]).to all(be_empty)
  end
end
