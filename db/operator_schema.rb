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

ActiveRecord::Schema[8.2].define(version: 2026_03_31_222108) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "department_statuses", force: :cascade do |t|
  end

  create_table "departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_status_id", default: 0, null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id"
    t.index ["department_status_id", "parent_id"], name: "index_departments_on_department_status_id_and_parent_id", unique: true
    t.index ["parent_id"], name: "index_departments_on_parent_id"
    t.index ["workspace_id"], name: "index_departments_on_workspace_id"
  end

  create_table "division_statuses", force: :cascade do |t|
  end

  create_table "divisions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "division_status_id", default: 0, null: false
    t.string "name"
    t.bigint "organization_id"
    t.datetime "updated_at", null: false
    t.index ["division_status_id", "organization_id"], name: "index_divisions_on_division_status_id_and_organization_id", unique: true
    t.index ["organization_id"], name: "index_divisions_on_organization_id"
  end

  create_table "operator_statuses", force: :cascade do |t|
  end

  create_table "operators", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id"
    t.integer "lock_version", default: 0, null: false
    t.string "moniker"
    t.string "public_id", null: false
    t.bigint "staff_id", null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_operators_on_department_id"
    t.index ["public_id"], name: "index_operators_on_public_id", unique: true
    t.index ["staff_id"], name: "index_operators_on_staff_id"
    t.index ["status_id"], name: "index_operators_on_status_id"
  end

  create_table "org_preference_binding_methods", force: :cascade do |t|
  end

  create_table "org_preference_colortheme_options", force: :cascade do |t|
  end

  create_table "org_preference_colorthemes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_org_preference_colorthemes_on_option_id"
    t.index ["preference_id"], name: "index_org_preference_colorthemes_on_preference_id", unique: true
  end

  create_table "org_preference_cookies", force: :cascade do |t|
    t.uuid "consent_version"
    t.boolean "consented", default: false, null: false
    t.datetime "consented_at"
    t.datetime "created_at", null: false
    t.boolean "functional", default: false, null: false
    t.boolean "performant", default: false, null: false
    t.bigint "preference_id", null: false
    t.boolean "targetable", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["preference_id"], name: "index_org_preference_cookies_on_preference_id", unique: true
  end

  create_table "org_preference_dbsc_statuses", force: :cascade do |t|
  end

  create_table "org_preference_language_options", force: :cascade do |t|
  end

  create_table "org_preference_languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_org_preference_languages_on_option_id"
    t.index ["preference_id"], name: "index_org_preference_languages_on_preference_id", unique: true
  end

  create_table "org_preference_region_options", force: :cascade do |t|
  end

  create_table "org_preference_regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_org_preference_regions_on_option_id"
    t.index ["preference_id"], name: "index_org_preference_regions_on_preference_id", unique: true
  end

  create_table "org_preference_statuses", force: :cascade do |t|
  end

  create_table "org_preference_timezone_options", force: :cascade do |t|
  end

  create_table "org_preference_timezones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "option_id", null: false
    t.bigint "preference_id", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_org_preference_timezones_on_option_id"
    t.index ["preference_id"], name: "index_org_preference_timezones_on_preference_id", unique: true
  end

  create_table "org_preferences", force: :cascade do |t|
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
    t.index ["binding_method_id"], name: "index_org_preferences_on_binding_method_id"
    t.index ["dbsc_session_id"], name: "index_org_preferences_on_dbsc_session_id", unique: true
    t.index ["dbsc_status_id"], name: "index_org_preferences_on_dbsc_status_id"
    t.index ["device_id"], name: "index_org_preferences_on_device_id"
    t.index ["device_id_digest"], name: "index_org_preferences_on_device_id_digest"
    t.index ["jti"], name: "index_org_preferences_on_jti", unique: true
    t.index ["public_id"], name: "index_org_preferences_on_public_id", unique: true
    t.index ["replaced_by_id"], name: "index_org_preferences_on_replaced_by_id"
    t.index ["revoked_at"], name: "index_org_preferences_on_revoked_at"
    t.index ["status_id"], name: "index_org_preferences_on_status_id"
    t.index ["token_digest"], name: "index_org_preferences_on_token_digest"
    t.index ["used_at"], name: "index_org_preferences_on_used_at"
  end

  create_table "organization_statuses", force: :cascade do |t|
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id"
    t.string "domain", default: "", null: false
    t.string "name", default: "", null: false
    t.bigint "operator_id"
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_status_id", default: 0, null: false
    t.index ["department_id"], name: "index_organizations_on_department_id"
    t.index ["domain"], name: "index_organizations_on_domain", unique: true
    t.index ["operator_id"], name: "index_organizations_on_operator_id"
    t.index ["parent_id"], name: "index_organizations_on_parent_id"
    t.index ["workspace_status_id"], name: "index_organizations_on_workspace_status_id"
  end

  create_table "role_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.bigint "staff_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["role_id"], name: "index_role_assignments_on_role_id"
    t.index ["staff_id"], name: "index_role_assignments_on_staff_id"
    t.index ["user_id"], name: "index_role_assignments_on_user_id"
  end

  create_table "staff_bulletins", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "read_at"
    t.bigint "staff_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_staff_bulletins_on_public_id", unique: true
    t.index ["staff_id"], name: "index_staff_bulletins_on_staff_id"
  end

  create_table "staff_email_statuses", force: :cascade do |t|
  end

  create_table "staff_emails", force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.datetime "locked_at"
    t.boolean "notifiable", default: true, null: false
    t.integer "otp_attempts_count", default: 0, null: false
    t.text "otp_counter", null: false
    t.datetime "otp_expires_at"
    t.datetime "otp_last_sent_at"
    t.string "otp_private_key", null: false
    t.boolean "promotional", default: true, null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.bigint "staff_id", null: false
    t.bigint "staff_identity_email_status_id", default: 0, null: false
    t.boolean "subscribable", default: true, null: false
    t.boolean "undeletable", default: false, null: false
    t.datetime "updated_at", null: false
    t.index "lower((address)::text)", name: "index_staff_emails_on_lower_address", unique: true
    t.index ["address"], name: "index_staff_emails_on_address"
    t.index ["public_id"], name: "index_staff_emails_on_public_id", unique: true
    t.index ["staff_id"], name: "index_staff_emails_on_staff_id"
    t.index ["staff_identity_email_status_id"], name: "index_staff_emails_on_staff_identity_email_status_id"
  end

  create_table "staff_identity_audit_events", id: :string, force: :cascade do |t|
  end

  create_table "staff_identity_audits", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "event_id", null: false
    t.string "ip_address"
    t.text "previous_value"
    t.bigint "staff_id", null: false
    t.datetime "timestamp"
    t.datetime "updated_at", null: false
    t.index ["staff_id"], name: "index_staff_identity_audits_on_staff_id"
  end

  create_table "staff_identity_passkeys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.uuid "external_id", null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.binary "webauthn_id", null: false
    t.index ["staff_id"], name: "index_staff_identity_passkeys_on_staff_id"
    t.index ["webauthn_id"], name: "index_staff_identity_passkeys_on_webauthn_id", unique: true
  end

  create_table "staff_identity_statuses", force: :cascade do |t|
  end

  create_table "staff_operators", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "operator_id", null: false
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.index ["operator_id"], name: "index_staff_operators_on_operator_id"
    t.index ["staff_id", "operator_id"], name: "index_staff_operators_on_staff_id_and_operator_id", unique: true
  end

  create_table "staff_org_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "org_preference_id", null: false
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.index ["org_preference_id"], name: "index_staff_org_preferences_on_org_preference_id"
    t.index ["staff_id", "org_preference_id"], name: "index_staff_org_preferences_on_staff_id_and_org_preference_id", unique: true
  end

  create_table "staff_passkey_statuses", force: :cascade do |t|
  end

  create_table "staff_passkeys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.text "public_key", null: false
    t.integer "sign_count", null: false
    t.bigint "staff_id", null: false
    t.bigint "status_id", default: 0, null: false
    t.string "transports"
    t.datetime "updated_at", null: false
    t.string "user_handle"
    t.string "webauthn_id", default: "", null: false
    t.index ["external_id"], name: "index_staff_passkeys_on_external_id"
    t.index ["staff_id"], name: "index_staff_passkeys_on_staff_id"
    t.index ["status_id"], name: "index_staff_passkeys_on_status_id"
    t.index ["webauthn_id"], name: "index_staff_passkeys_on_webauthn_id", unique: true
  end

  create_table "staff_recovery_codes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "expires_in"
    t.string "recovery_code_digest"
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id"], name: "index_staff_recovery_codes_on_staff_id"
  end

  create_table "staff_secret_kinds", force: :cascade do |t|
  end

  create_table "staff_secret_statuses", force: :cascade do |t|
  end

  create_table "staff_secrets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "password_digest"
    t.string "public_id", limit: 21, null: false
    t.bigint "staff_id", null: false
    t.bigint "staff_identity_secret_status_id", default: 0, null: false
    t.bigint "staff_secret_kind_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_staff_secrets_on_public_id", unique: true
    t.index ["staff_id"], name: "index_staff_secrets_on_staff_id"
    t.index ["staff_identity_secret_status_id"], name: "index_staff_secrets_on_staff_identity_secret_status_id"
    t.index ["staff_secret_kind_id"], name: "index_staff_secrets_on_staff_secret_kind_id"
  end

  create_table "staff_statuses", force: :cascade do |t|
  end

  create_table "staff_telephone_statuses", force: :cascade do |t|
  end

  create_table "staff_telephones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "locked_at"
    t.string "number", null: false
    t.integer "otp_attempts_count", default: 0, null: false
    t.text "otp_counter", null: false
    t.datetime "otp_expires_at"
    t.string "otp_private_key", null: false
    t.bigint "staff_id", null: false
    t.bigint "staff_identity_telephone_status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index "lower((number)::text)", name: "index_staff_telephones_on_lower_number", unique: true
    t.index ["staff_id"], name: "index_staff_telephones_on_staff_id"
    t.index ["staff_identity_telephone_status_id"], name: "index_staff_telephones_on_staff_identity_telephone_status_id"
  end

  create_table "staff_visibilities", force: :cascade do |t|
  end

  create_table "staffs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deletable_at", default: ::Float::INFINITY, null: false
    t.integer "lock_version", default: 0, null: false
    t.boolean "multi_factor_enabled", default: false, null: false
    t.string "public_id", limit: 16, null: false
    t.datetime "shreddable_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "visibility_id", default: 2, null: false
    t.string "webauthn_id"
    t.datetime "withdrawn_at"
    t.index ["deletable_at"], name: "index_staffs_on_deletable_at"
    t.index ["public_id"], name: "index_staffs_on_public_id", unique: true
    t.index ["shreddable_at"], name: "index_staffs_on_shreddable_at"
    t.index ["status_id"], name: "index_staffs_on_status_id"
    t.index ["visibility_id"], name: "index_staffs_on_visibility_id"
    t.index ["withdrawn_at"], name: "index_staffs_on_withdrawn_at", where: "(withdrawn_at IS NOT NULL)"
    t.check_constraint "char_length(public_id::text) = 16", name: "chk_staffs_public_id_length"
    t.check_constraint "public_id::text ~ '^[0-9A-FGHJKMNPQRSTVWXYZ]{16}$'::text", name: "chk_staffs_public_id_format"
  end

  create_table "user_workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_user_workspaces_on_user_id"
    t.index ["workspace_id"], name: "index_user_workspaces_on_workspace_id"
  end

  create_table "workspace_statuses", force: :cascade do |t|
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "departments", "department_statuses", name: "fk_departments_on_department_status_id"
  add_foreign_key "departments", "departments", column: "parent_id"
  add_foreign_key "departments", "organizations", column: "workspace_id", on_delete: :nullify
  add_foreign_key "divisions", "division_statuses"
  add_foreign_key "divisions", "organizations", on_delete: :nullify
  add_foreign_key "operators", "departments", on_delete: :nullify
  add_foreign_key "operators", "operator_statuses", column: "status_id"
  add_foreign_key "operators", "staffs"
  add_foreign_key "org_preference_colorthemes", "org_preference_colortheme_options", column: "option_id", name: "fk_org_preference_colorthemes_on_option_id"
  add_foreign_key "org_preference_colorthemes", "org_preferences", column: "preference_id"
  add_foreign_key "org_preference_cookies", "org_preferences", column: "preference_id"
  add_foreign_key "org_preference_languages", "org_preference_language_options", column: "option_id", name: "fk_org_preference_languages_on_option_id"
  add_foreign_key "org_preference_languages", "org_preferences", column: "preference_id"
  add_foreign_key "org_preference_regions", "org_preference_region_options", column: "option_id", name: "fk_org_preference_regions_on_option_id"
  add_foreign_key "org_preference_regions", "org_preferences", column: "preference_id"
  add_foreign_key "org_preference_timezones", "org_preference_timezone_options", column: "option_id", name: "fk_org_preference_timezones_on_option_id"
  add_foreign_key "org_preference_timezones", "org_preferences", column: "preference_id"
  add_foreign_key "org_preferences", "org_preference_binding_methods", column: "binding_method_id", name: "fk_org_preferences_on_binding_method_id"
  add_foreign_key "org_preferences", "org_preference_dbsc_statuses", column: "dbsc_status_id", name: "fk_org_preferences_on_dbsc_status_id"
  add_foreign_key "org_preferences", "org_preference_statuses", column: "status_id", name: "fk_org_preferences_on_status_id"
  add_foreign_key "org_preferences", "org_preferences", column: "replaced_by_id", on_delete: :nullify
  add_foreign_key "organizations", "organization_statuses", column: "workspace_status_id"
  add_foreign_key "role_assignments", "staffs", on_delete: :cascade
  add_foreign_key "staff_bulletins", "staffs"
  add_foreign_key "staff_emails", "staff_email_statuses", column: "staff_identity_email_status_id"
  add_foreign_key "staff_emails", "staffs"
  add_foreign_key "staff_identity_audits", "staff_identity_audit_events", column: "event_id"
  add_foreign_key "staff_identity_audits", "staffs"
  add_foreign_key "staff_identity_passkeys", "staffs"
  add_foreign_key "staff_operators", "operators", on_delete: :cascade
  add_foreign_key "staff_operators", "staffs", on_delete: :cascade
  add_foreign_key "staff_org_preferences", "org_preferences", on_delete: :cascade
  add_foreign_key "staff_org_preferences", "staffs"
  add_foreign_key "staff_passkeys", "staff_passkey_statuses", column: "status_id"
  add_foreign_key "staff_passkeys", "staffs"
  add_foreign_key "staff_recovery_codes", "staffs"
  add_foreign_key "staff_secrets", "staff_secret_kinds", name: "fk_staff_secrets_on_staff_secret_kind_id"
  add_foreign_key "staff_secrets", "staff_secret_statuses", column: "staff_identity_secret_status_id"
  add_foreign_key "staff_secrets", "staffs"
  add_foreign_key "staff_telephones", "staff_telephone_statuses", column: "staff_identity_telephone_status_id"
  add_foreign_key "staff_telephones", "staffs"
  add_foreign_key "staffs", "staff_statuses", column: "status_id"
  add_foreign_key "staffs", "staff_visibilities", column: "visibility_id"
  add_foreign_key "user_workspaces", "workspaces"
end
