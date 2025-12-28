# frozen_string_literal: true

FactoryBot.define do
  factory :collection do
    sequence(:name) { |n| "Collection #{n}" }
    description { "A test collection" }
    item_type { "mtg_card" }

    association :catalog

    trait :with_mtgjson_catalog do
      association :catalog, :mtgjson
    end
  end
end
