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

ActiveRecord::Schema[8.2].define(version: 2026_05_20_190002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "visitor_authorization_codes", force: :cascade do |t|
    t.bigint "visitor_id", null: false
    t.string "client_id", limit: 64, null: false
    t.string "code", limit: 64, null: false
    t.text "redirect_uri", null: false
    t.string "code_challenge", null: false
    t.string "code_challenge_method", limit: 8, default: "S256", null: false
    t.string "scope"
    t.string "state"
    t.string "nonce"
    t.string "auth_method"
    t.string "acr"
    t.datetime "consumed_at"
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_visitor_authorization_codes_on_code", unique: true
    t.index ["visitor_id"], name: "index_visitor_authorization_codes_on_visitor_id"
    t.check_constraint "discarded_at <= purged_at", name: "chk_visitor_authorization_codes_retention_order"
  end

  create_table "visitor_device_sessions", force: :cascade do |t|
    t.string "public_id", limit: 21, null: false
    t.bigint "visitor_id", null: false
    t.string "device_id_digest"
    t.string "dbsc_session_id_digest"
    t.string "dbsc_public_key_thumbprint"
    t.datetime "dbsc_bound_at"
    t.string "dpop_jkt"
    t.bigint "status_id", default: 1, null: false
    t.bigint "current_refresh_token_id"
    t.string "refresh_token_family_id"
    t.datetime "last_seen_at"
    t.datetime "revoked_at"
    t.string "revoke_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["current_refresh_token_id"], name: "index_visitor_device_sessions_on_current_refresh_token_id"
    t.index ["dbsc_session_id_digest"], name: "index_visitor_device_sessions_on_dbsc_session_id_digest"
    t.index ["device_id_digest"], name: "index_visitor_device_sessions_on_device_id_digest"
    t.index ["public_id"], name: "index_visitor_device_sessions_on_public_id", unique: true
    t.index ["refresh_token_family_id"], name: "index_visitor_device_sessions_on_refresh_token_family_id"
    t.index ["revoked_at"], name: "index_visitor_device_sessions_on_revoked_at"
    t.index ["visitor_id"], name: "index_visitor_device_sessions_on_visitor_id"
  end

  create_table "visitor_oidc_connections", force: :cascade do |t|
    t.string "public_id", limit: 21, null: false
    t.bigint "visitor_id", null: false
    t.string "client_id", limit: 64, null: false
    t.string "scope"
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_visitor_oidc_connections_on_public_id", unique: true
    t.index ["visitor_id", "client_id"], name: "index_visitor_oidc_connections_on_visitor_id_and_client_id", unique: true
    t.index ["visitor_id"], name: "index_visitor_oidc_connections_on_visitor_id"
  end

  create_table "visitor_sign_in_cycle_statuses", force: :cascade do |t|
  end

  create_table "visitor_sign_in_cycles", force: :cascade do |t|
    t.string "public_id", limit: 21, null: false
    t.bigint "principal_id"
    t.bigint "token_id"
    t.string "state", null: false
    t.string "step", null: false
    t.text "return_to"
    t.string "nonce_digest", null: false
    t.datetime "issued_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "completed_at"
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "status_id", default: 10, null: false
    t.index ["discarded_at"], name: "index_visitor_sign_in_cycles_on_discarded_at"
    t.index ["expires_at"], name: "index_visitor_sign_in_cycles_on_expires_at"
    t.index ["principal_id"], name: "index_visitor_sign_in_cycles_on_principal_id"
    t.index ["public_id"], name: "index_visitor_sign_in_cycles_on_public_id", unique: true
    t.index ["state"], name: "index_visitor_sign_in_cycles_on_state"
    t.index ["status_id"], name: "index_visitor_sign_in_cycles_on_status_id"
    t.index ["token_id"], name: "index_visitor_sign_in_cycles_on_token_id"
    t.check_constraint "discarded_at <= purged_at", name: "chk_com_sign_in_sequence_tickets_retention_order"
    t.check_constraint "issued_at < expires_at", name: "chk_com_sign_in_sequence_tickets_lifetime_order"
  end

  create_table "visitor_sign_out_cycle_kinds", force: :cascade do |t|
  end

  create_table "visitor_sign_out_cycle_statuses", force: :cascade do |t|
  end

  create_table "visitor_sign_out_cycles", force: :cascade do |t|
    t.string "public_id", limit: 21, null: false
    t.bigint "principal_id"
    t.bigint "token_id"
    t.bigint "status_id", default: 10, null: false
    t.bigint "kind_id", default: 0, null: false
    t.string "refresh_token_family_id"
    t.datetime "requested_at", null: false
    t.datetime "access_discarded_at"
    t.datetime "logically_revoked_at"
    t.datetime "access_expires_at", null: false
    t.datetime "refresh_expires_at", null: false
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.text "return_to"
    t.string "nonce_digest"
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_expires_at"], name: "index_visitor_sign_out_cycles_on_access_expires_at"
    t.index ["discarded_at"], name: "index_visitor_sign_out_cycles_on_discarded_at"
    t.index ["kind_id"], name: "index_visitor_sign_out_cycles_on_kind_id"
    t.index ["principal_id"], name: "index_visitor_sign_out_cycles_on_principal_id"
    t.index ["public_id"], name: "index_visitor_sign_out_cycles_on_public_id", unique: true
    t.index ["purged_at"], name: "index_visitor_sign_out_cycles_on_purged_at"
    t.index ["refresh_expires_at"], name: "index_visitor_sign_out_cycles_on_refresh_expires_at"
    t.index ["refresh_token_family_id"], name: "index_visitor_sign_out_cycles_on_refresh_token_family_id"
    t.index ["status_id"], name: "index_visitor_sign_out_cycles_on_status_id"
    t.index ["token_id"], name: "index_visitor_sign_out_cycles_on_token_id"
    t.check_constraint "access_expires_at <= refresh_expires_at", name: "chk_visitor_sign_out_cycles_token_expiry_order"
    t.check_constraint "discarded_at <= purged_at", name: "chk_visitor_sign_out_cycles_retention_order"
  end

  create_table "visitor_sign_up_cycle_statuses", force: :cascade do |t|
  end

  create_table "visitor_sign_up_cycles", force: :cascade do |t|
    t.string "public_id", limit: 21, null: false
    t.bigint "principal_id"
    t.bigint "token_id"
    t.string "state", null: false
    t.string "step", null: false
    t.text "return_to"
    t.string "nonce_digest", null: false
    t.datetime "issued_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "completed_at"
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "status_id", default: 10, null: false
    t.string "entry_method"
    t.string "pending_contact_type"
    t.bigint "pending_contact_id"
    t.string "social_provider"
    t.jsonb "completed_requirements", default: {}, null: false
    t.string "cleanup_token", default: "", null: false
    t.datetime "failed_at"
    t.datetime "cancelled_at"
    t.index ["cleanup_token"], name: "index_visitor_sign_up_cycles_on_cleanup_token"
    t.index ["discarded_at"], name: "index_visitor_sign_up_cycles_on_discarded_at"
    t.index ["expires_at"], name: "index_visitor_sign_up_cycles_on_expires_at"
    t.index ["pending_contact_id"], name: "index_visitor_sign_up_cycles_on_pending_contact_id"
    t.index ["principal_id"], name: "index_visitor_sign_up_cycles_on_principal_id"
    t.index ["public_id"], name: "index_visitor_sign_up_cycles_on_public_id", unique: true
    t.index ["state"], name: "index_visitor_sign_up_cycles_on_state"
    t.index ["status_id", "expires_at"], name: "index_visitor_sign_up_cycles_on_status_id_and_expires_at"
    t.index ["status_id"], name: "index_visitor_sign_up_cycles_on_status_id"
    t.index ["token_id"], name: "index_visitor_sign_up_cycles_on_token_id"
    t.check_constraint "discarded_at <= purged_at", name: "chk_com_sign_up_sequence_tickets_retention_order"
    t.check_constraint "issued_at < expires_at", name: "chk_com_sign_up_sequence_tickets_lifetime_order"
  end

  create_table "visitor_step_up_sessions", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "visitor_token_id", null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.string "method"
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.text "return_to", null: false
    t.string "scope", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["visitor_token_id"], name: "index_visitor_step_up_sessions_on_visitor_token_id", unique: true
  end

  add_check_constraint "visitor_step_up_sessions", "discarded_at <= purged_at", name: "chk_visitor_step_up_sessions_retention_order", validate: false

  create_table "visitor_token_binding_methods", force: :cascade do |t|
  end

  create_table "visitor_token_dbsc_statuses", force: :cascade do |t|
  end

  create_table "visitor_token_kinds", force: :cascade do |t|
  end

  create_table "visitor_token_statuses", force: :cascade do |t|
  end

  create_table "visitor_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "visitor_id", null: false
    t.bigint "visitor_token_binding_method_id", default: 0, null: false
    t.bigint "visitor_token_dbsc_status_id", default: 0, null: false
    t.bigint "visitor_token_kind_id", default: 1, null: false
    t.bigint "visitor_token_status_id", default: 1, null: false
    t.text "dbsc_challenge"
    t.datetime "dbsc_challenge_issued_at"
    t.jsonb "dbsc_public_key"
    t.string "dbsc_session_id"
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.string "device_id", default: "", null: false
    t.string "device_id_digest"
    t.datetime "last_step_up_at"
    t.string "last_step_up_scope"
    t.datetime "last_used_at"
    t.string "public_id", limit: 21, default: "", null: false
    t.binary "refresh_token_digest"
    t.string "refresh_token_family_id"
    t.integer "refresh_token_generation", default: 0, null: false
    t.datetime "rotated_at"
    t.datetime "updated_at", null: false
    t.string "dpop_jkt"
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.bigint "oidc_connection_id"
    t.string "oidc_client_id", limit: 64
    t.string "oidc_scope"
    t.uuid "oidc_sid", default: -> { "gen_random_uuid()" }
    t.uuid "oidc_jti", default: -> { "gen_random_uuid()" }
    t.bigint "device_session_id"
    t.index ["created_at"], name: "index_visitor_tokens_on_created_at"
    t.index ["dbsc_session_id"], name: "index_visitor_tokens_on_dbsc_session_id", unique: true
    t.index ["device_id"], name: "index_visitor_tokens_on_device_id"
    t.index ["device_id_digest"], name: "index_visitor_tokens_on_device_id_digest"
    t.index ["device_session_id"], name: "index_visitor_tokens_on_device_session_id"
    t.index ["discarded_at"], name: "index_visitor_tokens_on_discarded_at"
    t.index ["oidc_connection_id"], name: "index_visitor_tokens_on_oidc_connection_id"
    t.index ["oidc_jti"], name: "index_visitor_tokens_on_oidc_jti"
    t.index ["oidc_sid"], name: "index_visitor_tokens_on_oidc_sid"
    t.index ["public_id"], name: "index_visitor_tokens_on_public_id", unique: true
    t.index ["purged_at"], name: "index_visitor_tokens_on_purged_at"
    t.index ["refresh_token_digest"], name: "index_visitor_tokens_on_refresh_token_digest", unique: true
    t.index ["refresh_token_family_id"], name: "index_visitor_tokens_on_refresh_token_family_id"
    t.index ["rotated_at"], name: "index_visitor_tokens_on_rotated_at"
    t.index ["visitor_id", "last_step_up_at"], name: "index_visitor_tokens_on_visitor_id_and_last_step_up_at"
    t.index ["visitor_id", "oidc_client_id"], name: "index_visitor_tokens_on_visitor_id_and_oidc_client_id"
    t.index ["visitor_token_binding_method_id"], name: "index_visitor_tokens_on_visitor_token_binding_method_id"
    t.index ["visitor_token_dbsc_status_id"], name: "index_visitor_tokens_on_visitor_token_dbsc_status_id"
    t.index ["visitor_token_kind_id"], name: "index_visitor_tokens_on_visitor_token_kind_id"
    t.index ["visitor_token_status_id"], name: "index_visitor_tokens_on_visitor_token_status_id"
    t.check_constraint "visitor_token_kind_id >= 0", name: "chk_customer_tokens_kind_id_positive"
    t.check_constraint "visitor_token_status_id >= 0", name: "chk_customer_tokens_status_id_positive"
  end

  create_table "visitor_verifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "visitor_token_id", null: false
    t.datetime "last_used_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at", default: ::Float::INFINITY, null: false
    t.datetime "purged_at", default: ::Float::INFINITY, null: false
    t.index ["token_digest"], name: "index_visitor_verifications_on_token_digest", unique: true
    t.index ["visitor_token_id"], name: "index_visitor_verifications_on_visitor_token_id"
    t.check_constraint "discarded_at <= purged_at", name: "chk_customer_verifications_retention_order"
  end

  add_foreign_key "visitor_sign_in_cycles", "visitor_sign_in_cycle_statuses", column: "status_id", validate: false
  add_foreign_key "visitor_sign_in_cycles", "visitor_tokens", column: "token_id", on_delete: :cascade, validate: false
  add_foreign_key "visitor_sign_out_cycles", "visitor_sign_out_cycle_kinds", column: "kind_id", validate: false
  add_foreign_key "visitor_sign_out_cycles", "visitor_sign_out_cycle_statuses", column: "status_id", validate: false
  add_foreign_key "visitor_sign_out_cycles", "visitor_tokens", column: "token_id", on_delete: :cascade, validate: false
  add_foreign_key "visitor_sign_up_cycles", "visitor_sign_up_cycle_statuses", column: "status_id", validate: false
  add_foreign_key "visitor_sign_up_cycles", "visitor_tokens", column: "token_id", on_delete: :cascade, validate: false
  add_foreign_key "visitor_step_up_sessions", "visitor_tokens", on_delete: :cascade, validate: false
  add_foreign_key "visitor_tokens", "visitor_token_binding_methods", name: "fk_customer_tokens_on_customer_token_binding_method_id", validate: false
  add_foreign_key "visitor_tokens", "visitor_token_dbsc_statuses", name: "fk_customer_tokens_on_customer_token_dbsc_status_id", validate: false
  add_foreign_key "visitor_tokens", "visitor_token_kinds", name: "fk_customer_tokens_on_customer_token_kind_id", validate: false
  add_foreign_key "visitor_tokens", "visitor_token_statuses", name: "fk_customer_tokens_on_customer_token_status_id", validate: false
  add_foreign_key "visitor_verifications", "visitor_tokens", validate: false
end
