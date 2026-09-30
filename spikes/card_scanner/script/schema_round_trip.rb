# AC-3.1: does an FTS5 trigram table survive Rails' schema.rb dump and load?
# Usage: bundle exec ruby spikes/card_scanner/script/schema_round_trip.rb
require "bundler/setup"
require "active_record"
require "stringio"
require "tmpdir"

FTS_SQL = "SELECT sql FROM sqlite_master WHERE name = 'names_fts'".freeze

Dir.mktmpdir("fts-round-trip") do |dir|
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(dir, "source.sqlite3"))
  source = ActiveRecord::Base.connection
  source.create_table(:names) { |t| t.string :norm, null: false }
  source.create_virtual_table(:names_fts, :fts5, [ "norm", "content='names'", "content_rowid='id'", "tokenize='trigram remove_diacritics 1'" ])
  before = source.select_value(FTS_SQL)
  schema = StringIO.new
  ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, schema)
  File.write(File.join(dir, "schema.rb"), schema.string)

  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(dir, "loaded.sqlite3"))
  load File.join(dir, "schema.rb")
  loaded = ActiveRecord::Base.connection
  after = loaded.select_value(FTS_SQL)
  loaded.execute("INSERT INTO names (norm) VALUES ('lightning bolt')")
  loaded.execute("INSERT INTO names_fts (names_fts) VALUES ('rebuild')")
  hits = loaded.select_value("SELECT count(*) FROM names_fts WHERE names_fts MATCH '\"ghtn\"'")
  puts "Dumped schema:", schema.string, "Before: #{before}", "After:  #{after}",
    "Identical: #{before == after}", "Trigram query after load finds the row: #{hits == 1}"
end
