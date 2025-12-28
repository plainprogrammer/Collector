# frozen_string_literal: true

FactoryBot.define do
  factory :mtg_card_item_detail do
    condition { "NM" }
    finish { "nonfoil" }
    language { "EN" }
    signed { false }
    altered { false }
    graded { false }
    grading_service { nil }
    grade { nil }

    trait :near_mint do
      condition { "NM" }
    end

    trait :lightly_played do
      condition { "LP" }
    end

    trait :moderately_played do
      condition { "MP" }
    end

    trait :heavily_played do
      condition { "HP" }
    end

    trait :damaged do
      condition { "DMG" }
    end

    trait :foil do
      finish { "foil" }
    end

    trait :etched do
      finish { "etched" }
    end

    trait :signed do
      signed { true }
    end

    trait :altered do
      altered { true }
    end

    trait :graded do
      graded { true }
      grading_service { "PSA" }
      grade { "9" }
    end

    trait :japanese do
      language { "JP" }
    end
  end
end
