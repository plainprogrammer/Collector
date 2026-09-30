# AC-3.4: short, accented and multi-face names, queried exactly and with one misread character.
# Usage: bundle exec ruby spikes/card_scanner/script/name_edge_cases.rb
require "bundler/setup"
require_relative "../lib/card_scanner_spike"
require_relative "../lib/card_scanner_spike/name_index"

index = CardScannerSpike::NameIndex.new(File.join(CardScannerSpike::WORK_DIR, "names.sqlite3"))
abort "Build the name index first (build_name_index.rb)" if index.count.zero?
cases = index.short_names.map { |_, name| [ "shorter than 3", name ] } +
  [ "Æther Vial", "Lim-Dûl's Vault", "Jötun Grunt", "Dandân" ].map { [ "diacritic or ligature", it ] } +
  [ "Fire // Ice", "Fire", "Ice" ].map { [ "split", it ] } +
  [ "Bonecrusher Giant", "Stomp" ].map { [ "adventure", it ] } +
  [ "Delver of Secrets", "Insectile Aberration" ].map { [ "double-faced", it ] }
found = ->(expected, text) { (index.search(text).map(&:card_name) & expected).any? ? "yes" : "no" }

puts "| Category | Printed name | Expected card | Exact: top 3 | Misread | Misread: top 3 |", "|---|---|---|---|---|---|"
cases.each do |category, name|
  expected = index.card_names_for(name)
  misread = CardScannerSpike::Scoring.misread(name)
  shown = expected.empty? ? "(not indexed)" : expected.join("; ")
  puts "| #{category} | #{name} | #{shown} | #{found.call(expected, name)} | #{misread} | #{found.call(expected, misread)} |"
end
