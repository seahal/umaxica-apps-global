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

ActiveRecord::Schema[8.2].define(version: 2026_05_20_143101) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.string "name", default: "", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_companies_on_public_id", unique: true
  end

  create_table "company_unit_closures", force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "depth", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestor_id", "descendant_id"], name: "idx_company_unit_closures_unique_path", unique: true
    t.index ["ancestor_id"], name: "index_company_unit_closures_on_ancestor_id"
    t.index ["descendant_id"], name: "index_company_unit_closures_on_descendant_id"
    t.check_constraint "ancestor_id = descendant_id AND depth = 0 OR ancestor_id <> descendant_id AND depth > 0", name: "chk_company_unit_closures_depth_matches_self"
    t.check_constraint "depth >= 0", name: "chk_company_unit_closures_depth_nonnegative"
  end

  create_table "company_units", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "parent_id"
    t.string "public_id", default: "", null: false
    t.string "name", default: "", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_units_on_company_id"
    t.index ["id", "company_id"], name: "idx_company_units_id_company", unique: true
    t.index ["parent_id"], name: "index_company_units_on_parent_id"
    t.index ["public_id"], name: "index_company_units_on_public_id", unique: true
  end

  create_table "individual_membership_kinds", force: :cascade do |t|
  end

  create_table "individual_membership_revoke_reasons", force: :cascade do |t|
  end

  create_table "individual_membership_states", force: :cascade do |t|
  end

  create_table "individual_memberships", force: :cascade do |t|
    t.bigint "individual_id", null: false
    t.bigint "company_id", null: false
    t.bigint "company_unit_id", null: false
    t.bigint "membership_kind_id", default: 0, null: false
    t.bigint "membership_state_id", default: 0, null: false
    t.boolean "primary", default: false, null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.bigint "granted_by_individual_id"
    t.bigint "approved_by_individual_id"
    t.bigint "revoked_by_individual_id"
    t.datetime "revoked_at"
    t.bigint "revoke_reason_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_individual_id"], name: "index_individual_memberships_on_approved_by_individual_id"
    t.index ["company_id"], name: "index_individual_memberships_on_company_id"
    t.index ["company_unit_id"], name: "index_individual_memberships_on_company_unit_id"
    t.index ["granted_by_individual_id"], name: "index_individual_memberships_on_granted_by_individual_id"
    t.index ["individual_id"], name: "idx_individual_memberships_one_active_primary", unique: true, where: "((\"primary\" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL))"
    t.index ["individual_id"], name: "index_individual_memberships_on_individual_id"
    t.index ["membership_kind_id"], name: "index_individual_memberships_on_membership_kind_id"
    t.index ["membership_state_id"], name: "index_individual_memberships_on_membership_state_id"
    t.index ["revoke_reason_id"], name: "index_individual_memberships_on_revoke_reason_id"
    t.index ["revoked_by_individual_id"], name: "index_individual_memberships_on_revoked_by_individual_id"
  end

  create_table "individuals", force: :cascade do |t|
    t.bigint "visitor_identity_id", null: false
    t.string "public_id", default: "", null: false
    t.string "moniker"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_individuals_on_public_id", unique: true
    t.index ["visitor_identity_id"], name: "idx_individuals_one_per_visitor_identity", unique: true
    t.index ["visitor_identity_id"], name: "index_individuals_on_visitor_identity_id"
  end

  create_table "visitor_accounts", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.bigint "visitor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_visitor_accounts_on_public_id", unique: true
    t.index ["visitor_id"], name: "index_visitor_accounts_on_visitor_id", unique: true
  end

  create_table "visitor_identities", force: :cascade do |t|
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
    t.index ["issuer", "subject", "audience"], name: "index_visitor_identities_on_issuer_and_subject_and_audience", unique: true
    t.index ["public_id"], name: "index_visitor_identities_on_public_id", unique: true
    t.index ["source_record_id"], name: "index_visitor_identities_on_source_record_id", unique: true
    t.index ["status_id"], name: "index_visitor_identities_on_status_id"
  end

  create_table "visitor_identity_states", force: :cascade do |t|
  end

  add_foreign_key "company_unit_closures", "company_units", column: "ancestor_id"
  add_foreign_key "company_unit_closures", "company_units", column: "descendant_id"
  add_foreign_key "company_units", "companies"
  add_foreign_key "company_units", "company_units", column: "parent_id"
  add_foreign_key "company_units", "company_units", column: ["parent_id", "company_id"], primary_key: ["id", "company_id"], name: "fk_company_units_parent_same_company"
  add_foreign_key "individual_memberships", "companies"
  add_foreign_key "individual_memberships", "company_units"
  add_foreign_key "individual_memberships", "company_units", column: ["company_unit_id", "company_id"], primary_key: ["id", "company_id"], name: "fk_individual_memberships_unit_same_company"
  add_foreign_key "individual_memberships", "individual_membership_kinds", column: "membership_kind_id", validate: false
  add_foreign_key "individual_memberships", "individual_membership_revoke_reasons", column: "revoke_reason_id", validate: false
  add_foreign_key "individual_memberships", "individual_membership_states", column: "membership_state_id", validate: false
  add_foreign_key "individual_memberships", "individuals"
  add_foreign_key "individual_memberships", "individuals", column: "approved_by_individual_id", validate: false
  add_foreign_key "individual_memberships", "individuals", column: "granted_by_individual_id", validate: false
  add_foreign_key "individual_memberships", "individuals", column: "revoked_by_individual_id", validate: false
  add_foreign_key "visitor_identities", "visitor_identity_states", column: "status_id", validate: false
end
