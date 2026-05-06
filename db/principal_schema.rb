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

ActiveRecord::Schema[8.2].define(version: 2026_03_31_222107) do
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

  create_table "app_preference_colortheme_options", force: :cascade do |t|
  end

  create_table "app_preference_colorthemes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_app_preference_colorthemes_on_option_id"
    t.index ["preference_id"], name: "index_app_preference_colorthemes_on_preference_id", unique: true
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

  create_table "app_preference_dbsc_statuses", force: :cascade do |t|
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
    t.datetime "compromised_at"
    t.datetime "created_at", null: false
    t.text "dbsc_challenge"
    t.datetime "dbsc_challenge_issued_at"
    t.jsonb "dbsc_public_key"
    t.string "dbsc_session_id"
    t.bigint "dbsc_status_id", default: 0, null: false
    t.string "device_id"
    t.string "device_id_digest"
    t.datetime "expires_at"
    t.string "jti"
    t.string "public_id", null: false
    t.bigint "replaced_by_id"
    t.datetime "revoked_at"
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
    t.index ["replaced_by_id"], name: "index_app_preferences_on_replaced_by_id"
    t.index ["revoked_at"], name: "index_app_preferences_on_revoked_at"
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

  create_table "google_auths", force: :cascade do |t|
    t.text "access_token", null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.datetime "expires_at", null: false
    t.string "image_url", default: "", null: false
    t.string "name", default: "", null: false
    t.string "provider", default: "", null: false
    t.text "raw_info", null: false
    t.text "refresh_token", null: false
    t.string "uid", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_google_auths_on_user_id"
  end

  create_table "member_statuses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "division_id"
    t.string "moniker"
    t.string "public_id", null: false
    t.bigint "status_id", default: 5, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["division_id"], name: "index_members_on_division_id"
    t.index ["public_id"], name: "index_members_on_public_id", unique: true
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

  create_table "staff_preference_colortheme_options", force: :cascade do |t|
  end

  create_table "staff_preference_colorthemes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_staff_preference_colorthemes_on_option_id"
    t.index ["preference_id"], name: "index_staff_preference_colorthemes_on_preference_id", unique: true
  end

  create_table "staff_preference_language_options", force: :cascade do |t|
  end

  create_table "staff_preference_languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_staff_preference_languages_on_option_id"
    t.index ["preference_id"], name: "index_staff_preference_languages_on_preference_id", unique: true
  end

  create_table "staff_preference_region_options", force: :cascade do |t|
  end

  create_table "staff_preference_regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_staff_preference_regions_on_option_id"
    t.index ["preference_id"], name: "index_staff_preference_regions_on_preference_id", unique: true
  end

  create_table "staff_preference_timezone_options", force: :cascade do |t|
  end

  create_table "staff_preference_timezones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_staff_preference_timezones_on_option_id"
    t.index ["preference_id"], name: "index_staff_preference_timezones_on_preference_id", unique: true
  end

  create_table "staff_preferences", force: :cascade do |t|
    t.uuid "consent_version"
    t.boolean "consented", default: false, null: false
    t.datetime "consented_at"
    t.datetime "created_at", null: false
    t.boolean "functional", default: false, null: false
    t.string "language", default: "ja", null: false
    t.boolean "performant", default: false, null: false
    t.string "region", default: "jp", null: false
    t.bigint "staff_id", null: false
    t.boolean "targetable", default: false, null: false
    t.string "theme", default: "sy", null: false
    t.string "timezone", default: "Asia/Tokyo", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id"], name: "index_staff_preferences_on_staff_id", unique: true
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
    t.string "address_bidx"
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
    t.index ["address_bidx"], name: "index_user_emails_on_address_bidx", unique: true, where: "(address_bidx IS NOT NULL)"
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
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "webauthn_id", default: "", null: false
    t.index ["public_id"], name: "index_user_passkeys_on_public_id", unique: true
    t.index ["status_id"], name: "index_user_passkeys_on_status_id"
    t.index ["user_id"], name: "index_user_identity_passkeys_on_user_id"
    t.index ["webauthn_id"], name: "index_user_passkeys_on_webauthn_id", unique: true
  end

  create_table "user_preference_colortheme_options", force: :cascade do |t|
  end

  create_table "user_preference_colorthemes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_user_preference_colorthemes_on_option_id"
    t.index ["preference_id"], name: "index_user_preference_colorthemes_on_preference_id", unique: true
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
    t.boolean "functional", default: false, null: false
    t.string "language", default: "ja", null: false
    t.boolean "performant", default: false, null: false
    t.string "region", default: "jp", null: false
    t.boolean "targetable", default: false, null: false
    t.string "theme", default: "sy", null: false
    t.string "timezone", default: "Asia/Tokyo", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_preferences_on_user_id", unique: true
  end

  create_table "user_secret_kinds", force: :cascade do |t|
  end

  create_table "user_secret_statuses", force: :cascade do |t|
  end

  create_table "user_secrets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", default: ::Float::INFINITY, null: false
    t.datetime "last_used_at"
    t.string "name", default: "", null: false
    t.string "password_digest", default: "", null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "user_identity_secret_status_id", default: 0, null: false
    t.bigint "user_secret_kind_id", default: 0, null: false
    t.integer "uses_remaining", default: 1, null: false
    t.index ["expires_at"], name: "index_user_secrets_on_expires_at"
    t.index ["public_id"], name: "index_user_secrets_on_public_id", unique: true
    t.index ["user_id"], name: "index_user_secrets_on_user_id"
    t.index ["user_identity_secret_status_id"], name: "index_user_secrets_on_user_identity_secret_status_id"
    t.index ["user_secret_kind_id"], name: "index_user_secrets_on_user_secret_kind_id"
  end

  create_table "user_social_apple_statuses", force: :cascade do |t|
  end

  create_table "user_social_apples", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_authenticated_at"
    t.string "provider", default: "apple", null: false
    t.string "refresh_token", default: "", null: false
    t.bigint "status_id", default: 0, null: false
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
    t.bigint "status_id", default: 0, null: false
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
    t.string "number_bidx"
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
    t.index ["number_bidx"], name: "index_user_telephones_on_number_bidx", unique: true, where: "(number_bidx IS NOT NULL)"
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
    t.datetime "deletable_at", default: ::Float::INFINITY, null: false
    t.datetime "last_reauth_at"
    t.integer "lock_version", default: 0, null: false
    t.boolean "multi_factor_enabled", default: false, null: false
    t.string "public_id", limit: 255, default: "", null: false
    t.datetime "purged_at"
    t.datetime "scheduled_purge_at"
    t.datetime "shreddable_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "visibility_id", default: 2, null: false
    t.datetime "withdrawal_started_at"
    t.datetime "withdrawn_at", default: ::Float::INFINITY
    t.index ["deactivated_at"], name: "index_users_on_deactivated_at", where: "(deactivated_at IS NOT NULL)"
    t.index ["deletable_at"], name: "index_users_on_deletable_at"
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
    t.index ["purged_at"], name: "index_users_on_purged_at", where: "(purged_at IS NOT NULL)"
    t.index ["scheduled_purge_at"], name: "index_users_on_scheduled_purge_at", where: "(scheduled_purge_at IS NOT NULL)"
    t.index ["shreddable_at"], name: "index_users_on_shreddable_at"
    t.index ["status_id"], name: "index_users_on_status_id"
    t.index ["visibility_id"], name: "index_users_on_visibility_id"
    t.index ["withdrawal_started_at"], name: "index_users_on_withdrawal_started_at", where: "(withdrawal_started_at IS NOT NULL)"
    t.index ["withdrawn_at"], name: "index_users_on_withdrawn_at", where: "(withdrawn_at IS NOT NULL)"
  end

  add_foreign_key "app_preference_colorthemes", "app_preference_colortheme_options", column: "option_id", name: "fk_app_preference_colorthemes_on_option_id"
  add_foreign_key "app_preference_colorthemes", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_cookies", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_languages", "app_preference_language_options", column: "option_id", name: "fk_app_preference_languages_on_option_id"
  add_foreign_key "app_preference_languages", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_regions", "app_preference_region_options", column: "option_id", name: "fk_app_preference_regions_on_option_id"
  add_foreign_key "app_preference_regions", "app_preferences", column: "preference_id"
  add_foreign_key "app_preference_timezones", "app_preference_timezone_options", column: "option_id", name: "fk_app_preference_timezones_on_option_id"
  add_foreign_key "app_preference_timezones", "app_preferences", column: "preference_id"
  add_foreign_key "app_preferences", "app_preference_binding_methods", column: "binding_method_id", name: "fk_app_preferences_on_binding_method_id"
  add_foreign_key "app_preferences", "app_preference_dbsc_statuses", column: "dbsc_status_id", name: "fk_app_preferences_on_dbsc_status_id"
  add_foreign_key "app_preferences", "app_preference_statuses", column: "status_id", name: "fk_app_preferences_on_status_id"
  add_foreign_key "app_preferences", "app_preferences", column: "replaced_by_id", on_delete: :nullify
  add_foreign_key "apple_auths", "users"
  add_foreign_key "clients", "client_statuses"
  add_foreign_key "clients", "client_statuses", column: "status_id", name: "fk_clients_on_status_id"
  add_foreign_key "clients", "client_statuses", name: "fk_clients_on_client_status_id"
  add_foreign_key "clients", "users", on_delete: :nullify
  add_foreign_key "google_auths", "users"
  add_foreign_key "members", "member_statuses", column: "status_id"
  add_foreign_key "members", "users", on_delete: :nullify
  add_foreign_key "staff_preference_colorthemes", "staff_preference_colortheme_options", column: "option_id", name: "fk_staff_preference_colorthemes_on_option_id"
  add_foreign_key "staff_preference_colorthemes", "staff_preferences", column: "preference_id", name: "fk_staff_preference_colorthemes_on_preference_id"
  add_foreign_key "staff_preference_languages", "staff_preference_language_options", column: "option_id", name: "fk_staff_preference_languages_on_option_id"
  add_foreign_key "staff_preference_languages", "staff_preferences", column: "preference_id", name: "fk_staff_preference_languages_on_preference_id"
  add_foreign_key "staff_preference_regions", "staff_preference_region_options", column: "option_id", name: "fk_staff_preference_regions_on_option_id"
  add_foreign_key "staff_preference_regions", "staff_preferences", column: "preference_id", name: "fk_staff_preference_regions_on_preference_id"
  add_foreign_key "staff_preference_timezones", "staff_preference_timezone_options", column: "option_id", name: "fk_staff_preference_timezones_on_option_id"
  add_foreign_key "staff_preference_timezones", "staff_preferences", column: "preference_id", name: "fk_staff_preference_timezones_on_preference_id"
  add_foreign_key "user_app_preferences", "app_preferences", on_delete: :cascade
  add_foreign_key "user_app_preferences", "users"
  add_foreign_key "user_bulletins", "users"
  add_foreign_key "user_client_deletions", "clients"
  add_foreign_key "user_client_deletions", "users"
  add_foreign_key "user_client_discoveries", "clients"
  add_foreign_key "user_client_discoveries", "users"
  add_foreign_key "user_client_impersonations", "clients"
  add_foreign_key "user_client_impersonations", "users"
  add_foreign_key "user_client_observations", "clients"
  add_foreign_key "user_client_observations", "users"
  add_foreign_key "user_client_revocations", "clients"
  add_foreign_key "user_client_revocations", "users"
  add_foreign_key "user_client_suspensions", "clients"
  add_foreign_key "user_client_suspensions", "users"
  add_foreign_key "user_clients", "clients", on_delete: :cascade
  add_foreign_key "user_clients", "users", on_delete: :cascade
  add_foreign_key "user_emails", "user_email_statuses"
  add_foreign_key "user_emails", "users"
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
  add_foreign_key "user_members", "members", on_delete: :cascade
  add_foreign_key "user_members", "users", on_delete: :cascade
  add_foreign_key "user_memberships", "users"
  add_foreign_key "user_one_time_passwords", "user_one_time_password_statuses", column: "user_identity_one_time_password_status_id"
  add_foreign_key "user_one_time_passwords", "users"
  add_foreign_key "user_passkeys", "user_passkey_statuses", column: "status_id"
  add_foreign_key "user_passkeys", "users"
  add_foreign_key "user_preference_colorthemes", "user_preference_colortheme_options", column: "option_id", name: "fk_user_preference_colorthemes_on_option_id"
  add_foreign_key "user_preference_colorthemes", "user_preferences", column: "preference_id", name: "fk_user_preference_colorthemes_on_preference_id"
  add_foreign_key "user_preference_languages", "user_preference_language_options", column: "option_id", name: "fk_user_preference_languages_on_option_id"
  add_foreign_key "user_preference_languages", "user_preferences", column: "preference_id", name: "fk_user_preference_languages_on_preference_id"
  add_foreign_key "user_preference_regions", "user_preference_region_options", column: "option_id", name: "fk_user_preference_regions_on_option_id"
  add_foreign_key "user_preference_regions", "user_preferences", column: "preference_id", name: "fk_user_preference_regions_on_preference_id"
  add_foreign_key "user_preference_timezones", "user_preference_timezone_options", column: "option_id", name: "fk_user_preference_timezones_on_option_id"
  add_foreign_key "user_preference_timezones", "user_preferences", column: "preference_id", name: "fk_user_preference_timezones_on_preference_id"
  add_foreign_key "user_secrets", "user_secret_kinds"
  add_foreign_key "user_secrets", "user_secret_statuses", column: "user_identity_secret_status_id"
  add_foreign_key "user_secrets", "users"
  add_foreign_key "user_social_apples", "user_social_apple_statuses", column: "status_id"
  add_foreign_key "user_social_apples", "users"
  add_foreign_key "user_social_googles", "user_social_google_statuses", column: "status_id"
  add_foreign_key "user_social_googles", "users"
  add_foreign_key "user_telephones", "user_telephone_statuses", column: "user_identity_telephone_status_id"
  add_foreign_key "user_telephones", "users"
  add_foreign_key "users", "user_statuses", column: "status_id"
  add_foreign_key "users", "user_visibilities", column: "visibility_id"
end
