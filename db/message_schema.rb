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

ActiveRecord::Schema[8.2].define(version: 2026_05_25_232000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "direct_message_threads", force: :cascade do |t|
    t.string "public_id", null: false
    t.bigint "initiator_actor_id", null: false
    t.bigint "recipient_actor_id", null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiator_actor_id", "recipient_actor_id"], name: "index_direct_message_threads_on_participants"
    t.index ["public_id"], name: "index_direct_message_threads_on_public_id", unique: true
    t.check_constraint "initiator_actor_id <> recipient_actor_id", name: "chk_direct_message_threads_distinct_participants"
  end
end
