# Seed for the release not yet cut (spec 031 decision 4). Run by `bin/rails runner -` on a fresh instance of the image built
# from the code under test (AC-2.6) and, once a release step has renamed this file to a version, in that release's image.
# It fills every table of main (seed_exceptions.yml lists none under `next`). The last line it prints is what the harness reads.
password = "upgrade-password-1234"
marker = "upgrade-marker"
now = Time.current

sets = %w[ups upt].each_with_index.map do |code, index|
  Catalog::Set.create!(collectible_type: "mtg", code:, name: "Upgrade Set #{code.upcase}", released_on: Date.new(2020 + index, 1, 1),
    content_digest: "upgrade-seed")
end

names = Array.new(50) { |index| format("Upgrade Dragon %02d", index + 1) }
entries = names.each_with_index.map do |name, index|
  set = sets[index % 2]
  identity = Catalog::Identity.create!(collectible_type: "mtg", external_key: "upgrade-identity-#{index}", name:, content_digest: "upgrade-seed")
  entry = Catalog::Entry.create!(collectible_type: "mtg", external_key: "upgrade-entry-#{index}", set:, identity:, number: (index + 1).to_s,
    language: "en", name:, kind: "card", released_on: set.released_on, content_digest: "upgrade-seed")
  MTG::Card.create!(identity:, mana_cost: "{R}", type_line: "Creature", oracle_text: "Seed text.")
  MTG::Printing.create!(entry:, rarity: "common", finishes: %w[nonfoil foil], layout: "normal", illustration_id: "upgrade-illustration-#{index}",
    scryfall_uri: "https://scryfall.com/card/#{set.code}/#{index + 1}",
    faces: [ { "name" => name, "mana_cost" => "{R}", "type_line" => "Creature", "oracle_text" => "Seed text.", "artist" => "Nobody", "image_uris" => {} } ])
  entry
end
Catalog::NameIndex.new("mtg").rebuild

ada, = User::Command.call(email: "ada@upgrade.example", password:)
grace = User.create!(name: "Grace", email_address: "grace@upgrade.example", password:)
InstanceSetting.current.update!(sign_up_open: true)
[ ada, grace ].each { |user| user.sessions.create!(ip_address: "127.0.0.1", user_agent: "upgrade-seed") }

# 50 printings x 2 finishes x 5 conditions x 4 prices = 2,000 lots for Ada; Grace's collection stays empty.
variants = %w[nonfoil foil].product(%w[near_mint lightly_played moderately_played heavily_played damaged], [ nil, 100, 250, 1999 ])
Lot.insert_all(entries.each_with_index.flat_map do |entry, index|
  variants.each_with_index.map do |(finish, condition, price), position|
    { account_id: ada.account_id, catalog_entry_id: entry.id, quantity: 1 + (index + position) % 7, finish:, condition:, price_paid_cents: price,
      lot_key: Lot.key_for(finish, condition, price), created_at: now, updated_at: now }
  end
end)
Scanner::Sitting.add!(account: ada.account, printing: entries.first, finish: "nonfoil", reading_key: SecureRandom.hex(16))

session = ada.sessions.first
selection = BulkSelection.for(session)
ada.account.lots.limit(3).pluck(:id).each { |lot_id| selection.marks.create!(lot_id:, account: ada.account) }
BulkRemoval.create!(session:, account: ada.account, copies: 2,
  lots_data: [ { "catalog_entry_id" => entries.first.id, "finish" => "foil", "condition" => "damaged", "price_paid_cents" => nil, "quantity" => 2 } ])

Catalog::RefreshRun.create!(collectible_type: "mtg", trigger: "manual", status: "applied", source_version: "upgrade-seed", languages: "en",
  started_at: now - 60, finished_at: now, seen_count: 50, inserted_count: 50)
MTG::ArtBuild.create!(status: "finished", job_id: "upgrade-seed", catalog_version: "upgrade-seed", settings_digest: "upgrade-seed",
  index_file: "art-index-upgrade.bin.gz", started_at: now - 60, heartbeat_at: now, finished_at: now, total_count: 50, indexed_count: 50)
MTG::Artwork.create!(entry: entries.first, illustration_id: "upgrade-illustration-0", fingerprint: "\x00".b * 128, settings_digest: "upgrade-seed")
locations = [ "Binder A", "Shelf B" ].map { |location| Location.create!(account: ada.account, name: location) }
NumberEntry.add!(account: ada.account, entry: entries.first, quantity: 2, finish: "foil", line_key: SecureRandom.hex(16))
plan = Object.new
def plan.fingerprint(checksum) = "upgrade-seed-#{checksum}"
upload = ImportUpload.store!(account: grace.account, bytes: "{}", plan:)
ActiveStorage::VariantRecord.create!(blob: upload.file.blob, variation_digest: "upgrade-seed")
Catalog::RefreshJob.set(wait: 1.year).perform_later("mtg", marker)

facts = { release: "next", password:, marker:, locations: locations.map(&:name),
  users: [ { email: ada.email_address, lots: ada.account.lots.count, names: }, { email: grace.email_address, lots: 0, names: [] } ] }
puts "UPGRADE-SEED-COMPLETE #{facts.to_json}"
