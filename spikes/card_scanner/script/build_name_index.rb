# AC-3.2, AC-3.5: builds the name index from the English catalog; reports time, size and count.
# Usage: bin/rails runner spikes/card_scanner/script/build_name_index.rb
require_relative "../lib/card_scanner_spike"
require_relative "../lib/card_scanner_spike/name_index"

clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
path = File.join(CardScannerSpike::WORK_DIR, "names.sqlite3")
FileUtils.mkdir_p(File.dirname(path))
FileUtils.rm_f(path)
started = clock.call
english = Catalog::Entry.searchable.where(collectible_type: "mtg", language: "en")
rows = english.distinct.pluck(:name).map { [ it, it ] }
english.joins("JOIN mtg_printings ON mtg_printings.catalog_entry_id = catalog_entries.id")
  .pluck("catalog_entries.name", "mtg_printings.faces").each do |name, faces|
    faces = JSON.parse(faces) if faces.is_a?(String)
    rows.concat(faces.map { [ name, it.fetch("name") ] }) if faces.size > 1
  end
read = clock.call
count = CardScannerSpike::NameIndex.new(path).rebuild(rows.uniq)
finished = clock.call
fts_bytes = begin
  SQLite3::Database.new(path).get_first_value("SELECT sum(pgsize) FROM dbstat WHERE name LIKE 'names_fts%'")
rescue SQLite3::SQLException
  nil
end
puts({ names: count, read_s: (read - started).round(2), build_s: (finished - read).round(2),
       total_s: (finished - started).round(2), file_bytes: File.size(path), fts_bytes: }.to_json)
