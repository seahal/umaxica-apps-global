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

ActiveRecord::Schema[8.2].define(version: 2026_05_20_143100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "client_accounts", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_client_accounts_on_public_id", unique: true
    t.index ["user_id"], name: "index_client_accounts_on_user_id", unique: true
  end

  create_table "client_identities", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.string "issuer", null: false
    t.string "subject", null: false
    t.string "audience", null: false
    t.bigint "source_record_id", null: false
    t.bigint "status_id", default: 0, null: false
    t.datetime "last_authenticated_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issuer", "subject", "audience"], name: "index_client_identities_on_issuer_and_subject_and_audience", unique: true
    t.index ["public_id"], name: "index_client_identities_on_public_id", unique: true
    t.index ["source_record_id"], name: "index_client_identities_on_source_record_id", unique: true
    t.index ["status_id"], name: "index_client_identities_on_status_id"
  end

  create_table "client_identity_states", force: :cascade do |t|
  end

  create_table "client_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "division_id"
    t.integer "lock_version", default: 0, null: false
    t.string "moniker"
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "client_status_id", default: 0, null: false
    t.bigint "status_id", default: 0, null: false
    t.index ["client_status_id"], name: "index_client_profiles_on_client_status_id"
    t.index ["division_id"], name: "index_client_profiles_on_division_id"
    t.index ["public_id"], name: "index_client_profiles_on_public_id", unique: true
    t.index ["status_id"], name: "index_client_profiles_on_status_id"
    t.index ["user_id"], name: "index_client_profiles_on_user_id"
  end

  create_table "enterprise_unit_closures", force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "depth", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestor_id", "descendant_id"], name: "idx_enterprise_unit_closures_unique_path", unique: true
    t.index ["ancestor_id"], name: "index_enterprise_unit_closures_on_ancestor_id"
    t.index ["descendant_id"], name: "index_enterprise_unit_closures_on_descendant_id"
    t.check_constraint "ancestor_id = descendant_id AND depth = 0 OR ancestor_id <> descendant_id AND depth > 0", name: "chk_enterprise_unit_closures_depth_matches_self"
    t.check_constraint "depth >= 0", name: "chk_enterprise_unit_closures_depth_nonnegative"
  end

  create_table "enterprise_units", force: :cascade do |t|
    t.bigint "enterprise_id", null: false
    t.bigint "parent_id"
    t.string "public_id", default: "", null: false
    t.string "name", default: "", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enterprise_id"], name: "index_enterprise_units_on_enterprise_id"
    t.index ["id", "enterprise_id"], name: "idx_enterprise_units_id_enterprise", unique: true
    t.index ["parent_id"], name: "index_enterprise_units_on_parent_id"
    t.index ["public_id"], name: "index_enterprise_units_on_public_id", unique: true
  end

  create_table "enterprises", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.string "name", default: "", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_enterprises_on_public_id", unique: true
  end

  create_table "persona_membership_kinds", force: :cascade do |t|
  end

  create_table "persona_membership_revoke_reasons", force: :cascade do |t|
  end

  create_table "persona_membership_states", force: :cascade do |t|
  end

  create_table "persona_memberships", force: :cascade do |t|
    t.bigint "persona_id", null: false
    t.bigint "enterprise_id", null: false
    t.bigint "enterprise_unit_id", null: false
    t.bigint "membership_kind_id", default: 0, null: false
    t.bigint "membership_state_id", default: 0, null: false
    t.boolean "primary", default: false, null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.bigint "granted_by_persona_id"
    t.bigint "approved_by_persona_id"
    t.bigint "revoked_by_persona_id"
    t.datetime "revoked_at"
    t.bigint "revoke_reason_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_persona_id"], name: "index_persona_memberships_on_approved_by_persona_id"
    t.index ["enterprise_id"], name: "index_persona_memberships_on_enterprise_id"
    t.index ["enterprise_unit_id"], name: "index_persona_memberships_on_enterprise_unit_id"
    t.index ["granted_by_persona_id"], name: "index_persona_memberships_on_granted_by_persona_id"
    t.index ["membership_kind_id"], name: "index_persona_memberships_on_membership_kind_id"
    t.index ["membership_state_id"], name: "index_persona_memberships_on_membership_state_id"
    t.index ["persona_id"], name: "idx_persona_memberships_one_active_primary", unique: true, where: "((\"primary\" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL))"
    t.index ["persona_id"], name: "index_persona_memberships_on_persona_id"
    t.index ["revoke_reason_id"], name: "index_persona_memberships_on_revoke_reason_id"
    t.index ["revoked_by_persona_id"], name: "index_persona_memberships_on_revoked_by_persona_id"
  end

  create_table "personas", force: :cascade do |t|
    t.bigint "client_identity_id", null: false
    t.string "public_id", default: "", null: false
    t.string "moniker"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_identity_id"], name: "idx_personas_one_per_client_identity", unique: true
    t.index ["client_identity_id"], name: "index_personas_on_client_identity_id"
    t.index ["public_id"], name: "index_personas_on_public_id", unique: true
  end

  create_table "visitor_account_statuses", force: :cascade do |t|
  end

  add_foreign_key "client_identities", "client_identity_states", column: "status_id", validate: false
  add_foreign_key "client_profiles", "visitor_account_statuses", column: "client_status_id", validate: false
  add_foreign_key "client_profiles", "visitor_account_statuses", column: "status_id", validate: false
  add_foreign_key "enterprise_unit_closures", "enterprise_units", column: "ancestor_id"
  add_foreign_key "enterprise_unit_closures", "enterprise_units", column: "descendant_id"
  add_foreign_key "enterprise_units", "enterprise_units", column: "parent_id"
  add_foreign_key "enterprise_units", "enterprise_units", column: ["parent_id", "enterprise_id"], primary_key: ["id", "enterprise_id"], name: "fk_enterprise_units_parent_same_enterprise"
  add_foreign_key "enterprise_units", "enterprises"
  add_foreign_key "persona_memberships", "enterprise_units"
  add_foreign_key "persona_memberships", "enterprise_units", column: ["enterprise_unit_id", "enterprise_id"], primary_key: ["id", "enterprise_id"], name: "fk_persona_memberships_unit_same_enterprise"
  add_foreign_key "persona_memberships", "enterprises"
  add_foreign_key "persona_memberships", "persona_membership_kinds", column: "membership_kind_id", validate: false
  add_foreign_key "persona_memberships", "persona_membership_revoke_reasons", column: "revoke_reason_id", validate: false
  add_foreign_key "persona_memberships", "persona_membership_states", column: "membership_state_id", validate: false
  add_foreign_key "persona_memberships", "personas"
  add_foreign_key "persona_memberships", "personas", column: "approved_by_persona_id", validate: false
  add_foreign_key "persona_memberships", "personas", column: "granted_by_persona_id", validate: false
  add_foreign_key "persona_memberships", "personas", column: "revoked_by_persona_id", validate: false
end
