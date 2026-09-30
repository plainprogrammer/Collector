# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_30_000003) do
  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "catalog_entries", force: :cascade do |t|
    t.string "collectible_type", null: false
    t.string "external_key", null: false
    t.integer "catalog_set_id", null: false
    t.integer "catalog_identity_id", null: false
    t.string "number", null: false
    t.string "language", null: false
    t.string "name", null: false
    t.string "localized_name"
    t.string "kind", null: false
    t.date "released_on"
    t.string "image_url"
    t.string "content_digest", null: false
    t.datetime "retired_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_identity_id"], name: "index_catalog_entries_on_catalog_identity_id"
    t.index ["catalog_set_id"], name: "index_catalog_entries_on_catalog_set_id"
    t.index ["collectible_type", "external_key"], name: "index_catalog_entries_on_collectible_type_and_external_key", unique: true
    t.index ["kind", "retired_at"], name: "index_catalog_entries_on_kind_and_retired_at"
  end

  create_table "catalog_identities", force: :cascade do |t|
    t.string "collectible_type", null: false
    t.string "external_key", null: false
    t.string "name", null: false
    t.string "content_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collectible_type", "external_key"], name: "index_catalog_identities_on_collectible_type_and_external_key", unique: true
    t.index ["name"], name: "index_catalog_identities_on_name"
  end

  create_table "catalog_refresh_runs", force: :cascade do |t|
    t.string "collectible_type", null: false
    t.string "trigger", null: false
    t.string "status", null: false
    t.string "source_version"
    t.string "languages"
    t.integer "seen_count", default: 0, null: false
    t.integer "inserted_count", default: 0, null: false
    t.integer "updated_count", default: 0, null: false
    t.integer "retired_count", default: 0, null: false
    t.integer "restored_count", default: 0, null: false
    t.integer "malformed_count", default: 0, null: false
    t.text "message"
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collectible_type", "status", "started_at"], name: "idx_on_collectible_type_status_started_at_ed4a804a4c"
  end

  create_table "catalog_sets", force: :cascade do |t|
    t.string "collectible_type", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.date "released_on"
    t.string "parent_code"
    t.string "content_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collectible_type", "code"], name: "index_catalog_sets_on_collectible_type_and_code", unique: true
  end

  create_table "mtg_cards", force: :cascade do |t|
    t.integer "catalog_identity_id", null: false
    t.string "mana_cost"
    t.string "type_line"
    t.text "oracle_text"
    t.json "colors", default: [], null: false
    t.json "color_identity", default: [], null: false
    t.json "keywords", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_identity_id"], name: "index_mtg_cards_on_catalog_identity_id", unique: true
  end

  create_table "mtg_printings", force: :cascade do |t|
    t.integer "catalog_entry_id", null: false
    t.string "rarity", null: false
    t.json "finishes", default: [], null: false
    t.string "layout", null: false
    t.string "frame"
    t.string "border_color"
    t.string "security_stamp"
    t.json "variant_tags", default: [], null: false
    t.json "legalities", default: {}, null: false
    t.json "external_ids", default: {}, null: false
    t.json "faces", default: [], null: false
    t.string "scryfall_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_entry_id"], name: "index_mtg_printings_on_catalog_entry_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "catalog_entries", "catalog_identities"
  add_foreign_key "catalog_entries", "catalog_sets"
  add_foreign_key "mtg_cards", "catalog_identities"
  add_foreign_key "mtg_printings", "catalog_entries"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "accounts"
end
