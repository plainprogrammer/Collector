# Owned printings for collection specs (spec 006): each call makes a new printing and a lot of it.
module CollectionHelpers
  def owned_printing(name = "Lightning Bolt", account:, set: nil, number: nil, language: "en", localized_name: nil,
    released_on: nil, finishes: %w[nonfoil foil etched], **lot)
    identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
    set ||= create(:catalog_set, **{ released_on: }.compact)
    entry = create(:catalog_entry, identity:, name:, set:, language:, localized_name:, **{ number:, released_on: }.compact)
    create(:mtg_printing, entry:, finishes:)
    create(:lot, account:, entry:, **lot)
  end
end

RSpec.configure do |config|
  %i[model request system].each { |type| config.include CollectionHelpers, type: }
end
