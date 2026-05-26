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

ActiveRecord::Schema[8.2].define(version: 2026_05_26_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "action_push_native_devices", force: :cascade do |t|
    t.string "name"
    t.string "platform", null: false
    t.string "token", null: false
    t.string "owner_type"
    t.bigint "owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_action_push_native_devices_on_owner"
  end

  create_table "visitor_banners", force: :cascade do |t|
    t.bigint "visitor_id", null: false
    t.string "title", default: "", null: false
    t.text "body", null: false
    t.boolean "published", default: false, null: false
    t.datetime "starts_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "ends_at", default: "9999-12-31 23:59:59", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["visitor_id"], name: "index_visitor_banners_on_visitor_id"
    t.check_constraint "ends_at > starts_at", name: "visitor_banners_ends_at_after_starts_at"
  end

  create_table "visitor_email_statuses", force: :cascade do |t|
  end

  create_table "visitor_emails", force: :cascade do |t|
    t.string "address", default: "", null: false
    t.string "address_digest"
    t.datetime "locked_at", default: ::Float::INFINITY, null: false
    t.integer "otp_attempts_count", default: 0, null: false
    t.text "otp_counter", default: "", null: false
    t.datetime "otp_expires_at", default: -::Float::INFINITY, null: false
    t.datetime "otp_last_sent_at", default: -::Float::INFINITY, null: false
    t.string "otp_private_key", default: "", null: false
    t.boolean "undeletable", default: false, null: false
    t.binary "verification_token_digest"
    t.string "public_id", limit: 21, null: false
    t.bigint "visitor_id", null: false
    t.bigint "visitor_email_status_id", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "promotional", default: true, null: false
    t.boolean "notifiable", default: true, null: false
    t.boolean "subscribable", default: true, null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.index ["address_digest"], name: "index_visitor_emails_on_active_address_digest", unique: true, where: "((address_digest IS NOT NULL) AND (visitor_email_status_id <> 4))"
    t.index ["discarded_at"], name: "index_visitor_emails_on_discarded_at"
    t.index ["otp_last_sent_at"], name: "index_visitor_emails_on_otp_last_sent_at"
    t.index ["public_id"], name: "index_visitor_emails_on_public_id", unique: true
    t.index ["purged_at"], name: "index_visitor_emails_on_purged_at"
    t.index ["visitor_email_status_id"], name: "index_visitor_emails_on_visitor_email_status_id"
    t.index ["visitor_id"], name: "index_visitor_emails_on_visitor_id"
  end

  add_check_constraint "visitor_emails", "discarded_at <= purged_at", name: "chk_visitor_emails_retention_order", validate: false

  create_table "visitor_multi_factor_statuses", force: :cascade do |t|
  end

  create_table "visitor_multi_factors", force: :cascade do |t|
  end

  create_table "visitor_passkey_statuses", force: :cascade do |t|
  end

  create_table "visitor_passkeys", force: :cascade do |t|
    t.string "description", default: "", null: false
    t.uuid "external_id", null: false
    t.datetime "last_used_at"
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.string "public_id", limit: 21, null: false
    t.string "webauthn_id", default: "", null: false
    t.bigint "visitor_id", null: false
    t.bigint "status_id", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.index ["discarded_at"], name: "index_visitor_passkeys_on_discarded_at"
    t.index ["public_id"], name: "index_visitor_passkeys_on_public_id", unique: true
    t.index ["purged_at"], name: "index_visitor_passkeys_on_purged_at"
    t.index ["status_id"], name: "index_visitor_passkeys_on_status_id"
    t.index ["visitor_id"], name: "index_visitor_passkeys_on_visitor_id"
    t.index ["webauthn_id"], name: "index_visitor_passkeys_on_webauthn_id", unique: true
  end

  add_check_constraint "visitor_passkeys", "discarded_at <= purged_at", name: "chk_visitor_passkeys_retention_order", validate: false

  create_table "visitor_preference_currencies", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_currencies_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_currencies_on_preference_id", unique: true
  end

  create_table "visitor_preference_currency_options", force: :cascade do |t|
  end

  create_table "visitor_preference_date_format_options", force: :cascade do |t|
  end

  create_table "visitor_preference_date_formats", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_date_formats_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_date_formats_on_preference_id", unique: true
  end

  create_table "visitor_preference_densities", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_densities_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_densities_on_preference_id", unique: true
  end

  create_table "visitor_preference_density_options", force: :cascade do |t|
  end

  create_table "visitor_preference_items_per_page_options", force: :cascade do |t|
  end

  create_table "visitor_preference_items_per_pages", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_items_per_pages_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_items_per_pages_on_preference_id", unique: true
  end

  create_table "visitor_preference_language_options", force: :cascade do |t|
    t.index ["id"], name: "index_visitor_preference_language_options_on_id", unique: true
  end

  create_table "visitor_preference_languages", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_languages_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_languages_on_preference_id", unique: true
  end

  create_table "visitor_preference_motion_options", force: :cascade do |t|
  end

  create_table "visitor_preference_motions", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_motions_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_motions_on_preference_id", unique: true
  end

  create_table "visitor_preference_r18_display_stopper_options", force: :cascade do |t|
  end

  create_table "visitor_preference_r18_display_stoppers", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_r18_display_stoppers_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_r18_display_stoppers_on_preference_id", unique: true
  end

  create_table "visitor_preference_region_options", force: :cascade do |t|
    t.index ["id"], name: "index_visitor_preference_region_options_on_id", unique: true
  end

  create_table "visitor_preference_regions", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_regions_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_regions_on_preference_id", unique: true
  end

  create_table "visitor_preference_theme_options", force: :cascade do |t|
    t.index ["id"], name: "index_visitor_preference_theme_options_on_id", unique: true
  end

  create_table "visitor_preference_themes", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_themes_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_themes_on_preference_id", unique: true
  end

  create_table "visitor_preference_time_format_options", force: :cascade do |t|
  end

  create_table "visitor_preference_time_formats", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_time_formats_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_time_formats_on_preference_id", unique: true
  end

  create_table "visitor_preference_timezone_options", force: :cascade do |t|
    t.index ["id"], name: "index_visitor_preference_timezone_options_on_id", unique: true
  end

  create_table "visitor_preference_timezones", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_visitor_preference_timezones_on_option_id"
    t.index ["preference_id"], name: "index_visitor_preference_timezones_on_preference_id", unique: true
  end

  create_table "visitor_preferences", force: :cascade do |t|
    t.bigint "visitor_id", null: false
    t.boolean "consented", default: false, null: false
    t.boolean "functional", default: false, null: false
    t.boolean "performant", default: false, null: false
    t.boolean "targetable", default: false, null: false
    t.datetime "consented_at"
    t.uuid "consent_version"
    t.string "language", default: "ja", null: false
    t.string "region", default: "jp", null: false
    t.string "timezone", default: "Asia/Tokyo", null: false
    t.string "theme", default: "sy", null: false
    t.string "currency", default: "jpy", null: false
    t.string "date_format", default: "iso", null: false
    t.string "time_format", default: "hour_24", null: false
    t.string "motion", default: "standard", null: false
    t.string "density", default: "standard", null: false
    t.string "items_per_page", default: "20", null: false
    t.string "public_id", limit: 21
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_visitor_preferences_on_public_id", unique: true
    t.index ["visitor_id"], name: "index_visitor_preferences_on_visitor_id", unique: true
  end

  create_table "visitor_secret_kinds", force: :cascade do |t|
  end

  create_table "visitor_secret_statuses", force: :cascade do |t|
  end

  create_table "visitor_secrets", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "password_digest", default: "", null: false
    t.datetime "last_used_at"
    t.integer "uses_remaining", default: 1, null: false
    t.string "public_id", limit: 21, null: false
    t.bigint "visitor_id", null: false
    t.bigint "visitor_secret_status_id", default: 1, null: false
    t.bigint "visitor_secret_kind_id", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.index ["public_id"], name: "index_visitor_secrets_on_public_id", unique: true
    t.index ["visitor_id"], name: "index_visitor_secrets_on_visitor_id"
    t.index ["visitor_secret_kind_id"], name: "index_visitor_secrets_on_visitor_secret_kind_id"
    t.index ["visitor_secret_status_id"], name: "index_visitor_secrets_on_visitor_secret_status_id"
    t.check_constraint "discarded_at <= purged_at", name: "chk_customer_secrets_retention_order"
  end

  create_table "visitor_statuses", force: :cascade do |t|
  end

  create_table "visitor_telephone_statuses", force: :cascade do |t|
  end

  create_table "visitor_telephones", force: :cascade do |t|
    t.string "number", default: "", null: false
    t.string "number_digest"
    t.datetime "locked_at", default: -::Float::INFINITY, null: false
    t.integer "otp_attempts_count", default: 0, null: false
    t.text "otp_counter", default: "", null: false
    t.datetime "otp_expires_at", default: -::Float::INFINITY, null: false
    t.string "otp_private_key", default: "", null: false
    t.string "public_id", limit: 21, null: false
    t.bigint "visitor_id", null: false
    t.bigint "visitor_telephone_status_id", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.index ["discarded_at"], name: "index_visitor_telephones_on_discarded_at"
    t.index ["number_digest"], name: "index_visitor_telephones_on_active_number_digest", unique: true, where: "((number_digest IS NOT NULL) AND (visitor_telephone_status_id <> 4))"
    t.index ["public_id"], name: "index_visitor_telephones_on_public_id", unique: true
    t.index ["purged_at"], name: "index_visitor_telephones_on_purged_at"
    t.index ["visitor_id"], name: "index_visitor_telephones_on_visitor_id"
    t.index ["visitor_telephone_status_id"], name: "index_visitor_telephones_on_visitor_telephone_status_id"
  end

  add_check_constraint "visitor_telephones", "discarded_at <= purged_at", name: "chk_visitor_telephones_retention_order", validate: false

  create_table "visitor_visibilities", force: :cascade do |t|
  end

  create_table "visitor_withdrawal_cycle_events", force: :cascade do |t|
    t.bigint "visitor_withdrawal_cycle_id", null: false
    t.bigint "visitor_id", null: false
    t.bigint "from_status_id"
    t.bigint "to_status_id", null: false
    t.datetime "occurred_at", null: false
    t.string "token_public_id", limit: 64, default: "", null: false
    t.string "reason", limit: 64, default: "", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_status_id"], name: "index_visitor_withdrawal_cycle_events_on_from_status_id"
    t.index ["occurred_at"], name: "index_visitor_withdrawal_cycle_events_on_occurred_at"
    t.index ["to_status_id"], name: "index_visitor_withdrawal_cycle_events_on_to_status_id"
    t.index ["visitor_id"], name: "index_visitor_withdrawal_cycle_events_on_visitor_id"
    t.index ["visitor_withdrawal_cycle_id"], name: "idx_on_visitor_withdrawal_cycle_id_b3ca5138c1"
  end

  create_table "visitor_withdrawal_cycle_statuses", force: :cascade do |t|
  end

  create_table "visitor_withdrawal_cycles", force: :cascade do |t|
    t.string "public_id", limit: 21, null: false
    t.bigint "visitor_id", null: false
    t.bigint "status_id", default: 10, null: false
    t.datetime "began_at", null: false
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["began_at"], name: "index_visitor_withdrawal_cycles_on_began_at"
    t.index ["completed_at"], name: "index_visitor_withdrawal_cycles_on_completed_at"
    t.index ["discarded_at"], name: "index_visitor_withdrawal_cycles_on_discarded_at"
    t.index ["public_id"], name: "index_visitor_withdrawal_cycles_on_public_id", unique: true
    t.index ["purged_at"], name: "index_visitor_withdrawal_cycles_on_purged_at"
    t.index ["status_id"], name: "index_visitor_withdrawal_cycles_on_status_id"
    t.index ["visitor_id"], name: "index_visitor_withdrawal_cycles_on_visitor_id"
    t.check_constraint "discarded_at <= purged_at", name: "chk_visitor_withdrawal_cycles_retention_order"
  end

  create_table "visitors", force: :cascade do |t|
    t.datetime "deactivated_at"
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.boolean "multi_factor_enabled", default: false, null: false
    t.string "public_id", default: "", null: false
    t.bigint "status_id", default: 2, null: false
    t.bigint "visibility_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.datetime "withdrawn_at", default: ::Float::INFINITY
    t.datetime "withdrawal_started_at"
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.bigint "multi_factor_id", default: 0, null: false
    t.bigint "multi_factor_status_id", default: 5, null: false
    t.datetime "terminated_at"
    t.text "birthdate"
    t.index ["deactivated_at"], name: "index_visitors_on_deactivated_at", where: "(deactivated_at IS NOT NULL)"
    t.index ["discarded_at"], name: "index_visitors_on_discarded_at"
    t.index ["multi_factor_id"], name: "index_visitors_on_multi_factor_id"
    t.index ["multi_factor_status_id"], name: "index_visitors_on_multi_factor_status_id"
    t.index ["public_id"], name: "index_visitors_on_public_id", unique: true
    t.index ["purged_at"], name: "index_visitors_on_purged_at"
    t.index ["status_id"], name: "index_visitors_on_status_id"
    t.index ["terminated_at"], name: "index_visitors_on_terminated_at", where: "(terminated_at IS NOT NULL)"
    t.index ["visibility_id"], name: "index_visitors_on_visibility_id"
    t.index ["withdrawal_started_at"], name: "index_visitors_on_withdrawal_started_at", where: "(withdrawal_started_at IS NOT NULL)"
    t.index ["withdrawn_at"], name: "index_visitors_on_withdrawn_at", where: "(withdrawn_at IS NOT NULL)"
    t.check_constraint "birthdate IS NULL OR char_length(birthdate) <= 1000", name: "chk_visitors_birthdate_length"
    t.check_constraint "discarded_at <= purged_at", name: "chk_customers_retention_order"
  end

  add_foreign_key "visitor_banners", "visitors", validate: false
  add_foreign_key "visitor_emails", "visitor_email_statuses"
  add_foreign_key "visitor_emails", "visitors"
  add_foreign_key "visitor_passkeys", "visitor_passkey_statuses", column: "status_id"
  add_foreign_key "visitor_passkeys", "visitors"
  add_foreign_key "visitor_preference_currencies", "visitor_preference_currency_options", column: "option_id"
  add_foreign_key "visitor_preference_currencies", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_date_formats", "visitor_preference_date_format_options", column: "option_id"
  add_foreign_key "visitor_preference_date_formats", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_densities", "visitor_preference_density_options", column: "option_id"
  add_foreign_key "visitor_preference_densities", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_items_per_pages", "visitor_preference_items_per_page_options", column: "option_id"
  add_foreign_key "visitor_preference_items_per_pages", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_languages", "visitor_preference_language_options", column: "option_id"
  add_foreign_key "visitor_preference_languages", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_motions", "visitor_preference_motion_options", column: "option_id"
  add_foreign_key "visitor_preference_motions", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_r18_display_stoppers", "visitor_preference_r18_display_stopper_options", column: "option_id"
  add_foreign_key "visitor_preference_r18_display_stoppers", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_regions", "visitor_preference_region_options", column: "option_id"
  add_foreign_key "visitor_preference_regions", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_themes", "visitor_preference_theme_options", column: "option_id"
  add_foreign_key "visitor_preference_themes", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_time_formats", "visitor_preference_time_format_options", column: "option_id"
  add_foreign_key "visitor_preference_time_formats", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preference_timezones", "visitor_preference_timezone_options", column: "option_id"
  add_foreign_key "visitor_preference_timezones", "visitor_preferences", column: "preference_id"
  add_foreign_key "visitor_preferences", "visitors"
  add_foreign_key "visitor_secrets", "visitor_secret_kinds"
  add_foreign_key "visitor_secrets", "visitor_secret_statuses"
  add_foreign_key "visitor_secrets", "visitors"
  add_foreign_key "visitor_telephones", "visitor_telephone_statuses"
  add_foreign_key "visitor_telephones", "visitors"
  add_foreign_key "visitor_withdrawal_cycle_events", "visitor_withdrawal_cycle_statuses", column: "from_status_id", validate: false
  add_foreign_key "visitor_withdrawal_cycle_events", "visitor_withdrawal_cycle_statuses", column: "to_status_id", validate: false
  add_foreign_key "visitor_withdrawal_cycle_events", "visitor_withdrawal_cycles", validate: false
  add_foreign_key "visitor_withdrawal_cycle_events", "visitors", validate: false
  add_foreign_key "visitor_withdrawal_cycles", "visitor_withdrawal_cycle_statuses", column: "status_id", validate: false
  add_foreign_key "visitor_withdrawal_cycles", "visitors", validate: false
  add_foreign_key "visitors", "visitor_multi_factor_statuses", column: "multi_factor_status_id"
  add_foreign_key "visitors", "visitor_multi_factors", column: "multi_factor_id"
  add_foreign_key "visitors", "visitor_statuses", column: "status_id"
  add_foreign_key "visitors", "visitor_visibilities", column: "visibility_id"
end
