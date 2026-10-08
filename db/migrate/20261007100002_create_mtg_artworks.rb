# Spec 011 AC-3.7: one fingerprint per artwork, global catalog data (no account_id), with the printing whose image was
# fingerprinted and the digest of the settings it was made with. Built only by MTG::Art::BuildJob.
class CreateMTGArtworks < ActiveRecord::Migration[8.1]
  def change
    create_table :mtg_artworks do |t|
      t.string :illustration_id, null: false
      t.references :catalog_entry, null: false, foreign_key: true
      t.binary :fingerprint, null: false
      t.string :settings_digest, null: false
      t.timestamps
      t.index :illustration_id, unique: true
      t.index :settings_digest
    end
  end
end
