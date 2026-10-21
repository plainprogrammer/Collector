FactoryBot.define do
  factory :location do
    account { association(:user).account }
    sequence(:name) { |n| "Binder #{n}" }
  end
end
