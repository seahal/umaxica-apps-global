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

ActiveRecord::Schema[8.2].define(version: 2026_05_20_143102) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agent_membership_kinds", force: :cascade do |t|
  end

  create_table "agent_membership_revoke_reasons", force: :cascade do |t|
  end

  create_table "agent_membership_states", force: :cascade do |t|
  end

  create_table "agent_memberships", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "bureau_id", null: false
    t.bigint "bureau_unit_id", null: false
    t.bigint "membership_kind_id", default: 0, null: false
    t.bigint "membership_state_id", default: 0, null: false
    t.boolean "primary", default: false, null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.bigint "granted_by_agent_id"
    t.bigint "approved_by_agent_id"
    t.bigint "revoked_by_agent_id"
    t.datetime "revoked_at"
    t.bigint "revoke_reason_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "idx_agent_memberships_one_active_primary", unique: true, where: "((\"primary\" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL))"
    t.index ["agent_id"], name: "index_agent_memberships_on_agent_id"
    t.index ["approved_by_agent_id"], name: "index_agent_memberships_on_approved_by_agent_id"
    t.index ["bureau_id"], name: "index_agent_memberships_on_bureau_id"
    t.index ["bureau_unit_id"], name: "index_agent_memberships_on_bureau_unit_id"
    t.index ["granted_by_agent_id"], name: "index_agent_memberships_on_granted_by_agent_id"
    t.index ["membership_kind_id"], name: "index_agent_memberships_on_membership_kind_id"
    t.index ["membership_state_id"], name: "index_agent_memberships_on_membership_state_id"
    t.index ["revoke_reason_id"], name: "index_agent_memberships_on_revoke_reason_id"
    t.index ["revoked_by_agent_id"], name: "index_agent_memberships_on_revoked_by_agent_id"
  end

  create_table "agents", force: :cascade do |t|
    t.bigint "operator_identity_id", null: false
    t.string "public_id", default: "", null: false
    t.string "moniker"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["operator_identity_id"], name: "idx_agents_one_per_operator_identity", unique: true
    t.index ["operator_identity_id"], name: "index_agents_on_operator_identity_id"
    t.index ["public_id"], name: "index_agents_on_public_id", unique: true
  end

  create_table "bureau_unit_closures", force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "depth", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestor_id", "descendant_id"], name: "idx_bureau_unit_closures_unique_path", unique: true
    t.index ["ancestor_id"], name: "index_bureau_unit_closures_on_ancestor_id"
    t.index ["descendant_id"], name: "index_bureau_unit_closures_on_descendant_id"
    t.check_constraint "ancestor_id = descendant_id AND depth = 0 OR ancestor_id <> descendant_id AND depth > 0", name: "chk_bureau_unit_closures_depth_matches_self"
    t.check_constraint "depth >= 0", name: "chk_bureau_unit_closures_depth_nonnegative"
  end

  create_table "bureau_units", force: :cascade do |t|
    t.bigint "bureau_id", null: false
    t.bigint "parent_id"
    t.string "public_id", default: "", null: false
    t.string "name", default: "", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bureau_id"], name: "index_bureau_units_on_bureau_id"
    t.index ["id", "bureau_id"], name: "idx_bureau_units_id_bureau", unique: true
    t.index ["parent_id"], name: "index_bureau_units_on_parent_id"
    t.index ["public_id"], name: "index_bureau_units_on_public_id", unique: true
  end

  create_table "bureaus", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.string "name", default: "", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_bureaus_on_public_id", unique: true
  end

  create_table "operator_accounts", force: :cascade do |t|
    t.string "public_id", default: "", null: false
    t.bigint "staff_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_operator_accounts_on_public_id", unique: true
    t.index ["staff_id"], name: "index_operator_accounts_on_staff_id", unique: true
  end

  create_table "operator_identities", force: :cascade do |t|
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
    t.index ["issuer", "subject", "audience"], name: "index_operator_identities_on_issuer_and_subject_and_audience", unique: true
    t.index ["public_id"], name: "index_operator_identities_on_public_id", unique: true
    t.index ["source_record_id"], name: "index_operator_identities_on_source_record_id", unique: true
    t.index ["status_id"], name: "index_operator_identities_on_status_id"
  end

  create_table "operator_identity_states", force: :cascade do |t|
  end

  create_table "operator_workspace_account_memberships", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.bigint "operator_workspace_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["operator_workspace_account_id"], name: "idx_operator_workspace_memberships_on_account_id"
    t.index ["staff_id", "operator_workspace_account_id"], name: "idx_operator_workspace_memberships_on_staff_and_account", unique: true
  end

  create_table "operator_workspace_accounts", force: :cascade do |t|
    t.bigint "staff_id", null: false
    t.bigint "department_id"
    t.string "public_id", null: false
    t.string "moniker"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "status_id", default: 0, null: false
    t.index ["department_id"], name: "index_operator_workspace_accounts_on_department_id"
    t.index ["public_id"], name: "index_operator_workspace_accounts_on_public_id", unique: true
    t.index ["staff_id"], name: "index_operator_workspace_accounts_on_staff_id"
    t.index ["status_id"], name: "index_operator_workspace_accounts_on_status_id"
  end

  add_foreign_key "agent_memberships", "agent_membership_kinds", column: "membership_kind_id", validate: false
  add_foreign_key "agent_memberships", "agent_membership_revoke_reasons", column: "revoke_reason_id", validate: false
  add_foreign_key "agent_memberships", "agent_membership_states", column: "membership_state_id", validate: false
  add_foreign_key "agent_memberships", "agents"
  add_foreign_key "agent_memberships", "agents", column: "approved_by_agent_id", validate: false
  add_foreign_key "agent_memberships", "agents", column: "granted_by_agent_id", validate: false
  add_foreign_key "agent_memberships", "agents", column: "revoked_by_agent_id", validate: false
  add_foreign_key "agent_memberships", "bureau_units"
  add_foreign_key "agent_memberships", "bureau_units", column: ["bureau_unit_id", "bureau_id"], primary_key: ["id", "bureau_id"], name: "fk_agent_memberships_unit_same_bureau"
  add_foreign_key "agent_memberships", "bureaus"
  add_foreign_key "bureau_unit_closures", "bureau_units", column: "ancestor_id"
  add_foreign_key "bureau_unit_closures", "bureau_units", column: "descendant_id"
  add_foreign_key "bureau_units", "bureau_units", column: "parent_id"
  add_foreign_key "bureau_units", "bureau_units", column: ["parent_id", "bureau_id"], primary_key: ["id", "bureau_id"], name: "fk_bureau_units_parent_same_bureau"
  add_foreign_key "bureau_units", "bureaus"
  add_foreign_key "operator_identities", "operator_identity_states", column: "status_id"
  add_foreign_key "operator_workspace_account_memberships", "operator_workspace_accounts", on_delete: :cascade, validate: false
end
