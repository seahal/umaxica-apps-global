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

ActiveRecord::Schema[8.2].define(version: 2026_05_14_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "com_preference_binding_methods", force: :cascade do |t|
  end

  create_table "com_preference_cookies", force: :cascade do |t|
    t.uuid "consent_version"
    t.boolean "consented", default: false, null: false
    t.datetime "consented_at"
    t.datetime "created_at", null: false
    t.boolean "functional", default: false, null: false
    t.boolean "performant", default: false, null: false
    t.bigint "preference_id", null: false
    t.boolean "targetable", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["preference_id"], name: "index_com_preference_cookies_on_preference_id", unique: true
  end

  create_table "com_preference_currencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_currencies_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_currencies_on_preference_id", unique: true
  end

  create_table "com_preference_currency_options", force: :cascade do |t|
  end

  create_table "com_preference_date_format_options", force: :cascade do |t|
  end

  create_table "com_preference_date_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_date_formats_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_date_formats_on_preference_id", unique: true
  end

  create_table "com_preference_dbsc_statuses", force: :cascade do |t|
  end

  create_table "com_preference_densities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_densities_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_densities_on_preference_id", unique: true
  end

  create_table "com_preference_density_options", force: :cascade do |t|
  end

  create_table "com_preference_items_per_page_options", force: :cascade do |t|
  end

  create_table "com_preference_items_per_pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_items_per_pages_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_items_per_pages_on_preference_id", unique: true
  end

  create_table "com_preference_language_options", force: :cascade do |t|
  end

  create_table "com_preference_languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_languages_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_languages_on_preference_id", unique: true
  end

  create_table "com_preference_motion_options", force: :cascade do |t|
  end

  create_table "com_preference_motions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_motions_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_motions_on_preference_id", unique: true
  end

  create_table "com_preference_region_options", force: :cascade do |t|
  end

  create_table "com_preference_regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_regions_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_regions_on_preference_id", unique: true
  end

  create_table "com_preference_statuses", force: :cascade do |t|
  end

  create_table "com_preference_theme_options", force: :cascade do |t|
  end

  create_table "com_preference_themes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_themes_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_themes_on_preference_id", unique: true
  end

  create_table "com_preference_time_format_options", force: :cascade do |t|
  end

  create_table "com_preference_time_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_time_formats_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_time_formats_on_preference_id", unique: true
  end

  create_table "com_preference_timezone_options", force: :cascade do |t|
  end

  create_table "com_preference_timezones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_com_preference_timezones_on_option_id"
    t.index ["preference_id"], name: "index_com_preference_timezones_on_preference_id", unique: true
  end

  create_table "com_preferences", force: :cascade do |t|
    t.bigint "binding_method_id", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "dbsc_challenge"
    t.datetime "dbsc_challenge_issued_at"
    t.jsonb "dbsc_public_key"
    t.string "dbsc_session_id"
    t.bigint "dbsc_status_id", default: 0, null: false
    t.string "device_id"
    t.string "device_id_digest"
    t.string "jti"
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.string "public_id", null: false
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.bigint "replaced_by_id"
    t.bigint "status_id", default: 2, null: false
    t.binary "token_digest"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["binding_method_id"], name: "index_com_preferences_on_binding_method_id"
    t.index ["dbsc_session_id"], name: "index_com_preferences_on_dbsc_session_id", unique: true
    t.index ["dbsc_status_id"], name: "index_com_preferences_on_dbsc_status_id"
    t.index ["device_id"], name: "index_com_preferences_on_device_id"
    t.index ["device_id_digest"], name: "index_com_preferences_on_device_id_digest"
    t.index ["jti"], name: "index_com_preferences_on_jti", unique: true
    t.index ["public_id"], name: "index_com_preferences_on_public_id", unique: true
    t.index ["purge_at"], name: "index_com_preferences_on_purge_at"
    t.index ["replaced_by_id"], name: "index_com_preferences_on_replaced_by_id"
    t.index ["status_id"], name: "index_com_preferences_on_status_id"
    t.index ["token_digest"], name: "index_com_preferences_on_token_digest"
    t.index ["used_at"], name: "index_com_preferences_on_used_at"
  end

  create_table "visitor_preference_currencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_currencies_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_currencies_on_preference_id", unique: true
  end

  create_table "visitor_preference_currency_options", force: :cascade do |t|
  end

  create_table "visitor_preference_date_format_options", force: :cascade do |t|
  end

  create_table "visitor_preference_date_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_date_formats_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_date_formats_on_preference_id", unique: true
  end

  create_table "visitor_preference_densities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_densities_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_densities_on_preference_id", unique: true
  end

  create_table "visitor_preference_density_options", force: :cascade do |t|
  end

  create_table "visitor_preference_items_per_page_options", force: :cascade do |t|
  end

  create_table "visitor_preference_items_per_pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_items_per_pages_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_items_per_pages_on_preference_id", unique: true
  end

  create_table "visitor_preference_language_options", force: :cascade do |t|
  end

  create_table "visitor_preference_languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_languages_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_languages_on_preference_id", unique: true
  end

  create_table "visitor_preference_motion_options", force: :cascade do |t|
  end

  create_table "visitor_preference_motions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_motions_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_motions_on_preference_id", unique: true
  end

  create_table "visitor_preference_region_options", force: :cascade do |t|
  end

  create_table "visitor_preference_regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_regions_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_regions_on_preference_id", unique: true
  end

  create_table "visitor_preference_theme_options", force: :cascade do |t|
  end

  create_table "visitor_preference_themes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_themes_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_themes_on_preference_id", unique: true
  end

  create_table "visitor_preference_time_format_options", force: :cascade do |t|
  end

  create_table "visitor_preference_time_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_time_formats_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_time_formats_on_preference_id", unique: true
  end

  create_table "visitor_preference_timezone_options", force: :cascade do |t|
  end

  create_table "visitor_preference_timezones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_timezones_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_timezones_on_preference_id", unique: true
  end

  create_table "visitor_preferences", force: :cascade do |t|
    t.uuid "consent_version"
    t.boolean "consented", default: false, null: false
    t.datetime "consented_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "jpy", null: false
    t.string "date_format", default: "iso", null: false
    t.string "density", default: "standard", null: false
    t.boolean "functional", default: false, null: false
    t.string "items_per_page", default: "20", null: false
    t.string "language", default: "ja", null: false
    t.string "motion", default: "standard", null: false
    t.boolean "performant", default: false, null: false
    t.string "public_id", limit: 21
    t.string "region", default: "jp", null: false
    t.boolean "targetable", default: false, null: false
    t.string "theme", default: "sy", null: false
    t.string "time_format", default: "hour_24", null: false
    t.string "timezone", default: "Asia/Tokyo", null: false
    t.datetime "updated_at", null: false
    t.bigint "visitor_id", null: false
    t.index ["public_id"], name: "index_visitor_preferences_on_public_id", unique: true
    t.index ["visitor_id"], name: "index_visitor_preferences_on_visitor_id", unique: true
  end

  add_foreign_key "com_preference_cookies", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preference_currencies", "com_preference_currency_options", column: "option_id"
  add_foreign_key "com_preference_currencies", "com_preferences", column: "preference_id"
  add_foreign_key "com_preference_date_formats", "com_preference_date_format_options", column: "option_id"
  add_foreign_key "com_preference_date_formats", "com_preferences", column: "preference_id"
  add_foreign_key "com_preference_densities", "com_preference_density_options", column: "option_id"
  add_foreign_key "com_preference_densities", "com_preferences", column: "preference_id"
  add_foreign_key "com_preference_items_per_pages", "com_preference_items_per_page_options", column: "option_id"
  add_foreign_key "com_preference_items_per_pages", "com_preferences", column: "preference_id"
  add_foreign_key "com_preference_languages", "com_preference_language_options", column: "option_id", name: "fk_com_preference_languages_on_option_id", validate: false
  add_foreign_key "com_preference_languages", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preference_motions", "com_preference_motion_options", column: "option_id"
  add_foreign_key "com_preference_motions", "com_preferences", column: "preference_id"
  add_foreign_key "com_preference_regions", "com_preference_region_options", column: "option_id", name: "fk_com_preference_regions_on_option_id", validate: false
  add_foreign_key "com_preference_regions", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preference_themes", "com_preference_theme_options", column: "option_id", name: "fk_com_preference_themes_on_option_id", validate: false
  add_foreign_key "com_preference_themes", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preference_time_formats", "com_preference_time_format_options", column: "option_id"
  add_foreign_key "com_preference_time_formats", "com_preferences", column: "preference_id"
  add_foreign_key "com_preference_timezones", "com_preference_timezone_options", column: "option_id", name: "fk_com_preference_timezones_on_option_id", validate: false
  add_foreign_key "com_preference_timezones", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preferences", "com_preference_binding_methods", column: "binding_method_id", name: "fk_com_preferences_on_binding_method_id", validate: false
  add_foreign_key "com_preferences", "com_preference_dbsc_statuses", column: "dbsc_status_id", name: "fk_com_preferences_on_dbsc_status_id", validate: false
  add_foreign_key "com_preferences", "com_preference_statuses", column: "status_id", name: "fk_com_preferences_on_status_id", validate: false
  add_foreign_key "com_preferences", "com_preferences", column: "replaced_by_id", on_delete: :nullify, validate: false
  add_foreign_key "visitor_preference_currencies", "visitor_preference_currency_options", column: "option_id"
  add_foreign_key "visitor_preference_currencies", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_date_formats", "visitor_preference_date_format_options", column: "option_id"
  add_foreign_key "visitor_preference_date_formats", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_densities", "visitor_preference_density_options", column: "option_id"
  add_foreign_key "visitor_preference_densities", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_items_per_pages", "visitor_preference_items_per_page_options", column: "option_id"
  add_foreign_key "visitor_preference_items_per_pages", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_motions", "visitor_preference_motion_options", column: "option_id"
  add_foreign_key "visitor_preference_motions", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_time_formats", "visitor_preference_time_format_options", column: "option_id"
  add_foreign_key "visitor_preference_time_formats", "visitor_preferences", column: "preference_id"
end
