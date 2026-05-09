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

ActiveRecord::Schema[8.2].define(version: 2026_05_08_151000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "app_jump_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "destination_url", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.integer "max_uses", default: 0, null: false
    t.jsonb "policy", default: {}, null: false
    t.string "public_id", null: false
    t.datetime "purge_at", null: false
    t.integer "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "uses_count", default: 0, null: false
    t.index ["public_id"], name: "index_app_jump_links_on_public_id", unique: true
    t.index ["purge_at"], name: "index_app_jump_links_on_purge_at"
    t.index ["status_id"], name: "index_app_jump_links_on_status_id"
  end

  create_table "com_jump_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "destination_url", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.integer "max_uses", default: 0, null: false
    t.jsonb "policy", default: {}, null: false
    t.string "public_id", null: false
    t.datetime "purge_at", null: false
    t.integer "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "uses_count", default: 0, null: false
    t.index ["public_id"], name: "index_com_jump_links_on_public_id", unique: true
    t.index ["purge_at"], name: "index_com_jump_links_on_purge_at"
    t.index ["status_id"], name: "index_com_jump_links_on_status_id"
  end

  create_table "org_jump_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "destination_url", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.integer "max_uses", default: 0, null: false
    t.jsonb "policy", default: {}, null: false
    t.string "public_id", null: false
    t.datetime "purge_at", null: false
    t.integer "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "uses_count", default: 0, null: false
    t.index ["public_id"], name: "index_org_jump_links_on_public_id", unique: true
    t.index ["purge_at"], name: "index_org_jump_links_on_purge_at"
    t.index ["status_id"], name: "index_org_jump_links_on_status_id"
  end
end
