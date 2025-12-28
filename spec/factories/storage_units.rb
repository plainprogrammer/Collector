# frozen_string_literal: true

FactoryBot.define do
  factory :storage_unit do
    sequence(:name) { |n| "Storage Unit #{n}" }
    unit_type { "box" }
    notes { nil }
    parent { nil }

    trait :shelf do
      unit_type { "shelf" }
    end

    trait :binder do
      unit_type { "binder" }
    end

    trait :deck do
      unit_type { "deck" }
    end

    trait :with_parent do
      association :parent, factory: :storage_unit
    end
  end
end
