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

ActiveRecord::Schema[8.2].define(version: 2026_05_20_143001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "client_notification_records", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_client_notification_records_on_public_id", unique: true
    t.index ["user_id"], name: "index_client_notification_records_on_user_id"
  end

  create_table "member_notifications", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.bigint "user_notification_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_member_notifications_on_public_id", unique: true
    t.index ["user_notification_id"], name: "index_member_notifications_on_user_notification_id"
  end

  add_foreign_key "member_notifications", "client_notification_records", column: "user_notification_id", on_delete: :cascade, validate: false
end
