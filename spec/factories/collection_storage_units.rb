# frozen_string_literal: true

FactoryBot.define do
  factory :collection_storage_unit do
    association :collection
    association :storage_unit
  end
end
