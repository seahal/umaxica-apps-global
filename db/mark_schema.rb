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

ActiveRecord::Schema[8.2].define(version: 2026_05_08_202600) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "user_authorization_codes", force: :cascade do |t|
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
    t.bigint "user_id", null: false
    t.index ["code"], name: "index_user_authorization_codes_on_code", unique: true
    t.index ["user_id"], name: "index_user_authorization_codes_on_user_id"
    t.check_constraint "lapses_at <= purge_at", name: "chk_user_authorization_codes_retention_order"
  end

  create_table "user_reauth_sessions", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.string "method"
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.text "return_to", null: false
    t.string "scope", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_token_id", null: false
    t.datetime "verified_at"
    t.index ["user_token_id"], name: "index_user_reauth_sessions_on_user_token_id", unique: true
    t.check_constraint "lapses_at <= purge_at", name: "chk_user_reauth_sessions_retention_order"
  end

  create_table "user_token_binding_methods", force: :cascade do |t|
  end

  create_table "user_token_dbsc_statuses", force: :cascade do |t|
  end

  create_table "user_token_kinds", force: :cascade do |t|
  end

  create_table "user_token_statuses", force: :cascade do |t|
  end

  create_table "user_tokens", force: :cascade do |t|
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
    t.bigint "user_id", null: false
    t.bigint "user_token_binding_method_id", default: 0, null: false
    t.bigint "user_token_dbsc_status_id", default: 0, null: false
    t.bigint "user_token_kind_id", default: 11, null: false
    t.bigint "user_token_status_id", default: 1, null: false
    t.index ["dbsc_session_id"], name: "index_user_tokens_on_dbsc_session_id", unique: true
    t.index ["device_id"], name: "index_user_tokens_on_device_id"
    t.index ["device_id_digest"], name: "index_user_tokens_on_device_id_digest"
    t.index ["public_id"], name: "index_user_tokens_on_public_id", unique: true
    t.index ["purge_at"], name: "index_user_tokens_on_purge_at"
    t.index ["refresh_token_digest"], name: "index_user_tokens_on_refresh_token_digest", unique: true
    t.index ["refresh_token_family_id"], name: "index_user_tokens_on_refresh_token_family_id"
    t.index ["session_id"], name: "index_user_tokens_on_session_id"
    t.index ["user_id", "last_step_up_at"], name: "index_user_tokens_on_user_id_and_last_step_up_at"
    t.index ["user_token_binding_method_id"], name: "index_user_tokens_on_user_token_binding_method_id"
    t.index ["user_token_dbsc_status_id"], name: "index_user_tokens_on_user_token_dbsc_status_id"
    t.index ["user_token_kind_id"], name: "index_user_tokens_on_user_token_kind_id"
    t.index ["user_token_status_id"], name: "index_user_tokens_on_user_token_status_id"
    t.check_constraint "user_token_kind_id >= 0", name: "chk_user_tokens_kind_id_positive"
    t.check_constraint "user_token_status_id >= 0", name: "chk_user_tokens_status_id_positive"
  end

  create_table "user_verifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.datetime "last_used_at"
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigserial "user_token_id", null: false
    t.index ["token_digest"], name: "index_user_verifications_on_token_digest", unique: true
    t.index ["user_token_id"], name: "index_user_verifications_on_user_token_id"
    t.check_constraint "lapses_at <= purge_at", name: "chk_user_verifications_retention_order"
  end

  add_foreign_key "user_reauth_sessions", "user_tokens", on_delete: :cascade, validate: false
  add_foreign_key "user_tokens", "user_token_binding_methods", name: "fk_user_tokens_on_user_token_binding_method_id", validate: false
  add_foreign_key "user_tokens", "user_token_dbsc_statuses", name: "fk_user_tokens_on_user_token_dbsc_status_id", validate: false
  add_foreign_key "user_tokens", "user_token_kinds", name: "fk_user_tokens_on_user_token_kind_id", validate: false
  add_foreign_key "user_tokens", "user_token_statuses", name: "fk_user_tokens_on_user_token_status_id", validate: false
  add_foreign_key "user_verifications", "user_tokens", on_delete: :cascade, validate: false
end
