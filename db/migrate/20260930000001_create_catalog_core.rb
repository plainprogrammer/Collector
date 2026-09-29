class CreateCatalogCore < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_sets do |t|
      t.string :collectible_type, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.date :released_on
      t.string :parent_code
      t.string :content_digest, null: false
      t.timestamps
      t.index %i[collectible_type code], unique: true
    end

    create_table :catalog_identities do |t|
      t.string :collectible_type, null: false
      t.string :external_key, null: false
      t.string :name, null: false
      t.string :content_digest, null: false
      t.timestamps
      t.index %i[collectible_type external_key], unique: true
      t.index :name
    end

    create_table :catalog_entries do |t|
      t.string :collectible_type, null: false
      t.string :external_key, null: false
      t.references :catalog_set, null: false, foreign_key: true
      t.references :catalog_identity, null: false, foreign_key: true
      t.string :number, null: false
      t.string :language, null: false
      t.string :name, null: false
      t.string :localized_name
      t.string :kind, null: false
      t.date :released_on
      t.string :image_url
      t.string :content_digest, null: false
      t.datetime :retired_at
      t.timestamps
      t.index %i[collectible_type external_key], unique: true
      t.index %i[kind retired_at]
    end

    create_table :catalog_refresh_runs do |t|
      t.string :collectible_type, null: false
      t.string :trigger, null: false
      t.string :status, null: false
      t.string :source_version
      t.string :languages
      t.integer :seen_count, null: false, default: 0
      t.integer :inserted_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :retired_count, null: false, default: 0
      t.integer :restored_count, null: false, default: 0
      t.integer :malformed_count, null: false, default: 0
      t.text :message
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
      t.index %i[collectible_type status started_at]
    end
  end
end
