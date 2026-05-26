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
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "department_statuses", force: :cascade do |t|
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "workspace_id"
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "department_status_id", default: 0, null: false
    t.index ["department_status_id", "parent_id"], name: "index_departments_on_department_status_id_and_parent_id", unique: true
    t.index ["parent_id"], name: "index_departments_on_parent_id"
    t.index ["workspace_id"], name: "index_departments_on_workspace_id"
  end

  create_table "division_statuses", force: :cascade do |t|
  end

  create_table "divisions", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.bigint "division_status_id", default: 0, null: false
    t.index ["division_status_id", "organization_id"], name: "index_divisions_on_division_status_id_and_organization_id", unique: true
    t.index ["organization_id"], name: "index_divisions_on_organization_id"
  end

  create_table "operator_accounts", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.bigint "department_id"
    t.string "public_id", null: false
    t.string "moniker"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "status_id", default: 0, null: false
    t.index ["department_id"], name: "index_operator_accounts_on_department_id"
    t.index ["public_id"], name: "index_operator_accounts_on_public_id", unique: true
    t.index ["staff_id"], name: "index_operator_accounts_on_staff_id"
    t.index ["status_id"], name: "index_operator_accounts_on_status_id"
  end

  create_table "operator_banners", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.string "title", default: "", null: false
    t.text "body", null: false
    t.boolean "published", default: false, null: false
    t.datetime "starts_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "ends_at", default: "9999-12-31 23:59:59", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id"], name: "index_operator_banners_on_staff_id"
    t.check_constraint "ends_at > starts_at", name: "staff_banners_ends_at_after_starts_at"
  end

  create_table "operator_bulletins", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.string "public_id", limit: 21, null: false
    t.string "title", null: false
    t.text "body"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_operator_bulletins_on_public_id", unique: true
    t.index ["staff_id"], name: "index_operator_bulletins_on_staff_id"
  end

  create_table "operator_email_statuses", force: :cascade do |t|
  end

  create_table "operator_emails", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.string "address", null: false
    t.string "otp_private_key", null: false
    t.text "otp_counter", null: false
    t.datetime "otp_expires_at"
    t.datetime "otp_last_sent_at"
    t.integer "otp_attempts_count", default: 0, null: false
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "staff_identity_email_status_id", default: 0, null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.boolean "undeletable", default: false, null: false
    t.boolean "promotional", default: true, null: false
    t.boolean "notifiable", default: true, null: false
    t.boolean "subscribable", default: true, null: false
    t.string "address_digest"
    t.index ["address_digest"], name: "index_operator_emails_on_address_digest", unique: true, where: "(address_digest IS NOT NULL)"
    t.index ["public_id"], name: "index_operator_emails_on_public_id", unique: true
    t.index ["staff_id"], name: "index_operator_emails_on_staff_id"
    t.index ["staff_identity_email_status_id"], name: "index_operator_emails_on_staff_identity_email_status_id"
  end

  create_table "operator_identity_statuses", force: :cascade do |t|
  end

  create_table "operator_lifecycle_requests", force: :cascade do |t|
    t.string "public_id", limit: 21, null: false
    t.string "action", null: false
    t.string "status", default: "pending", null: false
    t.bigint "target_operator_id"
    t.string "target_email"
    t.bigint "organization_id"
    t.bigint "role_id", default: 0, null: false
    t.bigint "requested_by_operator_id", null: false
    t.bigint "approved_by_operator_id"
    t.bigint "rejected_by_operator_id"
    t.bigint "executed_by_operator_id"
    t.bigint "invitation_id"
    t.text "reason"
    t.text "rejection_reason"
    t.datetime "approved_at"
    t.datetime "rejected_at"
    t.datetime "executed_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_operator_lifecycle_requests_on_action"
    t.index ["approved_by_operator_id"], name: "index_operator_lifecycle_requests_on_approved_by_operator_id"
    t.index ["public_id"], name: "index_operator_lifecycle_requests_on_public_id", unique: true
    t.index ["requested_by_operator_id"], name: "index_operator_lifecycle_requests_on_requested_by_operator_id"
    t.index ["status"], name: "index_operator_lifecycle_requests_on_status"
    t.index ["target_email"], name: "index_operator_lifecycle_requests_on_target_email"
    t.index ["target_operator_id"], name: "index_operator_lifecycle_requests_on_target_operator_id"
  end

  create_table "operator_multi_factor_statuses", force: :cascade do |t|
  end

  create_table "operator_multi_factors", force: :cascade do |t|
  end

  create_table "operator_passkey_statuses", force: :cascade do |t|
  end

  create_table "operator_passkeys", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.string "external_id", null: false
    t.text "public_key", null: false
    t.integer "sign_count", null: false
    t.string "user_handle"
    t.string "name", null: false
    t.string "transports"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "status_id", default: 0, null: false
    t.string "webauthn_id", default: "", null: false
    t.datetime "last_used_at"
    t.index ["external_id"], name: "index_operator_passkeys_on_external_id"
    t.index ["staff_id"], name: "index_operator_passkeys_on_staff_id"
    t.index ["status_id"], name: "index_operator_passkeys_on_status_id"
    t.index ["webauthn_id"], name: "index_operator_passkeys_on_webauthn_id", unique: true
  end

  create_table "operator_preference_currencies", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_currencies_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_currencies_on_preference_id", unique: true
  end

  create_table "operator_preference_currency_options", force: :cascade do |t|
  end

  create_table "operator_preference_date_format_options", force: :cascade do |t|
  end

  create_table "operator_preference_date_formats", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_date_formats_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_date_formats_on_preference_id", unique: true
  end

  create_table "operator_preference_densities", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_densities_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_densities_on_preference_id", unique: true
  end

  create_table "operator_preference_density_options", force: :cascade do |t|
  end

  create_table "operator_preference_items_per_page_options", force: :cascade do |t|
  end

  create_table "operator_preference_items_per_pages", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_items_per_pages_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_items_per_pages_on_preference_id", unique: true
  end

  create_table "operator_preference_language_options", force: :cascade do |t|
  end

  create_table "operator_preference_languages", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_languages_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_languages_on_preference_id", unique: true
  end

  create_table "operator_preference_motion_options", force: :cascade do |t|
  end

  create_table "operator_preference_motions", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_motions_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_motions_on_preference_id", unique: true
  end

  create_table "operator_preference_r18_display_stopper_options", force: :cascade do |t|
  end

  create_table "operator_preference_r18_display_stoppers", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_r18_display_stoppers_on_option_id"
    t.index ["preference_id"], name: "idx_on_preference_id_7d925420d9", unique: true
  end

  create_table "operator_preference_region_options", force: :cascade do |t|
  end

  create_table "operator_preference_regions", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_regions_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_regions_on_preference_id", unique: true
  end

  create_table "operator_preference_theme_options", force: :cascade do |t|
  end

  create_table "operator_preference_themes", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_themes_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_themes_on_preference_id", unique: true
  end

  create_table "operator_preference_time_format_options", force: :cascade do |t|
  end

  create_table "operator_preference_time_formats", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_time_formats_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_time_formats_on_preference_id", unique: true
  end

  create_table "operator_preference_timezone_options", force: :cascade do |t|
  end

  create_table "operator_preference_timezones", force: :cascade do |t|
    t.bigint "preference_id", null: false
    t.bigint "option_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_operator_preference_timezones_on_option_id"
    t.index ["preference_id"], name: "index_operator_preference_timezones_on_preference_id", unique: true
  end

  create_table "operator_preferences", force: :cascade do |t|
    t.bigint "staff_id", null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", limit: 21
    t.string "currency", default: "jpy", null: false
    t.string "date_format", default: "iso", null: false
    t.string "time_format", default: "hour_24", null: false
    t.string "motion", default: "standard", null: false
    t.string "density", default: "standard", null: false
    t.string "items_per_page", default: "20", null: false
    t.index ["public_id"], name: "index_operator_preferences_on_public_id", unique: true
    t.index ["staff_id"], name: "index_operator_preferences_on_staff_id", unique: true
  end

  create_table "operator_secret_kinds", force: :cascade do |t|
  end

  create_table "operator_secret_statuses", force: :cascade do |t|
  end

  create_table "operator_secrets", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.string "password_digest"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "staff_identity_secret_status_id", default: 0, null: false
    t.bigint "staff_secret_kind_id", default: 0, null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.index ["public_id"], name: "index_operator_secrets_on_public_id", unique: true
    t.index ["staff_id"], name: "index_operator_secrets_on_staff_id"
    t.index ["staff_identity_secret_status_id"], name: "index_operator_secrets_on_staff_identity_secret_status_id"
    t.index ["staff_secret_kind_id"], name: "index_operator_secrets_on_staff_secret_kind_id"
    t.check_constraint "discarded_at <= purged_at", name: "chk_staff_secrets_retention_order"
  end

  create_table "operator_social_google_statuses", force: :cascade do |t|
  end

  create_table "operator_social_googles", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.string "provider", default: "google_org", null: false
    t.string "uid", default: "", null: false
    t.string "token", default: "", null: false
    t.string "refresh_token", default: "", null: false
    t.integer "token_expires_at", null: false
    t.bigint "status_id", default: 1, null: false
    t.datetime "last_authenticated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id"], name: "index_operator_social_googles_on_staff_id_unique", unique: true, where: "(staff_id IS NOT NULL)"
    t.index ["status_id"], name: "index_operator_social_googles_on_status_id"
    t.index ["token_expires_at"], name: "index_operator_social_googles_on_token_expires_at"
    t.index ["uid", "provider"], name: "index_operator_social_googles_on_uid_and_provider", unique: true
  end

  create_table "operator_statuses", force: :cascade do |t|
  end

  create_table "operator_telephone_statuses", force: :cascade do |t|
  end

  create_table "operator_telephones", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.string "number", null: false
    t.string "otp_private_key", null: false
    t.text "otp_counter", null: false
    t.datetime "otp_expires_at"
    t.integer "otp_attempts_count", default: 0, null: false
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "staff_identity_telephone_status_id", default: 0, null: false
    t.string "number_digest"
    t.index ["number_digest"], name: "index_operator_telephones_on_number_digest", unique: true, where: "(number_digest IS NOT NULL)"
    t.index ["staff_id"], name: "index_operator_telephones_on_staff_id"
    t.index ["staff_identity_telephone_status_id"], name: "idx_on_staff_identity_telephone_status_id_6c01767c57"
  end

  create_table "operator_visibilities", force: :cascade do |t|
  end

  create_table "operators", force: :cascade do |t|
    t.string "webauthn_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id", limit: 16, null: false
    t.datetime "withdrawn_at"
    t.bigint "status_id", default: 0, null: false
    t.boolean "multi_factor_enabled", default: false, null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "visibility_id", default: 2, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.bigint "multi_factor_id", default: 0, null: false
    t.bigint "multi_factor_status_id", default: 5, null: false
    t.datetime "withdrawal_started_at"
    t.datetime "deactivated_at"
    t.text "birthdate"
    t.index ["deactivated_at"], name: "index_operators_on_deactivated_at", where: "(deactivated_at IS NOT NULL)"
    t.index ["discarded_at"], name: "index_operators_on_discarded_at"
    t.index ["multi_factor_id"], name: "index_operators_on_multi_factor_id"
    t.index ["multi_factor_status_id"], name: "index_operators_on_multi_factor_status_id"
    t.index ["public_id"], name: "index_operators_on_public_id", unique: true
    t.index ["purged_at"], name: "index_operators_on_purged_at"
    t.index ["status_id"], name: "index_operators_on_status_id"
    t.index ["visibility_id"], name: "index_operators_on_visibility_id"
    t.index ["withdrawal_started_at"], name: "index_operators_on_withdrawal_started_at", where: "(withdrawal_started_at IS NOT NULL)"
    t.index ["withdrawn_at"], name: "index_operators_on_withdrawn_at", where: "(withdrawn_at IS NOT NULL)"
    t.check_constraint "birthdate IS NULL OR char_length(birthdate) <= 1000", name: "chk_operators_birthdate_length"
    t.check_constraint "char_length(public_id::text) = 16", name: "chk_staffs_public_id_length"
    t.check_constraint "discarded_at <= purged_at", name: "chk_staffs_retention_order"
    t.check_constraint "public_id::text ~ '^[0-9A-FGHJKMNPQRSTVWXYZ]{16}$'::text", name: "chk_staffs_public_id_format"
  end

  create_table "organization_statuses", force: :cascade do |t|
  end

  create_table "organizations", force: :cascade do |t|
    t.string "domain", default: "", null: false
    t.string "name", default: "", null: false
    t.bigint "operator_id"
    t.bigint "department_id"
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_status_id", default: 0, null: false
    t.index ["department_id"], name: "index_organizations_on_department_id"
    t.index ["domain"], name: "index_organizations_on_domain", unique: true
    t.index ["operator_id"], name: "index_organizations_on_operator_id"
    t.index ["parent_id"], name: "index_organizations_on_parent_id"
    t.index ["workspace_status_id"], name: "index_organizations_on_workspace_status_id"
  end

  create_table "role_assignments", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "staff_id"
    t.bigint "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_role_assignments_on_role_id"
    t.index ["staff_id"], name: "index_role_assignments_on_staff_id"
    t.index ["user_id"], name: "index_role_assignments_on_user_id"
  end

  create_table "staff_identity_audit_events", id: :string, force: :cascade do |t|
  end

  create_table "staff_identity_audits", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.string "event_id", null: false
    t.datetime "timestamp"
    t.string "ip_address"
    t.bigint "actor_id"
    t.string "actor_type"
    t.text "previous_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id"], name: "index_staff_identity_audits_on_staff_id"
  end

  create_table "staff_identity_passkeys", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.binary "webauthn_id", null: false
    t.text "public_key", null: false
    t.string "description", null: false
    t.bigint "sign_count", default: 0, null: false
    t.uuid "external_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id"], name: "index_staff_identity_passkeys_on_staff_id"
    t.index ["webauthn_id"], name: "index_staff_identity_passkeys_on_webauthn_id", unique: true
  end

  create_table "staff_identity_statuses", force: :cascade do |t|
  end

  create_table "staff_operators", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.bigint "operator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["operator_id"], name: "index_staff_operators_on_operator_id"
    t.index ["staff_id", "operator_id"], name: "index_staff_operators_on_staff_id_and_operator_id", unique: true
  end

  create_table "staff_recovery_codes", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.string "recovery_code_digest"
    t.date "expires_in"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id"], name: "index_staff_recovery_codes_on_staff_id"
  end

  create_table "user_workspaces", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_workspaces_on_user_id"
    t.index ["workspace_id"], name: "index_user_workspaces_on_workspace_id"
  end

  create_table "workspace_statuses", force: :cascade do |t|
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "departments", "department_statuses", name: "fk_departments_on_department_status_id"
  add_foreign_key "departments", "departments", column: "parent_id"
  add_foreign_key "departments", "organizations", column: "workspace_id", on_delete: :nullify
  add_foreign_key "divisions", "division_statuses"
  add_foreign_key "divisions", "organizations"
  add_foreign_key "operator_accounts", "departments", on_delete: :nullify
  add_foreign_key "operator_accounts", "operator_statuses", column: "status_id"
  add_foreign_key "operator_accounts", "operators", column: "staff_id"
  add_foreign_key "operator_banners", "operators", column: "staff_id"
  add_foreign_key "operator_bulletins", "operators", column: "staff_id"
  add_foreign_key "operator_emails", "operator_email_statuses", column: "staff_identity_email_status_id"
  add_foreign_key "operator_emails", "operators", column: "staff_id"
  add_foreign_key "operator_passkeys", "operator_passkey_statuses", column: "status_id"
  add_foreign_key "operator_passkeys", "operators", column: "staff_id"
  add_foreign_key "operator_preference_currencies", "operator_preference_currency_options", column: "option_id"
  add_foreign_key "operator_preference_currencies", "operator_preferences", column: "preference_id"
  add_foreign_key "operator_preference_date_formats", "operator_preference_date_format_options", column: "option_id"
  add_foreign_key "operator_preference_date_formats", "operator_preferences", column: "preference_id"
  add_foreign_key "operator_preference_densities", "operator_preference_density_options", column: "option_id"
  add_foreign_key "operator_preference_densities", "operator_preferences", column: "preference_id"
  add_foreign_key "operator_preference_items_per_pages", "operator_preference_items_per_page_options", column: "option_id"
  add_foreign_key "operator_preference_items_per_pages", "operator_preferences", column: "preference_id"
  add_foreign_key "operator_preference_languages", "operator_preference_language_options", column: "option_id", name: "fk_staff_preference_languages_on_option_id"
  add_foreign_key "operator_preference_languages", "operator_preferences", column: "preference_id", name: "fk_staff_preference_languages_on_preference_id"
  add_foreign_key "operator_preference_motions", "operator_preference_motion_options", column: "option_id"
  add_foreign_key "operator_preference_motions", "operator_preferences", column: "preference_id"
  add_foreign_key "operator_preference_r18_display_stoppers", "operator_preference_r18_display_stopper_options", column: "option_id"
  add_foreign_key "operator_preference_r18_display_stoppers", "operator_preferences", column: "preference_id"
  add_foreign_key "operator_preference_regions", "operator_preference_region_options", column: "option_id", name: "fk_staff_preference_regions_on_option_id"
  add_foreign_key "operator_preference_regions", "operator_preferences", column: "preference_id", name: "fk_staff_preference_regions_on_preference_id"
  add_foreign_key "operator_preference_themes", "operator_preference_theme_options", column: "option_id", name: "fk_staff_preference_themes_on_option_id"
  add_foreign_key "operator_preference_themes", "operator_preferences", column: "preference_id", name: "fk_staff_preference_themes_on_preference_id"
  add_foreign_key "operator_preference_time_formats", "operator_preference_time_format_options", column: "option_id"
  add_foreign_key "operator_preference_time_formats", "operator_preferences", column: "preference_id"
  add_foreign_key "operator_preference_timezones", "operator_preference_timezone_options", column: "option_id", name: "fk_staff_preference_timezones_on_option_id"
  add_foreign_key "operator_preference_timezones", "operator_preferences", column: "preference_id", name: "fk_staff_preference_timezones_on_preference_id"
  add_foreign_key "operator_preferences", "operators", column: "staff_id"
  add_foreign_key "operator_secrets", "operator_secret_kinds", column: "staff_secret_kind_id", name: "fk_staff_secrets_on_staff_secret_kind_id"
  add_foreign_key "operator_secrets", "operator_secret_statuses", column: "staff_identity_secret_status_id"
  add_foreign_key "operator_secrets", "operators", column: "staff_id"
  add_foreign_key "operator_social_googles", "operator_social_google_statuses", column: "status_id"
  add_foreign_key "operator_social_googles", "operators", column: "staff_id"
  add_foreign_key "operator_telephones", "operator_telephone_statuses", column: "staff_identity_telephone_status_id"
  add_foreign_key "operator_telephones", "operators", column: "staff_id"
  add_foreign_key "operators", "operator_identity_statuses", column: "status_id"
  add_foreign_key "operators", "operator_multi_factor_statuses", column: "multi_factor_status_id"
  add_foreign_key "operators", "operator_multi_factors", column: "multi_factor_id"
  add_foreign_key "operators", "operator_visibilities", column: "visibility_id"
  add_foreign_key "organizations", "organization_statuses", column: "workspace_status_id"
  add_foreign_key "role_assignments", "operators", column: "staff_id", on_delete: :cascade
  add_foreign_key "staff_identity_audits", "operators", column: "staff_id"
  add_foreign_key "staff_identity_audits", "staff_identity_audit_events", column: "event_id"
  add_foreign_key "staff_identity_passkeys", "operators", column: "staff_id"
  add_foreign_key "staff_operators", "operator_accounts", column: "operator_id", on_delete: :cascade
  add_foreign_key "staff_operators", "operators", column: "staff_id", on_delete: :cascade
  add_foreign_key "staff_recovery_codes", "operators", column: "staff_id"
  add_foreign_key "user_workspaces", "workspaces"
end
