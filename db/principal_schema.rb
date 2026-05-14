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

ActiveRecord::Schema[8.2].define(version: 2026_05_14_143000) do
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

  create_table "app_preference_binding_methods", force: :cascade do |t|
  end

  create_table "app_preference_cookies", force: :cascade do |t|
    t.uuid "consent_version"
    t.boolean "consented", default: false, null: false
    t.datetime "consented_at"
    t.datetime "created_at", null: false
    t.boolean "functional", default: false, null: false
    t.boolean "performant", default: false, null: false
    t.bigint "preference_id", null: false
    t.boolean "targetable", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["preference_id"], name: "index_app_preference_cookies_on_preference_id", unique: true
  end

  create_table "app_preference_currencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_currencies_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_currencies_on_preference_id", unique: true
  end

  create_table "app_preference_currency_options", force: :cascade do |t|
  end

  create_table "app_preference_date_format_options", force: :cascade do |t|
  end

  create_table "app_preference_date_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_date_formats_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_date_formats_on_preference_id", unique: true
  end

  create_table "app_preference_dbsc_statuses", force: :cascade do |t|
  end

  create_table "app_preference_densities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_densities_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_densities_on_preference_id", unique: true
  end

  create_table "app_preference_density_options", force: :cascade do |t|
  end

  create_table "app_preference_items_per_page_options", force: :cascade do |t|
  end

  create_table "app_preference_items_per_pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_items_per_pages_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_items_per_pages_on_preference_id", unique: true
  end

  create_table "app_preference_language_options", force: :cascade do |t|
  end

  create_table "app_preference_languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_languages_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_languages_on_preference_id", unique: true
  end

  create_table "app_preference_motion_options", force: :cascade do |t|
  end

  create_table "app_preference_motions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_motions_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_motions_on_preference_id", unique: true
  end

  create_table "app_preference_region_options", force: :cascade do |t|
  end

  create_table "app_preference_regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_regions_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_regions_on_preference_id", unique: true
  end

  create_table "app_preference_statuses", force: :cascade do |t|
  end

  create_table "app_preference_theme_options", force: :cascade do |t|
  end

  create_table "app_preference_themes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_themes_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_themes_on_preference_id", unique: true
  end

  create_table "app_preference_time_format_options", force: :cascade do |t|
  end

  create_table "app_preference_time_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_time_formats_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_time_formats_on_preference_id", unique: true
  end

  create_table "app_preference_timezone_options", force: :cascade do |t|
  end

  create_table "app_preference_timezones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_timezones_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_timezones_on_preference_id", unique: true
  end

  create_table "app_preferences", force: :cascade do |t|
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
    t.index ["binding_method_id"], name: "index_app_preferences_on_binding_method_id"
    t.index ["dbsc_session_id"], name: "index_app_preferences_on_dbsc_session_id", unique: true
    t.index ["dbsc_status_id"], name: "index_app_preferences_on_dbsc_status_id"
    t.index ["device_id"], name: "index_app_preferences_on_device_id"
    t.index ["device_id_digest"], name: "index_app_preferences_on_device_id_digest"
    t.index ["jti"], name: "index_app_preferences_on_jti", unique: true
    t.index ["public_id"], name: "index_app_preferences_on_public_id", unique: true
    t.index ["purge_at"], name: "index_app_preferences_on_purge_at"
    t.index ["replaced_by_id"], name: "index_app_preferences_on_replaced_by_id"
    t.index ["status_id"], name: "index_app_preferences_on_status_id"
    t.index ["token_digest"], name: "index_app_preferences_on_token_digest"
    t.index ["used_at"], name: "index_app_preferences_on_used_at"
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
    t.text "body", null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", default: "9999-12-31 23:59:59", null: false
    t.boolean "published", default: false, null: false
    t.datetime "starts_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "title", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_client_banners_on_client_id"
    t.check_constraint "ends_at > starts_at", name: "client_banners_ends_at_after_starts_at"
  end

  create_table "client_statuses", force: :cascade do |t|
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "client_status_id", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "division_id"
    t.integer "lock_version", default: 0, null: false
    t.string "moniker"
    t.string "public_id", null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["client_status_id"], name: "index_clients_on_client_status_id"
    t.index ["division_id"], name: "index_clients_on_division_id"
    t.index ["public_id"], name: "index_clients_on_public_id", unique: true
    t.index ["status_id"], name: "index_clients_on_status_id"
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "member_statuses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "division_id"
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.string "moniker"
    t.string "public_id", null: false
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 5, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["division_id"], name: "index_members_on_division_id"
    t.index ["public_id"], name: "index_members_on_public_id", unique: true
    t.index ["purge_at"], name: "index_members_on_purge_at"
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

  create_table "user_app_preferences", force: :cascade do |t|
    t.bigserial "app_preference_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["app_preference_id"], name: "index_user_app_preferences_on_app_preference_id"
    t.index ["user_id", "app_preference_id"], name: "index_user_app_preferences_on_user_id_and_app_preference_id", unique: true
    t.index ["user_id"], name: "index_user_app_preferences_on_user_id"
  end

  create_table "user_banners", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", default: "9999-12-31 23:59:59", null: false
    t.boolean "published", default: false, null: false
    t.datetime "starts_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "title", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_banners_on_user_id"
    t.check_constraint "ends_at > starts_at", name: "user_banners_ends_at_after_starts_at"
  end

  create_table "user_bulletins", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["public_id"], name: "index_user_bulletins_on_public_id", unique: true
    t.index ["user_id"], name: "index_user_bulletins_on_user_id"
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

  create_table "user_email_statuses", force: :cascade do |t|
  end

  create_table "user_emails", force: :cascade do |t|
    t.string "address", default: "", null: false
    t.string "address_digest"
    t.datetime "created_at", null: false
    t.datetime "locked_at", default: ::Float::INFINITY, null: false
    t.boolean "notifiable", default: true, null: false
    t.integer "otp_attempts_count", default: 0, null: false
    t.text "otp_counter", default: "", null: false
    t.datetime "otp_expires_at", default: -::Float::INFINITY, null: false
    t.datetime "otp_last_sent_at", default: -::Float::INFINITY, null: false
    t.string "otp_private_key", default: "", null: false
    t.boolean "promotional", default: true, null: false
    t.string "public_id", limit: 21, null: false
    t.boolean "subscribable", default: true, null: false
    t.boolean "undeletable", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_email_status_id", default: 0, null: false
    t.bigint "user_id", null: false
    t.binary "verification_token_digest"
    t.index "lower((address)::text)", name: "index_user_identity_emails_on_lower_address", unique: true
    t.index ["address_digest"], name: "index_user_emails_on_address_digest", unique: true, where: "(address_digest IS NOT NULL)"
    t.index ["otp_last_sent_at"], name: "index_user_emails_on_otp_last_sent_at"
    t.index ["public_id"], name: "index_user_emails_on_public_id", unique: true
    t.index ["user_email_status_id"], name: "index_user_emails_on_user_email_status_id"
    t.index ["user_id"], name: "index_user_emails_on_user_id"
  end

  create_table "user_member_deletions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "member_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["member_id"], name: "index_user_member_deletions_on_member_id"
    t.index ["user_id", "member_id"], name: "index_user_member_deletions_on_user_id_and_member_id", unique: true
  end

  create_table "user_member_discoveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "member_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["member_id"], name: "index_user_member_discoveries_on_member_id"
    t.index ["user_id", "member_id"], name: "index_user_member_discoveries_on_user_id_and_member_id", unique: true
  end

  create_table "user_member_impersonations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "member_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["member_id"], name: "index_user_member_impersonations_on_member_id"
    t.index ["user_id", "member_id"], name: "index_user_member_impersonations_on_user_id_and_member_id", unique: true
  end

  create_table "user_member_observations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "member_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["member_id"], name: "index_user_member_observations_on_member_id"
    t.index ["user_id", "member_id"], name: "index_user_member_observations_on_user_id_and_member_id", unique: true
  end

  create_table "user_member_revocations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "member_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["member_id"], name: "index_user_member_revocations_on_member_id"
    t.index ["user_id", "member_id"], name: "index_user_member_revocations_on_user_id_and_member_id", unique: true
  end

  create_table "user_member_suspensions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "member_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["member_id"], name: "index_user_member_suspensions_on_member_id"
    t.index ["user_id", "member_id"], name: "index_user_member_suspensions_on_user_id_and_member_id", unique: true
  end

  create_table "user_members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "member_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["member_id"], name: "index_user_members_on_member_id"
    t.index ["user_id", "member_id"], name: "index_user_members_on_user_id_and_member_id", unique: true
  end

  create_table "user_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "joined_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "left_at", default: -::Float::INFINITY, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id", "workspace_id"], name: "index_user_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["workspace_id"], name: "index_user_memberships_on_workspace_id"
  end

  create_table "user_multi_factor_statuses", force: :cascade do |t|
  end

  create_table "user_multi_factors", force: :cascade do |t|
  end

  create_table "user_one_time_password_statuses", force: :cascade do |t|
  end

  create_table "user_one_time_passwords", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_otp_at", default: -::Float::INFINITY, null: false
    t.string "private_key", limit: 1024, default: "", null: false
    t.string "public_id", limit: 21, null: false
    t.string "title", limit: 32
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_identity_one_time_password_status_id", default: 0, null: false
    t.index ["public_id"], name: "index_user_one_time_passwords_on_public_id", unique: true
    t.index ["user_id"], name: "index_user_one_time_passwords_on_user_id"
    t.index ["user_identity_one_time_password_status_id"], name: "idx_on_user_identity_one_time_password_status_id_c03cdf0b39"
  end

  create_table "user_passkey_statuses", force: :cascade do |t|
  end

  create_table "user_passkeys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", default: "", null: false
    t.uuid "external_id", null: false
    t.datetime "last_used_at"
    t.string "public_id", limit: 21, null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.bigint "status_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "webauthn_id", default: "", null: false
    t.index ["public_id"], name: "index_user_passkeys_on_public_id", unique: true
    t.index ["status_id"], name: "index_user_passkeys_on_status_id"
    t.index ["user_id"], name: "index_user_identity_passkeys_on_user_id"
    t.index ["webauthn_id"], name: "index_user_passkeys_on_webauthn_id", unique: true
  end

  create_table "user_preference_currencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_currencies_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_currencies_on_preference_id", unique: true
  end

  create_table "user_preference_currency_options", force: :cascade do |t|
  end

  create_table "user_preference_date_format_options", force: :cascade do |t|
  end

  create_table "user_preference_date_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_date_formats_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_date_formats_on_preference_id", unique: true
  end

  create_table "user_preference_densities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_densities_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_densities_on_preference_id", unique: true
  end

  create_table "user_preference_density_options", force: :cascade do |t|
  end

  create_table "user_preference_items_per_page_options", force: :cascade do |t|
  end

  create_table "user_preference_items_per_pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_items_per_pages_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_items_per_pages_on_preference_id", unique: true
  end

  create_table "user_preference_language_options", force: :cascade do |t|
  end

  create_table "user_preference_languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_languages_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_languages_on_preference_id", unique: true
  end

  create_table "user_preference_motion_options", force: :cascade do |t|
  end

  create_table "user_preference_motions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_motions_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_motions_on_preference_id", unique: true
  end

  create_table "user_preference_region_options", force: :cascade do |t|
  end

  create_table "user_preference_regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_regions_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_regions_on_preference_id", unique: true
  end

  create_table "user_preference_theme_options", force: :cascade do |t|
  end

  create_table "user_preference_themes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_themes_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_themes_on_preference_id", unique: true
  end

  create_table "user_preference_time_format_options", force: :cascade do |t|
  end

  create_table "user_preference_time_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_time_formats_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_time_formats_on_preference_id", unique: true
  end

  create_table "user_preference_timezone_options", force: :cascade do |t|
  end

  create_table "user_preference_timezones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_timezones_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_timezones_on_preference_id", unique: true
  end

  create_table "user_preferences", force: :cascade do |t|
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
    t.bigint "user_id", null: false
    t.index ["public_id"], name: "index_user_preferences_on_public_id", unique: true
    t.index ["user_id"], name: "index_user_preferences_on_user_id", unique: true
  end

  create_table "user_secret_kinds", force: :cascade do |t|
  end

  create_table "user_secret_statuses", force: :cascade do |t|
  end

  create_table "user_secrets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.datetime "last_used_at"
    t.string "name", default: "", null: false
    t.string "password_digest", default: "", null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_identity_secret_status_id", default: 0, null: false
    t.bigint "user_secret_kind_id", default: 0, null: false
    t.integer "uses_remaining", default: 1, null: false
    t.index ["public_id"], name: "index_user_secrets_on_public_id", unique: true
    t.index ["user_id"], name: "index_user_secrets_on_user_id"
    t.index ["user_identity_secret_status_id"], name: "index_user_secrets_on_user_identity_secret_status_id"
    t.index ["user_secret_kind_id"], name: "index_user_secrets_on_user_secret_kind_id"
    t.check_constraint "lapses_at <= purge_at", name: "chk_user_secrets_retention_order"
  end

  create_table "user_social_apple_statuses", force: :cascade do |t|
  end

  create_table "user_social_apples", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_authenticated_at"
    t.string "provider", default: "apple", null: false
    t.string "refresh_token", default: "", null: false
    t.bigint "status_id", default: 1, null: false
    t.string "token", default: "", null: false
    t.integer "token_expires_at", null: false
    t.string "uid", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status_id"], name: "index_user_social_apples_on_status_id"
    t.index ["token_expires_at"], name: "index_user_social_apples_on_token_expires_at"
    t.index ["uid", "provider"], name: "index_user_social_apples_on_uid_and_provider", unique: true
    t.index ["user_id"], name: "index_user_identity_social_apples_on_user_id_unique", unique: true, where: "(user_id IS NOT NULL)"
  end

  create_table "user_social_google_statuses", force: :cascade do |t|
  end

  create_table "user_social_googles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_authenticated_at"
    t.string "provider", default: "google_app", null: false
    t.string "refresh_token", default: "", null: false
    t.bigint "status_id", default: 1, null: false
    t.string "token", default: "", null: false
    t.integer "token_expires_at", null: false
    t.string "uid", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status_id"], name: "index_user_social_googles_on_status_id"
    t.index ["token_expires_at"], name: "index_user_social_googles_on_token_expires_at"
    t.index ["uid", "provider"], name: "index_user_social_googles_on_uid_and_provider", unique: true
    t.index ["user_id"], name: "index_user_identity_social_googles_on_user_id_unique", unique: true, where: "(user_id IS NOT NULL)"
  end

  create_table "user_statuses", force: :cascade do |t|
  end

  create_table "user_telephone_statuses", force: :cascade do |t|
  end

  create_table "user_telephones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "locked_at", default: -::Float::INFINITY, null: false
    t.string "number", default: "", null: false
    t.string "number_digest"
    t.integer "otp_attempts_count", default: 0, null: false
    t.text "otp_counter", default: "", null: false
    t.datetime "otp_expires_at", default: -::Float::INFINITY, null: false
    t.string "otp_private_key", default: "", null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_identity_telephone_status_id", default: 0, null: false
    t.index "lower((number)::text)", name: "index_user_telephones_on_lower_number", unique: true
    t.index ["number_digest"], name: "index_user_telephones_on_number_digest", unique: true, where: "(number_digest IS NOT NULL)"
    t.index ["public_id"], name: "index_user_telephones_on_public_id", unique: true
    t.index ["user_id"], name: "index_user_telephones_on_user_id"
    t.index ["user_identity_telephone_status_id"], name: "index_user_telephones_on_user_identity_telephone_status_id"
  end

  create_table "user_visibilities", force: :cascade do |t|
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.datetime "last_reauth_at"
    t.integer "lock_version", default: 0, null: false
    t.boolean "multi_factor_enabled", default: false, null: false
    t.bigint "multi_factor_id", default: 0, null: false
    t.bigint "multi_factor_status_id", default: 5, null: false
    t.string "public_id", limit: 255, default: "", null: false
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at"
    t.bigint "status_id", default: 11, null: false
    t.datetime "updated_at", null: false
    t.bigint "visibility_id", default: 2, null: false
    t.datetime "withdrawal_started_at"
    t.datetime "withdrawn_at", default: ::Float::INFINITY
    t.index ["deactivated_at"], name: "index_users_on_deactivated_at", where: "(deactivated_at IS NOT NULL)"
    t.index ["multi_factor_id"], name: "index_users_on_multi_factor_id"
    t.index ["multi_factor_status_id"], name: "index_users_on_multi_factor_status_id"
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
    t.index ["purge_at"], name: "index_users_on_purge_at"
    t.index ["purged_at"], name: "index_users_on_purged_at", where: "(purged_at IS NOT NULL)"
    t.index ["status_id"], name: "index_users_on_status_id"
    t.index ["visibility_id"], name: "index_users_on_visibility_id"
    t.index ["withdrawal_started_at"], name: "index_users_on_withdrawal_started_at", where: "(withdrawal_started_at IS NOT NULL)"
    t.index ["withdrawn_at"], name: "index_users_on_withdrawn_at", where: "(withdrawn_at IS NOT NULL)"
    t.check_constraint "lapses_at <= purge_at", name: "chk_users_retention_order"
  end

  add_foreign_key "app_preference_cookies", "app_preferences", column: "preference_id", validate: false
  add_foreign_key "app_preference_currencies", "app_preference_currency_options", column: "option_id"
  add_foreign_key "app_preference_currencies", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_date_formats", "app_preference_date_format_options", column: "option_id"
  add_foreign_key "app_preference_date_formats", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_densities", "app_preference_density_options", column: "option_id"
  add_foreign_key "app_preference_densities", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_items_per_pages", "app_preference_items_per_page_options", column: "option_id"
  add_foreign_key "app_preference_items_per_pages", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_languages", "app_preference_language_options", column: "option_id", name: "fk_app_preference_languages_on_option_id"
  add_foreign_key "app_preference_languages", "app_preferences", column: "preference_id", validate: false
  add_foreign_key "app_preference_motions", "app_preference_motion_options", column: "option_id"
  add_foreign_key "app_preference_motions", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_regions", "app_preference_region_options", column: "option_id", name: "fk_app_preference_regions_on_option_id"
  add_foreign_key "app_preference_regions", "app_preferences", column: "preference_id", validate: false
  add_foreign_key "app_preference_themes", "app_preference_theme_options", column: "option_id", name: "fk_app_preference_themes_on_option_id"
  add_foreign_key "app_preference_themes", "app_preferences", column: "preference_id", validate: false
  add_foreign_key "app_preference_time_formats", "app_preference_time_format_options", column: "option_id"
  add_foreign_key "app_preference_time_formats", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_timezones", "app_preference_timezone_options", column: "option_id", name: "fk_app_preference_timezones_on_option_id"
  add_foreign_key "app_preference_timezones", "app_preferences", column: "preference_id", validate: false
  add_foreign_key "app_preferences", "app_preference_binding_methods", column: "binding_method_id", name: "fk_app_preferences_on_binding_method_id", validate: false
  add_foreign_key "app_preferences", "app_preference_dbsc_statuses", column: "dbsc_status_id", name: "fk_app_preferences_on_dbsc_status_id", validate: false
  add_foreign_key "app_preferences", "app_preference_statuses", column: "status_id", name: "fk_app_preferences_on_status_id", validate: false
  add_foreign_key "app_preferences", "app_preferences", column: "replaced_by_id", on_delete: :nullify, validate: false
  add_foreign_key "apple_auths", "users", validate: false
  add_foreign_key "client_banners", "clients", validate: false
  add_foreign_key "clients", "client_statuses"
  add_foreign_key "clients", "client_statuses", column: "status_id", name: "fk_clients_on_status_id"
  add_foreign_key "clients", "client_statuses", name: "fk_clients_on_client_status_id"
  add_foreign_key "clients", "users", on_delete: :nullify
  add_foreign_key "members", "member_statuses", column: "status_id", validate: false
  add_foreign_key "members", "users", on_delete: :nullify, validate: false
  add_foreign_key "user_app_preferences", "app_preferences", on_delete: :cascade
  add_foreign_key "user_app_preferences", "users", validate: false
  add_foreign_key "user_banners", "users", validate: false
  add_foreign_key "user_bulletins", "users"
  add_foreign_key "user_client_deletions", "clients", validate: false
  add_foreign_key "user_client_deletions", "users", validate: false
  add_foreign_key "user_client_discoveries", "clients", validate: false
  add_foreign_key "user_client_discoveries", "users", validate: false
  add_foreign_key "user_client_impersonations", "clients", validate: false
  add_foreign_key "user_client_impersonations", "users", validate: false
  add_foreign_key "user_client_observations", "clients", validate: false
  add_foreign_key "user_client_observations", "users", validate: false
  add_foreign_key "user_client_revocations", "clients", validate: false
  add_foreign_key "user_client_revocations", "users", validate: false
  add_foreign_key "user_client_suspensions", "clients", validate: false
  add_foreign_key "user_client_suspensions", "users", validate: false
  add_foreign_key "user_clients", "clients", on_delete: :cascade, validate: false
  add_foreign_key "user_clients", "users", on_delete: :cascade, validate: false
  add_foreign_key "user_emails", "user_email_statuses"
  add_foreign_key "user_emails", "users", validate: false
  add_foreign_key "user_member_deletions", "members"
  add_foreign_key "user_member_deletions", "users"
  add_foreign_key "user_member_discoveries", "members"
  add_foreign_key "user_member_discoveries", "users"
  add_foreign_key "user_member_impersonations", "members"
  add_foreign_key "user_member_impersonations", "users"
  add_foreign_key "user_member_observations", "members"
  add_foreign_key "user_member_observations", "users"
  add_foreign_key "user_member_revocations", "members"
  add_foreign_key "user_member_revocations", "users"
  add_foreign_key "user_member_suspensions", "members"
  add_foreign_key "user_member_suspensions", "users"
  add_foreign_key "user_members", "members", on_delete: :cascade, validate: false
  add_foreign_key "user_members", "users", on_delete: :cascade, validate: false
  add_foreign_key "user_memberships", "users", validate: false
  add_foreign_key "user_one_time_passwords", "user_one_time_password_statuses", column: "user_identity_one_time_password_status_id"
  add_foreign_key "user_one_time_passwords", "users", validate: false
  add_foreign_key "user_passkeys", "user_passkey_statuses", column: "status_id", validate: false
  add_foreign_key "user_passkeys", "users", validate: false
  add_foreign_key "user_preference_currencies", "user_preference_currency_options", column: "option_id"
  add_foreign_key "user_preference_currencies", "user_preferences", column: "preference_id"
  add_foreign_key "user_preference_date_formats", "user_preference_date_format_options", column: "option_id"
  add_foreign_key "user_preference_date_formats", "user_preferences", column: "preference_id"
  add_foreign_key "user_preference_densities", "user_preference_density_options", column: "option_id"
  add_foreign_key "user_preference_densities", "user_preferences", column: "preference_id"
  add_foreign_key "user_preference_items_per_pages", "user_preference_items_per_page_options", column: "option_id"
  add_foreign_key "user_preference_items_per_pages", "user_preferences", column: "preference_id"
  add_foreign_key "user_preference_languages", "user_preference_language_options", column: "option_id", name: "fk_user_preference_languages_on_option_id"
  add_foreign_key "user_preference_languages", "user_preferences", column: "preference_id", name: "fk_user_preference_languages_on_preference_id"
  add_foreign_key "user_preference_motions", "user_preference_motion_options", column: "option_id"
  add_foreign_key "user_preference_motions", "user_preferences", column: "preference_id"
  add_foreign_key "user_preference_regions", "user_preference_region_options", column: "option_id", name: "fk_user_preference_regions_on_option_id"
  add_foreign_key "user_preference_regions", "user_preferences", column: "preference_id", name: "fk_user_preference_regions_on_preference_id"
  add_foreign_key "user_preference_themes", "user_preference_theme_options", column: "option_id", name: "fk_user_preference_themes_on_option_id"
  add_foreign_key "user_preference_themes", "user_preferences", column: "preference_id", name: "fk_user_preference_themes_on_preference_id"
  add_foreign_key "user_preference_time_formats", "user_preference_time_format_options", column: "option_id"
  add_foreign_key "user_preference_time_formats", "user_preferences", column: "preference_id"
  add_foreign_key "user_preference_timezones", "user_preference_timezone_options", column: "option_id", name: "fk_user_preference_timezones_on_option_id"
  add_foreign_key "user_preference_timezones", "user_preferences", column: "preference_id", name: "fk_user_preference_timezones_on_preference_id"
  add_foreign_key "user_secrets", "user_secret_kinds"
  add_foreign_key "user_secrets", "user_secret_statuses", column: "user_identity_secret_status_id"
  add_foreign_key "user_secrets", "users", validate: false
  add_foreign_key "user_social_apples", "user_social_apple_statuses", column: "status_id"
  add_foreign_key "user_social_apples", "users", validate: false
  add_foreign_key "user_social_googles", "user_social_google_statuses", column: "status_id"
  add_foreign_key "user_social_googles", "users", validate: false
  add_foreign_key "user_telephones", "user_telephone_statuses", column: "user_identity_telephone_status_id"
  add_foreign_key "user_telephones", "users", validate: false
  add_foreign_key "users", "user_multi_factor_statuses", column: "multi_factor_status_id", validate: false
  add_foreign_key "users", "user_multi_factors", column: "multi_factor_id", validate: false
  add_foreign_key "users", "user_statuses", column: "status_id"
  add_foreign_key "users", "user_visibilities", column: "visibility_id"
end
