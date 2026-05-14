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

ActiveRecord::Schema[8.2].define(version: 2026_05_13_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "client_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "public_id", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "visitor_id", null: false
    t.index ["public_id"], name: "index_client_accounts_on_public_id", unique: true
    t.index ["visitor_id"], name: "index_client_accounts_on_visitor_id", unique: true
  end

  create_table "client_visitor_statuses", force: :cascade do |t|
  end

  create_table "client_visitors", force: :cascade do |t|
    t.string "audience", null: false
    t.datetime "created_at", null: false
    t.string "issuer", null: false
    t.datetime "last_authenticated_at"
    t.integer "lock_version", default: 0, null: false
    t.string "public_id", default: "", null: false
    t.bigint "source_record_id", null: false
    t.bigint "status_id", default: 0, null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["issuer", "subject", "audience"], name: "index_client_visitors_on_issuer_and_subject_and_audience", unique: true
    t.index ["public_id"], name: "index_client_visitors_on_public_id", unique: true
    t.index ["source_record_id"], name: "index_client_visitors_on_source_record_id", unique: true
    t.index ["status_id"], name: "index_client_visitors_on_status_id"
  end

  add_foreign_key "client_visitors", "client_visitor_statuses", column: "status_id", validate: false
end
