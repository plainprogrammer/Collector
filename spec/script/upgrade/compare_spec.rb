require "rails_helper"
require Rails.root.join("script/upgrade/compare").to_s

RSpec.describe Upgrade::Compare, :upgrade do
  let(:dir) { upgrade_dir }
  let(:base) { [ "CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT, size INTEGER)",
    "INSERT INTO widgets VALUES (1, 'a', 10), (2, 'b', 20), (3, 'c', 30)" ] }
  let(:entry) { Struct.new(:table, :column, :kind, :migration, :reason, :matched, keyword_init: true) }

  # A fresh pair of files per call: an example may compare more than once.
  def databases(old_sql, new_sql)
    pair = SecureRandom.hex(4)
    [ old_sql, new_sql ].each_with_index.map do |statements, index|
      path = build_database(File.join(dir, "db#{pair}-#{index}.sqlite3")) { |db| db.execute_batch(statements.join(";\n")) }
      open_database(path)
    end
  end

  def compare(old_sql, new_sql, **) = described_class.new(*databases(old_sql, new_sql), **).call

  it "passes identical databases and prints a line per table with its counts (AC-4.1)", :aggregate_failures do
    report = compare(base, base)
    expect(report).to be_ok
    expect(report.lines.first).to match(/widgets\s+old\s+3\s+new\s+3\s+same/)
  end

  it "reports a missing row with the table and the first key (AC-4.2)", :aggregate_failures do
    report = compare(base, base.take(1) + [ "INSERT INTO widgets VALUES (1, 'a', 10), (3, 'c', 30)" ])
    expect(report.failures.map(&:kind)).to eq([ :rows_removed ])
    expect(report.to_lines.join("\n")).to include("widgets", "id = 2")
  end

  it "reports an extra row, a changed value (with its column), a dropped column and a dropped table (AC-4.2)", :aggregate_failures do
    extra = compare(base, base + [ "INSERT INTO widgets VALUES (4, 'd', 40)" ])
    changed = compare(base, base + [ "UPDATE widgets SET name = 'z' WHERE id = 3" ])
    dropped_column = compare(base, [ "CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT)", "INSERT INTO widgets VALUES (1, 'a'), (2, 'b'), (3, 'c')" ])
    dropped_table = compare(base, [ "CREATE TABLE other (id INTEGER PRIMARY KEY)" ])
    expect(extra.failures.map(&:kind)).to eq([ :rows_added ])
    expect(changed.failures.map { [ it.kind, it.column, it.key ] }).to eq([ [ :value_changed, "name", "id = 3" ] ])
    expect(dropped_column.failures.map { [ it.kind, it.column ] }).to eq([ [ :column_dropped, "size" ] ])
    expect(dropped_table.failures.map { [ it.kind, it.table ] }).to eq([ [ :table_dropped, "widgets" ] ])
  end

  it "ignores a column only the new table has, and a new table (AC-4.3)" do
    report = compare(base, base + [ "ALTER TABLE widgets ADD COLUMN note TEXT", "CREATE TABLE extras (id INTEGER PRIMARY KEY)" ])
    expect(report).to be_ok
  end

  it "says to fix the migration or list an expected change when a migration empties a column (AC-4.6)", :aggregate_failures do
    report = compare(base, base + [ "UPDATE widgets SET size = NULL" ])
    expect(report.failures.map { [ it.kind, it.column ] }).to eq([ [ :value_changed, "size" ] ])
    expect(report.to_lines.join("\n")).to include("fix it, or list the change in script/upgrade/expected_changes.yml")
  end

  it "passes a difference an expected change lists and prints it with its reason (AC-4.4)", :aggregate_failures do
    listed = entry.new(table: "widgets", column: "size", kind: "rewritten", migration: "1", reason: "Spec 99 rescales sizes")
    report = compare(base, base + [ "UPDATE widgets SET size = size * 2" ], expected: [ listed ])
    expect(report).to be_ok
    expect(report.to_lines.join("\n")).to include("expected: widgets.size rewritten (Spec 99 rescales sizes)")
    unlisted = compare(base, base + [ "UPDATE widgets SET name = 'q'" ], expected: [ listed ])
    expect(unlisted.failures.map(&:column)).to eq([ "name" ])
  end

  it "fails a live expected change that matches nothing and names it (AC-4.5)", :aggregate_failures do
    stale = entry.new(table: "widgets", column: "size", kind: "dropped", migration: "1", reason: "Spec 99 drops size")
    report = compare(base, base, expected: [ stale ])
    expect(report).not_to be_ok
    expect(report.to_lines.join("\n")).to include("widgets.size dropped (migration 1) matched no difference")
  end

  it "orders a table without an integer primary key by all its columns, so rowid order doesn't matter (AC-4.7)", :aggregate_failures do
    old = [ "CREATE TABLE pairs (a TEXT, b TEXT, PRIMARY KEY (a, b))", "INSERT INTO pairs VALUES ('x', '1'), ('y', '2')" ]
    reordered = [ "CREATE TABLE pairs (a TEXT, b TEXT, PRIMARY KEY (a, b))", "INSERT INTO pairs VALUES ('y', '2'), ('x', '1')" ]
    changed = [ "CREATE TABLE pairs (a TEXT, b TEXT, PRIMARY KEY (a, b))", "INSERT INTO pairs VALUES ('x', '1'), ('y', '3')" ]
    expect(compare(old, reordered)).to be_ok
    failure = compare(old, changed).failures.first
    expect(failure.kind).to eq(:value_changed)
    expect(failure.key).to include("row 2 of the ordering by a, b", "'y', '2'")
  end

  it "tells 1 from '1' and NULL from '' (decision 5's encoding; AC-4.7)", :aggregate_failures do
    old = [ "CREATE TABLE loose (id INTEGER PRIMARY KEY, v)", "INSERT INTO loose VALUES (1, 1), (2, NULL)" ]
    swapped = [ "CREATE TABLE loose (id INTEGER PRIMARY KEY, v)", "INSERT INTO loose VALUES (1, '1'), (2, '')" ]
    expect(compare(old, swapped).failures.map(&:key)).to eq([ "id = 1" ])
    expect(described_class.digest([ [ "1" ] ])).not_to eq(described_class.digest([ [ "'1'" ] ]))
  end

  it "skips schema_migrations, SQLite's own tables and a full-text table with its shadow tables (P5)", :aggregate_failures do
    sql = [ "CREATE TABLE names (id INTEGER PRIMARY KEY, name TEXT)", "CREATE TABLE schema_migrations (version TEXT)",
      "CREATE VIRTUAL TABLE names_fts USING fts5(name, content='names', content_rowid='id')", "INSERT INTO names VALUES (1, 'a')" ]
    rebuilt = sql + [ "INSERT INTO names_fts (names_fts) VALUES ('rebuild')" ]
    old_db, new_db = databases(sql, rebuilt)
    expect(described_class.tables(old_db)).to eq([ "names" ])
    expect(described_class.new(old_db, new_db).call).to be_ok
  end

  it "reads the facts of AC-2.3 back from a seeded database", :aggregate_failures do
    seeded = [ "CREATE TABLE accounts (id INTEGER PRIMARY KEY)", "CREATE TABLE users (id INTEGER PRIMARY KEY, password_digest TEXT)",
      "CREATE TABLE lots (id INTEGER PRIMARY KEY, account_id INTEGER)", "CREATE TABLE instance_settings (id INTEGER PRIMARY KEY, sign_up_open BOOLEAN)",
      "INSERT INTO accounts VALUES (1), (2)", "INSERT INTO users VALUES (1, 'x'), (2, 'y')", "INSERT INTO instance_settings VALUES (1, 1)",
      *Array.new(2000) { |i| "INSERT INTO lots VALUES (#{i + 1}, 1)" } ]
    full, thin = databases(seeded, seeded.reject { it.include?("(1, 1)") || it.start_with?("INSERT INTO lots") })
    expect(described_class.seed_problems(full)).to be_empty
    expect(described_class.seed_problems(thin).join("\n")).to include("fewer than 2,000 lots", "sign-up is not open")
  end

  it "reports a foreign key violation and a clean database (AC-3.5)", :aggregate_failures do
    clean, broken = databases(base, [ "PRAGMA foreign_keys = OFF", "CREATE TABLE parents (id INTEGER PRIMARY KEY)", "CREATE TABLE kids (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parents(id))",
      "INSERT INTO kids VALUES (1, 99)" ])
    expect(described_class.integrity(clean)).to be_empty
    expect(described_class.integrity(broken).join).to include("foreign_key_check: kids row 1")
  end

  it "requires the tables of a restore to be emptied and passes their removal (P4)", :aggregate_failures do
    old = [ "CREATE TABLE sessions (id INTEGER PRIMARY KEY)", "INSERT INTO sessions VALUES (1), (2)" ]
    optional = entry.new(table: "sessions", kind: "rows_removed", reason: "backup:restore ends every session")
    ended = compare(old, [ "CREATE TABLE sessions (id INTEGER PRIMARY KEY)" ], optional: [ optional ], emptied: %w[sessions])
    kept = compare(old, [ "CREATE TABLE sessions (id INTEGER PRIMARY KEY)", "INSERT INTO sessions VALUES (2)" ], optional: [ optional ], emptied: %w[sessions])
    expect(ended).to be_ok
    expect(kept.failures.map(&:kind)).to include(:not_emptied)
  end
end
