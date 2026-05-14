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

ActiveRecord::Schema[8.2].define(version: 2026_05_14_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "visitor_authorization_codes", force: :cascade do |t|
    t.string "acr"
    t.string "auth_method"
    t.string "client_id", limit: 64, null: false
    t.string "code", limit: 64, null: false
    t.string "code_challenge", null: false
    t.string "code_challenge_method", limit: 8, default: "S256", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.string "nonce"
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.text "redirect_uri", null: false
    t.string "scope"
    t.string "state"
    t.datetime "updated_at", null: false
    t.bigint "visitor_id", null: false
    t.index ["code"], name: "index_visitor_authorization_codes_on_code", unique: true
    t.index ["visitor_id"], name: "index_visitor_authorization_codes_on_visitor_id"
    t.check_constraint "lapses_at <= purge_at", name: "chk_visitor_authorization_codes_retention_order"
  end

  create_table "visitor_reauth_sessions", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.string "method"
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.text "return_to", null: false
    t.string "scope", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.bigint "visitor_token_id", null: false
    t.index ["visitor_token_id"], name: "index_visitor_reauth_sessions_on_visitor_token_id", unique: true
    t.check_constraint "lapses_at <= purge_at", name: "chk_customer_reauth_sessions_retention_order"
  end

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
    t.text "dbsc_challenge"
    t.datetime "dbsc_challenge_issued_at"
    t.jsonb "dbsc_public_key"
    t.string "dbsc_session_id"
    t.string "device_id", default: "", null: false
    t.string "device_id_digest"
    t.string "dpop_jkt"
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.datetime "last_step_up_at"
    t.string "last_step_up_scope"
    t.datetime "last_used_at"
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.binary "refresh_token_digest"
    t.string "refresh_token_family_id"
    t.integer "refresh_token_generation", default: 0, null: false
    t.datetime "rotated_at"
    t.string "session_id"
    t.datetime "updated_at", null: false
    t.bigint "visitor_id", null: false
    t.bigint "visitor_token_binding_method_id", default: 0, null: false
    t.bigint "visitor_token_dbsc_status_id", default: 0, null: false
    t.bigint "visitor_token_kind_id", default: 1, null: false
    t.bigint "visitor_token_status_id", default: 1, null: false
    t.index ["dbsc_session_id"], name: "index_visitor_tokens_on_dbsc_session_id", unique: true
    t.index ["device_id"], name: "index_visitor_tokens_on_device_id"
    t.index ["device_id_digest"], name: "index_visitor_tokens_on_device_id_digest"
    t.index ["public_id"], name: "index_visitor_tokens_on_public_id", unique: true
    t.index ["purge_at"], name: "index_visitor_tokens_on_purge_at"
    t.index ["refresh_token_digest"], name: "index_visitor_tokens_on_refresh_token_digest", unique: true
    t.index ["refresh_token_family_id"], name: "index_visitor_tokens_on_refresh_token_family_id"
    t.index ["session_id"], name: "index_visitor_tokens_on_session_id"
    t.index ["visitor_id", "last_step_up_at"], name: "index_visitor_tokens_on_visitor_id_and_last_step_up_at"
    t.index ["visitor_token_binding_method_id"], name: "index_visitor_tokens_on_visitor_token_binding_method_id"
    t.index ["visitor_token_dbsc_status_id"], name: "index_visitor_tokens_on_visitor_token_dbsc_status_id"
    t.index ["visitor_token_kind_id"], name: "index_visitor_tokens_on_visitor_token_kind_id"
    t.index ["visitor_token_status_id"], name: "index_visitor_tokens_on_visitor_token_status_id"
    t.check_constraint "visitor_token_kind_id >= 0", name: "chk_customer_tokens_kind_id_positive"
    t.check_constraint "visitor_token_status_id >= 0", name: "chk_customer_tokens_status_id_positive"
  end

  create_table "visitor_verifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.datetime "last_used_at"
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "visitor_token_id", null: false
    t.index ["token_digest"], name: "index_visitor_verifications_on_token_digest", unique: true
    t.index ["visitor_token_id"], name: "index_visitor_verifications_on_visitor_token_id"
    t.check_constraint "lapses_at <= purge_at", name: "chk_customer_verifications_retention_order"
  end

  add_foreign_key "visitor_reauth_sessions", "visitor_tokens", on_delete: :cascade, validate: false
  add_foreign_key "visitor_tokens", "visitor_token_binding_methods", name: "fk_customer_tokens_on_customer_token_binding_method_id", validate: false
  add_foreign_key "visitor_tokens", "visitor_token_dbsc_statuses", name: "fk_customer_tokens_on_customer_token_dbsc_status_id", validate: false
  add_foreign_key "visitor_tokens", "visitor_token_kinds", name: "fk_customer_tokens_on_customer_token_kind_id", validate: false
  add_foreign_key "visitor_tokens", "visitor_token_statuses", name: "fk_customer_tokens_on_customer_token_status_id", validate: false
  add_foreign_key "visitor_verifications", "visitor_tokens", validate: false
end
