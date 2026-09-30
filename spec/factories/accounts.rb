FactoryBot.define do
  factory :account

  factory :user do
    sequence(:name) { |n| "Collector #{n}" }
    sequence(:email_address) { |n| "collector#{n}@example.test" }
    password { "correct horse battery" }

    factory :admin do
      admin { true }
    end
  end
end
