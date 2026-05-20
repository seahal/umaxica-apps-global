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

ActiveRecord::Schema[8.2].define(version: 2026_05_07_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "operator_notifications", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.bigint "staff_notification_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_operator_notifications_on_public_id", unique: true
    t.index ["staff_notification_id"], name: "index_operator_notifications_on_staff_notification_id"
  end

  create_table "staff_notifications", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.bigint "staff_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_staff_notifications_on_public_id", unique: true
    t.index ["staff_id"], name: "index_staff_notifications_on_staff_id"
  end

  add_foreign_key "operator_notifications", "staff_notifications", on_delete: :cascade, validate: false
end
