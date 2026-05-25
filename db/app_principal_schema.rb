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

ActiveRecord::Schema[8.2].define(version: 2026_05_20_143000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "accounts", force: :cascade do |t|
    t.bigint "accountable_id", null: false
    t.string "accountable_type", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["accountable_type", "accountable_id"], name: "index_accounts_on_accountable_type_and_accountable_id", unique: true
    t.index ["email"], name: "index_accounts_on_email", unique: true
  end

  create_table "apple_auths", force: :cascade do |t|
    t.text "access_token", null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.datetime "expires_at", null: false
    t.string "name", default: "", null: false
    t.string "provider", default: "", null: false
    t.text "refresh_token", null: false
    t.string "uid", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_apple_auths_on_user_id"
  end

  create_table "client_banners", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", default: "", null: false
    t.text "body", null: false
    t.boolean "published", default: false, null: false
    t.datetime "starts_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "ends_at", default: "9999-12-31 23:59:59", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_client_banners_on_user_id"
    t.check_constraint "ends_at > starts_at", name: "user_banners_ends_at_after_starts_at"
  end

  create_table "client_bulletins", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "public_id", limit: 21, null: false
    t.string "title", null: false
    t.text "body"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_client_bulletins_on_public_id", unique: true
    t.index ["user_id"], name: "index_client_bulletins_on_user_id"
  end

  create_table "client_email_statuses", force: :cascade do |t|
  end

  create_table "client_emails", force: :cascade do |t|
    t.string "address", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "locked_at", default: ::Float::INFINITY, null: false
    t.integer "otp_attempts_count", default: 0, null: false
    t.text "otp_counter", default: "", null: false
    t.datetime "otp_expires_at", default: -::Float::INFINITY, null: false
    t.datetime "otp_last_sent_at", default: -::Float::INFINITY, null: false
    t.string "otp_private_key", default: "", null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.binary "verification_token_digest"
    t.bigint "user_email_status_id", default: 0, null: false
    t.string "address_digest"
    t.boolean "undeletable", default: false, null: false
    t.boolean "promotional", default: true, null: false
    t.boolean "notifiable", default: true, null: false
    t.boolean "subscribable", default: true, null: false
    t.index ["address_digest"], name: "index_client_emails_on_address_digest", unique: true, where: "(address_digest IS NOT NULL)"
    t.index ["otp_last_sent_at"], name: "index_client_emails_on_otp_last_sent_at"
    t.index ["public_id"], name: "index_client_emails_on_public_id", unique: true
    t.index ["user_email_status_id"], name: "index_client_emails_on_user_email_status_id"
    t.index ["user_id"], name: "index_client_emails_on_user_id"
  end

  create_table "client_member_deletions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_client_member_deletions_on_member_id"
    t.index ["user_id", "member_id"], name: "index_client_member_deletions_on_user_id_and_member_id", unique: true
  end

  create_table "client_member_discoveries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_client_member_discoveries_on_member_id"
    t.index ["user_id", "member_id"], name: "index_client_member_discoveries_on_user_id_and_member_id", unique: true
  end

  create_table "client_member_impersonations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_client_member_impersonations_on_member_id"
    t.index ["user_id", "member_id"], name: "index_client_member_impersonations_on_user_id_and_member_id", unique: true
  end

  create_table "client_member_observations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_client_member_observations_on_member_id"
    t.index ["user_id", "member_id"], name: "index_client_member_observations_on_user_id_and_member_id", unique: true
  end

  create_table "client_member_revocations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_client_member_revocations_on_member_id"
    t.index ["user_id", "member_id"], name: "index_client_member_revocations_on_user_id_and_member_id", unique: true
  end

  create_table "client_member_suspensions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_client_member_suspensions_on_member_id"
    t.index ["user_id", "member_id"], name: "index_client_member_suspensions_on_user_id_and_member_id", unique: true
  end

  create_table "client_members", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_client_members_on_member_id"
    t.index ["user_id", "member_id"], name: "index_client_members_on_user_id_and_member_id", unique: true
  end

  create_table "client_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "joined_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "left_at", default: -::Float::INFINITY, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id", "workspace_id"], name: "index_client_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["workspace_id"], name: "index_client_memberships_on_workspace_id"
  end

  create_table "client_multi_factor_statuses", force: :cascade do |t|
  end

  create_table "client_multi_factors", force: :cascade do |t|
  end

  create_table "client_one_time_password_statuses", force: :cascade do |t|
  end

  create_table "client_one_time_passwords", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_otp_at", default: -::Float::INFINITY, null: false
    t.string "private_key", limit: 1024, default: "", null: false
    t.string "public_id", limit: 21, null: false
    t.string "title", limit: 32
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_identity_one_time_password_status_id", default: 0, null: false
    t.index ["public_id"], name: "index_client_one_time_passwords_on_public_id", unique: true
    t.index ["user_id"], name: "index_client_one_time_passwords_on_user_id"
    t.index ["user_identity_one_time_password_status_id"], name: "idx_on_user_identity_one_time_password_status_id_45a55f4ebd"
  end

  create_table "client_passkey_statuses", force: :cascade do |t|
  end

  create_table "client_passkeys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", default: "", null: false
    t.uuid "external_id", null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "webauthn_id", default: "", null: false
    t.bigint "status_id", default: 1, null: false
    t.datetime "last_used_at"
    t.string "public_id", limit: 21, null: false
    t.index ["public_id"], name: "index_client_passkeys_on_public_id", unique: true
    t.index ["status_id"], name: "index_client_passkeys_on_status_id"
    t.index ["user_id"], name: "index_user_identity_passkeys_on_user_id"
    t.index ["webauthn_id"], name: "index_client_passkeys_on_webauthn_id", unique: true
  end

  create_table "client_preference_currencies", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_currencies_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_currencies_on_preference_id", unique: true
  end

  create_table "client_preference_currency_options", force: :cascade do |t|
  end

  create_table "client_preference_date_format_options", force: :cascade do |t|
  end

  create_table "client_preference_date_formats", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_date_formats_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_date_formats_on_preference_id", unique: true
  end

  create_table "client_preference_densities", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_densities_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_densities_on_preference_id", unique: true
  end

  create_table "client_preference_density_options", force: :cascade do |t|
  end

  create_table "client_preference_items_per_page_options", force: :cascade do |t|
  end

  create_table "client_preference_items_per_pages", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_items_per_pages_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_items_per_pages_on_preference_id", unique: true
  end

  create_table "client_preference_language_options", force: :cascade do |t|
  end

  create_table "client_preference_languages", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_languages_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_languages_on_preference_id", unique: true
  end

  create_table "client_preference_motion_options", force: :cascade do |t|
  end

  create_table "client_preference_motions", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_motions_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_motions_on_preference_id", unique: true
  end

  create_table "client_preference_region_options", force: :cascade do |t|
  end

  create_table "client_preference_regions", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_regions_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_regions_on_preference_id", unique: true
  end

  create_table "client_preference_theme_options", force: :cascade do |t|
  end

  create_table "client_preference_themes", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_themes_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_themes_on_preference_id", unique: true
  end

  create_table "client_preference_time_format_options", force: :cascade do |t|
  end

  create_table "client_preference_time_formats", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_time_formats_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_time_formats_on_preference_id", unique: true
  end

  create_table "client_preference_timezone_options", force: :cascade do |t|
  end

  create_table "client_preference_timezones", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_client_preference_timezones_on_option_id"
    t.index ["preference_id"], name: "index_client_preference_timezones_on_preference_id", unique: true
  end

  create_table "client_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.boolean "consented", default: false, null: false
    t.boolean "functional", default: false, null: false
    t.boolean "performant", default: false, null: false
    t.boolean "targetable", default: false, null: false
    t.datetime "consented_at"
    t.uuid "consent_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "language", default: "ja", null: false
    t.string "region", default: "jp", null: false
    t.string "timezone", default: "Asia/Tokyo", null: false
    t.string "theme", default: "sy", null: false
    t.string "public_id", limit: 21
    t.string "currency", default: "jpy", null: false
    t.string "date_format", default: "iso", null: false
    t.string "time_format", default: "hour_24", null: false
    t.string "motion", default: "standard", null: false
    t.string "density", default: "standard", null: false
    t.string "items_per_page", default: "20", null: false
    t.index ["public_id"], name: "index_client_preferences_on_public_id", unique: true
    t.index ["user_id"], name: "index_client_preferences_on_user_id", unique: true
  end

  create_table "client_secret_kinds", force: :cascade do |t|
  end

  create_table "client_secret_statuses", force: :cascade do |t|
  end

  create_table "client_secrets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", default: "", null: false
    t.string "password_digest", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "uses_remaining", default: 1, null: false
    t.bigint "user_identity_secret_status_id", default: 0, null: false
    t.bigint "user_secret_kind_id", default: 0, null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.index ["public_id"], name: "index_client_secrets_on_public_id", unique: true
    t.index ["user_id"], name: "index_client_secrets_on_user_id"
    t.index ["user_identity_secret_status_id"], name: "index_client_secrets_on_user_identity_secret_status_id"
    t.index ["user_secret_kind_id"], name: "index_client_secrets_on_user_secret_kind_id"
    t.check_constraint "discarded_at <= purged_at", name: "chk_user_secrets_retention_order"
  end

  create_table "client_social_apple_statuses", force: :cascade do |t|
  end

  create_table "client_social_apples", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "token_expires_at", null: false
    t.datetime "last_authenticated_at"
    t.string "provider", default: "apple", null: false
    t.string "refresh_token", default: "", null: false
    t.string "token", default: "", null: false
    t.string "uid", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "status_id", default: 1, null: false
    t.index ["status_id"], name: "index_client_social_apples_on_status_id"
    t.index ["token_expires_at"], name: "index_client_social_apples_on_token_expires_at"
    t.index ["uid", "provider"], name: "index_client_social_apples_on_uid_and_provider", unique: true
    t.index ["user_id"], name: "index_user_identity_social_apples_on_user_id_unique", unique: true, where: "(user_id IS NOT NULL)"
  end

  create_table "client_social_google_statuses", force: :cascade do |t|
  end

  create_table "client_social_googles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "token_expires_at", null: false
    t.datetime "last_authenticated_at"
    t.string "provider", default: "google_app", null: false
    t.string "refresh_token", default: "", null: false
    t.string "token", default: "", null: false
    t.string "uid", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "status_id", default: 1, null: false
    t.index ["status_id"], name: "index_client_social_googles_on_status_id"
    t.index ["token_expires_at"], name: "index_client_social_googles_on_token_expires_at"
    t.index ["uid", "provider"], name: "index_client_social_googles_on_uid_and_provider", unique: true
    t.index ["user_id"], name: "index_user_identity_social_googles_on_user_id_unique", unique: true, where: "(user_id IS NOT NULL)"
  end

  create_table "client_statuses", force: :cascade do |t|
  end

  create_table "client_telephone_statuses", force: :cascade do |t|
  end

  create_table "client_telephones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "locked_at", default: -::Float::INFINITY, null: false
    t.string "number", default: "", null: false
    t.integer "otp_attempts_count", default: 0, null: false
    t.text "otp_counter", default: "", null: false
    t.datetime "otp_expires_at", default: -::Float::INFINITY, null: false
    t.string "otp_private_key", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_identity_telephone_status_id", default: 0, null: false
    t.string "public_id", limit: 21, null: false
    t.string "number_digest"
    t.index ["number_digest"], name: "index_client_telephones_on_number_digest", unique: true, where: "(number_digest IS NOT NULL)"
    t.index ["public_id"], name: "index_client_telephones_on_public_id", unique: true
    t.index ["user_id"], name: "index_client_telephones_on_user_id"
    t.index ["user_identity_telephone_status_id"], name: "index_client_telephones_on_user_identity_telephone_status_id"
  end

  create_table "client_visibilities", force: :cascade do |t|
  end

  create_table "client_withdrawal_cycle_events", force: :cascade do |t|
    t.bigint "client_withdrawal_cycle_id", null: false
    t.bigint "client_id", null: false
    t.bigint "from_status_id"
    t.bigint "to_status_id", null: false
    t.datetime "occurred_at", null: false
    t.string "token_public_id", limit: 64, default: "", null: false
    t.string "reason", limit: 64, default: "", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_client_withdrawal_cycle_events_on_client_id"
    t.index ["client_withdrawal_cycle_id"], name: "idx_on_client_withdrawal_cycle_id_f40263c70b"
    t.index ["from_status_id"], name: "index_client_withdrawal_cycle_events_on_from_status_id"
    t.index ["occurred_at"], name: "index_client_withdrawal_cycle_events_on_occurred_at"
    t.index ["to_status_id"], name: "index_client_withdrawal_cycle_events_on_to_status_id"
  end

  create_table "client_withdrawal_cycle_statuses", force: :cascade do |t|
  end

  create_table "client_withdrawal_cycles", force: :cascade do |t|
    t.string "public_id", limit: 21, null: false
    t.bigint "client_id", null: false
    t.bigint "status_id", default: 10, null: false
    t.datetime "began_at", null: false
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["began_at"], name: "index_client_withdrawal_cycles_on_began_at"
    t.index ["client_id"], name: "index_client_withdrawal_cycles_on_client_id"
    t.index ["completed_at"], name: "index_client_withdrawal_cycles_on_completed_at"
    t.index ["discarded_at"], name: "index_client_withdrawal_cycles_on_discarded_at"
    t.index ["public_id"], name: "index_client_withdrawal_cycles_on_public_id", unique: true
    t.index ["purged_at"], name: "index_client_withdrawal_cycles_on_purged_at"
    t.index ["status_id"], name: "index_client_withdrawal_cycles_on_status_id"
    t.check_constraint "discarded_at <= purged_at", name: "chk_client_withdrawal_cycles_retention_order"
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_step_up_at"
    t.integer "lock_version", default: 0, null: false
    t.string "public_id", limit: 255, default: "", null: false
    t.datetime "updated_at", null: false
    t.datetime "withdrawn_at", default: ::Float::INFINITY
    t.bigint "status_id", default: 11, null: false
    t.boolean "multi_factor_enabled", default: false, null: false
    t.datetime "withdrawal_started_at"
    t.datetime "deactivated_at"
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.bigint "visibility_id", default: 2, null: false
    t.datetime "deletable_at", default: ::Float::INFINITY, null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.bigint "multi_factor_id", default: 0, null: false
    t.bigint "multi_factor_status_id", default: 5, null: false
    t.datetime "terminated_at"
    t.text "birthdate"
    t.index ["deactivated_at"], name: "index_clients_on_deactivated_at", where: "(deactivated_at IS NOT NULL)"
    t.index ["deletable_at"], name: "index_clients_on_deletable_at"
    t.index ["discarded_at"], name: "index_clients_on_discarded_at"
    t.index ["multi_factor_id"], name: "index_clients_on_multi_factor_id"
    t.index ["multi_factor_status_id"], name: "index_clients_on_multi_factor_status_id"
    t.index ["public_id"], name: "index_clients_on_public_id", unique: true
    t.index ["purged_at"], name: "index_clients_on_purged_at", where: "(purged_at IS NOT NULL)"
    t.index ["status_id"], name: "index_clients_on_status_id"
    t.index ["terminated_at"], name: "index_clients_on_terminated_at", where: "(terminated_at IS NOT NULL)"
    t.index ["visibility_id"], name: "index_clients_on_visibility_id"
    t.index ["withdrawal_started_at"], name: "index_clients_on_withdrawal_started_at", where: "(withdrawal_started_at IS NOT NULL)"
    t.index ["withdrawn_at"], name: "index_clients_on_withdrawn_at", where: "(withdrawn_at IS NOT NULL)"
    t.check_constraint "birthdate IS NULL OR char_length(birthdate) <= 1000", name: "chk_clients_birthdate_length"
    t.check_constraint "discarded_at <= purged_at", name: "chk_users_retention_order"
  end

  create_table "legacy_replaced_client_banners", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "title", default: "", null: false
    t.text "body", null: false
    t.boolean "published", default: false, null: false
    t.datetime "starts_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "ends_at", default: "9999-12-31 23:59:59", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_legacy_replaced_client_banners_on_client_id"
    t.check_constraint "ends_at > starts_at", name: "client_banners_ends_at_after_starts_at"
  end

  create_table "legacy_replaced_client_statuses", force: :cascade do |t|
  end

  create_table "legacy_replaced_clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "division_id"
    t.integer "lock_version", default: 0, null: false
    t.string "moniker"
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "client_status_id", default: 0, null: false
    t.bigint "status_id", default: 0, null: false
    t.index ["client_status_id"], name: "index_legacy_replaced_clients_on_client_status_id"
    t.index ["division_id"], name: "index_legacy_replaced_clients_on_division_id"
    t.index ["public_id"], name: "index_legacy_replaced_clients_on_public_id", unique: true
    t.index ["status_id"], name: "index_legacy_replaced_clients_on_status_id"
    t.index ["user_id"], name: "index_legacy_replaced_clients_on_user_id"
  end

  create_table "member_statuses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "members", force: :cascade do |t|
    t.string "public_id", null: false
    t.string "moniker"
    t.bigint "user_id"
    t.bigint "division_id"
    t.bigint "status_id", default: 5, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.index ["division_id"], name: "index_members_on_division_id"
    t.index ["public_id"], name: "index_members_on_public_id", unique: true
    t.index ["purged_at"], name: "index_members_on_purged_at"
    t.index ["status_id"], name: "index_members_on_status_id"
    t.index ["user_id"], name: "index_members_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.string "key", default: "", null: false
    t.string "name", default: "", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_roles_on_organization_id"
  end

  create_table "user_client_deletions", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_user_client_deletions_on_client_id"
    t.index ["user_id", "client_id"], name: "index_user_client_deletions_on_user_id_and_client_id", unique: true
  end

  create_table "user_client_discoveries", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_user_client_discoveries_on_client_id"
    t.index ["user_id", "client_id"], name: "index_user_client_discoveries_on_user_id_and_client_id", unique: true
  end

  create_table "user_client_impersonations", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_user_client_impersonations_on_client_id"
    t.index ["user_id", "client_id"], name: "index_user_client_impersonations_on_user_id_and_client_id", unique: true
  end

  create_table "user_client_observations", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_user_client_observations_on_client_id"
    t.index ["user_id", "client_id"], name: "index_user_client_observations_on_user_id_and_client_id", unique: true
  end

  create_table "user_client_revocations", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_user_client_revocations_on_client_id"
    t.index ["user_id", "client_id"], name: "index_user_client_revocations_on_user_id_and_client_id", unique: true
  end

  create_table "user_client_suspensions", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_user_client_suspensions_on_client_id"
    t.index ["user_id", "client_id"], name: "index_user_client_suspensions_on_user_id_and_client_id", unique: true
  end

  create_table "user_clients", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_user_clients_on_client_id"
    t.index ["user_id", "client_id"], name: "index_user_clients_on_user_id_and_client_id", unique: true
  end

  add_foreign_key "apple_auths", "clients", column: "user_id"
  add_foreign_key "client_banners", "clients", column: "user_id"
  add_foreign_key "client_bulletins", "clients", column: "user_id"
  add_foreign_key "client_emails", "client_email_statuses", column: "user_email_status_id"
  add_foreign_key "client_emails", "clients", column: "user_id"
  add_foreign_key "client_member_deletions", "clients", column: "user_id"
  add_foreign_key "client_member_deletions", "members"
  add_foreign_key "client_member_discoveries", "clients", column: "user_id"
  add_foreign_key "client_member_discoveries", "members"
  add_foreign_key "client_member_impersonations", "clients", column: "user_id"
  add_foreign_key "client_member_impersonations", "members"
  add_foreign_key "client_member_observations", "clients", column: "user_id"
  add_foreign_key "client_member_observations", "members"
  add_foreign_key "client_member_revocations", "clients", column: "user_id"
  add_foreign_key "client_member_revocations", "members"
  add_foreign_key "client_member_suspensions", "clients", column: "user_id"
  add_foreign_key "client_member_suspensions", "members"
  add_foreign_key "client_members", "clients", column: "user_id", on_delete: :cascade
  add_foreign_key "client_members", "members", on_delete: :cascade
  add_foreign_key "client_memberships", "clients", column: "user_id"
  add_foreign_key "client_one_time_passwords", "client_one_time_password_statuses", column: "user_identity_one_time_password_status_id"
  add_foreign_key "client_one_time_passwords", "clients", column: "user_id"
  add_foreign_key "client_passkeys", "client_passkey_statuses", column: "status_id"
  add_foreign_key "client_passkeys", "clients", column: "user_id"
  add_foreign_key "client_preference_currencies", "client_preference_currency_options", column: "option_id"
  add_foreign_key "client_preference_currencies", "client_preferences", column: "preference_id"
  add_foreign_key "client_preference_date_formats", "client_preference_date_format_options", column: "option_id"
  add_foreign_key "client_preference_date_formats", "client_preferences", column: "preference_id"
  add_foreign_key "client_preference_densities", "client_preference_density_options", column: "option_id"
  add_foreign_key "client_preference_densities", "client_preferences", column: "preference_id"
  add_foreign_key "client_preference_items_per_pages", "client_preference_items_per_page_options", column: "option_id"
  add_foreign_key "client_preference_items_per_pages", "client_preferences", column: "preference_id"
  add_foreign_key "client_preference_languages", "client_preference_language_options", column: "option_id", name: "fk_user_preference_languages_on_option_id"
  add_foreign_key "client_preference_languages", "client_preferences", column: "preference_id", name: "fk_user_preference_languages_on_preference_id"
  add_foreign_key "client_preference_motions", "client_preference_motion_options", column: "option_id"
  add_foreign_key "client_preference_motions", "client_preferences", column: "preference_id"
  add_foreign_key "client_preference_regions", "client_preference_region_options", column: "option_id", name: "fk_user_preference_regions_on_option_id"
  add_foreign_key "client_preference_regions", "client_preferences", column: "preference_id", name: "fk_user_preference_regions_on_preference_id"
  add_foreign_key "client_preference_themes", "client_preference_theme_options", column: "option_id", name: "fk_user_preference_themes_on_option_id"
  add_foreign_key "client_preference_themes", "client_preferences", column: "preference_id", name: "fk_user_preference_themes_on_preference_id"
  add_foreign_key "client_preference_time_formats", "client_preference_time_format_options", column: "option_id"
  add_foreign_key "client_preference_time_formats", "client_preferences", column: "preference_id"
  add_foreign_key "client_preference_timezones", "client_preference_timezone_options", column: "option_id", name: "fk_user_preference_timezones_on_option_id"
  add_foreign_key "client_preference_timezones", "client_preferences", column: "preference_id", name: "fk_user_preference_timezones_on_preference_id"
  add_foreign_key "client_secrets", "client_secret_kinds", column: "user_secret_kind_id"
  add_foreign_key "client_secrets", "client_secret_statuses", column: "user_identity_secret_status_id"
  add_foreign_key "client_secrets", "clients", column: "user_id"
  add_foreign_key "client_social_apples", "client_social_apple_statuses", column: "status_id"
  add_foreign_key "client_social_apples", "clients", column: "user_id"
  add_foreign_key "client_social_googles", "client_social_google_statuses", column: "status_id"
  add_foreign_key "client_social_googles", "clients", column: "user_id"
  add_foreign_key "client_telephones", "client_telephone_statuses", column: "user_identity_telephone_status_id"
  add_foreign_key "client_telephones", "clients", column: "user_id"
  add_foreign_key "client_withdrawal_cycle_events", "client_withdrawal_cycle_statuses", column: "from_status_id", validate: false
  add_foreign_key "client_withdrawal_cycle_events", "client_withdrawal_cycle_statuses", column: "to_status_id", validate: false
  add_foreign_key "client_withdrawal_cycle_events", "client_withdrawal_cycles", validate: false
  add_foreign_key "client_withdrawal_cycle_events", "clients", validate: false
  add_foreign_key "client_withdrawal_cycles", "client_withdrawal_cycle_statuses", column: "status_id", validate: false
  add_foreign_key "client_withdrawal_cycles", "clients", validate: false
  add_foreign_key "clients", "client_multi_factor_statuses", column: "multi_factor_status_id"
  add_foreign_key "clients", "client_multi_factors", column: "multi_factor_id"
  add_foreign_key "clients", "client_statuses", column: "status_id"
  add_foreign_key "clients", "client_visibilities", column: "visibility_id"
  add_foreign_key "legacy_replaced_clients", "clients", column: "user_id", on_delete: :nullify
  add_foreign_key "legacy_replaced_clients", "legacy_replaced_client_statuses", column: "client_status_id"
  add_foreign_key "legacy_replaced_clients", "legacy_replaced_client_statuses", column: "client_status_id", name: "fk_clients_on_client_status_id"
  add_foreign_key "legacy_replaced_clients", "legacy_replaced_client_statuses", column: "status_id", name: "fk_clients_on_status_id"
  add_foreign_key "members", "clients", column: "user_id", on_delete: :nullify
  add_foreign_key "members", "member_statuses", column: "status_id"
  add_foreign_key "user_client_deletions", "clients", column: "user_id"
  add_foreign_key "user_client_deletions", "legacy_replaced_clients", column: "client_id"
  add_foreign_key "user_client_discoveries", "clients", column: "user_id"
  add_foreign_key "user_client_discoveries", "legacy_replaced_clients", column: "client_id"
  add_foreign_key "user_client_impersonations", "clients", column: "user_id"
  add_foreign_key "user_client_impersonations", "legacy_replaced_clients", column: "client_id"
  add_foreign_key "user_client_observations", "clients", column: "user_id"
  add_foreign_key "user_client_observations", "legacy_replaced_clients", column: "client_id"
  add_foreign_key "user_client_revocations", "clients", column: "user_id"
  add_foreign_key "user_client_revocations", "legacy_replaced_clients", column: "client_id"
  add_foreign_key "user_client_suspensions", "clients", column: "user_id"
  add_foreign_key "user_client_suspensions", "legacy_replaced_clients", column: "client_id"
  add_foreign_key "user_clients", "clients", column: "user_id", on_delete: :cascade
  add_foreign_key "user_clients", "legacy_replaced_clients", column: "client_id", on_delete: :cascade
end
