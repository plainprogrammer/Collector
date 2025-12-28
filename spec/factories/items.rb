# frozen_string_literal: true

FactoryBot.define do
  factory :item do
    association :collection

    # Default to MTGCard as catalog entry
    catalog_entry { association :mtg_card, mtg_set: (create(:mtg_set)) }

    quantity { 1 }

    # Delegated type detail - create MTGCardItemDetail by default
    after(:build) do |item|
      item.detail ||= build(:mtg_card_item_detail)
    end

    # Optional storage unit - not created by default
    storage_unit { nil }

    trait :with_storage do
      transient do
        storage_collection { instance.collection }
      end

      after(:build) do |item, evaluator|
        unless item.storage_unit
          storage = build(:storage_unit)
          storage.collections << evaluator.storage_collection
          item.storage_unit = storage
        end
      end
    end

    trait :bulk do
      quantity { 100 }
    end

    trait :foil do
      after(:build) do |item|
        item.detail.finish = "foil"
      end
    end

    trait :lightly_played do
      after(:build) do |item|
        item.detail.condition = "LP"
      end
    end
  end
end
