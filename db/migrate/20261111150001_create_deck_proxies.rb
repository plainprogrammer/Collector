# Proxies (spec 068, #254): cards a deck's zone needs and the collector doesn't own, one row per zone, printing and finish.
# Additive: one new table, nothing else changes. A zone's or a deck's removal removes its proxies through the foreign key on
# the zone's location (the format change moves a dropped zone's proxies out first, in the app), and an account's deletion
# removes them through its own. The unique index uses COALESCE so that a proxy with no finish (a printing that lists none)
# is unique too: SQLite treats two NULLs as different in a plain unique index. Guarded, so a run that stopped part way is
# finished by the next boot.
class CreateDeckProxies < ActiveRecord::Migration[8.1]
  def change
    create_table :deck_proxies, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :location, null: false, foreign_key: { on_delete: :cascade } # the zone
      t.references :catalog_entry, null: false, foreign_key: true
      t.string :finish
      t.integer :quantity, null: false
      t.timestamps
      t.check_constraint "quantity BETWEEN 1 AND 9999", name: "deck_proxies_quantity_range"
    end
    add_index :deck_proxies, "location_id, catalog_entry_id, COALESCE(finish, '')", unique: true,
      name: "index_deck_proxies_on_zone_entry_and_finish", if_not_exists: true
  end
end
