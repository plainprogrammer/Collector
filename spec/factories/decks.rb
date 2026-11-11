FactoryBot.define do
  # A deck made as the New deck form makes one: through Deck::Creation, so its zones exist. `format` is a format key of
  # the "mtg" type (the factory's default collectible); pass `pair: "other/standard"` for another type's format.
  factory :deck do
    account { association(:user).account }
    transient do
      name { "Izzet Tempo" }
      format { "modern" }
      pair { "mtg/#{format}" }
    end

    initialize_with { Deck::Creation.new(account:, name:, format: pair).tap(&:save!).deck }
    to_create { |instance| instance } # Deck::Creation already wrote it
  end
end
