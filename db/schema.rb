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
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "visitor_email_statuses", force: :cascade do |t|
  end

  create_table "visitor_emails", force: :cascade do |t|
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
    t.binary "verification_token_digest"
    t.bigint "visitor_email_status_id", default: 1, null: false
    t.bigint "visitor_id", null: false
    t.index "lower((address)::text)", name: "index_visitor_emails_on_lower_address", unique: true
    t.index ["address_digest"], name: "index_visitor_emails_on_address_digest", unique: true, where: "(address_digest IS NOT NULL)"
    t.index ["otp_last_sent_at"], name: "index_visitor_emails_on_otp_last_sent_at"
    t.index ["public_id"], name: "index_visitor_emails_on_public_id", unique: true
    t.index ["visitor_email_status_id"], name: "index_visitor_emails_on_visitor_email_status_id"
    t.index ["visitor_id"], name: "index_visitor_emails_on_visitor_id"
  end

  create_table "visitor_multi_factor_statuses", force: :cascade do |t|
  end

  create_table "visitor_multi_factors", force: :cascade do |t|
  end

  create_table "visitor_passkey_statuses", force: :cascade do |t|
  end

  create_table "visitor_passkeys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", default: "", null: false
    t.uuid "external_id", null: false
    t.datetime "last_used_at"
    t.string "public_id", limit: 21, null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.bigint "status_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.bigint "visitor_id", null: false
    t.string "webauthn_id", default: "", null: false
    t.index ["public_id"], name: "index_visitor_passkeys_on_public_id", unique: true
    t.index ["status_id"], name: "index_visitor_passkeys_on_status_id"
    t.index ["visitor_id"], name: "index_visitor_passkeys_on_visitor_id"
    t.index ["webauthn_id"], name: "index_visitor_passkeys_on_webauthn_id", unique: true
  end

  create_table "visitor_secret_kinds", force: :cascade do |t|
  end

  create_table "visitor_secret_statuses", force: :cascade do |t|
  end

  create_table "visitor_secrets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.datetime "last_used_at"
    t.string "name", default: "", null: false
    t.string "password_digest", default: "", null: false
    t.string "public_id", limit: 21, null: false
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.datetime "updated_at", null: false
    t.integer "uses_remaining", default: 1, null: false
    t.bigint "visitor_id", null: false
    t.bigint "visitor_secret_kind_id", default: 1, null: false
    t.bigint "visitor_secret_status_id", default: 1, null: false
    t.index ["public_id"], name: "index_visitor_secrets_on_public_id", unique: true
    t.index ["visitor_id"], name: "index_visitor_secrets_on_visitor_id"
    t.index ["visitor_secret_kind_id"], name: "index_visitor_secrets_on_visitor_secret_kind_id"
    t.index ["visitor_secret_status_id"], name: "index_visitor_secrets_on_visitor_secret_status_id"
    t.check_constraint "lapses_at <= purge_at", name: "chk_customer_secrets_retention_order"
  end

  create_table "visitor_statuses", force: :cascade do |t|
  end

  create_table "visitor_telephone_statuses", force: :cascade do |t|
  end

  create_table "visitor_telephones", force: :cascade do |t|
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
    t.bigint "visitor_id", null: false
    t.bigint "visitor_telephone_status_id", default: 1, null: false
    t.index "lower((number)::text)", name: "index_visitor_telephones_on_lower_number", unique: true
    t.index ["number_digest"], name: "index_visitor_telephones_on_number_digest", unique: true, where: "(number_digest IS NOT NULL)"
    t.index ["public_id"], name: "index_visitor_telephones_on_public_id", unique: true
    t.index ["visitor_id"], name: "index_visitor_telephones_on_visitor_id"
    t.index ["visitor_telephone_status_id"], name: "index_visitor_telephones_on_visitor_telephone_status_id"
  end

  create_table "visitor_visibilities", force: :cascade do |t|
  end

  create_table "visitors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.integer "lock_version", default: 0, null: false
    t.boolean "multi_factor_enabled", default: false, null: false
    t.bigint "multi_factor_id", default: 0, null: false
    t.bigint "multi_factor_status_id", default: 5, null: false
    t.string "public_id", default: "", null: false
    t.datetime "purge_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "visibility_id", default: 1, null: false
    t.datetime "withdrawal_started_at"
    t.datetime "withdrawn_at", default: ::Float::INFINITY
    t.index ["deactivated_at"], name: "index_visitors_on_deactivated_at", where: "(deactivated_at IS NOT NULL)"
    t.index ["multi_factor_id"], name: "index_visitors_on_multi_factor_id"
    t.index ["multi_factor_status_id"], name: "index_visitors_on_multi_factor_status_id"
    t.index ["public_id"], name: "index_visitors_on_public_id", unique: true
    t.index ["purge_at"], name: "index_visitors_on_purge_at"
    t.index ["status_id"], name: "index_visitors_on_status_id"
    t.index ["visibility_id"], name: "index_visitors_on_visibility_id"
    t.index ["withdrawal_started_at"], name: "index_visitors_on_withdrawal_started_at", where: "(withdrawal_started_at IS NOT NULL)"
    t.index ["withdrawn_at"], name: "index_visitors_on_withdrawn_at", where: "(withdrawn_at IS NOT NULL)"
    t.check_constraint "lapses_at <= purge_at", name: "chk_customers_retention_order"
  end

  add_foreign_key "visitor_emails", "visitor_email_statuses"
  add_foreign_key "visitor_emails", "visitors"
  add_foreign_key "visitor_passkeys", "visitor_passkey_statuses", column: "status_id"
  add_foreign_key "visitor_passkeys", "visitors"
  add_foreign_key "visitor_secrets", "visitor_secret_kinds"
  add_foreign_key "visitor_secrets", "visitor_secret_statuses"
  add_foreign_key "visitor_secrets", "visitors"
  add_foreign_key "visitor_telephones", "visitor_telephone_statuses"
  add_foreign_key "visitor_telephones", "visitors"
  add_foreign_key "visitors", "visitor_multi_factor_statuses", column: "multi_factor_status_id", validate: false
  add_foreign_key "visitors", "visitor_multi_factors", column: "multi_factor_id", validate: false
  add_foreign_key "visitors", "visitor_statuses", column: "status_id", validate: false
  add_foreign_key "visitors", "visitor_visibilities", column: "visibility_id", validate: false
end
