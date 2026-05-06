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

ActiveRecord::Schema[8.2].define(version: 2026_03_29_143000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "area_domain_occurrences", force: :cascade do |t|
    t.bigint "area_occurrence_id", null: false
    t.datetime "created_at", null: false
    t.bigint "domain_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["area_occurrence_id", "domain_occurrence_id"], name: "idx_area_domain_occ_on_ids", unique: true
    t.index ["domain_occurrence_id"], name: "index_area_domain_occurrences_on_domain_occurrence_id"
  end

  create_table "area_email_occurrences", force: :cascade do |t|
    t.bigint "area_occurrence_id", null: false
    t.datetime "created_at", null: false
    t.bigint "email_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["area_occurrence_id", "email_occurrence_id"], name: "idx_area_email_occ_on_ids", unique: true
    t.index ["email_occurrence_id"], name: "index_area_email_occurrences_on_email_occurrence_id"
  end

  create_table "area_ip_occurrences", force: :cascade do |t|
    t.bigint "area_occurrence_id", null: false
    t.datetime "created_at", null: false
    t.bigint "ip_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["area_occurrence_id", "ip_occurrence_id"], name: "idx_area_ip_occ_on_ids", unique: true
    t.index ["ip_occurrence_id"], name: "index_area_ip_occurrences_on_ip_occurrence_id"
  end

  create_table "area_occurrence_statuses", force: :cascade do |t|
  end

  create_table "area_occurrences", force: :cascade do |t|
    t.string "body", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "deletable_at", precision: nil, default: ::Float::INFINITY, null: false
    t.string "memo", default: "", null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "revoked_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["body"], name: "index_area_occurrences_on_body", unique: true
    t.index ["deletable_at"], name: "index_area_occurrences_on_deletable_at"
    t.index ["public_id"], name: "index_area_occurrences_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_area_occurrences_on_revoked_at"
    t.index ["status_id"], name: "index_area_occurrences_on_status_id"
  end

  create_table "area_staff_occurrences", force: :cascade do |t|
    t.bigint "area_occurrence_id", null: false
    t.datetime "created_at", null: false
    t.bigint "staff_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["area_occurrence_id", "staff_occurrence_id"], name: "idx_area_staff_occ_on_ids", unique: true
    t.index ["staff_occurrence_id"], name: "index_area_staff_occurrences_on_staff_occurrence_id"
  end

  create_table "area_telephone_occurrences", force: :cascade do |t|
    t.bigint "area_occurrence_id", null: false
    t.datetime "created_at", null: false
    t.bigint "telephone_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["area_occurrence_id", "telephone_occurrence_id"], name: "idx_area_telephone_occ_on_ids", unique: true
    t.index ["telephone_occurrence_id"], name: "index_area_telephone_occurrences_on_telephone_occurrence_id"
  end

  create_table "area_user_occurrences", force: :cascade do |t|
    t.bigint "area_occurrence_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_occurrence_id", null: false
    t.index ["area_occurrence_id", "user_occurrence_id"], name: "idx_area_user_occ_on_ids", unique: true
    t.index ["user_occurrence_id"], name: "index_area_user_occurrences_on_user_occurrence_id"
  end

  create_table "area_zip_occurrences", force: :cascade do |t|
    t.bigint "area_occurrence_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "zip_occurrence_id", null: false
    t.index ["area_occurrence_id", "zip_occurrence_id"], name: "idx_area_zip_occ_on_ids", unique: true
    t.index ["zip_occurrence_id"], name: "index_area_zip_occurrences_on_zip_occurrence_id"
  end

  create_table "domain_email_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "domain_occurrence_id", null: false
    t.bigint "email_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["domain_occurrence_id", "email_occurrence_id"], name: "idx_domain_email_occ_on_ids", unique: true
    t.index ["email_occurrence_id"], name: "index_domain_email_occurrences_on_email_occurrence_id"
  end

  create_table "domain_ip_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "domain_occurrence_id", null: false
    t.bigint "ip_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["domain_occurrence_id", "ip_occurrence_id"], name: "idx_domain_ip_occ_on_ids", unique: true
    t.index ["ip_occurrence_id"], name: "index_domain_ip_occurrences_on_ip_occurrence_id"
  end

  create_table "domain_occurrence_statuses", force: :cascade do |t|
  end

  create_table "domain_occurrences", force: :cascade do |t|
    t.string "body", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "deletable_at", precision: nil, default: ::Float::INFINITY, null: false
    t.string "memo", default: "", null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "revoked_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["body"], name: "index_domain_occurrences_on_body", unique: true
    t.index ["deletable_at"], name: "index_domain_occurrences_on_deletable_at"
    t.index ["public_id"], name: "index_domain_occurrences_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_domain_occurrences_on_revoked_at"
    t.index ["status_id"], name: "index_domain_occurrences_on_status_id"
  end

  create_table "domain_staff_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "domain_occurrence_id", null: false
    t.bigint "staff_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["domain_occurrence_id", "staff_occurrence_id"], name: "idx_domain_staff_occ_on_ids", unique: true
    t.index ["staff_occurrence_id"], name: "index_domain_staff_occurrences_on_staff_occurrence_id"
  end

  create_table "domain_telephone_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "domain_occurrence_id", null: false
    t.bigint "telephone_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["domain_occurrence_id", "telephone_occurrence_id"], name: "idx_domain_telephone_occ_on_ids", unique: true
    t.index ["telephone_occurrence_id"], name: "index_domain_telephone_occurrences_on_telephone_occurrence_id"
  end

  create_table "domain_user_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "domain_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_occurrence_id", null: false
    t.index ["domain_occurrence_id", "user_occurrence_id"], name: "idx_domain_user_occ_on_ids", unique: true
    t.index ["user_occurrence_id"], name: "index_domain_user_occurrences_on_user_occurrence_id"
  end

  create_table "domain_zip_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "domain_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "zip_occurrence_id", null: false
    t.index ["domain_occurrence_id", "zip_occurrence_id"], name: "idx_domain_zip_occ_on_ids", unique: true
    t.index ["zip_occurrence_id"], name: "index_domain_zip_occurrences_on_zip_occurrence_id"
  end

  create_table "email_ip_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "email_occurrence_id", null: false
    t.bigint "ip_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["email_occurrence_id", "ip_occurrence_id"], name: "idx_email_ip_occ_on_ids", unique: true
    t.index ["ip_occurrence_id"], name: "index_email_ip_occurrences_on_ip_occurrence_id"
  end

  create_table "email_occurrence_statuses", force: :cascade do |t|
  end

  create_table "email_occurrences", force: :cascade do |t|
    t.string "body", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "deletable_at", precision: nil, default: ::Float::INFINITY, null: false
    t.string "memo", default: "", null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "revoked_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["body", "created_at"], name: "index_email_occurrences_on_body_created_at"
    t.index ["body"], name: "index_email_occurrences_on_body", unique: true
    t.index ["deletable_at"], name: "index_email_occurrences_on_deletable_at"
    t.index ["public_id"], name: "index_email_occurrences_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_email_occurrences_on_revoked_at"
    t.index ["status_id"], name: "index_email_occurrences_on_status_id"
    t.check_constraint "char_length(memo::text) <= 1000", name: "chk_email_occurrences_memo_length"
  end

  create_table "email_staff_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "email_occurrence_id", null: false
    t.bigint "staff_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["email_occurrence_id", "staff_occurrence_id"], name: "idx_email_staff_occ_on_ids", unique: true
    t.index ["staff_occurrence_id"], name: "index_email_staff_occurrences_on_staff_occurrence_id"
  end

  create_table "email_telephone_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "email_occurrence_id", null: false
    t.bigint "telephone_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["email_occurrence_id", "telephone_occurrence_id"], name: "idx_email_telephone_occ_on_ids", unique: true
    t.index ["telephone_occurrence_id"], name: "index_email_telephone_occurrences_on_telephone_occurrence_id"
  end

  create_table "email_user_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "email_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_occurrence_id", null: false
    t.index ["email_occurrence_id", "user_occurrence_id"], name: "idx_email_user_occ_on_ids", unique: true
    t.index ["user_occurrence_id"], name: "index_email_user_occurrences_on_user_occurrence_id"
  end

  create_table "email_zip_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "email_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "zip_occurrence_id", null: false
    t.index ["email_occurrence_id", "zip_occurrence_id"], name: "idx_email_zip_occ_on_ids", unique: true
    t.index ["zip_occurrence_id"], name: "index_email_zip_occurrences_on_zip_occurrence_id"
  end

  create_table "ip_occurrence_statuses", force: :cascade do |t|
  end

  create_table "ip_occurrences", force: :cascade do |t|
    t.string "body", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "deletable_at", precision: nil, default: ::Float::INFINITY, null: false
    t.string "memo", default: "", null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "revoked_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["body", "created_at"], name: "index_ip_occurrences_on_body_created_at"
    t.index ["body"], name: "index_ip_occurrences_on_body", unique: true
    t.index ["deletable_at"], name: "index_ip_occurrences_on_deletable_at"
    t.index ["public_id"], name: "index_ip_occurrences_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_ip_occurrences_on_revoked_at"
    t.index ["status_id"], name: "index_ip_occurrences_on_status_id"
    t.check_constraint "char_length(memo::text) <= 1000", name: "chk_ip_occurrences_memo_length"
  end

  create_table "ip_staff_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "ip_occurrence_id", null: false
    t.bigint "staff_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ip_occurrence_id", "staff_occurrence_id"], name: "idx_ip_staff_occ_on_ids", unique: true
    t.index ["staff_occurrence_id"], name: "index_ip_staff_occurrences_on_staff_occurrence_id"
  end

  create_table "ip_telephone_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "ip_occurrence_id", null: false
    t.bigint "telephone_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ip_occurrence_id", "telephone_occurrence_id"], name: "idx_ip_telephone_occ_on_ids", unique: true
    t.index ["telephone_occurrence_id"], name: "index_ip_telephone_occurrences_on_telephone_occurrence_id"
  end

  create_table "ip_user_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "ip_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_occurrence_id", null: false
    t.index ["ip_occurrence_id", "user_occurrence_id"], name: "idx_ip_user_occ_on_ids", unique: true
    t.index ["user_occurrence_id"], name: "index_ip_user_occurrences_on_user_occurrence_id"
  end

  create_table "ip_zip_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "ip_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "zip_occurrence_id", null: false
    t.index ["ip_occurrence_id", "zip_occurrence_id"], name: "idx_ip_zip_occ_on_ids", unique: true
    t.index ["zip_occurrence_id"], name: "index_ip_zip_occurrences_on_zip_occurrence_id"
  end

  create_table "jwt_anomaly_events", force: :cascade do |t|
    t.string "alg", default: "", null: false
    t.string "code", default: "", null: false
    t.datetime "created_at", null: false
    t.string "error_class", default: "", null: false
    t.string "error_message", default: "", null: false
    t.string "issuer", default: "", null: false
    t.string "jti", default: "", null: false
    t.bigint "jwt_occurrence_id", null: false
    t.string "kid", default: "", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "request_host", default: "", null: false
    t.string "typ", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_jwt_anomaly_events_on_code"
    t.index ["jwt_occurrence_id"], name: "index_jwt_anomaly_events_on_jwt_occurrence_id"
    t.index ["occurred_at"], name: "index_jwt_anomaly_events_on_occurred_at"
  end

  create_table "jwt_occurrence_statuses", force: :cascade do |t|
    t.string "name", default: "", null: false
  end

  create_table "jwt_occurrences", force: :cascade do |t|
    t.string "body", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "deletable_at", precision: nil, default: ::Float::INFINITY, null: false
    t.string "memo", default: "", null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "revoked_at", precision: nil, default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["body", "created_at"], name: "index_jwt_occurrences_on_body_and_created_at"
    t.index ["body"], name: "index_jwt_occurrences_on_body", unique: true
    t.index ["deletable_at"], name: "index_jwt_occurrences_on_deletable_at"
    t.index ["public_id"], name: "index_jwt_occurrences_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_jwt_occurrences_on_revoked_at"
    t.index ["status_id"], name: "index_jwt_occurrences_on_status_id"
    t.check_constraint "char_length(memo::text) <= 1000", name: "chk_jwt_occurrences_memo_length"
  end

  create_table "staff_occurrence_statuses", force: :cascade do |t|
    t.string "name", default: "", null: false
  end

  create_table "staff_occurrences", force: :cascade do |t|
    t.string "body", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "deletable_at", precision: nil, default: ::Float::INFINITY, null: false
    t.string "event_type", default: "", null: false
    t.string "memo", default: "", null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "revoked_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["body"], name: "index_staff_occurrences_on_body", unique: true
    t.index ["deletable_at"], name: "index_staff_occurrences_on_deletable_at"
    t.index ["event_type", "created_at"], name: "index_staff_occurrences_on_event_type_and_created_at"
    t.index ["public_id"], name: "index_staff_occurrences_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_staff_occurrences_on_revoked_at"
    t.index ["status_id", "created_at"], name: "index_staff_occurrences_on_status_id_and_created_at"
  end

  create_table "staff_telephone_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "staff_occurrence_id", null: false
    t.bigint "telephone_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_occurrence_id", "telephone_occurrence_id"], name: "idx_staff_telephone_occ_on_ids", unique: true
    t.index ["telephone_occurrence_id"], name: "index_staff_telephone_occurrences_on_telephone_occurrence_id"
  end

  create_table "staff_user_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "staff_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_occurrence_id", null: false
    t.index ["staff_occurrence_id", "user_occurrence_id"], name: "idx_staff_user_occ_on_ids", unique: true
    t.index ["user_occurrence_id"], name: "index_staff_user_occurrences_on_user_occurrence_id"
  end

  create_table "staff_zip_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "staff_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "zip_occurrence_id", null: false
    t.index ["staff_occurrence_id", "zip_occurrence_id"], name: "idx_staff_zip_occ_on_ids", unique: true
    t.index ["zip_occurrence_id"], name: "index_staff_zip_occurrences_on_zip_occurrence_id"
  end

  create_table "telephone_occurrence_statuses", force: :cascade do |t|
  end

  create_table "telephone_occurrences", force: :cascade do |t|
    t.string "body", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "deletable_at", precision: nil, default: ::Float::INFINITY, null: false
    t.string "memo", default: "", null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "revoked_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["body", "created_at"], name: "index_telephone_occurrences_on_body_created_at"
    t.index ["body"], name: "index_telephone_occurrences_on_body", unique: true
    t.index ["deletable_at"], name: "index_telephone_occurrences_on_deletable_at"
    t.index ["public_id"], name: "index_telephone_occurrences_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_telephone_occurrences_on_revoked_at"
    t.index ["status_id"], name: "index_telephone_occurrences_on_status_id"
    t.check_constraint "char_length(memo::text) <= 1000", name: "chk_telephone_occurrences_memo_length"
  end

  create_table "telephone_user_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "telephone_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_occurrence_id", null: false
    t.index ["telephone_occurrence_id", "user_occurrence_id"], name: "idx_telephone_user_occ_on_ids", unique: true
    t.index ["user_occurrence_id"], name: "index_telephone_user_occurrences_on_user_occurrence_id"
  end

  create_table "telephone_zip_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "telephone_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "zip_occurrence_id", null: false
    t.index ["telephone_occurrence_id", "zip_occurrence_id"], name: "idx_telephone_zip_occ_on_ids", unique: true
    t.index ["zip_occurrence_id"], name: "index_telephone_zip_occurrences_on_zip_occurrence_id"
  end

  create_table "user_occurrence_statuses", force: :cascade do |t|
    t.string "name", default: "", null: false
  end

  create_table "user_occurrences", force: :cascade do |t|
    t.string "body", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "deletable_at", precision: nil, default: ::Float::INFINITY, null: false
    t.string "event_type", default: "", null: false
    t.string "memo", default: "", null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "revoked_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["body"], name: "index_user_occurrences_on_body", unique: true
    t.index ["deletable_at"], name: "index_user_occurrences_on_deletable_at"
    t.index ["event_type", "created_at"], name: "index_user_occurrences_on_event_type_and_created_at"
    t.index ["public_id"], name: "index_user_occurrences_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_user_occurrences_on_revoked_at"
    t.index ["status_id", "created_at"], name: "index_user_occurrences_on_status_id_and_created_at"
  end

  create_table "user_zip_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_occurrence_id", null: false
    t.bigint "zip_occurrence_id", null: false
    t.index ["user_occurrence_id", "zip_occurrence_id"], name: "idx_user_zip_occ_on_ids", unique: true
    t.index ["zip_occurrence_id"], name: "index_user_zip_occurrences_on_zip_occurrence_id"
  end

  create_table "zip_occurrence_statuses", force: :cascade do |t|
  end

  create_table "zip_occurrences", force: :cascade do |t|
    t.string "body", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "deletable_at", precision: nil, default: ::Float::INFINITY, null: false
    t.string "memo", default: "", null: false
    t.string "public_id", limit: 21, default: "", null: false
    t.datetime "revoked_at", default: ::Float::INFINITY, null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["body"], name: "index_zip_occurrences_on_body", unique: true
    t.index ["deletable_at"], name: "index_zip_occurrences_on_deletable_at"
    t.index ["public_id"], name: "index_zip_occurrences_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_zip_occurrences_on_revoked_at"
    t.index ["status_id"], name: "index_zip_occurrences_on_status_id"
  end

  add_foreign_key "area_domain_occurrences", "area_occurrences"
  add_foreign_key "area_domain_occurrences", "domain_occurrences"
  add_foreign_key "area_email_occurrences", "area_occurrences"
  add_foreign_key "area_email_occurrences", "email_occurrences"
  add_foreign_key "area_ip_occurrences", "area_occurrences"
  add_foreign_key "area_ip_occurrences", "ip_occurrences"
  add_foreign_key "area_occurrences", "area_occurrence_statuses", column: "status_id", name: "fk_area_occurrences_on_status_id"
  add_foreign_key "area_staff_occurrences", "area_occurrences"
  add_foreign_key "area_staff_occurrences", "staff_occurrences"
  add_foreign_key "area_telephone_occurrences", "area_occurrences"
  add_foreign_key "area_telephone_occurrences", "telephone_occurrences"
  add_foreign_key "area_user_occurrences", "area_occurrences"
  add_foreign_key "area_user_occurrences", "user_occurrences"
  add_foreign_key "area_zip_occurrences", "area_occurrences"
  add_foreign_key "area_zip_occurrences", "zip_occurrences"
  add_foreign_key "domain_email_occurrences", "domain_occurrences"
  add_foreign_key "domain_email_occurrences", "email_occurrences"
  add_foreign_key "domain_ip_occurrences", "domain_occurrences"
  add_foreign_key "domain_ip_occurrences", "ip_occurrences"
  add_foreign_key "domain_occurrences", "domain_occurrence_statuses", column: "status_id", name: "fk_domain_occurrences_on_status_id"
  add_foreign_key "domain_staff_occurrences", "domain_occurrences"
  add_foreign_key "domain_staff_occurrences", "staff_occurrences"
  add_foreign_key "domain_telephone_occurrences", "domain_occurrences"
  add_foreign_key "domain_telephone_occurrences", "telephone_occurrences"
  add_foreign_key "domain_user_occurrences", "domain_occurrences"
  add_foreign_key "domain_user_occurrences", "user_occurrences"
  add_foreign_key "domain_zip_occurrences", "domain_occurrences"
  add_foreign_key "domain_zip_occurrences", "zip_occurrences"
  add_foreign_key "email_ip_occurrences", "email_occurrences"
  add_foreign_key "email_ip_occurrences", "ip_occurrences"
  add_foreign_key "email_occurrences", "email_occurrence_statuses", column: "status_id", name: "fk_email_occurrences_on_status_id"
  add_foreign_key "email_staff_occurrences", "email_occurrences"
  add_foreign_key "email_staff_occurrences", "staff_occurrences"
  add_foreign_key "email_telephone_occurrences", "email_occurrences"
  add_foreign_key "email_telephone_occurrences", "telephone_occurrences"
  add_foreign_key "email_user_occurrences", "email_occurrences"
  add_foreign_key "email_user_occurrences", "user_occurrences"
  add_foreign_key "email_zip_occurrences", "email_occurrences"
  add_foreign_key "email_zip_occurrences", "zip_occurrences"
  add_foreign_key "ip_occurrences", "ip_occurrence_statuses", column: "status_id", name: "fk_ip_occurrences_on_status_id"
  add_foreign_key "ip_staff_occurrences", "ip_occurrences"
  add_foreign_key "ip_staff_occurrences", "staff_occurrences"
  add_foreign_key "ip_telephone_occurrences", "ip_occurrences"
  add_foreign_key "ip_telephone_occurrences", "telephone_occurrences"
  add_foreign_key "ip_user_occurrences", "ip_occurrences"
  add_foreign_key "ip_user_occurrences", "user_occurrences"
  add_foreign_key "ip_zip_occurrences", "ip_occurrences"
  add_foreign_key "ip_zip_occurrences", "zip_occurrences"
  add_foreign_key "jwt_anomaly_events", "jwt_occurrences", name: "fk_jwt_anomaly_events_on_jwt_occurrence_id"
  add_foreign_key "jwt_occurrences", "jwt_occurrence_statuses", column: "status_id", name: "fk_jwt_occurrences_on_status_id"
  add_foreign_key "staff_occurrences", "staff_occurrence_statuses", column: "status_id", name: "fk_staff_occurrences_on_status_id"
  add_foreign_key "staff_telephone_occurrences", "staff_occurrences"
  add_foreign_key "staff_telephone_occurrences", "telephone_occurrences"
  add_foreign_key "staff_user_occurrences", "staff_occurrences"
  add_foreign_key "staff_user_occurrences", "user_occurrences"
  add_foreign_key "staff_zip_occurrences", "staff_occurrences"
  add_foreign_key "staff_zip_occurrences", "zip_occurrences"
  add_foreign_key "telephone_occurrences", "telephone_occurrence_statuses", column: "status_id", name: "fk_telephone_occurrences_on_status_id"
  add_foreign_key "telephone_user_occurrences", "telephone_occurrences"
  add_foreign_key "telephone_user_occurrences", "user_occurrences"
  add_foreign_key "telephone_zip_occurrences", "telephone_occurrences"
  add_foreign_key "telephone_zip_occurrences", "zip_occurrences"
  add_foreign_key "user_occurrences", "user_occurrence_statuses", column: "status_id", name: "fk_user_occurrences_on_status_id"
  add_foreign_key "user_zip_occurrences", "user_occurrences"
  add_foreign_key "user_zip_occurrences", "zip_occurrences"
  add_foreign_key "zip_occurrences", "zip_occurrence_statuses", column: "status_id", name: "fk_zip_occurrences_on_status_id"
end
