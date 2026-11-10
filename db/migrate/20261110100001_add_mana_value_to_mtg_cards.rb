# A card's mana value, Scryfall's cmc (spec 058 decision 1). Nullable: an existing row has none until the next catalog
# refresh fills it (MTG::Scryfall::Source#reapply?), and a card the source gives no value stays NULL, which is not zero.
# A float because the values are whole numbers or halves, exact in a double, and a later sum or average needs no
# conversion. Reversible: SQLite copies the table to
# remove the column, which is safe here because no foreign key points at mtg_cards (it only points at
# catalog_identities), unlike the tables AddLocationToLots had to protect. if_not_exists guards a re-run of the up.
class AddManaValueToMTGCards < ActiveRecord::Migration[8.1]
  def change
    add_column :mtg_cards, :mana_value, :float, if_not_exists: true
  end
end
