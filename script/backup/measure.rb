# AC-1.10, decision 13 (spec 030): times a backup and a restore of a SEEDED instance (a catalog of English-catalog size and
# 50,000 lots) and the longest wait of a write made while the backup runs. It builds its own database under tmp/ and never
# reads or writes storage/ or the maintainer's instance, so it needs nobody's database and no agent reads one. Run it in the
# test environment, whose only database is the primary, pointed at a scratch file:
#
#   mkdir -p tmp/measure && rm -f tmp/measure/primary.sqlite3*
#   export RAILS_ENV=test DATABASE_URL=sqlite3:$PWD/tmp/measure/primary.sqlite3
#   bin/rails db:schema:load
#   bin/rails runner script/backup/measure.rb
#
# The numbers are a seeded database's, not a real instance's: its rows are synthetic and their size is an estimate (the
# catalog is MEASURE_ENTRIES printings, default 100,000; the real Scryfall count isn't known to the plan). Record the
# printed counts and sizes beside the result. AC-5.6 (the maintainer's own restore) is the real-data check.
require Rails.root.join("lib/collector/backup").to_s
require "tmpdir"

abort "Run it against a scratch database under tmp/measure (see the header)." unless Rails.env.test? && ENV["DATABASE_URL"].to_s.include?("/tmp/measure/")

LOTS = 50_000
entries = Integer(ENV.fetch("MEASURE_ENTRIES", 100_000))
now = Time.current
digest = "d" * 64
legalities = %w[standard pioneer modern legacy vintage commander pauper brawl historic explorer].index_with { "legal" }

Catalog::Set.insert_all(Array.new(400) { |index| { id: index + 1, collectible_type: "mtg", code: "s#{index}", name: "Seeded set #{index}", content_digest: digest, created_at: now, updated_at: now } })
(1..entries).each_slice(5_000) do |ids|
  Catalog::Identity.insert_all(ids.map { |id| { id:, collectible_type: "mtg", external_key: "seed-identity-#{id}", name: "Seeded Card #{id}", content_digest: digest, created_at: now, updated_at: now } })
  Catalog::Entry.insert_all(ids.map do |id|
    { id:, collectible_type: "mtg", external_key: "seed-entry-#{id}", catalog_set_id: id % 400 + 1, catalog_identity_id: id, number: (id % 400).to_s, language: "en",
      name: "Seeded Card #{id}", kind: "card", content_digest: digest, created_at: now, updated_at: now }
  end)
  MTG::Printing.insert_all(ids.map do |id|
    { catalog_entry_id: id, rarity: "common", finishes: %w[nonfoil foil], layout: "normal", legalities:, external_ids: { "scryfall" => "seed-#{id}" },
      faces: [ { "name" => "Seeded Card #{id}", "mana_cost" => "{1}{R}", "type_line" => "Instant", "oracle_text" => "Deals 3 damage to any target. " * 6, "artist" => "A. Painter", "image_uris" => {} } ],
      scryfall_uri: "https://scryfall.com/card/s#{id % 400}/#{id}", created_at: now, updated_at: now }
  end)
end

unretired = Catalog::Entry.where(retired_at: nil).count
abort "The catalog holds #{unretired} unretired entries; the gate is 50,000." if unretired < LOTS

# The account is made before the clock starts: User.create! hashes a password with bcrypt, which the timed writes must not include.
account = User.create!(name: "Measure", email_address: "measure@example.test", password: "correct horse battery").account
ids = Catalog::Entry.where(retired_at: nil).order(:id).pluck(:id)
Lot.insert_all(ids.first(LOTS).map { |id| { account_id: account.id, catalog_entry_id: id, quantity: 1, lot_key: Lot.key_for(nil, nil, nil), created_at: now, updated_at: now } })
writer_ids = ids.drop(LOTS).first(2_000).presence || ids.first(2_000)

clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
primary = Collector::Backup::Databases.configured.primary
database_bytes = primary.size
waits = Queue.new
stop = false

Dir.mktmpdir("collector-measure") do |dir|
  directory = Pathname(dir).join("out").tap(&:mkpath)
  writer = Thread.new do
    ActiveRecord::Base.connection_pool.with_connection do
      index = 0
      until stop
        entry = Catalog::Entry.find(writer_ids[index % writer_ids.size])
        began = clock.call
        Lot.add!(account:, entry:) # the app's own write path, with no password hash in the timing
        waits << clock.call - began
        index += 1
        sleep 0.05
      end
    end
  end

  began = clock.call
  result = Collector::Backup::Create.new(directory:, source: primary).call
  backup_seconds = clock.call - began
  stop = true
  writer.join
  waited = Array.new(waits.size) { waits.pop }

  volume = Pathname(dir).join("volume").tap(&:mkpath)
  databases = Collector::Backup::Databases.new("primary" => volume.join("production.sqlite3"))
  began = clock.call
  Collector::Backup::Restore.new(file: result.path, databases:).call
  restore_seconds = clock.call - began

  manifest = Collector::Backup::Archive.read(result.path).manifest
  puts "| Measure | Value | Bar |", "|---|---|---|"
  puts "| Seeded database | #{Collector::Backup.size_phrase(database_bytes)} (#{Catalog::Entry.count} entries, #{unretired} unretired, #{Lot.count} lots) | gate: 50,000 unretired |"
  puts "| Backup file / snapshot | #{Collector::Backup.size_phrase(result.bytes)} / #{Collector::Backup.size_phrase(manifest.snapshot_bytes)} | |"
  puts "| Backup, verification included | #{format("%.1f", backup_seconds)} s | under 300 s: #{backup_seconds < 300 ? "met" : "MISSED"} |"
  puts "| Writes during the backup (Lot.add!, no password hash) | #{waited.size}, longest wait #{format("%.3f", waited.max.to_f)} s | under 5 s: #{waited.max.to_f < 5 ? "met" : "MISSED"} |"
  puts "| Restore | #{format("%.1f", restore_seconds)} s | under 300 s: #{restore_seconds < 300 ? "met" : "MISSED"} |"
  puts "| Write-ahead log after the run | #{Collector::Backup.size_phrase(File.size("#{primary}-wal"))} | recorded |" if File.exist?("#{primary}-wal")
end
