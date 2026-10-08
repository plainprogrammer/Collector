# Spec 011 AC-3.2, AC-3.11: each art build's run, global like the catalog's refresh runs, with its job id and a
# heartbeat so a re-run or a crashed build never blocks the next one.
class CreateMTGArtBuilds < ActiveRecord::Migration[8.1]
  def change
    create_table :mtg_art_builds do |t|
      t.string :status, null: false
      t.string :job_id
      t.string :catalog_version
      t.string :settings_digest
      t.string :index_file
      t.integer :total_count, :without_image_count, :fetched_count, :fingerprinted_count, :failed_count, :indexed_count,
        null: false, default: 0
      t.text :message
      t.datetime :started_at, null: false
      t.datetime :heartbeat_at, null: false
      t.datetime :finished_at
      t.timestamps
      t.index %i[status started_at]
      t.index :job_id
    end
  end
end
