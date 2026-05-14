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

ActiveRecord::Schema[8.2].define(version: 2026_05_08_151000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "app_document_audit_events", force: :cascade do |t|
  end

  create_table "app_document_audit_levels", force: :cascade do |t|
  end

  create_table "app_document_audits", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.datetime "expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_app_document_audits_on_actor_id_and_occurred_at"
    t.index ["event_id"], name: "index_app_document_audits_on_event_id"
    t.index ["expires_at"], name: "index_app_document_audits_on_expires_at"
    t.index ["level_id"], name: "index_app_document_audits_on_level_id"
    t.index ["occurred_at"], name: "index_app_document_audits_on_occurred_at"
    t.index ["subject_id"], name: "index_app_document_audits_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_cf1fa79ee4"
    t.check_constraint "event_id >= 0", name: "app_document_audits_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "app_document_audits_level_id_non_negative_check"
  end

  create_table "app_document_behavior_events", force: :cascade do |t|
  end

  create_table "app_document_behavior_levels", force: :cascade do |t|
  end

  create_table "app_document_behaviors", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "expires_at"
    t.bigint "level_id", null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_app_document_behaviors_on_actor_type_and_actor_id"
    t.index ["event_id"], name: "index_app_document_behaviors_on_event_id"
    t.index ["level_id"], name: "index_app_document_behaviors_on_level_id"
    t.index ["subject_id"], name: "index_app_document_behaviors_on_subject_id"
    t.index ["subject_type", "subject_id"], name: "index_app_document_behaviors_on_subject_type_and_subject_id"
  end

  create_table "app_preference_chronicle_events", force: :cascade do |t|
  end

  create_table "app_preference_chronicle_levels", force: :cascade do |t|
  end

  create_table "app_preference_chronicles", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.datetime "purge_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_app_preference_chronicles_on_actor_id_and_occurred_at"
    t.index ["event_id"], name: "index_app_preference_chronicles_on_event_id"
    t.index ["level_id"], name: "index_app_preference_chronicles_on_level_id"
    t.index ["occurred_at"], name: "index_app_preference_chronicles_on_occurred_at"
    t.index ["purge_at"], name: "index_app_preference_chronicles_on_purge_at"
    t.index ["subject_id"], name: "index_app_preference_chronicles_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_app_pref"
    t.check_constraint "event_id >= 0", name: "app_preference_activities_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "app_preference_activities_level_id_non_negative_check"
  end

  create_table "app_timeline_audit_events", force: :cascade do |t|
  end

  create_table "app_timeline_audit_levels", force: :cascade do |t|
  end

  create_table "app_timeline_audits", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.datetime "expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_app_timeline_audits_on_actor_id_and_occurred_at"
    t.index ["event_id"], name: "index_app_timeline_audits_on_event_id"
    t.index ["expires_at"], name: "index_app_timeline_audits_on_expires_at"
    t.index ["level_id"], name: "index_app_timeline_audits_on_level_id"
    t.index ["occurred_at"], name: "index_app_timeline_audits_on_occurred_at"
    t.index ["subject_id"], name: "index_app_timeline_audits_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_c80b4e4f83"
    t.check_constraint "event_id >= 0", name: "app_timeline_audits_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "app_timeline_audits_level_id_non_negative_check"
  end

  create_table "app_timeline_behavior_events", force: :cascade do |t|
  end

  create_table "app_timeline_behavior_levels", force: :cascade do |t|
  end

  create_table "app_timeline_behaviors", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "expires_at"
    t.bigint "level_id", null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_app_timeline_behaviors_on_actor_type_and_actor_id"
    t.index ["event_id"], name: "index_app_timeline_behaviors_on_event_id"
    t.index ["level_id"], name: "index_app_timeline_behaviors_on_level_id"
    t.index ["subject_id"], name: "index_app_timeline_behaviors_on_subject_id"
    t.index ["subject_type", "subject_id"], name: "index_app_timeline_behaviors_on_subject_type_and_subject_id"
  end

  create_table "com_document_audit_events", force: :cascade do |t|
  end

  create_table "com_document_audit_levels", force: :cascade do |t|
  end

  create_table "com_document_audits", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.datetime "expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_com_document_audits_on_actor_id_and_occurred_at"
    t.index ["event_id"], name: "index_com_document_audits_on_event_id"
    t.index ["expires_at"], name: "index_com_document_audits_on_expires_at"
    t.index ["level_id"], name: "index_com_document_audits_on_level_id"
    t.index ["occurred_at"], name: "index_com_document_audits_on_occurred_at"
    t.index ["subject_id"], name: "index_com_document_audits_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_c40361e81b"
    t.check_constraint "event_id >= 0", name: "com_document_audits_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "com_document_audits_level_id_non_negative_check"
  end

  create_table "com_document_behavior_events", force: :cascade do |t|
  end

  create_table "com_document_behavior_levels", force: :cascade do |t|
  end

  create_table "com_document_behaviors", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "expires_at"
    t.bigint "level_id", null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_com_document_behaviors_on_actor_type_and_actor_id"
    t.index ["event_id"], name: "index_com_document_behaviors_on_event_id"
    t.index ["level_id"], name: "index_com_document_behaviors_on_level_id"
    t.index ["subject_id"], name: "index_com_document_behaviors_on_subject_id"
    t.index ["subject_type", "subject_id"], name: "index_com_document_behaviors_on_subject_type_and_subject_id"
  end

  create_table "com_preference_chronicle_events", force: :cascade do |t|
  end

  create_table "com_preference_chronicle_levels", force: :cascade do |t|
  end

  create_table "com_preference_chronicles", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.datetime "purge_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_com_preference_chronicles_on_actor_id_and_occurred_at"
    t.index ["event_id"], name: "index_com_preference_chronicles_on_event_id"
    t.index ["level_id"], name: "index_com_preference_chronicles_on_level_id"
    t.index ["occurred_at"], name: "index_com_preference_chronicles_on_occurred_at"
    t.index ["purge_at"], name: "index_com_preference_chronicles_on_purge_at"
    t.index ["subject_id"], name: "index_com_preference_chronicles_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_com_pref"
    t.check_constraint "event_id >= 0", name: "com_preference_activities_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "com_preference_activities_level_id_non_negative_check"
  end

  create_table "com_timeline_audit_events", force: :cascade do |t|
  end

  create_table "com_timeline_audit_levels", force: :cascade do |t|
  end

  create_table "com_timeline_audits", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.datetime "expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_com_timeline_audits_on_actor_id_and_occurred_at"
    t.index ["event_id"], name: "index_com_timeline_audits_on_event_id"
    t.index ["expires_at"], name: "index_com_timeline_audits_on_expires_at"
    t.index ["level_id"], name: "index_com_timeline_audits_on_level_id"
    t.index ["occurred_at"], name: "index_com_timeline_audits_on_occurred_at"
    t.index ["subject_id"], name: "index_com_timeline_audits_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_99ec847a5c"
    t.check_constraint "event_id >= 0", name: "com_timeline_audits_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "com_timeline_audits_level_id_non_negative_check"
  end

  create_table "com_timeline_behavior_events", force: :cascade do |t|
  end

  create_table "com_timeline_behavior_levels", force: :cascade do |t|
  end

  create_table "com_timeline_behaviors", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "expires_at"
    t.bigint "level_id", null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_com_timeline_behaviors_on_actor_type_and_actor_id"
    t.index ["event_id"], name: "index_com_timeline_behaviors_on_event_id"
    t.index ["level_id"], name: "index_com_timeline_behaviors_on_level_id"
    t.index ["subject_id"], name: "index_com_timeline_behaviors_on_subject_id"
    t.index ["subject_type", "subject_id"], name: "index_com_timeline_behaviors_on_subject_type_and_subject_id"
  end

  create_table "org_document_audit_events", force: :cascade do |t|
  end

  create_table "org_document_audit_levels", force: :cascade do |t|
  end

  create_table "org_document_audits", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.datetime "expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_org_document_audits_on_actor_id_and_occurred_at"
    t.index ["event_id"], name: "index_org_document_audits_on_event_id"
    t.index ["expires_at"], name: "index_org_document_audits_on_expires_at"
    t.index ["level_id"], name: "index_org_document_audits_on_level_id"
    t.index ["occurred_at"], name: "index_org_document_audits_on_occurred_at"
    t.index ["subject_id"], name: "index_org_document_audits_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_bf53171ad0"
    t.check_constraint "event_id >= 0", name: "org_document_audits_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "org_document_audits_level_id_non_negative_check"
  end

  create_table "org_document_behavior_events", force: :cascade do |t|
  end

  create_table "org_document_behavior_levels", force: :cascade do |t|
  end

  create_table "org_document_behaviors", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "expires_at"
    t.bigint "level_id", null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_org_document_behaviors_on_actor_type_and_actor_id"
    t.index ["event_id"], name: "index_org_document_behaviors_on_event_id"
    t.index ["level_id"], name: "index_org_document_behaviors_on_level_id"
    t.index ["subject_id"], name: "index_org_document_behaviors_on_subject_id"
    t.index ["subject_type", "subject_id"], name: "index_org_document_behaviors_on_subject_type_and_subject_id"
  end

  create_table "org_preference_chronicle_events", force: :cascade do |t|
  end

  create_table "org_preference_chronicle_levels", force: :cascade do |t|
  end

  create_table "org_preference_chronicles", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.datetime "purge_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_org_preference_chronicles_on_actor_id_and_occurred_at"
    t.index ["event_id"], name: "index_org_preference_chronicles_on_event_id"
    t.index ["level_id"], name: "index_org_preference_chronicles_on_level_id"
    t.index ["occurred_at"], name: "index_org_preference_chronicles_on_occurred_at"
    t.index ["purge_at"], name: "index_org_preference_chronicles_on_purge_at"
    t.index ["subject_id"], name: "index_org_preference_chronicles_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_org_pref"
    t.check_constraint "event_id >= 0", name: "org_preference_activities_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "org_preference_activities_level_id_non_negative_check"
  end

  create_table "org_timeline_audit_events", force: :cascade do |t|
  end

  create_table "org_timeline_audit_levels", force: :cascade do |t|
  end

  create_table "org_timeline_audits", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.datetime "expires_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_org_timeline_audits_on_actor_id_and_occurred_at"
    t.index ["event_id"], name: "index_org_timeline_audits_on_event_id"
    t.index ["expires_at"], name: "index_org_timeline_audits_on_expires_at"
    t.index ["level_id"], name: "index_org_timeline_audits_on_level_id"
    t.index ["occurred_at"], name: "index_org_timeline_audits_on_occurred_at"
    t.index ["subject_id"], name: "index_org_timeline_audits_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_0f4341deba"
    t.check_constraint "event_id >= 0", name: "org_timeline_audits_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "org_timeline_audits_level_id_non_negative_check"
  end

  create_table "org_timeline_behavior_events", force: :cascade do |t|
  end

  create_table "org_timeline_behavior_levels", force: :cascade do |t|
  end

  create_table "org_timeline_behaviors", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "expires_at"
    t.bigint "level_id", null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_org_timeline_behaviors_on_actor_type_and_actor_id"
    t.index ["event_id"], name: "index_org_timeline_behaviors_on_event_id"
    t.index ["level_id"], name: "index_org_timeline_behaviors_on_level_id"
    t.index ["subject_id"], name: "index_org_timeline_behaviors_on_subject_id"
    t.index ["subject_type", "subject_id"], name: "index_org_timeline_behaviors_on_subject_type_and_subject_id"
  end

  create_table "scavenger_global_chronicle_events", force: :cascade do |t|
  end

  create_table "scavenger_global_chronicle_statuses", force: :cascade do |t|
  end

  create_table "scavenger_global_chronicles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "event_id", default: 0, null: false
    t.datetime "finished_at"
    t.string "idempotency_key", limit: 128, null: false
    t.string "job_type", limit: 64, null: false
    t.datetime "occurred_at"
    t.jsonb "payload"
    t.integer "retry_count"
    t.datetime "started_at"
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_scavenger_global_chronicles_on_event_id"
    t.index ["idempotency_key"], name: "index_scavenger_global_chronicles_on_idempotency_key", unique: true
    t.index ["job_type"], name: "index_scavenger_global_chronicles_on_job_type"
    t.index ["occurred_at"], name: "index_scavenger_global_chronicles_on_occurred_at"
    t.index ["status_id"], name: "index_scavenger_global_chronicles_on_status_id"
  end

  create_table "scavenger_regional_chronicle_events", force: :cascade do |t|
  end

  create_table "scavenger_regional_chronicle_statuses", force: :cascade do |t|
  end

  create_table "scavenger_regional_chronicles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "event_id", default: 0, null: false
    t.datetime "finished_at"
    t.string "idempotency_key", limit: 128, null: false
    t.string "job_type", limit: 64, null: false
    t.datetime "occurred_at"
    t.jsonb "payload"
    t.bigint "region_id", null: false
    t.integer "retry_count"
    t.datetime "started_at"
    t.bigint "status_id", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_scavenger_regional_chronicles_on_event_id"
    t.index ["occurred_at"], name: "index_scavenger_regional_chronicles_on_occurred_at"
    t.index ["region_id", "idempotency_key"], name: "idx_on_region_id_idempotency_key_2dd0f63eee", unique: true
    t.index ["region_id", "job_type"], name: "index_scavenger_regional_chronicles_on_region_id_and_job_type"
    t.index ["status_id"], name: "index_scavenger_regional_chronicles_on_status_id"
  end

  create_table "staff_chronicle_events", force: :cascade do |t|
  end

  create_table "staff_chronicle_levels", force: :cascade do |t|
  end

  create_table "staff_chronicles", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.datetime "purge_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_staff_chronicles_on_actor_id_and_occurred_at"
    t.index ["actor_type", "actor_id"], name: "index_staff_activities_on_actor"
    t.index ["event_id"], name: "index_staff_chronicles_on_event_id"
    t.index ["level_id"], name: "index_staff_chronicles_on_level_id"
    t.index ["occurred_at"], name: "index_staff_chronicles_on_occurred_at"
    t.index ["purge_at"], name: "index_staff_chronicles_on_purge_at"
    t.index ["subject_id"], name: "index_staff_chronicles_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_2e96c29236"
    t.check_constraint "event_id >= 0", name: "staff_activities_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "staff_activities_level_id_non_negative_check"
  end

  create_table "user_chronicle_events", force: :cascade do |t|
  end

  create_table "user_chronicle_levels", force: :cascade do |t|
  end

  create_table "user_chronicles", force: :cascade do |t|
    t.bigint "actor_id", default: 0, null: false
    t.text "actor_type", default: "", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "current_value", default: "", null: false
    t.bigint "event_id", default: 0, null: false
    t.inet "ip_address", default: "0.0.0.0", null: false
    t.datetime "lapses_at", default: ::Float::INFINITY, null: false
    t.bigint "level_id", default: 0, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "previous_value", default: "", null: false
    t.datetime "purge_at", default: -> { "(CURRENT_TIMESTAMP + 'P7Y'::interval)" }, null: false
    t.bigint "subject_id", null: false
    t.text "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "occurred_at"], name: "index_user_chronicles_on_actor_id_and_occurred_at"
    t.index ["actor_type", "actor_id"], name: "index_user_activities_on_actor"
    t.index ["event_id"], name: "index_user_chronicles_on_event_id"
    t.index ["level_id"], name: "index_user_chronicles_on_level_id"
    t.index ["occurred_at"], name: "index_user_chronicles_on_occurred_at"
    t.index ["purge_at"], name: "index_user_chronicles_on_purge_at"
    t.index ["subject_id"], name: "index_user_chronicles_on_subject_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "idx_on_subject_type_subject_id_occurred_at_a29eb711dd"
    t.check_constraint "event_id >= 0", name: "user_activities_event_id_non_negative_check"
    t.check_constraint "level_id >= 0", name: "user_activities_level_id_non_negative_check"
  end

  add_foreign_key "app_document_audits", "app_document_audit_events", column: "event_id", validate: false
  add_foreign_key "app_document_audits", "app_document_audit_levels", column: "level_id", validate: false
  add_foreign_key "app_document_behaviors", "app_document_behavior_events", column: "event_id"
  add_foreign_key "app_document_behaviors", "app_document_behavior_levels", column: "level_id"
  add_foreign_key "app_preference_chronicles", "app_preference_chronicle_events", column: "event_id", validate: false
  add_foreign_key "app_preference_chronicles", "app_preference_chronicle_levels", column: "level_id", validate: false
  add_foreign_key "app_timeline_audits", "app_timeline_audit_events", column: "event_id", validate: false
  add_foreign_key "app_timeline_audits", "app_timeline_audit_levels", column: "level_id", validate: false
  add_foreign_key "app_timeline_behaviors", "app_timeline_behavior_events", column: "event_id"
  add_foreign_key "app_timeline_behaviors", "app_timeline_behavior_levels", column: "level_id"
  add_foreign_key "com_document_audits", "com_document_audit_events", column: "event_id", validate: false
  add_foreign_key "com_document_audits", "com_document_audit_levels", column: "level_id", validate: false
  add_foreign_key "com_document_behaviors", "com_document_behavior_events", column: "event_id"
  add_foreign_key "com_document_behaviors", "com_document_behavior_levels", column: "level_id"
  add_foreign_key "com_preference_chronicles", "com_preference_chronicle_events", column: "event_id", validate: false
  add_foreign_key "com_preference_chronicles", "com_preference_chronicle_levels", column: "level_id", validate: false
  add_foreign_key "com_timeline_audits", "com_timeline_audit_events", column: "event_id", validate: false
  add_foreign_key "com_timeline_audits", "com_timeline_audit_levels", column: "level_id", validate: false
  add_foreign_key "com_timeline_behaviors", "com_timeline_behavior_events", column: "event_id"
  add_foreign_key "com_timeline_behaviors", "com_timeline_behavior_levels", column: "level_id"
  add_foreign_key "org_document_audits", "org_document_audit_events", column: "event_id", validate: false
  add_foreign_key "org_document_audits", "org_document_audit_levels", column: "level_id", validate: false
  add_foreign_key "org_document_behaviors", "org_document_behavior_events", column: "event_id"
  add_foreign_key "org_document_behaviors", "org_document_behavior_levels", column: "level_id"
  add_foreign_key "org_preference_chronicles", "org_preference_chronicle_events", column: "event_id", validate: false
  add_foreign_key "org_preference_chronicles", "org_preference_chronicle_levels", column: "level_id", validate: false
  add_foreign_key "org_timeline_audits", "org_timeline_audit_events", column: "event_id", validate: false
  add_foreign_key "org_timeline_audits", "org_timeline_audit_levels", column: "level_id", validate: false
  add_foreign_key "org_timeline_behaviors", "org_timeline_behavior_events", column: "event_id"
  add_foreign_key "org_timeline_behaviors", "org_timeline_behavior_levels", column: "level_id"
  add_foreign_key "scavenger_global_chronicles", "scavenger_global_chronicle_events", column: "event_id"
  add_foreign_key "scavenger_global_chronicles", "scavenger_global_chronicle_statuses", column: "status_id"
  add_foreign_key "scavenger_regional_chronicles", "scavenger_regional_chronicle_events", column: "event_id"
  add_foreign_key "scavenger_regional_chronicles", "scavenger_regional_chronicle_statuses", column: "status_id"
  add_foreign_key "staff_chronicles", "staff_chronicle_events", column: "event_id", validate: false
  add_foreign_key "staff_chronicles", "staff_chronicle_levels", column: "level_id", validate: false
  add_foreign_key "user_chronicles", "user_chronicle_events", column: "event_id", validate: false
  add_foreign_key "user_chronicles", "user_chronicle_levels", column: "level_id", validate: false
end
