FactoryBot.define do
  factory :lot do
    account { association(:user).account }
    entry { association(:mtg_printing).entry }
    quantity { 1 }
  end
end
