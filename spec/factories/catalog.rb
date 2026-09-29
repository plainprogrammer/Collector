FactoryBot.define do
  factory :catalog_set, class: "Catalog::Set" do
    collectible_type { "mtg" }
    sequence(:code) { |n| "s#{n}" }
    name { "Set #{code.upcase}" }
    released_on { Date.new(2020, 1, 1) }
    content_digest { "digest" }
  end

  factory :catalog_identity, class: "Catalog::Identity" do
    collectible_type { "mtg" }
    sequence(:external_key) { |n| "identity-#{n}" }
    name { "Lightning Bolt" }
    content_digest { "digest" }
  end

  factory :catalog_entry, class: "Catalog::Entry" do
    collectible_type { "mtg" }
    sequence(:external_key) { |n| "entry-#{n}" }
    set factory: :catalog_set
    identity factory: :catalog_identity
    sequence(:number, &:to_s)
    language { "en" }
    name { identity.name }
    kind { "card" }
    released_on { set.released_on }
    content_digest { "digest" }

    trait :retired do
      retired_at { 1.day.ago }
    end
  end

  factory :mtg_printing, class: "MTG::Printing" do
    entry factory: :catalog_entry
    rarity { "common" }
    finishes { %w[foil nonfoil] }
    layout { "normal" }
    faces do
      [ { "name" => entry.name, "mana_cost" => "{R}", "type_line" => "Instant",
          "oracle_text" => "Lightning Bolt deals 3 damage to any target.", "artist" => "Christopher Moeller",
          "image_uris" => {} } ]
    end
    scryfall_uri { "https://scryfall.com/card/#{entry.set.code}/#{entry.number}" }
  end

  factory :catalog_refresh_run, class: "Catalog::RefreshRun" do
    collectible_type { "mtg" }
    trigger { "scheduled" }
    status { "applied" }
    started_at { 1.hour.ago }
    finished_at { 30.minutes.ago }
  end
end
