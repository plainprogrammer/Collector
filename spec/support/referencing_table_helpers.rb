# Fills the tables that reference accounts, for the specs that copy accounts (spec 090 decision 5 (a) and (c)).
module ReferencingTableHelpers
  # One row in each of the thirteen tables that reference accounts, as the upgrade seed makes them (`script/upgrade/seeds/next.rb`).
  #
  # Writes through the models, so the example needs a database that holds the household columns; it does not need `:committed`.
  #
  # @param user [User] the user whose account owns the rows
  # @return [void]
  def fill_every_referencing_table(user)
    account = user.account
    entry = import_printing
    Lot.add!(account:, entry:, quantity: 2, finish: "nonfoil")
    Scanner::Sitting.add!(account:, printing: entry, finish: "nonfoil", reading_key: SecureRandom.hex(16))
    session = user.sessions.create!
    selection = BulkSelection.for(session)
    account.lots.limit(3).pluck(:id).each { |lot_id| selection.marks.create!(lot_id:, account:) }
    BulkRemoval.create!(session:, account:, copies: 2,
      lots_data: [ { "catalog_entry_id" => entry.id, "finish" => "foil", "condition" => "damaged", "price_paid_cents" => nil, "quantity" => 2 } ])
    Location.create!(account:, name: "Binder A")
    deck = Deck::Creation.new(account:, name: "Upgrade Deck", format: "mtg/modern").tap(&:save!).deck
    Lot.add!(account:, entry:, quantity: 3, finish: "nonfoil", location: deck.zone("main"))
    Deck::Proxy.add!(account:, zone: deck.zone("sideboard"), entry:, finish: "foil", quantity: 2)
    NumberEntry.add!(account:, entry:, quantity: 2, finish: "foil", line_key: SecureRandom.hex(16))
    ImportUpload.store!(account:, bytes: "{}", plan: ImportHelpers::FakePlan.new("fingerprint"))
  end
end
